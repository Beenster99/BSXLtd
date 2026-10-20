class_name WristHolo
extends CanvasLayer
## The wrist screen, like Star Citizen's mobiGlas: press the holo key (Keys.HOLO, F1 by
## default) anywhere in a game and your wrist projects a semi-transparent screen in front of
## your face. Its rail lists Home and every channel modules registered with
## HudSlots.register_holo_channel; click one to bring it up. A channel's Control that has a
## close_requested signal puts the screen away when it fires. The holo key, Esc or a click
## outside the screen puts it away. The UI bus owns one for the whole game.

const SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform vec4 tint : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform float strength = 1.0;
void fragment() {
	vec2 uv = UV;
	float scan = 0.5 + 0.5 * sin(uv.y * 720.0 + TIME * 6.0);
	float band = smoothstep(0.0, 0.04, fract(uv.y * 0.6 - TIME * 0.15)) * (1.0 - smoothstep(0.04, 0.1, fract(uv.y * 0.6 - TIME * 0.15)));
	float edge = max(smoothstep(0.012, 0.0, min(uv.x, 1.0 - uv.x)), smoothstep(0.02, 0.0, min(uv.y, 1.0 - uv.y)));
	float flicker = 0.92 + 0.08 * sin(TIME * 53.0) * sin(TIME * 7.3);
	float a = (scan * 0.035 + band * 0.05 + edge * 0.35) * flicker * strength;
	COLOR = vec4(tint.rgb * a, 1.0);
}
"""
## Where the screen sits: its size as a share of the window, and how far it leans.
const SCREEN_SHARE := Vector2(0.7, 0.72)
const TILT_DEG := -1.2
const HOLO_FILL := Color(0.03, 0.12, 0.17, 0.62)

var is_open := false
var channel := ""
var root: Control
var pane: PanelContainer
var content: Control
var rail: VBoxContainer
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _content_node: Control
var _tween: Tween


func _ready() -> void:
	name = "WristHolo"
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	HudSlots.holo_requested.connect(open)
	HudSlots.holo_channels_changed.connect(_on_channels_changed)


## True where the holo may come up: in a game, not on the menus.
func allowed() -> bool:
	var id := str(Router.current_id)
	return not id in ["main_menu", "settings", "boot"] and get_tree() != null


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


## Brings the screen up on `channel_id` ("" = Home). Already up: switches channel.
func open(channel_id: String = "") -> void:
	if is_open:
		show_channel(channel_id)
		return
	is_open = true
	_build()
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("holo_open", null, -6.0)
	show_channel(channel_id, false)
	# Unfolds up out of the wrist.
	pane.pivot_offset = Vector2(0, pane.size.y)
	pane.scale = Vector2(0.2, 0.05)
	pane.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(pane, "scale", Vector2.ONE, 0.22)
	_tween.tween_property(pane, "modulate:a", 1.0, 0.18)


func close() -> void:
	if not is_open:
		return
	is_open = false
	Sfx.play("holo_close", null, -8.0)
	if root:
		root.queue_free()
	root = null
	pane = null
	content = null
	_content_node = null
	channel = ""
	Input.mouse_mode = _mouse_before


## Puts a channel on the screen ("" = Home, the channel tiles).
func show_channel(channel_id: String, sound: bool = true) -> void:
	if not is_open:
		open(channel_id)
		return
	if channel_id != "" and HudSlots.holo_channel(channel_id).is_empty():
		channel_id = ""
	channel = channel_id
	if _content_node:
		content.remove_child(_content_node)  # now, so the new screen can take the name
		_content_node.queue_free()
		_content_node = null
	if channel_id == "":
		_content_node = _home()
	else:
		var made: Variant = HudSlots.holo_channel(channel_id).factory.call()
		_content_node = made as Control
		if _content_node == null:
			_content_node = BsxTheme.muted("This channel has nothing to show.")
		elif _content_node.has_signal("close_requested"):
			_content_node.connect("close_requested", close)
	_content_node.name = "Channel"
	_content_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(_content_node)
	_mark_rail()
	if sound:
		Sfx.play("holo_switch", null, -10.0)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.is_echo():
		return
	if event.is_action_pressed(Keys.HOLO) and (is_open or allowed()):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed(Keys.CANCEL):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	root = Control.new()
	root.name = "Holo"
	root.theme = BsxTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(root)
	var view := root.get_viewport_rect().size if root.is_inside_tree() else Vector2(1280, 720)
	if view.x <= 0.0:
		view = Vector2(1280, 720)

	var wrist := WristArm.new()
	wrist.name = "Wrist"
	wrist.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wrist)

	pane = PanelContainer.new()
	pane.name = "Pane"
	var size := (view * SCREEN_SHARE).max(Vector2(760, 480))
	pane.size = size
	pane.position = Vector2((view.x - size.x) * 0.5 + view.x * 0.03, (view.y - size.y) * 0.42)
	pane.rotation = deg_to_rad(TILT_DEG)
	var style := StyleBoxFlat.new()
	style.bg_color = HOLO_FILL
	style.border_color = Color(BsxTheme.ACCENT, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	style.shadow_color = Color(BsxTheme.ACCENT, 0.18)
	style.shadow_size = 18
	pane.add_theme_stylebox_override("panel", style)
	root.add_child(pane)
	wrist.target = pane

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pane.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	box.add_child(head)
	var title := BsxTheme.hud_label("BSX  //  WRIST", 20, BsxTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var game := BsxTheme.hud_label(Saves.current_name, 16, BsxTheme.HUD_DIM)
	game.name = "GameName"
	head.add_child(game)
	var clock := BsxTheme.hud_label(AlienSky.clock(AlienSky.setting_hour()), 18, BsxTheme.HUD)
	clock.name = "Clock"
	head.add_child(clock)
	var x := _holo_button("X", close)
	x.name = "Close"
	x.custom_minimum_size = Vector2(40, 32)
	head.add_child(x)
	var rule := ColorRect.new()
	rule.color = Color(BsxTheme.ACCENT, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	box.add_child(rule)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	box.add_child(body)
	rail = VBoxContainer.new()
	rail.name = "Rail"
	rail.custom_minimum_size = Vector2(190, 0)
	rail.add_theme_constant_override("separation", 6)
	body.add_child(rail)
	content = Control.new()
	content.name = "Content"
	content.clip_contents = true
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(content)
	_fill_rail()

	var glow := ColorRect.new()
	glow.name = "Scan"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	mat.shader = shader
	glow.material = mat
	pane.add_child(glow)


func _fill_rail() -> void:
	if rail == null:
		return
	for child in rail.get_children():
		rail.remove_child(child)
		child.queue_free()
	var home := _holo_button("Home", func() -> void: show_channel(""))
	home.name = "Home"
	rail.add_child(home)
	for c: Dictionary in HudSlots.holo_channels():
		var b := _holo_button(c.label, func() -> void: show_channel(c.id))
		b.name = "Ch_" + str(c.id).validate_node_name()
		b.set_meta("channel", c.id)
		rail.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail.add_child(spacer)
	rail.add_child(BsxTheme.hud_label("%s  close" % Keys.prompt(Keys.HOLO), 14, BsxTheme.MUTED))


func _mark_rail() -> void:
	if rail == null:
		return
	for b in rail.get_children():
		if b is Button:
			var on: bool = str(b.get_meta("channel", "")) == channel
			b.add_theme_color_override("font_color", BsxTheme.LIVE if on else BsxTheme.HUD)


func _home() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(BsxTheme.hud_label("CHANNELS", 16, BsxTheme.HUD_DIM))
	var grid := GridContainer.new()
	grid.name = "Tiles"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	var channels := HudSlots.holo_channels()
	for c: Dictionary in channels:
		var tile := _holo_button(c.label, func() -> void: show_channel(c.id))
		tile.name = "Tile_" + str(c.id).validate_node_name()
		tile.custom_minimum_size = Vector2(200, 84)
		grid.add_child(tile)
	if channels.is_empty():
		box.add_child(BsxTheme.muted("No channels yet."))
	return box


func _holo_button(text: String, on_pressed: Callable) -> Button:
	var b := BsxTheme.button(text, on_pressed)
	b.custom_minimum_size = Vector2(0, 38)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(BsxTheme.ACCENT, 0.16 if state == "hover" else (0.24 if state == "pressed" else 0.06))
		s.border_color = Color(BsxTheme.ACCENT, 0.5 if state == "hover" else 0.25)
		s.set_border_width_all(1)
		s.set_corner_radius_all(4)
		s.set_content_margin_all(8)
		b.add_theme_stylebox_override(state, s)
	b.add_theme_color_override("font_color", BsxTheme.HUD)
	return b


func _on_channels_changed() -> void:
	if is_open:
		_fill_rail()
		if channel != "" and HudSlots.holo_channel(channel).is_empty():
			show_channel("", false)
		else:
			_mark_rail()


## The forearm and gauntlet at the bottom left, with the emitter's light fanning up to the
## screen's lower corners.
class WristArm extends Control:
	var target: Control

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var s := size
		var cuff := Vector2(s.x * 0.16, s.y * 0.93)
		var arm := PackedVector2Array([Vector2(-20, s.y + 20), Vector2(s.x * 0.05, s.y * 0.86),
				Vector2(s.x * 0.2, s.y * 0.88), Vector2(s.x * 0.26, s.y + 20)])
		draw_colored_polygon(arm, Color(0.09, 0.1, 0.12, 0.96))
		var plate := PackedVector2Array([Vector2(s.x * 0.08, s.y * 0.885), Vector2(s.x * 0.2, s.y * 0.9),
				Vector2(s.x * 0.215, s.y * 0.97), Vector2(s.x * 0.075, s.y * 0.955)])
		draw_colored_polygon(plate, Color(0.2, 0.22, 0.25, 1.0))
		draw_polyline(plate + PackedVector2Array([plate[0]]), Color(1.0, 0.55, 0.16, 0.9), 2.0)
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
		draw_circle(cuff, 9.0, Color(BsxTheme.ACCENT, 0.9 * pulse))
		draw_circle(cuff, 20.0, Color(BsxTheme.ACCENT, 0.18 * pulse))
		if target and is_instance_valid(target):
			var t := target.get_global_transform()
			var bl := t * Vector2(0, target.size.y)
			var br := t * Vector2(target.size.x * 0.45, target.size.y)
			draw_colored_polygon(PackedVector2Array([cuff, bl, br]), Color(BsxTheme.ACCENT, 0.07))
			draw_line(cuff, bl, Color(BsxTheme.ACCENT, 0.25), 1.5)
			draw_line(cuff, br, Color(BsxTheme.ACCENT, 0.15), 1.5)
