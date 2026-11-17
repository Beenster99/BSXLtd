extends Node
## Screenshots of the design room for the screenshots page (run under a display):
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . \
##       res://modules/design/internal/tools/design_capture.tscn -- --flags=design.room=on --out=/abs/dir
## With --station (and --flags=yard=on,yard.station=on,design.room=on) it shoots the design
## room furnished inside the orbital yard's station instead.
## Saves console.png (the design console), room.png (the room with its TVs and table),
## holo_cut.png (the holotable cut through deck 1) and tv_plan.png (a wall TV's plan).

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
		var tv: Node = room.tvs["tv_left_1"]
		await _frames(5)
		var img: Image = tv.viewport.get_texture().get_image()
		img.save_png(out.path_join("tv_plan.png"))
		print("DesignCapture: ", out.path_join("tv_plan.png"))
		get_tree().quit()

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

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw

	func _save(out: String, id: String) -> void:
		var path := out.path_join(id + ".png")
		get_viewport().get_texture().get_image().save_png(path)
		print("DesignCapture: ", path)
