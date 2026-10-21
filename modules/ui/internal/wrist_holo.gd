class_name WristHolo
extends CanvasLayer
## The wrist screen, like Star Citizen's mobiGlas: press the holo key (Keys.HOLO, F1 by
## default) anywhere in a game and your wrist projects the yard terminal in front of your
## face, see-through: the BSX header, the hazard rule, a numbered tab for every channel
## modules registered with HudSlots.register_holo_channel (Orders, Stock, Contracts,
## Machines...), CLOSE, and the channel's screen under them. The holo key, Esc, CLOSE or a
## click outside the screen puts it away. A channel's Control with a close_requested signal
## puts it away too. The UI bus owns one for the whole game.
## It flickers on out of the wrist as a line of light that opens into the screen, and folds
## back to a line and a spark when put away. Everything pressed or typed on it ticks
## (Sfx.press). The footer's small print is the terminal's OS, the build, the date and time.

const SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform vec4 tint : source_color = vec4(0.55, 0.8, 0.95, 1.0);
uniform float strength = 1.0;
uniform float flash = 0.0;     // 0..1: the whole pane lit up (appearing, vanishing)
uniform float sweep = -1.0;    // 0..1: a bright line running down the pane (< 0 = none)
uniform float glitch = 0.0;    // 0..1: torn scan lines
float hash(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float scan = 0.5 + 0.5 * sin(uv.y * 720.0 + TIME * 6.0);
	float band = smoothstep(0.0, 0.04, fract(uv.y * 0.6 - TIME * 0.15)) * (1.0 - smoothstep(0.04, 0.1, fract(uv.y * 0.6 - TIME * 0.15)));
	float edge = max(smoothstep(0.008, 0.0, min(uv.x, 1.0 - uv.x)), smoothstep(0.014, 0.0, min(uv.y, 1.0 - uv.y)));
	float flicker = 0.92 + 0.08 * sin(TIME * 53.0) * sin(TIME * 7.3);
	float sw = sweep >= 0.0 ? exp(-pow((uv.y - sweep) * 38.0, 2.0)) : 0.0;
	float tear = step(1.0 - glitch * 0.12, hash(floor(uv.y * 90.0) + floor(TIME * 40.0) * 13.0));
	float a = (scan * 0.025 + band * 0.035 + edge * (0.3 + flash)) * flicker * strength;
	a += flash * 0.16 + sw * 0.55 + tear * glitch * 0.35;
	COLOR = vec4(tint.rgb * a, 1.0);
}
"""
## Where the screen sits: its size as a share of the window, and how far it leans.
const SCREEN_SHARE := Vector2(0.84, 0.8)
const TILT_DEG := -1.0
const T := preload("res://modules/ui/api/terminal_kit.gd")
## The terminal's operating system, for the footer's small print.
const OS_NAME := "BSX-OS"
const OS_VERSION := "4.2.1"
const UNIT := "WRIST UNIT WT-7"
## Seconds the screen takes to come up and to go away.
const APPEAR_TIME := 0.5
const VANISH_TIME := 0.28

var is_open := false
var channel := ""
var root: Control
var pane: PanelContainer
var content: MarginContainer
var tabs: HBoxContainer
var _readouts: Label
var _clock: Label
var _os: Label
var _status: Label
var _scan: ShaderMaterial
var _wrist: Control
var _col: Control
var _last := ""
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _content_node: Control
var _tween: Tween
var _tick := 0.0


func _ready() -> void:
	name = "WristHolo"
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	HudSlots.holo_requested.connect(open)
	HudSlots.holo_channels_changed.connect(_on_channels_changed)
	get_tree().node_added.connect(_on_node_added)


## True where the holo may come up: in a game, not on the menus.
func allowed() -> bool:
	var id := str(Router.current_id)
	return not id in ["main_menu", "settings", "boot"] and get_tree() != null


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


## Brings the screen up on `channel_id` ("" = the channel shown last, else the first).
## Already up: switches channel.
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
	_appear()


func close() -> void:
	if not is_open:
		return
	is_open = false
	Sfx.play("holo_close", null, -8.0)
	if root:
		_vanish()
	root = null
	pane = null
	content = null
	tabs = null
	_scan = null
	_wrist = null
	_col = null
	_content_node = null
	channel = ""
	Input.mouse_mode = _mouse_before


## Puts a channel on the screen ("" = the last one shown, else the first).
func show_channel(channel_id: String, sound: bool = true) -> void:
	if not is_open:
		open(channel_id)
		return
	if channel_id == "" or HudSlots.holo_channel(channel_id).is_empty():
		channel_id = _last if not HudSlots.holo_channel(_last).is_empty() else _first()
	channel = channel_id
	if channel_id != "":
		_last = channel_id
	if _content_node:
		content.remove_child(_content_node)  # now, so the new screen can take the name
		_content_node.queue_free()
		_content_node = null
	if channel_id == "":
		_content_node = T.label("No screens yet.", "body", 20, T.DIM)
	else:
		var factory: Callable = HudSlots.holo_channel(channel_id).factory
		var made: Variant = factory.call(true) if factory.get_argument_count() >= 1 else factory.call()
		_content_node = made as Control
		if _content_node == null:
			_content_node = T.label("This screen has nothing to show.", "body", 20, T.DIM)
		elif _content_node.has_signal("close_requested"):
			_content_node.connect("close_requested", close)
	_content_node.name = "Channel"
	_content_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_content_node)
	_fill_tabs()
	if sound:
		Sfx.play("holo_switch", null, -10.0)


func _process(delta: float) -> void:
	if not is_open:
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		_refresh_header()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.is_echo():
		return
	if event.is_action_pressed(Keys.HOLO) and (is_open or allowed()):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed(Keys.CANCEL):
		close()
		get_viewport().set_input_as_handled()


func _first() -> String:
	var all := HudSlots.holo_channels()
	return "" if all.is_empty() else str(all[0].id)


func _build() -> void:
	root = Control.new()
	root.name = "Holo"
	root.theme = BsxTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_meta("holo", true)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(root)
	var view := root.get_viewport_rect().size
	if view.x <= 0.0:
		view = Vector2(1280, 720)

	var wrist := WristArm.new()
	wrist.name = "Wrist"
	wrist.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wrist)
	_wrist = wrist

	pane = PanelContainer.new()
	pane.name = "Pane"
	var size := (view * SCREEN_SHARE).max(Vector2(900, 540))
	pane.size = size
	pane.position = Vector2((view.x - size.x) * 0.5 + view.x * 0.02, (view.y - size.y) * 0.4)
	pane.rotation = deg_to_rad(TILT_DEG)
	var style := T.box(T.tone(T.KIOSK, true, T.GLASS_KIOSK), Color(T.STEEL, 0.55), 2, 0)
	style.shadow_color = Color(0.55, 0.8, 0.95, 0.12)
	style.shadow_size = 16
	pane.add_theme_stylebox_override("panel", style)
	root.add_child(pane)
	wrist.target = pane

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	pane.add_child(col)
	_col = col

	# The terminal's header: the BSX badge, the title, the clock and readouts.
	var header := HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size.y = 58
	header.add_theme_constant_override("separation", 0)
	col.add_child(header)
	var badge := PanelContainer.new()
	var badge_st := T.box(Color(T.ORANGE, 0.88))
	badge_st.content_margin_left = 16
	badge_st.content_margin_right = 16
	badge.add_theme_stylebox_override("panel", badge_st)
	var bsx := T.label("BSX", "display_bold", 36, T.BLACK)
	bsx.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(bsx)
	header.add_child(badge)
	var title := VBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", -4)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(title)
	header.add_child(pad)
	title.add_child(T.label("WRIST TERMINAL", "display_bold", 28, T.TEXT))
	var game := T.label(Saves.current_name.to_upper() if Saves.current_name != "" else "BSX LTD  ·  SHIP FITTING",
			"display_medium", 15, T.DIM)
	game.name = "GameName"
	title.add_child(game)
	var readouts := VBoxContainer.new()
	readouts.alignment = BoxContainer.ALIGNMENT_CENTER
	readouts.add_theme_constant_override("separation", -2)
	var rpad := MarginContainer.new()
	rpad.add_theme_constant_override("margin_right", 16)
	rpad.add_child(readouts)
	header.add_child(rpad)
	_clock = T.label("", "mono_medium", 17, T.DIM)
	_clock.name = "Clock"
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readouts.add_child(_clock)
	_readouts = T.label("", "mono_bold", 24, T.ORANGE)
	_readouts.name = "Readouts"
	_readouts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readouts.add_child(_readouts)
	col.add_child(T.HazardRule.new(9.0, true))

	var tab_pad := MarginContainer.new()
	for side in ["left", "right", "top"]:
		tab_pad.add_theme_constant_override("margin_" + side, 14)
	tabs = HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 6)
	tab_pad.add_child(tabs)
	col.add_child(tab_pad)

	content = MarginContainer.new()
	content.name = "Content"
	content.clip_contents = true
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, 14)
	col.add_child(content)

	# The footer: the OS and build on the left, the keys in the middle, the date, time,
	# uptime and signal on the right, all in small print.
	var footer := PanelContainer.new()
	footer.name = "Footer"
	var fst := T.box(Color(T.EDGE, 0.45), Color.TRANSPARENT, 0, 5)
	fst.content_margin_left = 14
	fst.content_margin_right = 14
	footer.add_theme_stylebox_override("panel", fst)
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 12)
	footer.add_child(strip)
	_os = T.label(os_text(), "mono_medium", 12, Color(T.DIM, 0.9))
	_os.name = "OsInfo"
	_os.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	strip.add_child(_os)
	var hint := T.label("%s OR %s CLOSE   ·   CLICK A TAB FOR ANOTHER SCREEN   ·   %s USE" % [
			Keys.prompt(Keys.HOLO), Keys.prompt(Keys.CANCEL), Keys.prompt(Keys.INTERACT)],
			"display_medium", 14, T.DIM)
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.clip_text = true
	strip.add_child(hint)
	_status = T.label("", "mono_medium", 12, Color(T.DIM, 0.9))
	_status.name = "Status"
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	strip.add_child(_status)
	col.add_child(footer)

	var glow := ColorRect.new()
	glow.name = "Scan"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	mat.shader = shader
	glow.material = mat
	_scan = mat
	pane.add_child(glow)
	_refresh_header()


func _refresh_header() -> void:
	if _clock == null or not is_instance_valid(_clock):
		return
	_clock.text = AlienSky.clock(AlienSky.setting_hour())
	_readouts.text = "    ".join(HudSlots.holo_readouts())
	if _status and is_instance_valid(_status):
		_status.text = status_text()


## The footer's left side: "BSX-OS 4.2.1  ·  WRIST UNIT WT-7  ·  BUILD v0.3.0 (dev)".
func os_text() -> String:
	return "%s %s  ·  %s  ·  BUILD %s" % [OS_NAME, OS_VERSION, UNIT, BuildInfo.label().to_upper()]


## The footer's right side: "20 OCT 2026  22:23:41  ·  UP 00:04:12  ·  SIG ▮▮▮▮▯".
func status_text() -> String:
	var d := Time.get_datetime_dict_from_system()
	var months := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	var up := Time.get_ticks_msec() / 1000
	var bars := 4 + int(sin(Time.get_ticks_msec() * 0.0007) > 0.6)
	return "%02d %s %d  %02d:%02d:%02d  ·  UP %02d:%02d:%02d  ·  SIG %s" % [
			d.day, months[d.month - 1], d.year, d.hour, d.minute, d.second,
			up / 3600, (up / 60) % 60, up % 60, "▮".repeat(bars) + "▯".repeat(5 - bars)]


## Comes up out of the wrist: the emitter flares, a line of light stretches out across
## the view, opens top and bottom into the screen, and a bright line runs down it while the
## screen flickers in.
func _appear() -> void:
	if _tween:
		_tween.kill()
	pane.pivot_offset = pane.size * 0.5
	pane.scale = Vector2(0.03, 0.008)
	_col.modulate.a = 0.0
	_scan.set_shader_parameter("flash", 1.0)
	_scan.set_shader_parameter("glitch", 1.0)
	_scan.set_shader_parameter("sweep", -1.0)
	var a := APPEAR_TIME
	_tween = create_tween().set_parallel()
	_tween.tween_property(pane, "scale:x", 1.0, a * 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(pane, "scale:y", 1.0, a * 0.45).set_delay(a * 0.25) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_flare, 1.0, 0.0, a * 1.4)
	_tween.tween_property(_scan, "shader_parameter/flash", 0.0, a).set_ease(Tween.EASE_IN)
	_tween.tween_property(_scan, "shader_parameter/glitch", 0.0, a * 1.2).set_ease(Tween.EASE_IN)
	_tween.tween_property(_scan, "shader_parameter/sweep", 1.08, a * 0.6).from(0.0).set_delay(a * 0.4)
	_tween.tween_method(_flicker_in, 0.0, 1.0, a * 0.55).set_delay(a * 0.45)
	_tween.chain().tween_callback(func() -> void:
		if _scan:
			_scan.set_shader_parameter("sweep", -1.0))


## Goes away the other way: a flash, the screen folds to a line, the line shrinks to a spark
## at its middle and is gone. The old screen is left to fade while a new one can come up.
func _vanish() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	var old := root
	var old_pane := pane
	var mat := _scan
	var wrist := _wrist
	old.name = "HoloVanishing"
	old.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in old.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	old_pane.pivot_offset = old_pane.size * 0.5
	var v := VANISH_TIME
	var tw := create_tween().set_parallel()
	tw.tween_property(mat, "shader_parameter/flash", 1.0, v * 0.25)
	tw.tween_property(mat, "shader_parameter/glitch", 1.0, v * 0.25)
	tw.tween_property(_col, "modulate:a", 0.0, v * 0.4)
	tw.tween_property(old_pane, "scale:y", 0.008, v * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(old_pane, "scale:x", 0.0, v * 0.4).set_delay(v * 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if wrist:
		tw.tween_property(wrist, "flare", 1.0, v * 0.3)
	tw.tween_property(old, "modulate:a", 0.0, v * 0.35).set_delay(v * 0.75)
	tw.chain().tween_callback(old.queue_free)


func _flare(f: float) -> void:
	if _wrist and is_instance_valid(_wrist):
		_wrist.set("flare", f)


## The screen's contents flicker on: off and on a few times, then steady.
func _flicker_in(t: float) -> void:
	if _col == null or not is_instance_valid(_col):
		return
	var on := t >= 0.98 or fmod(sin(t * 91.7) * 4375.85, 1.0) > 0.35 - t * 0.3
	_col.modulate.a = t if on else t * 0.2


## Anything pressed or typed on the screen ticks; TerminalKit and BsxTheme buttons tick on
## their own (meta "sfx").
func _on_node_added(node: Node) -> void:
	if not is_open or root == null or node.has_meta("sfx") or not root.is_ancestor_of(node):
		return
	node.set_meta("sfx", true)
	if node is BaseButton:
		(node as BaseButton).pressed.connect(func() -> void: Sfx.press(node))
	elif node is LineEdit:
		(node as LineEdit).text_changed.connect(func(_t: String) -> void: Sfx.press(node, -18.0))
		(node as LineEdit).text_submitted.connect(func(_t: String) -> void: Sfx.press(node))
	elif node is Slider:
		(node as Slider).drag_ended.connect(func(_c: bool) -> void: Sfx.press(node, -14.0))


## One numbered tab per channel, the shown one lit, CLOSE at the end.
func _fill_tabs() -> void:
	if tabs == null:
		return
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	var n := 0
	for c: Dictionary in HudSlots.holo_channels():
		n += 1
		var b := T.button("%02d  %s" % [n, str(c.label).to_upper()], false, 19, c.id == channel, true)
		b.name = "Ch_" + str(c.id).validate_node_name()
		b.custom_minimum_size.x = 150
		b.set_meta("channel", c.id)
		b.pressed.connect(func() -> void: show_channel(c.id))
		tabs.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var x := T.button("CLOSE  ✕", false, 17, false, true)
	x.name = "Close"
	x.pressed.connect(close)
	tabs.add_child(x)


func _on_channels_changed() -> void:
	if not is_open:
		return
	if channel != "" and HudSlots.holo_channel(channel).is_empty():
		show_channel("", false)
	else:
		_fill_tabs()


## The forearm and gauntlet at the bottom left, with the emitter's light fanning up to the
## screen's lower corners.
class WristArm extends Control:
	var target: Control
	## 0..1: the emitter flaring as the screen comes and goes.
	var flare := 0.0

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
		draw_polyline(plate + PackedVector2Array([plate[0]]), Color(TerminalKit.ORANGE, 0.9), 2.0)
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
		var light := Color(0.62, 0.9, 1.0)
		draw_circle(cuff, 9.0 + flare * 6.0, Color(light, minf(1.0, 0.9 * pulse + flare)))
		draw_circle(cuff, 20.0 + flare * 40.0, Color(light, 0.18 * pulse + flare * 0.3))
		if target and is_instance_valid(target):
			var t := target.get_global_transform()
			var bl := t * Vector2(0, target.size.y)
			var br := t * Vector2(target.size.x * 0.45, target.size.y)
			draw_colored_polygon(PackedVector2Array([cuff, bl, br]), Color(light, 0.06 + flare * 0.14))
			draw_line(cuff, bl, Color(light, 0.25 + flare * 0.6), 1.5 + flare * 2.0)
			draw_line(cuff, br, Color(light, 0.15 + flare * 0.5), 1.5 + flare * 2.0)
