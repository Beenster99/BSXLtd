extends VBoxContainer
## Settings > Debug > Progression: testing shortcuts for the local player.

var bus: ProgressionBus
var _level: Label


func _init(p_bus: ProgressionBus) -> void:
	bus = p_bus
	add_theme_constant_override("separation", 6)
	_level = BsxTheme.muted("")
	add_child(_level)
	var max_xp := BsxTheme.button("Max XP", bus.request_max_xp)
	max_xp.name = "MaxXp"
	max_xp.tooltip_text = "Every tool at its top level, for you only."
	add_child(max_xp)
	bus.profile_changed.connect(_show_level)
	_show_level()


func _show_level() -> void:
	var me := bus.my_player_id()
	_level.text = "%s: total level %d" % [me, bus.total_level(me)]
