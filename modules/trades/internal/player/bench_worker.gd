class_name BenchWorker
extends CharacterBody3D
## The BSX worker on foot: walk with WASD, Space jumps, look with the mouse, V swaps first and
## third person. On a ladder (a scaffold's climbing space calls set_ladder) forward or Space
## climbs and back climbs down.
## Two symbolic stretchy hands hang in front of the camera (StretchHand), so you see your own
## hands doing the work in either view. The origin is at the feet.
##
## In the yard this is the player (TradesBay stands Ship and Bay's walker down).

const EYE := 1.62
## The body's chest, where Void Salvage's PlayerModel measures from (its eyes are 0.3 up).
const CHEST := Vector3(0, EYE - 0.3, 0)
## The upper arm, shoulder to elbow (metres); the stretchy forearm goes on from the elbow.
const UPPER_ARM_M := 0.3
## Footsteps kept soft (beenster, 0.3.6: "walking sound needs to be more subtle"), dB.
const STEP_DB := -18.0

@export var walk_speed := 2.4
## Holding Shift (m/s): across the yard.
@export var run_speed := 5.5
@export var mouse_sensitivity := 0.0025
## Take-off speed of a jump (m/s): about 1.25 m up, enough to jump onto any of the yard's
## hover trolleys (beenster, 22 Oct), whose chassis stands 1.12 m tall, and ride its deck up
## to work at height.
@export var jump_speed := 4.75
## The planet's gravity (m/s²), as the yard has it.
@export var gravity := 9.0
## Climbing speed on a ladder (m/s).
@export var climb_speed := 1.6
## Third-person camera: over the right shoulder, in the body's space (metres), looking at
## the point the head is aimed at, so the crosshair still points where you work.
@export var boom := Vector3(1.3, 2.0, 0.55)
@export var boom_look_m := 1.0
## Looking down at the bench you lean over it: the head goes this far forward and down
## (metres) by the time you look `lean_full_deg` below level, starting at `lean_from_deg`.
@export var lean_forward_m := 0.26
@export var lean_down_m := 0.12
@export var lean_from_deg := 25.0
@export var lean_full_deg := 60.0

var third_person := false
## Jumping and climbing ladders (the bay turns them on with trades.jump).
var agile := true
## True while a hand is working something: the mouse drives the work, not the view.
var look_locked := false
## True while the keys drive something else (a trolley on remote): stand still.
var held_still := false

var head: Node3D
var camera: Camera3D
var left_hand: StretchHand
var right_hand: StretchHand
var _body_model: Node3D
## The welder's shield on your head (TradesBay flicks it down while the arc is lit).
var welding_helmet: TradesWeldingHelmet
## Each upper arm, swung to point at its hand (beenster, 2026-10-22): {shoulder (body
## space), upper, strut, joint (meshes), hand}.
var _arms: Array[Dictionary] = []
var _pitch := 0.0
var _kick := 0.0
## How many ladders' climbing spaces the worker is in.
var _ladders := 0
## Footsteps underfoot (UI's Footsteps: steps by the surface, a thud on landing).
var footsteps: Footsteps


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	footsteps = Footsteps.new()
	footsteps.volume_db = STEP_DB
	add_child(footsteps)

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
	var cast := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if third \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for n in _body_model.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = cast
	_place_camera()


## A small jolt of the view (the wrench's click), metres.
func kick(amount: float) -> void:
	_kick += amount


func _process(delta: float) -> void:
	_kick = move_toward(_kick, 0.0, delta * 0.15)
	_lean()
	_place_camera()
	_pose_arms()


func _lean() -> void:
	var down := rad_to_deg(-_pitch)
	var l := smoothstep(lean_from_deg, lean_full_deg, down)
	head.position = Vector3(0.0, EYE - lean_down_m * l, -lean_forward_m * l)


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
	# Twice: leaning in moves the eye, which changes the angle down a little.
	for i in 2:
		var eye := global_transform * head.position
		var across := Vector2(point.x - eye.x, point.z - eye.z).length()
		_pitch = atan2(point.y - eye.y, across)
		head.rotation.x = _pitch
		_lean()


## The aim ray: from the camera, through the middle of the screen.
func aim_origin() -> Vector3:
	return camera.global_position


func aim_dir() -> Vector3:
	return -camera.global_basis.z


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not look_locked and not held_still:
		input.x = Input.get_action_strength(Keys.RIGHT) - Input.get_action_strength(Keys.LEFT)
		input.y = Input.get_action_strength(Keys.BACK) - Input.get_action_strength(Keys.FORWARD)
	var speed := run_speed if Input.is_action_pressed(Keys.RUN) else walk_speed
	var move := (global_basis * Vector3(input.x, 0.0, input.y)).normalized() * speed
	velocity.x = move.x
	velocity.z = move.z
	var jump := agile and not look_locked and not held_still and Input.is_action_pressed(Keys.JUMP)
	if _ladders > 0:
		# On a ladder: forward or jump climbs, back climbs down; you stay on it unless you're
		# standing at its foot.
		var climb := clampf(-input.y + (1.0 if jump else 0.0), -1.0, 1.0)
		velocity.y = climb * climb_speed
		if not (is_on_floor() and climb <= 0.0):
			velocity.x = 0.0
			velocity.z = 0.0
	elif is_on_floor():
		velocity.y = jump_speed if jump else 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()


## A ladder's climbing space counts the worker in (+1) and out (-1). Leaving one out of its
## top, it hands over where to step off (`step_to`, else INF). Ship and Bay's scaffold rigs
## call this on whoever climbs.
func set_ladder(way: int, step_to: Vector3 = Vector3.INF) -> void:
	if not agile:
		return
	_ladders = maxi(_ladders + way, 0)
	if way < 0 and step_to.is_finite():
		global_position = step_to
		velocity = Vector3.ZERO


func on_ladder() -> bool:
	return _ladders > 0


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


## The salvager (PlayerModel, standing, with the exoskeleton): helmet with an amber visor,
## suit, life support pack, the frame's struts and jets, colour flashes in BSX orange. The
## arms stop at the elbows: the hands are the stretchy ones.
func _build_body() -> Node3D:
	var root := Node3D.new()
	root.name = "Body"
	root.position = CHEST
	add_child(root)
	var suit := TradesLook.metal(TradesLook.SUIT, 0.0, 0.75)
	var frame := TradesLook.metal(TradesLook.FRAME, 0.8, 0.4)
	var visor := TradesLook.metal(TradesLook.VISOR, 1.0, 0.08)
	var accent := TradesLook.metal(TradesLook.TRIM, 0.4, 0.5)
	accent.emission_enabled = true
	accent.emission = TradesLook.TRIM
	accent.emission_energy_multiplier = 0.5
	var up := PI * 0.5
	_part(_sphere(0.17), Vector3(0, 0.32, 0), suit, root)
	_part(_sphere(0.14), Vector3(0, 0.33, -0.07), visor, root).scale = Vector3(0.95, 0.72, 0.6)
	welding_helmet = TradesWeldingHelmet.new()
	welding_helmet.position = Vector3(0, 0.32, 0)
	root.add_child(welding_helmet)
	_part(_cylinder(0.11, 0.06), Vector3(0, 0.15, 0), frame, root)                    # neck ring
	_part(_capsule(0.19, 0.62), Vector3(0, -0.04, 0), suit, root)
	_part(_box(Vector3(0.34, 0.16, 0.22)), Vector3(0, -0.4, 0), suit, root)
	_part(_box(Vector3(0.24, 0.3, 0.12)), Vector3(0, -0.02, 0.2), suit, root)          # life support
	_part(_box(Vector3(0.1, 0.18, 0.02)), Vector3(0, 0.0, 0.265), accent, root)
	for side: float in [-1.0, 1.0]:
		var shoulder := Vector3(side * 0.24, 0.12, 0.0)
		var elbow := Vector3(side * 0.3, -0.1, -0.22)
		var upper := _limb(shoulder, elbow, 0.065, suit, root)
		_part(_box(Vector3(0.07, 0.03, 0.14)), Vector3(side * 0.24, 0.2, 0), accent, root)   # shoulder flash
		var hip := Vector3(side * 0.11, -0.45, 0.0)
		var knee := Vector3(side * 0.12, -0.84, -0.06)
		var ankle := Vector3(side * 0.12, -1.16, 0.02)
		_limb(hip, knee, 0.08, suit, root)
		_limb(knee, ankle, 0.07, suit, root)
		_part(_box(Vector3(0.11, 0.07, 0.24)), ankle + Vector3(0, -0.05, -0.05), frame, root)  # boot
		# Exoskeleton: leg struts with powered knees, an arm strut, jets on the pack and calves.
		var strut_x := side * 0.21
		_limb(Vector3(strut_x, -0.42, 0.04), Vector3(strut_x, -0.84, -0.02), 0.022, frame, root)
		_limb(Vector3(strut_x, -0.84, -0.02), Vector3(strut_x, -1.14, 0.05), 0.022, frame, root)
		_part(_cylinder(0.05, 0.05), Vector3(strut_x, -0.84, -0.02), accent, root).rotation.z = up
		var strut := _limb(shoulder + Vector3(side * 0.06, 0.04, 0.05), elbow + Vector3(side * 0.06, 0.0, 0.03), 0.018, frame, root)
		var joint := _part(_cylinder(0.04, 0.05), elbow + Vector3(side * 0.06, 0.0, 0.03), accent, root)
		joint.rotation.z = up
		_arms.append({"shoulder": shoulder, "upper": upper, "strut": strut, "joint": joint,
				"hand": left_hand if side < 0.0 else right_hand, "side": side})
		for y: float in [0.12, -0.24]:
			var jet := Vector3(side * 0.2, y, 0.3)
			_part(_cylinder(0.045, 0.1), jet, frame, root).rotation.x = up
			_part(_cylinder(0.05, 0.02), jet + Vector3(0, 0, 0.055), accent, root).rotation.x = up
		_part(_cylinder(0.035, 0.08), Vector3(side * 0.12, -1.0, 0.12), frame, root).rotation.x = up
	# Spine: backpack frame, shoulder yoke, hip belt.
	_part(_box(Vector3(0.3, 0.46, 0.14)), Vector3(0, -0.02, 0.27), frame, root)
	_part(_box(Vector3(0.12, 0.3, 0.02)), Vector3(0, 0.0, 0.345), accent, root)
	_part(_box(Vector3(0.06, 0.62, 0.06)), Vector3(0, -0.2, 0.23), frame, root)
	_part(_box(Vector3(0.56, 0.05, 0.08)), Vector3(0, 0.16, 0.14), frame, root)
	_part(_box(Vector3(0.46, 0.06, 0.3)), Vector3(0, -0.36, 0.03), frame, root)
	return root


## A capsule from a to b (a limb or strut).
func _limb(a: Vector3, b: Vector3, radius: float, mat: Material, parent: Node3D) -> MeshInstance3D:
	var m := _part(_capsule(radius, maxf(a.distance_to(b) + radius * 2.0, radius * 2.0)), (a + b) * 0.5, mat, parent)
	_pose_limb(m, a, b)
	return m


## Lays a limb's capsule from a to b (its parent's space), keeping its length.
static func _pose_limb(m: Node3D, a: Vector3, b: Vector3) -> void:
	var along := (b - a).normalized()
	var side := along.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = along.cross(Vector3.RIGHT)
	side = side.normalized()
	m.basis = Basis(side, along, side.cross(along))
	m.position = (a + b) * 0.5


## Swings each upper arm from its shoulder toward its hand, so the arm points at the work
## (beenster, 2026-10-22: "an arm by the waist with the elastic hands going over the head is
## wrong"), and in third person starts the hand's stretchy forearm at that elbow.
func _pose_arms() -> void:
	if _body_model == null:
		return
	var to_body := _body_model.global_transform.affine_inverse()
	for arm in _arms:
		var hand := arm.hand as StretchHand
		if hand == null or not hand.is_inside_tree():
			continue
		var shoulder: Vector3 = arm.shoulder
		var side := float(arm.side)
		var wrist := to_body * hand.palm().origin
		var dir := wrist - shoulder
		if dir.length() < 0.05:
			continue
		dir = dir.normalized()
		var elbow := shoulder + dir * UPPER_ARM_M
		_pose_limb(arm.upper, shoulder, elbow)
		var off := Vector3(side * 0.06, 0.0, 0.03)
		_pose_limb(arm.strut, shoulder + off + Vector3(0, 0.04, 0.02), elbow + off)
		(arm.joint as Node3D).position = elbow + off
		hand.arm_root = _body_model.global_transform * elbow if third_person else Vector3.INF


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
