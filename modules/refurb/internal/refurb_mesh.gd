extends RefCounted
## A mesh kit for the refurb works' detailed models: shapes go in by material and come out as
## one mesh with a surface per material (a few draw calls for a whole drone's body, not one per
## piece). Chamfered boxes, cylinders and cones, spheres and caps, tori and part tori, tubes
## along a smooth curve (hoses and cables), and curved shells (the drone's hood). Every shape
## takes a transform (its basis may scale). Presentation only.

## The mesh is built this much bigger and its node scaled back down: the salvage surface's
## wear (chips, rust, scratches) is laid out in the mesh's own metres, so a small model drawn
## big gets finer weathering.
var grain := 1.0
var _tools: Dictionary = {}   # Material -> SurfaceTool
var _order: Array[Material] = []


func _st(mat: Material) -> SurfaceTool:
	if not _tools.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[mat] = st
		_order.append(mat)
	return _tools[mat]


## True when nothing has been added.
func is_empty() -> bool:
	return _order.is_empty()


## The mesh so far, as a MeshInstance3D under `parent` (null when empty).
func commit(parent: Node3D, node_name := "") -> MeshInstance3D:
	if _order.is_empty():
		return null
	var mesh := ArrayMesh.new()
	for m in _order:
		var st: SurfaceTool = _tools[m]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = Vector3.ONE / grain
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	_tools.clear()
	_order.clear()
	return mi


## One triangle, its corners' normals given; turned to face the way the normals do.
func tri(mat: Material, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var st := _st(mat)
	var n := na + nb + nc
	# Godot's front faces wind clockwise seen from the front.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	for p: Array in [[a, na], [b, nb], [c, nc]]:
		var v: Vector3 = p[0]
		var nn: Vector3 = (p[1] as Vector3).normalized()
		st.set_normal(nn)
		st.set_uv(Vector2(v.x + v.z, v.y))
		st.add_vertex(v * grain)


func quad(mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3) -> void:
	tri(mat, a, b, c, na, nb, nc)
	tri(mat, a, c, d, na, nc, nd)


func flat(mat: Material, pts: Array, n: Vector3) -> void:
	for k in range(1, pts.size() - 1):
		tri(mat, pts[0], pts[k], pts[k + 1], n, n, n)


## A box `size` with its edges chamfered by `bevel` (m, 0 for a plain box).
func box(mat: Material, size: Vector3, xf: Transform3D, bevel := 0.0) -> void:
	var h := size * 0.5
	var b := clampf(bevel, 0.0, minf(h.x, minf(h.y, h.z)) * 0.95)
	var nb := xf.basis.inverse().transposed()
	var P := func(v: Vector3) -> Vector3: return xf * v
	var N := func(v: Vector3) -> Vector3: return (nb * v).normalized()
	# Faces.
	for ax in 3:
		for s: float in [-1.0, 1.0]:
			var u := (ax + 1) % 3
			var w := (ax + 2) % 3
			var pts: Array = []
			for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var v := Vector3.ZERO
				v[ax] = s * h[ax]
				v[u] = c.x * (h[u] - b)
				v[w] = c.y * (h[w] - b)
				pts.append(P.call(v))
			var n := Vector3.ZERO
			n[ax] = s
			flat(mat, pts, N.call(n))
	if b <= 0.0:
		return
	# Edge chamfers: between the faces of axes a1 and a2, running along the third.
	for a1 in 3:
		for a2 in range(a1 + 1, 3):
			var run := 3 - a1 - a2
			for s1: float in [-1.0, 1.0]:
				for s2: float in [-1.0, 1.0]:
					var pts: Array = []
					for e: float in [-1.0, 1.0]:
						var p1 := Vector3.ZERO
						p1[a1] = s1 * h[a1]
						p1[a2] = s2 * (h[a2] - b)
						p1[run] = e * (h[run] - b)
						var p2 := Vector3.ZERO
						p2[a1] = s1 * (h[a1] - b)
						p2[a2] = s2 * h[a2]
						p2[run] = e * (h[run] - b)
						pts.append(p1)
						pts.append(p2)
					var n := Vector3.ZERO
					n[a1] = s1
					n[a2] = s2
					flat(mat, [P.call(pts[0]), P.call(pts[1]), P.call(pts[3]), P.call(pts[2])], N.call(n))
	# Corners.
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var a := Vector3(sx * h.x, sy * (h.y - b), sz * (h.z - b))
				var c2 := Vector3(sx * (h.x - b), sy * h.y, sz * (h.z - b))
				var c3 := Vector3(sx * (h.x - b), sy * (h.y - b), sz * h.z)
				flat(mat, [P.call(a), P.call(c2), P.call(c3)], N.call(Vector3(sx, sy, sz)))


## A cylinder (or a cone, with `top` for its top radius) along its local Y, `length` long,
## centred on the transform's origin. `caps` closes its ends.
func cyl(mat: Material, r: float, length: float, xf: Transform3D, segs := 16, top := -1.0, caps := true) -> void:
	var r2 := r if top < 0.0 else top
	var nb := xf.basis.inverse().transposed()
	var y0 := -length * 0.5
	var y1 := length * 0.5
	var slope := (r - r2) / maxf(length, 0.0001)
	for k in segs:
		var a0 := TAU * k / segs
		var a1 := TAU * (k + 1) / segs
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var n0 := (nb * (d0 + Vector3(0, slope, 0))).normalized()
		var n1 := (nb * (d1 + Vector3(0, slope, 0))).normalized()
		quad(mat, xf * (d0 * r + Vector3(0, y0, 0)), xf * (d1 * r + Vector3(0, y0, 0)),
				xf * (d1 * r2 + Vector3(0, y1, 0)), xf * (d0 * r2 + Vector3(0, y1, 0)), n0, n1, n1, n0)
		if caps:
			var up := (nb * Vector3.UP).normalized()
			if r2 > 0.0:
				tri(mat, xf * Vector3(0, y1, 0), xf * (d0 * r2 + Vector3(0, y1, 0)), xf * (d1 * r2 + Vector3(0, y1, 0)), up, up, up)
			if r > 0.0:
				tri(mat, xf * Vector3(0, y0, 0), xf * (d1 * r + Vector3(0, y0, 0)), xf * (d0 * r + Vector3(0, y0, 0)), -up, -up, -up)


## A sphere of radius `r` (the basis may squash it); `v_max` < PI leaves the bottom open (a cap
## from the top, its pole on +Y).
func sphere(mat: Material, r: float, xf: Transform3D, segs := 16, rings := 8, v_max := PI) -> void:
	var nb := xf.basis.inverse().transposed()
	for j in rings:
		var v0 := v_max * j / rings
		var v1 := v_max * (j + 1) / rings
		for k in segs:
			var u0 := TAU * k / segs
			var u1 := TAU * (k + 1) / segs
			var d := [_sd(u0, v0), _sd(u1, v0), _sd(u1, v1), _sd(u0, v1)]
			var ns: Array = []
			var ps: Array = []
			for q: Vector3 in d:
				ps.append(xf * (q * r))
				ns.append((nb * q).normalized())
			if j == 0:
				tri(mat, ps[0], ps[2], ps[3], ns[0], ns[2], ns[3])
			else:
				quad(mat, ps[0], ps[1], ps[2], ps[3], ns[0], ns[1], ns[2], ns[3])


static func _sd(u: float, v: float) -> Vector3:
	return Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))


## A torus round its local Y: the ring's radius `big`, the tube's `small`; `arc` < TAU for part
## of one (from +X towards +Z).
func torus(mat: Material, big: float, small: float, xf: Transform3D, segs := 24, tube_segs := 8, arc := TAU) -> void:
	var nb := xf.basis.inverse().transposed()
	for k in segs:
		var a0 := arc * k / segs
		var a1 := arc * (k + 1) / segs
		for j in tube_segs:
			var b0 := TAU * j / tube_segs
			var b1 := TAU * (j + 1) / tube_segs
			var pts: Array = []
			var ns: Array = []
			for ab: Vector2 in [Vector2(a0, b0), Vector2(a1, b0), Vector2(a1, b1), Vector2(a0, b1)]:
				var ring := Vector3(cos(ab.x), 0, sin(ab.x))
				var n := ring * cos(ab.y) + Vector3.UP * sin(ab.y)
				pts.append(xf * (ring * big + n * small))
				ns.append((nb * n).normalized())
			quad(mat, pts[0], pts[1], pts[2], pts[3], ns[0], ns[1], ns[2], ns[3])


## A tube of radius `r` along a smooth curve through `pts` (a hose, a cable), its ends open.
func tube(mat: Material, pts: PackedVector3Array, r: float, segs := 8, per_span := 6) -> void:
	if pts.size() < 2:
		return
	var line: PackedVector3Array = []
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		for k in per_span:
			var t := float(k) / per_span
			var t2 := t * t
			var t3 := t2 * t
			line.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	line.append(pts[pts.size() - 1])
	var tangent := (line[1] - line[0]).normalized()
	var normal := tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT).normalized()
	var rings: Array = []
	for i in line.size():
		var t: Vector3 = ((line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)])).normalized()
		# Carry the frame along the curve (no twist).
		normal = (normal - t * normal.dot(t)).normalized()
		var binormal := t.cross(normal)
		var ring: Array = []
		for k in segs:
			var a := TAU * k / segs
			var d := normal * cos(a) + binormal * sin(a)
			ring.append([line[i] + d * r, d])
		rings.append(ring)
	for i in rings.size() - 1:
		for k in segs:
			var k1 := (k + 1) % segs
			var a: Array = rings[i][k]
			var b: Array = rings[i][k1]
			var c: Array = rings[i + 1][k1]
			var d: Array = rings[i + 1][k]
			quad(mat, a[0], b[0], c[0], d[0], a[1], b[1], c[1], d[1])


## A curved shell: part of an ellipsoid round `centre` with radii `radii`, `thick` thick, from
## the top pole (v 0) down to `v_max(u)` (radians from +Y), for u from `u0` to `u1` round
## the Y axis (0 is -Z, the front; positive towards +X). `offset` pushes it out (a stripe on
## the shell). `rim` closes its edges.
func shell(mat: Material, centre: Vector3, radii: Vector3, u0: float, u1: float, v_max: Callable,
		thick: float, xf := Transform3D(), segs := 24, rings := 12, offset := 0.0, rim := true) -> void:
	var nb := xf.basis.inverse().transposed()
	var outer: Array = []
	var inner: Array = []
	for j in rings + 1:
		var orow: Array = []
		var irow: Array = []
		for k in segs + 1:
			var u := lerpf(u0, u1, float(k) / segs)
			var v := float(v_max.call(u)) * j / rings
			var dir := Vector3(sin(v) * sin(u), cos(v), -sin(v) * cos(u))
			var n := Vector3(dir.x / radii.x, dir.y / radii.y, dir.z / radii.z).normalized()
			var p := centre + Vector3(dir.x * radii.x, dir.y * radii.y, dir.z * radii.z) + n * offset
			orow.append([xf * p, (nb * n).normalized()])
			irow.append([xf * (p - n * thick), (nb * -n).normalized()])
		outer.append(orow)
		inner.append(irow)
	for j in rings:
		for k in segs:
			var a: Array = outer[j][k]
			var b: Array = outer[j][k + 1]
			var c: Array = outer[j + 1][k + 1]
			var d: Array = outer[j + 1][k]
			quad(mat, a[0], b[0], c[0], d[0], a[1], b[1], c[1], d[1])
			if thick > 0.0:
				var ia: Array = inner[j][k]
				var ib: Array = inner[j][k + 1]
				var ic: Array = inner[j + 1][k + 1]
				var id: Array = inner[j + 1][k]
				quad(mat, ia[0], ib[0], ic[0], id[0], ia[1], ib[1], ic[1], id[1])
	if not rim or thick <= 0.0:
		return
	# The rim round its open edge: the bottom row and both sides. Each edge point keeps a point
	# just inside the shell, so its rim faces away from it.
	var edge: Array = []
	for k in segs + 1:
		edge.append([outer[rings][k], inner[rings][k], outer[rings - 1][k][0]])
	for j in range(rings, -1, -1):
		edge.push_front([outer[j][0], inner[j][0], outer[j][1][0]])
		edge.append([outer[j][segs], inner[j][segs], outer[j][segs - 1][0]])
	for i in edge.size() - 1:
		var o0: Array = edge[i][0]
		var i0: Array = edge[i][1]
		var o1: Array = edge[i + 1][0]
		var i1: Array = edge[i + 1][1]
		var along: Vector3 = (o1[0] as Vector3) - (o0[0] as Vector3)
		if along.length() < 0.00001:
			continue
		var n: Vector3 = along.cross(o0[1] as Vector3).normalized()
		if n.dot((edge[i][2] as Vector3) - (o0[0] as Vector3)) > 0.0:
			n = -n
		quad(mat, o0[0], o1[0], i1[0], i0[0], n, n, n, n)
