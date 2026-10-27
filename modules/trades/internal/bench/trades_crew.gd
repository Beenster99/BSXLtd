class_name TradesCrew
extends Node
## The crew in the yard see and hear each other's work (beenster, 0.3.16 two-player playtest:
## "we cannot see each other's arms, tools or interactions, neither can we hear their tools";
## bolts and the stand's rings didn't match between players). Through Multiplayer's bus:
## your hands stream to the crew (set_local_hands) so your avatar reaches where they are;
## what you hold and do is shared (set_held), and each crewmate's avatar gets a copy of
## their tool in its hand, its sound while they use it and their shield when it's down;
## bolts and rivet heads that drop fall for everyone; the practice stand's joints match,
## late joiners included (a snapshot). Presentation only, behind trades.crew_tools.

## Event names (Multiplayer's "<module>.<thing>").
const POP_EVENT := "trades.pop"
const PRACTICE_EVENT := "trades.practice"
## The snapshot section for late joiners.
const SECTION := "trades"
## How loud a crewmate's tool is (dB) and how far it carries (m).
const SOUND_DB := -4.0
const SOUND_RANGE_M := 30.0

var bay: TradesBay
var _net: Node
## What we last shared with set_held().
var _sent := {}
## Crewmates by peer: {tool: StringName, node: TradesTool, sound: AudioStreamPlayer3D,
## playing: StringName, helmet: bool}.
var _crew := {}


static func enabled() -> bool:
	return Flags.is_on("trades.crew_tools")


## Joins the crew: hands, events, the snapshot and crewmates' changes.
func start(net: Node) -> void:
	_net = net
	if _net == null:
		return
	if _net.has_method("set_local_hands"):
		_net.call("set_local_hands", bay.worker.right_hand, bay.worker.left_hand)
	_net.call("register_event", POP_EVENT, _apply_pop, _validate_pop)
	_net.call("register_event", PRACTICE_EVENT, _apply_practice, _validate_practice)
	if _net.has_method("register_snapshot_provider"):
		_net.call("register_snapshot_provider", SECTION, self)
	if _net.has_signal("held_changed"):
		_net.connect("held_changed", _on_held)
	if _net.has_signal("avatar_added"):
		_net.connect("avatar_added", _on_avatar)


func stop() -> void:
	if _net == null:
		return
	if _net.has_method("set_local_hands"):
		_net.call("set_local_hands", null, null)
	_net.call("unregister_event", POP_EVENT)
	_net.call("unregister_event", PRACTICE_EVENT)
	if _net.has_method("unregister_snapshot_provider"):
		_net.call("unregister_snapshot_provider", SECTION)
	if _net.has_signal("held_changed") and _net.is_connected("held_changed", _on_held):
		_net.disconnect("held_changed", _on_held)
	if _net.has_signal("avatar_added") and _net.is_connected("avatar_added", _on_avatar):
		_net.disconnect("avatar_added", _on_avatar)
	for peer: int in _crew.keys():
		_drop(peer)
	_net = null


func _online() -> bool:
	return _net != null and bool(_net.call("is_online"))


# --- What you hold and do -----------------------------------------------------------------

## What this player holds and does now, as the crew sees it.
func held_state() -> Dictionary:
	return {"tool": String(bay.tool), "sound": String(bay.looping()),
			"helmet": bay.helmet_down() > 0.5, "crouch": bay.worker.crouched, "board": bay.worker.riding(),
			"spray": bay.extinguishers != null and bool(bay.extinguishers.held_state().get("spray", false))}


func _process(_delta: float) -> void:
	if not _online() or not _net.has_method("set_held"):
		return
	var now := held_state()
	if now != _sent:
		_sent = now
		_net.call("set_held", now)


## A crewmate's tool, sound or shield changed: show it on their avatar.
func _on_held(peer: int, held: Dictionary) -> void:
	if _net == null or peer == int(_net.call("local_peer_id")):
		return
	var c: Dictionary = _crew.get(peer, {})
	var tool := StringName(str(held.get("tool", "")))
	var hand := _net.call("avatar_hand", peer, true) as Node3D if _net.has_method("avatar_hand") else null
	if tool != c.get("tool", &"") or not is_instance_valid(c.get("node")):
		if is_instance_valid(c.get("node")):
			(c.node as Node).queue_free()
		c.tool = tool
		c.node = _copy_tool(tool, hand)
	if not is_instance_valid(c.get("sound")) and hand:
		var p := AudioStreamPlayer3D.new()
		p.name = "CrewToolSound"
		p.volume_db = SOUND_DB
		p.max_distance = SOUND_RANGE_M
		hand.add_child(p)
		c.sound = p
	var sound := StringName(str(held.get("sound", "")))
	if sound != c.get("playing", &""):
		c.playing = sound
		var p := c.get("sound") as AudioStreamPlayer3D
		if is_instance_valid(p):
			p.stop()
			var stream := bay.loop_stream(sound)
			if stream and DisplayServer.get_name() != "headless":
				p.stream = stream
				p.play()
	c.helmet = bool(held.get("helmet", false))
	_show_board(peer, c, bool(held.get("board", false)))
	_crew[peer] = c
	var head := _net.call("avatar_head", peer) as Node3D if _net.has_method("avatar_head") else null
	bay.crew_helmet(peer, c.helmet, head)


## Their avatar was rebuilt (a join, a scene change): put their tool back in its hand.
func _on_avatar(peer: int, _avatar: Node3D) -> void:
	if _net == null:
		return
	_drop(peer)
	var held: Dictionary = _net.call("held", peer) if _net.has_method("held") else {}
	if not held.is_empty():
		_on_held(peer, held)


func _drop(peer: int) -> void:
	var c: Dictionary = _crew.get(peer, {})
	for key: String in ["node", "sound", "board"]:
		if is_instance_valid(c.get(key)):
			(c[key] as Node).queue_free()
	_crew.erase(peer)


## A crewmate riding their hover board: the board under their avatar's feet, or gone.
func _show_board(peer: int, c: Dictionary, on: bool) -> void:
	var have := is_instance_valid(c.get("board"))
	if on == have:
		return
	if not on:
		(c.board as Node).queue_free()
		c.erase("board")
		return
	var avatar := _net.call("avatar", peer) as Node3D if _net.has_method("avatar") else null
	if avatar == null:
		return
	var look := TradesHoverBoard.build_look()
	look.name = "CrewBoard"
	avatar.add_child(look)
	c.board = look


## A look-alike of one of our tools in a crewmate's avatar hand, held the way we hold it.
## Its screen stays off: it would turn to face this player's eye.
func _copy_tool(tool: StringName, hand: Node3D) -> TradesTool:
	var mine := bay.tool_node(tool)
	if mine == null or hand == null:
		return null
	var copy := (mine.get_script() as Script).new() as TradesTool
	copy.name = "CrewTool"
	hand.add_child(copy)
	copy.transform = copy.hold * Transform3D(Basis(), -copy.grip)
	copy.set_process(false)
	if copy._swivel:
		copy._swivel.visible = false
	return copy


## The tool a crewmate holds on their avatar now (tests).
func crew_tool(peer: int) -> TradesTool:
	var c: Dictionary = _crew.get(peer, {})
	return c.get("node") as TradesTool if is_instance_valid(c.get("node")) else null


## The loop a crewmate's tool is playing ("" for none; tests).
func crew_sound(peer: int) -> StringName:
	return (_crew.get(peer, {}) as Dictionary).get("playing", &"")


# --- Bolts and rivet heads ----------------------------------------------------------------

## Something dropped here falls for the crew too: "bolt", "rivet" or "rivet_hot".
func share_pop(kind: String, at: Vector3, vel: Vector3) -> void:
	if enabled() and _online():
		_net.call("request", POP_EVENT, {"kind": kind, "at": at, "vel": vel})


func _validate_pop(sender: int, p: Dictionary) -> Variant:
	if not (p.get("at") is Vector3 and p.get("vel") is Vector3):
		return "no position"
	return {"peer": sender, "kind": str(p.get("kind", "bolt")), "at": p.at, "vel": p.vel}


func _apply_pop(p: Dictionary) -> void:
	if _net == null or int(p.get("peer", 0)) == int(_net.call("local_peer_id")):
		return
	var station := bay.ship_station()
	if station:
		station.pop_part(str(p.kind), p.at as Vector3, p.vel as Vector3)


# --- The practice stand -------------------------------------------------------------------

## A joint on the stand made or undone here: the same for the crew.
func share_practice(joint_id: String, made: bool) -> void:
	if enabled() and _online():
		_net.call("request", PRACTICE_EVENT, {"id": joint_id, "made": made})


func _validate_practice(sender: int, p: Dictionary) -> Variant:
	if str(p.get("id", "")) == "":
		return "no joint"
	return {"peer": sender, "id": str(p.id), "made": bool(p.get("made"))}


func _apply_practice(p: Dictionary) -> void:
	if _net == null or int(p.get("peer", 0)) == int(_net.call("local_peer_id")):
		return
	var station := bay.ship_station()
	if station:
		station.set_practice(str(p.id), bool(p.made))


## Multiplayer's snapshot for late joiners: the stand's joints as they are.
func get_net_snapshot() -> Dictionary:
	var station := bay.ship_station()
	return {"practice": station.practice.duplicate()} if station else {}


func apply_net_snapshot(data: Dictionary) -> void:
	var station := bay.ship_station()
	var practice: Dictionary = data.get("practice", {})
	if station == null:
		return
	for id: String in practice:
		station.set_practice(id, bool(practice[id]))
