class_name HullBuilder
extends RefCounted
## Builds a hull frame first, then skins it: give it the hull's cross-section (its outer
## surface, as points round the outline) at stations along the ship, and it puts up
##   - a ring of girders round each station (frames),
##   - girders running fore and aft between the stations at every corner (stringers),
##   - a node block wherever girders meet,
##   - skin plates over every face between two stations, cut to fit (a slope that tapers
##     gets trapezoid or triangle plates).
## Stations can change shape along the ship (taper, flare, chamfered ends): each station
## needs the same number of points. Use `style` to choose each face's material, tag, or to
## leave it open (for doors, or to fill it yourself with a ShipKit wall that has holes).
## End caps: `cap()` plates a flat outline at a station.
##
## Profiles are in ship space (x, y), points in order round the outline; z is the station.

var kit: ShipKit
## Skin plate thickness, frame girder size and node size, in metres.
var skin: float = 0.08
var frame_width: float = 0.14
var frame_height: float = 0.18
var node_size: float = 0.26
var frame_mat: Material
var skin_mat: Material
## Stations, front to back: {z: float, profile: PackedVector2Array}.
var stations: Array[Dictionary] = []
## Optional: `frame_skip(station_index, edge) -> bool` leaves out a ring girder (say, where
## a cabin opens through the roof). Stringers and nodes are unaffected.
var frame_skip := Callable()


func _init(target: ShipKit, skin_material: Material, frame_material: Material) -> void:
	kit = target
	skin_mat = skin_material
	frame_mat = frame_material


func add_station(z: float, profile: PackedVector2Array) -> void:
	stations.append({"z": z, "profile": profile})


## Builds frames and skin. `style(segment, edge) -> {skip, mat, tag, solid}` (all optional)
## styles the face between station `segment` and the next, along profile edge `edge` (from
## point `edge` to the next one). `frames` false = skin only.
func build(style := Callable(), frames := true) -> void:
	if frames:
		_build_frames()
	for seg in stations.size() - 1:
		var a: Dictionary = stations[seg]
		var b: Dictionary = stations[seg + 1]
		var pa: PackedVector2Array = a["profile"]
		var pb: PackedVector2Array = b["profile"]
		var n := pa.size()
		for e in n:
			var look: Dictionary = style.call(seg, e) if style.is_valid() else {}
			if look.get("skip", false):
				continue
			var mat: Material = look.get("mat", skin_mat)
			var tag: String = look.get("tag", "")
			var solid: bool = look.get("solid", true)
			var a0 := Vector3(pa[e].x, pa[e].y, a["z"])
			var a1 := Vector3(pa[(e + 1) % n].x, pa[(e + 1) % n].y, a["z"])
			var b0 := Vector3(pb[e].x, pb[e].y, b["z"])
			var b1 := Vector3(pb[(e + 1) % n].x, pb[(e + 1) % n].y, b["z"])
			var out := _edge_outward(pa, e)
			face([a0, a1, b1, b0], out, mat, tag, solid)


## Skin over a flat or nearly flat face given by its corners in order (3 or 4 of them).
## A four-cornered face that isn't flat is split into two triangles.
func face(corners: Array, outward: Vector3, mat: Material, tag: String = "", solid: bool = true) -> void:
	var pts := PackedVector3Array()
	for c: Vector3 in corners:
		if pts.is_empty() or pts[pts.size() - 1].distance_to(c) > 0.001:
			pts.append(c)
	if pts.size() > 3 and pts[0].distance_to(pts[pts.size() - 1]) < 0.001:
		pts.remove_at(pts.size() - 1)
	if pts.size() < 3:
		return
	if pts.size() == 4 and not _flat(pts):
		face([pts[0], pts[1], pts[2]], outward, mat, tag, solid)
		face([pts[0], pts[2], pts[3]], outward, mat, tag, solid)
		return
	var made := FrameParts.plate_between(pts, outward, skin)
	kit.add(made[0], made[1], mat, tag, null, solid)


## An end cap at station z: plates over each convex outline (x, y) in `pieces`, facing
## `facing` (-1 = forward, +1 = aft).
func cap(z: float, pieces: Array, facing: float, mat: Material, tag: String = "") -> void:
	for outline: PackedVector2Array in pieces:
		var pts: Array = []
		for p in outline:
			pts.append(Vector3(p.x, p.y, z))
		face(pts, Vector3(0, 0, facing), mat, tag)


func _build_frames() -> void:
	var inward := skin + frame_height * 0.5
	# The first and last rings sit a little way in from the ends, so their girders and
	# nodes don't poke through the end caps.
	var end_inset := maxf(node_size, frame_width) * 0.5 + skin
	var nodes: Dictionary = {}
	var ring_points: Array[PackedVector3Array] = []
	for k in stations.size():
		var st: Dictionary = stations[k]
		var z: float = st["z"]
		if stations.size() > 1 and (k == 0 or k == stations.size() - 1):
			var other: float = stations[1 if k == 0 else k - 1]["z"]
			z += signf(other - z) * end_inset
		var inner := FrameParts.inset(st["profile"], inward)
		var pts := PackedVector3Array()
		for p in inner:
			pts.append(Vector3(p.x, p.y, z))
		ring_points.append(pts)
	for k in ring_points.size():
		var ring := ring_points[k]
		var n := ring.size()
		for i in n:
			# Ring girder, height facing out of the hull (up = toward the outer skin).
			nodes[ring[i]] = true
			if frame_skip.is_valid() and frame_skip.call(k, i):
				continue
			var a := ring[i]
			var b := ring[(i + 1) % n]
			var mid := (a + b) * 0.5
			var centre := _centre(ring)
			var made := FrameParts.girder_between(a, b, frame_width, frame_height, mid - centre)
			kit.add(made[0], made[1], frame_mat, "", null, false)
			nodes[a] = true
		if k + 1 < ring_points.size():
			var next := ring_points[k + 1]
			for i in n:
				var made := FrameParts.girder_between(ring[i], next[i], frame_width, frame_height,
						ring[i] - _centre(ring))
				kit.add(made[0], made[1], frame_mat, "", null, false)
	var node := FrameParts.node(node_size)
	for p: Vector3 in nodes:
		kit.add(node, Transform3D(Basis(), p), frame_mat, "", null, false)


## The way out of the hull across edge `e` of a profile.
static func _edge_outward(profile: PackedVector2Array, e: int) -> Vector3:
	var n := profile.size()
	var c := Vector2.ZERO
	for p in profile:
		c += p
	c /= float(n)
	var a := profile[e]
	var b := profile[(e + 1) % n]
	var d := b - a
	var nrm := Vector2(d.y, -d.x).normalized()
	if nrm.dot((a + b) * 0.5 - c) < 0.0:
		nrm = -nrm
	return Vector3(nrm.x, nrm.y, 0.0)


static func _flat(pts: PackedVector3Array) -> bool:
	var n := (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
	return absf(n.dot(pts[3] - pts[0])) < 0.002


static func _centre(pts: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	return c / float(pts.size())
