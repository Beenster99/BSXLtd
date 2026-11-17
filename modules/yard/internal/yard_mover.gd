extends CharacterBody3D
## You in the orbital yard, for now: walk where the station has gravity, fly where the dock
## is weightless, and the switch happens as you pass through the airlock's outer door.
## A stand-in until stage 1.3 brings the Void Salvage suit, avatar and zero-g movement;
## keep it plain so it is easy to replace. The origin is at the feet.
##
## Walking: WASD, Shift run, Space jump. Flying: WASD along the view, Space up, Ctrl down,
## X stops the drift, and the suit damps a little on its own.

const EYE := 1.62

## Walking and running speeds, m/s.
@export var walk_speed := 3.0
@export var run_speed := 6.5
## Take-off speed of a jump, m/s.
@export var jump_speed := 3.8
## The station's gravity, m/s².
@export var gravity := 9.0
## Suit thrust in zero g, m/s², and with Shift held.
@export var thrust := 3.0
@export var boost_thrust := 8.0
## Top speed in zero g, m/s.
@export var max_fly_speed := 14.0
## How fast the drift dies away on its own (1/s), and with X held.
@export var drift_damping := 0.25
@export var brake_damping := 3.0
## Radians of turn per pixel of mouse movement.
@export var mouse_sensitivity := 0.0025
## How far you can reach to use something (m).
@export var reach := 3.0

## True while the station's gravity holds you.
var in_gravity := true
var head: Node3D
var camera: Camera3D
## Whatever usable thing the view is on (a node with meta "yard_use"), or null.
var looking_at: Node
var _pitch := 0.0
## A function that says if a point (station space) has gravity; set by the station.
var gravity_at: Callable


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.05
	camera.far = 60000.0
	camera.fov = 75.0
	head.add_child(camera)
	floor_snap_length = 0.3


func look(relative: Vector2) -> void:
	rotation.y -= relative.x * mouse_sensitivity
	_pitch = clampf(_pitch - relative.y * mouse_sensitivity, -1.5, 1.5)
	head.rotation.x = _pitch


## Stands (or floats) at `at` looking towards `target`.
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
	in_gravity = _gravity_here()


func _physics_process(delta: float) -> void:
	in_gravity = _gravity_here()
	var input := Vector2(_held(Keys.RIGHT) - _held(Keys.LEFT), _held(Keys.BACK) - _held(Keys.FORWARD))
	# A screen that has the mouse (a console, the wrist) keeps your hands off the controls.
	if HudSlots.pointer_claimed():
		input = Vector2.ZERO
	if in_gravity:
		_walk(input, delta)
	else:
		_fly(input, delta)
	_update_look_target()


func _walk(input: Vector2, delta: float) -> void:
	var speed := run_speed if _held(Keys.RUN) > 0.0 else walk_speed
	var move := (global_basis * Vector3(input.x, 0.0, input.y)).normalized() * speed
	velocity.x = move.x
	velocity.z = move.z
	if is_on_floor():
		if not HudSlots.pointer_claimed() and Input.is_action_just_pressed(Keys.JUMP):
			velocity.y = jump_speed
	else:
		velocity.y -= gravity * delta
	move_and_slide()


func _fly(input: Vector2, delta: float) -> void:
	var view := camera.global_basis
	var up_down := 0.0 if HudSlots.pointer_claimed() else _held("yard.up") - _held("yard.down")
	var push := view * Vector3(input.x, 0.0, input.y) + Vector3.UP * up_down
	if push.length() > 1.0:
		push = push.normalized()
	var accel := boost_thrust if _held(Keys.RUN) > 0.0 else thrust
	velocity += push * accel * delta
	var damping := brake_damping if _held("yard.brake") > 0.0 and not HudSlots.pointer_claimed() else drift_damping
	velocity *= maxf(0.0, 1.0 - damping * delta)
	velocity = velocity.limit_length(max_fly_speed)
	move_and_slide()


func _gravity_here() -> bool:
	return gravity_at.call(global_position + Vector3(0, 0.9, 0)) if gravity_at.is_valid() else true


## Uses whatever the view is on (F).
func use() -> void:
	if looking_at and looking_at.has_meta("yard_use"):
		(looking_at.get_meta("yard_use") as Callable).call()


## The hint for what the view is on ("" for nothing).
func hint() -> String:
	if looking_at == null or not looking_at.has_meta("yard_hint"):
		return ""
	var h: Variant = looking_at.get_meta("yard_hint")
	return str((h as Callable).call()) if h is Callable else str(h)


func _update_look_target() -> void:
	looking_at = null
	if camera == null or not is_inside_tree():
		return
	var from := camera.global_position
	var to := from - camera.global_basis.z * reach
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var n := hit.collider as Node
	while n and not n.has_meta("yard_use"):
		n = n.get_parent()
		if n is Node3D and n.name == "Station":
			n = null
	looking_at = n


func _held(action: String) -> float:
	return 1.0 if InputMap.has_action(action) and Input.is_action_pressed(action) else 0.0
