class_name MotionCheck
extends RefCounted
## Does every moving part have room to move? Each mover's swept volume (MotionMovers.sweep)
## against everything fixed round it: the other parts (in rooms and on the hull), the room it
## stands in (walls, deck and deckhead), and for doors the wall its leaves slide into and the
## head room a shutter's drum needs. Results go on WILL IT WORK as DesignRules problems.
##
## clashes(rec, cat) -> {mover id -> [{what ("part" | "room" | "pocket" | "head"), id, text}]}

## How far a swept box may touch something before it counts as a clash, m.
const SLACK := 0.03


## Every obstacle that doesn't move, as boxes: [{id, name, xf, size, deck}].
static func obstacles(rec: DesignRecord, cat: DesignCatalog) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in rec.components.values():
		var pt := cat.part(str(c.type))
		var r: Dictionary = rec.rooms.get(str(c.room), {})
		if pt == null or r.is_empty():
			continue
		var f := DesignRules.footprint(c, pt)
		var h := minf(pt.size.y, rec.deck_height - MotionMovers.FLOOR)
		out.append({"id": "component:" + str(c.id), "name": "%s %s" % [pt.display_name, DesignRecord.tag(str(c.id))],
				"xf": Transform3D(Basis.IDENTITY, Vector3(f.get_center().x, float(r.deck) * rec.deck_height + h * 0.5, f.get_center().y)),
				"size": Vector3(f.size.x, h, f.size.y), "deck": int(r.deck), "moves": MotionTable.moves(pt)})
	for m: Dictionary in rec.mounts.values():
		var pt := cat.part(str(m.type))
		if pt == null:
			continue
		var base := MotionMovers.mount_base(rec, m, pt)
		out.append({"id": "mount:" + str(m.id), "name": "%s %s" % [pt.display_name, DesignRecord.tag(str(m.id))],
				"xf": base * Transform3D(Basis.IDENTITY, Vector3(0, pt.size.y * 0.5, 0)), "size": pt.size,
				"deck": int(m.deck), "moves": MotionTable.moves(pt)})
	return out


static func clashes(rec: DesignRecord, cat: DesignCatalog, movers: Array[Dictionary] = []) -> Dictionary:
	var out := {}
	if rec == null:
		return out
	if movers.is_empty():
		movers = MotionMovers.list(rec, cat)
	var fixed := obstacles(rec, cat)
	for mv: Dictionary in movers:
		var found: Array[Dictionary] = []
		var swept := MotionMovers.sweep(mv)
		var hit := {}
		for ob: Dictionary in fixed:
			if str(ob.id) == str(mv.id) or absi(int(ob.deck) - int(mv.deck)) > 1:
				continue
			for p: Dictionary in swept:
				if MotionMovers.boxes_overlap(p.xf, p.size, ob.xf, ob.size, SLACK):
					hit[str(ob.id)] = ob
					break
		for oid: String in hit:
			var ob: Dictionary = hit[oid]
			found.append({"what": "part", "id": oid, "text": "%s hits %s as it %s" % [mv.name, ob.name, _verb(mv)]})
		if mv.kind == "component":
			var wall := _out_of_room(rec, mv, swept)
			if wall != "":
				found.append({"what": "room", "id": str(mv.room), "text": "%s %s as it %s" % [mv.name, wall, _verb(mv)]})
		elif mv.kind == "door":
			found.append_array(_door_room(rec, mv))
		if not found.is_empty():
			out[str(mv.id)] = found
	return out


static func _verb(mv: Dictionary) -> String:
	match str(mv.spec.kind):
		"hinge_out", "hinge_up", "door_swing":
			return "swings open"
		"spin":
			return "turns"
		"leg":
			return "deploys"
		"slide_up":
			return "rises"
		"door_roll":
			return "rolls up"
	return "slides"


## Where a part in a room would leave it as it moves ("" when it stays inside).
static func _out_of_room(rec: DesignRecord, mv: Dictionary, swept: Array[Dictionary]) -> String:
	var r: Dictionary = rec.rooms.get(str(mv.room), {})
	if r.is_empty():
		return ""
	var floor_y := float(r.deck) * rec.deck_height
	var top := floor_y + rec.deck_height - MotionMovers.FLOOR + SLACK
	var poly := DesignRecord.room_poly(r)
	var grown := Geometry2D.offset_polygon(poly, SLACK)
	var inside: PackedVector2Array = grown[0] if not grown.is_empty() else poly
	for p: Dictionary in swept:
		for v in MotionMovers.corners(p.xf, p.size):
			if v.y > top:
				return "goes through the deckhead"
			if v.y < floor_y - SLACK:
				return "goes through the deck"
			if not Geometry2D.is_point_in_polygon(Vector2(v.x, v.z), inside):
				return "goes through the wall"
	return ""


## A door's leaves need wall to slide into, a shutter head room for its drum, and a hinged
## leaf clear floor to swing over.
static func _door_room(rec: DesignRecord, mv: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var g: Dictionary = rec.doors.get(str(mv.ref), {})
	var style := str(mv.spec.get("style", ""))
	var w := float(mv.size.x)
	if style == "roll":
		var need := float(mv.size.y) + 0.4
		if need > rec.deck_height - MotionMovers.FLOOR + 0.01:
			out.append({"what": "head", "id": str(mv.ref), "text": "%s needs %s m over its opening for the shutter drum; the deck gives %s m" % [
					mv.name, _m(0.4), _m(rec.deck_height - MotionMovers.FLOOR - float(mv.size.y))]})
		return out
	if style != "split" and style != "slide":
		return out
	# The wall the door is in: room a's side through it, run on by every room side in line
	# with it that it meets (a leaf slides into whichever room's stretch of the wall is there).
	var p := Vector2(float(g.x), float(g.z))
	var seg := _wall_line(rec, int(g.get("deck", 0)), _side_of(rec.rooms.get(str(g.a), {}), p))
	if seg.size() < 2:
		return out
	var dir := (seg[1] - seg[0]).normalized()
	var t := (p - seg[0]).dot(dir)
	var length := seg[0].distance_to(seg[1])
	var lo := t - w * 0.5
	var hi := t + w * 0.5
	if style == "split":
		lo -= w * 0.5
		hi += w * 0.5
	else:
		hi += w
	var short := maxf(0.0 - lo, hi - length)
	# Another door in the same stretch of wall takes the pocket too.
	var other := ""
	for oid: String in rec.doors:
		if oid == str(mv.ref):
			continue
		var o: Dictionary = rec.doors[oid]
		if int(o.get("deck", 0)) != int(g.get("deck", 0)):
			continue
		var op := Vector2(float(o.x), float(o.z))
		if Geometry2D.get_closest_point_to_segment(op, seg[0], seg[1]).distance_to(op) > 0.05:
			continue
		var ot := (op - seg[0]).dot(dir)
		var ow := DesignCatalog.door_w(o) * 0.5
		if ot + ow > lo + 0.02 and ot - ow < hi - 0.02:
			other = DesignRecord.tag(oid)
			break
	if short > 0.02:
		out.append({"what": "pocket", "id": str(mv.ref), "text": "%s has no wall to slide into: it needs %s m more wall beside it" % [
				mv.name, _m(short)]})
	elif other != "":
		out.append({"what": "pocket", "id": str(mv.ref), "text": "%s slides into the wall where door %s is" % [mv.name, other]})
	return out


## A stretch of wall run on along its line by the sides of other rooms on the deck that touch
## or overlap it, both ways, as far as they go on unbroken.
static func _wall_line(rec: DesignRecord, deck: int, seg: PackedVector2Array) -> PackedVector2Array:
	if seg.size() < 2:
		return seg
	var a0 := seg[0]
	var d0 := (seg[1] - seg[0]).normalized()
	var spans: Array[Vector2] = []
	for r: Dictionary in rec.rooms.values():
		if int(r.deck) != deck:
			continue
		var poly := DesignRecord.room_poly(r)
		for i in poly.size():
			var p := poly[i]
			var q := poly[(i + 1) % poly.size()]
			if p.distance_to(q) < 0.01 or absf(d0.cross(q - p)) > 0.01 or absf(d0.cross(p - a0)) > 0.02:
				continue
			var t0 := (p - a0).dot(d0)
			var t1 := (q - a0).dot(d0)
			spans.append(Vector2(minf(t0, t1), maxf(t0, t1)))
	var lo := 0.0
	var hi := seg[0].distance_to(seg[1])
	var grew := true
	while grew:
		grew = false
		for sp in spans:
			if sp.x <= hi + 0.02 and sp.y >= lo - 0.02 and (sp.x < lo - 0.001 or sp.y > hi + 0.001):
				lo = minf(lo, sp.x)
				hi = maxf(hi, sp.y)
				grew = true
	return PackedVector2Array([a0 + d0 * lo, a0 + d0 * hi])


static func _side_of(r: Dictionary, p: Vector2) -> PackedVector2Array:
	if r.is_empty():
		return PackedVector2Array()
	var poly := DesignRecord.room_poly(r)
	var best := PackedVector2Array()
	var near := INF
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var d := Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)
		if d < near:
			near = d
			best = PackedVector2Array([a, b])
	return best


static func _m(v: float) -> String:
	return str(snappedf(v, 0.01))


## The clashes as WILL IT WORK problems (DesignRules problem dicts, code "motion.clash").
static func problems(rec: DesignRecord, cat: DesignCatalog, found: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mid: String in found:
		var kind := mid.get_slice(":", 0)
		var ref := mid.get_slice(":", 1)
		for c: Dictionary in found[mid]:
			var comps: Array = [ref] if kind == "component" else []
			if str(c.id).begins_with("component:"):
				comps.append(str(c.id).get_slice(":", 1))
			var doors: Array = [ref] if kind == "door" else []
			out.append({"code": "motion.clash", "severity": DesignRules.ERROR, "text": str(c.text), "rooms": [],
					"components": comps, "doors": doors, "mover": mid})
	return out
