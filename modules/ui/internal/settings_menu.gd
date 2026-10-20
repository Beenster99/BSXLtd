extends Control
## Settings: sound, the time of day in the yard, key binds and the like, laid out like the main menu.
## Graphics have their own screen (GraphicsPanel). Modules' own settings sections get
## controls here as they need them.

func _ready() -> void:
	theme = BsxTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BsxTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := BsxTheme.title("SETTINGS", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_spacer(12))

	box.add_child(BsxTheme.muted("Master volume"))
	var volume := HSlider.new()
	volume.name = "MasterVolume"
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = Settings.get_value("audio", "master")
	volume.value_changed.connect(func(v): Settings.set_value("audio", "master", v))
	box.add_child(volume)

	var time_label := BsxTheme.muted("")
	time_label.name = "TimeOfDayLabel"
	box.add_child(time_label)
	var time := HSlider.new()
	time.name = "TimeOfDay"
	time.min_value = 0.0
	time.max_value = 24.0
	time.step = 0.25
	time.value = AlienSky.setting_hour()
	var show_time := func(h: float) -> void:
		time_label.text = "Time of day   %s" % AlienSky.clock(h)
	show_time.call(time.value)
	time.value_changed.connect(func(h: float) -> void:
		show_time.call(h)
		Settings.set_value(AlienSky.SECTION, AlienSky.KEY, h))
	box.add_child(time)
	box.add_child(_spacer(12))
	var keys := BsxTheme.button("Key binds", _open_keys)
	keys.name = "KeyBinds"
	box.add_child(keys)
	box.add_child(BsxTheme.button("Back", _back))
	_center = center


var _center: CenterContainer


## Every key the game uses, over the settings (they hide until it's closed).
func _open_keys() -> void:
	_center.visible = false
	var panel := PanelContainer.new()
	panel.name = "KeyBindsOverlay"
	panel.add_theme_stylebox_override("panel", BsxTheme.panel_style(20))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(660, 760)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := BsxTheme.title("KEY BINDS", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(BsxTheme.muted("Click a key, then press the new one. Esc cancels."))
	var binds := KeyBindsPanel.new()
	binds.name = "KeyBindsPanel"
	binds.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(binds)
	var back := BsxTheme.button("Done", func() -> void:
		panel.queue_free()
		_center.visible = true)
	back.name = "Done"
	box.add_child(back)
	add_child(panel)


func _back() -> void:
	Settings.save()
	Router.goto(UiBus.MAIN_MENU)


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c
