class_name BsxTheme
extends RefCounted
## The shared look, taken from Void Salvage so the two games read as one: near-black
## space, a pale cyan accent, Godot's own buttons and fields, and the HUD's cyan
## monospace readouts with a dark outline (Void Salvage's Hud). Every module's UI uses
## BsxTheme.get_theme() and the helpers below so screens match without copying styles.
## Fonts are Void Salvage's: JetBrains Mono for readouts and numbers, Barlow and Barlow
## Condensed for prose and titles (OFL, licences in fonts/).

## Void Salvage's menu background and accent (scripts/ui/menu.gd, Hud.HUD_COLOR).
const BG := Color(0.015, 0.02, 0.035)
const ACCENT := Color(0.62, 0.9, 1.0)
## Panels: Void Salvage's graphics screen (dark glass, cyan edge).
const PANEL := Color(0.02, 0.04, 0.07, 0.96)
const TEXT := Color(0.875, 0.875, 0.875)
const MUTED := Color(0.62, 0.9, 1.0, 0.55)
## HUD colours, as Void Salvage's Hud: readouts, dim lines, warnings, live values.
const HUD := Color(0.62, 0.9, 1.0, 0.9)
const HUD_DIM := Color(0.62, 0.9, 1.0, 0.35)
const WARN := Color(1.0, 0.45, 0.2, 0.95)
const LIVE := Color(1.0, 0.85, 0.2, 1.0)
const STATUS := Color(1.0, 0.75, 0.5)

const FONT_DIR := "res://modules/ui/api/fonts/"
const FACES := {
	"mono": "JetBrainsMono-Regular.ttf",
	"mono_medium": "JetBrainsMono-Medium.ttf",
	"mono_bold": "JetBrainsMono-Bold.ttf",
	"body": "Barlow-Regular.ttf",
	"body_medium": "Barlow-Medium.ttf",
	"display": "BarlowCondensed-SemiBold.ttf",
	"display_bold": "BarlowCondensed-Bold.ttf",
	"display_medium": "BarlowCondensed-Medium.ttf",
}

static var _theme: Theme
static var _fonts: Dictionary = {}


## A face from FACES. Loaded once: fresh fonts draw as blocks for a frame.
static func font(face: String = "mono") -> Font:
	if not _fonts.has(face):
		var f := load(FONT_DIR + FACES.get(face, FACES["mono"])) as Font
		_fonts[face] = f if f else ThemeDB.fallback_font
	return _fonts[face]


## Godot's default controls (as Void Salvage's menus use them) with the panels, labels and
## colours above. Anything not set here falls back to the default theme.
static func get_theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.set_color("font_color", "Label", TEXT)
	_theme.set_stylebox("panel", "PanelContainer", panel_style())
	_theme.set_stylebox("panel", "Panel", panel_style())
	return _theme


## Void Salvage's dark glass panel with a cyan edge.
static func panel_style(margin: int = 20) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.border_color = Color(ACCENT, 0.5)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(margin)
	return s


## A HUD slot box, as Void Salvage's hotbar: lit when `on`.
static func slot_style(on: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(4)
	s.set_content_margin_all(10)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.set_border_width_all(2)
	s.bg_color = Color(ACCENT, 0.18) if on else Color(0, 0, 0, 0.35)
	s.border_color = HUD if on else Color(ACCENT, 0.18)
	return s


## A HUD readout: cyan monospace with a dark outline, readable over any scene.
static func hud_label(text: String = "", size: int = 18, color: Color = HUD) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = font("mono")
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = 4
	ls.outline_color = Color(0, 0, 0, 0.6)
	l.label_settings = ls
	return l


static func title(text: String, size: int = 52) -> Label:
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
	b.custom_minimum_size = Vector2(150, 42)
	b.pressed.connect(on_pressed)
	return b
