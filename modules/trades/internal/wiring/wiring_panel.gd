class_name TradesWiringPanel
extends Control
## The wiring diagram's picture, shown on the wiring tool's screen (TradesWiringTablet): the
## plug's diagram on the left (each pin's signal and wire colour), the loom's tails and the
## plug face on the right. Drag a tail's end onto a pin; drag a landed wire off its pin to
## take it back. PLUG IN pushes the plug home and tests every pin; Esc or CLOSE folds the tool
## away (what you landed stays). The station owns it and does the plugging
## (TradesShipJoints.open_wiring).

signal plug_requested
signal close_requested

const T := preload("res://modules/ui/api/terminal_kit.gd")
## The picture's size (pixels).
const CARD := Vector2(1180, 700)

var loom: TradesWireLoom
var title := ""
var board: Board
var _card: PanelContainer
var _status: Label
var _plug: Button
var _clear: Button


func _init(p_loom: TradesWireLoom, p_title: String) -> void:
	loom = p_loom
	title = p_title
	name = "TradesWiring"
	size = CARD
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", T.plate(18.0))
	_card.size = CARD
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_card.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var name_l := T.label(title, "display_bold", 30, T.TEXT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	var close := T.button("CLOSE  %s" % Keys.prompt(Keys.CANCEL), false, 18)
	close.pressed.connect(func() -> void: close_requested.emit())
	head.add_child(close)
	var rule := ColorRect.new()
	rule.color = T.ORANGE
	rule.custom_minimum_size = Vector2(0, 3)
	col.add_child(rule)
	board = Board.new()
	board.loom = loom
	board.custom_minimum_size = Vector2(0, 520)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.changed.connect(_refresh)
	col.add_child(board)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	col.add_child(foot)
	_status = T.label("", "body_medium", 20, T.DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_status)
	_clear = T.button("CLEAR", false, 20)
	_clear.pressed.connect(func() -> void:
		loom.clear()
		_refresh())
	foot.add_child(_clear)
	_plug = T.button("PLUG IN AND TEST", true, 22)
	_plug.pressed.connect(func() -> void: plug_requested.emit())
	foot.add_child(_plug)
	_refresh()


## Called by the station after the plug went in, and whenever the wires change.
func _refresh() -> void:
	var locked := loom.tested
	board.locked = locked
	_plug.disabled = locked or not loom.all_landed()
	_clear.disabled = locked or loom.landed_count() == 0
	_status.text = status_text()
	_status.add_theme_color_override("font_color", T.DIM if not locked else (T.GOOD if loom.is_right() else T.BAD))
	board.queue_redraw()


func status_text() -> String:
	if loom.tested:
		if loom.is_right():
			return "Plugged in. All %d pins test good." % loom.pins.size()
		var bad: PackedStringArray = []
		var ok := loom.pins_ok()
		for p in ok.size():
			if not ok[p]:
				bad.append(str(p + 1))
		return "Plugged in, but pin%s %s test open%s. Right click the plug to pull it and rewire." % [
				"s" if bad.size() > 1 else "", ", ".join(bad), " and the supply shorts" if loom.is_short() else ""]
	if loom.all_landed():
		return "Every wire is on a pin. Plug it in to test."
	return "Drag each wire onto its pin, as the diagram shows. %d of %d on." % [loom.landed_count(), loom.pins.size()]


## The diagram and the work: drawn by hand so the wires can bend to the pointer.
class Board:
	extends Control

	signal changed

	const DIAGRAM_W := 440.0
	const ROW := 66.0
	const TOP := 66.0
	const TAIL_X := 520.0
	const END_X := 600.0
	const PIN_X := 1000.0
	const GRAB_PX := 22.0
	const DROP_PX := 30.0
	const WIRE_W := 9.0

	var loom: TradesWireLoom
	var locked := false
	## The wire being dragged (-1 none) and where the pointer is.
	var dragging := -1
	var pointer := Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true

	func _row_y(i: int) -> float:
		return TOP + 40.0 + i * ROW

	## Where wire w's free end sits while it hangs loose.
	func end_at(w: int) -> Vector2:
		return Vector2(END_X, _row_y(loom.order.find(w)))

	func tail_root(w: int) -> Vector2:
		return Vector2(TAIL_X, _row_y(loom.order.find(w)))

	func pin_at(p: int) -> Vector2:
		return Vector2(PIN_X, _row_y(p))

	func pin_under(at: Vector2, within := DROP_PX) -> int:
		for p in loom.pins.size():
			if at.distance_to(pin_at(p)) < within:
				return p
		return -1

	## The wire whose free end (or landed end) is under the pointer, or -1.
	func wire_under(at: Vector2) -> int:
		for w in loom.pins.size():
			var e := pin_at(loom.landed[w]) if loom.landed[w] >= 0 else end_at(w)
			if at.distance_to(e) < GRAB_PX:
				return w
		return -1

	## Drag a wire onto a pin (tests drive this; the mouse goes through it too).
	func drop(w: int, at: Vector2) -> void:
		var p := pin_under(at)
		if p >= 0:
			loom.land(w, p)
			Sfx.press(self, -6.0)
		else:
			loom.lift(w)
		dragging = -1
		changed.emit()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			pointer = (event as InputEventMouseMotion).position
			if dragging >= 0:
				queue_redraw()
		elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var b := event as InputEventMouseButton
			pointer = b.position
			if locked:
				return
			if b.pressed:
				dragging = wire_under(b.position)
				queue_redraw()
			elif dragging >= 0:
				drop(dragging, b.position)
			accept_event()

	func _draw() -> void:
		var mono := T.font("mono_medium")
		var bold := T.font("display_bold")
		var body := T.font("body_medium")
		# --- The diagram: a printed sheet, a row per pin.
		draw_rect(Rect2(0, 0, DIAGRAM_W, size.y), T.DOCKET)
		draw_string(bold, Vector2(20, 40), "WIRING DIAGRAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, T.INK)
		draw_string(mono, Vector2(20, 62), "%s PLUG  %s" % [loom.kind.to_upper(), loom.joint_id.to_upper()],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, T.INK_DIM)
		for p in loom.pins.size():
			var y := _row_y(p)
			var c: StringName = loom.pins[p].colour
			_wire_line(Vector2(24, y), Vector2(150, y), c, 7.0)
			draw_string(mono, Vector2(24, y + 26), TradesWireLoom.colour_name(c), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, T.INK_DIM)
			draw_line(Vector2(150, y), Vector2(250, y), T.INK, 2.0)
			draw_circle(Vector2(256, y), 6.0, T.INK)
			draw_string(bold, Vector2(272, y + 9), "PIN %d" % (p + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, T.INK)
			draw_string(body, Vector2(350, y + 8), String(loom.pins[p].signal), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, T.INK)
		# --- The work: the loom coming in on the left, the plug face on the right.
		draw_rect(Rect2(DIAGRAM_W + 20, 0, size.x - DIAGRAM_W - 20, size.y), Color(T.KIOSK, 0.9))
		draw_string(bold, Vector2(DIAGRAM_W + 40, 40), "LOOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, T.DIM)
		draw_string(bold, Vector2(PIN_X - 60, 40), "PLUG", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, T.DIM)
		var face := Rect2(PIN_X - 44, TOP + 4, 120, _row_y(loom.pins.size() - 1) - TOP + 36)
		draw_rect(face, T.PLATE_HI)
		draw_rect(face, T.EDGE, false, 3.0)
		var ok := loom.pins_ok()
		for p in loom.pins.size():
			var at := pin_at(p)
			var ring := T.STEEL
			if loom.tested:
				ring = T.GOOD if ok[p] else T.BAD
			elif dragging >= 0 and pin_under(pointer) == p:
				ring = T.ORANGE_HI
			draw_circle(at, 17.0, T.EDGE)
			draw_circle(at, 14.0, ring)
			draw_circle(at, 8.0, Color(0.72, 0.6, 0.3))
			draw_string(bold, at + Vector2(26, 9), str(p + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, T.TEXT)
		# The bundle: every tail leaves the sheath at the left edge.
		var sheath := Rect2(DIAGRAM_W + 30, TOP + 20, 30, _row_y(loom.pins.size() - 1) - TOP + 40)
		draw_rect(sheath, Color(0.1, 0.1, 0.11))
		for w: int in loom.order:
			var root := tail_root(w)
			_wire_line(Vector2(sheath.end.x, root.y), root, loom.pins[w].colour, WIRE_W)
			var end := end_at(w)
			if dragging == w:
				end = pointer
			elif loom.landed[w] >= 0:
				end = pin_at(loom.landed[w])
			_curve(root, end, loom.pins[w].colour)
			# The crimped ferrule on the end, the handle you drag.
			draw_circle(end, 9.0, Color(0.85, 0.86, 0.88))
			draw_circle(end, 4.0, T.EDGE)

	func _curve(a: Vector2, b: Vector2, c: StringName) -> void:
		var pts := PackedVector2Array()
		var dx := maxf(60.0, absf(b.x - a.x) * 0.5)
		for i in 25:
			var t := i / 24.0
			var p0 := a
			var p1 := a + Vector2(dx, 0)
			var p2 := b - Vector2(dx, 0)
			var p3 := b
			var u := 1.0 - t
			pts.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
		draw_polyline(pts, Color(0.55, 0.58, 0.62, 0.55), WIRE_W + 3.0, true)
		draw_polyline(pts, TradesWireLoom.colour_of(c), WIRE_W, true)
		var stripe := TradesWireLoom.stripe_of(c)
		if stripe.a > 0.0:
			# A tracer stripe: dashes down the middle.
			for i in range(0, 24, 2):
				draw_line(pts[i], pts[i + 1], stripe, WIRE_W * 0.4)

	func _wire_line(a: Vector2, b: Vector2, c: StringName, width: float) -> void:
		draw_line(a, b, Color(0.55, 0.58, 0.62, 0.55) if a.x > DIAGRAM_W else Color(0, 0, 0, 0.5), width + 3.0)
		draw_line(a, b, TradesWireLoom.colour_of(c), width)
		var stripe := TradesWireLoom.stripe_of(c)
		if stripe.a > 0.0:
			var n := int(a.distance_to(b) / 12.0)
			for i in range(0, n, 2):
				draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), stripe, width * 0.4)
