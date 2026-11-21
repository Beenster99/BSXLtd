class_name ContractSignaturePad
extends VBoxContainer
## Signing a contract paper by hand (beenster, 21 Nov: "actually sign it by scribbling my
## signature on a line"). A pad with a line to sign on: press and drag to write, CLEAR to start
## again, SIGN to send it. The signature is kept with the paper as strokes, each a run of points
## packed as ints 0..255 across and down the pad (x, y, x, y ...): small enough to save and sync.
## `ContractSignaturePad.view(sig, size)` draws a kept one back.

signal signed(sig: Array)
signal cancelled

const T := preload("res://modules/ui/api/terminal_kit.gd")
## The pad's shape (width : height).
const ASPECT := 4.0
## Strokes and points kept at most (the host clips to these too).
const MAX_STROKES := 40
const MAX_POINTS := 1200
const INK := Color(0.12, 0.2, 0.55)
const PAPER := Color(0.93, 0.92, 0.87)

var strokes: Array = []
var _pad: Control
var _sign: Button
var _drawing := false


## A pad titled `title` (what is being signed), `fs` the font size.
static func make(title: String, fs := 14) -> ContractSignaturePad:
	var p := ContractSignaturePad.new()
	p._build(title, fs)
	return p


func _build(title: String, fs: int) -> void:
	add_theme_constant_override("separation", int(fs * 0.4))
	var l := T.label(title, "mono_medium", fs - 1, T.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(l)
	_pad = Control.new()
	_pad.name = "Pad"
	_pad.custom_minimum_size = Vector2(fs * 20.0, fs * 20.0 / ASPECT)
	_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	_pad.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_pad.gui_input.connect(_on_pad_input)
	_pad.draw.connect(func() -> void: _draw_pad(_pad, strokes, true))
	_pad.resized.connect(func() -> void: _pad.custom_minimum_size.y = _pad.size.x / ASPECT)
	add_child(_pad)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(fs * 0.4))
	var clear := T.button("CLEAR", false, fs - 2)
	clear.pressed.connect(func() -> void:
		strokes.clear()
		_changed())
	row.add_child(clear)
	var cancel := T.button("CANCEL", false, fs - 2)
	cancel.pressed.connect(func() -> void: cancelled.emit())
	row.add_child(cancel)
	_sign = T.button("SIGN", true, fs)
	_sign.name = "Sign"
	_sign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sign.pressed.connect(func() -> void: signed.emit(packed()))
	row.add_child(_sign)
	add_child(row)
	_changed()


## The signature as kept on a paper: [PackedByteArray-like Array of ints per stroke].
func packed() -> Array:
	return pack(strokes)


## Adds a stroke of pad-space points (0..1 across and down): for tests and the capture.
func add_stroke(points: PackedVector2Array) -> void:
	strokes.append(points)
	_changed()


func _on_pad_input(e: InputEvent) -> void:
	var sz := _pad.size
	if sz.x <= 1.0 or sz.y <= 1.0:
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drawing = (e as InputEventMouseButton).pressed
		if _drawing and strokes.size() < MAX_STROKES:
			strokes.append(PackedVector2Array([_norm((e as InputEventMouseButton).position, sz)]))
		_changed()
		_pad.accept_event()
	elif e is InputEventMouseMotion and _drawing and not strokes.is_empty():
		var pts: PackedVector2Array = strokes.back()
		var p := _norm((e as InputEventMouseMotion).position, sz)
		if pts.is_empty() or pts[pts.size() - 1].distance_to(p) > 0.004:
			pts.append(p)
			strokes[strokes.size() - 1] = pts
			_pad.queue_redraw()
		_pad.accept_event()


static func _norm(p: Vector2, sz: Vector2) -> Vector2:
	return Vector2(clampf(p.x / sz.x, 0.0, 1.0), clampf(p.y / sz.y, 0.0, 1.0))


func _changed() -> void:
	if _sign:
		var ink := 0
		for s: PackedVector2Array in strokes:
			ink += s.size()
		_sign.disabled = ink < 6
		_sign.tooltip_text = "Write your signature on the line first." if _sign.disabled else "Sign the paper."
	if _pad:
		_pad.queue_redraw()


## Strokes (pad-space points) as kept on a paper: each stroke an Array of ints 0..255, x then y.
static func pack(src: Array) -> Array:
	var out: Array = []
	var total := 0
	for s: PackedVector2Array in src:
		if out.size() >= MAX_STROKES or total >= MAX_POINTS:
			break
		var a: Array = []
		for p in s:
			if total >= MAX_POINTS:
				break
			a.append(clampi(roundi(p.x * 255.0), 0, 255))
			a.append(clampi(roundi(p.y * 255.0), 0, 255))
			total += 1
		if a.size() >= 2:
			out.append(a)
	return out


## A kept signature, checked (as the host takes it from a player): [] when it is not one.
static func clean(sig: Variant) -> Array:
	if not sig is Array:
		return []
	var out: Array = []
	var total := 0
	for s: Variant in sig:
		if not s is Array or out.size() >= MAX_STROKES:
			continue
		var a: Array = []
		for v: Variant in s:
			if total >= MAX_POINTS * 2:
				break
			a.append(clampi(int(v), 0, 255))
			total += 1
		if a.size() % 2 == 1:
			a.pop_back()
		if a.size() >= 2:
			out.append(a)
	return out


## Draws a kept signature `sig` in a box `size` (on the paper's own colour).
static func view(sig: Array, size: Vector2) -> Control:
	var c := Control.new()
	c.custom_minimum_size = size
	var strokes: Array = []
	for s: Variant in sig:
		var pts := PackedVector2Array()
		var a: Array = s
		for i in range(0, a.size() - 1, 2):
			pts.append(Vector2(float(a[i]) / 255.0, float(a[i + 1]) / 255.0))
		strokes.append(pts)
	c.draw.connect(func() -> void: _draw_pad(c, strokes, false))
	return c


static func _draw_pad(c: Control, strokes: Array, guide: bool) -> void:
	var sz := c.size
	c.draw_rect(Rect2(Vector2.ZERO, sz), PAPER)
	var line_y := sz.y * 0.78
	c.draw_line(Vector2(sz.x * 0.04, line_y), Vector2(sz.x * 0.96, line_y), Color(0.3, 0.3, 0.3, 0.7), 1.0)
	if guide:
		c.draw_string(T.font("mono_medium"), Vector2(sz.x * 0.04, line_y + 14.0), "x  sign here", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(0.3, 0.3, 0.3, 0.8))
	var w := maxf(1.5, sz.y / 45.0)
	for s: PackedVector2Array in strokes:
		if s.size() == 1:
			c.draw_circle(s[0] * sz, w * 0.6, INK)
			continue
		var pts := PackedVector2Array()
		for p in s:
			pts.append(p * sz)
		c.draw_polyline(pts, INK, w, true)
