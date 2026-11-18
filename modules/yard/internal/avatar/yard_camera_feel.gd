class_name YardCameraFeel
extends Node
## The helmet camera (EV2, docs/review/08_MOVEMENT.md 2.2): how your own view moves. A child
## "YardCameraFeel" of every rig, stepped only on your own (`JetRig._process`); presentation only,
## nothing sent or saved. Every shake in the game goes through it, on one comfort slider
## (`camera_motion`):
## - trauma (`add_trauma`): a bang, a blast, a section freed. The shake is trauma squared of smooth
##   noise, a turn of the head (pitch, yaw, roll) and a little offset, the same at any frame rate;
## - rumble (`set_rumble(source, level)`): what lasts (your jets, the socket hammering, the ship's
##   engines aboard, the jump's run-up); the largest source is the floor;
## - kicks (`kick(direction, degrees)`): a spring that throws the view away from a source and
##   settles; dips (`dip(metres)`): a vertical spring (EV3's landings);
## - the field of view: wider boosting, a touch narrower braking hard (`fov_extra`, degrees);
## - the bob: a little up and down on the stride while walking.
## `offset` is what the rig puts under the eye (the camera's local transform, the held tool with
## it); the aim never shakes (`JetRig.aim_transform`).

@export_group("Trauma")
## How fast trauma falls away (per second): trauma 1 is gone in 1 / this.
@export var trauma_decay: float = 1.2
## How quickly the shake's noise moves (Hz).
@export var shake_hz: float = 14.0
## The most a full shake turns the view in pitch and yaw (degrees).
@export var shake_angle_deg: float = 2.0
## ... and in roll (degrees).
@export var shake_roll_deg: float = 1.2
## ... and moves the eye (m).
@export var shake_offset: float = 0.02

@export_group("Rumble")
## The turn at a rumble of 1 (degrees).
@export var rumble_angle_deg: float = 0.4
## How quickly a rumble moves (Hz).
@export var rumble_hz: float = 7.0
## Your jets at full throttle (rumble level, 0..1).
@export var jet_rumble: float = 0.25
## The socket hammering a seized bolt (0..1).
@export var hammer_rumble: float = 0.3
## The ship's engines while you are aboard, at engine level 2 (boost) (0..1; level 1 is half).
@export var engine_rumble: float = 0.5
## The jump's run-up at its end (0..1; it builds with the run-up).
@export var runup_rumble: float = 1.0

@export_group("Kicks")
## The kick spring's frequency (Hz) and damping ratio (0..1): it settles in about 0.3 s.
@export var kick_hz: float = 4.0
@export var kick_damping: float = 0.55
## The dip spring's frequency (Hz) and damping ratio.
@export var dip_hz: float = 3.5
@export var dip_damping: float = 0.6
## A fuel tank going up next to you kicks the view this far away from it (degrees).
@export var blast_kick_deg: float = 6.0

@export_group("Field of view")
## Wider while boosting and speeding up (degrees).
@export var boost_fov_deg: float = 5.0
## Narrower while braking hard (degrees), over `brake_fov_speed` m/s.
@export var brake_fov_deg: float = 2.0
@export var brake_fov_speed: float = 1.0
## How fast the field of view eases to where it is going (per second).
@export var fov_ease: float = 6.0

@export_group("Bob")
## The eye's rise and fall on each stride while walking (m).
@export var bob_height: float = 0.012
## One stride (m): the bob's clock.
@export var stride_length: float = 0.55

## Tests set it (0..1) to stand in for the setting; below 0 the setting rules.
static var force_motion: float = -1.0
## The comfort slider (0..1): how much the view may move (Void Salvage's GameSettings.camera_motion).
static var camera_motion: float = 1.0

## 0..1: how hard the shake is now (falls at `trauma_decay`).
var trauma: float = 0.0
## The field of view's change now (degrees, after the slider): the rig adds it.
var fov_extra: float = 0.0
## What goes under the eye this frame (rig's head space): the camera's transform on foot, on
## top of the seat camera's seated.
var offset := Transform3D.IDENTITY
## Each lasting source's level (0..1).
var _rumble: Dictionary = {}
var _time: float = 0.0
var _kick := Vector2.ZERO      # yaw, pitch (rad)
var _kick_v := Vector2.ZERO
var _dip: float = 0.0          # m, down
var _dip_v: float = 0.0
var _spring_left: float = 0.0
var _bob_phase: float = 0.0
var _bob: float = 0.0
var _view := Basis.IDENTITY
var _noise: Array[FastNoiseLite] = []

## The springs are stepped at this rate, whatever the frame rate (s).
const SPRING_STEP := 1.0 / 240.0


func _init() -> void:
	for i in 6:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.seed = 7919 * (i + 1)
		n.frequency = 1.0
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
		_noise.append(n)


## The comfort slider's share now (0..1): 0 headless, in script runs (tests, captures) and with
## `--capture` runs, unless a test set `force_motion`.
static func motion() -> float:
	if force_motion >= 0.0:
		return clampf(force_motion, 0.0, 1.0)
	if quiet_run():
		return 0.0
	return clampf(camera_motion, 0.0, 1.0)


## Headless, a script run or a capture: the camera keeps still.
static func quiet_run() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	var args := OS.get_cmdline_args()
	if args.has("-s") or args.has("--script"):
		return true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture"):
			return true
	return false


## A bang, a blast, a section coming free: `amount` (0..1) more shake, falling away.
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + maxf(amount, 0.0), 0.0, 1.0)


## A lasting shake from `source` at `level` (0..1); 0 ends it.
func set_rumble(source: String, level: float) -> void:
	if level <= 0.001:
		_rumble.erase(source)
	else:
		_rumble[source] = clampf(level, 0.0, 1.0)


## The rumble now: the largest source's level.
func rumble() -> float:
	var top := 0.0
	for v: float in _rumble.values():
		top = maxf(top, v)
	return top


func rumble_of(source: String) -> float:
	return float(_rumble.get(source, 0.0))


## Throws the view `degrees` toward `direction` (world: from the source to you), settling back.
func kick(direction: Vector3, degrees: float) -> void:
	var d := _view.inverse() * direction
	# Shoved sideways the face turns away; shoved up or back the head goes back.
	var push := Vector2(-d.x, d.y + d.z * 0.5)
	if push.length() < 0.05:
		push = Vector2(0.0, 1.0)
	_kick_v += push.normalized() * deg_to_rad(degrees) * _peak_to_speed(kick_hz, kick_damping)


## Drops the eye `metres` and springs it back (a landing).
func dip(metres: float) -> void:
	_dip_v += metres * _peak_to_speed(dip_hz, dip_damping)


## The speed a damped spring needs to peak at 1 (its peak for a starting speed of 1 is
## e^(-z/sqrt(1-z^2) * atan(sqrt(1-z^2)/z)) / w).
static func _peak_to_speed(hz: float, z: float) -> float:
	var w := TAU * hz
	z = clampf(z, 0.05, 0.95)
	var s := sqrt(1.0 - z * z)
	return w / exp(-z / s * atan(s / z))


## The kick's turn now (rad: yaw, pitch) and the dip (m).
func kick_now() -> Vector2:
	return _kick


func dip_now() -> float:
	return _dip


## One frame: `view` the aim's basis (world, for kicks), `walking` the speed over the deck you
## walk (m/s, 0 not walking), `fov_goal` the field of view's change asked (degrees, before the
## slider). Works out `offset` and `fov_extra`.
func step(delta: float, view: Basis, walking: float = 0.0, fov_goal: float = 0.0) -> void:
	_view = view.orthonormalized()
	_time += delta
	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	_spring_left += delta
	while _spring_left >= SPRING_STEP:
		_spring_left -= SPRING_STEP
		_kick_v += (-_kick * pow(TAU * kick_hz, 2.0) - _kick_v * 2.0 * kick_damping * TAU * kick_hz) * SPRING_STEP
		_kick += _kick_v * SPRING_STEP
		_dip_v += (-_dip * pow(TAU * dip_hz, 2.0) - _dip_v * 2.0 * dip_damping * TAU * dip_hz) * SPRING_STEP
		_dip += _dip_v * SPRING_STEP
	if walking > 0.05:
		_bob_phase = fmod(_bob_phase + walking / maxf(stride_length, 0.05) * PI * delta, TAU)
		_bob = sin(_bob_phase * 2.0) * bob_height
	else:
		_bob = move_toward(_bob, 0.0, delta * 0.1)
	var m := motion()
	var k := 1.0 - exp(-fov_ease * delta)
	fov_extra = lerpf(fov_extra, fov_goal * m, k)
	if m <= 0.0:
		offset = Transform3D.IDENTITY
		return
	var s := trauma * trauma
	var r := rumble()
	var a := deg_to_rad(shake_angle_deg) * s
	var ra := deg_to_rad(rumble_angle_deg) * r
	var ts := _time * shake_hz
	var tr := _time * rumble_hz
	var yaw := a * _n(0, ts) + ra * _n(3, tr) + _kick.x
	var pitch := a * _n(1, ts) + ra * _n(4, tr) + _kick.y
	var roll := deg_to_rad(shake_roll_deg) * s * _n(2, ts)
	var pos := Vector3(_n(5, ts), _n(3, ts + 50.0), 0.0) * shake_offset * s
	pos.y += _bob - _dip
	offset = Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll) * m), pos * m)


## The view's turn from straight ahead now (degrees).
func angle_deg() -> float:
	return rad_to_deg(offset.basis.get_rotation_quaternion().get_angle())


func _n(i: int, t: float) -> float:
	return clampf(_noise[i].get_noise_1d(t) * 1.4, -1.0, 1.0)
