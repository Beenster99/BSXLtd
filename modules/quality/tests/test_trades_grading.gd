extends ModuleTest
## Quality: riveting, welding and wiring rules (release 0.2).
##   tools/run_tests.sh quality

var g := QualityGrader.new()


func run_tests() -> void:
	check(g.riveting != null and g.welding != null and g.wiring != null, "0.2 rules load from data")
	_riveting()
	_welding()
	_wiring()


func _riveting() -> void:
	var good := _grade(&"RIVET", _rivets(4, {}))
	check(good.score == 100 and good.grade == JointRecord.PASS and good.faults.is_empty(),
			"neat rivets score 100: %d %s %s" % [good.score, good.grade, good.faults])

	# Two heads 20% short: (0.5 + 1) / 2 = 0.75 each -> head 50 * 3.5 / 4 = 43.75.
	var squat := _grade(&"RIVET", _rivets(4, {"head_height_mm": [2.4, 2.4, 3.0, 3.0]}))
	check(squat.score == 94 and squat.grade == JointRecord.PASS, "short heads cost marks: %d" % squat.score)
	check(_codes(squat).count("head_shape") == 2, "each bad head is a fault")

	var sloppy := _grade(&"RIVET", _rivets(4, {"deburred": [false, false, false, false],
			"seated": [false, false, true, true], "hole_fit_mm": [0.4, 0.4, 0.4, 0.4]}))
	# 50 + 0 + 0 + 7.5 = 57.5 -> 58
	check(sloppy.score == 58 and sloppy.grade == JointRecord.MARGINAL,
			"skipping prep is MARGINAL: %d %s" % [sloppy.score, sloppy.grade])

	var cracked := _grade(&"RIVET", _rivets(4, {"cracked_head": [false, false, false, true]}))
	check(cracked.grade == JointRecord.FAIL and cracked.faults[0].hole == 3, "a cracked head fails")

	var none := _grade(&"RIVET", {})
	check(none.grade == JointRecord.FAIL and none.score == 0, "no rivet readings fails")


func _welding() -> void:
	var good := _grade(&"WELD", _weld({}))
	check(good.score == 100 and good.grade == JointRecord.PASS and good.faults.is_empty(),
			"a steady full weld scores 100: %d %s %s" % [good.score, good.grade, good.faults])

	# Speed samples average 25% off target: (25 - 10) / 30 = 0.5 marks -> 10 of 20.
	var rushed := _grade(&"WELD", _weld({"travel_speed_mm_s": [5.0, 5.0, 3.0, 3.0]}))
	check(rushed.score == 90 and rushed.grade == JointRecord.PASS and _codes(rushed).has("speed"),
			"uneven travel speed costs marks: %d %s" % [rushed.score, _codes(rushed)])

	var gappy := _grade(&"WELD", _weld({"coverage": 0.85}))
	check(gappy.grade == JointRecord.FAIL and _codes(gappy).has("gap"), "a seam 85% welded fails")

	var shallow := _grade(&"WELD", _weld({"penetration": 0.8}))
	# Penetration (1 - 0.8) / 0.4 = 0.5 marks -> 12.5 of 25.
	check(shallow.score == 88 and shallow.grade == JointRecord.PASS and _codes(shallow).has("shallow"),
			"shallow penetration costs marks: %d" % shallow.score)
	check(_grade(&"WELD", _weld({"penetration": 0.6})).grade == JointRecord.FAIL, "lack of fusion fails")
	check(_grade(&"WELD", _weld({"burn_through": true})).grade == JointRecord.FAIL, "burn-through fails")

	var none := _grade(&"WELD", {})
	check(none.grade == JointRecord.FAIL and none.score == 0, "no weld readings fails: %d" % none.score)


func _wiring() -> void:
	var good := _grade(&"WIRE", _wire(2, {}))
	check(good.score == 100 and good.grade == JointRecord.PASS and good.faults.is_empty(),
			"a clean circuit scores 100: %d %s %s" % [good.score, good.grade, good.faults])

	# One crimp at 75% of minimum: 0.5 marks -> crimp 35 * 1.5 / 2 = 26.25; one strip 2 mm off: 0.5.
	var loose := _grade(&"WIRE", _wire(2, {"crimp_pull_n": [120.0, 90.0], "strip_length_mm": [6.0, 8.0]}))
	check(loose.score == 88 and loose.grade == JointRecord.PASS
			and _codes(loose).has("weak_crimp") and _codes(loose).has("strip_length"),
			"a weak crimp and long strip cost marks: %d %s" % [loose.score, _codes(loose)])

	check(_grade(&"WIRE", _wire(2, {"continuity_ohm": INF})).grade == JointRecord.FAIL, "open circuit fails")
	check(_grade(&"WIRE", _wire(2, {"continuity_ohm": -1.0})).grade == JointRecord.FAIL, "-1 means open")
	check(_grade(&"WIRE", _wire(2, {"polarity_ok": false})).grade == JointRecord.FAIL, "reversed polarity fails")
	check(_grade(&"WIRE", _wire(2, {"insulation_mohm": 10.0})).grade == JointRecord.FAIL, "a short fails")

	var warm := _grade(&"WIRE", _wire(2, {"continuity_ohm": 0.75}))
	# Twice-ish the 0.5 ohm maximum: (1.5 - 1) / 1 = 0.5 marks -> 12.5 of 25.
	check(warm.score == 88 and _codes(warm).has("resistance"), "high resistance costs marks: %d" % warm.score)


func _grade(trade: StringName, m: Dictionary) -> JointRecord:
	var r := JointRecord.new()
	r.joint_id = &"test"
	r.trade = trade
	r.measurements = m
	g.grade(r)
	return r


func _rivets(n: int, extra: Dictionary) -> Dictionary:
	var m := {
		"head_height_mm": _fill(n, 3.0), "head_height_target_mm": 3.0,
		"head_dia_mm": _fill(n, 6.0), "head_dia_target_mm": 6.0,
		"hole_fit_mm": _fill(n, 0.1), "deburred": _fill(n, true), "seated": _fill(n, true),
		"cracked_head": _fill(n, false),
	}
	m.merge(extra, true)
	return m


func _weld(extra: Dictionary) -> Dictionary:
	var m := {
		"travel_speed_mm_s": [4.0, 4.1, 3.9, 4.0], "travel_speed_target_mm_s": 4.0,
		"torch_angle_deg": [15.0, 16.0, 14.0, 15.0], "torch_angle_target_deg": 15.0,
		"arc_length_mm": [3.0, 3.1, 2.9, 3.0], "arc_length_target_mm": 3.0,
		"coverage": 1.0, "penetration": 1.05, "burn_through": false,
	}
	m.merge(extra, true)
	return m


func _wire(n: int, extra: Dictionary) -> Dictionary:
	var m := {
		"strip_length_mm": _fill(n, 6.0), "strip_length_target_mm": 6.0,
		"crimp_pull_n": _fill(n, 130.0), "crimp_pull_min_n": 120.0,
		"continuity_ohm": 0.2, "continuity_max_ohm": 0.5,
		"insulation_mohm": 200.0, "insulation_min_mohm": 100.0, "polarity_ok": true,
	}
	m.merge(extra, true)
	return m


func _fill(n: int, v: Variant) -> Array:
	var a := []
	a.resize(n)
	a.fill(v)
	return a


func _codes(r: JointRecord) -> Array:
	return r.faults.map(func(f): return f.code)
