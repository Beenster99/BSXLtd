class_name ProgressionBus
extends Node
## Progression module bus (Modules.bus("progression")). Trade skills, certifications, and tool and yard upgrades.
## Other modules use this module only through this folder: signals here, and resource
## classes placed next to it. Everything else lives in internal/.
##
## Skills and certs belong to a player; upgrades belong to the company. XP comes from
## joints as Quality grades them (score 0..100 scales the XP; ungraded joints count as
## half), certs from passed test jobs, upgrades from Business purchases.
##
## Modules below Progression can't call it, so it pushes what they need down instead: after
## any change it hands each player's effects to Trades and Quality with
## `set_player_modifiers(player_id, {effect_key: value})`, where offered. Each reads the keys
## it owns (Trades "bolt_speed", Quality "torque_tolerance") and ignores the rest. It listens for these, where present:
##   Quality   joint_graded(record: JointRecord), record_dropped(joint_id),
##             test_passed(job_id, player_ids: Array)  (from 0.5)
##   Contracts job_closed(job_id)
##   Business  purchase_completed(order_id), purchase_failed(order_id, reason)
## and buys through Business `request_purchase(price_ref, order_id)`.
##
## Players are known by their crew name (Multiplayer's profile), so XP survives rejoining
## with a new peer id; Trades and Quality still get effects keyed by str(peer_id). Queries
## take either. The host keeps the state and sends it to every peer after each change.
## Settings > Character shows the local player's skills, levels and certs.
##
## The module flag "progression" switches on XP and levels (one track per tool, five
## levels each). Perks, certifications and upgrades each have their own feature flag.

signal xp_gained(player_id: StringName, skill_id: StringName, amount: int, total: int)
signal level_up(player_id: StringName, skill_id: StringName, level: int)
signal cert_awarded(player_id: StringName, cert_id: StringName)
signal cert_lapsed(player_id: StringName, cert_id: StringName)
signal upgrade_unlocked(upgrade_id: StringName)
signal upgrade_failed(upgrade_id: StringName, reason: String)
## Anything in the state changed (here, or from the host's copy on a client).
signal profile_changed

const SAVE_SECTION := "progression"
const STATE_EVENT := "progression.state"
const UPGRADE_EVENT := "progression.upgrade"
const MAX_XP_EVENT := "progression.debug_max_xp"
const DEBUG_SECTION := "progression.debug"
const PROFILE_SECTION := "progression.skills"
## Bonuses from levels (tool speed, tolerance).
const PERKS := "progression.perks"
## Certifications from test jobs.
const CERTS := "progression.certs"
## Tool and yard upgrades bought through Business.
const UPGRADES := "progression.upgrades"
const ORDER_PREFIX := "progression:"
## XP scale for a joint Quality has no rules for yet.
const UNGRADED_QUALITY := 0.5
const Catalog := preload("res://modules/progression/internal/catalog.gd")
const State := preload("res://modules/progression/internal/progression_state.gd")
const ProfilePanel := preload("res://modules/progression/internal/ui/profile_panel.gd")
const DebugPanel := preload("res://modules/progression/internal/ui/debug_panel.gd")

var _state: RefCounted = State.new(Catalog.from_data())
var _trades: Node
var _quality: Node
var _business: Node
var _net: MultiplayerBus
var _pending: Dictionary = {}  # order_id -> upgrade_id


func register_module() -> void:
	attach(Modules.bus("trades"), Modules.bus("business"), Modules.bus("quality"),
			Modules.bus("contracts"))
	attach_net(Modules.bus("multiplayer") as MultiplayerBus)
	Saves.register_section(SAVE_SECTION, self)
	Menu.register_settings_section(Menu.CHARACTER, PROFILE_SECTION, "Skills",
			func() -> Control: return ProfilePanel.new(self), 10)
	Menu.register_settings_section(Menu.DEBUG, DEBUG_SECTION, "Progression",
			func() -> Control: return DebugPanel.new(self), 10)


func unregister_module() -> void:
	Saves.unregister_section(SAVE_SECTION)
	Menu.unregister_settings_section(Menu.CHARACTER, PROFILE_SECTION)
	Menu.unregister_settings_section(Menu.DEBUG, DEBUG_SECTION)
	if _net:
		_net.unregister_event(STATE_EVENT)
		_net.unregister_event(UPGRADE_EVENT)
		_net.unregister_event(MAX_XP_EVENT)
		_net.unregister_snapshot_provider(SAVE_SECTION)
		if _net.peer_joined.is_connected(_on_peer_joined):
			_net.peer_joined.disconnect(_on_peer_joined)


## Connects to the other modules' buses. register_module() passes the real ones; tests pass
## stand-ins. Any of them may be null.
func attach(trades: Node, business: Node, quality: Node, contracts: Node) -> void:
	_trades = trades
	_quality = quality
	_business = business
	_listen(quality, "joint_graded", _on_joint_graded)
	_listen(quality, "record_dropped", _on_record_dropped)
	_listen(quality, "test_passed", _on_test_passed)
	_listen(contracts, "job_closed", _on_job_closed)
	_listen(business, "purchase_completed", _on_purchase_completed)
	_listen(business, "purchase_failed", _on_purchase_failed)


## Shares the state through Multiplayer (null plays alone). Tests pass a stand-in.
func attach_net(net: MultiplayerBus) -> void:
	_net = net
	if _net == null:
		return
	_net.register_event(STATE_EVENT, _apply_state)
	_net.register_event(UPGRADE_EVENT, _apply_upgrade_request, _validate_upgrade_request)
	_net.register_event(MAX_XP_EVENT, _apply_max_xp, _validate_max_xp)
	_net.register_snapshot_provider(SAVE_SECTION, self)
	if not _net.peer_joined.is_connected(_on_peer_joined):
		_net.peer_joined.connect(_on_peer_joined)


# Queries (player_id is a crew name, or a peer id as a string)

func skill_xp(player_id: StringName, skill_id: StringName) -> int:
	return _state.xp(_key(player_id), skill_id)


func skill_level(player_id: StringName, skill_id: StringName) -> int:
	return _state.level(_key(player_id), skill_id)


## Every skill's level added up.
func total_level(player_id: StringName) -> int:
	var total := 0
	for s: ProgressionSkill in skills():
		total += skill_level(player_id, s.id)
	return total


func has_cert(player_id: StringName, cert_id: StringName) -> bool:
	return _state.has_cert(_key(player_id), cert_id)


## Cert ids the player holds now.
func player_certs(player_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for c: ProgressionCert in certs():
		if has_cert(player_id, c.id):
			out.append(c.id)
	return out


## The local player.
func my_player_id() -> StringName:
	return player_for_peer(_net.local_peer_id() if _net else 1)


## A peer's crew name, or str(peer_id) when there's no profile for them. When two in the
## session share a name (everyone starts as "Fitter"), the lowest peer id keeps it and the
## others become "Name#<peer_id>", so they don't share one profile.
func player_for_peer(peer_id: int) -> StringName:
	if _net == null:
		return StringName(str(peer_id))
	var peers := _net.peers()
	var name := _name_of(peers.get(peer_id))
	if name == "":
		return StringName(str(peer_id))
	for other: int in peers:
		if other < peer_id and _name_of(peers[other]) == name:
			return StringName("%s#%d" % [name, peer_id])
	return StringName(name)


static func _name_of(profile: Variant) -> String:
	return str(profile.get("name", "")) if profile is Dictionary else ""


func has_upgrade(upgrade_id: StringName) -> bool:
	return _state.has_upgrade(upgrade_id)


## Skill perks plus owned upgrades for `key`; 0.0 when nothing applies.
func effect(player_id: StringName, key: StringName) -> float:
	return _state.effect(_key(player_id), key, Flags.is_on(PERKS), Flags.is_on(UPGRADES))


func effects(player_id: StringName) -> Dictionary:
	return _state.effects(_key(player_id), Flags.is_on(PERKS), Flags.is_on(UPGRADES))


## {ok: bool, missing: Array[StringName]}; missing holds required upgrade ids, or "owned"
## or "unknown".
func can_unlock(upgrade_id: StringName) -> Dictionary:
	return _state.can_unlock(upgrade_id)


func skills() -> Array:
	return _state.catalog.skills.values()


func certs() -> Array:
	return _state.catalog.certs.values()


func upgrades() -> Array:
	return _state.catalog.upgrades.values()


# Commands (run on the host; a client's request goes to the host through Multiplayer)

## Asks Business to charge for the upgrade; upgrade_unlocked or upgrade_failed follows.
func request_upgrade(upgrade_id: StringName) -> void:
	if not Flags.is_on(UPGRADES):
		upgrade_failed.emit(upgrade_id, "upgrades_off")
		return
	if not _is_host():
		if _net:
			_net.request(UPGRADE_EVENT, {"id": String(upgrade_id)})
		else:
			upgrade_failed.emit(upgrade_id, "not_host")
		return
	var check := can_unlock(upgrade_id)
	if not check.ok:
		upgrade_failed.emit(upgrade_id, "missing:" + ",".join(PackedStringArray(check.missing)))
		return
	if _business == null or not _business.has_method("request_purchase"):
		upgrade_failed.emit(upgrade_id, "business_unavailable")
		return
	var order_id := ORDER_PREFIX + String(upgrade_id)
	if _pending.has(order_id):
		return
	_pending[order_id] = upgrade_id
	var u: ProgressionUpgrade = _state.catalog.upgrades[upgrade_id]
	_business.request_purchase(u.price_ref, order_id)


## Testing (Settings > Debug): puts the local player at the top level with every tool. The
## host applies it, so it works the same for a client.
func request_max_xp() -> void:
	if _net:
		_net.request(MAX_XP_EVENT, {})
	else:
		max_xp(&"1")


func max_xp(player_id: StringName) -> void:
	if not _is_host():
		return
	var key := _key(player_id)
	var before := {}
	for s: ProgressionSkill in skills():
		before[s.id] = skill_level(key, s.id)
	_state.max_out(key)
	for s: ProgressionSkill in skills():
		for lvl in range(int(before[s.id]) + 1, skill_level(key, s.id) + 1):
			level_up.emit(key, s.id, lvl)
	_changed()


func award_cert(player_id: StringName, cert_id: StringName) -> void:
	if not Flags.is_on(CERTS) or not _is_host() or not _state.catalog.certs.has(cert_id) or has_cert(player_id, cert_id):
		return
	_state.award(_key(player_id), cert_id)
	cert_awarded.emit(_key(player_id), cert_id)
	_changed()


# Save provider (Saves section "progression")

func save_version() -> int:
	return State.SAVE_VERSION


func save_data() -> Dictionary:
	return _state.to_dict()


func load_data(data: Dictionary, from_version: int) -> void:
	_state.from_dict(data, from_version)
	_pending = {}
	_changed()


# Multiplayer snapshot (a joining peer gets the host's state)

func get_net_snapshot() -> Dictionary:
	return {"version": State.SAVE_VERSION, "state": _state.to_dict()}


func apply_net_snapshot(data: Dictionary) -> void:
	_apply_state(data)


# Events from other modules

## `record` is a Quality JointRecord, read by field so either module can ship first.
func _on_joint_graded(record: Object) -> void:
	if not _is_host():
		return
	var score := int(record.get("score"))
	var quality := UNGRADED_QUALITY if score < 0 else score / 100.0
	var player_id := player_for_peer(int(record.get("peer_id")))
	var r: Dictionary = _state.add_joint(player_id, StringName(record.get("joint_id")),
			StringName(record.get("trade")), quality)
	if r.is_empty():
		return
	xp_gained.emit(player_id, r.skill, r.amount, r.xp)
	for lvl in range(r.level_before + 1, r.level_after + 1):
		level_up.emit(player_id, r.skill, lvl)
	_changed()


func _on_record_dropped(joint_id: StringName) -> void:
	_state.forget_joint(joint_id)


func _on_test_passed(job_id: StringName, player_ids: Array) -> void:
	if not Flags.is_on(CERTS) or not _is_host():
		return
	var keys := player_ids.map(func(p: Variant) -> StringName: return _key(StringName(str(p))))
	for pair in _state.pass_test(job_id, keys):
		cert_awarded.emit(pair[0], pair[1])
	_changed()


func _on_job_closed(_job_id: Variant) -> void:
	if not _is_host():
		return
	for pair in _state.close_job():
		cert_lapsed.emit(pair[0], pair[1])
	_changed()


func _on_purchase_completed(order_id: String) -> void:
	if not _pending.has(order_id):
		return
	var id: StringName = _pending[order_id]
	_pending.erase(order_id)
	_state.own(id)
	upgrade_unlocked.emit(id)
	_changed()


func _on_purchase_failed(order_id: String, reason: String) -> void:
	if _pending.has(order_id):
		upgrade_failed.emit(_pending[order_id], reason)
		_pending.erase(order_id)


## After any change on the host: effects to Trades and Quality, the state to every peer.
func _changed() -> void:
	_push_effects()
	if _net and _is_host():
		_net.host_emit(STATE_EVENT, get_net_snapshot())
	profile_changed.emit()


## Trades and Quality key their modifiers by str(peer_id). Without Multiplayer (tests),
## every known player's key is used as it is.
func _push_effects() -> void:
	var keys: Array = _net.peers().keys().map(str) if _net else _state.players.keys()
	for key: String in keys:
		var fx := effects(StringName(key))
		for bus in [_trades, _quality]:
			if bus and bus.has_method("set_player_modifiers"):
				bus.set_player_modifiers(StringName(key), fx)


func _on_peer_joined(_peer_id: int, _profile: Dictionary) -> void:
	_push_effects()


## A client takes the host's state as it is; the host already has it.
func _apply_state(payload: Dictionary) -> void:
	if _is_host() or not payload.get("state") is Dictionary:
		return
	_state.from_dict(payload.state, int(payload.get("version", State.SAVE_VERSION)))
	profile_changed.emit()


func _validate_upgrade_request(_sender_id: int, payload: Dictionary) -> Variant:
	var id := StringName(str(payload.get("id", "")))
	var check := can_unlock(id)
	return payload if check.ok else "missing:" + ",".join(PackedStringArray(check.missing))


func _validate_max_xp(sender_id: int, _payload: Dictionary) -> Variant:
	return {"player": String(player_for_peer(sender_id))}


func _apply_max_xp(payload: Dictionary) -> void:
	if _is_host():
		max_xp(StringName(str(payload.get("player", ""))))


func _apply_upgrade_request(payload: Dictionary) -> void:
	if _is_host():
		request_upgrade(StringName(str(payload.get("id", ""))))


## Queries take a crew name or a peer id; a peer id in the session means its crew name.
func _key(player_id: StringName) -> StringName:
	var s := String(player_id)
	return player_for_peer(int(s)) if s.is_valid_int() else player_id


func _is_host() -> bool:
	if _net:
		return _net.is_host()
	return not is_inside_tree() or multiplayer.is_server()


static func _listen(bus: Node, signal_name: String, handler: Callable) -> void:
	if bus and bus.has_signal(signal_name) and not bus.is_connected(signal_name, handler):
		bus.connect(signal_name, handler)
