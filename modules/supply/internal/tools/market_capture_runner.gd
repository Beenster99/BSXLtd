extends Node
## Runs the parts market screenshots (see market_capture.gd), from a node of the root so it
## carries on when the design room scene replaces the capture scene.

const SIZE := Vector2i(1110, 780)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://market_shots"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	if not Modules.ready_done:
		await Modules.modules_ready
	var design := Modules.bus("design") as DesignBus
	var bus := Modules.bus("supply") as SupplyBus
	design.open_sample()
	bus.set_standing("tarrow", 58)
	bus.set_standing("orbis", 44)
	DisplayServer.window_set_size(SIZE)
	get_tree().root.size = SIZE
	var screen := (design.wall_views[SupplyBus.WALL_VIEW].make as Callable).call(150.0) as Control
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	await _frames(20)
	await _save(out, "market_design")
	# The line with the widest spread of prices, over six months.
	var opt := bus.optimiser()
	var best := ""
	var spread := 0.0
	for r in opt.rows:
		var qs: Array = r.quotes
		if qs.size() >= 3 and r.line.kind == "component":
			var s := float(qs[qs.size() - 1].unit) / float(qs[0].unit)
			if s > spread:
				spread = s
				best = str(r.line.key)
	screen.call("set_span", 180)
	screen.call("set_plan", SupplyOptimiser.RELIABLE)
	screen.call("select", best)
	await _frames(20)
	await _save(out, "market_line")
	screen.queue_free()
	if "--room" in OS.get_cmdline_user_args():
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		get_tree().root.size = Vector2i(1920, 1080)
		Router.goto("design.room")
		await _frames(30)
		var room: Node = get_tree().current_scene
		room.call("set_room_view", true)
		var cam := room.get("camera") as Camera3D
		cam.position = Vector3(-4.0, 2.6, 3.0)
		cam.rotation = Vector3(-0.05, -1.25, 0)
		await _frames(40)
		await _save(out, "room")
		var wall: Node = (room.get("walls") as Dictionary)["wall_right"]
		var img: Image = wall.get("viewport").get_texture().get_image()
		img.save_png(out.path_join("wall_right.png"))
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(out: String, shot: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(shot + ".png"))
	print("MarketCapture: ", out.path_join(shot + ".png"))
