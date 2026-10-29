class_name TradesBeamCuts
extends RefCounted
## Cutting beams to length on the plasma bed (trades.beam_cutting, beenster 0.3.27: "we need a
## way of creating beams to specific lengths. For simplicity let's use the plasma bed to cut
## lengths of beams"). A stock bar (Shared Components' StockBeams) lies along the bed's rails;
## the console takes a list of lengths, each end square or mitred, lays them along the bar with
## a kerf between, and the torch runs across the bar at each cut. The pieces and what is left
## drop as loose parts "<bar id>:len:<mm>" (":<a>:<b>" after it when an end is mitred, in
## degrees). Static: the bed runs the program.
##
## In the bar's own space x runs along it (from -length/2), z across its width and y up its
## height. A piece's length is along its long edge (z = -w/2); a mitre takes its far side in by
## w x tan(angle).

## The torch's kerf (m) and how far past the bar's sides it runs (m).
const KERF_M := 0.003
const RUN_OUT_M := 0.03
## The ends the console offers (degrees; 0 square).
const MITRES: Array[float] = [0.0, 45.0, 30.0, 60.0]
## The shortest piece (m).
const MIN_M := 0.05
const PREFIX := ":len:"


static func enabled() -> bool:
	return Flags.is_on("trades.beam_cutting")


## A bar or a piece of one as the bed takes it: {id (the component), bar, kind "beam", size
## (Vector2: length, width), thickness (its height), wall, material, family "metal", beam_family,
## section {w, h, t}, area} or {} when it isn't one.
static func bar_info(component: String) -> Dictionary:
	var bar := component
	var length := -1.0
	var at := component.find(PREFIX)
	if at > 0:
		bar = component.left(at)
		var rest := component.substr(at + PREFIX.length()).split(":")
		# Only a square-ended piece goes back on the bed.
		if rest.size() > 1 and (float(rest[1]) != 0.0 or (rest.size() > 2 and float(rest[2]) != 0.0)):
			return {}
		length = float(rest[0]) / 1000.0
	if not StockBeams.is_beam(bar):
		return {}
	var it := StockBeams.item(bar)
	var s: Dictionary = it.section
	if length < 0.0:
		length = float(it.length)
	return {"id": component, "bar": bar, "kind": "beam", "size": Vector2(length, float(s.w)), "thickness": float(s.h),
			"wall": float(s.t), "material": str(it.material), "family": "metal", "beam_family": str(it.family),
			"section": s.duplicate(), "area": float(it.area)}


static func is_beam(info: Dictionary) -> bool:
	return str(info.get("kind", "")) == "beam"


## A piece's component name.
static func piece_name(bar: String, mm: int, a := 0.0, b := 0.0) -> String:
	if a == 0.0 and b == 0.0:
		return "%s%s%d" % [bar, PREFIX, mm]
	return "%s%s%d:%d:%d" % [bar, PREFIX, mm, roundi(a), roundi(b)]


## How the pieces lie along the bar: {pieces [{mm, a, b, from (x of its long edge's start)}],
## cuts [[from Vector2, to Vector2] in bed x, z], left_m (what is left past the last cut),
## left_from, left_a (the offcut's first end: the last cut's angle, negative)} or {} when
## they don't fit. `lengths`: [{mm, a, b}].
static func layout(info: Dictionary, lengths: Array) -> Dictionary:
	if lengths.is_empty() or not is_beam(info):
		return {}
	var l: float = (info.size as Vector2).x
	var w: float = (info.size as Vector2).y
	var x := -l * 0.5
	var pieces: Array = []
	var cuts: Array = []
	var last_b := 0.0
	for i in lengths.size():
		var p: Dictionary = lengths[i]
		var mm := int(p.get("mm", 0))
		var a := clampf(float(p.get("a", 0.0)), 0.0, 60.0)
		var b := clampf(float(p.get("b", 0.0)), 0.0, 60.0)
		var m := mm / 1000.0
		if m < MIN_M or m - w * (tan(deg_to_rad(a)) + tan(deg_to_rad(b))) < 0.01:
			return {}
		# The bar's own end is square: the first square piece needs no cut there.
		if i > 0 or a != 0.0:
			if i > 0:
				x += KERF_M
			if a != 0.0 or last_b != 0.0 or i == 0:
				cuts.append(_line(x, w, a))
		pieces.append({"mm": mm, "a": a, "b": b, "from": x})
		x += m
		if x > l * 0.5 + 0.0001:
			return {}
		cuts.append(_line(x, w, -b))
		last_b = b
	var left := l * 0.5 - (x + KERF_M)
	return {"pieces": pieces, "cuts": cuts, "left_m": maxf(left, 0.0), "left_from": x + KERF_M, "left_a": -last_b,
			"used_m": x + l * 0.5}


## A cut across the bar at x (on its long edge), leaning `deg` across its width.
static func _line(x: float, w: float, deg: float) -> Array:
	var lean := tan(deg_to_rad(deg))
	var z0 := -w * 0.5 - RUN_OUT_M
	var z1 := w * 0.5 + RUN_OUT_M
	return [Vector2(x + (z0 + w * 0.5) * lean, z0), Vector2(x + (z1 + w * 0.5) * lean, z1)]


## Total metres of bar a list takes (pieces and kerfs), for the console.
static func used_m(info: Dictionary, lengths: Array) -> float:
	var lay := layout(info, lengths)
	return float(lay.get("used_m", -1.0))


## A length of bar as a mesh, x along it centred (its long edge `length_m`), ends leaning in by
## the angles (degrees; negative leans out).
static func mesh(info: Dictionary, length_m: float, a := 0.0, b := 0.0) -> ArrayMesh:
	var s: Dictionary = info.section
	var w := float(s.w)
	var o := StockBeams.section_outline(str(info.beam_family), w, float(s.h), float(s.t))
	var bores := StockBeams.section_holes(str(info.beam_family), w, float(s.h), float(s.t))
	var ta := tan(deg_to_rad(a))
	var tb := tan(deg_to_rad(b))
	var h := length_m * 0.5
	var end_a := func(u: float) -> float: return -h + (u + w * 0.5) * ta
	var end_b := func(u: float) -> float: return h - (u + w * 0.5) * tb
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var loops: Array = [o]
	for bore: PackedVector2Array in bores:
		loops.append(bore)
	# The walls: the outline counter-clockwise, a bore clockwise, so (dv, -du) faces out of the metal.
	for loop: PackedVector2Array in loops:
		var n := loop.size()
		for i in n:
			var p := loop[i]
			var q := loop[(i + 1) % n]
			var out := Vector3(0, -(q.x - p.x), q.y - p.y).normalized()
			var pa := Vector3(end_a.call(p.x), p.y, p.x)
			var pb := Vector3(end_b.call(p.x), p.y, p.x)
			var qa := Vector3(end_a.call(q.x), q.y, q.x)
			var qb := Vector3(end_b.call(q.x), q.y, q.x)
			_tri(verts, normals, pa, pb, qb, out)
			_tri(verts, normals, pa, qb, qa, out)
	# The ends: the section (round a box's bore) on each cut face.
	var tris := _section_tris(o, bores)
	var out_a := Vector3(-1, 0, ta).normalized()
	var out_b := Vector3(1, 0, tb).normalized()
	for k in range(0, tris.size(), 3):
		var t0 := tris[k]
		var t1 := tris[k + 1]
		var t2 := tris[k + 2]
		_tri(verts, normals, Vector3(end_a.call(t0.x), t0.y, t0.x), Vector3(end_a.call(t1.x), t1.y, t1.x), Vector3(end_a.call(t2.x), t2.y, t2.x), out_a)
		_tri(verts, normals, Vector3(end_b.call(t0.x), t0.y, t0.x), Vector3(end_b.call(t1.x), t1.y, t1.x), Vector3(end_b.call(t2.x), t2.y, t2.x), out_b)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## One triangle facing `out` (Godot's front faces wind clockwise), as StockBeams' bars are.
static func _tri(verts: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	if -(b - a).cross(c - a).dot(out) < 0.0:
		var s := b
		b = c
		c = s
	verts.append_array([a, b, c])
	normals.append_array([out, out, out])


static func _section_tris(outline: PackedVector2Array, bores: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if bores.is_empty():
		for i in Geometry2D.triangulate_polygon(outline):
			out.append(outline[i])
		return out
	# A box tube: the ring between its outside and its bore, as a strip of quads.
	var bore: PackedVector2Array = bores[0]
	if bore.size() != outline.size():
		for i in Geometry2D.triangulate_polygon(outline):
			out.append(outline[i])
		return out
	var inner := bore.duplicate()
	if _signed(inner) * _signed(outline) < 0.0:
		inner.reverse()
	# Match each outside corner with its nearest bore corner.
	var shift := 0
	var best := INF
	for k in inner.size():
		var d := outline[0].distance_to(inner[k])
		if d < best:
			best = d
			shift = k
	var n := outline.size()
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		var c := inner[(i + shift + 1) % n]
		var d := inner[(i + shift) % n]
		out.append_array(PackedVector2Array([a, b, c, a, c, d]))
	return out


static func _signed(loop: PackedVector2Array) -> float:
	var s := 0.0
	for i in loop.size():
		s += loop[i].cross(loop[(i + 1) % loop.size()])
	return s


## A piece's middle along the bar (x) from its long edge's start, its length and its ends.
static func piece_middle(from: float, length_m: float) -> float:
	return from + length_m * 0.5


## A piece's mass (kg): the section's area along its mean length.
static func piece_kg(info: Dictionary, length_m: float, a: float, b: float) -> float:
	var w: float = (info.size as Vector2).y
	var mean := length_m - w * 0.5 * (tan(deg_to_rad(a)) + tan(deg_to_rad(b)))
	var density := float(Materials.info(str(info.material)).get("density", 7850.0))
	return float(info.area) * maxf(mean, 0.0) * density
