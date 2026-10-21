class_name TradesSparks
extends Node3D
## Sparks off the tools (beenster, 0.3.7: "a lot of sparks which fall under gravity, they can
## bounce off other objects and the floor and then fade away"): bright streaks thrown from
## a point, pulled down by gravity, bouncing off whatever the physics world has there, and
## cooling from white through orange to dull red before they go. One MultiMesh draws them
## all. Also pops: a rivet heated out of its hole jumps off and rattles away. Presentation
## only; nothing here is game state.

## Most sparks alive at once.
const MAX := 600
## Pull down (m/s²), the share of speed kept off a bounce, and how long one lives (s).
const GRAVITY := 9.8
const BOUNCE := 0.35
const LIFE_S := Vector2(0.5, 1.4)
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
	ALBEDO = COLOR.rgb * 1.6;
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
func pop(at: Vector3, vel: Vector3, mesh: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.top_level = true
	add_child(mi)
	mi.global_position = at
	_pops.append({"node": mi, "vel": vel, "spin": Vector3(_rng.randf_range(-20, 20), _rng.randf_range(-20, 20), 0), "age": 0.0})


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


func _step_pops(delta: float, space: PhysicsDirectSpaceState3D) -> void:
	for p in _pops.duplicate():
		var mi: MeshInstance3D = p.node
		p.age += delta
		if p.age > 4.0 or not is_instance_valid(mi):
			if is_instance_valid(mi):
				mi.queue_free()
			_pops.erase(p)
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
		p.vel = v
		mi.global_position = to
		mi.rotation += (p.spin as Vector3) * delta * minf(1.0, v.length())
		mi.transparency = clampf((p.age - 3.0), 0.0, 1.0)


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
