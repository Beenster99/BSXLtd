class_name TradesPlateShapes
extends RefCounted
## Plate templates as shapes: the cutting bed's own library of stock sizes, measuring a
## traced plate into a template, fitting a template on a stock plate, and the meshes of a cut
## piece and what's left of the plate (beenster, 0.3.23: "a player makes a template by tracing
## the line of the plate, this is then measured by the system and a template created which can
## be fed into the plasma cutter. The plasma cutter can store its own template sizes").
##
## A template is a Dictionary {id, name, outline (PackedVector2Array, metres, centred on 0,
## anticlockwise), size (Vector2 m, its bounding box), kind ("library" or "traced"), source
## (what it was traced from, "" for the library)}.

## The bed's stored sizes: [id, name, maker(args)].
const LIBRARY := [
	["L-RECT-1000x500", "Rectangle 1000 x 500", "rect", [1.0, 0.5]],
	["L-SQ-500", "Square 500", "rect", [0.5, 0.5]],
	["L-PANEL-1200x800", "Hatch panel 1200 x 800, rounded", "rounded", [1.2, 0.8, 0.1]],
	["L-DISC-600", "Disc 600", "disc", [0.3]],
	["L-RING-600", "Flange ring 600 / 300", "ring", [0.3, 0.15]],
	["L-GUSSET-400", "Gusset 400", "gusset", [0.4]],
	["L-HEX-500", "Hex plate 500", "polygon", [0.25, 6]],
	["L-ANGLE-600", "Angle bracket 600 x 400", "angle", [0.6, 0.4, 0.15]],
]
## Points round a full circle.
const ARC_STEPS := 40


static func library() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Array in LIBRARY:
		out.append(make(str(row[0]), str(row[1]), str(row[2]), row[3]))
	return out


## One shape by kind: rect [w, h], rounded [w, h, r], disc [r], ring [r, hole r],
## gusset [leg] (a right triangle), polygon [r, sides], angle [w, h, leg width].
static func make(id: String, name: String, kind: String, args: Array) -> Dictionary:
	var outline := PackedVector2Array()
	var holes: Array[PackedVector2Array] = []
	match kind:
		"rect":
			outline = _rect(float(args[0]), float(args[1]))
		"rounded":
			outline = _rounded(float(args[0]), float(args[1]), float(args[2]))
		"disc":
			outline = _circle(float(args[0]), ARC_STEPS)
		"ring":
			outline = _circle(float(args[0]), ARC_STEPS)
			var hole := _circle(float(args[1]), ARC_STEPS)
			hole.reverse()
			holes.append(hole)
		"gusset":
			var l := float(args[0])
			outline = PackedVector2Array([Vector2(0, 0), Vector2(l, 0), Vector2(0, l)])
		"polygon":
			outline = _circle(float(args[0]), int(args[1]))
		"angle":
			var w := float(args[0])
			var h := float(args[1])
			var t := float(args[2])
			outline = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, t), Vector2(t, t), Vector2(t, h), Vector2(0, h)])
	return finish({"id": id, "name": name, "outline": outline, "holes": holes, "kind": "library", "source": ""})


## Centres the outline on 0 and fills in its size.
static func finish(t: Dictionary) -> Dictionary:
	var outline: PackedVector2Array = t.outline
	var box := bounds(outline)
	var shift := -box.get_center()
	for i in outline.size():
		outline[i] += shift
	var holes: Array[PackedVector2Array] = []
	for h: PackedVector2Array in t.get("holes", []):
		var moved := h.duplicate()
		for i in moved.size():
			moved[i] += shift
		holes.append(moved)
	t.outline = outline
	t.holes = holes
	t.size = box.size
	return t


## A traced plate measured into a template: the points you traced (plate plane, metres) are
## snapped onto the plate's real edges (`edges`, its outline) where they're within `snap_m`, and
## the template is the plate's outline once the trace has gone all the way round (`covered`
## of the perimeter's `bins`). Returns {} while it hasn't.
static func measure(points: PackedVector2Array, edges: PackedVector2Array, snap_m := 0.08,
		bins := 24, covered := 0.9) -> Dictionary:
	var hit := coverage(points, edges, snap_m, bins)
	if hit < covered:
		return {}
	return finish({"id": "", "name": "", "outline": edges.duplicate(), "holes": [], "kind": "traced", "source": ""})


## How much of an outline's perimeter (0..1, in `bins` equal stretches) has a traced point
## within `snap_m` of it.
static func coverage(points: PackedVector2Array, edges: PackedVector2Array, snap_m := 0.08, bins := 24) -> float:
	if edges.size() < 3 or points.is_empty():
		return 0.0
	var perimeter := perimeter_of(edges)
	var seen := {}
	for p in points:
		var best := INF
		var along := 0.0
		var run := 0.0
		for i in edges.size():
			var a := edges[i]
			var b := edges[(i + 1) % edges.size()]
			var q := Geometry2D.get_closest_point_to_segment(p, a, b)
			var d := p.distance_to(q)
			if d < best:
				best = d
				along = run + a.distance_to(q)
			run += a.distance_to(b)
		if best <= snap_m:
			seen[mini(int(along / perimeter * bins), bins - 1)] = true
	return float(seen.size()) / float(bins)


static func perimeter_of(outline: PackedVector2Array) -> float:
	var p := 0.0
	for i in outline.size():
		p += outline[i].distance_to(outline[(i + 1) % outline.size()])
	return p


static func area_of(t: Dictionary) -> float:
	var a := absf(_signed_area(t.outline))
	for h: PackedVector2Array in t.get("holes", []):
		a -= absf(_signed_area(h))
	return a


static func bounds(outline: PackedVector2Array) -> Rect2:
	if outline.is_empty():
		return Rect2()
	var r := Rect2(outline[0], Vector2.ZERO)
	for p in outline:
		r = r.expand(p)
	return r


## Whether a template fits on a plate of `plate_size` (m, x by y), turned a quarter if it
## needs to, with `margin_m` all round. Returns the turn (0 or PI/2) or -1 when it doesn't.
static func fit_turn(t: Dictionary, plate_size: Vector2, margin_m := 0.02) -> float:
	var s: Vector2 = t.size
	var room := plate_size - Vector2.ONE * margin_m * 2.0
	if s.x <= room.x and s.y <= room.y:
		return 0.0
	if s.y <= room.x and s.x <= room.y:
		return PI * 0.5
	return -1.0


## A copy of a template turned by `turn` (radians) about its middle, re-centred.
static func make_turned(t: Dictionary, turn: float) -> Dictionary:
	if is_zero_approx(turn):
		return t
	var out := t.duplicate()
	out.outline = _turned(t.outline, turn)
	var holes: Array[PackedVector2Array] = []
	for h: PackedVector2Array in t.get("holes", []):
		holes.append(_turned(h, turn))
	out.holes = holes
	return finish(out)


## The torch's path for a template on the bed: the outline turned by `turn` (with the holes
## first, as a real cutter does), each loop closed, starting from its lead-in.
static func cut_path(t: Dictionary, turn: float) -> Array[PackedVector2Array]:
	var loops: Array[PackedVector2Array] = []
	for h: PackedVector2Array in t.get("holes", []):
		loops.append(_closed(_turned(h, turn)))
	loops.append(_closed(_turned(t.outline, turn)))
	return loops


## A flat piece: `outline` (and `holes`) extruded `thickness` m along +Y, top at thickness/2,
## lying in X/Z. The cut edges get their own surface (darkened, the kerf).
static func extrude(outline: PackedVector2Array, holes: Array, thickness: float) -> ArrayMesh:
	var face := SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := SurfaceTool.new()
	edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := thickness * 0.5
	# The faces: the outline triangulated, round any holes.
	var poly := outline.duplicate()
	if _signed_area(poly) < 0.0:
		poly.reverse()
	var tris := PackedVector2Array()
	if holes.is_empty():
		for i in Geometry2D.triangulate_polygon(poly):
			tris.append(poly[i])
	else:
		tris = _triangulate_with_holes(poly, holes)
	for s: float in [1.0, -1.0]:
		face.set_normal(Vector3(0, s, 0))
		for i in range(0, tris.size(), 3):
			var a := tris[i]
			var b := tris[i + 1]
			var c := tris[i + 2]
			# Godot draws clockwise faces: anticlockwise in (x, z) is clockwise seen from +Y.
			var order := [a, b, c] if s > 0.0 else [a, c, b]
			for v: Vector2 in order:
				face.set_uv(v)
				face.add_vertex(Vector3(v.x, s * half, v.y))
	# The edges: every loop's walls.
	var loops: Array = [poly]
	for h: PackedVector2Array in holes:
		loops.append(h)
	for loop: PackedVector2Array in loops:
		var outward := _signed_area(loop) > 0.0
		for i in loop.size():
			var a := loop[i]
			var b := loop[(i + 1) % loop.size()]
			var d := (b - a).normalized()
			var n2 := Vector2(d.y, -d.x) if outward else Vector2(-d.y, d.x)
			var n := Vector3(n2.x, 0, n2.y)
			var quad := [Vector3(a.x, half, a.y), Vector3(b.x, half, b.y), Vector3(b.x, -half, b.y), Vector3(a.x, -half, a.y)]
			var order := [0, 1, 2, 0, 2, 3] if not outward else [0, 2, 1, 0, 3, 2]
			for k: int in order:
				edge.set_normal(n)
				edge.add_vertex(quad[k])
	var mesh := face.commit()
	edge.commit(mesh)
	return mesh


## A triangulation of `poly` minus `holes`: Delaunay over every corner, keeping the triangles
## whose middles are inside the outline and outside every hole.
static func _triangulate_with_holes(poly: PackedVector2Array, holes: Array) -> PackedVector2Array:
	var pts := poly.duplicate()
	for h: PackedVector2Array in holes:
		pts.append_array(h)
	var idx := Geometry2D.triangulate_delaunay(pts)
	var out := PackedVector2Array()
	for i in range(0, idx.size(), 3):
		var a := pts[idx[i]]
		var b := pts[idx[i + 1]]
		var c := pts[idx[i + 2]]
		var mid := (a + b + c) / 3.0
		if not Geometry2D.is_point_in_polygon(mid, poly):
			continue
		var in_hole := false
		for h: PackedVector2Array in holes:
			if Geometry2D.is_point_in_polygon(mid, h):
				in_hole = true
		if in_hole:
			continue
		# Anticlockwise.
		if (b - a).cross(c - a) < 0.0:
			out.append_array([a, c, b])
		else:
			out.append_array([a, b, c])
	return out


static func _signed_area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return a * 0.5


static func _turned(p: PackedVector2Array, turn: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in p:
		out.append(v.rotated(turn))
	return out


static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var out := p.duplicate()
	if not out.is_empty():
		out.append(out[0])
	return out


static func _rect(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])


static func _rounded(w: float, h: float, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var corners := [Vector2(w - r, r), Vector2(w - r, h - r), Vector2(r, h - r), Vector2(r, r)]
	var start := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for k in 4:
		for s in 7:
			var a: float = start[k] + PI * 0.5 * s / 6.0
			out.append(corners[k] + Vector2(cos(a), sin(a)) * r)
	return out


static func _circle(r: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(Vector2(cos(a), sin(a)) * r)
	return out
