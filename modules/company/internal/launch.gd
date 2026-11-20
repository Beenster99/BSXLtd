extends Node3D
## Launch day (master plan 8.4: "a bottle against the hull, the bots lined up, and the ship
## leaving the dock under its own power"): placed at the build berth. A bottle swings in on a
## line and breaks on her bow (glass, foam, a flash), her engines light, and she slides out of
## the berth bow first and away, faster and faster, her name on a holo over her. Presentation
## only; it frees itself when she is gone.

const LaunchSounds := preload("res://modules/company/internal/launch_sounds.gd")
const SECONDS := 34.0
const BOTTLE_AT := 4.0
const ENGINES_AT := 9.0
const MOVE_AT := 12.0

var ship: Node3D
var _t := 0.0
var _bottle: MeshInstance3D
var _burst: CPUParticles3D
var _foam: CPUParticles3D
var _flash: OmniLight3D
var _glows: Array[OmniLight3D] = []
var _plumes: Array[MeshInstance3D] = []
var _label: Label3D
var _player: AudioStreamPlayer3D
var _half := 10.0
var _plume_len := 6.0
var _broke := false


func setup(view: Node3D, ship_name: String) -> void:
	ship = view
	add_child(ship)
	var hb: Node3D = ship.get_node_or_null("Ship")
	_half = 10.0
	if hb:
		_half = absf(hb.position.z) if absf(hb.position.z) > 1.0 else 10.0
	var aabb := _bounds(ship)
	if aabb.size.z > 1.0:
		_half = aabb.size.z * 0.5
	# The bottle on its line, swinging in from above the bow.
	_bottle = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.16
	cyl.height = 0.6
	_bottle.mesh = cyl
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.15, 0.45, 0.2, 0.85)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.2
	glass.roughness = 0.1
	_bottle.material_override = glass
	add_child(_bottle)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.95, 0.8)
	_flash.omni_range = 16.0
	_flash.light_energy = 0.0
	add_child(_flash)
	_burst = _particles(Color(0.6, 0.9, 0.7, 0.9), 120, 0.05, 4.0, 1.4)
	_foam = _particles(Color(1.0, 0.98, 0.9, 0.85), 160, 0.12, 1.6, 2.6)
	# Her engines at the stern (+Z in her own space), spaced and sized to her beam.
	var beam := clampf(aabb.size.x * 0.22, 1.2, 8.0) if aabb.size.x > 1.0 else 1.6
	var nozzle := clampf(beam * 0.45, 0.6, 3.0)
	_plume_len = nozzle * 4.5
	for x: float in [-beam, beam]:
		var l := OmniLight3D.new()
		l.light_color = Color(0.5, 0.75, 1.0)
		l.omni_range = 14.0
		l.light_energy = 0.0
		l.position = Vector3(x, aabb.get_center().y, _half + 1.5)
		ship.add_child(l)
		_glows.append(l)
		var plume := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.05
		cone.bottom_radius = nozzle
		cone.height = _plume_len
		plume.mesh = cone
		var hot := StandardMaterial3D.new()
		hot.albedo_color = Color(0.35, 0.6, 1.0, 0.3)
		hot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hot.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		plume.material_override = hot
		plume.rotation_degrees = Vector3(90, 0, 0)
		plume.position = Vector3(x, aabb.get_center().y, _half + 0.3 + _plume_len * 0.5)
		plume.scale = Vector3(1, 0.01, 1)
		ship.add_child(plume)
		_plumes.append(plume)
	_label = Label3D.new()
	_label.text = ship_name.to_upper()
	_label.font_size = 160
	_label.pixel_size = 0.02
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(1.0, 0.62, 0.3, 0.0)
	_label.outline_size = 12
	_label.position = Vector3(0, aabb.size.y * 0.5 + 6.0, 0)
	ship.add_child(_label)
	_player = AudioStreamPlayer3D.new()
	_player.stream = LaunchSounds.stream("horn")
	_player.unit_size = 30.0
	add_child(_player)
	_player.play()


func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = (n.global_transform.affine_inverse() * mi.global_transform) * mi.mesh.get_aabb() if n.is_inside_tree() \
				else mi.transform * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _particles(colour: Color, amount: int, size: float, speed: float, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3(0, 0, -1)
	p.spread = 70.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = 0.3
	p.damping_max = 0.8
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = mat
	add_child(p)
	return p


func _process(delta: float) -> void:
	_t += delta
	var bow := Vector3(0, 0.5, -_half - 0.3)
	# The bottle swings down on its line to her bow and breaks.
	if not _broke:
		var u := clampf(_t / BOTTLE_AT, 0.0, 1.0)
		var swing := 1.0 - u * u
		_bottle.position = bow + Vector3(0, 7.0 * swing, -6.0 * swing)
		_bottle.rotation = Vector3(-swing * 1.2, 0, 0)
		if u >= 1.0:
			_broke = true
			_bottle.visible = false
			for p: CPUParticles3D in [_burst, _foam]:
				p.position = bow
				p.emitting = true
			_flash.position = bow
			var crack := AudioStreamPlayer3D.new()
			crack.stream = LaunchSounds.stream("smash")
			crack.position = bow
			add_child(crack)
			crack.play()
	_flash.light_energy = maxf(0.0, 6.0 - (_t - BOTTLE_AT) * 8.0) if _t >= BOTTLE_AT else 0.0
	_label.modulate.a = clampf((_t - BOTTLE_AT) / 1.5, 0.0, 1.0) * clampf((SECONDS - _t) / 3.0, 0.0, 1.0)
	# Her engines light, then she moves out bow first, ever faster.
	var e := clampf((_t - ENGINES_AT) / 2.5, 0.0, 1.0)
	for l in _glows:
		l.light_energy = 3.5 * e * (0.9 + 0.1 * sin(_t * 31.0))
	for p in _plumes:
		var s := maxf(0.01, e * (1.0 + 0.08 * sin(_t * 23.0)))
		p.scale = Vector3(1, s, 1)
		p.position.z = _half + 0.3 + _plume_len * 0.5 * s
	if _t >= MOVE_AT:
		var m := _t - MOVE_AT
		ship.position = Vector3(0, 0, -0.5 * 1.4 * m * m)
	if _t >= SECONDS:
		queue_free()


## Runs on to `seconds` at once (screenshots, tests).
func jump_to(seconds: float) -> void:
	while _t < seconds - 0.05:
		_process(0.05)
