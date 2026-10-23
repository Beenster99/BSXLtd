class_name TradesSparks
extends Node3D
## Sparks off the tools (beenster, 0.3.7: "a lot of sparks which fall under gravity, they can
## bounce off other objects and the floor and then fade away"): bright streaks thrown from
## a point, pulled down by gravity, bouncing off whatever the physics world has there, and
## cooling from white through orange to dull red before they go. One MultiMesh draws them
## all. Also pops: a rivet heated out of its hole jumps off and rattles away. Presentation
## only; nothing here is game state.

## Most sparks alive at once.
const MAX := 1600
## The glow the sparks throw on what's round them (beenster, 2026-10-22: "the surrounding
## area should glow from their emitted light"): a few warm lights, each at the middle of a
## share of the hot sparks, brighter the more sparks it has. Light per hot spark, the most one
## light gives, and its reach (m).
const LIGHTS := 4
const LIGHT_PER_SPARK := 0.035
const LIGHT_MAX := 2.6
const LIGHT_RANGE_M := 3.5
## A spark counts as hot for its first share of its life.
const HOT_SHARE := 0.55
## Pull down (m/s²), the share of speed kept off a bounce, and how long one lives (s).
const GRAVITY := 9.8
const BOUNCE := 0.35
const LIFE_S := Vector2(0.5, 1.4)
## Fallen bolts and rivet heads: how many at once, how long they last and fade (seconds).
const POP_MAX := 100
const POP_LIFE_S := 15.0
const POP_FADE_S := 4.0
## A streak's thickness and its length per m/s of speed (m).
const THICK_M := 0.004
const STREAK_S := 0.012

var _pos: PackedVector3Array = []
var _vel: PackedVector3Array = []
var _age: PackedFloat32Array = []
var _life: PackedFloat32Array = []
var _mm: MultiMesh
var _view: MultiMeshInstance3D
var _rng := RandomNumberGenerator.new()
var _pops: Array[Dictionary] = []
var _lights: Array[OmniLight3D] = []
## Bodies the sparks fly through (the worker).
var exclude: Array[RID] = []


func _ready() -> void:
	top_level = true
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	var streak := BoxMesh.new()
	streak.size = Vector3(1, 1, 1)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
void fragment() {
	ALBEDO = COLOR.rgb * 3.0;
	ALPHA = COLOR.a;
}
"""
	mat.shader = sh
	streak.material = mat
	_mm.mesh = streak
	_mm.instance_count = MAX
	_mm.visible_instance_count = 0
	_view = MultiMeshInstance3D.new()
	_view.multimesh = _mm
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.extra_cull_margin = 50.0
	add_child(_view)
	for i in LIGHTS:
		var l := OmniLight3D.new()
		l.name = "SparkGlow%d" % i
		l.light_color = Color(1.0, 0.62, 0.28)
		l.omni_range = LIGHT_RANGE_M
		l.omni_attenuation = 1.6
		l.shadow_enabled = false
		l.visible = false
		l.set_meta("gfx_no_shadow", true)
		add_child(l)
		_lights.append(l)


## Throws `count` sparks from `at`, in a cone round `dir` (spread 0..1: 0 a jet, 1 a hemisphere)
## at about `speed` m/s.
func emit(at: Vector3, dir: Vector3, count: int, speed: float, spread := 0.6) -> void:
	var d := dir.normalized() if dir.length() > 0.001 else Vector3.UP
	for i in count:
		if _pos.size() >= MAX:
			_remove(0)
		var side := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
		var v := (d + side * spread).normalized() * speed * _rng.randf_range(0.4, 1.2)
		_pos.append(at)
		_vel.append(v)
		_age.append(0.0)
		_life.append(_rng.randf_range(LIFE_S.x, LIFE_S.y))


## A small part jumping off from `at` with velocity `vel`, tumbling, bouncing and fading.
## Bolts and rivet heads that come out fall under gravity and lie where they land (beenster,
## 0.3.14): at most POP_MAX at once (the oldest goes), each gone after POP_LIFE_S, fading
## over the last POP_FADE_S.
func pop(at: Vector3, vel: Vector3, mesh: Mesh, mat: Material) -> void:
	while _pops.size() >= POP_MAX:
		var old: Dictionary = _pops.pop_front()
		if is_instance_valid(old.node):
			(old.node as Node).queue_free()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.top_level = true
	add_child(mi)
	mi.global_position = at
	_pops.append({"node": mi, "vel": vel, "spin": Vector3(_rng.randf_range(-20, 20), _rng.randf_range(-20, 20), 0), "age": 0.0})


## Fallen bits lying about or still falling (tests).
func pop_count() -> int:
	return _pops.size()


## Where the fallen bits are (tests).
func pop_positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in _pops:
		if is_instance_valid(p.node):
			out.append((p.node as Node3D).global_position)
	return out


## Sparks alive now (tests).
func count() -> int:
	return _pos.size()


## Where the sparks are (tests).
func positions() -> PackedVector3Array:
	return _pos


func _physics_process(delta: float) -> void:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	var i := 0
	while i < _pos.size():
		_age[i] += delta
		if _age[i] >= _life[i]:
			_remove(i)
			continue
		var v := _vel[i] + Vector3.DOWN * GRAVITY * delta
		var to := _pos[i] + v * delta
		if space:
			var q := PhysicsRayQueryParameters3D.create(_pos[i], to)
			q.exclude = exclude
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				var n: Vector3 = hit.normal
				v = v.bounce(n) * BOUNCE
				to = (hit.position as Vector3) + n * 0.002
		_vel[i] = v
		_pos[i] = to
		i += 1
	_step_pops(delta, space)
	_draw()
	_glow()


func _step_pops(delta: float, space: PhysicsDirectSpaceState3D) -> void:
	for p in _pops.duplicate():
		var mi: MeshInstance3D = p.node
		p.age += delta
		if p.age > POP_LIFE_S or not is_instance_valid(mi):
			if is_instance_valid(mi):
				mi.queue_free()
			_pops.erase(p)
			continue
		mi.transparency = clampf((p.age - (POP_LIFE_S - POP_FADE_S)) / POP_FADE_S, 0.0, 1.0)
		if p.get("rest", false):
			continue
		var v: Vector3 = p.vel + Vector3.DOWN * GRAVITY * delta
		var to := mi.global_position + v * delta
		if space:
			var q := PhysicsRayQueryParameters3D.create(mi.global_position, to)
			q.exclude = exclude
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				v = v.bounce(hit.normal) * 0.4
				to = (hit.position as Vector3) + (hit.normal as Vector3) * 0.004
				# Slow on something it can lie on: it settles there.
				if v.length() < 0.4 and (hit.normal as Vector3).y > 0.6:
					p.rest = true
					v = Vector3.ZERO
		p.vel = v
		mi.global_position = to
		mi.rotation += (p.spin as Vector3) * delta * minf(1.0, v.length())


func _draw() -> void:
	_mm.visible_instance_count = _pos.size()
	for i in _pos.size():
		var v := _vel[i]
		var speed := v.length()
		var along := v / speed if speed > 0.01 else Vector3.UP
		var side := along.cross(Vector3.UP)
		if side.length() < 0.01:
			side = along.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(along).normalized()
		var length := maxf(THICK_M, speed * STREAK_S)
		var basis := Basis(side * THICK_M, up * THICK_M, along * length)
		_mm.set_instance_transform(i, Transform3D(basis, _pos[i] - along * length * 0.5))
		var t := _age[i] / _life[i]
		var c := Color(1.0, 0.85, 0.45).lerp(Color(1.0, 0.4, 0.05), clampf(t * 2.0, 0.0, 1.0))
		c = c.lerp(Color(0.5, 0.06, 0.0), clampf(t * 2.0 - 1.0, 0.0, 1.0))
		c.a = 1.0 - clampf(t * 1.5 - 0.5, 0.0, 1.0)
		_mm.set_instance_color(i, c)


## Puts the glow lights at the hot sparks: spark i goes to light i mod LIGHTS.
func _glow() -> void:
	var sums: Array[Vector3] = []
	var counts: Array[int] = []
	for k in LIGHTS:
		sums.append(Vector3.ZERO)
		counts.append(0)
	for i in _pos.size():
		if _age[i] > _life[i] * HOT_SHARE:
			continue
		var k := i % LIGHTS
		sums[k] += _pos[i]
		counts[k] += 1
	for k in LIGHTS:
		var l := _lights[k]
		l.visible = counts[k] >= 3
		if l.visible:
			l.global_position = sums[k] / counts[k]
			l.light_energy = minf(LIGHT_MAX, counts[k] * LIGHT_PER_SPARK) * _rng.randf_range(0.8, 1.1)


## Glow lights lit now (tests).
func lit_glows() -> int:
	var n := 0
	for l in _lights:
		n += 1 if l.visible else 0
	return n


func _remove(i: int) -> void:
	var last := _pos.size() - 1
	_pos[i] = _pos[last]
	_vel[i] = _vel[last]
	_age[i] = _age[last]
	_life[i] = _life[last]
	_pos.resize(last)
	_vel.resize(last)
	_age.resize(last)
	_life.resize(last)
