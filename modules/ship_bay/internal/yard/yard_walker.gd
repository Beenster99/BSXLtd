extends CharacterBody3D
## You on foot in the shipyard: WASD walk, Shift run, Space jump, mouse look. A plain first
## person walker on the planet's gravity; the origin is at the feet.
##
## Trades' bench has its own worker with hands and tools. One shared player for every scene
## belongs with Core and Multiplayer once one is needed; until then this one only walks.

const EYE := 1.62

## Walking and running speeds, metres per second.
@export var walk_speed := 3.0
@export var run_speed := 7.0
## Take-off speed of a jump, metres per second.
@export var jump_speed := 4.2
## The planet's gravity, metres per second squared.
@export var gravity := 9.0
## Climbing speed on a ladder, metres per second.
@export var climb_speed := 1.6
## Radians of turn per pixel of mouse movement.
@export var mouse_sensitivity := 0.0025

## How many ladders' climbing spaces the walker is in (scaffold rigs count it).
var _ladders := 0
var head: Node3D
var camera: Camera3D
var _pitch := 0.0


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	# Steps and a landing thud (metal on decks and gratings that say so).
	add_child(Footsteps.new())
	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.05
	camera.far = 6000.0
	camera.fov = 75.0
	head.add_child(camera)


func look(relative: Vector2) -> void:
	rotation.y -= relative.x * mouse_sensitivity
	_pitch = clampf(_pitch - relative.y * mouse_sensitivity, -1.45, 1.45)
	head.rotation.x = _pitch


## Stands at `at` looking towards `target` (both in the yard's space).
func place(at: Vector3, target: Vector3) -> void:
	position = at
	velocity = Vector3.ZERO
	var flat := Vector3(target.x - at.x, 0.0, target.z - at.z)
	if flat.length() > 0.01:
		rotation.y = atan2(-flat.x, -flat.z)
	var eye := at + Vector3(0, EYE, 0)
	_pitch = atan2(target.y - eye.y, Vector2(target.x - eye.x, target.z - eye.z).length())
	if head:
		head.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	# While a trolley is on remote, W A S D drive it: you stand still.
	var bus := Modules.bus("ship_bay") as ShipBayBus
	var free := bus == null or not bus.remote_driving
	if free:
		input.x = _held(Keys.RIGHT, KEY_D) - _held(Keys.LEFT, KEY_A)
		input.y = _held(Keys.BACK, KEY_S) - _held(Keys.FORWARD, KEY_W)
	var speed := run_speed if _held(Keys.RUN, KEY_SHIFT) > 0.0 else walk_speed
	var move := (global_basis * Vector3(input.x, 0.0, input.y)).normalized() * speed
	velocity.x = move.x
	velocity.z = move.z
	if _ladders > 0:
		# On a ladder: forward or jump climbs, back climbs down; you stay on it unless you're
		# standing at its foot.
		var climb := clampf(_held(Keys.FORWARD, KEY_W) + _held(Keys.JUMP, KEY_SPACE) - _held(Keys.BACK, KEY_S), -1.0, 1.0)
		velocity.y = climb * climb_speed
		if not (is_on_floor() and climb <= 0.0):
			velocity.x = 0.0
			velocity.z = 0.0
	elif is_on_floor():
		if free and _held(Keys.JUMP, KEY_SPACE) > 0.0:
			velocity.y = jump_speed
	else:
		velocity.y -= gravity * delta
	move_and_slide()


## 1 while a Core movement action (as bound in Settings > Key binds) is held; `key` before
## the key map is in.
func _held(action: String, key: Key) -> float:
	if InputMap.has_action(action):
		return 1.0 if Input.is_action_pressed(action) else 0.0
	return 1.0 if Input.is_physical_key_pressed(key) else 0.0


## A ladder's climbing space counts the walker in (+1) and out (-1). Leaving one out of its
## top, it hands over where to step off (`step_to`, else INF).
func set_ladder(way: int, step_to: Vector3 = Vector3.INF) -> void:
	_ladders = maxi(_ladders + way, 0)
	if way < 0 and step_to.is_finite():
		global_position = step_to
		velocity = Vector3.ZERO
