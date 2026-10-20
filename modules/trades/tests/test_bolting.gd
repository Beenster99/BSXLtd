extends ModuleTest
## Bolting: the joint rules, the bus, and the bench scene booting.

const TUNING := preload("res://modules/trades/internal/bolting/bolting.tres")
const M8 := &"bolt_m8x25_8.8"
const M6 := &"bolt_m6x20_8.8"


func run_tests() -> void:
	var bus := Modules.bus("trades") as TradesBus
	check(bus != null, "trades bus is loaded")
	check(Router.has_scene(TradesBus.WORKBENCH), "workbench scene is registered")

	_test_clean_joint()
	_test_bracket_must_line_up()
	_test_cross_thread()
	_test_hands_run_down()
	_test_order_torque_and_parts()
	_test_back_out_reopens()
	_test_bus(bus)
	await _test_bench_scene(bus)


func _spec() -> JointSpec:
	var s := JointSpec.new()
	s.torque_target_nm = 25.0
	s.sequence = PackedInt32Array([0, 2, 1, 3])
	return s


func _joint() -> BoltJoint:
	return BoltJoint.new(_spec(), 4, TUNING)


## Turn by hand just until the thread catches.
func _hand_start(j: BoltJoint, hole: int, tilt := 0.0, fastener := M8, washer := true) -> void:
	for i in 40:
		if j.hand_turn(hole, tilt, fastener, washer, 0.05) != &"turning":
			return


## Keep turning by hand until it seats.
func _run_down(j: BoltJoint, hole: int) -> void:
	for i in 100:
		if j.hand_turn(hole, 0.0, M8, true, 0.05) != &"turning":
			return


func _torque(j: BoltJoint, hole: int, nm: float) -> void:
	j.begin_pull(hole)
	j.pull(nm * 0.5)
	j.pull(nm)
	j.end_pull()


func _test_clean_joint() -> void:
	var j := _joint()
	var clicks: Array[int] = []
	var done := [false]
	j.wrench_clicked.connect(func(h: int) -> void: clicks.append(h))
	j.completed.connect(func() -> void: done[0] = true)
	check(j.place_bracket(4.0, 2.0), "bracket seats when close and square")
	for h in 4:
		_hand_start(j, h)
		check(j.state[h] == BoltJoint.Hole.STARTED, "bolt %d starts by hand" % h)
		_run_down(j, h)
		check(j.state[h] == BoltJoint.Hole.SEATED, "bolt %d runs down" % h)
	for h in [0, 2, 1]:
		_torque(j, h, 25.4)
	check(not j.is_complete(), "not complete with a bolt left")
	_torque(j, 3, 25.4)
	check(j.is_complete() and done[0], "complete once every bolt is torqued")
	check(clicks == [0, 2, 1, 3], "wrench clicks once per bolt at target")
	var m := j.measurements()
	check(m.torque_nm == [25.4, 25.4, 25.4, 25.4], "torques recorded")
	check(m.sequence_ok and m.sequence == PackedInt32Array([0, 2, 1, 3]), "order recorded and matches")
	check(m.cross_threaded == [false, false, false, false], "no cross threads")
	check(m.washer == [true, true, true, true], "washers recorded")
	check(is_equal_approx(m.misalign_mm, 1.0), "snap leaves a quarter of the offset")


func _test_bracket_must_line_up() -> void:
	var j := _joint()
	check(not j.place_bracket(30.0, 0.0), "bracket far from its seat does not snap")
	check(not j.place_bracket(2.0, 15.0), "bracket at an angle does not snap")
	check(j.hand_turn(0, 0.0, M8, true, 0.1) == &"", "no bolts before the bracket is seated")


func _test_cross_thread() -> void:
	var j := _joint()
	j.place_bracket(0.0, 0.0)
	var results: Array[StringName] = []
	for i in 20:
		results.append(j.hand_turn(1, 9.0, M8, true, 0.05))
	check(j.cross[1], "a tilted bolt cross-threads")
	check(results.has(&"bind") and j.state[1] == BoltJoint.Hole.STARTING, "a cross-threaded bolt binds by hand")
	j.back_out(1)
	check(j.state[1] == BoltJoint.Hole.EMPTY and not j.cross[1], "backing out clears it")
	_hand_start(j, 1, 2.0)
	check(j.state[1] == BoltJoint.Hole.STARTED and not j.cross[1], "a straight restart is clean")
	for i in 20:
		j.hand_turn(2, 9.0, M8, true, 0.05)
	check(j.is_bound(2) and j.can_pull(2), "a jammed bolt can still take the torque wrench")
	_torque(j, 2, 25.0)
	check(j.state[2] == BoltJoint.Hole.TORQUED and j.measurements().cross_threaded[2], "forcing it with the wrench keeps the cross thread")


func _test_hands_run_down() -> void:
	var j := _joint()
	j.place_bracket(0.0, 0.0)
	j.hand_turn(0, 0.0, M8, true, 0.1)
	check(j.state[0] == BoltJoint.Hole.STARTING and not j.begin_pull(0), "no torque wrench before the bolt is run down")
	_hand_start(j, 0)
	check(j.state[0] == BoltJoint.Hole.STARTED and not j.can_pull(0), "thread caught but not yet seated")
	_run_down(j, 0)
	check(j.state[0] == BoltJoint.Hole.SEATED and j.can_pull(0), "hands run it down finger tight")
	check(j.hand_turn(0, 0.0, M8, true, 0.1) == &"", "hands can't turn a seated bolt further")
	var fast := _joint()
	fast.speed = 2.0
	fast.place_bracket(0.0, 0.0)
	fast.hand_turn(0, 0.0, M8, true, 1.0)
	check(is_equal_approx(fast.turns[0], 2.0 * TUNING.hand_turns_per_second), "skill speed turns faster")


func _test_order_torque_and_parts() -> void:
	var j := _joint()
	j.place_bracket(0.0, 0.0)
	for h in 4:
		_hand_start(j, h, 0.0, M6 if h == 3 else M8, h != 1)
		_run_down(j, h)
	_torque(j, 0, 25.0)
	_torque(j, 1, 40.0)
	_torque(j, 2, 18.0)
	check(j.state[2] == BoltJoint.Hole.TORQUED, "a short pull above the minimum counts")
	_torque(j, 3, 8.0)
	check(j.state[3] == BoltJoint.Hole.SEATED, "a pull below the minimum share is not final torque")
	_torque(j, 3, 25.0)
	_torque(j, 1, 10.0)
	var m := j.measurements()
	check(not m.sequence_ok and m.sequence == PackedInt32Array([0, 1, 2, 3]), "wrong order reported")
	check(m.torque_nm == [25.0, 40.0, 18.0, 25.0], "over and under torque recorded, a weaker re-pull changes nothing")
	check(m.washer == [true, false, true, true], "missing washer recorded")
	check(m.fastener_ids == [M8, M8, M8, M6], "wrong fastener recorded")


func _test_back_out_reopens() -> void:
	var j := _joint()
	j.place_bracket(0.0, 0.0)
	for h in [0, 2, 1, 3]:
		_hand_start(j, h)
		_run_down(j, h)
		_torque(j, h, 25.0)
	check(j.is_complete(), "complete")
	check(j.back_out(2), "backing out a finished joint says it needs rework")
	check(not j.is_complete() and j.order == PackedInt32Array([0, 1, 3]), "order forgets the removed bolt")
	check(not j.lift_bracket(), "bracket stays while bolts are in")


func _test_bus(bus: TradesBus) -> void:
	var s := JointSite.new()
	s.joint_id = &"test_joint"
	s.spec = _spec()
	add_child(s)
	check(bus.site(&"test_joint") == s, "a site registers on entering the tree")
	var got: Array[JointResult] = []
	var removed: Array[StringName] = []
	bus.joint_completed.connect(func(r: JointResult) -> void: got.append(r))
	bus.joint_removed.connect(func(id: StringName) -> void: removed.append(id))
	bus.complete_joint(s, {"torque_nm": [25.0]})
	check(got.size() == 1 and got[0].joint_id == &"test_joint" and got[0].trade == &"BOLT", "joint_completed carries the result")
	check(got[0].measurements.torque_nm == [25.0] and got[0].time > 0, "result carries measurements and time")
	check(bus.get_result(&"test_joint") == got[0], "result is kept")
	bus.remove_joint(&"test_joint")
	bus.set_player_modifiers(&"1", {&"bolt_speed": 0.1})
	check(is_equal_approx(bus.modifier(1, &"bolt_speed"), 0.1) and bus.modifier(2, &"bolt_speed") == 0.0, "player modifiers are kept per player")
	bus.set_player_modifiers(1, {})
	check(removed == [&"test_joint"] and bus.get_result(&"test_joint") == null, "joint_removed drops it")
	s.queue_free()
	await frames(1)
	check(bus.site(&"test_joint") == null, "a site unregisters on leaving the tree")


func _test_bench_scene(bus: TradesBus) -> void:
	var bench: Node = load(TradesBus.BENCH_SCENE).instantiate()
	add_child(bench)
	await frames(2)
	var got: Array[JointResult] = []
	bus.joint_completed.connect(func(r: JointResult) -> void: got.append(r))
	await bench.stage_for_screenshot(&"bolting")
	var station: Node = bench.station(&"bolting")
	var j: BoltJoint = station.joint
	check(j.bracket_seated and j.order == PackedInt32Array([0, 2]), "screenshot staging seats the bracket and torques two bolts")
	check(j.pulling_hole() == 1 and station.wrench.visible, "staging has the wrench on the third bolt")
	j.end_pull()
	for h in [1, 3]:
		_hand_start(j, h)
		_run_down(j, h)
		_torque(j, h, 25.0)
	check(got.size() == 1 and got[0].joint_id == &"bench_bracket", "finishing on the bench reports to the bus")
	check(got[0].measurements.sequence_ok, "bench joint in spec order")
	bench.reset_all()
	check(bus.get_result(&"bench_bracket") == null, "resetting the bench removes its result")
	bench._on_action(TradesBus.KEY_TOOL + "1")   # hands: the bench leaves the right hand alone
	var hand: StretchHand = bench.worker.right_hand
	var snaps := [0]
	hand.snapped.connect(func() -> void: snaps[0] += 1)
	hand.reach_to(bench.worker.global_position + Vector3(0, 1.2, -1.0))
	await get_tree().create_timer(0.5).timeout
	check(hand.is_on_target() and snaps[0] == 0 and hand.tension() > 0.0, "a hand stretches out to something within reach")
	hand.reach_to(bench.worker.global_position + Vector3(0, 1.2, -4.0))
	await frames(3)
	check(snaps[0] == 1 and not hand.out, "a hand over-stretched lets go")
	bench.worker.set_view(true)
	check(bench.worker.camera.position.length() > 1.0, "third person moves the camera out behind the shoulder")
	bench.queue_free()
	await frames(1)
