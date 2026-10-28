extends Node3D
## Another player in the world: a suit, a helmet, a name tag and two arms. The Head child is
## the mover the player's own camera drives (looking down -Z, like a camera); the body stands
## under it and turns with it. HandR and HandL are movers too, driven by the player's real
## hands when their tools share them (hands_live), else held at a rest pose in front of the
## suit. Other modules find heads by the group HEAD_GROUP and hands by HAND_GROUP, each with
## the meta "peer_id" (hands also "side": "right"/"left"): Graphics hangs crewmates' helmet
## torches on heads, Tools puts the tool they hold in their hand and plays its sounds there.
## play_emote() acts out a signal (wave, thumbs up, point...) for EMOTE_TIME with a bubble
## over the helmet saying what it means.

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
const EMOTE_TIME := 3.0
## Right hand (and left, for two-handed signals) from the head, in the suit's facing, for
## each emote. "wave" also swings side to side.
const EMOTE_POSE := {
	"wave": [Vector3(0.38, 0.18, -0.1), null],
	"thumbs_up": [Vector3(0.22, -0.2, -0.45), null],
	"thumbs_down": [Vector3(0.22, -0.45, -0.45), null],
	"point": [Vector3(0.15, -0.1, -0.7), null],
	"come_here": [Vector3(0.2, -0.3, -0.5), null],
	"stop": [Vector3(0.1, -0.05, -0.6), null],
	"help": [Vector3(0.4, 0.25, -0.05), Vector3(-0.4, 0.25, -0.05)],
	"cheer": [Vector3(0.3, 0.35, -0.05), Vector3(-0.3, 0.35, -0.05)],
}

var head := Node3D.new()
var hand_r := Node3D.new()
var hand_l := Node3D.new()
## True while the player's real hand positions stream in; false keeps the hands at rest.
var hands_live := false
## True while the player crouches: the suit squats so its feet stay on the floor.
var crouch := false
var _body: MeshInstance3D
var _arms: Array[MeshInstance3D] = []
var _emote := ""
var _emote_left := 0.0
var _bubble: Label3D


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
	_bubble = Label3D.new()
	_bubble.name = "Bubble"
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 56
	_bubble.pixel_size = 0.004
	_bubble.outline_size = 12
	_bubble.modulate = Color("ffd166")
	_bubble.position = Vector3(0, 0.55, 0)
	_bubble.no_depth_test = true
	_bubble.visible = false
	head.add_child(_bubble)
	_rest_hands()


## Acts out an emote for EMOTE_TIME; `text` is what the bubble says ("Wave").
func play_emote(emote: String, text: String) -> void:
	_emote = emote
	_emote_left = EMOTE_TIME
	_bubble.text = text.to_upper()
	_bubble.visible = true


func emote() -> String:
	return _emote


func _process(delta: float) -> void:
	var at := head.global_transform
	var yaw := at.basis.get_euler().y
	var eye := CROUCH_EYE if crouch else EYE_HEIGHT
	global_transform = Transform3D(Basis(Vector3.UP, yaw), at.origin - Vector3(0, eye, 0))
	var squat := eye / EYE_HEIGHT
	_body.scale = Vector3(1, squat, 1)
	_body.position = Vector3(0, 0.75 * squat, 0)
	if not hands_live:
		_rest_hands()
	if _emote != "":
		_emote_left -= delta
		_pose(delta)
		_bubble.modulate.a = clampf(_emote_left / 0.5, 0.0, 1.0)
		if _emote_left <= 0.0:
			_emote = ""
			_bubble.visible = false
	_reach(_arms[0], _shoulder(1.0), hand_r.global_position)
	_reach(_arms[1], _shoulder(-1.0), hand_l.global_position)


## Hands hanging at the suit's sides, turned with it.
func _rest_hands() -> void:
	var turn := Basis(Vector3.UP, head.global_basis.get_euler().y)
	for side in [1.0, -1.0]:
		var hand := hand_r if side > 0.0 else hand_l
		hand.global_transform = Transform3D(turn, head.global_position + turn * (HAND_REST * Vector3(side, 1, 1)))


## Puts the hands where the emote wants them (over whatever they were doing).
func _pose(_delta: float) -> void:
	var pose: Array = EMOTE_POSE.get(_emote, [null, null])
	var turn := Basis(Vector3.UP, head.global_basis.get_euler().y)
	for i in 2:
		if pose[i] == null:
			continue
		var at: Vector3 = pose[i]
		if _emote == "wave" and i == 0:
			at.x += sin((EMOTE_TIME - _emote_left) * 9.0) * 0.12
		elif _emote == "come_here" and i == 0:
			at.z += sin((EMOTE_TIME - _emote_left) * 7.0) * 0.15
		var hand := hand_r if i == 0 else hand_l
		hand.global_transform = Transform3D(turn, head.global_position + turn * at)


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
