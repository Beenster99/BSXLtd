extends ModuleTest
## Wiring: terminations, the circuit test and its faults, and the bay's station.



func run_tests() -> void:
	_test_good_circuit()
	_test_faults()
	_test_ends()
	_test_rework()
	await _test_station()


func _circuit() -> WireCircuit:
	var s := JointSpec.new()
	s.trade = &"WIRE"
	return WireCircuit.new(s)


func _wire(c: WireCircuit, a: int, b: int, colour: StringName, strip := 8.0, crimp := 1.0) -> void:
	c.lay(a, b, colour)
	for t in [a, b]:
		c.strip(t, strip)
		c.crimp_end(t, crimp)


func _good(c: WireCircuit) -> void:
	_wire(c, WireCircuit.SUPPLY_POS, WireCircuit.SWITCH_COM, &"red")
	_wire(c, WireCircuit.SWITCH_NO, WireCircuit.LAMP_POS, &"red")
	_wire(c, WireCircuit.LAMP_NEG, WireCircuit.SUPPLY_NEG, &"black")


func _test_good_circuit() -> void:
	var c := _circuit()
	var done := [false]
	c.completed.connect(func() -> void: done[0] = true)
	_good(c)
	check(c.is_ready_to_test() and not c.lamp_lit, "wired, switch off, lamp dark")
	c.set_switch(true)
	check(c.lamp_lit and done[0] and c.is_complete(), "switching on lights the lamp and finishes the test")
	var m := c.measurements()
	check(m.strip_length_mm.size() == 6 and m.crimp_pull_n == [310.0, 310.0, 310.0, 310.0, 310.0, 310.0], "six ends, full crimps")
	check(absf(m.continuity_ohm - 0.21) < 0.001 and m.insulation_mohm == 500.0, "low resistance, sound insulation")
	check(m.polarity_ok and not m.miswired and m.colour_ok, "right way round, right colours")
	c.set_switch(false)
	check(not c.lamp_lit, "switching off puts it out")


func _test_faults() -> void:
	var r := _circuit()
	_wire(r, WireCircuit.SUPPLY_POS, WireCircuit.SWITCH_COM, &"red")
	_wire(r, WireCircuit.SWITCH_NO, WireCircuit.LAMP_NEG, &"red")
	_wire(r, WireCircuit.LAMP_POS, WireCircuit.SUPPLY_NEG, &"black")
	r.set_switch(true)
	check(r.lamp_lit and not r.measurements().polarity_ok and not r.is_miswired(), "a lamp wired backwards lights but fails polarity")
	var b := _circuit()
	_wire(b, WireCircuit.SUPPLY_POS, WireCircuit.LAMP_POS, &"red")
	_wire(b, WireCircuit.LAMP_NEG, WireCircuit.SUPPLY_NEG, &"black")
	b.set_switch(true)
	check(b.is_complete() and b.is_miswired(), "a lamp that ignores the switch is miswired")
	var s := _circuit()
	_wire(s, WireCircuit.SUPPLY_POS, WireCircuit.SUPPLY_NEG, &"red")
	s.set_switch(true)
	var m := s.measurements()
	check(m.miswired and m.continuity_ohm == -1.0 and m.insulation_mohm == 0.0, "a dead short reads open and no insulation")
	var k := _circuit()
	_wire(k, WireCircuit.SUPPLY_POS, WireCircuit.SWITCH_COM, &"black")
	_wire(k, WireCircuit.SWITCH_NO, WireCircuit.LAMP_POS, &"red")
	_wire(k, WireCircuit.LAMP_NEG, WireCircuit.SUPPLY_NEG, &"black")
	k.set_switch(true)
	check(k.lamp_lit and not k.colour_ok(), "a black wire on the positive side is the wrong colour")


func _test_ends() -> void:
	var c := _circuit()
	_wire(c, WireCircuit.SUPPLY_POS, WireCircuit.SWITCH_COM, &"red", 4.0, 1.0)
	_wire(c, WireCircuit.SWITCH_NO, WireCircuit.LAMP_POS, &"red", 11.0, 1.0)
	_wire(c, WireCircuit.LAMP_NEG, WireCircuit.SUPPLY_NEG, &"black", 8.0, 0.5)
	c.set_switch(true)
	var m := c.measurements()
	check(m.crimp_pull_n[0] == 186.0, "a short strip only grips insulation")
	check(m.bare_mm[3] == 3.0 and m.insulation_mohm == 2.0, "a long strip leaves bare copper")
	check(m.crimp_pull_n[5] == 175.0 and m.continuity_ohm > 0.5, "a half crimp is weak and resistive")
	var o := _circuit()
	_wire(o, WireCircuit.SUPPLY_POS, WireCircuit.SWITCH_COM, &"red")
	_wire(o, WireCircuit.SWITCH_NO, WireCircuit.LAMP_POS, &"red")
	_wire(o, WireCircuit.LAMP_NEG, WireCircuit.SUPPLY_NEG, &"black", 8.0, 0.1)
	o.set_switch(true)
	check(not o.lamp_lit and o.measurements().continuity_ohm == -1.0 and not o.is_miswired(), "a crimp that never closed is an open circuit")


func _test_rework() -> void:
	var c := _circuit()
	check(not c.lay(0, 0, &"red"), "a wire needs two terminals")
	c.lay(WireCircuit.SUPPLY_POS, WireCircuit.SWITCH_COM, &"red")
	check(not c.lay(WireCircuit.SUPPLY_POS, WireCircuit.LAMP_POS, &"red"), "one wire per terminal")
	check(not c.crimp_end(WireCircuit.SUPPLY_POS, 1.0), "strip before crimping")
	c.set_switch(true)
	check(not c.is_complete(), "no test with ends undone")
	c.set_switch(false)
	_good(c)
	c.set_switch(true)
	check(c.is_complete(), "complete")
	check(c.cut_back(WireCircuit.LAMP_POS) and c.end_state[WireCircuit.LAMP_POS] == WireCircuit.End.LAID, "cutting an end back reopens it")
	check(not c.lamp_lit, "and the lamp goes out")
	check(not c.remove_wire_at(WireCircuit.LAMP_POS) and c.wires.size() == 2, "pulling the wire off frees both terminals")
	check(c.end_state[WireCircuit.SWITCH_NO] == WireCircuit.End.EMPTY, "both ends empty")


func _test_station() -> void:
	var bus := Modules.bus("trades") as TradesBus
	check(Menu.entries().any(func(e: Dictionary) -> bool: return e.id == "bench_wiring"), "wiring is on the menu")
	check(bus.is_tool_enabled(&"wire_tool"), "the crimper is enabled")
	var bay: Node = load(TradesBus.BENCH_SCENE).instantiate()
	add_child(bay)
	await frames(2)
	var got: Array[JointResult] = []
	bus.joint_completed.connect(func(r: JointResult) -> void: got.append(r))
	await bay.stage_for_screenshot(&"wiring")
	var station: Node = bay.station(&"wiring")
	var c: WireCircuit = station.circuit
	check(c.wires.size() == 3 and station.wire_tool.mode == "crimp", "staging has three wires run and the crimper on the last end")
	station.release()
	check(c.end_state[WireCircuit.SUPPLY_NEG] == WireCircuit.End.TERMINATED, "letting go crimps the end")
	c.crimp_end(WireCircuit.LAMP_NEG, 1.0)
	c.set_switch(true)
	await frames(1)
	check(c.lamp_lit and station._lamp_light.visible, "the lamp lights on the board")
	check(got.size() == 1 and got[0].trade == &"WIRE" and got[0].joint_id == &"bench_circuit", "the test reports to the bus")
	bay.reset_all()
	check(bus.get_result(&"bench_circuit") == null and c.wires.is_empty(), "resetting clears the board and its result")
	bay.queue_free()
	await frames(1)
