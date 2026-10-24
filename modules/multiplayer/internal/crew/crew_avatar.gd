extends Node3D
## Another player in the world: a suit, a helmet, a name tag and two arms. The Head child is
## the mover the player's own camera drives (looking down -Z, like a camera); the body stands
## under it and turns with it. HandR and HandL are movers too, driven by the player's real
## hands when their tools share them (hands_live), else held at a rest pose in front of the
## suit. Other modules find heads by the group HEAD_GROUP and hands by HAND_GROUP, each with
## the meta "peer_id" (hands also "side": "right"/"left"): Graphics hangs crewmates' helmet
## torches on heads, Tools puts the tool they hold in their hand and plays its sounds there.

const HEAD_GROUP := "crew_head"
const HAND_GROUP := "crew_hand"
const EYE_HEIGHT := 1.65
## Eye height while crouched (Tools drops the eye 0.5 m and sends "crouch" in held).
const CROUCH_EYE := 1.15
const SUIT := Color("e8792b")
const VISOR := Color("16191c")
const GLOVE := Color("2b2f33")
## Shoulders, from the head: down and to each side (right is +X).
const SHOULDER := Vector3(0.21, -0.3, 0.02)
## Where an idle hand hangs, from the head.
const HAND_REST := Vector3(0.24, -0.85, -0.12)
const ARM_RADIUS := 0.05

var head := Node3D.new()
var hand_r := Node3D.new()
var hand_l := Node3D.new()
## True while the player's real hand positions stream in; false keeps the hands at rest.
var hands_live := false
## True while the player crouches: the suit squats so its feet stay on the floor.
var crouch := false
var _body: MeshInstance3D
var _arms: Array[MeshInstance3D] = []


func _ready() -> void:
	var peer := int(get_meta("peer_id", 0))
	head.name = "Head"
	head.top_level = true
	head.add_to_group(HEAD_GROUP)
	head.set_meta("peer_id", peer)
	add_child(head)
	var helmet := _mesh(SphereMesh.new(), SUIT.lightened(0.15))
	(helmet.mesh as SphereMesh).radius = 0.17
	(helmet.mesh as SphereMesh).height = 0.34
	head.add_child(helmet)
	var visor := _mesh(BoxMesh.new(), VISOR)
	(visor.mesh as BoxMesh).size = Vector3(0.26, 0.12, 0.08)
	visor.position = Vector3(0, 0.0, -0.14)
	head.add_child(visor)
	var body := _mesh(CapsuleMesh.new(), SUIT)
	(body.mesh as CapsuleMesh).radius = 0.25
	(body.mesh as CapsuleMesh).height = 1.4
	body.position = Vector3(0, 0.75, 0)
	add_child(body)
	_body = body
	var tag := Label3D.new()
	tag.text = str(get_meta("player_name", "")).to_upper()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 40
	tag.pixel_size = 0.004
	tag.position = Vector3(0, 0.32, 0)
	tag.no_depth_test = true
	head.add_child(tag)
	for hand: Node3D in [hand_r, hand_l]:
		var right := hand == hand_r
		hand.name = "HandR" if right else "HandL"
		hand.top_level = true
		hand.add_to_group(HAND_GROUP)
		hand.set_meta("peer_id", peer)
		hand.set_meta("side", "right" if right else "left")
		add_child(hand)
		var glove := _mesh(SphereMesh.new(), GLOVE)
		(glove.mesh as SphereMesh).radius = 0.055
		(glove.mesh as SphereMesh).height = 0.11
		hand.add_child(glove)
		var arm := _mesh(CylinderMesh.new(), SUIT)
		(arm.mesh as CylinderMesh).top_radius = ARM_RADIUS
		(arm.mesh as CylinderMesh).bottom_radius = ARM_RADIUS
		(arm.mesh as CylinderMesh).height = 1.0
		arm.name = "ArmR" if right else "ArmL"
		arm.top_level = true
		add_child(arm)
		_arms.append(arm)
	_rest_hands()


func _process(_delta: float) -> void:
	var at := head.global_transform
	var yaw := at.basis.get_euler().y
	var eye := CROUCH_EYE if crouch else EYE_HEIGHT
	global_transform = Transform3D(Basis(Vector3.UP, yaw), at.origin - Vector3(0, eye, 0))
	var squat := eye / EYE_HEIGHT
	_body.scale = Vector3(1, squat, 1)
	_body.position = Vector3(0, 0.75 * squat, 0)
	if not hands_live:
		_rest_hands()
	_reach(_arms[0], _shoulder(1.0), hand_r.global_position)
	_reach(_arms[1], _shoulder(-1.0), hand_l.global_position)


## Hands hanging at the suit's sides, turned with it.
func _rest_hands() -> void:
	var turn := Basis(Vector3.UP, head.global_basis.get_euler().y)
	for side in [1.0, -1.0]:
		var hand := hand_r if side > 0.0 else hand_l
		hand.global_transform = Transform3D(turn, head.global_position + turn * (HAND_REST * Vector3(side, 1, 1)))


func _shoulder(side: float) -> Vector3:
	var turn := Basis(Vector3.UP, head.global_basis.get_euler().y)
	return head.global_position + turn * (SHOULDER * Vector3(side, 1, 1))


## Stretches an arm (a unit cylinder along Y) from the shoulder to the hand.
static func _reach(arm: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var along := to - from
	var length := along.length()
	if length < 0.01:
		arm.visible = false
		return
	arm.visible = true
	var y := along / length
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	arm.global_transform = Transform3D(Basis(x, y * length, z), from + along * 0.5)


func _mesh(m: Mesh, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mi.material_override = mat
	return mi
