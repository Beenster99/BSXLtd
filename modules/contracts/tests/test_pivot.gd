extends ModuleTest
## The shipbuilder pivot's Wave 0 (contracts.vs_orders and contracts.wrecks off by default):
## no Void Salvage orders on the board or from the clients, a work order file from that
## game refused with a readable reason, no VOID SALVAGE tab; wreck contracts off.
##   tools/run_tests.sh contracts

const BoardPanel := preload("res://modules/contracts/internal/board_panel.gd")
const FIXTURE := "res://modules/contracts/tests/fixtures/kestrel_coil_fit.workorder.json"
const OFF := {"core": true, "ui": true, "contracts": true, "contracts.board": true, "contracts.kinds": false,
		"contracts.fit_jobs": false, "contracts.clients": true, "contracts.debug": true, "contracts.wrecks": false,
		"contracts.vs_orders": false}
## The old offers back on, for the checks that the flags alone hide them.
const OLD := {"contracts.kinds": true, "contracts.fit_jobs": true}


func run_tests() -> void:
	var saved := Flags.all()
	var project := load("res://config/project_flags.tres").flags as Dictionary
	check(not bool(project.get("contracts.vs_orders", true)), "project flags: orders from Void Salvage are off")
	check(not bool(project.get("contracts.wrecks", true)), "project flags: wreck contracts are off")
	check(not bool(project.get("contracts.kinds", true)) and not bool(project.get("contracts.fit_jobs", true)),
			"project flags: part jobs and fit jobs are off")
	for profile in ["v0.3", "v0.4"]:
		var release := load("res://config/release_profiles/%s.tres" % profile).flags as Dictionary
		check(not bool(release.get("contracts.vs_orders", true)) and not bool(release.get("contracts.wrecks", true))
				and not bool(release.get("contracts.kinds", true)) and not bool(release.get("contracts.fit_jobs", true)),
				"release profile %s: the dropped systems are off" % profile)

	Flags.use(OFF)
	Modules.load_all()
	var bus := Modules.bus("contracts") as ContractsBus
	if bus == null:
		check(false, "contracts loads")
		Flags.use(saved)
		Modules.load_all()
		return
	check(bus.board(ContractsBus.VOID_SALVAGE).is_empty(), "no Void Salvage offers on the board")
	check(bus.board(ContractsBus.LOCAL).is_empty(), "no local offers either: the board is empty before Wave 4")
	var r := bus.import_work_order(FIXTURE)
	check(not r.ok() and r.errors.has(ContractsBus.VS_ORDERS_OFF), "a Void Salvage work order file is refused with the reason: %s" % "; ".join(r.errors))
	check(bus.call_in("hesper_line", 1) == "", "no part job can be called in with the kinds off")
	check(bus._validate_call_in(1, {"client": "hesper_line", "tier": 1}) is String, "the debug call-in says so")
	var old := OFF.duplicate()
	old.merge(OLD, true)
	Flags.use(old)
	Modules.load_all()
	bus = Modules.bus("contracts") as ContractsBus
	check(bus.board(ContractsBus.VOID_SALVAGE).is_empty(), "with the part jobs back on, still no Void Salvage offers")
	check(not bus.board(ContractsBus.LOCAL).is_empty(), "the local fit jobs are back")
	for job in bus.board(ContractsBus.LOCAL):
		check(not ContractsBus.is_vs_order(job.order), "%s is a local order" % job.job_id)
	check(bus.call_in("tpa", 1) == "", "a Void Salvage client cannot be called in")
	check(bus.call_in("hesper_line", 1) != "", "a BSX client can")
	check(bus._validate_call_in(1, {"client": "tpa", "tier": 1}) is String, "the debug call-in refuses a Void Salvage client")
	for i in 6:
		bus.advance_cycle()
	for job in bus.board(ContractsBus.LOCAL) + bus.board(ContractsBus.TAKEN):
		check(not ContractsBus.is_vs_order(job.order), "cycles post nothing from Void Salvage: %s" % job.job_id)
		check(String(job.order.subject.get("type", "part")) != "wreck", "no wreck contracts: %s" % job.job_id)
	var panel: Control = HudSlots.holo_channel(ContractsBus.BOARD_CHANNEL).factory.call(true)
	add_child(panel)
	check(BoardPanel.tabs() == BoardPanel.LOCAL_TABS, "the board has no VOID SALVAGE tab")
	check(panel.tab == "local work", "the board opens on local work: %s" % panel.tab)
	panel.queue_free()

	var on := old.duplicate()
	on["contracts.vs_orders"] = true
	Flags.use(on)
	Modules.load_all()
	bus = Modules.bus("contracts") as ContractsBus
	check(not bus.board(ContractsBus.VOID_SALVAGE).is_empty(), "with the flag on the Void Salvage offers come back")
	check(BoardPanel.tabs() == BoardPanel.TABS, "and the tab")
	Flags.use(saved)
	Modules.load_all()
