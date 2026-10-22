extends ModuleTest
## The contracts board on the wrist screen: bundled offers, tabs, the docket, ACCEPT JOB,
## and a save that doesn't bring a taken job back on offer.
##   tools/run_tests.sh contracts

const BoardPanel := preload("res://modules/contracts/internal/board_panel.gd")


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "contracts.board": true, "contracts.kinds": false})
	Modules.load_all()
	var bus := Modules.bus("contracts") as ContractsBus
	check(bus != null, "contracts loads")
	if bus == null:
		Flags.use(saved)
		Modules.load_all()
		return
	check(not HudSlots.holo_channel(ContractsBus.BOARD_CHANNEL).is_empty(), "board is a wrist screen channel")

	var vs := bus.board(ContractsBus.VOID_SALVAGE)
	var local := bus.board(ContractsBus.LOCAL)
	check(vs.size() == 4, "four Void Salvage offers: %d" % vs.size())
	check(local.size() == 3, "three local yard offers: %d" % local.size())
	check(bus.board(ContractsBus.TAKEN).is_empty(), "nothing taken on yet")
	check(vs[0].job_id == "rook_salvage.vs101", "soonest due first: %s" % vs[0].job_id)
	for job in vs + local:
		check(job.state == ContractJob.OFFERED, "%s is on offer" % job.job_id)

	var factory: Callable = HudSlots.holo_channel(ContractsBus.BOARD_CHANNEL).factory
	var panel: Control = factory.call(true)
	add_child(panel)
	check(panel.jobs().size() == 4, "panel opens on Void Salvage")
	check(panel.find_child("Row_rook_salvage_vs101", true, false) != null, "a row per job")
	check(BoardPanel.part_name("attractor_coil_1") == "Attractor coil Mk I", "module ids read as words")

	panel.pick("ashfall_crew.vs102")
	var accept := panel.find_child("Accept", true, false) as Button
	check(accept != null, "offer has ACCEPT JOB")
	var accepted: Array[String] = []
	bus.contract_accepted.connect(func(id: String, v: int, d: int) -> void: accepted.append("%s %d %d" % [id, v, d]))
	if accept:
		accept.pressed.emit()
	check(bus.get_job("ashfall_crew.vs102").state == ContractJob.ACCEPTED, "ACCEPT JOB accepts")
	check(accepted == ["ashfall_crew.vs102 9800 5"], "contract_accepted for Business: %s" % str(accepted))
	check(bus.get_active_job() != null and bus.get_active_job().job_id == "ashfall_crew.vs102", "first job taken becomes active")
	check(panel.jobs().size() == 3, "it leaves the offers")
	panel.pick_tab("accepted")
	check(panel.jobs().size() == 1 and panel.find_child("Accept", true, false) == null, "and shows under accepted")

	panel.pick_tab("local work")
	panel.pick("kettle_rock.lw202")
	(panel.find_child("Accept", true, false) as Button).pressed.emit()
	check(bus.get_active_job().job_id == "ashfall_crew.vs102", "a second job doesn't take over the active one")
	panel.pick_tab("accepted")
	panel.pick("kettle_rock.lw202")
	var make := panel.find_child("MakeActive", true, false) as Button
	check(make != null, "a taken job can be made active")
	if make:
		make.pressed.emit()
	check(bus.get_active_job().job_id == "kettle_rock.lw202", "MAKE ACTIVE JOB switches")

	var data: Dictionary = JSON.parse_string(JSON.stringify(bus.save_data()))
	var bus2 := ContractsBus.new()
	add_child(bus2)
	bus2.load_data(data, ContractsBus.SAVE_VERSION)
	check(bus2.board(ContractsBus.VOID_SALVAGE).size() == 3, "a taken job isn't offered again after loading")
	check(bus2.board(ContractsBus.TAKEN).size() == 2, "taken jobs survive a save")
	bus2.queue_free()
	panel.queue_free()

	Flags.use({"core": true, "ui": true, "contracts": true, "contracts.board": false})
	Modules.load_all()
	check(HudSlots.holo_channel(ContractsBus.BOARD_CHANNEL).is_empty(), "no channel with the flag off")
	Flags.use(saved)
	Modules.load_all()
