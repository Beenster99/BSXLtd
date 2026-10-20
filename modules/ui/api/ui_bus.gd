class_name UiBus
extends Node
## The UI module's bus (Modules.bus("ui")). Registers the menus with Router and the audio
## setting (window and graphics options belong to the Graphics autoload), and applies it
## when it changes.

signal notice_posted(text: String)

const MAIN_MENU := "main_menu"
const SETTINGS := "settings"
const TIME_CHANNEL := "ui.time"
const KEYS_CHANNEL := "ui.keys"

## The wrist screen (Keys.HOLO in any game scene).
var holo: WristHolo


func register_module() -> void:
	Router.register_scene(MAIN_MENU, "res://modules/ui/internal/main_menu.tscn")
	Router.register_scene(SETTINGS, "res://modules/ui/internal/settings_menu.tscn")
	Settings.register("audio", {"master": 1.0})
	Settings.register(AlienSky.SECTION, {AlienSky.KEY: AlienSky.DEFAULT_HOUR})
	Shots.register("main_menu", MAIN_MENU)
	Shots.register("settings", SETTINGS)
	Settings.changed.connect(_on_setting_changed)
	apply_settings()
	holo = WristHolo.new()
	add_child(holo)
	HudSlots.register_holo_channel(TIME_CHANNEL, "Time of day", _time_channel, 900)
	HudSlots.register_holo_channel(KEYS_CHANNEL, "Key binds", func() -> Control: return KeyBindsPanel.new(), 910)


func unregister_module() -> void:
	HudSlots.unregister_holo_channel(TIME_CHANNEL)
	HudSlots.unregister_holo_channel(KEYS_CHANNEL)
	if holo:
		holo.close()
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


## The wrist screen's time of day: the same slider as Settings.
func _time_channel() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var label := BsxTheme.hud_label("", 28, BsxTheme.ACCENT)
	label.name = "Clock"
	box.add_child(label)
	var slider := HSlider.new()
	slider.name = "TimeOfDay"
	slider.min_value = 0.0
	slider.max_value = 24.0
	slider.step = 0.25
	slider.value = AlienSky.setting_hour()
	label.text = AlienSky.clock(slider.value)
	slider.value_changed.connect(func(h: float) -> void:
		label.text = AlienSky.clock(h)
		Settings.set_value(AlienSky.SECTION, AlienSky.KEY, h))
	box.add_child(slider)
	box.add_child(BsxTheme.muted("Moves the sun over the yard. Saved with your settings."))
	return box
