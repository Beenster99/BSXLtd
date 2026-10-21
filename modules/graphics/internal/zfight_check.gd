extends RefCounted
## G5, the Z-fighting checker. Finds faces of two different meshes that lie in the same plane
## (within PLANE_GAP), face the same way and overlap: the depth buffer can't tell which is in
## front, so they flicker as the camera moves. Run on a built scene:
##   var hits := ZFightCheck.scan(scene)   # [{a, b, area, at, normal}], biggest first
## a and b are the two meshes' node paths, area the overlap (m²), at a point in it.
## Small faces (under MIN_FACE) and small overlaps (under MIN_OVERLAP) are left out: they
## don't show. Meshes with meta "gfx_coplanar_ok" (decals laid on purpose with a depth
## offset, glow layers) and anything Graphics drew itself are skipped.

const PLANE_GAP := 0.0005       # m: closer than this, the depth buffer can't separate them (owners lift layers by 0.6 mm)
const MIN_FACE := 0.01          # m², triangles smaller than this are ignored
const MIN_OVERLAP := 0.004      # m², overlaps smaller than this are ignored
const NORMAL_STEP := 0.02       # bucket size for normals
const CELL := 2.0               # m, the grid inside one plane for finding neighbours
const OK_META := "gfx_coplanar_ok"
## A face is hidden when the air just in front of it (this far out, m) is inside a solid box.
const BURIED_PROBE := 0.01
## Downward faces lower than this are under the ground, m.
const GROUND := 0.05


## Every flickering pair under root, biggest overlap first.
static func scan(root: Node) -> Array[Dictionary]:
	var tris: Array[Dictionary] = []
	var meshes: Array[MeshInstance3D] = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or _skipped(mi):
			continue
		var id := meshes.size()
		meshes.append(mi)
		_collect(mi, id, tris)
	# Bucket by plane: quantised normal and distance.
	var planes: Dictionary = {}
	for i in tris.size():
		var t := tris[i]
		var key := _plane_key(t.n, t.d)
		if not planes.has(key):
			planes[key] = []
		planes[key].append(i)
	var pairs: Dictionary = {}    # "a:b" -> {area, at, normal}
	var seen: Dictionary = {}     # triangle pairs already compared
	for key: Vector4i in planes:
		var list: Array = planes[key]
		# Neighbouring distance bucket too, so a pair split by a bucket edge still meets.
		var next: Vector4i = key + Vector4i(0, 0, 0, 1)
		var others: Array = list.duplicate()
		if planes.has(next):
			others.append_array(planes[next])
		if others.size() < 2:
			continue
		_compare(list, others, tris, pairs, seen)
	var boxes: Array[MeshInstance3D] = []
	for mi in meshes:
		if mi.mesh is BoxMesh:
			boxes.append(mi)
	var out: Array[Dictionary] = []
	for k: String in pairs:
		var p: Dictionary = pairs[k]
		if float(p.area) < MIN_OVERLAP or _buried(p.at + (p.normal as Vector3) * BURIED_PROBE, boxes):
			continue
		var ids := k.split(":")
		out.append({"a": meshes[int(ids[0])].get_path(), "b": meshes[int(ids[1])].get_path(),
				"area": p.area, "at": p.at, "normal": p.normal})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.area) > float(y.area))
	return out


## One line per pair, for logs and test failures.
static func describe(hits: Array[Dictionary], most := 20) -> String:
	var lines: PackedStringArray = []
	for i in mini(most, hits.size()):
		var h := hits[i]
		lines.append("%.3f m² at %s: %s / %s" % [h.area, str((h.at as Vector3).snapped(Vector3.ONE * 0.01)), h.a, h.b])
	if hits.size() > most:
		lines.append("... and %d more" % (hits.size() - most))
	return "\n".join(lines)


## True when a point is inside one of the solid boxes (so a face there can't be seen).
static func _buried(point: Vector3, boxes: Array[MeshInstance3D]) -> bool:
	for b in boxes:
		var local := b.global_transform.affine_inverse() * point
		var half := (b.mesh as BoxMesh).size * 0.5
		if absf(local.x) < half.x and absf(local.y) < half.y and absf(local.z) < half.z:
			return true
	return false


static func _skipped(mi: MeshInstance3D) -> bool:
	if mi.has_meta(OK_META) or mi.name.begins_with("Gfx"):
		return true
	var p := mi.get_parent()
	while p:
		if p.has_meta(OK_META):
			return true
		p = p.get_parent()
	return false


static func _collect(mi: MeshInstance3D, id: int, tris: Array[Dictionary]) -> void:
	var xf := mi.global_transform
	var mesh := mi.mesh
	for s in mesh.get_surface_count():
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := index.size() if index.size() > 0 else verts.size()
		for i in range(0, count - 2, 3):
			var a := xf * verts[index[i] if index.size() > 0 else i]
			var b := xf * verts[index[i + 1] if index.size() > 0 else i + 1]
			var c := xf * verts[index[i + 2] if index.size() > 0 else i + 2]
			var cross := (c - a).cross(b - a)   # Godot's front faces wind clockwise
			var area := cross.length() * 0.5
			if area < MIN_FACE:
				continue
			var n := cross / (area * 2.0)
			if n.y < -0.9 and maxf(a.y, maxf(b.y, c.y)) < GROUND:
				continue   # the underside of something on the ground: nobody sees it
			tris.append({"m": id, "a": a, "b": b, "c": c, "n": n, "d": n.dot(a)})


static func _plane_key(n: Vector3, d: float) -> Vector4i:
	return Vector4i(roundi(n.x / NORMAL_STEP), roundi(n.y / NORMAL_STEP), roundi(n.z / NORMAL_STEP),
			floori(d / PLANE_GAP))


## Compares the triangles in one plane bucket against those in it and the next one.
static func _compare(list: Array, others: Array, tris: Array[Dictionary], pairs: Dictionary, seen: Dictionary) -> void:
	var n: Vector3 = tris[list[0]].n
	var u := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := n.cross(u)
	# A grid over the plane: each triangle in the cells its 2D box touches.
	var grid: Dictionary = {}
	var flat: Dictionary = {}
	for i: int in others:
		var t := tris[i]
		var poly := PackedVector2Array([Vector2(t.a.dot(u), t.a.dot(v)), Vector2(t.b.dot(u), t.b.dot(v)),
				Vector2(t.c.dot(u), t.c.dot(v))])
		flat[i] = poly
		var lo := Vector2(minf(poly[0].x, minf(poly[1].x, poly[2].x)), minf(poly[0].y, minf(poly[1].y, poly[2].y)))
		var hi := Vector2(maxf(poly[0].x, maxf(poly[1].x, poly[2].x)), maxf(poly[0].y, maxf(poly[1].y, poly[2].y)))
		for gx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
			for gy in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
				var cell := Vector2i(gx, gy)
				if not grid.has(cell):
					grid[cell] = []
				grid[cell].append(i)
	var mine: Dictionary = {}
	for i: int in list:
		mine[i] = true
	for cell: Vector2i in grid:
		var here: Array = grid[cell]
		for x in here.size():
			var i: int = here[x]
			for y in range(x + 1, here.size()):
				var j: int = here[y]
				if not (mine.has(i) or mine.has(j)):
					continue
				var ti := tris[i]
				var tj := tris[j]
				if ti.m == tj.m or (ti.n as Vector3).dot(tj.n) < 0.999 or absf(float(ti.d) - float(tj.d)) > PLANE_GAP:
					continue
				var pk := Vector2i(mini(i, j), maxi(i, j))
				if seen.has(pk):
					continue
				seen[pk] = true
				var clip := Geometry2D.intersect_polygons(flat[i], flat[j])
				if clip.is_empty():
					continue
				var area := 0.0
				var at := Vector2.ZERO
				var biggest := 0.0
				for poly: PackedVector2Array in clip:
					var pa := absf(_area(poly))
					area += pa
					if pa > biggest:
						biggest = pa
						at = _centre(poly)
				if area <= 0.0:
					continue
				var key := "%d:%d" % [mini(ti.m, tj.m), maxi(ti.m, tj.m)]
				var p: Dictionary = pairs.get(key, {"area": 0.0, "at": Vector3.ZERO, "normal": n})
				p.area = float(p.area) + area
				p.at = u * at.x + v * at.y + n * float(ti.d)
				pairs[key] = p


static func _centre(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for q in poly:
		c += q
	return c / float(poly.size())


static func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5
