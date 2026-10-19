class_name QualityGrader
extends RefCounted
## Turns a JointRecord's raw measurements into a score, grade, breakdown and faults.
## One grade_<trade>() per trade; trades without rules stay UNGRADED.

const BOLTING_RULES := "res://modules/quality/internal/data/bolting_rules.tres"

var bolting: BoltingRules


func _init(bolting_rules: BoltingRules = null) -> void:
	bolting = bolting_rules if bolting_rules else load(BOLTING_RULES) as BoltingRules


func grade(r: JointRecord) -> void:
	r.breakdown = {}
	r.faults = []
	match r.trade:
		&"BOLT":
			_grade_bolting(r)
		_:
			r.score = -1
			r.grade = JointRecord.UNGRADED


## Bolting keys (Trades spec 4.3): torque_nm, torque_target_nm, sequence_ok, cross_threaded,
## washer, fastener_ids; optional fastener_spec_id and needs_washer copied from the spec.
func _grade_bolting(r: JointRecord) -> void:
	var m := r.measurements
	var rules := bolting
	var torques: Array = m.get("torque_nm", [])
	var target := float(m.get("torque_target_nm", 0.0))
	var holes := torques.size()
	var cross: Array = m.get("cross_threaded", [])
	var washers: Array = m.get("washer", [])
	var fasteners: Array = m.get("fastener_ids", [])
	var spec_fastener := StringName(m.get("fastener_spec_id", ""))
	var needs_washer := bool(m.get("needs_washer", true))
	var auto_fail := false

	if holes == 0 or target <= 0.0:
		r.faults.append(_fault("no_data", -1, "No torque readings"))
		_finish(r, 0.0, true, rules)
		return

	var torque_marks := 0.0
	for i in holes:
		var t := float(torques[i])
		var off_pct := (t - target) / target * 100.0
		var dev := absf(off_pct)
		torque_marks += 1.0 - clampf((dev - rules.torque_full_pct)
				/ (rules.torque_zero_pct - rules.torque_full_pct), 0.0, 1.0)
		if off_pct >= rules.over_torque_fail_pct:
			auto_fail = true
			r.faults.append(_fault("over_torque", i, "Hole %d over-torqued by %d%%: bolt yielded"
					% [i + 1, roundi(off_pct)]))
		elif dev > rules.torque_full_pct:
			var word := "over" if off_pct > 0 else "under"
			r.faults.append(_fault(word + "_torque", i, "Hole %d %s target by %d%%"
					% [i + 1, word, roundi(dev)]))
	r.breakdown["torque"] = rules.weight_torque * torque_marks / holes

	var in_order := bool(m.get("sequence_ok", false))
	r.breakdown["sequence"] = rules.weight_sequence if in_order else 0.0
	if not in_order:
		r.faults.append(_fault("sequence", -1, "Tightened out of sequence"))

	var right_parts := 0
	for i in holes:
		var ok := true
		if spec_fastener != &"" and i < fasteners.size() and StringName(fasteners[i]) != spec_fastener:
			ok = false
			r.faults.append(_fault("wrong_fastener", i, "Hole %d has %s, spec is %s"
					% [i + 1, fasteners[i], spec_fastener]))
		if needs_washer and not (i < washers.size() and bool(washers[i])):
			ok = false
			r.faults.append(_fault("no_washer", i, "Hole %d missing its washer" % (i + 1)))
		if ok:
			right_parts += 1
	r.breakdown["fastener"] = rules.weight_fastener * right_parts / holes

	var clean := 0
	for i in holes:
		if i < cross.size() and bool(cross[i]):
			auto_fail = true
			r.faults.append(_fault("cross_threaded", i, "Hole %d cross-threaded" % (i + 1)))
		else:
			clean += 1
	r.breakdown["threads"] = rules.weight_threads * clean / holes

	var total := 0.0
	for k in r.breakdown:
		total += r.breakdown[k]
	_finish(r, total, auto_fail, rules)


func _finish(r: JointRecord, total: float, auto_fail: bool, rules: BoltingRules) -> void:
	r.score = clampi(roundi(total), 0, 100)
	if auto_fail or r.score < rules.marginal_score:
		r.grade = JointRecord.FAIL
	elif r.score < rules.pass_score:
		r.grade = JointRecord.MARGINAL
	else:
		r.grade = JointRecord.PASS


static func _fault(code: String, hole: int, text: String) -> Dictionary:
	return {"code": code, "hole": hole, "text": text}
