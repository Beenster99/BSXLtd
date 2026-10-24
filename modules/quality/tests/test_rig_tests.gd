extends ModuleTest
## Quality: rig tests for Component Upgrades (U1). The field sweep's rated and tested
## figures, how joint quality sets the gain, what trips, overheats or falls short, the plate
## and its serial, the rig screen and the plate on the unit, and the save round trip.
##   tools/run_tests.sh quality

const BASE := {"attract_reach": 18.0, "attract_max_mass": 6000.0, "attract_speed": 5.0}


func run_tests() -> void:
	_sweep()
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "trades": true,
			"multiplayer": true, "quality": true, "quality.rig_tests": true})
	Modules.load_all()
	var bus := Modules.bus("quality") as QualityBus
	check(bus != null, "quality loads with rig tests on")
	if bus:
		await _bus(bus)
	Flags.use(saved)
	Modules.load_all()
	await frames(1)


func _sweep() -> void:
	var rules := RigRules.new()
	var addons := [{"part": "quantum_core", "tier": 2, "mount": "coil_bay"},
			{"part": "field_emitter_array", "tier": 1, "mount": "horn_mount"}]
	var rated := FieldSweep.rated(BASE, addons, rules)
	check(is_equal_approx(rated.attract_max_mass, 15000.0), "a Q2 core rates the coil at 2.5x mass: %s" % rated.attract_max_mass)
	check(is_equal_approx(rated.attract_reach, 18.0 * 1.2 * 1.15), "add-ons stack on reach: %s" % rated.attract_reach)
	check(is_equal_approx(rated.attract_speed, 5.5), "the emitter array adds pull speed")

	var good := {"a": _rec("a", 100), "b": _rec("b", 100)}
	var p := FieldSweep.run(_req(addons, ["a", "b"]), good, rules)
	check(p.passed and p.grade == "A" and p.tier == 2 and p.family == "attractor_coil", "perfect joints pass at A, tier 2")
	check(p.efficiency > 1.0 and p.tested.attract_max_mass > rated.attract_max_mass, "perfect work beats the rating")

	var fair := {"a": _rec("a", 90), "b": _rec("b", 90)}
	p = FieldSweep.run(_req(addons, ["a", "b"]), fair, rules)
	check(p.passed and is_equal_approx(p.efficiency, 1.005), "good joints reach the rating: %s" % p.efficiency)

	var poor := {"a": _rec("a", 55), "b": _rec("b", 60)}
	p = FieldSweep.run(_req(addons, ["a", "b"]), poor, rules)
	check(not p.passed and _codes(p) == ["short"], "marginal joints fall short: %s" % [_codes(p)])
	check(p.tested.attract_max_mass > BASE.attract_max_mass and p.tested.attract_max_mass < rated.attract_max_mass,
			"a short unit still tests above its old figures")
	check(str(p.snags[0].text).contains("rated"), "the snag says how short: " + str(p.snags[0].text))

	var cracked := {"a": _rec("a", 100), "b": _rec("b", 20, true)}
	p = FieldSweep.run(_req(addons, ["a", "b"]), cracked, rules)
	check(not p.passed and _codes(p).has("trip") and p.grade == "D", "a failed joint trips the sweep")

	var t3 := [{"part": "quantum_core", "tier": 3, "mount": "coil_bay"}]
	p = FieldSweep.run(_req(t3, ["a", "b"]), good, rules)
	check(_codes(p) == ["overheat"] and p.tier == 3, "tier 3 without a heat exchanger overheats")
	t3.append({"part": "heat_exchanger", "tier": 1, "mount": "jacket"})
	check(FieldSweep.run(_req(t3, ["a", "b"]), good, rules).passed, "a heat exchanger lets tier 3 run")

	p = FieldSweep.run(_req([], []), good, rules)
	check(_codes(p) == ["nothing_fitted"] and p.tested.attract_reach == 18.0, "an empty unit can't pass")

	var own := _req(addons, ["a", "b"])
	own["rated"] = {"attract_reach": 30.0}
	p = FieldSweep.run(own, fair, rules)
	check(is_equal_approx(p.rated.attract_reach, 30.0) and p.tested.attract_max_mass == 6000.0,
			"figures from the shared rules file replace Quality's stand-in")
	check(FieldSweep.stat_text("attract_max_mass", 15000.0) == "Max mass 15.0 t", "mass shows in tonnes")


func _bus(bus: QualityBus) -> void:
	bus.clear()
	_submit(bus, "coil_bay_bolts", [25.0, 25.0, 25.0, 25.0])
	_submit(bus, "horn_bolts", [25.0, 25.0, 25.0, 25.0])
	var heard: Array[UpgradePlate] = []
	bus.rig_test_finished.connect(func(p: UpgradePlate) -> void: heard.append(p))
	var addons := [{"part": "quantum_core", "tier": 2, "mount": "coil_bay"}]
	bus.run_field_sweep(_req(addons, ["coil_bay_bolts", "horn_bolts"]))
	check(heard.size() == 1 and heard[0].passed and heard[0].serial == "BSX-U-0001",
			"a passing sweep is certified with a serial: %s" % [heard[0].serial if heard.size() > 0 else "none"])
	check(bus.last_plate("attractor_coil_1") == heard[0] and bus.get_plate("BSX-U-0001") == heard[0], "plates are kept")

	_submit(bus, "bad_bolts", [25.0, 25.0, 25.0, 25.0], {"cross_threaded": [true, false, false, false]})
	bus.run_field_sweep(_req(addons, ["coil_bay_bolts", "bad_bolts"]))
	var failed: UpgradePlate = heard.back()
	check(not failed.passed and failed.serial == "" and _codes(failed).has("trip"), "a failed sweep gets snags, no serial")
	check(bus.plates().size() == 2 and bus.plates()[0] == failed, "plates list newest first")

	var screen := bus.make_sweep_screen(heard[0], true)
	add_child(screen)
	check(screen.find_child("Figures", true, false).get_child_count() == 3, "the rig screen shows every figure")
	check((screen.find_child("Result", true, false) as Control) != null, "the rig screen shows the result")
	screen.queue_free()
	var node := bus.make_plate_node(heard[0])
	check(node.call("lines")[2].begins_with("SERIAL BSX-U-0001"), "the plate is engraved with the serial and grade")
	check(node.call("lines")[1].ends_with("TIER 2"), "the plate shows the tier")
	var tag := bus.make_plate_node(failed)
	check(tag.call("lines")[0] == "REJECTED", "a failed unit gets a reject tag")
	node.free()
	tag.free()

	var data := bus.save_data()
	bus.clear()
	bus.load_data(JSON.parse_string(JSON.stringify(data)), QualityBus.SAVE_VERSION)
	check(bus.plates().size() == 2 and bus.get_plate("BSX-U-0001").tested.has("attract_max_mass"), "plates survive a save")
	bus.run_field_sweep(_req(addons, ["coil_bay_bolts", "horn_bolts"]))
	check(heard.back().serial == "BSX-U-0002", "serials keep counting after a load")

	Flags.set_flag(QualityBus.RIG_TESTS, false)
	var n := heard.size()
	bus.run_field_sweep(_req(addons, ["coil_bay_bolts"]))
	check(heard.size() == n, "no sweeps while rig tests are off")
	Flags.set_flag(QualityBus.RIG_TESTS, true)


func _req(addons: Array, joints: Array) -> Dictionary:
	return {"unit_id": "attractor_coil_1", "base": BASE.duplicate(), "addons": addons, "joint_ids": joints}


func _rec(id: String, score: int, fail := false) -> JointRecord:
	var r := JointRecord.new()
	r.joint_id = StringName(id)
	r.trade = &"BOLT"
	r.component_id = &"quantum_core"
	r.score = score
	r.grade = JointRecord.FAIL if fail else (JointRecord.PASS if score >= 70 else JointRecord.MARGINAL)
	if fail:
		r.faults.assign([{"code": "cross_threaded", "hole": 0, "text": "Hole 1 cross-threaded"}])
	return r


func _codes(p: UpgradePlate) -> Array:
	return p.snags.map(func(s): return s.code)


class FakeResult extends Resource:
	var joint_id: StringName
	var trade: StringName = &"BOLT"
	var component_id: StringName = &"quantum_core"
	var mount_id: StringName = &"coil_bay"
	var measurements: Dictionary = {}
	var peer_id := 1
	var time := 1000


func _submit(bus: QualityBus, id: String, torques: Array, extra: Dictionary = {}) -> void:
	var res := FakeResult.new()
	res.joint_id = StringName(id)
	var n := torques.size()
	var fill := func(v: bool) -> Array:
		var a := []
		a.resize(n)
		a.fill(v)
		return a
	var m := {"torque_nm": torques, "torque_target_nm": 25.0, "sequence": [], "sequence_ok": true,
			"cross_threaded": fill.call(false), "washer": fill.call(true), "fastener_ids": [], "misalign_mm": 0.5}
	m.merge(extra, true)
	res.measurements = m
	bus.submit(res)
