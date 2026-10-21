extends Control
## Settings: sound, the time of day in the yard, key binds and the like, laid out like the main menu.
## Graphics have their own screen (GraphicsPanel). Pages registered with
## Menu.register_settings_page (UI's Character, modules' own) each get a button that opens
## the page over the menu: the page's controls, then the sections modules added to it.

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
	_pages = VBoxContainer.new()
	_pages.name = "Pages"
	_pages.add_theme_constant_override("separation", 14)
	box.add_child(_pages)
	_fill_pages()
	Menu.settings_pages_changed.connect(_fill_pages)
	var keys := BsxTheme.button("Key binds", _open_keys)
	keys.name = "KeyBinds"
	box.add_child(keys)
	box.add_child(BsxTheme.button("Back", _back))
	_center = center


var _center: CenterContainer
var _pages: VBoxContainer


func _exit_tree() -> void:
	if Menu.settings_pages_changed.is_connected(_fill_pages):
		Menu.settings_pages_changed.disconnect(_fill_pages)


## One button per registered page.
func _fill_pages() -> void:
	if _pages == null:
		return
	for c in _pages.get_children():
		_pages.remove_child(c)
		c.queue_free()
	for p: Dictionary in Menu.settings_pages():
		var b := BsxTheme.button(str(p.label), open_page.bind(str(p.id)))
		b.name = "Page_" + str(p.id).validate_node_name()
		_pages.add_child(b)


## Opens a registered page over the menu: its own controls, then its sections.
func open_page(id: String) -> void:
	var page := Menu.settings_page(id)
	if page.is_empty():
		return
	var body := VBoxContainer.new()
	body.name = "PageBody"
	body.add_theme_constant_override("separation", 14)
	var fill := func() -> void:
		for c in body.get_children():
			body.remove_child(c)
			c.queue_free()
		var f: Callable = page.factory
		if f.is_valid():
			var own: Variant = f.call()
			if own is Control:
				(own as Control).name = "PageControls"
				body.add_child(own)
		for sec: Dictionary in Menu.settings_sections(id):
			var part := VBoxContainer.new()
			part.name = "Section_" + str(sec.id).validate_node_name()
			part.add_theme_constant_override("separation", 6)
			var head := BsxTheme.muted(str(sec.label).to_upper())
			head.add_theme_color_override("font_color", Color(BsxTheme.ACCENT, 0.85))
			part.add_child(head)
			var made: Variant = (sec.factory as Callable).call()
			if made is Control:
				part.add_child(made)
			body.add_child(part)
	fill.call()
	var on_change := func(changed: String) -> void:
		if changed == id and is_instance_valid(body):
			fill.call()
	Menu.settings_sections_changed.connect(on_change)
	body.tree_exiting.connect(func() -> void:
		if Menu.settings_sections_changed.is_connected(on_change):
			Menu.settings_sections_changed.disconnect(on_change))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	_overlay("Page_%s_Overlay" % id.validate_node_name(), str(page.label).to_upper(), "", scroll)


## Every key the game uses, over the settings (they hide until it's closed).
func _open_keys() -> void:
	var binds := KeyBindsPanel.new()
	binds.name = "KeyBindsPanel"
	binds.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overlay("KeyBindsOverlay", "KEY BINDS", "Click a key, then press the new one. Esc cancels.", binds)


## A panel over the settings with a title, an optional note, `content` and Done.
func _overlay(node_name: String, heading: String, note: String, content: Control) -> void:
	_center.visible = false
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", BsxTheme.panel_style(20))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(660, 760)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := BsxTheme.title(heading, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	if note != "":
		box.add_child(BsxTheme.muted(note))
	box.add_child(content)
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
