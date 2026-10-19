extends ModuleTest
## Work order import: the Kestrel fixture reads; bad files are refused with readable lines;
## unknown fields survive a save.
##   tools/run_tests.sh contracts

const FIXTURES := "res://modules/contracts/tests/fixtures/"
const KNOWN: PackedStringArray = ["hold_net", "attractor_coil_1"]


func run_tests() -> void:
	var bus := ContractsBus.new()
	add_child(bus)
	bus.set_component_library(func(id: String) -> bool: return id in KNOWN)
	var imported: Array[String] = []
	var failed: Array[String] = []
	bus.contract_imported.connect(func(id: String) -> void: imported.append(id))
	bus.import_failed.connect(func(path: String, _e: PackedStringArray) -> void: failed.append(path))

	var r := bus.import_work_order(FIXTURES + "kestrel_coil_fit.workorder.json")
	check(r.ok(), "Kestrel fixture imports: %s" % "; ".join(r.errors))
	check(imported == ["rook_salvage.bsx1"], "contract_imported fired once")
	var job := bus.get_active_job()
	check(job != null and job.job_id == "rook_salvage.bsx1", "first import becomes the active job")
	var o := job.order
	check(o.ship_id == "rook_salvage/kestrel" and o.design == "kestrel", "ship read")
	check(o.client.get("company") == "rook_salvage", "client read")
	check(o.current_fit.size() == 1 and is_equal_approx(o.current_fit[0]["condition"], 0.8), "current fit read")
	var c := o.change("c1")
	check(c != null and c.action == ChangeItem.REPLACE and c.slot == "hold_module_1", "change read")
	check(c.install.id == "attractor_coil_1" and c.install.material == "copper", "install component read")
	check(c.remove.id == "hold_net" and c.remove.material == "", "removed component read")
	check(o.manifest.size() == 1 and o.manifest[0].qty == 1 and "refurbished" in o.manifest[0].allowed_sources, "manifest read")
	check(o.overrides.get("c1", {}).get("bolt", {}).get("torque_nm") == 200, "spec override read")
	check(o.notes_for("c1").size() == 1, "note on the change read")
	check(job.status_of("c1") == ChangeItem.PENDING, "changes start pending")

	r = bus.import_work_order(FIXTURES + "kestrel_coil_fit.workorder.json")
	check(not r.ok() and "already in the bay" in r.errors[0], "same contract refused twice")

	r = bus.import_work_order(FIXTURES + "unknown_component.workorder.json")
	check(not r.ok() and r.errors.size() == 1 and "flux_capacitor" in r.errors[0], "unknown component refused with one line: %s" % str(r.errors))

	r = bus.import_work_order(FIXTURES + "future_version.workorder.json")
	check(not r.ok() and "newer BSX" in r.errors[0], "newer schema refused, not half-loaded")
	check(bus.get_job("rook_salvage.bsx3") == null, "refused file makes no job")
	check(failed.size() == 3, "import_failed fired for each refusal")

	r = bus.import_work_order(FIXTURES + "no_such_file.json")
	check(not r.ok(), "missing file refused")
	r = bus.import_text("{not json")
	check(not r.ok() and "readable" in r.errors[0], "broken JSON refused")
	r = bus.import_text(JSON.stringify({"schema": "bsx.as_built", "schema_version": 1}))
	check(not r.ok() and "not a work order" in r.errors[0], "wrong schema refused")
	var bad := JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "kestrel_coil_fit.workorder.json")) as Dictionary
	bad["contract_id"] = "bad"
	bad["changes"][0]["action"] = "paint"
	bad["manifest"][0]["qty"] = 0
	r = bus.import_text(JSON.stringify(bad))
	check(r.errors.size() == 2, "every problem listed, one line each: %s" % str(r.errors))

	r = bus.import_work_order(FIXTURES + "v1_extra_fields.workorder.json")
	check(r.ok(), "file with unknown fields imports")
	var data := bus.save_data()
	var again := ContractsBus.new()
	add_child(again)
	again.load_data(JSON.parse_string(JSON.stringify(data)), ContractsBus.SAVE_VERSION)
	var kept := again.get_job("rook_salvage.bsx4")
	check(kept != null and kept.order.raw.get("paint_scheme") == "red stripes", "unknown top-level field kept through a save")
	check(kept.order.raw["changes"][0].get("priority") == "high", "unknown nested field kept through a save")
	check(again.get_active_job().job_id == "rook_salvage.bsx1", "active job kept through a save")
	bus.queue_free()
	again.queue_free()
