extends SceneTree
## Close-ups of one refurb drone from the front, side, back and three-quarter, on a plain floor,
## for checking its model.
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##       -s res://modules/refurb/tools/refurb_bot_capture.gd -- --out=/abs/dir [--heavy] [--tool=cutter]

const BotLook := preload("res://modules/refurb/internal/refurb_bot_look.gd")
const Spray := preload("res://modules/refurb/internal/refurb_spray.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://refurb_bot"
	var heavy := false
	var tool_name := "cutter"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--heavy":
			heavy = true
		elif arg.begins_with("--tool="):
			tool_name = arg.trim_prefix("--tool=")
	DirAccess.make_dir_recursive_absolute(out)
	var size := Vector2i(1200, 900)
	DisplayServer.window_set_size(size)
	root.size = size
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.33, 0.35)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.environment.ambient_light_energy = 0.3
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	world.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.5, 2.5, -2.5)
	fill.omni_range = 9.0
	fill.light_energy = 0.6
	world.add_child(fill)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.42, 0.43, 0.45)
	floor_mi.material_override = fm
	world.add_child(floor_mi)
	var bot: Node3D = BotLook.new()
	world.add_child(bot)
	bot.call("build", "RF-2/07", heavy)
	var cam := Camera3D.new()
	cam.fov = 40.0
	world.add_child(cam)
	cam.current = true
	var at := Vector3(0, 1.4, 0)
	var work := at + Vector3(0.25, -0.9, -1.1)
	for k in 30:
		bot.call("pose", at, at + Vector3(0, 0, -5), work, Vector3.INF, 0.8, false, tool_name, 1.0 / 30.0)
		await process_frame
	if tool_name == "blaster":
		await _spray_shots(world, bot, cam, at, out)
		quit()
		return
	var r: float = 3.6 if heavy else 2.9
	var shots := {"three_quarter": Vector3(-0.8, 0.45, -1.0), "front": Vector3(0, 0.15, -1), "side": Vector3(-1, 0.15, 0),
			"back": Vector3(0.4, 0.5, 1), "top": Vector3(0.3, 1.4, 0.6)}
	for n: String in shots:
		var dir: Vector3 = (shots[n] as Vector3).normalized()
		cam.global_position = at + dir * r
		cam.look_at(at + Vector3(0, -0.15, 0), Vector3.UP)
		for f in 3:
			bot.call("pose", at, at + Vector3(0, 0, -5), work, Vector3.INF, 0.8, false, tool_name, 1.0 / 30.0)
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png(out.path_join("bot_%s%s.png" % ["heavy_" if heavy else "", n]))
	quit()


## The pressure washer at work on a grimy block: a few views of the spray.
func _spray_shots(world: Node3D, bot: Node3D, cam: Camera3D, at: Vector3, out: String) -> void:
	var block := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 0.9, 1.0)
	block.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.3, 0.25)
	block.material_override = m
	block.position = at + Vector3(0, -0.95, -1.4)
	world.add_child(block)
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.2, 6.0, 10.0)
	wall.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.12, 0.13, 0.15)
	wall.material_override = wmat
	wall.position = at + Vector3(2.5, 0, 0)
	world.add_child(wall)
	var spray: Node3D = Spray.new()
	world.add_child(spray)
	var hit := block.position + Vector3(0.1, 0.45, 0.2)
	var reach := hit + (at - hit).normalized() * 0.6
	spray.set("on", true)
	for k in 90:
		bot.call("pose", at, hit, reach, Vector3.INF, 0.8, false, "blaster", 1.0 / 30.0)
		spray.call("aim", bot.get("tip"), hit)
		await process_frame
	var views := {"spray_side": Vector3(-1.0, 0.1, -0.35), "spray_front": Vector3(-0.35, 0.25, -1.0), "spray_close": Vector3(-0.6, 0.3, 0.2)}
	for n: String in views:
		var dir: Vector3 = (views[n] as Vector3).normalized()
		var look := hit + Vector3(0, 0.15, 0.35)
		cam.global_position = look + dir * (1.4 if n == "spray_close" else 2.6)
		cam.look_at(look, Vector3.UP)
		for f in 4:
			bot.call("pose", at, hit, reach, Vector3.INF, 0.8, false, "blaster", 1.0 / 30.0)
			spray.call("aim", bot.get("tip"), hit)
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("bot_%s.png" % n))
