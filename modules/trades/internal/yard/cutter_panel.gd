class_name TradesCutterPanel
extends Control
## The cutting bed's console screen (on a TouchScreen at the machine's front corner): down the
## left your saved configs (plates saved off a ship with the scribe) with their sizes, then the
## bed's own stored sizes; on the right the bed drawn with the plate on it and the picked
## config laid where it will be cut, the plate's and the cut's figures, and ROTATE, DELETE (a
## saved config) and START. Look at it and click, like every screen in the yard.
## With a beam bar on the bed (trades.beam_cutting) the left side is the lengths: the next
## length, nudged by the steps, its two ends (square or mitred), ADD, and the cut list (click one
## to take it off); the right draws the bar with its cuts, and CLEAR and START.

const BG := Color(0.04, 0.06, 0.07)
const INK := Color(0.78, 0.95, 0.9)
const DIM := Color(0.4, 0.55, 0.52)
const AMBER := Color(1.0, 0.68, 0.15)
const RED := Color(1.0, 0.35, 0.3)
const GREEN := Color(0.35, 1.0, 0.55)

var bed: Node  # TradesCuttingBed
var _list: VBoxContainer
var _preview: Control
var _info: Label
var _status: Label
var _cut: Button
var _delete: Button
var _rotate: Button
## The next beam length the console will add: millimetres and its ends (degrees).
var entry_mm := 1000
var entry_a := 0.0
var entry_b := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_top = 18
	root.offset_right = -24
	root.offset_bottom = -18
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var head := _label("BSX  ·  CNC CUTTING TABLE   PLASMA / WATER JET", 30, AMBER)
	root.add_child(head)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(390, 0)
	body.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	_preview = Control.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.draw.connect(_draw_preview)
	right.add_child(_preview)
	_info = _label("", 21, INK)
	right.add_child(_info)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	right.add_child(buttons)
	_rotate = _button("ROTATE 90°", func() -> void: bed.call("rotate_quarter"))
	buttons.add_child(_rotate)
	_delete = _button("DELETE", _delete_picked)
	buttons.add_child(_delete)
	_cut = _button("START", _press_cut)
	_cut.custom_minimum_size = Vector2(220, 64)
	buttons.add_child(_cut)
	_status = _label("", 24, GREEN)
	root.add_child(_status)
	refresh()


## Everything again from the bed and the templates.
func refresh() -> void:
	if _list == null or bed == null:
		return
	for c in _list.get_children():
		# Out now, so the new buttons keep their names.
		_list.remove_child(c)
		c.queue_free()
	if bed.call("is_beam"):
		_refresh_lengths()
		return
	_rotate.visible = true
	_delete.text = "DELETE"
	var bus := Modules.bus("trades")
	var templates: Array = bus.call("templates") if bus and bus.has_method("templates") else []
	var saved := templates.filter(func(t: Dictionary) -> bool: return str(t.kind) == "traced")
	_list.add_child(_label("YOUR SAVED CONFIGS", 22, AMBER))
	if saved.is_empty():
		var none := _label("None yet. Point the scribe at a plate\nof a ship and click to save one.", 18, DIM)
		_list.add_child(none)
	for t: Dictionary in saved:
		_list.add_child(_config_button(t))
	_list.add_child(_label("STORED SIZES", 22, DIM))
	for t: Dictionary in templates:
		if str(t.kind) != "traced":
			_list.add_child(_config_button(t))
	var plate: Dictionary = bed.get("plate")
	var job: Dictionary = bed.get("job")
	var picked := str(bed.get("picked"))
	var t: Dictionary = bed.call("template", picked)
	var lines := PackedStringArray()
	if plate.is_empty():
		lines.append("PLATE   none: beam a stock plate onto the bed")
	else:
		var s: Vector2 = plate.size
		lines.append("PLATE   %s  %d x %d x %d mm" % [str(plate.material).to_upper(), roundi(s.x * 1000.0), roundi(s.y * 1000.0), roundi(float(plate.thickness) * 1000.0)])
		lines.append("HEAD    %s" % ("WATER JET (glass)" if bed.call("is_glass") else "PLASMA"))
	if not t.is_empty():
		var area := TradesPlateShapes.area_of(t)
		lines.append("CUT     %s, %.2f m², %.1f m of kerf" % [str(t.name), area, TradesPlateShapes.perimeter_of(t.outline)])
		if not plate.is_empty():
			var feed: float = bed.call("_feed")
			lines.append("FEED    %d mm/min,  about %d s" % [roundi(feed * 60000.0), ceili(_kerf_m(t) / feed)])
	_info.text = "\n".join(lines)
	var why: String = bed.call("refusal", picked)
	if not job.is_empty():
		var steps: Array = job.program
		_status.text = "CUTTING  %d%%" % roundi(100.0 * int(job.step) / maxf(steps.size(), 1))
		_status.add_theme_color_override("font_color", AMBER)
	elif why == "":
		_status.text = "READY  ·  press START"
		_status.add_theme_color_override("font_color", GREEN)
	else:
		var made: PackedStringArray = bed.get("made")
		_status.text = ("DONE  ·  the piece and the offcut are on the bed.  " if not made.is_empty() and plate.is_empty() else "") + why.to_upper()
		_status.add_theme_color_override("font_color", RED if why != "No plate on the bed" else DIM)
	_cut.disabled = why != ""
	_delete.disabled = t.is_empty() or str(t.kind) != "traced" or not job.is_empty()
	_rotate.disabled = not job.is_empty()
	_preview.queue_redraw()


func _process(_delta: float) -> void:
	if bed and not (bed.get("job") as Dictionary).is_empty() and Engine.get_process_frames() % 10 == 0:
		refresh()


## A config in the list: its name, its size and (a saved one) its number.
func _config_button(t: Dictionary) -> Button:
	var id := str(t.id)
	var size: Vector2 = t.size
	var b := _button("%s%s\n%d x %d mm" % ["%s  " % id if t.kind == "traced" else "", str(t.name), roundi(size.x * 1000.0), roundi(size.y * 1000.0)],
			func() -> void: bed.call("pick", id))
	b.name = "Config_" + id.validate_node_name()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(360, 66)
	b.add_theme_font_size_override("font_size", 19)
	if id == str(bed.get("picked")):
		b.add_theme_color_override("font_color", AMBER)
		b.add_theme_color_override("font_hover_color", AMBER)
	return b


func _kerf_m(t: Dictionary) -> float:
	var m := TradesPlateShapes.perimeter_of(t.outline)
	for h: PackedVector2Array in t.get("holes", []):
		m += TradesPlateShapes.perimeter_of(h)
	return m


## The lengths screen for a bar on the bed.
func _refresh_lengths() -> void:
	var plate: Dictionary = bed.get("plate")
	var job: Dictionary = bed.get("job")
	var list: Array = bed.get("lengths")
	_list.add_child(_label("NEXT LENGTH", 22, AMBER))
	var length := _label("%d mm" % entry_mm, 40, INK)
	length.name = "EntryLength"
	_list.add_child(length)
	var steps := GridContainer.new()
	steps.columns = 3
	steps.add_theme_constant_override("h_separation", 8)
	steps.add_theme_constant_override("v_separation", 8)
	_list.add_child(steps)
	for by: int in [-1000, -100, -10, 1000, 100, 10]:
		var b := _small("%+d" % by, func() -> void: nudge(by))
		b.name = "Step_%s%d" % ["m" if by < 0 else "p", absi(by)]
		steps.add_child(b)
	var ends := HBoxContainer.new()
	ends.add_theme_constant_override("separation", 8)
	_list.add_child(ends)
	var ea := _small("END A  %s" % _end_word(entry_a), func() -> void: toggle_end(0))
	ea.name = "EndA"
	ea.custom_minimum_size = Vector2(180, 54)
	ends.add_child(ea)
	var eb := _small("END B  %s" % _end_word(entry_b), func() -> void: toggle_end(1))
	eb.name = "EndB"
	eb.custom_minimum_size = Vector2(180, 54)
	ends.add_child(eb)
	var add := _button("ADD", _press_add)
	add.name = "AddLength"
	add.custom_minimum_size = Vector2(368, 58)
	add.disabled = not job.is_empty()
	_list.add_child(add)
	_list.add_child(_label("CUT LIST  (click one to take it off)", 20, DIM))
	if list.is_empty():
		_list.add_child(_label("Nothing yet.", 18, DIM))
	for i in list.size():
		var e: Dictionary = list[i]
		var row := _small("%d.  %d mm   %s / %s" % [i + 1, int(e.mm), _end_word(float(e.a)), _end_word(float(e.b))],
				func() -> void: bed.call("remove_length", i))
		row.name = "Length_%d" % i
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(368, 46)
		row.disabled = not job.is_empty()
		_list.add_child(row)
	var s: Vector2 = plate.size
	var lines := PackedStringArray()
	lines.append("BAR     %s %s  %d mm long" % [str(plate.material).to_upper(), StockBeams.family(str(plate.beam_family)).get("display_name", plate.beam_family),
			roundi(s.x * 1000.0)])
	lines.append("        %d x %d x %d mm section" % [roundi(s.y * 1000.0), roundi(float(plate.thickness) * 1000.0), roundi(float(plate.wall) * 1000.0)])
	var lay := TradesBeamCuts.layout(plate, list)
	if not list.is_empty():
		if lay.is_empty():
			lines.append("USED    the list is longer than the bar")
		else:
			lines.append("USED    %d mm in %d pieces,  %d mm left" % [roundi(float(lay.used_m) * 1000.0), list.size(), roundi(float(lay.left_m) * 1000.0)])
			var feed: float = bed.call("_feed")
			lines.append("CUTS    %d across the bar,  about %d s" % [(lay.cuts as Array).size(), ceili((lay.cuts as Array).size() * (s.y + 0.06) / feed)])
	_info.text = "\n".join(lines)
	var why: String = bed.call("length_refusal")
	if not job.is_empty():
		var program: Array = job.program
		_status.text = "CUTTING  %d%%" % roundi(100.0 * int(job.step) / maxf(program.size(), 1))
		_status.add_theme_color_override("font_color", AMBER)
	elif why == "":
		_status.text = "READY  ·  press START"
		_status.add_theme_color_override("font_color", GREEN)
	else:
		_status.text = why.to_upper()
		_status.add_theme_color_override("font_color", RED if why != "Add a length" else DIM)
	_cut.disabled = why != ""
	_rotate.visible = false
	_delete.text = "CLEAR"
	_delete.disabled = list.is_empty() or not job.is_empty()
	_preview.queue_redraw()


func nudge(by: int) -> void:
	entry_mm = clampi(entry_mm + by, 50, 12000)
	refresh()


## Steps an end through square, 45, 30 and 60 degrees.
func toggle_end(which: int) -> void:
	var m := TradesBeamCuts.MITRES
	if which == 0:
		entry_a = m[(m.find(entry_a) + 1) % m.size()]
	else:
		entry_b = m[(m.find(entry_b) + 1) % m.size()]
	refresh()


static func _end_word(deg: float) -> String:
	return "SQUARE" if deg == 0.0 else "%d°" % roundi(deg)


func _press_add() -> void:
	var why: String = bed.call("add_length", entry_mm, entry_a, entry_b)
	if why != "":
		_status.text = why.to_upper()
		_status.add_theme_color_override("font_color", RED)


func _small(text: String, pressed: Callable) -> Button:
	var b := _button(text, pressed)
	b.custom_minimum_size = Vector2(117, 54)
	b.add_theme_font_size_override("font_size", 19)
	return b


func _press_cut() -> void:
	if bed.call("is_beam"):
		var why_beam: String = bed.call("cut_lengths")
		if why_beam != "":
			_status.text = why_beam.to_upper()
		return
	var why: String = bed.call("cut")
	if why != "":
		_status.text = why.to_upper()


func _delete_picked() -> void:
	if bed.call("is_beam"):
		bed.call("clear_lengths")
		return
	var bus := Modules.bus("trades")
	if bus and bus.has_method("remove_template"):
		bus.call("remove_template", str(bed.get("picked")))
	bed.call("pick", "")


## The bed from above: its slats, the plate, and the template where it will be cut (the cut
## so far in amber while it runs).
func _draw_preview() -> void:
	var r := Rect2(Vector2.ZERO, _preview.size)
	_preview.draw_rect(r, Color(0.02, 0.03, 0.035))
	var half: Vector2 = TradesCuttingBed.HALF
	var scale := minf((r.size.x - 20.0) / (half.x * 2.0), (r.size.y - 20.0) / (half.y * 2.0))
	var mid := r.get_center()
	var to := func(p: Vector2) -> Vector2: return mid + p * scale
	var x := -half.x
	while x <= half.x:
		_preview.draw_line(to.call(Vector2(x, -half.y)), to.call(Vector2(x, half.y)), Color(0.15, 0.18, 0.2), 2.0)
		x += 0.16
	var plate: Dictionary = bed.get("plate")
	if not plate.is_empty():
		var s: Vector2 = plate.size
		_preview.draw_rect(Rect2(to.call(-s * 0.5), s * scale), Color(0.35, 0.38, 0.4, 0.8))
	if bed.call("is_beam"):
		_draw_bar(to)
		return
	var t: Dictionary = bed.call("template", str(bed.get("picked")))
	var job: Dictionary = bed.get("job")
	if not job.is_empty():
		t = job.shape
	elif not t.is_empty():
		t = TradesPlateShapes.make_turned(t, float(bed.get("turn")))
		if not plate.is_empty():
			var extra := TradesPlateShapes.fit_turn(t, plate.size)
			if extra > 0.0:
				t = TradesPlateShapes.make_turned(t, extra)
	if t.is_empty():
		return
	for loop: PackedVector2Array in TradesPlateShapes.cut_path(t, 0.0):
		var pts := PackedVector2Array()
		for p in loop:
			pts.append(to.call(p))
		_preview.draw_polyline(pts, AMBER if not job.is_empty() else INK, 3.0, true)
	if not job.is_empty():
		var head: Vector2 = bed.get("head")
		_preview.draw_circle(to.call(head), 7.0, Color(0.6, 0.85, 1.0))


## A bar's cut list: the pieces shaded in turn, each cut line, and the head while it runs.
func _draw_bar(to: Callable) -> void:
	var plate: Dictionary = bed.get("plate")
	var job: Dictionary = bed.get("job")
	var lay: Dictionary = job.layout if not job.is_empty() else TradesBeamCuts.layout(plate, bed.get("lengths"))
	if lay.is_empty():
		return
	var w: float = (plate.size as Vector2).y
	var k := 0
	for pc: Dictionary in lay.pieces:
		var x0 := float(pc.from)
		var x1 := x0 + int(pc.mm) / 1000.0
		var ta := tan(deg_to_rad(float(pc.a))) * w
		var tb := tan(deg_to_rad(float(pc.b))) * w
		var quad := PackedVector2Array([to.call(Vector2(x0, -w * 0.5)), to.call(Vector2(x1, -w * 0.5)),
				to.call(Vector2(x1 - tb, w * 0.5)), to.call(Vector2(x0 + ta, w * 0.5))])
		_preview.draw_colored_polygon(quad, Color(0.3, 0.75, 0.65, 0.35 if k % 2 == 0 else 0.2))
		k += 1
	for c: Array in lay.cuts:
		_preview.draw_line(to.call(c[0]), to.call(c[1]), AMBER if not job.is_empty() else INK, 3.0, true)
	if not job.is_empty():
		var head: Vector2 = bed.get("head")
		_preview.draw_circle(to.call(head), 7.0, Color(0.6, 0.85, 1.0))


func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


func _button(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 64)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(pressed)
	return b
