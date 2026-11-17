class_name FrameMounts
extends RefCounted
## How a frame build's fittings and systems are fastened where they stand (docs/SHIP_FRAME_PLAN.md
## 4.4), shared by the frame builds (KestrelShip, MantaShip): the design lists what
## may carry a fitting (`add`: deck plates, wall panels, linings, ceilings, skin plates), and when
## the kit has folded a unit into its part (ShipKit.mount) `mount` tacks it with spot welds, a deck
## plate under its foot first, else the panel, lining, ceiling or skin plate its back (or top)
## lies against; on a stud wall also to a stud behind every mounting point (StudWall.stud_behind),
## the panel bolted to it there. A unit of looks only rides on the part it lies against
## (`rest`); a leaf (a door's, a hatch's) is bolted where the design's `hangers` say.

var kit: ShipKit
var model: PartModel
## What fittings may be fastened to: {part, kind ("floor", "wall", "lining", "skin",
## "ceiling"), box (its collision's bounds, ship space), wall (a StudWall)}.
var mounts: Array[Dictionary] = []
## How each unit was fastened, by its path: {onto: [paths], spots, studs: [paths]} (a unit of
## looks only also "rides": true).
var tacks: Dictionary = {}
## Units that found nothing to be fastened to (the tests want none).
var unmounted: PackedStringArray = []
## The design's `hangers(part, unit) -> Array` for a leaf: [[holder, where (ship space), role],
## ...], each a bolt from the leaf to the holder, its head on the leaf.
var hangers := Callable()
## How far apart two faces may stand and still count as touching, metres.
var tol: float = 0.035
## A look-only unit rides on the nearest part within this, metres, when it touches none.
var reach: float = 0.25
## Mount indices by the 1 m cells their boxes (grown by 4 cm) touch (`anchor`).
var _cells: Dictionary = {}


func _init(into: ShipKit) -> void:
	kit = into
	model = into.model


func add(p: PartData, kind: String, wall: StudWall = null) -> void:
	if p == null:
		return
	var box := part_box(p)
	var lo := Vector3i(box.grow(0.04).position.floor())
	var hi := Vector3i(box.grow(0.04).end.floor())
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				(_cells.get_or_add(Vector3i(x, y, z), []) as Array).append(mounts.size())
	mounts.append({"part": p, "kind": kind, "box": box, "wall": wall})


## The bounds of a part's collision shapes (ship space).
func part_box(p: PartData) -> AABB:
	var cols: Array = [model.part_collider(p.id)]
	cols.append_array(model.extra_colliders(p.id))
	var box := AABB()
	var first := true
	for col: CollisionShape3D in cols:
		var pts := PackedVector3Array()
		if col.shape is ConvexPolygonShape3D:
			pts = (col.shape as ConvexPolygonShape3D).points
		elif col.shape is BoxShape3D:
			var h := (col.shape as BoxShape3D).size * 0.5
			for k in 8:
				pts.append(Vector3(h.x if k & 1 else -h.x, h.y if k & 2 else -h.y, h.z if k & 4 else -h.z))
		else:
			var b := col.shape.get_debug_mesh().get_aabb()
			for k in 8:
				pts.append(b.get_endpoint(k))
		for q in pts:
			var at := col.transform * q
			if first:
				box = AABB(at, Vector3.ZERO)
				first = false
			else:
				box = box.expand(at)
	return box


## The deck plate under (x, z) whose top is `top` (a stud wall's sill welds to it), or null.
func floor_at(x: float, z: float, top: float = 0.0) -> PartData:
	for m: Dictionary in mounts:
		var b: AABB = m["box"]
		if m["kind"] == "floor" and absf(b.end.y - top) < 0.01 and x >= b.position.x - 0.011 and x <= b.end.x + 0.011 \
				and z >= b.position.z - 0.011 and z <= b.end.z + 0.011:
			return m["part"]
	return null


## The lining (or wall panel) a point at the edge of a wall or the ceiling lies against: the
## smallest mount of those `kinds` whose bounds, grown a little, hold it.
func anchor(p: Vector3, kinds: Array = ["lining", "wall"]) -> PartData:
	var best: PartData = null
	var best_v := INF
	for i: int in _cells.get(Vector3i(p.floor()), []):
		var m: Dictionary = mounts[i]
		if not m["kind"] in kinds:
			continue
		var b := (m["box"] as AABB).grow(0.04)
		if b.has_point(p):
			var v := b.get_volume()
			if v < best_v:
				best_v = v
				best = m["part"]
	return best


## A unit's part is made (ShipKit.mount): tack it where it stands; a leaf is hung, a unit of looks
## only rides.
func mount(p: PartData, unit: Dictionary) -> void:
	if p == null:
		rest(unit)
		return
	if unit["kind"] == "leaf":
		hang(p, unit, hangers.call(p, unit) if hangers.is_valid() else [])
		return
	var box := part_box(p)
	var path: String = unit["path"]
	var made := {"onto": [], "spots": 0, "studs": []}
	# Standing on the floor.
	for m: Dictionary in mounts:
		if m["kind"] != "floor":
			continue
		var b: AABB = m["box"]
		if absf(box.position.y - b.end.y) > tol:
			continue
		var r := Rect2(box.position.x, box.position.z, box.size.x, box.size.z).intersection(
				Rect2(b.position.x, b.position.z, b.size.x, b.size.z))
		if r.get_area() < 0.0004:
			continue
		var pts: Array = []
		for c in corners(r):
			pts.append(Vector3(c.x, b.end.y, c.y))
		spots(p, m["part"], pts, Vector3.UP, path, made)
	if (made["onto"] as Array).is_empty():
		# Hung under the deck (a jump tank): spots on the plates' undersides over it.
		for m: Dictionary in mounts:
			if m["kind"] != "floor":
				continue
			var b: AABB = m["box"]
			if absf(b.position.y - box.end.y) > tol or box.end.y > b.position.y + 0.001:
				continue
			var r := Rect2(box.position.x, box.position.z, box.size.x, box.size.z).intersection(
					Rect2(b.position.x, b.position.z, b.size.x, b.size.z))
			if r.get_area() < 0.0004:
				continue
			var pts: Array = []
			for c in corners(r):
				pts.append(Vector3(c.x, b.position.y, c.y))
			spots(p, m["part"], pts, Vector3.DOWN, path, made)
	if (made["onto"] as Array).is_empty():
		# Against a wall, a lining, the ceiling or the skin: the face with the most contact.
		var best: Dictionary = {}
		var best_area := 0.0004
		var best_axis := -1
		var best_sign := 0.0
		for m: Dictionary in mounts:
			if m["kind"] == "floor":
				continue
			var b: AABB = m["box"]
			for axis in 3:
				for sgn: float in [1.0, -1.0]:
					# sgn 1: the fitting lies on the support's + side (its low face on the support's high one).
					var gap := box.position[axis] - b.end[axis] if sgn > 0.0 else b.position[axis] - box.end[axis]
					if absf(gap) > tol:
						continue
					var u := (axis + 1) % 3
					var v := (axis + 2) % 3
					var r := Rect2(box.position[u], box.position[v], box.size[u], box.size[v]).intersection(
							Rect2(b.position[u], b.position[v], b.size[u], b.size[v]))
					if r.get_area() > best_area:
						best_area = r.get_area()
						best = m
						best_axis = axis
						best_sign = sgn
		if not best.is_empty():
			var b: AABB = best["box"]
			var u := (best_axis + 1) % 3
			var v := (best_axis + 2) % 3
			var r := Rect2(box.position[u], box.position[v], box.size[u], box.size[v]).intersection(
					Rect2(b.position[u], b.position[v], b.size[u], b.size[v]))
			var face := b.end[best_axis] if best_sign > 0.0 else b.position[best_axis]
			var normal := Vector3.ZERO
			normal[best_axis] = best_sign
			var pts: Array = []
			for c in corners(r):
				var at := Vector3.ZERO
				at[best_axis] = face
				at[u] = c.x
				at[v] = c.y
				pts.append(at)
			spots(p, best["part"], pts, normal, path, made)
			var wall: StudWall = best["wall"]
			if wall:
				# Through the panel to a stud behind each mounting point.
				var fixed := {}
				var panel: PartData = best["part"]
				for at: Vector3 in pts:
					var stud := wall.stud_behind_at(at)
					if stud == null:
						continue
					var key := stud.path.trim_prefix("wall:%s/" % wall.name)
					var n: int = fixed.get(key, 0)
					fixed[key] = n + 1
					kit.phase = "wall"
					kit.join(panel, stud, ConnectionData.Kind.BOLT, at, normal, Vector3.ZERO, Vector2.ZERO,
							"%s/fix:%s/%s/%d" % [panel.path, path, key, n])
					kit.phase = "fitting"
					if not (made["studs"] as Array).has(stud.path):
						(made["studs"] as Array).append(stud.path)
	if (made["onto"] as Array).is_empty():
		unmounted.append(path)
	tacks[path] = made


## A unit of looks only (no collision: a lamp, a name board, the hold's nets, a screen): it
## rides on the part it lies against (the ceiling, a wall panel, the skin), else the nearest
## part within `reach` (a screen over the console).
func rest(unit: Dictionary) -> void:
	var box: AABB = unit["box"]
	var best: PartData = null
	var best_d := reach
	var candidates: Array = []
	for m: Dictionary in mounts:
		candidates.append([m["part"], m["box"]])
	for u: Dictionary in kit.units:
		if u.has("part"):
			candidates.append([u["part"], part_box(u["part"])])
	var best_area := 0.0
	for c: Array in candidates:
		var b: AABB = c[1]
		var d := 0.0
		for axis in 3:
			d = maxf(d, maxf(b.position[axis] - box.end[axis], box.position[axis] - b.end[axis]))
		# Touching: the one it shares most face with; else the nearest.
		var area := box.grow(tol).intersection(b.grow(tol)).get_volume()
		if d <= tol and (best_d > tol or area > best_area):
			best_d = d
			best_area = area
			best = c[0]
		elif best_d > tol and d < best_d:
			best_d = d
			best = c[0]
	if best:
		unit["onto"] = best
		tacks[unit["path"]] = {"onto": [best.path], "spots": 0, "studs": [], "rides": true}
	else:
		unmounted.append(unit["path"])


## A door's or hatch's leaf (a moving part): bolted at `points` ([holder, where, role]) to what
## it runs on, the heads on the leaf so they travel with it.
func hang(p: PartData, unit: Dictionary, points: Array) -> void:
	var path: String = unit["path"]
	var made := {"onto": [], "spots": 0, "studs": []}
	var k := 0
	for pt: Array in points:
		var holder: PartData = pt[0]
		if holder == null:
			continue
		kit.join(p, holder, ConnectionData.Kind.BOLT, pt[1], Vector3.UP, Vector3.ZERO, Vector2.ZERO,
				"%s/%s:%s/%d" % [path, pt[2], holder.path, k])
		k += 1
		if not (made["onto"] as Array).has(holder.path):
			(made["onto"] as Array).append(holder.path)
	made["spots"] = k
	if k == 0:
		unmounted.append(path)
	tacks[path] = made


## The four corners of `r` pulled in a little (two along a thin strip, one on a speck).
static func corners(r: Rect2) -> Array[Vector2]:
	var m := Vector2(minf(0.05, r.size.x * 0.25), minf(0.05, r.size.y * 0.25))
	var lo := r.position + m
	var hi := r.end - m
	var out: Array[Vector2] = []
	for c: Vector2 in [lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)]:
		var dup := false
		for o in out:
			dup = dup or o.distance_to(c) < 0.03
		if not dup:
			out.append(c)
	return out


## Spot welds from `p` onto `onto` at `pts`, the puddles facing `normal`, named for what they weld to.
func spots(p: PartData, onto: PartData, pts: Array, normal: Vector3, path: String, made: Dictionary) -> void:
	var k := 0
	for at: Vector3 in pts:
		kit.join(p, onto, ConnectionData.Kind.SPOT, at, normal, Vector3.ZERO, Vector2.ZERO,
				"%s/spot:%s/%d" % [path, onto.path, k])
		k += 1
	made["spots"] = int(made["spots"]) + k
	(made["onto"] as Array).append(onto.path)
