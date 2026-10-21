class_name FrameMember
extends RefCounted
## A frame member cut to fit: a straight bar whose ends are cut at an angle (mitred), so
## the members of a ring close up at the corners like a welded picture frame instead of
## stopping short with a joint block over the gap.
##
## The bar's side outline lies in the local XY plane (X along the bar, +Y out of the hull)
## and it is `width` thick along Z. Long faces are split into cells about `cell` metres
## long, so DeformMesh can bend the bar (see DeformMesh.displace).


## Builds a bar from its four outline corners in local XY, in order round the outline:
## inner start, inner end, outer end, outer start. Returns a PartShape (mesh, convex
## collision, volume).
static func build(outline: PackedVector2Array, width: float, cell: float = 0.12) -> PartShapes.PartShape:
	var in0 := outline[0]
	var in1 := outline[1]
	var out1 := outline[2]
	var out0 := outline[3]
	var hz := width * 0.5
	var centre := (in0 + in1 + out1 + out0) * 0.25
	var steps := clampi(int(ceil(maxf(in0.distance_to(in1), out0.distance_to(out1)) / cell)), 1, 48)
	var k := MeshKit.new()
	var inner_out := _side_out(in0, in1, centre)
	var outer_out := _side_out(out0, out1, centre)
	for i in steps:
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var a_in := in0.lerp(in1, t0)
		var b_in := in0.lerp(in1, t1)
		var a_out := out0.lerp(out1, t0)
		var b_out := out0.lerp(out1, t1)
		# Inner and outer long faces.
		k.quad(_v(a_in, -hz), _v(b_in, -hz), _v(b_in, hz), _v(a_in, hz), inner_out)
		k.quad(_v(a_out, -hz), _v(b_out, -hz), _v(b_out, hz), _v(a_out, hz), outer_out)
		# The flat sides (front and back of the ring).
		k.quad(_v(a_in, hz), _v(b_in, hz), _v(b_out, hz), _v(a_out, hz), Vector3.BACK)
		k.quad(_v(a_in, -hz), _v(b_in, -hz), _v(b_out, -hz), _v(a_out, -hz), Vector3.FORWARD)
	# The two cut ends.
	k.quad(_v(in0, -hz), _v(out0, -hz), _v(out0, hz), _v(in0, hz), _side_out(in0, out0, centre))
	k.quad(_v(in1, -hz), _v(out1, -hz), _v(out1, hz), _v(in1, hz), _side_out(in1, out1, centre))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = k.volume()
	var pts := PackedVector3Array()
	for p in [in0, in1, out1, out0]:
		pts.append(_v(p, -hz))
		pts.append(_v(p, hz))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	return shape


## The four outline corners of a member running along the centre line from `a` to `b`
## (2D, in the ring's plane), `depth` deep across it, with each end cut along the line
## through that end in direction `cut_a` / `cut_b` (the mitre line), and pulled back `gap`
## metres from it (half the clearance to the neighbour). `outward` is which way is out of
## the hull. Corners in the same space as a and b: inner a, inner b, outer b, outer a.
static func mitre_outline(a: Vector2, b: Vector2, depth: float, outward: Vector2,
		cut_a: Vector2, cut_b: Vector2, gap: float) -> PackedVector2Array:
	var dir := (b - a).normalized()
	var n := outward.normalized()
	var pts := PackedVector2Array()
	for end: Array in [[a, cut_a, 1.0], [b, cut_b, -1.0]]:
		var p: Vector2 = end[0]
		var m: Vector2 = (end[1] as Vector2).normalized()
		if m.dot(n) < 0.0:
			m = -m
		var t := depth * 0.5 / maxf(m.dot(n), 0.2)
		# Pull back along the member until the end is `gap` clear of the cut line.
		var across := Vector2(m.y, -m.x)
		var back := dir * float(end[2]) * gap / maxf(absf(across.dot(dir)), 0.2)
		pts.append(p - m * t + back)
		pts.append(p + m * t + back)
	# pts: inner a, outer a, inner b, outer b -> reorder.
	return PackedVector2Array([pts[0], pts[2], pts[3], pts[1]])


## The mitre line where two members meet at a corner, given each one's direction of
## travel (in order round the ring): it splits the corner angle in half.
static func mitre_line(dir_in: Vector2, dir_out: Vector2) -> Vector2:
	var s := (dir_in.normalized() + dir_out.normalized())
	if s.length() < 0.001:
		return Vector2(-dir_in.y, dir_in.x)
	s = s.normalized()
	return Vector2(-s.y, s.x)


static func _v(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, p.y, z)


## Which way is out of the bar across the edge from p to q (in XY).
static func _side_out(p: Vector2, q: Vector2, centre: Vector2) -> Vector3:
	var e := q - p
	var n := Vector2(e.y, -e.x)
	if n.dot((p + q) * 0.5 - centre) < 0.0:
		n = -n
	return Vector3(n.x, n.y, 0.0)
