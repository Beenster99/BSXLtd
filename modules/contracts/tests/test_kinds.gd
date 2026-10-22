extends ModuleTest
## The scrapyard loop's small jobs (plan stage S1): break, scrap, refurbish and dispose
## orders read in, offered on the board behind contracts.kinds, the subject sent off to
## Ship and Bay on accept, recoveries, the handover gate and the as-built record.
##   tools/run_tests.sh contracts

const BoardPanel := preload("res://modules/contracts/internal/board_panel.gd")
const Reader := preload("res://modules/contracts/internal/work_order_reader.gd")

const BREAK := "tpa.sb301"
const DISPOSE := "brine_fuels.sd302"
const REFURB := "hesper_line.sr303"
const SCRAP := "kettle_rock.ss304"


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
	check(bus.get_job(BREAK) == null, "no break jobs on offer with contracts.kinds off")

	Flags.use({"core": true, "ui": true, "contracts": true, "contracts.board": true, "contracts.kinds": true})
	Modules.load_all()
	bus = Modules.bus("contracts") as ContractsBus
	_test_reading()
	_test_board(bus)
	_test_break_flow(bus)
	_test_scrap_and_dispose(bus)
	_test_save(bus)
	Flags.use(saved)
	Modules.load_all()


func _test_reading() -> void:
	var reader := Reader.new()
	var base := {"schema": "bsx.work_order", "schema_version": 1, "contract_id": "x.1", "issued_at": "2026-10-22T00:00:00Z",
			"client": {"company": "x"}, "manifest": [], "commercial": {"price": 100}}
	var bad := base.duplicate()
	bad["kind"] = "paint"
	check(reader.read(bad) == null and "kind must be one of" in reader.errors[0], "unknown kind is an error")
	bad = base.duplicate()
	bad["kind"] = "break"
	check(reader.read(bad) == null, "a break order needs a subject and wants")
	check(reader.errors.size() == 2 and "subject" in reader.errors[0] and "wants" in reader.errors[1],
			"and says both: %s" % str(reader.errors))
	var good := base.duplicate()
	good["kind"] = "scrap"
	good["subject"] = {"type": "part", "component": {"id": "HullPlating", "material": "alloy"}, "condition": 0.2, "mass_kg": 500}
	good["wants"] = [{"what": "material", "material": "alloy", "kg": 300}]
	var o := reader.read(good)
	check(o != null, "a scrap order with a part subject and a material want reads: %s" % str(reader.errors))
	if o:
		check(o.kind == WorkOrder.SCRAP and not o.is_fit(), "kind read")
		check(o.subject_part() != null and o.subject_part().material == "alloy", "subject part read")
		check(o.keeps == "bsx" and o.changes.is_empty() and o.ship_id == "", "no ship or changes needed")
	var fit := base.duplicate()
	fit["ship"] = {"ship_id": "x/kestrel", "design": "kestrel"}
	fit["changes"] = []
	check(reader.read(fit) == null and "changes" in reader.errors[0], "a fit order still needs a change")
	good["wants"] = [{"what": "material", "material": "alloy", "kg": 0}]
	check(reader.read(good) == null and "kg must be above 0" in reader.errors[0], "a material want needs kilograms")


func _test_board(bus: ContractsBus) -> void:
	var vs := bus.board(ContractsBus.VOID_SALVAGE)
	var local := bus.board(ContractsBus.LOCAL)
	check(vs.size() == 7, "seven Void Salvage offers with the flag on: %d" % vs.size())
	check(local.size() == 4, "four local offers: %d" % local.size())
	check(bus.get_job(BREAK) != null and bus.get_job(BREAK).order.kind == WorkOrder.BREAK, "the turret break job is on offer")
	check(BoardPanel.job_title(bus.get_job(BREAK)) == "Break a naval turret", "title: %s" % BoardPanel.job_title(bus.get_job(BREAK)))
	check(BoardPanel.job_title(bus.get_job(SCRAP)) == "Scrap hull plating", "scrap title: %s" % BoardPanel.job_title(bus.get_job(SCRAP)))
	check(BoardPanel.job_title(bus.get_job(REFURB)) == "Refurbish a main thruster", "refurbish title")
	check(BoardPanel.job_title(bus.get_job(DISPOSE)) == "Dispose of a fuel tank", "dispose title")
	check(BoardPanel.subject_name(bus.get_job(BREAK).order) == "Bench", "a part job happens at the bench")
	check(BoardPanel.subject_text(bus.get_job(BREAK).order) == "Arrives: Naval turret, 55%, 6.2 t", "subject line: %s" % BoardPanel.subject_text(bus.get_job(BREAK).order))
	var factory: Callable = HudSlots.holo_channel(ContractsBus.BOARD_CHANNEL).factory
	var panel: Control = factory.call(true)
	add_child(panel)
	panel.pick(BREAK)
	check(panel.find_child("Accept", true, false) != null, "the docket offers ACCEPT JOB")
	var texts := PackedStringArray()
	for l in panel.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	check("2 × Turret motor back, 60% or better" in texts, "docket lists what the client wants: %s" % str(texts))
	check("BSX keeps the rest" in texts, "and who keeps the rest")
	check(texts.has("WEAPONS") and texts.has("POWER"), "and the hazards")
	panel.queue_free()


func _test_break_flow(bus: ContractsBus) -> void:
	var due: Array = []
	bus.subject_due.connect(func(id: String, s: Dictionary) -> void: due.append([id, s]))
	var accepted: Array[String] = []
	bus.contract_accepted.connect(func(id: String, v: int, _d: int) -> void: accepted.append("%s %d" % [id, v]))
	check(bus.accept(BREAK), "accept the break job")
	check(accepted == ["tpa.sb301 4200"], "Business hears contract_accepted: %s" % str(accepted))
	check(bus.get_job(BREAK).state == ContractJob.ARRIVING, "a part job goes straight to arriving")
	check(due.size() == 1 and due[0][0] == BREAK, "subject_due for Ship and Bay")
	if due.size() == 1:
		var s: Dictionary = due[0][1]
		check(s.get("type") == "part" and s.get("component") == {"id": "NavalTurret", "material": "steel"}
				and is_equal_approx(float(s.get("mass_kg")), 6200.0), "with the part, its material and mass: %s" % str(s))
	check(not bus.advance(BREAK, ContractJob.IN_BAY), "nothing starts until it lands")
	check(bus.subject_landed(BREAK), "Ship and Bay lands it")
	check(bus.get_job(BREAK).state == ContractJob.PARTS_READY, "then it is ready")
	check(not bus.subject_landed(BREAK), "landing twice does nothing")
	check(bus.advance(BREAK, ContractJob.IN_BAY) and bus.advance(BREAK, ContractJob.IN_PROGRESS), "into work")

	var lines: Array[Dictionary] = []
	bus.recovery_recorded.connect(func(_id: String, l: Dictionary) -> void: lines.append(l))
	var motor := ComponentRef.new()
	motor.id = "TurretMotor"
	check(bus.record_recovery(BREAK, motor, 0.7), "a motor comes out")
	check(bus.record_recovery(BREAK, motor, 0.4), "a worn one too")
	var sight := ComponentRef.new()
	sight.id = "Gunsight"
	bus.record_recovery(BREAK, sight, 0.8)
	bus.record_scrap(BREAK, "steel", 4100.0)
	check(lines.size() == 4, "every recovery is announced")
	check(bus.advance(BREAK, ContractJob.INSPECTION), "to inspection")
	var missing := bus.get_job(BREAK).missing_wants()
	check(missing == PackedStringArray(["1 of 2 TurretMotor returned"]), "the worn motor doesn't count: %s" % str(missing))
	check(not bus.advance(BREAK, ContractJob.HANDED_OVER), "can't hand over short of what the client wants")
	bus.record_recovery(BREAK, motor, 0.65)
	var handed: Array[String] = []
	bus.contract_handed_over.connect(func(id: String, q: float, s: int) -> void: handed.append("%s %.2f %d" % [id, q, s]))
	check(bus.advance(BREAK, ContractJob.HANDED_OVER), "handed over once both motors and the sight are back")
	check(handed == ["tpa.sb301 0.64 0"], "quality is the mean condition of what went back: %s" % str(handed))
	var record := bus.as_built(BREAK)
	check(record.get("kind") == "break" and record.get("subject", {}).get("component", {}).get("id") == "NavalTurret",
			"the as-built record carries the kind and subject")
	check((record.get("recovered", []) as Array).size() == 5 and (record.get("installed", []) as Array).is_empty(),
			"and the recoveries, with no installs")
	check(bus.get_job(BREAK).order.is_fit() == false and not bus.record_recovery("rook_salvage.vs101", motor, 1.0),
			"a fit job takes no recoveries")


func _test_scrap_and_dispose(bus: ContractsBus) -> void:
	bus.accept(SCRAP)
	bus.subject_landed(SCRAP)
	bus.advance(SCRAP, ContractJob.IN_BAY)
	bus.advance(SCRAP, ContractJob.IN_PROGRESS)
	bus.record_scrap(SCRAP, "alloy", 5000.0)
	bus.advance(SCRAP, ContractJob.INSPECTION)
	check(bus.get_job(SCRAP).missing_wants() == PackedStringArray(["5000 of 8000 kg alloy"]), "scrap short: %s" % str(bus.get_job(SCRAP).missing_wants()))
	bus.record_scrap(SCRAP, "alloy", 3500.0)
	check(bus.advance(SCRAP, ContractJob.HANDED_OVER), "eight tonnes pressed, handed over")

	bus.accept(DISPOSE)
	bus.subject_landed(DISPOSE)
	bus.advance(DISPOSE, ContractJob.IN_BAY)
	bus.advance(DISPOSE, ContractJob.IN_PROGRESS)
	bus.advance(DISPOSE, ContractJob.INSPECTION)
	check(bus.get_job(DISPOSE).missing_wants() == PackedStringArray(["subject scrapped or destroyed"]), "the tank is still there")
	bus.record_scrap(DISPOSE, "steel", 3800.0, "destroyed")
	check(bus.advance(DISPOSE, ContractJob.HANDED_OVER), "gone, handed over")

	bus.accept(REFURB)
	bus.subject_landed(REFURB)
	bus.advance(REFURB, ContractJob.IN_BAY)
	bus.advance(REFURB, ContractJob.IN_PROGRESS)
	bus.advance(REFURB, ContractJob.INSPECTION)
	var thruster := bus.get_job(REFURB).order.subject_part()
	bus.record_recovery(REFURB, thruster, 0.8)
	check(not bus.advance(REFURB, ContractJob.HANDED_OVER), "80% is not the 90% asked for")
	bus.record_recovery(REFURB, thruster, 0.92)
	check(bus.advance(REFURB, ContractJob.HANDED_OVER), "92% is")


func _test_save(bus: ContractsBus) -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(bus.save_data()))
	var bus2 := ContractsBus.new()
	add_child(bus2)
	bus2.load_data(data, ContractsBus.SAVE_VERSION)
	var job := bus2.get_job(BREAK)
	check(job != null and job.order.kind == WorkOrder.BREAK and job.recoveries.size() == 5, "a break job and its recoveries survive a save")
	check(job != null and job.state == ContractJob.HANDED_OVER, "and its state")
	bus2.queue_free()
