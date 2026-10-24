class_name QualityBus
extends Node
## Quality and Inspection module bus (Modules.bus("quality")). Joint quality records, inspection tools, the snag list, commissioning tests and the as-built record.
## Other modules use this module only through this folder: signals here, and resource
## classes placed next to it. Everything else lives in internal/.
##
## Trades reports what was built (raw measurements); Quality decides whether it is good
## enough, so pass marks are tuned here without touching Trades. Release 0.1 has grading
## (quality.scores) for bolting; inspection, snags, tests and handover follow in 0.5.
##
## Surveys (quality.surveys): players never inspect their own work. The customer mandates an
## independent consultancy (SurveyReport.FIRM) whose surveyors walk the ship scanning joints,
## then leave a SurveyReport: spot surveys turn up unannounced while a job is in progress,
## the crew can call one from the wrist screen or a TV (the Surveys channel), and marking the
## job complete (Contracts' inspection state) brings the final survey, which hands the job
## over or sends it back for rework. The host runs the visits; every player gets the reports.
##
## Rig tests (quality.rig_tests, Component Upgrades U1): when a crew has fitted add-ons to a
## unit on a rig, the rig calls run_field_sweep() with the unit, its add-ons and the joint ids
## it made; Quality scores the sweep from those joints and answers with an UpgradePlate on
## rig_test_finished (serial, tier, grade, tested figures, or the snags that failed it):
##   quality.run_field_sweep({"unit_id": "attractor_coil_1", "base": {"attract_reach": 18.0},
##           "addons": [{"part": "quantum_core", "tier": 2, "mount": "coil_bay"}],
##           "joint_ids": ["coil_bay_bolts", "loom_plug"]})
## make_sweep_screen() and make_plate_node() draw the result on the rig and on the unit.
## The emitter frame rig needs none of that: its TEST button fires Ship and Bay's
## rig_test_requested(rig_id, unit_id); Quality reads the opened unit from Tools
## (TradesBus.unit_state) and answers with ShipBayBus.rig_show_test(rig_id, result).

## A joint was graded (also fired again when a reworked joint is regraded).
signal joint_graded(record: JointRecord)
## A joint's record was dropped because Trades took it apart for rework.
signal record_dropped(joint_id: StringName)
## Surveyors arrived to scan these joints (ids as Strings). kind is a SurveyReport kind.
signal survey_started(kind: StringName, job_id: String, joint_ids: Array)
## The surveyors left and their report is in.
signal survey_finished(report: SurveyReport)
## A rig test is done; plate.passed says whether the unit is certified (it has a serial).
signal rig_test_finished(plate: UpgradePlate)

const SCORES := "quality.scores"
const SURVEYS := "quality.surveys"
const SCORE_CARD := "quality_score_card"
const SURVEYS_CHANNEL := "quality.surveys"
const RIG_TESTS := "quality.rig_tests"
const SAVE_VERSION := 2

const CALL_EVENT := "quality.survey_call"
const START_EVENT := "quality.survey_start"
const REPORT_EVENT := "quality.survey_report"
const SWEEP_EVENT := "quality.field_sweep"
const PLATE_EVENT := "quality.plate"
const NOTICE := "quality.survey"
const NOTICE_S := 14.0

const SurveyScreen := preload("res://modules/quality/internal/survey_screen.gd")
const SurveyCrew := preload("res://modules/quality/internal/survey_crew.gd")
const SurveyDemo := preload("res://modules/quality/internal/survey_demo.gd")
const SweepScreen := preload("res://modules/quality/internal/sweep_screen.gd")
const PlateNode := preload("res://modules/quality/internal/plate_node.gd")

var _records: Dictionary = {}
var _modifiers: Dictionary = {}  # str(peer_id) -> {effect_key: value}
var _grader: QualityGrader

var survey_rules: SurveyRules = load("res://modules/quality/internal/data/survey_rules.tres")
var _contracts: Node
var _net: Node
var _reports: Array[SurveyReport] = []
var _count := 0
## The visit under way: {id, kind, job_id, joints, duration, crew}; {} with none.
var _survey: Dictionary = {}
var _survey_left := 0.0
var _random_left := 0.0
var _final_pending := false
var _notice_left := 0.0
var _yard: Node3D
var _rng := RandomNumberGenerator.new()
var rig_rules: RigRules = load("res://modules/quality/internal/data/rig_rules.tres")
var _plates: Array[UpgradePlate] = []
var _serials := 0


func register_module() -> void:
	_grader = QualityGrader.new()
	var trades := Modules.bus("trades")
	if trades:
		# JointResult belongs to Trades; read it by field so either side can ship first.
		if trades.has_signal("joint_completed"):
			trades.joint_completed.connect(submit)
		if trades.has_signal("joint_removed"):
			trades.joint_removed.connect(drop)
	Saves.register_section("quality", self)
	# With surveys on, players learn how good their work is from the surveyors' reports.
	if Flags.is_on(SCORES) and not Flags.is_on(SURVEYS):
		HudSlots.register_panel(SCORE_CARD, "res://modules/quality/internal/score_card.tscn",
				HudSlots.NOTICES)
	attach(Modules.bus("contracts"), Modules.bus("multiplayer"))
	# Ship and Bay's rigs and Tools' opened units arrive in U1; listen when they're there.
	var rigs := Modules.bus("ship_bay")
	if Flags.is_on(RIG_TESTS) and rigs and rigs.has_signal("rig_test_requested"):
		rigs.connect("rig_test_requested", _on_rig_test_requested)
	if Flags.is_on(SURVEYS):
		HudSlots.register_holo_channel(SURVEYS_CHANNEL, "Surveys",
				func(glass: bool) -> Control: return SurveyScreen.new(self, glass), 58)
		var yard_bus := Modules.bus("ship_bay")
		if yard_bus and yard_bus.has_signal("shipyard_ready") and not yard_bus.shipyard_ready.is_connected(_on_shipyard_ready):
			yard_bus.shipyard_ready.connect(_on_shipyard_ready)
		if Router.has_scene(ShipBayBus.SHIPYARD_SCENE):
			Shots.register("quality_surveyors_on_ship", ShipBayBus.SHIPYARD_SCENE, _shot_crew, 40)
			Shots.register("quality_survey_report", ShipBayBus.SHIPYARD_SCENE, _shot_report, 40)


func unregister_module() -> void:
	HudSlots.unregister_panel(SCORE_CARD)
	HudSlots.unregister_holo_channel(SURVEYS_CHANNEL)
	HudSlots.clear_info(NOTICE)
	Saves.unregister_section("quality")
	if _net:
		for e in [CALL_EVENT, START_EVENT, REPORT_EVENT, SWEEP_EVENT, PLATE_EVENT]:
			_net.call("unregister_event", e)
		_net.call("unregister_snapshot_provider", "quality")
	if _contracts and _contracts.job_state_changed.is_connected(_on_job_state_changed):
		_contracts.job_state_changed.disconnect(_on_job_state_changed)


## Connects to Contracts and Multiplayer (either may be null). register_module() passes the
## real buses; tests pass stand-ins. With no net the visits run here as if solo.
func attach(contracts: Node, net: Node) -> void:
	_contracts = contracts
	if _contracts and _contracts.has_signal("job_state_changed") \
			and not _contracts.job_state_changed.is_connected(_on_job_state_changed):
		_contracts.job_state_changed.connect(_on_job_state_changed)
	_net = net if net and net.has_method("register_event") else null
	if _net:
		_net.call("register_event", CALL_EVENT, _apply_call, _validate_call)
		_net.call("register_event", START_EVENT, _apply_start)
		_net.call("register_event", REPORT_EVENT, _apply_report)
		_net.call("register_event", SWEEP_EVENT, _apply_sweep, _validate_sweep)
		_net.call("register_event", PLATE_EVENT, _apply_plate)
		_net.call("register_snapshot_provider", "quality", self)
	_random_left = _next_random()


## Grades a finished joint. `result` is a Trades JointResult, or anything with its fields
## (joint_id, trade, component_id, mount_id, measurements, peer_id, time).
func submit(result: Object) -> JointRecord:
	var r := JointRecord.new()
	r.joint_id = StringName(result.get("joint_id"))
	r.trade = StringName(result.get("trade"))
	r.component_id = StringName(_field(result, "component_id", ""))
	r.mount_id = StringName(_field(result, "mount_id", ""))
	r.measurements = _field(result, "measurements", {}).duplicate(true)
	r.peer_id = int(_field(result, "peer_id", 1))
	r.time = int(_field(result, "time", int(Time.get_unix_time_from_system())))
	var job := _active_job()
	r.job_id = str(job.get("job_id")) if job else ""
	_grader.grade(r, _modifiers.get(str(r.peer_id), {}))
	_records[r.joint_id] = r
	joint_graded.emit(r)
	return r


## Forgets a joint (Trades took it apart); the next attempt is graded fresh.
func drop(joint_id: StringName) -> void:
	if _records.erase(joint_id):
		record_dropped.emit(joint_id)


## Progression pushes each player's effects here (player_id is str(peer_id)). Quality reads
## "torque_tolerance" and ignores keys it doesn't own. Applies to joints graded from now on.
func set_player_modifiers(player_id: Variant, effects: Dictionary) -> void:
	_modifiers[str(player_id)] = effects.duplicate()


func get_record(joint_id: StringName) -> JointRecord:
	return _records.get(joint_id)


## Records matching every key in filter, e.g. {"trade": &"BOLT", "grade": JointRecord.FAIL}.
func records(filter: Dictionary = {}) -> Array[JointRecord]:
	var out: Array[JointRecord] = []
	for r: JointRecord in _records.values():
		if filter.keys().all(func(k): return r.get(k) == filter[k]):
			out.append(r)
	return out


## {"joints": n, "passed": n, "marginal": n, "failed": n, "average": float,
##  "by_trade": {"BOLT": {"joints": n, "average": float}}}; average ignores UNGRADED joints.
func summary() -> Dictionary:
	var out := {"joints": 0, "passed": 0, "marginal": 0, "failed": 0, "average": 0.0, "by_trade": {}}
	var graded := 0
	var total := 0
	for r: JointRecord in _records.values():
		out.joints += 1
		match r.grade:
			JointRecord.PASS: out.passed += 1
			JointRecord.MARGINAL: out.marginal += 1
			JointRecord.FAIL: out.failed += 1
		var t: Dictionary = out.by_trade.get_or_add(String(r.trade), {"joints": 0, "average": 0.0, "_sum": 0, "_n": 0})
		t.joints += 1
		if r.score >= 0:
			graded += 1
			total += r.score
			t._sum += r.score
			t._n += 1
	out.average = float(total) / graded if graded > 0 else 0.0
	for t: Dictionary in out.by_trade.values():
		t.average = float(t._sum) / t._n if t._n > 0 else 0.0
		t.erase("_sum")
		t.erase("_n")
	return out


func clear() -> void:
	_records = {}
	_reports = []
	_survey = {}
	_count = 0
	_final_pending = false
	_plates = []
	_serials = 0


# Rig tests

## What a field sweep would show now, without running it (rig screens, previews, tests).
func field_sweep(request: Dictionary) -> UpgradePlate:
	return FieldSweep.run(request, _records, rig_rules, int(_now()))


## Runs the rig's field sweep on a unit (any player may ask; the host scores it). The plate
## comes back on rig_test_finished for every player. request: see the header.
func run_field_sweep(request: Dictionary) -> void:
	if _net:
		_net.call("request", SWEEP_EVENT, request)
	elif _validate_sweep(0, request) is Dictionary:
		_apply_sweep(request)


## Every plate, newest first; certified ones carry a serial.
func plates() -> Array[UpgradePlate]:
	return _plates.duplicate()


func get_plate(serial: String) -> UpgradePlate:
	for p in _plates:
		if p.serial == serial and serial != "":
			return p
	return null


## The latest plate for a unit, or null.
func last_plate(unit_id: String) -> UpgradePlate:
	for p in _plates:
		if p.unit_id == unit_id:
			return p
	return null


## The rig's screen for a plate: before, rated and tested figures, grade and snags.
func make_sweep_screen(plate: UpgradePlate, glass := false) -> Control:
	return SweepScreen.new(plate, glass)


## The plate itself, to fix on the unit (a reject tag when it failed). Faces +Z.
func make_plate_node(plate: UpgradePlate) -> Node3D:
	return PlateNode.new(plate)


## A rig's TEST button (Ship and Bay, on the host): read the unit off Tools and sweep it.
func _on_rig_test_requested(rig_id: String, unit_id: String) -> void:
	if _is_host():
		run_field_sweep(rig_request(rig_id, unit_id))


## The sweep request for the unit on a rig, from Tools' unit_state(rig_id) (or `state`).
func rig_request(rig_id: String, unit_id: String, state: Dictionary = {}) -> Dictionary:
	var trades := Modules.bus("trades")
	if state.is_empty() and trades and trades.has_method("unit_state"):
		state = trades.call("unit_state", rig_id)
	var addons := FieldSweep.addons_from_fitted(state.get("fitted", []), rig_rules)
	return {"unit_id": unit_id, "rig_id": rig_id, "base": rig_rules.base_figures.get(unit_id, {}).duplicate(),
			"addons": addons, "joint_scores": state.get("joints", {}), "open": bool(state.get("open", false))}


func _validate_sweep(_sender: int, p: Dictionary) -> Variant:
	if not Flags.is_on(RIG_TESTS):
		return "Rig tests are switched off"
	if str(p.get("unit_id", "")) == "" or not p.get("base", null) is Dictionary:
		return "No unit on the rig"
	return p


func _apply_sweep(p: Dictionary) -> void:
	if not _is_host():
		return
	var plate := field_sweep(p)
	if plate.passed:
		_serials += 1
		plate.serial = "%s%04d" % [rig_rules.serial_prefix, _serials]
	_host_send(PLATE_EVENT, {"plate": plate.to_dict(), "serials": _serials})


func _apply_plate(p: Dictionary) -> void:
	var plate := UpgradePlate.from_dict(p.get("plate", {}))
	_serials = maxi(_serials, int(p.get("serials", 0)))
	_plates.push_front(plate)
	if plate.passed:
		_notice("%s certified: grade %s" % [FieldSweep.part_words(plate.unit_id).capitalize(), plate.grade],
				"Tier %d  ·  plate %s" % [plate.tier, plate.serial], NOTICE_S)
	else:
		_notice("Field sweep failed", str(plate.snags[0].get("text", "")) if not plate.snags.is_empty() else "", NOTICE_S)
	rig_test_finished.emit(plate)
	var rigs := Modules.bus("ship_bay")
	if plate.rig_id != "" and _is_host() and rigs and rigs.has_method("rig_show_test"):
		rigs.call("rig_show_test", plate.rig_id, FieldSweep.rig_result(plate))


# Surveys

## Survey reports, newest first.
func reports() -> Array[SurveyReport]:
	return _reports.duplicate()


func get_report(id: String) -> SurveyReport:
	for r in _reports:
		if r.id == id:
			return r
	return null


## The visit under way: {id, kind, job_id, joints, duration, crew}, or {} with none.
func current_survey() -> Dictionary:
	return _survey.duplicate()


func survey_running() -> bool:
	return not _survey.is_empty()


## Seconds until the surveyors on site leave (host only; 0 elsewhere).
func survey_time_left() -> float:
	return maxf(_survey_left, 0.0) if survey_running() else 0.0


## The active job's records, oldest first.
func job_records(job_id: String) -> Array[JointRecord]:
	var out: Array[JointRecord] = []
	for r: JointRecord in _records.values():
		if r.job_id == job_id:
			out.append(r)
	out.sort_custom(func(a: JointRecord, b: JointRecord) -> bool: return a.time < b.time)
	return out


## Why a survey of this kind can't be called now, or "" when it can.
func why_not(kind: StringName) -> String:
	if not kind in SurveyReport.KINDS:
		return "Unknown kind of survey"
	if survey_running():
		return "The surveyors are already on site"
	var job := _active_job()
	if job == null:
		return "No active job to survey"
	var state := str(job.get("state"))
	if kind == SurveyReport.FINAL:
		return "" if state in [ContractJob.IN_PROGRESS, ContractJob.INSPECTION] else "The job isn't being worked on yet"
	if state != ContractJob.IN_PROGRESS:
		return "Nothing to survey until work on the job starts"
	if not job_records(str(job.get("job_id"))).any(func(r: JointRecord) -> bool: return r.survey_id == ""):
		return "Nothing new since the last survey"
	return ""


## Calls the surveyors in (CALLED), or marks the active job complete for its final survey
## (FINAL). Any player may ask; the host decides. Refusals come back through Multiplayer's
## request_rejected, with why_not()'s reason.
func request_survey(kind: StringName = SurveyReport.CALLED) -> void:
	if _net:
		_net.call("request", CALL_EVENT, {"kind": String(kind)})
	elif why_not(kind) == "":
		_apply_call({"kind": String(kind)})


## Sends the surveyors on site home now with their report (host only): tests, the dev
## console, and a skipped clock.
func finish_survey_now() -> void:
	if survey_running() and _is_host():
		_finish()


func _validate_call(_sender: int, p: Dictionary) -> Variant:
	var reason := why_not(StringName(p.get("kind", "")))
	return p if reason == "" else reason


func _apply_call(p: Dictionary) -> void:
	if not _is_host():
		return
	var kind := StringName(p.get("kind", ""))
	var job := _active_job()
	if kind == SurveyReport.FINAL and job and str(job.get("state")) == ContractJob.IN_PROGRESS:
		# Marking the job complete: Contracts moves it to inspection, which brings the final
		# survey (_on_job_state_changed), however the job got there.
		_contracts.call("advance", str(job.get("job_id")), ContractJob.INSPECTION)
	elif why_not(kind) == "":
		_begin(kind)


func _begin(kind: StringName) -> void:
	var job := _active_job()
	if job == null:
		return
	var job_id := str(job.get("job_id"))
	var joints := SurveyDesk.pick(job_records(job_id), kind, survey_rules, _rng)
	_count += 1
	var crew := survey_rules.final_crew if kind == SurveyReport.FINAL else survey_rules.crew
	_host_send(START_EVENT, {"id": "S-%03d" % _count, "kind": String(kind), "job_id": job_id,
			"joints": Array(joints), "duration": SurveyDesk.duration(joints.size(), kind, survey_rules),
			"crew": crew, "count": _count})


func _apply_start(p: Dictionary) -> void:
	_survey = p.duplicate(true)
	_count = maxi(_count, int(p.get("count", 0)))
	_survey_left = float(p.get("duration", 0.0))
	var kind := StringName(p.get("kind", ""))
	var n: int = p.get("joints", []).size()
	_notice("%s on site" % SurveyReport.FIRM, "%s of %d joint%s. They'll leave a report when they're done." % [
			_kind_words(kind), n, "" if n == 1 else "s"], 0.0)
	survey_started.emit(kind, str(p.get("job_id", "")), p.get("joints", []))


func _finish() -> void:
	var p := _survey
	var job_id := str(p.get("job_id", ""))
	var scanned: Array[JointRecord] = []
	for id in p.get("joints", []):
		var r: JointRecord = _records.get(StringName(id))
		if r:
			scanned.append(r)
	var rep := SurveyDesk.write(str(p.get("id", "")), StringName(p.get("kind", "")), job_id, scanned,
			job_records(job_id).size(), int(_now()))
	_host_send(REPORT_EVENT, {"report": rep.to_dict()})


func _apply_report(p: Dictionary) -> void:
	var rep := SurveyReport.from_dict(p.get("report", {}))
	for line in rep.lines:
		var r: JointRecord = _records.get(StringName(line.get("joint_id", "")))
		if r:
			r.survey_id = rep.id
			r.inspected = true
	_reports.push_front(rep)
	if _reports.size() > survey_rules.keep_reports:
		_reports.resize(survey_rules.keep_reports)
	_survey = {}
	_survey_left = 0.0
	_notice("Survey report in: grade %s" % rep.grade, rep.summary() + "\nThe full report is on the Surveys channel.", NOTICE_S)
	survey_finished.emit(rep)
	if not _is_host():
		return
	_random_left = _next_random()
	if rep.kind == SurveyReport.FINAL and _contracts:
		_contracts.call("record_test", rep.job_id, "Independent final survey", rep.accepted, rep.average, "score")
		if rep.accepted:
			_contracts.call("sign_off", rep.job_id, "surveyor", SurveyReport.FIRM, 0)
			_contracts.call("advance", rep.job_id, ContractJob.HANDED_OVER)
		else:
			_contracts.call("advance", rep.job_id, ContractJob.IN_PROGRESS)
	elif _final_pending:
		_final_pending = false
		_begin(SurveyReport.FINAL)


func _on_job_state_changed(job_id: String, _from: String, to: String) -> void:
	if to != ContractJob.INSPECTION or not _is_host():
		return
	var job := _active_job()
	if job == null or str(job.get("job_id")) != job_id:
		return
	if survey_running():
		_final_pending = true
	else:
		_begin(SurveyReport.FINAL)


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			HudSlots.clear_info(NOTICE)
	if not _is_host() or not Flags.is_on(SURVEYS):
		return
	if survey_running():
		_survey_left -= delta
		if _survey_left <= 0.0:
			_finish()
	elif is_instance_valid(_yard) and _yard.is_inside_tree():
		# Spot surveys only turn up while the yard is open.
		_random_left -= delta
		if _random_left <= 0.0:
			_random_left = _next_random()
			if why_not(SurveyReport.RANDOM) == "":
				_begin(SurveyReport.RANDOM)


func _on_shipyard_ready(yard: Node3D) -> void:
	_yard = yard
	var crew := SurveyCrew.new(self)
	crew.name = "QualitySurveyCrew"
	yard.add_child(crew)


func _shot_crew(scene: Node) -> void:
	var crew := scene.find_child("QualitySurveyCrew", true, false)
	if crew:
		crew.call("stage_shot")


func _shot_report(_scene: Node) -> void:
	_reports = SurveyDemo.reports()
	HudSlots.open_holo(SURVEYS_CHANNEL)


func _host_send(event_name: String, payload: Dictionary) -> void:
	if _net:
		_net.call("host_emit", event_name, payload)
	elif event_name == START_EVENT:
		_apply_start(payload)
	elif event_name == PLATE_EVENT:
		_apply_plate(payload)
	else:
		_apply_report(payload)


func _notice(title: String, text: String, seconds: float) -> void:
	HudSlots.set_info(NOTICE, title, text, 5)
	_notice_left = seconds


func _active_job() -> Object:
	return _contracts.call("get_active_job") if _contracts and _contracts.has_method("get_active_job") else null


func _is_host() -> bool:
	return _net == null or bool(_net.call("is_host"))


func _now() -> float:
	return float(_net.call("server_time")) if _net else Time.get_unix_time_from_system()


func _next_random() -> float:
	return _rng.randf_range(survey_rules.random_min_s, survey_rules.random_max_s)


static func _kind_words(kind: StringName) -> String:
	var r := SurveyReport.new()
	r.kind = kind
	return r.kind_name()


# Multiplayer snapshot: a joining player gets the reports and any visit under way.

func get_net_snapshot() -> Dictionary:
	return {"reports": _report_rows(), "survey": _survey, "count": _count, "plates": _plate_rows(), "serials": _serials}


func apply_net_snapshot(data: Dictionary) -> void:
	_load_reports(data)
	_load_plates(data)
	_survey = data.get("survey", {})


# Saves provider.

func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	var rows: Array = []
	for r: JointRecord in _records.values():
		rows.append(r.to_dict())
	return {"records": rows, "reports": _report_rows(), "count": _count, "plates": _plate_rows(), "serials": _serials}


## Version 1 saves have no reports; their records load with no job and unsurveyed.
func load_data(data: Dictionary, _from_version: int) -> void:
	_records = {}
	for row in data.get("records", []):
		var r := JointRecord.from_dict(row)
		_records[r.joint_id] = r
	_load_reports(data)
	_load_plates(data)
	_survey = {}
	_final_pending = false


func _report_rows() -> Array:
	var rows: Array = []
	for r in _reports:
		rows.append(r.to_dict())
	return rows


func _plate_rows() -> Array:
	var rows: Array = []
	for p in _plates:
		rows.append(p.to_dict())
	return rows


func _load_plates(data: Dictionary) -> void:
	_plates = []
	for row in data.get("plates", []):
		_plates.append(UpgradePlate.from_dict(row))
	_serials = int(data.get("serials", 0))


func _load_reports(data: Dictionary) -> void:
	_reports = []
	for row in data.get("reports", []):
		_reports.append(SurveyReport.from_dict(row))
	_count = int(data.get("count", _reports.size()))


static func _field(o: Object, key: String, fallback: Variant) -> Variant:
	var v: Variant = o.get(key)
	return fallback if v == null else v
