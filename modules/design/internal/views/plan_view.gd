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

const RoomShape := preload("res://modules/design/internal/views/room_shape.gd")
const PlanMarks := preload("res://modules/design/internal/views/plan_marks.gd")
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
## The marks over the drawing: dimensions, the title block, tape, section line, notes, "look
## here" and the room readout (plan_marks.gd).
var marks: PlanMarks
## Keep the whole design in view as it changes and when resized (wall TVs).
var auto_frame := false

## Pixels per metre and the ship point at the control's centre.
var zoom := 22.0
var centre := Vector2.ZERO

var selected_kind := ""
var selected_id := ""

## Points of the wire or pipe being drawn (tool "run:<kind>"), ship space.
var _run_pts: Array[Vector2] = []
## Corners of the hull outline being drawn (tool "hull"), ship space.
var _hull_pts: Array[Vector2] = []
## The hull walls round the rooms on this deck (DesignStructure, refreshed on change).
var _structure: DesignStructure
var _stale := true
var _frame_queued := false
## Shift held: a room's corner drag keeps its sides square (its neighbours follow), and a
## side's handle puts a square step in it; otherwise corners move freely, sides at any angle.
var keep_square := false
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
	editable = can_edit
	bus.design_changed.connect(_on_changed)
	bus.carry_changed.connect(func(_id: String) -> void: queue_redraw())
	bus.mirror_changed.connect(func(_a: int) -> void: queue_redraw())
	# One pick shared by every drawing and the table (plan 3.3).
	bus.focus_changed.connect(_on_focus)
	bus.section_changed.connect(queue_redraw)
	bus.look_requested.connect(_on_look)
	marks = PlanMarks.new(self)
	marks.build_bar(14)
	if bus.crew:
		bus.crew.call("attach_view", self)
	_on_changed()


## What the DOOR tool places (DesignCatalog.DOOR_KINDS).
var door_kind := "door"


func set_tool(t: String) -> void:
	tool = t
	_drag = {}
	_run_pts = []
	_hull_pts = []
	queue_redraw()
	tool_changed.emit(tool)


## Esc: drops a half-drawn run, else puts the tool in hand down. False if there was nothing to
## cancel (the console then closes).
func cancel() -> bool:
	if marks and marks.cancel():
		return true
	if bus and bus.carrying != "":
		bus.carry("")
		return true
	if not _run_pts.is_empty() or not _hull_pts.is_empty():
		_run_pts = []
		_hull_pts = []
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
	if bus:
		bus.set_focus(kind, id)


## Something was picked on another drawing or at the table: picked here too.
func _on_focus(kind: String, id: String) -> void:
	if kind == selected_kind and id == selected_id:
		return
	select(kind, id)


## "Look here": the drawing pulled to the spot (a plan of another deck goes to that deck if it
## is the console's), and rings round it for a few seconds.
func _on_look(at_deck: int, at: Vector2, who: String, colour: Color) -> void:
	marks.on_look(at_deck, at, who, colour)
	var rec := _rec()
	if mode == PLAN:
		if editable:
			deck = at_deck
		if deck == at_deck:
			centre = at
	elif rec:
		var u := at.y if mode == SIDE else at.x
		centre = Vector2(u, -(at_deck + 0.5) * rec.deck_height)
	queue_redraw()
	get_tree().create_timer(PlanMarks.LOOK_SECONDS + 0.1).timeout.connect(queue_redraw)


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
	# The rules and the measured hull are read when next drawn or used, not on every edit
	# (a sample design is dozens of edits; every wall panel shows a plan).
	_stale = true
	var rec := _rec()
	if rec:
		if selected_kind == "room" and not rec.rooms.has(selected_id) \
				or selected_kind == "run" and not rec.runs.has(selected_id) \
				or selected_kind == "part" and not rec.components.has(selected_id) \
				or selected_kind == "door" and not rec.doors.has(selected_id) \
				or selected_kind == "wall" and not rec.walls.has(selected_id) \
				or selected_kind == "beam" and not rec.beams.has(selected_id) \
				or selected_kind == "mount" and not rec.mounts.has(selected_id) \
				or selected_kind == "hull" and int(selected_id) >= rec.hull_outline(deck).size():
			select("", "")
	if auto_frame and not _frame_queued:
		_frame_queued = true
		(func() -> void:
			_frame_queued = false
			frame_all()).call_deferred()
	queue_redraw()


## The problems and the measured hull as the design now stands.
func _refresh() -> void:
	if not _stale:
		return
	_stale = false
	problem_rooms = {}
	problem_parts = {}
	_structure = null
	if _rec() == null:
		return
	for p in bus.problems():
		for r in p.rooms:
			if problem_rooms.get(r, "") != DesignRules.ERROR:
				problem_rooms[r] = p.severity
		for c in p.components:
			if problem_parts.get(c, "") != DesignRules.ERROR:
				problem_parts[c] = p.severity
	_structure = bus.structure() if mode == PLAN else null


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
	_refresh()
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	_draw_grid()
	var rec := _rec()
	if rec == null:
		_text(size * 0.5 - Vector2(140, 0), "No design open", INK, 20)
		return
	if mode == PLAN:
		_draw_plan(rec)
		_draw_mirror_line()
	else:
		_draw_elevation(rec)
	_draw_drag_ghost(rec)
	_draw_guides()
	marks.draw(rec)
	if show_title:
		_draw_title(rec)


## Symmetry mode's mirror line, across the whole view.
func _draw_mirror_line() -> void:
	if bus.mirror == DesignMirror.OFF:
		return
	var c := Color(0.95, 0.4, 0.85, 0.8)
	if bus.mirror == DesignMirror.ACROSS:
		var x := to_screen(Vector2.ZERO).x
		draw_dashed_line(Vector2(x, 0), Vector2(x, size.y), c, 2.0, 12.0)
		_text(Vector2(x + 6, 18), "MIRROR", c, 12)
	else:
		var y := to_screen(Vector2.ZERO).y
		draw_dashed_line(Vector2(0, y), Vector2(size.x, y), c, 2.0, 12.0)
		_text(Vector2(8, y - 6), "MIRROR", c, 12)


func _draw_grid() -> void:
	var step := _grid()
	while step * zoom < 8.0:
		step *= 2.0
	var a := to_ship(Vector2.ZERO)
	var b := to_ship(size)
	# Counted in whole steps, so the 5 m lines stay major however fine the grid.
	var per5 := maxi(int(round(5.0 / step)), 1)
	var i := int(floorf(a.x / step))
	while i * step <= b.x:
		var sx := to_screen(Vector2(i * step, 0)).x
		draw_line(Vector2(sx, 0), Vector2(sx, size.y), GRID_MAJOR if i % per5 == 0 else GRID)
		i += 1
	var k := int(floorf(a.y / step))
	while k * step <= b.y:
		var sy := to_screen(Vector2(0, k * step)).y
		draw_line(Vector2(0, sy), Vector2(size.x, sy), GRID_MAJOR if k % per5 == 0 else GRID)
		k += 1


func _draw_plan(rec: DesignRecord) -> void:
	# The deck below, faint, to line up stairwells.
	if deck > 0:
		for r in rec.rooms_on(deck - 1):
			var sr := Rect2(to_screen(Vector2(r.x, r.z)), Vector2(r.w, r.d) * zoom)
			draw_rect(sr, Color(DIM, 0.25), false, 1.0)
	_draw_hull_fill(rec)
	_draw_shapes()
	for r in rec.rooms_on(deck):
		_draw_room(rec, r)
	_draw_hull(rec)
	_draw_beams(rec)
	for m: Dictionary in rec.mounts.values():
		if int(m.deck) == deck:
			_draw_mount(m, selected_kind == "mount" and selected_id == m.id, 1.0)
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


## A drawn hull: the deck plated out to it, faintly, and its corners as handles.
func _draw_hull_fill(rec: DesignRecord) -> void:
	var outline := rec.hull_outline(deck)
	if outline.size() < 3:
		return
	var sp := PackedVector2Array()
	for p in outline:
		sp.append(to_screen(p))
	if Geometry2D.triangulate_polygon(sp).size() > 0:
		draw_colored_polygon(sp, Color(0.45, 0.6, 0.75, 0.10))


func _draw_hull_handles(rec: DesignRecord) -> void:
	var outline := rec.hull_outline(deck)
	if not editable or outline.size() < 3:
		return
	for i in outline.size():
		var sel: bool = selected_kind == "hull" and int(selected_id) == i
		var at := to_screen(outline[i])
		if _drag.get("kind", "") == "hull_pt" and int(_drag.index) == i and _drag.has("pos"):
			at = to_screen(_drag.pos)
		draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), SELECT if sel else INK, not sel, 1.5 if sel else -1.0)


## A part on the hull: its footprint standing out from the hull's side, its front outward.
func _draw_mount(m: Dictionary, sel: bool, alpha: float) -> void:
	var pt := bus.catalog.part(str(m.type))
	if pt == null:
		return
	var pts := PackedVector2Array()
	var mid: Vector2
	if DesignOutside.on_skin(m):
		# A part on the skin anywhere (roof, belly, nose...): the plan of its box, dashed round
		# when it is on the roof or belly, over the rooms.
		var foot := _skin_foot(m, pt)
		for c in foot:
			pts.append(to_screen(c))
		var sum := Vector2.ZERO
		for c in foot:
			sum += c
		mid = to_screen(sum / maxf(foot.size(), 1))
	else:
		var at := Vector2(float(m.x), float(m.z))
		var n := Vector2.from_angle(float(m.get("angle", 0.0)))
		var t := Vector2(-n.y, n.x)
		var half_w := pt.size.x * 0.5
		var depth := pt.size.z
		for c in [at + t * half_w, at + t * half_w + n * depth, at - t * half_w + n * depth, at - t * half_w]:
			pts.append(to_screen(c))
		mid = to_screen(at + n * depth * 0.5)
	if pts.size() < 3:
		return
	var bad: bool = problem_parts.get(str(m.get("id", "")), "") == DesignRules.ERROR
	draw_colored_polygon(pts, Color(pt.colour, 0.55 * alpha))
	pts.append(pts[0])
	draw_polyline(pts, SELECT if sel else (BAD if bad else Color(INK, alpha)), 2.0 if sel else 1.2)
	_text(mid - Vector2(12, -4), pt.short, Color(INK, alpha), 11)


## A part on the skin seen from above: the outline of its box, ship x z.
func _skin_foot(m: Dictionary, pt: DesignPartType) -> PackedVector2Array:
	var xf := DesignRules.mount_transform(_rec(), m, pt, bus.frame_plan())
	var bx := DesignOutside.box_of(xf, pt)
	var c: Transform3D = bx[0]
	var h: Vector3 = (bx[1] as Vector3) * 0.5
	var pts := PackedVector2Array()
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var p := c * Vector3(sx * h.x, sy * h.y, sz * h.z)
				pts.append(Vector2(p.x, p.z))
	var hull := Geometry2D.convex_hull(pts)
	if hull.size() > 1:
		hull.remove_at(hull.size() - 1)
	return hull


## A hull part in hand: it snaps to the nearest stretch of hull under the pointer.
func _mount_spot(p: Vector2) -> Dictionary:
	_refresh()
	var near := DesignStructure.nearest_hull(_rec(), deck, p, _structure)
	if near.is_empty() or float(near.dist) > 3.0:
		return {}
	var q: Vector2 = (near.point as Vector2).snapped(Vector2.ONE * _grid() * 0.25)
	near = DesignStructure.nearest_hull(_rec(), deck, q, _structure)
	return {"x": (near.point as Vector2).x, "z": (near.point as Vector2).y, "angle": float(near.angle)}


## Beams placed by hand: a dashed orange line, the selected one solid.
func _draw_beams(rec: DesignRecord) -> void:
	for kind: String in ["beam", "wall"]:
		for b: Dictionary in (rec.beams if kind == "beam" else rec.walls).values():
			if int(b.deck) != deck:
				continue
			var ends := _line_ends(kind, b)
			var a := to_screen(ends[0])
			var e := to_screen(ends[1])
			var sel: bool = selected_kind == kind and selected_id == b.id
			var dragged: bool = _drag.get("kind", "") == "line_end" and str(_drag.id) == str(b.id)
			if sel or dragged:
				draw_line(a, e, SELECT, 4.0)
			elif kind == "beam":
				draw_dashed_line(a, e, Color(1.0, 0.7, 0.35, 0.9), clampf(zoom * 0.1, 2.0, 5.0), 8.0)
			# Its ends are nodes to grab.
			if editable:
				for at in [a, e]:
					draw_rect(Rect2(at - Vector2(3.5, 3.5), Vector2(7, 7)), SELECT if sel or dragged else INK, not (sel or dragged), 1.2)


## A beam's or wall's two ends, an end being dragged where it is going.
func _line_ends(kind: String, b: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = [DesignStructure._v(b.a), DesignStructure._v(b.b)]
	if _drag.get("kind", "") == "line_end" and str(_drag.what) == kind and str(_drag.id) == str(b.id) and _drag.has("pos"):
		out[0 if str(_drag.end) == "a" else 1] = _drag.pos
	return out


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
	# Its floor as drawn: a shaped room's outline (moved and stretched with a drag), or the box.
	var poly := _room_outline(r, rect)
	var spoly := PackedVector2Array()
	for p in poly:
		spoly.append(to_screen(p))
	var shaped: bool = DesignRecord.is_shaped(r) or (_drag.get("kind", "") == "room_poly" and str(_drag.id) == str(r.id))
	if shaped:
		if Geometry2D.triangulate_polygon(spoly).size() > 0:
			draw_colored_polygon(spoly, Color(col, 0.22))
	else:
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
	if shaped:
		var ring := spoly.duplicate()
		ring.append(spoly[0])
		draw_polyline(ring, border, width)
	else:
		draw_rect(sr, border, false, width)
	# Selected: its corners to drag, and a step handle mid-side to put a step in that side.
	if editable and mode == PLAN and selected_kind == "room" and selected_id == r.id:
		for i in spoly.size():
			draw_rect(Rect2(spoly[i] - Vector2(4, 4), Vector2(8, 8)), SELECT)
			var mid := (spoly[i] + spoly[(i + 1) % spoly.size()]) * 0.5
			draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -5), mid + Vector2(5, 0), mid + Vector2(0, 5),
					mid + Vector2(-5, 0)]), Color(SELECT, 0.7))
	_draw_link_mark(rec, r, sr, col)


## A room's outline in ship space as it will be drawn: mid-drag the drag's own outline, else
## its outline (a shaped room's corners, a box's four) moved and stretched to `rect`.
func _room_outline(r: Dictionary, rect: Rect2) -> PackedVector2Array:
	if _drag.get("kind", "") == "room_poly" and str(_drag.id) == str(r.id) and _drag.has("poly"):
		return _drag.poly
	var poly := DesignRecord.room_poly(r)
	var sx := rect.size.x / maxf(float(r.w), 0.01)
	var sz := rect.size.y / maxf(float(r.d), 0.01)
	var out := PackedVector2Array()
	for p in poly:
		out.append(rect.position + Vector2((p.x - float(r.x)) * sx, (p.y - float(r.z)) * sz))
	return out


## Stairs, lifts and hatches: treads, a cross for the shaft, a ladder; and which decks they reach.
func _draw_link_mark(rec: DesignRecord, r: Dictionary, sr: Rect2, col: Color) -> void:
	var rt := bus.catalog.room(str(r.type))
	if rt == null or not rt.links_decks:
		return
	var ink := Color(col.lightened(0.3), 0.7)
	match str(r.type):
		"stairs":
			_draw_flight(rec, r, ink)
		"lift":
			draw_line(sr.position, sr.end, ink, 1.5)
			draw_line(Vector2(sr.end.x, sr.position.y), Vector2(sr.position.x, sr.end.y), ink, 1.5)
		_:
			var c := sr.get_center()
			var h := minf(minf(sr.size.x, sr.size.y) * 0.35, zoom * 0.5)
			draw_rect(Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), ink, false, 1.5)
	var reach: Array[String] = []
	if _stacked(rec, r, 1) != "":
		reach.append("UP")
	if _stacked(rec, r, -1) != "":
		reach.append("DOWN")
	var t2 := " / ".join(reach) if not reach.is_empty() else "ONE DECK ONLY"
	_text(Vector2(sr.position.x + 4, sr.end.y - 5), t2, SELECT if not reach.is_empty() else WARN, 11, sr.size.x - 6)


## A stairwell's flight (DesignStairs): its treads, an arrow up the way it climbs, and the
## landings at its foot and head; on the deck above, the opening it comes up through.
func _draw_flight(rec: DesignRecord, r: Dictionary, ink: Color) -> void:
	var below := _stacked(rec, r, -1)
	if _stacked(rec, r, 1) == "":
		if below != "":
			var hole: Rect2 = DesignStairs.flight(rec.rooms[below], rec.deck_height).rect
			var a := to_screen(hole.position)
			var b := to_screen(hole.end)
			var hr := Rect2(a, b - a).abs()
			for e: Array in [[hr.position, Vector2(hr.end.x, hr.position.y)], [Vector2(hr.end.x, hr.position.y), hr.end],
					[hr.end, Vector2(hr.position.x, hr.end.y)], [Vector2(hr.position.x, hr.end.y), hr.position]]:
				draw_dashed_line(e[0], e[1], ink, 1.0, 5.0)
			_text(hr.get_center() - Vector2(18, -4), "OPEN", ink, 10, hr.size.x)
		return
	var f := DesignStairs.flight(r, rec.deck_height)
	var fr: Rect2 = f.rect
	var p0 := to_screen(fr.position)
	var p1 := to_screen(fr.end)
	var sr := Rect2(p0, p1 - p0).abs()
	var col := ink if bool(f.fits) else Color(WARN, 0.8)
	draw_rect(sr, col, false, 1.5)
	var along_z: bool = f.along_z
	var n := maxi(int(float(f.length) / 0.25), 2)
	for i in range(1, n):
		var t := float(i) / n
		if along_z:
			var y := lerpf(sr.position.y, sr.end.y, t)
			draw_line(Vector2(sr.position.x + 2, y), Vector2(sr.end.x - 2, y), col, 1.0)
		else:
			var x := lerpf(sr.position.x, sr.end.x, t)
			draw_line(Vector2(x, sr.position.y + 2), Vector2(x, sr.end.y - 2), col, 1.0)
	# The arrow: from the foot up to the head.
	var dir := (Vector2(0, 1) if along_z else Vector2(1, 0)) * float(f.climbs)
	var c := sr.get_center()
	var half := (sr.size.y if along_z else sr.size.x) * 0.4
	var tip := c + dir * half
	var tail := c - dir * half
	draw_line(tail, tip, SELECT, 2.0)
	var side := Vector2(-dir.y, dir.x) * minf(6.0, sr.size.length() * 0.05)
	draw_line(tip, tip - dir * 8.0 + side, SELECT, 2.0)
	draw_line(tip, tip - dir * 8.0 - side, SELECT, 2.0)
	_text(tail - Vector2(10, -4) - dir * 10.0, "UP", SELECT, 10)
	# The landings, faint.
	for k: String in ["foot", "head"]:
		var lr: Rect2 = f[k]
		var la := to_screen(lr.position)
		var lb := to_screen(lr.end)
		draw_rect(Rect2(la, lb - la).abs(), Color(SELECT, 0.12))


## The room of the same kind stacked on the deck `step` above (or below) `r`, "" if none.
func _stacked(rec: DesignRecord, r: Dictionary, step: int) -> String:
	var rect := Rect2(r.x, r.z, r.w, r.d)
	for u: Dictionary in rec.rooms_on(int(r.deck) + step):
		if str(u.type) == str(r.type) and Rect2(u.x, u.z, u.w, u.d).intersection(rect).get_area() >= 1.0:
			return str(u.id)
	return ""


## The decks a stairwell, lift or hatch spans: the stack of rooms of its kind over each other.
func _stack(rec: DesignRecord, r: Dictionary) -> Dictionary:
	var ids := {int(r.deck): str(r.id)}
	var cur := r
	while true:
		var up := _stacked(rec, cur, 1)
		if up == "":
			break
		cur = rec.rooms[up]
		ids[int(cur.deck)] = up
	cur = r
	while true:
		var down := _stacked(rec, cur, -1)
		if down == "":
			break
		cur = rec.rooms[down]
		ids[int(cur.deck)] = down
	return ids


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
	# Which way the wall runs: the room's side the door sits on (at any angle).
	var along := DesignRecord.side_at(rec.rooms.get(str(door.a), {"x": 0, "z": 0, "w": 0, "d": 0}), p)
	var kind := DesignCatalog.door_kind(door)
	var half := maxf(DesignRules.MIN_DOOR, DesignCatalog.door_w(door) - 0.2) * 0.5
	var a := p - along * half
	var b := p + along * half
	var sa := to_screen(a)
	var sb := to_screen(b)
	draw_line(sa, sb, BG, 6.0)
	var col := DOOR if str(door.b) != "" else Color("6fc8e8")
	if selected_kind == "door" and selected_id == door.id:
		col = SELECT
	var n := Vector2(-along.y, along.x) * 4.0
	if bool(kind.leaves):
		draw_line(sa, sb, col, 4.0 if str(door.get("kind", "")) == "cargo" else 2.0)
	else:
		draw_dashed_line(sa, sb, col, 2.0, 4.0)  # an open doorway
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
		draw_rect(sr, SELECT if selected_kind == "room" and str(r.id) == selected_id else Color(col, 0.9), false, 2.0)
	# The selected room's ends to drag (and its top and bottom for stairs, lifts and hatches),
	# drawn over the rest.
	if editable and selected_kind == "room" and rec.rooms.has(selected_id):
		var sel: Dictionary = rec.rooms[selected_id]
		var ssr := Rect2(to_screen(_room_view_rect(rec, sel).position), _room_view_rect(rec, sel).size * zoom)
		draw_rect(ssr, SELECT, false, 3.0)
		for x: float in [ssr.position.x, ssr.end.x]:
			draw_rect(Rect2(x - 4, ssr.get_center().y - 14, 8, 28), SELECT)
		var srt := bus.catalog.room(str(sel.type))
		if srt and srt.links_decks:
			for y: float in [ssr.position.y, ssr.end.y]:
				draw_rect(Rect2(ssr.get_center().x - 14, y - 4, 28, 8), SELECT)
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
	if mode != PLAN:
		if _drag.has("rect") and str(_drag.get("kind", "")) in ["new_room", "room"]:
			var gr: Rect2 = _drag.rect
			var gs := Rect2(to_screen(gr.position), gr.size * zoom)
			draw_rect(gs, Color(SELECT, 0.15))
			draw_rect(gs, SELECT, false, 2.0)
			_text(gs.position + Vector2(4, -6), "%s m  DECK %d" % [_m(gr.size.x), _deck_at(_rec(), gr.position.y + 0.01) + 1], SELECT, 13)
		return
	if bus.carrying != "" and mode == PLAN:
		_draw_module_ghost()
		return
	_draw_hull_handles(_rec())
	if tool.begins_with("run:") and editable:
		_draw_run_ghost()
		return
	if tool == "hull" and editable:
		_draw_hull_ghost()
		return
	if tool in ["wall", "beam"] and editable:
		_draw_line_ghost()
		return
	if tool.begins_with("mount:") and editable:
		var spot := _mount_spot(to_ship(_mouse))
		if not spot.is_empty():
			spot["type"] = tool.trim_prefix("mount:")
			_draw_mount(spot, true, 0.7)
		_text(_mouse + Vector2(14, -10), "ON THE HULL: click on the hull's side", SELECT, 12)
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


func _draw_hull_ghost() -> void:
	var pts := PackedVector2Array()
	for p in _hull_pts:
		pts.append(to_screen(p))
	var next := to_screen(_snap(to_ship(_mouse), _grid() * 0.5))
	var closing := _hull_pts.size() >= 3 and next.distance_to(pts[0]) < 10.0
	pts.append(pts[0] if closing else next)
	if pts.size() >= 2:
		draw_polyline(pts, Color(0.75, 0.85, 0.95, 0.9), 3.0)
	for p in pts:
		draw_circle(p, 3.5, INK)
	draw_circle(next, 5.0, SELECT)
	var hint := "click to close the hull" if closing else \
			"click each corner of the hull, back on the first (or Enter) to close, Esc to cancel"
	_text(next + Vector2(10, -8), "HULL: %s" % hint, SELECT, 12)


## A wall or beam: press at one end, drag to the other.
func _draw_line_ghost() -> void:
	var at := to_screen(_snap(to_ship(_mouse), _grid() * 0.5))
	var col := Color(1.0, 0.7, 0.35) if tool == "beam" else INK
	if _drag.get("kind", "") == "line" and _drag.has("b"):
		var a := to_screen(_drag.a)
		var b := to_screen(_drag.b)
		draw_line(a, b, col, 3.0)
		_text(b + Vector2(10, -8), "%s m" % _m((_drag.a as Vector2).distance_to(_drag.b)), SELECT, 13)
	else:
		draw_circle(at, 5.0, SELECT)
		_text(at + Vector2(10, -8), "%s: drag from one end to the other" % ("BEAM" if tool == "beam" else "INNER WALL"),
				SELECT, 12)


## Commits the hull being drawn.
func _finish_hull() -> void:
	if _hull_pts.size() >= 3:
		var pts: Array = []
		for p in _hull_pts:
			pts.append([p.x, p.y])
		bus.editor.do({"op": "set_hull", "deck": deck, "points": pts})
		set_tool("select")
	_hull_pts = []
	queue_redraw()


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
		select("run", _add({"op": "add_run", "run": {"kind": tool.trim_prefix("run:"), "deck": deck, "points": pts}}, _rec().runs))
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
	if title == "":
		marks.draw_title_block(rec, view_name)
		return
	var t := title
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
	if is_equal_approx(v, roundf(v)):
		return "%d" % int(v)
	return ("%.1f" % v) if is_equal_approx(v * 10.0, roundf(v * 10.0)) else ("%.2f" % v)


# Input

func _gui_input(event: InputEvent) -> void:
	if bus == null:
		return
	if event is InputEventWithModifiers:
		keep_square = (event as InputEventWithModifiers).shift_pressed
	if event is InputEventMouseMotion:
		_mouse = event.position
		if _pan_from != Vector2.INF:
			centre -= event.relative / zoom
			queue_redraw()
		elif not _drag.is_empty():
			_drag_move(event.position)
		elif bus.carrying != "" or editable and (tool.begins_with("part:") or tool.begins_with("run:")
				or tool in ["hull", "wall", "beam"] or tool.begins_with("mount:")):
			queue_redraw()
		elif marks.moved(event.position):
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
			elif mb.pressed and mb.double_click and tool == "hull" and editable:
				_finish_hull()
			elif mb.pressed and marks.press(mb.position, mb.shift_pressed):
				pass
			elif mb.pressed:
				_press(mb.position)
			else:
				_release(mb.position)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo and editable:
		var k := event as InputEventKey
		if k.ctrl_pressed and k.keycode == KEY_C:
			copy_selected()
			accept_event()
		elif k.ctrl_pressed and k.keycode == KEY_V:
			paste(to_ship(_mouse) if Rect2(Vector2.ZERO, size).has_point(_mouse) else Vector2.INF)
			accept_event()
		elif k.ctrl_pressed and k.keycode == KEY_D:
			var kept := clipboard
			if copy_selected():
				paste(Vector2.INF)
			clipboard = kept
			accept_event()
		elif k.keycode == KEY_R:
			rotate_selected()
			accept_event()
		elif k.keycode == KEY_M:
			bus.cycle_mirror()
			accept_event()
		elif k.keycode in [KEY_DELETE, KEY_BACKSPACE]:
			delete_selected()
			accept_event()
		elif k.keycode in [KEY_ENTER, KEY_KP_ENTER] and tool.begins_with("run:"):
			_finish_run()
			accept_event()
		elif k.keycode in [KEY_ENTER, KEY_KP_ENTER] and tool == "hull":
			_finish_hull()
			accept_event()
		elif k.keycode == KEY_ESCAPE and tool.begins_with("run:") and not _run_pts.is_empty():
			_run_pts = []
			queue_redraw()
			accept_event()
		elif k.keycode == KEY_ESCAPE and tool != "select":
			set_tool("select")
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and marks:
		marks.pointer_left()


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
	elif selected_kind == "room":
		turn_room(selected_id)


## Turns a room a quarter (clockwise from above) about its middle, its parts with it; its
## doors come out (they no longer sit on its walls). One undo step.
func turn_room(room_id: String) -> void:
	var rec := _rec()
	var r: Dictionary = rec.rooms.get(room_id, {}) if rec else {}
	if r.is_empty():
		return
	var mid := Vector2(float(r.x) + float(r.w) * 0.5, float(r.z) + float(r.d) * 0.5)
	var size := Vector2(float(r.d), float(r.w))
	var at := _snap(mid - size * 0.5, rec.grid)
	var mid2 := at + size * 0.5
	var fields := {"x": at.x, "z": at.y, "w": size.x, "d": size.y}
	if DesignRecord.is_shaped(r):
		# Its corners turned with it, about its middle.
		var pts: Array = []
		for p in DesignRecord.room_poly(r):
			var rel := p - mid
			var q := mid2 + Vector2(-rel.y, rel.x) - at
			pts.append([snappedf(q.x, 0.01), snappedf(q.y, 0.01)])
		fields["outline"] = pts
	var ops: Array = [{"op": "set_room", "id": room_id, "fields": fields}]
	for c: Dictionary in rec.components.values():
		if c.room == room_id:
			var rel := Vector2(float(c.x), float(c.z)) - mid
			var q := mid2 + Vector2(-rel.y, rel.x)
			ops.append({"op": "set_component", "id": c.id, "fields": {"x": q.x, "z": q.y, "rot": (int(c.get("rot", 0)) + 1) % 4}})
	for door: Dictionary in rec.doors.values():
		if door.a == room_id or door.b == room_id:
			ops.append({"op": "remove_door", "id": door.id})
	bus.editor.do({"op": "batch", "ops": ops})


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
		"wall":
			bus.editor.do({"op": "remove_wall", "id": selected_id})
		"beam":
			bus.editor.do({"op": "remove_beam", "id": selected_id})
		"mount":
			bus.editor.do({"op": "remove_mount", "id": selected_id})
		"shape":
			bus.editor.do({"op": "remove_shape", "id": selected_id})
			select("", "")
		"hull":
			# A corner: take it out (a hull keeps at least three).
			var pts: Array = _rec().hull.get(str(deck), []).duplicate(true)
			if pts.size() > 3:
				pts.remove_at(int(selected_id))
				bus.editor.do({"op": "set_hull", "deck": deck, "points": pts})


## What is under a screen point on this deck: {kind, id, edge} (edge: which room edges are
## grabbed, as a Vector2i of -1/0/1 for x and z).
func pick(s: Vector2) -> Dictionary:
	var rec := _rec()
	if rec == null or mode != PLAN:
		return {}
	var p := to_ship(s)
	if editable and selected_kind == "room" and rec.rooms.has(selected_id) and int(rec.rooms[selected_id].deck) == deck:
		# The selected room's corners and step handles (a non-rectangular room, beenster 19 Nov).
		var poly := DesignRecord.room_poly(rec.rooms[selected_id])
		for i in poly.size():
			if to_screen(poly[i]).distance_to(s) < 7.0:
				return {"kind": "room_vertex", "id": selected_id, "index": i}
		for i in poly.size():
			if to_screen((poly[i] + poly[(i + 1) % poly.size()]) * 0.5).distance_to(s) < 7.0:
				return {"kind": "room_step", "id": selected_id, "index": i}
	if editable:
		var outline := rec.hull_outline(deck)
		for i in outline.size():
			if to_screen(outline[i]).distance_to(s) < 8.0:
				return {"kind": "hull", "id": str(i)}
	for m: Dictionary in rec.mounts.values():
		var mp := bus.catalog.part(str(m.type))
		if mp and int(m.deck) == deck and DesignOutside.on_skin(m):
			if Geometry2D.is_point_in_polygon(p, _skin_foot(m, mp)):
				return {"kind": "mount", "id": m.id}
		elif mp and int(m.deck) == deck:
			var n := Vector2.from_angle(float(m.angle))
			var rel := p - Vector2(float(m.x), float(m.z))
			if absf(rel.dot(Vector2(-n.y, n.x))) < mp.size.x * 0.5 and rel.dot(n) > -0.1 and rel.dot(n) < mp.size.z:
				return {"kind": "mount", "id": m.id}
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
	for kind: String in ["beam", "wall"]:
		for e: Dictionary in (rec.beams if kind == "beam" else rec.walls).values():
			if int(e.deck) != deck:
				continue
			# Its ends are nodes: grab one to move it (beenster, 19 Nov).
			if editable:
				for end: String in ["a", "b"]:
					if to_screen(DesignStructure._v(e[end])).distance_to(s) < 8.0:
						return {"kind": kind, "id": e.id, "end": end}
			var q := Geometry2D.get_closest_point_to_segment(p, DesignStructure._v(e.a), DesignStructure._v(e.b))
			if to_screen(q).distance_to(s) < 6.0:
				return {"kind": kind, "id": e.id}
	if editable:
		# A hull side: grabbing it puts a new corner there to drag.
		var outline := rec.hull_outline(deck)
		for i in outline.size():
			var q := Geometry2D.get_closest_point_to_segment(p, outline[i], outline[(i + 1) % outline.size()])
			if to_screen(q).distance_to(s) < 6.0:
				return {"kind": "hull_edge", "id": str(i), "at": q}
	var list := rec.rooms_on(deck)
	list.reverse()
	for r in list:
		if DesignRecord.is_shaped(r):
			# A shaped room is picked only on its floor (a click in its notch goes through); its
			# sides are moved with its corner and step handles.
			if DesignRecord.room_has(r, p):
				return {"kind": "room", "id": r.id, "edge": Vector2i.ZERO}
			continue
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
	# Her wings, pods and fins, seen from above (outside designer, stage 2).
	for sh: Array in _shape_outlines():
		if Geometry2D.is_point_in_polygon(p, sh[1]):
			return {"kind": "shape", "id": sh[0]}
	return {}


## Each limb's outline from above (x, z): [[shape id, outline]], from the frame plan.
func _shape_outlines() -> Array:
	var out: Array = []
	var rec := _rec()
	if rec == null or rec.shapes.is_empty() or bus == null:
		return out
	for limb: Dictionary in bus.frame_plan().get("limbs", []):
		var fore := PackedVector2Array()
		var aft := PackedVector2Array()
		for st: Dictionary in limb.stations:
			var lo := INF
			var hi := -INF
			for v: Vector2 in (st.profile as PackedVector2Array):
				lo = minf(lo, v.x)
				hi = maxf(hi, v.x)
			fore.append(Vector2(lo, float(st.z)))
			aft.append(Vector2(hi, float(st.z)))
		aft.reverse()
		out.append([str(limb.shape), fore + aft])
	return out


## The limbs drawn round the hull: a dashed outline, filled faint, orange when picked.
func _draw_shapes() -> void:
	for sh: Array in _shape_outlines():
		var pts := PackedVector2Array()
		for v: Vector2 in (sh[1] as PackedVector2Array):
			pts.append(to_screen(v))
		var on: bool = selected_kind == "shape" and selected_id == sh[0]
		var c := SELECT if on else DIM
		if pts.size() >= 3 and Geometry2D.triangulate_polygon(pts).size() > 0:
			draw_colored_polygon(pts, Color(c, 0.12))
		pts.append(pts[0])
		draw_polyline(pts, c, 2.0 if on else 1.0)


func _update_cursor(s: Vector2) -> void:
	if not editable or tool != "select" or not _drag.is_empty():
		return
	if mode != PLAN:
		var eh := _elevation_pick(_rec(), s) if _rec() else {}
		var e := int(eh.get("edge", 0))
		mouse_default_cursor_shape = Control.CURSOR_ARROW if eh.is_empty() else (Control.CURSOR_HSIZE if absi(e) == 1
				else (Control.CURSOR_VSIZE if absi(e) == 2 else Control.CURSOR_MOVE))
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
	if rec == null:
		return
	if mode != PLAN:
		_press_elevation(rec, s)
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
	elif tool == "hull":
		var at := _snap(p, _grid() * 0.5)
		if _hull_pts.size() >= 3 and to_screen(_hull_pts[0]).distance_to(s) < 10.0:
			_finish_hull()
		elif _hull_pts.is_empty() or _hull_pts[_hull_pts.size() - 1] != at:
			_hull_pts.append(at)
			queue_redraw()
	elif tool in ["wall", "beam"]:
		var at := _snap(p, _grid() * 0.5)
		_drag = {"kind": "line", "a": at, "b": at}
	elif tool.begins_with("mount:"):
		var spot := _mount_spot(p)
		if not spot.is_empty():
			spot["type"] = tool.trim_prefix("mount:")
			spot["deck"] = deck
			select("mount", _add({"op": "add_mount", "mount": spot}, rec.mounts))
	else:
		var hit := pick(s)
		if str(hit.get("kind", "")) in ["room_vertex", "room_step"]:
			_drag = {"kind": "room_poly", "id": hit.id, "how": hit.kind, "index": int(hit.index), "start": p,
					"orig": DesignRecord.room_poly(rec.rooms[hit.id])}
			queue_redraw()
			return
		select(hit.get("kind", ""), hit.get("id", ""))
		if hit.get("kind", "") == "room":
			_drag = {"kind": "room", "id": hit.id, "edge": hit.edge, "start": p,
					"orig": rec.room_rect(hit.id)}
		elif hit.get("kind", "") == "part":
			var c: Dictionary = rec.components[hit.id]
			_drag = {"kind": "part", "id": hit.id, "start": p, "orig": Vector2(c.x, c.z)}
		elif hit.get("kind", "") == "hull":
			_drag = {"kind": "hull_pt", "index": int(hit.id), "orig": rec.hull_outline(deck)[int(hit.id)]}
		elif hit.get("kind", "") == "hull_edge":
			# A new corner on that side, where it was grabbed, dragged from there.
			var at := _snap(hit.at, _grid() * 0.5)
			var pts: Array = rec.hull.get(str(deck), []).duplicate(true)
			var i := int(hit.id) + 1
			pts.insert(i, [at.x, at.y])
			bus.editor.do({"op": "set_hull", "deck": deck, "points": pts})
			select("hull", str(i))
			_drag = {"kind": "hull_pt", "index": i, "orig": at}
		elif hit.get("kind", "") in ["beam", "wall"] and hit.has("end"):
			var table := rec.beams if hit.kind == "beam" else rec.walls
			_drag = {"kind": "line_end", "what": hit.kind, "id": hit.id, "end": hit.end,
					"orig": DesignStructure._v(table[hit.id][hit.end])}


func _drag_move(s: Vector2) -> void:
	var rec := _rec()
	if rec == null or _drag.is_empty():
		return
	var p := to_ship(s)
	if mode != PLAN:
		_drag_elevation(rec, p)
		queue_redraw()
		return
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
				var al := align(r, "room", str(_drag.id))
				r.position += al.offset
				_drag.guides = al.guides
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
			var c: Dictionary = rec.components.get(str(_drag.id), {})
			var pt := bus.catalog.part(str(c.get("type", "")))
			if pt:
				var moved := c.duplicate()
				moved.x = _drag.pos.x
				moved.z = _drag.pos.y
				var al := align(DesignRules.footprint(moved, pt), "part", str(_drag.id))
				_drag.pos += al.offset
				_drag.guides = al.guides
		"hull_pt", "line_end":
			_drag.pos = _snap(p, _grid() * 0.5)
		"room_poly":
			var delta := _snap(p - _drag.start, rec.grid)
			_drag.poly = RoomShape.reshape(_drag.orig, str(_drag.how), int(_drag.index), delta, keep_square)
		"line":
			_drag.b = _snap(p, _grid() * 0.5)
	queue_redraw()


func _release(_s: Vector2) -> void:
	var rec := _rec()
	if rec == null or _drag.is_empty():
		return
	var d := _drag
	_drag = {}
	if mode != PLAN:
		_release_elevation(rec, d)
		queue_redraw()
		return
	match str(d.kind):
		"new_room":
			var type_id := tool.trim_prefix("room:")
			var rt := bus.catalog.room(type_id)
			var rect: Rect2 = d.rect
			if rect.size.x < rec.grid or rect.size.y < rec.grid:
				# A click: the room at its usual size, centred on the click.
				var sz := rt.default_size if rt else Vector2(4, 4)
				rect = Rect2(_snap(d.start - sz * 0.5, rec.grid), sz)
			var newest := _add({"op": "add_room", "room": {"type": type_id, "deck": deck,
					"x": rect.position.x, "z": rect.position.y, "w": rect.size.x, "d": rect.size.y}}, rec.rooms)
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
		"hull_pt":
			if d.has("pos") and d.pos != d.orig:
				var pts: Array = rec.hull.get(str(deck), []).duplicate(true)
				pts[int(d.index)] = [d.pos.x, d.pos.y]
				bus.editor.do({"op": "set_hull", "deck": deck, "points": pts})
		"room_poly":
			if d.has("poly"):
				var fields := RoomShape.fields(d.poly)
				if not fields.is_empty():
					bus.editor.do({"op": "set_room", "id": d.id, "fields": fields})
		"line_end":
			if d.has("pos") and d.pos != d.orig:
				bus.editor.do({"op": "set_" + str(d.what), "id": d.id, "fields": {str(d.end): [d.pos.x, d.pos.y]}})
		"line":
			var a: Vector2 = d.a
			var b: Vector2 = d.b
			if a.distance_to(b) >= 0.1:
				select(tool, _add({"op": "add_" + tool, tool: {"deck": deck, "a": [a.x, a.y], "b": [b.x, b.y]}},
						rec.walls if tool == "wall" else rec.beams))
	queue_redraw()


# Drawing in the elevations: rooms drawn and moved along the ship (side) or across it (end),
# and between decks; the other way they take the room type's usual size, on the ship's middle.

## The deck a height in the elevation (its y, up negative) is on.
func _deck_at(rec: DesignRecord, v: float) -> int:
	return maxi(int(floor(-v / rec.deck_height)), 0)


## A room's span along the elevation's axis (z in the side view, x in the end view).
func _span_of(r: Dictionary) -> Vector2:
	return Vector2(float(r.z), float(r.z) + float(r.d)) if mode == SIDE else Vector2(float(r.x), float(r.x) + float(r.w))


func _row(rec: DesignRecord, u0: float, u1: float, dk: int) -> Rect2:
	return Rect2(minf(u0, u1), -(dk + 1.0) * rec.deck_height, absf(u1 - u0), rec.deck_height)


func _press_elevation(rec: DesignRecord, s: Vector2) -> void:
	var p := to_ship(s)
	if not editable:
		return
	if tool.begins_with("room:"):
		var u := snappedf(p.x, rec.grid)
		var dk := _deck_at(rec, p.y)
		_drag = {"kind": "new_room", "start": Vector2(u, p.y), "deck": dk, "rect": _row(rec, u, u, dk)}
		return
	if tool != "select":
		return
	var hit := _elevation_pick(rec, s)
	if hit.is_empty():
		select("", "")
		return
	var r: Dictionary = rec.rooms[hit.id]
	select("room", str(r.id))
	_drag = {"kind": "room", "id": str(r.id), "edge": int(hit.edge), "start": p, "span": _span_of(r), "deck": int(r.deck),
			"rect": _room_view_rect(rec, r)}


## The room under the pointer in an elevation and which edge of it: {id, edge} (edge -1/1 its
## ends along the view, 2/-2 its top and bottom for rooms that link decks, 0 the room itself),
## or {}. The selected room is tried first, so its ends can be grabbed where rooms behind it
## line up with them; then the nearest room (the elevation draws the far ones first).
func _elevation_pick(rec: DesignRecord, s: Vector2) -> Dictionary:
	var list: Array = rec.rooms.values()
	list.sort_custom(func(a, b):
		return float(a.x) + float(a.w) > float(b.x) + float(b.w) if mode == SIDE else float(a.z) + float(a.d) < float(b.z) + float(b.d))
	if selected_kind == "room" and rec.rooms.has(selected_id):
		list.erase(rec.rooms[selected_id])
		list.push_front(rec.rooms[selected_id])
	for r: Dictionary in list:
		var rr := _room_view_rect(rec, r)
		var sr := Rect2(to_screen(rr.position), rr.size * zoom)
		if not sr.grow(EDGE_GRAB).has_point(s):
			continue
		var edge := 0
		var rt := bus.catalog.room(str(r.type))
		if rt and rt.links_decks and absf(s.y - sr.position.y) < EDGE_GRAB:
			edge = 2  # the top: stretch it up (or back down) a deck at a time
		elif rt and rt.links_decks and absf(s.y - sr.end.y) < EDGE_GRAB:
			edge = -2
		elif absf(s.x - sr.position.x) < EDGE_GRAB:
			edge = -1
		elif absf(s.x - sr.end.x) < EDGE_GRAB:
			edge = 1
		return {"id": str(r.id), "edge": edge}
	return {}


func _drag_elevation(rec: DesignRecord, p: Vector2) -> void:
	match str(_drag.kind):
		"new_room":
			var a: Vector2 = _drag.start
			_drag.rect = _row(rec, a.x, snappedf(p.x, rec.grid), int(_drag.deck))
		"room":
			var span: Vector2 = _drag.span
			var du := snappedf(p.x - (_drag.start as Vector2).x, rec.grid)
			var dk := int(_drag.deck)
			var u0 := span.x
			var u1 := span.y
			if absi(int(_drag.edge)) == 2:
				var st := _stack(rec, rec.rooms[_drag.id])
				var lo: int = st.keys().min()
				var hi: int = st.keys().max()
				var at := _deck_at(rec, p.y)
				if int(_drag.edge) == 2:
					hi = maxi(at, lo)
				else:
					lo = mini(at, hi)
				_drag.decks = Vector2i(lo, hi)
				_drag.rect = Rect2(span.x, -(hi + 1.0) * rec.deck_height, span.y - span.x, (hi - lo + 1) * rec.deck_height)
				return
			match int(_drag.edge):
				-1:
					u0 = minf(span.x + du, span.y - rec.grid)
				1:
					u1 = maxf(span.y + du, span.x + rec.grid)
				_:
					u0 += du
					u1 += du
					dk = maxi(int(_drag.deck) + roundi(((_drag.start as Vector2).y - p.y) / rec.deck_height), 0)
			_drag.u = Vector2(u0, u1)
			_drag.to_deck = dk
			_drag.rect = _row(rec, u0, u1, dk)


func _release_elevation(rec: DesignRecord, d: Dictionary) -> void:
	match str(d.kind):
		"new_room":
			var type_id := tool.trim_prefix("room:")
			var rt := bus.catalog.room(type_id)
			var sz := rt.default_size if rt else Vector2(4, 4)
			var r: Rect2 = d.rect
			var u0 := r.position.x
			var len := r.size.x
			if len < rec.grid:
				# A click: the room at its usual length, centred on the click.
				len = sz.y if mode == SIDE else sz.x
				u0 = snappedf((d.start as Vector2).x - len * 0.5, rec.grid)
			var mid := rec.bounds().get_center()
			var room := {"type": type_id, "deck": int(d.deck)}
			if mode == SIDE:
				room.merge({"z": u0, "d": len, "w": sz.x, "x": snappedf(mid.x - sz.x * 0.5, rec.grid)})
			else:
				room.merge({"x": u0, "w": len, "d": sz.y, "z": snappedf(mid.y - sz.y * 0.5, rec.grid)})
			var newest := _add({"op": "add_room", "room": room}, rec.rooms)
			set_tool("select")
			select("room", newest)
			deck = int(d.deck)
		"room":
			if d.has("decks"):
				_stretch(rec, str(d.id), d.decks)
				return
			if not d.has("u"):
				return
			var r: Dictionary = rec.rooms.get(str(d.id), {})
			if r.is_empty():
				return
			var u: Vector2 = d.u
			var from := Rect2(r.x, r.z, r.w, r.d)
			var to := Rect2(r.x, u.x, r.w, u.y - u.x) if mode == SIDE else Rect2(u.x, r.z, u.y - u.x, r.d)
			var dk := int(d.get("to_deck", r.deck))
			if to == from and dk == int(r.deck):
				return
			_move_room_with_contents(rec, str(d.id), from, to, {"deck": dk} if dk != int(r.deck) else {})


## A stairwell, lift or hatch made to span decks lo..hi: its kind stacked over itself on each,
## the ones outside taken out. One undo step.
func _stretch(rec: DesignRecord, room_id: String, decks: Vector2i) -> void:
	var r: Dictionary = rec.rooms.get(room_id, {})
	if r.is_empty():
		return
	var st := _stack(rec, r)
	var ops: Array = []
	for dk in range(decks.x, decks.y + 1):
		if not st.has(dk):
			ops.append({"op": "add_room", "room": {"type": str(r.type), "deck": dk, "x": r.x, "z": r.z, "w": r.w, "d": r.d}})
	for dk: int in st:
		if dk < decks.x or dk > decks.y:
			ops.append({"op": "remove_room", "id": st[dk]})
	if not ops.is_empty():
		bus.editor.do({"op": "batch", "ops": ops})


## A moved room takes its components (and drops doors that no longer fit) in one undo step.
func _move_room_with_contents(rec: DesignRecord, room_id: String, from: Rect2, to: Rect2, extra: Dictionary = {}) -> void:
	var fields := {"x": to.position.x, "z": to.position.y, "w": to.size.x, "d": to.size.y}
	fields.merge(extra, true)
	var ops: Array = [{"op": "set_room", "id": room_id, "fields": fields}]
	if not extra.is_empty() and from.size == to.size and from.position == to.position:
		for door: Dictionary in rec.doors.values():
			if door.a == room_id or door.b == room_id:
				ops.append({"op": "remove_door", "id": door.id})
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
	select("part", _add({"op": "add_component", "component": {"type": tool.trim_prefix("part:"),
			"room": room_id, "x": at.x, "z": at.y, "rot": place_rot}}, rec.components))


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
	var dw := maxf(DesignRules.MIN_DOOR, float(DesignCatalog.DOOR_KINDS[door_kind].w) - 0.2)
	var half := dw * 0.5
	# Snap along the wall, kept a half door from the corners.
	if out.x != 0:
		at.y = clampf(snappedf(at.y, rec.grid * 0.5), rr.position.y + half, rr.end.y - half)
	else:
		at.x = clampf(snappedf(at.x, rec.grid * 0.5), rr.position.x + half, rr.end.x - half)
	var other := rec.room_at(deck, at + out * 0.1)
	var door := {"a": best.room, "b": other, "deck": deck, "x": at.x, "z": at.y}
	if door_kind != "door":
		door["kind"] = door_kind
	if other != "":
		var wall := rec.shared_wall(best.room, other, dw)
		if wall.is_empty():
			return
		if out.x != 0:
			door.z = clampf(at.y, minf(wall[0].y, wall[1].y) + half, maxf(wall[0].y, wall[1].y) - half)
		else:
			door.x = clampf(at.x, minf(wall[0].x, wall[1].x) + half, maxf(wall[0].x, wall[1].x) - half)
	select("door", _add({"op": "add_door", "door": door}, rec.doors))


## What Ctrl+C took: {kind: "part"|"mount"|"room", item, parts (a room's, as offsets)}, shared
## by every plan (copy at the console, paste on a wall's).
static var clipboard := {}
## Smart guides (beenster, 20 Nov: "like you get in PowerPoint"): how near, in screen pixels, an
## edge or middle has to come to another's to snap to it. Alt held turns it off.
const GUIDE_SNAP_PX := 8.0
const GUIDE_COLOUR := Color(1.0, 0.3, 0.85)


## Ctrl+C: the selected component, hull part or room (with what is in it). False if nothing.
func copy_selected() -> bool:
	var rec := _rec()
	if rec == null:
		return false
	match selected_kind:
		"part":
			if rec.components.has(selected_id):
				clipboard = {"kind": "part", "item": (rec.components[selected_id] as Dictionary).duplicate(true)}
				return true
		"mount":
			if rec.mounts.has(selected_id):
				clipboard = {"kind": "mount", "item": (rec.mounts[selected_id] as Dictionary).duplicate(true)}
				return true
		"room":
			if rec.rooms.has(selected_id):
				var r: Dictionary = (rec.rooms[selected_id] as Dictionary).duplicate(true)
				var parts: Array = []
				for c: Dictionary in rec.components.values():
					if str(c.room) == selected_id:
						var cc := c.duplicate(true)
						cc.dx = float(c.x) - float(r.x)
						cc.dz = float(c.z) - float(r.z)
						parts.append(cc)
				clipboard = {"kind": "room", "item": r, "parts": parts}
				return true
	return false


## Ctrl+V: a copy of what was copied, at `at` (ship metres, the pointer) on this deck, or next
## to the original when `at` is INF. Returns the new id ("" if nothing could go there).
func paste(at: Vector2 = Vector2.INF) -> String:
	var rec := _rec()
	if rec == null or clipboard.is_empty() or not editable:
		return ""
	var item: Dictionary = (clipboard.item as Dictionary).duplicate(true)
	item.erase("id")
	match str(clipboard.kind):
		"part":
			var pos := Vector2(float(item.x), float(item.z)) + Vector2(1.0, 1.0) * maxf(rec.grid, 0.5) \
					if at == Vector2.INF else _snap(at, rec.grid * 0.5)
			var room_id := rec.room_at(deck, pos)
			if room_id == "":
				return ""
			item.x = pos.x
			item.z = pos.y
			item.room = room_id
			var id := _add({"op": "add_component", "component": item}, rec.components)
			select("part", id)
			return id
		"mount":
			if DesignOutside.on_skin(item):
				# A part on the skin: the copy a step along the hull (across the nose or stern).
				var step := maxf((bus.catalog.part(str(item.type)).size.x if bus.catalog.part(str(item.type)) else 1.0) + 0.2, 0.5)
				if int(item.get("edge", 0)) < 0:
					item.x = float(item.get("x", 0.0)) + step
				else:
					item.z = float(item.get("z", 0.0)) + step
				var sid := _add({"op": "add_mount", "mount": item}, rec.mounts)
				select("mount", sid)
				return sid
			var spot := _mount_spot(at if at != Vector2.INF else Vector2(float(item.get("x", 0.0)), float(item.get("z", 0.0))) + Vector2(0, 1.0))
			if spot.is_empty():
				return ""
			spot["type"] = item.type
			spot["deck"] = deck
			var id := _add({"op": "add_mount", "mount": spot}, rec.mounts)
			select("mount", id)
			return id
		"room":
			var pos := Vector2(float(item.x) + float(item.w) + rec.grid, float(item.z)) if at == Vector2.INF \
					else _snap(at - Vector2(float(item.w), float(item.d)) * 0.5, rec.grid)
			item.x = pos.x
			item.z = pos.y
			item.deck = deck
			var rid := _add({"op": "add_room", "room": item}, rec.rooms)
			if rid == "":
				return ""
			var ops: Array = []
			for c: Dictionary in clipboard.get("parts", []):
				var cc := c.duplicate(true)
				cc.erase("id")
				cc.x = pos.x + float(cc.dx)
				cc.z = pos.y + float(cc.dz)
				cc.erase("dx")
				cc.erase("dz")
				cc.room = rid
				ops.append({"op": "add_component", "component": cc})
			if not ops.is_empty():
				bus.editor.do({"op": "batch", "ops": ops})
			select("room", rid)
			return rid
	return ""


## Smart guides for a box being moved on this deck: where its edges or middle come within
## GUIDE_SNAP_PX of another room's or part's, the shift that lines them up and the lines to
## draw ({offset, guides: [[from, to]...]}, ship metres). Alt held: none.
func align(box: Rect2, kind: String, id: String) -> Dictionary:
	var out := {"offset": Vector2.ZERO, "guides": []}
	var rec := _rec()
	if rec == null or Input.is_key_pressed(KEY_ALT):
		return out
	var others: Array[Rect2] = []
	for r: Dictionary in rec.rooms.values():
		if int(r.deck) == deck and not (kind == "room" and str(r.id) == id):
			others.append(rec.room_rect(str(r.id)))
	for c: Dictionary in rec.components.values():
		if kind == "part" and str(c.id) == id:
			continue
		if kind == "room" and str(c.room) == id:
			continue
		var r: Dictionary = rec.rooms.get(str(c.room), {})
		var pt := bus.catalog.part(str(c.type))
		if pt and not r.is_empty() and int(r.deck) == deck:
			others.append(DesignRules.footprint(c, pt))
	var tol := GUIDE_SNAP_PX / maxf(zoom, 0.001)
	var best := [INF, INF]
	var hit := [[], []]
	for axis in 2:
		var mine := [box.position[axis], box.get_center()[axis], box.end[axis]]
		for o in others:
			var theirs := [o.position[axis], o.get_center()[axis], o.end[axis]]
			for m: float in mine:
				for t: float in theirs:
					var d := t - m
					if absf(d) <= tol and absf(d) <= absf(best[axis]) + 0.0001:
						if absf(d) < absf(best[axis]) - 0.0001:
							hit[axis] = []
						best[axis] = d
						hit[axis].append([t, o])
	var off := Vector2(best[0] if best[0] != INF else 0.0, best[1] if best[1] != INF else 0.0)
	var moved := Rect2(box.position + off, box.size)
	for axis in 2:
		for h: Array in hit[axis]:
			var o: Rect2 = h[1]
			var t: float = h[0]
			var lo := minf(moved.position[1 - axis], o.position[1 - axis])
			var hi := maxf(moved.end[1 - axis], o.end[1 - axis])
			if axis == 0:
				out.guides.append([Vector2(t, lo), Vector2(t, hi)])
			else:
				out.guides.append([Vector2(lo, t), Vector2(hi, t)])
	out.offset = off
	return out


func _draw_guides() -> void:
	if _drag.is_empty() or not _drag.has("guides"):
		return
	for g: Array in _drag.guides:
		var a := to_screen(g[0])
		var b := to_screen(g[1])
		draw_dashed_line(a, b, GUIDE_COLOUR, 1.5, 6.0)
		draw_circle(a, 2.5, GUIDE_COLOUR)
		draw_circle(b, 2.5, GUIDE_COLOUR)


## Does an add op, and with symmetry on (bus.mirror) its mirrored twin in the same undo step.
## Returns the id the original got.
func _add(op: Dictionary, table: Dictionary) -> String:
	var before := table.duplicate()
	bus.editor.do(DesignMirror.with_twin(_rec(), op, bus.mirror))
	var best := ""
	var best_n := 1 << 30
	for id: String in table:
		if before.has(id):
			continue
		var n := int(id.substr(1)) if id.substr(1).is_valid_int() else 0
		if n < best_n:
			best_n = n
			best = id
	return best


func _newest(table: Dictionary) -> String:
	var best := ""
	var best_n := -1
	for id: String in table:
		var n := int(id.substr(1)) if id.substr(1).is_valid_int() else -1
		if n > best_n:
			best_n = n
			best = id
	return best
