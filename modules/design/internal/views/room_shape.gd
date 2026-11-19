extends RefCounted
## Reshaping a room on the plan (beenster, 19 Nov: "edit the vertices of a room to create non
## rectangular rooms"). A room's outline stays square-cornered: every side runs along x or z.
##   reshape(poly, "room_vertex", i, delta): corner i moved; the two sides at it move with it.
##   reshape(poly, "room_step", i, delta): side i stepped: from its middle on it moves out (or in)
##     by delta across it, so a box becomes an L, an L a U or T.
##   fields(poly): the set_room fields for an outline ({} if it isn't a usable room shape).

const EPS := 0.01
## The smallest a room's box can be, m.
const MIN_SIZE := 0.5


static func reshape(orig: PackedVector2Array, how: String, i: int, delta: Vector2) -> PackedVector2Array:
	var poly := orig.duplicate()
	var n := poly.size()
	if n < 4 or delta == Vector2.ZERO:
		return poly
	if how == "room_vertex":
		var v := poly[i]
		for k in [(i + n - 1) % n, (i + 1) % n]:
			if absf(poly[k].x - v.x) < EPS:
				poly[k].x += delta.x
			if absf(poly[k].y - v.y) < EPS:
				poly[k].y += delta.y
		poly[i] = v + delta
		return poly
	# A step in side i: its far half moved across the side.
	var a := poly[i]
	var b := poly[(i + 1) % n]
	var along_x := absf(a.y - b.y) < EPS
	var shift := Vector2(0, delta.y) if along_x else Vector2(delta.x, 0)
	if shift.length() < EPS:
		return poly
	var mid := ((a + b) * 0.5).snapped(Vector2(0.5, 0.5))
	if along_x:
		mid.y = a.y
	else:
		mid.x = a.x
	var out := PackedVector2Array()
	for k in n:
		var p := poly[k]
		if k == (i + 1) % n:
			p += shift
		out.append(p)
		if k == i:
			out.append(mid)
			out.append(mid + shift)
	# The side after b ran from b along the other axis: it stays square, only its length changes.
	return out


## The outline cleaned (repeated corners and corners on a straight side taken out).
static func clean(poly: PackedVector2Array) -> PackedVector2Array:
	var pts := poly.duplicate()
	var changed := true
	while changed and pts.size() >= 3:
		changed = false
		for k in pts.size():
			var prev := pts[(k + pts.size() - 1) % pts.size()]
			var p := pts[k]
			var next := pts[(k + 1) % pts.size()]
			var straight := (absf(prev.x - p.x) < EPS and absf(p.x - next.x) < EPS) \
					or (absf(prev.y - p.y) < EPS and absf(p.y - next.y) < EPS)
			if p.distance_to(next) < EPS or straight:
				pts.remove_at(k)
				changed = true
				break
	return pts


## Whether no two sides of the outline cross or touch (other than neighbours at their corner).
static func is_simple(poly: PackedVector2Array) -> bool:
	var n := poly.size()
	for i in n:
		for k in range(i + 1, n):
			if k == i + 1 or (i == 0 and k == n - 1):
				continue
			if Geometry2D.segment_intersects_segment(poly[i], poly[(i + 1) % n], poly[k], poly[(k + 1) % n]) != null:
				return false
	return true


## set_room fields for the outline: its box (x, z, w, d) and its corners from the box's corner,
## or outline null where it is just a box again. {} when it can't be a room.
static func fields(poly: PackedVector2Array) -> Dictionary:
	var pts := clean(poly)
	if pts.size() < 4 or not is_simple(pts):
		return {}
	for k in pts.size():
		var a := pts[k]
		var b := pts[(k + 1) % pts.size()]
		if absf(a.x - b.x) > EPS and absf(a.y - b.y) > EPS:
			return {}  # a slanted side
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	if box.size.x < MIN_SIZE or box.size.y < MIN_SIZE:
		return {}
	var out := {"x": box.position.x, "z": box.position.y, "w": box.size.x, "d": box.size.y}
	if pts.size() == 4:
		out["outline"] = null
		return out
	var rel: Array = []
	for p in pts:
		rel.append([snappedf(p.x - box.position.x, 0.01), snappedf(p.y - box.position.y, 0.01)])
	out["outline"] = rel
	return out
