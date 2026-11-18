class_name YardSparkSpray
extends Node3D
## The bits a working tool throws off, simulated in world space and drawn as three
## multimeshes: streaks (hot sparks, stretched along their path like a long exposure), globs
## (molten slag and dross, round and glowing) and chips (cold flakes: rust, paint, swarf,
## tile and glass, tumbling and lit by the scene). Dust goes into a soft smoke trail.
##
## No air and no gravity out here: everything flies straight and only cools. What a bit
## flies into comes from one ray cast along its path (the wreck, loose pieces, any player's
## suit): when it gets there a spark skips off, a chip rattles off and a glob splats and
## sticks, cooling where it landed. A spark or chip that bounced gets one more ray. Rays are
## cast in the physics step, at most `ray_budget` a step; bits past the budget fly on.
##
## The shower (`shower`) is for sparks by the hundred, the grinder's welder-like spray: no
## per-frame work on the CPU at all. Each spark's whole flight (what it hits, the bounce, a
## second hit, a burst into a star) is worked out once when it is thrown, written as a few
## straight stretches into one big multimesh, and moved and cooled by its shader
## (`shaders/spark_shower.gdshader`) from the clock alone. What a shower spark flies into
## comes from probe rays shared by every spark thrown the same way (within `PROBE_CELL`)
## from the same spot (`probe_budget` new ones a step, kept `probe_keep` seconds), taken as
## a flat surface where they met something; its bounce from one more real ray while
## `bounce_budget` lasts.
##
## Embers (`shower(..., stick)`, the plasma's sparks): a shower spark that meets a deck or a
## wall may stick there instead of skipping off, and glows on where it landed, flaring as it
## hits, then a steady dim glow that fades out over `ember_seconds`. Written once like the
## shower, drawn by `shaders/spark_ember.gdshader` from the clock; they ride the body they
## landed on (its transform the layer's `frame` uniform) (up to `MAX_EMBER_FRAMES` moving bodies at once, the rest in world space), so a
## turning wreck or a flying ship keeps its embers. At most the Particles option's
## `GraphicsSettings.VX_BUDGET` "plasma_embers" glow at once per body (`ember_cap`).
## Presentation only, never sent.

enum Kind { STREAK, GLOB, CHIP }

## Most bits alive at once (all kinds); more are dropped.
const MAX_BITS: int = 700
## Bounces a spark or chip may make (each needs a ray).
const MAX_BOUNCES: int = 2

## Rays cast per physics step to find what bits will hit.
@export var ray_budget: int = 16
## How far ahead a bit's ray looks, metres.
@export var ray_reach: float = 8.0
## How much of its path a streak shows, seconds of flight (the long-exposure look).
@export var streak_seconds: float = 0.035
## A streak's thickness, metres.
@export var streak_width: float = 0.007
## Speed kept off a hit, along the surface's normal (0 = none, 1 = all), for sparks and chips.
@export var spark_restitution: float = 0.35
@export var chip_restitution: float = 0.45
## Speed kept along the surface on a hit, 0..1 (sparks skid on).
@export var skid: float = 0.7
## How long a glob glows on after it has stuck where it landed, seconds.
@export var stuck_glow: float = 1.6

## The colour a spark cools to (and a glob, darker).
const COOLED := Color(1.0, 0.2, 0.03)

## Stretches of shower sparks the multimesh holds (a spark is one to a few); past it new
## sparks are dropped until old ones die.
const SHOWER_SLOTS: int = 12288
## How far round where they are thrown shower sparks are drawn (their culling box), metres.
const SHOWER_REACH: float = 12.0
## The shower's probe rays a physics step (new spots and directions).
@export var probe_budget: int = 6
## How long a probe stays good, seconds (a stale one serves till a new one is cast), and how
## far from where it was cast, metres.
@export var probe_keep: float = 0.5
@export var probe_spot: float = 0.12
## Real rays a physics step for shower sparks' bounces (past them a bounced spark flies on).
@export var bounce_budget: int = 6
## Share of shower sparks that throw a couple of short bright splinters where they hit.
@export var splash_share: float = 0.3
## How much of its path a shower streak shows, seconds of flight, and how wide, metres.
@export var shower_streak_seconds: float = 0.045
@export var shower_width: float = 0.0055
## How bright shower sparks glow (past 1 the bloom picks them up).
@export var shower_energy: float = 3.2
## How long a spark that stuck (an ember) glows where it landed, seconds, give or take
## `ember_spread` of it.
@export var ember_seconds: float = 10.0
@export var ember_spread: float = 0.3
## An ember's size, metres (x 0.6 .. 1.4 each), and how bright it glows (past 1 it blooms).
@export var ember_size: float = 0.015
@export var ember_energy: float = 2.4
## Embers glowing at once per body they're on; -1 = the Particles option's VX_BUDGET
## "plasma_embers" (set before the first ember lands).
@export var ember_budget: int = -1

## Moving bodies whose embers are carried with them at once (more: those land in world space).
const MAX_EMBER_FRAMES: int = 4

## Probes are kept per direction cell: a direction x this, rounded (about 6 degrees a cell).
const PROBE_CELL: float = 10.0
## Spots probes are kept for at once (the plasma throws from both faces of the cut).
const PROBE_SPOTS: int = 3

## A probe ray: what it met (a plane at `p` facing `n`) or nothing.
class Probe:
	extends RefCounted
	var hit := false
	var p := Vector3.ZERO
	var n := Vector3.UP
	var born: float = 0.0
	## What it met (a collider), for embers to stick to and ride.
	var body: Object = null


## The embers on one body (null: in world space): a multimesh in its frame, a ring of slots.
class EmberLayer:
	extends RefCounted
	var node: MultiMeshInstance3D
	var mat: ShaderMaterial
	var body: Node3D = null
	var next: int = 0
	var t0 := PackedFloat32Array()
	var gone := PackedFloat32Array()
	## Where each sits, in the body's space (the multimesh holds it too: tests read this).
	var at := PackedVector3Array()
	## Clock when its last ember is out, and the box they're in (the body's space).
	var until: float = -1.0
	var box := AABB()


class Bit:
	extends RefCounted
	var kind: int = 0
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var age: float = 0.0
	var life: float = 1.0
	var hot := Color.WHITE
	var size: float = 1.0
	## Age at which a streak bursts into a little star (-1 never).
	var fork: float = -1.0
	## Age at which it meets what its ray found (INF: nothing), there, facing.
	var hit_t: float = INF
	var hit_p := Vector3.ZERO
	var hit_n := Vector3.UP
	var needs_ray := false
	var bounces: int = 0
	var stuck := false
	## A chip's tumble: axis times radians per second.
	var spin := Vector3.ZERO


var _bits: Array[Bit] = []
var _streaks: MultiMeshInstance3D
var _globs: MultiMeshInstance3D
var _chips: MultiMeshInstance3D
var _dust: YardSmokeTrail
## Rays cast so far (counts across the spray's life: tests read it).
var rays_cast: int = 0
## Hits found (a bit flying into something), and bounces made off them.
var hits_found: int = 0
var bounces_made: int = 0
## Shower sparks thrown, and dropped for want of room.
var shower_thrown: int = 0
var shower_dropped: int = 0
## Sparks that stuck as embers, and embers dropped for want of room.
var embers_stuck: int = 0
var embers_dropped: int = 0
## The colour the last shower spark was thrown with and whether it keeps its hue (tests).
var last_hot := Color.BLACK
var last_keep_hue := false

## The shower: its multimesh, the clock its shader runs on (seconds), the next slot to write,
## and per slot when it starts, when it is gone, its velocity and whether it is a spark's
## first stretch (what `count` and the tests read).
var _shower: MultiMeshInstance3D
var _shower_mat: ShaderMaterial
var _now: float = 0.0
var _frame_dt: float = 1.0 / 60.0
var _next_slot: int = 0
var _slot_t0 := PackedFloat32Array()
var _slot_gone := PackedFloat32Array()
var _slot_vel := PackedVector3Array()
var _slot_first := PackedByteArray()
## Clock when the last shower stretch is gone, and the box they fly in (for culling).
var _shower_until: float = -1.0
var _shower_box := AABB()
## Per spot probes are kept for: [where, {direction cell (Vector3i): Probe}], newest last.
var _spots: Array = []
var _last_at := Vector3.INF
var _last_cells: Dictionary = {}
var _step: int = -1
var _probes_used: int = 0
var _bounces_used: int = 0

var _ember_layers: Array[EmberLayer] = []

static var _hot_mat: ShaderMaterial
static var _shower_shader: Shader
static var _ember_shader: Shader
static var _chip_mat: StandardMaterial3D


func _init() -> void:
	top_level = true


func _ready() -> void:
	if _hot_mat == null:
		_hot_mat = ShaderMaterial.new()
		_hot_mat.shader = load("res://modules/yard/assets/tools_fx/tool_spark.gdshader") as Shader
		_chip_mat = StandardMaterial3D.new()
		_chip_mat.vertex_color_use_as_albedo = true
		_chip_mat.metallic = 0.35
		_chip_mat.roughness = 0.55
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_streaks = _layer("Streaks", box, _hot_mat)
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 8
	ball.rings = 4
	_globs = _layer("Globs", ball, _hot_mat)
	_chips = _layer("Chips", box, _chip_mat)
	if _shower_shader == null:
		_shower_shader = load("res://modules/yard/assets/tools_fx/spark_shower.gdshader") as Shader
	_shower_mat = ShaderMaterial.new()
	_shower_mat.shader = _shower_shader
	_shower_mat.set_shader_parameter("streak_seconds", shower_streak_seconds)
	_shower_mat.set_shader_parameter("width", shower_width)
	_shower_mat.set_shader_parameter("energy", shower_energy)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_shower = _layer("Shower", quad, _shower_mat, SHOWER_SLOTS, false)
	_shower.multimesh.visible_instance_count = -1
	_shower.multimesh.custom_aabb = AABB(Vector3.ONE * -0.5, Vector3.ONE)
	_shower.visible = false
	_slot_t0.resize(SHOWER_SLOTS)
	_slot_gone.resize(SHOWER_SLOTS)
	_slot_gone.fill(-1.0)
	_slot_vel.resize(SHOWER_SLOTS)
	_slot_first.resize(SHOWER_SLOTS)


func _layer(layer_name: String, mesh: Mesh, mat: Material, slots: int = MAX_BITS, colors: bool = true) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = layer_name
	mmi.top_level = true
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = slots
	mm.visible_instance_count = 0
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mmi


# --- Throwing ---------------------------------------------------------------------------

## A hot spark from `at` along `vel` (m/s), glowing `hot` as it leaves and cooling over
## `life` seconds; `fork` (age, s, or -1) bursts it into a little star of sparks then.
## (Each of these returns the new bit, or null when the spray is full.)
func spark(at: Vector3, vel: Vector3, life: float, hot: Color, fork: float = -1.0, size: float = 1.0) -> Bit:
	var b := _add(Kind.STREAK, at, vel, life, hot, size)
	if b:
		b.fork = fork
	return b


## A molten glob `size` metres across: slag or dross. It sticks where it lands.
func glob(at: Vector3, vel: Vector3, life: float, hot: Color, size: float) -> Bit:
	return _add(Kind.GLOB, at, vel, life, hot, size)


## A cold flake `size` metres across, of colour `color`, tumbling at up to `tumble` rad/s.
func chip(at: Vector3, vel: Vector3, life: float, color: Color, size: float, tumble: float = 12.0) -> Bit:
	var b := _add(Kind.CHIP, at, vel, life, color, size)
	if b:
		b.spin = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() \
				* randf_range(0.3, 1.0) * tumble
	return b


## A puff of dust at `at` drifting along `drift` (m/s), tinted `tint` (fine grit, rust, tile).
func dust(at: Vector3, drift: Vector3, tint: Color) -> void:
	if _dust == null or not is_instance_valid(_dust) or _dust.is_full():
		if _dust and is_instance_valid(_dust):
			_dust.close()
		_dust = YardSmokeTrail.new()
		_dust.name = "Dust"
		_dust.puff_life = 1.4
		_dust.start_size = 0.03
		_dust.end_size = 0.3
		_dust.tint_min = 0.85
		_dust.tint_max = 1.0
		_dust.opacity = 0.35
		_dust.stretch = 0.6
		_dust.material_override = YardFx.dust_material()   # ragged, not round
		add_child(_dust)
	_dust.puff(at, drift, tint)


func _add(kind: int, at: Vector3, vel: Vector3, life: float, hot: Color, size: float) -> Bit:
	if _bits.size() >= MAX_BITS or life <= 0.0:
		return null
	var b := Bit.new()
	b.kind = kind
	b.pos = at
	b.vel = vel
	b.life = life
	b.hot = hot
	b.size = size
	b.needs_ray = vel.length_squared() > 0.0001
	_bits.append(b)
	return b


## How many bits of `kind` are flying (or stuck) now.
func count(kind: int) -> int:
	var n := shower_count() if kind == Kind.STREAK else 0
	for b in _bits:
		if b.kind == kind:
			n += 1
	return n


func live_bits() -> Array[Bit]:
	return _bits


# --- The shower ------------------------------------------------------------------------

## A hot spark for the shower (the grinder's hundreds): from `at` along `vel` (m/s), glowing
## `hot` as it leaves and cooling over `life` seconds; `fork` (age, s, or -1) bursts it into
## a little star then. Its whole flight is worked out now (what it hits, its bounce, a second
## hit, the star) and drawn by the shader from then on. False when the shower is full.
## `stick`: the chance a hit leaves it stuck there as an ember instead (never on a suit);
## `keep_hue`: it cools to a dim shade of its own colour, not a metal spark's dull red (the
## plasma's blue). Call it in the physics step (it may cast rays).
func shower(at: Vector3, vel: Vector3, life: float, hot: Color, fork: float = -1.0, size: float = 1.0,
		stick: float = 0.0, keep_hue: bool = false) -> bool:
	if _shower == null or life <= 0.0 or _slot_gone[_next_slot] > _now:
		shower_dropped += 1
		return false
	_new_step()
	shower_thrown += 1
	last_hot = hot
	last_keep_hue = keep_hue
	if _shower_until < _now:
		_shower_box = AABB(at - Vector3.ONE * SHOWER_REACH, Vector3.ONE * SHOWER_REACH * 2.0)
	elif not _shower_box.has_point(at):
		_shower_box = _shower_box.merge(AABB(at - Vector3.ONE * SHOWER_REACH, Vector3.ONE * SHOWER_REACH * 2.0))
	# Thrown at some moment in the frame the shader draws next, so a step's sparks don't bunch.
	var t0 := _now + randf() * _frame_dt
	var hit := _probe_hit(at, vel)
	var hue := -1.0 if keep_hue else 1.0   # the size's sign tells the shader how it cools
	var p0 := at
	var heat := 0.0
	var first := true
	var bounces := 0
	while true:
		var remain := life - heat
		var end := remain
		var event := 0   # 0 dies, 1 hits something, 2 bursts
		if not hit.is_empty() and float(hit[0]) < end:
			end = float(hit[0])
			event = 1
		if fork > heat and fork - heat < end:
			end = fork - heat
			event = 2
		if not _segment(p0, vel, t0, end, heat, life, size * hue, hot, first):
			return true
		first = false
		var there := p0 + vel * end
		t0 += end
		heat += end
		if event == 0:
			return true
		var speed := vel.length()
		if event == 2:
			# A carbon burst: a few short bright ones off where it popped, and it is gone.
			var d := vel / maxf(speed, 0.001)
			var star := hot.lerp(Color(1.0, 0.95, 0.8), 0.6)
			for k in randi_range(3, 5):
				var out := (d + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))).normalized()
				_segment(there, out * speed * randf_range(0.3, 0.7), t0, INF, 0.0, randf_range(0.08, 0.2), 0.6 * hue, star, false)
			return true
		# It hits: sticks there glowing (an ember), or skids off, having lost heat on it, and
		# now and then throws splinters.
		var n: Vector3 = hit[2]
		hits_found += 1
		if stick > 0.0 and randf() < stick and _sticks_to(hit[3]):
			_ember(there, n, t0, hot, hit[3])
			return true
		vel = bounced(vel, n, spark_restitution)
		life = heat + (life - heat) * 0.6
		fork = -1.0
		bounces += 1
		bounces_made += 1
		p0 = there + n * 0.003
		if randf() < splash_share:
			for k in randi_range(1, 2):
				var out := bounced(vel, n, 1.0).normalized().slerp(_off_surface(n), randf_range(0.2, 0.6))
				_segment(p0, out * speed * randf_range(0.25, 0.55), t0, INF, 0.03, randf_range(0.1, 0.22), 0.55 * hue,
						hot.lerp(Color(1.0, 0.92, 0.75), 0.5), false)
		hit = []
		if bounces < MAX_BOUNCES and _bounces_used < bounce_budget:
			_bounces_used += 1
			hit = _ray_hit(p0, vel)
	return true


## How many shower sparks are flying now (a spark's first stretch till it ends or it bounces).
func shower_count() -> int:
	var n := 0
	if _shower_until < _now:
		return 0
	for i in SHOWER_SLOTS:
		if _slot_first[i] == 1 and _slot_t0[i] <= _now and _slot_gone[i] > _now:
			n += 1
	return n


## The shower sparks flying now on their first stretch, as velocities (the tests read them).
func shower_velocities() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in SHOWER_SLOTS:
		if _slot_first[i] == 1 and _slot_t0[i] <= _now and _slot_gone[i] > _now:
			out.append(_slot_vel[i])
	return out


## A speed `vel` off a surface facing `n`: keeps `skid` of it along the surface and `e` of it
## along the normal, roughed up a little.
func bounced(vel: Vector3, n: Vector3, e: float) -> Vector3:
	var into := vel.dot(n)
	if into >= 0.0:
		return vel
	var along := (vel - n * into) * skid
	var jitter := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * vel.length() * 0.15
	jitter -= n * jitter.dot(n)
	return along - n * into * e + jitter


static func _off_surface(n: Vector3) -> Vector3:
	var d := (n + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 1.2).normalized()
	return d if d.dot(n) > 0.05 else (d - n * d.dot(n) * 2.0).normalized()


## One straight stretch of a shower spark: from `p0` along `vel` from clock `t0` for `end`
## seconds (INF: till it cools), `heat0` its age then, `life` its whole glow.
func _segment(p0: Vector3, vel: Vector3, t0: float, end: float, heat0: float, life: float, size: float,
		hot: Color, first: bool) -> bool:
	var i := _next_slot
	if _slot_gone[i] > _now:
		shower_dropped += 1
		return false
	end = minf(end, life - heat0)
	if end <= 0.0:
		return true
	var code := float(int(clampf(hot.r, 0.0, 1.0) * 255.0) + int(clampf(hot.g, 0.0, 1.0) * 255.0) * 256 \
			+ int(clampf(hot.b, 0.0, 1.0) * 255.0) * 65536)
	_shower.multimesh.set_instance_transform(i, Transform3D(Basis(vel, Vector3(t0, end, heat0),
			Vector3(life, size, code)), p0))
	var gone := t0 + minf(end + shower_streak_seconds, life - heat0)
	_slot_t0[i] = t0
	_slot_gone[i] = gone
	_slot_vel[i] = vel
	_slot_first[i] = 1 if first else 0
	_next_slot = (i + 1) % SHOWER_SLOTS
	_shower_until = maxf(_shower_until, gone)
	return true


func _new_step() -> void:
	var step := Engine.get_physics_frames()
	if step == _step:
		return
	_step = step
	_probes_used = 0
	_bounces_used = 0


## What a shower spark from `at` along `vel` flies into: [seconds, point, normal], or []
## for nothing. From the probe for its direction cell from this spot (cast along it now if
## there is none or it is stale and the budget lasts), taken as a flat surface.
func _probe_hit(at: Vector3, vel: Vector3) -> Array:
	var speed := vel.length()
	if speed < 0.01:
		return []
	var d := vel / speed
	var cells := _cells_at(at)
	var key := Vector3i((d * PROBE_CELL).round())
	var pr: Probe = cells.get(key)
	if (pr == null or _now - pr.born > probe_keep) and _probes_used < probe_budget:
		_probes_used += 1
		pr = _cast_probe(at, d)
		cells[key] = pr
	if pr == null or not pr.hit:
		return []
	var into := vel.dot(pr.n)
	if into > -0.02 * speed:
		return []
	var t := (pr.p - at).dot(pr.n) / into
	if t <= 0.0 or t * speed > ray_reach:
		return []
	return [t, at + vel * t, pr.n, pr.body]


## The probe cells kept for the spot `at` (a new set if it is somewhere else).
func _cells_at(at: Vector3) -> Dictionary:
	if at == _last_at:
		return _last_cells
	_last_at = at
	_last_cells = _find_cells(at)
	return _last_cells


func _find_cells(at: Vector3) -> Dictionary:
	var near := probe_spot * probe_spot
	for spot: Array in _spots:
		if (spot[0] as Vector3).distance_squared_to(at) < near:
			return spot[1]
	if _spots.size() >= PROBE_SPOTS:
		_spots.pop_front()
	var cells := {}
	_spots.append([at, cells])
	return cells


func _cast_probe(at: Vector3, d: Vector3) -> Probe:
	var pr := Probe.new()
	pr.born = _now
	var hit := _intersect(at, at + d * ray_reach)
	if not hit.is_empty():
		pr.hit = true
		pr.p = hit.position
		pr.n = (hit.normal as Vector3).normalized()
		pr.body = hit.get("collider")
	return pr


## A real ray for a bounced spark: [seconds, point, normal] or [].
func _ray_hit(at: Vector3, vel: Vector3) -> Array:
	var speed := vel.length()
	if speed < 0.01:
		return []
	var hit := _intersect(at, at + vel / speed * ray_reach)
	if hit.is_empty():
		return []
	var p: Vector3 = hit.position
	return [at.distance_to(p) / speed, p, (hit.normal as Vector3).normalized(), hit.get("collider")]


func _intersect(from: Vector3, to: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2 | 8
	rays_cast += 1
	return get_world_3d().direct_space_state.intersect_ray(query)


## Every slot empty and the clock back to 0 (it runs on in float seconds otherwise).
func _reset_shower() -> void:
	_now = 0.0
	_shower_until = -1.0
	_slot_gone.fill(-1.0)
	_slot_first.fill(0)
	var zero := PackedFloat32Array()
	zero.resize(SHOWER_SLOTS * 12)
	_shower.multimesh.buffer = zero
	_spots.clear()
	_last_at = Vector3.INF
	for layer in _ember_layers:
		layer.node.queue_free()
	_ember_layers.clear()


# --- Embers ----------------------------------------------------------------------------

## Embers glowing at once per body (`ember_budget`, else the Particles option's budget).
func ember_cap() -> int:
	if ember_budget >= 0:
		return ember_budget
	var b: Variant = null
	return int(b) if b != null else 1200


## How many embers glow now (landed, not yet out), over every body.
func ember_count() -> int:
	var n := 0
	for layer in _ember_layers:
		if layer.until < _now:
			continue
		for i in layer.gone.size():
			if layer.t0[i] <= _now and layer.gone[i] > _now:
				n += 1
	return n


## The embers' layers (tests read them): one per body they're on, null = world space.
func ember_layers() -> Array[EmberLayer]:
	return _ember_layers


## Whether a spark sticks to `body`: never to a suit (a crewmate walks through the spray).
static func _sticks_to(body: Object) -> bool:
	var o := body as CollisionObject3D
	return o == null or o.collision_layer & (2 | 8) == 0


## The frame an ember on `body` rides: a body that moves (a wreck, a piece, a ship), else
## world space (null).
static func _frame_of(body: Object) -> Node3D:
	return body as RigidBody3D


## A spark stuck at `at` on a surface facing `n`, landing at clock `t` with its colour `hot`.
func _ember(at: Vector3, n: Vector3, t: float, hot: Color, body: Object) -> bool:
	if ember_seconds <= 0.0:
		return false
	var layer := _layer_for(_frame_of(body))
	if layer == null or layer.gone[layer.next] > _now:
		embers_dropped += 1
		return false
	var i := layer.next
	var life := ember_seconds * randf_range(1.0 - ember_spread, 1.0 + ember_spread)
	var p := at + n * 0.003
	var local_n := n
	if layer.body:
		var to_local := layer.body.global_transform.affine_inverse()
		p = to_local * p
		local_n = (to_local.basis * n).normalized()
	var code := float(int(clampf(hot.r, 0.0, 1.0) * 255.0) + int(clampf(hot.g, 0.0, 1.0) * 255.0) * 256 \
			+ int(clampf(hot.b, 0.0, 1.0) * 255.0) * 65536)
	layer.node.multimesh.set_instance_transform(i, Transform3D(Basis(local_n,
			Vector3(t, life, ember_size * randf_range(0.6, 1.4)), Vector3(code, randf(), 0.0)), p))
	layer.t0[i] = t
	layer.gone[i] = t + life
	layer.at[i] = p
	layer.next = (i + 1) % layer.gone.size()
	var spot := AABB(p - Vector3.ONE * 0.1, Vector3.ONE * 0.2)
	layer.box = spot if layer.until < _now else layer.box.merge(spot)
	layer.until = maxf(layer.until, t + life)
	embers_stuck += 1
	return true


## The layer for embers on `body` (null: world space): its own, an idle one taken over, a new
## one, or (every frame busy) world space's.
func _layer_for(body: Node3D) -> EmberLayer:
	if _ember_shader == null:
		_ember_shader = load("res://modules/yard/assets/tools_fx/spark_ember.gdshader") as Shader
	var idle: EmberLayer = null
	var moving := 0
	for layer in _ember_layers:
		if layer.body == body:
			return layer
		if layer.body != null:
			moving += 1
			if layer.until < _now:
				idle = layer
	if body != null and idle:
		idle.body = body
		return idle
	if body != null and moving >= MAX_EMBER_FRAMES:
		return _layer_for(null)
	var cap := maxi(ember_cap(), 1)
	var layer := EmberLayer.new()
	layer.body = body
	layer.mat = ShaderMaterial.new()
	layer.mat.shader = _ember_shader
	layer.mat.set_shader_parameter("energy", ember_energy)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	layer.node = _layer("Embers", quad, layer.mat, cap, false)
	layer.node.multimesh.visible_instance_count = -1
	layer.node.visible = false
	layer.t0.resize(cap)
	layer.at.resize(cap)
	layer.gone.resize(cap)
	layer.gone.fill(-1.0)
	_ember_layers.append(layer)
	return layer


func _embers_on() -> bool:
	for layer in _ember_layers:
		if layer.until >= _now:
			return true
	return false


## Each frame: every layer with embers glowing shown in its body's frame (a body gone takes
## its embers with it).
func _place_embers() -> void:
	if _ember_layers.is_empty():
		return
	var i := 0
	while i < _ember_layers.size():
		var layer := _ember_layers[i]
		if layer.body != null and not is_instance_valid(layer.body):
			layer.node.queue_free()
			_ember_layers.remove_at(i)
			continue
		var on := layer.until >= _now
		layer.node.visible = on
		if on:
			var frame := layer.body.global_transform if layer.body else Transform3D.IDENTITY
			layer.mat.set_shader_parameter("now", _now)
			layer.mat.set_shader_parameter("frame", Projection(frame))
			layer.node.multimesh.custom_aabb = frame * layer.box
		i += 1


# --- Simulation -------------------------------------------------------------------------

## Casts the rays that find what new (and freshly bounced) bits will fly into.
func _physics_process(_delta: float) -> void:
	if _bits.is_empty() or not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var used := 0
	for b in _bits:
		if not b.needs_ray:
			continue
		if used >= ray_budget:
			break
		b.needs_ray = false
		var speed := b.vel.length()
		var reach := minf(speed * (b.life - b.age), ray_reach)
		if reach < 0.02:
			continue
		var query := PhysicsRayQueryParameters3D.create(b.pos, b.pos + b.vel / speed * reach)
		query.collision_mask = 1 | 2 | 8
		var hit := space.intersect_ray(query)
		used += 1
		rays_cast += 1
		if hit.is_empty():
			continue
		hits_found += 1
		b.hit_p = hit.position
		b.hit_n = (hit.normal as Vector3).normalized()
		b.hit_t = b.age + b.pos.distance_to(b.hit_p) / speed
	# Bits that never got a ray before they died need none.


func _process(delta: float) -> void:
	_now += delta
	_frame_dt = clampf(delta, 0.001, 0.1)
	if _shower:
		var on := _now < _shower_until
		_shower.visible = on
		if on:
			_shower_mat.set_shader_parameter("now", _now)
			_shower.multimesh.custom_aabb = _shower_box
		elif _now > 600.0 and not _embers_on():
			_reset_shower()   # idle a while: start the clock again before it loses precision
	_place_embers()
	var i := 0
	while i < _bits.size():
		var b := _bits[i]
		b.age += delta
		if b.age >= b.life:
			_bits[i] = _bits[_bits.size() - 1]
			_bits.pop_back()
			continue
		if b.age >= b.hit_t:
			_bounce(b)
		elif b.kind == Kind.STREAK and b.fork > 0.0 and b.age >= b.fork:
			_burst(b)
		if not b.stuck:
			b.pos += b.vel * delta
		i += 1
	_draw()


## Its ray's hit has come: a spark skips off, a chip rattles off, a glob sticks.
func _bounce(b: Bit) -> void:
	var n := b.hit_n
	b.hit_t = INF
	b.pos = b.hit_p + n * 0.003
	if b.kind == Kind.GLOB:
		b.stuck = true
		b.vel = Vector3.ZERO
		b.pos = b.hit_p + n * b.size * 0.3
		# Cools where it landed: the glow it had left, then some.
		b.life = b.age + minf(b.life - b.age, 0.6) + stuck_glow
		bounces_made += 1
		return
	if b.vel.dot(n) >= 0.0:
		return
	b.vel = bounced(b.vel, n, spark_restitution if b.kind == Kind.STREAK else chip_restitution)
	b.bounces += 1
	bounces_made += 1
	b.needs_ray = b.bounces < MAX_BOUNCES
	if b.kind == Kind.STREAK:
		b.fork = -1.0
		b.life = b.age + (b.life - b.age) * 0.6   # it lost heat on the hit
	else:
		b.spin = b.spin.rotated(n, randf_range(1.0, 3.0)) * randf_range(0.8, 1.6)


## A carbon burst: the spark pops into a few short bright ones and is gone.
func _burst(b: Bit) -> void:
	var speed := b.vel.length()
	for k in randi_range(3, 5):
		var d := (b.vel / maxf(speed, 0.001) + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))).normalized()
		var s := _add(Kind.STREAK, b.pos, d * speed * randf_range(0.3, 0.7), randf_range(0.08, 0.2),
				b.hot.lerp(Color(1.0, 0.95, 0.8), 0.6), 0.6)
		if s:
			s.needs_ray = false
	b.life = b.age


func _draw() -> void:
	var streaks := _streaks.multimesh
	var globs := _globs.multimesh
	var chips := _chips.multimesh
	var ns := 0
	var ng := 0
	var nc := 0
	for b in _bits:
		var t := b.age / b.life
		match b.kind:
			Kind.STREAK:
				var speed := b.vel.length()
				var dir := b.vel / speed if speed > 0.001 else Vector3.UP
				var length := clampf(speed * streak_seconds, 0.015, 0.4) * b.size
				var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
				var w := streak_width * b.size
				var basis := Basis(side * w, dir * length, side.cross(dir) * w)
				streaks.set_instance_transform(ns, Transform3D(basis, b.pos - dir * length * 0.5))
				# White-hot as it leaves, its own colour, then cooling to a dull red.
				var c := Color(1.0, 0.97, 0.88).lerp(b.hot, smoothstep(0.0, 0.18, t)).lerp(COOLED, smoothstep(0.35, 1.0, t))
				c.a = 1.0 - t * t
				streaks.set_instance_color(ns, c)
				ns += 1
			Kind.GLOB:
				var speed := b.vel.length()
				var stretch := 1.0 + minf(speed * 0.12, 0.9)
				var dir := b.vel / speed if speed > 0.001 else b.hit_n
				var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
				var flat := 0.55 if b.stuck else 1.0   # a splat once it has landed
				var basis := Basis(side * b.size, dir * b.size * stretch * flat, side.cross(dir) * b.size)
				globs.set_instance_transform(ng, Transform3D(basis, b.pos))
				var c := Color(1.0, 0.92, 0.7).lerp(b.hot, smoothstep(0.0, 0.3, t)).lerp(COOLED * 0.5, smoothstep(0.4, 1.0, t))
				c.a = 1.0 - smoothstep(0.7, 1.0, t)
				globs.set_instance_color(ng, c)
				ng += 1
			Kind.CHIP:
				var shrink := 1.0 - smoothstep(0.85, 1.0, t)
				var s := b.size * shrink
				var turn := Basis.IDENTITY
				var rate := b.spin.length()
				if rate > 0.001:
					turn = Basis(b.spin / rate, rate * b.age)
				chips.set_instance_transform(nc, Transform3D(turn.scaled_local(Vector3(s, s * 0.22, s * 0.7)), b.pos))
				chips.set_instance_color(nc, b.hot)
				nc += 1
	streaks.visible_instance_count = ns
	globs.visible_instance_count = ng
	chips.visible_instance_count = nc
