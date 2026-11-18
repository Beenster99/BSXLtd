extends Node
## Shoots every VsParts part on its own, as the stores and the design room draw it (Void
## Salvage's salvage surface, its glass and lit details), one picture each. Needs a renderer:
##   xvfb-run -a -s "-screen 0 800x800x24" godot --path . --rendering-driver opengl3 \
##       res://modules/shared_components/internal/tools/vs_parts_capture.tscn -- --out=/abs/dir

const SIZE := Vector2i(640, 640)

var _cam: Camera3D


func _ready() -> void:
	_run()


func _run() -> void:
	var out := "user://vs_parts_capture"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(SIZE)
	get_tree().root.size = SIZE
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_energy = 0.55
	add_child(fill)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.11, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.75)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_cam = Camera3D.new()
	_cam.fov = 35.0
	add_child(_cam)
	_cam.current = true
	for id in VsParts.ids():
		var node := VsParts.instance(id)
		add_child(node)
		var box := VsParts.shape(id).mesh.get_aabb()
		var r := box.size.length() * 0.5
		var c := box.get_center()
		_cam.near = maxf(r * 0.01, 0.01)
		_cam.far = r * 20.0
		var dist := r / sin(deg_to_rad(_cam.fov * 0.5)) * 1.05
		_cam.position = c + Vector3(1.0, 0.7, 1.3).normalized() * dist
		_cam.look_at(c, Vector3.UP)
		for i in 5:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, id])
		print("vs_parts_capture: ", id)
		node.queue_free()
		await get_tree().process_frame
	get_tree().quit()
