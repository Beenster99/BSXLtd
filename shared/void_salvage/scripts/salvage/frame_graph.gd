class_name FrameGraph
extends RefCounted
## The lines a cable can lie on in a body, and the search that routes leads along them
## (docs/SHIP_FRAME_PLAN.md 4.5, docs/WIRING_PLAN.md). Any builder fills one: the wrecks'
## WireRouter from a SalvageHull and its interiors, a ship's FrameHull, DeckFrame and StudWall
## (`add_lanes`) on the crew's ships. Then:
##   - lanes are straight lines on the faces of members (`add_lane`); steps are short framed
##     connectors between them (`add_step`: round a node, through a hole in a beam's web, the
##     slot past a deck's edge);
##   - each lead runs from the device's nearest face, a short free hop onto a lane, along
##     lanes (Dijkstra, corners and free air cost extra, a lane another spur already uses
##     is cheaper so spurs gather into bundles), and a short hop onto its target;
##   - spurs sharing a lane lie side by side (each in its own slot) under common straps,
##     drawn as decor on the member, so they cost no draw calls.
## Pure geometry: the same input gives the same routes on every machine, so nothing here
## is synced. A lead is a visual on the device and one CONNECTOR plug, made by the builder's
## `plug_maker` (FrameTarget.power_lead). Nothing here knows a game class.

## Longest free hop from a device (or onto a loom) to a lane, m.
const TAIL_MAX: float = 0.5
## Distance between straps along a framed stretch, m.
const CLIP_SPACING: float = 0.5
## From a member's face to the lead's surface, m.
const LEAD_STANDOFF: float = 0.02
## How tight a lead turns a corner, m.
const BEND_RADIUS: float = 0.04
## One wire pair's radius, m (WiringLoom.lead_mesh's default).
const LEAD_RADIUS: float = 0.008
## Between pairs lying side by side in a bundle, m.
const SLOT_PITCH: float = 0.02
## Cost per metre of free air (lanes cost 1.0).
const HOP_COST: float = 4.0
## Cost of turning from one lane onto another.
const CORNER_COST: float = 0.15
## Taken off a lane's cost per metre while another spur already lies on it.
const SHARED_DISCOUNT: float = 0.3
## Obstacle sampling step along an edge, m.
const SAMPLE: float = 0.05
## Where a lane sits off the face it follows (centre of the lead).
const OFF_FACE: float = LEAD_STANDOFF + LEAD_RADIUS
## The wrecks' lane kinds ("ring", "wall" (a ring lane moved onto a bulkhead's face),
## "stringer", "under", "passage"); the frame builders add "node" (round a node block),
## "deck" (under a deck, on its beams and girders) and "stud" (inside a stud wall).
const LANE_KINDS: Array[String] = ["ring", "wall", "stringer", "under", "passage"]


## A straight line a cable can lie on. `exempt` parts don't block it (a conduit through
## a jamb's gland); a `through_deck` lane may pass deck plates (a slot past the deck's edge).
class Lane:
	extends RefCounted
	var id: int
	var kind: String
	var a: Vector3
	var b: Vector3
	## Away from the face the lane lies on (unit).
	var up: Vector3
	## Across the lane in the face's plane: bundle slots stack this way (unit).
	var side: Vector3
	## What straps are drawn on (null = no straps).
	var member: PartData
	var exempt: Array[int] = []
	var through_deck: bool = false
	var cost: float = 1.0
	## Route indices in slot order.
	var users: Array[int] = []
	## Metres along the lane of every node on it.
	var params: Array[float] = []

	func length() -> float:
		return a.distance_to(b)

	func dir() -> Vector3:
		return (b - a).normalized()

	func point(t: float) -> Vector3:
		return a + dir() * t

	## Metres along the lane of the point nearest `p`, clamped to the lane.
	func nearest_t(p: Vector3) -> float:
		return clampf((p - a).dot(dir()), 0.0, length())


## One lead to route.
class Route:
	extends RefCounted
	var device: PartData
	## Array[PartData] (loom spans) or a PartData (a box, a generator).
	var target: Variant
	## "stud": Vector3 (body space) where the lead leaves the device; "through": Array[int]
	## parts it may pass (the panel a fitting is fixed to: the gland behind it); "goal": Vector3
	## where it arrives on a target part (its port); "path": the plug's path.
	var hints: Dictionary
	var points := PackedVector3Array()
	var plug: ConnectionData
	var ok: bool = false
	## Metres on lanes and in free air.
	var framed: float = 0.0
	var free: float = 0.0
	## Longest free hop, m.
	var hop: float = 0.0
	## Lane id -> [t0, t1] covered.
	var uses: Dictionary = {}
	## The route as drawn, before corner rounding: [from, to, on a frame line] per
	## segment (body space), for the wiring overlay (F5) and tests.
	var segments: Array = []


## The body's parts (looks for the obstacles and studs, decor for the straps).
var model: PartModel
## `plug_maker(device, target part, points, path) -> ConnectionData`: makes the lead's plug and
## draws it (FrameTarget.power_lead).
var plug_maker := Callable()
var routes: Array[Route] = []
## How many leads could not be routed along the frames (they were drawn straight).
var unrouted: int = 0
## Every lane as [from, to, kind] (body space), kept after routing for the overlay.
var lanes_drawn: Array = []
var lanes: Array[Lane] = []
## Boxes nothing may pass (body space): where a door's leaf runs when it opens.
var keep_out: Array[AABB] = []
## Parts that are in the way only where their collision shapes are, not over their look's whole
## box (part id -> true): a channel member, its mouth open to the cable lane inside it.
var open_parts: Dictionary = {}

var _nodes := PackedVector3Array()
var _node_keys: Dictionary = {}
## Per node: Array of [to: int, cost: float, lane: int (-1 = a step between lanes)].
var _adj: Array = []
## Framed connectors that lie on no lane: [from, to, through_deck, exempt].
var _steps: Array = []
## Obstacles: [inverse transform, shrunk AABB (part space), AABB (body space), part id, name,
## its index].
var _obstacles: Array = []
var _slabs: Dictionary = {}

static var _strap_meshes: Dictionary = {}
static var _strap_material: StandardMaterial3D


func _init(body_model: PartModel = null, plugs := Callable()) -> void:
	model = body_model
	plug_maker = plugs


# --- Lanes ------------------------------------------------------------------------------

func add_lane(kind: String, a: Vector3, c: Vector3, up: Vector3, side: Vector3, member: PartData,
		cost: float = 1.0) -> Lane:
	var l := Lane.new()
	l.id = lanes.size()
	l.kind = kind
	l.a = a
	l.b = c
	l.up = up.normalized()
	l.side = side.normalized()
	l.member = member
	l.cost = cost
	l.params = [0.0, l.length()]
	lanes.append(l)
	return l


## A framed connector from `from` to `to` that lies on no lane. `through_deck`: it may pass a
## deck plate (down the slot beside a wall); `exempt` parts don't block it (a hole through a
## beam's web, the gland through a lining).
func add_step(from: Vector3, to: Vector3, through_deck: bool = false, exempt: Array[int] = []) -> void:
	_steps.append([from, to, through_deck, exempt])


## Steps from `p` to the nearest points of up to `count` lanes (of `kinds`, or any) within a
## free hop: how a lane's loose end joins what is round it. The graph drops a step something
## blocks.
func link_nearest(p: Vector3, kinds: Array = [], exempt: Array[int] = [], through_deck: bool = false,
		count: int = 3, reach: float = TAIL_MAX) -> void:
	var found: Array = []
	for l in lanes:
		if not kinds.is_empty() and not kinds.has(l.kind):
			continue
		var t := l.nearest_t(p)
		var q := l.point(t)
		var dist := q.distance_to(p)
		if dist <= reach and dist > 0.0005:
			found.append([dist, q, l, t])
	found.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for f: Array in found.slice(0, count):
		(f[2] as Lane).params.append(float(f[3]))
		add_step(p, f[1], through_deck, exempt)


## Whether WIRE_DEBUG asks about lanes near `z` (its value is a z, or "all").
static func debug_near(z: float) -> bool:
	if not OS.has_environment("WIRE_DEBUG"):
		return false
	var v := OS.get_environment("WIRE_DEBUG")
	return v == "all" or absf(z - float(v)) < 2.0


## The nearest three points on lanes 0..`count` (of `kinds`, or any) within a free hop of
## `p`: [distance, point, lane].
func nearest_on(p: Vector3, count: int, kinds: Array) -> Array:
	var found: Array = []
	for li in count:
		var other := lanes[li]
		if not kinds.is_empty() and not kinds.has(other.kind):
			continue
		var q := other.point(other.nearest_t(p))
		var dist := q.distance_to(p)
		if dist <= TAIL_MAX:
			found.append([dist, q, other])
	found.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	return found.slice(0, 3)


## Adds `p` as a node on every lane of `kinds` it lies on (within a few mm). Returns
## the point on the nearest of them (so a step ending there shares its node), or `p`.
func register_on_lanes(p: Vector3, kinds: Array) -> Vector3:
	var snapped := p
	var best := INF
	for l in lanes:
		if not kinds.has(l.kind):
			continue
		var t := l.nearest_t(p)
		var d := l.point(t).distance_to(p)
		if d < 0.01:
			l.params.append(t)
			if d < best:
				best = d
				snapped = l.point(t)
	return snapped


## A step's ends become nodes on the lanes (of `kinds`) they touch (a stringer's end on the
## ring's face), so the step joins those lanes rather than hanging off them.
func register_steps(kinds: Array) -> void:
	# The lanes of `kinds` by the half-metre cells their boxes touch (in lane order), so each end
	# looks only at the lanes near it: the same answer as `register_on_lanes`, faster.
	var cells: Dictionary = {}
	for l in lanes:
		if not kinds.has(l.kind):
			continue
		var lo := _cell(l.a.min(l.b) - Vector3.ONE * 0.01)
		var hi := _cell(l.a.max(l.b) + Vector3.ONE * 0.01)
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					(cells.get_or_add(Vector3i(x, y, z), []) as Array).append(l)
	for st: Array in _steps:
		st[0] = _register_near(st[0], cells)
		st[1] = _register_near(st[1], cells)


static func _cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x * 2.0), floori(p.y * 2.0), floori(p.z * 2.0))


## `register_on_lanes` over the lanes in `cells` (register_steps) near `p`.
func _register_near(p: Vector3, cells: Dictionary) -> Vector3:
	var lo := _cell(p - Vector3.ONE * 0.01)
	var hi := _cell(p + Vector3.ONE * 0.01)
	var near: Array = cells.get(lo, [])
	if lo != hi:
		near = []
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					for l: Lane in cells.get(Vector3i(x, y, z), []):
						if not near.has(l):
							near.append(l)
		near.sort_custom(func(u: Lane, v: Lane) -> bool: return u.id < v.id)
	var snapped := p
	var best := INF
	for l: Lane in near:
		var t := l.nearest_t(p)
		var d := l.point(t).distance_to(p)
		if d < 0.01:
			l.params.append(t)
			if d < best:
				best = d
				snapped = l.point(t)
	return snapped


## A lead from `device` to `target` (a part, or an Array of loom spans), routed by `route_all`.
func lead(device: PartData, target: Variant, hints: Dictionary = {}) -> Route:
	if device == null or target == null:
		return null
	var r := Route.new()
	r.device = device
	r.target = target
	r.hints = hints
	routes.append(r)
	return r


## Routes every lead asked for with `lead` and draws them and their straps: the studs are each
## device's faces (or its hinted stud), the goals the target part's faces or, on a loom, the
## nearest point of each span to the device and its ends. Call once, after every lane is in.
## A builder with its own goals (the wrecks' loom ties) routes with `route` instead.
func route_all() -> void:
	if routes.is_empty():
		return
	collect_obstacles()
	var ends: Array = []
	for r in routes:
		var studs := studs_of(r.device, r.hints.get("stud"))
		var goals: Array = []
		if r.hints.get("goal") is Vector3:
			goals = [[r.hints["goal"], r.target]]
		elif r.target is PartData:
			goals = studs_of(r.target)
		else:
			for span: PartData in r.target:
				goals.append_array(_span_goals(span, r.device))
		for s: Array in studs:
			register_feet(s[0])
		for g: Array in goals:
			register_feet(g[0])
		ends.append([studs, goals])
	var kinds: Array = []
	for l in lanes:
		if not kinds.has(l.kind):
			kinds.append(l.kind)
	register_steps(kinds)
	build_graph()
	for i in routes.size():
		route(i, ends[i][0], ends[i][1])
	draw_straps()
	for l in lanes:
		lanes_drawn.append([l.a, l.b, l.kind])


## Where a lead may land on loom span `span` (a part whose look runs along its local Y): its
## centre line's point nearest the device and points a third in from each end, as [point,
## span].
func _span_goals(span: PartData, device: PartData) -> Array:
	var xf := span.local_transform
	var half := model.part_visual(span.id).get_aabb().size.y * 0.5
	var axis := xf.basis.y.normalized()
	var c := xf.origin
	var near := c + axis * clampf((device.local_transform.origin - c).dot(axis), -half + 0.1, half - 0.1)
	return [[near, span], [c - axis * half * 0.66, span], [c + axis * half * 0.66, span]]


# --- Terminals ---------------------------------------------------------------------------

## Where a lead can leave a part, as [point, part, face normal] (body space): the centre
## of each of its six faces and, per face, the points nearest the lanes within reach
## (a cable leaves a cabinet where the frame is closest, not from the middle of a side).
## A hinted stud replaces them all.
func studs_of(part: PartData, hint: Variant = null) -> Array:
	var out: Array = []
	if hint is Vector3:
		out.append([hint, part, Vector3.ZERO])
		return out
	var aabb := model.part_visual(part.id).get_aabb()
	var c := aabb.get_center()
	var half := aabb.size * 0.5
	var xf := part.local_transform
	var inv := xf.affine_inverse()
	for axis in 3:
		for sgn: float in [-1.0, 1.0]:
			var centre := c
			centre[axis] += sgn * half[axis]
			var n := Vector3.ZERO
			n[axis] = sgn
			var normal := (xf.basis * n).normalized()
			var found: Array = []
			found.append([0.0, xf * centre])
			for l in lanes:
				# Pull the lane's nearest point onto the face, twice, so the stud sits
				# where the face is closest to the lane.
				var p := centre
				for _pass in 2:
					var q := inv * l.point(l.nearest_t(xf * p))
					p = q
					p[axis] = centre[axis]
					for other in 3:
						if other != axis:
							p[other] = clampf(p[other], c[other] - half[other], c[other] + half[other])
				var world := xf * p
				var d := l.point(l.nearest_t(world)).distance_to(world)
				if d <= TAIL_MAX:
					found.append([d, world])
			found.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
			var kept: Array[Vector3] = []
			for f: Array in found:
				var w: Vector3 = f[1]
				var dup := false
				for k in kept:
					if k.distance_to(w) < 0.02:
						dup = true
						break
				if dup:
					continue
				kept.append(w)
				out.append([w, part, normal])
				if kept.size() >= 4:
					break
	return out


## The nearest few lane points within TAIL_MAX of `p` become nodes.
func register_feet(p: Vector3) -> void:
	var found: Array = []
	for l in lanes:
		var t := l.nearest_t(p)
		var d := l.point(t).distance_to(p)
		if d <= TAIL_MAX:
			found.append([d, l, t])
	found.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for i in mini(found.size(), 6):
		var l: Lane = found[i][1]
		l.params.append(float(found[i][2]))


## [node index, hop length, lane] for the feet of `p` (registered earlier).
func feet(p: Vector3, exempt: Array[int]) -> Array:
	var out: Array = []
	for l in lanes:
		var t := l.nearest_t(p)
		var q := l.point(t)
		var d := q.distance_to(p)
		if d > TAIL_MAX:
			continue
		var idx: int = _node_keys.get(key(q), -1)
		if idx < 0:
			continue
		if blocked(p, q, exempt, true):
			continue
		out.append([idx, d, l])
	out.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) < float(y[1]))
	return out.slice(0, 6)


# --- Graph -------------------------------------------------------------------------------

static func key(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * 500.0), roundi(p.y * 500.0), roundi(p.z * 500.0))


func node(p: Vector3) -> int:
	var k := key(p)
	if _node_keys.has(k):
		return _node_keys[k]
	var i := _nodes.size()
	_nodes.append(p)
	_node_keys[k] = i
	_adj.append([])
	return i


func _link(i: int, j: int, cost: float, lane: int) -> void:
	if i == j:
		return
	_adj[i].append([j, cost, lane])
	_adj[j].append([i, cost, lane])


## Joins every lane's nodes (each stretch something blocks is left out) and every step that
## nothing blocks.
func build_graph() -> void:
	for l in lanes:
		l.params.sort()
		var cleaned: Array[float] = []
		for t in l.params:
			if cleaned.is_empty() or t - cleaned[cleaned.size() - 1] > 0.002:
				cleaned.append(t)
		l.params = cleaned
		for i in cleaned.size() - 1:
			var p := l.point(cleaned[i])
			var q := l.point(cleaned[i + 1])
			# A passage's lanes are laid out by the code that built the passage, clear of
			# its parts; the box test would see a cut end plate's box across the doorway.
			if l.kind != "passage" and blocked(p, q, l.exempt, l.through_deck):
				if l.kind != "under" and (debug_near(p.z) or debug_near(q.z)):
						print("WireRouter: %s lane from %s to %s blocked by %s" % [l.kind, p, q, blocker(p, q, l.exempt)])
				continue
			_link(node(p), node(q), l.cost * p.distance_to(q), l.id)
			if l.kind == "passage" and debug_near(p.z):
				print("WireRouter: passage stretch %s -> %s linked (nodes %d, %d)" % [p, q, node(p), node(q)])
	for s: Array in _steps:
		var p: Vector3 = s[0]
		var q: Vector3 = s[1]
		var exempt: Array[int] = s[3] if s.size() > 3 else []
		if blocked(p, q, exempt, s.size() > 2 and bool(s[2])):
			if debug_near(p.z) and OS.get_environment("WIRE_DEBUG") == "all":
				pass
			continue
		_link(node(p), node(q), p.distance_to(q), -1)
		if debug_near(p.z) and (on_passage(p) or on_passage(q)):
			print("WireRouter: passage step %s -> %s linked (nodes %d, %d)" % [p, q, node(p), node(q)])


## Debug: a node, its lanes and its neighbours (reached ones starred), `depth` deep.
func dump_node(i: int, depth: int, done: Dictionary, seen: Dictionary) -> void:
	if seen.has(i) or depth < 0:
		return
	seen[i] = true
	var kinds: Array = []
	for l in lanes:
		if l.point(l.nearest_t(_nodes[i])).distance_to(_nodes[i]) < 0.01:
			kinds.append("%s#%d %s..%s params %s blocked '%s'" % [l.kind, l.id, l.a, l.b, l.params, blocker(l.a, l.b, l.exempt)])
	var names: Array = []
	for e: Array in _adj[i]:
		names.append("%d%s@%s" % [int(e[0]), "*" if done.has(int(e[0])) else "", _nodes[int(e[0])]])
	print("%snode %d %s %s on %s: %s" % ["    ".repeat(4 - depth), i, _nodes[i], "reached" if done.has(i) else "NOT reached", kinds, ", ".join(names)])
	for e: Array in _adj[i]:
		dump_node(int(e[0]), depth - 1, done, seen)


## Debug: is `p` on a passage lane?
func on_passage(p: Vector3) -> bool:
	for l in lanes:
		if l.kind == "passage" and l.point(l.nearest_t(p)).distance_to(p) < 0.01:
			return true
	return false


## How many nodes and links the graph has (tests, the log).
func graph_size() -> Vector2i:
	var links := 0
	for a: Array in _adj:
		links += a.size()
	return Vector2i(_nodes.size(), links / 2)


# --- Obstacles ---------------------------------------------------------------------------

## Every part but wiring and glass is in the way, as the box of its look; and the keep-out
## boxes.
func collect_obstacles() -> void:
	_obstacles.clear()
	_slabs.clear()
	for p: PartData in model.parts.values():
		if p.kind == PartData.Kind.CONDUIT or p.kind == PartData.Kind.GLASS:
			continue
		if open_parts.has(p.id):
			_add_collision_obstacles(p)
			continue
		var vis := model.part_visual(p.id)
		if vis == null:
			continue
		var aabb := vis.get_aabb()
		var shrunk := aabb.grow(-0.003)
		if shrunk.size.x <= 0.0 or shrunk.size.y <= 0.0 or shrunk.size.z <= 0.0:
			continue
		var world := p.local_transform * aabb
		_add_obstacle([p.local_transform.affine_inverse(), shrunk, world, p.id, p.part_name])
	for box in keep_out:
		_add_obstacle([Transform3D.IDENTITY, box, box, -1, "keep_out"])


## One obstacle per collision shape of `p` (an open part): the box of each shape's points in its
## own space.
func _add_collision_obstacles(p: PartData) -> void:
	var cols: Array = [model.part_collider(p.id)]
	cols.append_array(model.extra_colliders(p.id))
	for col: CollisionShape3D in cols:
		if col == null or not col.shape is ConvexPolygonShape3D:
			continue
		var pts := (col.shape as ConvexPolygonShape3D).points
		if pts.is_empty():
			continue
		var box := AABB(pts[0], Vector3.ZERO)
		for q in pts:
			box = box.expand(q)
		var shrunk := box.grow(-0.003)
		if shrunk.size.x <= 0.0 or shrunk.size.y <= 0.0 or shrunk.size.z <= 0.0:
			continue
		_add_obstacle([col.transform.affine_inverse(), shrunk, col.transform * box, p.id, p.part_name])


func _add_obstacle(entry: Array) -> void:
	entry.append(_obstacles.size())
	_obstacles.append(entry)
	var world: AABB = entry[2]
	var z0 := floori(world.position.z)
	var z1 := floori(world.end.z)
	for z in range(z0, z1 + 1):
		if not _slabs.has(z):
			_slabs[z] = []
		(_slabs[z] as Array).append(entry)


## The name of the first part the line p-q passes through (debugging), or "".
func blocker(p: Vector3, q: Vector3, exempt: Array[int]) -> String:
	for o: Array in _obstacles:
		if exempt.has(int(o[3])):
			continue
		var world: AABB = o[2]
		if not world.intersects(AABB(p, Vector3.ZERO).expand(q).grow(0.001)):
			continue
		var inv: Transform3D = o[0]
		var box: AABB = o[1]
		var n := maxi(int(ceil(p.distance_to(q) / SAMPLE)), 1)
		for i in n + 1:
			var at := p.lerp(q, float(i) / float(n))
			if box.has_point(inv * at):
				return "%s_%d at %s (local %s in box %s)" % [o[4], o[3], at, inv * at, box]
	return ""


## Does the straight line p-q pass through any part? `exempt` part ids are ignored;
## `through_deck` lets it pass deck plates (a hop from floor kit down into the void).
func blocked(p: Vector3, q: Vector3, exempt: Array[int], through_deck: bool) -> bool:
	var seg := AABB(p, Vector3.ZERO).expand(q).grow(0.001)
	var seen: Dictionary = {}
	for z in range(floori(seg.position.z), floori(seg.end.z) + 1):
		if not _slabs.has(z):
			continue
		for o: Array in _slabs[z]:
			var pid: int = o[3]
			# An obstacle spans several slabs: test it once (a part may have several, one per shape).
			if seen.has(o[5]):
				continue
			seen[o[5]] = true
			if pid >= 0 and exempt.has(pid):
				continue
			if through_deck and (o[4] as String) in ["DeckPlate", "FloorGrating"]:
				continue
			var world: AABB = o[2]
			if not world.intersects(seg):
				continue
			var inv: Transform3D = o[0]
			var box: AABB = o[1]
			var n := maxi(int(ceil(p.distance_to(q) / SAMPLE)), 1)
			for i in n + 1:
				var s := p.lerp(q, float(i) / float(n))
				if box.has_point(inv * s):
					return true
	return false


# --- Routing -----------------------------------------------------------------------------

## Routes lead `index` from the first of `studs` it can reach to the cheapest of `goals`
## ([point, part, normal?] each), and has `plug_maker` plug and draw it (straight, and
## counted in `unrouted`, if no frame route reaches).
func route(index: int, studs: Array, goals: Array) -> void:
	var r := routes[index]
	var exempt: Array[int] = [r.device.id]
	if r.target is PartData:
		exempt.append((r.target as PartData).id)
	for id: int in r.hints.get("through", []):
		exempt.append(id)
	# Goal nodes: foot -> [hop length, goal point, target part].
	var goal_feet: Dictionary = {}
	for g: Array in goals:
		for f: Array in feet(g[0], exempt):
			var idx: int = f[0]
			var d: float = f[1]
			if not goal_feet.has(idx) or d < float(goal_feet[idx][0]):
				goal_feet[idx] = [d, g[0], g[1]]
	# Dijkstra from every stud's feet.
	var dist: Dictionary = {}
	var prev: Dictionary = {}     # node -> [prev node, lane]
	var start: Dictionary = {}    # node -> [stud point, hop]
	var open: Array = []   # a binary heap of [cost, order pushed, node]
	var pushed := 0
	for s: Array in studs:
		var normal: Vector3 = s[2] if s.size() > 2 else Vector3.ZERO
		for f: Array in feet(s[0], exempt):
			var idx: int = f[0]
			var c: float = HOP_COST * float(f[1])
			if normal != Vector3.ZERO and float(f[1]) > 0.001:
				# Leaving a face sideways or backwards costs up to twice as much.
				var dir := (_nodes[idx] - (s[0] as Vector3)).normalized()
				c *= 2.0 - clampf(dir.dot(normal), 0.0, 1.0)
			if not dist.has(idx) or c < float(dist[idx]):
				dist[idx] = c
				start[idx] = [s[0], float(f[1])]
				prev[idx] = null
				_push(open, [c, pushed, idx])
				pushed += 1
	var done: Dictionary = {}
	var best_goal := -1
	var best_cost := INF
	while not open.is_empty():
		# Smallest first, the earliest pushed of equals.
		var cur: Array = _pop(open)
		var u: int = cur[2]
		var cu: float = cur[0]
		if done.has(u) or cu > float(dist[u]) + 1e-6:
			continue
		done[u] = true
		if goal_feet.has(u):
			var total: float = cu + HOP_COST * float(goal_feet[u][0])
			if total < best_cost:
				best_cost = total
				best_goal = u
		if cu > best_cost:
			break
		var in_lane: int = -2 if prev[u] == null else int((prev[u] as Array)[1])
		for e: Array in _adj[u]:
			var v: int = e[0]
			var lane_id: int = e[2]
			var c: float = e[1]
			if lane_id >= 0 and not lanes[lane_id].users.is_empty():
				c *= 1.0 - SHARED_DISCOUNT
			if in_lane != -2 and lane_id != in_lane:
				c += CORNER_COST
			var nd := cu + c
			if not dist.has(v) or nd < float(dist[v]):
				dist[v] = nd
				prev[v] = [u, lane_id]
				_push(open, [nd, pushed, v])
				pushed += 1
	if best_goal < 0:
		if OS.has_environment("WIRE_DEBUG"):
			var stud_feet := 0
			for st: Array in studs:
				stud_feet += feet(st[0], exempt).size()
			var reached := AABB()
			var first := true
			for node_i: int in done:
				if first:
					reached = AABB(_nodes[node_i], Vector3.ZERO)
					first = false
				else:
					reached = reached.expand(_nodes[node_i])
			print("WireRouter: %s at %s: %d studs with %d feet, %d goals with %d feet, %d nodes reached within %s .. %s" % [
					r.device.part_name, r.device.local_transform.origin, studs.size(), stud_feet, goals.size(), goal_feet.size(),
					done.size(), reached.position, reached.end])
			# The passage nodes near the device: reached or not, and what they join (3 deep).
			for i in _nodes.size():
				if on_passage(_nodes[i]) and _nodes[i].distance_to(r.device.local_transform.origin) < 12.0:
					dump_node(i, 3, done, {})
		_straight(r, studs, goals)
		return
	# Walk back.
	var chain: Array = []   # [node, lane used to reach it]
	var u := best_goal
	while u >= 0 and prev.has(u):
		var pr: Variant = prev[u]
		chain.push_front([u, -1 if pr == null else int((pr as Array)[1])])
		if pr == null:
			break
		u = int((pr as Array)[0])
	# Slots on each lane this route uses.
	var slots: Dictionary = {}
	for i in range(1, chain.size()):
		var lane_id: int = chain[i][1]
		if lane_id < 0 or slots.has(lane_id):
			continue
		var l := lanes[lane_id]
		slots[lane_id] = l.users.size()
		l.users.append(index)
	# Points: stud, the lane nodes offset into their slot, the goal.
	var first: int = chain[0][0]
	var pts := PackedVector3Array()
	pts.append(start[first][0])
	r.free = float(start[first][1])
	r.hop = r.free
	r.segments.append([start[first][0], _nodes[first], false])
	for i in chain.size():
		var node_i: int = chain[i][0]
		var p := _nodes[node_i]
		var lane_in: int = chain[i][1]
		var lane_out: int = chain[i + 1][1] if i + 1 < chain.size() else -1
		for lane_id: int in [lane_in, lane_out]:
			if lane_id < 0:
				if lane_in < 0 and lane_out < 0:
					pts.append(p)
				continue
			var l := lanes[lane_id]
			var slot: int = slots[lane_id]
			pts.append(p + l.side * SLOT_PITCH * float(slot))
			var t := l.nearest_t(p)
			if r.uses.has(lane_id):
				var u2: Array = r.uses[lane_id]
				r.uses[lane_id] = [minf(u2[0], t), maxf(u2[1], t)]
			else:
				r.uses[lane_id] = [t, t]
		if i > 0:
			var q := _nodes[chain[i - 1][0]]
			r.framed += p.distance_to(q)
			r.segments.append([q, p, true])
	var gf: Array = goal_feet[best_goal]
	var goal_hop: float = gf[0]
	r.free += goal_hop
	r.hop = maxf(r.hop, goal_hop)
	pts.append(gf[1])
	r.segments.append([_nodes[best_goal], gf[1], false])
	r.points = tidy(pts)
	r.ok = true
	r.plug = plug_maker.call(r.device, gf[2], r.points, String(r.hints.get("path", "")))


## Whether heap entry `a` ([cost, order pushed, ...]) comes before `b`.
static func _before(a: Array, b: Array) -> bool:
	return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1]))


static func _push(heap: Array, e: Array) -> void:
	heap.append(e)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if not _before(heap[i], heap[parent]):
			break
		var t: Array = heap[i]
		heap[i] = heap[parent]
		heap[parent] = t
		i = parent


static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	var n := heap.size()
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < n and _before(heap[l], heap[m]):
			m = l
		if r < n and _before(heap[r], heap[m]):
			m = r
		if m == i:
			break
		var t: Array = heap[i]
		heap[i] = heap[m]
		heap[m] = t
		i = m
	return top


## No frame route: draw it the old way (a straight lead), and say so.
func _straight(r: Route, studs: Array, goals: Array) -> void:
	var best := INF
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var part: PartData = null
	for s: Array in studs:
		for g: Array in goals:
			var d: float = (s[0] as Vector3).distance_to(g[0])
			if d < best:
				best = d
				from = s[0]
				to = g[0]
				part = g[1]
	if part == null:
		return
	unrouted += 1
	push_warning("WireRouter: no frame route for %s, drawn straight" % r.device.part_name)
	r.points = PackedVector3Array([from, from.lerp(to, 0.5), to])
	r.segments.append([from, to, false])
	r.free = best
	r.hop = best
	r.plug = plug_maker.call(r.device, part, r.points, String(r.hints.get("path", "")))


## Drops repeats and points on a straight line, then rounds every corner tight.
static func tidy(pts: PackedVector3Array) -> PackedVector3Array:
	var clean := PackedVector3Array()
	for p in pts:
		if clean.is_empty() or clean[clean.size() - 1].distance_to(p) > 0.012:
			clean.append(p)
	var straight := PackedVector3Array()
	for i in clean.size():
		if i > 0 and i < clean.size() - 1:
			var d1 := (clean[i] - clean[i - 1]).normalized()
			var d2 := (clean[i + 1] - clean[i]).normalized()
			if d1.dot(d2) > 0.9986:  # under 3 degrees
				continue
		straight.append(clean[i])
	var out := PackedVector3Array()
	for i in straight.size():
		if i == 0 or i == straight.size() - 1:
			out.append(straight[i])
			continue
		var v := straight[i]
		var to_prev := straight[i - 1] - v
		var to_next := straight[i + 1] - v
		var r := minf(BEND_RADIUS, minf(to_prev.length(), to_next.length()) * 0.45)
		out.append(v + to_prev.normalized() * r)
		out.append(v + to_next.normalized() * r)
	return out


# --- Straps ------------------------------------------------------------------------------

## A saddle strap over every bundle, every CLIP_SPACING along each lane in use, as decor
## on the member it follows.
func draw_straps() -> void:
	for l in lanes:
		if l.users.is_empty() or l.member == null:
			continue
		var length := l.length()
		var t := CLIP_SPACING * 0.5 if length > CLIP_SPACING * 0.75 else length * 0.5
		if length < 0.1:
			continue
		while t <= length - 0.03:
			var n := 0
			for ri in l.users:
				var use: Array = routes[ri].uses.get(l.id, [INF, -INF])
				if t >= float(use[0]) - 0.02 and t <= float(use[1]) + 0.02:
					n += 1
			if n > 0:
				var thick := LEAD_STANDOFF + LEAD_RADIUS * 2.0 + 0.004
				var width := SLOT_PITCH * float(n) + 0.008
				var centre := l.point(t) + l.side * SLOT_PITCH * float(n - 1) * 0.5 \
						+ l.up * (thick * 0.5 - OFF_FACE)
				var x := l.dir()
				var y := l.up
				var z := x.cross(y).normalized()
				model.add_decor(l.member.id, _strap_mesh(width), _strap_mat(),
						Transform3D(Basis(x, y, z), centre))
			t += CLIP_SPACING


static func _strap_mesh(width: float) -> Mesh:
	var k := roundi(width * 1000.0)
	if not _strap_meshes.has(k):
		var kit := MeshKit.new()
		kit.color = Color(0.5, 0.52, 0.55)
		kit.box(Vector3(0.014, LEAD_STANDOFF + LEAD_RADIUS * 2.0 + 0.004, width))
		_strap_meshes[k] = kit.finish()
	return _strap_meshes[k]


static func _strap_mat() -> StandardMaterial3D:
	if _strap_material == null:
		_strap_material = StandardMaterial3D.new()
		_strap_material.vertex_color_use_as_albedo = true
		_strap_material.metallic = 0.6
		_strap_material.roughness = 0.45
	return _strap_material


## One line per lead, for tests and the log.
func report() -> Array[String]:
	var out: Array[String] = []
	for r in routes:
		out.append("%s: %s framed %.2f m, free %.2f m, longest hop %.2f m" % [r.device.part_name,
				"routed" if r.ok else "STRAIGHT", r.framed, r.free, r.hop])
	return out
