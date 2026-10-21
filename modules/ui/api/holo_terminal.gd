class_name HoloTerminal
extends PanelContainer
## The BSX terminal: the orange badge and title, clock and readouts (HudSlots readouts), the
## hazard rule, a numbered tab for every wrist channel (HudSlots.register_holo_channel), the
## channel's screen, and the footer's small print (OS, build, date, time, uptime). The wrist
## screen shows one on glass; a TV or any screen in the world can show the same channels:
##   var term := HoloTerminal.new(false, "HALL TERMINAL")   # opaque, for a TV's SubViewport
##   term.show_channel("business.orders")
## On glass it's see-through and has CLOSE; close_requested also comes from a channel's own.

signal close_requested
signal channel_changed(id: String)

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
const T := preload("res://modules/ui/api/terminal_kit.gd")
## The terminal's operating system, for the footer's small print.
const OS_NAME := "BSX-OS"
const OS_VERSION := "4.2.1"

var glass := true
var title_text := "WRIST TERMINAL"
var unit := "WRIST UNIT WT-7"
## Shows CLOSE at the end of the tabs.
var closable := true
## The footer's middle text.
var hint_text := ""
var channel := ""
var col: VBoxContainer
var tabs: HBoxContainer
var content: MarginContainer
var scan: ShaderMaterial
var _content_node: Control
var _readouts: Label
var _clock: Label
var _os: Label
var _status: Label
var _tick := 0.0


func _init(p_glass := true, p_title := "WRIST TERMINAL", p_unit := "WRIST UNIT WT-7") -> void:
	glass = p_glass
	title_text = p_title
	unit = p_unit
	closable = p_glass
	name = "Terminal"
	theme = BsxTheme.get_theme()
	_build()


func _ready() -> void:
	HudSlots.holo_channels_changed.connect(_on_channels_changed)
	refresh_header()


func _exit_tree() -> void:
	if HudSlots.holo_channels_changed.is_connected(_on_channels_changed):
		HudSlots.holo_channels_changed.disconnect(_on_channels_changed)


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		refresh_header()


## Puts a channel up ("" or an unknown id: the first). Its factory is told whether it's on glass.
func show_channel(id: String) -> void:
	if id == "" or HudSlots.holo_channel(id).is_empty():
		id = first_channel()
	channel = id
	if _content_node:
		content.remove_child(_content_node)  # now, so the new screen can take the name
		_content_node.queue_free()
		_content_node = null
	if id == "":
		_content_node = T.label("No screens yet.", "body", 20, T.DIM)
	else:
		var factory: Callable = HudSlots.holo_channel(id).factory
		var made: Variant = factory.call(glass) if factory.get_argument_count() >= 1 else factory.call()
		_content_node = made as Control
		if _content_node == null:
			_content_node = T.label("This screen has nothing to show.", "body", 20, T.DIM)
		elif _content_node.has_signal("close_requested") and closable:
			_content_node.connect("close_requested", func() -> void: close_requested.emit())
	_content_node.name = "Channel"
	_content_node.set_meta("channel", id)
	_content_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_content_node)
	# After this click is done: the tab pressed is still handling its mouse release, and a
	# freed button lets the release fall through to the game, which takes the mouse.
	fill_tabs.call_deferred()
	channel_changed.emit(id)


static func first_channel() -> String:
	var all := HudSlots.holo_channels()
	return "" if all.is_empty() else str(all[0].id)


## One numbered tab per channel, the shown one lit, CLOSE at the end.
func fill_tabs() -> void:
	if tabs == null or not is_instance_valid(tabs):
		return
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	var n := 0
	for c: Dictionary in HudSlots.holo_channels():
		n += 1
		var b := T.button("%02d  %s" % [n, str(c.label).to_upper()], false, 19, c.id == channel, glass)
		b.name = "Ch_" + str(c.id).validate_node_name()
		b.custom_minimum_size.x = 150
		b.set_meta("channel", c.id)
		b.pressed.connect(func() -> void:
			if c.id != channel:
				show_channel(c.id)
				Sfx.play("holo_switch", null, -16.0))
		tabs.add_child(b)
	if closable:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(spacer)
		var x := T.button("CLOSE  ✕", false, 17, false, glass)
		x.name = "Close"
		x.pressed.connect(func() -> void: close_requested.emit())
		tabs.add_child(x)


func refresh_header() -> void:
	if _clock == null:
		return
	_clock.text = AlienSky.clock(AlienSky.setting_hour())
	_readouts.text = "    ".join(HudSlots.holo_readouts())
	_status.text = status_text()


## The footer's left side: "BSX-OS 4.2.1  ·  WRIST UNIT WT-7  ·  BUILD v0.3.0 (dev)".
func os_text() -> String:
	return "%s %s  ·  %s  ·  BUILD %s" % [OS_NAME, OS_VERSION, unit, BuildInfo.label().to_upper()]


## The footer's right side: "20 OCT 2026  22:23:41  ·  UP 00:04:12  ·  SIG ▮▮▮▮▯".
static func status_text() -> String:
	var d := Time.get_datetime_dict_from_system()
	var months := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	var up := Time.get_ticks_msec() / 1000
	var bars := 4 + int(sin(Time.get_ticks_msec() * 0.0007) > 0.6)
	return "%02d %s %d  %02d:%02d:%02d  ·  UP %02d:%02d:%02d  ·  SIG %s" % [
			d.day, months[d.month - 1], d.year, d.hour, d.minute, d.second,
			up / 3600, (up / 60) % 60, up % 60, "▮".repeat(bars) + "▯".repeat(5 - bars)]


func _on_channels_changed() -> void:
	if channel != "" and HudSlots.holo_channel(channel).is_empty():
		show_channel("")
	else:
		fill_tabs()


func _build() -> void:
	var style := T.box(T.tone(T.KIOSK, glass, T.GLASS_KIOSK), Color(T.STEEL, 0.55), 2, 0)
	if glass:
		style.shadow_color = Color(0.55, 0.8, 0.95, 0.12)
		style.shadow_size = 16
	add_theme_stylebox_override("panel", style)
	col = VBoxContainer.new()
	col.name = "Col"
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	# The header: the BSX badge, the title, the clock and readouts.
	var header := HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size.y = 58
	header.add_theme_constant_override("separation", 0)
	col.add_child(header)
	var badge := PanelContainer.new()
	var badge_st := T.box(Color(T.ORANGE, 0.88 if glass else 1.0))
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
	var t := T.label(title_text, "display_bold", 28, T.TEXT)
	t.name = "Title"
	title.add_child(t)
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
	col.add_child(T.HazardRule.new(9.0, glass))

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

	# The footer: the OS and build on the left, the hint in the middle, the date, time,
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
	var hint := T.label(hint_text, "display_medium", 14, T.DIM)
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
	scan = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	scan.shader = shader
	scan.set_shader_parameter("strength", 1.0 if glass else 0.5)
	glow.material = scan
	add_child(glow)


## Sets the footer's middle text.
func set_hint(text: String) -> void:
	hint_text = text
	(col.find_child("Hint", true, false) as Label).text = text
