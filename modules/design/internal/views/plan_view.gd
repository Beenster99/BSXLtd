extends Control
## A drawing of the open design: a deck plan, or a side or end elevation (plan 2.2, 3.2).
## In plan mode with `editable` on it is the main way to design: place rooms by dragging
## out a rectangle on the grid, move and resize them, put doors on shared walls and drop
## components into rooms. The same control, read-only, is what the wall TVs show.
##
## Ship (x, z) is drawn with x across and z down, so the bow (-Z) is at the top. Side view:
## z across (bow left), y up. End view: x across, y up, seen from the bow.
##
## Mouse: left to place, select and drag (drag an edge to resize); right or middle drag to
## pan; wheel to zoom. Keys (while the mouse is over it): R turns, Delete removes.

signal selection_changed(kind: String, id: String)
## The tool went back to select (after placing, or Esc).
signal tool_changed(tool: String)

const PLAN := "plan"
const SIDE := "side"
const END := "end"

const BG := Color(0.03, 0.07, 0.12)
const GRID := Color(0.35, 0.6, 0.85, 0.10)
const GRID_MAJOR := Color(0.35, 0.6, 0.85, 0.22)
const INK := Color(0.82, 0.93, 1.0)
const DIM := Color(0.55, 0.7, 0.85, 0.7)
const SELECT := Color("ff9a4d")
const BAD := Color("ff5a3c")
const WARN := Color("e8c25a")
const DOOR := Color(0.55, 1.0, 0.95)
## Pixels from a room edge that count as grabbing it to resize.
const EDGE_GRAB := 7.0

var bus: DesignBus
var mode := PLAN
var deck := 0
var editable := false
## "select", "door", "room:<type>" or "part:<type>".
var tool := "select"
## Quarter turns for the next component placed.
var place_rot := 0
## Room and component ids to outline in red/amber (the rules' problems), and in a player's
## colour (Wave 3 highlights).
var problem_rooms: Dictionary = {}
var problem_parts: Dictionary = {}
var title := ""
var show_title := true
## Keep the whole design in view as it changes and when resized (wall TVs).
var auto_frame := false

## Pixels per metre and the ship point at the control's centre.
var zoom := 22.0
var centre := Vector2.ZERO

var selected_kind := ""
var selected_id := ""

## Points of the wire or pipe being drawn (tool "run:<kind>"), ship space.
var _run_pts: Array[Vector2] = []
## The hull walls round the rooms on this deck (DesignStructure, refreshed on change).
var _structure: DesignStructure
var _drag := {}  # what the left button is doing: {kind, id, start, edge, rect, ...}
var _pan_from := Vector2.INF
var _mouse := Vector2.ZERO
var _font: Font


func _init() -> void:
	resized.connect(func() -> void:
		if auto_frame:
			frame_all())
	clip_contents = true
	focus_mode = Control.FOCUS_CLICK
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = TerminalKit.font("mono_medium")


func setup(design_bus: DesignBus, view_mode: String = PLAN, can_edit: bool = false) -> void:
	bus = design_bus
	mode = view_mode
	editable = can_edit and mode == PLAN
	bus.design_changed.connect(_on_changed)
	bus.carry_changed.connect(func(_id: String) -> void: queue_redraw())
	_on_changed()


func set_tool(t: String) -> void:
	tool = t
	_drag = {}
	_run_pts = []
	queue_redraw()
	tool_changed.emit(tool)


## Esc: drops a half-drawn run, else puts the tool in hand down. False if there was nothing to
## cancel (the console then closes).
func cancel() -> bool:
	if bus and bus.carrying != "":
		bus.carry("")
		return true
	if not _run_pts.is_empty():
		_run_pts = []
		queue_redraw()
		return true
	if tool != "select":
		set_tool("select")
		return true
	return false


func set_deck(n: int) -> void:
	deck = maxi(n, 0)
	queue_redraw()


func select(kind: String, id: String) -> void:
	selected_kind = kind
	selected_id = id
	queue_redraw()
	selection_changed.emit(kind, id)


## Fits the whole design in view.
func frame_all() -> void:
	var rec := _rec()
	if rec == null:
		return
	var b := _view_bounds(rec)
	if b.size.x < 1.0 or b.size.y < 1.0:
		b = Rect2(-10, -10, 20, 20)
	b = b.grow(3.0)
	centre = b.get_center()
	var avail := size if size.x > 10 else Vector2(800, 600)
	zoom = clampf(minf(avail.x / b.size.x, avail.y / b.size.y), 4.0, 80.0)
	queue_redraw()


func _rec() -> DesignRecord:
	return bus.library.current if bus else null


func _on_changed() -> void:
	var rec := _rec()
	problem_rooms = {}
	problem_parts = {}
	if rec:
		for p in bus.problems():
			for r in p.rooms:
				if problem_rooms.get(r, "") != DesignRules.ERROR:
					problem_rooms[r] = p.severity
			for c in p.components:
				if problem_parts.get(c, "") != DesignRules.ERROR:
					problem_parts[c] = p.severity
		_structure = DesignStructure.measure(rec) if mode == PLAN else null
		if selected_kind == "room" and not rec.rooms.has(selected_id) \
				or selected_kind == "run" and not rec.runs.has(selected_id) \
				or selected_kind == "part" and not rec.components.has(selected_id) \
				or selected_kind == "door" and not rec.doors.has(selected_id):
			select("", "")
	if auto_frame:
		frame_all()
	queue_redraw()


# Coordinates

func to_screen(p: Vector2) -> Vector2:
	return (p - centre) * zoom + size * 0.5


func to_ship(s: Vector2) -> Vector2:
	return (s - size * 0.5) / zoom + centre


func _snap(v: Vector2, step: float) -> Vector2:
	return Vector2(snappedf(v.x, step), snappedf(v.y, step))


func _grid() -> float:
	var rec := _rec()
	return rec.grid if rec else 1.0


## A room's rectangle as this view draws it (plan: x/z; side: z/height; end: x/height).
func _room_view_rect(rec: DesignRecord, r: Dictionary) -> Rect2:
	var h := rec.deck_height
	var top := -(float(r.deck) + 1.0) * h
	match mode:
		SIDE:
			return Rect2(r.z, top, r.d, h)
		END:
			return Rect2(r.x, top, r.w, h)
	return Rect2(r.x, r.z, r.w, r.d)


func _view_bounds(rec: DesignRecord) -> Rect2:
	var out := Rect2()
	var first := true
	for r: Dictionary in rec.rooms.values():
		var rr := _room_view_rect(rec, r)
		out = rr if first else out.merge(rr)
		first = false
	return out


# Drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	_draw_grid()
	var rec := _rec()
	if rec == null:
		_text(size * 0.5 - Vector2(140, 0), "No design open", INK, 20)
		return
	if mode == PLAN:
		_draw_plan(rec)
	else:
		_draw_elevation(rec)
	_draw_drag_ghost(rec)
	if show_title:
		_draw_title(rec)


func _draw_grid() -> void:
	var step := _grid()
	while step * zoom < 8.0:
		step *= 2.0
	var a := to_ship(Vector2.ZERO)
	var b := to_ship(size)
	var x := floorf(a.x / step) * step
	while x <= b.x:
		var major := is_zero_approx(fmod(absf(x), 5.0)) or is_equal_approx(fmod(absf(x), 5.0), 5.0)
		draw_line(Vector2(to_screen(Vector2(x, 0)).x, 0), Vector2(to_screen(Vector2(x, 0)).x, size.y),
				GRID_MAJOR if major else GRID)
		x += step
	var y := floorf(a.y / step) * step
	while y <= b.y:
		var major := is_zero_approx(fmod(absf(y), 5.0)) or is_equal_approx(fmod(absf(y), 5.0), 5.0)
		draw_line(Vector2(0, to_screen(Vector2(0, y)).y), Vector2(size.x, to_screen(Vector2(0, y)).y),
				GRID_MAJOR if major else GRID)
		y += step


func _draw_plan(rec: DesignRecord) -> void:
	# The deck below, faint, to line up stairwells.
	if deck > 0:
		for r in rec.rooms_on(deck - 1):
			var sr := Rect2(to_screen(Vector2(r.x, r.z)), Vector2(r.w, r.d) * zoom)
			draw_rect(sr, Color(DIM, 0.25), false, 1.0)
	for r in rec.rooms_on(deck):
		_draw_room(rec, r)
	_draw_hull(rec)
	for door: Dictionary in rec.doors.values():
		if int(door.deck) == deck:
			_draw_door(rec, door)
	for c: Dictionary in rec.components.values():
		var r: Dictionary = rec.rooms.get(c.room, {})
		if not r.is_empty() and int(r.deck) == deck:
			_draw_part(c)
	for w: Dictionary in rec.runs.values():
		if int(w.deck) == deck:
			_draw_run(w)
	for r in rec.rooms_on(deck):
		_draw_room_label(r)


## The hull round the rooms: outer walls heavy, inner walls light, frame ticks every spacing.
func _draw_hull(rec: DesignRecord) -> void:
	if _structure == null:
		return
	var spacing := maxf(float(rec.structure.get("spacing", 2.0)), 0.5)
	var outer_w := clampf(zoom * 0.12, 2.0, 6.0)
	for e: Dictionary in _structure.outer_edges:
		if int(e.deck) != deck:
			continue
		var a := to_screen(e.a)
		var b := to_screen(e.b)
		draw_line(a, b, Color(0.75, 0.85, 0.95, 0.9), outer_w)
		# Frame ticks across the wall, every spacing along it.
		var along: Vector2 = (e.b - e.a)
		var n := int(floor(along.length() / spacing + 0.001))
		var normal := Vector2(-along.y, along.x).normalized() * maxf(zoom * 0.18, 3.0)
		for i in n + 1:
			var p := to_screen((e.a as Vector2) + along.normalized() * spacing * i)
			draw_line(p - normal, p + normal, Color(1.0, 0.7, 0.35, 0.8), 1.5)
	for e: Dictionary in _structure.inner_edges:
		if int(e.deck) == deck:
			draw_line(to_screen(e.a), to_screen(e.b), Color(0.75, 0.85, 0.95, 0.55), maxf(outer_w * 0.5, 1.5))


func _draw_run(w: Dictionary) -> void:
	var spec: Dictionary = DesignServices.KINDS.get(str(w.kind), {})
	var col: Color = spec.get("colour", INK)
	var pts := DesignServices.points(w)
	var sel: bool = selected_kind == "run" and selected_id == w.id
	var width := clampf(zoom * 0.08, 1.5, 4.0) * (1.8 if sel else 1.0)
	var screen := PackedVector2Array()
	for p in pts:
		screen.append(to_screen(p))
	draw_polyline(screen, SELECT if sel else col, width)
	if str(w.kind) != "wire":
		# Pipes: a darker core so they read differently from wires.
		draw_polyline(screen, Color(BG, 0.6), maxf(width * 0.35, 1.0))
	for p in [screen[0], screen[screen.size() - 1]]:
		draw_circle(p, width * 1.2, col)


func _room_colour(r: Dictionary) -> Color:
	var rt := bus.catalog.room(str(r.type))
	return rt.colour if rt else Color.GRAY


func _room_name(r: Dictionary) -> String:
	if str(r.get("name", "")) != "":
		return str(r.name)
	var rt := bus.catalog.room(str(r.type))
	return rt.display_name if rt else str(r.type)


func _draw_room(rec: DesignRecord, r: Dictionary) -> void:
	var rect := Rect2(r.x, r.z, r.w, r.d)
	if _drag.get("kind", "") == "room" and _drag.id == r.id and _drag.has("rect"):
		rect = _drag.rect
	var sr := Rect2(to_screen(rect.position), rect.size * zoom)
	var col := _room_colour(r)
	draw_rect(sr, Color(col, 0.22))
	var border := Color(col, 0.95)
	var width := 2.0
	match problem_rooms.get(r.id, ""):
		DesignRules.ERROR:
			border = BAD
			width = 3.0
		DesignRules.WARNING:
			border = WARN
	if selected_kind == "room" and selected_id == r.id:
		border = SELECT
		width = 3.0
	draw_rect(sr, border, false, width)


## The room's name and size, over its components, on a dark tab so it always reads.
func _draw_room_label(r: Dictionary) -> void:
	var rect := Rect2(r.x, r.z, r.w, r.d)
	if _drag.get("kind", "") == "room" and _drag.id == r.id and _drag.has("rect"):
		rect = _drag.rect
	var sr := Rect2(to_screen(rect.position), rect.size * zoom)
	var fs := clampi(int(zoom * 0.45), 9, 18)
	if sr.size.x < 40 or sr.size.y < 26:
		return
	var name_text := _room_name(r)
	var dims := "%s x %s m" % [_m(rect.size.x), _m(rect.size.y)]
	var w := minf(maxf(_font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x,
			_font.get_string_size(dims, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(fs - 3, 8)).x) + 10, sr.size.x - 4)
	draw_rect(Rect2(sr.position + Vector2(2, 2), Vector2(w, fs * 2 + 8)), Color(BG, 0.78))
	_text(sr.position + Vector2(6, fs + 3), name_text, INK, fs, sr.size.x - 10)
	_text(sr.position + Vector2(6, fs * 2 + 6), dims, DIM, maxi(fs - 3, 8), sr.size.x - 10)


func _draw_door(rec: DesignRecord, door: Dictionary) -> void:
	var p := Vector2(door.x, door.z)
	# Which way the wall runs: along x if the door sits on a room's top or bottom edge.
	var along_x := false
	var ra := rec.room_rect(str(door.a))
	if absf(p.y - ra.position.y) < 0.05 or absf(p.y - ra.end.y) < 0.05:
		along_x = true
	var half := DesignRules.MIN_DOOR * 0.5
	var a := p - (Vector2(half, 0) if along_x else Vector2(0, half))
	var b := p + (Vector2(half, 0) if along_x else Vector2(0, half))
	var sa := to_screen(a)
	var sb := to_screen(b)
	draw_line(sa, sb, BG, 6.0)
	var col := DOOR if str(door.b) != "" else Color("6fc8e8")
	if selected_kind == "door" and selected_id == door.id:
		col = SELECT
	draw_line(sa, sb, col, 2.0)
	var n := (Vector2(0, 1) if along_x else Vector2(1, 0)) * 4.0
	draw_line(sa - n, sa + n, col, 2.0)
	draw_line(sb - n, sb + n, col, 2.0)


func _draw_part(c: Dictionary) -> void:
	var pt := bus.catalog.part(str(c.type))
	if pt == null:
		return
	var cc := c
	if _drag.get("kind", "") == "part" and _drag.id == c.id and _drag.has("pos"):
		cc = c.duplicate()
		cc.x = _drag.pos.x
		cc.z = _drag.pos.y
	var f := DesignRules.footprint(cc, pt)
	var sr := Rect2(to_screen(f.position), f.size * zoom)
	draw_rect(sr, Color(pt.colour, 0.55))
	var border := pt.colour.lightened(0.3)
	match problem_parts.get(c.id, ""):
		DesignRules.ERROR:
			border = BAD
		DesignRules.WARNING:
			border = WARN
	if selected_kind == "part" and selected_id == c.id:
		border = SELECT
	draw_rect(sr, border, false, 2.0)
	# The front, where the fitter stands.
	var front := DesignRules.FRONTS[int(cc.rot) % 4]
	var mid := sr.get_center() + Vector2(front.x * sr.size.x, front.y * sr.size.y) * 0.5
	var across := Vector2(-front.y, front.x)
	var half_len := (absf(across.x) * sr.size.x + absf(across.y) * sr.size.y) * 0.4
	draw_line(mid - across * half_len, mid + across * half_len, Color.WHITE, 3.0)
	if sr.size.x > 22:
		_text(sr.position + Vector2(3, minf(sr.size.y - 3, 14)), pt.short, Color.WHITE,
				clampi(int(zoom * 0.35), 8, 13), sr.size.x - 4)


func _draw_elevation(rec: DesignRecord) -> void:
	var list: Array = rec.rooms.values()
	# Far rooms first so nearer ones draw over them: side view looks from starboard (+X).
	list.sort_custom(func(a, b):
		return float(a.x) + float(a.w) < float(b.x) + float(b.w) if mode == SIDE else float(a.z) + float(a.d) > float(b.z) + float(b.d))
	for r: Dictionary in list:
		var rr := _room_view_rect(rec, r)
		var sr := Rect2(to_screen(rr.position), rr.size * zoom)
		var col := _room_colour(r)
		draw_rect(sr, Color(col, 0.18))
		draw_rect(sr, Color(col, 0.9), false, 2.0)
	# Names, nearest rooms first, skipping any that would print over another.
	var taken: Array[Rect2] = []
	var fs := clampi(int(zoom * 0.4), 8, 15)
	for i in range(list.size() - 1, -1, -1):
		var r: Dictionary = list[i]
		var sr := Rect2(to_screen(_room_view_rect(rec, r).position), _room_view_rect(rec, r).size * zoom)
		var name_text := _room_name(r)
		var w := minf(_font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8, sr.size.x - 4)
		var spot := Rect2(sr.position + Vector2(2, 2), Vector2(w, fs + 6))
		var y_step := 0
		while taken.any(func(t: Rect2) -> bool: return t.intersects(spot)) and y_step < 4:
			spot.position.y += fs + 6
			y_step += 1
		if sr.size.x < 36 or taken.any(func(t: Rect2) -> bool: return t.intersects(spot)) or spot.end.y > sr.end.y:
			continue
		taken.append(spot)
		draw_rect(spot, Color(BG, 0.7))
		_text(spot.position + Vector2(4, fs + 1), name_text, INK, fs, spot.size.x - 4)
	# Deck lines.
	for n in rec.decks():
		var y := to_screen(Vector2(0, -float(n) * rec.deck_height)).y
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(DIM, 0.35), 1.0)
		_text(Vector2(8, y - 4), "DECK %d" % (n + 1), DIM, 11)


func _draw_drag_ghost(_rec_unused: DesignRecord) -> void:
	if bus.carrying != "" and mode == PLAN:
		_draw_module_ghost()
		return
	if tool.begins_with("run:") and editable:
		_draw_run_ghost()
		return
	if _drag.get("kind", "") != "new_room" or not _drag.has("rect"):
		if editable and tool.begins_with("part:") and _drag.is_empty():
			_draw_part_ghost()
		return
	var rect: Rect2 = _drag.rect
	var sr := Rect2(to_screen(rect.position), rect.size * zoom)
	var rt := bus.catalog.room(tool.trim_prefix("room:"))
	var col := rt.colour if rt else INK
	draw_rect(sr, Color(col, 0.3))
	draw_rect(sr, SELECT, false, 2.0)
	_text(sr.position + Vector2(4, -6), "%s x %s m" % [_m(rect.size.x), _m(rect.size.y)], SELECT, 13)


## The module being carried, under the pointer: its room and parts, where a click drops it.
func _draw_module_ghost() -> void:
	var m := bus.library.module(bus.carrying)
	if m.is_empty():
		return
	var rec := _rec()
	var size_m := Vector2(float(m.room.w), float(m.room.d))
	var corner := (to_ship(_mouse) - size_m * 0.5).snapped(Vector2.ONE * rec.grid)
	var rt := bus.catalog.room(str(m.room.type))
	var col := rt.colour if rt else INK
	var sr := Rect2(to_screen(corner), size_m * zoom)
	draw_rect(sr, Color(col, 0.3))
	draw_rect(sr, SELECT, false, 2.0)
	for c: Dictionary in m.components:
		var pt := bus.catalog.part(str(c.type))
		if pt:
			var f := DesignRules.footprint({"x": corner.x + float(c.x), "z": corner.y + float(c.z), "rot": c.rot}, pt)
			draw_rect(Rect2(to_screen(f.position), f.size * zoom), Color(pt.colour, 0.5))
	_text(sr.position + Vector2(4, -6), "%s: click to place, right-click to put down" % str(m.name).to_upper(), SELECT, 13)


func _draw_run_ghost() -> void:
	var spec: Dictionary = DesignServices.KINDS.get(tool.trim_prefix("run:"), {})
	var col: Color = spec.get("colour", INK)
	var pts := PackedVector2Array()
	for p in _run_pts:
		pts.append(to_screen(p))
	var next := to_screen(_run_point(to_ship(_mouse)))
	pts.append(next)
	if pts.size() >= 2:
		draw_polyline(pts, Color(col, 0.8), 2.0)
	draw_circle(next, 4.0, SELECT)
	var hint := "click to add points, double-click or Enter to finish, Esc to cancel"
	_text(next + Vector2(10, -8), "%s: %s" % [str(spec.get("name", "Run")).to_upper(), hint], SELECT, 12)


## Run points snap to half the grid, and keep square: each leg runs along X or Z.
func _run_point(p: Vector2) -> Vector2:
	var at := _snap(p, _grid() * 0.5)
	if not _run_pts.is_empty():
		var last: Vector2 = _run_pts[_run_pts.size() - 1]
		if absf(at.x - last.x) > absf(at.y - last.y):
			at.y = last.y
		else:
			at.x = last.x
	return at


func _finish_run() -> void:
	if _run_pts.size() >= 2:
		var pts: Array = []
		for p in _run_pts:
			pts.append([p.x, p.y])
		bus.editor.do({"op": "add_run", "run": {"kind": tool.trim_prefix("run:"), "deck": deck, "points": pts}})
		select("run", _newest(_rec().runs))
	_run_pts = []
	queue_redraw()


func _draw_part_ghost() -> void:
	var pt := bus.catalog.part(tool.trim_prefix("part:"))
	if pt == null:
		return
	var p := _snap(to_ship(_mouse), _grid() * 0.5)
	var f := DesignRules.footprint({"x": p.x, "z": p.y, "rot": place_rot}, pt)
	var sr := Rect2(to_screen(f.position), f.size * zoom)
	draw_rect(sr, Color(pt.colour, 0.3))
	draw_rect(sr, SELECT, false, 1.5)


func _draw_title(rec: DesignRecord) -> void:
	var view_name: String = {"plan": "PLAN  DECK %d" % (deck + 1), "side": "SIDE ELEVATION",
			"end": "END ELEVATION, FROM THE BOW"}.get(mode, mode)
	var t := title if title != "" else "%s   %s" % [rec.name.to_upper(), view_name]
	var box := Rect2(size.x - 330, size.y - 46, 320, 36)
	draw_rect(box, Color(BG, 0.85))
	draw_rect(box, Color(DIM, 0.6), false, 1.0)
	_text(box.position + Vector2(8, 15), t, INK, 12, box.size.x - 12)
	_text(box.position + Vector2(8, 30), "BSX LTD  DESIGN OFFICE   GRID %s m   1 m = %d px" % [_m(rec.grid), int(zoom)],
			DIM, 10, box.size.x - 12)


func _text(pos: Vector2, s: String, col: Color, fs: int, width: float = -1.0) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, fs, col,
			TextServer.JUSTIFICATION_NONE)


static func _m(v: float) -> String:
	return ("%d" % int(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v)


# Input

func _gui_input(event: InputEvent) -> void:
	if bus == null:
		return
	if event is InputEventMouseMotion:
		_mouse = event.position
		if _pan_from != Vector2.INF:
			centre -= event.relative / zoom
			queue_redraw()
		elif not _drag.is_empty():
			_drag_move(event.position)
		elif bus.carrying != "" or editable and (tool.begins_with("part:") or tool.begins_with("run:")):
			queue_redraw()
		_update_cursor(event.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.15)
		elif mb.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and bus.carrying != "":
				bus.carry("")
				return
			if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and editable and tool.begins_with("run:") \
					and not _run_pts.is_empty():
				_finish_run()
				return
			if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and editable and tool != "select":
				set_tool("select")
				return
			_pan_from = mb.position if mb.pressed else Vector2.INF
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and mb.double_click and tool.begins_with("run:") and editable:
				_finish_run()
			elif mb.pressed:
				_press(mb.position)
			else:
				_release(mb.position)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo and editable:
		var k := event as InputEventKey
		if k.keycode == KEY_R:
			rotate_selected()
			accept_event()
		elif k.keycode in [KEY_DELETE, KEY_BACKSPACE]:
			delete_selected()
			accept_event()
		elif k.keycode in [KEY_ENTER, KEY_KP_ENTER] and tool.begins_with("run:"):
			_finish_run()
			accept_event()
		elif k.keycode == KEY_ESCAPE and tool.begins_with("run:") and not _run_pts.is_empty():
			_run_pts = []
			queue_redraw()
			accept_event()
		elif k.keycode == KEY_ESCAPE and tool != "select":
			set_tool("select")
			accept_event()


func _zoom_at(at: Vector2, factor: float) -> void:
	var before := to_ship(at)
	zoom = clampf(zoom * factor, 4.0, 120.0)
	centre += before - to_ship(at)
	queue_redraw()


func rotate_selected() -> void:
	if tool.begins_with("part:"):
		place_rot = (place_rot + 1) % 4
		queue_redraw()
	elif selected_kind == "part":
		var c: Dictionary = _rec().components.get(selected_id, {})
		if not c.is_empty():
			bus.editor.do({"op": "set_component", "id": selected_id, "fields": {"rot": (int(c.rot) + 1) % 4}})


func delete_selected() -> void:
	match selected_kind:
		"room":
			bus.editor.do({"op": "remove_room", "id": selected_id})
		"part":
			bus.editor.do({"op": "remove_component", "id": selected_id})
		"door":
			bus.editor.do({"op": "remove_door", "id": selected_id})
		"run":
			bus.editor.do({"op": "remove_run", "id": selected_id})


## What is under a screen point on this deck: {kind, id, edge} (edge: which room edges are
## grabbed, as a Vector2i of -1/0/1 for x and z).
func pick(s: Vector2) -> Dictionary:
	var rec := _rec()
	if rec == null or mode != PLAN:
		return {}
	var p := to_ship(s)
	for c: Dictionary in rec.components.values():
		var r: Dictionary = rec.rooms.get(c.room, {})
		var pt := bus.catalog.part(str(c.type))
		if pt and not r.is_empty() and int(r.deck) == deck and DesignRules.footprint(c, pt).has_point(p):
			return {"kind": "part", "id": c.id}
	for door: Dictionary in rec.doors.values():
		if int(door.deck) == deck and to_screen(Vector2(door.x, door.z)).distance_to(s) < maxf(8.0, zoom * 0.5):
			return {"kind": "door", "id": door.id}
	for w: Dictionary in rec.runs.values():
		if int(w.deck) != deck:
			continue
		var pts := DesignServices.points(w)
		for i in pts.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
			if to_screen(q).distance_to(s) < 6.0:
				return {"kind": "run", "id": w.id}
	var list := rec.rooms_on(deck)
	list.reverse()
	for r in list:
		var sr := Rect2(to_screen(Vector2(r.x, r.z)), Vector2(r.w, r.d) * zoom)
		if not sr.grow(EDGE_GRAB).has_point(s):
			continue
		var edge := Vector2i.ZERO
		if absf(s.x - sr.position.x) < EDGE_GRAB:
			edge.x = -1
		elif absf(s.x - sr.end.x) < EDGE_GRAB:
			edge.x = 1
		if absf(s.y - sr.position.y) < EDGE_GRAB:
			edge.y = -1
		elif absf(s.y - sr.end.y) < EDGE_GRAB:
			edge.y = 1
		if edge != Vector2i.ZERO or sr.has_point(s):
			return {"kind": "room", "id": r.id, "edge": edge}
	return {}


func _update_cursor(s: Vector2) -> void:
	if not editable or tool != "select" or not _drag.is_empty():
		return
	var hit := pick(s)
	var shape := Control.CURSOR_ARROW
	if hit.get("kind", "") == "room":
		var e: Vector2i = hit.edge
		if e.x != 0 and e.y != 0:
			shape = Control.CURSOR_FDIAGSIZE if e.x == e.y else Control.CURSOR_BDIAGSIZE
		elif e.x != 0:
			shape = Control.CURSOR_HSIZE
		elif e.y != 0:
			shape = Control.CURSOR_VSIZE
		else:
			shape = Control.CURSOR_MOVE
	elif hit.get("kind", "") == "part":
		shape = Control.CURSOR_MOVE
	mouse_default_cursor_shape = shape


func _press(s: Vector2) -> void:
	grab_focus()
	var rec := _rec()
	if rec == null or mode != PLAN:
		return
	var p := to_ship(s)
	if bus.carrying != "":
		# A carried module drops on any plan, the console's or a wall's.
		var rid := bus.drop_carried(deck, p)
		if rid != "":
			select("room", rid)
		return
	if not editable:
		var hit := pick(s)
		select(hit.get("kind", ""), hit.get("id", ""))
		return
	if tool.begins_with("room:"):
		var start := _snap(p, rec.grid)
		_drag = {"kind": "new_room", "start": start, "rect": Rect2(start, Vector2.ZERO)}
	elif tool.begins_with("part:"):
		_place_part(p)
	elif tool == "door":
		_place_door(p)
	elif tool.begins_with("run:"):
		_run_pts.append(_run_point(p))
		queue_redraw()
	else:
		var hit := pick(s)
		select(hit.get("kind", ""), hit.get("id", ""))
		if hit.get("kind", "") == "room":
			_drag = {"kind": "room", "id": hit.id, "edge": hit.edge, "start": p,
					"orig": rec.room_rect(hit.id)}
		elif hit.get("kind", "") == "part":
			var c: Dictionary = rec.components[hit.id]
			_drag = {"kind": "part", "id": hit.id, "start": p, "orig": Vector2(c.x, c.z)}


func _drag_move(s: Vector2) -> void:
	var rec := _rec()
	if rec == null or _drag.is_empty():
		return
	var p := to_ship(s)
	match str(_drag.kind):
		"new_room":
			var a: Vector2 = _drag.start
			var b := _snap(p, rec.grid)
			_drag.rect = Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
		"room":
			var orig: Rect2 = _drag.orig
			var delta := _snap(p - _drag.start, rec.grid)
			var e: Vector2i = _drag.edge
			var r := orig
			if e == Vector2i.ZERO:
				r.position += delta
			else:
				var x0 := orig.position.x
				var x1 := orig.end.x
				var z0 := orig.position.y
				var z1 := orig.end.y
				if e.x < 0:
					x0 = minf(x0 + delta.x, x1 - rec.grid)
				elif e.x > 0:
					x1 = maxf(x1 + delta.x, x0 + rec.grid)
				if e.y < 0:
					z0 = minf(z0 + delta.y, z1 - rec.grid)
				elif e.y > 0:
					z1 = maxf(z1 + delta.y, z0 + rec.grid)
				r = Rect2(x0, z0, x1 - x0, z1 - z0)
			_drag.rect = r
		"part":
			_drag.pos = _snap(_drag.orig + (p - _drag.start), rec.grid * 0.5)
	queue_redraw()


func _release(_s: Vector2) -> void:
	var rec := _rec()
	if rec == null or _drag.is_empty():
		return
	var d := _drag
	_drag = {}
	match str(d.kind):
		"new_room":
			var type_id := tool.trim_prefix("room:")
			var rt := bus.catalog.room(type_id)
			var rect: Rect2 = d.rect
			if rect.size.x < rec.grid or rect.size.y < rec.grid:
				# A click: the room at its usual size, centred on the click.
				var sz := rt.default_size if rt else Vector2(4, 4)
				rect = Rect2(_snap(d.start - sz * 0.5, rec.grid), sz)
			bus.editor.do({"op": "add_room", "room": {"type": type_id, "deck": deck,
					"x": rect.position.x, "z": rect.position.y, "w": rect.size.x, "d": rect.size.y}})
			var newest := _newest(rec.rooms)
			set_tool("select")
			select("room", newest)
		"room":
			if d.has("rect") and d.rect != d.orig:
				var r: Rect2 = d.rect
				_move_room_with_contents(rec, d.id, d.orig, r)
		"part":
			if d.has("pos") and d.pos != d.orig:
				var room_id := rec.room_at(deck, d.pos)
				var fields := {"x": d.pos.x, "z": d.pos.y}
				if room_id != "":
					fields.room = room_id
				bus.editor.do({"op": "set_component", "id": d.id, "fields": fields})
	queue_redraw()


## A moved room takes its components (and drops doors that no longer fit) in one undo step.
func _move_room_with_contents(rec: DesignRecord, room_id: String, from: Rect2, to: Rect2) -> void:
	var ops: Array = [{"op": "set_room", "id": room_id, "fields": {
			"x": to.position.x, "z": to.position.y, "w": to.size.x, "d": to.size.y}}]
	if from.size == to.size:
		var delta := to.position - from.position
		for c: Dictionary in rec.components.values():
			if c.room == room_id:
				ops.append({"op": "set_component", "id": c.id, "fields": {
						"x": float(c.x) + delta.x, "z": float(c.z) + delta.y}})
		for door: Dictionary in rec.doors.values():
			if door.a == room_id or door.b == room_id:
				ops.append({"op": "remove_door", "id": door.id})
	bus.editor.do({"op": "batch", "ops": ops})


func _place_part(p: Vector2) -> void:
	var rec := _rec()
	var at := _snap(p, rec.grid * 0.5)
	var room_id := rec.room_at(deck, at)
	if room_id == "":
		return
	bus.editor.do({"op": "add_component", "component": {"type": tool.trim_prefix("part:"),
			"room": room_id, "x": at.x, "z": at.y, "rot": place_rot}})
	select("part", _newest(rec.components))


## A door on the wall nearest the click: between the two rooms that share it there, or out
## of the room through an outer wall.
func _place_door(p: Vector2) -> void:
	var rec := _rec()
	var best := {}
	var best_dist := 1.0
	for r in rec.rooms_on(deck):
		var rr := Rect2(r.x, r.z, r.w, r.d)
		var cands := [
			[Vector2(rr.position.x, clampf(p.y, rr.position.y, rr.end.y)), Vector2(-1, 0)],
			[Vector2(rr.end.x, clampf(p.y, rr.position.y, rr.end.y)), Vector2(1, 0)],
			[Vector2(clampf(p.x, rr.position.x, rr.end.x), rr.position.y), Vector2(0, -1)],
			[Vector2(clampf(p.x, rr.position.x, rr.end.x), rr.end.y), Vector2(0, 1)],
		]
		for c in cands:
			var dist: float = (c[0] as Vector2).distance_to(p)
			if dist < best_dist:
				best_dist = dist
				best = {"room": r.id, "at": c[0], "out": c[1], "rect": rr}
	if best.is_empty():
		return
	var at: Vector2 = best.at
	var out: Vector2 = best.out
	var rr: Rect2 = best.rect
	var half := DesignRules.MIN_DOOR * 0.5
	# Snap along the wall, kept a half door from the corners.
	if out.x != 0:
		at.y = clampf(snappedf(at.y, rec.grid * 0.5), rr.position.y + half, rr.end.y - half)
	else:
		at.x = clampf(snappedf(at.x, rec.grid * 0.5), rr.position.x + half, rr.end.x - half)
	var other := rec.room_at(deck, at + out * 0.1)
	var door := {"a": best.room, "b": other, "deck": deck, "x": at.x, "z": at.y}
	if other != "":
		var wall := rec.shared_wall(best.room, other, DesignRules.MIN_DOOR)
		if wall.is_empty():
			return
		if out.x != 0:
			door.z = clampf(at.y, minf(wall[0].y, wall[1].y) + half, maxf(wall[0].y, wall[1].y) - half)
		else:
			door.x = clampf(at.x, minf(wall[0].x, wall[1].x) + half, maxf(wall[0].x, wall[1].x) - half)
	bus.editor.do({"op": "add_door", "door": door})
	select("door", _newest(rec.doors))


func _newest(table: Dictionary) -> String:
	var best := ""
	var best_n := -1
	for id: String in table:
		var n := int(id.substr(1)) if id.substr(1).is_valid_int() else -1
		if n > best_n:
			best_n = n
			best = id
	return best
