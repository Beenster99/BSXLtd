extends Node
## Shots of the station from any camera, with the frame's render counts, for the room fixes.
##   xvfb-run -s "-screen 0 1600x900x24" godot --path . res://modules/yard/tools/room_capture.tscn -- \
##       --out=/abs/dir --cam=name:px,py,pz:tx,ty,tz [--cam=...] \
##       [--shadows=1] [--frames=4] --flags=<the release profile's, so it is built as players get it>

func _ready() -> void:
	_run.call_deferred()


func _v(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _run() -> void:
	var out := "user://room_shots"
	var cams: Array = []
	var size := Vector2i(1280, 720)
	var settle := 4
	var shadows := 1   # software GL draws a frame of the default's shadows in minutes
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--cam="):
			cams.append(arg.trim_prefix("--cam=").split(":"))
		elif arg.begins_with("--frames="):
			settle = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--shadows="):
			shadows = int(arg.trim_prefix("--shadows="))
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(size)
	get_tree().root.size = size
	if not Modules.ready_done:
		await Modules.modules_ready
	GraphicsOptions.set_value("shadows", shadows)
	if Modules.bus("yard") == null:
		var bus := YardBus.new()
		bus.name = "yard"
		Modules.add_child(bus)
		bus.register_module()
	var station := (load(YardBus.SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child(station)
	for i in 10:
		await get_tree().process_frame
	var cam := Camera3D.new()
	cam.fov = 75.0
	station.add_child(cam)
	for c: PackedStringArray in cams:
		cam.position = _v(c[1])
		cam.look_at(_v(c[2]))
		cam.current = true
		for i in settle:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [out, c[0]]
		get_viewport().get_texture().get_image().save_png(path)
		print("captured %s  draws %d  objects %d  prims %d" % [path,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	# The lights that would cast shadows at the default setting (High).
	GraphicsOptions.set_value("shadows", 3)
	var lights := 0
	var shadowed := 0
	var by_name := {}
	for l: Node in get_tree().root.find_children("*", "Light3D", true, false):
		if l is DirectionalLight3D or not (l as Light3D).is_visible_in_tree():
			continue
		lights += 1
		load("res://modules/core/api/graphics.gd").tune_light(l as Light3D)
		if (l as Light3D).shadow_enabled:
			shadowed += 1
			var key := String(l.name).rstrip("0123456789_")
			by_name[key] = int(by_name.get(key, 0)) + 1
	print("lights %d shadowed at High %d nodes %d  %s" % [lights, shadowed, get_tree().root.find_children("*", "", true, false).size(), by_name])
	get_tree().quit()
