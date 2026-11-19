extends Node
## Screenshots of the design room for the screenshots page (run under a display):
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . \
##       res://modules/design/internal/tools/design_capture.tscn -- --flags=design.room=on --out=/abs/dir
## With --station (and --flags=yard=on,yard.station=on,design.room=on) it shoots the design
## room furnished inside the orbital yard's station instead.
## Saves console.png (the design console), room.png (the room with its walls and table),
## holo_cut.png (the holotable cut through deck 1), wall_left.png, wall_right.png (what two walls show)
## and walk_*.png (walk-inside mode). --parts shoots the palette, --models walk-inside fitted out in
## the parts' detailed models (models_*.png).

const SIZE := Vector2i(1920, 1080)


func _ready() -> void:
	var runner := Runner.new()
	runner.name = "DesignCapture"
	get_tree().root.add_child.call_deferred(runner)


class Runner:
	extends Node

	func _ready() -> void:
		_run.call_deferred()

	func _run() -> void:
		var out := "user://design_shots"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--out="):
				out = arg.trim_prefix("--out=")
		DirAccess.make_dir_recursive_absolute(out)
		DisplayServer.window_set_size(SIZE)
		get_tree().root.size = SIZE
		if not Modules.ready_done:
			await Modules.modules_ready
		var bus := Modules.bus("design") as DesignBus
		bus.open_sample()
		if "--station" in OS.get_cmdline_user_args():
			await _station(bus, out)
			return
		Router.goto("design.room")
		await _frames(20)
		var room: Node = get_tree().current_scene
		if "--parts" in OS.get_cmdline_user_args():
			await _parts_shots(room, out)
			get_tree().quit()
			return
		if "--models" in OS.get_cmdline_user_args():
			await _model_shots(room, out)
			get_tree().quit()
			return
		if "--frame" in OS.get_cmdline_user_args():
			await _frame_shots(room, out)
			get_tree().quit()
			return
		room.console.plan.select("room", "r4")
		room.console.plan.set_tool("room:workshop")
		await _frames(30)
		await _save(out, "console")
		room.console.plan.set_tool("select")
		room.set_room_view(true)
		await _frames(30)
		await _save(out, "room")
		room.set_room_view(false)
		for layer in ["frame", "power"]:
			(room.console.find_child("Layer_" + layer, true, false) as Button).button_pressed = true
		(room.console.find_child("Cut", true, false) as HSlider).value = 0.45
		room.console._set_view("side")
		await _frames(30)
		await _save(out, "holo_cut")
		for id: String in ["wall_left", "wall_right"]:
			var wall: Node = room.walls[id]
			await _frames(5)
			var img: Image = wall.viewport.get_texture().get_image()
			img.save_png(out.path_join(id + ".png"))
			print("DesignCapture: ", out.path_join(id + ".png"))
		# The whiteboard on the back wall: a sketch over the deck plan.
		var wall: Node = room.walls["wall_back_low_left"]
		var wb: Node = wall.content.call("content", 0)
		wb.call("toggle_plan")
		var sketch := [["box", "ff9a4d", 7.0, [[520, 300], [760, 520]]],
				["pen", "f2f2ee", 3.0, [[770, 410], [830, 380], [900, 360], [960, 350]]],
				["line", "f2f2ee", 3.0, [[960, 350], [935, 335]]], ["line", "f2f2ee", 3.0, [[960, 350], [938, 368]]],
				["marker", "e8c25a", 15.0, [[380, 640], [600, 650], [820, 640]]],
				["pen", "6fc8e8", 3.0, [[1000, 300], [1040, 330], [1010, 380], [1060, 420], [1030, 470]]]]
		var lay: String = room.bus.library.current.peek_id("l")
		room.bus.editor.do({"op": "add_layer", "layer": {"id": lay, "name": "Bigger hold?"}})
		for k in sketch:
			room.bus.editor.do({"op": "add_stroke", "stroke": {"layer": lay, "tool": k[0], "colour": k[1], "width": k[2], "points": k[3]}})
		(wall.viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS
		await _frames(10)
		(wall.viewport.get_texture().get_image() as Image).save_png(out.path_join("whiteboard.png"))
		print("DesignCapture: ", out.path_join("whiteboard.png"))
		# Walk-inside: in the corridor looking to the bow, then in engineering, then outside.
		room.console._set_view("plan")
		room.furnishing.open_walk()
		var walk: Node3D = room.furnishing.walk
		for shot in [["walk_corridor", Vector3(0, 1.0, 3.0), 0.0, -0.05],
				["walk_engineering", Vector3(6.2, 1.0, -1.3), 2.36, -0.2],
				["walk_stairs", Vector3(-1.5, 1.0, 1.0), PI * 0.5, 0.45],
				["walk_outside", Vector3(9, 1.0, 12), 0.62, 0.0],
				["walk_bridge", Vector3(0.3, 1.0, -6.6), 0.0, -0.35]]:
			walk.body.position = shot[1]
			walk.body.rotation.y = shot[2]
			walk.set("_pitch", shot[3])
			walk.camera.rotation.x = shot[3]
			await _frames(20)
			await _save(out, shot[0])
		# Designing from inside: a fuel pump in your hands in engineering, showing where it fits.
		walk.body.position = Vector3(2.0, 1.0, -1.2)
		walk.body.rotation.y = PI
		walk.set("_pitch", -0.7)
		walk.camera.rotation.x = -0.7
		walk.call("take_new", "fuel_pump")
		await _frames(20)
		await _save(out, "walk_design")
		walk.call("toggle_palette")
		await _frames(10)
		await _save(out, "walk_palette")
		walk.call("toggle_palette")
		walk.set("holding", {})
		room.furnishing.close_walk()
		await _hull_shots(room, out)
		get_tree().quit()

	## The same ship with a hull of its own drawn round it: a tapered bow, an open deck, a
	## partition wall and a beam across it.
	func _hull_shots(room: Node, out: String) -> void:
		var ed: DesignEditor = room.bus.editor
		ed.do({"op": "set_hull", "deck": 0, "points": [[-8, -6.5], [-3, -11.5], [3.5, -11.5], [8, -3], [8, 6], [-8, 6]]})
		ed.do({"op": "add_wall", "wall": {"deck": 0, "a": [-8, 2], "b": [-3, 2]}})
		ed.do({"op": "add_beam", "beam": {"deck": 0, "a": [-6, -7], "b": [-2, -7]}})
		for x in [-4.5, 4.5]:
			ed.do({"op": "add_mount", "mount": {"type": "main_thruster", "deck": 0, "x": x, "z": 6, "angle": PI * 0.5}})
		ed.do({"op": "add_mount", "mount": {"type": "thruster_pack", "deck": 0, "x": 8, "z": 1, "angle": 0.0}})
		room.furnishing.open_console()
		room.console._set_view("plan")
		room.console.plan.select("hull", "1")
		room.console.plan.set_tool("hull")
		await _frames(30)
		await _save(out, "hull_console")
		room.console.plan.set_tool("select")
		for layer in ["frame", "power"]:
			(room.console.find_child("Layer_" + layer, true, false) as Button).button_pressed = layer == "frame"
		(room.console.find_child("Cut", true, false) as HSlider).value = 1.0
		await _frames(30)
		await _save(out, "hull_holo")
		room.furnishing.open_walk()
		var walk: Node3D = room.furnishing.walk
		for shot in [["walk_hull_bow", Vector3(-2.6, 1.0, -6.3), 0.95, 0.2],
				["walk_hull_outside", Vector3(15, 1.0, -2), 1.3, 0.05],
				["walk_hull_stern", Vector3(7.5, 1.4, 10.5), 0.45, -0.05]]:
			walk.body.position = shot[1]
			walk.body.rotation.y = shot[2]
			walk.set("_pitch", shot[3])
			walk.camera.rotation.x = shot[3]
			await _frames(20)
			await _save(out, shot[0])
		room.furnishing.close_walk()

	## The structure proposed round the sample: from outside with its skin, then as a bare
	## skeleton of rings, stringers and node blocks, and on the holotable.
	func _frame_shots(room: Node, out: String) -> void:
		room.furnishing.open_console()
		for layer in ["frame", "plates", "components", "power"]:
			(room.console.find_child("Layer_" + layer, true, false) as Button).button_pressed = layer in ["frame", "plates"]
		(room.console.find_child("Cut", true, false) as HSlider).value = 1.0
		room.console._set_view("plan")
		await _frames(30)
		await _save(out, "frame_holo")
		room.furnishing.open_walk()
		var walk: Node3D = room.furnishing.walk
		await _frames(5)
		walk.set_physics_process(false)
		var b: Object = walk.get("builder")
		var plan: Dictionary = b.get("frame_plan")
		var st: Array = plan.stations
		var mid := Vector3(0, 1.5, (float(st[0].z) + float(st[st.size() - 1].z)) * 0.5)
		var model: PartModel = b.get("frame_model")
		var skin_names := ["HullPlate", "CapPlate", "WindowPane"]
		for shot in [["frame_outside", 0.9, 0.3, 17.0, []], ["frame_skeleton", 0.9, 0.3, 17.0, skin_names],
				["frame_inner", 0.6, 0.55, 12.0, skin_names + ["WallPanel", "DeckPlate"]]]:
			for p: PartData in model.parts.values():
				var vis := model.part_visual(p.id)
				if vis:
					vis.visible = not (p.part_name in shot[4] or p.kind == PartData.Kind.GLASS and not (shot[4] as Array).is_empty())
			var yaw: float = shot[1]
			var up := float(shot[3]) * float(shot[2])
			walk.body.position = mid + Vector3(sin(yaw), 0, cos(yaw)) * float(shot[3]) + Vector3(0, up, 0)
			walk.body.rotation.y = yaw
			walk.camera.rotation.x = -atan2(up, float(shot[3]))
			await _frames(20)
			await _save(out, shot[0])
		for p: PartData in model.parts.values():
			var vis := model.part_visual(p.id)
			if vis:
				vis.visible = true
		# Inside: the corridor, looking along it at the stud walls and the deck plates.
		walk.body.position = Vector3(0.0, 1.0, 3.2)
		walk.body.rotation.y = 0.35
		walk.camera.rotation.x = -0.25
		await _frames(20)
		await _save(out, "frame_room")
		room.furnishing.close_walk()

	## The furnished design room inside the orbital yard's station.
	func _station(bus: DesignBus, out: String) -> void:
		# Needs the yard on: -- --flags=yard=on,yard.station=on,design.room=on --station
		if Router.goto("yard.station") != OK:
			printerr("DesignCapture: the yard station is off; pass --flags=yard=on,yard.station=on")
			get_tree().quit(1)
			return
		await _frames(5)
		var station: Node = get_tree().current_scene
		await _frames(20)
		for view in ["design_room", "design_window"]:
			station.call("show_view", view)
			await _frames(20)
			await _save(out, "station_" + view)
		var cam: Camera3D = station.get("view_camera")
		cam.position = Vector3(3.2, 2.6, -9.5)
		cam.look_at(Vector3(0, 1.5, -13))
		await _frames(20)
		await _save(out, "station_table")
		var f: Node = station.get_node("DesignRoomRoot/DesignFurnishing")
		f.call("open_console")
		await _frames(20)
		await _save(out, "station_console")
		get_tree().quit()

	## The component palette in its groups at a picked size and grade, and the ship ratings
	## (--parts).
	func _parts_shots(room: Node, out: String) -> void:
		var bus: DesignBus = room.bus
		for op in [
			{"op": "add_component", "component": {"type": "cooker", "room": "r9", "x": 3.2, "z": -3.6, "rot": 2}},
			{"op": "add_component", "component": {"type": "fridge", "room": "r9", "x": 0.0, "z": -3.6, "rot": 2}},
			{"op": "add_component", "component": {"type": "mess_table", "room": "r9", "x": 1.5, "z": -1.6, "rot": 0}},
			{"op": "add_component", "component": {"type": "sofa", "room": "r9", "x": 2.5, "z": -0.55, "rot": 0}},
			{"op": "add_component", "component": {"type": "battery_bank:4P", "room": "r5", "x": 6.4, "z": -1.4, "rot": 3}},
			{"op": "add_component", "component": {"type": "jump_drive:3Q", "room": "r4", "x": -4.5, "z": -1.6, "rot": 0}},
		]:
			bus.editor.do(op)
		var console: Node = room.console
		console._open_groups = {"power": true, "galley": true}
		console.set_pick(5, "H")
		await _frames(10)
		var head := console.find_child("Group_power", true, false) as Control
		var scroll: Node = head.get_parent()
		while scroll and not scroll is ScrollContainer:
			scroll = scroll.get_parent()
		await _frames(5)
		if scroll:
			(scroll as ScrollContainer).scroll_vertical = int(head.position.y) - 40
		await _frames(30)
		await _save(out, "parts_palette")
		# A client's ship order picked, the data channel scoring against it, and a selected
		# part's size and grade steppers.
		var contracts := Modules.bus("contracts") as ContractsBus
		var orders := contracts.ship_orders() if contracts else ([] as Array[Dictionary])
		if not orders.is_empty():
			console.set_order(orders[0])
		console._orders_open = true
		console._fill_palette()
		room.console.plan.select("part", "c2")
		await _frames(10)
		if scroll:
			(scroll as ScrollContainer).scroll_vertical = 0
		var data_scroll: Node = room.console.data
		while data_scroll and not data_scroll is ScrollContainer:
			data_scroll = data_scroll.get_parent()
		if data_scroll == null:
			data_scroll = room.console.data.find_child("*Scroll*", true, false)
		var fit_label: Node = room.console.data.find_child("*", true, false)
		for n in room.console.data.find_children("*", "Label", true, false):
			if (n as Label).text == "CONTRACT FIT":
				fit_label = n
		if data_scroll is ScrollContainer and fit_label is Control:
			await _frames(5)
			(data_scroll as ScrollContainer).ensure_control_visible(fit_label)
			(data_scroll as ScrollContainer).scroll_vertical += 300
		await _frames(30)
		await _save(out, "parts_order")

	## Walk-inside with the rooms fitted out in the parts' detailed models, Void Salvage's and
	## BSX's own (PartModels), and weapons and lights on the hull (--models).
	func _model_shots(room: Node, out: String) -> void:
		var bus: DesignBus = room.bus
		var n := 0
		for c in [["cooker", "r9", 3.5, -3.6, 2], ["fridge", "r9", -0.5, -3.6, 2], ["kitchen_sink", "r9", 2.6, -3.6, 2],
				["food_printer", "r9", -0.5, -0.4, 0], ["drinks_dispenser", "r9", 0.3, -0.4, 0], ["sofa", "r9", 2.6, -0.5, 0],
				["games_table", "r9", 1.6, -2.0, 0],
				["jump_drive", "r5", 5.4, -0.6, 0], ["coolant_pump", "r5", 6.4, 1.0, 3], ["power_distributor", "r5", 3.4, -1.6, 2],
				["breaker_panel", "r5", 4.4, -1.85, 2], ["fire_suppression", "r5", 1.4, 0.8, 1], ["oxygen_generator", "r5", 1.6, 3.4, 0],
				["helm_console", "r1", 0.5, -7.2, 2], ["captains_chair", "r1", 0.5, -8.2, 2], ["flight_computer", "r1", 2.5, -9.6, 2],
				["comms_suite", "r1", -1.5, -7.0, 1],
				["tech_container", "r4", -5.5, -1.2, 0], ["pallet_lifter", "r4", -3.0, -1.5, 0], ["spares_cage", "r4", -1.6, -5.5, 2],
				["tool_rack", "r4", -4.0, -5.7, 2], ["weapons_locker", "r4", -6.6, -1.0, 1],
				["captains_cabin", "r3", 2.2, -4.9, 2], ["wardrobe", "r3", 1.5, -2.4, 0], ["desk", "r3", 3.6, -2.4, 0]]:
			n += 1
			bus.editor.do({"op": "add_component", "component": {"id": "m%d" % n, "type": c[0], "room": c[1],
					"x": c[2], "z": c[3], "rot": c[4]}})
		for m in [["point_defence", -7.0, -3.0, PI], ["missile_rack", -7.0, -5.0, PI], ["radar_array", -7.0, -1.0, PI],
				["nav_lights", -2.0, -8.0, PI], ["twin_turret", 7.0, 0.5, 0.0]]:
			n += 1
			bus.editor.do({"op": "add_mount", "mount": {"id": "m%d" % n, "type": m[0], "deck": 0, "x": m[1], "z": m[2], "angle": m[3]}})
		room.furnishing.open_walk()
		var walk: Node3D = room.furnishing.walk
		for shot in [["models_mess", Vector3(1.6, 4.0, -1.0), PI * 0.08, -0.35],
				["models_engineering", Vector3(1.8, 1.4, 1.0), -0.93, -0.25],
				["models_bridge", Vector3(0.6, 1.0, -6.6), 0.0, -0.3],
				["models_hold", Vector3(-2.0, 1.0, -0.6), PI * 0.25, -0.25],
				["models_quarters", Vector3(4.4, 1.0, -2.6), PI * 0.35, -0.3]]:
			walk.body.position = shot[1]
			walk.body.rotation.y = shot[2]
			walk.set("_pitch", shot[3])
			walk.camera.rotation.x = shot[3]
			await _frames(30)
			await _save(out, shot[0])
		room.furnishing.close_walk()

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw

	func _save(out: String, id: String) -> void:
		var path := out.path_join(id + ".png")
		get_viewport().get_texture().get_image().save_png(path)
		print("DesignCapture: ", path)
