class_name QualityGrader
extends RefCounted
## Turns a JointRecord's raw measurements into a score, grade, breakdown and faults.
## One grade_<trade>() per trade; trades without rules stay UNGRADED.

const DATA := "res://modules/quality/internal/data/"

var bolting: BoltingRules
var riveting: RivetingRules
var welding: WeldingRules
var wiring: WiringRules


## Each rule set loads from internal/data/ unless a test passes its own.
func _init(bolting_rules: BoltingRules = null, riveting_rules: RivetingRules = null,
		welding_rules: WeldingRules = null, wiring_rules: WiringRules = null) -> void:
	bolting = bolting_rules if bolting_rules else load(DATA + "bolting_rules.tres") as BoltingRules
	riveting = riveting_rules if riveting_rules else load(DATA + "riveting_rules.tres") as RivetingRules
	welding = welding_rules if welding_rules else load(DATA + "welding_rules.tres") as WeldingRules
	wiring = wiring_rules if wiring_rules else load(DATA + "wiring_rules.tres") as WiringRules


## `modifiers` are the worker's Progression effects, e.g. {"torque_tolerance": 0.05}.
func grade(r: JointRecord, modifiers: Dictionary = {}) -> void:
	r.breakdown = {}
	r.faults = []
	match r.trade:
		&"BOLT":
			_grade_bolting(r, modifiers)
		&"RIVET":
			_grade_riveting(r)
		&"WELD":
			_grade_welding(r)
		&"WIRE":
			_grade_wiring(r)
		_:
			r.score = -1
			r.grade = JointRecord.UNGRADED


## Bolting keys (Trades spec 4.3): torque_nm, torque_target_nm, sequence_ok, cross_threaded,
## washer, fastener_ids; optional fastener_spec_id and needs_washer copied from the spec,
## and stripped_thread from the powered wrench.
## torque_tolerance (a fraction of target) widens both torque bands by that many percent;
## the over-torque fail line never moves, since a yielded bolt fails whoever fitted it.
func _grade_bolting(r: JointRecord, modifiers: Dictionary) -> void:
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
	var bonus_pct := maxf(float(modifiers.get("torque_tolerance", 0.0)), 0.0) * 100.0
	var full_pct := rules.torque_full_pct + bonus_pct
	var zero_pct := rules.torque_zero_pct + bonus_pct

	if holes == 0 or target <= 0.0:
		r.faults.append(_fault("no_data", -1, "No torque readings"))
		_finish(r, 0.0, true, rules.pass_score, rules.marginal_score)
		return

	var torque_marks := 0.0
	for i in holes:
		var t := float(torques[i])
		var off_pct := (t - target) / target * 100.0
		var dev := absf(off_pct)
		torque_marks += 1.0 - clampf((dev - full_pct) / (zero_pct - full_pct), 0.0, 1.0)
		if off_pct >= rules.over_torque_fail_pct:
			auto_fail = true
			r.faults.append(_fault("over_torque", i, "Hole %d over-torqued by %d%%: bolt yielded"
					% [i + 1, roundi(off_pct)]))
		elif dev > full_pct:
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

	# A stripped thread (powered wrench held past its clutch) also sets cross_threaded;
	# name it as what it is.
	var stripped: Array = m.get("stripped_thread", [])
	var clean := 0
	for i in holes:
		if bool(_at(stripped, i, false)):
			auto_fail = true
			r.faults.append(_fault("stripped_thread", i, "Hole %d thread stripped" % (i + 1)))
		elif i < cross.size() and bool(cross[i]):
			auto_fail = true
			r.faults.append(_fault("cross_threaded", i, "Hole %d cross-threaded" % (i + 1)))
		else:
			clean += 1
	r.breakdown["threads"] = rules.weight_threads * clean / holes

	_finish(r, _total(r), auto_fail, rules.pass_score, rules.marginal_score)


## Riveting keys: head_height_mm, head_height_target_mm, head_dia_mm, head_dia_target_mm,
## hole_fit_mm, deburred, seated, cracked_head (arrays have one entry per rivet).
func _grade_riveting(r: JointRecord) -> void:
	var m := r.measurements
	var rules := riveting
	var heights: Array = m.get("head_height_mm", [])
	var n := heights.size()
	if n == 0:
		r.faults.append(_fault("no_data", -1, "No rivet readings"))
		_finish(r, 0.0, true, rules.pass_score, rules.marginal_score)
		return
	var auto_fail := false
	var dias: Array = m.get("head_dia_mm", [])
	var fits: Array = m.get("hole_fit_mm", [])
	var deburred: Array = m.get("deburred", [])
	var seated: Array = m.get("seated", [])
	var cracked: Array = m.get("cracked_head", [])
	var h_target := float(m.get("head_height_target_mm", 0.0))
	var d_target := float(m.get("head_dia_target_mm", 0.0))
	var head := 0.0
	var hole := 0.0
	var clean := 0
	var tight := 0
	for i in n:
		var hm := _pct_marks(float(heights[i]), h_target, rules.head_full_pct, rules.head_zero_pct)
		var dm := _pct_marks(float(_at(dias, i, 0.0)), d_target, rules.head_full_pct, rules.head_zero_pct)
		head += (hm + dm) / 2.0
		if hm < 1.0 or dm < 1.0:
			r.faults.append(_fault("head_shape", i, "Rivet %d head badly formed" % (i + 1)))
		var fit := float(_at(fits, i, INF))
		hole += _band(fit, rules.hole_fit_full_mm, rules.hole_fit_zero_mm)
		if fit > rules.hole_fit_full_mm:
			r.faults.append(_fault("loose_hole", i, "Rivet %d hole oversize" % (i + 1)))
		if bool(_at(deburred, i, false)):
			clean += 1
		else:
			r.faults.append(_fault("burr", i, "Rivet %d hole not deburred" % (i + 1)))
		if bool(_at(seated, i, false)):
			tight += 1
		else:
			r.faults.append(_fault("gap", i, "Rivet %d sheets not drawn tight" % (i + 1)))
		if bool(_at(cracked, i, false)):
			auto_fail = true
			r.faults.append(_fault("cracked_head", i, "Rivet %d head cracked" % (i + 1)))
	r.breakdown["head"] = rules.weight_head * head / n
	r.breakdown["hole"] = rules.weight_hole * hole / n
	r.breakdown["deburr"] = rules.weight_deburr * clean / n
	r.breakdown["seated"] = rules.weight_seated * tight / n
	_finish(r, _total(r), auto_fail, rules.pass_score, rules.marginal_score)


## Welding keys: travel_speed_mm_s, torch_angle_deg, arc_length_mm (samples along the seam)
## with their *_target values, coverage, penetration, burn_through.
func _grade_welding(r: JointRecord) -> void:
	var m := r.measurements
	var rules := welding
	var auto_fail := false
	var steady := [
		["speed", "travel_speed_mm_s", "travel_speed_target_mm_s", rules.weight_speed, "Travel speed uneven"],
		["angle", "torch_angle_deg", "torch_angle_target_deg", rules.weight_angle, "Torch angle wandered"],
		["arc", "arc_length_mm", "arc_length_target_mm", rules.weight_arc, "Arc length inconsistent"],
	]
	for s in steady:
		var dev := _mean_dev_pct(m.get(s[1], []), float(m.get(s[2], 0.0)))
		var marks := _band(dev, rules.steady_full_pct, rules.steady_zero_pct)
		r.breakdown[s[0]] = s[3] * marks
		if marks < 1.0:
			r.faults.append(_fault(s[0], -1, "%s (%d%% off)" % [s[4], roundi(minf(dev, 999.0))]))

	var coverage := float(m.get("coverage", 0.0))
	r.breakdown["coverage"] = rules.weight_coverage * _band(rules.coverage_full - coverage,
			0.0, rules.coverage_full - rules.coverage_zero)
	if coverage < rules.coverage_fail:
		auto_fail = true
		r.faults.append(_fault("gap", -1, "Seam only %d%% welded" % roundi(coverage * 100.0)))
	elif coverage < rules.coverage_full:
		r.faults.append(_fault("gap", -1, "Small gaps in the seam"))

	var pen := float(m.get("penetration", 0.0))
	r.breakdown["penetration"] = rules.weight_penetration * _band(1.0 - pen,
			0.0, 1.0 - rules.penetration_zero)
	if pen < rules.penetration_fail:
		auto_fail = true
		r.faults.append(_fault("lack_of_fusion", -1, "Lack of fusion: %d%% penetration" % roundi(pen * 100.0)))
	elif pen < 1.0:
		r.faults.append(_fault("shallow", -1, "Shallow penetration"))

	if bool(m.get("burn_through", false)):
		auto_fail = true
		r.faults.append(_fault("burn_through", -1, "Burned through the plate"))
	_finish(r, _total(r), auto_fail, rules.pass_score, rules.marginal_score)


## Wiring keys: strip_length_mm, strip_length_target_mm, crimp_pull_n, crimp_pull_min_n
## (per termination), continuity_ohm, continuity_max_ohm, insulation_mohm,
## insulation_min_mohm, polarity_ok; diagram wiring adds pins_ok and terminals (pin names).
func _grade_wiring(r: JointRecord) -> void:
	var m := r.measurements
	var rules := wiring
	var auto_fail := false
	var pulls: Array = m.get("crimp_pull_n", [])
	var strips: Array = m.get("strip_length_mm", [])
	var n := pulls.size()
	if n == 0:
		r.faults.append(_fault("no_data", -1, "No termination readings"))
		_finish(r, 0.0, true, rules.pass_score, rules.marginal_score)
		return
	var pull_min := float(m.get("crimp_pull_min_n", 0.0))
	var strip_target := float(m.get("strip_length_target_mm", 0.0))
	var crimp := 0.0
	var strip := 0.0
	for i in n:
		var ratio := float(pulls[i]) / pull_min if pull_min > 0.0 else 0.0
		crimp += _band(1.0 - ratio, 0.0, 1.0 - rules.crimp_zero)
		if ratio < 1.0:
			r.faults.append(_fault("weak_crimp", i, "Crimp %d pulls out at %d%% of minimum"
					% [i + 1, roundi(ratio * 100.0)]))
		var off := absf(float(_at(strips, i, INF)) - strip_target)
		strip += _band(off, rules.strip_full_mm, rules.strip_zero_mm)
		if off > rules.strip_full_mm:
			r.faults.append(_fault("strip_length", i, "Termination %d stripped wrong length" % (i + 1)))
	r.breakdown["crimp"] = rules.weight_crimp * crimp / n
	r.breakdown["strip"] = rules.weight_strip * strip / n

	var ohm := float(m.get("continuity_ohm", -1.0))
	var max_ohm := float(m.get("continuity_max_ohm", 0.0))
	if ohm < 0.0 or is_inf(ohm) or max_ohm <= 0.0:
		auto_fail = true
		r.breakdown["continuity"] = 0.0
		r.faults.append(_fault("open_circuit", -1, "Open circuit"))
	else:
		var over := ohm / max_ohm
		r.breakdown["continuity"] = rules.weight_continuity * _band(over, 1.0, rules.continuity_zero)
		if over > 1.0:
			r.faults.append(_fault("resistance", -1, "Circuit resistance too high"))

	var ins_min := float(m.get("insulation_min_mohm", 0.0))
	var ins := float(m.get("insulation_mohm", 0.0)) / ins_min if ins_min > 0.0 else 0.0
	r.breakdown["insulation"] = rules.weight_insulation * _band(1.0 - ins, 0.0, 1.0 - rules.insulation_zero)
	if ins < rules.insulation_fail:
		auto_fail = true
		r.faults.append(_fault("short", -1, "Insulation breakdown: short to frame"))
	elif ins < 1.0:
		r.faults.append(_fault("insulation", -1, "Insulation resistance low"))

	if bool(m.get("polarity_ok", false)):
		r.breakdown["polarity"] = rules.weight_polarity
	else:
		auto_fail = true
		r.breakdown["polarity"] = 0.0
		r.faults.append(_fault("polarity", -1, "Wired with reversed polarity"))

	# Diagram wiring (ship plugs) names each pin; say which ones are wrong.
	var pins_ok: Array = m.get("pins_ok", [])
	var names: Array = m.get("terminals", [])
	for i in pins_ok.size():
		if not bool(pins_ok[i]):
			r.faults.append(_fault("wrong_pin", i, "Pin %s wired wrong" % str(_at(names, i, i + 1))))
	_finish(r, _total(r), auto_fail, rules.pass_score, rules.marginal_score)


func _finish(r: JointRecord, total: float, auto_fail: bool, pass_score: int, marginal_score: int) -> void:
	r.score = clampi(roundi(total), 0, 100)
	if auto_fail or r.score < marginal_score:
		r.grade = JointRecord.FAIL
	elif r.score < pass_score:
		r.grade = JointRecord.MARGINAL
	else:
		r.grade = JointRecord.PASS


static func _total(r: JointRecord) -> float:
	var total := 0.0
	for k in r.breakdown:
		total += r.breakdown[k]
	return total


## 1.0 at or under `full`, falling linearly to 0.0 at `zero`.
static func _band(value: float, full: float, zero: float) -> float:
	return 1.0 - clampf((value - full) / (zero - full), 0.0, 1.0)


## Marks for a value's percentage distance from target; no target means no marks.
static func _pct_marks(value: float, target: float, full_pct: float, zero_pct: float) -> float:
	if target <= 0.0:
		return 0.0
	return _band(absf(value - target) / target * 100.0, full_pct, zero_pct)


## Average percentage distance of samples from target; INF when there is nothing to judge.
static func _mean_dev_pct(samples: Array, target: float) -> float:
	if samples.is_empty() or target == 0.0:
		return INF
	var sum := 0.0
	for v in samples:
		sum += absf(float(v) - target)
	return sum / samples.size() / absf(target) * 100.0


static func _at(a: Array, i: int, fallback: Variant) -> Variant:
	return a[i] if i < a.size() else fallback


static func _fault(code: String, hole: int, text: String) -> Dictionary:
	return {"code": code, "hole": hole, "text": text}
