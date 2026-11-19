extends RefCounted
## What a drawing adds over the design itself (plan 3.2 to 3.4), for one PlanView:
##   - printed dimensions: the design's overall length and beam (or height) outside the drawing,
##     each room's width and depth inside it, and a title block in the corner (3.2);
##   - a small bar of marks in the drawing's top corner (any view, the console's or a wall's):
##       MEASURE  a tape between any points, each leg and the running total (Esc or MEASURE again
##                clears it),
##       SECTION  a click on a plan throws a section line across the ship there (Shift: along it)
##                onto the holotable as a cutting plane; SECTION again takes it off,
##       NOTE     a click pins a note to the ship there (type it, Enter); a click on a note takes it
##                off,
##       LOOK     "look here": a click pulls everyone's drawings to that spot (3.3, 3.4);
##   - a readout of the room under the pointer: its ID, area and volume (3.4).

const T := preload("res://modules/ui/api/terminal_kit.gd")

const ACTIONS := [["measure", "MEASURE"], ["section", "SECTION"], ["note", "NOTE"], ["look", "LOOK HERE"]]
const TAPE := Color("ffd166")
const SECTION := Color("ff6fd8")
const NOTE := Color("9be564")
## How long a "look here" mark stays on the drawings, s.
const LOOK_SECONDS := 4.0

var view: Control
## The mark armed by the bar ("" none): the next click on the drawing is it.
var action := ""
## The tape's points (ship space, this view's deck) and where the pointer is now.
var tape: Array[Vector2] = []
var tape_deck := 0
var pointer := Vector2.INF
## The room under the pointer, for the readout ("" none).
var hover := ""
## The last "look here": {deck, at, who, colour, until (msec)}.
var look := {}
var bar: HBoxContainer
var _buttons: Dictionary = {}
var _note_edit: LineEdit
var _note_at := Vector2.ZERO


func _init(owner: Control) -> void:
	view = owner


## The bar of marks, added over the drawing's top right corner.
func build_bar(font_size: int) -> void:
	bar = HBoxContainer.new()
	bar.name = "Marks"
	bar.add_theme_constant_override("separation", 4)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.position = Vector2(-8, 8)
	for spec: Array in ACTIONS:
		var b := T.button(spec[1], false, font_size)
		b.name = "Mark_" + str(spec[0])
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(press_action.bind(str(spec[0])))
		bar.add_child(b)
		_buttons[spec[0]] = b
	view.add_child(bar)
	_mark_buttons()


## A bar button: arms that mark (or, pressed again, disarms it; SECTION and MEASURE pressed
## with nothing armed and one showing take theirs off).
func press_action(what: String) -> void:
	if action == what:
		action = ""
		if what == "measure":
			tape = []
	elif what == "section" and not view.bus.section.is_empty() and action == "":
		view.bus.set_section("")
	elif what == "measure" and not tape.is_empty() and action == "":
		tape = []
	else:
		action = what
		if what == "measure":
			tape = []
	_close_note()
	_mark_buttons()
	view.queue_redraw()


func _mark_buttons() -> void:
	for k: String in _buttons:
		var b := _buttons[k] as Button
		var on: bool = action == k or k == "section" and not view.bus.section.is_empty() \
				or k == "measure" and not tape.is_empty()
		b.add_theme_stylebox_override("normal", T.box(T.PLATE_HI if on else T.PLATE, T.ORANGE if on else T.EDGE, 2, 6.0))
	if bar:
		bar.visible = view.mode == "plan"


## Esc: drops the armed mark and the tape. False if there was nothing to drop.
func cancel() -> bool:
	if action == "" and tape.is_empty() and _note_edit == null:
		return false
	action = ""
	tape = []
	_close_note()
	_mark_buttons()
	view.queue_redraw()
	return true


## A click on the drawing with a mark armed: true if the mark took it.
func press(s: Vector2, shift := false) -> bool:
	if action == "" or view.mode != "plan":
		return false
	var rec: DesignRecord = view._rec()
	var p: Vector2 = view.to_ship(s)
	var deck: int = view.deck
	match action:
		"measure":
			if tape.is_empty() or tape_deck != deck:
				tape = []
				tape_deck = deck
			tape.append(_snap(rec, p))
		"section":
			var q := _snap(rec, p)
			view.bus.set_section("x" if shift else "z", q.x if shift else q.y)
			action = ""
		"note":
			var hit := note_at(rec, s)
			if hit != "":
				view.bus.editor.do({"op": "remove_pin", "id": hit})
			else:
				_open_note(_snap(rec, p), s)
			action = ""
		"look":
			view.bus.look_here(deck, p)
			action = ""
	_mark_buttons()
	view.queue_redraw()
	return true


## The tape's length so far, m.
func tape_total() -> float:
	var total := 0.0
	for i in range(1, tape.size()):
		total += tape[i - 1].distance_to(tape[i])
	return total


static func _snap(rec: DesignRecord, p: Vector2) -> Vector2:
	var g := minf(rec.grid, 0.25) if rec else 0.25
	return p.snapped(Vector2(g, g))


## Pointer moved over the drawing: true if the drawing should be redrawn.
func moved(s: Vector2) -> bool:
	pointer = view.to_ship(s)
	var redraw := action == "measure" and not tape.is_empty() or action != ""
	var rec: DesignRecord = view._rec()
	var was := hover
	hover = rec.room_at(view.deck, pointer) if rec and view.mode == "plan" else ""
	return redraw or hover != was


func pointer_left() -> void:
	pointer = Vector2.INF
	if hover != "":
		hover = ""
		view.queue_redraw()


## The note pinned near screen point `s` on this deck ("" none).
func note_at(rec: DesignRecord, s: Vector2) -> String:
	for n: Dictionary in rec.pins.values():
		if int(n.deck) == view.deck and view.to_screen(Vector2(float(n.x), float(n.z))).distance_to(s) < 12.0:
			return str(n.id)
	return ""


func _open_note(at: Vector2, s: Vector2) -> void:
	_close_note()
	_note_at = at
	_note_edit = LineEdit.new()
	_note_edit.name = "NoteEdit"
	_note_edit.placeholder_text = "Note, then Enter"
	_note_edit.custom_minimum_size = Vector2(260, 0)
	_note_edit.position = s + Vector2(12, -12)
	_note_edit.text_submitted.connect(func(t: String) -> void: add_note(t))
	view.add_child(_note_edit)
	_note_edit.grab_focus()


## The open note box's text pinned where it was opened.
func add_note(text: String) -> void:
	if text.strip_edges() != "":
		view.bus.editor.do({"op": "add_pin", "pin": {"deck": view.deck, "x": _note_at.x, "z": _note_at.y,
				"text": text}})
	_close_note()


func _close_note() -> void:
	if _note_edit and is_instance_valid(_note_edit):
		_note_edit.queue_free()
	_note_edit = null


func on_look(deck: int, at: Vector2, who: String, colour: Color) -> void:
	look = {"deck": deck, "at": at, "who": who, "colour": colour, "until": Time.get_ticks_msec() + int(LOOK_SECONDS * 1000.0)}


# Drawing

func draw(rec: DesignRecord) -> void:
	if view.mode == "plan":
		_draw_room_dims(rec)
	_draw_overall(rec)
	_draw_section(rec)
	if view.mode == "plan":
		_draw_notes(rec)
		_draw_tape()
		_draw_hover(rec)
	_draw_look()
	_mark_buttons()


## Each room's width along its top side and depth down its left, where there's room to print.
func _draw_room_dims(rec: DesignRecord) -> void:
	var fs := clampi(int(view.zoom * 0.32), 9, 13)
	for r in rec.rooms_on(view.deck):
		var box := Rect2(view.to_screen(Vector2(r.x, r.z)), Vector2(r.w, r.d) * view.zoom)
		if box.size.x < 70 or box.size.y < 50:
			continue
		var w := "%s m" % view._m(float(r.w))
		var d := "%s m" % view._m(float(r.d))
		var tw: float = view._font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		view._text(Vector2(box.get_center().x - tw * 0.5, box.end.y - 6), w, view.DIM, fs)
		view.draw_set_transform(Vector2(box.end.x - 6, box.get_center().y), -PI * 0.5)
		var td: float = view._font.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		view._text(Vector2(-td * 0.5, 0), d, view.DIM, fs)
		view.draw_set_transform(Vector2.ZERO)


## The overall size outside the drawing: length and beam on a plan (this deck's rooms and hull),
## length or beam and height on an elevation, with extension lines and ticks.
func _draw_overall(rec: DesignRecord) -> void:
	var b := Rect2()
	var first := true
	for r: Dictionary in rec.rooms.values():
		if view.mode == "plan" and int(r.deck) != view.deck:
			continue
		var rr: Rect2 = view._room_view_rect(rec, r)
		b = rr if first else b.merge(rr)
		first = false
	if view.mode == "plan":
		for p in rec.hull_outline(view.deck):
			b = Rect2(p, Vector2.ZERO) if first else b.expand(p)
			first = false
	if first or b.size.x < 0.1:
		return
	var sb := Rect2(view.to_screen(b.position), b.size * view.zoom)
	var col := Color(view.INK, 0.8)
	var fs := 12
	# Along the bottom: x on a plan or an end view, z on a side view.
	var y := sb.end.y + 22
	view.draw_line(Vector2(sb.position.x, sb.end.y + 4), Vector2(sb.position.x, y + 6), Color(col, 0.4), 1.0)
	view.draw_line(Vector2(sb.end.x, sb.end.y + 4), Vector2(sb.end.x, y + 6), Color(col, 0.4), 1.0)
	_dim_line(Vector2(sb.position.x, y), Vector2(sb.end.x, y), col)
	var across := "%s m" % view._m(snappedf(b.size.x, 0.01))
	var tw: float = view._font.get_string_size(across, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	view.draw_rect(Rect2(sb.get_center().x - tw * 0.5 - 4, y - 9, tw + 8, 16), view.BG)
	view._text(Vector2(sb.get_center().x - tw * 0.5, y + 4), across, col, fs)
	# Up the left: z on a plan, height on an elevation.
	var x := sb.position.x - 22
	view.draw_line(Vector2(sb.position.x - 4, sb.position.y), Vector2(x - 6, sb.position.y), Color(col, 0.4), 1.0)
	view.draw_line(Vector2(sb.position.x - 4, sb.end.y), Vector2(x - 6, sb.end.y), Color(col, 0.4), 1.0)
	_dim_line(Vector2(x, sb.position.y), Vector2(x, sb.end.y), col)
	var down := "%s m" % view._m(snappedf(b.size.y, 0.01))
	var th: float = view._font.get_string_size(down, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	view.draw_set_transform(Vector2(x, sb.get_center().y), -PI * 0.5)
	view.draw_rect(Rect2(-th * 0.5 - 4, -9, th + 8, 16), view.BG)
	view._text(Vector2(-th * 0.5, 4), down, col, fs)
	view.draw_set_transform(Vector2.ZERO)


func _dim_line(a: Vector2, b: Vector2, col: Color) -> void:
	view.draw_line(a, b, col, 1.0)
	var n := (b - a).normalized()
	var t := Vector2(-n.y, n.x)
	for p in [a, b]:
		view.draw_line(p - (n + t) * 4.0, p + (n + t) * 4.0, col, 1.5)


## The section line across the drawing (on a plan; on the elevation it cuts across, a line too).
func _draw_section(rec: DesignRecord) -> void:
	var sec: Dictionary = view.bus.section
	if sec.is_empty():
		return
	var axis := str(sec.axis)
	var at := float(sec.at)
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	match view.mode:
		"plan":
			if axis == "z":
				a = Vector2(0, view.to_screen(Vector2(0, at)).y)
				b = Vector2(view.size.x, a.y)
			else:
				a = Vector2(view.to_screen(Vector2(at, 0)).x, 0)
				b = Vector2(a.x, view.size.y)
		"side":
			if axis != "z":
				return
			a = Vector2(view.to_screen(Vector2(at, 0)).x, 0)
			b = Vector2(a.x, view.size.y)
		_:
			if axis != "x":
				return
			a = Vector2(view.to_screen(Vector2(at, 0)).x, 0)
			b = Vector2(a.x, view.size.y)
	view.draw_dashed_line(a, b, SECTION, 2.0, 10.0)
	var tag := "SECTION %s %s m" % ["ACROSS AT Z" if axis == "z" else "ALONG AT X", view._m(snappedf(at, 0.01))]
	var pos := (a + Vector2(10, 18)) if a.x < 1.0 else (a + Vector2(6, 40))
	view._text(pos, tag + "   ON THE TABLE", SECTION, 12)


func _draw_notes(rec: DesignRecord) -> void:
	for n: Dictionary in rec.pins.values():
		if int(n.deck) != view.deck:
			continue
		var s: Vector2 = view.to_screen(Vector2(float(n.x), float(n.z)))
		view.draw_circle(s, 6.0, NOTE)
		view.draw_line(s, s + Vector2(10, -14), NOTE, 2.0)
		var text := "%s  %s" % [DesignRecord.tag(str(n.id)), str(n.text)]
		var fs := 13
		var w := minf(view._font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12, 320.0)
		var box := Rect2(s + Vector2(10, -32), Vector2(w, 20))
		view.draw_rect(box, Color(0.05, 0.12, 0.06, 0.92))
		view.draw_rect(box, NOTE, false, 1.5)
		view._text(box.position + Vector2(6, 15), text, Color(0.9, 1.0, 0.85), fs, w - 10)


## The tape: each leg with its length, the total at the last point, and a leg to the pointer.
func _draw_tape() -> void:
	if tape.is_empty() or tape_deck != view.deck:
		return
	var pts := tape.duplicate()
	var live := action == "measure" and pointer != Vector2.INF
	if live:
		pts.append(pointer)
	var total := 0.0
	for i in range(1, pts.size()):
		var a: Vector2 = view.to_screen(pts[i - 1])
		var b: Vector2 = view.to_screen(pts[i])
		var leg: float = (pts[i - 1] as Vector2).distance_to(pts[i])
		total += leg
		view.draw_line(a, b, TAPE if i < tape.size() else Color(TAPE, 0.6), 2.0)
		view._text((a + b) * 0.5 + Vector2(6, -6), "%s m" % view._m(snappedf(leg, 0.01)), TAPE, 12)
	for p in tape:
		view.draw_circle(view.to_screen(p), 4.0, TAPE)
	var end: Vector2 = view.to_screen(pts[pts.size() - 1])
	var label := "TOTAL %s m   %d LEGS" % [view._m(snappedf(total, 0.01)), pts.size() - 1]
	view.draw_rect(Rect2(end + Vector2(10, 6), Vector2(160, 20)), Color(view.BG, 0.9))
	view._text(end + Vector2(14, 21), label, TAPE, 12)


## The room under the pointer: its ID, type, area and volume.
func _draw_hover(rec: DesignRecord) -> void:
	if hover == "" or pointer == Vector2.INF or not rec.rooms.has(hover) or action != "":
		return
	var r: Dictionary = rec.rooms[hover]
	var area := DesignRecord.room_area(r)
	var text := "%s  %s   %s m2   %s m3" % [DesignRecord.tag(hover), view._room_name(r).to_upper(),
			view._m(snappedf(area, 0.1)), view._m(snappedf(area * rec.deck_height, 0.1))]
	var s: Vector2 = view.to_screen(pointer) + Vector2(16, 18)
	var w: float = view._font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12
	s.x = minf(s.x, view.size.x - w - 4)
	view.draw_rect(Rect2(s, Vector2(w, 20)), Color(view.BG, 0.92))
	view.draw_rect(Rect2(s, Vector2(w, 20)), Color(view.DIM, 0.6), false, 1.0)
	view._text(s + Vector2(6, 15), text, view.INK, 12)


## "Look here": rings round the spot for a few seconds, with who asked.
func _draw_look() -> void:
	if look.is_empty() or Time.get_ticks_msec() > int(look.until):
		return
	var at: Vector2 = look.at
	var s := Vector2.ZERO
	if view.mode == "plan":
		if int(look.deck) != view.deck:
			return
		s = view.to_screen(at)
	else:
		var rec: DesignRecord = view._rec()
		var u := at.y if view.mode == "side" else at.x
		s = view.to_screen(Vector2(u, -(int(look.deck) + 0.5) * rec.deck_height))
	var col: Color = look.colour
	var k := float(int(look.until) - Time.get_ticks_msec()) / (LOOK_SECONDS * 1000.0)
	for i in 3:
		var rad := 14.0 + 12.0 * i + 10.0 * (1.0 - k)
		view.draw_arc(s, rad, 0, TAU, 40, Color(col, 0.9 * k), 3.0)
	view._text(s + Vector2(22, -22), "%s: LOOK HERE" % str(look.who).to_upper(), col, 14)


## The title block in the bottom right (3.2): the design, the order it answers, the view, a
## scale bar, the grid, the date, and who drew it.
func draw_title_block(rec: DesignRecord, view_name: String) -> void:
	var w := 380.0
	var h := 92.0
	var box := Rect2(view.size.x - w - 10, view.size.y - h - 10, w, h)
	view.draw_rect(box, Color(view.BG, 0.94))
	view.draw_rect(box, Color(view.INK, 0.7), false, 1.5)
	var mid := box.position.y + 30
	view.draw_line(Vector2(box.position.x, mid), Vector2(box.end.x, mid), Color(view.DIM, 0.6), 1.0)
	view.draw_line(Vector2(box.position.x + w * 0.55, mid), Vector2(box.position.x + w * 0.55, box.end.y), Color(view.DIM, 0.6), 1.0)
	view._text(box.position + Vector2(8, 21), rec.name.to_upper(), view.INK, 16, w - 16)
	var order := str(rec.order.get("title", ""))
	view._text(box.position + Vector2(8, 48), view_name, view.INK, 12, w * 0.55 - 12)
	view._text(box.position + Vector2(8, 64), ("FOR: " + order.to_upper()) if order != "" else "NO SHIP ORDER", view.DIM, 10, w * 0.55 - 12)
	view._text(box.position + Vector2(8, 80), "%d ROOMS  %d PARTS  %d DOORS" % [rec.rooms.size(),
			rec.components.size() + rec.mounts.size(), rec.doors.size()], view.DIM, 10, w * 0.55 - 12)
	var rx := box.position.x + w * 0.55 + 8
	view._text(Vector2(rx, mid + 18), "BSX LTD  DESIGN OFFICE", view.DIM, 10)
	view._text(Vector2(rx, mid + 34), "%s   GRID %s m" % [Time.get_date_string_from_system(), view._m(rec.grid)], view.DIM, 10)
	# A 5 m scale bar, in alternating blocks.
	var bar_m := 5.0
	var px: float = bar_m * view.zoom
	while px > w * 0.4 and bar_m > 1.0:
		bar_m = 1.0 if bar_m <= 2.0 else bar_m * 0.5
		px = bar_m * view.zoom
	var sx := rx
	var sy := mid + 44
	for i in 5:
		var seg := px / 5.0
		view.draw_rect(Rect2(sx + seg * i, sy, seg, 6), view.INK if i % 2 == 0 else Color(view.BG, 1.0))
	view.draw_rect(Rect2(sx, sy, px, 6), view.INK, false, 1.0)
	view._text(Vector2(sx + px + 6, sy + 7), "%s m" % view._m(bar_m), view.DIM, 10)
