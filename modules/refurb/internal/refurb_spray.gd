extends Node3D
## A pressure washer's spray (beenster, 20 Nov: "The spray/debris is not detailed enough, use
## volumetrics and tiny droplets to create the sort of spray you get with a pressure washer"):
## a fan jet of fine droplet streaks from the lance's nozzle to the part, hazed along its length
## (0.4.7 playtest: "the spray needs to be a bigger cloud effect"); where it hits, a
## burst of tiny droplets fanning back off the surface (some carrying the dirt, brown), slower
## spatter that falls under gravity, a rolling cloud of soft mist that drifts and fades, and a
## FogVolume in the mist so it hangs in the light when volumetric fog is on. All GPU particles;
## `aim(from, to)` each frame while it runs, `on` to start and stop. Presentation only.

## The jet's droplets live this long (s): their speed is set to reach the surface in it.
const JET_LIFE := 0.06

var on := false:
	set(v):
		if v == on:
			return
		on = v
		for p: GPUParticles3D in [_jet, _splash, _dirt, _spatter, _mist, _haze]:
			p.emitting = v
		_core.visible = v
		_sheath.visible = v
		if not v:
			_fog_target = 0.0

var _jet: GPUParticles3D
var _splash: GPUParticles3D
var _dirt: GPUParticles3D
var _spatter: GPUParticles3D
var _mist: GPUParticles3D
var _haze: GPUParticles3D
var _core: MeshInstance3D
var _sheath: MeshInstance3D
var _fog: FogVolume
var _fog_mat: FogMaterial
var _fog_level := 0.0
var _fog_target := 0.0

static var _puff_tex: Texture2D


func _ready() -> void:
	name = "Spray"
	_jet = _particles("Jet", 1800, JET_LIFE, Color(0.88, 0.95, 1.0, 0.45), 6.0, Vector2(0.003, 0.05), true)
	_splash = _particles("Splash", 2400, 0.35, Color(0.82, 0.9, 1.0, 0.42), 72.0, Vector2(0.0025, 0.028), true)
	_dirt = _particles("Dirt", 500, 0.45, Color(0.36, 0.27, 0.17, 0.6), 60.0, Vector2(0.003, 0.022), true)
	_spatter = _particles("Spatter", 400, 0.8, Color(0.8, 0.88, 0.97, 0.55), 55.0, Vector2(0.006, 0.006), false)
	_mist = _particles("Mist", 520, 3.6, Color(0.9, 0.94, 1.0, 0.26), 95.0, Vector2(1.5, 1.5), false, true)
	_haze = _particles("Haze", 160, 2.2, Color(0.9, 0.94, 1.0, 0.16), 40.0, Vector2(0.9, 0.9), false, true)
	var m: ParticleProcessMaterial = _splash.process_material
	m.initial_velocity_min = 1.5
	m.initial_velocity_max = 5.0
	m.gravity = Vector3(0, -9.8, 0)
	m.damping_min = 3.0
	m.damping_max = 6.0
	m = _dirt.process_material
	m.initial_velocity_min = 1.0
	m.initial_velocity_max = 3.0
	m.gravity = Vector3(0, -9.8, 0)
	m = _spatter.process_material
	m.initial_velocity_min = 0.5
	m.initial_velocity_max = 1.8
	m.gravity = Vector3(0, -9.8, 0)
	m.scale_min = 0.6
	m.scale_max = 1.6
	_billow(_mist.process_material, 0.4, 2.0, 0.3)
	# A haze round the jet itself, from the nozzle to the part (the jet's own mist).
	_billow(_haze.process_material, 0.05, 0.5, 0.06)
	# The jet itself: a bright thin core and a fainter sheath that widens to the surface.
	_core = _cone("Core", 0.004, 0.02, Color(0.9, 0.96, 1.0, 0.28))
	_sheath = _cone("Sheath", 0.012, 0.11, Color(0.8, 0.9, 1.0, 0.1))
	_fog = FogVolume.new()
	_fog.name = "MistFog"
	_fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	_fog.size = Vector3(3.2, 2.4, 3.2)
	_fog_mat = FogMaterial.new()
	_fog_mat.density = 0.0
	_fog_mat.albedo = Color(0.92, 0.95, 1.0)
	_fog_mat.edge_fade = 1.0
	_fog.material = _fog_mat
	add_child(_fog)


## The spray from the nozzle at `from` to the surface at `to` (global).
func aim(from: Vector3, to: Vector3) -> void:
	var gap := to - from
	var d := maxf(gap.length(), 0.05)
	var dir := gap / d
	_jet.global_transform = Transform3D(_basis(dir), from)
	for c: MeshInstance3D in [_core, _sheath]:
		var flick := 1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.05 + (0.0 if c == _core else 1.7))
		c.global_transform = Transform3D(_basis(dir) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(flick, d, flick)), from + dir * d * 0.5)
	var jm: ParticleProcessMaterial = _jet.process_material
	jm.initial_velocity_min = d / JET_LIFE * 0.92
	jm.initial_velocity_max = d / JET_LIFE * 1.02
	# Off the surface: back towards the nozzle and out sideways.
	var back := Transform3D(_basis(-dir), to - dir * 0.02)
	_splash.global_transform = back
	_dirt.global_transform = back
	_spatter.global_transform = back
	_mist.global_transform = Transform3D(_basis(-dir), to - dir * 0.2)
	# The haze comes off the jet along its length.
	var hm: ParticleProcessMaterial = _haze.process_material
	hm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	hm.emission_box_extents = Vector3(0.05, 0.05, d * 0.5)
	_haze.global_transform = Transform3D(_basis(dir), from + dir * d * 0.5)
	_fog.global_position = to - dir * 0.5 + Vector3(0, 0.2, 0)
	_fog_target = 0.6 if on else 0.0


func _process(delta: float) -> void:
	_fog_level = move_toward(_fog_level, _fog_target, delta * (0.8 if _fog_target > _fog_level else 0.35))
	if _fog_mat:
		_fog_mat.density = _fog_level
		_fog.visible = _fog_level > 0.001


## A rolling cloud: puffs that start small at `radius` (m), go out at up to `speed` (m/s), slow,
## rise a little, turn and grow as they fade in, hang and fade out.
static func _billow(m: ParticleProcessMaterial, radius: float, speed: float, rise: float) -> void:
	m.initial_velocity_min = speed * 0.2
	m.initial_velocity_max = speed
	m.gravity = Vector3(0, rise, 0)
	m.damping_min = 0.6
	m.damping_max = 1.4
	m.scale_min = 0.5
	m.scale_max = 1.5
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -20.0
	m.angular_velocity_max = 20.0
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = radius
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.3))
	grow.add_point(Vector2(1, 1.0))
	var gt := CurveTexture.new()
	gt.curve = grow
	m.scale_curve = gt
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	m.color_ramp = ft


## A see-through cone 1 m long along +Y (scaled to the jet's length), `r0` at its bottom.
func _cone(n: String, r0: float, r1: float, colour: Color) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r0
	cm.top_radius = r1
	cm.height = 1.0
	cm.radial_segments = 10
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = colour
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	mi.set_meta("gfx_coplanar_ok", true)
	add_child(mi)
	return mi


## A basis whose -Z is `dir`.
static func _basis(dir: Vector3) -> Basis:
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	return Basis.looking_at(dir, up)


func _particles(n: String, amount: int, life: float, colour: Color, spread: float, size: Vector2,
		streak: bool, puff := false) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = n
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0, -1)
	m.spread = spread
	m.initial_velocity_min = 8.0
	m.initial_velocity_max = 10.0
	m.gravity = Vector3.ZERO
	if not puff:
		var fade := Gradient.new()
		fade.set_color(0, colour)
		fade.set_color(1, Color(colour.r, colour.g, colour.b, 0.0))
		var ft := GradientTexture1D.new()
		ft.gradient = fade
		m.color_ramp = ft
	p.process_material = m
	var q := QuadMesh.new()
	q.size = size
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if streak:
		# Streaks along their flight: the droplets' motion blur.
		p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
		mat.albedo_color = Color(1, 1, 1)
	else:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.billboard_keep_scale = true
		mat.albedo_texture = _puff()
		if puff:
			mat.albedo_color = colour
			mat.proximity_fade_enabled = true
			mat.proximity_fade_distance = 0.35
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	q.material = mat
	p.draw_pass_1 = q
	add_child(p)
	return p


## A soft round spot, white in the middle fading to nothing at its edge.
static func _puff() -> Texture2D:
	if _puff_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_puff_tex = t
	return _puff_tex
