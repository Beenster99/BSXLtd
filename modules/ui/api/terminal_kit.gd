class_name TerminalKit
extends RefCounted
## The BSX terminal look, for every screen in the game: the yard terminal's design (Void
## Salvage's station terminals taken industrial: Barlow Condensed titles, Barlow prose,
## JetBrains Mono numbers, gunmetal plates, BSX orange, a hazard rule under the header) in
## one place, so the wall terminals and the wrist screen's channels all match. Pass
## `glass = true` for the wrist screen: the same plates, see-through.
##   var row := TerminalKit.row([TerminalKit.cell_text("Stringer", "Orbital surplus"),
##           TerminalKit.cell("24", 60), TerminalKit.cell("CR 120", 96, TerminalKit.TEXT, "mono_bold")], alt, glass)

const KIOSK := Color("16191c")
const PLATE := Color("2a2f34")
const PLATE_HI := Color("363c42")
const EDGE := Color("0d0f11")
const STEEL := Color("8a939b")
const TEXT := Color("e4e2dc")
const DIM := Color("8b949c")
const ORANGE := Color("e8792b")
const ORANGE_HI := Color("ff9a4d")
const BLACK := Color("111111")
## The docket: grey works paper, dark ink (pale glass on the wrist).
const DOCKET := Color("cfccc3")
const INK := Color("1f2328")
const INK_DIM := Color("5b6168")
const GOOD := Color("7fd47a")
const BAD := Color("ff5a3c")
const CYAN := Color("6fc8e8")
const AMBER := Color("e8c25a")
## How opaque plates and the kiosk are on glass.
const GLASS_PLATE := 0.58
const GLASS_KIOSK := 0.56
## Settings > Gameplay "Terminal text": how big terminal and screen text and list rows are,
## so a tab can hold more. Sizes passed to the kit are at Standard; it scales them.
const TEXT_SECTION := "terminal"
const TEXT_KEY := "text"
const TEXT_SIZES := {"Compact": 0.82, "Standard": 1.0, "Large": 1.15}
const TEXT_DEFAULT := "Compact"


## The chosen text scale (Compact by default).
static func text_scale() -> float:
	var v: Variant = Settings.get_value(TEXT_SECTION, TEXT_KEY)
	return float(TEXT_SIZES.get(str(v), TEXT_SIZES[TEXT_DEFAULT]))


## A size, font or width, at the chosen text scale.
static func px(n: float) -> int:
	return maxi(1, roundi(n * text_scale()))


static func font(face: String) -> Font:
	return BsxTheme.font(face)


## A plate colour, see-through on glass.
static func tone(c: Color, glass: bool, alpha := GLASS_PLATE) -> Color:
	return Color(c, c.a * alpha) if glass else c


static func box(bg: Color, border_color := Color.TRANSPARENT, border := 0, margin := 0.0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	if border > 0:
		b.border_color = border_color
		b.set_border_width_all(border)
	b.set_content_margin_all(margin)
	b.anti_aliasing = false
	return b


## A steel plate panel: flat, a dark edge, a lighter top lip.
static func plate(margin := 12.0, glass := false, bg := PLATE) -> StyleBoxFlat:
	var b := box(tone(bg, glass), tone(EDGE, glass, 0.8), 2, margin)
	b.border_width_top = 3
	b.shadow_color = Color(0, 0, 0, 0.12 if glass else 0.35)
	b.shadow_size = 3
	return b


static func label(text: String, face: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(face))
	l.add_theme_font_size_override("font_size", px(size))
	l.add_theme_color_override("font_color", color)
	return l


## A plate button: orange filled for the main action, steel otherwise; `on` lights a tab.
static func button(text: String, filled := false, size := 20, on := false, glass := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font("display_bold" if filled else "display"))
	b.add_theme_font_size_override("font_size", px(size))
	var bg := ORANGE if filled else (PLATE_HI if on else PLATE)
	var a := 0.85 if filled else GLASS_PLATE + 0.1
	var normal := box(tone(bg, glass, a), ORANGE if on else tone(EDGE, glass, 0.8), 2, px(8.0))
	if on:
		normal.border_width_left = 0
		normal.border_width_right = 0
		normal.border_width_top = 0
		normal.border_width_bottom = 4
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", box(tone(ORANGE_HI if filled else PLATE_HI, glass, a + 0.1), ORANGE, 2, 8.0))
	b.add_theme_stylebox_override("pressed", box(tone(ORANGE.darkened(0.2), glass, 0.9), ORANGE, 2, 8.0))
	b.add_theme_stylebox_override("disabled", box(Color(bg, 0.25 if glass else 0.35), tone(EDGE, glass, 0.6), 2, 8.0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ink := BLACK if filled else (TEXT if on else STEEL)
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", BLACK if filled else TEXT)
	b.add_theme_color_override("font_pressed_color", BLACK if filled else TEXT)
	b.add_theme_color_override("font_disabled_color", Color(ink, 0.4))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func() -> void: Sfx.press(b))
	b.set_meta("sfx", true)
	return b


## A search box in the terminal's plate style; `on_changed(text)` as the player types.
static func search(placeholder: String, on_changed: Callable, glass := false) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.clear_button_enabled = true
	e.custom_minimum_size = Vector2(px(220), px(34))
	e.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	e.add_theme_font_override("font", font("body_medium"))
	e.add_theme_font_size_override("font_size", px(17))
	e.add_theme_color_override("font_color", TEXT)
	e.add_theme_color_override("font_placeholder_color", DIM)
	e.add_theme_color_override("caret_color", ORANGE)
	var st := box(tone(EDGE, glass, 0.7), tone(PLATE_HI, glass, 0.9), 2, 6.0)
	st.content_margin_left = 10
	e.add_theme_stylebox_override("normal", st)
	var focus := box(tone(EDGE, glass, 0.8), ORANGE, 2, 6.0)
	focus.content_margin_left = 10
	e.add_theme_stylebox_override("focus", focus)
	e.text_changed.connect(on_changed)
	return e


## A row of filter chips (ALL first when `all` is set); `on_pick(name)`, "" for ALL.
static func chips(names: PackedStringArray, current: String, on_pick: Callable, glass := false, all := true) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	var list := PackedStringArray([""]) if all else PackedStringArray()
	list.append_array(names)
	for n in list:
		var b := button(n.to_upper() if n != "" else "ALL", false, 15, n == current, glass)
		b.pressed.connect(on_pick.bind(n))
		flow.add_child(b)
	return flow


## Column headings over a list: specs are [text, width] (width 0 = takes the rest).
static func columns(specs: Array) -> MarginContainer:
	var head := HBoxContainer.new()
	for spec: Array in specs:
		var l := label(spec[0], "display_medium", 14, DIM)
		if int(spec[1]) == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.custom_minimum_size.x = px(spec[1])
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(l)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 22)
	pad.add_child(head)
	return pad


## One line of a list on a plate, alternate lines a shade lighter. `cells` sit left to right.
static func row(cells: Array, alt := false, glass := false) -> PanelContainer:
	var panel := PanelContainer.new()
	var st := box(tone(PLATE_HI if alt else PLATE, glass), Color.TRANSPARENT, 0, 0)
	st.content_margin_left = 10
	st.content_margin_right = 8
	st.content_margin_top = px(5)
	st.content_margin_bottom = px(5)
	panel.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	panel.add_child(h)
	for c: Control in cells:
		h.add_child(c)
	return panel


## A list's name cell: a name over a dim small-caps line; it takes the row's spare width.
static func cell_text(title: String, sub: String = "") -> VBoxContainer:
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -3)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := label(title, "body_medium", 19, TEXT)
	t.clip_text = true
	names.add_child(t)
	if sub != "":
		names.add_child(label(sub.to_upper(), "display_medium", 13, DIM))
	return names


## A right-aligned number cell `width` wide.
static func cell(text: String, width: float, color := DIM, face := "mono_medium") -> Label:
	var l := label(text, face, 17, color)
	l.custom_minimum_size.x = px(width)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## A small coloured tag: "NEW", "IN STOCK", "ON JOB".
static func tag(text: String, color: Color, size := 15) -> CenterContainer:
	var p := PanelContainer.new()
	var st := box(Color(color, 0.16), color, 1, 0.0)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 1
	st.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", st)
	p.add_child(label(text.to_upper(), "mono_medium", size, color))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var c := CenterContainer.new()
	c.add_child(p)
	return c


## A scrolling list body; add rows to the returned box (its parent is the ScrollContainer).
static func list() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box_ := VBoxContainer.new()
	box_.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_.add_theme_constant_override("separation", 3)
	scroll.add_child(box_)
	return box_


## A docket: the side panel with a title over a rule (the purchase order's paper). On glass
## it's pale frosted glass with light ink.
static func docket(title: String, ref: String = "", glass := false) -> Dictionary:
	var paper := PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := box(Color(DOCKET, 0.16) if glass else DOCKET, tone(EDGE, glass, 0.8), 2, 14)
	st.border_width_top = 8
	st.border_color = STEEL.darkened(0.3) if not glass else Color(STEEL, 0.6)
	paper.add_theme_stylebox_override("panel", st)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	paper.add_child(col)
	var top := HBoxContainer.new()
	var t := label(title.to_upper(), "display_bold", 26, TEXT if glass else INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	if ref != "":
		top.add_child(label(ref, "mono_medium", 14, DIM if glass else INK_DIM))
	col.add_child(top)
	var rule := ColorRect.new()
	rule.color = Color(TEXT, 0.4) if glass else INK
	rule.custom_minimum_size.y = 2
	col.add_child(rule)
	return {"panel": paper, "body": col}


## The sections other modules added to `channel` (HudSlots.register_holo_section), one
## docket each, kept up to date as they come and go. Put it where the channel wants them.
static func sections(channel: String, glass := false) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.name = "Sections"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	var fill := func() -> void:
		for c in col.get_children():
			col.remove_child(c)
			c.queue_free()
		for sec: Dictionary in HudSlots.holo_sections(channel):
			var d := docket(str(sec.label), "", glass)
			d.panel.name = "Section_" + str(sec.id).validate_node_name()
			var f: Callable = sec.factory
			var made: Variant = f.call(glass) if f.get_argument_count() >= 1 else f.call()
			if made is Control:
				d.body.add_child(made)
			col.add_child(d.panel)
	fill.call()
	var on_change := func(ch: String) -> void:
		if ch == channel and is_instance_valid(col):
			fill.call()
	HudSlots.holo_sections_changed.connect(on_change)
	col.tree_exiting.connect(func() -> void:
		if HudSlots.holo_sections_changed.is_connected(on_change):
			HudSlots.holo_sections_changed.disconnect(on_change))
	return col


## A big figure with its caption, for summaries ("STOCK VALUE  CR 12,400").
static func figure(what: String, value: String, colour := TEXT, glass := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", plate(12.0, glass))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.add_child(label(what.to_upper(), "display_medium", 15, DIM))
	v.add_child(label(value, "mono_bold", 28, colour))
	p.add_child(v)
	return p


## "12,400".
static func money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Diagonal orange and black stripes: the rule under the header.
class HazardRule:
	extends Control
	var glass := false

	func _init(height := 8.0, p_glass := false) -> void:
		custom_minimum_size.y = height
		glass = p_glass
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var a := 0.75 if glass else 1.0
		draw_rect(Rect2(Vector2.ZERO, size), Color(BLACK, 0.5 if glass else 1.0))
		var h := size.y
		var x := -h
		while x < size.x + h:
			draw_colored_polygon(PackedVector2Array([Vector2(x, h), Vector2(x + h, 0), Vector2(x + h * 2, 0), Vector2(x + h, h)]), Color(ORANGE, a))
			x += h * 3
