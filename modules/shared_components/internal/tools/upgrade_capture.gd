extends Node
## Shoots the Component Upgrades units for the ship page: the attractor coil at Mk I, II
## and III side by side (covers on), the add-ons on their own (a Q3 quantum core, an E3 field
## emitter array, the control board), a Mk III opened (its cover lifted off) with every
## add-on fitted, and a close-up of the emitter flange. Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 \
##       res://modules/shared_components/internal/tools/upgrade_capture.tscn -- --out=/abs/dir

const SIZE := Vector2i(1600, 900)

var _cam: Camera3D
var _env: Environment
var _we: WorldEnvironment


func _ready() -> void:
	_run()


func _run() -> void:
	var out := "user://upgrade_capture"
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
	# The three tiers in a row on a bench top, front (the emitter end) toward -z.
	var bench := RigidBody3D.new()
	bench.freeze = true
	add_child(bench)
	var kit := ShipKit.new(bench)
	kit.model = PartModel.new(bench, true)
	var top := kit.add(PartShapes.box(Vector3(5.0, 0.04, 1.6)), Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0)), ShipKit.paint(Color(0.2, 0.21, 0.22), 0.2, 0.8))
	var xs: Array[float] = [-1.7, 0.0, 1.75]
	var units: Array[Dictionary] = []
	for tier in [1, 2, 3]:
		var size := UpgradeRules.unit_size("attractor_coil", tier)
		var u := UpgradeUnits.attractor_coil(kit, tier, Transform3D(Basis.IDENTITY, Vector3(xs[tier - 1], size.y * 0.5 + 0.01, 0)))
		units.append(u)
	await _shoot(out, "upgrade_01_tiers", Vector3(0.6, 1.3, -2.6), Vector3(0, 0.15, 0), 55.0)
	# The add-ons on their own: a Q3 core, an E3 emitter array and the control board.
	for n in bench.get_children():
		n.queue_free()
	bench.queue_free()
	var tray := RigidBody3D.new()
	tray.freeze = true
	add_child(tray)
	var tkit := ShipKit.new(tray)
	tkit.model = PartModel.new(tray, true)
	tkit.add(PartShapes.box(Vector3(1.6, 0.04, 0.8)), Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0)), ShipKit.paint(Color(0.2, 0.21, 0.22), 0.2, 0.8))
	UpgradeUnits.quantum_core(tkit, 3, Transform3D(Basis.IDENTITY, Vector3(-0.1, UpgradeUnits.CORE_RADIUS[3], -0.2)))
	UpgradeUnits.field_emitter(tkit, 3, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.35, 0.0, 0.15)))
	UpgradeUnits.control_board(tkit, Transform3D(Basis.IDENTITY, Vector3(-0.3, UpgradeUnits.BOARD_SIZE.y * 0.5, 0.15)))
	await _shoot(out, "upgrade_02_addons", Vector3(-0.3, 0.75, -1.0), Vector3(0.0, 0.03, -0.02), 45.0)
	tray.queue_free()
	# A Mk III opened, on its own: the cover lifted and set beside it, every add-on in.
	var rig := RigidBody3D.new()
	rig.freeze = true
	add_child(rig)
	var rkit := ShipKit.new(rig)
	rkit.model = PartModel.new(rig, true)
	rkit.add(PartShapes.box(Vector3(2.4, 0.04, 1.4)), Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0)), ShipKit.paint(Color(0.2, 0.21, 0.22), 0.2, 0.8))
	var size3 := UpgradeRules.unit_size("attractor_coil", 3)
	var open := UpgradeUnits.attractor_coil(rkit, 3, Transform3D(Basis.IDENTITY, Vector3(0, size3.y * 0.5 + 0.01, 0)))
	var fitted := PackedStringArray()
	var made: Dictionary = {}
	for id in ["quantum_core_3", "field_emitter_3", "control_board"]:
		made[id] = UpgradeUnits.fit_addon(rkit, open, id, fitted)
		fitted.append(id)
	# Lift the cover off: its look and its bolts' heads go with it (presentation only).
	var cover: PartData = open["cover"]
	rkit.model.move_part(cover.id, Transform3D(Basis(Vector3.RIGHT, -0.35), cover.local_transform.origin + Vector3(0, 0.02, 0.62)))
	await _shoot(out, "upgrade_03_opened", Vector3(-0.9, 0.75, -0.95), Vector3(0.05, 0.1, 0.05), 45.0)
	await _shoot(out, "upgrade_04_opened_above", Vector3(0.0, 1.45, -0.3), Vector3(0, 0.05, 0.02), 45.0)
	var em: PartData = made["field_emitter_3"].get("part")
	if em:
		var o := em.local_transform.origin
		await _shoot(out, "upgrade_05_emitter", o + Vector3(-0.35, 0.16, -0.3), o + Vector3(0, 0, -0.05), 35.0)
	get_tree().quit()


func _light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 20.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, -150, 0)
	fill.light_energy = 0.5
	add_child(fill)
	_env = Environment.new()
	var env := WorldEnvironment.new()
	_we = env
	var e := _env
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.08, 0.09, 0.11)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.7)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)


func _shoot(out: String, name: String, from: Vector3, at: Vector3, fov: float = 60.0) -> void:
	_cam.fov = fov
	if _env:   # the Graphics module retunes the environment it finds; the shots stay dark
		_env.background_mode = Environment.BG_COLOR
		_env.sky = null
		_env.background_color = Color(0.08, 0.09, 0.11)
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.ambient_light_energy = 0.9
		_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		_env.tonemap_exposure = 1.0
	_cam.attributes = null   # no auto exposure brightening the dark backdrop
	if _we and _we.camera_attributes:
		_we.camera_attributes = null
	_cam.position = from
	_cam.look_at(at, Vector3.UP if absf(from.direction_to(at).dot(Vector3.UP)) < 0.99 else Vector3.FORWARD)
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("upgrade_capture: ", name)
