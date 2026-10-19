class_name NetSession
extends Node
## One multiplayer session: transport, join handshake, the event pipeline, join snapshots,
## object claims and the shared clock. MultiplayerBus owns one; the loopback test makes two
## in one process. Each session gets its own SceneMultiplayer rooted at itself, and every RPC
## lives on the Wire child, so RPC paths match on every peer wherever the session sits.
##
## Host-authoritative: a player's action is a request; the host validates it, gives it the
## next sequence number and broadcasts the resulting event; every peer (host included)
## applies events through the same handler. Offline the local player is the host, so the
## same code runs solo and online.

signal session_started(as_host: bool)
signal session_ended(reason: String)
signal peer_joined(peer_id: int, profile: Dictionary)
signal peer_left(peer_id: int, reason: String)
signal event_applied(event_name: String, payload: Dictionary)
signal request_rejected(event_name: String, reason: String)
signal claim_changed(object_id: String, peer_id: int)

enum State { OFFLINE, HOSTING, JOINING, JOINED }

const HOST_ID := 1
## Bump when the wire format changes; peers with different protocols refuse each other.
const PROTOCOL := 1
const CLAIM := "net.claim"
const RELEASE := "net.release"
const CLOCK_SAMPLES := 8
const PING_INTERVAL := 1.0
const REFUSE_GRACE := 0.5

## What a joining peer must match: {"game_version": ..., "modules": {id: version}, ...}.
## Set by the owner before hosting or joining; PROTOCOL is added automatically.
var compat: Dictionary = {}
## This player's name tag and anything else other peers should see.
var profile: Dictionary = {"name": "Fitter"}

var state := State.OFFLINE
var _mp := SceneMultiplayer.new()
var _wire: Node
var _peers: Dictionary = {}  # peer id -> profile, accepted peers only (host included)
var _events: Dictionary = {}  # event name -> {"apply": Callable, "validate": Callable}
var _snapshots: Dictionary = {}  # section id -> provider
var _claims: Dictionary = {}  # object id -> peer id
var _seq := 0
var _end_reason := ""
var _clock_offset := 0.0
var _clock_samples: Array[Vector2] = []  # (rtt, offset)
var _ping_timer := 0.0
var _max_clients := 0


func _init() -> void:
	_wire = preload("res://modules/multiplayer/internal/net_wire.gd").new()
	_wire.name = "Wire"
	_wire.session = self
	add_child(_wire)
	_mp.peer_connected.connect(_on_peer_connected)
	_mp.peer_disconnected.connect(_on_peer_disconnected)
	_mp.connected_to_server.connect(_on_connected_to_server)
	_mp.connection_failed.connect(_on_connection_failed)
	_mp.server_disconnected.connect(_on_server_disconnected)
	register_event(CLAIM, _apply_claim, _validate_claim)
	register_event(RELEASE, _apply_claim, _validate_release)
	register_snapshot_provider("net", self)


func _enter_tree() -> void:
	get_tree().set_multiplayer(_mp, get_path())
	if _mp.multiplayer_peer == null or _mp.multiplayer_peer is OfflineMultiplayerPeer:
		_go_offline()


func _exit_tree() -> void:
	if state != State.OFFLINE:
		_close("left")
	get_tree().set_multiplayer(null, get_path())


func _process(delta: float) -> void:
	if state != State.JOINED:
		return
	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = PING_INTERVAL
		_wire.ping.rpc_id(HOST_ID, _now())


# --- Session ---------------------------------------------------------------------------

func host(port: int, max_clients: int) -> Error:
	if state != State.OFFLINE:
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
	if err != OK:
		return err
	_mp.multiplayer_peer = peer
	_max_clients = max_clients
	state = State.HOSTING
	_end_reason = ""
	_peers = {HOST_ID: profile.duplicate()}
	session_started.emit(true)
	return OK


func join(address: String, port: int) -> Error:
	if state != State.OFFLINE:
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	_mp.multiplayer_peer = peer
	state = State.JOINING
	_end_reason = ""
	return OK


## Ends the session. A host leaving ends it for everyone (no host migration).
func leave() -> void:
	if state != State.OFFLINE:
		_close("left")


func is_online() -> bool:
	return state != State.OFFLINE


## True offline too: solo play is a session of one with the local player as host.
func is_host() -> bool:
	return state == State.OFFLINE or state == State.HOSTING


func local_peer_id() -> int:
	return _mp.get_unique_id()


## Accepted peers, host included: peer id -> profile.
func peers() -> Dictionary:
	return _peers.duplicate(true)


## Seconds on the host's clock, the same on every peer to within half a round trip. Use it
## to timestamp anything judged across players (two-player riveting).
func server_time() -> float:
	return _now() + _clock_offset


## Best recent round trip to the host in seconds (0 for the host).
func round_trip() -> float:
	if _clock_samples.is_empty():
		return 0.0
	return _best_sample().x


# --- Events ----------------------------------------------------------------------------

## Registers what an event does. `apply(payload)` runs on every peer, in host order.
## `validate(sender_id, payload)` runs on the host only and returns the payload to
## broadcast (it may add to it), or a String saying why the request is refused. Without a
## validator the payload is broadcast unchanged.
func register_event(event_name: String, apply: Callable, validate := Callable()) -> void:
	_events[event_name] = {"apply": apply, "validate": validate}


func unregister_event(event_name: String) -> void:
	_events.erase(event_name)


## Asks the host to perform an action. Offline and on the host it runs straight away.
func request(event_name: String, payload: Dictionary = {}) -> void:
	if is_host():
		_host_handle(local_peer_id(), event_name, payload)
	elif state == State.JOINED:
		_wire.request.rpc_id(HOST_ID, event_name, payload)
	else:
		request_rejected.emit(event_name, "not connected")


## Host only: broadcasts an event without a request (timers, deliveries, the host's systems).
func host_emit(event_name: String, payload: Dictionary = {}) -> void:
	if not is_host():
		push_error("NetSession: only the host emits events (%s)" % event_name)
		return
	if not _events.has(event_name):
		push_error("NetSession: no event registered as '%s'" % event_name)
		return
	_broadcast(event_name, payload)


# --- Snapshots -------------------------------------------------------------------------

## A provider has get_net_snapshot() -> Dictionary and apply_net_snapshot(data). The host
## sends every section to a peer when it joins, so players can drop in mid-job.
func register_snapshot_provider(section: String, provider: Object) -> void:
	assert(provider.has_method("get_net_snapshot") and provider.has_method("apply_net_snapshot"),
			"NetSession: %s snapshot provider lacks get/apply_net_snapshot()" % section)
	_snapshots[section] = provider


func unregister_snapshot_provider(section: String) -> void:
	_snapshots.erase(section)


func get_net_snapshot() -> Dictionary:
	return {"claims": _claims.duplicate()}


func apply_net_snapshot(data: Dictionary) -> void:
	_claims = {}
	var claims: Dictionary = data.get("claims", {})
	for id in claims:
		_claims[str(id)] = int(claims[id])


# --- Claims ----------------------------------------------------------------------------

## Asks to hold an object (a part, a tool, a circuit lock) so nobody else grabs it.
## claim_changed fires when the host grants it; request_rejected when someone has it.
func claim(object_id: String) -> void:
	request(CLAIM, {"object_id": object_id})


func release(object_id: String) -> void:
	request(RELEASE, {"object_id": object_id})


## Peer holding the object, or 0.
func claim_owner(object_id: String) -> int:
	return _claims.get(object_id, 0)


func _validate_claim(sender: int, payload: Dictionary) -> Variant:
	var id := str(payload.get("object_id", ""))
	var owner: int = _claims.get(id, 0)
	if id == "":
		return "no object_id"
	if owner != 0 and owner != sender:
		return "held by %s" % _peer_name(owner)
	return {"object_id": id, "peer": sender}


func _validate_release(sender: int, payload: Dictionary) -> Variant:
	var id := str(payload.get("object_id", ""))
	if _claims.get(id, 0) != sender:
		return "not held by you"
	return {"object_id": id, "peer": 0}


func _apply_claim(payload: Dictionary) -> void:
	var id: String = payload.object_id
	var peer: int = payload.peer
	if peer == 0:
		_claims.erase(id)
	else:
		_claims[id] = peer
	claim_changed.emit(id, peer)


func _release_all(peer_id: int) -> void:
	for id in _claims.keys():
		if _claims[id] == peer_id:
			_broadcast(RELEASE, {"object_id": id, "peer": 0})


# --- Host side -------------------------------------------------------------------------

func _host_handle(sender: int, event_name: String, payload: Dictionary) -> void:
	var entry: Dictionary = _events.get(event_name, {})
	if entry.is_empty():
		_reject(sender, event_name, "unknown event")
		return
	var out: Variant = payload
	var validate: Callable = entry.validate
	if validate.is_valid():
		out = validate.call(sender, payload)
	if out is String:
		_reject(sender, event_name, out)
	elif out is Dictionary:
		_broadcast(event_name, out)
	else:
		_reject(sender, event_name, "validator returned %s" % type_string(typeof(out)))


func _broadcast(event_name: String, payload: Dictionary) -> void:
	_seq += 1
	for id in _peers:
		if id != HOST_ID:
			_wire.event.rpc_id(id, _seq, event_name, payload)
	_apply(event_name, payload)


func _reject(sender: int, event_name: String, reason: String) -> void:
	if sender == local_peer_id():
		request_rejected.emit(event_name, reason)
	else:
		_wire.rejected.rpc_id(sender, event_name, reason)


func _collect_snapshot() -> Dictionary:
	var out := {}
	for section in _snapshots:
		out[section] = _snapshots[section].get_net_snapshot()
	return out


## The first way two compat dictionaries differ, in words, or "" if they match.
static func compat_problem(host_info: Dictionary, peer_info: Dictionary) -> String:
	if host_info.get("protocol") != peer_info.get("protocol"):
		return "Different network protocol (host %s, you %s)" % [host_info.get("protocol"), peer_info.get("protocol")]
	if host_info.get("game_version") != peer_info.get("game_version"):
		return "Different game version (host %s, you %s)" % [host_info.get("game_version"), peer_info.get("game_version")]
	var host_mods: Dictionary = host_info.get("modules", {})
	var peer_mods: Dictionary = peer_info.get("modules", {})
	var ids := host_mods.keys() + peer_mods.keys()
	ids.sort()
	for id in ids:
		var h: Variant = host_mods.get(id)
		var p: Variant = peer_mods.get(id)
		if h == p:
			continue
		if h == null:
			return "You have %s on and the host doesn't" % id
		if p == null:
			return "Host has %s on and you don't" % id
		return "Different %s version (host %s, you %s)" % [id, h, p]
	for key in host_info:
		if key not in ["protocol", "game_version", "modules"] and host_info[key] != peer_info.get(key):
			return "Different %s (host %s, you %s)" % [key, host_info[key], peer_info.get(key)]
	return ""


func _compat_info() -> Dictionary:
	var info := compat.duplicate(true)
	info["protocol"] = PROTOCOL
	return info


func _on_peer_connected(_id: int) -> void:
	pass  # Nothing until the peer says hello.


func _on_peer_disconnected(id: int) -> void:
	if state != State.HOSTING or not _peers.has(id):
		return
	_peers.erase(id)
	_release_all(id)
	for other in _peers:
		if other != HOST_ID:
			_wire.peer_removed.rpc_id(other, id, "left")
	peer_left.emit(id, "left")


func _on_hello(sender: int, info: Dictionary) -> void:
	if state != State.HOSTING or _peers.has(sender):
		return
	var problem := compat_problem(_compat_info(), info.get("compat", {}))
	if problem == "" and _peers.size() > _max_clients:
		problem = "The crew is full"
	if problem != "":
		_wire.refused.rpc_id(sender, problem)
		get_tree().create_timer(REFUSE_GRACE).timeout.connect(func():
			if _mp.multiplayer_peer is ENetMultiplayerPeer and sender in _mp.get_peers():
				_mp.multiplayer_peer.disconnect_peer(sender))
		return
	var peer_profile: Dictionary = info.get("profile", {})
	for other in _peers:
		if other != HOST_ID:
			_wire.peer_added.rpc_id(other, sender, peer_profile)
	_peers[sender] = peer_profile
	_wire.welcome.rpc_id(sender, _peers, _seq, _collect_snapshot())
	peer_joined.emit(sender, peer_profile)


func _on_request(sender: int, event_name: String, payload: Dictionary) -> void:
	if state == State.HOSTING and _peers.has(sender):
		_host_handle(sender, event_name, payload)


func _on_ping(sender: int, t_client: float) -> void:
	if state == State.HOSTING and _peers.has(sender):
		_wire.pong.rpc_id(sender, t_client, _now())


# --- Client side -----------------------------------------------------------------------

func _on_connected_to_server() -> void:
	_wire.hello.rpc_id(HOST_ID, {"compat": _compat_info(), "profile": profile})


func _on_connection_failed() -> void:
	_close("Could not reach the host")


func _on_server_disconnected() -> void:
	_close(_end_reason if _end_reason != "" else "The host left")


func _on_welcome(all_peers: Dictionary, seq: int, snapshot: Dictionary) -> void:
	if state != State.JOINING:
		return
	_peers = all_peers
	_seq = seq
	for section in snapshot:
		if _snapshots.has(section):
			_snapshots[section].apply_net_snapshot(snapshot[section])
	state = State.JOINED
	_ping_timer = 0.0
	session_started.emit(false)
	for id in _peers:
		if id != local_peer_id():
			peer_joined.emit(id, _peers[id])


func _on_refused(reason: String) -> void:
	_end_reason = reason
	_close.call_deferred(reason)  # Not from inside the peer's own poll.


func _on_event(seq: int, event_name: String, payload: Dictionary) -> void:
	if state != State.JOINED or seq <= _seq:
		return
	if seq != _seq + 1:
		push_warning("NetSession: missed events %d to %d" % [_seq + 1, seq - 1])
	_seq = seq
	_apply(event_name, payload)


func _on_rejected(event_name: String, reason: String) -> void:
	request_rejected.emit(event_name, reason)


func _on_peer_added(id: int, peer_profile: Dictionary) -> void:
	if state == State.JOINED and not _peers.has(id):
		_peers[id] = peer_profile
		peer_joined.emit(id, peer_profile)


func _on_peer_removed(id: int, reason: String) -> void:
	if state == State.JOINED and _peers.has(id):
		_peers.erase(id)
		peer_left.emit(id, reason)


func _on_pong(t_client: float, t_host: float) -> void:
	var now := _now()
	var rtt := now - t_client
	_clock_samples.append(Vector2(rtt, t_host + rtt / 2.0 - now))
	if _clock_samples.size() > CLOCK_SAMPLES:
		_clock_samples.pop_front()
	_clock_offset = _best_sample().y


# --- Shared ----------------------------------------------------------------------------

func _apply(event_name: String, payload: Dictionary) -> void:
	var entry: Dictionary = _events.get(event_name, {})
	if entry.is_empty():
		push_warning("NetSession: event '%s' has no handler here" % event_name)
		return
	var apply: Callable = entry.apply
	if apply.is_valid():
		apply.call(payload)
	event_applied.emit(event_name, payload)


func _close(reason: String) -> void:
	var was := state
	if _mp.multiplayer_peer and not _mp.multiplayer_peer is OfflineMultiplayerPeer:
		_mp.multiplayer_peer.close()
	if was == State.JOINING or was == State.JOINED:
		_claims.clear()  # The host's world is gone; keep nothing it lent us.
	_go_offline()
	if was != State.OFFLINE:
		session_ended.emit(reason)


func _go_offline() -> void:
	_mp.multiplayer_peer = OfflineMultiplayerPeer.new()
	state = State.OFFLINE
	_peers = {HOST_ID: profile.duplicate()}
	for id in _claims.keys():
		if _claims[id] != HOST_ID:
			_claims.erase(id)
	_clock_offset = 0.0
	_clock_samples.clear()


func _best_sample() -> Vector2:
	var best := _clock_samples[0]
	for s in _clock_samples:
		if s.x < best.x:
			best = s
	return best


func _peer_name(peer_id: int) -> String:
	return str(_peers.get(peer_id, {}).get("name", "player %d" % peer_id))


static func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0
