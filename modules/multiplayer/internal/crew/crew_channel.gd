extends Node
## The crew: text chat, what each player is doing, and the presence that makes everyone
## visible to everyone (an avatar for each other player, and this player's head streamed
## as the mover "player:<peer id>" for avatars and helmet cams, their hands as
## "player:<peer id>:hand_r" and ":hand_l" once Tools shares them). What each player holds
## and does with their hands ("held": {"tool": "welder", "using": true, ...}) is shared too,
## so Tools can draw it on their avatar and play its sounds there. Owned by MultiplayerBus.

signal chat_received(line: Dictionary)
signal activity_changed(peer_id: int, text: String)
signal ping_received(ping: Dictionary)
signal ping_removed(ping_id: int)
signal held_changed(peer_id: int, held: Dictionary)
signal avatar_added(peer_id: int, avatar: Node3D)

const SAY := "crew.say"
const ACTIVITY := "crew.activity"
const PING := "crew.ping"
const HELD := "crew.held"
const HELD_KEYS := 8
const HELD_TEXT := 48
const PING_LIFE := 10.0
const PINGS_EACH := 5  # live pings per player; a sixth replaces their oldest
const MAX_LABEL := 48
const PING_GAP := 0.25  # seconds between one player's pings, enforced on the host
const MAX_ID := 96
## Crew colours by place on the crew list: host first, then in joining order.
const COLOURS: Array[Color] = [Color("e8792b"), Color("6fc8e8"), Color("7fd47a"), Color("e8c25a")]
const LOG_SIZE := 100
const MAX_CHARS := 200
const AVATAR := preload("res://modules/multiplayer/internal/crew/crew_avatar.gd")

var net: MultiplayerBus
var _log: Array[Dictionary] = []  # {"time", "peer", "name", "text"}
var _activity: Dictionary = {}  # peer id -> text
var _head := Node3D.new()  # this player's head, copied from the active camera
var _head_id := ""
var _hands: Array[Node3D] = [Node3D.new(), Node3D.new()]  # this player's hands, right then left
var _hand_sources: Array = [null, null]  # what Tools gave set_local_hands(), weakrefs
var _hand_ids: Array[String] = []
var _held: Dictionary = {}  # peer id -> held state
var _avatars: Dictionary = {}  # peer id -> avatar node
var _check := 0.0
var _pings: Array[Dictionary] = []
var _last_ping: Dictionary = {}  # peer id -> host clock time of their last ping
var _ping_seq := 0  # host side: ping ids


func _ready() -> void:
	_head.name = "LocalHead"
	add_child(_head)
	for i in 2:
		_hands[i].name = "LocalHandR" if i == 0 else "LocalHandL"
		add_child(_hands[i])
	net.register_event(SAY, _apply_say, _validate_say)
	net.register_event(ACTIVITY, _apply_activity, _validate_activity)
	net.register_event(PING, _apply_ping, _validate_ping)
	net.register_event(HELD, _apply_held, _validate_held)
	net.register_snapshot_provider("crew", self)
	for s: Signal in [net.session_started, net.session_ended, net.peer_joined, net.peer_left]:
		s.connect(func(_a = null, _b = null) -> void: _sync_presence())
	_sync_presence()


func _exit_tree() -> void:
	for id in _avatars:
		if is_instance_valid(_avatars[id]):
			_avatars[id].queue_free()
	_avatars.clear()


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam and not cam.get_viewport() is SubViewport:
		_head.global_transform = cam.global_transform
	for i in 2:
		var src: Node3D = _hand_sources[i].get_ref() if _hand_sources[i] else null
		if is_instance_valid(src) and src.is_inside_tree():
			_hands[i].global_transform = src.global_transform
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_place_avatars()


# --- Chat ------------------------------------------------------------------------------

func say(text: String) -> void:
	net.request(SAY, {"text": text})


func chat_log() -> Array[Dictionary]:
	return _log.duplicate()


func _validate_say(sender: int, p: Dictionary) -> Variant:
	var text := str(p.get("text", "")).strip_edges().left(MAX_CHARS)
	if text == "":
		return "nothing to say"
	var t := Time.get_time_dict_from_system()
	return {"time": "%02d:%02d" % [t.hour, t.minute], "peer": sender, "name": player_name(sender), "text": text}


func _apply_say(p: Dictionary) -> void:
	_log.append(p)
	if _log.size() > LOG_SIZE:
		_log.pop_front()
	chat_received.emit(p)


# --- Pings: "look here" ---------------------------------------------------------------

func ping(at: Vector3, object_id: String, normal: Vector3, label: String) -> void:
	net.request(PING, {"at": at, "object_id": object_id, "normal": normal, "label": label})


## Pings still showing (younger than PING_LIFE), oldest first.
func pings() -> Array[Dictionary]:
	var now := net.server_time()
	var live: Array[Dictionary] = []
	live.assign(_pings.filter(func(p: Dictionary) -> bool: return now - float(p.time) < PING_LIFE))
	return live


func player_colour(peer_id: int) -> Color:
	var ids := net.peers().keys()
	ids.sort()
	var i := ids.find(peer_id)
	return COLOURS[i % COLOURS.size()] if i >= 0 else COLOURS[0]


func _validate_ping(sender: int, p: Dictionary) -> Variant:
	var at: Variant = p.get("at")
	var normal: Variant = p.get("normal", Vector3.UP)
	if not at is Vector3 or not (at as Vector3).is_finite():
		return "no place to ping"
	if not normal is Vector3 or not (normal as Vector3).is_finite() or (normal as Vector3).is_zero_approx():
		normal = Vector3.UP
	var now := net.server_time()
	if now - float(_last_ping.get(sender, -INF)) < PING_GAP:
		return "pinging too fast"
	_last_ping[sender] = now
	_ping_seq += 1
	return {"id": _ping_seq, "label": str(p.get("label", "")).strip_edges().left(MAX_LABEL), "peer": sender, "name": player_name(sender), "colour": player_colour(sender), "at": at,
			"normal": (normal as Vector3).normalized(), "object_id": str(p.get("object_id", "")).left(MAX_ID),
			"time": now}


func _apply_ping(p: Dictionary) -> void:
	_pings = pings()
	var theirs := _pings.filter(func(q: Dictionary) -> bool: return q.peer == p.peer)
	while theirs.size() >= PINGS_EACH:
		var oldest: Dictionary = theirs.pop_front()
		_pings.erase(oldest)
		ping_removed.emit(int(oldest.id))
	_pings.append(p)
	ping_received.emit(p)


# --- Hands and what they hold --------------------------------------------------------

## Tools hands over this player's hand nodes (null for none): their transforms stream to the
## crew, whose avatars of this player then reach where these hands are.
func set_local_hands(right: Node3D, left: Node3D) -> void:
	_hand_sources = [weakref(right) if right else null, weakref(left) if left else null]
	var live := right != null or left != null
	_share_hands()
	if bool(held(net.local_peer_id()).get("hands", false)) != live:
		var state := held(net.local_peer_id())
		state["hands"] = live
		set_held(state)


## Streams the hands Tools gave us, and nothing while there are none.
func _share_hands() -> void:
	for i in mini(2, _hand_ids.size()):
		if _hand_sources[i]:
			net.register_mover(_hand_ids[i], _hands[i])
		else:
			net.unregister_mover(_hand_ids[i])


## Shares what this player holds and does: small values only (at most HELD_KEYS keys of
## bool, number or short text), e.g. {"tool": "welder", "using": true}. Replaces the last.
func set_held(state: Dictionary) -> void:
	var keep := held(net.local_peer_id())
	if keep.has("hands") and not state.has("hands"):
		state = state.duplicate()
		state["hands"] = keep.hands
	if state != keep:
		net.request(HELD, {"held": state})


## What a player holds ({} when nothing is known).
func held(peer_id: int) -> Dictionary:
	return (_held.get(peer_id, {}) as Dictionary).duplicate()


func _validate_held(sender: int, p: Dictionary) -> Variant:
	var given: Variant = p.get("held")
	if not given is Dictionary:
		return "nothing held"
	var clean := {}
	for key in given:
		if clean.size() >= HELD_KEYS:
			break
		var v: Variant = given[key]
		if v is String or v is StringName:
			v = str(v).left(HELD_TEXT)
		elif not (v is bool or v is int or v is float):
			continue
		clean[str(key).left(HELD_TEXT)] = v
	return {"peer": sender, "held": clean}


func _apply_held(p: Dictionary) -> void:
	var peer := int(p.peer)
	_held[peer] = p.held
	var a: Node = _avatars.get(peer)
	if is_instance_valid(a):
		a.set("hands_live", bool((p.held as Dictionary).get("hands", false)))
		a.set("crouch", bool((p.held as Dictionary).get("crouch", false)))
	held_changed.emit(peer, (p.held as Dictionary).duplicate())


# --- Activity --------------------------------------------------------------------------

func set_activity(text: String) -> void:
	if text != activity(net.local_peer_id()):
		net.request(ACTIVITY, {"text": text})


func activity(peer_id: int) -> String:
	return _activity.get(peer_id, "")


func _validate_activity(sender: int, p: Dictionary) -> Variant:
	return {"peer": sender, "text": str(p.get("text", "")).strip_edges().left(40)}


func _apply_activity(p: Dictionary) -> void:
	_activity[int(p.peer)] = str(p.text)
	activity_changed.emit(int(p.peer), str(p.text))


func player_name(peer_id: int) -> String:
	return str(net.peers().get(peer_id, {}).get("name", "Player %d" % peer_id))


# --- Snapshot --------------------------------------------------------------------------

func get_net_snapshot() -> Dictionary:
	return {"log": _log.duplicate(true), "activity": _activity.duplicate(), "held": _held.duplicate(true)}


func apply_net_snapshot(data: Dictionary) -> void:
	_log.clear()
	for line in data.get("log", []):
		_log.append(line)
	_activity.clear()
	var acts: Dictionary = data.get("activity", {})
	for id in acts:
		_activity[int(id)] = str(acts[id])
	_held.clear()
	var holds: Dictionary = data.get("held", {})
	for id in holds:
		if holds[id] is Dictionary:
			_held[int(id)] = holds[id]


# --- Presence --------------------------------------------------------------------------

## The node at another player's head (helmet cams follow it), or null.
func head_of(peer_id: int) -> Node3D:
	if peer_id == net.local_peer_id():
		return _head
	var a: Node = _avatars.get(peer_id)
	return a.get_node("Head") as Node3D if is_instance_valid(a) else null


## Another player's avatar, or null (none for this player).
func avatar_of(peer_id: int) -> Node3D:
	var a: Node = _avatars.get(peer_id)
	return a as Node3D if is_instance_valid(a) and not a.is_queued_for_deletion() else null


## Another player's hand on their avatar (right or left), or null.
func hand_of(peer_id: int, right := true) -> Node3D:
	var a := avatar_of(peer_id)
	return a.get_node("HandR" if right else "HandL") as Node3D if a else null


static func head_id(peer_id: int) -> String:
	return "player:%d" % peer_id


static func hand_id(peer_id: int, right: bool) -> String:
	return "player:%d:%s" % [peer_id, "hand_r" if right else "hand_l"]


func _sync_presence() -> void:
	if _head_id != "":
		net.unregister_mover(_head_id)
	for id in _hand_ids:
		net.unregister_mover(id)
	_head_id = head_id(net.local_peer_id())
	net.register_mover(_head_id, _head)
	_hand_ids = [hand_id(net.local_peer_id(), true), hand_id(net.local_peer_id(), false)]
	_share_hands()
	var peers := net.peers()
	for id in _held.keys():
		if not peers.has(id):
			_held.erase(id)
	for id in _avatars.keys():
		if not peers.has(id) or id == net.local_peer_id():
			net.unregister_mover(head_id(id))
			net.unregister_mover(hand_id(id, true))
			net.unregister_mover(hand_id(id, false))
			if is_instance_valid(_avatars[id]):
				_avatars[id].queue_free()
			_avatars.erase(id)
	for id: int in peers:
		if id != net.local_peer_id() and not _avatars.has(id):
			_avatars[id] = null
	_place_avatars()


## Puts an avatar for each other player in the current 3D scene, making new ones when a
## scene change took the old ones with it.
func _place_avatars() -> void:
	var scene := get_tree().current_scene if is_inside_tree() else null
	var world := scene if scene is Node3D else self
	for id: int in _avatars:
		var a: Node3D = _avatars[id]
		if is_instance_valid(a) and not a.is_queued_for_deletion() and a.get_parent() == world:
			continue
		if is_instance_valid(a):
			a.queue_free()
		a = AVATAR.new()
		a.name = "Crew_%d" % id
		a.set_meta("player_name", player_name(id))
		a.set_meta("peer_id", id)
		a.set("hands_live", bool(held(id).get("hands", false)))
		a.set("crouch", bool(held(id).get("crouch", false)))
		world.add_child(a)
		_avatars[id] = a
		net.register_mover(head_id(id), a.get_node("Head"))
		net.register_mover(hand_id(id, true), a.get_node("HandR"))
		net.register_mover(hand_id(id, false), a.get_node("HandL"))
		avatar_added.emit(id, a)
