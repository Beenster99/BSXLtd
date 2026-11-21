class_name DesignFree
extends RefCounted
## Free structure (beenster, 21 Nov: "there is no such thing as a wing or a fin or a nosecone -
## there is just beams and plates, arranged in a way that we define what they are"): beams laid
## anywhere in 3D between two points, turned about their own length, and plates spanned across
## three or four of their ends. Whatever shape the crew make of them is theirs: a wing, a fin, a
## cowl, a strake. Placing snaps to a grid, to beam ends, to points along beams and to the hull's
## own frame corners, and guidelines show when a point lines up with another along an axis.
##
## Record (DesignRecord): beams[id] = {id, a: [x, y, z], b: [x, y, z], roll (rad), size}
## in `free_beams` (ids "g"), plates[id] = {id, pts: [[x, y, z] x3..4], kind, paint?} in
## `free_plates` (ids "p"). Ship space: x across (+ starboard), y up from deck 0's floor, z along
## (- forward), as the frame plan.

## Beam sections: name, width x height (m), kg per metre, cost per metre.
const SIZES := {
	"light": {"name": "Light", "w": 0.1, "h": 0.12, "kg_m": 9.0, "cost_m": 60},
	"medium": {"name": "Medium", "w": 0.14, "h": 0.18, "kg_m": 18.0, "cost_m": 110},
	"heavy": {"name": "Heavy", "w": 0.2, "h": 0.26, "kg_m": 34.0, "cost_m": 190},
}
const SIZE_ORDER: PackedStringArray = ["light", "medium", "heavy"]
## Plate kinds: name, thickness (m), kg per m2, cost per m2.
const PLATES := {
	"metal": {"name": "Metal", "t": 0.04, "kg_m2": 32.0, "cost_m2": 90},
	"armour": {"name": "Armour", "t": 0.08, "kg_m2": 95.0, "cost_m2": 260},
	"glass": {"name": "Glass", "t": 0.05, "kg_m2": 28.0, "cost_m2": 180},
}
const PLATE_ORDER: PackedStringArray = ["metal", "armour", "glass"]
## Grid steps a crew can snap to (m).
const GRIDS: Array[float] = [0.1, 0.25, 0.5, 1.0]
## Roll steps (rad): R turns a beam this far about its length.
const ROLL_STEP := PI / 12.0
## How near a point must come to a node or a beam to snap to it (m).
const SNAP := 0.3
## How near two coordinates must be to line up on a guideline (m).
const ALIGN := 0.12
## Ends this close are one node (welded together).
const JOIN := 0.03
const MIN_BEAM := 0.2


static func v3(a: Variant) -> Vector3:
	if a is Vector3:
		return a
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2])) if arr.size() >= 3 else Vector3.ZERO


static func arr(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


static func size_of(beam: Dictionary) -> Dictionary:
	return SIZES.get(str(beam.get("size", "medium")), SIZES.medium)


static func plate_of(plate: Dictionary) -> Dictionary:
	return PLATES.get(str(plate.get("kind", "metal")), PLATES.metal)


static func length(beam: Dictionary) -> float:
	return v3(beam.a).distance_to(v3(beam.b))


## Where a beam goes: X along it a to b, its height turned `roll` about X from the up nearest
## the world's, origin in its middle.
static func beam_xf(beam: Dictionary) -> Transform3D:
	var a := v3(beam.a)
	var b := v3(beam.b)
	var xf := FrameParts.along(a, b, Vector3.UP)
	xf.basis = xf.basis * Basis(Vector3.RIGHT, float(beam.get("roll", 0.0)))
	return xf


## A plate's corners (ship space), in order.
static func corners(plate: Dictionary) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Variant in plate.get("pts", []):
		out.append(v3(p))
	return out


static func plate_normal(pts: PackedVector3Array) -> Vector3:
	var n := Vector3.ZERO
	for i in pts.size():
		n += pts[i].cross(pts[(i + 1) % pts.size()])
	return n.normalized() if n.length() > 0.0001 else Vector3.UP


static func plate_area(pts: PackedVector3Array) -> float:
	var n := Vector3.ZERO
	for i in pts.size():
		n += pts[i].cross(pts[(i + 1) % pts.size()])
	return n.length() * 0.5


## Three or four corners, none on top of another, the fourth on the plane of the first three
## (within 8 cm) and the outline convex.
static func plate_ok(pts: PackedVector3Array) -> bool:
	if pts.size() < 3 or pts.size() > 4:
		return false
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			if pts[i].distance_to(pts[j]) < 0.1:
				return false
	if plate_area(pts) < 0.02:
		return false
	if pts.size() == 4:
		var pl := Plane(pts[0], pts[1], pts[2])
		if absf(pl.distance_to(pts[3])) > 0.08:
			return false
		var n := plate_normal(pts)
		for i in 4:
			var e := pts[(i + 1) % 4] - pts[i]
			var f := pts[(i + 2) % 4] - pts[(i + 1) % 4]
			if e.cross(f).dot(n) <= 0.0:
				return false
	return true


# Snapping ----------------------------------------------------------------------------------

## Every point a beam can end on: the free beams' ends and plates' corners, and the hull frame's
## corners (each station's profile corners, where its rings meet its stringers).
static func nodes(d: DesignRecord, fp: Dictionary) -> PackedVector3Array:
	var out := PackedVector3Array()
	if d:
		for b: Dictionary in d.free_beams.values():
			_add_node(out, v3(b.a))
			_add_node(out, v3(b.b))
		for p: Dictionary in d.free_plates.values():
			for c in corners(p):
				_add_node(out, c)
	for st: Dictionary in fp.get("stations", []):
		var pr: PackedVector2Array = st.profile
		for c in pr:
			_add_node(out, Vector3(c.x, c.y, float(st.z)))
	return out


static func _add_node(out: PackedVector3Array, p: Vector3) -> void:
	for q in out:
		if q.distance_to(p) < JOIN:
			return
	out.append(p)


## Where a point `raw` (ship space) lands: on a node within SNAP, else on a beam within SNAP (at
## a grid step along it), else on the grid, pulled into line with any node it nearly lines up
## with. {point, kind ("node", "beam", "grid"), id (the beam's), guides: [[from, to], ...]}.
static func place(d: DesignRecord, fp: Dictionary, raw: Vector3, grid: float) -> Dictionary:
	var ns := nodes(d, fp)
	var best_d := SNAP
	var hit := {}
	for n in ns:
		var dd := n.distance_to(raw)
		if dd < best_d:
			best_d = dd
			hit = {"point": n, "kind": "node", "id": ""}
	if hit.is_empty() and d:
		for b: Dictionary in d.free_beams.values():
			var a := v3(b.a)
			var e := v3(b.b)
			var q := Geometry3D.get_closest_point_to_segment(raw, a, e)
			var dd := q.distance_to(raw)
			if dd < best_d:
				var len := a.distance_to(e)
				var t := clampf(snappedf(a.distance_to(q), maxf(grid, 0.05)), 0.0, len)
				best_d = dd
				hit = {"point": a + (e - a).normalized() * t, "kind": "beam", "id": str(b.id)}
	if hit.is_empty():
		var g := maxf(grid, 0.01)
		var p := Vector3(snappedf(raw.x, g), snappedf(raw.y, g), snappedf(raw.z, g))
		# Into line with a node it nearly shares two coordinates with.
		for n in ns:
			for ax in 3:
				var o1 := (ax + 1) % 3
				var o2 := (ax + 2) % 3
				if absf(raw[o1] - n[o1]) < ALIGN and absf(raw[o2] - n[o2]) < ALIGN:
					p[o1] = n[o1]
					p[o2] = n[o2]
		hit = {"point": p, "kind": "grid", "id": ""}
	hit["guides"] = guides(ns, hit.point)
	return hit


## Guidelines through `p`: to every node it lines up with along x, y or z (both other
## coordinates within a centimetre), nearest few first. [[node, p, axis], ...].
static func guides(ns: PackedVector3Array, p: Vector3) -> Array:
	var out: Array = []
	for n in ns:
		if n.distance_to(p) < JOIN:
			continue
		for ax in 3:
			var o1 := (ax + 1) % 3
			var o2 := (ax + 2) % 3
			if absf(p[o1] - n[o1]) < 0.01 and absf(p[o2] - n[o2]) < 0.01:
				out.append([n, p, ax])
	out.sort_custom(func(x: Array, y: Array) -> bool: return (x[0] as Vector3).distance_to(p) < (y[0] as Vector3).distance_to(p))
	return out.slice(0, 6)


## The point a ray (ship space) aims at to place by: a node it passes close to, else where it
## meets her skin, else where it crosses the work plane through `anchor` (the last point placed:
## the axis plane most square to the ray), else `reach` metres along it. Then `place`.
static func from_ray(d: DesignRecord, fp: Dictionary, from: Vector3, dir: Vector3, anchor: Variant,
		grid: float, reach := 8.0, surface: Variant = null) -> Dictionary:
	dir = dir.normalized()
	var best := INF
	var raw: Variant = null
	for n in nodes(d, fp):
		var t := (n - from).dot(dir)
		if t <= 0.0:
			continue
		var off := (from + dir * t).distance_to(n)
		if off < 0.12 + t * 0.01 and t < best:
			best = t
			raw = n
	if raw == null and surface is Vector3:
		raw = surface
	if raw == null and not fp.is_empty():
		var skin := DesignOutside.pick(fp, from, dir)
		if not skin.is_empty():
			raw = skin.point
	if raw == null and anchor is Vector3:
		var ax := 0
		for i in 3:
			if absf(dir[i]) > absf(dir[ax]):
				ax = i
		var nrm := Vector3.ZERO
		nrm[ax] = 1.0
		var hit: Variant = Plane(nrm, (anchor as Vector3)[ax]).intersects_ray(from, dir)
		if hit is Vector3 and from.distance_to(hit) < reach * 4.0:
			raw = hit
	if raw == null:
		raw = from + dir * reach
	return place(d, fp, raw, grid)


# Picking -----------------------------------------------------------------------------------

## The free beam or plate a ray meets first: {kind ("beam" or "plate"), id, dist}, {}.
static func pick(d: DesignRecord, from: Vector3, dir: Vector3) -> Dictionary:
	var best := {}
	if d == null:
		return best
	dir = dir.normalized()
	for b: Dictionary in d.free_beams.values():
		var a := v3(b.a)
		var e := v3(b.b)
		var r := maxf(float(size_of(b).h), 0.12)
		var pts := Geometry3D.get_closest_points_between_segments(from, from + dir * 200.0, a, e)
		if (pts[0] as Vector3).distance_to(pts[1]) < r:
			var dist := from.distance_to(pts[0])
			if best.is_empty() or dist < float(best.dist):
				best = {"kind": "beam", "id": str(b.id), "dist": dist}
	for p: Dictionary in d.free_plates.values():
		var cs := corners(p)
		for i in range(1, cs.size() - 1):
			var hit: Variant = Geometry3D.ray_intersects_triangle(from, dir, cs[0], cs[i], cs[i + 1])
			if hit is Vector3:
				var dist := from.distance_to(hit)
				if best.is_empty() or dist < float(best.dist) - 0.05:
					best = {"kind": "plate", "id": str(p.id), "dist": dist}
	return best


## From a built part's path ("free/g12", "free/p3"): {kind, id}, {} for any other part.
static func of_path(path: String) -> Dictionary:
	if not path.begins_with("free/"):
		return {}
	var id := path.get_slice("/", 1)
	if id.begins_with("g"):
		return {"kind": "beam", "id": id}
	if id.begins_with("p"):
		return {"kind": "plate", "id": id}
	return {}


# Measuring ---------------------------------------------------------------------------------

## Metres of beam, square metres and count of plates, mass (kg) and cost.
static func counts(d: DesignRecord) -> Dictionary:
	return counts_of(d.free_beams if d else {}, d.free_plates if d else {})


static func counts_of(beams: Dictionary, plates: Dictionary) -> Dictionary:
	var c := {"beams": 0, "beam_m": 0.0, "plates": 0, "plate_m2": 0.0, "kg": 0.0, "cost": 0.0, "welds": 0, "rivets": 0}
	for b: Dictionary in beams.values():
		var s := size_of(b)
		var len := length(b)
		c.beams += 1
		c.beam_m += len
		c.kg += len * float(s.kg_m)
		c.cost += len * float(s.cost_m)
		c.welds += 2
	for p: Dictionary in plates.values():
		var k := plate_of(p)
		var area := plate_area(corners(p))
		c.plates += 1
		c.plate_m2 += area
		c.kg += area * float(k.kg_m2)
		c.cost += area * float(k.cost_m2)
		c.rivets += (p.pts as Array).size() * 2
	return c


## The box every free beam and plate takes up (ship space), or an empty AABB.
static func extent(d: DesignRecord) -> AABB:
	var box := AABB()
	var first := true
	if d == null:
		return box
	for b: Dictionary in d.free_beams.values():
		for p: Vector3 in [v3(b.a), v3(b.b)]:
			box = AABB(p, Vector3.ZERO) if first else box.expand(p)
			first = false
	for pl: Dictionary in d.free_plates.values():
		for p in corners(pl):
			box = AABB(p, Vector3.ZERO) if first else box.expand(p)
			first = false
	return box


## Free beams and plates that do not reach the hull through other beams and plates: groups
## of ids adrift (WILL IT WORK).
static func adrift(d: DesignRecord, fp: Dictionary) -> Array:
	if d == null or (d.free_beams.is_empty() and d.free_plates.is_empty()):
		return []
	var hull_nodes := PackedVector3Array()
	for st: Dictionary in fp.get("stations", []):
		for c: Vector2 in (st.profile as PackedVector2Array):
			hull_nodes.append(Vector3(c.x, c.y, float(st.z)))
	var ids: Array = d.free_beams.keys() + d.free_plates.keys()
	var pts := {}
	for id: String in d.free_beams:
		pts[id] = [v3(d.free_beams[id].a), v3(d.free_beams[id].b)]
	for id: String in d.free_plates:
		pts[id] = Array(corners(d.free_plates[id]))
	var held := {}
	var frontier: Array = []
	for id: String in ids:
		for p: Vector3 in pts[id]:
			if _on_hull(fp, hull_nodes, p):
				held[id] = true
				frontier.append(id)
				break
	while not frontier.is_empty():
		var cur: String = frontier.pop_back()
		for id: String in ids:
			if held.has(id):
				continue
			if _touch(d, cur, id, pts):
				held[id] = true
				frontier.append(id)
	var loose: Array = []
	for id: String in ids:
		if not held.has(id):
			loose.append(id)
	return loose


static func _on_hull(fp: Dictionary, hull_nodes: PackedVector3Array, p: Vector3) -> bool:
	for n in hull_nodes:
		if n.distance_to(p) < 0.35:
			return true
	var st: Array = fp.get("stations", [])
	if st.is_empty():
		return false
	var z0 := float(st[0].z)
	var z1 := float(st[st.size() - 1].z)
	if p.z < z0 - 0.3 or p.z > z1 + 0.3:
		return false
	var pr: PackedVector2Array = st[DesignFrame.station_at(fp, p.z)].profile
	for i in pr.size():
		var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.y), pr[i], pr[(i + 1) % pr.size()])
		if q.distance_to(Vector2(p.x, p.y)) < 0.35:
			return true
	return false


## Whether two free items touch: an end or corner of one on the other's end, corner or length.
static func _touch(d: DesignRecord, a: String, b: String, pts: Dictionary) -> bool:
	for p: Vector3 in pts[a]:
		if _near_item(d, b, p, pts):
			return true
	for p: Vector3 in pts[b]:
		if _near_item(d, a, p, pts):
			return true
	return false


static func _near_item(d: DesignRecord, id: String, p: Vector3, pts: Dictionary) -> bool:
	var ps: Array = pts[id]
	for i in ps.size():
		var q := Geometry3D.get_closest_point_to_segment(p, ps[i], ps[(i + 1) % ps.size()] if d.free_plates.has(id) else ps[1])
		if q.distance_to(p) < 0.05:
			return true
	return false


# Building ----------------------------------------------------------------------------------

## Builds every free beam and plate of the plan (its "free_beams" and "free_plates") on `kit`: beams as girders turned to their roll, plates as
## slabs of their kind; beams welded where their ends meet, plates riveted to the beams under
## their edges, and beam ends on her frame bolted to its ring there. Returns the parts by id.
static func build(fp: Dictionary, body: FrameHull, kit: ShipKit, steel: Material,
		glass: Material, plate_mat: Callable) -> Dictionary:
	var made := {}
	var beams: Dictionary = fp.get("free_beams", {})
	var plates: Dictionary = fp.get("free_plates", {})
	var ids := beams.keys()
	ids.sort()
	for id: String in ids:
		var b: Dictionary = beams[id]
		var len := length(b)
		if len < MIN_BEAM * 0.5:
			continue
		var s := size_of(b)
		var shape := PartShapes.girder(len, float(s.w), float(s.h))
		made[id] = kit.part("FreeBeam", PartData.Kind.FRAME, shape, beam_xf(b), steel, "", 0.6, null, "free/" + id)
	var pids := plates.keys()
	pids.sort()
	for id: String in pids:
		var p: Dictionary = plates[id]
		var cs := corners(p)
		if not plate_ok(cs):
			continue
		var k := plate_of(p)
		var n := plate_normal(cs)
		var mid := Vector3.ZERO
		for c in cs:
			mid += c
		mid /= cs.size()
		var t := float(k.t)
		var local := PackedVector3Array()
		for c in cs:
			# Set back a hair from each corner so it never sits inside the beam it rests on.
			var q := c.lerp(mid, 0.01) - mid
			local.append(q + n * t * 0.5)
			local.append(q - n * t * 0.5)
		var shape := PartShapes._hull(local)
		var is_glass := str(p.get("kind", "metal")) == "glass"
		var mat: Material = glass if is_glass else plate_mat.call(p)
		var part_name := "GlassPlate" if is_glass else ("ArmourPlate" if str(p.get("kind", "")) == "armour" else "HullPlate")
		made[id] = kit.part(part_name, PartData.Kind.GLASS if is_glass else PartData.Kind.HULL, shape,
				Transform3D(Basis.IDENTITY, mid), mat, "", 1.0, null, "free/" + id)
	_join_beams(beams, kit, made)
	_join_plates(beams, plates, kit, made)
	_bolt_to_hull(beams, plates, fp, body, kit, made)
	return made


static func _join_beams(beams: Dictionary, kit: ShipKit, made: Dictionary) -> void:
	var ids := beams.keys()
	ids.sort()
	for i in ids.size():
		var a: Dictionary = beams[ids[i]]
		if not made.has(ids[i]):
			continue
		for j in range(i + 1, ids.size()):
			var b: Dictionary = beams[ids[j]]
			if not made.has(ids[j]):
				continue
			var at: Variant = _meet(v3(a.a), v3(a.b), v3(b.a), v3(b.b))
			if at is Vector3:
				var c := kit.join(made[ids[i]], made[ids[j]], ConnectionData.Kind.WELD, at, Vector3.UP,
						Vector3.ZERO, Vector2.ZERO, "free/%s/weld:%s" % [ids[i], ids[j]])
				if c:
					c.phase = "frame"


## Where two beams meet: an end of one on the other (end to end, or on its length), or null.
static func _meet(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> Variant:
	for p: Vector3 in [a0, a1]:
		if Geometry3D.get_closest_point_to_segment(p, b0, b1).distance_to(p) < 0.05:
			return p
	for p: Vector3 in [b0, b1]:
		if Geometry3D.get_closest_point_to_segment(p, a0, a1).distance_to(p) < 0.05:
			return p
	return null


static func _join_plates(beams: Dictionary, plates: Dictionary, kit: ShipKit, made: Dictionary) -> void:
	for pid: String in plates:
		if not made.has(pid):
			continue
		var cs := corners(plates[pid])
		var n := plate_normal(cs)
		for bid: String in beams:
			if not made.has(bid):
				continue
			var b: Dictionary = beams[bid]
			var a := v3(b.a)
			var e := v3(b.b)
			var k := 0
			for i in cs.size():
				var c0 := cs[i]
				var c1 := cs[(i + 1) % cs.size()]
				# The beam lies along this edge (both its ends on the edge's line, overlapping it).
				var on0 := Geometry3D.get_closest_point_to_segment(a, c0, c1).distance_to(a) < 0.06
				var on1 := Geometry3D.get_closest_point_to_segment(e, c0, c1).distance_to(e) < 0.06
				var cov0 := Geometry3D.get_closest_point_to_segment(c0, a, e).distance_to(c0) < 0.06
				var cov1 := Geometry3D.get_closest_point_to_segment(c1, a, e).distance_to(c1) < 0.06
				if (on0 or cov0) and (on1 or cov1):
					for f: float in [0.25, 0.75]:
						var c := kit.join(made[pid], made[bid], ConnectionData.Kind.RIVET, c0.lerp(c1, f), n,
								Vector3.ZERO, Vector2.ZERO, "free/%s/rivet:%s/%d:%d" % [pid, bid, i, k])
						if c:
							c.phase = "skin"
						k += 1
			if k == 0:
				# Only a corner on the beam: one rivet there.
				for c0 in cs:
					if Geometry3D.get_closest_point_to_segment(c0, a, e).distance_to(c0) < 0.06:
						var c := kit.join(made[pid], made[bid], ConnectionData.Kind.RIVET, c0, n,
								Vector3.ZERO, Vector2.ZERO, "free/%s/rivet:%s/c" % [pid, bid])
						if c:
							c.phase = "skin"
						break


## Beam ends (and plate corners) on her frame: bolted to the ring girder of the station there
## (the nearest edge of its section), else to the nearest of her own parts within reach.
static func _bolt_to_hull(beams: Dictionary, plates: Dictionary, fp: Dictionary, body: FrameHull, kit: ShipKit, made: Dictionary) -> void:
	if body == null:
		return
	var st: Array = fp.get("stations", [])
	if st.is_empty():
		return
	var hull_nodes := PackedVector3Array()
	for s: Dictionary in st:
		for c: Vector2 in (s.profile as PackedVector2Array):
			hull_nodes.append(Vector3(c.x, c.y, float(s.z)))
	for id: String in made:
		var ends: Array = []
		if beams.has(id):
			ends = [v3(beams[id].a), v3(beams[id].b)]
		else:
			ends = Array(corners(plates[id]))
		var k := 0
		for p: Vector3 in ends:
			if not _on_hull(fp, hull_nodes, p):
				continue
			var j := DesignFrame.station_at(fp, p.z)
			if absf(float(st[j].z) - p.z) > 0.6 or j >= body.rings.size():
				continue
			var pr: PackedVector2Array = st[j].profile
			var e := _nearest_edge(pr, Vector2(p.x, p.y))
			var ring: PartData = body.rings[j][e] if e >= 0 and e < (body.rings[j] as Array).size() else null
			if ring == null:
				continue
			var out := FrameHull.edge_out(pr, e)
			var c := kit.join(made[id], ring, ConnectionData.Kind.BOLT, p, Vector3(out.x, out.y, 0.0),
					Vector3.ZERO, Vector2.ZERO, "free/%s/bolt:%s/%d" % [id, ring.path, k])
			if c:
				c.phase = "frame"
			k += 1


static func _nearest_edge(pr: PackedVector2Array, p: Vector2) -> int:
	var best := INF
	var edge := -1
	for i in pr.size():
		var q := Geometry2D.get_closest_point_to_segment(p, pr[i], pr[(i + 1) % pr.size()])
		if q.distance_to(p) < best:
			best = q.distance_to(p)
			edge = i
	return edge


# Mirroring ---------------------------------------------------------------------------------

## A point mirrored across the centre line (axis 1) or fore and aft (axis 2).
static func flip3(p: Vector3, axis: int) -> Vector3:
	return Vector3(-p.x, p.y, p.z) if axis == DesignMirror.ACROSS else Vector3(p.x, p.y, -p.z)


## The twin of an add_free_beam / add_free_plate op with symmetry on, or {} where it would land
## on itself (on the centre line).
static func twin(op: Dictionary, axis: int) -> Dictionary:
	if axis == DesignMirror.OFF:
		return {}
	match str(op.get("op", "")):
		"add_free_beam":
			var b: Dictionary = (op.beam as Dictionary).duplicate(true)
			b.erase("id")
			var a := flip3(v3(b.a), axis)
			var e := flip3(v3(b.b), axis)
			if a.distance_to(v3(b.a)) < 0.05 and e.distance_to(v3(b.b)) < 0.05:
				return {}
			b.a = arr(a)
			b.b = arr(e)
			b.roll = -float(b.get("roll", 0.0))
			return {"op": "add_free_beam", "beam": b}
		"add_free_plate":
			var p: Dictionary = (op.plate as Dictionary).duplicate(true)
			p.erase("id")
			var pts: Array = []
			var same := true
			for c: Variant in p.pts:
				var q := flip3(v3(c), axis)
				same = same and q.distance_to(v3(c)) < 0.05
				pts.append(arr(q))
			if same:
				return {}
			pts.reverse()
			p.pts = pts
			return {"op": "add_free_plate", "plate": p}
	return {}


static func with_twin(op: Dictionary, axis: int) -> Dictionary:
	var t := twin(op, axis)
	return op if t.is_empty() else {"op": "batch", "ops": [op, t]}
