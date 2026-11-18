class_name YardSmokeTrail
extends MultiMeshInstance3D
## A lingering trail of soft smoke puffs (a limpet's rocket trail). Puffs are added along a
## path, then each grows, drifts and fades on its own; the trail frees itself once the last
## has gone. One multimesh for the whole trail, so long trails stay cheap.

## Seconds each puff lasts.
@export var puff_life: float = 2.2
## Puff size at birth and at the end, in metres.
@export var start_size: float = 0.12
@export var end_size: float = 0.9
## How light the puffs are (0 black, 1 white), picked per puff between these.
@export var tint_min: float = 0.42
@export var tint_max: float = 0.78
## How opaque a fresh puff is, 0..1 (thin wisps: low).
@export var opacity: float = 0.72
## How much longer than wide a puff may be drawn, along its own turn (0 round; dust 0.6).
@export var stretch: float = 0.0
## Full, a new puff takes the oldest one's place once that has faded (a fire burning for
## minutes keeps one trail), rather than being dropped.
@export var recycle: bool = false

const MAX_PUFFS: int = 160

var _pos: Array[Vector3] = []
var _drift: Array[Vector3] = []
## Each puff's carrier: the velocity of what it came off (a drifting wreck), never slowed.
var _carry: Array[Vector3] = []
var _age: Array[float] = []
var _spin: Array[float] = []
## Each puff's own shape: its length over its width, and its patch of YardFx.dust_material's noise
## (the instance's custom data, which only that material reads).
var _aspect: Array[float] = []
var _seed: Array[Vector2] = []
## Each puff's own grey: varied darker and lighter, a touch warm or cool.
var _tints: Array[Color] = []
var _closed := false
## The slot the next recycled puff takes (`recycle`): puffs live alike, so the oldest.
var _ring: int = 0


func _init() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = MAX_PUFFS
	mm.visible_instance_count = 0
	multimesh = mm
	material_override = YardFx.smoke_material()


## Adds a puff at `at` (world space), drifting gently along `drift` (m/s) and carried along
## at `carry` (m/s: what it came off, not slowed as the drift is), its grey multiplied by
## `tint` (rust-brown dust, pale tile grit).
func puff(at: Vector3, drift: Vector3, tint := Color.WHITE, carry := Vector3.ZERO) -> void:
	var grey := randf_range(tint_min, tint_max)
	var warmth := randf_range(-0.04, 0.04)
	var wobble := Vector3(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15), randf_range(-0.15, 0.15))
	if _pos.size() >= MAX_PUFFS:
		if not recycle or _age[_ring] < puff_life:
			return
		var i := _ring
		_ring = (_ring + 1) % MAX_PUFFS
		_pos[i] = at
		_drift[i] = drift + wobble
		_carry[i] = carry
		_age[i] = 0.0
		_spin[i] = randf() * TAU
		_aspect[i] = 1.0 + randf() * stretch
		_seed[i] = Vector2(randf(), randf())
		_tints[i] = Color(grey + warmth, grey, grey - warmth) * tint
		return
	_pos.append(at)
	_drift.append(drift + wobble)
	_carry.append(carry)
	_age.append(0.0)
	_spin.append(randf() * TAU)
	_aspect.append(1.0 + randf() * stretch)
	_seed.append(Vector2(randf(), randf()))
	_tints.append(Color(grey + warmth, grey, grey - warmth) * tint)


## Puffs still showing.
func live_puffs() -> int:
	var n := 0
	for a: float in _age:
		if a < puff_life:
			n += 1
	return n


## True once it has taken all the puffs it can (a long-lived emitter starts another trail).
func is_full() -> bool:
	return _pos.size() >= MAX_PUFFS


## No more puffs coming: free the trail once the last has faded.
func close() -> void:
	_closed = true


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var mm := multimesh
	var shown := 0
	var alive := false
	for i in _pos.size():
		_age[i] += delta
		var t := _age[i] / puff_life
		if t >= 1.0:
			continue
		alive = true
		_drift[i] *= maxf(1.0 - 0.6 * delta, 0.0)
		_pos[i] += (_drift[i] + _carry[i]) * delta
		var size := lerpf(start_size, end_size, 1.0 - pow(1.0 - t, 2.5))
		# Face the camera (billboard), turned a little per puff so they don't look stamped.
		var basis := Basis()
		if cam:
			basis = cam.global_basis * Basis(Vector3.BACK, _spin[i] + t * 0.8)
		var a := sqrt(_aspect[i])
		mm.set_instance_transform(shown, Transform3D(basis.scaled_local(Vector3(size * a, size / a, size)), _pos[i]))
		mm.set_instance_custom_data(shown, Color(_seed[i].x, _seed[i].y, t, 0.0))
		# Denser at first, thinning out; darker puffs read as thicker smoke.
		var alpha := opacity * pow(1.0 - t, 1.3) * minf(_age[i] * 12.0, 1.0)
		var tint := _tints[i]
		mm.set_instance_color(shown, Color(tint.r, tint.g, tint.b, alpha))
		shown += 1
	mm.visible_instance_count = shown
	if _closed and not alive:
		queue_free()
