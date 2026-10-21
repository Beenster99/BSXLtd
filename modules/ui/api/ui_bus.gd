class_name UiBus
extends Node
## The UI module's bus (Modules.bus("ui")). Registers the menus with Router and the audio
## setting (window and graphics options belong to the Graphics autoload), and applies it
## when it changes.

signal notice_posted(text: String)

const MAIN_MENU := "main_menu"
const SETTINGS := "settings"

## The wrist screen (Keys.HOLO in any game scene).
var holo: WristHolo
## The see-through info cards on the right (HudSlots.set_info).
var info: InfoPanel
## Esc in a game (Menu.open_pause).
var pause: PauseMenu
## The "what you're looking at" card (HudSlots look hints).
var look: LookHints


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
	info = InfoPanel.new()
	add_child(info)
	pause = PauseMenu.new()
	add_child(pause)
	look = LookHints.new()
	add_child(look)
	Menu.register_settings_page(Menu.CHARACTER, "Character", _character_page, 10)


func unregister_module() -> void:
	Menu.unregister_settings_page(Menu.CHARACTER)
	if holo:
		holo.close()
	if pause:
		pause.close()
	if Settings.changed.is_connected(_on_setting_changed):
		Settings.changed.disconnect(_on_setting_changed)


## The top of Settings > Character, over the sections modules add (level, payslips...).
func _character_page() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var game := Saves.current_name if Saves.current_name != "" else "No game loaded"
	col.add_child(BsxTheme.muted("Your profile in %s." % game))
	if Menu.settings_sections(Menu.CHARACTER).is_empty():
		col.add_child(BsxTheme.muted("Nothing else to show yet."))
	return col


## Shows a short message in the HUD's notices slot.
func post_notice(text: String) -> void:
	notice_posted.emit(text)


func apply_settings() -> void:
	var master: float = Settings.get_value("audio", "master")
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))


func _on_setting_changed(_section: String, _key: String, _value: Variant) -> void:
	apply_settings()


## The in-game settings (the pause menu's Settings): the time of day on the left, key binds
## on the right, on the terminal's plates (see-through on glass).
func settings_panel(glass: bool) -> Control:
	var T := TerminalKit
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var left := T.docket("Time of day", "SKY", glass)
	var lp: PanelContainer = left.panel
	lp.size_flags_stretch_ratio = 0.8
	row.add_child(lp)
	var body: VBoxContainer = left.body
	var label := T.label("", "mono_bold", 44, T.ORANGE)
	label.name = "Clock"
	body.add_child(label)
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
	body.add_child(slider)
	body.add_child(T.label("Moves the sun over the yard.", "body", 17, T.DIM))
	var right := T.docket("Key binds", "KEYS", glass)
	var rp: PanelContainer = right.panel
	rp.size_flags_stretch_ratio = 1.2
	row.add_child(rp)
	var binds := KeyBindsPanel.new()
	binds.name = "KeyBindsPanel"
	binds.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(right.body as VBoxContainer).add_child(binds)
	(right.body as VBoxContainer).size_flags_vertical = Control.SIZE_EXPAND_FILL
	return row
