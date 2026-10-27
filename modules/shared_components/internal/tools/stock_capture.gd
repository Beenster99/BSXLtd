extends Node
## Shoots the BSX stock plates for the ship page and the release notes: the five kinds,
## steel's four sizes, and a stack of one kind in every thickness. Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 \
##       res://modules/shared_components/internal/tools/stock_capture.tscn -- --out=/abs/dir

const SIZE := Vector2i(1600, 900)

var _cam: Camera3D
var _env: Environment
var _we: WorldEnvironment


func _ready() -> void:
	_run()


func _run() -> void:
	var out := "user://stock_capture"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(SIZE)
	get_tree().root.size = SIZE
	_light()
	_cam = Camera3D.new()
	_cam.near = 0.02
	_cam.far = 100.0
	add_child(_cam)
	_cam.current = true
	var body := RigidBody3D.new()
	body.freeze = true
	add_child(body)
	var kit := ShipKit.new(body)
	kit.add(PartShapes.box(Vector3(16.0, 0.04, 10.0)), Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0)), ShipKit.paint(Color(0.2, 0.21, 0.22), 0.2, 0.8))
	# The five kinds, 1000 x 1000, lying flat in a row.
	var x := -3.6
	for k in StockPlates.kinds():
		var t := 12 if StockPlates.kind(k)["family"] == "metal" else 15
		_lay(kit, StockPlates.item_id(k, 1000, 1000, t), Vector3(x, 0.0, -1.6))
		x += 1.25
	await _shoot(out, "stock_01_kinds", Vector3(-1.1, 3.2, 1.2), Vector3(-1.1, 0.0, -1.6), 55.0)
	# The four steel sizes, 8 mm, side by side.
	x = -4.0
	for sz in [[1000, 1000], [2000, 1000], [2500, 1250], [3000, 1500]]:
		var id := StockPlates.item_id("SteelPlate", sz[0], sz[1], 8)
		var w: float = StockPlates.item(id)["size"].x
		_lay(kit, id, Vector3(x + w * 0.5, 0.0, 1.6))
		x += w + 0.25
	await _shoot(out, "stock_02_sizes", Vector3(0.3, 4.6, 5.6), Vector3(0.3, 0.0, 1.4), 60.0)
	# A stack of alloy, one of each thickness, thinnest on top, offset so every edge shows.
	var y := 0.0
	var stack: Array[String] = []
	for id in StockPlates.item_ids("", "AlloyPlate"):
		if StockPlates.item(id)["length_mm"] == 1000:
			stack.append(id)
	stack.reverse()
	var i := 0
	for id in stack:
		var t: float = StockPlates.item(id)["size"].y
		_lay(kit, id, Vector3(6.0 + i * 0.08, y, -3.0 - i * 0.08))
		y += t + 0.004
		i += 1
	await _shoot(out, "stock_03_thicknesses", Vector3(5.1, 0.45, -1.9), Vector3(6.2, 0.02, -3.2), 40.0)
	get_tree().quit()


## Lays a plate flat with its bottom face on the floor at `at`.
func _lay(kit: ShipKit, id: String, at: Vector3) -> void:
	var s: Vector3 = StockPlates.item(id)["size"]
	kit.add(StockPlates.make_shape(id), Transform3D(Basis.IDENTITY, at + Vector3(0, s.y * 0.5 + 0.002, 0)), StockPlates.paint(id))


func _light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, -150, 0)
	fill.light_energy = 0.5
	add_child(fill)
	_env = Environment.new()
	_we = WorldEnvironment.new()
	_we.environment = _env
	add_child(_we)


func _shoot(out: String, name: String, from: Vector3, at: Vector3, fov: float = 60.0) -> void:
	_env.background_mode = Environment.BG_COLOR
	_env.sky = null
	_env.background_color = Color(0.08, 0.09, 0.11)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.55, 0.6, 0.7)
	_env.ambient_light_energy = 0.9
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.tonemap_exposure = 1.0
	_we.camera_attributes = null
	_cam.attributes = null
	_cam.fov = fov
	_cam.position = from
	_cam.look_at(at, Vector3.UP)
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("stock_capture: ", name)
