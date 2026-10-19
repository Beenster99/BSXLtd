extends Node
## Player settings (autoload `Settings`), saved to user://settings.cfg. A module registers
## its section with defaults, then reads and writes values; Core never needs to know them.
##   Settings.register("audio", {"master": 1.0})
##   Settings.get_value("audio", "master")

signal changed(section: String, key: String, value: Variant)

const PATH := "user://settings.cfg"

var _defaults: Dictionary = {}
var _cfg := ConfigFile.new()


func _init() -> void:
	_cfg.load(PATH)


func register(section: String, defaults: Dictionary) -> void:
	_defaults[section] = defaults.duplicate()


func get_value(section: String, key: String) -> Variant:
	var fallback: Variant = _defaults.get(section, {}).get(key)
	return _cfg.get_value(section, key, fallback)


func set_value(section: String, key: String, value: Variant) -> void:
	_cfg.set_value(section, key, value)
	changed.emit(section, key, value)


func sections() -> PackedStringArray:
	return PackedStringArray(_defaults.keys())


func keys(section: String) -> PackedStringArray:
	return PackedStringArray(_defaults.get(section, {}).keys())


func save() -> void:
	_cfg.save(PATH)
