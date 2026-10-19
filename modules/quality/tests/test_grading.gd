extends ModuleTest
## Quality: bolting rules turn Trades measurements into scores, grades and faults.
##   tools/run_tests.sh quality


## Stands in for Trades' JointResult until Trades ships it.
class FakeResult extends Resource:
	var joint_id: StringName = &"bracket_a"
	var trade: StringName = &"BOLT"
	var component_id: StringName
	var mount_id: StringName
	var measurements: Dictionary = {}
	var peer_id := 1
	var time := 1000


func run_tests() -> void:
	var g := QualityGrader.new()
	check(g.bolting != null, "bolting rules load from data")

	var good := _bolt([25.0, 25.5, 24.6, 25.0])
	g.grade(good)
	check(good.score == 100 and good.grade == JointRecord.PASS,
			"careful bolting scores 100 and passes: %d %s" % [good.score, good.grade])
	check(good.faults.is_empty(), "no faults on a good joint")

	var sloppy := _bolt([20.0, 30.0, 25.0, 25.0], {"sequence_ok": false})
	g.grade(sloppy)
	# Holes 1 and 2 are 20% off: 0.25 marks each -> torque 60 * 2.5 / 4 = 37.5; no sequence.
	check(sloppy.score == 63 and sloppy.grade == JointRecord.MARGINAL,
			"20%% off on two holes and out of order is MARGINAL 63: %d %s" % [sloppy.score, sloppy.grade])
	check(_codes(sloppy).has("sequence") and _codes(sloppy).has("under_torque")
			and _codes(sloppy).has("over_torque"), "sloppy faults listed: %s" % [_codes(sloppy)])

	var crossed := _bolt([25.0, 25.0, 25.0, 25.0], {"cross_threaded": [false, true, false, false]})
	g.grade(crossed)
	check(crossed.grade == JointRecord.FAIL and crossed.score == 98,
			"a cross-threaded bolt fails a high-scoring joint: %d %s" % [crossed.score, crossed.grade])
	check(crossed.faults[0].hole == 1, "fault names the hole")

	var yielded := _bolt([25.0, 36.0, 25.0, 25.0])
	g.grade(yielded)
	check(yielded.grade == JointRecord.FAIL, "44% over target fails the joint")

	var parts := _bolt([25.0, 25.0, 25.0, 25.0], {"washer": [true, false, true, true],
			"fastener_ids": [&"bolt_m8x25_8.8", &"bolt_m8x25_8.8", &"bolt_m6x20_8.8", &"bolt_m8x25_8.8"],
			"fastener_spec_id": &"bolt_m8x25_8.8"})
	g.grade(parts)
	check(is_equal_approx(parts.breakdown.fastener, 7.5) and parts.grade == JointRecord.PASS,
			"wrong bolt and missing washer cost fastener marks: %s" % [parts.breakdown])

	var empty := _bolt([])
	g.grade(empty)
	check(empty.grade == JointRecord.FAIL and empty.score == 0, "no readings fails")

	var weld := JointRecord.new()  # lifting and fitting has no rules until 0.3
	weld.trade = &"FIT"
	g.grade(weld)
	check(weld.grade == JointRecord.UNGRADED and weld.score == -1, "trades without rules stay ungraded")

	var strict := BoltingRules.new()
	strict.pass_score = 99
	var g2 := QualityGrader.new(strict)
	var r := _bolt([25.0, 27.5, 25.0, 25.0])
	g2.grade(r)
	check(r.grade == JointRecord.MARGINAL, "pass mark comes from the rules data")

	var skilled := _bolt([25.0, 25.0, 23.25, 25.0])
	g.grade(skilled, {"torque_tolerance": 0.05, "bolt_speed": 0.1})
	var unskilled := _bolt([25.0, 25.0, 23.25, 25.0])
	g.grade(unskilled)
	check(skilled.score == 100 and skilled.faults.is_empty() and unskilled.score < 100,
			"torque_tolerance widens the full-marks band: %d vs %d" % [skilled.score, unskilled.score])
	var yielded_skilled := _bolt([25.0, 36.0, 25.0, 25.0])
	g.grade(yielded_skilled, {"torque_tolerance": 0.5})
	check(yielded_skilled.grade == JointRecord.FAIL, "tolerance never moves the over-torque fail line")

	await _test_bus()


func _test_bus() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "trades": true,
			"quality": true, "quality.scores": true})
	Modules.load_all()
	var bus := Modules.bus("quality") as QualityBus
	check(bus != null, "quality bus loads with its chain on")
	if bus == null:
		Flags.use(saved)
		return
	check(HudSlots.panels_in(HudSlots.NOTICES).any(func(p): return p.id == QualityBus.SCORE_CARD),
			"score card registered when quality.scores is on")

	var hud := HudLayer.new()
	add_child(hud)
	await frames(2)
	var heard: Array = []
	bus.joint_graded.connect(func(rec): heard.append(rec))

	var res := FakeResult.new()
	res.measurements = _bolting_measurements([25.0, 25.0, 25.0, 25.0], {})
	var rec := bus.submit(res)
	check(heard.size() == 1 and heard[0] == rec, "joint_graded fires")
	check(bus.get_record(&"bracket_a").grade == JointRecord.PASS, "record stored by joint id")
	await frames(1)
	var card := hud.find_child("QualityScoreCard", true, false) as Control
	check(card != null and card.visible, "score card pops up on a graded joint")
	var head := card.find_child("Headline", true, false) as Label if card else null
	check(head != null and head.text.begins_with("100/100"), "card shows the score")

	var res2 := FakeResult.new()
	res2.joint_id = &"bracket_b"
	res2.measurements = _bolting_measurements([25.0, 25.0, 25.0, 25.0], {"cross_threaded": [true, false, false, false]})
	bus.submit(res2)
	var s := bus.summary()
	check(s.joints == 2 and s.passed == 1 and s.failed == 1, "summary counts: %s" % [s])
	check(bus.records({"grade": JointRecord.FAIL}).size() == 1, "records filter by grade")

	bus.set_player_modifiers("7", {"torque_tolerance": 0.05})
	var res3 := FakeResult.new()
	res3.joint_id = &"bracket_c"
	res3.peer_id = 7
	res3.measurements = _bolting_measurements([25.0, 25.0, 23.25, 25.0], {})
	check(bus.submit(res3).score == 100, "player modifiers from Progression apply by peer id")
	res3.peer_id = 1
	check(bus.submit(res3).score < 100, "modifiers are per player")
	bus.drop(&"bracket_c")

	var data := bus.save_data()
	bus.clear()
	bus.load_data(JSON.parse_string(JSON.stringify(data)), QualityBus.SAVE_VERSION)
	check(bus.records().size() == 2 and bus.get_record(&"bracket_b").grade == JointRecord.FAIL,
			"records survive a save round trip")

	bus.drop(&"bracket_b")
	check(bus.get_record(&"bracket_b") == null, "rework drops the record")
	bus.drop(&"bracket_a")
	await frames(1)
	check(card != null and not card.visible, "card hides when its joint is taken apart")

	hud.queue_free()
	Flags.use(saved)
	Modules.load_all()
	await frames(1)


func _bolt(torques: Array, extra: Dictionary = {}) -> JointRecord:
	var r := JointRecord.new()
	r.joint_id = &"bracket_a"
	r.trade = &"BOLT"
	r.measurements = _bolting_measurements(torques, extra)
	return r


func _bolting_measurements(torques: Array, extra: Dictionary) -> Dictionary:
	var n := torques.size()
	var m := {
		"torque_nm": torques, "torque_target_nm": 25.0, "sequence": [], "sequence_ok": true,
		"cross_threaded": _fill(n, false), "washer": _fill(n, true), "fastener_ids": [],
		"misalign_mm": 0.5,
	}
	m.merge(extra, true)
	return m


func _fill(n: int, v: bool) -> Array:
	var a := []
	a.resize(n)
	a.fill(v)
	return a


func _codes(r: JointRecord) -> Array:
	return r.faults.map(func(f): return f.code)
