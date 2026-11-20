extends RefCounted
## The touches that make the station a place people live and work in (0.4.1 playtest: "we
## need the feeling that our station is a living space, more use of materials and effects"):
## service runs along the corridor's ceiling (pipes, a cable tray, a slow vent fan, one lamp
## that flickers), steam off the crew room's coffee machine, mugs and a plant on the mess
## tables, jackets on the lockers, scuffed walkways and pallets in the stores, dust motes in
## its lamps' light, and a dripping condensate pipe by goods in. Built once into the kit;
## the moving parts (fan, flicker) animate in `Ticker`.

const Kit := preload("res://modules/yard/internal/yard_kit.gd")


class Ticker extends Node3D:
	var fan: Node3D
	var lamp: SpotLight3D
	var lamp_face: MeshInstance3D
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if fan:
			fan.rotate_object_local(Vector3.FORWARD, delta * 2.2)
		if lamp:
			# Mostly on, now and then a stutter.
			var cycle := fmod(_t, 7.3)
			var on := not (cycle > 6.2 and fmod(_t * 13.0, 1.0) < 0.55)
			lamp.visible = on
			if lamp_face:
				lamp_face.visible = on


func build(kit, root: Node3D) -> Node3D:
	var k = kit
	var ticker := Ticker.new()
	ticker.name = "LivedIn"
	root.add_child(ticker)
	var steel: Material = k.paint(Color(0.62, 0.64, 0.66), 0.7, 0.35, "brushed_steel")
	var copper: Material = k.paint(Color(0.72, 0.45, 0.3), 0.8, 0.35)
	var dark: Material = k.paint(Kit.DARK, 0.6, 0.45, "gunmetal")
	var yellow: Material = k.paint(Color(0.85, 0.68, 0.12), 0.2, 0.6)
	# Corridor ceiling (x -34..46, z -4..0, 3.2 high): two pipes, a cable tray with its
	# looms, brackets every 3 m.
	for i in range(-33, 46, 3):
		k.box(Vector3(0.06, 0.32, 0.9), Vector3(float(i), 3.02, -0.6), dark, false)
	k.span(Vector3(-33.6, 2.82, -0.42), Vector3(45.6, 2.9, -0.34), steel, false)
	k.span(Vector3(-33.6, 2.94, -0.88), Vector3(45.6, 3.02, -0.8), copper, false)
	k.box(Vector3(79.2, 0.05, 0.36), Vector3(6.0, 2.98, -0.6 - 0.0), dark, false)
	for j in 3:
		var c: Color = [Color(0.15, 0.15, 0.17), Color(0.6, 0.18, 0.12), Color(0.12, 0.3, 0.55)][j]
		k.box(Vector3(79.0, 0.04, 0.05), Vector3(6.0, 3.025, -0.72 + j * 0.1), k.paint(c, 0.1, 0.6), false)
	# A vent fan in the corridor's wall by the airlock, turning slowly.
	var fan_at := Vector3(-28.0, 2.4, -3.88)
	k.box(Vector3(0.9, 0.9, 0.06), fan_at, dark, false)
	var fan := Node3D.new()
	fan.name = "VentFan"
	fan.position = fan_at + Vector3(0, 0, 0.06)
	ticker.add_child(fan)
	for b in 5:
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.36, 0.02)
		blade.mesh = bm
		blade.material_override = steel
		blade.position = Vector3(0, 0.18, 0).rotated(Vector3.BACK, TAU * b / 5.0)
		blade.rotation = Vector3(0, 0, TAU * b / 5.0)
		fan.add_child(blade)
	ticker.fan = fan
	# One corridor lamp that flickers.
	ticker.lamp = k.ceiling_lamp(Vector3(18.0, 3.2, -2.0), Vector2(1.6, 0.4), 0.7, 6.0)
	# Crew room: steam off the coffee machine, mugs and a plant on the tables, jackets on the
	# lockers, a rug by the sofa.
	_steam(ticker, Vector3(3.8, 1.6, 0.6))
	# (On Void Salvage's mess tables, with the room detail pass, a little higher.)
	var mug_y := 0.8605 if Flags.is_on(YardBus.ROOM_DETAIL) else 0.83
	for z: float in [3.5, 7.0]:
		for m in 3:
			var mc: Color = [Color(0.85, 0.85, 0.82), Color(0.2, 0.4, 0.7), Color(0.75, 0.25, 0.2)][m]
			k.box(Vector3(0.08, 0.1, 0.08), Vector3(5.0 + m * 0.9, mug_y, z + (m - 1) * 0.25), k.paint(mc, 0.0, 0.4), false)
	_plant(k, Vector3(8.2, 0.0, 10.9))
	_plant(k, Vector3(19.0, 0.0, 10.9))
	for i in 3:
		var jc: Color = [Kit.ORANGE, Color(0.2, 0.3, 0.45), Color(0.3, 0.32, 0.3)][i]
		k.box(Vector3(0.12, 0.85, 0.42), Vector3(19.3, 1.35, 1.3 + i * 1.2), k.paint(jc, 0.0, 0.85, "plastic_textured"), false)
	k.box(Vector3(3.6, 0.01, 2.2), Vector3(13.0, 0.005, 10.0), k.paint(Color(0.42, 0.24, 0.18), 0.0, 1.0, "plastic_textured"), false)
	# Stores: worn walkways along the aisles, pallets stacked by goods in, a dripping
	# condensate pipe, dust in the light.
	for x: float in [16.4, 24.8, 33.5, 42.7, 52.0, 62.4]:
		k.box(Vector3(1.6, 0.004, 54.0), Vector3(x, 0.004, -33.0), k.paint(Color(0.38, 0.4, 0.42), 0.3, 0.75), false)
	for p in 6:
		var at := Vector3(80.5, 0.07 + p * 0.15, -8.0)
		k.box(Vector3(1.2, 0.14, 1.0), at, k.paint(Color(0.55, 0.42, 0.26), 0.0, 0.9), false)
	k.span(Vector3(83.6, 0.0, -12.2), Vector3(83.8, 14.0, -12.0), copper, false)
	_drips(ticker, Vector3(83.0, 4.0, -12.1))
	k.box(Vector3(1.2, 0.003, 0.9), Vector3(83.0, 0.003, -12.1), k.paint(Color(0.2, 0.22, 0.25), 0.4, 0.15), false)
	k.box(Vector3(2.0, 1.0, 0.04), Vector3(82.0, 1.2, -4.25), yellow, false)
	k.sign("MIND THE DRIP", Vector3(82.0, 1.2, -4.28), Vector3.FORWARD, 0.006, Kit.DARK)
	_dust(ticker, AABB(Vector3(16, 1, -60), Vector3(46, 13, 52)))
	return ticker


func _plant(k, at: Vector3) -> void:
	k.box(Vector3(0.45, 0.5, 0.45), at + Vector3(0, 0.25, 0), k.paint(Color(0.62, 0.36, 0.24), 0.0, 0.85))
	var leaf: Material = k.paint(Color(0.2, 0.48, 0.22), 0.0, 0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 10.0)
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf() * 0.4
		var h := 0.7 + rng.randf() * 0.6
		k.box(Vector3(0.08, h, 0.22), at + Vector3(cos(a) * 0.12, 0.5 + h * 0.5, sin(a) * 0.12), leaf, false)


## A wisp of steam: soft white puffs rising and spreading, fading.
func _steam(parent: Node3D, at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.name = "Steam"
	p.position = at
	p.amount = 18
	p.lifetime = 2.4
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.12
	p.initial_velocity_max = 0.22
	p.gravity = Vector3(0, 0.05, 0)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.12
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 2.2))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.35))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = fade
	p.mesh = _puff()
	parent.add_child(p)


## Drops off a pipe's elbow every second or so.
func _drips(parent: Node3D, at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.name = "Drips"
	p.position = at
	p.amount = 3
	p.lifetime = 0.9
	p.direction = Vector3.DOWN
	p.spread = 0.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.03
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.8, 0.9, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.2
	mat.roughness = 0.05
	m.material = mat
	p.mesh = m
	parent.add_child(p)


## Dust motes hanging in the hall's lamplight, drifting.
func _dust(parent: Node3D, box: AABB) -> void:
	var p := CPUParticles3D.new()
	p.name = "Dust"
	p.position = box.get_center()
	p.amount = 260
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box.size * 0.5
	p.direction = Vector3(0.3, 0.1, 0.2)
	p.spread = 180.0
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.06
	p.gravity = Vector3(0, -0.004, 0)
	p.scale_amount_min = 0.012
	p.scale_amount_max = 0.025
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 0.97, 0.9, 0.0))
	fade.add_point(0.3, Color(1, 0.97, 0.9, 0.55))
	fade.add_point(0.7, Color(1, 0.97, 0.9, 0.55))
	fade.set_color(fade.get_point_count() - 1, Color(1, 0.97, 0.9, 0.0))
	p.color_ramp = fade
	p.mesh = _puff()
	p.visibility_aabb = AABB(-box.size * 0.6, box.size * 1.2)
	parent.add_child(p)


static var _puff_mesh: QuadMesh


## A soft round puff that always faces the camera (steam, dust).
func _puff() -> QuadMesh:
	if _puff_mesh == null:
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		var mat := StandardMaterial3D.new()
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
		mat.albedo_texture = ImageTexture.create_from_image(img)
		q.material = mat
		_puff_mesh = q
	return _puff_mesh
