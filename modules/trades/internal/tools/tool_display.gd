class_name TradesToolDisplay
extends Node3D
## The display set into a tool (beenster, 0.3.6: "the information about the tool I am holding
## should be integrated on the tool itself like a display"): a small screen in the yard's TV
## look (TerminalKit: gunmetal, BSX orange, Barlow and JetBrains Mono) that the tool draws its
## name, its labelled readings, a fill bar, a status light and what it's doing on. It is a
## SubViewport shown on a quad, so the text stays sharp at arm's length; it only redraws
## while its tool is out.

## Pixels across the screen's picture; its height follows the glass's shape.
const WIDTH_PX := 360
## How bright the glass glows: a touch over 1 so it reads in daylight (the tone mapping dims it).
const GLOW := 1.5

var _viewport: SubViewport
var _title: Label
var _rows: VBoxContainer
var _bar_track: ColorRect
var _bar: ColorRect
var _led: ColorRect
var _state: Label
var _accent := TerminalKit.ORANGE
var _text_cache := ""


## A screen of `size` metres (the glass), facing +Z, its text the way +Y points.
func build(size: Vector2, accent := TerminalKit.ORANGE) -> void:
	_accent = accent
	_viewport = SubViewport.new()
	_viewport.name = "Picture"
	_viewport.size = Vector2i(WIDTH_PX, roundi(WIDTH_PX * size.y / size.x))
	_viewport.transparent_bg = false
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(_viewport)
	_build_picture()

	var quad := MeshInstance3D.new()
	quad.name = "Glass"
	var mesh := QuadMesh.new()
	mesh.size = size
	quad.mesh = mesh
	var mat := StandardMaterial3D.new()
	# Black glass with a little sheen; the picture is its glow.
	mat.albedo_color = Color.BLACK
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission_texture = _viewport.get_texture()
	mat.emission_energy_multiplier = GLOW
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.position.z = 0.0006
	add_child(quad)


## Draws the tool's state: `title` across the top, `rows` ([[label, value], ...]), the bar
## (`fill` 0..1, below 0 hides it), the light lit while `alert`, and `state` along the foot.
func show_state(title: String, rows: Array, state: String, fill: float, alert: bool) -> void:
	if _title == null:
		return
	_title.text = title.to_upper()
	while _rows.get_child_count() < rows.size():
		_rows.add_child(_row())
	for i in _rows.get_child_count():
		var line := _rows.get_child(i) as HBoxContainer
		line.visible = i < rows.size()
		if line.visible:
			(line.get_child(0) as Label).text = str(rows[i][0])
			(line.get_child(1) as Label).text = str(rows[i][1])
	_bar_track.visible = fill >= 0.0
	_bar.anchor_right = clampf(fill, 0.0, 1.0)
	_led.color = _accent.lightened(0.2) if alert else Color(TerminalKit.PLATE_HI, 1.0)
	_state.text = state
	_state.add_theme_color_override("font_color", _accent if alert else TerminalKit.GOOD if state == "READY" else TerminalKit.TEXT)
	var lines := PackedStringArray([_title.text])
	for r: Array in rows:
		lines.append("%s %s" % [r[0], r[1]])
	lines.append(state)
	_text_cache = "\n".join(lines)


## Everything on the screen as text (for tests).
func text() -> String:
	return _text_cache


func _build_picture() -> void:
	var w := float(_viewport.size.x)
	var h := float(_viewport.size.y)
	var root := PanelContainer.new()
	root.size = Vector2(w, h)
	root.add_theme_stylebox_override("panel", TerminalKit.box(TerminalKit.KIOSK, TerminalKit.EDGE, 4, 0.0))
	_viewport.add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	root.add_child(col)

	# Header: the tool's name in Barlow Condensed on a gunmetal plate, the status light at its
	# right, an orange rule under it.
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", TerminalKit.box(TerminalKit.PLATE, Color.TRANSPARENT, 0, 0.0))
	col.add_child(head)
	var head_row := MarginContainer.new()
	for side: String in ["left", "right"]:
		head_row.add_theme_constant_override("margin_" + side, 16)
	head_row.add_theme_constant_override("margin_top", 4)
	head_row.add_theme_constant_override("margin_bottom", 2)
	head.add_child(head_row)
	var head_box := HBoxContainer.new()
	head_row.add_child(head_box)
	_title = TerminalKit.label("", "display_bold", 46, TerminalKit.TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	head_box.add_child(_title)
	_led = ColorRect.new()
	_led.custom_minimum_size = Vector2(26, 26)
	_led.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_box.add_child(_led)
	var rule := ColorRect.new()
	rule.color = _accent
	rule.custom_minimum_size.y = 5
	col.add_child(rule)

	# The readings, label left in grey, value right in white.
	var body := MarginContainer.new()
	for side: String in ["left", "right"]:
		body.add_theme_constant_override("margin_" + side, 16)
	body.add_theme_constant_override("margin_top", 6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 0)
	body.add_child(_rows)

	# The bar and what the tool is doing.
	var foot := MarginContainer.new()
	for side: String in ["left", "right"]:
		foot.add_theme_constant_override("margin_" + side, 16)
	foot.add_theme_constant_override("margin_bottom", 8)
	col.add_child(foot)
	var foot_col := VBoxContainer.new()
	foot_col.add_theme_constant_override("separation", 4)
	foot.add_child(foot_col)
	_bar_track = ColorRect.new()
	_bar_track.color = TerminalKit.PLATE_HI
	_bar_track.custom_minimum_size.y = 12
	foot_col.add_child(_bar_track)
	_bar = ColorRect.new()
	_bar.color = _accent
	_bar.anchor_bottom = 1.0
	_bar.anchor_right = 0.0
	_bar_track.add_child(_bar)
	_state = TerminalKit.label("", "display_bold", 40, TerminalKit.TEXT)
	foot_col.add_child(_state)


func _row() -> HBoxContainer:
	var line := HBoxContainer.new()
	var name_label := TerminalKit.label("", "mono_bold", 28, TerminalKit.STEEL)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	line.add_child(TerminalKit.label("", "mono_bold", 44, TerminalKit.TEXT))
	return line
