class_name ProgressionBus
extends Node
## Progression module bus (Modules.bus("progression")). Trade skills, certifications, and tool and yard upgrades.
## Other modules use this module only through this folder: signals here, and resource
## classes placed next to it. Everything else lives in internal/.
##
## Skills and certs belong to a player; upgrades belong to the company. XP comes from
## finished joints, certs from passed test jobs, upgrades from Business purchases.
##
## Modules below Progression can't call it, so it pushes what they need down instead: after
## any change it hands Trades each player's effects with `set_player_modifiers(player_id,
## {effect_key: value})`, if Trades offers that method. It listens for these, where present:
##   Trades    joint_completed(joint_id, quality, trade, player_id)
##   Quality   test_passed(job_id, player_ids: Array)
##   Contracts job_closed(job_id)
##   Business  purchase_completed(order_id), purchase_failed(order_id, reason)
## and buys through Business `request_purchase(price_ref, order_id)`.

signal xp_gained(player_id: StringName, skill_id: StringName, amount: int, total: int)
signal level_up(player_id: StringName, skill_id: StringName, level: int)
signal cert_awarded(player_id: StringName, cert_id: StringName)
signal cert_lapsed(player_id: StringName, cert_id: StringName)
signal upgrade_unlocked(upgrade_id: StringName)
signal upgrade_failed(upgrade_id: StringName, reason: String)

const SAVE_SECTION := "progression"
const ORDER_PREFIX := "progression:"
const Catalog := preload("res://modules/progression/internal/catalog.gd")
const State := preload("res://modules/progression/internal/progression_state.gd")

var _state: RefCounted = State.new(Catalog.from_data())
var _trades: Node
var _business: Node
var _pending: Dictionary = {}  # order_id -> upgrade_id


func register_module() -> void:
	attach(Modules.bus("trades"), Modules.bus("business"), Modules.bus("quality"),
			Modules.bus("contracts"))
	Saves.register_section(SAVE_SECTION, self)


func unregister_module() -> void:
	Saves.unregister_section(SAVE_SECTION)


## Connects to the other modules' buses. register_module() passes the real ones; tests pass
## stand-ins. Any of them may be null.
func attach(trades: Node, business: Node, quality: Node, contracts: Node) -> void:
	_trades = trades
	_business = business
	_listen(trades, "joint_completed", _on_joint_completed)
	_listen(quality, "test_passed", _on_test_passed)
	_listen(contracts, "job_closed", _on_job_closed)
	_listen(business, "purchase_completed", _on_purchase_completed)
	_listen(business, "purchase_failed", _on_purchase_failed)


# Queries

func skill_xp(player_id: StringName, skill_id: StringName) -> int:
	return _state.xp(player_id, skill_id)


func skill_level(player_id: StringName, skill_id: StringName) -> int:
	return _state.level(player_id, skill_id)


func has_cert(player_id: StringName, cert_id: StringName) -> bool:
	return _state.has_cert(player_id, cert_id)


func has_upgrade(upgrade_id: StringName) -> bool:
	return _state.has_upgrade(upgrade_id)


## Skill perks plus owned upgrades for `key`; 0.0 when nothing applies.
func effect(player_id: StringName, key: StringName) -> float:
	return _state.effect(player_id, key)


func effects(player_id: StringName) -> Dictionary:
	return _state.effects(player_id)


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


# Commands (host only; Multiplayer routes client requests to the host)

## Asks Business to charge for the upgrade; upgrade_unlocked or upgrade_failed follows.
func request_upgrade(upgrade_id: StringName) -> void:
	if not _is_host():
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


func award_cert(player_id: StringName, cert_id: StringName) -> void:
	if not _is_host() or not _state.catalog.certs.has(cert_id) or has_cert(player_id, cert_id):
		return
	_state.award(player_id, cert_id)
	cert_awarded.emit(player_id, cert_id)


# Save provider (Saves section "progression")

func save_version() -> int:
	return State.SAVE_VERSION


func save_data() -> Dictionary:
	return _state.to_dict()


func load_data(data: Dictionary, from_version: int) -> void:
	_state.from_dict(data, from_version)
	_pending = {}
	for pid in _state.players:
		_push_effects(StringName(pid))


# Events from other modules

func _on_joint_completed(_joint_id: Variant, quality: float, trade: StringName = &"",
		player_id: StringName = &"") -> void:
	if not _is_host():
		return
	var r: Dictionary = _state.add_joint(player_id, trade, quality)
	if r.is_empty():
		return
	xp_gained.emit(player_id, r.skill, r.amount, r.xp)
	for lvl in range(r.level_before + 1, r.level_after + 1):
		level_up.emit(player_id, r.skill, lvl)
	if r.level_after > r.level_before:
		_push_effects(player_id)


func _on_test_passed(job_id: StringName, player_ids: Array) -> void:
	if not _is_host():
		return
	for pair in _state.pass_test(job_id, player_ids):
		cert_awarded.emit(pair[0], pair[1])


func _on_job_closed(_job_id: Variant) -> void:
	if not _is_host():
		return
	for pair in _state.close_job():
		cert_lapsed.emit(pair[0], pair[1])


func _on_purchase_completed(order_id: String) -> void:
	if not _pending.has(order_id):
		return
	var id: StringName = _pending[order_id]
	_pending.erase(order_id)
	_state.own(id)
	upgrade_unlocked.emit(id)
	for pid in _state.players:
		_push_effects(StringName(pid))


func _on_purchase_failed(order_id: String, reason: String) -> void:
	if _pending.has(order_id):
		upgrade_failed.emit(_pending[order_id], reason)
		_pending.erase(order_id)


func _push_effects(player_id: StringName) -> void:
	if _trades and _trades.has_method("set_player_modifiers"):
		_trades.set_player_modifiers(player_id, effects(player_id))


func _is_host() -> bool:
	return not is_inside_tree() or multiplayer.is_server()


static func _listen(bus: Node, signal_name: String, handler: Callable) -> void:
	if bus and bus.has_signal(signal_name) and not bus.is_connected(signal_name, handler):
		bus.connect(signal_name, handler)
