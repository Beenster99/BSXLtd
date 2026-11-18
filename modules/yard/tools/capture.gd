extends Node
## Captures the orbital yard's views (YardBus registers them as yard_<view> shots) to PNGs,
## for the Yard thread's screenshots page. Turns the yard's flags on itself.
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##       res://modules/yard/tools/capture.tscn -- --out=/abs/dir [--only=dock,crew] [--size=1600x900]

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://yard_shots"
	var only: PackedStringArray = []
	var size := Vector2i(1600, 900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		elif arg.begins_with("--size="):
			var p := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(size)
	get_tree().root.size = size
	if not Modules.ready_done:
		await Modules.modules_ready
	for f: String in [YardBus.FLAG, YardBus.STATION, YardBus.DOCK, YardBus.RACKING]:
		Flags.set_flag(f, true)
	if Modules.bus("yard") == null:
		var bus := YardBus.new()
		bus.name = "yard"
		Modules.add_child(bus)
		bus.register_module()
	var station := (load(YardBus.SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child(station)
	for i in 10:
		await get_tree().process_frame
	# Something at each port, so the front is not empty.
	var hall: Node = station.get("racking")
	if hall:
		for s in 3:
			hall.call("use_port", s)
		var t := 0.0
		while hall.call("busy") and t < 20.0:
			await get_tree().create_timer(0.25).timeout
			t += 0.25
	var ids: Array = (station.get("VIEWS") as Dictionary).keys() + (station.get("SUIT_VIEWS") as Dictionary).keys() + (station.get("TOOL_VIEWS") as Array)
	for id: String in ids:
		if not only.is_empty() and not only.has(id):
			continue
		station.call("show_view", id)
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/yard_%s.png" % [out, id]
		get_viewport().get_texture().get_image().save_png(path)
		print("captured ", path)
	get_tree().quit()
