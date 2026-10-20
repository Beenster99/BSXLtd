extends Node
## The crew: text chat, what each player is doing, and the presence that makes everyone
## visible to everyone (an avatar for each other player, and this player's head streamed
## as the mover "player:<peer id>" for avatars and helmet cams). Owned by MultiplayerBus.

signal chat_received(line: Dictionary)
signal activity_changed(peer_id: int, text: String)

const SAY := "crew.say"
const ACTIVITY := "crew.activity"
const LOG_SIZE := 100
const MAX_CHARS := 200
const AVATAR := preload("res://modules/multiplayer/internal/crew/crew_avatar.gd")

var net: MultiplayerBus
var _log: Array[Dictionary] = []  # {"time", "peer", "name", "text"}
var _activity: Dictionary = {}  # peer id -> text
var _head := Node3D.new()  # this player's head, copied from the active camera
var _head_id := ""
var _avatars: Dictionary = {}  # peer id -> avatar node
var _check := 0.0


func _ready() -> void:
	_head.name = "LocalHead"
	add_child(_head)
	net.register_event(SAY, _apply_say, _validate_say)
	net.register_event(ACTIVITY, _apply_activity, _validate_activity)
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
	return {"log": _log.duplicate(true), "activity": _activity.duplicate()}


func apply_net_snapshot(data: Dictionary) -> void:
	_log.clear()
	for line in data.get("log", []):
		_log.append(line)
	_activity.clear()
	var acts: Dictionary = data.get("activity", {})
	for id in acts:
		_activity[int(id)] = str(acts[id])


# --- Presence --------------------------------------------------------------------------

## The node at another player's head (helmet cams follow it), or null.
func head_of(peer_id: int) -> Node3D:
	if peer_id == net.local_peer_id():
		return _head
	var a: Node = _avatars.get(peer_id)
	return a.get_node("Head") as Node3D if is_instance_valid(a) else null


static func head_id(peer_id: int) -> String:
	return "player:%d" % peer_id


func _sync_presence() -> void:
	if _head_id != "":
		net.unregister_mover(_head_id)
	_head_id = head_id(net.local_peer_id())
	net.register_mover(_head_id, _head)
	var peers := net.peers()
	for id in _avatars.keys():
		if not peers.has(id) or id == net.local_peer_id():
			net.unregister_mover(head_id(id))
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
		world.add_child(a)
		_avatars[id] = a
		net.register_mover(head_id(id), a.get_node("Head"))
