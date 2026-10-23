extends Node
## The world the crew shares: the host's time of day. A player who joined sees the host's
## hour on every sky (UI's AlienSky, group "alien_sky") instead of their own setting, and goes
## back to their own when the session ends. Owned by MultiplayerBus.

const TIME := "world.time"
const CHECK := 0.5

var net: MultiplayerBus
var _hour := -1.0  # the host's hour while joined; -1 follows this player's own setting
var _check := 0.0


func _ready() -> void:
	net.register_event(TIME, _apply_time, func(_sender: int, _p: Dictionary) -> Variant:
		return "only the host sets the time")
	net.register_snapshot_provider("world", self)
	Settings.changed.connect(_on_setting)
	net.session_ended.connect(func(_reason: String) -> void: _follow_own())


func _exit_tree() -> void:
	if Settings.changed.is_connected(_on_setting):
		Settings.changed.disconnect(_on_setting)


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or _hour < 0.0:
		return
	_check = CHECK
	# New scenes bring new skies, and a sky goes back to its setting when that changes.
	for sky: AlienSky in get_tree().get_nodes_in_group("alien_sky"):
		if not is_equal_approx(sky.hour_override, _hour):
			sky.set_hour(_hour)


## The hour a joined player sees, or -1 when they follow their own setting.
func shared_hour() -> float:
	return _hour


func _on_setting(section: String, key: String, _value: Variant) -> void:
	if section == AlienSky.SECTION and key == AlienSky.KEY and net.is_online() and net.is_host():
		net.host_emit(TIME, {"hour": AlienSky.setting_hour()})


func _apply_time(p: Dictionary) -> void:
	if not net.is_host():
		_take(float(p.get("hour", AlienSky.DEFAULT_HOUR)))


func _take(hour: float) -> void:
	_hour = fposmod(hour, 24.0)
	_check = 0.0


func _follow_own() -> void:
	if _hour < 0.0:
		return
	for sky: AlienSky in get_tree().get_nodes_in_group("alien_sky"):
		if is_equal_approx(sky.hour_override, _hour):
			sky.set_hour(-1.0)
	_hour = -1.0


func get_net_snapshot() -> Dictionary:
	return {"hour": AlienSky.setting_hour()}


func apply_net_snapshot(data: Dictionary) -> void:
	_take(float(data.get("hour", AlienSky.DEFAULT_HOUR)))
