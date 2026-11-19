class_name MotionMovers
extends RefCounted
## Every moving part of a design, where it stands and how it is posed as it moves, in design
## space (metres, +X starboard, -Z forward, y up; deck n's floor at n x deck_height).
##
## A mover: {id ("component:c3", "mount:m1", "door:d2"), kind ("component" | "mount" | "door"),
##   ref (its id in the record), type, name, deck, room (a component's), spec (MotionTable),
##   base: Transform3D (the part's own space: floor middle, front -Z), size: Vector3}
## pieces(mover, t): the moving pieces at t (0 stowed or shut, 1 deployed or open) as boxes:
##   [{name, xf: Transform3D (box middle and turn), size: Vector3}]

## The same build-up walk-inside uses (WalkBuild): the hull wall, its lining, the deck plate.
const WALL := 0.14
const LINING := 0.025
const FLOOR := 0.1
## Steps a swept volume is sampled at.
const SWEEP_STEPS := 12


## Every mover in the design (components and hull parts that move, doors with leaves).
static func list(rec: DesignRecord, cat: DesignCatalog) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if rec == null or cat == null:
		return out
	var ids: Array = rec.components.keys()
	ids.sort()
	for cid: String in ids:
		var c: Dictionary = rec.components[cid]
		var pt := cat.part(str(c.type))
		var s := MotionTable.spec(pt)
		var r: Dictionary = rec.rooms.get(str(c.room), {})
		if s.is_empty() or r.is_empty():
			continue
		var f := DesignRules.footprint(c, pt)
		var h := minf(pt.size.y, rec.deck_height - FLOOR)
		var base := Transform3D(Basis(Vector3.UP, int(c.get("rot", 0)) * PI * 0.5),
				Vector3(f.get_center().x, float(r.deck) * rec.deck_height, f.get_center().y))
		out.append({"id": "component:" + cid, "kind": "component", "ref": cid, "type": str(c.type),
				"name": "%s %s" % [pt.display_name, DesignRecord.tag(cid)], "deck": int(r.deck), "room": str(c.room),
				"spec": s, "base": base, "size": Vector3(pt.size.x, h, pt.size.z)})
	ids = rec.mounts.keys()
	ids.sort()
	for mid: String in ids:
		var m: Dictionary = rec.mounts[mid]
		var pt := cat.part(str(m.type))
		var s := MotionTable.spec(pt)
		if s.is_empty():
			continue
		out.append({"id": "mount:" + mid, "kind": "mount", "ref": mid, "type": str(m.type),
				"name": "%s %s" % [pt.display_name, DesignRecord.tag(mid)], "deck": int(m.deck), "room": "",
				"spec": s, "base": mount_base(rec, m, pt), "size": pt.size})
	ids = rec.doors.keys()
	ids.sort()
	for did: String in ids:
		var g: Dictionary = rec.doors[did]
		var s := MotionTable.door_spec(g)
		var base := door_base(rec, g)
		if s.is_empty() or base == Transform3D():
			continue
		var k := DesignCatalog.door_kind(g)
		out.append({"id": "door:" + did, "kind": "door", "ref": did, "type": "door:" + str(g.get("kind", "door")),
				"name": "%s %s" % [str(k.name), DesignRecord.tag(did)], "deck": int(g.get("deck", 0)), "room": str(g.a),
				"spec": s, "base": base, "size": Vector3(DesignCatalog.door_w(g), DesignCatalog.door_h(g), 0.1)})
	return out


## A hull part's own space, as walk-inside fits it (DesignRules.mount_transform): against the
## plating, or a landing leg under the hull's edge.
static func mount_base(rec: DesignRecord, m: Dictionary, pt: DesignPartType) -> Transform3D:
	return DesignRules.mount_transform(rec, m, pt)


## A door's own space: on its wall at floor level, X along the wall, -Z into room a (the side
## a hinged door swings to). Identity when its room is gone.
static func door_base(rec: DesignRecord, g: Dictionary) -> Transform3D:
	var a: Dictionary = rec.rooms.get(str(g.get("a", "")), {})
	if a.is_empty():
		return Transform3D()
	var p := Vector2(float(g.x), float(g.z))
	var along := DesignRecord.side_at(a, p)
	var into := Vector2(-along.y, along.x)
	var mid := Rect2(float(a.x), float(a.z), float(a.w), float(a.d)).get_center()
	if into.dot(mid - p) < 0.0:
		into = -into
	var x := Vector3(along.x, 0, along.y)
	var z := -Vector3(into.x, 0, into.y)
	return Transform3D(Basis(x, Vector3.UP, z), Vector3(p.x, float(g.get("deck", 0)) * rec.deck_height, p.y))


## The moving pieces at t (0..1), in design space.
static func pieces(mv: Dictionary, t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var base: Transform3D = mv.base
	for p: Dictionary in local_pieces(mv, t):
		out.append({"name": p.name, "xf": base * (p.xf as Transform3D), "size": p.size})
	return out


## The moving pieces at t in the part's own space.
static func local_pieces(mv: Dictionary, t: float) -> Array[Dictionary]:
	var s: Dictionary = mv.spec
	var S: Vector3 = mv.size
	var out: Array[Dictionary] = []
	var rng := float(s.get("range", 0.0))
	t = clampf(t, 0.0, 1.0)
	match str(s.kind):
		"hinge_out":
			# A slab hinged at its foot, standing up, falls out (-Z).
			var th := clampf(S.z, 0.08, 0.2)
			var rot := Basis(Vector3.RIGHT, -deg_to_rad(rng) * t)
			out.append(_piece("ramp", Transform3D(rot, Vector3.ZERO) * Transform3D(Basis.IDENTITY, Vector3(0, S.y * 0.5, 0)),
					Vector3(S.x, S.y, th)))
		"hinge_up":
			if str(mv.kind) == "mount":
				# Folded flat against the hull, hinged at its top edge, it swings out level.
				var hinge := Vector3(0, S.y, S.z * 0.5 - 0.04)
				var rot := Basis(Vector3.RIGHT, deg_to_rad(rng) * t)
				out.append(_piece("panel", Transform3D(rot, hinge) * Transform3D(Basis.IDENTITY, Vector3(0, -S.z * 0.5, 0)),
						Vector3(S.x, S.z, 0.06)))
			else:
				# A lid on top, hinged at its back edge, lifts its front.
				var hinge := Vector3(0, S.y, S.z * 0.5)
				var rot := Basis(Vector3.RIGHT, deg_to_rad(rng) * t)
				out.append(_piece("lid", Transform3D(rot, hinge) * Transform3D(Basis.IDENTITY, Vector3(0, 0.04, -S.z * 0.5)),
						Vector3(S.x, 0.08, S.z)))
		"slide_side":
			var d := rng if rng > 0.0 else S.x
			out.append(_piece("leaf", Transform3D(Basis.IDENTITY, Vector3(d * t, S.y * 0.5, 0)),
					Vector3(S.x, S.y, clampf(S.z * 0.5, 0.06, 0.2))))
		"slide_out":
			var d := rng if rng > 0.0 else S.z
			out.append(_piece("collar", Transform3D(Basis.IDENTITY, Vector3(0, S.y * 0.5, -S.z * 0.5 - 0.1 - d * t)),
					Vector3(S.x * 0.8, S.y * 0.8, 0.2)))
		"slide_up":
			var d := rng if rng > 0.0 else maxf(S.y - 0.15, 0.1)
			out.append(_piece("platform", Transform3D(Basis.IDENTITY, Vector3(0, 0.075 + d * t, 0)),
					Vector3(S.x, 0.15, S.z)))
		"spin":
			var reach := float(s.get("reach", 0.0))
			if reach <= 0.0:
				reach = maxf(S.x, S.z) * (1.6 if str(mv.type).begins_with("crane") else 0.75)
			var half := deg_to_rad(spin_half(mv))
			var a := lerpf(-half, half, t)
			var w := clampf(minf(S.x, S.z) * 0.3, 0.15, 0.6)
			out.append(_piece("arm", Transform3D(Basis(Vector3.UP, a), Vector3(0, S.y * 0.85, 0))
					* Transform3D(Basis.IDENTITY, Vector3(0, 0, -reach * 0.5)), Vector3(w, 0.25, reach)))
		"leg":
			# Hung under the hull: folded flat along it (+X) from a pivot at its top, it swings
			# down, then its oleo runs out and the foot comes to rest at the part's own foot.
			var swing := clampf(t / 0.6, 0.0, 1.0)
			var run := clampf((t - 0.6) / 0.4, 0.0, 1.0)
			var w := clampf(S.x * 0.3, 0.15, 0.8)
			var stroke := leg_stroke(mv)
			var strut := maxf(S.y - stroke - 0.1, 0.2)
			var leg := Transform3D(Basis(Vector3.BACK, deg_to_rad(90.0) * (1.0 - swing)), Vector3(0, S.y, 0))
			out.append(_piece("strut", leg * Transform3D(Basis.IDENTITY, Vector3(0, -strut * 0.5, 0)), Vector3(w, strut, w)))
			var oleo := stroke * run
			out.append(_piece("oleo", leg * Transform3D(Basis.IDENTITY, Vector3(0, -strut - oleo * 0.5 + 0.05, 0)),
					Vector3(w * 0.7, oleo + 0.1, w * 0.7)))
			out.append(_piece("foot", leg * Transform3D(Basis.IDENTITY, Vector3(0, -strut - oleo - 0.05, 0)),
					Vector3(foot_radius(mv) * 2.0, 0.1, foot_radius(mv) * 2.0)))
		"door_split":
			var half := float(mv.size.x) * 0.5 - 0.08
			var h := float(mv.size.y) - 0.12
			for side in [-1.0, 1.0]:
				out.append(_piece("leaf_" + ("l" if side < 0 else "r"),
						Transform3D(Basis.IDENTITY, Vector3(side * (half * 0.5 + half * t), h * 0.5, 0)), Vector3(half, h, 0.05)))
		"door_slide":
			var clear := float(mv.size.x) - 0.16
			var h := float(mv.size.y) - 0.12
			out.append(_piece("leaf", Transform3D(Basis.IDENTITY, Vector3(clear * t, h * 0.5, 0)), Vector3(clear, h, 0.08)))
		"door_swing":
			var clear := float(mv.size.x) - 0.16
			var h := float(mv.size.y) - 0.12
			var rot := Basis(Vector3.UP, deg_to_rad(90.0) * t)
			out.append(_piece("leaf", Transform3D(rot, Vector3(-clear * 0.5, 0, 0))
					* Transform3D(Basis.IDENTITY, Vector3(clear * 0.5, h * 0.5, -0.03)), Vector3(clear, h, 0.04)))
		"door_roll":
			var clear := float(mv.size.x) - 0.16
			var h := float(mv.size.y) - 0.12
			var left := h * (1.0 - t)
			out.append(_piece("shutter", Transform3D(Basis.IDENTITY, Vector3(0, h - left * 0.5 + 0.0, 0)),
					Vector3(clear, maxf(left, 0.02), 0.05)))
			out.append(_piece("drum", Transform3D(Basis.IDENTITY, Vector3(0, h + 0.22, 0)), Vector3(clear, 0.36, 0.36)))
	return out


## How far a hull part turns either side of straight out, degrees (a hull mount can't turn
## into its own hull: 90 at most).
static func spin_half(mv: Dictionary) -> float:
	var r := float(mv.spec.get("range", 180.0))
	return minf(r, 90.0) if str(mv.kind) == "mount" else r


## How far a leg's oleo runs and can take up uneven ground, m: the catalogue's move_range
## when it is a leg's, else a fifth of its height.
static func leg_stroke(mv: Dictionary) -> float:
	var r := float(mv.spec.get("stroke", 0.0))
	return r if r > 0.0 else float(mv.size.y) * 0.2


static func foot_radius(mv: Dictionary) -> float:
	return clampf(float(mv.size.x) * 0.45, 0.2, 2.0)


## Where a deployed leg's foot touches, design space: the middle of its foot, the part's own
## foot (the leg hangs its full height under the hull).
static func foot_point(mv: Dictionary) -> Vector3:
	var base: Transform3D = mv.base
	return base * Vector3.ZERO


static func _piece(n: String, xf: Transform3D, size: Vector3) -> Dictionary:
	return {"name": n, "xf": xf, "size": size}


## The swept volume: the pieces at every step of the move.
static func sweep(mv: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if str(mv.spec.kind) == "belt":
		return out
	for i in SWEEP_STEPS + 1:
		out.append_array(pieces(mv, float(i) / SWEEP_STEPS))
	return out


# Boxes

## Do two turned boxes overlap (by more than `slack` m)? Separating axes.
static func boxes_overlap(a_xf: Transform3D, a_size: Vector3, b_xf: Transform3D, b_size: Vector3, slack: float = 0.01) -> bool:
	var ax := [a_xf.basis.x.normalized(), a_xf.basis.y.normalized(), a_xf.basis.z.normalized()]
	var bx := [b_xf.basis.x.normalized(), b_xf.basis.y.normalized(), b_xf.basis.z.normalized()]
	var ah := a_size * 0.5
	var bh := b_size * 0.5
	var d := b_xf.origin - a_xf.origin
	var axes: Array = []
	axes.append_array(ax)
	axes.append_array(bx)
	for i in 3:
		for k in 3:
			var c: Vector3 = (ax[i] as Vector3).cross(bx[k])
			if c.length_squared() > 1e-6:
				axes.append(c.normalized())
	for axis: Vector3 in axes:
		var ra := ah.x * absf(axis.dot(ax[0])) + ah.y * absf(axis.dot(ax[1])) + ah.z * absf(axis.dot(ax[2]))
		var rb := bh.x * absf(axis.dot(bx[0])) + bh.y * absf(axis.dot(bx[1])) + bh.z * absf(axis.dot(bx[2]))
		if absf(d.dot(axis)) > ra + rb - slack:
			return false
	return true


## A box's eight corners.
static func corners(xf: Transform3D, size: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var h := size * 0.5
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				out.append(xf * Vector3(h.x * x, h.y * y, h.z * z))
	return out
