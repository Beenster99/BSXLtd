class_name DesignOutside
extends RefCounted
## Parts fitted anywhere on the outside of the hull (plan 3.10, the outside designer, stage 3):
## on the roof, the belly, the shoulders and chines, the sides, the nose and the stern, picked
## in 3D on the skin DesignFrame proposes. A part placed this way is a mount with "face" =
## "skin", anchored to the skin rather than to a point in space, so it rides the hull when the
## rooms or the sections change:
##   {id, type, face: "skin", edge, z, t, spin, x, y?, deck}
##     edge 0..7: the section's edge it sits on (DesignFrame.SIDES: 0 roof, 2 starboard, 4 belly,
##       6 port, odd ones the chamfers), z along the ship and t across the edge (0 at its first
##       corner, 1 at its next); NOSE (-1) or STERN (-2): the end plate at the front or back,
##       x and y on it.
##     spin: turned about the hull's outward normal, radians.
##     stand: true stands it on its foot (an antenna, a mast, a turret on the roof), false fits it
##       by its back with its front out (a thruster anywhere, any part on a side); absent: it
##       stands on the roof and belly unless it pushes (thrust) or is a nozzle.
##     x, z and deck are also kept where it was placed, for the plan views and the build order.
## A mount without "face" is the older kind: on the side of a deck's hull outline (DesignRules).
##
##   var hit := DesignOutside.pick(plan, origin, dir)   # {point, normal, edge, z, t | x, y}
##   var m := DesignOutside.anchor(hit)                 # the mount's fields for add_mount
##   var xf := DesignOutside.transform(plan, m, pt, d)  # where walk-inside, the holotable and the bots put it

const NOSE := -1
const STERN := -2
## Between the skin and the part's back, m.
const GAP := 0.01
## Clear space a part wants in front of it, m: an engine's or thruster's plume more.
const FRONT_CLEAR := 0.5
const PLUME_CLEAR := 2.0
## How far a corner of a part's back may stand off the skin before it overhangs an edge, m.
const OVERHANG := 0.12


## The proposed frame for `d`, kept while the design's shape is unchanged (the build module,
## the rules and the views all ask for it once per part).
static func plan_for(d: DesignRecord) -> Dictionary:
	var key := hash([d.rooms, d.hull, d.frame_edits, d.structure, d.doors, d.deck_height, d.livery, d.shapes])
	if _memo.get("key", -1) == key and _memo.get("d") == d:
		return _memo.plan
	var p := DesignFrame.propose(d)
	_memo = {"key": key, "d": d, "plan": p}
	return p


static var _memo := {}


## Whether a mount is fitted to the skin (else it is on a deck's hull outline).
static func on_skin(m: Dictionary) -> bool:
	return str(m.get("face", "")) == "skin"


## The skin's faces: [{edge, z0, z1, quad: [p0, p1, p2, p3]}] for each bay and edge, and the two
## end plates as {edge: NOSE | STERN, z, poly}.
static func faces(plan: Dictionary) -> Array:
	var out: Array = []
	var st: Array = plan.get("stations", [])
	for i in range(1, st.size()):
		var a: PackedVector2Array = st[i - 1].profile
		var b: PackedVector2Array = st[i].profile
		var za := float(st[i - 1].z)
		var zb := float(st[i].z)
		for k in a.size():
			var k1 := (k + 1) % a.size()
			out.append({"edge": k, "z0": za, "z1": zb, "quad": [Vector3(a[k].x, a[k].y, za),
					Vector3(a[k1].x, a[k1].y, za), Vector3(b[k1].x, b[k1].y, zb), Vector3(b[k].x, b[k].y, zb)]})
	if not st.is_empty():
		out.append({"edge": NOSE, "z": float(st[0].z), "poly": st[0].profile})
		out.append({"edge": STERN, "z": float(st[st.size() - 1].z), "poly": st[st.size() - 1].profile})
	return out


## Where a ray (ship space) first meets the skin from outside: {point, normal (out), edge, z,
## t} on a side face, {point, normal, edge (NOSE or STERN), x, y} on an end plate; {} if it
## misses.
static func pick(plan: Dictionary, origin: Vector3, dir: Vector3) -> Dictionary:
	var best := {}
	var best_d := INF
	dir = dir.normalized()
	for f: Dictionary in faces(plan):
		if f.has("quad"):
			var q: Array = f.quad
			for tri: Array in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
				var hit: Variant = Geometry3D.ray_intersects_triangle(origin, dir, tri[0], tri[1], tri[2])
				if hit == null:
					continue
				var dist := origin.distance_to(hit)
				if dist < best_d:
					best_d = dist
					best = _side_hit(plan, f, hit as Vector3)
		else:
			var z := float(f.z)
			if is_zero_approx(dir.z):
				continue
			var s := (z - origin.z) / dir.z
			if s <= 0.0:
				continue
			var hit := origin + dir * s
			if not Geometry2D.is_point_in_polygon(Vector2(hit.x, hit.y), f.poly):
				continue
			if s < best_d:
				best_d = s
				best = {"point": hit, "normal": Vector3(0, 0, -1 if int(f.edge) == NOSE else 1),
						"edge": int(f.edge), "x": hit.x, "y": hit.y, "z": z}
	return best


static func _side_hit(plan: Dictionary, f: Dictionary, p: Vector3) -> Dictionary:
	var k := int(f.edge)
	var ends := _edge_at(plan, k, p.z)
	var a: Vector2 = ends[0]
	var b: Vector2 = ends[1]
	var t := clampf(Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.y), a, b).distance_to(a) / maxf(a.distance_to(b), 0.001), 0.0, 1.0)
	var s := surface(plan, {"face": "skin", "edge": k, "z": p.z, "t": t})
	s["edge"] = k
	s["z"] = p.z
	s["t"] = t
	return s


## The two corners of edge `k` of the section at z, between the stations either side (x, y).
static func _edge_at(plan: Dictionary, k: int, z: float) -> Array:
	var st: Array = plan.get("stations", [])
	if st.is_empty():
		return [Vector2.ZERO, Vector2.ZERO]
	z = clampf(z, float(st[0].z), float(st[st.size() - 1].z))
	var i := maxi(DesignFrame.bay_at(plan, z), 0)
	var j := mini(i + 1, st.size() - 1)
	var za := float(st[i].z)
	var zb := float(st[j].z)
	var s := 0.0 if is_equal_approx(za, zb) else (z - za) / (zb - za)
	var pa: PackedVector2Array = st[i].profile
	var pb: PackedVector2Array = st[j].profile
	var k1 := (k + 1) % pa.size()
	return [pa[k].lerp(pb[k], s), pa[k1].lerp(pb[k1], s)]


## Where a skin mount's anchor is on the skin now: {point, normal (out)}; {} without a frame.
static func surface(plan: Dictionary, m: Dictionary) -> Dictionary:
	var st: Array = plan.get("stations", [])
	if st.is_empty():
		return {}
	var edge := int(m.get("edge", 0))
	if edge == NOSE or edge == STERN:
		var z := float(st[0 if edge == NOSE else st.size() - 1].z)
		return {"point": Vector3(float(m.get("x", 0.0)), float(m.get("y", 0.0)), z),
				"normal": Vector3(0, 0, -1 if edge == NOSE else 1)}
	var z := float(m.get("z", 0.0))
	var ends := _edge_at(plan, edge, z)
	var a: Vector2 = ends[0]
	var b: Vector2 = ends[1]
	var p := a.lerp(b, clampf(float(m.get("t", 0.5)), 0.0, 1.0))
	# Out from the section: the edge's normal in x y, leaned fore or aft where the hull tapers.
	var along := (b - a).normalized()
	var n2 := Vector2(along.y, -along.x)
	var c: Vector2 = _centre(plan, z)
	if n2.dot(p - c) < 0.0:
		n2 = -n2
	var lean := _taper(plan, edge, z, n2)
	var n := Vector3(n2.x, n2.y, lean).normalized()
	return {"point": Vector3(p.x, p.y, z), "normal": n}


static func _centre(plan: Dictionary, z: float) -> Vector2:
	var st: Array = plan.stations
	var i := DesignFrame.station_at(plan, z)
	return (st[i].rect as Rect2).get_center()


## How far the face leans fore (-) or aft (+) where the section changes from station to station:
## the outward move per metre along z, negated, so the normal stays square to the face.
static func _taper(plan: Dictionary, edge: int, z: float, n2: Vector2) -> float:
	var st: Array = plan.stations
	var i := maxi(DesignFrame.bay_at(plan, clampf(z, float(st[0].z), float(st[st.size() - 1].z))), 0)
	var j := mini(i + 1, st.size() - 1)
	if i == j:
		return 0.0
	var pa: PackedVector2Array = st[i].profile
	var pb: PackedVector2Array = st[j].profile
	var mid_a := (pa[edge] + pa[(edge + 1) % pa.size()]) * 0.5
	var mid_b := (pb[edge] + pb[(edge + 1) % pb.size()]) * 0.5
	var dz := float(st[j].z) - float(st[i].z)
	return -(mid_b - mid_a).dot(n2) / dz


## A pick as a new skin mount's fields (type and id to add): its anchor, and where it is in plan.
static func anchor(hit: Dictionary, d: DesignRecord = null) -> Dictionary:
	if hit.is_empty():
		return {}
	var p: Vector3 = hit.point
	var m := {"face": "skin", "edge": int(hit.edge), "spin": 0.0, "x": snappedf(p.x, 0.01), "z": snappedf(p.z, 0.01),
			"y": snappedf(p.y, 0.01), "angle": Vector2((hit.normal as Vector3).x, (hit.normal as Vector3).z).angle()}
	if int(hit.edge) >= 0:
		m["t"] = snappedf(float(hit.t), 0.001)
		m["z"] = snappedf(float(hit.z), 0.01)
	m["deck"] = deck_of(d, p.y) if d else 0
	return m


## The deck a height is on (the lowest or the top one past the hull's ends).
static func deck_of(d: DesignRecord, y: float) -> int:
	var decks := d.decks()
	if decks.is_empty():
		return 0
	var k := floori(y / maxf(d.deck_height, 0.1))
	return clampi(k, int(decks[0]), int(decks[decks.size() - 1]))


## Which part of the hull a skin mount is on, as the designers say it.
static func face_name(m: Dictionary) -> String:
	var e := int(m.get("edge", 0))
	if e == NOSE:
		return "nose"
	if e == STERN:
		return "stern"
	return DesignFrame.EDGE_NAMES[e % DesignFrame.SIDES]


## Where a part fitted to the skin is: its own space as DesignRules.mount_transform gives it
## (origin on its foot in the middle, front -Z out along the hull's normal, up the ship's up on
## the sides and towards the bow on the roof and belly, then turned `spin` about the normal). A
## landing leg on the belly hangs straight down from it.
static func transform(plan: Dictionary, m: Dictionary, pt: DesignPartType) -> Transform3D:
	var s := surface(plan, m)
	if s.is_empty():
		return Transform3D.IDENTITY
	var p: Vector3 = s.point
	var n: Vector3 = s.normal
	var spin := float(m.get("spin", 0.0))
	if pt.under_hull():
		var yaw := Basis(Vector3.UP, spin)
		return Transform3D(yaw, p + Vector3(0, -pt.size.y, 0))
	if standing(m, pt, n):
		# On its foot: up along the normal, its front towards the bow (or up the ship's side).
		var ahead := Vector3.FORWARD if absf(n.z) < 0.7 else Vector3.UP
		ahead = (ahead - n * ahead.dot(n)).normalized()
		var b := Basis(n.cross(-ahead).normalized(), n, -ahead)
		b = Basis(n, spin) * b
		return Transform3D(b, p + n * GAP)
	var up := Vector3.UP if absf(n.y) < 0.7 else Vector3.FORWARD
	var basis := Basis.looking_at(n, up)
	basis = Basis(n, spin) * basis
	var centre := p + n * (pt.size.z * 0.5 + GAP)
	return Transform3D(basis, centre - basis.y * pt.size.y * 0.5)


## Whether a part on the skin stands on its foot (else it is fitted by its back, front out).
static func standing(m: Dictionary, pt: DesignPartType, n: Vector3) -> bool:
	if m.has("stand"):
		return bool(m.stand)
	return absf(n.y) >= 0.7 and pt.thrust <= 0.0 and not pt.nozzle_down and not pt.under_hull()


## The skin's outward normal under a skin mount, and whether it stands: [normal, stand].
static func _how(plan: Dictionary, m: Dictionary, pt: DesignPartType) -> Array:
	var s := surface(plan, m)
	var n: Vector3 = s.get("normal", Vector3.UP)
	return [n, standing(m, pt, n)]


## A part's box (its middle's transform, and its size) where it is fitted.
static func box_of(xf: Transform3D, pt: DesignPartType) -> Array:
	return [xf * Transform3D(Basis.IDENTITY, Vector3(0, pt.size.y * 0.5, 0)), pt.size]


## The clear space a part wants in front of it: its face's size, FRONT_CLEAR deep (an engine or
## thruster: PLUME_CLEAR), just in front of it (over it when it stands).
static func front_box(xf: Transform3D, pt: DesignPartType, stand := false) -> Array:
	var deep := PLUME_CLEAR if pt.thrust > 0.0 else FRONT_CLEAR
	if stand:
		var up := xf * Transform3D(Basis.IDENTITY, Vector3(0, pt.size.y + 0.05 + deep * 0.5, 0))
		return [up, Vector3(pt.size.x * 0.9, deep, pt.size.z * 0.9)]
	var c := xf * Transform3D(Basis.IDENTITY, Vector3(0, pt.size.y * 0.5, -pt.size.z * 0.5 - 0.05 - deep * 0.5))
	return [c, Vector3(pt.size.x * 0.9, pt.size.y * 0.9, deep)]


## Whether two boxes (a middle's transform and a size each) overlap: separating axes.
static func boxes_overlap(a: Transform3D, sa: Vector3, b: Transform3D, sb: Vector3, margin := 0.0) -> bool:
	var ax: Array[Vector3] = [a.basis.x.normalized(), a.basis.y.normalized(), a.basis.z.normalized()]
	var bx: Array[Vector3] = [b.basis.x.normalized(), b.basis.y.normalized(), b.basis.z.normalized()]
	var ha := sa * 0.5 - Vector3.ONE * margin
	var hb := sb * 0.5 - Vector3.ONE * margin
	var axes: Array[Vector3] = []
	axes.append_array(ax)
	axes.append_array(bx)
	for u in ax:
		for v in bx:
			var c := u.cross(v)
			if c.length_squared() > 1e-6:
				axes.append(c.normalized())
	var t := b.origin - a.origin
	for l in axes:
		var ra := absf(ax[0].dot(l)) * ha.x + absf(ax[1].dot(l)) * ha.y + absf(ax[2].dot(l)) * ha.z
		var rb := absf(bx[0].dot(l)) * hb.x + absf(bx[1].dot(l)) * hb.y + absf(bx[2].dot(l)) * hb.z
		if absf(t.dot(l)) > ra + rb:
			return false
	return true


## Whether a skin mount's anchor is still on the hull (the hull may have shrunk from under it).
static func on_hull(plan: Dictionary, m: Dictionary) -> bool:
	var st: Array = plan.get("stations", [])
	if st.is_empty():
		return false
	var e := int(m.get("edge", 0))
	if e == NOSE or e == STERN:
		var poly: PackedVector2Array = st[0 if e == NOSE else st.size() - 1].profile
		return Geometry2D.is_point_in_polygon(Vector2(float(m.get("x", 0.0)), float(m.get("y", 0.0))), poly)
	var z := float(m.get("z", 0.0))
	return z >= float(st[0].z) - 0.01 and z <= float(st[st.size() - 1].z) + 0.01


## The corners of a part's back (its foot when it stands) that stand off the skin by more than
## OVERHANG (it hangs past an edge of the hull: off the roof, past the nose); 0 when it sits flat.
static func overhang(plan: Dictionary, m: Dictionary, xf: Transform3D, pt: DesignPartType) -> int:
	if pt.under_hull():
		return 0
	var how := _how(plan, m, pt)
	var n: Vector3 = how[0]
	var out := 0
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var back: Vector3
		if how[1]:
			back = xf * Vector3(c.x * pt.size.x * 0.45, 0.0, c.y * pt.size.z * 0.45)
		else:
			back = xf * Vector3(c.x * pt.size.x * 0.45, (c.y + 1.0) * 0.5 * pt.size.y * 0.9 + 0.05 * (1.0 - c.y) * 0.5, pt.size.z * 0.5)
		var hit := pick(plan, back + n * 0.05, -n)
		if hit.is_empty() or (hit.point as Vector3).distance_to(back) > OVERHANG + GAP + 0.05:
			out += 1
	return out


## Whether the space in front of a part runs into the hull (a part fitted in a corner facing
## back across the ship).
static func front_blocked(plan: Dictionary, m: Dictionary, xf: Transform3D, pt: DesignPartType) -> bool:
	if pt.under_hull():
		return false
	var how := _how(plan, m, pt)
	var fb := front_box(xf, pt, how[1])
	var c: Transform3D = fb[0]
	var size: Vector3 = fb[1]
	var deep: float = size.y if how[1] else size.z
	var n: Vector3 = (xf.basis.y if how[1] else -xf.basis.z).normalized()
	var from := c.origin - n * deep * 0.5
	var hit := pick(plan, from, n)
	return not hit.is_empty() and (hit.point as Vector3).distance_to(from) < deep


## The clear space in front of a mount as a box, [middle, size]; [] for one on a deck's outline.
static func clear_box(plan: Dictionary, m: Dictionary, xf: Transform3D, pt: DesignPartType) -> Array:
	if not on_skin(m) or pt.under_hull():
		return []
	return front_box(xf, pt, _how(plan, m, pt)[1])
