class_name MultiplayerBus
extends Node
## Multiplayer module bus (Modules.bus("multiplayer")). Lobby, sessions, state sync, two-player interactions and player avatars.
## Other modules use this module only through this folder: signals here, and resource
## classes placed next to it. Everything else lives in internal/.
##
## Solo play is a session of one with the local player as host, so modules write their
## actions the same way whether or not anyone else is connected:
##
##   var net := Modules.bus("multiplayer") as MultiplayerBus
##   net.register_event("trades.joint_completed", _apply_joint, _validate_joint)
##   net.request("trades.joint_completed", {"joint_id": id, "torque": 41.5})
##
## `apply(payload)` runs on every peer in the host's order; `validate(sender_id, payload)`
## runs on the host and returns the payload to broadcast or a String reason to refuse.
## Sync events, not scenes: address things by data ids (joint_id, component instance id),
## never node paths. Joining players get each registered snapshot provider's state first.
##
## The module itself is always on (flag "multiplayer"); hosting and joining are the
## "multiplayer.online" feature, switched on in release 0.4.

signal session_started(as_host: bool)
signal session_ended(reason: String)
signal peer_joined(peer_id: int, profile: Dictionary)
signal peer_left(peer_id: int, reason: String)
## After any event has been applied on this peer (handy for HUD feedback and tests).
signal event_applied(event_name: String, payload: Dictionary)
## A request this player made was refused by the host, or could not be sent.
signal request_rejected(event_name: String, reason: String)
signal claim_changed(object_id: String, peer_id: int)
## A hold started, changed or ended (info is {} when it ended). See set_hold().
signal hold_changed(object_id: String, info: Dictionary)
## A line in the crew text channel: {"time": "22:14", "peer", "name", "text"}.
signal chat_received(line: Dictionary)
signal activity_changed(peer_id: int, text: String)

const ONLINE_FLAG := "multiplayer.online"
const DEFAULT_PORT := 24570
## Host plus three. Change here if the crew size changes.
const MAX_CREW := 4
## The wrist screen's Crew channel (behind the flag of the same name). Other modules add
## dockets to it with HudSlots.register_holo_section(CREW_CHANNEL, ...).
const CREW_CHANNEL := "multiplayer.crew"
const CREW_SCREEN := preload("res://modules/multiplayer/internal/crew/crew_screen.gd")

var _crew: Node

var _session: NetSession


func register_module() -> void:
	Settings.register("multiplayer", {"player_name": "Fitter", "port": DEFAULT_PORT,
			"last_address": "127.0.0.1"})
	_session = NetSession.new()
	_session.name = "Session"
	_session.compat = compat_info()
	_session.profile = {"name": str(Settings.get_value("multiplayer", "player_name"))}
	for s in ["session_started", "session_ended", "peer_joined", "peer_left", "event_applied",
			"request_rejected", "claim_changed", "hold_changed"]:
		_session.connect(s, Signal(self, s).emit)
	add_child(_session)
	_crew = preload("res://modules/multiplayer/internal/crew/crew_channel.gd").new()
	_crew.name = "Crew"
	_crew.net = self
	_crew.chat_received.connect(chat_received.emit)
	_crew.activity_changed.connect(activity_changed.emit)
	add_child(_crew)
	if Flags.is_on(CREW_CHANNEL):
		HudSlots.register_holo_channel(CREW_CHANNEL, "Crew", _crew_screen, 45)


func unregister_module() -> void:
	HudSlots.unregister_holo_channel(CREW_CHANNEL)
	if _session:
		_session.leave()


# --- Sessions --------------------------------------------------------------------------

## Starts hosting. Fails with ERR_UNAVAILABLE while the online feature is switched off.
func host(port: int = DEFAULT_PORT) -> Error:
	if not Flags.is_on(ONLINE_FLAG):
		return ERR_UNAVAILABLE
	_refresh_identity()
	return _session.host(port, MAX_CREW - 1)


## Joins a host; session_started or session_ended (with the reason) follows.
func join(address: String, port: int = DEFAULT_PORT) -> Error:
	if not Flags.is_on(ONLINE_FLAG):
		return ERR_UNAVAILABLE
	_refresh_identity()
	return _session.join(address, port)


func leave() -> void:
	_session.leave()


func is_online() -> bool:
	return _session.is_online()


## True when solo, so host-only work (deliveries, timers) runs in solo play too.
func is_host() -> bool:
	return _session.is_host()


func local_peer_id() -> int:
	return _session.local_peer_id()


## Accepted players, host included: peer id -> profile ({"name": ...}).
func peers() -> Dictionary:
	return _session.peers()


## Seconds on the host's clock; timestamps compared across players use this.
func server_time() -> float:
	return _session.server_time()


func round_trip() -> float:
	return _session.round_trip()


# --- Events ----------------------------------------------------------------------------

## Event names are "<module>.<thing>" so modules never collide.
func register_event(event_name: String, apply: Callable, validate := Callable()) -> void:
	_session.register_event(event_name, apply, validate)


func unregister_event(event_name: String) -> void:
	_session.unregister_event(event_name)


func request(event_name: String, payload: Dictionary = {}) -> void:
	_session.request(event_name, payload)


## Host only: an event no player asked for (a delivery arriving, a timer running out).
func host_emit(event_name: String, payload: Dictionary = {}) -> void:
	_session.host_emit(event_name, payload)


## provider: get_net_snapshot() -> Dictionary, apply_net_snapshot(data: Dictionary).
## Use the module id as the section.
func register_snapshot_provider(section: String, provider: Object) -> void:
	_session.register_snapshot_provider(section, provider)


func unregister_snapshot_provider(section: String) -> void:
	_session.unregister_snapshot_provider(section)


# --- Claims ----------------------------------------------------------------------------

## Hold a part, tool or circuit lock so nobody else takes it; claim_changed confirms.
func claim(object_id: String) -> void:
	_session.claim(object_id)


func release(object_id: String) -> void:
	_session.release(object_id)


## Peer id holding the object, or 0.
func claim_owner(object_id: String) -> int:
	return _session.claim_owner(object_id)


func is_mine(object_id: String) -> bool:
	return _session.claim_owner(object_id) == _session.local_peer_id()


# --- Holds: one player holds, another fastens ----------------------------------------
#
# The tractor beam (or a pair of hands) holds a unit; the holder's tool decides each moment
# whether it sits within tolerance of its target and says so here. A fastening event's
# validator checks is_hold_ready() on the host, so the first rivet, weld or bolt only counts
# while the unit is held in alignment:
#
#   net.set_hold("unit:reactor_2", true, false, "slot:engine_bay_1")    # holder, aligned
#   func _validate_rivet(sender, p): return p if net.is_hold_ready(p.unit) else "not held in line"
#
# Solo play: the same player locks the hold (locked = true), puts the beam down and fastens.

## Holds the object (claiming it if free). Send again whenever aligned or locked changes.
func set_hold(object_id: String, aligned: bool, locked := false, target := "") -> void:
	_session.set_hold(object_id, aligned, locked, target)


## Ends the hold and lets the object go (the same as release()).
func end_hold(object_id: String) -> void:
	_session.release(object_id)


## {"peer": holder, "aligned": bool, "locked": bool, "target": String}, or {}.
func hold_info(object_id: String) -> Dictionary:
	return _session.hold_info(object_id)


func is_hold_ready(object_id: String) -> bool:
	return _session.is_hold_ready(object_id)


# --- Movers: things that move every frame -------------------------------------------
#
# A unit in a tractor beam, a hover trolley, the picking lift. Each peer registers its own
# node under the same data id; the player with the object claimed drives it (the host when
# nobody has, so automated trolleys and the lift run on the host) and everyone else's copy
# follows smoothly. Route planning only ever runs on the driving peer.
#
#   net.register_mover("trolley:large_1", trolley_node)
#   net.claim("trolley:large_1")      # remote control: this player now drives it

func register_mover(object_id: String, node: Node3D) -> void:
	_session.register_mover(object_id, node)


func unregister_mover(object_id: String) -> void:
	_session.unregister_mover(object_id)


## Peer driving the object: its claim owner, or the host.
func mover_authority(object_id: String) -> int:
	return _session.mover_authority(object_id)


## True when this peer should run the object's motion (physics, routing, beam control).
func drives(object_id: String) -> bool:
	return _session.mover_authority(object_id) == _session.local_peer_id()


# --- Crew ------------------------------------------------------------------------------

## Says something on the crew text channel (everyone sees it, solo play included).
func say(text: String) -> void:
	_crew.say(text)


func chat_log() -> Array[Dictionary]:
	return _crew.chat_log()


## A few words on what this player is doing ("Riveting", "Stores"), shown on the crew list.
## Tools and other modules may set it as the player changes job.
func set_activity(text: String) -> void:
	_crew.set_activity(text)


func activity(peer_id: int) -> String:
	return _crew.activity(peer_id)


func player_name(peer_id: int) -> String:
	return _crew.player_name(peer_id)


func _crew_screen(glass: bool) -> Control:
	var screen: Control = CREW_SCREEN.new()
	screen.net = self
	screen.crew = _crew
	screen.glass = glass
	return screen


# --- Compatibility ---------------------------------------------------------------------

## What a joining player must match: game version and the version of every loaded module.
## A mismatch is refused with a plain reason ("Different trades version (host 0.2.0, you
## 0.1.0)"). The Shared Components library hash joins this once that module exists.
func compat_info() -> Dictionary:
	var modules := {}
	for id in Modules.loaded():
		var m := Modules.manifest(id)
		if m:
			modules[id] = m.version
	return {
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"modules": modules,
	}


## Modules finish loading after this one, and the name can change in settings.
func _refresh_identity() -> void:
	_session.compat = compat_info()
	_session.profile = {"name": str(Settings.get_value("multiplayer", "player_name"))}
