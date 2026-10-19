class_name MeshKit
extends RefCounted
## Builds solid, flat-shaded meshes from triangles, quads and polygons, with a colour per
## face (vertex colours: tint the whole part with the material's albedo; use colours for
## details like gaskets and bolt heads).
##
## Every face is given an outward direction so it always faces the right way, whatever
## order its corners come in. Godot draws clockwise-wound faces as the front.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var color := Color.WHITE


func tri(a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	# Clockwise from outside means the right-hand normal points inward.
	if n.dot(outward) > 0.0:
		var t := b
		b = c
		c = t
		n = -n
	var face := -n.normalized()
	for p in [a, b, c]:
		verts.append(p)
		normals.append(face)
		colors.append(color)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	tri(a, b, c, outward)
	tri(a, c, d, outward)


## A flat convex polygon (corners in order around its edge).
func poly(points: PackedVector3Array, outward: Vector3) -> void:
	for i in range(1, points.size() - 1):
		tri(points[0], points[i], points[i + 1], outward)


## A prism: the 2D outline `outline` (convex or not, in order) in the XY plane, extruded
## from z = -depth/2 to +depth/2. Caps are fanned, so give convex outlines for caps, or
## set `caps` false and close it yourself.
func extrude(outline: PackedVector2Array, depth: float, caps: bool = true) -> void:
	var z0 := -depth * 0.5
	var z1 := depth * 0.5
	var centre := Vector2.ZERO
	for p in outline:
		centre += p
	centre /= float(outline.size())
	var n := outline.size()
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		var mid := (a + b) * 0.5
		var edge := b - a
		var side_out := Vector2(edge.y, -edge.x)
		if side_out.dot(mid - centre) < 0.0:
			side_out = -side_out
		quad(Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1),
				Vector3(a.x, a.y, z1), Vector3(side_out.x, side_out.y, 0.0))
	if caps:
		var front := PackedVector3Array()
		var back := PackedVector3Array()
		for p in outline:
			front.append(Vector3(p.x, p.y, z1))
			back.append(Vector3(p.x, p.y, z0))
		poly(front, Vector3.BACK)
		poly(back, Vector3.FORWARD)


## A solid between two rings of points (same count, in order round): a frustum, a tapered
## beam, a lofted section. Caps both ends as flat fans.
func loft(ring_a: PackedVector3Array, ring_b: PackedVector3Array, caps: bool = true) -> void:
	var n := ring_a.size()
	var ca := _centroid(ring_a)
	var cb := _centroid(ring_b)
	var axis := (cb - ca).normalized()
	for i in n:
		var j := (i + 1) % n
		var mid := (ring_a[i] + ring_a[j] + ring_b[i] + ring_b[j]) * 0.25
		var core := ca.lerp(cb, 0.5)
		var out := mid - core
		out -= axis * out.dot(axis)
		quad(ring_a[i], ring_a[j], ring_b[j], ring_b[i], out)
	if caps:
		poly(ring_a, -axis)
		poly(ring_b, axis)


## A ring-shaped solid made by spinning a closed 2D profile (x = radius, y = height) round
## the Y axis, in `segments` steps. For flanges, lips and round frames.
func lathe(profile: PackedVector2Array, segments: int) -> void:
	var n := profile.size()
	var pc := Vector2.ZERO
	for p in profile:
		pc += p
	pc /= float(n)
	for s in segments:
		var a0 := TAU * float(s) / float(segments)
		var a1 := TAU * float(s + 1) / float(segments)
		for i in n:
			var p := profile[i]
			var q := profile[(i + 1) % n]
			var edge := q - p
			var out2 := Vector2(edge.y, -edge.x)
			if out2.dot((p + q) * 0.5 - pc) < 0.0:
				out2 = -out2
			var am := (a0 + a1) * 0.5
			var out := Vector3(out2.x * cos(am), out2.y, out2.x * sin(am))
			quad(_spin(p, a0), _spin(q, a0), _spin(q, a1), _spin(p, a1), out)


## Adds an axis-aligned box centred at `centre`.
func box(size: Vector3, centre: Vector3 = Vector3.ZERO) -> void:
	var h := size * 0.5
	var c := centre
	var p := func(x: float, y: float, z: float) -> Vector3: return c + Vector3(x * h.x, y * h.y, z * h.z)
	quad(p.call(1, -1, -1), p.call(1, 1, -1), p.call(1, 1, 1), p.call(1, -1, 1), Vector3.RIGHT)
	quad(p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(-1, 1, 1), p.call(-1, -1, 1), Vector3.LEFT)
	quad(p.call(-1, 1, -1), p.call(1, 1, -1), p.call(1, 1, 1), p.call(-1, 1, 1), Vector3.UP)
	quad(p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), p.call(-1, -1, 1), Vector3.DOWN)
	quad(p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1), Vector3.BACK)
	quad(p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(-1, 1, -1), Vector3.FORWARD)


## A box from `a` to `b` (a strut), `thickness` square, at any angle.
func strut(a: Vector3, b: Vector3, thickness: float) -> void:
	var along := b - a
	var length := along.length()
	if length < 0.0001:
		return
	var y := along / length
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var t := thickness * 0.5
	var ring_a := PackedVector3Array([a + (x + z) * t, a + (x - z) * t, a + (-x - z) * t, a + (-x + z) * t])
	var ring_b := PackedVector3Array()
	for p in ring_a:
		ring_b.append(p + along)
	loft(ring_a, ring_b)


func finish() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	if not verts.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Volume enclosed by everything added so far, in cubic metres (closed solids only; each
## separate solid adds its own).
func volume() -> float:
	var v := 0.0
	var i := 0
	while i < verts.size():
		# Faces wind clockwise from outside, so the signed volume comes out negative.
		v -= verts[i].dot(verts[i + 1].cross(verts[i + 2])) / 6.0
		i += 3
	return absf(v)


static func _centroid(points: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in points:
		c += p
	return c / float(maxi(points.size(), 1))


static func _spin(p: Vector2, angle: float) -> Vector3:
	return Vector3(p.x * cos(angle), p.y, p.x * sin(angle))
