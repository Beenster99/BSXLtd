class_name FrameParts
extends RefCounted
## Frame-and-plate parts: the bones and skin of a ship. Build the shape as a frame of
## girders first (straight, mitred to meet at any angle, with corner nodes), then bolt
## plates over it: squares, rectangles, every kind of triangle, trapezoids, parallelograms,
## regular polygons, or a plate cut to any flat outline you give it.
##
## Plates lie in the XZ plane with their outer face at y = 0 and their back at
## y = -thickness; the outer edges are bevelled. Girders run along X. All sizes in metres.
## FrameHull uses these to frame and skin whole hulls from cross-sections.

const PLATE_THICKNESS: float = 0.06
const PLATE_BEVEL: float = 0.02


# --- Girders --------------------------------------------------------------------------

## A straight girder between two points (ship space): the shape and where it goes. `up`
## picks which way its height faces (it's kept square to the girder).
static func girder_between(a: Vector3, b: Vector3, width: float, height: float,
		up := Vector3.UP, cut_start: float = 0.0, cut_end: float = 0.0) -> Array:
	var length := a.distance_to(b)
	var shape := PartShapes.girder(maxf(length, 0.01), width, height, cut_start, cut_end)
	return [shape, along(a, b, up)]


## A frame for something lying from `a` to `b`: X along it, Y as close to `up` as can be,
## origin in the middle.
static func along(a: Vector3, b: Vector3, up := Vector3.UP) -> Transform3D:
	var x := (b - a).normalized()
	if x.length() < 0.5:
		x = Vector3.RIGHT
	var hint := up if absf(up.normalized().dot(x)) < 0.95 else (Vector3.FORWARD if absf(x.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT)
	var z := x.cross(hint).normalized()
	var y := z.cross(x).normalized()
	return Transform3D(Basis(x, y, z), (a + b) * 0.5)


## A girder that chains round a bend: both ends cut at half of `bend` degrees, so a run of
## them turns `bend` degrees at every joint (e.g. 8 of them at 45 make an octagon).
static func angled_girder(length: float, bend: float, width: float = 0.16, height: float = 0.2) -> PartShapes.PartShape:
	return PartShapes.girder(length, width, height, bend * 0.5, bend * 0.5)


## A V-shaped girder piece: two arms of `arm` metres meeting at a bend of `bend` degrees
## (0 = straight on), mitred where they meet. The corner is at the origin; the first arm
## runs along -X, the second turns up toward +Y.
static func girder_corner(arm: float, bend: float, width: float = 0.16, height: float = 0.2) -> PartShapes.PartShape:
	var a := PartShapes.girder(arm, width, height, 0.0, bend * 0.5)
	var b := PartShapes.girder(arm, width, height, bend * 0.5, 0.0)
	var k := MeshKit.new()
	var turn := Basis(Vector3.BACK, deg_to_rad(bend))
	_append(k, a.mesh, Transform3D(Basis(), Vector3(-arm * 0.5, 0, 0)))
	_append(k, b.mesh, Transform3D(turn, turn * Vector3(arm * 0.5, 0, 0)))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = a.volume + b.volume
	var pts := PackedVector3Array()
	for v in k.verts:
		pts.append(v)
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	return PartShapes.stamp(shape, "girder_corner", [arm, bend, width, height])


## A rib: a flat web over `outline` (XY plane, convex, points in order) `web` thick along Z,
## with a flange along every edge (`lip` deep in from the edge, `flange` wide along Z) for a
## skin to be fastened to: the frame of something too thin for node blocks (a wing, a horn).
## Collision: the web, and each edge's flange as a piece of its own (`extra_collision`).
static func rib(outline: PackedVector2Array, web: float = 0.03, flange: float = 0.1, lip: float = 0.015) -> PartShapes.PartShape:
	var centre := Vector2.ZERO
	for p in outline:
		centre += p
	centre /= float(outline.size())
	var k := MeshKit.new()
	k.extrude(outline, web)
	var shape := PartShapes.PartShape.new()
	shape.collision = _prism(outline, web)
	var n := outline.size()
	for e in n:
		var a := outline[e]
		var b := outline[(e + 1) % n]
		if a.distance_to(b) < 0.01:
			continue
		var inward := (b - a).normalized().orthogonal()
		if inward.dot(centre - (a + b) * 0.5) < 0.0:
			inward = -inward
		var strip := PackedVector2Array([a, b, b + inward * lip, a + inward * lip])
		k.extrude(strip, flange)
		shape.extra_collision.append(_prism(strip, flange))
	shape.mesh = k.finish()
	shape.volume = k.volume()
	return PartShapes.stamp(shape, "rib", [outline, web, flange, lip])


## A convex prism over `outline` (XY plane) from z = -depth/2 to +depth/2.
static func _prism(outline: PackedVector2Array, depth: float) -> ConvexPolygonShape3D:
	var pts := PackedVector3Array()
	for p in outline:
		pts.append(Vector3(p.x, p.y, -depth * 0.5))
		pts.append(Vector3(p.x, p.y, depth * 0.5))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	return col


## A joint block where girders meet: a cube with bevelled edges.
static func node(size: float = 0.26) -> PartShapes.PartShape:
	return PartShapes.stamp(PartShapes.chamfer_box(Vector3.ONE * size, size * 0.22), "node", [size])


## A slim joint block: a box `size` (x across the corner, y out of the hull, z along the ship)
## with `bevel` on its edges, just over the members welded to it (FrameHull's `slim_nodes`).
static func node_box(size: Vector3, bevel: float) -> PartShapes.PartShape:
	return PartShapes.stamp(PartShapes.chamfer_box(size, bevel), "node_box", [size, bevel])


# --- Plates ---------------------------------------------------------------------------

## A plate cut to a convex outline (points in order round the edge, in the XZ plane). Its
## outer face is at y = `y_top` (0 by default) and its back `thickness` below that.
static func plate(outline: PackedVector2Array, thickness: float = PLATE_THICKNESS,
		bevel: float = PLATE_BEVEL, y_top: float = 0.0) -> PartShapes.PartShape:
	var bev := minf(bevel, thickness * 0.5)
	var top_outline := inset(outline, bev)
	var bottom := PackedVector3Array()
	var mid := PackedVector3Array()
	var top := PackedVector3Array()
	for p in outline:
		bottom.append(Vector3(p.x, y_top - thickness, p.y))
		mid.append(Vector3(p.x, y_top - bev, p.y))
	for p in top_outline:
		top.append(Vector3(p.x, y_top, p.y))
	var k := MeshKit.new()
	k.loft(bottom, mid, false)
	k.loft(mid, top, false)
	k.poly(top, Vector3.UP)
	k.poly(bottom, Vector3.DOWN)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = k.volume()
	var col := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array(bottom)
	pts.append_array(top)
	col.points = pts
	shape.collision = col
	return PartShapes.stamp(shape, "plate", [outline, thickness, bevel, y_top])


static func square(side: float, thickness: float = PLATE_THICKNESS) -> PartShapes.PartShape:
	return PartShapes.stamp(rect(side, side, thickness), "square", [side, thickness])


static func rect(width: float, length: float, thickness: float = PLATE_THICKNESS) -> PartShapes.PartShape:
	var w := width * 0.5
	var l := length * 0.5
	return PartShapes.stamp(plate(PackedVector2Array([Vector2(-w, -l), Vector2(w, -l), Vector2(w, l), Vector2(-w, l)]), thickness), "rect", [width, length, thickness])


## Equal sides; centred on its middle, a point toward -Z.
static func tri_equilateral(side: float, thickness: float = PLATE_THICKNESS) -> PartShapes.PartShape:
	return PartShapes.stamp(tri_isosceles(side, side * sqrt(3.0) * 0.5, thickness), "tri_equilateral", [side, thickness])


## A `base` wide, `height` tall triangle with two equal sides; base along X at +Z.
static func tri_isosceles(base: float, height: float, thickness: float = PLATE_THICKNESS) -> PartShapes.PartShape:
	return PartShapes.stamp(_centred_plate(PackedVector2Array([Vector2(-base * 0.5, 0), Vector2(base * 0.5, 0), Vector2(0, -height)]), thickness), "tri_isosceles", [base, height, thickness])


## A right-angled triangle with legs `a` (along X) and `b` (along Z).
static func tri_right(a: float, b: float, thickness: float = PLATE_THICKNESS) -> PartShapes.PartShape:
	return PartShapes.stamp(_centred_plate(PackedVector2Array([Vector2(0, 0), Vector2(a, 0), Vector2(0, -b)]), thickness), "tri_right", [a, b, thickness])


## A triangle from its three side lengths (any shape that can exist).
static func tri_scalene(a: float, b: float, c: float, thickness: float = PLATE_THICKNESS) -> PartShapes.PartShape:
	# Side a along X; the third corner from the law of cosines.
	var x := (a * a + c * c - b * b) / (2.0 * a)
	var y := sqrt(maxf(c * c - x * x, 0.0001))
	return PartShapes.stamp(_centred_plate(PackedVector2Array([Vector2(0, 0), Vector2(a, 0), Vector2(x, -y)]), thickness), "tri_scalene", [a, b, c, thickness])


## `bottom` wide at +Z, `top` wide at -Z, `height` apart. Set top to 0 for a triangle.
static func trapezoid(bottom: float, top: float, height: float, offset: float = 0.0,
		thickness: float = PLATE_THICKNESS) -> PartShapes.PartShape:
	return PartShapes.stamp(_centred_plate(PackedVector2Array([Vector2(-bottom * 0.5, 0), Vector2(bottom * 0.5, 0),
			Vector2(top * 0.5 + offset, -height), Vector2(-top * 0.5 + offset, -height)]), thickness), "plate_trapezoid", [bottom, top, height, offset, thickness])


## A slanted rectangle: `width` by `height`, its far edge shifted `skew` along X.
static func parallelogram(width: float, height: float, skew: float, thickness: float = PLATE_THICKNESS) -> PartShapes.PartShape:
	return PartShapes.stamp(trapezoid(width, width, height, skew, thickness), "parallelogram", [width, height, skew, thickness])


## A diamond, `width` by `length`.
static func rhombus(width: float, length: float, thickness: float = PLATE_THICKNESS) -> PartShapes.PartShape:
	return PartShapes.stamp(plate(PackedVector2Array([Vector2(0, -length * 0.5), Vector2(width * 0.5, 0), Vector2(0, length * 0.5),
			Vector2(-width * 0.5, 0)]), thickness), "rhombus", [width, length, thickness])


## A regular polygon with `sides` sides (5 = pentagon, 6 = hexagon, 8 = octagon...).
static func polygon(sides: int, radius: float, thickness: float = PLATE_THICKNESS) -> PartShapes.PartShape:
	var pts := PackedVector2Array()
	for i in sides:
		var a := TAU * float(i) / float(sides) - PI * 0.5
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return PartShapes.stamp(plate(pts, thickness), "polygon", [sides, radius, thickness])


## A rectangle with its corners cut off at 45 degrees.
static func chamfered_rect(width: float, length: float, chamfer: float, thickness: float = PLATE_THICKNESS) -> PartShapes.PartShape:
	return PartShapes.stamp(plate(PartShapes._chamfer_rect(width, length, chamfer), thickness), "chamfered_rect", [width, length, chamfer, thickness])


## A plate over `points` (ship space, on its outer face's plane) built in the given
## `frame` (plate space: Y out of the face, the outer face at local y = `y_top`): the
## outline is the points seen in that frame. For a second, bigger outline on a plate
## placed with `plate_between` (a flush skin's visual over its inset collision).
static func plate_in_frame(points: PackedVector3Array, frame: Transform3D, thickness: float = PLATE_THICKNESS,
		bevel: float = PLATE_BEVEL, y_top: float = 0.0) -> PartShapes.PartShape:
	var inv := frame.affine_inverse()
	var outline := PackedVector2Array()
	for p in points:
		var l := inv * p
		outline.append(Vector2(l.x, l.z))
	return plate(outline, thickness, bevel, y_top)


## A plate spanning a flat outline in ship space (3 or more points in order round it; the
## outer face is the side `outward` points to, and the plate's thickness goes the other
## way). Returns [shape, transform].
static func plate_between(points: PackedVector3Array, outward: Vector3, thickness: float = PLATE_THICKNESS,
		bevel: float = PLATE_BEVEL) -> Array:
	var origin := Vector3.ZERO
	for p in points:
		origin += p
	origin /= float(points.size())
	var n := (points[1] - points[0]).cross(points[2] - points[0])
	if n.length() < 1e-8 and points.size() > 3:
		n = (points[2] - points[0]).cross(points[3] - points[0])
	n = n.normalized()
	if n.dot(outward) < 0.0:
		n = -n
	var u := (points[1] - points[0]).normalized()
	# Plate space: X along the first edge, Y out of the face, Z = X x Y.
	var basis := Basis(u, n, u.cross(n))
	var outline := PackedVector2Array()
	for p in points:
		var d := p - origin
		outline.append(Vector2(d.dot(basis.x), d.dot(basis.z)))
	return [plate(outline, thickness, bevel), Transform3D(basis, origin)]


## An outline moved inward by `d` (convex outlines, points in order).
static func inset(outline: PackedVector2Array, d: float) -> PackedVector2Array:
	if d <= 0.0:
		return outline
	var centre := Vector2.ZERO
	for p in outline:
		centre += p
	centre /= float(outline.size())
	var n := outline.size()
	var normals: Array[Vector2] = []
	for i in n:
		var e := outline[(i + 1) % n] - outline[i]
		var nrm := Vector2(-e.y, e.x).normalized()
		if nrm.dot(centre - (outline[i] + outline[(i + 1) % n]) * 0.5) < 0.0:
			nrm = -nrm
		normals.append(nrm)
	var out := PackedVector2Array()
	for i in n:
		var n1 := normals[(i - 1 + n) % n]
		var n2 := normals[i]
		var denom := 1.0 + n1.dot(n2)
		out.append(outline[i] + (n1 + n2) * (d / maxf(denom, 0.1)))
	return out


static func _centred_plate(outline: PackedVector2Array, thickness: float) -> PartShapes.PartShape:
	var c := Vector2.ZERO
	for p in outline:
		c += p
	c /= float(outline.size())
	var moved := PackedVector2Array()
	for p in outline:
		moved.append(p - c)
	return plate(moved, thickness)


static func _append(k: MeshKit, mesh: ArrayMesh, xform: Transform3D) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in verts.size():
		k.verts.append(xform * verts[i])
		k.normals.append((xform.basis * normals[i]).normalized())
		k.colors.append(colors[i])


# --- Catalogue ------------------------------------------------------------------------

## Every frame and plate piece in a few sizes: [name, PartShape].
static func catalogue() -> Array:
	var list: Array = []
	for length: float in [0.5, 1.0, 2.0, 4.0]:
		list.append(["girder %.1f m" % length, PartShapes.girder(length, 0.16, 0.2)])
	for bend: float in [15.0, 22.5, 30.0, 45.0, 60.0, 90.0]:
		for length: float in [1.0, 2.0, 3.0]:
			list.append(["girder %.0f m, %.1f deg ends" % [length, bend], angled_girder(length, bend)])
	for bend: float in [30.0, 45.0, 60.0, 90.0, 120.0]:
		list.append(["corner %.0f deg" % bend, girder_corner(1.0, bend)])
	list.append(["node 0.26", node(0.26)])
	list.append(["node 0.4", node(0.4)])
	for s: float in [0.5, 1.0, 2.0]:
		list.append(["plate square %.1f" % s, square(s)])
	for wl: Vector2 in [Vector2(1, 2), Vector2(0.5, 2), Vector2(2, 4)]:
		list.append(["plate rect %.1fx%.1f" % [wl.x, wl.y], rect(wl.x, wl.y)])
	for s: float in [1.0, 2.0]:
		list.append(["triangle equilateral %.0f" % s, tri_equilateral(s)])
	list.append(["triangle isosceles 1x2", tri_isosceles(1.0, 2.0)])
	list.append(["triangle isosceles 2x1", tri_isosceles(2.0, 1.0)])
	list.append(["triangle right 1x1", tri_right(1.0, 1.0)])
	list.append(["triangle right 1x2", tri_right(1.0, 2.0)])
	list.append(["triangle scalene 2,1.5,1", tri_scalene(2.0, 1.5, 1.0)])
	list.append(["trapezoid 2/1 x1", trapezoid(2.0, 1.0, 1.0)])
	list.append(["trapezoid 2/1.5 x2 offset", trapezoid(2.0, 1.5, 2.0, 0.25)])
	list.append(["parallelogram 1x2 skew 0.5", parallelogram(1.0, 2.0, 0.5)])
	list.append(["rhombus 1x2", rhombus(1.0, 2.0)])
	for n: int in [5, 6, 8]:
		list.append(["polygon %d sides" % n, polygon(n, 0.8)])
	list.append(["chamfered rect 2x1", chamfered_rect(2.0, 1.0, 0.25)])
	return list


## An outline moved inward by a different distance per edge (`dists[i]` for the edge from
## point i to i + 1): each corner is where its two offset edges cross.
static func inset_edges(outline: PackedVector2Array, dists: Array[float]) -> PackedVector2Array:
	var centre := Vector2.ZERO
	for p in outline:
		centre += p
	centre /= float(outline.size())
	var n := outline.size()
	var normals: Array[Vector2] = []
	for i in n:
		var e := outline[(i + 1) % n] - outline[i]
		var nrm := Vector2(-e.y, e.x).normalized()
		if nrm.dot(centre - (outline[i] + outline[(i + 1) % n]) * 0.5) < 0.0:
			nrm = -nrm
		normals.append(nrm)
	var out := PackedVector2Array()
	for i in n:
		var n1 := normals[(i - 1 + n) % n]
		var n2 := normals[i]
		var d1 := dists[(i - 1 + n) % n]
		var d2 := dists[i]
		var det := n1.x * n2.y - n1.y * n2.x
		if absf(det) < 1e-4:
			out.append(outline[i] + n1 * maxf(d1, d2))
			continue
		var v := Vector2((d1 * n2.y - n1.y * d2) / det, (n1.x * d2 - n2.x * d1) / det)
		out.append(outline[i] + v)
	return out


# --- Mitred frames (the ribbed frame, wreck pipeline v5) ----------------------------------

## A box girder `w` by `h` from `pa` to `pb` (its frame `along`, `up` its height) with each end
## cut on a plane ([a point, its normal into the girder], ship space): the look to the cuts, the collision
## `gap` short of each. Null when the cuts cross (too short for its joints).
static func cut_girder(pa: Vector3, pb: Vector3, up: Vector3, w: float, h: float, ca: Array, cb: Array,
		gap: float) -> PartShapes.PartShape:
	var xf := along(pa, pb, up)
	var inv := xf.affine_inverse()
	var loops: Array = []
	for g: float in [0.0, gap]:
		var ends: Array = []
		for c: Array in [ca, cb]:
			var nn: Vector3 = (inv.basis * (c[1] as Vector3)).normalized()
			if absf(nn.x) < 0.2:
				return null
			var pt: Vector3 = inv * ((c[0] as Vector3) + (c[1] as Vector3).normalized() * g)
			var loop := PackedVector3Array()
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var o := Vector3(0.0, corner.y * h * 0.5, corner.x * w * 0.5)
				loop.append(o + Vector3(nn.dot(pt - o) / nn.x, 0.0, 0.0))
			ends.append(loop)
		for i in 4:
			if (ends[0][i] as Vector3).x >= (ends[1][i] as Vector3).x - 0.02:
				return null
		loops.append(ends)
	var shape := PartShapes.PartShape.new()
	shape.mesh = solid_between(loops[0][0], loops[0][1])
	var col := ConvexPolygonShape3D.new()
	col.points = (loops[1][0] as PackedVector3Array) + (loops[1][1] as PackedVector3Array)
	shape.collision = col
	var length := 0.0
	for i in 4:
		length += ((loops[0][1] as PackedVector3Array)[i].x - (loops[0][0] as PackedVector3Array)[i].x) * 0.25
	shape.volume = w * h * length
	return PartShapes.stamp(shape, "cut_girder", [pa, pb, up, w, h, ca, cb, gap])


## The convex solid between two corner loops (corner for corner), flat shaded, wound as Godot draws front faces.
static func solid_between(la: PackedVector3Array, lb: PackedVector3Array) -> ArrayMesh:
	var n := la.size()
	var middle := Vector3.ZERO
	for p in la + lb:
		middle += p
	middle /= float(2 * n)
	var tris: Array = []
	for i in range(1, n - 1):
		tris.append([la[0], la[i], la[i + 1]])
		tris.append([lb[0], lb[i + 1], lb[i]])
	for i in n:
		var j := (i + 1) % n
		tris.append([la[i], lb[i], lb[j]])
		tris.append([la[i], lb[j], la[j]])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t: Array in tris:
		var nrm: Vector3 = ((t[1] as Vector3) - (t[0] as Vector3)).cross((t[2] as Vector3) - (t[0] as Vector3)).normalized()
		if nrm.dot((t[0] as Vector3) - middle) > 0.0:
			t = [t[0], t[2], t[1]]
			nrm = -nrm
		for v in t:
			st.set_color(Color.WHITE)
			st.set_normal(-nrm)
			st.add_vertex(v)
	var arrays := st.commit_to_arrays()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	MeshKit.keep(mesh, arrays)            # the shadow merge reads its corners here, not off the GPU
	return mesh


## A bar lofted from section `a` (XY) at z `za` to section `b` (corner for corner) at `zb`, ship space: the
## look (caps and sides, flat shaded) and a convex collision of its corners (an edge bar down a lip).
static func loft_bar(a: PackedVector2Array, za: float, b: PackedVector2Array, zb: float) -> PartShapes.PartShape:
	if absf(zb - za) < 0.05:
		return null
	var n := a.size()
	var pa := PackedVector3Array()
	var pb := PackedVector3Array()
	for i in n:
		pa.append(Vector3(a[i].x, a[i].y, za))
		pb.append(Vector3(b[i].x, b[i].y, zb))
	var shape := PartShapes.PartShape.new()
	shape.mesh = solid_between(pa, pb)
	var col := ConvexPolygonShape3D.new()
	col.points = pa + pb
	shape.collision = col
	shape.volume = absf(_area2(a) + _area2(b)) * 0.5 * absf(zb - za)
	return PartShapes.stamp(shape, "loft_bar", [a, za, b, zb])


## A flat outline's signed area.
static func _area2(pts: PackedVector2Array) -> float:
	var s := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5
