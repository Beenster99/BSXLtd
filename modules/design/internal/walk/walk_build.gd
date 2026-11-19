extends RefCounted
## Builds the open design at full size for walk-inside mode, as near real as the design says
## (beenster, 18 Nov: "plates, floors, walls, doors... the only thing that tells you that you
## are in the hologram is a slight pale blue outline to some of the objects"):
##   deck plates on every floor, lined walls with hull plating outside, frame ribs at the
##   design's frame spacing and weight, ceiling beams and light panels, a lamp in each room,
##   doorways with sliding doors, stairs with steps and a rail round the stairwell, and the
##   parts as solid units. The parts, doors and stairs carry a faint pale blue outline.
##
## Everything you can aim at to design with carries meta "walk": {kind, ...} on its body:
##   floor {room}, wall {deck, a, b, outer}, component {id}, door {id}.
## Room space: ship metres, deck n's floor at n * deck_height (DesignRecord).

const SURFACE := preload("res://shared/void_salvage/shaders/salvage_surface.gdshader")

## The physics layer walk-inside alone uses (bit 20).
const LAYER := 1 << 19
## The visual layer of what faces space: the only thing walk-inside's sun lights.
const EXTERIOR := 1 << 1
## Wall core thickness and the lining on each face, m.
const WALL := 0.14
const LINING := 0.025
## Floor (deck plate and its bed) thickness, m.
const FLOOR := 0.1
## A doorway: width and height, m.
const DOOR_W := 1.2
## How fast a lift platform rides, m/s, and how long you stand on it before it goes, s.
const LIFT_SPEED := 1.6
const LIFT_DWELL := 1.0
## A hatch's opening through the deck, m square.
const HATCH := 1.0
const DOOR_H := 2.2
## Stairs: the flight's width at most, and the landing at its top, m.
const RAMP_W := 1.2
const LANDING := 1.0
## Deck plates and wall panels, m.
const PLATE := 1.0
const PANEL := 1.2
const HULL_PANEL := 2.0
## Frame girder size by the design's frame weight: [width, depth], m.
## A pipe under the lowest deck's plates (below its beams), metres from the deck's top; a cable
## run within this of a stud wall's line goes into the wall, metres.
const UNDER_DECK := -0.3
const WALL_REACH := 0.6
const GIRDERS := {"light": [0.1, 0.12], "standard": [0.14, 0.18], "heavy": [0.2, 0.26]}
## The hologram's only tell.
const OUTLINE := Color(0.62, 0.86, 1.0, 0.42)

var catalog: DesignCatalog
var root: Node3D
var rec: DesignRecord
## Built last time, for tests and the walker.
var wall_pieces: Array[Dictionary] = []  # {deck, a, b, y0, y1, outer}
var ramps: PackedStringArray = []
## Sliding doors: {id, centre (Vector3), left, right (Node3D), dir (Vector3), half (m), open (0..1)}.
var doors: Array[Dictionary] = []
## Each lift shaft: {id, body (the platform), rect, decks, rooms (deck -> room id), gates, at, target}.
var lifts: Array[Dictionary] = []
## Each ladder up a hatch: {rect (where you can climb it, floor plan), y0, y1 (its top)}.
var ladders: Array[Dictionary] = []
var lamps := 0
var ribs := 0
## The structure proposed for the design (DesignFrame.propose) and the frame built from it:
## its body (a frozen RigidBody3D on the walk layer), parts and joints.
var frame_plan: Dictionary = {}
var frame: FrameHull
var frame_body: RigidBody3D
var frame_model: PartModel
var _paints: Dictionary = {}
var _outline: Array[Vector3] = []
## The materials the frame was built in ({shell, frame, lining, deck}), for WalkCad.
var frame_mats: Dictionary = {}
## Openings cut in outer walls for glass in the hull beside them (tests).
var windows := 0
var _glass: Array[Dictionary] = []


## The glazed hull panels (frame_plan.glass) as boxes: [{x0, x1, y0, y1, z0, z1}], ship space.
func _glass_boxes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if frame_plan.is_empty():
		return out
	var st: Array = frame_plan.stations
	for key: String in (frame_plan.glass as Dictionary):
		var k := int(key.get_slice(":", 0))
		var e := int(key.get_slice(":", 1))
		if k < 0 or k + 1 >= st.size():
			continue
		var box := {"x0": INF, "x1": -INF, "y0": INF, "y1": -INF,
				"z0": float(st[k].z), "z1": float(st[k + 1].z)}
		for s in [st[k], st[k + 1]]:
			var prof: PackedVector2Array = s.profile
			if prof.size() < 3:
				continue
			for p: Vector2 in [prof[e % prof.size()], prof[(e + 1) % prof.size()]]:
				box.x0 = minf(box.x0, p.x)
				box.x1 = maxf(box.x1, p.x)
				box.y0 = minf(box.y0, p.y)
				box.y1 = maxf(box.y1, p.y)
		if box.x0 <= box.x1:
			out.append(box)
	return out


## Whether glass in the hull lies over `rect` (x, z) above `top` m: the ceiling stays open.
func _glass_over(rect: Rect2, top: float) -> bool:
	for g in _glass:
		if float(g.y1) > top - 0.05 and float(g.x1) > rect.position.x + 0.1 and float(g.x0) < rect.end.x - 0.1 \
				and float(g.z1) > rect.position.y + 0.1 and float(g.z0) < rect.end.y - 0.1:
			return true
	return false


## Where along an outer wall (from a along dir, length m, facing out_dir) glass in the hull is
## beside it at this deck's height: [{t0, t1, sill, head}] openings, m.
func _window_spans(a: Vector2, dir: Vector2, length: float, out_dir: Vector2, y0: float, y1: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if absf(dir.y) < 0.7:
		return out  # only the side walls (along the ship) face side panels
	var x := a.x
	for g in _glass:
		var gx := (float(g.x0) + float(g.x1)) * 0.5
		if (gx - x) * out_dir.x <= 0.05:
			continue
		var sill := maxf(y0 + WINDOW_SILL, float(g.y0))
		var head := minf(y1 - WINDOW_HEAD, float(g.y1))
		if head - sill < 0.4:
			continue
		var za := a.y
		var zb := a.y + dir.y * length
		var t0 := clampf((float(g.z0) - za) / dir.y, 0.0, length)
		var t1 := clampf((float(g.z1) - za) / dir.y, 0.0, length)
		if t0 > t1:
			var tmp := t0
			t0 = t1
			t1 = tmp
		t0 += WINDOW_POST
		t1 -= WINDOW_POST
		if t1 - t0 > 0.3:
			out.append({"t0": t0, "t1": t1, "sill": sill, "head": head})
	return out


## A window opening's sill over the floor, its head under the deckhead and the post left
## each side, m.
const WINDOW_SILL := 0.85
const WINDOW_HEAD := 0.25
const WINDOW_POST := 0.15


## Forget the frame built last, so the next build makes it afresh (a change of look).
func forget_frame() -> void:
	_built_plan = {}
## The frame kept from the last build when the proposal hasn't changed (moving a part, a door
## inside, a run): building it is most of a rebuild's second.
var _kept := {}
var _built_plan: Dictionary = {}
## How many times the frame itself was built (tests).
var frame_builds := 0


func _init(design_catalog: DesignCatalog) -> void:
	catalog = design_catalog


## Builds `record` under `parent` (cleared first). `plan` and `structure`: its proposed frame
## and measured structure when already worked out (the bus keeps both per edit).
func build(record: DesignRecord, parent: Node3D, plan: Dictionary = {}, structure: DesignStructure = null) -> void:
	var next_plan := {}
	if record:
		next_plan = plan.duplicate(true) if not plan.is_empty() else DesignFrame.propose(record)
	_kept = {}
	if frame_body and is_instance_valid(frame_body) and parent == root and frame_body.get_parent() == root \
			and not next_plan.is_empty() and next_plan == _built_plan:
		root.remove_child(frame_body)
		_kept = {"body": frame_body, "frame": frame, "model": frame_model}
	rec = record
	root = parent
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()
	wall_pieces.clear()
	ramps.clear()
	doors.clear()
	lifts.clear()
	ladders.clear()
	_outline.clear()
	windows = 0
	lamps = 0
	ribs = 0
	frame = null
	frame_body = null
	frame_model = null
	frame_plan = {}
	if rec == null:
		return
	frame_plan = next_plan
	_glass = _glass_boxes()
	var stairs := stairwells(rec, catalog)
	for r: Dictionary in rec.rooms.values():
		if not DesignRecord.is_square(r):
			_slanted_room(r)  # a side at an angle: floor and ceiling cut to its outline
			continue
		# A shaped room is built a rectangle of floor and ceiling at a time.
		var cells := DesignRecord.room_cells(r)
		for i in cells.size():
			var tag := str(r.id) + ("" if i == 0 else "_%d" % i)
			_floor(r, stairs, cells[i], tag)
			_ceiling(r, shaft(r, rec.rooms[stairs[str(r.id)]]) if stairs.has(str(r.id)) else Rect2(), cells[i], tag)
	for deck in rec.decks():
		if rec.hull_outline(deck).size() >= 3:
			_open_deck(deck)
	var st := structure if structure else DesignStructure.measure(rec)
	for b: Dictionary in rec.beams.values():
		_beam(b)
	for e in st.outer_edges:
		_wall(e, true)
	for e in st.inner_edges:
		_wall(e, false)
	for low_id: String in stairs:
		if str(rec.rooms[low_id].type) in ["lift", "hatch"]:
			continue
		_stairs(rec.rooms[low_id], rec.rooms[stairs[low_id]])
	_lifts(stairs)
	_ladders(stairs)
	_frame()
	_components()
	_services()
	_draw_outline()


# Shared queries

## Lower stairs room id -> the stairs room over it.
static func stairwells(d: DesignRecord, cat: DesignCatalog) -> Dictionary:
	var out := {}
	for r: Dictionary in d.rooms.values():
		var rt := cat.room(str(r.type))
		if rt == null or not rt.links_decks:
			continue
		var rect := Rect2(r.x, r.z, r.w, r.d)
		for u: Dictionary in d.rooms_on(int(r.deck) + 1):
			var ut := cat.room(str(u.type))
			if ut and ut.links_decks and ut.id == rt.id and Rect2(u.x, u.z, u.w, u.d).intersects(rect):
				out[str(r.id)] = str(u.id)
				break
	return out


## The opening between a deck-linking room and the one over it: the stairs' flight, or a
## lift's whole shaft.
static func shaft(low: Dictionary, upper: Dictionary) -> Rect2:
	var both := Rect2(low.x, low.z, low.w, low.d).intersection(Rect2(upper.x, upper.z, upper.w, upper.d))
	if str(low.type) == "lift":
		return both
	if str(low.type) == "hatch":
		# A metre-square opening against the hatch's -Z wall, the ladder up that wall.
		var side := minf(HATCH, minf(both.size.x, both.size.y))
		return Rect2(both.get_center().x - side * 0.5, both.position.y, side, side)
	return ramp_plan(low).rect


## The flight in a stairs room: along its long side, against its start wall, climbing to a
## landing at the far end.
static func ramp_plan(r: Dictionary) -> Dictionary:
	var along_z := float(r.d) >= float(r.w)
	var length := (float(r.d) if along_z else float(r.w)) - LANDING
	var across := float(r.w) if along_z else float(r.d)
	var width := minf(RAMP_W, across * 0.5)
	var foot := Rect2(r.x, r.z, width, length) if along_z else Rect2(r.x, r.z, length, width)
	return {"rect": foot, "along_z": along_z, "length": length, "width": width}


## `rect` with `hole` cut out, as up to four rectangles.
static func minus(rect: Rect2, hole: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var h := hole.intersection(rect)
	if not h.has_area():
		out.append(rect)
		return out
	for cand in [
		Rect2(rect.position.x, rect.position.y, rect.size.x, h.position.y - rect.position.y),
		Rect2(rect.position.x, h.end.y, rect.size.x, rect.end.y - h.end.y),
		Rect2(rect.position.x, h.position.y, h.position.x - rect.position.x, h.size.y),
		Rect2(h.end.x, h.position.y, rect.end.x - h.end.x, h.size.y),
	]:
		if cand.size.x > 0.01 and cand.size.y > 0.01:
			out.append(cand)
	return out


# Floors and ceilings

func _floor(r: Dictionary, stairs: Dictionary, rect: Rect2, tag: String) -> void:
	var y := int(r.deck) * rec.deck_height
	var hole := Rect2()
	for low_id: String in stairs:
		if stairs[low_id] == str(r.id):
			hole = shaft(rec.rooms[low_id], r).intersection(rect)
	if not hole.has_area():
		hole = Rect2()
	var covered := DesignStructure.on_deck(rec, int(r.deck) - 1, rect.get_center())
	# On a deck frame its plates are the floor you see; this is what you stand on.
	var framed := not (frame_plan.get("decks", []) as Array).is_empty() and not str(r.type) in DesignFrame.LINKS
	var bed := paint(Color(0.2, 0.21, 0.23), "gunmetal")
	var plate := paint(Color(0.46, 0.48, 0.5), "bare_steel")
	var tiles: Array[Transform3D] = []
	for p in minus(rect, hole):
		# The bed: what you stand on (collision), its underside the hull where nothing is below.
		var body := _body({"kind": "floor", "room": str(r.id), "deck": int(r.deck)})
		body.position = Vector3(p.get_center().x, y - FLOOR * 0.5 - 0.01, p.get_center().y)
		_box_in(body, Vector3(p.size.x, FLOOR - 0.02, p.size.y), bed if covered else paint(Color(0.5, 0.52, 0.55), "brushed_alloy"))
		if not covered:
			(body.get_child(0) as VisualInstance3D).layers = 1 | EXTERIOR
		(body.get_child(0) as VisualInstance3D).visible = not framed
		# (A hair over the deck plates when they are the frame's, so the aim finds the floor.)
		_shape_in(body, Vector3(p.size.x, FLOOR, p.size.y), Vector3(0, 0.015 if framed else 0.01, 0))
		# Deck plates on top, with a hair of a seam between them.
		var x := p.position.x
		while x < p.end.x - 0.01:
			var x1 := minf(snappedf(x + PLATE, PLATE) if not is_equal_approx(fmod(x, PLATE), 0.0) else x + PLATE, p.end.x)
			var z := p.position.y
			while z < p.end.y - 0.01:
				var z1 := minf(snappedf(z + PLATE, PLATE) if not is_equal_approx(fmod(z, PLATE), 0.0) else z + PLATE, p.end.y)
				tiles.append(Transform3D(Basis.from_scale(Vector3(x1 - x - 0.01, 0.018, z1 - z - 0.01)),
						Vector3((x + x1) * 0.5, y - 0.009, (z + z1) * 0.5)))
				z = z1
			x = x1
	if not framed:
		_multi("DeckPlates_" + tag, tiles, plate)


## `hole`: the stairwell's opening up through this room's ceiling (none if empty).
func _ceiling(r: Dictionary, shaft_hole: Rect2, rect: Rect2, tag: String) -> void:
	var hole := shaft_hole.intersection(rect) if shaft_hole.has_area() else Rect2()
	if not hole.has_area():
		hole = Rect2()
	var top := (int(r.deck) + 1) * rec.deck_height - FLOOR
	var spec: Array = GIRDERS.get(str(rec.structure.get("frame", "standard")), GIRDERS.standard)
	var gh: float = spec[1]
	var under := top - gh
	# Ceiling panels between the beams.
	var panels: Array[Transform3D] = []
	for piece in minus(rect, hole):
		var x := piece.position.x
		while x < piece.end.x - 0.01:
			var x1 := minf(x + PANEL, piece.end.x)
			panels.append(Transform3D(Basis.from_scale(Vector3(x1 - x - 0.012, 0.02, piece.size.y - 0.02)),
					Vector3((x + x1) * 0.5, under - 0.01, piece.get_center().y)))
			x = x1
	# Under glass in the hull (a bridge's glazed roof): no ceiling or roof plate to hide it, so
	# the view goes up through it (beenster, 19 Nov: "windows don't work").
	var glazed := _glass_over(rect, top)
	if not glazed:
		_multi("Ceiling_" + tag, panels, paint(Color(0.62, 0.64, 0.65), "satin_paint"))
	# A roof of hull plate where no room stands over this one.
	if not glazed and not DesignStructure.on_deck(rec, int(r.deck) + 1, rect.get_center()):
		var roof := MeshInstance3D.new()
		roof.name = "Roof_" + tag
		roof.mesh = _box_mesh(Vector3(rect.size.x, FLOOR - 0.02, rect.size.y))
		roof.material_override = paint(Color(0.5, 0.52, 0.55), "brushed_alloy")
		roof.position = Vector3(rect.get_center().x, top + FLOOR * 0.5, rect.get_center().y)
		roof.layers = EXTERIOR
		root.add_child(roof)
	# Beams across the short way at the frame spacing, from the frame's grid.
	var spacing := maxf(float(rec.structure.get("spacing", 2.0)), 0.5)
	var across_x := rect.size.x <= rect.size.y
	var from := rect.position.y if across_x else rect.position.x
	var to := rect.end.y if across_x else rect.end.x
	var s := ceilf((from + 0.2) / spacing) * spacing
	var gw: float = spec[0]
	while s < to - 0.2 and not hole.has_area():
		var a := Vector3(rect.position.x, top - gh * 0.5, s) if across_x else Vector3(s, top - gh * 0.5, rect.position.y)
		var b := Vector3(rect.end.x, top - gh * 0.5, s) if across_x else Vector3(s, top - gh * 0.5, rect.end.y)
		_girder(a, b, gw, gh, Vector3.UP)
		s += spacing
	# Light panels and the room's lamp.
	var glow := _glow(Color(1.0, 0.96, 0.88))
	var n := maxi(int(rect.size.length() / 4.0), 1)
	for i in n:
		var t := (i + 0.5) / n
		var at := rect.position + rect.size * t if n > 1 else rect.get_center()
		var lp := MeshInstance3D.new()
		lp.mesh = _box_mesh(Vector3(1.2, 0.03, 0.3) if across_x else Vector3(0.3, 0.03, 1.2))
		lp.material_override = glow
		lp.position = Vector3(at.x, under - 0.035, at.y)
		root.add_child(lp)
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp_" + str(r.id)
	lamp.position = Vector3(rect.get_center().x, under - 0.3, rect.get_center().y)
	lamp.omni_range = maxf(rect.size.length() * 0.75, 3.5) + 1.5
	# Small rooms get a gentler lamp: their walls are close to it.
	lamp.light_energy = clampf(rect.get_area() / 24.0, 0.35, 0.9)
	lamp.light_color = Color(1.0, 0.95, 0.88)
	lamp.shadow_enabled = false
	root.add_child(lamp)
	lamps += 1


## A room with a side at an angle: its floor (what you stand on, plated), its ceiling, a roof of
## hull plate where no room is over it, and a lamp, each cut to its outline.
func _slanted_room(r: Dictionary) -> void:
	var poly := DesignRecord.room_poly(r)
	if Geometry2D.triangulate_polygon(poly).is_empty():
		return
	var deck := int(r.deck)
	var y := deck * rec.deck_height
	var mid := _centroid(poly)
	var covered := DesignStructure.on_deck(rec, deck - 1, mid)
	var framed := not (frame_plan.get("decks", []) as Array).is_empty()
	var body := _body({"kind": "floor", "room": str(r.id), "deck": deck})
	body.name = "Floor_" + str(r.id)
	var top := PackedVector3Array()
	_fan(poly, y + (0.015 if framed else 0.01), top, false)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(top)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	var under := PackedVector3Array()
	_fan(poly, y - FLOOR, under, true)
	body.add_child(_tri_mesh(under, paint(Color(0.2, 0.21, 0.23), "gunmetal") if covered
			else paint(Color(0.5, 0.52, 0.55), "brushed_alloy"), 1 if covered else 1 | EXTERIOR))
	if not framed:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_plate(st, poly, y)
		st.generate_normals()
		var pm := MeshInstance3D.new()
		pm.name = "DeckPlates_" + str(r.id)
		pm.mesh = st.commit()
		pm.material_override = paint(Color(0.46, 0.48, 0.5), "bare_steel")
		root.add_child(pm)
	var roof_y := (deck + 1) * rec.deck_height - FLOOR
	var spec: Array = GIRDERS.get(str(rec.structure.get("frame", "standard")), GIRDERS.standard)
	var low := roof_y - float(spec[1])
	var ceiling := PackedVector3Array()
	_fan(poly, low - 0.01, ceiling, true)
	var cm := _tri_mesh(ceiling, paint(Color(0.62, 0.64, 0.65), "satin_paint"), 1)
	cm.name = "Ceiling_" + str(r.id)
	root.add_child(cm)
	if not DesignStructure.on_deck(rec, deck + 1, mid):
		var roof := PackedVector3Array()
		_fan(poly, roof_y + FLOOR, roof, false)
		var rm := _tri_mesh(roof, paint(Color(0.5, 0.52, 0.55), "brushed_alloy"), EXTERIOR)
		rm.name = "Roof_" + str(r.id)
		root.add_child(rm)
	var at := mid if Geometry2D.is_point_in_polygon(mid, poly) else (poly[0] + poly[1] + poly[2]) / 3.0
	var lp := MeshInstance3D.new()
	lp.mesh = _box_mesh(Vector3(1.2, 0.03, 0.3))
	lp.material_override = _glow(Color(1.0, 0.96, 0.88))
	lp.position = Vector3(at.x, low - 0.035, at.y)
	root.add_child(lp)
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp_" + str(r.id)
	lamp.position = Vector3(at.x, low - 0.3, at.y)
	var size := Vector2(float(r.w), float(r.d))
	lamp.omni_range = maxf(size.length() * 0.75, 3.5) + 1.5
	lamp.light_energy = clampf(DesignRecord.room_area(r) / 24.0, 0.35, 0.9)
	lamp.light_color = Color(1.0, 0.95, 0.88)
	lamp.shadow_enabled = false
	root.add_child(lamp)
	lamps += 1


## The deck inside a drawn hull that no room covers: plated out to the hull's sides, one
## plate a metre square (cut to the hull where it angles), lit, and roofed where nothing is over it.
func _open_deck(deck: int) -> void:
	var outline := rec.hull_outline(deck)
	var y := deck * rec.deck_height
	var top := (deck + 1) * rec.deck_height - FLOOR
	var box := DesignStructure._bounds(outline)
	var plates := SurfaceTool.new()
	plates.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bed_up := PackedVector3Array()
	var bed_down := PackedVector3Array()
	var bed_seen := PackedVector3Array()
	var roof := PackedVector3Array()
	var lit := {}
	var x := floorf(box.position.x)
	while x < box.end.x:
		var z := floorf(box.position.y)
		while z < box.end.y:
			var cell := PackedVector2Array([Vector2(x, z), Vector2(x + PLATE, z), Vector2(x + PLATE, z + PLATE), Vector2(x, z + PLATE)])
			for piece in Geometry2D.intersect_polygons(cell, outline):
				for open in _minus_rooms(piece, deck):
					var c := _centroid(open)
					_fan(open, y - 0.018, bed_up, false)
					_fan(open, y - FLOOR, bed_down if DesignStructure.on_deck(rec, deck - 1, c) else bed_seen, true)
					for inset in Geometry2D.offset_polygon(open, -0.006):
						_plate(plates, inset, y)
					if not DesignStructure.on_deck(rec, deck + 1, c):
						_fan(open, top, roof, true)
					lit[Vector2i(floori(c.x / 5.0), floori(c.y / 5.0))] = true
			z += PLATE
		x += PLATE
	if bed_up.is_empty():
		return
	plates.generate_normals()
	var pm := MeshInstance3D.new()
	pm.name = "OpenDeckPlates_%d" % deck
	pm.mesh = plates.commit()
	pm.material_override = paint(Color(0.46, 0.48, 0.5), "bare_steel")
	root.add_child(pm)
	var body := _body({"kind": "floor", "room": "", "deck": deck})
	body.name = "OpenDeck_%d" % deck
	var shape := ConcavePolygonShape3D.new()
	var faces := PackedVector3Array()
	for v in bed_up:
		faces.append(v + Vector3(0, 0.018, 0))
	shape.set_faces(faces)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	# Its underside: the ceiling of the deck below, or hull plating where nothing is under it.
	if not bed_down.is_empty():
		body.add_child(_tri_mesh(bed_down, paint(Color(0.62, 0.64, 0.65), "satin_paint"), 1))
	if not bed_seen.is_empty():
		body.add_child(_tri_mesh(bed_seen, paint(Color(0.5, 0.52, 0.55), "brushed_alloy"), 1 | EXTERIOR))
	if not roof.is_empty():
		var rm := _tri_mesh(roof, paint(Color(0.62, 0.64, 0.65), "satin_paint"), 1 | EXTERIOR)
		rm.name = "OpenDeckRoof_%d" % deck
		root.add_child(rm)
	# A lamp over every 5 m block of open deck.
	var glow := _glow(Color(1.0, 0.96, 0.88))
	for k: Vector2i in lit:
		var at := Vector2(k.x * 5.0 + 2.5, k.y * 5.0 + 2.5)
		if not Geometry2D.is_point_in_polygon(at, outline) or rec.room_at(deck, at) != "":
			continue
		var lp := MeshInstance3D.new()
		lp.mesh = _box_mesh(Vector3(1.2, 0.03, 0.3))
		lp.material_override = glow
		lp.position = Vector3(at.x, top - 0.035, at.y)
		root.add_child(lp)
		var lamp := OmniLight3D.new()
		lamp.name = "Lamp_open_%d_%d_%d" % [deck, k.x, k.y]
		lamp.position = Vector3(at.x, top - 0.3, at.y)
		lamp.omni_range = 8.0
		lamp.light_energy = 0.85
		lamp.light_color = Color(1.0, 0.95, 0.88)
		root.add_child(lamp)
		lamps += 1


## `poly` with every room on the deck cut out of it.
func _minus_rooms(poly: PackedVector2Array, deck: int) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = [poly]
	for r in rec.rooms_on(deck):
		for sq: PackedVector2Array in [DesignRecord.room_poly(r)]:
			var next: Array[PackedVector2Array] = []
			for p in out:
				for q in Geometry2D.clip_polygons(p, sq):
					if not Geometry2D.is_polygon_clockwise(q) or q.size() < 3:
						next.append(q)
			out = next
	return out.filter(func(p): return absf(DesignStructure._area(p)) > 0.0004)


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / maxf(poly.size(), 1)


## A flat polygon as triangles at height y, appended to `out` (facing down when `down`).
static func _fan(poly: PackedVector2Array, y: float, out: PackedVector3Array, down: bool) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	for i in range(0, idx.size(), 3):
		var a := Vector3(poly[idx[i]].x, y, poly[idx[i]].y)
		var b := Vector3(poly[idx[i + 1]].x, y, poly[idx[i + 1]].y)
		var c := Vector3(poly[idx[i + 2]].x, y, poly[idx[i + 2]].y)
		# Godot's front faces wind clockwise as seen from in front.
		var up := (b - a).cross(c - a).y > 0.0
		if up != down:
			out.append_array([a, c, b])
		else:
			out.append_array([a, b, c])


## One deck plate: its top at y and a thin edge round it.
func _plate(st: SurfaceTool, poly: PackedVector2Array, y: float) -> void:
	var tris := PackedVector3Array()
	_fan(poly, y, tris, false)
	for v in tris:
		st.add_vertex(v)
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		var quad := [Vector3(p.x, y, p.y), Vector3(q.x, y, q.y), Vector3(q.x, y - 0.018, q.y), Vector3(p.x, y - 0.018, p.y)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(quad[k])


func _tri_mesh(tris: PackedVector3Array, mat: Material, layers: int) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in tris:
		st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.layers = layers
	return mi


## A beam placed by hand: a girder along the deckhead.
func _beam(b: Dictionary) -> void:
	var spec: Array = GIRDERS.get(str(rec.structure.get("frame", "standard")), GIRDERS.standard)
	var gh: float = spec[1]
	var y := (int(b.deck) + 1) * rec.deck_height - FLOOR - gh * 0.5
	var a := DesignStructure._v(b.a)
	var e := DesignStructure._v(b.b)
	_girder(Vector3(a.x, y, a.y), Vector3(e.x, y, e.y), spec[0], gh, Vector3.UP)


# Walls, frames and doors

## One wall stretch on one deck, with a doorway wherever a door stands on it.
func _wall(e: Dictionary, outer: bool) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var deck := int(e.deck)
	var y0 := deck * rec.deck_height
	var y1 := y0 + rec.deck_height - FLOOR
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var dir := (b - a) / length
	var normal := Vector2(-dir.y, dir.x)
	# Which faces are inside a room.
	var mid := (a + b) * 0.5
	var inside_pos := DesignStructure.on_deck(rec, deck, mid + normal * 0.1)
	var inside_neg := DesignStructure.on_deck(rec, deck, mid - normal * 0.1)
	var hulled := rec.hull_outline(deck).size() >= 3
	var gaps: Array[Dictionary] = []
	for d: Dictionary in rec.doors.values():
		# Without a drawn hull a room's outer door is on the outer hull; with one it can open
		# onto the deck inside it, so match doors to walls by where they stand.
		if int(d.deck) != deck or not hulled and outer != (str(d.b) == ""):
			continue
		var at := Vector2(float(d.x), float(d.z))
		var t := (at - a).dot(dir)
		if t < -0.01 or t > length + 0.01 or (a + dir * t).distance_to(at) > 0.05:
			continue
		var dw := DesignCatalog.door_w(d)
		gaps.append({"id": str(d.id), "t0": maxf(t - dw * 0.5, 0.0), "t1": minf(t + dw * 0.5, length),
				"h": DesignCatalog.door_h(d), "leaves": bool(DesignCatalog.door_kind(d).leaves),
				"style": str(DesignCatalog.door_kind(d).get("style", "split")),
				"airtight": bool(DesignCatalog.door_kind(d).get("airtight", false))})
	gaps.sort_custom(func(p, q): return p.t0 < q.t0)
	var info := {"kind": "wall", "deck": deck, "a": a, "b": b, "outer": outer}
	# Glass in the hull beside an outer wall: the wall opens there (sill to head) to look out.
	if outer and inside_pos != inside_neg:
		var out_dir := normal if inside_neg else -normal
		for w in _window_spans(a, dir, length, out_dir, y0, y1):
			var clash := false
			for g in gaps:
				clash = clash or (w.t0 < float(g.t1) and w.t1 > float(g.t0))
			if not clash:
				gaps.append(w)
		gaps.sort_custom(func(p, q): return p.t0 < q.t0)
	var start := 0.0
	for g in gaps:
		_wall_piece(info, a, dir, normal, start, g.t0, y0, y1, inside_pos, inside_neg, outer)
		if g.has("sill"):
			_wall_piece(info, a, dir, normal, g.t0, g.t1, y0, float(g.sill), inside_pos, inside_neg, outer)
			_wall_piece(info, a, dir, normal, g.t0, g.t1, float(g.head), y1, inside_pos, inside_neg, outer)
			windows += 1
			start = g.t1
			continue
		_wall_piece(info, a, dir, normal, g.t0, g.t1, y0 + float(g.h), y1, inside_pos, inside_neg, outer)
		_door(g, a, dir, normal, y0, outer)
		start = g.t1
	_wall_piece(info, a, dir, normal, start, length, y0, y1, inside_pos, inside_neg, outer)
	if outer and frame_plan.is_empty():
		_ribs(a, dir, normal if inside_pos else -normal, length, gaps, y0, y1)


func _wall_piece(info: Dictionary, a: Vector2, dir: Vector2, normal: Vector2, t0: float, t1: float,
		y0: float, y1: float, inside_pos: bool, inside_neg: bool, outer: bool) -> void:
	if t1 - t0 < 0.02 or y1 - y0 < 0.02:
		return
	var p0 := a + dir * t0
	var p1 := a + dir * t1
	var mid := (p0 + p1) * 0.5
	var basis := Basis(Vector3(dir.x, 0, dir.y), Vector3.UP, Vector3(normal.x, 0, normal.y))
	var body := _body(info)
	body.transform = Transform3D(basis, Vector3(mid.x, (y0 + y1) * 0.5, mid.y))
	var len := t1 - t0
	# An inner wall the frame builds as a stud wall: you see its panels; this keeps what you
	# bump into and aim at (a hair thicker, so the aim finds the wall before its panels).
	var studded := not outer and not (frame_plan.get("walls", []) as Array).is_empty() \
			and (absf(dir.x) > 0.999 or absf(dir.y) > 0.999)
	_box_in(body, Vector3(len, y1 - y0, WALL), paint(Color(0.24, 0.25, 0.27), "gunmetal"))
	_shape_in(body, Vector3(len, y1 - y0, DesignFrame.INNER_WALL + 0.012 if studded else WALL), Vector3.ZERO)
	wall_pieces.append({"deck": int(info.deck), "a": p0, "b": p1, "y0": y0, "y1": y1, "outer": outer})
	if studded:
		(body.get_child(0) as VisualInstance3D).visible = false
		return
	# Each face: lining panels inside a room, hull plating where it faces space.
	for side in [1.0, -1.0]:
		# Inside the frame an outer wall is the hull's lining: its back faces the frame, not space.
		var inside := (inside_pos if side > 0.0 else inside_neg) or not frame_plan.is_empty()
		var w := PANEL if inside else HULL_PANEL
		var mat := paint(Color(0.52, 0.54, 0.54), "satin_paint") if inside else paint(Color(0.5, 0.52, 0.55), "brushed_alloy")
		var panels: Array[Transform3D] = []
		var t := 0.0
		while t < len - 0.01:
			var t2 := minf(t + w, len)
			panels.append(Transform3D(Basis.from_scale(Vector3(t2 - t - 0.01, y1 - y0 - 0.02, LINING)),
					Vector3(-len * 0.5 + (t + t2) * 0.5, 0, side * (WALL + LINING) * 0.5)))
			t = t2
		_multi("Panels" if inside else "HullPlates", panels, mat, body, 1 if inside else EXTERIOR)
		if inside and y1 - y0 > 2.0:
			# A kick strip along the floor in a darker paint.
			var kick := MeshInstance3D.new()
			kick.mesh = _box_mesh(Vector3(len, 0.12, 0.012))
			kick.material_override = paint(Color(0.3, 0.32, 0.34), "satin_paint")
			kick.position = Vector3(0, -(y1 - y0) * 0.5 + 0.07, side * (WALL * 0.5 + LINING + 0.006))
			body.add_child(kick)


## The structure: the proposed frame built as parts and joints with the shared frame kit (rings,
## node blocks, stringers, welded; the skin riveted on; glass; the outer doors cut and framed),
## and a sill across the gap at each outer door from the room's wall to the skin.
func _frame() -> void:
	if frame_plan.is_empty():
		_built_plan = {}
		return
	if not _kept.is_empty():
		frame_body = _kept.body
		frame = _kept.frame
		frame_model = _kept.model
		_kept = {}
		root.add_child(frame_body)
		_sills()
		return
	frame_builds += 1
	_built_plan = frame_plan.duplicate(true)
	frame_body = RigidBody3D.new()
	frame_body.name = "Frame"
	frame_body.freeze = true
	frame_body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	frame_body.collision_layer = LAYER
	frame_body.collision_mask = 0
	frame_body.set_meta("walk", {"kind": "frame", "deck": 0})
	root.add_child(frame_body)
	var kit := ShipKit.new(frame_body)
	frame_model = PartModel.new(frame_body, true)
	kit.model = frame_model
	frame_mats = {"shell": paint(Color(0.5, 0.52, 0.55), "brushed_alloy"),
			"frame": paint(Color(0.34, 0.36, 0.38), "gunmetal"), "lining": paint(Color(0.52, 0.54, 0.54), "satin_paint"),
			"deck": paint(Color(0.46, 0.48, 0.5), "bare_steel")}
	frame = DesignFrame.build(frame_plan, kit, frame_mats)
	for v in frame_body.find_children("*", "VisualInstance3D", true, false):
		(v as VisualInstance3D).layers = 1 | EXTERIOR
	_sills()


## A sill across the gap at each outer door, from the room's wall to the skin.
func _sills() -> void:
	var st: Array = frame_plan.stations
	for o: Dictionary in frame_plan.openings:
		var g: Dictionary = rec.doors.get(str(o.name).trim_prefix("door_"), {})
		if g.is_empty():
			continue
		var at := Vector3(float(g.x), int(g.deck) * rec.deck_height, float(g.z))
		var to := at
		if int(o.edge) >= 0:
			var r := _station_rect(at.z)
			to.x = r.end.x if int(o.edge) == DesignFrame.STARBOARD else r.position.x
		else:
			to.z = float(st[0 if int(o.cap) == 0 else st.size() - 1].z)
		var gw := DesignCatalog.door_w(g)
		var size := Vector3(absf(to.x - at.x) + WALL, FLOOR, gw) if int(o.edge) >= 0 \
				else Vector3(gw, FLOOR, absf(to.z - at.z) + WALL)
		var sill := _body({"kind": "floor", "deck": int(g.deck)})
		sill.name = "Sill_%s" % str(g.id)
		sill.position = (at + to) * 0.5 + Vector3(0, -FLOOR * 0.5, 0)
		_box_in(sill, size, paint(Color(0.3, 0.32, 0.34), "gunmetal"))
		_shape_in(sill, size, Vector3.ZERO)


## The frame station nearest `z`'s section (x across, y up).
func _station_rect(z: float) -> Rect2:
	var best: Dictionary = frame_plan.stations[0]
	for s: Dictionary in frame_plan.stations:
		if absf(float(s.z) - z) < absf(float(best.z) - z):
			best = s
	return best.rect


## The frame part a ray hit (its collider and shape index), null if not the frame's.
func frame_part(collider: Object, shape: int) -> PartData:
	if frame_model == null or collider != frame_body:
		return null
	var owner := frame_body.shape_find_owner(shape)
	var cs := frame_body.shape_owner_get_owner(owner) as CollisionShape3D
	return frame_model.part_for_collider(cs) if cs else null


## The frame's joint nearest a point (walk space), null if none within `reach` m.
func frame_joint(at: Vector3, reach: float = 0.35) -> ConnectionData:
	if frame_model == null:
		return null
	return frame_model.find_connection_near(at, reach)


## Frame ribs up the inside of an outer wall, on the design's frame grid.
func _ribs(a: Vector2, dir: Vector2, inward: Vector2, length: float, gaps: Array[Dictionary], y0: float, y1: float) -> void:
	var spec: Array = GIRDERS.get(str(rec.structure.get("frame", "standard")), GIRDERS.standard)
	var spacing := maxf(float(rec.structure.get("spacing", 2.0)), 0.5)
	var gw: float = spec[0]
	var gh: float = spec[1]
	# Ribs where the frame grid crosses the wall (x for walls along z and the other way); an
	# angled hull side takes them every spacing along it.
	var t := spacing * 0.5
	if absf(dir.x) > 0.999 or absf(dir.y) > 0.999:
		var along := a.x if absf(dir.x) > 0.5 else a.y
		var sign := dir.x if absf(dir.x) > 0.5 else dir.y
		var first := ceilf((along + 0.15 * sign) / spacing) * spacing if sign > 0 else floorf((along - 0.15) / spacing) * spacing
		t = absf(first - along)
	while t < length - 0.15:
		var clear := true
		for g in gaps:
			if t > float(g.t0) - gw and t < float(g.t1) + gw:
				clear = false
		if clear and t > 0.15:
			var p := a + dir * t + inward * (WALL * 0.5 + LINING + gh * 0.5)
			_girder(Vector3(p.x, y0, p.y), Vector3(p.x, y1 - gh, p.y), gw, gh, Vector3(inward.x, 0, inward.y))
			ribs += 1
		t += spacing


func _door(g: Dictionary, a: Vector2, dir: Vector2, normal: Vector2, y0: float, outer: bool) -> void:
	var t0: float = g.t0
	var t1: float = g.t1
	var c2 := a + dir * ((t0 + t1) * 0.5)
	var basis := Basis(Vector3(dir.x, 0, dir.y), Vector3.UP, Vector3(normal.x, 0, normal.y))
	var frame := _body({"kind": "door", "id": str(g.id)})
	frame.name = "Door_" + str(g.id)
	frame.transform = Transform3D(basis, Vector3(c2.x, y0, c2.y))
	var w := t1 - t0
	var dh := float(g.get("h", DOOR_H))
	var trim := paint(Color(0.86, 0.62, 0.16), "satin_paint") if not outer else paint(Color(0.72, 0.2, 0.15), "satin_paint")
	var depth := WALL + LINING * 2.0 + 0.04
	for side in [-1.0, 1.0]:
		var jamb := MeshInstance3D.new()
		jamb.mesh = _box_mesh(Vector3(0.08, dh, depth))
		jamb.material_override = trim
		jamb.position = Vector3(side * (w * 0.5 - 0.04), dh * 0.5, 0)
		frame.add_child(jamb)
		_outline_box(frame.transform * Transform3D(Basis.IDENTITY, jamb.position), Vector3(0.08, dh, depth))
	var head := MeshInstance3D.new()
	head.mesh = _box_mesh(Vector3(w, 0.1, depth))
	head.material_override = trim
	head.position = Vector3(0, dh - 0.05, 0)
	frame.add_child(head)
	# The sill is flush with the deck plates; a hazard tread strip on it.
	var sill := MeshInstance3D.new()
	sill.mesh = _box_mesh(Vector3(w - 0.16, 0.012, depth))
	sill.material_override = paint(Color(0.9, 0.7, 0.1), "hazard_stripes")
	sill.position = Vector3(0, 0.002, 0)
	frame.add_child(sill)
	_shape_in(frame, Vector3(0.08, dh, depth), Vector3(-(w * 0.5 - 0.04), dh * 0.5, 0))
	_shape_in(frame, Vector3(0.08, dh, depth), Vector3(w * 0.5 - 0.04, dh * 0.5, 0))
	if not bool(g.get("leaves", true)):
		return  # an open doorway: frame and sill, no leaves
	var style := str(g.get("style", "split"))
	var steel := paint(Color(0.56, 0.58, 0.6), "brushed_steel")
	var clear := w - 0.16
	if style == "split":
		# Two leaves that slide apart into the wall.
		var half := clear * 0.5
		var leaves: Array[Node3D] = []
		for side in [-1.0, 1.0]:
			var leaf := _leaf(Vector3(half, dh - 0.12, 0.05), steel, trim)
			leaf.position = Vector3(side * half * 0.5, (dh - 0.1) * 0.5, 0)
			frame.add_child(leaf)
			leaves.append(leaf)
		doors.append({"id": str(g.id), "centre": Vector3(c2.x, y0 + 1.0, c2.y), "left": leaves[0], "right": leaves[1],
				"half": half, "open": 0.0, "style": style})
		return
	# One leaf: it slides aside, swings on hinges at one jamb, or rolls up into the head.
	var thick := 0.12 if bool(g.get("airtight", false)) else (0.04 if style == "swing" else 0.05)
	var leaf := _leaf(Vector3(clear, dh - 0.12, thick), steel if style != "roll" else paint(Color(0.42, 0.44, 0.46), "gunmetal"), trim)
	var holder: Node3D = leaf
	if style == "swing":
		# Hung from the left jamb: a pivot there, the leaf beside it.
		var pivot := Node3D.new()
		pivot.name = "Hinge"
		pivot.position = Vector3(-clear * 0.5, (dh - 0.1) * 0.5, 0)
		leaf.position = Vector3(clear * 0.5, 0, 0)
		pivot.add_child(leaf)
		frame.add_child(pivot)
		holder = pivot
	else:
		leaf.position = Vector3(0, (dh - 0.1) * 0.5, 0)
		frame.add_child(leaf)
	if bool(g.get("airtight", false)):
		# A pressure door's locking wheel, both faces.
		for face in [-1.0, 1.0]:
			var wheel := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.13
			tm.outer_radius = 0.17
			wheel.mesh = tm
			wheel.material_override = trim
			wheel.rotation = Vector3(PI * 0.5, 0, 0)
			wheel.position = Vector3(0, 0.05, face * (thick * 0.5 + 0.02))
			leaf.add_child(wheel)
	doors.append({"id": str(g.id), "centre": Vector3(c2.x, y0 + 1.0, c2.y), "left": holder, "right": holder,
			"half": clear, "open": 0.0, "style": style, "rest": holder.position, "h": dh - 0.12})


## A door leaf with a trim stripe across it.
func _leaf(size: Vector3, mat: Material, trim: Material) -> MeshInstance3D:
	var leaf := MeshInstance3D.new()
	leaf.name = "Leaf"
	leaf.mesh = _box_mesh(size)
	leaf.material_override = mat
	var stripe := MeshInstance3D.new()
	stripe.mesh = _box_mesh(Vector3(size.x, 0.08, size.z + 0.006))
	stripe.material_override = trim
	stripe.position = Vector3(0, 0.1, 0)
	leaf.add_child(stripe)
	return leaf


## Opens each door as someone comes near (`near`: room-space points) and closes it after.
func update_doors(near: Array[Vector3], delta: float) -> void:
	for d in doors:
		if not is_instance_valid(d.left):
			continue
		var want := 0.0
		for p in near:
			if p.distance_to(d.centre) < 2.4:
				want = 1.0
		# A lift's doors stay shut on every deck but the one it stands at.
		if d.has("lift") and (int(d.lift.at) != int(d.deck) or int(d.lift.at) != int(d.lift.target)):
			want = 0.0
		d.open = move_toward(float(d.open), want, delta * 2.5)
		var s := smoothstep(0.0, 1.0, float(d.open))
		var half: float = d.half
		match str(d.get("style", "split")):
			"slide":
				(d.left as Node3D).position.x = (d.rest as Vector3).x - s * half * 0.95
			"swing":
				(d.left as Node3D).rotation.y = s * deg_to_rad(100.0)
			"roll":
				var leaf := d.left as Node3D
				var h: float = d.h
				leaf.scale.y = 1.0 - 0.92 * s
				leaf.position.y = (d.rest as Vector3).y + h * 0.46 * s
			_:
				(d.left as Node3D).position.x = -half * 0.5 - s * half * 0.95
				(d.right as Node3D).position.x = half * 0.5 + s * half * 0.95


# Lifts

## Each lift shaft: a platform that rides between the decks its lift rooms stack over, a gate
## across the shaft on every deck it isn't at, and the shaft's doors only open where it is.
func _lifts(stairs: Dictionary) -> void:
	var h := rec.deck_height
	for low_id: String in stairs:
		var low: Dictionary = rec.rooms[low_id]
		if str(low.type) != "lift" or stairs.values().has(low_id):
			continue  # only from the bottom of each stack
		var stack: Array = [low]
		var next := low_id
		while stairs.has(next):
			next = stairs[next]
			stack.append(rec.rooms[next])
		var rect := Rect2(low.x, low.z, low.w, low.d)
		for r in stack:
			rect = rect.intersection(Rect2(r.x, r.z, r.w, r.d))
		var decks: Array[int] = []
		var rooms := {}
		for r in stack:
			decks.append(int(r.deck))
			rooms[int(r.deck)] = str(r.id)
		var plat := AnimatableBody3D.new()
		plat.name = "Lift_" + low_id
		plat.collision_layer = LAYER
		plat.collision_mask = 0
		plat.sync_to_physics = false
		plat.set_meta("walk", {"kind": "floor", "room": low_id, "deck": decks[0]})
		var size := Vector3(rect.size.x - 0.08, FLOOR, rect.size.y - 0.08)
		_box_in(plat, size, paint(Color(0.46, 0.48, 0.5), "bare_steel"))
		(plat.get_child(0) as Node3D).position.y = -FLOOR * 0.5
		_shape_in(plat, size, Vector3(0, -FLOOR * 0.5, 0))
		var edge := MeshInstance3D.new()
		edge.mesh = _box_mesh(Vector3(size.x, 0.012, size.z))
		edge.material_override = paint(Color(0.9, 0.7, 0.1), "hazard_stripes")
		edge.position.y = 0.006
		edge.scale = Vector3(1, 1, 1)
		plat.add_child(edge)
		var inner := MeshInstance3D.new()
		inner.mesh = _box_mesh(Vector3(size.x - 0.3, 0.014, size.z - 0.3))
		inner.material_override = paint(Color(0.46, 0.48, 0.5), "bare_steel")
		inner.position.y = 0.007
		plat.add_child(inner)
		plat.position = Vector3(rect.get_center().x, decks[0] * h, rect.get_center().y)
		root.add_child(plat, true)
		_outline_box(Transform3D(Basis.IDENTITY, plat.position + Vector3(0, 0.03, 0)), Vector3(size.x, 0.06, size.z))
		var gates := {}
		for k in decks:
			var gate := _body({"kind": "lift_gate", "room": rooms[k], "deck": k})
			gate.name = "LiftGate_%s_%d" % [low_id, k]
			gate.position = Vector3(rect.get_center().x, k * h + 1.2, rect.get_center().y)
			_shape_in(gate, Vector3(rect.size.x - 0.1, 2.2, rect.size.y - 0.1), Vector3.ZERO)
			gates[k] = gate
		var lift := {"id": low_id, "body": plat, "rect": rect, "decks": decks, "rooms": rooms, "gates": gates,
				"at": decks[0], "target": decks[0], "dwell": 0.0}
		lifts.append(lift)
		_set_gates(lift)
	# The shaft's doors belong to their lift.
	for d in doors:
		var door: Dictionary = rec.doors.get(str(d.id), {})
		for lift in lifts:
			for k: int in lift.rooms:
				if str(door.get("a", "")) == lift.rooms[k] or str(door.get("b", "")) == lift.rooms[k]:
					d["lift"] = lift
					d["deck"] = k


func _set_gates(lift: Dictionary) -> void:
	var moving: bool = int(lift.at) != int(lift.target)
	for k: int in lift.gates:
		var off := moving or k == int(lift.at)
		for c in (lift.gates[k] as Node).get_children():
			(c as CollisionShape3D).disabled = off


## Rides each lift: someone standing on it for a moment sends it to the other end of its shaft;
## someone by its door on another deck calls it. `near`: the walkers' positions (capsule middles).
func update_lifts(near: Array[Vector3], delta: float) -> void:
	var h := rec.deck_height if rec else 3.0
	for lift in lifts:
		var plat: AnimatableBody3D = lift.body
		if not is_instance_valid(plat):
			continue
		var rect: Rect2 = lift.rect
		var decks: Array = lift.decks
		if int(lift.at) != int(lift.target):
			var y := move_toward(plat.position.y, int(lift.target) * h, LIFT_SPEED * delta)
			plat.position.y = y
			if is_equal_approx(y, int(lift.target) * h):
				lift.at = lift.target
				lift.hold = true  # you step off before it goes again
				_set_gates(lift)
			continue
		var riding := false
		var called := -1
		for p in near:
			var feet := p.y - 0.9
			var on := rect.has_point(Vector2(p.x, p.z))
			if on and absf(feet - plat.position.y) < 0.4:
				riding = true
			elif rect.grow(1.6).has_point(Vector2(p.x, p.z)):
				for k: int in decks:
					if k != int(lift.at) and absf(feet - k * h) < 0.6:
						called = k
		if not riding:
			lift.hold = false
		lift.dwell = float(lift.dwell) + delta if riding and not lift.get("hold", false) else 0.0
		if riding and float(lift.dwell) > LIFT_DWELL:
			var i := decks.find(int(lift.at))
			lift.target = decks[i + 1] if i + 1 < decks.size() else decks[0]
			lift.dwell = 0.0
		elif called >= 0 and not riding:
			lift.target = called
		if int(lift.target) != int(lift.at):
			_set_gates(lift)


# Hatches

## A hatch: an opening through the deck over it, a hazard rim round the opening, and a ladder
## up the hatch's back wall (its -Z side) from the floor to a hand-hold over the deck above.
func _ladders(stairs: Dictionary) -> void:
	var h := rec.deck_height
	for low_id: String in stairs:
		var low: Dictionary = rec.rooms[low_id]
		if str(low.type) != "hatch":
			continue
		var up: Dictionary = rec.rooms[stairs[low_id]]
		var rect := shaft(low, up)
		var y0 := int(low.deck) * h
		var y1 := int(up.deck) * h
		var steel := paint(Color(0.86, 0.62, 0.16), "satin_paint")
		var wall_z := rect.position.y + WALL * 0.5 + LINING + 0.12
		var cx := rect.get_center().x
		for side in [-0.22, 0.22]:
			var rail := MeshInstance3D.new()
			rail.mesh = _box_mesh(Vector3(0.04, y1 - y0 + 1.0, 0.04))
			rail.material_override = steel
			rail.position = Vector3(cx + side, (y0 + y1 + 1.0) * 0.5, wall_z)
			root.add_child(rail)
		var rungs: Array[Transform3D] = []
		var y := y0 + 0.3
		while y < y1 + 0.95:
			rungs.append(Transform3D(Basis.from_scale(Vector3(0.44, 0.03, 0.03)), Vector3(cx, y, wall_z)))
			y += 0.3
		_multi("Ladder_" + low_id, rungs, steel)
		_outline_box(Transform3D(Basis.IDENTITY, Vector3(cx, (y0 + y1 + 1.0) * 0.5, wall_z)), Vector3(0.48, y1 - y0 + 1.0, 0.06))
		var rim := MeshInstance3D.new()
		rim.mesh = _box_mesh(Vector3(rect.size.x, 0.014, rect.size.y))
		rim.material_override = paint(Color(0.9, 0.7, 0.1), "hazard_stripes")
		rim.position = Vector3(rect.get_center().x, y1 + 0.007, rect.get_center().y)
		rim.scale = Vector3(1.0, 1.0, 1.0)
		var frame := MeshInstance3D.new()
		frame.mesh = _box_mesh(Vector3(rect.size.x + 0.16, 0.012, rect.size.y + 0.16))
		frame.material_override = rim.material_override
		frame.position = Vector3(rect.get_center().x, y1 + 0.006, rect.get_center().y)
		root.add_child(frame)
		ladders.append({"id": low_id, "rect": rect, "y0": y0, "y1": y1})


## The ladder someone at `p` (capsule middle) is on, or {}.
func ladder_at(p: Vector3) -> Dictionary:
	for l in ladders:
		var feet := p.y - 0.9
		var zone: Rect2 = l.rect
		if feet > float(l.y1) - 0.05:
			zone = zone.grow(0.45)  # stepping off at the top carries you clear of the opening
		if zone.has_point(Vector2(p.x, p.z)) and feet > float(l.y0) - 0.1 and feet < float(l.y1) + 0.3:
			return l
	return {}


# Stairs

func _stairs(r: Dictionary, upper: Dictionary) -> void:
	var plan := ramp_plan(r)
	var rect: Rect2 = plan.rect
	var h := rec.deck_height
	var y := int(r.deck) * h
	var length: float = plan.length
	var along_z: bool = plan.along_z
	# What you walk on: a smooth slope (no collision on the steps).
	var ramp := StaticBody3D.new()
	ramp.name = "Ramp_" + str(r.id)
	ramp.collision_layer = LAYER
	ramp.collision_mask = 0
	ramp.set_meta("walk", {"kind": "floor", "room": str(r.id), "deck": int(r.deck)})
	var angle := atan2(h, length)
	var c := rect.get_center()
	ramp.position = Vector3(c.x, y + h * 0.5 - 0.06, c.y)
	if along_z:
		ramp.rotation.x = -angle
	else:
		ramp.rotation.z = angle
	var slope := Vector2(length, h).length()
	_shape_in(ramp, Vector3(rect.size.x, 0.06, slope) if along_z else Vector3(slope, 0.06, rect.size.y), Vector3.ZERO)
	root.add_child(ramp)
	ramps.append(str(r.id))
	# The steps you see.
	var n := maxi(int(ceilf(h / 0.2)), 2)
	var tread := paint(Color(0.46, 0.48, 0.5), "bare_steel")
	var steps: Array[Transform3D] = []
	for i in n:
		var rise := h * (i + 1) / n
		var run0 := length * i / n
		var run1 := length * (i + 1) / n
		var sz := Vector3(rect.size.x - 0.04, rise, run1 - run0) if along_z else Vector3(run1 - run0, rise, rect.size.y - 0.04)
		var at := Vector3(c.x, y + rise * 0.5 - 0.002, rect.position.y + (run0 + run1) * 0.5) if along_z \
				else Vector3(rect.position.x + (run0 + run1) * 0.5, y + rise * 0.5 - 0.002, c.y)
		steps.append(Transform3D(Basis.from_scale(sz), at))
	_multi("Steps_" + str(r.id), steps, tread)
	var lo := Vector3(rect.position.x, y, rect.position.y)
	var hi := Vector3(rect.end.x, y + h, rect.end.y)
	_outline_box(Transform3D(Basis.IDENTITY, (lo + hi) * 0.5), hi - lo)
	# A rail round the open sides of the stairwell on the deck above.
	var hole := rect.intersection(Rect2(upper.x, upper.z, upper.w, upper.d))
	var up := Rect2(upper.x, upper.z, upper.w, upper.d)
	var top := y + h
	var edges := [
		[Vector2(hole.end.x, hole.position.y), Vector2(hole.end.x, hole.end.y)],
		[Vector2(hole.position.x, hole.end.y), Vector2(hole.end.x, hole.end.y)],
		[Vector2(hole.position.x, hole.position.y), Vector2(hole.position.x, hole.end.y)],
		[Vector2(hole.position.x, hole.position.y), Vector2(hole.end.x, hole.position.y)],
	]
	for e in edges:
		var ea: Vector2 = e[0]
		var eb: Vector2 = e[1]
		var m := (ea + eb) * 0.5
		var on_wall := absf(m.x - up.position.x) < 0.02 or absf(m.x - up.end.x) < 0.02 \
				or absf(m.y - up.position.y) < 0.02 or absf(m.y - up.end.y) < 0.02
		# The top end of the flight stays open: you walk off it onto the landing.
		var top_end := (along_z and absf(m.y - hole.end.y) < 0.02 and absf(ea.y - eb.y) < 0.02) \
				or (not along_z and absf(m.x - hole.end.x) < 0.02 and absf(ea.x - eb.x) < 0.02)
		if on_wall or top_end:
			continue
		_rail(ea, eb, top)


func _rail(a: Vector2, b: Vector2, y: float) -> void:
	var steel := paint(Color(0.85, 0.62, 0.16), "satin_paint")
	var body := _body({"kind": "rail"})
	body.name = "Rail"
	var mid := (a + b) * 0.5
	var len := a.distance_to(b)
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	body.position = Vector3(mid.x, y + 0.5, mid.y)
	var bar := Vector3(len, 0.05, 0.05) if along_x else Vector3(0.05, 0.05, len)
	for hy in [0.48, 0.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(bar)
		mi.material_override = steel
		mi.position.y = hy
		body.add_child(mi)
	var posts := maxi(int(len / 1.0), 1)
	for i in posts + 1:
		var t := -0.5 + float(i) / posts
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(Vector3(0.05, 1.0, 0.05))
		mi.material_override = steel
		mi.position = Vector3(t * len, 0, 0) if along_x else Vector3(0, 0, t * len)
		body.add_child(mi)
	_shape_in(body, Vector3(bar.x, 1.0, bar.z), Vector3.ZERO)
	_outline.append_array([Vector3(a.x, y + 1.0, a.y), Vector3(b.x, y + 1.0, b.y)])


# Services

## Wires in cable trays under the ceiling, fuel pipes on brackets low down, risers between
## decks where a run carries on over another's end: where they will really go.
func _services() -> void:
	var h := rec.deck_height
	var spec: Array = GIRDERS.get(str(rec.structure.get("frame", "standard")), GIRDERS.standard)
	var tray_y := h - FLOOR - float(spec[1]) - 0.12
	var pipe_y := 0.35
	var tray := paint(Color(0.55, 0.57, 0.6), "galvanised")
	# With the structure framed the services hide where a real ship's do: cables beside a stud
	# wall go into its cavity, pipes on the lowest deck under its deck plates. You see them
	# faintly through what hides them (the x-ray lines).
	var under_deck := not (frame_plan.get("decks", []) as Array).is_empty()
	var xray: Array = []  # [a, b, colour]
	for w: Dictionary in rec.runs.values():
		var kind := str(w.kind)
		if not DesignServices.KINDS.has(kind):
			continue
		var col: Color = DesignServices.KINDS[kind].colour
		var pts := DesignServices.points(w)
		var in_wall := {}
		if kind == "wire":
			var routed := _into_walls(pts, int(w.deck))
			in_wall = routed.moved
			pts = routed.pts
		var below := kind != "wire" and under_deck and int(w.deck) == 0
		var y := int(w.deck) * h + (tray_y if kind == "wire" else (UNDER_DECK if below else pipe_y))
		var mat := paint(col.darkened(0.25), "satin_paint") if kind == "wire" else paint(col.darkened(0.15), "gloss_paint")
		for i in pts.size() - 1:
			var a := Vector3(pts[i].x, y, pts[i].y)
			var b := Vector3(pts[i + 1].x, y, pts[i + 1].y)
			if a.distance_to(b) < 0.01:
				continue
			var xf := FrameParts.along(a, b, Vector3.UP)
			var len := a.distance_to(b)
			if in_wall.has(i) or below:
				xray.append([a, b, col])
			if in_wall.has(i):
				# A cable bundle up in the wall's cavity, behind its panels.
				var cw := MeshInstance3D.new()
				cw.name = "CableInWall"
				cw.mesh = _box_mesh(Vector3(len + 0.1, 0.06, 0.06))
				cw.material_override = mat
				cw.transform = xf
				root.add_child(cw, true)
				continue
			if kind == "wire":
				# The tray, and the cable bundle lying in it.
				var t := MeshInstance3D.new()
				t.name = "CableTray"
				t.mesh = _box_mesh(Vector3(len + 0.2, 0.05, 0.24))
				t.material_override = tray
				t.transform = xf
				root.add_child(t, true)
				var cab := MeshInstance3D.new()
				cab.mesh = _box_mesh(Vector3(len + 0.2, 0.05, 0.14))
				cab.material_override = mat
				cab.transform = xf.translated_local(Vector3(0, 0.045, 0))
				root.add_child(cab)
			else:
				var pipe := MeshInstance3D.new()
				pipe.name = "PipeUnderDeck" if below else "Pipe"
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.045
				cyl.bottom_radius = 0.045
				cyl.height = len + 0.09
				cyl.radial_segments = 12
				pipe.mesh = cyl
				pipe.material_override = mat
				pipe.transform = xf * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO)
				root.add_child(pipe, true)
				# Flanges every 2 m.
				var n := int(len / 2.0)
				for k in n:
					var fl := MeshInstance3D.new()
					var fc := CylinderMesh.new()
					fc.top_radius = 0.07
					fc.bottom_radius = 0.07
					fc.height = 0.04
					fl.mesh = fc
					fl.material_override = paint(Color(0.6, 0.62, 0.64), "brushed_steel")
					fl.transform = xf * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-len * 0.5 + (k + 1) * len / (n + 1), 0, 0))
					root.add_child(fl)
		# Risers: up to the deck above where a run of this kind carries on from this one's end.
		for end in [pts[0], pts[pts.size() - 1]]:
			for u: Dictionary in rec.runs.values():
				if str(u.kind) != kind or int(u.deck) != int(w.deck) + 1:
					continue
				var up := DesignServices.points(u)
				if up.is_empty() or (up[0].distance_to(end) > DesignServices.JOIN and up[up.size() - 1].distance_to(end) > DesignServices.JOIN):
					continue
				var y2 := (int(w.deck) + 1) * h + (tray_y if kind == "wire" else pipe_y)
				var r := MeshInstance3D.new()
				r.name = "Riser"
				if kind == "wire":
					r.mesh = _box_mesh(Vector3(0.12, y2 - y, 0.12))
				else:
					var rc := CylinderMesh.new()
					rc.top_radius = 0.045
					rc.bottom_radius = 0.045
					rc.height = y2 - y
					rc.radial_segments = 12
					r.mesh = rc
				r.material_override = mat
				r.position = Vector3(end.x, (y + y2) * 0.5, end.y)
				root.add_child(r, true)
	_xray(xray)


## Where a cable run's stretches lie along a stud wall on its deck (within reach of its line,
## mostly over its span): moved onto the wall's line, into its cavity. Returns the stretches
## moved (index -> true) and the points: {moved, pts}.
func _into_walls(from: PackedVector2Array, deck: int) -> Dictionary:
	var pts := from.duplicate()
	var moved := {}
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		for wl: Dictionary in frame_plan.get("walls", []):
			if int(wl.deck) != deck:
				continue
			var across: bool = wl.across
			# Along the wall: the stretch runs the way the wall does.
			if across != (absf(a.y - b.y) < 0.01) or (not across and absf(a.x - b.x) > 0.01):
				continue
			var off := (a.y if across else a.x) - float(wl.at)
			if absf(off) > WALL_REACH:
				continue
			var lo := minf(a.x, b.x) if across else minf(a.y, b.y)
			var hi := maxf(a.x, b.x) if across else maxf(a.y, b.y)
			var over := minf(hi, float(wl.t1)) - maxf(lo, float(wl.t0))
			if over < (hi - lo) * 0.5:
				continue
			if across:
				pts[i].y = float(wl.at)
				pts[i + 1].y = float(wl.at)
			else:
				pts[i].x = float(wl.at)
				pts[i + 1].x = float(wl.at)
			moved[i] = true
			break
	return {"moved": moved, "pts": pts}


## The hidden services drawn faintly through whatever hides them, in their colours.
func _xray(lines: Array) -> void:
	if lines.is_empty():
		return
	var im := ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.vertex_color_use_as_albedo = true
	im.surface_begin(Mesh.PRIMITIVE_LINES, m)
	for l: Array in lines:
		var c: Color = l[2]
		c.a = 0.7
		im.surface_set_color(c)
		im.surface_add_vertex(l[0])
		im.surface_set_color(c)
		im.surface_add_vertex(l[1])
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.name = "ServiceXray"
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


# Parts

func _components() -> void:
	for c: Dictionary in rec.components.values():
		var pt := catalog.part(str(c.type))
		var r: Dictionary = rec.rooms.get(c.room, {})
		if pt == null or r.is_empty():
			continue
		var f := DesignRules.footprint(c, pt)
		var y := float(r.deck) * rec.deck_height
		var h := minf(pt.size.y, rec.deck_height - FLOOR - 0.3)
		var body := _body({"kind": "component", "id": str(c.id)})
		body.name = "Part_" + str(c.id)
		body.position = Vector3(f.get_center().x, y, f.get_center().y)
		component_look(body, pt, Vector3(f.size.x, h, f.size.y), int(c.get("rot", 0)), self)
		_shape_in(body, Vector3(f.size.x, h, f.size.y), Vector3(0, h * 0.5, 0))
		_outline_box(Transform3D(Basis.IDENTITY, body.position + Vector3(0, h * 0.5, 0)), Vector3(f.size.x, h, f.size.y))
	for m: Dictionary in rec.mounts.values():
		_mount(m)


## A part on the outside of the hull, against its plating, its front facing out, halfway up
## the deck's wall.
func _mount(m: Dictionary) -> void:
	var pt := catalog.part(str(m.type))
	if pt == null:
		return
	var body := _body({"kind": "mount", "id": str(m.id)})
	body.name = "Mount_" + str(m.id)
	# Against the plating, its front (-Z) turned to the hull's outward normal; a landing leg
	# under the hull's edge (DesignRules.mount_transform).
	body.transform = DesignRules.mount_transform(rec, m, pt)
	var vs := VsParts.instance(pt.shared_part) if pt.shared_part != "" else null
	var model := part_model(pt) if vs == null else null
	if vs != null:
		var bb := VsParts.shape(pt.shared_part).mesh.get_aabb()
		vs.scale = Vector3.ONE * pt.model_scale
		if pt.nozzle_down:
			# Laid over: its nozzle (-Y) to the front (-Z), out from the hull.
			vs.rotation.x = PI * 0.5
			vs.position = Vector3(0, pt.size.y * 0.5, 0) - vs.basis * bb.get_center()
		else:
			vs.position.y = -bb.position.y * pt.model_scale
		body.add_child(vs)
	elif model != null:
		# BSX's own model: built mounting face to +Z, standing out from the hull to -Z.
		model.scale = Vector3.ONE * pt.model_scale
		body.add_child(model)
	else:
		_box_in(body, pt.size, paint(pt.colour.darkened(0.25), "metallic_paint"))
		(body.get_child(0) as Node3D).position.y = pt.size.y * 0.5
	for c in body.find_children("*", "VisualInstance3D", true, false):
		(c as VisualInstance3D).layers = 1 | EXTERIOR
	_shape_in(body, pt.size, Vector3(0, pt.size.y * 0.5, 0))
	_outline_box(body.transform * Transform3D(Basis.IDENTITY, Vector3(0, pt.size.y * 0.5, 0)), pt.size)


## BSX's own detailed model of a part Void Salvage has no part for (PartModels, by its base
## catalogue id), at its base size; null when there is none or design.part_models is off.
static func part_model(pt: DesignPartType) -> Node3D:
	if not Flags.is_on("design.part_models"):
		return null
	return PartModels.instance(pt.base_id if pt.base_id != "" else pt.id)


## A part as a fitted unit: a dark plinth, its body in its colour, a panel on its working
## face (FRONTS[rot]) and a trim round the top. Origin at the floor, middle of its footprint.
static func component_look(parent: Node3D, pt: DesignPartType, size: Vector3, rot: int, kit: Object) -> void:
	var vs := VsParts.instance(pt.shared_part) if pt.shared_part != "" else null
	if vs != null:
		# Void Salvage's own part, its front (-Z) turned to FRONTS[rot], standing on the floor.
		var bb := VsParts.shape(pt.shared_part).mesh.get_aabb()
		# A bigger or smaller size class than the part as Void Salvage builds it.
		vs.scale = Vector3.ONE * pt.model_scale
		vs.rotation.y = rot * PI * 0.5
		vs.position.y = -bb.position.y * pt.model_scale
		parent.add_child(vs)
		return
	var model := part_model(pt)
	if model != null:
		# BSX's own detailed model (PartModels), its front (-Z) turned to FRONTS[rot].
		model.scale = Vector3.ONE * pt.model_scale
		model.rotation.y = rot * PI * 0.5
		parent.add_child(model)
		return
	var plinth := MeshInstance3D.new()
	plinth.mesh = _box_mesh(Vector3(size.x - 0.06, 0.08, size.z - 0.06))
	plinth.material_override = kit.call("paint", Color(0.18, 0.19, 0.2), "gunmetal")
	plinth.position.y = 0.04
	parent.add_child(plinth)
	var body := MeshInstance3D.new()
	body.mesh = _box_mesh(Vector3(size.x, size.y - 0.1, size.z))
	body.material_override = kit.call("paint", pt.colour.darkened(0.25), "metallic_paint")
	body.position.y = 0.08 + (size.y - 0.1) * 0.5
	parent.add_child(body)
	var cap := MeshInstance3D.new()
	cap.mesh = _box_mesh(Vector3(size.x + 0.02, 0.04, size.z + 0.02))
	cap.material_override = kit.call("paint", Color(0.62, 0.64, 0.66), "brushed_steel")
	cap.position.y = size.y - 0.02
	parent.add_child(cap)
	# The working face: a recessed panel with a lit strip, facing where the fitter stands.
	var front: Vector2 = DesignRules.FRONTS[rot % 4]
	var face_w := (size.z if absf(front.x) > 0.5 else size.x) * 0.7
	var panel := MeshInstance3D.new()
	panel.mesh = _box_mesh(Vector3(face_w, size.y * 0.45, 0.02))
	panel.material_override = kit.call("paint", Color(0.12, 0.13, 0.14), "plastic")
	var depth := (size.x if absf(front.x) > 0.5 else size.z) * 0.5 + 0.01
	panel.position = Vector3(front.x * depth, size.y * 0.55, front.y * depth)
	panel.rotation.y = atan2(front.x, front.y)
	parent.add_child(panel)
	var strip := MeshInstance3D.new()
	strip.mesh = _box_mesh(Vector3(face_w * 0.8, 0.03, 0.01))
	strip.material_override = kit.call("glow_mat", pt.colour.lightened(0.35))
	strip.position = Vector3(0, size.y * 0.14, 0.011)
	panel.add_child(strip)


# Kit

func paint(c: Color, finish: String) -> ShaderMaterial:
	var key := "%s/%s" % [c.to_html(), finish]
	if not _paints.has(key):
		var info := SurfaceFinish.info(finish)
		var m := ShaderMaterial.new()
		m.shader = SURFACE
		m.set_shader_parameter("albedo", Color(c.r, c.g, c.b))
		m.set_shader_parameter("metallic", float(info.get("metallic", 0.3)))
		m.set_shader_parameter("roughness", float(info.get("roughness", 0.5)))
		m.set_shader_parameter("survey_skip", true)
		SurfaceFinish.apply(m)
		SurfaceFinish.set_finish(m, finish, Color(c.r, c.g, c.b, 1.0))
		m.set_shader_parameter("material_blend", 0.0)
		_paints[key] = m
	return _paints[key]


func glow_mat(c: Color) -> StandardMaterial3D:
	return _glow(c)


func _glow(c: Color) -> StandardMaterial3D:
	var key := "glow/" + c.to_html()
	if not _paints.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		_paints[key] = m
	return _paints[key]


func _body(info: Dictionary) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = LAYER
	b.collision_mask = 0
	b.set_meta("walk", info)
	root.add_child(b, true)
	return b


func _shape_in(body: Node3D, size: Vector3, at: Vector3) -> void:
	var s := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	s.shape = box
	s.position = at
	body.add_child(s)


func _box_in(body: Node3D, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(size)
	mi.material_override = mat
	body.add_child(mi)


static func _box_mesh(size: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm


## Unit boxes scaled and placed by `xforms`, one draw for the lot.
func _multi(id: String, xforms: Array[Transform3D], mat: Material, parent: Node3D = null, layers := 1) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _box_mesh(Vector3.ONE)
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = id
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.layers = layers
	(parent if parent else root).add_child(mmi, true)


func _girder(a: Vector3, b: Vector3, w: float, h: float, up: Vector3) -> void:
	var g: Array = FrameParts.girder_between(a, b, w, h, up)
	var mi := MeshInstance3D.new()
	mi.name = "Girder"
	mi.mesh = (g[0] as PartShapes.PartShape).mesh
	mi.transform = g[1]
	mi.material_override = paint(Color(0.34, 0.36, 0.39), "gunmetal")
	root.add_child(mi, true)


func _outline_box(xf: Transform3D, size: Vector3) -> void:
	var h := size * 0.5
	var c: Array[Vector3] = []
	for i in 8:
		c.append(xf * Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1)))
	for pair in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
		_outline.append_array([c[pair[0]], c[pair[1]]])


func _draw_outline() -> void:
	if _outline.is_empty():
		return
	var im := ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = OUTLINE
	im.surface_begin(Mesh.PRIMITIVE_LINES, m)
	for p in _outline:
		im.surface_add_vertex(p)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.name = "HoloOutline"
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
