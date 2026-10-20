extends Control
## Settings: sound, the time of day in the yard and the like, laid out like the main menu.
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
	box.add_child(BsxTheme.button("Back", _back))


func _back() -> void:
	Settings.save()
	Router.goto(UiBus.MAIN_MENU)


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c
