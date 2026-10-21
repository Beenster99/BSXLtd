class_name FrameHull
extends RefCounted
## A frame-first hull built as parts and joints (docs/SHIP_FRAME_PLAN.md 4.2): give it the
## hull's cross-section (its outer surface, points round the outline) at stations along the
## ship and a FrameStyle, and it builds into a FrameTarget (a ShipKit for the crew's ships,
## a wreck's ShipBuilder) the frame, the skin and the caps. How the frame is made is the
## style's `corners`:
##   - "mitre" (the wrecks', SalvageHull): a ring of mitred members at each station, welded
##     at every corner; stringers along each side between stations (one per
##     `stringer_spacing` of side), butt-welded to the rings; skin plates over every face
##     between two stations, riveted to the rings at both ends (plain rectangles are box
##     plates, so they dent and tear; tapered faces are cut to fit), flush to the seam lines
##     on a `flush` skin; glass panes where the style says so; end caps (`caps`); inner
##     panels on the frame (`lining`).
##   - "node" (the Kestrel's): a node block at every profile corner of every station, a ring
##     girder between neighbouring nodes round each station, a stringer along every corner
##     between stations, every member's ends welded to its nodes all round (the style's
##     bead); skin plates cut round the openings and riveted in rows along every member they
##     lie over (at the style's pitch); caps on the outlines a design gives (`cap`). Looks are
##     as HullBuilder draws them (girders node to node, plates corner to corner); the
##     collision shapes are pulled in to keep the gaps, so a part's look and collision differ.
## Parts keep clear gaps (the salvage model needs parts never to overlap).
##
## Profiles are in ship space (x, y), convex, points in order round the outline (either way
## round); every station needs the same number of points; stations go front (-Z) to back
## (+Z). Part names follow the test wreck's, so wreck events work on any design: FrameNode,
## "FrameRing", "Stringer", FrameSplice, "HullPlate", "CapPlate", "WindowPane".

## The gap kept between parts' collision shapes, metres (ShipBuilder.GAP).
const GAP: float = 0.02
## How a rivet row keeps clear of a plate's edge, metres (node styles).
const ROW_MARGIN: float = 0.025
## Rivet heads on a node style's skin: the flush bump (ConnectionData.head 1).
const RIVET_HEAD: int = 1
## Linings deeper than this stand on brackets off the rings, metres.
const BRACKET_FROM: float = 0.15

var target: FrameTarget
var style_id: String
## The FrameStyle entry.
var spec: Dictionary
## Sizes, metres (from the style; a design may change them before `build`, as the wrecks'
## heavier frames and the Kestrel canopy's lighter posts do).
var skin: float                  # plate thickness
var depth: float                 # frame member depth (radial, out of the hull)
var ring_width: float            # frame member width along the ship
var node_size: float             # node block (node styles)
var stringer_size: float         # stringer width (square on the mitred style)
var stringer_depth: float        # stringer depth out of the hull (node styles)
var stringer_spacing: float      # one stringer per this much side length (mitred)
var bead: int                    # weld head style (node styles; the wrecks set their own)
var rivet_pitch: float           # rivets along a row (node styles)
var skin_mat: Material
var frame_mat: Material
var glass_mat: Material
## Stations, front to back: {z: float, profile: PackedVector2Array}.
var stations: Array[Dictionary] = []
## Optional `style(segment, edge) -> {skip, mat, glass, tag, name}` for the face between
## station `segment` and the next, along profile edge `edge` (from point edge to edge + 1).
var style := Callable()
## Optional `frame_skip(station, edge) -> bool`: leave out a ring member (an opening).
var frame_skip := Callable()
## Optional `stringer_skip(segment, edge) -> bool`: leave out the stringers along that face
## (a doorway cut through the side). Mitred.
var stringer_skip := Callable()
## End caps (mitred): `caps[0]` front, `caps[1]` back: true, or a style dictionary {skip,
## mat, glass}. Node styles make theirs with `cap`.
var caps: Array = [true, true]
## A flush skin (v4, docs/V4_PIPELINE.md; mitred): every plate's visual runs out to the seam
## lines (the profile corners, the middle of each ring, the caps' faces) with a
## `flush_bevel` V-groove where neighbours meet, so the hull reads as one skin with panel
## lines; the collision shapes keep their gaps. Linings get the same treatment.
var flush: bool = false
var flush_bevel: float = 0.005
## Inner panels (`lining`, mitred): how far they stand in from the ring members' inner faces
## (room for leads along the faces; 0.3 and more makes a double hull with a cavity for
## services and components behind hatches), how thick they are. Deep linings (over
## `BRACKET_FROM`) stand on brackets off the rings.
var lining_inset: float
var lining_thickness: float
## How much further to hold the plates back from the front and back stations, metres (a
## neighbouring section's plates meet them there). Node styles.
var end_gap: Array[float] = [0.0, 0.0]

## What was built, for designs to fit things to:
##   rings[station][edge]: the ring member along that edge (null where skipped);
##   stringers[segment][...]: mitred, [edge] the first stringer along that face; node
##     styles, [corner] the stringer down that corner;
##   all_stringers[segment][edge]: every stringer along that face, in order along the edge
##     (mitred; WreckDesign.loom hangs a loom under one);
##   plates[segment][edge]: mitred, the plate (or null); node styles, an Array of the
##     pieces of that face (cut round the openings);
##   nodes[station][corner] (node styles);
##   caps_made [front, back] (mitred), cap_plates every plate `cap` made (node styles);
##   welds and rivets: the frame's welds and the skin's rivets (ConnectionData; node styles.
##     The mitred style keeps none: a wreck design keeps its hulls, so they would keep every
##     joint alive with them).
var nodes: Array = []
var rings: Array = []
var stringers: Array = []
var all_stringers: Array = []
var plates: Array = []
var caps_made: Array = [null, null]
var cap_plates: Array[PartData] = []
var welds: Array[ConnectionData] = []
var rivets: Array[ConnectionData] = []
## Inner panels built with `lining`: "segment:edge" -> PartData, and how deep each one
## stands ({"inset", "clipped"}: a y-clipped panel stands inside the room on the deck and
## doesn't shape the room's outline).
var linings: Dictionary = {}
var lining_insets: Dictionary = {}

## Openings cut through the skin (node styles): [edge, AABB (ship space)].
var _openings: Array = []
## Node centres per station (ship space) and each node's collision half size.
var _points: Array = []
var _node_half: Array = []
## Every member that can hold a plate: {part, p0, p1} (the ends of its collision, on its
## centre line).
var _members: Array[Dictionary] = []
## The planes no member may cross (each plate's inner face, the ends): [normal, limit]:
## inside where normal . p <= limit.
var _planes: Array = []


func _init(into: FrameTarget, id: String, skin_material: Material, frame_material: Material,
		glass_material: Material = null) -> void:
	target = into
	style_id = id
	spec = FrameStyle.of(id)
	skin = spec["skin"]
	ring_width = (spec["member"] as Vector2).x
	depth = (spec["member"] as Vector2).y
	node_size = spec["node"]
	stringer_size = (spec["stringer"] as Vector2).x
	stringer_depth = (spec["stringer"] as Vector2).y
	stringer_spacing = spec.get("stringer_spacing", 2.6)
	bead = spec["bead"]
	rivet_pitch = spec["rivet_pitch"]
	lining_inset = spec["lining_inset"]
	lining_thickness = spec["lining_thickness"]
	skin_mat = skin_material
	frame_mat = frame_material
	glass_mat = glass_material


func add_station(z: float, profile: PackedVector2Array) -> void:
	stations.append({"z": z, "profile": profile})


## Cuts a hole through the skin over profile edge `edge` where it meets `box` (ship space):
## the plates of that face are split round it into strips (a doorway, a window, a hatch).
## Node styles.
func opening(edge: int, box: AABB) -> void:
	_openings.append([edge, box])


func build() -> void:
	if spec["corners"] == "mitre":
		_mitre_rings()
		_spaced_stringers()
		_mitre_skin()
		_mitre_caps()
		return
	var was := target.parts_model().head_style
	_place_nodes()
	_collect_planes()
	target.parts_model().head_style = bead
	_build_nodes()
	_node_rings()
	_corner_stringers()
	target.parts_model().head_style = RIVET_HEAD
	_node_skin()
	target.parts_model().head_style = was


# --- Geometry helpers -----------------------------------------------------------------

## The way out of the hull across edge `e` of a profile (2D).
static func edge_out(profile: PackedVector2Array, e: int) -> Vector2:
	var c := Vector2.ZERO
	for p in profile:
		c += p
	c /= float(profile.size())
	var a := profile[e]
	var q := profile[(e + 1) % profile.size()]
	var d := q - a
	var n := Vector2(d.y, -d.x).normalized()
	if n.dot((a + q) * 0.5 - c) < 0.0:
		n = -n
	return n


## The direction of edge `e` of a profile.
static func stations_edge_dir(profile: PackedVector2Array, e: int) -> Vector2:
	return (profile[(e + 1) % profile.size()] - profile[e]).normalized()


static func v3(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, p.y, z)


## The frame centre line for a station's profile. Where the skin slopes in or out across
## the station (a tapering nose), a sloped plate's back reaches further in and passes over the
## ring's front and back edges at different heights, so the ring sits deeper.
func centre_line(profile: PackedVector2Array, station: int = -1) -> PackedVector2Array:
	var t := _station_tilt(station) if station >= 0 else 0.0
	return FrameParts.inset(profile, skin / cos(t) + GAP + ring_width * 0.5 * tan(t) + depth * 0.5)


## The steepest slope (radians from the ship's axis) of the skin either side of a station.
func _station_tilt(i: int) -> float:
	var worst := 0.0
	for j: int in [i - 1, i]:
		if j < 0 or j >= stations.size() - 1:
			continue
		var pa: PackedVector2Array = stations[j]["profile"]
		var pb: PackedVector2Array = stations[j + 1]["profile"]
		var dz: float = absf(float(stations[j + 1]["z"]) - float(stations[j]["z"]))
		for e in pa.size():
			var ma := (pa[e] + pa[(e + 1) % pa.size()]) * 0.5
			var mb := (pb[e] + pb[(e + 1) % pb.size()]) * 0.5
			var n := edge_out(pa, e)
			worst = maxf(worst, atan(absf((mb - ma).dot(n)) / maxf(dz, 0.01)))
	return minf(worst, deg_to_rad(70.0))


func _look(seg: int, e: int) -> Dictionary:
	return style.call(seg, e) if style.is_valid() else {}


## How far to pull a plate's end back from profile corner `k` so it clears the plate on the
## other side of the corner (thicker plates and sharper corners need more; `t` the
## thickness, the skin's by default).
func _corner_trim(profile: PackedVector2Array, k: int, t: float = -1.0) -> float:
	var n := profile.size()
	var a := (profile[(k + n - 1) % n] - profile[k]).normalized()
	var c := (profile[(k + 1) % n] - profile[k]).normalized()
	var angle := acos(clampf(a.dot(c), -1.0, 1.0))   # interior angle
	return GAP + (skin if t < 0.0 else t) / maxf(tan(angle * 0.5), 0.15)


## Whether four corners lie in one plane (within `tolerance`, metres).
static func _flat(c: PackedVector3Array, tolerance: float = 0.01) -> bool:
	var n := (c[1] - c[0]).cross(c[3] - c[0])
	if n.length() < 1e-6:
		n = (c[2] - c[1]).cross(c[3] - c[1])
	return absf(n.normalized().dot(c[2] - c[0])) < tolerance


## Joins and keeps the joint in `into` (welds or rivets).
func _join(into: Array[ConnectionData], a: PartData, b: PartData, kind: ConnectionData.Kind, at: Vector3,
		normal: Vector3, seam_up := Vector3.ZERO, seam_size := Vector2.ZERO) -> ConnectionData:
	var made := target.join(a, b, kind, at, normal, seam_up, seam_size)
	into.append(made)
	return made


# --- Mitred frame: rings --------------------------------------------------------------

func _mitre_rings() -> void:
	for i in stations.size():
		var z: float = stations[i]["z"]
		var line := centre_line(stations[i]["profile"], i)
		var n := line.size()
		var ring: Array = []
		var placed: Array[PackedVector2Array] = []
		for e in n:
			var a := line[e]
			var q := line[(e + 1) % n]
			if (frame_skip.is_valid() and frame_skip.call(i, e)) or a.distance_to(q) < depth * 1.2:
				ring.append(null)
				continue
			var d := (q - a).normalized()
			var before := (line[e] - line[(e + n - 1) % n]).normalized()
			var after := (line[(e + 2) % n] - q).normalized()
			var out := edge_out(line, e)
			var outline := FrameMember.mitre_outline(a, q, depth, out,
					FrameMember.mitre_line(before, d), FrameMember.mitre_line(d, after), GAP * 0.5)
			var x3 := Vector3(d.x, d.y, 0.0)
			var y3 := Vector3(out.x, out.y, 0.0)
			var xform := Transform3D(Basis(x3, y3, x3.cross(y3)), v3((a + q) * 0.5, z))
			# On a short side between sharp corners the cuts cross over, or a small section's
			# centre line folds: leave out anything that would overlap a member already placed.
			if (outline[1] - outline[0]).dot(d) < 0.06 or (outline[2] - outline[3]).dot(d) < 0.06 \
					or (q - a).dot(stations_edge_dir(stations[i]["profile"], e)) <= 0.0 \
					or _clashes(outline, placed):
				ring.append(null)
				continue
			placed.append(outline.duplicate())
			var to_local := xform.affine_inverse()
			for k in outline.size():
				var lp := to_local * v3(outline[k], z)
				outline[k] = Vector2(lp.x, lp.y)
			ring.append(target.member("FrameRing", PartData.Kind.FRAME, outline, ring_width, xform, frame_mat, 0.35))
		# Welds round each corner, where two members meet.
		for e in n:
			var m1: PartData = ring[e]
			var m2: PartData = ring[(e + 1) % n]
			if m1 == null or m2 == null:
				continue
			var a := line[e]
			var q := line[(e + 1) % n]
			var d := (q - a).normalized()
			var after := (line[(e + 2) % n] - q).normalized()
			var cut := FrameMember.mitre_line(d, after)
			var across := depth / maxf(absf(cut.dot(edge_out(line, e))), 0.2)
			var seam_n := (d + after).normalized()
			target.join(m1, m2, ConnectionData.Kind.WELD, v3(q, z), Vector3(seam_n.x, seam_n.y, 0.0),
					Vector3.BACK, Vector2(ring_width, across))
		rings.append(ring)


## Whether a member's outline would overlap any already placed in its ring.
static func _clashes(outline: PackedVector2Array, placed: Array[PackedVector2Array]) -> bool:
	var shrunk := FrameParts.inset(outline, 0.004)
	for other in placed:
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(shrunk, other):
			if absf(_area2(piece)) > 0.0004:
				return true
	return false


static func _area2(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].x * p[(i + 1) % p.size()].y - p[(i + 1) % p.size()].x * p[i].y
	return a * 0.5


# --- Mitred frame: stringers ----------------------------------------------------------

func _spaced_stringers() -> void:
	for i in stations.size() - 1:
		var za: float = stations[i]["z"]
		var zb: float = stations[i + 1]["z"]
		var la := centre_line(stations[i]["profile"], i)
		var lb := centre_line(stations[i + 1]["profile"], i + 1)
		var n := la.size()
		var row: Array = []
		var all_row: Array = []
		for e in n:
			row.append(null)
			all_row.append([])
			var ra: PartData = rings[i][e]
			var rb: PartData = rings[i + 1][e]
			if ra == null and rb == null:
				continue
			if stringer_skip.is_valid() and stringer_skip.call(i, e):
				continue
			var length := la[e].distance_to(la[(e + 1) % n])
			if length < 0.6:
				continue
			var count := maxi(1, roundi(length / stringer_spacing))
			for k in count:
				var t := (float(k) + 0.5) / float(count)
				var pa := la[e].lerp(la[(e + 1) % n], t)
				var pb := lb[e].lerp(lb[(e + 1) % n], t)
				var out := (edge_out(la, e) + edge_out(lb, e)).normalized()
				var p0 := v3(pa, za)
				var p1 := v3(pb, zb)
				var along := (p1 - p0).normalized()
				# A slanted stringer's square end pokes forward at one corner: allow for it.
				var lean := stringer_size * 0.5 * tan(acos(clampf(absf(along.z), 0.0, 1.0)))
				var clear := ring_width * 0.5 + GAP + lean
				p0 += along * clear / maxf(absf(along.z), 0.2)
				p1 -= along * clear / maxf(absf(along.z), 0.2)
				var y := Vector3(out.x, out.y, 0.0)
				y = (y - along * y.dot(along)).normalized()
				var x := y.cross(along)
				var s := target.box("Stringer", PartData.Kind.FRAME, Vector3(stringer_size, stringer_size, p0.distance_to(p1)),
						Transform3D(Basis(x, y, along), (p0 + p1) * 0.5), frame_mat, 0.35)
				if k == 0:
					row[e] = s
				(all_row[e] as Array).append(s)
				if ra:
					target.join(s, ra, ConnectionData.Kind.WELD, p0 - along * GAP * 0.5, along, y,
							Vector2(stringer_size, stringer_size))
				if rb:
					target.join(s, rb, ConnectionData.Kind.WELD, p1 + along * GAP * 0.5, along, y,
							Vector2(stringer_size, stringer_size))
		stringers.append(row)
		all_stringers.append(all_row)


# --- Mitred skin ----------------------------------------------------------------------

func _mitre_skin() -> void:
	var last := stations.size() - 2
	for i in stations.size() - 1:
		var za: float = stations[i]["z"]
		var zb: float = stations[i + 1]["z"]
		var pa: PackedVector2Array = stations[i]["profile"]
		var pb: PackedVector2Array = stations[i + 1]["profile"]
		var n := pa.size()
		# The first and last plates run on over the end ring to meet the caps.
		var z0 := za - (ring_width * 0.5 if i == 0 else -0.01)
		var z1 := zb + (ring_width * 0.5 if i == last else -0.01)
		# A flush skin's visuals meet over the middle of each ring, and run on over the
		# caps' edges at the ends (to the cap's outer face).
		var vz0 := za - (ring_width * 0.5 + GAP + skin if i == 0 else 0.0)
		var vz1 := zb + (ring_width * 0.5 + GAP + skin if i == last else 0.0)
		var row: Array = []
		for e in n:
			var look := _look(i, e)
			if look.get("skip", false):
				row.append(null)
				continue
			var e1 := (e + 1) % n
			var ta := _corner_trim(pa, e)
			var tb := _corner_trim(pa, e1)
			var tc := _corner_trim(pb, e)
			var td := _corner_trim(pb, e1)
			var dir_a := (pa[e1] - pa[e]).normalized()
			var dir_b := (pb[e1] - pb[e]).normalized()
			var a0 := pa[e] + dir_a * ta
			var a1 := pa[e1] - dir_a * tb
			var b0 := pb[e] + dir_b * tc
			var b1 := pb[e1] - dir_b * td
			if a0.distance_to(a1) < 0.08 and b0.distance_to(b1) < 0.08:
				row.append(null)
				continue
			# A sloped plate's back face reaches past its ends: pull them in to clear the
			# plates either side.
			var ma := (pa[e] + pa[e1]) * 0.5
			var mb := (pb[e] + pb[e1]) * 0.5
			var tilt := atan(absf((mb - ma).dot(edge_out(pa, e))) / maxf(zb - za, 0.01))
			var pull := skin * sin(tilt) + 0.004
			var lean := (mb - ma) / maxf(zb - za, 0.01)
			var zz0 := z0 + (pull if i > 0 else 0.0)
			var zz1 := z1 - (pull if i < last else 0.0)
			if tilt > 0.05:
				var extra := skin * 0.6
				a0 += dir_a * extra
				a1 -= dir_a * extra
				b0 += dir_b * extra
				b1 -= dir_b * extra
			var glass: bool = look.get("glass", false)
			var o2 := edge_out(pa, e)
			# The profiles are given at the stations; a flat plate's ends sit a little off
			# them (over the ring, or past the end ring to the cap), so a flat face follows
			# the taper there (a sheared hull's end plates would cut into their rings
			# otherwise). A twisted face keeps its corners at the stations' widths: its
			# triangles are shrunk to clear each other and have no room to lean further.
			var flat_shift_a := lean * (zz0 - za)
			var flat_shift_b := lean * (zz1 - zb)
			var corners := PackedVector3Array([v3(a0 + flat_shift_a, zz0), v3(a1 + flat_shift_a, zz0),
					v3(b1 + flat_shift_b, zz1), v3(b0 + flat_shift_b, zz1)])
			if not _flat(corners):
				a0 += lean * (zz0 - z0)
				a1 += lean * (zz0 - z0)
				b0 += lean * (zz1 - z1)
				b1 += lean * (zz1 - z1)
				corners = PackedVector3Array([v3(a0, zz0), v3(a1, zz0), v3(b1, zz1), v3(b0, zz1)])
				# A twisted face (its edge turns between stations): two triangles, each held
				# by the ring along its long side.
				var t1 := _mitre_plate(PackedVector3Array([corners[0], corners[1], corners[2]]), o2, look, glass)
				var t2 := _mitre_plate(PackedVector3Array([corners[0], corners[2], corners[3]]), o2, look, glass)
				row.append(t1)
				_fasten_edge(t1, corners[0], corners[1], rings[i][e], 1.0)
				_fasten_edge(t2, corners[3], corners[2], rings[i + 1][e], -1.0)
				continue
			# The flush visual: the untrimmed face, corner to corner and ring middle to
			# ring middle, so it meets its neighbours along the seam lines.
			var visual := PackedVector3Array()
			if flush:
				var la := lean * (vz0 - za)
				var lb := lean * (vz1 - zb)
				visual = PackedVector3Array([v3(pa[e] + la, vz0), v3(pa[e1] + la, vz0),
						v3(pb[e1] + lb, vz1), v3(pb[e] + lb, vz1)])
			var plate := _mitre_plate(corners, o2, look, glass, visual)
			row.append(plate)
			_fasten(plate, corners, i, e, ConnectionData.Kind.RIVET, Vector3(o2.x, o2.y, 0.0))
		plates.append(row)


## One skin plate over four outer-surface corners (a0, a1, b1, b0). Rectangles are boxes.
## `visual`, when given (a flush skin), is the bigger outline the plate is drawn over.
func _mitre_plate(c: PackedVector3Array, out2: Vector2, look: Dictionary, glass: bool,
		visual := PackedVector3Array()) -> PartData:
	if c.size() == 3:
		# Shrink it a little toward its middle, to clear its partner across the diagonal.
		var mid := (c[0] + c[1] + c[2]) / 3.0
		var area := (c[1] - c[0]).cross(c[2] - c[0]).length() * 0.5
		var perimeter := c[0].distance_to(c[1]) + c[1].distance_to(c[2]) + c[2].distance_to(c[0])
		var inradius := 2.0 * area / maxf(perimeter, 0.001)
		var k := clampf(1.0 - (skin * 0.7 + 0.01) / maxf(inradius, 0.01), 0.5, 1.0)
		var shrunk := PackedVector3Array()
		for p in c:
			shrunk.append(mid + (p - mid) * k)
		var made3 := FrameParts.plate_between(shrunk, Vector3(out2.x, out2.y, 0.0), skin, minf(0.012, skin * 0.4))
		return target.part(look.get("name", "WindowPane" if glass else "HullPlate"),
				PartData.Kind.GLASS if glass else PartData.Kind.HULL, made3[0], made3[1],
				look.get("mat", glass_mat if glass else skin_mat))
	var mat: Material = look.get("mat", glass_mat if glass else skin_mat)
	var part_name: String = look.get("name", "WindowPane" if glass else "HullPlate")
	var kind := PartData.Kind.GLASS if glass else PartData.Kind.HULL
	var out := Vector3(out2.x, out2.y, 0.0)
	return flat_plate(part_name, kind, c, out, skin, mat, visual)


## A flat plate part over four corners (a0, a1, b1, b0) lying on its outer surface, `t`
## thick behind them. A rectangle with its long sides along the ship is a box part (it
## dents and tears); anything else is cut to fit. With `visual` (a flush skin, lining or
## deck: the bigger outline to draw) the mesh runs out to it over the inset collision.
func flat_plate(part_name: String, kind: PartData.Kind, c: PackedVector3Array, out: Vector3, t: float,
		mat: Material, visual := PackedVector3Array(), bevel: float = -1.0) -> PartData:
	var bev := (flush_bevel if bevel < 0.0 else bevel)
	var across := c[1] - c[0]
	var along := c[3] - c[0]
	var rect := (c[2] - c[3]).distance_to(across) < 0.005 and absf(along.normalized().dot(out)) < 0.003 \
			and absf(along.normalized().dot(across.normalized())) < 0.003
	if rect and c[0].distance_to(c[1]) > 0.02:
		var x := across.normalized()
		var y := out
		var z := x.cross(y)
		var centre := (c[0] + c[1] + c[2] + c[3]) * 0.25 - out * t * 0.5
		var size := Vector3(across.length(), t, along.length())
		var xform := Transform3D(Basis(x, y, z), centre)
		if visual.is_empty():
			return target.box(part_name, kind, size, xform, mat, 1.0)
		var inv := xform.affine_inverse()
		var outline := PackedVector2Array()
		for p in visual:
			var l := inv * p
			outline.append(Vector2(l.x, l.z))
		return target.flush_box(part_name, kind, size, outline, xform, mat, 1.0, bev)
	var pts := PackedVector3Array()
	for p in c:
		if pts.is_empty() or pts[pts.size() - 1].distance_to(p) > 0.02:
			pts.append(p)
	if pts.size() > 3 and pts[0].distance_to(pts[pts.size() - 1]) < 0.02:
		pts.remove_at(pts.size() - 1)
	var made := FrameParts.plate_between(pts, out, t, minf(0.012, t * 0.4))
	var shape: PartShapes.PartShape = made[0]
	if visual.is_empty():
		return target.part(part_name, kind, shape, made[1], mat)
	var vis := FrameParts.plate_in_frame(visual, made[1], t, bev, 0.0)
	return target.flush_part(part_name, kind, shape, vis.mesh, made[1], mat, 1.0)


## One rivet in the middle of a triangle plate's side that lies along a ring, set in a
## little toward the plate (`side` +1 = toward +Z).
func _fasten_edge(plate: PartData, p0: Vector3, p1: Vector3, ring: PartData, side: float) -> void:
	if ring == null:
		return
	var at := (p0 + p1) * 0.5 + Vector3(0, 0, side * ring_width * 0.25)
	var n := (p1 - p0).cross(Vector3.BACK).normalized()
	if Vector2(n.x, n.y).dot(Vector2(at.x, at.y)) < 0.0:
		n = -n
	target.join(plate, ring, ConnectionData.Kind.RIVET, at, n)


## Rivets a plate to the rings at both ends of its segment (or to the side's stringer where
## a ring member is missing): two per end, or one on a narrow plate. `c` are the plate's
## outer-surface corners (a0, a1, b1, b0); heads sit on that surface.
func _fasten(plate: PartData, c: PackedVector3Array, seg: int, e: int, kind: ConnectionData.Kind,
		out: Vector3) -> void:
	var span := maxf(c[3].z - c[0].z, 0.001)
	for end in 2:
		var holder: PartData = rings[seg + end][e]
		if holder == null and stringers.size() > seg:
			holder = stringers[seg][e]
		if holder == null:
			continue
		# Over the middle of the ring member's width.
		var ring_z: float = stations[seg + end]["z"]
		var f := (ring_z - c[0].z) / span + (ring_width * 0.25 / span) * (1.0 if end == 0 else -1.0)
		f = clampf(f, 0.02, 0.98)
		var left := c[0].lerp(c[3], f)
		var right := c[1].lerp(c[2], f)
		var row_len := left.distance_to(right)
		var spots: Array[float] = [0.5]
		if row_len >= 0.7:
			var inset := minf(0.25, row_len * 0.2) / row_len
			spots = [inset, 1.0 - inset]
		for t in spots:
			target.join(plate, holder, kind, left.lerp(right, t), out)


# --- Mitred caps ----------------------------------------------------------------------

func _mitre_caps() -> void:
	for end in 2:
		var cap_spec: Variant = caps[end]
		if cap_spec is bool and not cap_spec:
			continue
		var look: Dictionary = cap_spec if cap_spec is Dictionary else {}
		if look.get("skip", false):
			continue
		var s: int = 0 if end == 0 else stations.size() - 1
		var z: float = stations[s]["z"]
		var facing := -1.0 if end == 0 else 1.0
		var face_z := z + facing * (ring_width * 0.5 + GAP + skin)
		var profile: PackedVector2Array = FrameParts.inset(stations[s]["profile"], 0.01)
		var pts := PackedVector3Array()
		for p in profile:
			pts.append(v3(p, face_z))
		var glass: bool = look.get("glass", false)
		var made := FrameParts.plate_between(pts, Vector3(0, 0, facing), skin, minf(0.012, skin * 0.4))
		var cap_plate := target.part(look.get("name", "WindowPane" if glass else "CapPlate"),
				PartData.Kind.GLASS if glass else PartData.Kind.HULL, made[0], made[1],
				look.get("mat", glass_mat if glass else skin_mat))
		caps_made[end] = cap_plate
		var line := centre_line(stations[s]["profile"], s)
		for e in line.size():
			var m: PartData = rings[s][e]
			if m == null:
				continue
			var mid := (line[e] + line[(e + 1) % line.size()]) * 0.5
			target.join(cap_plate, m, ConnectionData.Kind.RIVET, v3(mid, face_z), Vector3(0, 0, facing))


# --- Mitred linings (v4) --------------------------------------------------------------

## The outline the linings' cavity-side faces lie on at station `s`: inside the ring
## members by `lining_inset` (or `inset`).
func lining_line(s: int, inset: float = -1.0) -> PackedVector2Array:
	var d_in := depth * 0.5 + GAP + (lining_inset if inset < 0.0 else inset)
	return FrameParts.inset(centre_line(stations[s]["profile"], s), d_in)


## The outline the linings' room-side faces lie on at station `s` (one panel thickness
## further in): the room's clear section where a bay is lined all round.
func lining_face(s: int, inset: float = -1.0) -> PackedVector2Array:
	var d_in := depth * 0.5 + GAP + (lining_inset if inset < 0.0 else inset) + lining_thickness
	return FrameParts.inset(centre_line(stations[s]["profile"], s), d_in)


## An inner panel over the frame between stations `seg` and `seg + 1` across profile edge
## `e`: the double hull's inner skin. It lies `inset` (default `lining_inset`) inside the
## ring members' inner faces, bolted to the rings at both ends (heads on the room side); a
## deep one (over BRACKET_FROM) stands on a bracket welded to each ring instead, leaving
## a cavity for services and components. Flush like the skin when `flush` is on. Returns
## the panel (null on a face too narrow or twisted to line).
## `y_clip` and `z_clip` (ship space, min and max) cut the panel down: a deep lining that
## stands on the deck (y from the floor up), or stops short of a bulkhead in its bay.
func lining(seg: int, e: int, mat: Material, inset: float = -1.0, part_name: String = "InnerPanel",
		y_clip := Vector2(-INF, INF), z_clip := Vector2(-INF, INF)) -> PartData:
	var ins := lining_inset if inset < 0.0 else inset
	var t := lining_thickness
	var last := stations.size() - 2
	var za: float = stations[seg]["z"]
	var zb: float = stations[seg + 1]["z"]
	var la := lining_line(seg, ins)
	var lb := lining_line(seg + 1, ins)
	var n := la.size()
	var e1 := (e + 1) % n
	var dir_a := (la[e1] - la[e]).normalized()
	var dir_b := (lb[e1] - lb[e]).normalized()
	var a0 := _clip_y(la[e] + dir_a * _corner_trim(la, e, t), dir_a, y_clip)
	var a1 := _clip_y(la[e1] - dir_a * _corner_trim(la, e1, t), dir_a, y_clip)
	var b0 := _clip_y(lb[e] + dir_b * _corner_trim(lb, e, t), dir_b, y_clip)
	var b1 := _clip_y(lb[e1] - dir_b * _corner_trim(lb, e1, t), dir_b, y_clip)
	if a0.distance_to(a1) < 0.1 or b0.distance_to(b1) < 0.1 or (a1 - a0).dot(dir_a) <= 0.0:
		return null
	var z0 := maxf(za - (ring_width * 0.5 if seg == 0 else -0.01), z_clip.x)
	var z1 := minf(zb + (ring_width * 0.5 if seg == last else -0.01), z_clip.y)
	if z1 - z0 < 0.15:
		return null
	var out := edge_out(la, e)
	var inward := Vector3(-out.x, -out.y, 0.0)
	# The panel's room-side face (what flat_plate takes as its outer surface).
	var room := PackedVector3Array([v3(a0, z0), v3(a1, z0), v3(b1, z1), v3(b0, z1)])
	for i in room.size():
		room[i] += inward * t
	if not _flat(room):
		return null
	var visual := PackedVector3Array()
	if flush:
		var vz0 := maxf(za - (ring_width * 0.5 if seg == 0 else 0.0), z_clip.x)
		var vz1 := minf(zb + (ring_width * 0.5 if seg == last else 0.0), z_clip.y)
		visual = PackedVector3Array([v3(_clip_y(la[e], dir_a, y_clip), vz0), v3(_clip_y(la[e1], dir_a, y_clip), vz0),
				v3(_clip_y(lb[e1], dir_b, y_clip), vz1), v3(_clip_y(lb[e], dir_b, y_clip), vz1)])
		for i in visual.size():
			visual[i] += inward * t
	var panel := flat_plate(part_name, PartData.Kind.HULL, room, inward, t, mat, visual)
	linings["%d:%d" % [seg, e]] = panel
	lining_insets["%d:%d" % [seg, e]] = {"inset": ins, "clipped": y_clip.x > -INF or y_clip.y < INF}
	# Held at both ends: bolted straight to the ring (a long bolt through the standoff),
	# or to a bracket welded to the ring on a deep lining.
	var span := maxf(room[3].z - room[0].z, 0.001)
	for end in 2:
		var ring: PartData = rings[seg + end][e]
		if ring == null:
			continue
		var ring_z: float = stations[seg + end]["z"]
		var f := clampf((ring_z - room[0].z) / span, 0.02, 0.98)
		var left := room[0].lerp(room[3], f)
		var right := room[1].lerp(room[2], f)
		var holder := ring
		if ins > BRACKET_FROM:
			# From the ring's inner face to the panel's back, under the panel's middle.
			var length := ins - GAP * 2.0
			var mid := left.lerp(right, 0.5) - inward * (t + GAP + length * 0.5)
			var x := (right - left).normalized()
			var bracket := target.box("LiningBracket", PartData.Kind.FRAME, Vector3(0.1, length, 0.1),
					Transform3D(Basis(x, inward, x.cross(inward)), mid), frame_mat, 0.6)
			target.join(bracket, ring, ConnectionData.Kind.WELD, mid - inward * (length * 0.5 + GAP * 0.5),
					-inward, x, Vector2(0.1, 0.1))
			holder = bracket
		var row_len := left.distance_to(right)
		var spots: Array[float] = [0.5]
		if row_len >= 0.7 and holder == ring:
			var ins_t := minf(0.25, row_len * 0.2) / row_len
			spots = [ins_t, 1.0 - ins_t]
		for s in spots:
			target.join(panel, holder, ConnectionData.Kind.BOLT, left.lerp(right, s), inward)
	return panel


## Lines every face in `edges` of segments seg0..seg1 (inclusive). Returns the panels made.
func line_bays(seg0: int, seg1: int, edges: Array, mat: Material, inset: float = -1.0,
		part_name: String = "InnerPanel") -> Array[PartData]:
	var made: Array[PartData] = []
	for seg in range(seg0, seg1 + 1):
		for e: int in edges:
			var p := lining(seg, e, mat, inset, part_name)
			if p:
				made.append(p)
	return made


## The lining panel in segment `seg` nearest the point (x, y) (by its edge's centre
## line), or null (also when the nearest is further off than `max_dist`).
func lining_at(seg: int, p: Vector2, max_dist: float = INF) -> PartData:
	var line := centre_line(stations[seg]["profile"], seg)
	var best: PartData = null
	var best_d := max_dist
	for e in line.size():
		var panel: PartData = linings.get("%d:%d" % [seg, e])
		if panel == null:
			continue
		var c := Geometry2D.get_closest_point_to_segment(p, line[e], line[(e + 1) % line.size()])
		if c.distance_to(p) < best_d:
			best_d = c.distance_to(p)
			best = panel
	return best


## `p` moved along `dir` until its y is within `clip` (an edge end cut to a floor or ceiling).
static func _clip_y(p: Vector2, dir: Vector2, clip: Vector2) -> Vector2:
	if absf(dir.y) < 0.001:
		return p
	if p.y < clip.x:
		return p + dir * ((clip.x - p.y) / dir.y)
	if p.y > clip.y:
		return p + dir * ((clip.y - p.y) / dir.y)
	return p


# --- Node frame -----------------------------------------------------------------------

## The z of station `i`'s ring on a node style: the end rings stand in from the ends, clear
## of the caps.
func ring_z(i: int) -> float:
	var z: float = stations[i]["z"]
	if stations.size() > 1 and (i == 0 or i == stations.size() - 1):
		var other: float = stations[1 if i == 0 else i - 1]["z"]
		z += signf(other - z) * (node_size * 0.5 + skin + GAP + end_gap[0 if i == 0 else 1])
	return z


func _place_nodes() -> void:
	_points.clear()
	for i in stations.size():
		var row: Array[Vector3] = []
		for p in centre_line(stations[i]["profile"], i):
			row.append(v3(p, ring_z(i)))
		_points.append(row)


func _ring_centre(i: int) -> Vector3:
	var c := Vector3.ZERO
	for p: Vector3 in _points[i]:
		c += p
	return c / float((_points[i] as Array).size())


## The planes bounding where the frame may be: every face's inner skin surface (less the
## gap), and the planes past the end stations.
func _collect_planes() -> void:
	_planes.clear()
	for seg in stations.size() - 1:
		var pa: PackedVector2Array = stations[seg]["profile"]
		var pb: PackedVector2Array = stations[seg + 1]["profile"]
		var za: float = stations[seg]["z"]
		var zb: float = stations[seg + 1]["z"]
		for e in pa.size():
			var e1 := (e + 1) % pa.size()
			var a0 := v3(pa[e], za)
			var a1 := v3(pa[e1], za)
			var b0 := v3(pb[e], zb)
			var b1 := v3(pb[e1], zb)
			var o2 := edge_out(pa, e)
			for tri: Array in [[a0, a1, b0], [a1, b1, b0]]:
				var n := ((tri[1] as Vector3) - (tri[0] as Vector3)).cross((tri[2] as Vector3) - (tri[0] as Vector3)).normalized()
				if n.length() < 0.5:
					continue
				if n.dot(Vector3(o2.x, o2.y, 0.0)) < 0.0:
					n = -n
				_planes.append([n, n.dot(tri[0] as Vector3) - skin - GAP])
	var z0: float = stations[0]["z"]
	var z1: float = stations[stations.size() - 1]["z"]
	_planes.append([Vector3.FORWARD, -(z0 + skin + GAP)])
	_planes.append([Vector3.BACK, z1 - skin - GAP])


## The biggest cube (half size) centred at `p` that keeps inside the frame's planes.
func _cube_room(p: Vector3) -> float:
	var h := node_size * 0.5
	for pl: Array in _planes:
		var n: Vector3 = pl[0]
		h = minf(h, (float(pl[1]) - n.dot(p)) / (absf(n.x) + absf(n.y) + absf(n.z)))
	return maxf(h, 0.02)


## How far along `d` from a node's centre a member must start to clear its collision cube
## (half size `h`) by the gap.
static func _setback(h: float, d: Vector3) -> float:
	return h * (absf(d.x) + absf(d.y) + absf(d.z)) + GAP


## How far along `d` from a node's centre its look's surface is (where a member's bead goes).
func _face_at(d: Vector3) -> float:
	return node_size * 0.5 * maxf(absf(d.x), maxf(absf(d.y), absf(d.z)))


func _build_nodes() -> void:
	nodes.clear()
	_node_half.clear()
	var look := FrameParts.node(node_size)
	for i in stations.size():
		var row: Array = []
		var halves: Array[float] = []
		for p: Vector3 in _points[i]:
			var h := _cube_room(p)
			var shape := PartShapes.PartShape.new()
			shape.mesh = look.mesh
			shape.recipe = look.recipe
			shape.volume = look.volume
			var box := BoxShape3D.new()
			box.size = Vector3.ONE * h * 2.0
			shape.collision = box
			row.append(target.part("FrameNode", PartData.Kind.FRAME, shape, Transform3D(Basis(), p), frame_mat, "", 0.6))
			halves.append(h)
		nodes.append(row)
		_node_half.append(halves)


func _node_rings() -> void:
	rings.clear()
	for i in stations.size():
		var pts: Array = _points[i]
		var n := pts.size()
		var row: Array = []
		var centre := _ring_centre(i)
		for e in n:
			if frame_skip.is_valid() and frame_skip.call(i, e):
				row.append(null)
				continue
			var e1 := (e + 1) % n
			row.append(_member("FrameRing", nodes[i][e], nodes[i][e1], pts[e], pts[e1], _node_half[i][e],
					_node_half[i][e1], ((pts[e] as Vector3) + (pts[e1] as Vector3)) * 0.5 - centre,
					Vector2(ring_width, depth), 0.0))
		rings.append(row)


func _corner_stringers() -> void:
	stringers.clear()
	for i in stations.size() - 1:
		var row: Array = []
		var centre := _ring_centre(i)
		for k in (_points[i] as Array).size():
			var a: Vector3 = _points[i][k]
			var b: Vector3 = _points[i + 1][k]
			row.append(_member("Stringer", nodes[i][k], nodes[i + 1][k], a, b, _node_half[i][k], _node_half[i + 1][k],
					a - centre, Vector2(stringer_size, stringer_depth), ring_width * 0.5))
		stringers.append(row)


## A square member from node `na` (centre `a`, collision half `ha`) to node `nb`, its height
## facing `up`, its section (width, height): drawn node centre to node centre, its
## collision pulled back clear of both nodes and fitted inside the skin. A member running
## along the ship (a stringer, a splice) also keeps clear of the ring girders' slab either
## side of each node (`ring_half`: half their width). Welded to both nodes all round where it
## meets each node's look. Null if the nodes are too close.
func _member(member_name: String, na: PartData, nb: PartData, a: Vector3, b: Vector3, ha: float, hb: float,
		up: Vector3, section: Vector2, ring_half: float) -> PartData:
	var length := a.distance_to(b)
	var d := (b - a) / maxf(length, 0.001)
	var ta := _setback(ha, d)
	var tb := _setback(hb, d)
	if ring_half > 0.0:
		# Its square end leans past the ring's face at one corner when it slants.
		var dz := clampf(absf(d.z), 0.2, 1.0)
		var lean := maxf(section.x, section.y) * 0.5 * tan(acos(dz))
		var clear := (ring_half + GAP + lean) / dz
		ta = maxf(ta, clear)
		tb = maxf(tb, clear)
	if length - ta - tb < 0.05:
		return null
	var xform := FrameParts.along(a, b, up)
	var x0 := -length * 0.5 + ta
	var x1 := length * 0.5 - tb
	var half := Vector2(section.y * 0.5, section.x * 0.5)   # (height, width) halves
	var s := _fit(xform, x0, x1, half)
	var look := PartShapes.girder(length, section.x, section.y)
	var shape := PartShapes.PartShape.new()
	shape.mesh = look.mesh
	shape.recipe = look.recipe
	shape.volume = look.volume
	shape.collision = _box_points(Vector3(x0, -half.x * s, -half.y * s), Vector3(x1, half.x * s, half.y * s))
	var made := target.part(member_name, PartData.Kind.FRAME, shape, xform, frame_mat, "", 0.35)
	var seam_up := xform.basis.y
	var fa := minf(_face_at(d), length * 0.5)
	var fb := minf(_face_at(-d), length * 0.5)
	var seam := Vector2(section.y, section.x)   # along seam_up (the height), across it (the width)
	_join(welds, made, na, ConnectionData.Kind.WELD, a + d * fa, d, seam_up, seam)
	_join(welds, made, nb, ConnectionData.Kind.WELD, b - d * fb, d, seam_up, seam)
	_members.append({"part": made, "p0": xform * Vector3(x0, 0, 0), "p1": xform * Vector3(x1, 0, 0),
			"half": maxf(section.x, section.y) * 0.5})
	return made


## The share (0.2 .. 1) of a member's section its collision may keep and stay inside every
## plane: its box runs x0..x1 along it, `half` (height, width) across.
func _fit(xform: Transform3D, x0: float, x1: float, half: Vector2) -> float:
	var s := 1.0
	for pl: Array in _planes:
		var n: Vector3 = pl[0]
		var room := float(pl[1]) - n.dot(xform.origin) - maxf(n.dot(xform.basis.x) * x0, n.dot(xform.basis.x) * x1)
		var reach := half.x * absf(n.dot(xform.basis.y)) + half.y * absf(n.dot(xform.basis.z))
		if reach > 0.0001:
			s = minf(s, room / reach)
	return clampf(s, 0.2, 1.0)


static func _box_points(lo: Vector3, hi: Vector3) -> ConvexPolygonShape3D:
	var pts := PackedVector3Array()
	for k in 8:
		pts.append(Vector3(hi.x if k & 1 else lo.x, hi.y if k & 2 else lo.y, hi.z if k & 4 else lo.z))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	return col


## Joins this hull's station `mine` to `other`'s station `theirs` (two sections meeting end
## to end, as the canopy meets the main hull): a short splice girder between each pair of
## nodes [my corner, their corner], welded to both. Node styles.
func splice(mine: int, other: FrameHull, theirs: int, pairs: Array) -> void:
	var was := target.parts_model().head_style
	target.parts_model().head_style = bead
	for pair: Vector2i in pairs:
		var a: Vector3 = _points[mine][pair.x]
		var b: Vector3 = other._points[theirs][pair.y]
		_member("FrameSplice", nodes[mine][pair.x], other.nodes[theirs][pair.y], a, b, _node_half[mine][pair.x],
				other._node_half[theirs][pair.y], a - _ring_centre(mine), Vector2(ring_width, depth),
				maxf(ring_width, other.ring_width) * 0.5)
	target.parts_model().head_style = was


# --- Node skin ------------------------------------------------------------------------

func _node_skin() -> void:
	plates.clear()
	var last := stations.size() - 2
	for seg in stations.size() - 1:
		var za: float = stations[seg]["z"]
		var zb: float = stations[seg + 1]["z"]
		var pa: PackedVector2Array = stations[seg]["profile"]
		var pb: PackedVector2Array = stations[seg + 1]["profile"]
		var n := pa.size()
		var row: Array = []
		for e in n:
			var look := _look(seg, e)
			if look.get("skip", false):
				row.append([])
				continue
			var e1 := (e + 1) % n
			var o2 := edge_out(pa, e)
			var out := Vector3(o2.x, o2.y, 0.0)
			# How far each kind of edge stands back: along the corners, at the stations (a
			# sloped plate's back face reaches past its ends), and at the section's ends.
			var ma := (pa[e] + pa[e1]) * 0.5
			var mb := (pb[e] + pb[e1]) * 0.5
			var tilt := atan(absf((mb - ma).dot(o2)) / maxf(zb - za, 0.01))
			var station_back := GAP * 0.5 + skin * sin(tilt) + (0.004 if tilt > 0.05 else 0.0)
			var back_a := end_gap[0] + GAP * 0.5 if seg == 0 else station_back
			var back_b := end_gap[1] + GAP * 0.5 if seg == last else station_back
			var side_a := maxf(_corner_trim(pa, e), _corner_trim(pb, e))
			var side_b := maxf(_corner_trim(pa, e1), _corner_trim(pb, e1))
			var corners := PackedVector3Array([v3(pa[e], za), v3(pa[e1], za), v3(pb[e1], zb), v3(pb[e], zb)])
			var pieces: Array = []
			if _flat(corners, 0.002):
				for strip: Array in _strips(seg, e, corners):
					pieces.append(strip)
			else:
				# A twisted face: two triangles, the diagonal between them held back too.
				pieces.append([PackedVector3Array([corners[0], corners[1], corners[2]]),
						[back_a, side_b, GAP * 0.5 + skin * 0.7]])
				pieces.append([PackedVector3Array([corners[0], corners[2], corners[3]]),
						[GAP * 0.5 + skin * 0.7, back_b, side_a]])
			var made: Array = []
			for piece: Array in pieces:
				var poly: PackedVector3Array = piece[0]
				var backs: Array = piece[1]
				# Strips come with edge kinds; resolve them to distances.
				var amounts: Array[float] = []
				for k in backs.size():
					var v: Variant = backs[k]
					if v is String:
						match String(v):
							"a": amounts.append(back_a)
							"b": amounts.append(back_b)
							"side_a": amounts.append(side_a)
							"side_b": amounts.append(side_b)
							_: amounts.append(GAP * 0.5)
					else:
						amounts.append(float(v))
				var plate := _node_plate(poly, amounts, out, look)
				if plate:
					made.append(plate)
			row.append(made)
		plates.append(row)


## The face (seg, e) split round its openings into rectangles, each [corners, edge kinds]:
## corners in the face's order (a0, a1, b1, b0 sense) and per edge "a" / "b" (at a station),
## "side_a" / "side_b" (along a profile corner) or "cut" (beside a hole or another strip).
func _strips(seg: int, e: int, c: PackedVector3Array) -> Array:
	var za := c[0].z
	var zb := c[3].z
	var along := c[1] - c[0]
	var length := along.length()
	var u := along / maxf(length, 0.001)
	var holes: Array[Rect2] = []
	for op: Array in _openings:
		if int(op[0]) != e:
			continue
		var box: AABB = op[1]
		var s0 := INF
		var s1 := -INF
		for k in 8:
			var s := (box.get_endpoint(k) - c[0]).dot(u)
			s0 = minf(s0, s)
			s1 = maxf(s1, s)
		var h := Rect2(maxf(s0, 0.0), maxf(box.position.z, za), minf(s1, length) - maxf(s0, 0.0),
				minf(box.end.z, zb) - maxf(box.position.z, za))
		if h.size.x > 0.01 and h.size.y > 0.01:
			holes.append(h)
	var at := func(s: float, z: float) -> Vector3:
		var t := (z - za) / maxf(zb - za, 0.001)
		return c[0].lerp(c[3], t) + u * s
	if holes.is_empty():
		return [[c, ["a", "side_b", "b", "side_a"]]]
	var zs: Array[float] = [za, zb]
	for h in holes:
		zs.append(h.position.y)
		zs.append(h.end.y)
	zs.sort()
	var out: Array = []
	for i in zs.size() - 1:
		var z0 := zs[i]
		var z1 := zs[i + 1]
		if z1 - z0 < 0.02:
			continue
		var mid := (z0 + z1) * 0.5
		var spans: Array = [[0.0, length]]
		for h in holes:
			if mid <= h.position.y or mid >= h.end.y:
				continue
			var next: Array = []
			for sp: Array in spans:
				if h.end.x <= sp[0] or h.position.x >= sp[1]:
					next.append(sp)
					continue
				if h.position.x > sp[0]:
					next.append([sp[0], h.position.x])
				if h.end.x < sp[1]:
					next.append([h.end.x, sp[1]])
			spans = next
		for sp: Array in spans:
			var s0: float = sp[0]
			var s1: float = sp[1]
			if s1 - s0 < 0.02:
				continue
			var poly := PackedVector3Array([at.call(s0, z0), at.call(s1, z0), at.call(s1, z1), at.call(s0, z1)])
			out.append([poly, ["a" if is_equal_approx(z0, za) else "cut",
					"side_b" if is_equal_approx(s1, length) else "cut",
					"b" if is_equal_approx(z1, zb) else "cut",
					"side_a" if is_equal_approx(s0, 0.0) else "cut"]])
	return out


## One plate over `poly` (its outer surface, ship space, convex, in order): drawn over the
## whole outline, its collision with each edge k held back by `backs[k]`. Riveted along
## every member it lies over. Null if nothing is left after the trim.
func _node_plate(poly: PackedVector3Array, backs: Array[float], out: Vector3, look: Dictionary) -> PartData:
	var glass: bool = look.get("glass", false)
	var shown := FrameParts.plate_between(poly, out, skin)
	var vis_xform: Transform3D = shown[1]
	var trimmed := _shrink(poly, backs, vis_xform)
	if trimmed.size() < 3:
		return null
	var held := FrameParts.plate_between(trimmed, out, skin, minf(0.012, skin * 0.4))
	var vis: PartShapes.PartShape = shown[0]
	var shape := PartShapes.PartShape.new()
	shape.mesh = vis.mesh
	shape.recipe = vis.recipe
	shape.volume = (held[0] as PartShapes.PartShape).volume
	shape.collision = _moved((held[0] as PartShapes.PartShape).collision as ConvexPolygonShape3D,
			vis_xform.affine_inverse() * (held[1] as Transform3D))
	var part_name: String = look.get("name", "WindowPane" if glass else "HullPlate")
	var mat: Material = look.get("mat", glass_mat if glass else skin_mat)
	var made := target.part(part_name, PartData.Kind.GLASS if glass else PartData.Kind.HULL, shape, vis_xform, mat,
			look.get("tag", ""))
	_rivet(made, trimmed, out, vis_xform)
	return made


## `poly` with each edge k moved in by `backs[k]` in its own plane (`frame`: Y out of it).
static func _shrink(poly: PackedVector3Array, backs: Array[float], frame: Transform3D) -> PackedVector3Array:
	var inv := frame.affine_inverse()
	var flat := PackedVector2Array()
	for p in poly:
		var l := inv * p
		flat.append(Vector2(l.x, l.z))
	# Wind it one way, so "in" is the same side for every edge.
	var area := 0.0
	for i in flat.size():
		area += flat[i].x * flat[(i + 1) % flat.size()].y - flat[(i + 1) % flat.size()].x * flat[i].y
	var turn := 1.0 if area > 0.0 else -1.0
	var lines: Array = []
	for i in flat.size():
		var a := flat[i]
		var b := flat[(i + 1) % flat.size()]
		var d := (b - a).normalized()
		var inward := Vector2(-d.y, d.x) * turn
		lines.append([a + inward * backs[i], d])
	var out := PackedVector3Array()
	for i in lines.size():
		var l0: Array = lines[(i + lines.size() - 1) % lines.size()]
		var l1: Array = lines[i]
		var hit: Variant = Geometry2D.line_intersects_line(l0[0], l0[1], l1[0], l1[1])
		if hit == null:
			continue
		var p: Vector2 = hit
		out.append(frame * Vector3(p.x, 0.0, p.y))
	# A plate trimmed to nothing (its edges crossed over) is dropped.
	if out.size() >= 3:
		var n := (out[1] - out[0]).cross(out[2] - out[0])
		var m := (poly[1] - poly[0]).cross(poly[2] - poly[0])
		if n.dot(m) <= 0.0:
			return PackedVector3Array()
	return out


static func _moved(col: ConvexPolygonShape3D, by: Transform3D) -> ConvexPolygonShape3D:
	var pts := PackedVector3Array()
	for p in col.points:
		pts.append(by * p)
	var moved := ConvexPolygonShape3D.new()
	moved.points = pts
	return moved


## Rivets a plate (its trimmed outer outline `poly`, plate space `frame`) in a row along every
## member lying under it, at the style's pitch (one at least on a short row).
func _rivet(plate: PartData, poly: PackedVector3Array, out: Vector3, frame: Transform3D) -> void:
	var inv := frame.affine_inverse()
	var flat := PackedVector2Array()
	for p in poly:
		var l := inv * p
		flat.append(Vector2(l.x, l.z))
	var inner := FrameParts.inset(flat, ROW_MARGIN)
	if inner.size() < 3:
		inner = flat
	var reach := skin + GAP + depth + 0.06   # a member's centre line under the skin
	for m: Dictionary in _members:
		var p0: Vector3 = inv * (m["p0"] as Vector3)
		var p1: Vector3 = inv * (m["p1"] as Vector3)
		# Under this plate: both ends below its face, no further than a member's depth.
		if p0.y > -skin or p1.y > -skin or p0.y < -reach or p1.y < -reach:
			continue
		# The row may sit anywhere over the member's face: off its centre line, toward the
		# plate's middle, where the plate stops short over it (at a station, by a corner).
		var a2 := Vector2(p0.x, p0.z)
		var b2 := Vector2(p1.x, p1.z)
		var across := (b2 - a2).normalized().orthogonal()
		var q := float(m["half"]) * 0.45
		var row: Array = []
		for shift: float in [0.0, q, -q, q * 2.0, -q * 2.0]:
			row = _clip_segment(a2 + across * shift, b2 + across * shift, inner)
			if not row.is_empty():
				break
		if row.is_empty():
			continue
		var a: Vector2 = row[0]
		var b: Vector2 = row[1]
		var count := maxi(1, roundi(a.distance_to(b) / rivet_pitch))
		for k in count:
			var t := (float(k) + 0.5) / float(count)
			var at := a.lerp(b, t)
			_join(rivets, plate, m["part"], ConnectionData.Kind.RIVET, frame * Vector3(at.x, 0.0, at.y), out)


## The part of segment a..b inside convex `poly` ([] if none): [start, end].
static func _clip_segment(a: Vector2, b: Vector2, poly: PackedVector2Array) -> Array:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	var area := 0.0
	for i in poly.size():
		area += poly[i].x * poly[(i + 1) % poly.size()].y - poly[(i + 1) % poly.size()].x * poly[i].y
	var turn := 1.0 if area > 0.0 else -1.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		var e := q - p
		var inward := Vector2(-e.y, e.x) * turn
		var num := (a - p).dot(inward)
		var den := d.dot(inward)
		if absf(den) < 1e-9:
			if num < 0.0:
				return []
			continue
		var t := -num / den
		if den > 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
		if t0 > t1:
			return []
	if (t1 - t0) * d.length() < 0.01:
		return []
	return [a + d * t0, a + d * t1]


# --- Node caps ------------------------------------------------------------------------

## End caps at station `end` (0 = the front, or the last station): a plate over each convex
## outline (x, y) in `pieces`, facing out of that end, its collision inside the side plates
## and clear of its neighbours, riveted to the end ring. Node styles (the mitred style caps
## its ends itself, `caps`).
func cap(end: int, pieces: Array, mat: Material, tag: String = "", glass: bool = false) -> Array[PartData]:
	var was := target.parts_model().head_style
	target.parts_model().head_style = RIVET_HEAD
	var s := 0 if end == 0 else stations.size() - 1
	var z: float = stations[s]["z"]
	var facing := Vector3.FORWARD if end == 0 else Vector3.BACK
	var profile: PackedVector2Array = stations[s]["profile"]
	var made: Array[PartData] = []
	for outline: PackedVector2Array in pieces:
		var poly := PackedVector3Array()
		for p in outline:
			poly.append(v3(p, z))
		var backs: Array[float] = []
		for k in outline.size():
			backs.append(skin + GAP if _on_outline(outline[k], outline[(k + 1) % outline.size()], profile) else GAP * 0.5)
		var look := {"mat": mat, "tag": tag, "glass": glass, "name": "WindowPane" if glass else "CapPlate"}
		var plate := _node_plate(poly, backs, facing, look)
		if plate:
			made.append(plate)
			cap_plates.append(plate)
	target.parts_model().head_style = was
	return made


## Whether edge p..q lies along the profile's outline (an outer edge of a cap piece).
static func _on_outline(p: Vector2, q: Vector2, profile: PackedVector2Array) -> bool:
	for i in profile.size():
		var a := profile[i]
		var b := profile[(i + 1) % profile.size()]
		var near_p := Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 0.002
		var near_q := Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) < 0.002
		if near_p and near_q:
			return true
	return false
