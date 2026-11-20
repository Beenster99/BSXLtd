extends Node
## Pictures of the refurb works on its own (no station: quick, with a stand-in floor and the
## station's room light faked), for the thread's screenshots page.
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##       res://modules/refurb/tools/refurb_capture.tscn -- --out=/abs/dir [--at=200] [--size=1600x900]
##       [--watch=inspect,clean]: close-ups of a drone at that stage (its scan, its spray) instead

const Shop := preload("res://modules/refurb/internal/refurb_shop.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://refurb_shots"
	var at := 560.0
	var size := Vector2i(1600, 900)
	var only: PackedStringArray = []
	var yard := OS.get_cmdline_user_args().has("--yard")
	var watch: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--at="):
			at = float(arg.trim_prefix("--at="))
		elif arg.begins_with("--watch="):
			watch = arg.trim_prefix("--watch=").split(",")
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
	if yard:
		await _in_yard(out, at, only)
		return
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.01, 0.012, 0.02)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.4, 0.43, 0.5)
	env.environment.ambient_light_energy = 0.7
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	# The station lays the annex's floor and lights the room; here a stand-in of each.
	var floor_mi := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(36.0, 0.3, 30.0)
	floor_mi.mesh = fm
	floor_mi.position = Vector3(0, -0.15, 0)
	floor_mi.material_override = load("res://modules/refurb/internal/refurb_paint.gd").call("paint", Color(0.5, 0.52, 0.55), 0.2, 0.55, "tread_diamond_paint")
	add_child(floor_mi)
	for x: float in [-12.0, 0.0, 12.0]:
		for z: float in [-10.0, 0.0, 10.0]:
			var o := OmniLight3D.new()
			o.position = Vector3(x, 9.0, z)
			o.omni_range = 16.0
			o.omni_attenuation = 0.35
			o.light_energy = 0.5
			add_child(o)
	var shop: Node3D = Shop.new()
	add_child(shop)
	shop.call("setup", null, null, RefurbWorks.new())
	shop.call("fast_forward", at)
	var cam := Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	cam.current = true
	if not watch.is_empty():
		await _watch(shop, cam, watch, out)
		get_tree().quit()
		return
	var views: Dictionary = shop.call("view_points")
	for id: String in views:
		if not only.is_empty() and not only.has(id):
			continue
		for i in 40:
			await get_tree().process_frame
		var v: Array = views[id]
		cam.global_position = v[0]
		cam.look_at(v[1])
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [out, id]
		get_viewport().get_texture().get_image().save_png(path)
		print("captured ", path)
	get_tree().quit()


## In the station (slow: it builds the whole yard): the shop as the bus opens it, from the
## station's own camera, under the yard's sky and lights.
func _in_yard(out: String, at: float, only: PackedStringArray) -> void:
	for f: String in [YardBus.FLAG, YardBus.STATION, YardBus.DOCK, YardBus.RACKING, RefurbBus.FLAG, RefurbBus.SHOP_FLAG]:
		Flags.set_flag(f, true)
	var station := (load(YardBus.SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child(station)
	for i in 10:
		await get_tree().process_frame
	var bus := Modules.bus("refurb") as RefurbBus
	var shop := bus.shop()
	if shop == null:
		printerr("no refurb shop in the station")
		get_tree().quit(1)
		return
	shop.call("fast_forward", at)
	var cam: Camera3D = station.get("view_camera")
	var views: Dictionary = shop.call("view_points")
	views["refurb_outside"] = [Vector3(120, 30, 50), shop.to_global(Vector3(0, 6, 0))]
	for id: String in views:
		if not only.is_empty() and not only.has(id):
			continue
		var v: Array = views[id]
		cam.global_position = v[0]
		cam.look_at(v[1])
		cam.current = true
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/yard_%s.png" % [out, id]
		get_viewport().get_texture().get_image().save_png(path)
		print("captured ", path)
	get_tree().quit()


## Close-ups of a drone at each stage in `stages` ("inspect", "clean"): the works runs on till a
## light-line drone is at work on that stage, then three views of it.
func _watch(shop: Node3D, cam: Camera3D, stages: PackedStringArray, out: String) -> void:
	var works: RefurbWorks = shop.get("works")
	for st in stages:
		var want := RefurbWorks.Stage.INSPECT if st == "inspect" else RefurbWorks.Stage.CLEAN
		var bi := -1
		for k in 2400:
			for b in works.bots:
				if String(b.role) != "light" or String(b.state) != RefurbWorks.BOT_WORK:
					continue
				var lot: Dictionary = works.lots.get(int(b.lot), {})
				if not lot.is_empty() and not bool(lot.heavy) and int(lot.stage) == want and (b.pos as Vector3).distance_to(b.target) < 0.1 and float(lot.progress) > 0.2:
					bi = int(b.id)
			if bi >= 0:
				break
			shop.call("fast_forward", 0.25)
		if bi < 0:
			printerr("no drone at ", st)
			continue
		var b: Dictionary = works.bots[bi]
		var lot: Dictionary = works.lots[int(b.lot)]
		var mid := shop.to_global((lot.pos as Vector3) + Vector3(0, float(lot.h) * 0.5, 0))
		var bot := shop.to_global(b.pos)
		var side := (bot - mid)
		side.y = 0
		side = side.normalized()
		var across := side.cross(Vector3.UP)
		var views := {"left": across * 2.6 + side * 0.4 + Vector3(0, 0.6, 0), "right": -across * 2.6 + side * 0.4 + Vector3(0, 0.6, 0),
				"behind": side * 2.6 + across * 1.0 + Vector3(0, 1.6, 0)}
		for n: String in views:
			var look := (mid + bot) * 0.5
			cam.global_position = look + (views[n] as Vector3)
			cam.look_at(look)
			for i in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var path := "%s/%s_%s.png" % [out, st, n]
			get_viewport().get_texture().get_image().save_png(path)
			print("captured ", path)
