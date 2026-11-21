extends RefCounted
## Small fittings drawn as a few merged meshes (the room detail pass, beenster 20 Nov: "bring
## them up to Void Salvage standards"). Thousands of seams, bolts, brackets and grilles would
## be thousands of nodes as Kit boxes; here they gather by material and by 8 m cell (the
## compatibility renderer lights a mesh with only the first eight lamps over it), then
## `commit` makes one MeshInstance3D per material and cell. Presentation only: no collision.

const CELL := 8.0

## The cell this mesher gathers by (m): CELL indoors; the dock's open frames take bigger.
var cell := CELL

var _parts: Dictionary = {}   # "mat_id/cx/cz" -> {mat, st}
var _mats: Dictionary = {}    # material -> id
var count := 0                # shapes added
var boxes: Array[AABB] = []   # every shape's bounds (station space), for the tests


## A box `size` at `centre`, turned by `basis` (station space).
func box(mat: Material, size: Vector3, centre: Vector3, basis := Basis.IDENTITY) -> void:
	var st := _st(mat, centre)
	var h := size * 0.5
	boxes.append(Transform3D(basis, centre) * AABB(-h, size))
	for f in 6:
		var n := Vector3.ZERO
		n[f / 2] = 1.0 if f % 2 == 0 else -1.0
		var u := Vector3.ZERO
		u[(f / 2 + 1) % 3] = 1.0
		var v := n.cross(u)
		_quad(st, basis, centre, n, [(n + u - v) * h, (n - u - v) * h, (n - u + v) * h, (n + u + v) * h])
	count += 1


## A box between corners `a` and `b` (station space, axis-aligned).
func span(mat: Material, a: Vector3, b: Vector3) -> void:
	box(mat, (b - a).abs(), (a + b) * 0.5)


## A round bar or pipe from `a` to `b`, `radius` m, `sides` faces round.
func rod(mat: Material, a: Vector3, b: Vector3, radius: float, sides := 8) -> void:
	var axis := b - a
	if axis.length() < 0.001:
		return
	var st := _st(mat, (a + b) * 0.5)
	boxes.append(AABB(a, Vector3.ZERO).expand(b).grow(radius))
	var w := axis.normalized()
	var u := w.cross(Vector3.UP if absf(w.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := w.cross(u)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var n0 := u * cos(a0) + v * sin(a0)
		var n1 := u * cos(a1) + v * sin(a1)
		# Wound clockwise seen from outside (Godot's front faces).
		for q: Array in [[n0, a], [n0, b], [n1, b], [n0, a], [n1, b], [n1, a]]:
			var nq: Vector3 = q[0]
			st.set_normal(nq)
			st.add_vertex((q[1] as Vector3) + nq * radius)
	count += 1


## Every gathered shape as meshes under `parent`, named `prefix`N; with `shadows` off they cast
## none (seams and bolts a few mm proud of a wall throw nothing worth a shadow pass).
func commit(parent: Node3D, prefix: String, shadows := true) -> int:
	var n := 0
	for key: String in _parts:
		var p: Dictionary = _parts[key]
		var st: SurfaceTool = p.st
		var mi := MeshInstance3D.new()
		mi.name = "%s%d" % [prefix, n]
		mi.mesh = st.commit()
		mi.material_override = p.mat
		if not shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		n += 1
	_parts.clear()
	return n


func _st(mat: Material, at: Vector3) -> SurfaceTool:
	if not _mats.has(mat):
		_mats[mat] = _mats.size()
	var key := "%d/%d/%d" % [_mats[mat], floori(at.x / cell), floori(at.z / cell)]
	if not _parts.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_parts[key] = {"mat": mat, "st": st}
	return _parts[key].st


func _quad(st: SurfaceTool, basis: Basis, centre: Vector3, n: Vector3, c: Array) -> void:
	var nn := (basis * n).normalized()
	var p: Array[Vector3] = []
	for q: Vector3 in c:
		p.append(centre + basis * q)
	# Wound clockwise seen from outside (Godot's front faces).
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(nn)
		st.add_vertex(p[i])
