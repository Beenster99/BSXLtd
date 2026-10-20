extends ModuleTest
## Welding: the seam's bead, speed, heat and arc, and the bay's station.

const DT := 1.0 / 60.0


func run_tests() -> void:
	_test_clean_run()
	_test_heat()
	_test_arc_breaks()
	_test_gaps_and_ends()
	await _test_station()


func _seam() -> WeldSeam:
	var s := JointSpec.new()
	s.trade = &"WELD"
	var w := WeldSeam.new(s)
	w.set_amps(w.amps_target)
	return w


## Run from where the torch is to `to_mm` at `speed` mm/s.
func _run(w: WeldSeam, to_mm: float, speed: float, angle := 30.0) -> StringName:
	var r := &""
	for i in 10000:
		r = w.travel(speed * DT, 0.0, angle, DT)
		if r != &"welding" or w.pos_mm >= to_mm:
			return r
	return r


func _test_clean_run() -> void:
	var w := _seam()
	var done := [false]
	w.completed.connect(func() -> void: done[0] = true)
	check(w.strike(0.0) and w.arc_on, "the arc strikes")
	check(_run(w, w.length_mm, w.speed_target_mm_s) == &"end", "the torch runs to the far end")
	w.stop()
	check(done[0] and w.is_complete(), "a seam welded end to end is complete")
	var m := w.measurements()
	check(m.coverage == 1.0 and not m.burn_through and m.restarts == 0, "full coverage, no burn through, one strike")
	check(m.travel_speed_mm_s.size() == 12, "one sample per 10 mm")
	var pens: Array = m.penetration_samples
	check(absf(m.penetration - 1.0) < 0.1 and m.arc_length_target_mm == 3.0, "mean penetration and Quality's target names reported")
	check(absf(pens[6] - 1.0) < 0.05 and absf(m.travel_speed_mm_s[6] - 8.0) < 0.1, "steady travel at the target gives full penetration")
	check(m.torch_angle_deg[3] == 30.0 and m.arc_length_mm[3] == 3.0, "angle and arc recorded")
	check(not w.strike(10.0), "a finished seam can't be struck again")


func _test_heat() -> void:
	var w := _seam()
	check(w.penetration(4.0, 3.0) > 1.3, "slow travel digs deeper")
	check(w.penetration(16.0, 3.0) < 0.75, "fast travel digs too little")
	check(w.penetration(8.0, 6.0) < w.penetration(8.0, 3.0), "a long arc spreads the heat")
	w.set_amps(90.0)
	check(w.penetration(8.0, 3.0) < 0.75, "too few amps for the plate")
	w.set_amps(203.0)
	check(w.amps == 200.0, "amps stay on the dial")
	var b := _seam()
	b.strike(50.0)
	for i in 120:
		b.travel(0.0, 0.0, 30.0, DT)
	check(b.burn_through, "holding still burns through")


func _test_arc_breaks() -> void:
	var w := _seam()
	var broke := [0]
	w.arc_broke.connect(func() -> void: broke[0] += 1)
	w.strike(0.0)
	_run(w, 40.0, 8.0)
	check(w.travel(0.1, 6.0, 30.0, DT) == &"broke" and not w.arc_on and broke[0] == 1, "lifting the torch away breaks the arc")
	w.strike(w.pos_mm)
	check(w.travel(0.1, -2.6, 30.0, DT) == &"broke", "pushing it into the plate stubs it out")
	w.strike(w.pos_mm)
	_run(w, w.length_mm, 8.0)
	w.stop()
	var m := w.measurements()
	check(w.is_complete() and m.restarts == 2, "restarts are counted")


func _test_gaps_and_ends() -> void:
	var w := _seam()
	w.strike(30.0)
	_run(w, w.length_mm, 8.0)
	w.stop()
	check(not w.is_complete(), "a seam with an unwelded start isn't finished")
	w.strike(0.0)
	_run(w, 10.0, 8.0)
	w.stop()
	check(w.is_complete() and w.coverage() < 0.9, "both ends welded finishes it, with the gap in the coverage")
	check(w.grind_out() and w.coverage() == 0.0 and not w.is_complete(), "grinding out starts again")


func _test_station() -> void:
	var bus := Modules.bus("trades") as TradesBus
	check(bus.is_tool_enabled(&"welder"), "the welder is enabled")
	var bay: Node = load(TradesBus.BENCH_SCENE).instantiate()
	add_child(bay)
	await frames(2)
	var got: Array[JointResult] = []
	bus.joint_completed.connect(func(r: JointResult) -> void: got.append(r))
	await bay.stage_for_screenshot(&"welding")
	var station: Node = bay.station(&"welding")
	var w: WeldSeam = station.seam
	check(w.arc_on and w.pos_mm > 60.0 and bay.tool == &"welder", "staging has the arc lit along the seam")
	check(station.torch.lit, "the torch glows while the arc is lit")
	var angle: float = station._torch_angle(station._tip_world())
	check(angle > 15.0 and angle < 60.0, "the torch leans back toward the worker (%.0f deg)" % angle)
	_run(w, w.length_mm, 8.0)
	station.release()
	check(got.size() == 1 and got[0].trade == &"WELD" and got[0].measurements.coverage == 1.0, "finishing the seam reports to the bus")
	check(not station.torch.lit, "the arc is out after the run")
	check(station.adjust(-1) and w.amps == 125.0, "Q turns the amps down")
	bay.reset_all()
	check(bus.get_result(&"bench_seam") == null and w.coverage() == 0.0, "resetting clears the seam and its result")
	bay.queue_free()
	await frames(1)
