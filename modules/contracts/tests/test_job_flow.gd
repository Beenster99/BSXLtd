extends ModuleTest
## A job from import to as-built: states, rework, spec lookup, install records, the
## as-built file and the save round trip.
##   tools/run_tests.sh contracts

const FIXTURE := "res://modules/contracts/tests/fixtures/kestrel_coil_fit.workorder.json"
const ID := "rook_salvage.bsx1"


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "business": false})
	Modules.load_all()
	_test_without_business()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "business": true})
	Modules.load_all()
	_test_with_business()
	Flags.use(saved)
	Modules.load_all()


func _library(bus: ContractsBus) -> void:
	bus.set_component_library(func(_id: String) -> bool: return true,
			func(id: String) -> Dictionary:
				return {"bolt": {"torque_nm": 180, "pattern": "cross"}, "connector": {"gauge_awg": 8}} if id == "attractor_coil_1" else {})


func _test_without_business() -> void:
	check(not Modules.is_loaded("business"), "Business is off for the first pass")
	var bus := ContractsBus.new()
	add_child(bus)
	_library(bus)
	var moves: Array[String] = []
	bus.job_state_changed.connect(func(_j: String, a: String, b: String) -> void: moves.append("%s>%s" % [a, b]))
	check(bus.import_work_order(FIXTURE).ok(), "fixture imports")
	var events: Array[String] = []
	bus.contract_handed_over.connect(func(id: String, q: float, s: int) -> void: events.append("handed_over %s %.2f %d" % [id, q, s]))
	bus.contract_cancelled.connect(func(id: String, by: bool) -> void: events.append("cancelled %s %s" % [id, by]))
	bus.contract_accepted.connect(func(id: String, v: int, d: int) -> void: events.append("accepted %s %d %d" % [id, v, d]))

	var spec := bus.get_spec(ID, "c1")
	check(spec.bolt.get("torque_nm") == 200, "work order override beats the library")
	check(spec.bolt.get("pattern") == "star", "override pattern applies")
	check(spec.connector.get("gauge_awg") == 8, "library value kept where nothing overrides it")
	check(spec.component.id == "attractor_coil_1", "spec names the part going in")
	check(bus.get_spec(ID, "nope") == null, "unknown change has no spec")

	check(not bus.advance(ID, ContractJob.IN_BAY), "can't skip ahead to in_bay")
	check(bus.advance(ID, ContractJob.PARTS_READY), "offered straight to parts_ready while Business is off")
	check(bus.advance(ID, ContractJob.IN_BAY) and bus.advance(ID, ContractJob.IN_PROGRESS), "into the bay and working")
	bus.set_change_status(ID, "c1", ChangeItem.STRIPPED)
	bus.record_removal(ID, "c1", 0.75, "returned")
	bus.set_change_status(ID, "c1", ChangeItem.INSTALLED)
	check(bus.advance(ID, ContractJob.INSPECTION), "to inspection")
	bus.set_change_status(ID, "c1", ChangeItem.FAILED)
	check(bus.advance(ID, ContractJob.IN_PROGRESS), "rework loop back to in_progress")
	check(bus.get_job(ID).status_of("c1") == ChangeItem.INSTALLED, "failed change back to installed for rework")
	check(bus.advance(ID, ContractJob.INSPECTION), "inspection again")
	bus.set_change_status(ID, "c1", ChangeItem.INSPECTED)
	check(bus.advance(ID, ContractJob.HANDED_OVER), "handed over")
	check(events == ["handed_over %s 1.00 0" % ID], "handover signalled for Business: %s" % str(events))
	check(bus.as_built(ID).is_empty(), "no as-built without an install record")
	check(bus.export_as_built(ID, OS.get_user_data_dir()) == ERR_UNCONFIGURED, "export refused without an install record")

	var rec := InstallRecord.new()
	rec.component = ComponentRef.from_dict({"id": "attractor_coil_1", "material": "copper"})
	rec.serial = "BSX-000123"
	rec.source = "refurbished"
	rec.quality = 0.87
	rec.joints = {"bolt": {"count": 6, "min": 0.78, "mean": 0.91}}
	rec.defects = [{"type": "bad_crimp", "severity": 0.2, "hidden": true}]
	bus.record_install(ID, "c1", rec)
	bus.record_test(ID, "coil_power_on", true, 0.98, "ratio")
	bus.sign_off(ID, "bsx_3", "qa_inspector")
	check(bus.raise_variation(ID, "Corroded mount plate", 4000.0) == "v1", "variation logged")

	# Save and reload mid-handover: the job comes back whole.
	var data: Dictionary = JSON.parse_string(JSON.stringify(bus.save_data()))
	var bus2 := ContractsBus.new()
	add_child(bus2)
	bus2.load_data(data, ContractsBus.SAVE_VERSION)
	var job2 := bus2.get_job(ID)
	check(job2 != null and job2.state == ContractJob.HANDED_OVER, "state survives a save")
	check(job2.installs.has("c1") and is_equal_approx((job2.installs["c1"] as InstallRecord).quality, 0.87), "install record survives a save")

	var closed: Array[String] = []
	bus2.job_closed.connect(func(id: String) -> void: closed.append(id))
	var path := OS.get_user_data_dir().path_join("%s.asbuilt.json" % ID)
	check(bus2.export_as_built(ID, OS.get_user_data_dir()) == OK, "as-built exported")
	check(bus2.get_job(ID).state == ContractJob.CLOSED, "export closes the job")
	var out: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(out.get("schema") == "bsx.as_built" and out.get("schema_version") == 1.0, "as-built schema")
	check(out.get("contract_id") == ID and out.get("ship_id") == "rook_salvage/kestrel", "as-built names the job and ship")
	var inst: Dictionary = out["installed"][0]
	check(inst["component"] == {"id": "attractor_coil_1", "material": "copper"} and inst["slot"] == "hold_module_1", "installed line")
	check(is_equal_approx(inst["quality"], 0.87) and inst["joints"]["bolt"]["count"] == 6.0, "quality and joints written")
	check(inst["defects"][0]["hidden"] == true, "hidden defect written")
	var rem: Dictionary = out["removed"][0]
	check(rem["component"] == {"id": "hold_net"} and is_equal_approx(rem["condition"], 0.75), "removed line")
	check(out["tests"].size() == 1 and out["signed_by"][0]["role"] == "qa_inspector", "tests and sign-off written")
	check(out["variations"].size() == 1, "variation written")
	check(not out.has("invoice"), "no invoice while Business is off")
	check(moves.size() == 7, "every move signalled once: %s" % str(moves))
	check(closed == [ID], "job_closed fired for Progression")
	DirAccess.remove_absolute(path)

	check(not ContractJob.can_move(ContractJob.HANDED_OVER, ContractJob.CANCELLED), "can't cancel after handover")
	check(ContractJob.can_move(ContractJob.IN_BAY, ContractJob.CANCELLED), "can cancel in the bay")

	# The Business path: offered -> accepted fires contract_accepted; cancel says who.
	var order: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	order["contract_id"] = "rook_salvage.bsx9"
	order["commercial"]["due_day"] = 12
	check(bus.import_text(JSON.stringify(order)).ok(), "second job imports")
	events.clear()
	check(bus.advance("rook_salvage.bsx9", ContractJob.ACCEPTED), "accepted")
	check(bus.cancel("rook_salvage.bsx9", true), "cancelled by the client")
	check(events == ["accepted rook_salvage.bsx9 120000 12", "cancelled rook_salvage.bsx9 true"], "accept and cancel signalled: %s" % str(events))
	check(not bus.cancel("rook_salvage.bsx9", true), "can't cancel twice")
	bus.queue_free()
	bus2.queue_free()


## With Business loaded, the loaded Contracts bus can't skip acceptance, accepting books the
## deposit, and the as-built carries an invoice.
func _test_with_business() -> void:
	var bus := Modules.bus("contracts") as ContractsBus
	var books := Modules.bus("business") as BusinessBus
	check(bus != null and books != null, "both buses load with Business on: %s" % Modules.skipped_reason("business"))
	if bus == null or books == null:
		return
	books.reset()
	_library(bus)
	var order: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	order["contract_id"] = "rook_salvage.bsx20"
	order["commercial"]["due_day"] = 12
	check(bus.import_text(JSON.stringify(order)).ok(), "job imports with Business on")
	var id := "rook_salvage.bsx20"
	var cash := books.get_cash()
	check(not bus.advance(id, ContractJob.PARTS_READY), "can't skip acceptance while Business is on")
	check(bus.advance(id, ContractJob.ACCEPTED), "offered to accepted")
	var deposit := books.get_cash() - cash
	check(deposit > 0 and deposit == int(order["commercial"]["price"] * 0.3), "deposit booked on acceptance: %d" % deposit)
	check(books.get_contract_balance(id).get("deposit") == deposit, "Business holds the contract")
	check(bus.advance(id, ContractJob.PARTS_READY), "accepted to parts_ready")
	check(bus.cancel(id, true), "cancelled by the client")
	books.reset()
