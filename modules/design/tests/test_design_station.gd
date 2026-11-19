extends ModuleTest
## Design Room in the orbital yard's station: the holotable, the interactive walls and the console go into the
## station's design room on its wall planes, and using the table opens the console.
##   tools/run_tests.sh design

const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")


func run_tests() -> void:
	var bus := Modules.bus("design") as DesignBus
	for f: String in [YardBus.FLAG, YardBus.STATION]:
		Flags.set_flag(f, true)
	var yard := Modules.bus("yard") as YardBus
	if yard == null:
		yard = YardBus.new()
		yard.name = "yard"
		Modules.add_child(yard)
		yard.register_module()
	if not yard.station_ready.is_connected(bus.furnish_station):
		yard.station_ready.connect(bus.furnish_station)
	var station := (load(YardBus.SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child(station)
	await frames(5)
	var root := yard.design_room_root()
	check(root != null, "the station has a design room")
	if root == null:
		return
	var f := root.get_node_or_null("DesignFurnishing")
	check(f != null, "the design room is furnished")
	if f == null:
		return
	# The walls themselves are the screens (beenster, 18 Nov), one per wall plane.
	var walls: Dictionary = f.get("walls")
	var planes := {}
	for w in bus.room_walls():
		planes[w.id] = w
	check(walls.size() == planes.size() and walls.size() >= 4, "every wall plane is a screen: %s" % [walls.keys()])
	for id: String in ["wall_left", "wall_right"]:
		check(walls.has(id), "%s is a screen" % id)
	for id: String in walls:
		var screen: Node3D = walls[id]
		var plane: Transform3D = planes[id].transform
		check(screen.position.distance_to(plane.origin) < 0.1, "%s covers its plane" % id)
		# The screen's face (+Z) points into the room, the way the plane's -Z does.
		check(screen.basis.z.dot(-plane.basis.z) > 0.99, "%s faces into the room" % id)
		var sz: Vector2 = planes[id].size
		check(is_equal_approx((screen.get("size_m") as Vector2).x, sz.x), "%s spans the whole wall (%.1f m)" % [id, sz.x])
	var board: Node = (walls["wall_left"] as Node).get("content")
	var first := str(board.get("panels")[0].view)
	board.call("step", 0, 1)
	var second := str(board.get("panels")[0].view)
	check(second != first and board.call("content", 0) != null, "> on a panel changes what it shows (%s to %s)" % [first, second])
	board.call("set_view", 0, "data")
	check(board.call("content", 0).get_class() == "PanelContainer", "a panel can show the parts and cost channel")
	board.call("step", 0, 1)
	check(str(board.get("panels")[0].view) == "modules", "after the parts channel comes the modules list")
	board.call("step", 0, 1)
	check(str(board.get("panels")[0].view) == "whiteboard", "then the whiteboard")
	# Panels other modules offer (the parts market) come after the room's own.
	for id: String in bus.wall_views:
		board.call("step", 0, 1)
		check(str(board.get("panels")[0].view) == id, "then the %s panel" % id)
	board.call("step", 0, 1)
	check(str(board.get("panels")[0].view) == "plan:0", "stepping on from the last view comes round to deck 1")
	# Pick a module up on one wall panel, drop it on a wall plan.
	bus.open_sample()
	var mid := bus.library.save_module("Mess", "r9")
	board.call("set_view", 1, "modules")
	await frames(1)
	var mod_b := (board.call("content", 1) as Node).find_child("Module_" + mid, true, false) as Button
	check(mod_b != null, "the wall lists the modules")
	if mod_b:
		mod_b.pressed.emit()
	check(bus.carrying == mid, "pressing one on the wall picks it up")
	var wall_plan: Control = board.call("content", 0)
	var before := bus.library.current.rooms.size()
	wall_plan.call("_press", wall_plan.call("to_screen", Vector2(30, 0)))
	check(bus.library.current.rooms.size() == before + 1 and bus.carrying == "", "pressing a wall plan drops it there")
	var holo: Node3D = f.get("holo")
	# The yard keeps a 10 x 6 m rectangle clear (DESIGN_CLEAR_SIZE; read by name until it lands).
	var clear: Vector2 = (YardBus as Script).get_script_constant_map().get("DESIGN_CLEAR_SIZE", Vector2(10, 6))
	check(Vector2(holo.position.x, holo.position.z).length() < 0.01 and HoloTable.TABLE_SIZE.x <= clear.x - 2.0
			and HoloTable.TABLE_SIZE.y <= clear.y - 2.0, "the holotable stands in the clear rectangle with room to walk round")
	check(HoloTable.TABLE_SIZE.x > HoloTable.TABLE_SIZE.y and HoloTable.TABLE_SIZE.x >= 6.0, "the table is long and rectangular")
	var use := holo.get_node_or_null("TableUse")
	check(use != null and use.has_meta("yard_use") and str((use.get_meta("yard_hint") as Callable).call()).contains("holotable"),
			"the table can be used: E Design at the holotable")
	(use.get_meta("yard_use") as Callable).call()
	check(f.call("is_console_open") and HudSlots.pointer_claimed(), "using it opens the console and frees the mouse")
	f.call("close_console")
	check(not f.call("is_console_open") and not HudSlots.pointer_claimed(), "leaving gives the mouse back")
	# Walking up to the table: the arrows turn and zoom the hologram, N steps the layers,
	# Page Up / Down cut it; F still opens the console (beenster, 19 Nov).
	check(str((use.get_meta("yard_hint") as Callable).call()).contains("turn"), "the table's hint lists its keys")
	var cam := Camera3D.new()
	holo.add_child(cam)
	cam.position = Vector3(0, 1.7, HoloTable.TABLE_SIZE.y * 0.5 + 1.0)
	cam.make_current()
	await frames(1)
	check(f.call("at_table"), "standing a metre off the table's edge counts as at the table")
	var turn0: float = holo.get("turn")
	var zoom0: float = holo.get("zoom")
	Input.action_press(DesignBus.KEY_HOLO_RIGHT)
	Input.action_press(DesignBus.KEY_HOLO_IN)
	await frames(10)
	Input.action_release(DesignBus.KEY_HOLO_RIGHT)
	Input.action_release(DesignBus.KEY_HOLO_IN)
	check(float(holo.get("turn")) > turn0 and float(holo.get("zoom")) > zoom0,
			"holding the arrows turns and zooms the hologram (%.2f, %.2f)" % [holo.get("turn"), holo.get("zoom")])
	check(str(f.call("next_layer_view")) == "everything" and (holo.get("layers") as Dictionary).values().all(func(v): return v),
			"N first shows every layer")
	check(str(f.call("next_layer_view")) == "rooms" and (holo.get("layers") as Dictionary).values().count(true) == 1
			and holo.get("layers").rooms, "then each layer alone")
	for i in HoloTable.LAYERS.size() - 1:
		f.call("next_layer_view")
	check(str(f.call("next_layer_view")) == "as set" and not holo.get("layers").wiring and holo.get("layers").frame,
			"and round to the layers as they were set")
	var ev := InputEventAction.new()
	ev.action = DesignBus.KEY_HOLO_CUT_DOWN
	ev.pressed = true
	f.call("_unhandled_input", ev)
	check(float(holo.get("cut")) < 1.0, "Page Down cuts the top away")
	holo.call("set_cut", 1.0)
	cam.position = Vector3(0, 1.7, 9.0)
	await frames(1)
	var turn1: float = holo.get("turn")
	Input.action_press(DesignBus.KEY_HOLO_RIGHT)
	await frames(5)
	Input.action_release(DesignBus.KEY_HOLO_RIGHT)
	check(not f.call("at_table") and is_equal_approx(float(holo.get("turn")), turn1), "away from the table the arrows do nothing")
	(use.get_meta("yard_use") as Callable).call()
	check(not f.call("at_table"), "with the console open the walk-up keys stand down")
	f.call("close_console")
	cam.queue_free()
	bus.furnish_station()
	check(root.get_children().filter(func(c): return c.name == "DesignFurnishing").size() == 1,
			"furnishing twice does not double up")

