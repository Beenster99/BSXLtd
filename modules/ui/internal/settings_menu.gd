extends Control
## Settings: the base video and audio options. Modules' own settings sections get controls
## here as they need them.

func _ready() -> void:
	theme = BsxTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BsxTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 120)
	add_child(column)
	column.add_child(BsxTheme.title("Settings", 44))

	var fullscreen := CheckButton.new()
	fullscreen.name = "Fullscreen"
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = Settings.get_value("video", "fullscreen")
	fullscreen.toggled.connect(func(on): Settings.set_value("video", "fullscreen", on))
	column.add_child(fullscreen)

	var volume_row := HBoxContainer.new()
	volume_row.add_child(BsxTheme.muted("Master volume"))
	var volume := HSlider.new()
	volume.name = "MasterVolume"
	volume.custom_minimum_size.x = 260
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = Settings.get_value("audio", "master")
	volume.value_changed.connect(func(v): Settings.set_value("audio", "master", v))
	volume_row.add_child(volume)
	column.add_child(volume_row)

	column.add_child(BsxTheme.button("Back", _back))


func _back() -> void:
	Settings.save()
	Router.goto(UiBus.MAIN_MENU)
