class_name GraphicsPanel
extends PanelContainer
## The graphics settings screen (main menu > Graphics, or Esc > Graphics): a quality preset
## at the top, then Display, Quality and Lighting tabs built from GraphicsOptions.OPTIONS.
## Every change applies straight away and is saved; the graphics API switch needs a restart.

signal closed

const ACCENT := Color(0.62, 0.9, 1.0)

var _controls: Dictionary = {}       # key -> Control
var _value_labels: Dictionary = {}   # slider key -> Label
var _preset: OptionButton
var _help: Label
var _restart_note: Label
var _refreshing := false


func _ready() -> void:
	GraphicsOptions.load_settings()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(780, 640)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.07, 0.96)
	style.border_color = Color(ACCENT, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title := Label.new()
	title.text = "GRAPHICS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)
	# Preset row.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var pl := Label.new()
	pl.text = "Quality preset"
	pl.custom_minimum_size = Vector2(220, 0)
	row.add_child(pl)
	_preset = OptionButton.new()
	for p in GraphicsOptions.PRESETS:
		_preset.add_item(p)
	_preset.add_item(GraphicsOptions.CUSTOM)
	_preset.set_item_disabled(GraphicsOptions.PRESETS.size(), true)
	_preset.custom_minimum_size = Vector2(240, 32)
	_preset.item_selected.connect(_on_preset)
	row.add_child(_preset)
	var reset := Button.new()
	reset.text = "Reset all"
	reset.pressed.connect(func() -> void:
		GraphicsOptions.reset_defaults()
		_changed(""))
	row.add_child(reset)
	# Tabs.
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	var grids: Dictionary = {}
	for tab: String in ["Display", "Quality", "Lighting"]:
		var scroll := ScrollContainer.new()
		scroll.name = tab
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(scroll)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)
		grids[tab] = grid
	for o: Dictionary in GraphicsOptions.OPTIONS:
		_add_option(grids[o["tab"]], o)
	# Help line and buttons.
	_help = Label.new()
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.custom_minimum_size = Vector2(0, 54)
	_help.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	box.add_child(_help)
	_restart_note = Label.new()
	_restart_note.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	box.add_child(_restart_note)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(200, 38)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	box.add_child(back)
	_refresh()


func _add_option(grid: GridContainer, o: Dictionary) -> void:
	var key: String = o["key"]
	var label := Label.new()
	label.text = o["label"]
	label.custom_minimum_size = Vector2(230, 0)
	grid.add_child(label)
	var ctl: Control
	match o["kind"]:
		GraphicsOptions.Kind.CHOICE:
			var ob := OptionButton.new()
			for c: String in o["choices"]:
				ob.add_item(c)
			ob.item_selected.connect(func(i: int) -> void: _set_option(key, i))
			ctl = ob
		GraphicsOptions.Kind.SLIDER:
			var s := HSlider.new()
			s.min_value = o["min"]
			s.max_value = o["max"]
			s.step = o["step"]
			s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			s.value_changed.connect(func(v: float) -> void: _set_option(key, v))
			ctl = s
		GraphicsOptions.Kind.TOGGLE:
			var t := CheckButton.new()
			t.toggled.connect(func(on: bool) -> void: _set_option(key, on))
			ctl = t
	ctl.custom_minimum_size = Vector2(300, 30)
	ctl.tooltip_text = o["help"]
	var show_help := func() -> void: _help.text = "%s: %s" % [o["label"], o["help"]] if o["help"] != "" else ""
	ctl.mouse_entered.connect(show_help)
	ctl.focus_entered.connect(show_help)
	grid.add_child(ctl)
	var value := Label.new()
	value.custom_minimum_size = Vector2(90, 0)
	grid.add_child(value)
	_controls[key] = ctl
	if o["kind"] == GraphicsOptions.Kind.SLIDER:
		_value_labels[key] = value
	if key == "hdr" and not _hdr_supported():
		(ctl as CheckButton).disabled = true
		value.text = "not available"
	if key == "renderer" and not GraphicsOptions.can_switch_renderer():
		(ctl as OptionButton).disabled = true
		value.text = "Windows only"


static func _hdr_supported() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_HDR_OUTPUT) and DisplayServer.window_is_hdr_output_supported()


func _set_option(key: String, v: Variant) -> void:
	if _refreshing:
		return
	GraphicsOptions.set_value(key, v)
	if key == "renderer" and GraphicsOptions.can_switch_renderer():
		GraphicsOptions.write_renderer(int(v))
	_changed(key)


func _on_preset(i: int) -> void:
	if _refreshing or i >= GraphicsOptions.PRESETS.size():
		return
	GraphicsOptions.apply_preset(GraphicsOptions.PRESETS[i])
	_changed("")


func _changed(_key: String) -> void:
	GraphicsOptions.save_settings()
	var g := get_node_or_null("/root/Graphics")
	if g:
		g.call("apply_all")
	_refresh()


## Puts every control back in step with the settings (after a preset or reset).
func _refresh() -> void:
	_refreshing = true
	for key: String in _controls:
		var ctl: Control = _controls[key]
		var v: Variant = GraphicsOptions.get_value(key)
		if ctl is OptionButton:
			(ctl as OptionButton).select(int(v))
		elif ctl is HSlider:
			(ctl as HSlider).value = float(v)
		elif ctl is CheckButton:
			(ctl as CheckButton).button_pressed = bool(v)
		if _value_labels.has(key):
			var o := GraphicsOptions.option(key)
			var f := "%.0f" if float(o["step"]) >= 1.0 else ("%.2f" if float(o["step"]) < 0.1 else "%.1f")
			(_value_labels[key] as Label).text = (f % float(v)) + String(o["unit"])
	var pi := GraphicsOptions.PRESETS.find(GraphicsOptions.preset)
	_preset.select(pi if pi >= 0 else GraphicsOptions.PRESETS.size())
	var running := GraphicsOptions.current_renderer()
	if GraphicsOptions.can_switch_renderer() and int(GraphicsOptions.get_value("renderer")) != running:
		_restart_note.text = "Restart the game to switch to %s (running %s now)." % [
				["Vulkan", "DirectX 12"][int(GraphicsOptions.get_value("renderer"))], ["Vulkan", "DirectX 12"][running]]
	else:
		_restart_note.text = ""
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		_restart_note.text += ("\n" if _restart_note.text != "" else "") + \
				"Your PC is running the simple OpenGL renderer (Vulkan/DirectX 12 didn't start): global illumination, volumetrics and FSR are unavailable."
	_refreshing = false
