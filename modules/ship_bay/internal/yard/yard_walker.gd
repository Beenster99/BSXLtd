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
## Radians of turn per pixel of mouse movement.
@export var mouse_sensitivity := 0.0025

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
	input.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	input.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	var speed := run_speed if Input.is_physical_key_pressed(KEY_SHIFT) else walk_speed
	var move := (global_basis * Vector3(input.x, 0.0, input.y)).normalized() * speed
	velocity.x = move.x
	velocity.z = move.z
	if is_on_floor():
		if Input.is_physical_key_pressed(KEY_SPACE):
			velocity.y = jump_speed
	else:
		velocity.y -= gravity * delta
	move_and_slide()
