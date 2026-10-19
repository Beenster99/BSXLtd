extends ModuleTest
## Riveting: drilling, deburring, rivet length and the squeezed head, and the bay's station.


func run_tests() -> void:
	_test_good_rivet()
	_test_wobble_and_offset()
	_test_lengths()
	_test_over_squeeze()
	_test_order_of_work()
	_test_drill_out()
	await _test_station()


func _joint(holes := 5) -> RivetJoint:
	var s := JointSpec.new()
	s.trade = &"RIVET"
	return RivetJoint.new(s, holes)


func _drill(j: RivetJoint, hole: int, offset := 0.0, wobble := 0.0) -> void:
	for i in 100:
		if j.drill(hole, offset, wobble, 0.05) != &"drilling":
			return


func _deburr(j: RivetJoint, hole: int) -> void:
	for i in 100:
		if j.deburr(hole, 0.05):
			return


func _rivet(j: RivetJoint, hole: int, length := 8.0, squeeze := 0.667) -> void:
	_drill(j, hole)
	_deburr(j, hole)
	j.insert(hole, length)
	j.begin_squeeze(hole)
	j.press(squeeze * 0.5)
	j.press(squeeze)
	j.end_squeeze()


func _test_good_rivet() -> void:
	var j := _joint(1)
	var done := [false]
	j.completed.connect(func() -> void: done[0] = true)
	_drill(j, 0)
	check(j.state[0] == RivetJoint.Hole.DRILLED and is_equal_approx(j.clearance_mm[0], 0.1), "a still drill leaves a clean 3.3 mm hole")
	_deburr(j, 0)
	check(j.deburred[0], "deburring cleans the hole")
	check(j.insert(0, 8.0) and j.state[0] == RivetJoint.Hole.RIVET, "a rivet goes in a drilled hole")
	j.begin_squeeze(0)
	j.press(0.667)
	check(absf(j.head_height_mm(0) - 1.6) < 0.01 and absf(j.head_dia_mm(0) - 4.8) < 0.02, "8 mm rivet squeezed to 1.6 mm makes a 4.8 mm head")
	j.end_squeeze()
	check(j.is_complete() and done[0], "complete once every rivet is formed")
	var m := j.measurements()
	check(m.head_height_mm == [1.6] and m.head_dia_target_mm == 4.8, "head and target reported")
	check(m.seated == [true] and m.cracked_head == [false] and m.deburred == [true], "seated, sound and deburred")
	check(m.hole_fit_mm == [0.1], "hole fit reported")


func _test_wobble_and_offset() -> void:
	var j := _joint(2)
	_drill(j, 0, 2.5, 20.0)
	check(j.clearance_mm[0] > 0.5, "a wobbling drill opens the hole up")
	check(is_equal_approx(j.offset_mm[0], 2.5), "the offset from the mark is kept")
	check(j.drill(0, 0.0, 0.0, 0.1) == &"", "a drilled hole doesn't drill again")
	j.speed = 2.0
	j.drill(1, 0.0, 0.0, j.drill_seconds / 2.0)
	check(j.state[1] == RivetJoint.Hole.DRILLED, "skill speed drills faster")


func _test_lengths() -> void:
	var j := _joint(3)
	_rivet(j, 0, 6.0, 0.43)
	check(not j.is_seated(0), "a 6 mm rivet is too short to draw the sheets tight")
	check(j.head_dia_mm(0) < 4.0, "and its head comes out small")
	_rivet(j, 1, 10.0, 0.765)
	check(j.is_seated(1) and j.head_dia_mm(1) > 5.5, "a 10 mm rivet at the right height spreads too wide")
	_rivet(j, 2, 8.0, 0.667)
	check(j.is_seated(2) and not j.is_cracked(2), "8 mm is right")


func _test_over_squeeze() -> void:
	var j := _joint(1)
	_rivet(j, 0, 8.0, 0.85)
	check(j.is_cracked(0) and j.measurements().cracked_head == [true], "squeezing too far cracks the head")
	j.begin_squeeze(0)
	check(not j.begin_squeeze(0) or j.squeeze[0] == 0.85, "a finished joint can't be squeezed again")
	var k := _joint(2)
	_drill(k, 0)
	_deburr(k, 0)
	k.insert(0, 8.0)
	k.begin_squeeze(0)
	k.press(0.6)
	k.press(0.3)
	check(is_equal_approx(k.squeeze[0], 0.6), "a head only gets flatter")
	k.end_squeeze()
	k.begin_squeeze(0)
	k.press(0.9)
	check(is_equal_approx(k.squeeze[0], 0.85), "the squeezer bottoms out")


func _test_order_of_work() -> void:
	var j := _joint(2)
	check(not j.insert(0, 8.0), "no rivet before the hole is drilled")
	check(not j.begin_squeeze(0), "nothing to squeeze yet")
	_drill(j, 0)
	j.insert(0, 8.0)
	check(not j.deburred[0] and not j.deburr(0, 1.0), "a hole with a rivet in can't be deburred")
	j.begin_squeeze(0)
	j.press(0.2)
	j.end_squeeze()
	check(j.state[0] == RivetJoint.Hole.RIVET, "a light squeeze hasn't formed a head")


func _test_drill_out() -> void:
	var j := _joint(1)
	_rivet(j, 0)
	check(j.is_complete(), "complete")
	check(j.drill_out(0), "drilling out a finished joint says it needs rework")
	check(j.state[0] == RivetJoint.Hole.DRILLED and is_equal_approx(j.clearance_mm[0], 0.25) and not j.deburred[0], "the hole is bigger and rough again")


func _test_station() -> void:
	var bus := Modules.bus("trades") as TradesBus
	check(Menu.entries().any(func(e: Dictionary) -> bool: return e.id == "bench_riveting" and e.group == "Workbench"), "riveting is on the menu")
	check(bus.is_tool_enabled(&"drill") and bus.is_tool_enabled(&"rivet_squeezer"), "riveting tools are enabled")
	var bay: Node = load(TradesBus.BENCH_SCENE).instantiate()
	add_child(bay)
	await frames(2)
	var got: Array[JointResult] = []
	bus.joint_completed.connect(func(r: JointResult) -> void: got.append(r))
	await bay.stage_for_screenshot(&"riveting")
	var station: Node = bay.station(&"riveting")
	var j: RivetJoint = station.joint
	check(j.squeezing_hole() == 3 and bay.tool == &"rivet_squeezer", "staging has the squeezer on the fourth rivet")
	check(bay.focus() == station, "the bay works at the riveting station")
	station.release()
	_rivet(j, 4)
	j.begin_squeeze(3)
	j.press(0.667)
	j.end_squeeze()
	check(got.size() == 1 and got[0].trade == &"RIVET" and got[0].joint_id == &"bench_lap", "finishing the rivets reports to the bus")
	check(got[0].measurements.head_height_mm.size() == 5, "five rivets measured")
	bay.reset_all()
	check(bus.get_result(&"bench_lap") == null and j.state[0] == RivetJoint.Hole.MARKED, "resetting clears the joint and its result")
	bay.queue_free()
	await frames(1)
