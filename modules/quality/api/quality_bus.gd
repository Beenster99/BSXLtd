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

## A joint was graded (also fired again when a reworked joint is regraded).
signal joint_graded(record: JointRecord)
## A joint's record was dropped because Trades took it apart for rework.
signal record_dropped(joint_id: StringName)
## Surveyors arrived to scan these joints (ids as Strings). kind is a SurveyReport kind.
signal survey_started(kind: StringName, job_id: String, joint_ids: Array)
## The surveyors left and their report is in.
signal survey_finished(report: SurveyReport)

const SCORES := "quality.scores"
const SURVEYS := "quality.surveys"
const SCORE_CARD := "quality_score_card"
const SURVEYS_CHANNEL := "quality.surveys"
const SAVE_VERSION := 2

const CALL_EVENT := "quality.survey_call"
const START_EVENT := "quality.survey_start"
const REPORT_EVENT := "quality.survey_report"
const NOTICE := "quality.survey"
const NOTICE_S := 14.0

const SurveyScreen := preload("res://modules/quality/internal/survey_screen.gd")
const SurveyCrew := preload("res://modules/quality/internal/survey_crew.gd")
const SurveyDemo := preload("res://modules/quality/internal/survey_demo.gd")

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
		for e in [CALL_EVENT, START_EVENT, REPORT_EVENT]:
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
	return {"reports": _report_rows(), "survey": _survey, "count": _count}


func apply_net_snapshot(data: Dictionary) -> void:
	_load_reports(data)
	_survey = data.get("survey", {})


# Saves provider.

func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	var rows: Array = []
	for r: JointRecord in _records.values():
		rows.append(r.to_dict())
	return {"records": rows, "reports": _report_rows(), "count": _count}


## Version 1 saves have no reports; their records load with no job and unsurveyed.
func load_data(data: Dictionary, _from_version: int) -> void:
	_records = {}
	for row in data.get("records", []):
		var r := JointRecord.from_dict(row)
		_records[r.joint_id] = r
	_load_reports(data)
	_survey = {}
	_final_pending = false


func _report_rows() -> Array:
	var rows: Array = []
	for r in _reports:
		rows.append(r.to_dict())
	return rows


func _load_reports(data: Dictionary) -> void:
	_reports = []
	for row in data.get("reports", []):
		_reports.append(SurveyReport.from_dict(row))
	_count = int(data.get("count", _reports.size()))


static func _field(o: Object, key: String, fallback: Variant) -> Variant:
	var v: Variant = o.get(key)
	return fallback if v == null else v
