extends RefCounted
## The yard terminal's look: Void Salvage's station terminals (its TerminalTheme: Barlow
## Condensed titles, Barlow prose, JetBrains Mono numbers, a docket on a dark kiosk) taken
## industrial. Gunmetal kiosk, riveted steel plates instead of client colours, BSX orange,
## a hazard rule under the header, and the purchase order on a dull grey works docket.

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
## The purchase order docket: grey works paper, dark ink.
const DOCKET := Color("cfccc3")
const INK := Color("1f2328")
const INK_DIM := Color("5b6168")
const GOOD := Color("7fd47a")
const BAD := Color("ff5a3c")

const CONDITION_COLOURS := {
	"new": Color("7fd47a"), "refurbished": Color("6fc8e8"), "used": Color("e8c25a"), "damaged": Color("ff6a4a"),
}


static func font(face: String) -> Font:
	return BsxTheme.font(face)


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
static func plate(margin := 12.0, bg := PLATE) -> StyleBoxFlat:
	var b := box(bg, EDGE, 2, margin)
	b.border_width_top = 3
	b.border_color = EDGE
	b.shadow_color = Color(0, 0, 0, 0.35)
	b.shadow_size = 3
	return b


static func label(text: String, face: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(face))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A plate button: orange filled for the main action, steel otherwise; `on` lights a tab.
static func button(text: String, filled := false, size := 20, on := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font("display_bold" if filled else "display"))
	b.add_theme_font_size_override("font_size", size)
	var bg := ORANGE if filled else (PLATE_HI if on else PLATE)
	var normal := box(bg, ORANGE if on else EDGE, 2, 8.0)
	if on:
		normal.border_width_left = 0
		normal.border_width_right = 0
		normal.border_width_top = 0
		normal.border_width_bottom = 4
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", box(ORANGE_HI if filled else PLATE_HI, ORANGE, 2, 8.0))
	b.add_theme_stylebox_override("pressed", box(ORANGE.darkened(0.2), ORANGE, 2, 8.0))
	b.add_theme_stylebox_override("disabled", box(Color(bg, 0.35), EDGE, 2, 8.0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ink := BLACK if filled else (TEXT if on else STEEL)
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", BLACK if filled else TEXT)
	b.add_theme_color_override("font_pressed_color", BLACK if filled else TEXT)
	b.add_theme_color_override("font_disabled_color", Color(ink, 0.4))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## "12,400".
static func money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## A tag in a condition's colour: "NEW", "USED"...
static func condition_tag(condition: String, size := 15) -> PanelContainer:
	var c: Color = CONDITION_COLOURS.get(condition, STEEL)
	var p := PanelContainer.new()
	var st := box(Color(c, 0.16), c, 1, 0.0)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 1
	st.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", st)
	p.add_child(label(PartCondition.label(condition), "mono_medium", size, c))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


## Diagonal orange and black stripes: the rule under the header.
class HazardRule:
	extends Control

	func _init(height := 8.0) -> void:
		custom_minimum_size.y = height
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), BLACK)
		var h := size.y
		var x := -h
		while x < size.x + h:
			draw_colored_polygon(PackedVector2Array([Vector2(x, h), Vector2(x + h, 0), Vector2(x + h * 2, 0), Vector2(x + h, h)]), ORANGE)
			x += h * 3
