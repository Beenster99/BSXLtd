extends ModuleTest
## Design Room: the numbers (parts list, cost, power, fit to demands) and the rules that
## flag what will not work.
##   tools/run_tests.sh design

var cat := DesignCatalog.load_default()


## A small working ship: airlock at the stern, corridor, bridge at the bow, engineering with
## a reactor and an engine, quarters with two bunks, a cargo hold.
func small_ship() -> DesignRecord:
	var d := DesignRecord.new("s", "Skiff")
	var ops := [
		{"op": "add_room", "room": {"id": "r1", "type": "bridge", "x": -2, "z": -10, "w": 5, "d": 4}},
		{"op": "add_room", "room": {"id": "r2", "type": "corridor", "x": -1, "z": -6, "w": 2, "d": 10}},
		{"op": "add_room", "room": {"id": "r3", "type": "quarters", "x": 1, "z": -6, "w": 4, "d": 4}},
		{"op": "add_room", "room": {"id": "r4", "type": "cargo", "x": -7, "z": -6, "w": 6, "d": 6}},
		{"op": "add_room", "room": {"id": "r5", "type": "engineering", "x": 1, "z": -2, "w": 6, "d": 6}},
		{"op": "add_room", "room": {"id": "r6", "type": "airlock", "x": -1, "z": 4, "w": 3, "d": 2}},
		{"op": "add_door", "door": {"a": "r1", "b": "r2", "x": 0, "z": -6}},
		{"op": "add_door", "door": {"a": "r2", "b": "r3", "x": 1, "z": -4}},
		{"op": "add_door", "door": {"a": "r2", "b": "r4", "x": -1, "z": -2}},
		{"op": "add_door", "door": {"a": "r2", "b": "r5", "x": 1, "z": 1}},
		{"op": "add_door", "door": {"a": "r2", "b": "r6", "x": 0, "z": 4}},
		{"op": "add_door", "door": {"a": "r6", "b": "", "x": 0.5, "z": 6}},
		{"op": "add_component", "component": {"id": "c1", "type": "pilot_console", "room": "r1", "x": 0.5, "z": -9.4, "rot": 2}},
		{"op": "add_component", "component": {"id": "c2", "type": "reactor_small", "room": "r5", "x": 3, "z": 2.5, "rot": 0}},
		{"op": "add_component", "component": {"id": "c3", "type": "main_engine", "room": "r5", "x": 5.6, "z": 2.6, "rot": 0}},
		{"op": "add_component", "component": {"id": "c4", "type": "bunk", "room": "r3", "x": 3.9, "z": -5, "rot": 1}},
		{"op": "add_component", "component": {"id": "c5", "type": "bunk", "room": "r3", "x": 3.9, "z": -3, "rot": 1}},
		{"op": "add_component", "component": {"id": "c6", "type": "life_support", "room": "r5", "x": 2, "z": -1.5, "rot": 2}},
	]
	for op in ops:
		var u := d.apply(op)
		check(not u.is_empty(), "small ship op applies: %s" % [op])
	return d


func run_tests() -> void:
	var d := small_ship()
	var problems := DesignRules.check(d, cat)
	check(DesignRules.errors(problems) == 0, "the small ship has no errors: %s" % [_texts(problems)])
	var t := DesignTotals.compute(d, cat)
	check(t.floor_area == 20 + 20 + 16 + 36 + 36 + 6, "floor area adds up: %s" % t.floor_area)
	check(t.crew == 2 + 4, "two bunks and four quarters berths: %d" % t.crew)
	check(t.cargo_m3 > 80.0, "cargo hold gives space: %.1f" % t.cargo_m3)
	check(t.power_balance() > 0.0, "the reactor covers the load: %.1f" % t.power_balance())
	check(t.thrust == 180.0 and t.acceleration() > 0.0, "the engine gives thrust")
	check(t.lead_days == 6, "the reactor is the longest wait: %d" % t.lead_days)
	var line_cost := 0.0
	for l in t.lines:
		line_cost += l.cost
	check(is_equal_approx(line_cost, t.cost) and t.lines[0].kind == "hull", "the parts list adds up to the cost")
	var fit := t.fit({"cargo_m3": 200.0, "crew": 4, "budget": t.cost + 1.0})
	var by_key := {}
	for f in fit:
		by_key[f.key] = f
	check(not by_key.cargo_m3.ok and by_key.cargo_m3.share < 1.0, "200 m3 of cargo is not met")
	check(by_key.crew.ok and by_key.budget.ok, "crew and budget are met")

	# Break it, one rule at a time.
	_expect(d, {"op": "set_room", "id": "r4", "fields": {"x": -6.0}}, "overlap")
	_expect(d, {"op": "remove_door", "id": "d10"}, "no_route")
	_expect(d, {"op": "remove_door", "id": "d12"}, "no_way_out")
	_expect(d, {"op": "remove_room", "id": "r1"}, "missing_bridge")
	_expect(d, {"op": "remove_component", "id": "c2"}, "power")
	_expect(d, {"op": "set_component", "id": "c1", "fields": {"x": 4.0}}, "outside_room")
	_expect(d, {"op": "set_component", "id": "c5", "fields": {"z": -4.6}}, "parts_overlap")
	_expect(d, {"op": "set_component", "id": "c2", "fields": {"rot": 2, "z": 3.1}}, "no_access")
	_expect(d, {"op": "add_component", "component": {"type": "bunk", "room": "r4", "x": -5, "z": -3}}, "wrong_room")
	_expect(d, {"op": "set_room", "id": "r3", "fields": {"w": 1.5}}, "too_small")
	_expect(d, {"op": "add_door", "door": {"a": "r1", "b": "r4", "x": 0, "z": 0}}, "door_off_wall")
	check(DesignRules.errors(DesignRules.check(d, cat)) == 0, "every break was undone")

	# Stairwells join decks.
	var two := small_ship()
	two.apply({"op": "add_room", "room": {"id": "s0", "type": "stairs", "deck": 0, "x": -3, "z": 0, "w": 2, "d": 4}})
	two.apply({"op": "add_door", "door": {"a": "r2", "b": "s0", "deck": 0, "x": -1, "z": 2}})
	two.apply({"op": "add_room", "room": {"id": "s1", "type": "stairs", "deck": 1, "x": -3, "z": 0, "w": 2, "d": 4}})
	two.apply({"op": "add_room", "room": {"id": "u1", "type": "workshop", "deck": 1, "x": -7, "z": 0, "w": 4, "d": 4}})
	two.apply({"op": "add_door", "door": {"a": "s1", "b": "u1", "deck": 1, "x": -3, "z": 2}})
	var reach := DesignRules.reachable(two, cat)
	check(reach.has("u1"), "a room upstairs is reached by the stairwell")
	two.apply({"op": "set_room", "id": "s1", "fields": {"x": 5.0}})
	check(not DesignRules.reachable(two, cat).has("u1"), "and not once the stairwells no longer line up")

	# Reached the way walk-inside builds her (beenster, 19 Nov): inside a drawn hull the deck
	# round the rooms is floor, so doors out onto it join up there; and a door joins whatever
	# rooms stand either side of it, whichever two it was drawn between.
	var open := small_ship()
	open.apply({"op": "remove_door", "id": "d7"})
	check(not DesignRules.reachable(open, cat).has("r1"), "without its door the bridge is cut off")
	open.apply({"op": "add_door", "door": {"id": "dx", "a": "r1", "b": "r4", "x": 0, "z": -6}})
	check(DesignRules.reachable(open, cat).has("r1"), "a door standing on the bridge's wall to the corridor joins them, drawn between any two")
	open.apply({"op": "remove_door", "id": "dx"})
	open.apply({"op": "add_door", "door": {"id": "dn", "a": "r1", "b": "", "x": 0.5, "z": -10}})
	open.apply({"op": "add_door", "door": {"id": "dw", "a": "r2", "b": "", "x": -1, "z": 2}})
	check(not DesignRules.reachable(open, cat).has("r1"), "with no hull drawn, doors out lead into space")
	open.apply({"op": "set_hull", "deck": 0, "points": [[-9, -12], [9, -12], [9, 8], [-9, 8]]})
	check(DesignRules.reachable(open, cat).has("r1"), "inside a drawn hull the open deck joins the doors onto it")
	check(not DesignRules.check(open, cat).any(func(p): return p.code == "no_route"), "and the check says nothing is cut off")


func _expect(d: DesignRecord, op: Dictionary, code: String) -> void:
	var undo := d.apply(op)
	check(not undo.is_empty(), "%s: the op applies" % code)
	var problems := DesignRules.check(d, cat)
	check(problems.any(func(p): return p.code == code), "%s is flagged: %s" % [code, _texts(problems)])
	d.apply(undo)


func _texts(problems: Array[Dictionary]) -> Array:
	return problems.map(func(p): return "%s: %s" % [p.code, p.text])
