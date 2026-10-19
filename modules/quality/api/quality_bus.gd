class_name QualityBus
extends Node
## Quality and Inspection module bus (Modules.bus("quality")). Joint quality records, inspection tools, the snag list, commissioning tests and the as-built record.
## Other modules use this module only through this folder: signals here, and resource
## classes placed next to it. Everything else lives in internal/.
##
## Trades reports what was built (raw measurements); Quality decides whether it is good
## enough, so pass marks are tuned here without touching Trades. Release 0.1 has grading
## (quality.scores) for bolting; inspection, snags, tests and handover follow in 0.5.

## A joint was graded (also fired again when a reworked joint is regraded).
signal joint_graded(record: JointRecord)
## A joint's record was dropped because Trades took it apart for rework.
signal record_dropped(joint_id: StringName)

const SCORES := "quality.scores"
const SCORE_CARD := "quality_score_card"
const SAVE_VERSION := 1

var _records: Dictionary = {}
var _grader: QualityGrader


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
	if Flags.is_on(SCORES):
		HudSlots.register_panel(SCORE_CARD, "res://modules/quality/internal/score_card.tscn",
				HudSlots.NOTICES)


func unregister_module() -> void:
	HudSlots.unregister_panel(SCORE_CARD)
	Saves.unregister_section("quality")


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
	_grader.grade(r)
	_records[r.joint_id] = r
	joint_graded.emit(r)
	return r


## Forgets a joint (Trades took it apart); the next attempt is graded fresh.
func drop(joint_id: StringName) -> void:
	if _records.erase(joint_id):
		record_dropped.emit(joint_id)


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


# Saves provider.

func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	var rows: Array = []
	for r: JointRecord in _records.values():
		rows.append(r.to_dict())
	return {"records": rows}


func load_data(data: Dictionary, _from_version: int) -> void:
	_records = {}
	for row in data.get("records", []):
		var r := JointRecord.from_dict(row)
		_records[r.joint_id] = r


static func _field(o: Object, key: String, fallback: Variant) -> Variant:
	var v: Variant = o.get(key)
	return fallback if v == null else v
