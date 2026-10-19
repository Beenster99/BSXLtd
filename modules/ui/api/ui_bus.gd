class_name UiBus
extends Node
## The UI module's bus (Modules.bus("ui")). Registers the menus with Router and the audio
## setting (window and graphics options belong to the Graphics autoload), and applies it
## when it changes.

signal notice_posted(text: String)

const MAIN_MENU := "main_menu"
const SETTINGS := "settings"


func register_module() -> void:
	Router.register_scene(MAIN_MENU, "res://modules/ui/internal/main_menu.tscn")
	Router.register_scene(SETTINGS, "res://modules/ui/internal/settings_menu.tscn")
	Settings.register("audio", {"master": 1.0})
	Shots.register("main_menu", MAIN_MENU)
	Shots.register("settings", SETTINGS)
	Settings.changed.connect(_on_setting_changed)
	apply_settings()


func unregister_module() -> void:
	if Settings.changed.is_connected(_on_setting_changed):
		Settings.changed.disconnect(_on_setting_changed)


## Shows a short message in the HUD's notices slot.
func post_notice(text: String) -> void:
	notice_posted.emit(text)


func apply_settings() -> void:
	var master: float = Settings.get_value("audio", "master")
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))


func _on_setting_changed(_section: String, _key: String, _value: Variant) -> void:
	apply_settings()
