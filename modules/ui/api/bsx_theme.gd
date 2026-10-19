class_name BsxTheme
extends RefCounted
## The shared look: workshop dark with safety-orange accents. Every module's UI uses
## BsxTheme.get_theme() (or the widgets below) so screens match without copying styles.

const BG := Color("1d2630")
const PANEL := Color("27323e")
const ACCENT := Color("f2a33a")
const TEXT := Color("e8edf2")
const MUTED := Color("93a1af")

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = 22
	_theme.set_color("font_color", "Label", TEXT)
	_theme.set_color("font_color", "Button", TEXT)
	_theme.set_color("font_hover_color", "Button", ACCENT)
	_theme.set_stylebox("normal", "Button", _box(PANEL, 2))
	_theme.set_stylebox("hover", "Button", _box(PANEL.lightened(0.08), 2, ACCENT))
	_theme.set_stylebox("pressed", "Button", _box(PANEL.darkened(0.2), 2, ACCENT))
	_theme.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, 2, ACCENT))
	_theme.set_stylebox("disabled", "Button", _box(PANEL.darkened(0.3), 2))
	_theme.set_stylebox("panel", "PanelContainer", _box(PANEL, 4))
	return _theme


static func title(text: String, size: int = 56) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ACCENT)
	return l


static func muted(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", MUTED)
	return l


static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 52)
	b.pressed.connect(on_pressed)
	return b


static func _box(color: Color, radius: int, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(10)
	if border.a > 0:
		s.set_border_width_all(2)
		s.border_color = border
	return s
