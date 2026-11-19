extends ModuleTest
## Design Room: the plan editor places, moves, resizes and connects rooms and drops
## components with the mouse; the holotable builds its layers from the same record; the
## console's saves work.
##   tools/run_tests.sh design

const PlanView := preload("res://modules/design/internal/views/plan_view.gd")
const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")
const DesignConsole := preload("res://modules/design/internal/console/design_console.gd")
const Samples := preload("res://modules/design/internal/sample_designs.gd")


func run_tests() -> void:
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	var holo := HoloTable.new()
	add_child(holo)
	holo.setup(bus)
	var layer := CanvasLayer.new()
	add_child(layer)
	var console := DesignConsole.new()
	layer.add_child(console)
	console.setup(bus, holo)
	await frames(3)
	check(bus.library.current != null and bus.library.list().size() == 1, "the console opens a first design")
	var plan: PlanView = console.plan
	plan.size = Vector2(1000, 700)
	plan.zoom = 20.0
	plan.centre = Vector2.ZERO
	var rec := bus.library.current

	# Drag out a 6 x 4 m bridge from (-3, -8) to (3, -4).
	plan.set_tool("room:bridge")
	_drag(plan, Vector2(-3, -8), Vector2(3, -4))
	check(rec.rooms.size() == 1, "dragging with a room tool places a room")
	var bridge: Dictionary = rec.rooms.values()[0]
	check(is_equal_approx(float(bridge.w), 6.0) and is_equal_approx(float(bridge.d), 4.0) and bridge.type == "bridge",
			"the room is the dragged size: %s" % [bridge])
	check(plan.tool == "select" and plan.selected_id == bridge.id, "placing selects the room and goes back to select")

	# A click places a corridor at its usual size (2 x 6), centred on the click, snapped.
	plan.set_tool("room:corridor")
	_drag(plan, Vector2(0, -1), Vector2(0, -1))
	var corridor: Dictionary = rec.rooms[plan.selected_id]
	check(float(corridor.w) == 2.0 and float(corridor.d) == 6.0 and float(corridor.x) == -1.0 and float(corridor.z) == -4.0,
			"a click places the usual size: %s" % [corridor])

	# Drag the corridor's bottom edge down 2 m: it grows to 8 m.
	plan.set_tool("select")
	_drag(plan, Vector2(0, 2), Vector2(0, 4))
	check(float(corridor.d) == 8.0 and float(corridor.z) == -4.0, "dragging an edge resizes: %s" % [corridor])
	# Drag its middle 1 m right and back: moves.
	_drag(plan, Vector2(0, 0), Vector2(1, 0))
	check(float(corridor.x) == 0.0, "dragging the middle moves: %s" % [corridor])
	_drag(plan, Vector2(1, 0), Vector2(0, 0))

	# A door on the shared wall at z = -4.
	plan.set_tool("door")
	_drag(plan, Vector2(0.2, -4.1), Vector2(0.2, -4.1))
	check(rec.doors.size() == 1, "the door tool puts a door on the nearest wall")
	var door: Dictionary = rec.doors.values()[0]
	check(door.b != "" and door.a != door.b, "between the two rooms: %s" % [door])
	check(not bus.problems().any(func(p): return p.code == "door_off_wall"), "and it fits the wall")

	# A pilot console in the bridge, turned twice.
	plan.set_tool("part:pilot_console")
	plan.rotate_selected()
	plan.rotate_selected()
	_drag(plan, Vector2(0, -7), Vector2(0, -7))
	check(rec.components.size() == 1 and int(rec.components.values()[0].rot) == 2,
			"a component goes in the room under the click, turned: %s" % [rec.components])
	plan.set_tool("select")
	plan.select("part", rec.components.keys()[0])
	plan.delete_selected()
	check(rec.components.is_empty(), "Delete removes the selected component")
	check(bus.editor.undo() and rec.components.size() == 1, "undo brings it back")

	# Moving a room takes its components along.
	var comp: Dictionary = rec.components.values()[0]
	var bz := float(comp.z)
	_drag(plan, Vector2(-2.5, -7.5), Vector2(-2.5, -9.5))
	check(float(rec.rooms[bridge.id].z) == -10.0 and is_equal_approx(float(comp.z), bz - 2.0),
			"the console moves with its room: %s" % [comp])
	bus.editor.undo()
	check(float(rec.rooms[bridge.id].z) == -8.0 and is_equal_approx(float(comp.z), bz), "one undo puts both back")

	# The holotable builds every layer from the record.
	await frames(2)
	Samples.skiff(rec)
	await frames(2)
	var ship := holo.model.get_node_or_null("Ship")
	check(ship != null, "the holotable shows the design")
	if ship:
		for l in HoloTable.LAYERS:
			check(ship.get_node_or_null(l.capitalize()) != null, "layer %s is built" % l)
		holo.set_layer("rooms", false)
		check(not ship.get_node("Rooms").visible, "a layer switches off")
		holo.set_layer("rooms", true)
	holo.set_cut(0.5)
	await frames(1)
	check(holo._cut_y < 50.0, "the cutting plane comes down")

	# Wires and pipes: draw one by clicking points, route the rest, swap the hull.
	plan.set_deck(0)
	var runs_before := rec.runs.size()
	plan.set_tool("run:wire")
	plan._press(plan.to_screen(Vector2(3, 2.5)))
	plan._press(plan.to_screen(Vector2(5.6, 2.4)))
	plan._finish_run()
	check(rec.runs.size() == runs_before + 1 and plan.selected_kind == "run", "clicking points draws a wire")
	var w: Dictionary = rec.runs[plan.selected_id]
	check(w.points.size() == 2 and is_equal_approx(float(w.points[1][1]), 2.5), "its legs keep square: %s" % [w.points])
	check(DesignServices.connected(rec, bus.catalog, "wire").components.has("c3"), "it powers the engine")
	plan.set_tool("run:wire")
	plan._press(plan.to_screen(Vector2(0, 0)))
	check(plan.cancel() and rec.runs.size() == runs_before + 1, "Esc drops a half-drawn run")
	check(plan.cancel() and plan.tool == "select" and not plan.cancel(), "then puts the tool down, then nothing")
	var added := console.route_all("fuel")
	check(added > 0 and DesignServices.cut_off(rec, bus.catalog, "fuel").is_empty() and holo.layers.pipes,
			"ROUTE ALL lays fuel lines to every engine and shows the pipes layer (%d runs)" % added)
	bus.editor.undo()
	check(not DesignServices.cut_off(rec, bus.catalog, "fuel").is_empty(), "one undo takes the whole route away")
	var hull_b := console.find_child("Structure_hull", true, false) as Button
	# Worked out once per edit and shared by every view (co-op lag, 19 Nov).
	check(bus.totals() == bus.totals() and bus.frame_plan() == bus.frame_plan(), "totals and the frame are kept between edits")
	var kept := bus.totals()
	var cost0 := bus.totals().cost
	hull_b.pressed.emit()
	check(rec.structure.hull == "armoured" and bus.totals().cost > cost0 and hull_b.text.contains("ARMOURED"),
			"the hull button swaps the plating and the cost goes up: %s" % hull_b.text)
	check(bus.totals() != kept, "and an edit works them out again")

	# Ready-made modules: save the mess with its galley, drop copies on the plan.
	var mess_id := ""
	for r: Dictionary in rec.rooms.values():
		if r.type == "mess":
			mess_id = r.id
	var mid := bus.library.save_module("Crew mess", mess_id)
	check(mid != "" and bus.library.modules().size() == 1 and (bus.library.module(mid).components as Array).size() == 1,
			"a room saves as a module with its parts")
	check(console.find_child("Module_" + mid, true, false) != null, "the module shows in the palette")
	check(bus.library.save_module("Crew mess", mess_id) != mid and bus.library.modules()[1].name == "Crew mess 2",
			"a second save under the same name gets a number")
	bus.library.remove_module(bus.library.modules()[1].id)
	var rooms_before := rec.rooms.size()
	var parts_before := rec.components.size()
	(console.find_child("Module_" + mid, true, false) as Button).pressed.emit()
	check(bus.carrying == mid, "pressing it picks the module up")
	plan.set_deck(0)
	plan._press(plan.to_screen(Vector2(20, 0)))
	check(rec.rooms.size() == rooms_before + 1 and rec.components.size() == parts_before + 1 and bus.carrying == "",
			"a click drops the room and its galley and puts the module down")
	var dropped: Dictionary = rec.rooms[plan.selected_id]
	check(dropped.type == "mess" and int(dropped.deck) == 0 and absf(float(dropped.x) + float(dropped.w) * 0.5 - 20.0) <= 0.5,
			"centred on the click, on the plan's deck: %s" % [dropped])
	bus.editor.undo()
	check(rec.rooms.size() == rooms_before and rec.components.size() == parts_before, "one undo takes the whole module away")
	bus.carry(mid)
	check(plan.cancel() and bus.carrying == "", "Esc puts a carried module down")
	var saved := bus.library.save_data()
	bus.library.load_data(JSON.parse_string(JSON.stringify(saved)), DesignLibrary.SAVE_VERSION)
	check(bus.library.modules().size() == 1 and bus.library.module(mid).name == "Crew mess", "modules are kept in the save")
	rec = bus.library.current

	# R turns a room a quarter about its middle.
	plan.set_deck(0)
	plan.set_tool("room:cargo")
	_drag(plan, Vector2(20, 0), Vector2(26, 2))
	var tid := plan.selected_id
	var tr: Dictionary = rec.rooms[tid]
	check(is_equal_approx(float(tr.w), 6.0) and is_equal_approx(float(tr.d), 2.0), "a 6 x 2 m room to turn")
	plan.rotate_selected()
	check(is_equal_approx(float(tr.w), 2.0) and is_equal_approx(float(tr.d), 6.0) and is_equal_approx(float(tr.x) + 1.0, 23.0),
			"R turns the room a quarter about its middle: %s" % [tr])
	bus.editor.undo()
	bus.editor.undo()

	# Drawing in the side elevation: along the ship and up the decks.
	console._set_view("side")
	plan.size = Vector2(1000, 700)
	plan.zoom = 20.0
	plan.centre = Vector2(10, -3)
	plan.set_tool("room:cargo")
	var n0 := rec.rooms.size()
	_drag(plan, Vector2(10, -1.5), Vector2(14, -1.5))
	var sid := plan.selected_id
	var sr: Dictionary = rec.rooms.get(sid, {})
	check(rec.rooms.size() == n0 + 1 and int(sr.get("deck", -1)) == 0 and is_equal_approx(float(sr.get("z", 0)), 10.0)
			and is_equal_approx(float(sr.get("d", 0)), 4.0), "a room drawn in the side elevation: %s" % [sr])
	_drag(plan, Vector2(12, -1.5), Vector2(16, -4.5))
	check(int(sr.deck) == 1 and is_equal_approx(float(sr.z), 14.0), "dragged up a deck and aft in the side view: %s" % [sr])
	console._set_view("end")
	plan.zoom = 20.0
	plan.centre = Vector2(0, -3)
	plan.set_tool("room:cargo")
	_drag(plan, Vector2(-6, -1.5), Vector2(-2, -1.5))
	var er: Dictionary = rec.rooms.get(plan.selected_id, {})
	check(is_equal_approx(float(er.get("x", 0)), -6.0) and is_equal_approx(float(er.get("w", 0)), 4.0), "and in the end elevation: %s" % [er])
	for i in 3:
		bus.editor.undo()
	check(rec.rooms.size() == n0, "undo takes them back")
	# A stairwell stretched up two decks by its top edge in the side view, then back.
	console._set_view("side")
	plan.zoom = 20.0
	plan.centre = Vector2(30, -4)
	bus.editor.do({"op": "add_room", "room": {"type": "stairs", "deck": 0, "x": 30, "z": 30, "w": 2, "d": 4}})
	var stid := plan._newest(rec.rooms)
	plan.set_tool("select")
	_drag(plan, Vector2(32, -rec.deck_height), Vector2(32, -rec.deck_height * 2.5))
	var flights: Array = rec.rooms.values().filter(func(r): return str(r.type) == "stairs" and is_equal_approx(float(r.z), 30.0))
	check(flights.size() == 3 and flights.map(func(r): return int(r.deck)).max() == 2,
			"dragging a stairwell's top edge up stacks it on the decks above: %d" % flights.size())
	_drag(plan, Vector2(32, -rec.deck_height * 3), Vector2(32, -rec.deck_height * 1.5))
	flights = rec.rooms.values().filter(func(r): return str(r.type) == "stairs" and is_equal_approx(float(r.z), 30.0))
	check(flights.size() == 2, "and dragging it back down takes the top one off: %d" % flights.size())
	bus.editor.undo()
	bus.editor.undo()
	bus.editor.undo()
	check(not rec.rooms.has(stid) and rec.rooms.size() == n0, "undo clears the stairwell")
	console._set_view("plan")
	plan.size = Vector2(1000, 700)
	plan.zoom = 20.0
	plan.centre = Vector2.ZERO
	check(console._holo_cam.cull_mask == HoloTable.VIEW_LAYER, "the console's 3D view shows the hologram alone")

	# DECK - on the lowest deck adds a deck under it: everything moves up one.
	var low_before: Array = rec.rooms.values().map(func(r): return int(r.deck))
	plan.set_deck(0)
	console._change_deck(-1)
	var low_after: Array = rec.rooms.values().map(func(r): return int(r.deck))
	check(plan.deck == 0 and rec.rooms_on(0).is_empty() and low_after == low_before.map(func(v): return v + 1),
			"DECK - below the lowest deck adds a new empty deck under it")
	plan.set_tool("room:cargo")
	_drag(plan, Vector2(-3, -2), Vector2(3, 2))
	check(rec.rooms_on(0).size() == 1, "and you can draw rooms on it")
	bus.editor.undo()
	bus.editor.undo()
	check(rec.rooms.values().map(func(r): return int(r.deck)) == low_before, "undo takes the new deck back out")
	plan.set_tool("select")

	# Saves through the console.
	console._on_save()
	check(not bus.library.dirty, "save stores the design")
	console._on_save_as()
	check(bus.library.list().size() == 2 and bus.library.current.name.ends_with("Mk2"), "save as makes a copy")
	console._on_new()
	check(bus.library.list().size() == 3 and bus.library.current.rooms.is_empty(), "new starts an empty design")
	console._toggle_library()
	check(console._library_panel.visible, "the designs list opens")


func _drag(plan: PlanView, from: Vector2, to: Vector2) -> void:
	plan._press(plan.to_screen(from))
	plan._drag_move(plan.to_screen(to))
	plan._release(plan.to_screen(to))
