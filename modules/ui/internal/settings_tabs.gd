class_name SettingsTabs
extends VBoxContainer
## The settings in a game (Esc > Settings): a row of tabs, Graphics, Key binds, Sound and
## Gameplay, then one per Menu settings page (Character, modules' own), then Debug (flag
## ui.debug_tab), and the open tab's controls under it. Sound and Gameplay show their own controls, then the sections modules
## added (Menu.register_settings_section(Menu.SOUND / Menu.GAMEPLAY, ...)). Changes apply
## and save straight away.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const GRAPHICS := "graphics"
const KEYS := "keys"

var tabs: HBoxContainer
var body: MarginContainer
var current := ""


func _ready() -> void:
	name = "SettingsTabs"
	add_theme_constant_override("separation", 10)
	tabs = HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 6)
	add_child(tabs)
	add_child(T.HazardRule.new(6.0, false))
	body = MarginContainer.new()
	body.name = "TabBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	Menu.settings_pages_changed.connect(_fill_tabs)
	Menu.settings_sections_changed.connect(_on_sections_changed)
	open_tab(GRAPHICS)


func _exit_tree() -> void:
	if Menu.settings_pages_changed.is_connected(_fill_tabs):
		Menu.settings_pages_changed.disconnect(_fill_tabs)
	if Menu.settings_sections_changed.is_connected(_on_sections_changed):
		Menu.settings_sections_changed.disconnect(_on_sections_changed)
	Settings.save()


## Every tab, in order: [id, label].
func tab_list() -> Array:
	var out: Array = [[GRAPHICS, "Graphics"], [KEYS, "Key binds"], [Menu.SOUND, "Sound"], [Menu.GAMEPLAY, "Gameplay"]]
	for p: Dictionary in Menu.settings_pages():
		out.append([str(p.id), str(p.label)])
	if Flags.is_on("ui.debug_tab"):
		out.append([Menu.DEBUG, "Debug"])
	return out


func open_tab(id: String) -> void:
	current = id
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	var page: Control
	match id:
		GRAPHICS:
			page = _graphics()
		KEYS:
			var binds := KeyBindsPanel.new()
			binds.name = "KeyBindsPanel"
			binds.size_flags_vertical = Control.SIZE_EXPAND_FILL
			page = binds
		Menu.SOUND:
			page = _with_sections(_sound(), id)
		Menu.GAMEPLAY:
			page = _with_sections(_gameplay(), id)
		Menu.DEBUG:
			page = _with_sections(T.label("Testing shortcuts. They change this game's save.", "body", 18, T.DIM), id)
		_:
			var p := Menu.settings_page(id)
			var own: Variant = (p.factory as Callable).call() if not p.is_empty() and (p.factory as Callable).is_valid() else null
			page = _with_sections(own as Control, id)
	page.name = "Tab_" + id.validate_node_name()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(page)
	_fill_tabs()


func _fill_tabs() -> void:
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	for t: Array in tab_list():
		var id := str(t[0])
		var b := T.button(str(t[1]).to_upper(), false, 19, id == current)
		b.name = "Tab_" + id.validate_node_name()
		b.custom_minimum_size.x = 140
		# After the click: the pressed tab is rebuilt by open_tab.
		b.pressed.connect(func() -> void: open_tab.call_deferred(id))
		tabs.add_child(b)


func _on_sections_changed(page: String) -> void:
	if page == current:
		open_tab(current)


## The graphics screen without its own title and Back (the menu has them).
func _graphics() -> Control:
	var g := GraphicsPanel.new()
	g.ready.connect(func() -> void:
		g.custom_minimum_size = Vector2.ZERO
		g.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var box := g.get_child(0) as VBoxContainer
		box.get_child(0).visible = false  # GRAPHICS title
		for b in box.get_children():
			if b is Button and (b as Button).text == "Back":
				(b as Button).visible = false, CONNECT_ONE_SHOT)
	return g


func _sound() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.add_child(_slider("MasterVolume", "Master volume", "audio", "master", 0.0, 1.0, 0.05,
			func(v: float) -> String: return "%d%%" % roundi(v * 100.0)))
	col.add_child(_slider("EffectsVolume", "Effects (tools, footsteps, screens)", "audio", "effects", 0.0, 1.0, 0.05,
			func(v: float) -> String: return "%d%%" % roundi(v * 100.0)))
	return col


func _gameplay() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.add_child(_slider("TimeOfDay", "Time of day (moves the sun over the yard)", AlienSky.SECTION, AlienSky.KEY,
			0.0, 24.0, 0.25, func(h: float) -> String: return AlienSky.clock(h)))
	col.add_child(_choice("TerminalText", "Terminal text (screens and the wrist terminal)", T.TEXT_SECTION, T.TEXT_KEY,
			T.TEXT_SIZES.keys()))
	return col


## A labelled row of buttons, one per choice, bound to a setting.
func _choice(node_name: String, label: String, section: String, key: String, choices: Array) -> Control:
	var row := HBoxContainer.new()
	row.name = node_name + "Row"
	row.add_theme_constant_override("separation", 14)
	var l := T.label(label, "body_medium", 18, T.TEXT)
	l.custom_minimum_size.x = 380
	row.add_child(l)
	var buttons := HBoxContainer.new()
	buttons.name = node_name
	buttons.add_theme_constant_override("separation", 6)
	row.add_child(buttons)
	var fill := func(fill_again: Callable) -> void:
		for c in buttons.get_children():
			buttons.remove_child(c)
			c.queue_free()
		for choice: Variant in choices:
			var b := T.button(str(choice).to_upper(), false, 17, str(Settings.get_value(section, key)) == str(choice))
			b.name = str(choice)
			b.pressed.connect(func() -> void:
				Settings.set_value(section, key, str(choice))
				fill_again.call.call_deferred(fill_again))
			buttons.add_child(b)
	fill.call(fill)
	return row


## A labelled slider bound to a setting, with its value shown on the right.
func _slider(node_name: String, label: String, section: String, key: String, lo: float, hi: float,
		step: float, show: Callable) -> Control:
	var row := HBoxContainer.new()
	row.name = node_name + "Row"
	row.add_theme_constant_override("separation", 14)
	var l := T.label(label, "body_medium", 18, T.TEXT)
	l.custom_minimum_size.x = 380
	row.add_child(l)
	var s := HSlider.new()
	s.name = node_name
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v: Variant = Settings.get_value(section, key)
	s.value = float(v) if v != null else hi
	row.add_child(s)
	var shown := T.label(str(show.call(s.value)), "mono_bold", 18, T.ORANGE)
	shown.custom_minimum_size.x = 90
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(shown)
	s.value_changed.connect(func(x: float) -> void:
		shown.text = str(show.call(x))
		Settings.set_value(section, key, x))
	return row


## `own` (may be null), then the sections modules added to `page`, in a scroll.
func _with_sections(own: Control, page: String) -> Control:
	var col := VBoxContainer.new()
	col.name = "Page"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 18)
	if own:
		own.name = "PageControls"
		col.add_child(own)
	for sec: Dictionary in Menu.settings_sections(page):
		var part := VBoxContainer.new()
		part.name = "Section_" + str(sec.id).validate_node_name()
		part.add_theme_constant_override("separation", 6)
		part.add_child(T.label(str(sec.label).to_upper(), "display_bold", 18, T.ORANGE))
		var made: Variant = (sec.factory as Callable).call()
		if made is Control:
			part.add_child(made)
		col.add_child(part)
	if col.get_child_count() == 0:
		col.add_child(T.label("Nothing to set here yet.", "body", 18, T.DIM))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(col)
	return scroll
