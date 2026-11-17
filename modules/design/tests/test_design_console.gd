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
