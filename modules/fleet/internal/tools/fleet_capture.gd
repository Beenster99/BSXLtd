extends Node
## Screenshots of the TARTANCO FLEET screen with the yard's real crew at work, for the fleet
## thread's screenshots page. Not part of the game.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 \
##       res://modules/fleet/internal/tools/fleet_capture.tscn -- --out=/abs/dir [--ticks=N]

const SIZE := Vector2i(1600, 900)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://fleet_shots"
	var ticks := 60 * 60 * 20
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--ticks="):
			ticks = int(arg.trim_prefix("--ticks="))
	DirAccess.make_dir_recursive_absolute(out)
	if not Modules.ready_done:
		await Modules.modules_ready
	DisplayServer.window_set_size(SIZE)
	get_tree().root.size = SIZE
	var bus := Modules.bus("fleet") as FleetBus
	var design := Modules.bus("design") as DesignBus
	design.open_sample()
	var station := (load(YardBus.SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child(station)
	var sim: Node = station.get("sim")
	sim.set_process(false)
	# Twenty minutes of work, so the crew wears, runs down and charges.
	sim.call("run_ticks", ticks)
	if station.has_method("show_view"):
		station.call("show_view", "build_berth")
	var layer := CanvasLayer.new()
	add_child(layer)
	var screen := bus.make_screen(150.0)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(screen)
	# The most worn bot in detail.
	var worst := ""
	var cond := 2.0
	for r in bus.rows():
		if float(r.condition) < cond:
			cond = float(r.condition)
			worst = str(r.serial)
	screen.call("select", worst)
	await _frames(20)
	await _save(out, "fleet_bot")
	# Orders: two groups, the hull crew with the sample's build plan.
	bus.command({"op": "group_add", "name": "Frame crew"})
	bus.command({"op": "group_add", "name": "Hull crew"})
	var rows := bus.rows()
	for r in rows:
		bus.command({"op": "bot_assign", "serial": str(r.serial), "group": "g1" if str(r.role) in ["W", "F"] else "g2"})
	bus.command({"op": "group_priority", "group": "g2", "priority": 4})
	for t in bus.plan_tasks():
		bus.command({"op": "task_add", "group": "g2" if str(t.trade) in ["R", "B"] else "g1", "task": t})
	var g2: Array = bus.orders.group("g2").tasks
	if g2.size() > 1:
		bus.command({"op": "task_priority", "group": "g2", "task": str(g2[1].id), "priority": 5})
	screen.call("show_group", "g2")
	await _frames(20)
	await _save(out, "fleet_orders")
	screen.queue_free()
	# The wrist screen's glass over the berth.
	var wrist := bus.make_screen(150.0, true)
	wrist.anchor_left = 0.08
	wrist.anchor_right = 0.92
	wrist.anchor_top = 0.1
	wrist.anchor_bottom = 0.9
	layer.add_child(wrist)
	wrist.call("select", worst)
	await _frames(20)
	await _save(out, "fleet_wrist")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(out: String, shot: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(shot + ".png"))
	print("FleetCapture: ", out.path_join(shot + ".png"))
