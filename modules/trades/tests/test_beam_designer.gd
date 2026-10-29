extends ModuleTest
## trades.beam_designer (beenster, 0.3.27, stage D1 of the beam plan): the design tablet draws a
## hologram of beams round the ship in the courtyard. Drawing a beam end to end, ends snapping to
## another beam's end and to the grid, picking one up and setting it down elsewhere, turning,
## rolling, a new section by the wheel, copying, deleting, undo and redo; a beam through the ship
## or across another is red, an end nothing holds amber; the design kept per ship in the save and
## shared with the crew by one event that refuses a bad design.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var saved := {}
	for flag: String in ["trades.beam_designer"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	# Drawn end to end, the first way (trades.beam_grow, growing out of the ship, is test_beam_grow's).
	saved["trades.beam_grow"] = Flags.is_on("trades.beam_grow")
	Flags.set_flag("trades.beam_grow", false)
	bus.reset_data()

	# The sections.
	check(TradesBeamSections.order().size() == 13, "every stocked section can be drawn: %d" % TradesBeamSections.order().size())
	for id: String in TradesBeamSections.order():
		var m := TradesBeamSections.mesh(id, 2.0)
		check(m.get_surface_count() == 1 and m.get_aabb().size.z > 1.99, "%s builds as a 2 m beam" % TradesBeamSections.name_of(id))
	var bar := StockBeams.item("SteelBox_100x100x5_6000")
	check(absf(TradesBeamSections.mass("box_100x100x5", 6.0) - float(bar.mass)) < 0.1, "a 6 m box weighs as the stock bar: %.1f kg" % float(bar.mass))
	check(TradesBeamSections.normal("box_100") == "box_100x100x5" and TradesBeamSections.has("i_150"), "the first designs' sections still read")

	ship_bus.load_ship("vs_kestrel")
	var yard := _fake_yard()
	var walker := CharacterBody3D.new()
	walker.position = Vector3(3, 0, 12)
	yard.set("walker", walker)
	yard.add_child(walker)
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	check(rig.hotbar.has(&"tablet") and rig.tool_node(&"tablet") is TradesDesignTablet, "the design tablet is on the hotbar")
	if rig.designer == null:
		rig.build_designer()
	var d := rig.designer
	check(d != null, "the designer is in the yard")
	var ship := d.ship_id()
	check(ship != "", "it draws round the ship in the bay: %s" % ship)
	rig.set_tool(&"tablet")
	# Out in the air above the ship, so nothing holds the first beam.
	var y := ship_bus.ship.bounds.end.y + 3.0

	# Drawing a beam: a click at each end.
	d.start = Vector3(-1, y, 0)
	d.aim_point = Vector3(1, y, 0)
	d.click(true)
	var list := d.beams()
	check(list.size() == 1 and ((list[0].b as Vector3) - (list[0].a as Vector3)).length() > 1.99, "two clicks draw a 2 m beam")
	check(bus.beam_design(ship).size() == 1, "the design is kept for the ship")
	var first := int(list[0].id)
	# Snapping: a point near its end goes to the end; elsewhere to the 50 mm grid.
	var s := d.snap(Vector3(1.1, y + 0.05, 0.08))
	check(s[1] == "end" and (s[0] as Vector3).is_equal_approx(Vector3(1, y, 0)), "a point near its end snaps onto it")
	s = d.snap(Vector3(0.123, y + 1.0, 0.471))
	check(s[1] == "grid" and (s[0] as Vector3).is_equal_approx(Vector3(0.1, snappedf(y + 1.0, 0.05), 0.45)), "elsewhere to the grid: %s" % s[0])
	# A second beam up from its end: they meet.
	var up := d.add_beam(Vector3(1, y, 0), Vector3(1, y + 1.5, 0))
	check(up >= 0 and d.beams().size() == 2, "a second beam from its end")
	d.run_checks()
	check(d.clashes.is_empty(), "beams meeting at an end don't clash")
	var loose := d.loose_ends.map(func(e: Array) -> String: return "%d/%d" % e)
	check(loose.has("%d/0" % first) and loose.has("%d/1" % up) and not loose.has("%d/1" % first) and not loose.has("%d/0" % up),
			"the free ends are amber, the joined ones held: %s" % [loose])
	# One across the first's middle clashes.
	var cross := d.add_beam(Vector3(0, y, -1), Vector3(0, y, 1))
	d.run_checks()
	check(d.clashes.has(cross) and d.clashes.has(first), "a beam across another's middle is red")
	d.delete_beam(cross)
	check(d.beam(cross).is_empty() and d.beams().size() == 2, "right click on it deletes it")
	# Undo brings it back, redo takes it away again.
	check(d.undo() and not d.beam(cross).is_empty(), "undo brings it back")
	check(d.redo() and d.beam(cross).is_empty(), "redo takes it away")
	# Through the ship: a stand-in block where the ship is.
	var block := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 2)
	shape.shape = box
	block.add_child(shape)
	add_child(block)
	block.global_position = rig.ship_transform() * Vector3(0, y + 6.0, 0)
	await physics_frames(2)
	var through := d.add_beam(Vector3(-2, y + 6.0, 0), Vector3(2, y + 6.0, 0))
	d.run_checks()
	check(d.clashes.get(through, "") == "ship", "a beam through the ship is red")
	var resting := d.add_beam(Vector3(1.0 + 0.05, y + 6.0, 0), Vector3(3, y + 6.0, 0))
	d.run_checks()
	check(not d.clashes.has(resting) and not d.loose_ends.any(func(e: Array) -> bool: return e[0] == resting and e[1] == 0),
			"one ending on another beam is held there and doesn't clash")
	d.delete_beam(through)
	d.run_checks()
	check(d.loose_ends.any(func(e: Array) -> bool: return e[0] == resting and e[1] == 0),
			"resting on something that isn't the ship's frame doesn't hold it")
	d.delete_beam(resting)
	block.queue_free()

	# Turning and rolling.
	d.turn_beam(first, 90.0)
	var t := d.beam(first)
	check(absf(((t.b as Vector3) - (t.a as Vector3)).normalized().dot(Vector3.FORWARD)) > 0.99, "Q/E turns it about the upright")
	d.hovered = first
	d.key(TradesBus.KEY_TURN_RIGHT)
	t = d.beam(first)
	check(absf(((t.b as Vector3) - (t.a as Vector3)).normalized().dot(Vector3.FORWARD)) < 0.99, "the key turns it 15 degrees")
	d.turn_beam(first, 45.0, true)
	check(is_equal_approx(float(d.beam(first).turn), 45.0), "Shift rolls it about its length")
	# The wheel on a beam changes its section.
	check(d.wheel(1) and str(d.beam(first).section) == TradesBeamSections.step(TradesBeamSections.DEFAULT, 1), "the wheel on it changes its section")
	# Picking up and setting down elsewhere: only shared when it is set down.
	d.pick_up(first)
	var was: Vector3 = d.beam(first).a
	d.edit_beam(first, {"a": was + Vector3(0, 0, 2), "b": (d.beam(first).b as Vector3) + Vector3(0, 0, 2)}, false)
	check(((bus.beam_design(ship).filter(func(r: Dictionary) -> bool: return int(r.id) == first)[0] as Dictionary).a as Array)[2] == snappedf(was.z, 0.001),
			"while moving, the design isn't changed yet")
	d.set_down()
	check(d.grabbed < 0 and (d.beam(first).a as Vector3).is_equal_approx(was + Vector3(0, 0, 2)), "setting it down moves it")
	check(d.undo() and (d.beam(first).a as Vector3).is_equal_approx(was), "undo puts it back")
	# Cancelling a move puts it back with nothing to undo.
	var undos := d._undo.size()
	d.pick_up(first)
	d.edit_beam(first, {"a": was + Vector3.ONE}, false)
	d.click(false)
	check((d.beam(first).a as Vector3).is_equal_approx(was) and d._undo.size() == undos, "right click cancels a move")
	# Copying: G on a beam copies it and picks the copy up.
	d.grabbed = -1
	d.hovered = first
	var n := d.beams().size()
	check(d.key(TradesBus.KEY_NEXT), "G copies the beam")
	d.hovered = -1
	d._aim()
	check(d.beams().size() == n + 1 and d.grabbed >= 0 and d.grabbed != first, "the copy is picked up")
	d.set_down()

	# The screen and the panel.
	rig._process(0.0)
	d._physics_process(0.0)
	var card := HudSlots.infos().filter(func(c: Dictionary) -> bool: return c.id == TradesBeamDesigner.INFO)
	check(card.size() == 1 and str(card[0].text).contains("beams"), "the right-hand panel shows the design: %s" % [card])
	check((rig.tool_node(&"tablet") as TradesDesignTablet).readout_text().contains("BEAMS"), "the tablet's screen counts the beams")
	check(d.get_node("Hologram").get_children().filter(func(c: Node) -> bool: return c.name.begins_with("Beam_")).size() == d.beams().size(),
			"each beam is drawn in the hologram")

	# Shared: the event refuses a bad design.
	check(d._validate(2, {"ship": ship, "rows": [{"a": [0, 0, 0], "b": [0, 0, 0.01], "section": "box_100x100x5"}]}) is String, "a beam too short is refused")
	check(d._validate(2, {"ship": ship, "rows": [{"a": [0, 0, 0], "b": [0, 0, 2], "section": "nope"}]}) is String, "an unknown section is refused")
	check(d._validate(2, {"ship": ship, "rows": [{"a": [0, 0, 0], "b": [0, 0, 2], "section": "box_100x100x5"}]}) is Dictionary, "a good one is taken")
	# Kept in the save, gone with a new game; the tracer's snapshot leaves it alone.
	var count := d.beams().size()
	bus.load_data({"templates": []}, bus.save_version())
	check(d.beams().size() == count, "the scribe's snapshot leaves the design alone")
	var data := bus.save_data()
	bus.reset_data()
	check(d.beams().is_empty(), "a new game has no design")
	bus.load_data(JSON.parse_string(JSON.stringify(data)), bus.save_version())
	check(d.beams().size() == count, "the design comes back from the save")
	# Put away, the tablet stops drawing.
	rig.set_tool(&"hands")
	d._physics_process(0.0)
	check(HudSlots.infos().all(func(c: Dictionary) -> bool: return c.id != TradesBeamDesigner.INFO), "put away, its panel goes")

	bus.reset_data()
	yard.queue_free()
	await frames(2)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _fake_yard() -> Node3D:
	var script := GDScript.new()
	script.source_code = FAKE_YARD
	script.reload()
	var n := Node3D.new()
	n.set_script(script)
	return n
