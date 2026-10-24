extends Node3D
## G6, a ship's screen (flag "graphics.screens"): a glowing page over a screen's glass, drawn
## in its own small viewport like Void Salvage's ship monitors. Each kind of screen has its
## own page: the hold monitor (text and the soft keys' row), the cockpit's flight readout
## (text and gauges), the cockpit monitor (text and the hold's fill bar), the nav display (a
## radar sweep) and the system map (orbits). Text is the owner's; the first line is the title.
## set_on() boots it (a short start-up flicker) or blanks it; the glass under it stays as it
## is. Pages redraw a few times a second, not every frame.

const ScreenShader := preload("res://modules/graphics/internal/led_screen.gdshader")
## Pixels per metre of glass, and the page size's limits.
const DENSITY := 900.0
const MIN_PX := 160
const MAX_PX := 1024
## Redraws a second while on.
const RATE := 8.0
const BOOT_TIME := 0.7
const INK := Color(0.45, 0.95, 1.0)
const DIM := Color(0.45, 0.95, 1.0, 0.35)
const WARM := Color(1.0, 0.72, 0.35)
const BG_TOP := Color(0.012, 0.05, 0.065)
const BG_BOTTOM := Color(0.004, 0.02, 0.03)
## The hold monitor's soft keys (Void Salvage's MONITOR_KEYS).
const SOFT_KEYS: PackedStringArray = ["HOLD", "SURVEY", "JOBS", "MARKET", "", "MENU"]

## "monitor", "cockpit_screen", "cockpit_monitor", "nav_display", "map_screen" (else text only).
var kind := ""
var text := ""
var on := false
var size_m := Vector2(0.6, 0.4)
var viewport: SubViewport
var page: Control
var quad: MeshInstance3D
var _mat: ShaderMaterial
var _clock := 0.0
var _since_draw := 0.0
var _booted := 0.0


## A screen over `glass` (a quad facing its +Z): a sibling just in front of it.
static func over(glass: MeshInstance3D, screen_kind: String, screen_text: String) -> Node3D:
	var s: Node3D = (load("res://modules/graphics/internal/led_screen.gd") as GDScript).new()
	s.name = "LedScreen"
	s.kind = screen_kind
	s.text = screen_text
	if glass.mesh is QuadMesh:
		s.size_m = (glass.mesh as QuadMesh).size
	s.transform = glass.transform * Transform3D(Basis(), Vector3(0, 0, 0.0015))
	glass.get_parent().add_child(s)
	return s


func _init() -> void:
	set_process(false)


func _ready() -> void:
	var px := Vector2i((size_m * DENSITY).round())
	var k := 1.0
	if maxi(px.x, px.y) > MAX_PX:
		k = float(MAX_PX) / float(maxi(px.x, px.y))
	if mini(px.x, px.y) < MIN_PX:
		k = maxf(k, float(MIN_PX) / float(maxi(mini(px.x, px.y), 1)))
	px = Vector2i((Vector2(px) * k).round())
	viewport = SubViewport.new()
	viewport.name = "Page"
	viewport.size = px
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	page = Control.new()
	page.size = Vector2(px)
	page.draw.connect(_draw_page)
	viewport.add_child(page)
	quad = MeshInstance3D.new()
	quad.name = "Glow"
	var qm := QuadMesh.new()
	qm.size = size_m
	quad.mesh = qm
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = ScreenShader
	_mat.set_shader_parameter("page", viewport.get_texture())
	_mat.set_shader_parameter("rows", float(px.y) * 0.5)
	_mat.set_shader_parameter("grid", Vector2(px) * 0.5)
	quad.material_override = _mat
	add_child(quad)
	visible = on
	set_process(on)


## Boots the screen (on) or blanks it (off).
func set_on(want: bool) -> void:
	if want == on:
		return
	on = want
	visible = on
	_booted = 0.0
	_since_draw = 1.0
	set_process(on)


func set_text(t: String) -> void:
	text = t
	_since_draw = 1.0


func _process(delta: float) -> void:
	_clock += delta
	_booted += delta
	_since_draw += delta
	if _mat:
		# Power-up: a flicker, then steady.
		var p := 1.0
		if _booted < BOOT_TIME:
			var t := _booted / BOOT_TIME
			p = t * (0.6 + 0.4 * absf(sin(_booted * 47.0)))
		_mat.set_shader_parameter("power", p)
	if _since_draw >= 1.0 / RATE and page:
		_since_draw = 0.0
		page.queue_redraw()
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _draw_page() -> void:
	var sz := page.size
	var u := sz.y / 300.0   # layout unit: a 300 px tall page is the reference
	page.draw_rect(Rect2(Vector2.ZERO, sz), BG_BOTTOM)
	page.draw_rect(Rect2(Vector2.ZERO, Vector2(sz.x, sz.y * 0.5)), BG_TOP)
	var font := BsxTheme.font("mono")
	if _booted < BOOT_TIME:
		_draw_boot(font, sz, u)
		return
	var lines := text.split("\n")
	var title := lines[0] if lines.size() > 0 else ""
	var fs := int(round(16.0 * u))
	# Title bar with the time on the right.
	page.draw_rect(Rect2(0, 0, sz.x, 26.0 * u), Color(INK, 0.16))
	page.draw_string(font, Vector2(10.0 * u, 19.0 * u), title, HORIZONTAL_ALIGNMENT_LEFT, sz.x * 0.7, fs, INK)
	var clock := Time.get_time_string_from_system().left(5)
	page.draw_string(font, Vector2(sz.x - 10.0 * u - font.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, 19.0 * u),
			clock, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, DIM)
	var body_w := sz.x
	match kind:
		"nav_display", "map_screen":
			body_w = sz.x * 0.45
	var y := 48.0 * u
	for i in range(1, lines.size()):
		var line := lines[i]
		if y > sz.y - 20.0 * u:
			break
		var col := WARM if line.begins_with("!") else INK
		page.draw_string(font, Vector2(10.0 * u, y), line.trim_prefix("!"), HORIZONTAL_ALIGNMENT_LEFT, body_w - 14.0 * u, fs, col)
		y += 20.0 * u
	# A blinking cursor after the text.
	if fmod(_clock, 1.0) < 0.55:
		page.draw_rect(Rect2(10.0 * u, y - 14.0 * u, 9.0 * u, 15.0 * u), Color(INK, 0.8))
	match kind:
		"monitor":
			_draw_soft_keys(font, sz, u)
		"cockpit_screen":
			_draw_gauges(font, sz, u)
		"cockpit_monitor":
			_draw_fill(sz, u)
		"nav_display":
			_draw_radar(sz, u)
		"map_screen":
			_draw_map(sz, u)


func _draw_boot(font: Font, sz: Vector2, u: float) -> void:
	var fs := int(round(16.0 * u))
	var steps := ["SYSTEM START", "SELF TEST .... OK", "BUS ........... OK", "DISPLAY ....... OK"]
	var shown := int(_booted / BOOT_TIME * float(steps.size() + 1))
	for i in mini(shown, steps.size()):
		page.draw_string(font, Vector2(10.0 * u, (24.0 + 22.0 * float(i)) * u), steps[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)


## The hold monitor's six soft-key legends along the bottom, the first lit.
func _draw_soft_keys(font: Font, sz: Vector2, u: float) -> void:
	var n := SOFT_KEYS.size()
	var w := sz.x / float(n)
	var h := 24.0 * u
	var fs := int(round(12.0 * u))
	for i in n:
		var r := Rect2(w * float(i) + 4.0 * u, sz.y - h - 4.0 * u, w - 8.0 * u, h)
		page.draw_rect(r, Color(INK, 0.22 if i == 0 else 0.07))
		page.draw_rect(r, Color(INK, 0.5), false, maxf(1.0, u))
		var t := SOFT_KEYS[i]
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		page.draw_string(font, Vector2(r.position.x + (r.size.x - tw) * 0.5, r.position.y + r.size.y * 0.7), t,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK if i == 0 else DIM)


## Three idle gauges down the right: drive, power, air.
func _draw_gauges(font: Font, sz: Vector2, u: float) -> void:
	var names := ["DRV", "PWR", "AIR"]
	var levels := [0.0, 0.62 + 0.03 * sin(_clock * 1.3), 0.97]
	var x0 := sz.x * 0.62
	var bw := (sz.x * 0.36) / 3.0
	var top := 44.0 * u
	var bottom := sz.y - 26.0 * u
	var fs := int(round(12.0 * u))
	for i in 3:
		var x := x0 + bw * float(i)
		var r := Rect2(x + 6.0 * u, top, bw - 12.0 * u, bottom - top)
		page.draw_rect(r, Color(INK, 0.08))
		var fill := r.size.y * float(levels[i])
		page.draw_rect(Rect2(r.position.x, r.end.y - fill, r.size.x, fill), WARM if i == 0 else Color(INK, 0.7))
		page.draw_string(font, Vector2(r.position.x, sz.y - 8.0 * u), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, DIM)


## The hold's fill bar along the bottom.
func _draw_fill(sz: Vector2, u: float) -> void:
	var r := Rect2(10.0 * u, sz.y - 24.0 * u, sz.x - 20.0 * u, 12.0 * u)
	page.draw_rect(r, Color(INK, 0.1))
	page.draw_rect(r, Color(INK, 0.5), false, maxf(1.0, u))


## A radar: rings, a cross and a sweep trailing off.
func _draw_radar(sz: Vector2, u: float) -> void:
	var c := Vector2(sz.x * 0.72, sz.y * 0.56)
	var r := minf(sz.x * 0.26, sz.y * 0.4)
	for k in 3:
		page.draw_arc(c, r * float(k + 1) / 3.0, 0.0, TAU, 64, Color(INK, 0.35), maxf(1.0, u))
	page.draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(INK, 0.2), maxf(1.0, u))
	page.draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(INK, 0.2), maxf(1.0, u))
	var a := fmod(_clock * 1.6, TAU)
	for k in 12:
		var b := a - float(k) * 0.06
		page.draw_line(c, c + Vector2(cos(b), sin(b)) * r, Color(INK, 0.6 * (1.0 - float(k) / 12.0)), maxf(1.0, 2.0 * u))
	page.draw_circle(c, 3.0 * u, INK)


## A system map: the star, a few orbits and a ship marker going round.
func _draw_map(sz: Vector2, u: float) -> void:
	var c := Vector2(sz.x * 0.72, sz.y * 0.56)
	var r := minf(sz.x * 0.26, sz.y * 0.4)
	page.draw_circle(c, 5.0 * u, WARM)
	for k in 4:
		var rr := r * (0.3 + 0.23 * float(k))
		page.draw_arc(c, rr, 0.0, TAU, 72, Color(INK, 0.3), maxf(1.0, u))
		var a := _clock * (0.25 / float(k + 1)) + float(k) * 1.7
		page.draw_circle(c + Vector2(cos(a), sin(a)) * rr, 3.0 * u, Color(INK, 0.8))
