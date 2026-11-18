class_name YardToolEffects
extends Node3D
## What a working tool throws off where it touches, for every player's tool on every machine
## (presentation only, never sent). The flying bits are a YardSparkSpray: sparks, molten globs
## and cold flakes that fly straight (no air, no gravity) and bounce off whatever they meet,
## players' suits included.
##
## Each tool does what its real one does:
## - YardGrinder: a tight fan of sparks thrown off the disc's rim the way it spins (`YardGrinder.
##   rim_direction`), skidding along the plate; steel sparks burst into little stars.
## - YardCutter (gas): the flame splays on the metal over a melt pool that goes from orange to
##   yellow-white, and the oxygen jet blows molten slag off along the surface: globs that
##   stick where they land and cool. On a bolt it only heats.
## - Plasma torch: the arc's blue gas blown out of the far side of the cut with a shower of
##   blue sparks that skip off decks and walls behind it, some sticking there as embers that
##   glow on for ~10 s (YardSparkSpray's embers), a blue light on that side, dross, spatter at
##   the front, smoke curling off the kerf.
## - YardSocket: a seized bolt sheds rust flakes and dust under the hammering and lets go with a
##   crack and a puff; a turning bolt throws glints of thread, a hot one smokes.
## - Battery: a snap of blue sparks as the clamps go on, a crackle while it feeds, a spit as
##   they come off.
## - YardGrabber: dust and flakes pulled off the gripped surface up the beam into the claw.
## What comes off depends on the material (MATERIALS): steel sparks orange and bursts,
## titanium burns white, alloy and copper hardly spark but shed swarf, ceramic and glass
## give grit and spalled flakes, copper turns the gas flame green.

## Hot sparks a second off a grinder biting steel at full spark_amount (the tool's
## spark_amount, the material and the graphics preset scale it). They go into the spray's
## shower, worked out once and moved on the GPU, so this many costs little.
@export var grind_rate: float = 2400.0
## Share of the grinder's sparks that leave right along the plate and skid down it.
@export var grind_hug_share: float = 0.25
## Sparks a second off a grinder skating over plate.
@export var skim_rate: float = 80.0
## Molten globs a second off the gas torch on steel.
@export var slag_rate: float = 28.0
## Hammer blows a second of the socket's impact gun.
@export var hammer_hz: float = 18.0
## Seconds the gas torch takes to bring its melt pool up to yellow-white.
@export var pool_time: float = 1.4
## How far the contact light reaches while a tool bites, metres (the spray lights the room).
@export var bite_light_range: float = 3.0

@export_group("Work glow")
## VX2: how far the work glow lights the room round a biting tool (m): under the 5 m at which
## Graphics.tune_light would give an omni lamp a shadow, and it never has one.
@export var work_glow_range: float = 4.5
## Its brightness at the top of its flicker.
@export var work_glow_energy: float = 0.9
## How far it rises off the work toward the room (m), in the spray.
@export var work_glow_lift: float = 0.35
## How quickly it comes up and dies away (energy a second).
@export var work_glow_ease: float = 6.0
## Its share of a lamp's light in the dust (unshadowed, it would light the dust through walls).
@export var work_glow_fog: float = 0.25
@export_group("")

@export_group("Plasma")
## Sparks and dross globs a second out of the back of a plasma cut (x the material's sparks,
## at least a quarter, and the Particles option).
@export var through_rate: float = 620.0
@export var dross_rate: float = 16.0
## The through-sparks' blue, and how much of it over the metal's own colour (0..1).
@export var plasma_blue := Color(0.2, 0.45, 1.0)
@export var plasma_blue_share: float = 0.9
## A through-spark's glow in flight, seconds (min, max), and its speed, m/s (min, max).
@export var through_life := Vector2(0.9, 2.2)
@export var through_speed := Vector2(3.5, 11.0)
## How wide the spray out of the back fans (0 straight through, 1 a wide fan).
@export var through_spread: float = 0.38
## Chance a through-spark that meets a deck or a wall sticks there as an ember, 0..1 (how long
## they glow: the spray's `ember_seconds`, 10 s).
@export var ember_share: float = 0.45
## The arc's gas out of the back of the cut: its length and its width at the far end, metres,
## and how bright (the core is 1.6 times as bright, half as long and a third as wide).
@export var jet_length: float = 0.34
@export var jet_width: float = 0.09
@export var jet_energy: float = 1.0
## The blue light the cut throws on the far side: energy and reach (m).
@export var back_light_energy: float = 1.6
@export var back_light_range: float = 3.5
@export_group("")

## Per material: sparks (share of the spray), spark colour, forks (share of sparks that burst),
## life (s), speed (x), dust (puffs/s), dust tint, chips (flakes/s), chip colour, slag
## (share of the gas torch's globs), slag colour, spall (flakes/s popping off under a
## flame), flame (the gas flame's colour on it), arcs (it crackles blue when worked),
## shimmer (its sparks change hue).
const MATERIALS: Dictionary = {
	"steel": {"sparks": 1.0, "color": Color(1.0, 0.58, 0.18), "forks": 0.22, "life": 0.75, "speed": 1.0,
			"slag": 1.0, "slag_color": Color(1.0, 0.55, 0.15)},
	"alloy": {"sparks": 0.03, "color": Color(1.0, 0.82, 0.55), "life": 0.3, "speed": 0.7,
			"dust": 6.0, "dust_tint": Color(0.85, 0.86, 0.9), "chips": 12.0, "chip_color": Color(0.8, 0.82, 0.86),
			"slag": 0.5, "slag_color": Color(0.8, 0.7, 0.55)},
	"copper": {"sparks": 0.04, "color": Color(1.0, 0.5, 0.25), "life": 0.35, "speed": 0.6,
			"dust": 2.0, "dust_tint": Color(0.8, 0.6, 0.45), "chips": 14.0, "chip_color": Color(0.85, 0.48, 0.28),
			"slag": 0.6, "slag_color": Color(1.0, 0.5, 0.2), "flame": Color(0.3, 1.0, 0.45)},
	"glass": {"sparks": 0.0, "dust": 10.0, "dust_tint": Color(0.95, 0.97, 1.0), "chips": 18.0,
			"chip_color": Color(0.75, 0.88, 0.95), "slag": 0.25, "slag_color": Color(1.0, 0.6, 0.25), "spall": 4.0},
	"crystal": {"sparks": 0.0, "dust": 10.0, "dust_tint": Color(0.95, 0.94, 1.0), "chips": 18.0,
			"chip_color": Color(0.85, 0.8, 1.0), "slag": 0.25, "slag_color": Color(1.0, 0.6, 0.35), "spall": 4.0},
	"titanium": {"sparks": 1.5, "color": Color(1.0, 0.97, 0.92), "forks": 0.08, "life": 1.1, "speed": 1.25,
			"slag": 0.8, "slag_color": Color(1.0, 0.9, 0.7)},
	"superconductor": {"sparks": 0.25, "color": Color(0.65, 0.85, 1.0), "life": 0.5, "speed": 0.9,
			"chips": 6.0, "chip_color": Color(0.7, 0.75, 0.85), "slag": 0.4, "slag_color": Color(0.7, 0.85, 1.0),
			"arcs": true},
	"ceramic": {"sparks": 0.007, "color": Color(1.0, 0.8, 0.6), "life": 0.2, "dust": 12.0,
			"dust_tint": Color(0.92, 0.9, 0.84), "chips": 8.0, "chip_color": Color(0.9, 0.88, 0.82),
			"slag": 0.0, "spall": 5.0},
	"tungsten": {"sparks": 0.2, "color": Color(1.0, 0.38, 0.1), "life": 0.4, "speed": 0.55,
			"slag": 0.4, "slag_color": Color(1.0, 0.4, 0.1)},
	"veil": {"sparks": 0.9, "color": Color(0.78, 0.55, 1.0), "forks": 0.15, "life": 0.9, "speed": 1.1,
			"slag": 0.6, "slag_color": Color(0.85, 0.6, 1.0), "shimmer": true},
}
## Rust flakes' colours (the socket on a seized bolt, the grabber's motes).
const RUST: Array[Color] = [Color(0.36, 0.17, 0.08), Color(0.5, 0.26, 0.1), Color(0.26, 0.13, 0.07), Color(0.42, 0.33, 0.27)]
const RUST_DUST := Color(0.8, 0.55, 0.38)
const GAS_FLAME := Color(0.35, 0.55, 1.0)

## The flying bits (tests read it).
var spray: YardSparkSpray

var _light: OmniLight3D
## VX2: the room lit round a biting tool ("WorkGlow"): no shadow, the tool's colour, flickering with
## the spray; lit on the `work_glows` budget's nearest biting rigs (`_glows`).
var work_glow: OmniLight3D
## Whether it is lit now (inside the budget and biting; tests read it).
var work_glow_lit := false
var _glow_step: int = -10          # the physics step a biting update last asked for it
var _glow_goal: float = 0.0
var _glow_flicker: float = 0.0
## Every YardToolEffects, for the work glows' budget.
static var _glows: Array[YardToolEffects] = []
var _arc: CPUParticles3D          # blue-white burst: live wiring arcing
var _arc_light: OmniLight3D
var _arc_cooldown: float = 0.0
var _wisps: YardSmokeTrail            # plasma: smoke curling off the kerf
var _wisp_timer: float = 0.0
var _jet_core: MeshInstance3D     # plasma: the gas out of the back of the cut
var _jet_sheath: MeshInstance3D
var _back_light: OmniLight3D      # plasma: the far side lit blue
## The plasma's gas, 0 (off) .. 1 (through and burning), eased (tests read it).
var jet_level: float = 0.0
var _splash: MeshInstance3D       # gas torch: the flame splayed on the metal
var _pool: MeshInstance3D         # gas torch: the melt pool under it
var _splash_mat: StandardMaterial3D
var _pool_mat: StandardMaterial3D
## The gas torch's melt pool, 0 (just lit) .. 1 (yellow-white), for tests.
var pool_heat: float = 0.0
## Spare emission per stream (fractions of a bit carried to the next step).
var _owed: Dictionary = {}
## The physics step `plasma` was last called with `on` (the gas dies away a step after).
var _jet_step: int = -10
## The material the last update was on, for the plasma's through-spray.
var _material: String = ""
## The socket: blow timer, and whether it was straining on a seized bolt last step.
var _blow: float = 0.0
var _was_straining := false
## The battery: feeding last step, and where (for the spit as the clamps come off).
var _was_feeding := false
var _feed_at := Vector3.ZERO
var _feed_normal := Vector3.UP
var _crackle: float = 0.0
## The grabber: holding last step.
var _was_holding := false
## The spray can's mist (made on first use) and how many puffs it has put out (tests).
var _mist: YardSmokeTrail
var mist_puffs: int = 0


func _ready() -> void:
	top_level = true  # lives in world space, placed at the contact point each frame

	spray = YardSparkSpray.new()
	spray.name = "Spray"
	add_child(spray)

	_light = OmniLight3D.new()
	_light.name = "ContactLight"
	_light.omni_range = 2.0
	_light.omni_attenuation = 2.0  # falls off fast: a hot point, not a floodlight
	_light.light_energy = 0.0
	_light.shadow_enabled = true
	_light.position = Vector3(0.0, 0.08, 0.0)
	add_child(_light)

	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var streak := BoxMesh.new()
	streak.size = Vector3(0.006, 0.07, 0.006)
	streak.material = spark_mat
	_arc = CPUParticles3D.new()
	_arc.name = "Arc"
	_arc.mesh = streak
	_arc.amount = 60
	_arc.lifetime = 0.3
	_arc.one_shot = true
	_arc.explosiveness = 1.0
	_arc.local_coords = false
	_arc.emitting = false
	_arc.direction = Vector3.UP
	_arc.spread = 120.0
	_arc.gravity = Vector3.ZERO
	_arc.initial_velocity_min = 3.0
	_arc.initial_velocity_max = 9.0
	_arc.particle_flag_align_y = true
	_arc.scale_amount_min = 0.5
	_arc.scale_amount_max = 1.3
	var blue := Gradient.new()
	blue.set_color(0, Color(0.9, 0.97, 1.0, 1.0))
	blue.set_color(1, Color(0.3, 0.55, 1.0, 0.0))
	_arc.color_ramp = blue
	add_child(_arc)
	work_glow = OmniLight3D.new()
	work_glow.name = "WorkGlow"
	work_glow.omni_range = work_glow_range
	work_glow.omni_attenuation = 1.2
	work_glow.light_energy = 0.0
	work_glow.shadow_enabled = false
	work_glow.set_meta("gfx_no_shadow", true)   # (VX2: it lights the room, the tool's own glow shadows)
	work_glow.light_volumetric_fog_energy = work_glow_fog   # (Graphics keeps it as its own: little dust lit)
	work_glow.light_bake_mode = Light3D.BAKE_DISABLED   # out of the GI: none through walls
	work_glow.position = Vector3(0.0, work_glow_lift, 0.0)
	work_glow.visible = false
	add_child(work_glow)

	_arc_light = OmniLight3D.new()
	_arc_light.name = "ArcLight"
	_arc_light.light_color = Color(0.6, 0.8, 1.0)
	_arc_light.omni_range = 4.0
	_arc_light.light_energy = 0.0
	_arc.add_child(_arc_light)

	# The gas torch's flame splayed flat on the metal (a soft blue disc) over its melt pool.
	_splash_mat = _glow_material()
	_pool_mat = _glow_material()
	_splash = _disc("FlameSplash", _splash_mat)
	_pool = _disc("MeltPool", _pool_mat)

	# The plasma's gas out of the back of a cut, and the blue light it throws on that side.
	_jet_sheath = _jet("JetSheath", 1.0, 1.0)
	_jet_core = _jet("JetCore", 1.6, 0.0)
	_back_light = OmniLight3D.new()
	_back_light.name = "BackLight"
	_back_light.top_level = true
	_back_light.light_color = Color(0.45, 0.65, 1.0)
	_back_light.omni_attenuation = 1.6
	_back_light.light_energy = 0.0
	_back_light.shadow_enabled = true
	_back_light.shadow_bias = 0.004      # a thin plate between it and the front: no leak
	_back_light.light_bake_mode = Light3D.BAKE_DISABLED   # out of the GI: none through walls
	_back_light.visible = false
	add_child(_back_light)


## One of the plasma's gas cones: an open cone, narrow end at the kerf (`brightness` x the
## jet's energy; `cool` 0 keeps it white-blue all along, 1 lets it go blue).
func _jet(jet_name: String, brightness: float, cool: float) -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.5
	cone.bottom_radius = 0.06
	cone.height = 1.0
	cone.cap_top = false
	cone.cap_bottom = false
	cone.radial_segments = 14
	cone.rings = 4
	var mat := ShaderMaterial.new()
	mat.shader = load("res://modules/yard/assets/tools_fx/plasma_jet.gdshader") as Shader
	mat.set_shader_parameter("energy", jet_energy * brightness)
	if cool <= 0.0:
		mat.set_shader_parameter("color", Color(0.6, 0.8, 1.0))
	var m := MeshInstance3D.new()
	m.name = jet_name
	m.mesh = cone
	m.material_override = mat
	m.top_level = true
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	m.visible = false
	add_child(m)
	return m


func _glow_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = YardFx.soft_texture()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m


func _disc(disc_name: String, mat: StandardMaterial3D) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := MeshInstance3D.new()
	m.name = disc_name
	m.mesh = quad
	m.material_override = mat
	m.top_level = true
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	add_child(m)
	return m


func _enter_tree() -> void:
	if not _glows.has(self):
		_glows.append(self)


func _exit_tree() -> void:
	_glows.erase(self)


## Whether this rig's tool is biting now (a work glow wanted, VX2).
func glow_wanted() -> bool:
	return Engine.get_physics_frames() - _glow_step <= 1


## The biting tools' rank by distance from `eye`, this one's place in it (0 nearest).
func _glow_rank(eye: Vector3) -> int:
	var mine := global_position.distance_squared_to(eye)
	var rank := 0
	for e: YardToolEffects in _glows:
		if e != self and is_instance_valid(e) and e.glow_wanted():
			var d := e.global_position.distance_squared_to(eye)
			if d < mine or (d == mine and e.get_instance_id() < get_instance_id()):
				rank += 1
	return rank


## The work glow (VX2): lit while biting and among the `work_glows` nearest the camera.
func _step_glow(delta: float) -> void:
	var lit := glow_wanted()
	if lit:
		var cam := get_viewport().get_camera_3d()
		var eye := cam.global_position if cam else global_position
		lit = _glow_rank(eye) < 2
	work_glow_lit = lit
	var goal := _glow_goal * work_glow_energy if lit else 0.0
	work_glow.light_energy = move_toward(work_glow.light_energy, goal, work_glow_ease * delta)
	work_glow.visible = work_glow.light_energy > 0.0


func _process(delta: float) -> void:
	_step_glow(delta)
	_arc_cooldown -= delta
	if jet_level > 0.0 and Engine.get_physics_frames() - _jet_step > 1:
		_jet_off(delta)
	if _arc_light.light_energy > 0.0:
		_arc_light.light_energy = maxf(_arc_light.light_energy - delta * 30.0, 0.0)


## The material's row in MATERIALS ("" or an unknown one: steel).
static func profile(material: String) -> Dictionary:
	return MATERIALS.get(material, MATERIALS["steel"])


## How many bits stream `key` throws this step at `rate` a second.
func _due(key: String, rate: float, delta: float) -> int:
	if rate <= 0.0:
		_owed.erase(key)
		return 0
	var owed: float = float(_owed.get(key, randf())) + rate * delta
	var n := int(owed)
	_owed[key] = owed - float(n)
	return n


static func _jitter(amount: float) -> Vector3:
	return Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amount


## A direction off a surface facing `n`: out into the open half, spread `spread` (0 straight
## out, 1 anywhere in the half).
static func _off(n: Vector3, spread: float) -> Vector3:
	var d := (n + _jitter(spread * 1.6)).normalized()
	return d if d.dot(n) > 0.05 else (d - n * d.dot(n) * 2.0).normalized()


## Any direction along a surface facing `n`, used when nothing better is known.
static func _along(n: Vector3) -> Vector3:
	return n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()


static func _spark_colour(p: Dictionary, strength: float) -> Color:
	var c: Color = p.get("color", Color(1.0, 0.58, 0.18))
	if p.get("shimmer", false):
		c = Color.from_hsv(fposmod(c.h + randf_range(-0.12, 0.12), 1.0), c.s, c.v)
	return Color(c.r * strength, c.g * strength, c.b * strength, 1.0)


## The spray can's mist, every machine: while `on`, puffs of `colour` out of `nozzle` toward
## `at` (the surface, or the can's reach in the open), `rate` a second, a few splaying off the
## surface. Short-lived and faint, so the line it lays stays in view.
func spray_mist(on: bool, nozzle: Vector3, at: Vector3, colour: Color, rate: float, delta: float) -> void:
	if not on:
		_owed.erase("mist")
		return
	if _mist == null:
		_mist = YardSmokeTrail.new()
		_mist.name = "SprayMist"
		_mist.puff_life = 0.35
		_mist.start_size = 0.02
		_mist.end_size = 0.16
		_mist.tint_min = 0.95
		_mist.tint_max = 1.05
		_mist.opacity = 0.18
		_mist.recycle = true
		add_child(_mist)   # (top level: it lives in world space whatever its parent)
	var span := at - nozzle
	var length := span.length()
	if length < 0.01:
		return
	var along := span / length
	for k in _due("mist", rate * YardFx.effect_scale(), delta):
		var t := randf_range(0.05, 0.95)
		var d := (along + _jitter(0.12)).normalized()
		_mist.puff(nozzle + span * t + _jitter(0.01 + 0.04 * t), d * length / 0.3, colour)
		mist_puffs += 1


## Live wiring arcing at `at`: bursts of blue-white sparks and flashes. Call each frame
## while it happens; `delta` paces the bursts.
func arc(at: Vector3, normal: Vector3, _delta: float) -> void:
	if _arc_cooldown > 0.0:
		return
	_arc_cooldown = randf_range(0.08, 0.22)
	_arc.global_transform = Transform3D(_basis_up(normal), at + normal * 0.03)
	_arc.restart()
	_arc.emitting = true
	_arc_light.light_energy = randf_range(4.0, 8.0)


## The plasma torch's extra show: call every physics step with `on` while the arc is through
## a part `thickness` thick at `at` (facing `normal`): the arc's blue gas and a fan of blue
## sparks blow out of the far side (skipping off what's behind, some sticking there as
## embers), lighting it blue, and smoke curls off the kerf.
func plasma(on: bool, at: Vector3, normal: Vector3, thickness: float, delta: float) -> void:
	if on:
		_jet_step = Engine.get_physics_frames()
	else:
		if _wisps:
			_wisps.close()
			_wisps = null
		_owed.erase("through")
		_owed.erase("dross")
		return
	var back := at - normal * (thickness + 0.02)
	var p := profile(_material)
	var scale := YardFx.effect_scale()
	_burn_jet(at - normal * (thickness + 0.004), -normal, delta)
	# Out of the far side: the arc's gas blows the melt through in a fan, the sparks blue-white
	# (far hotter than a grinder's) and staying blue as they cool; those that meet a deck or a
	# wall skip off it or stick there glowing.
	var tint := plasma_blue
	for k in _due("through", through_rate * maxf(float(p.get("sparks", 0.0)), 0.25) * scale, delta):
		var d := (-normal + _jitter(through_spread)).normalized()
		var c := _spark_colour(p, 0.8).lerp(tint, plasma_blue_share)
		spray.shower(back, d * randf_range(through_speed.x, through_speed.y), randf_range(through_life.x, through_life.y),
				c, -1.0, randf_range(0.8, 1.5), ember_share, true)
	for k in _due("dross", dross_rate * maxf(float(p.get("slag", 0.0)), 0.3) * scale, delta):
		var d := (-normal + _jitter(0.3)).normalized()
		spray.glob(back, d * randf_range(2.0, 5.0), randf_range(1.0, 2.0), p.get("slag_color", Color(1.0, 0.55, 0.15)),
				randf_range(0.006, 0.013))
	if _wisps == null:
		# Thin, faint wisps, so the cut stays in view.
		_wisps = YardSmokeTrail.new()
		_wisps.puff_life = 1.6
		_wisps.start_size = 0.015
		_wisps.end_size = 0.14
		_wisps.tint_min = 0.6
		_wisps.tint_max = 0.8
		_wisps.opacity = 0.22
		add_child(_wisps)   # (top level: it lives in world space whatever its parent)
	_wisp_timer -= delta
	while _wisp_timer <= 0.0:
		_wisp_timer += 0.12
		# A tendril: a few small puffs strung out along one curling path, off the front face
		# (and now and then out of the back).
		var side := 1.0 if randf() < 0.8 else -1.0
		var d := (normal * side + _jitter(0.5)).normalized()
		var curl := d.cross(normal + Vector3(0.3, 0.2, 0.1)).normalized()
		var from := at if side > 0.0 else back
		var speed := randf_range(0.12, 0.3)
		for k in 3:
			var bend := d + curl * 0.35 * float(k)
			_wisps.puff(from + d * (0.015 + 0.02 * float(k)), bend.normalized() * speed * (1.0 - 0.15 * float(k)))


## The arc's gas out of the back of the cut at `at` along `out`, flickering, and the far side
## lit blue (eased off again in `_process` once `plasma` stops being called with `on`).
func _burn_jet(at: Vector3, out: Vector3, delta: float) -> void:
	jet_level = move_toward(jet_level, 1.0, delta * 10.0)
	var flicker := randf_range(0.82, 1.15)
	var length := jet_length * jet_level * flicker
	var basis := _basis_up(out)
	_jet_sheath.global_transform = Transform3D(basis.scaled_local(Vector3(jet_width, length, jet_width) * randf_range(0.9, 1.1)),
			at + out * length * 0.5)
	_jet_core.global_transform = Transform3D(basis.scaled_local(Vector3(jet_width * 0.33, length * 0.5, jet_width * 0.33)),
			at + out * length * 0.25)
	for m: MeshInstance3D in [_jet_sheath, _jet_core]:
		m.visible = true
		(m.material_override as ShaderMaterial).set_shader_parameter("level", jet_level)
	_back_light.visible = true
	_back_light.global_position = at + out * 0.12
	_back_light.omni_range = back_light_range
	_back_light.light_energy = back_light_energy * jet_level * randf_range(0.55, 1.1)   # strobing with the arc


## The gas dies away quickly once the arc is out of the cut.
func _jet_off(delta: float) -> void:
	jet_level = move_toward(jet_level, 0.0, delta * 12.0)
	for m: MeshInstance3D in [_jet_sheath, _jet_core]:
		m.visible = jet_level > 0.0
		(m.material_override as ShaderMaterial).set_shader_parameter("level", jet_level)
	_back_light.light_energy = back_light_energy * jet_level
	_back_light.visible = jet_level > 0.0


## Call every physics step for the tool in hand. `on` = it is working a surface right now
## at `at` (facing `normal`); `cutting_joint` = it is biting a joint, not skating over plate.
func update(on: bool, at: Vector3, normal: Vector3, tool: YardTool, cutting_joint: bool) -> void:
	var delta := get_physics_process_delta_time()
	_material = tool.work_material
	if not (on and tool is YardCutter):
		_gas_off(delta)
	if not (on and tool is YardSocket):
		_was_straining = false
	if not tool is YardGrabber:
		_was_holding = false
	if not on:
		_light.light_energy = move_toward(_light.light_energy, 0.0, 0.5)
		_owed.clear()
		return
	global_transform = Transform3D(_basis_up(normal), at + normal * 0.02)
	_light.position = Vector3(0.0, 0.08, 0.0)
	if tool is YardSocket:
		_socket(tool as YardSocket, at, normal, delta)
	elif tool is YardGrinder:
		_grind(tool as YardGrinder, at, normal, cutting_joint, delta)
	elif tool is YardCutter:
		_gas(tool as YardCutter, at, normal, cutting_joint, delta)
	if not tool.sparks:
		_light.light_energy = move_toward(_light.light_energy, 0.0, 0.5)
		return
	if _light.light_color != tool.light_color:
		_light.light_color = tool.light_color
	var glow := randf_range(0.35, 0.8) if cutting_joint else randf_range(0.1, 0.25)
	_light.light_energy = glow * tool.light_strength
	if cutting_joint:
		# The room round the work flickers with the spray (VX2): a new level now and then.
		_glow_step = Engine.get_physics_frames()
		_glow_flicker -= delta
		if _glow_flicker <= 0.0:
			_glow_flicker = randf_range(0.04, 0.12)
			_glow_goal = randf_range(0.6, 1.0)
		if work_glow.light_color != tool.light_color:
			work_glow.light_color = tool.light_color
		work_glow.position = Vector3(0.0, work_glow_lift, 0.0)
		work_glow.omni_range = work_glow_range
	var reach := bite_light_range if cutting_joint else 2.0
	if _light.omni_range != reach:
		_light.omni_range = reach
	if cutting_joint and profile(tool.work_material).get("arcs", false) and randf() < delta * 3.0:
		arc(at, normal, delta)   # superconductor crackles as it's cut


# --- YardGrinder ----------------------------------------------------------------------------

## A tight fan of sparks off the rim the way the disc turns, lifting a little off the
## plate and skidding along it; grit and swarf for what doesn't spark.
func _grind(g: YardGrinder, at: Vector3, n: Vector3, biting: bool, delta: float) -> void:
	var p := profile(g.work_material)
	var scale := YardFx.effect_scale()
	var too_hard := biting and g.work_factor <= 0.0
	var t := g.rim_direction()
	t -= n * t.dot(n)
	t = t.normalized() if t.length() > 0.05 else _along(n)
	var axis := t.cross(n).normalized()   # the disc's axle, near enough: out of the fan
	var from := at + n * 0.01
	if biting:
		_light.global_position = at + n * 0.2 + t * 0.3   # out in the fan: the shower lights the room
	var rate := grind_rate * g.spark_amount if biting else skim_rate
	if too_hard:
		rate *= 1.5   # it skids on stock it can't cut: all sparks, no bite
	var life: float = float(p.get("life", 0.75)) * (0.5 if too_hard or not biting else 1.0)
	var speed: float = float(p.get("speed", 1.0))
	var forks: float = float(p.get("forks", 0.0))
	var hot := _spark_colour(p, g.spark_strength)
	var shimmer: bool = p.get("shimmer", false)
	var hug_share := grind_hug_share if biting else 0.0
	var lift_max := 38.0 if biting else 60.0
	var lift_min := 3.0 if biting else 5.0
	for k in _due("grind", rate * float(p.get("sparks", 0.0)) * scale, delta):
		# A tight fan: most lift a little off the plate, some leave right along it and skid
		# down it, swung up to 9 degrees either way across it.
		var lift := deg_to_rad(-randf_range(1.0, 6.0) if randf() < hug_share else randf_range(lift_min, lift_max))
		var d := (t * cos(lift) + n * sin(lift) + axis * randf_range(-0.24, 0.24)).normalized()
		var fork := randf_range(0.25, 0.6) * life if randf() < forks else -1.0
		spray.shower(from, d * (randf_range(5.0, 12.0) * speed), life * randf_range(0.6, 1.25),
				_spark_colour(p, g.spark_strength) if shimmer else hot, fork)
	if not biting:
		return
	var chip_color: Color = p.get("chip_color", Color.GRAY)
	for k in _due("swarf", float(p.get("chips", 0.0)) * scale, delta):
		var d := (t + n * randf_range(0.1, 0.6) + _jitter(0.25)).normalized()
		spray.chip(from, d * randf_range(1.0, 3.5), randf_range(1.5, 3.0), chip_color * randf_range(0.8, 1.15),
				randf_range(0.003, 0.009), 25.0)
	for k in _due("grit", float(p.get("dust", 0.0)) * scale, delta):
		spray.dust(from + t * 0.03, (t * 0.5 + n * 0.25 + _jitter(0.15)) * randf_range(0.4, 1.0),
				p.get("dust_tint", Color.WHITE))


# --- Gas cutting torch -----------------------------------------------------------------

## The flame splays on the metal over a melt pool; the oxygen jet blows slag off along the
## surface, away from the torch. On a bolt it only heats (the socket takes it out).
func _gas(c: YardCutter, at: Vector3, n: Vector3, biting: bool, delta: float) -> void:
	var p := profile(c.work_material)
	var scale := YardFx.effect_scale()
	var heating := c.work_kind == ConnectionData.Kind.BOLT
	pool_heat = minf(pool_heat + delta / pool_time, 1.0)
	# The flame splayed on the plate, flickering, and the pool glowing through it.
	var flame: Color = p.get("flame", GAS_FLAME)
	var face := _basis_facing(n)
	var flicker := randf_range(0.85, 1.15)
	_splash.visible = true
	_splash.global_transform = Transform3D(face.scaled(Vector3.ONE * 0.11 * flicker), at + n * 0.006)
	_splash_mat.albedo_color = Color(flame.r, flame.g, flame.b, 0.55 * flicker)
	var pool := Color(1.0, 0.3, 0.05).lerp(Color(1.0, 0.85, 0.5), smoothstep(0.3, 1.0, pool_heat))
	if p.get("spall", 0.0) > 0.0 and not heating:
		pool = pool.lerp(Color(1.0, 0.97, 0.9), 0.5)   # tile and glass go white-hot
	_pool.visible = true
	_pool.global_transform = Transform3D(face.scaled(Vector3.ONE * lerpf(0.025, 0.05, pool_heat)), at + n * 0.004)
	_pool_mat.albedo_color = Color(pool.r, pool.g, pool.b, lerpf(0.4, 1.0, pool_heat))
	if not biting:
		return
	# The jet comes in along the head; what it blows off goes on along the surface.
	var jet := -c.head.global_basis.z if c.head else -c.global_basis.z
	var away := jet - n * jet.dot(n)
	away = away.normalized() if away.length() > 0.1 else _along(n).rotated(n, randf() * TAU)
	var from := at + n * 0.01
	var slag := 0.0 if heating else float(p.get("slag", 0.0)) * smoothstep(0.15, 0.6, pool_heat)
	for k in _due("slag", slag_rate * slag * scale, delta):
		var d := (away + n * randf_range(0.1, 0.7) + _jitter(0.35)).normalized()
		spray.glob(from, d * randf_range(1.2, 4.5), randf_range(1.2, 2.4), p.get("slag_color", Color(1.0, 0.55, 0.15)),
				randf_range(0.006, 0.016))
	var sparks := float(p.get("sparks", 0.0)) * (0.3 if heating else 1.0)
	for k in _due("gas_sparks", 45.0 * sparks * scale, delta):
		var d := (away * randf_range(0.3, 1.0) + _off(n, 0.6)).normalized()
		spray.shower(from, d * randf_range(3.0, 8.0) * float(p.get("speed", 1.0)), randf_range(0.2, 0.5) * float(p.get("life", 0.75)) + 0.1,
				_spark_colour(p, c.spark_strength))
	# Tile and glass can't take the heat: flakes crack off round the flame.
	var chip_color: Color = p.get("chip_color", Color.WHITE)
	for k in _due("spall", float(p.get("spall", 0.0)) * scale, delta):
		var ring := _along(n).rotated(n, randf() * TAU) * randf_range(0.02, 0.06)
		spray.chip(at + ring + n * 0.005, _off(n, 0.5) * randf_range(0.4, 1.6), randf_range(2.0, 3.5), chip_color,
				randf_range(0.006, 0.014), 18.0)


func _gas_off(delta: float) -> void:
	pool_heat = maxf(pool_heat - delta * 3.0, 0.0)
	if _splash and _splash.visible:
		_splash.visible = false
		_pool.visible = false


# --- Plasma torch ----------------------------------------------------------------------

## A little spatter back off the front of the cut (most of it goes out of the back: plasma()).
func _spatter(tool: YardTool, at: Vector3, n: Vector3, delta: float) -> void:
	var p := profile(tool.work_material)
	for k in _due("spatter", 25.0 * maxf(float(p.get("sparks", 0.0)), 0.2) * YardFx.effect_scale(), delta):
		spray.shower(at + n * 0.01, _off(n, 0.7) * randf_range(2.0, 5.0), randf_range(0.15, 0.35),
				_spark_colour(p, 0.8).lerp(plasma_blue.lightened(0.3), 0.6), -1.0, 1.0, 0.0, true)


# --- YardSocket -----------------------------------------------------------------------------

## The impact gun hammering: a seized bolt sheds rust and dust under the blows, then lets go
## with a crack; a turning one throws glints of thread, a hot one smokes.
func _socket(s: YardSocket, at: Vector3, n: Vector3, delta: float) -> void:
	if s.work_kind != ConnectionData.Kind.BOLT:
		_was_straining = false
		return
	var scale := YardFx.effect_scale()
	if s.straining:
		_blow -= delta
		while _blow <= 0.0:
			_blow += 1.0 / hammer_hz
			var flakes := 0
			if randf() < 0.6 * scale:
				flakes = 2 if randf() < 0.3 else 1
			for k in flakes:
				spray.chip(at + _jitter(0.015), _off(n, 0.8) * randf_range(0.3, 1.4), randf_range(2.5, 4.5),
						RUST[randi() % RUST.size()], randf_range(0.005, 0.014), 16.0)
			if randf() < 0.1 * scale:
				spray.dust(at + n * 0.02, _off(n, 0.6) * randf_range(0.15, 0.4), RUST_DUST)
		_was_straining = true
		return
	if _was_straining:
		# It gives: a crack, a cloud of rust and a scatter of flakes.
		_was_straining = false
		for k in int(18 * scale) + 4:
			spray.chip(at + _jitter(0.02), _off(n, 1.0) * randf_range(0.5, 2.2), randf_range(2.5, 5.0),
					RUST[randi() % RUST.size()], randf_range(0.004, 0.013), 20.0)
		for k in 3:
			spray.dust(at + n * 0.03, _off(n, 0.8) * randf_range(0.2, 0.6), RUST_DUST)
	for k in _due("glints", 6.0 * scale, delta):
		spray.chip(at + _jitter(0.01), _off(n, 1.0) * randf_range(0.3, 1.0), randf_range(1.5, 3.0),
				Color(0.85, 0.86, 0.88), randf_range(0.002, 0.005), 30.0)
	if s.work_heat > 0.3:
		for k in _due("bolt_smoke", 5.0 * s.work_heat * scale, delta):
			spray.dust(at + n * 0.02, _off(n, 0.3) * randf_range(0.1, 0.3), Color(0.55, 0.55, 0.55))


# --- Battery ----------------------------------------------------------------------------

## Call every physics step with the battery out: `feeding` while its clamps are on a device
## at `at`. A snap of blue sparks as they go on, a crackle now and then while it feeds, a
## spit as they come off.
func battery(feeding: bool, at: Vector3, normal: Vector3) -> void:
	var delta := get_physics_process_delta_time()
	var blue := Color(0.6, 0.82, 1.0)
	if feeding and not _was_feeding:
		for k in 22:
			spray.spark(at + normal * 0.01, _off(normal, 0.9) * randf_range(2.0, 6.0), randf_range(0.15, 0.4), blue)
		_arc.global_transform = Transform3D(_basis_up(normal), at + normal * 0.03)
		_arc_light.light_energy = 9.0
		_crackle = randf_range(0.4, 1.0)
	elif feeding:
		_crackle -= delta
		if _crackle <= 0.0:
			_crackle = randf_range(0.35, 1.3)
			for k in randi_range(2, 6):
				spray.spark(at + normal * 0.01, _off(normal, 0.8) * randf_range(1.0, 3.5), randf_range(0.08, 0.2), blue, -1.0, 0.7)
			_arc.global_transform = Transform3D(_basis_up(normal), at + normal * 0.03)
			_arc_light.light_energy = randf_range(1.5, 3.5)
	elif _was_feeding:
		for k in 8:
			spray.spark(_feed_at + _feed_normal * 0.01, _off(_feed_normal, 0.9) * randf_range(1.5, 4.0),
					randf_range(0.1, 0.25), blue, -1.0, 0.8)
		_arc_light.light_energy = 3.0
	if feeding:
		_feed_at = at
		_feed_normal = normal
	_was_feeding = feeding


# --- YardGrabber ----------------------------------------------------------------------------

## Call every physics step with the grabber out: `holding` while its beam holds a body by
## `grip` (world). The coil pulls loose rust and grit off the surface up the beam into the
## claw at `claw`; a burst of it as the grip first takes.
func grab(holding: bool, grip: Vector3, claw: Vector3) -> void:
	var delta := get_physics_process_delta_time()
	if not holding:
		_was_holding = false
		_owed.erase("motes")
		return
	var scale := YardFx.effect_scale()
	var n := 18 if not _was_holding else _due("motes", 16.0 * scale, delta)
	for k in n:
		var from := grip + _jitter(0.12)
		var to := claw - from
		var length := to.length()
		if length < 0.05:
			continue
		var speed := randf_range(1.5, 3.5)
		var c := RUST[randi() % RUST.size()] if randf() < 0.6 else Color(0.55, 0.57, 0.6)
		var b := spray.chip(from, to / length * speed, length / speed, c, randf_range(0.002, 0.006), 20.0)
		if b:
			b.needs_ray = false   # they fly into the claw, not off your suit
	if not _was_holding:
		spray.dust(grip, (claw - grip).normalized() * 0.3, RUST_DUST)
	_was_holding = true


static func _basis_up(n: Vector3) -> Basis:
	var up := n.normalized()
	var side := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := side.cross(up).normalized()
	return Basis(x, up, x.cross(up).normalized())


## A basis whose +Z faces along `n` (a QuadMesh laid flat on the surface), turned at random.
static func _basis_facing(n: Vector3) -> Basis:
	var b := _basis_up(n)
	return Basis(b.x, -b.z, b.y).rotated(n.normalized(), randf() * TAU)
