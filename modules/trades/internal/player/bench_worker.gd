class_name BenchWorker
extends CharacterBody3D
## The BSX worker on foot: walk with WASD, look with the mouse, V swaps first and third person.
## Two symbolic stretchy hands hang in front of the camera (StretchHand), so you see your own
## hands doing the work in either view. The origin is at the feet.
##
## Only the bench uses this for now. A shared player for every scene belongs with Core and
## Multiplayer once one is needed.

const EYE := 1.62
const HI_VIS := Color("f2a33a")
const OVERALLS := Color("31465c")
const HARD_HAT := Color("f2d23a")

@export var walk_speed := 2.4
@export var mouse_sensitivity := 0.0025
## Third-person camera: over the right shoulder, in the body's space (metres), looking at
## the point the head is aimed at, so the crosshair still points where you work.
@export var boom := Vector3(1.3, 2.0, 0.55)
@export var boom_look_m := 1.0

var third_person := false
## True while a hand is working something: the mouse drives the work, not the view.
var look_locked := false

var head: Node3D
var camera: Camera3D
var left_hand: StretchHand
var right_hand: StretchHand
var _body_model: Node3D
var _pitch := 0.0
var _kick := 0.0


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 65.0
	camera.near = 0.02
	camera.current = true
	head.add_child(camera)

	left_hand = _hand("Left", Vector3(-0.24, -0.3, -0.42), true)
	right_hand = _hand("Right", Vector3(0.24, -0.3, -0.42), false)
	_body_model = _build_body()
	set_view(false)


func set_view(third: bool) -> void:
	third_person = third
	_body_model.visible = third
	_place_camera()


## A small jolt of the view (the wrench's click), metres.
func kick(amount: float) -> void:
	_kick += amount


func _process(delta: float) -> void:
	_kick = move_toward(_kick, 0.0, delta * 0.15)
	_place_camera()


func _place_camera() -> void:
	if not third_person:
		camera.transform = Transform3D(Basis(), Vector3(0, -_kick, 0))
		return
	var look_at_point := head.global_transform * Vector3(0, 0, -boom_look_m)
	var from := global_transform * boom + Vector3(0, -_kick, 0)
	camera.global_transform = Transform3D(Basis.looking_at(look_at_point - from, Vector3.UP), from)


## Turn the view by a mouse movement, in pixels.
func look(relative: Vector2) -> void:
	if look_locked:
		return
	rotation.y -= relative.x * mouse_sensitivity
	_pitch = clampf(_pitch - relative.y * mouse_sensitivity, deg_to_rad(-85.0), deg_to_rad(80.0))
	head.rotation.x = _pitch


## Face a point (used to set up the bench and screenshots).
func face(point: Vector3) -> void:
	var flat := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	if flat.length() > 0.01:
		rotation.y = atan2(-flat.x, -flat.z)
	var eye := global_position + Vector3(0, EYE, 0)
	_pitch = atan2(point.y - eye.y, flat.length())
	head.rotation.x = _pitch


## The aim ray: from the camera, through the middle of the screen.
func aim_origin() -> Vector3:
	return camera.global_position


func aim_dir() -> Vector3:
	return -camera.global_basis.z


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not look_locked:
		input.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		input.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	var move := (global_basis * Vector3(input.x, 0.0, input.y)).normalized() * walk_speed
	velocity.x = move.x
	velocity.z = move.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()


func _hand(side: String, at: Vector3, is_left: bool) -> StretchHand:
	var mount := Node3D.new()
	mount.name = "HandMount" + side
	mount.position = at
	head.add_child(mount)
	var hand := StretchHand.new()
	hand.name = side + "Hand"
	hand.left = is_left
	mount.add_child(hand)
	return hand


## Grey-box worker for third person: hard hat, hi-vis vest over overalls. The hands are the
## stretchy ones, so the arms stop at the elbows.
func _build_body() -> Node3D:
	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	var vest := StretchHand._mat(HI_VIS, 0.0, 0.6)
	var overalls := StretchHand._mat(OVERALLS, 0.0, 0.8)
	var skin := StretchHand._mat(Color("d9a37e"), 0.0, 0.8)
	var hat := StretchHand._mat(HARD_HAT, 0.1, 0.4)
	_part(_capsule(0.19, 0.62), Vector3(0, 1.22, 0), overalls, root)
	_part(_box(Vector3(0.42, 0.42, 0.26)), Vector3(0, 1.3, 0), vest, root)
	_part(_sphere(0.12), Vector3(0, 1.62, 0), skin, root)
	_part(_cylinder(0.15, 0.06), Vector3(0, 1.72, 0), hat, root)
	_part(_cylinder(0.19, 0.015), Vector3(0, 1.69, -0.03), hat, root)
	for x in [-0.1, 0.1]:
		_part(_capsule(0.08, 0.86), Vector3(x, 0.45, 0), overalls, root)
	for x in [-0.27, 0.27]:
		var arm := _part(_capsule(0.06, 0.34), Vector3(x, 1.32, -0.08), overalls, root)
		arm.rotation.x = deg_to_rad(-55.0)
	return root


func _part(mesh: Mesh, at: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m


static func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return m


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	return m
