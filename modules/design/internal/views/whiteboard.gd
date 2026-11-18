extends PanelContainer
## The design's whiteboard (plan 3.5, first version, beenster 18 Nov: "please start the
## whiteboard in now"): sketch over the design with pens, a highlighter, straight lines and
## boxes, on layers you can add, hide, pick and delete, like Photoshop's. It's part of the
## design record, so it's saved with the design, undone like any edit and, in Wave 3, shared.
##
## Smart touches: the deck plan can show faintly underneath, to sketch over; a pen stroke that
## is nearly straight snaps to a straight line; strokes are thinned as they're drawn.
## Shown as a view on any design wall panel (WallBoard "whiteboard").

const T := preload("res://modules/ui/api/terminal_kit.gd")
const PlanView := preload("res://modules/design/internal/views/plan_view.gd")

## The board's own units: every panel shows this area, fitted and centred.
const BOARD := Vector2(1600, 900)
const TOOLS: PackedStringArray = ["pen", "marker", "line", "box", "erase"]
const TOOL_NAMES := {"pen": "PEN", "marker": "HIGHLIGHT", "line": "LINE", "box": "BOX", "erase": "ERASE"}
const COLOURS: PackedStringArray = ["f2f2ee", "ff9a4d", "6fc8e8", "7fd47a", "ff5a3c", "e8c25a"]
const WIDTHS := [3.0, 7.0]
## A highlighter stroke is this much wider than a pen, and see-through.
const MARKER_WIDTH := 5.0
const MARKER_ALPHA := 0.35
## A pen stroke snaps straight when no point strays further than this share of its length.
const SNAP_STRAIGHT := 0.035
## Points closer than this are thinned out as you draw, board units.
const MIN_STEP := 3.0
## The eraser takes strokes within this of its path, board units.
const ERASE_REACH := 10.0

var bus: DesignBus
var tool := "pen"
var colour := "f2f2ee"
var width := 3.0
var active_layer := ""
var show_plan := false
var plan_deck := 0
var canvas: Control
var plan: PlanView
var _font := 18
var _tool_buttons: Dictionary = {}
var _colour_buttons: Dictionary = {}
var _layer_list: VBoxContainer
var _plan_button: Button
## The stroke being drawn: board-unit points.
var _drawing := PackedVector2Array()
var _down := false


func setup(design_bus: DesignBus, font := 18) -> void:
	bus = design_bus
	_font = font
	add_theme_stylebox_override("panel", T.box(Color(0.03, 0.05, 0.07), Color.TRANSPARENT, 0, font * 0.3))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(font * 0.3))
	add_child(col)
	col.add_child(_toolbar())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(font * 0.4))
	col.add_child(body)
	var stack := Control.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.clip_contents = true
	body.add_child(stack)
	plan = PlanView.new()
	plan.name = "Underlay"
	plan.setup(bus, PlanView.PLAN, false)
	plan.auto_frame = true
	plan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plan.modulate = Color(1, 1, 1, 0.4)
	plan.visible = false
	stack.add_child(plan)
	canvas = Canvas.new()
	canvas.name = "Canvas"
	(canvas as Canvas).board = self
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.gui_input.connect(_canvas_input)
	stack.add_child(canvas)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = font * 9
	side.add_theme_constant_override("separation", int(font * 0.25))
	body.add_child(side)
	side.add_child(T.label("LAYERS", "display_bold", font, T.ORANGE))
	_layer_list = VBoxContainer.new()
	_layer_list.add_theme_constant_override("separation", int(font * 0.2))
	side.add_child(_layer_list)
	var add := T.button("+ LAYER", false, font)
	add.name = "AddLayer"
	add.pressed.connect(add_layer)
	side.add_child(add)
	bus.design_changed.connect(_on_changed)
	tree_exiting.connect(func() -> void:
		if bus.design_changed.is_connected(_on_changed):
			bus.design_changed.disconnect(_on_changed))
	_on_changed()


func record() -> DesignRecord:
	return bus.library.current if bus else null


func _toolbar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_font * 0.3))
	for t in TOOLS:
		var b := T.button(TOOL_NAMES[t], false, _font, t == tool)
		b.name = "Tool_" + t
		b.pressed.connect(set_tool.bind(t))
		_tool_buttons[t] = b
		row.add_child(b)
	row.add_child(_gap())
	for c in COLOURS:
		var b := Button.new()
		b.name = "Colour_" + c
		b.custom_minimum_size = Vector2(_font * 1.6, _font * 1.6)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(set_colour.bind(c))
		_colour_buttons[c] = b
		row.add_child(b)
	_mark_colours()
	row.add_child(_gap())
	for w in WIDTHS:
		var b := T.button("THIN" if w == WIDTHS[0] else "THICK", false, _font)
		b.name = "Width_%d" % int(w)
		b.pressed.connect(func() -> void: width = w)
		row.add_child(b)
	row.add_child(_gap())
	_plan_button = T.button("PLAN UNDER", false, _font)
	_plan_button.name = "PlanUnder"
	_plan_button.pressed.connect(toggle_plan)
	row.add_child(_plan_button)
	var deck := T.button("DECK", false, _font)
	deck.name = "PlanDeck"
	deck.pressed.connect(func() -> void:
		var rec := record()
		var n := (rec.decks()[rec.decks().size() - 1] + 1) if rec else 1
		plan_deck = (plan_deck + 1) % maxi(n, 1)
		plan.deck = plan_deck
		plan.queue_redraw())
	row.add_child(deck)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	var undo := T.button("UNDO", false, _font)
	undo.pressed.connect(func() -> void: bus.editor.undo())
	row.add_child(undo)
	var clear := T.button("CLEAR LAYER", false, _font)
	clear.name = "ClearLayer"
	clear.pressed.connect(clear_layer)
	row.add_child(clear)
	return row


func _gap() -> Control:
	var g := Control.new()
	g.custom_minimum_size.x = _font * 0.6
	return g


func set_tool(t: String) -> void:
	tool = t
	for k in _tool_buttons:
		var b: Button = _tool_buttons[k]
		b.add_theme_stylebox_override("normal", T.box(T.ORANGE if k == t else T.PLATE, T.EDGE, 1, 4.0))


func set_colour(c: String) -> void:
	colour = c
	if tool == "erase":
		set_tool("pen")
	_mark_colours()


func _mark_colours() -> void:
	for c: String in _colour_buttons:
		var b: Button = _colour_buttons[c]
		var on := c == colour
		var st := T.box(Color(c), Color.WHITE if on else Color(0, 0, 0, 0.6), 4 if on else 2, 0.0)
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, st)


func toggle_plan() -> void:
	show_plan = not show_plan
	plan.visible = show_plan
	_plan_button.add_theme_stylebox_override("normal", T.box(T.ORANGE if show_plan else T.PLATE, T.EDGE, 1, 4.0))


## A new layer on top, made the one you draw on.
func add_layer() -> String:
	var rec := record()
	if rec == null:
		return ""
	var id := rec.peek_id("l")
	bus.editor.do({"op": "add_layer", "layer": {"id": id, "name": "Layer %d" % (rec.sketch_layers.size() + 1)}})
	active_layer = id
	_fill_layers()
	return id


## The layer you draw on, made if there's none.
func _layer_for_drawing() -> Array:
	var rec := record()
	if rec.sketch_layers.has(active_layer):
		return [active_layer, []]
	var layers := rec.layers_in_order()
	if not layers.is_empty():
		active_layer = str(layers[layers.size() - 1].id)
		return [active_layer, []]
	var id := rec.peek_id("l")
	active_layer = id
	return [id, [{"op": "add_layer", "layer": {"id": id, "name": "Layer 1"}}]]


func clear_layer() -> void:
	var rec := record()
	var ops: Array = []
	for k: Dictionary in rec.strokes.values():
		if str(k.layer) == active_layer:
			ops.append({"op": "remove_stroke", "id": k.id})
	if not ops.is_empty():
		bus.editor.do({"op": "batch", "ops": ops})


# Drawing

## Where a point on the canvas lands on the board, and back.
func board_rect() -> Rect2:
	var s := canvas.size
	var scale := minf(s.x / BOARD.x, s.y / BOARD.y) if s.x > 0 and s.y > 0 else 1.0
	var sz := BOARD * scale
	return Rect2((s - sz) * 0.5, sz)


func to_board(p: Vector2) -> Vector2:
	var r := board_rect()
	return ((p - r.position) / r.size * BOARD).clamp(Vector2.ZERO, BOARD)


func to_canvas(b: Vector2) -> Vector2:
	var r := board_rect()
	return r.position + b / BOARD * r.size


func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			begin(to_board(event.position))
		else:
			finish()
		canvas.accept_event()
	elif event is InputEventMouseMotion and _down:
		extend(to_board(event.position))
		canvas.accept_event()


func begin(at: Vector2) -> void:
	_down = true
	_drawing = PackedVector2Array([at])
	canvas.queue_redraw()


func extend(at: Vector2) -> void:
	if not _down:
		return
	if tool in ["line", "box"]:
		if _drawing.size() < 2:
			_drawing.append(at)
		else:
			_drawing[1] = at
	elif _drawing[_drawing.size() - 1].distance_to(at) >= MIN_STEP:
		_drawing.append(at)
	canvas.queue_redraw()


## Ends the stroke being drawn and puts it on the board. Returns the new stroke's id, or ""
## (the eraser, or a stroke too short to keep).
func finish() -> String:
	if not _down:
		return ""
	_down = false
	var pts := _drawing
	_drawing = PackedVector2Array()
	canvas.queue_redraw()
	if tool == "erase":
		_erase_along(pts)
		return ""
	if pts.size() < 2:
		if pts.size() == 1:
			pts.append(pts[0] + Vector2(0.5, 0))  # a dot
		else:
			return ""
	if tool == "pen":
		pts = straightened(pts)
	var rec := record()
	var lay := _layer_for_drawing()
	var id := rec.peek_id("k") if (lay[1] as Array).is_empty() else ""
	var ops: Array = lay[1]
	var stroke := {"layer": lay[0], "tool": tool, "colour": colour,
			"width": width * (MARKER_WIDTH if tool == "marker" else 1.0), "points": _to_array(pts)}
	if id != "":
		stroke["id"] = id
	ops.append({"op": "add_stroke", "stroke": stroke})
	var before := rec.strokes.keys()
	bus.editor.do({"op": "batch", "ops": ops} if ops.size() > 1 else ops[0])
	_fill_layers()
	for k in rec.strokes:
		if not k in before:
			return str(k)
	return ""


## A pen stroke that is nearly straight becomes a straight line; otherwise it's thinned.
static func straightened(pts: PackedVector2Array) -> PackedVector2Array:
	var a := pts[0]
	var b := pts[pts.size() - 1]
	var length := a.distance_to(b)
	if length > 40.0 and pts.size() > 2:
		var worst := 0.0
		for p in pts:
			worst = maxf(worst, Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p))
		if worst < length * SNAP_STRAIGHT:
			return PackedVector2Array([a, b])
	return pts


func _erase_along(path: PackedVector2Array) -> void:
	var rec := record()
	var ops: Array = []
	for k: Dictionary in rec.strokes.values():
		var layer: Dictionary = rec.sketch_layers.get(str(k.layer), {})
		if layer.is_empty() or not bool(layer.visible):
			continue
		if _touches(stroke_points(k), path, ERASE_REACH + float(k.width) * 0.5):
			ops.append({"op": "remove_stroke", "id": k.id})
	if not ops.is_empty():
		bus.editor.do({"op": "batch", "ops": ops})


static func _touches(a: PackedVector2Array, b: PackedVector2Array, reach: float) -> bool:
	for p in b:
		if a.size() == 1 and a[0].distance_to(p) < reach:
			return true
		for i in a.size() - 1:
			if Geometry2D.get_closest_point_to_segment(p, a[i], a[i + 1]).distance_to(p) < reach:
				return true
	return false


## A stroke's points as drawn: a box's two corners become its outline.
static func stroke_points(k: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Array in k.get("points", []):
		out.append(Vector2(float(p[0]), float(p[1])))
	if str(k.get("tool", "")) == "box" and out.size() >= 2:
		var a := out[0]
		var b := out[1]
		out = PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y), a])
	return out


static func _to_array(pts: PackedVector2Array) -> Array:
	var out: Array = []
	for p in pts:
		out.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
	return out


# Layers

func _on_changed() -> void:
	canvas.queue_redraw()
	_fill_layers()


func _fill_layers() -> void:
	if _layer_list == null:
		return
	for c in _layer_list.get_children():
		_layer_list.remove_child(c)
		c.queue_free()
	var rec := record()
	if rec == null:
		return
	var layers := rec.layers_in_order()
	if not rec.sketch_layers.has(active_layer) and not layers.is_empty():
		active_layer = str(layers[layers.size() - 1].id)
	if layers.is_empty():
		_layer_list.add_child(T.label("Draw to start Layer 1", "body", int(_font * 0.8), T.DIM))
	layers.reverse()  # top layer first, like Photoshop
	for l in layers:
		var row := HBoxContainer.new()
		row.name = "Layer_" + str(l.id)
		row.add_theme_constant_override("separation", int(_font * 0.2))
		var eye := T.button("ON" if l.visible else "OFF", false, int(_font * 0.8))
		eye.name = "Eye"
		eye.pressed.connect(func() -> void: bus.editor.do({"op": "set_layer", "id": l.id, "fields": {"visible": not bool(l.visible)}}))
		row.add_child(eye)
		var pick := T.button(str(l.name), str(l.id) == active_layer, int(_font * 0.8))
		pick.name = "Pick"
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.pressed.connect(func() -> void:
			active_layer = str(l.id)
			_fill_layers())
		row.add_child(pick)
		var up := T.button("^", false, int(_font * 0.8))
		up.name = "Up"
		up.pressed.connect(raise_layer.bind(str(l.id)))
		row.add_child(up)
		var del := T.button("X", false, int(_font * 0.8))
		del.name = "Delete"
		del.pressed.connect(func() -> void: bus.editor.do({"op": "remove_layer", "id": l.id}))
		row.add_child(del)
		_layer_list.add_child(row)


## Swaps a layer with the one above it.
func raise_layer(layer_id: String) -> void:
	var layers := record().layers_in_order()
	for i in layers.size() - 1:
		if str(layers[i].id) == layer_id:
			var a: Dictionary = layers[i]
			var b: Dictionary = layers[i + 1]
			bus.editor.do({"op": "batch", "ops": [
				{"op": "set_layer", "id": a.id, "fields": {"order": int(b.order)}},
				{"op": "set_layer", "id": b.id, "fields": {"order": int(a.order)}}]})
			return


class Canvas:
	extends Control
	var board

	func _draw() -> void:
		var r: Rect2 = board.board_rect()
		draw_rect(r, Color(0.06, 0.09, 0.12, 0.0 if board.show_plan else 0.85))
		draw_rect(r, Color(0.4, 0.6, 0.75, 0.5), false, 2.0)
		# A faint grid, every 100 board units.
		var step: float = r.size.x / (board.BOARD.x / 100.0)
		var x := r.position.x + step
		while x < r.end.x - 1.0:
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0.4, 0.6, 0.75, 0.07), 1.0)
			x += step
		var y := r.position.y + step
		while y < r.end.y - 1.0:
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.4, 0.6, 0.75, 0.07), 1.0)
			y += step
		var rec: DesignRecord = board.record()
		if rec == null:
			return
		var px: float = r.size.x / board.BOARD.x
		for l in rec.layers_in_order():
			if not bool(l.visible):
				continue
			for k: Dictionary in rec.strokes.values():
				if str(k.layer) == str(l.id):
					_stroke(board.stroke_points(k), str(k.tool), Color(str(k.colour)), float(k.width) * px)
		# The stroke being drawn.
		if board._drawing.size() > 0:
			var live: PackedVector2Array = board._drawing
			var t: String = board.tool
			if t == "erase":
				for p in live:
					draw_circle(board.to_canvas(p), board.ERASE_REACH * px, Color(1, 1, 1, 0.15))
				return
			var k := {"tool": t, "points": board._to_array(live)}
			var w: float = board.width * (board.MARKER_WIDTH if t == "marker" else 1.0)
			_stroke(board.stroke_points(k), t, Color(board.colour), w * px)

	func _stroke(pts: PackedVector2Array, t: String, col: Color, w: float) -> void:
		if t == "marker":
			col.a = board.MARKER_ALPHA
		var canvas_pts := PackedVector2Array()
		for p in pts:
			canvas_pts.append(board.to_canvas(p))
		if canvas_pts.size() == 1:
			draw_circle(canvas_pts[0], w * 0.5, col)
			return
		draw_polyline(canvas_pts, col, maxf(w, 1.0), true)
		if t != "marker":
			for p in [canvas_pts[0], canvas_pts[canvas_pts.size() - 1]]:
				draw_circle(p, maxf(w, 1.0) * 0.5, col)
