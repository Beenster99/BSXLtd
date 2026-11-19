extends ModuleTest
## Moving parts: every moving part has a motion (doors by kind, ramps, hatches, legs, cranes,
## turrets), its swept volume finds what it hits (a hinged door's leaf on a locker, a crane's
## boom through its room's wall, a sliding door with no wall to slide into), clashes and ground
## problems reach WILL IT WORK, SET HER DOWN stands her on her legs (loads add up to her mass,
## level on a flat pad, clearance, tipping, too few legs), and OPERATE plays on the holotable
## and walk-inside and on the MOVING PARTS wall, shared with the crew.
##   tools/run_tests.sh motion

func run_tests() -> void:
	var design := Modules.bus("design") as DesignBus
	var bus := Modules.bus("motion") as MotionBus
	check(design != null and bus != null, "the design and motion modules are loaded")
	if design == null or bus == null:
		return
	var cat := design.catalog
	_table(cat)
	_cycle()
	_clashes(cat)
	_ground(cat)
	await _views(design, bus)


func _table(cat: DesignCatalog) -> void:
	var gear := MotionTable.spec(cat.part("landing_gear"))
	check(str(gear.get("kind", "")) == "leg" and float(gear.load_kg) > 0.0, "landing gear is a leg with a rated load: %s" % [gear])
	var ramp := MotionTable.spec(cat.part("cargo_ramp"))
	check(str(ramp.get("kind", "")) == "hinge_out" and (ramp.open as Vector2).x > 2.0, "a cargo ramp hinges out and opens a way: %s" % [ramp])
	check(MotionTable.spec(cat.part("crane_hoist")).get("kind", "") == "spin", "a crane slews")
	check(MotionTable.spec(cat.part("locker")).is_empty(), "a locker doesn't move")
	var big := MotionTable.spec(cat.part("landing_gear:5S"))
	check(big.is_empty() or float(big.load_kg) > float(gear.load_kg), "a bigger leg carries more")
	var hinged := MotionTable.door_spec({"kind": "hinged"})
	check(str(hinged.kind) == "door_swing" and float(hinged.seconds) > 0.0, "a hinged door swings")
	check(MotionTable.door_spec({"kind": "doorway"}).is_empty(), "an open doorway has nothing to move")


func _cycle() -> void:
	check(MotionBus.cycle_phase(4.0, 0.0) == 0.0, "the loop starts stowed")
	check(is_equal_approx(MotionBus.cycle_phase(4.0, 4.5), 1.0), "it holds open")
	check(MotionBus.cycle_phase(4.0, 2.0) > 0.3 and MotionBus.cycle_phase(4.0, 2.0) < 0.7, "halfway out at half its time")
	check(MotionBus.cycle_phase(4.0, 9.5) < 0.01, "back stowed after its round")


static func _two_rooms(door_kind: String, wall_d: float = 4.0) -> DesignRecord:
	var rec := DesignRecord.new("t", "Test")
	rec.apply({"op": "add_room", "room": {"id": "r1", "type": "quarters", "deck": 0, "x": 0, "z": 0, "w": 4, "d": wall_d}})
	rec.apply({"op": "add_room", "room": {"id": "r2", "type": "corridor", "deck": 0, "x": 4, "z": 0, "w": 3, "d": wall_d}})
	rec.apply({"op": "add_door", "door": {"id": "d1", "a": "r1", "b": "r2", "deck": 0, "x": 4, "z": minf(2.0, wall_d * 0.5), "kind": door_kind}})
	return rec


func _clashes(cat: DesignCatalog) -> void:
	# A hinged door swings into room a: a locker just inside is in its way.
	var rec := _two_rooms("hinged")
	rec.apply({"op": "add_component", "component": {"id": "c1", "type": "locker", "room": "r1", "x": 3.5, "z": 1.7}})
	var movers := MotionMovers.list(rec, cat)
	check(movers.size() == 1 and movers[0].id == "door:d1", "the hinged door is the one mover: %s" % [movers.map(func(m): return m.id)])
	var found := MotionCheck.clashes(rec, cat)
	var hits: Array = found.get("door:d1", [])
	check(hits.size() == 1 and str(hits[0].text).contains("Locker"), "its leaf hits the locker as it swings: %s" % [hits])
	rec.apply({"op": "set_component", "id": "c1", "fields": {"x": 0.6, "z": 0.6}})
	check(MotionCheck.clashes(rec, cat).is_empty(), "moved into the far corner, the door swings clear")
	# Open, its leaf stands across the room, square to the wall.
	var open := MotionMovers.pieces(movers[0], 1.0)
	var leaf: Transform3D = open[0].xf
	check(leaf.origin.x < 4.0 - 0.3, "open, the leaf stands inside room a: %s" % [leaf.origin])

	# A sliding door in a short stretch of wall has nowhere to slide (both rooms 1.6 m deep).
	var short := _two_rooms("door", 1.6)
	var pocket: Array = MotionCheck.clashes(short, cat).get("door:d1", [])
	check(pocket.size() == 1 and pocket[0].what == "pocket", "a sliding door in 1.6 m of wall has no pocket: %s" % [pocket])
	check(MotionCheck.clashes(_two_rooms("door"), cat).is_empty(), "in 4 m of wall it slides clear")
	var longer := _two_rooms("door", 1.6)
	longer.apply({"op": "set_room", "id": "r1", "fields": {"z": -2, "d": 6}})
	check(MotionCheck.clashes(longer, cat).is_empty(), "room a's wall running on past the corridor takes the leaf")

	# A crane's boom slews through the wall of a small room.
	var small := DesignRecord.new("s", "Small")
	small.apply({"op": "add_room", "room": {"id": "r1", "type": "workshop", "deck": 0, "x": 0, "z": 0, "w": 3, "d": 3}})
	small.apply({"op": "add_component", "component": {"id": "c1", "type": "crane_hoist", "room": "r1", "x": 1.5, "z": 1.5}})
	var crane: Array = MotionCheck.clashes(small, cat).get("component:c1", [])
	check(crane.size() >= 1 and crane[0].what == "room", "the crane's boom goes through the wall: %s" % [crane])
	small.apply({"op": "set_room", "id": "r1", "fields": {"x": -3, "z": -3, "w": 9, "d": 9}})
	check(MotionCheck.clashes(small, cat).is_empty(), "in a big room it slews clear")

	var probs := MotionCheck.problems(rec, cat, {"door:d1": [{"what": "part", "id": "component:c1", "text": "x"}]})
	check(probs.size() == 1 and probs[0].severity == DesignRules.ERROR and "c1" in probs[0].components and "d1" in probs[0].doors,
			"a clash is a WILL IT WORK error naming both: %s" % [probs])


## A 12 x 8 m box of a ship with a hold, legs at its four corners on the hull.
static func _lander(legs: int) -> DesignRecord:
	var rec := DesignRecord.new("l", "Lander")
	rec.apply({"op": "add_room", "room": {"id": "r1", "type": "cargo", "deck": 0, "x": -4, "z": -6, "w": 8, "d": 8}})
	rec.apply({"op": "add_room", "room": {"id": "r2", "type": "bridge", "deck": 0, "x": -2, "z": 2, "w": 4, "d": 4}})
	var spots := [[-4, -5, PI], [4, -5, 0.0], [-4, 1, PI], [4, 1, 0.0]]
	for i in legs:
		var s: Array = spots[i]
		rec.apply({"op": "add_mount", "mount": {"id": "m%d" % (i + 1), "type": "landing_gear", "deck": 0, "x": s[0], "z": s[1], "angle": s[2]}})
	return rec


func _ground(cat: DesignCatalog) -> void:
	var rec := _lander(4)
	var t := DesignTotals.compute(rec, cat)
	var g := MotionGround.check(rec, cat, t)
	check(int(g.legs) == 4 and g.cases.size() == 4, "four legs, four cases (flat and rough, empty and full): %d" % g.cases.size())
	var flat: Dictionary = g.cases[0]
	var sum := 0.0
	for kg in flat.loads:
		sum += float(kg)
	check(absf(sum - float(flat.mass)) < 1.0, "the feet carry all of her: %.0f of %.0f kg" % [sum, float(flat.mass)])
	check(bool(flat.level) and float(flat.tip_deg) > 0.0, "on a flat pad she stands level and inside her feet: %s" % [flat.tip_deg])
	check(float(flat.clearance) > 0.0, "there is room under her belly: %.2f m" % float(flat.clearance))
	var full: Dictionary = g.cases[1]
	check(float(full.mass) >= float(flat.mass), "a full hold weighs more: %.0f >= %.0f" % [float(full.mass), float(flat.mass)])
	# Every leg deploys clear of the hull parts next to it.
	check(MotionCheck.clashes(rec, cat).is_empty(), "the legs deploy clear: %s" % [MotionCheck.clashes(rec, cat)])
	var feet: Array = g.feet
	check(float(feet[0].at.y) < -0.5, "a deployed foot reaches below her belly: %.2f" % float(feet[0].at.y))
	var two := MotionGround.check(_lander(2), cat, DesignTotals.compute(_lander(2), cat))
	check(two.cases.is_empty() and two.problems.size() == 1 and two.problems[0].severity == DesignRules.ERROR,
			"two legs can't stand her: %s" % [two.problems])
	var rough := MotionGround.ground("rough", 3.0, 1.0)
	check(rough != 0.0 and MotionGround.ground("flat", 3.0, 1.0) == 0.0, "rough ground isn't flat")


func _views(design: DesignBus, bus: MotionBus) -> void:
	design.library.reset_data()
	var rec := design.library.create("Hinge test")
	for op in [
		{"op": "add_room", "room": {"id": "r1", "type": "quarters", "deck": 0, "x": 0, "z": 0, "w": 4, "d": 4}},
		{"op": "add_room", "room": {"id": "r2", "type": "corridor", "deck": 0, "x": 4, "z": 0, "w": 3, "d": 4}},
		{"op": "add_door", "door": {"id": "d1", "a": "r1", "b": "r2", "deck": 0, "x": 4, "z": 2, "kind": "hinged"}},
		{"op": "add_component", "component": {"id": "c1", "type": "locker", "room": "r1", "x": 3.5, "z": 1.7}},
	]:
		design.editor.do(op)
	var probs := design.problems().filter(func(p): return str(p.code) == "motion.clash")
	check(probs.size() == 1, "the clash is on WILL IT WORK: %s" % [probs])
	design.editor.do({"op": "set_component", "id": "c1", "fields": {"x": 0.6, "z": 0.6}})
	check(design.problems().filter(func(p): return str(p.code) == "motion.clash").is_empty(), "and goes when the locker moves")
	check(bus.report().movers.size() == 1, "the bus reports the open design's movers")

	# The console's OPERATE (a tool on the design bus), the holotable playing it.
	check(design.console_tools.has("motion.operate") and str(design.console_tools["motion.operate"].label) == "OPERATE",
			"the console has OPERATE")
	check(design.console_tools.has("motion.ground"), "and SET HER DOWN")
	var room := Node3D.new()
	add_child(room)
	var ship := Node3D.new()
	ship.name = "Ship"
	room.add_child(ship)
	design.holo_built.emit(room, ship)
	var holo := room.find_child("MotionOperate", true, false) as Node3D
	check(holo != null and holo.get_parent().name == "Ship", "the holotable has the moving parts under its ship")
	(design.console_tools["motion.operate"].press as Callable).call()
	await frames(2)
	check(bus.operating, "OPERATE plays them")
	holo = room.find_child("MotionOperate", true, false) as Node3D
	var piece := holo.find_child("leaf", true, false) as MeshInstance3D if holo else null
	check(piece != null and piece.visible, "the door's leaf shows")
	var before := piece.transform if piece else Transform3D()
	bus.started_msec -= 1000
	await frames(2)
	check(piece != null and not piece.transform.is_equal_approx(before), "and moves")
	var sweep := holo.find_child("Sweep", true, false) as Node3D if holo else null
	check(sweep != null and sweep.visible and sweep.get_child_count() > 3, "its swept volume glows")
	bus.set_operating(false)
	check(not bus.operating and not sweep.visible, "pressed again, it stops")

	# Walk-inside gets the same at full size.
	var root := Node3D.new()
	add_child(root)
	design.walk_built.emit(root, null)
	var walk := root.get_node_or_null("MotionWalk")
	check(walk != null and walk.find_child("Sweep", true, false) != null and walk.find_child("TestBlock", true, false) != null, "walk-inside gets the swept volume and a test block at full size")

	# The wall panel.
	var wall := bus.make_wall(150.0)
	add_child(wall)
	await frames(2)
	check(wall.find_child("BtnOperate", true, false) != null, "the MOVING PARTS wall has OPERATE")
	var text := _all_text(wall)
	check(text.contains("Hinged door") and text.contains("SET HER DOWN") and text.contains("THROUGH THE OPENINGS"),
			"it lists the door, the openings and the ground check")
	bus.set_grounded(true)
	check(bus.grounded, "SET HER DOWN is on")
	bus.set_grounded(false)
	bus.set_pad("rough", false)
	check(bus.pad == "rough" and not bus.full_hold, "the pad and hold can be picked")
	bus.set_pad("flat", true)
	var cyc := bus.cycle()
	check(cyc.parts.size() == 1 and bool(cyc.parts[0].clear), "a surveyor's cycle runs every part: %s" % [cyc.parts])
	room.queue_free()
	root.queue_free()
	wall.queue_free()


func _all_text(n: Node) -> String:
	var s := ""
	if n is Label:
		s += (n as Label).text + "\n"
	elif n is Button:
		s += (n as Button).text + "\n"
	for c in n.get_children():
		s += _all_text(c)
	return s
