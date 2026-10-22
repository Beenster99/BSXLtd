class_name PartShapes
extends RefCounted
## The parts library: geometric shapes to build ships from, each in any size you ask for.
##
## Every function returns a PartShape: a mesh (vertex-coloured; tint it with a material), a
## collision shape that fits it, its volume (for mass), and for windows the glass and the
## fastener points. Shapes are centred on the origin. Units are metres.
##
## Families (see the gallery: scenes/part_gallery.tscn):
##   Blocks      box, wedge (right-angle slope), ridge (peak), slope (ramp), trapezoid
##               (tapered), corner (cube corner), corner_cut (cube with a corner off)
##   Beams       prism (3-8 sided), frustum (cones, nozzles, transitions), girder (box
##               section with mitred ends, to meet at angles), i_beam, truss (lattice)
##   Curves      arc_panel (a slice of a tube wall: tile them into round hulls and corners),
##               dome (a cap for noses and pods)
##   Details     chamfer_box (bevelled block), ring (duct rim), nozzle (bell with lip),
##               louvre (vent with angled slats), inset_panel (raised border, recessed face)
##   Windows     window_panel (square-edged frame with a round, hex, rounded-rectangle or
##               slot opening: fills a wall's rectangular hole exactly),
##               porthole_round, porthole_hex, window_rect (chamfered, with mullions),
##               window_slit (stadium, with an eyebrow shroud), window_tri, canopy_panel


## One shape: its look, its collision, its volume, and extras for windows.
class PartShape:
	var mesh: ArrayMesh
	var collision: Shape3D
	var volume: float = 0.0
	## Windows: the glass, separate so it can take a glass material, of `glass_kind`
	## (Glazing.Kind: clear, tinted, frosted, armoured, amber or red lens, solar cover).
	var glass: ArrayMesh
	var glass_kind: int = Glazing.Kind.CLEAR
	## Lit details (thruster glow, lamp lenses, light strips), separate so they can take an
	## emissive material of `glow_color`.
	var glow: ArrayMesh
	var glow_color := Color(0.4, 0.75, 1.0)
	## The lit details by kind (docs/DAMAGE_PLAN.md 9.3.2), so each kind can behave on
	## low power: [{"kind", "mesh", "color"}], kinds from EMISSIVE_KINDS. Empty for a part
	## nobody has tagged yet: its `glow` counts as one "led". Once tagged, `glow` is the
	## union of these (for anything that only draws one glow).
	var emissives: Array = []
	## Windows: where to put fasteners, and which way they face (shape space).
	var fastener_points: PackedVector3Array = PackedVector3Array()
	var fastener_normals: PackedVector3Array = PackedVector3Array()
	## More collision shapes for one part (a holed plate's convex pieces), same space as
	## `collision`; SalvageStructure gives the part a collider for each.
	var extra_collision: Array[Shape3D] = []
	## How to make it again: {"shape": constructor name, "args": its arguments in order}, set
	## by every public constructor here and in FrameParts (the ship file writes pieces by
	## it, docs/SHIP_FORMAT_PLAN.md 4.6). Empty for a shape built by hand from a MeshKit.
	var recipe: Dictionary = {}

	func aabb() -> AABB:
		return mesh.get_aabb()


## The kinds of lit detail (PartShape.emissives):
##   led     status lights (blink slowly on low power)
##   screen  readouts and monitors (a frozen readout or static on low power; can blow)
##   strip   recessed and floor strips, exit signs (amber at a third on low power)
##   lamp    lenses of nav and head lamps
##   hot     thruster floors, reactor cores: lit as built whatever the power
##   warning a red flasher (slow blink on low power, steady on full, off when dead)
const EMISSIVE_KINDS := ["led", "screen", "strip", "lamp", "hot", "warning"]


## Tags `mesh` on `shape` as lit detail of `kind` (EMISSIVE_KINDS) in `color`, and adds it
## to the shape's `glow` (the union); the first one tagged sets `glow_color`.
static func emissive(shape: PartShape, kind: String, mesh: ArrayMesh, color: Color) -> void:
	if mesh == null or mesh.get_surface_count() == 0:
		return
	shape.emissives.append({"kind": kind, "mesh": mesh, "color": color})
	if shape.glow == null:
		shape.glow = ArrayMesh.new()
		shape.glow_color = color
	for i in mesh.get_surface_count():
		shape.glow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(i))


## Stamps `shape` with its recipe and returns it (the last constructor to return a shape
## names it: a prism is a frustum underneath, but its recipe says prism).
static func stamp(shape: PartShape, shape_name: String, args: Array) -> PartShape:
	shape.recipe = {"shape": shape_name, "args": args}
	return shape


const DETAIL := Color(0.55, 0.56, 0.58, SurfaceZones.BARE_A)    # bolts and studs, darker than the body (bare metal)
const GASKET := Color(0.12, 0.12, 0.13, SurfaceZones.RUBBER_A)  # rubber seals round glass
const ACCENT := Color(1.0, 0.62, 0.15, SurfaceZones.HAZARD_PAINT_A)  # warning trim (hazard paint)


# --- Blocks ---------------------------------------------------------------------------

static func box(size: Vector3) -> PartShape:
	var k := MeshKit.new()
	k.box(size)
	return stamp(_convex(k), "box", [size])


## A right-angle wedge: full height at the back (-Z), sloping to nothing at the front (+Z).
## Width along X.
static func wedge(size: Vector3) -> PartShape:
	var h := size * 0.5
	var outline := PackedVector2Array([Vector2(-h.z, -h.y), Vector2(h.z, -h.y), Vector2(-h.z, h.y)])
	return stamp(_extruded_x(outline, size.x), "wedge", [size])


## A peaked ridge: a triangle with its apex centred on top, along X.
static func ridge(size: Vector3) -> PartShape:
	var h := size * 0.5
	var outline := PackedVector2Array([Vector2(-h.z, -h.y), Vector2(h.z, -h.y), Vector2(0.0, h.y)])
	return stamp(_extruded_x(outline, size.x), "ridge", [size])


## A ramp: full height at the back (-Z) dropping to `low` of the height at the front.
static func slope(size: Vector3, low: float = 0.35) -> PartShape:
	var h := size * 0.5
	var outline := PackedVector2Array([Vector2(-h.z, -h.y), Vector2(h.z, -h.y),
			Vector2(h.z, -h.y + size.y * low), Vector2(-h.z, h.y)])
	return stamp(_extruded_x(outline, size.x), "slope", [size, low])


## A tapered block: `bottom` wide at the base, `top` wide at the top, `height` tall,
## `depth` deep (Z). For chamfered transitions and angled hull sides.
static func trapezoid(bottom: float, top: float, height: float, depth: float) -> PartShape:
	var outline := PackedVector2Array([Vector2(-bottom * 0.5, -height * 0.5), Vector2(bottom * 0.5, -height * 0.5),
			Vector2(top * 0.5, height * 0.5), Vector2(-top * 0.5, height * 0.5)])
	var k := MeshKit.new()
	k.extrude(outline, depth)
	return stamp(_convex(k), "trapezoid", [bottom, top, height, depth])


## The corner of a cube sliced off diagonally: a right tetrahedron filling `size`.
static func corner(size: Vector3) -> PartShape:
	var h := size * 0.5
	var o := Vector3(-h.x, -h.y, -h.z)
	var px := Vector3(h.x, -h.y, -h.z)
	var py := Vector3(-h.x, h.y, -h.z)
	var pz := Vector3(-h.x, -h.y, h.z)
	var k := MeshKit.new()
	var c := (o + px + py + pz) / 4.0
	for f: Array in [[o, px, py], [o, py, pz], [o, pz, px], [px, py, pz]]:
		var centre: Vector3 = (f[0] + f[1] + f[2]) / 3.0
		k.tri(f[0], f[1], f[2], centre - c)
	return stamp(_convex(k), "corner", [size])


## A box with one corner (the +X +Y +Z one) cut off at `cut` of its size: for inside
## corners where slopes meet.
static func corner_cut(size: Vector3, cut: float = 0.5) -> PartShape:
	var h := size * 0.5
	var pts := PackedVector3Array()
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				if x > 0 and y > 0 and z > 0:
					continue
				pts.append(Vector3(x * h.x, y * h.y, z * h.z))
	pts.append(Vector3(h.x - size.x * cut, h.y, h.z))
	pts.append(Vector3(h.x, h.y - size.y * cut, h.z))
	pts.append(Vector3(h.x, h.y, h.z - size.z * cut))
	return stamp(_hull(pts), "corner_cut", [size, cut])


# --- Beams ----------------------------------------------------------------------------

## A straight beam with `sides` faces (3 = triangle, 6 = hex, 8 = octagon), along Y.
static func prism(sides: int, radius: float, length: float) -> PartShape:
	return stamp(frustum(radius, radius, length, sides), "prism", [sides, radius, length])


## A cone or tapered beam along Y: `bottom` radius at -Y, `top` at +Y. Nozzles, noses,
## transitions between round sections.
static func frustum(bottom: float, top: float, length: float, sides: int = 16) -> PartShape:
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	for i in sides:
		var ang := TAU * (float(i) + 0.5) / float(sides)
		a.append(Vector3(cos(ang) * bottom, -length * 0.5, sin(ang) * bottom))
		b.append(Vector3(cos(ang) * top, length * 0.5, sin(ang) * top))
	if top < 0.001:
		var k := MeshKit.new()
		var tip := Vector3(0, length * 0.5, 0)
		for i in sides:
			var j := (i + 1) % sides
			var mid := (a[i] + a[j]) * 0.5
			k.tri(a[i], a[j], tip, Vector3(mid.x, 0.3, mid.z))
		k.poly(a, Vector3.DOWN)
		return stamp(_convex(k), "frustum", [bottom, top, length, sides])
	var k2 := MeshKit.new()
	k2.loft(a, b)
	return stamp(_convex(k2), "frustum", [bottom, top, length, sides])


## A box-section girder along X, `width` (Z) by `height` (Y), with each end cut at an angle
## (degrees, round Y) so girders meet cleanly at bends: two girders with 22.5 degree cuts
## make a 45 degree corner. `length` is measured along the centre line.
static func girder(length: float, width: float, height: float, cut_start: float = 0.0,
		cut_end: float = 0.0) -> PartShape:
	var hw := width * 0.5
	var hh := height * 0.5
	var ts := tan(deg_to_rad(cut_start))
	var te := tan(deg_to_rad(cut_end))
	var pts := PackedVector3Array()
	for z: float in [-hw, hw]:
		for y: float in [-hh, hh]:
			pts.append(Vector3(-length * 0.5 + z * ts, y, z))
			pts.append(Vector3(length * 0.5 - z * te, y, z))
	var shape := _hull(pts)
	# Darker lightening holes along the sides, just for looks.
	var k := MeshKit.new()
	k.verts = shape.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	k.normals = shape.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	k.colors = shape.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	k.color = DETAIL
	var holes := maxi(int(length / (height * 1.6)), 1)
	for i in holes:
		var x := -length * 0.5 + length * (float(i) + 0.5) / float(holes)
		for side: float in [-1.0, 1.0]:
			k.box(Vector3(height * 0.55, height * 0.45, 0.004), Vector3(x, 0.0, side * (hw + 0.002)))
	shape.mesh = k.finish()
	return stamp(shape, "girder", [length, width, height, cut_start, cut_end])


## An I-beam along X: two flanges and a web. Collision is its outer box.
static func i_beam(length: float, width: float, height: float, flange: float = 0.0,
		web: float = 0.0) -> PartShape:
	if flange <= 0.0:
		flange = height * 0.14
	if web <= 0.0:
		web = width * 0.18
	var k := MeshKit.new()
	k.box(Vector3(length, flange, width), Vector3(0, height * 0.5 - flange * 0.5, 0))
	k.box(Vector3(length, flange, width), Vector3(0, -height * 0.5 + flange * 0.5, 0))
	k.box(Vector3(length, height - flange * 2.0, web))
	var shape := PartShape.new()
	shape.mesh = k.finish()
	shape.volume = k.volume()
	var col := BoxShape3D.new()
	col.size = Vector3(length, height, width)
	shape.collision = col
	return stamp(shape, "i_beam", [length, width, height, flange, web])


## A lattice truss along X: four chords and zig-zag bracing in `bays` bays. Light and
## open-looking; collision is its outer box. Like `girder`, each end can be cut at an
## angle (degrees, round Y) so trusses meet cleanly at bends: two 45 degree cuts make a
## square corner. `length` is measured along the centre line.
static func truss(length: float, width: float, height: float, bays: int = 4, member: float = 0.0,
		cut_start: float = 0.0, cut_end: float = 0.0) -> PartShape:
	if member <= 0.0:
		member = minf(width, height) * 0.12
	var k := MeshKit.new()
	var hw := width * 0.5 - member * 0.5
	var hh := height * 0.5 - member * 0.5
	var ts := tan(deg_to_rad(cut_start))
	var te := tan(deg_to_rad(cut_end))
	var corners := [Vector2(hh, hw), Vector2(hh, -hw), Vector2(-hh, -hw), Vector2(-hh, hw)]
	for c: Vector2 in corners:
		# A chord's ends follow the cut: further over on one side of the truss than the other.
		var x0 := -length * 0.5 + c.y * ts
		var x1 := length * 0.5 - c.y * te
		k.box(Vector3(x1 - x0, member, member), Vector3((x0 + x1) * 0.5, c.x, c.y))
	k.color = DETAIL
	var inner0 := -length * 0.5 + absf(hw * ts) + member
	var inner1 := length * 0.5 - absf(hw * te) - member
	var span := maxf(inner1 - inner0, 0.1)
	for i in bays:
		var x0 := inner0 + span * float(i) / float(bays)
		var x1 := x0 + span / float(bays)
		var flip := i % 2 == 0
		for f in 4:
			var a: Vector2 = corners[f]
			var b: Vector2 = corners[(f + 1) % 4]
			var p0 := Vector3(x0, a.x, a.y)
			var p1 := Vector3(x1, b.x, b.y)
			if flip:
				p0 = Vector3(x0, b.x, b.y)
				p1 = Vector3(x1, a.x, a.y)
			k.strut(p0, p1, member * 0.7)
	var shape := PartShape.new()
	shape.mesh = k.finish()
	shape.volume = k.volume()
	if cut_start == 0.0 and cut_end == 0.0:
		var col := BoxShape3D.new()
		col.size = Vector3(length, height, width)
		shape.collision = col
	else:
		var hull := ConvexPolygonShape3D.new()
		var pts := PackedVector3Array()
		for z: float in [-width * 0.5, width * 0.5]:
			for y: float in [-height * 0.5, height * 0.5]:
				pts.append(Vector3(-length * 0.5 + z * ts, y, z))
				pts.append(Vector3(length * 0.5 - z * te, y, z))
		hull.points = pts
		shape.collision = hull
	return stamp(shape, "truss", [length, width, height, bays, member, cut_start, cut_end])


# --- Curves ---------------------------------------------------------------------------

## A slice of a tube wall: centred on `radius` (to the middle of the wall), `thickness`
## thick, spanning `arc` degrees round the Z axis, `depth` long along Z. The middle of the
## arc points along +Y. Tile them (rotate by `arc` each) to build round hulls; four 90
## degree pieces make a tube, two 45 degree pieces make a rounded corner. Arcs above 45
## degrees are split into steps for a smooth curve; collision hugs it as one convex piece,
## so keep each piece at 45 degrees or less for a tight fit.
static func arc_panel(radius: float, thickness: float, arc: float, depth: float, steps: int = 0) -> PartShape:
	if steps <= 0:
		steps = maxi(int(ceil(arc / 7.5)), 2)
	var r0 := radius - thickness * 0.5
	var r1 := radius + thickness * 0.5
	var k := MeshKit.new()
	var a0 := deg_to_rad(90.0 - arc * 0.5)
	var step := deg_to_rad(arc) / float(steps)
	var z0 := -depth * 0.5
	var z1 := depth * 0.5
	for i in steps:
		var a := a0 + step * float(i)
		var b := a + step
		var ia := Vector3(cos(a) * r0, sin(a) * r0, 0)
		var ib := Vector3(cos(b) * r0, sin(b) * r0, 0)
		var oa := Vector3(cos(a) * r1, sin(a) * r1, 0)
		var ob := Vector3(cos(b) * r1, sin(b) * r1, 0)
		var mid := Vector3(cos((a + b) * 0.5), sin((a + b) * 0.5), 0)
		var dz := Vector3(0, 0, 1)
		k.quad(oa + dz * z0, ob + dz * z0, ob + dz * z1, oa + dz * z1, mid)     # outer skin
		k.quad(ia + dz * z0, ib + dz * z0, ib + dz * z1, ia + dz * z1, -mid)    # inner skin
		k.quad(ia + dz * z1, ib + dz * z1, ob + dz * z1, oa + dz * z1, Vector3.BACK)
		k.quad(ia + dz * z0, ib + dz * z0, ob + dz * z0, oa + dz * z0, Vector3.FORWARD)
	for end in 2:
		var ang := a0 if end == 0 else a0 + deg_to_rad(arc)
		var radial := Vector3(cos(ang), sin(ang), 0)
		var tangent := Vector3(-sin(ang), cos(ang), 0) * (-1.0 if end == 0 else 1.0)
		k.quad(radial * r0 + Vector3(0, 0, z0), radial * r1 + Vector3(0, 0, z0),
				radial * r1 + Vector3(0, 0, z1), radial * r0 + Vector3(0, 0, z1), tangent)
	# Centre the piece on its own bounding box, so it sits where you place it.
	var shape := PartShape.new()
	var mesh := k.finish()
	var centre := mesh.get_aabb().get_center()
	var moved := MeshKit.new()
	for i in k.verts.size():
		moved.verts.append(k.verts[i] - centre)
	moved.normals = k.normals
	moved.colors = k.colors
	shape.mesh = moved.finish()
	shape.volume = deg_to_rad(arc) * radius * thickness * depth
	var col := ConvexPolygonShape3D.new()
	col.points = _unique(moved.verts)
	shape.collision = col
	return stamp(shape, "arc_panel", [radius, thickness, arc, depth, steps])


## Where arc_panel(radius, ...) puts its centre, relative to the tube's axis (add this to the
## axis position to place a piece). The piece's middle points along +Y before rotation.
static func arc_offset(radius: float, thickness: float, arc: float) -> Vector3:
	var r0 := radius - thickness * 0.5
	var r1 := radius + thickness * 0.5
	var half := deg_to_rad(arc * 0.5)
	var lowest := r0 * cos(half)
	return Vector3(0, (lowest + r1) * 0.5, 0)


## A rounded cap (part of a sphere), `radius`, rising `height` from a flat base on -Y.
static func dome(radius: float, height: float, sides: int = 20, rings: int = 5) -> PartShape:
	var sphere_r := (radius * radius + height * height) / (2.0 * height)
	var base_y := -height * 0.5
	var centre_y := base_y + height - sphere_r
	var all := PackedVector3Array()
	var ring_pts: Array[PackedVector3Array] = []
	for r in rings:
		var y := base_y + height * float(r) / float(rings)
		var ring_r := sqrt(maxf(sphere_r * sphere_r - pow(y - centre_y, 2.0), 0.0))
		var ring := PackedVector3Array()
		for i in sides:
			var a := TAU * float(i) / float(sides)
			ring.append(Vector3(cos(a) * ring_r, y, sin(a) * ring_r))
		ring_pts.append(ring)
		all.append_array(ring)
	var top := Vector3(0, base_y + height, 0)
	all.append(top)
	var k := MeshKit.new()
	var sphere_c := Vector3(0, centre_y, 0)
	for r in rings - 1:
		var a: PackedVector3Array = ring_pts[r]
		var b: PackedVector3Array = ring_pts[r + 1]
		for i in sides:
			var j := (i + 1) % sides
			k.quad(a[i], a[j], b[j], b[i], (a[i] + b[j]) * 0.5 - sphere_c)
	var last: PackedVector3Array = ring_pts[rings - 1]
	for i in sides:
		var j := (i + 1) % sides
		k.tri(last[i], last[j], top, (last[i] + last[j] + top) / 3.0 - sphere_c)
	k.poly(ring_pts[0], Vector3.DOWN)
	var shape := PartShape.new()
	shape.mesh = k.finish()
	shape.volume = k.volume()
	var col := ConvexPolygonShape3D.new()
	col.points = all
	shape.collision = col
	return stamp(shape, "dome", [radius, height, sides, rings])


# --- Hull details (0.10 additions) ------------------------------------------------------

## A box with its edges bevelled by `chamfer` all round: chunky hull plates and blocks that
## catch the light on every edge.
static func chamfer_box(size: Vector3, chamfer: float) -> PartShape:
	var h := size * 0.5
	var c := minf(chamfer, minf(h.x, minf(h.y, h.z)) * 0.9)
	var pts := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				pts.append(Vector3(sx * (h.x - c), sy * h.y, sz * (h.z - c)))
				pts.append(Vector3(sx * h.x, sy * (h.y - c), sz * (h.z - c)))
				pts.append(Vector3(sx * (h.x - c), sy * (h.y - c), sz * h.z))
	var shape := _hull(pts)
	var col := BoxShape3D.new()
	col.size = size
	shape.collision = col
	return stamp(shape, "chamfer_box", [size, chamfer])


## A flat ring round the Y axis (`inner` to `outer` radius, `depth` tall): duct rims, port
## surrounds, engine collars.
static func ring(inner: float, outer: float, depth: float, segments: int = 32) -> PartShape:
	var k := MeshKit.new()
	k.lathe(PackedVector2Array([Vector2(inner, -depth * 0.5), Vector2(outer, -depth * 0.5),
			Vector2(outer, depth * 0.5), Vector2(inner, depth * 0.5)]), segments)
	var shape := PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * (outer * outer - inner * inner) * depth
	shape.collision = _cylinder_y(outer, depth)
	return stamp(shape, "ring", [inner, outer, depth, segments])


## A rocket nozzle along Y: a collar at the throat (-Y) flaring to a bell with a rolled lip at
## the exit (+Y), with real wall thickness so you can see into it.
static func nozzle(throat: float, exit: float, length: float, wall: float = 0.06) -> PartShape:
	var k := MeshKit.new()
	var steps := 6
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var r := lerpf(throat, exit, pow(t, 1.6))
		var y := -length * 0.5 + length * t
		outer.append(Vector2(r + wall, y))
		inner.append(Vector2(r, y))
	var profile := PackedVector2Array()
	profile.append_array(outer)
	profile.append(Vector2(exit + wall * 2.0, length * 0.5))     # lip
	inner.reverse()
	profile.append_array(inner)
	k.lathe(profile, 28)
	k.color = DETAIL
	k.lathe(PackedVector2Array([Vector2(throat * 0.6, -length * 0.5 - wall * 3.0), Vector2(throat + wall * 2.5, -length * 0.5 - wall * 3.0),
			Vector2(throat + wall * 2.5, -length * 0.5 + wall), Vector2(throat * 0.6, -length * 0.5 + wall)]), 20)
	var shape := PartShape.new()
	shape.mesh = k.finish()
	shape.volume = k.volume()
	var col := ConvexPolygonShape3D.new()
	var cp := PackedVector3Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		cp.append(Vector3(cos(a) * (throat + wall * 2.5), -length * 0.5 - wall * 3.0, sin(a) * (throat + wall * 2.5)))
		cp.append(Vector3(cos(a) * (exit + wall * 2.0), length * 0.5, sin(a) * (exit + wall * 2.0)))
	col.points = cp
	shape.collision = col
	return stamp(shape, "nozzle", [throat, exit, length, wall])


## A louvred vent: a frame with `slats` angled blades across it (X wide, Z tall, Y deep;
## the open face is +Y).
static func louvre(width: float, height: float, depth: float = 0.12, slats: int = 6) -> PartShape:
	var k := MeshKit.new()
	var f := minf(width, height) * 0.08
	# Frame: four bars.
	k.box(Vector3(width, depth, f), Vector3(0, 0, height * 0.5 - f * 0.5))
	k.box(Vector3(width, depth, f), Vector3(0, 0, -height * 0.5 + f * 0.5))
	k.box(Vector3(f, depth, height - f * 2.0), Vector3(width * 0.5 - f * 0.5, 0, 0))
	k.box(Vector3(f, depth, height - f * 2.0), Vector3(-width * 0.5 + f * 0.5, 0, 0))
	# Back plate, dark, set in.
	k.color = GASKET
	k.box(Vector3(width - f * 2.0, depth * 0.2, height - f * 2.0), Vector3(0, -depth * 0.4, 0))
	k.color = Color.WHITE
	var inner := height - f * 2.0
	var pitch := inner / float(slats)
	for i in slats:
		var z := -inner * 0.5 + pitch * (float(i) + 0.5)
		var a := Vector3(-width * 0.5 + f, depth * 0.35, z + pitch * 0.35)
		var b := Vector3(width * 0.5 - f, depth * 0.35, z + pitch * 0.35)
		var t := Vector3(0, -depth * 0.55, -pitch * 0.55)
		var th := Vector3(0, pitch * 0.12, 0)
		k.loft(PackedVector3Array([a, a + th, a + t + th, a + t]), PackedVector3Array([b, b + th, b + t + th, b + t]))
	var shape := PartShape.new()
	shape.mesh = k.finish()
	shape.volume = k.volume()
	var col := BoxShape3D.new()
	col.size = Vector3(width, depth, height)
	shape.collision = col
	return stamp(shape, "louvre", [width, height, depth, slats])


## A plate with a raised border round a recessed middle (X wide, Z long, Y thick; face +Y):
## hull panelling, access covers.
static func inset_panel(width: float, length: float, thickness: float = 0.1, border: float = 0.12) -> PartShape:
	var k := MeshKit.new()
	var b := minf(border, minf(width, length) * 0.3)
	k.box(Vector3(width, thickness * 0.6, length), Vector3(0, -thickness * 0.2, 0))
	k.box(Vector3(width, thickness * 0.4, b), Vector3(0, thickness * 0.3, length * 0.5 - b * 0.5))
	k.box(Vector3(width, thickness * 0.4, b), Vector3(0, thickness * 0.3, -length * 0.5 + b * 0.5))
	k.box(Vector3(b, thickness * 0.4, length - b * 2.0), Vector3(width * 0.5 - b * 0.5, thickness * 0.3, 0))
	k.box(Vector3(b, thickness * 0.4, length - b * 2.0), Vector3(-width * 0.5 + b * 0.5, thickness * 0.3, 0))
	var shape := PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * length * thickness * 0.8
	var col := BoxShape3D.new()
	col.size = Vector3(width, thickness, length)
	shape.collision = col
	return stamp(shape, "inset_panel", [width, length, thickness, border])


# --- Windows --------------------------------------------------------------------------
# Each window is set into a hull: its outside face is +Y, its back -Y, `thickness` deep.
# The frame and glass are separate meshes; collision covers the whole window.

## A round porthole: a raised, stepped ring with bolts round it and recessed glass.
static func porthole_round(radius: float, thickness: float = 0.08, bolts: int = 8) -> PartShape:
	var rim := radius * 0.28
	var k := MeshKit.new()
	# Profile (x = radius out from the centre, y = height): flange, raised lip, inner step.
	var r0 := radius
	var r1 := radius + rim
	var t := thickness
	k.lathe(PackedVector2Array([Vector2(r0, -t * 0.5), Vector2(r1, -t * 0.5), Vector2(r1, t * 0.15),
			Vector2(r0 + rim * 0.55, t * 0.5), Vector2(r0, t * 0.5)]), 28)
	k.color = GASKET
	k.lathe(PackedVector2Array([Vector2(r0 - 0.012, -t * 0.1), Vector2(r0 + 0.001, -t * 0.1),
			Vector2(r0 + 0.001, t * 0.25), Vector2(r0 - 0.012, t * 0.25)]), 28)
	var shape := PartShape.new()
	_add_bolts(k, shape, bolts, r0 + rim * 0.6, t * 0.5, radius * 0.07)
	shape.mesh = k.finish()
	shape.glass = _glass_disc(r0 - 0.005, 0.0, 28, t * 0.4)
	shape.volume = k.volume() + PI * r0 * r0 * t * 0.4
	shape.collision = _cylinder_y(r1, t)
	return stamp(shape, "porthole_round", [radius, thickness, bolts])


## A hexagonal porthole: a flat flange with a bevelled inner frame.
static func porthole_hex(radius: float, thickness: float = 0.08) -> PartShape:
	var k := MeshKit.new()
	var t := thickness
	var flange := radius * 0.3
	# Six frame segments, each a bevelled trapezoid block.
	for i in 6:
		var a := TAU * float(i) / 6.0
		var b := TAU * float(i + 1) / 6.0
		var in_a := Vector3(cos(a) * radius, 0, sin(a) * radius)
		var in_b := Vector3(cos(b) * radius, 0, sin(b) * radius)
		var out_a := in_a * (1.0 + flange / radius)
		var out_b := in_b * (1.0 + flange / radius)
		var lo := Vector3(0, -t * 0.5, 0)
		var hi := Vector3(0, t * 0.5, 0)
		var bevel := 0.75
		k.loft(PackedVector3Array([in_a + lo, out_a + lo, out_b + lo, in_b + lo]),
				PackedVector3Array([in_a.lerp(out_a, 0.25) + hi, out_a.lerp(in_a, 1.0 - bevel) + hi,
						out_b.lerp(in_b, 1.0 - bevel) + hi, in_b.lerp(out_b, 0.25) + hi]))
	var shape := PartShape.new()
	k.color = DETAIL
	for i in 6:
		var a := TAU * (float(i) + 0.5) / 6.0
		var p := Vector3(cos(a), 0, sin(a)) * (radius + flange * 0.45)
		_bolt(k, p + Vector3(0, t * 0.45, 0), radius * 0.06)
		shape.fastener_points.append(p + Vector3(0, t * 0.5, 0))
		shape.fastener_normals.append(Vector3.UP)
	shape.mesh = k.finish()
	shape.glass = _glass_disc(radius, 0.0, 6, t * 0.4)
	shape.volume = k.volume() + 2.6 * radius * radius * t * 0.4
	var col := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for i in 6:
		var a := TAU * float(i) / 6.0
		for y: float in [-t * 0.5, t * 0.5]:
			pts.append(Vector3(cos(a) * (radius + flange), y, sin(a) * (radius + flange)))
	col.points = pts
	shape.collision = col
	return stamp(shape, "porthole_hex", [radius, thickness])


## A rectangular window with chamfered corners, a deep frame, and optional mullions
## (`cross` 0 = none, 1 = one vertical bar, 2 = a cross).
static func window_rect(width: float, height: float, thickness: float = 0.08,
		chamfer: float = 0.08, cross: int = 0) -> PartShape:
	var frame := minf(width, height) * 0.14
	var outer := _chamfer_rect(width + frame * 2.0, height + frame * 2.0, chamfer + frame * 0.6)
	var inner := _chamfer_rect(width, height, chamfer)
	var k := MeshKit.new()
	_frame_between(k, outer, inner, thickness, thickness * 0.35)
	k.color = GASKET
	_frame_between(k, inner, _scaled(inner, 0.97), thickness * 0.3, 0.0)
	k.color = Color.WHITE
	if cross >= 1:
		k.box(Vector3(frame * 0.4, thickness * 0.7, height), Vector3(0, thickness * 0.1, 0))
	if cross >= 2:
		k.box(Vector3(width, thickness * 0.7, frame * 0.4), Vector3(0, thickness * 0.1, 0))
	var shape := PartShape.new()
	k.color = DETAIL
	for p: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var at := Vector3(p.x * (width * 0.5 + frame * 0.5), thickness * 0.5, p.y * (height * 0.5 + frame * 0.5))
		_bolt(k, at, frame * 0.22)
		shape.fastener_points.append(at)
		shape.fastener_normals.append(Vector3.UP)
	shape.mesh = k.finish()
	shape.glass = _glass_poly(_scaled(inner, 0.97), 0.0, thickness * 0.3)
	shape.volume = k.volume() + width * height * thickness * 0.3
	shape.collision = _slab(outer, thickness)
	return stamp(shape, "window_rect", [width, height, thickness, chamfer, cross])


## A window that fills a rectangular hole exactly: a square-edged frame plate `width` (X)
## by `height` (Z), with an opening of `inner` shape ("round", "hex", "chamfer" for a
## rounded rectangle, "stadium" for a long slot) and `opening` of the plate's size (0..1).
## The frame bevels down toward the glass, with a gasket and four corner bolts. Cut the
## same rectangle in the wall and nothing shows round the edges.
static func window_panel(width: float, height: float, inner: String = "round",
		thickness: float = 0.16, opening: float = 0.78) -> PartShape:
	var iw := width * opening
	var ih := height * opening
	var margin := minf(width - iw, height - ih) * 0.5
	var hole: PackedVector2Array
	match inner:
		"hex":
			hole = PackedVector2Array()
			var r := minf(iw, ih) * 0.5
			for i in 6:
				var a := TAU * float(i) / 6.0
				hole.append(Vector2(cos(a), sin(a)) * r)
		"chamfer":
			hole = _chamfer_rect(iw, ih, minf(iw, ih) * 0.18)
		"stadium":
			if iw >= ih:
				hole = _stadium(iw, ih, 10)
			else:
				hole = PackedVector2Array()
				for p in _stadium(ih, iw, 10):
					hole.append(Vector2(p.y, p.x))
		_:
			hole = PackedVector2Array()
			var r := minf(iw, ih) * 0.5
			for i in 32:
				var a := TAU * float(i) / 32.0
				hole.append(Vector2(cos(a), sin(a)) * r)
	var rings := _ray_rings(Vector2(width, height), hole)
	var outer: PackedVector2Array = rings[0]
	var rim: PackedVector2Array = rings[1]
	var k := MeshKit.new()
	_frame_between(k, outer, rim, thickness, thickness * 0.3)
	# A raised lip round the opening, then a dark gasket holding the glass.
	k.color = DETAIL
	_frame_between(k, _scaled(rim, 1.0), _scaled(rim, 0.985), thickness * 1.15, 0.0)
	k.color = GASKET
	_frame_between(k, _scaled(rim, 0.985), _scaled(rim, 0.94), thickness * 0.45, 0.0)
	var shape := PartShape.new()
	k.color = DETAIL
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var at := Vector3(c.x * (width * 0.5 - margin * 0.5), thickness * 0.5, c.y * (height * 0.5 - margin * 0.5))
		_bolt(k, at, minf(margin * 0.18, 0.03))
		shape.fastener_points.append(at)
		shape.fastener_normals.append(Vector3.UP)
	shape.mesh = k.finish()
	shape.glass = _glass_poly(_scaled(rim, 0.95), 0.0, thickness * 0.25)
	shape.volume = k.volume() + iw * ih * thickness * 0.25
	var col := BoxShape3D.new()
	col.size = Vector3(width, thickness, height)
	shape.collision = col
	return stamp(shape, "window_panel", [width, height, inner, thickness, opening])


## Rays from the centre through every corner of `hole` (convex, centred) and of a
## `size` rectangle: where each ray meets the rectangle (ring 0) and the hole (ring 1).
## Same point count in both, so a frame can be lofted between them.
static func _ray_rings(size: Vector2, hole: PackedVector2Array) -> Array:
	var angles: Array[float] = []
	for p in hole:
		angles.append(atan2(p.y, p.x))
	for c: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		angles.append(atan2(c.y * size.y, c.x * size.x))
	angles.sort()
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var last := -INF
	for a in angles:
		if a - last < 0.0005:
			continue
		last = a
		var d := Vector2(cos(a), sin(a))
		# The rectangle: the nearer of the two edge crossings.
		var tx := (size.x * 0.5) / absf(d.x) if absf(d.x) > 1e-6 else INF
		var ty := (size.y * 0.5) / absf(d.y) if absf(d.y) > 1e-6 else INF
		outer.append(d * minf(tx, ty))
		inner.append(d * _ray_polygon(d, hole))
	return [outer, inner]


## Distance along direction `d` from the origin to the edge of a convex polygon round it.
static func _ray_polygon(d: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var e := b - a
		var den := d.x * e.y - d.y * e.x
		if absf(den) < 1e-9:
			continue
		var t := (a.x * e.y - a.y * e.x) / den
		var u := (a.x * d.y - a.y * d.x) / den
		if t > 0.0 and u >= -1e-6 and u <= 1.0 + 1e-6:
			best = minf(best, t)
	return best if best < INF else 0.0


## A long slit window with rounded ends and a shroud ("eyebrow") over the top edge.
static func window_slit(length: float, height: float, thickness: float = 0.08) -> PartShape:
	var frame := height * 0.35
	var inner := _stadium(length, height, 10)
	var outer := _stadium(length + frame * 2.0, height + frame * 2.0, 10)
	var k := MeshKit.new()
	_frame_between(k, outer, inner, thickness, thickness * 0.3)
	k.color = ACCENT
	# The eyebrow: a sloped visor over the top edge, standing off the hull.
	var brow_w := length + frame * 1.6
	var z := height * 0.5 + frame * 0.7
	k.loft(PackedVector3Array([Vector3(-brow_w * 0.5, thickness * 0.5, z - frame * 0.35),
			Vector3(brow_w * 0.5, thickness * 0.5, z - frame * 0.35),
			Vector3(brow_w * 0.5, thickness * 0.5, z + frame * 0.35),
			Vector3(-brow_w * 0.5, thickness * 0.5, z + frame * 0.35)]),
			PackedVector3Array([Vector3(-brow_w * 0.5, thickness * 0.5 + frame * 0.9, z - frame * 0.95),
			Vector3(brow_w * 0.5, thickness * 0.5 + frame * 0.9, z - frame * 0.95),
			Vector3(brow_w * 0.5, thickness * 0.5 + frame * 0.9, z - frame * 0.55),
			Vector3(-brow_w * 0.5, thickness * 0.5 + frame * 0.9, z - frame * 0.55)]))
	var shape := PartShape.new()
	shape.mesh = k.finish()
	shape.glass = _glass_poly(inner, 0.0, thickness * 0.3)
	shape.volume = k.volume() + length * height * thickness * 0.3
	shape.collision = _slab(outer, thickness)
	for x: float in [-length * 0.5, length * 0.5]:
		shape.fastener_points.append(Vector3(x, thickness * 0.5, -height * 0.5 - frame * 0.5))
		shape.fastener_normals.append(Vector3.UP)
	return stamp(shape, "window_slit", [length, height, thickness])


## A triangular window (for wedge noses and slanted panels), point toward +Z.
static func window_tri(size: float, thickness: float = 0.08) -> PartShape:
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	var frame := size * 0.12
	for i in 3:
		var a := PI * 0.5 + TAU * float(i) / 3.0
		inner.append(Vector2(cos(a), sin(a)) * size * 0.5)
		outer.append(Vector2(cos(a), sin(a)) * (size * 0.5 + frame * 2.0))
	var k := MeshKit.new()
	_frame_between(k, outer, inner, thickness, thickness * 0.3)
	var shape := PartShape.new()
	k.color = DETAIL
	for p in outer:
		var at := Vector3(p.x, thickness * 0.5, p.y) * Vector3(0.78, 1.0, 0.78)
		_bolt(k, at, frame * 0.25)
		shape.fastener_points.append(at)
		shape.fastener_normals.append(Vector3.UP)
	shape.mesh = k.finish()
	shape.glass = _glass_poly(inner, 0.0, thickness * 0.3)
	shape.volume = k.volume() + 0.43 * size * size * thickness * 0.3
	shape.collision = _slab(outer, thickness)
	return stamp(shape, "window_tri", [size, thickness])


## A curved canopy panel: glass on a slice of a tube, with ribs at each end and one in the
## middle. Same placement as arc_panel; tile several for a wrap-around cockpit.
static func canopy_panel(radius: float, arc: float, depth: float, thickness: float = 0.06) -> PartShape:
	var glass_part := arc_panel(radius, thickness * 0.5, arc, depth)
	var ribs := MeshKit.new()
	var centre := arc_offset(radius, thickness * 0.5, arc)
	var steps := maxi(int(ceil(arc / 7.5)), 2)
	for rz: float in [-depth * 0.5 + thickness * 0.5, 0.0, depth * 0.5 - thickness * 0.5]:
		var a0 := deg_to_rad(90.0 - arc * 0.5)
		for i in steps:
			var a := a0 + deg_to_rad(arc) * float(i) / float(steps)
			var b := a0 + deg_to_rad(arc) * float(i + 1) / float(steps)
			var pa := Vector3(cos(a), sin(a), 0) * (radius + thickness * 0.4) - centre + Vector3(0, 0, rz)
			var pb := Vector3(cos(b), sin(b), 0) * (radius + thickness * 0.4) - centre + Vector3(0, 0, rz)
			ribs.strut(pa, pb, thickness * 1.2)
	var shape := PartShape.new()
	shape.mesh = ribs.finish()
	shape.glass = glass_part.mesh
	shape.volume = ribs.volume() + glass_part.volume
	shape.collision = glass_part.collision
	return stamp(shape, "canopy_panel", [radius, arc, depth, thickness])


# --- Helpers --------------------------------------------------------------------------

static func _convex(k: MeshKit) -> PartShape:
	var shape := PartShape.new()
	shape.mesh = k.finish()
	shape.volume = k.volume()
	var col := ConvexPolygonShape3D.new()
	col.points = _unique(k.verts)
	shape.collision = col
	return shape


## A convex solid wrapped round `points` (its faces worked out from the points).
static func _hull(points: PackedVector3Array) -> PartShape:
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	var k := MeshKit.new()
	var centre := Vector3.ZERO
	for p in points:
		centre += p
	centre /= float(points.size())
	# Rebuild the hull's faces from Geometry: triangulate via the convex hull helper.
	var tris := _hull_triangles(points)
	for t: Array in tris:
		var mid: Vector3 = (t[0] + t[1] + t[2]) / 3.0
		k.tri(t[0], t[1], t[2], mid - centre)
	var shape := PartShape.new()
	shape.mesh = k.finish()
	shape.volume = k.volume()
	shape.collision = hull
	return shape


## Triangles of the convex hull of `points` (simple gift-wrap; fine for the small point
## sets parts use).
static func _hull_triangles(points: PackedVector3Array) -> Array:
	var out: Array = []
	var n := points.size()
	var seen: Dictionary = {}
	for i in n:
		for j in range(i + 1, n):
			for l in range(j + 1, n):
				var a := points[i]
				var b := points[j]
				var c := points[l]
				var normal := (b - a).cross(c - a)
				if normal.length_squared() < 1e-12:
					continue
				normal = normal.normalized()
				var front := 0
				var back := 0
				for m in n:
					var d := normal.dot(points[m] - a)
					if d > 1e-5:
						front += 1
					elif d < -1e-5:
						back += 1
				if front > 0 and back > 0:
					continue
				# A face of the hull. Merge coplanar triangles by keying on the plane: keep
				# all of them (overlaps are harmless for shading), but skip exact repeats.
				var key := "%d_%d_%d" % [i, j, l]
				if seen.has(key):
					continue
				seen[key] = true
				out.append([a, b, c])
	return _dedupe_coplanar(out, points)


## Coplanar hull faces with 4+ points come out as overlapping triangles; keep a clean fan
## per plane so faces don't z-fight.
static func _dedupe_coplanar(tris: Array, points: PackedVector3Array) -> Array:
	var planes: Dictionary = {}
	for t: Array in tris:
		var n: Vector3 = ((t[1] as Vector3) - t[0]).cross((t[2] as Vector3) - t[0]).normalized()
		var centre := Vector3.ZERO
		for p in points:
			centre += p
		centre /= float(points.size())
		if n.dot((t[0] as Vector3) - centre) < 0.0:
			n = -n
		var dist := n.dot(t[0])
		var key := "%.3f_%.3f_%.3f_%.3f" % [n.x, n.y, n.z, dist]
		if not planes.has(key):
			planes[key] = [n, []]
		for p: Vector3 in t:
			var list: Array = planes[key][1]
			var dup := false
			for q: Vector3 in list:
				if q.distance_squared_to(p) < 1e-10:
					dup = true
			if not dup:
				list.append(p)
	var out: Array = []
	for key: String in planes:
		var n: Vector3 = planes[key][0]
		var face: Array = planes[key][1]
		var c := Vector3.ZERO
		for p: Vector3 in face:
			c += p
		c /= float(face.size())
		var first: Vector3 = face[0]
		var u := (first - c).normalized()
		var v := n.cross(u)
		face.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return atan2((a - c).dot(v), (a - c).dot(u)) < atan2((b - c).dot(v), (b - c).dot(u)))
		for i in range(1, face.size() - 1):
			out.append([face[0], face[i], face[i + 1]])
	return out


static func _extruded_x(outline_zy: PackedVector2Array, width: float) -> PartShape:
	# Outline is given as (z, y); build it in XY then turn so the extrusion runs along X.
	var k := MeshKit.new()
	var outline := PackedVector2Array()
	for p in outline_zy:
		outline.append(Vector2(-p.x, p.y))
	k.extrude(outline, width)
	var turned := MeshKit.new()
	var turn := Basis(Vector3.UP, PI * 0.5)
	for i in k.verts.size():
		turned.verts.append(turn * k.verts[i])
		turned.normals.append(turn * k.normals[i])
		turned.colors.append(k.colors[i])
	return _convex(turned)


static func _unique(points: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in points:
		var dup := false
		for q in out:
			if q.distance_squared_to(p) < 1e-10:
				dup = true
				break
		if not dup:
			out.append(p)
	return out


static func _bolt(k: MeshKit, at: Vector3, radius: float) -> void:
	var old := k.color
	k.color = DETAIL
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	for i in 6:
		var ang := TAU * float(i) / 6.0
		a.append(at + Vector3(cos(ang) * radius, -radius * 0.2, sin(ang) * radius))
		b.append(at + Vector3(cos(ang) * radius, radius * 0.5, sin(ang) * radius))
	k.loft(a, b)
	k.color = old


static func _add_bolts(k: MeshKit, shape: PartShape, count: int, radius: float, y: float, size: float) -> void:
	for i in count:
		var ang := TAU * (float(i) + 0.5) / float(count)
		var at := Vector3(cos(ang) * radius, y, sin(ang) * radius)
		_bolt(k, at, size)
		shape.fastener_points.append(at)
		shape.fastener_normals.append(Vector3.UP)


## A flat solid ring between two outlines (outer and inner, same corner count), raised by
## `rise` on its outer edge relative to the inner, `thickness` deep.
static func _frame_between(k: MeshKit, outer: PackedVector2Array, inner: PackedVector2Array,
		thickness: float, rise: float) -> void:
	var n := outer.size()
	var lo := -thickness * 0.5
	var hi := thickness * 0.5
	for i in n:
		var j := (i + 1) % n
		var oa := outer[i]
		var ob := outer[j]
		var ia := inner[i]
		var ib := inner[j]
		k.loft(PackedVector3Array([Vector3(ia.x, lo, ia.y), Vector3(oa.x, lo, oa.y), Vector3(ob.x, lo, ob.y), Vector3(ib.x, lo, ib.y)]),
				PackedVector3Array([Vector3(ia.x, hi - rise, ia.y), Vector3(oa.x, hi, oa.y), Vector3(ob.x, hi, ob.y), Vector3(ib.x, hi - rise, ib.y)]))


static func _glass_disc(radius: float, y: float, sides: int, thickness: float) -> ArrayMesh:
	var ring := PackedVector2Array()
	for i in sides:
		var a := TAU * float(i) / float(sides)
		ring.append(Vector2(cos(a), sin(a)) * radius)
	return _glass_poly(ring, y, thickness)


static func _glass_poly(outline: PackedVector2Array, y: float, thickness: float) -> ArrayMesh:
	var k := MeshKit.new()
	k.extrude(outline, thickness)
	# extrude builds in XY along Z; turn so the pane lies in XZ facing +Y.
	var turned := MeshKit.new()
	var turn := Basis(Vector3.RIGHT, -PI * 0.5)
	for i in k.verts.size():
		turned.verts.append(turn * k.verts[i] + Vector3(0, y, 0))
		turned.normals.append(turn * k.normals[i])
		turned.colors.append(Color.WHITE)
	return turned.finish()


static func _chamfer_rect(w: float, h: float, c: float) -> PackedVector2Array:
	var x := w * 0.5
	var y := h * 0.5
	c = minf(c, minf(x, y) * 0.9)
	return PackedVector2Array([Vector2(-x + c, -y), Vector2(x - c, -y), Vector2(x, -y + c), Vector2(x, y - c),
			Vector2(x - c, y), Vector2(-x + c, y), Vector2(-x, y - c), Vector2(-x, -y + c)])


static func _stadium(length: float, height: float, arc_steps: int) -> PackedVector2Array:
	var r := height * 0.5
	var half := maxf(length * 0.5 - r, 0.0)
	var out := PackedVector2Array()
	for i in arc_steps + 1:
		var a := -PI * 0.5 + PI * float(i) / float(arc_steps)
		out.append(Vector2(half + cos(a) * r, sin(a) * r))
	for i in arc_steps + 1:
		var a := PI * 0.5 + PI * float(i) / float(arc_steps)
		out.append(Vector2(-half + cos(a) * r, sin(a) * r))
	return out


static func _scaled(outline: PackedVector2Array, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in outline:
		out.append(p * s)
	return out


static func _slab(outline: PackedVector2Array, thickness: float) -> ConvexPolygonShape3D:
	var pts := PackedVector3Array()
	for p in outline:
		pts.append(Vector3(p.x, -thickness * 0.5, p.y))
		pts.append(Vector3(p.x, thickness * 0.5, p.y))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	return col


static func _cylinder_y(radius: float, height: float) -> CylinderShape3D:
	var col := CylinderShape3D.new()
	col.radius = radius
	col.height = height
	return col


# --- Catalogue ------------------------------------------------------------------------

## Every shape family in a few sizes: [name, PartShape]. Used by the gallery and the tests.
static func catalogue() -> Array:
	return [
		["box 1x1x1", box(Vector3.ONE)],
		["chamfer box 2x1x1", chamfer_box(Vector3(2, 1, 1), 0.15)],
		["chamfer slab 3x0.4x2", chamfer_box(Vector3(3, 0.4, 2), 0.12)],
		["ring 0.6-0.8", ring(0.6, 0.8, 0.3)],
		["ring wide 1.0-1.4", ring(1.0, 1.4, 0.2)],
		["nozzle small", nozzle(0.3, 0.6, 0.9)],
		["nozzle big", nozzle(0.8, 1.5, 2.0, 0.08)],
		["louvre 1x0.6", louvre(1.0, 0.6)],
		["louvre tall 0.6x1.6", louvre(0.6, 1.6, 0.12, 10)],
		["inset panel 2x3", inset_panel(2.0, 3.0)],
		["window panel round", window_panel(0.8, 0.8, "round")],
		["window panel hex", window_panel(0.8, 0.8, "hex")],
		["window panel wide", window_panel(1.0, 2.0, "chamfer", 0.16, 0.86)],
		["window panel slot", window_panel(0.5, 1.8, "stadium", 0.16, 0.7)],
		["window panel big", window_panel(1.2, 2.6, "chamfer", 0.16, 0.9)],
		["box 2x0.5x1", box(Vector3(2, 0.5, 1))],
		["wedge 1", wedge(Vector3.ONE)],
		["wedge 2x1x2", wedge(Vector3(2, 1, 2))],
		["wedge long 1x0.5x2", wedge(Vector3(1, 0.5, 2))],
		["ridge 1", ridge(Vector3.ONE)],
		["ridge wide 2x0.6x1.5", ridge(Vector3(2, 0.6, 1.5))],
		["slope 1", slope(Vector3.ONE)],
		["slope shallow 2x0.6x2", slope(Vector3(2, 0.6, 2), 0.6)],
		["trapezoid 1.5/1", trapezoid(1.5, 1.0, 1.0, 1.0)],
		["trapezoid 2/0.6", trapezoid(2.0, 0.6, 0.8, 1.2)],
		["corner 1", corner(Vector3.ONE)],
		["corner 2x1x1", corner(Vector3(2, 1, 1))],
		["corner cut 1", corner_cut(Vector3.ONE)],
		["prism 3-sided", prism(3, 0.4, 1.5)],
		["prism 6-sided", prism(6, 0.4, 1.5)],
		["prism 8-sided", prism(8, 0.5, 1.0)],
		["cone", frustum(0.5, 0.0, 1.0)],
		["nozzle", frustum(0.3, 0.6, 0.9)],
		["transition", frustum(0.8, 0.5, 0.6, 8)],
		["girder 2m", girder(2.0, 0.25, 0.35)],
		["girder 22.5 cut", girder(2.0, 0.25, 0.35, 0.0, 22.5)],
		["girder 45 both", girder(1.5, 0.25, 0.35, 45.0, 45.0)],
		["i-beam", i_beam(2.0, 0.25, 0.4)],
		["truss 3m", truss(3.0, 0.4, 0.4, 6)],
		["truss 45 both", truss(2.0, 0.4, 0.4, 4, 0.0, 45.0, 45.0)],
		["truss deep", truss(2.0, 0.3, 0.7, 3)],
		["arc 45 r1.5", arc_panel(1.5, 0.08, 45.0, 1.0)],
		["arc 22.5 r3", arc_panel(3.0, 0.08, 22.5, 1.5)],
		["arc 90 r1", arc_panel(1.0, 0.1, 90.0, 1.0)],
		["dome", dome(0.8, 0.5)],
		["dome tall", dome(0.6, 0.6, 16, 6)],
		["porthole round", porthole_round(0.25)],
		["porthole big", porthole_round(0.45, 0.1, 12)],
		["porthole hex", porthole_hex(0.3)],
		["window rect", window_rect(0.8, 0.5)],
		["window cross", window_rect(0.9, 0.9, 0.08, 0.12, 2)],
		["window slit", window_slit(1.4, 0.22)],
		["window tri", window_tri(0.7)],
		["canopy panel", canopy_panel(1.4, 40.0, 1.2)],
	]
