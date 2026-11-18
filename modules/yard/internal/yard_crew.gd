class_name YardCrew
extends Node3D
## Stage 1.6: the crew in the yard. Friends are drawn in the Void Salvage suit (YardAvatar),
## walking on the station's decks and flying in the dock, with their helmet lamp and the tool
## in their hand. Online play is the Multiplayer module's; it is optional, so it is reached by
## name only (Modules.bus("multiplayer")) and the yard plays alone without it.
##
## Each player streams their own suit as two movers the Multiplayer module carries for them
## (any id under "player:<peer id>:" is that player's to drive): BODY_ID, the rig's centre and
## turn, and HEAD_ID, the eye with its look. What changes now and then goes in their "held"
## state: "yard" (in the yard), "deck" (on a deck or floating), "tool" (in hand, "" for none),
## "using" (the trigger) and "lamp". The module's own stand-in for each friend (a plain suit
## and arms) stays for other modules to hang things on, with its shapes hidden while the
## friend is drawn here.

const BODY_ID := "yard_body"
const HEAD_ID := "yard_head"
## How often this player's held state is checked for a change (s).
const HELD_EVERY := 0.2
## A friend's lamp: as the rig's, without shadows (four of them would cost too much).
const LAMP_AT := Vector3(0.12, 0.08, -0.25)
## The stand-in's own render layers, kept on each of its shapes while it is out of sight.
const STAND_IN_LAYERS := &"yard_stand_in_layers"

## The station's own rig: what this player streams.
var rig: YardRig
## Other players drawn here: peer id -> Crewmate.
var crewmates: Dictionary = {}

var _net: Object
var _body := Node3D.new()
var _head := Node3D.new()
var _my_ids: Array[String] = []
var _held_left := 0.0


## A friend: the body mover with the head mover over it, the suit, its lamp and a hand's worth
## of tools (only the one they hold is shown).
class Crewmate:
	extends Node3D
	var peer := 0
	var head := Node3D.new()
	var lamp := SpotLight3D.new()
	var avatar: YardAvatar
	var tools: Dictionary = {}  # tool id -> YardTool
	var shown_tool := ""
	var _last := Vector3.ZERO
	var _seen := false

	func build(display_name: String, colour: Color) -> void:
		head.name = "Head"
		head.top_level = true
		add_child(head)
		lamp.name = "HelmetLamp"
		lamp.position = LAMP_AT
		lamp.light_color = Color(1, 0.94, 0.84)
		lamp.light_energy = 7.0
		lamp.spot_range = 40.0
		lamp.spot_angle = 34.0
		lamp.spot_angle_attenuation = 0.8
		lamp.visible = false
		head.add_child(lamp)
		avatar = YardAvatar.new()
		avatar.name = "Avatar"
		add_child(avatar)
		avatar.setup(display_name, colour, lamp, false, YardSuitLook.default_look())
		var hold := Node3D.new()
		hold.name = "ToolHold"
		hold.transform = str_to_var(YardToolController.HOLD)
		head.add_child(hold)
		for tool: YardTool in [YardGrinder.new(), YardCutter.new(), YardSocket.new(), YardGrabber.new(), YardTractor.new(), YardTablet.new()]:
			tool.position = -tool.grip
			tool.visible = false
			hold.add_child(tool)
			tool.set_mark(1)
			tools[tool.tool_id] = tool

	## What they hold and do, from their held state.
	func wear(held: Dictionary) -> void:
		avatar.set_on_deck(bool(held.get("deck", true)))
		lamp.visible = bool(held.get("lamp", false))
		var id := str(held.get("tool", ""))
		if id != shown_tool:
			if tools.has(shown_tool):
				(tools[shown_tool] as YardTool).set_working(false, false)
				(tools[shown_tool] as YardTool).visible = false
			shown_tool = id if tools.has(id) else ""
			avatar.tool_override = tools.get(shown_tool)
			if shown_tool != "":
				(tools[shown_tool] as YardTool).visible = true
		if shown_tool != "":
			(tools[shown_tool] as YardTool).set_working(bool(held.get("using", false)), false)

	## The pose from where the movers put the body and the head this frame.
	func follow(delta: float) -> void:
		var at := global_position
		var speed := (at - _last) / maxf(delta, 0.001) if _seen else Vector3.ZERO
		_last = at
		_seen = true
		avatar.ground_speed = global_basis.inverse() * speed if avatar.on_deck else Vector3.ZERO
		avatar.motion = Vector3.ZERO
		avatar.glide = 0.0
		var look := global_basis.inverse() * head.global_basis
		avatar.set("_look_pitch", look.get_euler().x)


func _ready() -> void:
	name = "Crew"
	for n: Node3D in [_body, _head]:
		n.top_level = true
		add_child(n)
	_body.name = "MyBody"
	_head.name = "MyHead"
	if _net == null:
		_net = Modules.bus("multiplayer")
	if _net == null:
		return
	for s: String in ["session_started", "session_ended", "peer_joined", "peer_left"]:
		if _net.has_signal(s):
			_net.connect(s, func(_a: Variant = null, _b: Variant = null) -> void: _sync())
	if _net.has_signal("avatar_added"):
		_net.connect("avatar_added", _on_stand_in)
	if _net.has_signal("held_changed"):
		_net.connect("held_changed", _on_held)
	_sync()


## Plays through this Multiplayer bus rather than the module's own (tests run two players in
## one process); before the node enters the tree.
func use_net(net: Object) -> void:
	_net = net


func _exit_tree() -> void:
	_unregister_mine()
	for peer: int in crewmates.keys():
		_drop(peer)
	if _net and is_instance_valid(_net) and _net.has_method("set_held"):
		var held: Dictionary = _net.call("held", _local_peer())
		if held.has("yard"):
			for key in ["yard", "deck", "tool", "using", "lamp"]:
				held.erase(key)
			_net.call("set_held", held)


func _process(delta: float) -> void:
	if rig and is_instance_valid(rig):
		_body.global_transform = rig.global_transform
		_head.global_transform = rig.head.global_transform
	for peer: int in crewmates:
		(crewmates[peer] as Crewmate).follow(delta)
	_held_left -= delta
	if _held_left <= 0.0:
		_held_left = HELD_EVERY
		_share_held()


## A friend stood in for captures and tests, with no one behind it: `feet` where they stand
## (or the soles would be, floating), facing `face`, wearing `held` (as the held state).
func show_stand_in(display_name: String, colour: Color, feet: Vector3, face: Vector3, held: Dictionary) -> Crewmate:
	var c := Crewmate.new()
	c.name = "StandIn_%s" % display_name
	c.top_level = true
	add_child(c)
	c.build(display_name, colour)
	var centre := feet + Vector3(0, YardRig.FEET, 0)
	var flat := Vector3(face.x - centre.x, 0.0, face.z - centre.z)
	var deck := bool(held.get("deck", true))
	c.global_transform = Transform3D(Basis.looking_at(flat if deck else face - centre, Vector3.UP), centre)
	c.head.global_transform = Transform3D(Basis.looking_at(face - (centre + c.global_basis.y * YardRig.EYE), Vector3.UP),
			centre + c.global_basis.y * YardRig.EYE)
	c.wear(held)
	c.follow(0.016)
	c.avatar.snap()
	return c


## The movers ids for a player's suit.
static func body_id(peer: int) -> String:
	return "player:%d:%s" % [peer, BODY_ID]


static func head_id(peer: int) -> String:
	return "player:%d:%s" % [peer, HEAD_ID]


func _local_peer() -> int:
	return int(_net.call("local_peer_id")) if _net else 1


func _online() -> bool:
	return _net != null and bool(_net.call("is_online"))


## Brings the movers and the friends in line with the session: this player's suit under its
## own peer id (it changes on joining), a crewmate for each other player and none for those gone.
func _sync() -> void:
	if _net == null:
		return
	_unregister_mine()
	var me := _local_peer()
	_my_ids = [body_id(me), head_id(me)]
	_net.call("register_mover", _my_ids[0], _body)
	_net.call("register_mover", _my_ids[1], _head)
	var peers: Dictionary = _net.call("peers") if _online() else {}
	for peer: int in crewmates.keys():
		if not peers.has(peer) or peer == me:
			_drop(peer)
	for peer: int in peers:
		if peer != me and not crewmates.has(peer):
			_add(peer)
	_held_left = 0.0


func _unregister_mine() -> void:
	if _net and is_instance_valid(_net):
		for id in _my_ids:
			_net.call("unregister_mover", id)
	_my_ids.clear()


func _add(peer: int) -> void:
	var c := Crewmate.new()
	c.name = "Crewmate_%d" % peer
	c.peer = peer
	c.top_level = true
	c.visible = false   # until they say they are in the yard
	add_child(c)
	c.build(str(_net.call("player_name", peer)), _net.call("player_colour", peer) as Color)
	crewmates[peer] = c
	_net.call("register_mover", body_id(peer), c)
	_net.call("register_mover", head_id(peer), c.head)
	_on_held(peer, _net.call("held", peer))
	_hide_stand_in(peer)


func _drop(peer: int) -> void:
	var c: Crewmate = crewmates.get(peer)
	crewmates.erase(peer)
	if _net and is_instance_valid(_net):
		_net.call("unregister_mover", body_id(peer))
		_net.call("unregister_mover", head_id(peer))
	if is_instance_valid(c):
		c.queue_free()


func _on_held(peer: int, held: Dictionary) -> void:
	var c: Crewmate = crewmates.get(peer)
	if c == null:
		return
	c.visible = bool(held.get("yard", false))
	c.wear(held)
	_hide_stand_in(peer)


## The Multiplayer module's plain stand-in for a friend drawn here: its shapes out of sight, its
## head and hands kept (other modules hang things on them).
func _on_stand_in(peer: int, _avatar: Node3D) -> void:
	_hide_stand_in(peer)


func _hide_stand_in(peer: int) -> void:
	var c: Crewmate = crewmates.get(peer)
	var stand_in: Node3D = _net.call("avatar", peer) if _net else null
	if c == null or stand_in == null:
		return
	# Out of every camera's layers rather than hidden: the stand-in shows and hides its own
	# arms and bubble every frame.
	for g in stand_in.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if not gi.has_meta(STAND_IN_LAYERS):
			gi.set_meta(STAND_IN_LAYERS, gi.layers)
		gi.layers = 0 if c.visible else int(gi.get_meta(STAND_IN_LAYERS))
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if c.visible else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## This player's suit state, sent when it changes (the module sends nothing for no change).
func _share_held() -> void:
	if not _online() or rig == null or not is_instance_valid(rig):
		return
	var held: Dictionary = _net.call("held", _local_peer())
	held["yard"] = true
	held["deck"] = rig.on_deck()
	held["lamp"] = rig.lamp.visible if rig.lamp else false
	var t := rig.tools
	var holding := t != null and not t.holstered
	held["tool"] = t.active_tool().tool_id if holding else ""
	held["using"] = holding and t.trigger
	_net.call("set_held", held)
