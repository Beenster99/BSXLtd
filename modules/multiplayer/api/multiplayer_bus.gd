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
## "multiplayer.online" feature (on since 2026-10-21; Host and Join are on the title
## screen's Play Online).

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
## Someone pinged (the sender too, solo play included): {"id": int, "peer", "name",
## "colour": Color, "at": Vector3, "normal": Vector3, "object_id": String ("" for bare
## floor), "label": what the object is called ("" for none), "time": host clock}. Draw the
## marker, highlight and label from this signal, not from the click, for PING_LIFE. See ping().
signal ping_received(ping: Dictionary)
## A player's sixth live ping replaced their oldest: take that marker down now.
signal ping_removed(ping_id: int)
## The home router's port for hosting changed: see router_info().
signal router_changed(info: Dictionary)
## What a player holds or does changed (set_held()); fires for this player too.
signal held_changed(peer_id: int, held: Dictionary)
## An avatar for another player was put in the scene (joining, or a scene change rebuilt it):
## dress it now, e.g. the tool in its hand from held(peer_id).
signal avatar_added(peer_id: int, avatar: Node3D)
## Someone signalled the crew (the sender too, solo play included): {"peer", "name",
## "emote": id from EMOTES, "label": what it says ("Need help"), "time": host clock}.
## Their avatar acts it out with a bubble over the helmet; see emote().
signal emote_received(emote: Dictionary)

const ONLINE_FLAG := "multiplayer.online"
const DEFAULT_PORT := 24570
## Host plus three. Change here if the crew size changes.
const MAX_CREW := 4
## The wrist screen's Crew channel (behind the flag of the same name). Other modules add
## dockets to it with HudSlots.register_holo_section(CREW_CHANNEL, ...).
const CREW_CHANNEL := "multiplayer.crew"
## How long a ping marker shows, and how many each player can have showing at once.
const PING_LIFE := 10.0
const PINGS_EACH := 5
## The title screen's Play Online screen (host or join), there while online play is on.
const PLAY_SCENE := "multiplayer.play_together"
const CREW_SCREEN := preload("res://modules/multiplayer/internal/crew/crew_screen.gd")

var _crew: Node
var _was_client := false
var _router: Node
var _host_port := DEFAULT_PORT

var _session: NetSession


func register_module() -> void:
	Settings.register("multiplayer", {"player_name": "Fitter", "port": DEFAULT_PORT,
			"last_address": "127.0.0.1", "open_router": true})
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
	_crew.ping_received.connect(ping_received.emit)
	_crew.ping_removed.connect(ping_removed.emit)
	_crew.held_changed.connect(held_changed.emit)
	_crew.avatar_added.connect(avatar_added.emit)
	_crew.emote_received.connect(emote_received.emit)
	add_child(_crew)
	var world: Node = preload("res://modules/multiplayer/internal/world_sync.gd").new()
	world.name = "World"
	world.net = self
	add_child(world)
	if Flags.is_on(CREW_CHANNEL):
		HudSlots.register_holo_channel(CREW_CHANNEL, "Crew", _crew_screen, 45)
	if Flags.is_on(ONLINE_FLAG):
		Router.register_scene(PLAY_SCENE, "res://modules/multiplayer/internal/lobby/play_together.tscn")
		Menu.register_entry(PLAY_SCENE, "Play Online", PLAY_SCENE, 5)
	_router = preload("res://modules/multiplayer/internal/net_router.gd").new()
	_router.name = "Router"
	_router.changed.connect(router_changed.emit)
	add_child(_router)
	session_started.connect(func(as_host: bool) -> void:
		_was_client = not as_host
		if as_host and bool(Settings.get_value("multiplayer", "open_router")):
			_router.open(_host_port))
	session_ended.connect(_on_session_ended)


func unregister_module() -> void:
	HudSlots.unregister_holo_channel(CREW_CHANNEL)
	Menu.unregister_entry(PLAY_SCENE)
	if _session:
		_session.leave()


## A player who joined someone's yard has no game of their own there, so when the session
## ends (the host left, or they did) they go back to Play Online, which says why.
func _on_session_ended(reason: String) -> void:
	_router.close()
	var was_client := _was_client
	_was_client = false
	if was_client and Modules.bus("multiplayer") == self and Router.has_scene(PLAY_SCENE) \
			and Router.current_id != PLAY_SCENE:
		Router.goto.call_deferred(PLAY_SCENE, {"note": "Left the crew game: %s" % reason})


# --- Sessions --------------------------------------------------------------------------

## Starts hosting. Fails with ERR_UNAVAILABLE while the online feature is switched off.
func host(port: int = DEFAULT_PORT) -> Error:
	if not Flags.is_on(ONLINE_FLAG):
		return ERR_UNAVAILABLE
	_refresh_identity()
	_host_port = port
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


## Hosting over the internet: when hosting starts, the game asks the home router (UPnP) to
## open the port and for its internet address. {"state": "off" | "opening" | "open" |
## "failed", "external": the address crew type to join from outside, "port", "reason"}.
## Settings "multiplayer" / "open_router" = false skips the router.
func router_info() -> Dictionary:
	return _router.info.duplicate()


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


## Another player's avatar head (face toward -Z, centre at the origin) for hanging gear on,
## such as a welding shield or helmet torch; null for this player or when there is no avatar.
func avatar_head(peer_id: int) -> Node3D:
	if peer_id == local_peer_id():
		return null
	return _crew.head_of(peer_id)


## Another player's avatar (feet at the origin, facing -Z), or null for this player or none.
func avatar(peer_id: int) -> Node3D:
	return null if peer_id == local_peer_id() else _crew.avatar_of(peer_id)


## Another player's hand on their avatar (right or left; it holds what their real hand holds
## when Tools shares hands), for putting their tool in and playing its sounds from; null for
## this player or when there is no avatar. Hands are in group "crew_hand" with metas
## "peer_id" and "side".
func avatar_hand(peer_id: int, right := true) -> Node3D:
	return null if peer_id == local_peer_id() else _crew.hand_of(peer_id, right)


## Tools: this player's hand nodes (null for none). Their transforms stream to the crew so
## this player's avatar reaches where the hands really are; otherwise its hands hang at rest.
func set_local_hands(right: Node3D, left: Node3D) -> void:
	_crew.set_local_hands(right, left)


## Tools: what this player holds and does, for the crew to show on their avatar and hear,
## e.g. {"tool": "welder", "using": true}. Small values only: up to 8 keys of bool, number
## or short text. Send it when it changes, not every frame; held_changed follows everywhere.
func set_held(state: Dictionary) -> void:
	_crew.set_held(state)


## What a player last shared with set_held() ({} for nothing).
func held(peer_id: int) -> Dictionary:
	return _crew.held(peer_id)


## Signals the crew: an emote id from emotes() ("wave", "thumbs_up", "come_here", "point",
## "help", "stop", "thumbs_down", "cheer"). The host allows one per player every 0.5 s.
func emote(emote_id: String) -> void:
	_crew.emote(emote_id)


## The emotes on the wheel, clockwise from the top: [{"id", "label"}].
func emotes() -> Array[Dictionary]:
	return _crew.EMOTES.duplicate(true)


## Graphics: middle mouse (or the ping key) held past a tap opens the emote wheel; the
## player moves the mouse toward a signal. While it's open the view doesn't turn.
func open_emote_wheel() -> void:
	_crew.open_wheel()


## Graphics: let go. Sends the emote the wheel points at and gives its id, or "" when the
## player let go in the middle (nothing sent).
func close_emote_wheel() -> String:
	return _crew.close_wheel()


func emote_wheel_open() -> bool:
	return _crew.wheel.is_open


## This player's crew colour (host orange, then cyan, green, amber), for markers and names.
func player_colour(peer_id: int) -> Color:
	return _crew.player_colour(peer_id)


## "Look here" for the whole crew: the middle mouse button's hit point, the data id of what
## is under the mouse ("" for bare floor; never a node path) and the surface normal. The host
## allows one ping per player every 0.25 s and PINGS_EACH showing at once (a new one
## replaces their oldest, with ping_removed); ping_received follows on every peer. `label` is
## what the pinged object is called ("Reactor housing"), shown with the marker.
func ping(at: Vector3, object_id := "", normal := Vector3.UP, label := "") -> void:
	_crew.ping(at, object_id, normal, label)


## Pings still showing (younger than PING_LIFE), oldest first, for things made after one arrived.
func pings() -> Array[Dictionary]:
	return _crew.pings()


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
