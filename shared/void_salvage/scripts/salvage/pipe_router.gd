class_name PipeRouter
extends RefCounted
## Lays a body's pipe runs (docs/SHIP_FRAME_PLAN.md 4.5, F5b): each run from a port on one
## part (ShipParts.ports: a spigot with its fluid and radius) to a port on another, as real
## parts and joints a crew can take apart: straight `pipe` spans, a 90 degree `pipe_elbow` at
## every corner, a flanged `pipe_union` wherever a run crosses a ring's station along the
## body, each span clipped to the frame member (or, failing one, the panel) beside it every
## `clip_pitch`, and the run's ends bolted to the parts at their spigots.
##
## The search: a pipe is too fat to lie on the wire lanes (FrameGraph) and needs a straight
## stretch between bends, so it has its own. The space round a run is a grid (`cell` apart,
## with the ports' own lines added so a run leaves and meets them dead straight), every grid
## point blocked that is nearer any part than the pipe's radius and `gap` (the parts a run
## starts and ends on, and those it passes through on the way, such as the lining behind a
## spigot or the plate under it, only beyond `pass_reach` of its ends), and the leads already
## laid (`avoid`). A* over (point, heading, metres since the last bend) finds the cheapest
## path that bends only at right angles and keeps 2 bend radii between bends: a metre costs
## less beside a frame member (`hug_cost`, so pipes follow the frames), more above `low_y`
## (`high_cost`: the belly and the cavities before anywhere high), much more inside a room
## (`room_cost`: only where a spigot stands in one), and each bend costs `turn_cost`.
##
## Pure geometry and the parts it makes: the same input lays the same runs on every machine,
## so nothing here is synced. It builds into a FrameTarget (`pipe_part`, `join`). Paths
## (4.7): "pipe:<run>/span/<k>", "pipe:<run>/elbow/<k>", "pipe:<run>/union:st:<label>"; joints
## "<span>/weld:<elbow>", "<union>/bolt:<span>/<k>", "<span>/clip:<holder path>/<k>",
## "<span>/bolt:<port part path>/<k>"; every joint stamped `service`. Nothing here knows a game
## class.

## Grid pitch, metres.
var cell: float = 0.04
## Kept between a pipe's surface and any other part, metres.
var gap: float = 0.012
## Bend radius of the elbows, in pipe radii.
var bend_factor: float = 2.0
## A clip along a span every so many metres.
var clip_pitch: float = 0.6
## How far from its ends a run may pass the parts it starts on, ends on and goes through
## (a spigot through the lining behind it), metres.
var pass_reach: float = 0.3
## Searched round the box of a run's two ends, metres each way.
var margin: float = 0.5
## Cost per metre: beside a member, above `low_y`, inside a room; and per bend.
var hug_cost: float = 0.7
var high_cost: float = 1.6
var room_cost: float = 15.0
var turn_cost: float = 0.3
## The search's guess of the cost left, per metre: at `hug_cost` it is exact A* (the cheapest
## path), nearer 1 it searches far less for a path a little dearer.
var heuristic: float = 1.0
## Within this of a member a metre counts as beside it, metres (beyond the pipe's clearance).
var hug: float = 0.07
## How far a clip reaches to its holder, metres (beyond the pipe's surface).
var clip_reach: float = 0.16
## The shortest span that takes fluid bands, m.
var band_least: float = 0.45
## A span shorter than band_least but this long, m, wears one band in its middle.
var band_one: float = 0.15
## Give up a run after this many search steps.
var max_steps: int = 3000000
## Guide the search by a map of the cost left: each grid point's cheapest way to the run's end
## through points not blocked, at the search's own costs (`_cost_to_go`), plus the bends it
## still owes (`_turns_left`), stands in for the straight line in its guess of the cost left.
## The guess never runs over, so it finds as cheap a path, but it no longer fills the grid where
## pipes cost more than the straight line's metre (over `low_y`, round a wall, for the bends):
## the Patience's fuel lines searched 3 million points for a 6 m run, 60 s, and now 27,000 in
## 1 s. A run walled off from its end fails at once. Wrecks lay theirs so
## (WreckDesign.pipe_router); off, the player ships' routes are kept as they were.
var guided: bool = false

var model: PartModel
var target: FrameTarget
## Spaces the crew walks in (body space): a pipe crosses one only near a spigot.
var rooms: Array[AABB] = []
## Frame members (part id -> true): pipes run beside them and are clipped to them.
var members: Dictionary = {}
## Above this height (body y) pipes cost `high_cost` a metre.
var low_y: float = INF
## The stations a run along the body crosses ([z, label] each): a union at each.
var stations: Array = []
## Lines to keep clear of (the leads): [points (body space), radius] each.
var avoid: Array = []
var runs: Array[Run] = []


## One pipe run, port to port.
class Run:
	extends RefCounted
	var name: String
	var fluid: String
	var radius: float
	var mat: Material
	## {part: PartData, position: Vector3, direction: Vector3 (the way the pipe leaves)}.
	var from: Dictionary
	var to: Dictionary
	## Parts it may pass near its ends (the lining behind a spigot, the plate under it).
	var through: Array[int] = []
	## Parts it may pass anywhere (a panel with a gland let into it for the pipe).
	var glands: Array[int] = []
	## Points it passes on its way, in order: [position, direction it heads through, and
	## optionally the part ids it may pass within pass_reach of the point (a deck plate it rises
	## through there)] each (body space). A long run is searched a leg at a time between them,
	## each leg's grid only round it.
	var via: Array = []
	## The centre line's corners, port to port (body space).
	var points := PackedVector3Array()
	var ok: bool = false
	var why: String = ""
	var spans: Array[PartData] = []
	var elbows: Array[PartData] = []
	var unions: Array[PartData] = []
	## Every clip: [joint, span, holder].
	var clips: Array = []
	var ends: Array[ConnectionData] = []
	## Station labels a union sits at, and those crossed with no room for one.
	var crossed: Array[String] = []
	var missed: Array[String] = []
	var steps: int = 0
	var msec: int = 0
	## `search_run` found its centre line (built by `build_run`).
	var found: bool = false


func _init(into: FrameTarget = null) -> void:
	target = into
	if into:
		model = into.parts_model()


## Asks for a run named `run_name` of `fluid` and `radius` from `from` to `to` ({part,
## position, direction}: a port in body space on its part), passing `through` near its ends,
## `glands` anywhere and the points `via` in order ([position, direction, parts passed near it?]
## each, square to the body's axes). Laid in the order asked, each clear of those before it, by `lay_all`.
func run(run_name: String, fluid: String, radius: float, from: Dictionary, to: Dictionary,
		mat: Material, through: Array[int] = [], glands: Array[int] = [], via: Array = []) -> Run:
	var r := Run.new()
	r.glands = glands
	r.via = via
	r.name = run_name
	r.fluid = fluid
	r.radius = radius
	r.from = from
	r.to = to
	r.mat = mat
	r.through = through
	runs.append(r)
	return r


## Searches and builds every run asked for, in order (each sees the parts of those before it).
func lay_all() -> void:
	begin_laying()
	for r in runs:
		prepare_run(r)
		search_run(r)
		build_run(r)
	end_laying()


## Laying a step at a time (a builder that hands each run's search to a worker thread): `begin_laying`,
## then for each run in order `prepare_run` (files the parts so far), `search_run` (reads only this
## router's own data and what `prepare_run` filed: nothing of the body, so it may run on another
## thread while nothing else touches her) and `build_run` (makes the parts), then `end_laying`.
## `lay_all` is these in order: the same runs either way.
func begin_laying() -> void:
	if target:
		target.begin_builder("pipes")


func prepare_run(r: Run) -> void:
	r.msec = 0
	_part_index()


func search_run(r: Run) -> void:
	var t := Time.get_ticks_msec()
	r.found = _search(r)
	r.msec += Time.get_ticks_msec() - t


func build_run(r: Run) -> void:
	var t := Time.get_ticks_msec()
	if r.found:
		_build(r)
	r.msec += Time.get_ticks_msec() - t


func end_laying() -> void:
	if target:
		target.end_builder()


## A union's length for run `r`, metres.
func union_length(r: Run) -> float:
	return maxf(0.05, r.radius * 2.4)


func _along_z(h0: int, h1: int) -> bool:
	return h0 >= 4 or h1 >= 4


func _near_station(z: float, room: float) -> bool:
	for st: Array in stations:
		if absf(z - float(st[0])) < room:
			return true
	return false


func bend_radius(r: Run) -> float:
	return r.radius * bend_factor


## How long a run leaves its spigot straight before it may bend, metres.
func spigot(r: Run) -> float:
	return bend_radius(r) + 0.03


# --- The search ---------------------------------------------------------------------------

const DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
## Metres since the last bend are counted in steps of this, metres.
const RUN_STEP: float = 0.01

# The grid of the run being searched.
var _ax: Array = [PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array()]
var _n := Vector3i.ZERO
## Per grid point: bit 1 blocked, 2 beside a member, 4 in a room.
var _cells := PackedByteArray()
var _index: Array = []
var _indexed := {}   # part id -> its entry in _index ([] for a part with no look)
var _index_seen := -1
var _index_cells := {}   # Vector3i (INDEX_CELL cells) -> the index's positions of the entries there
const INDEX_CELL: float = 1.0
## The cost left from each grid point to the leg's end in TOGO_UNITs, -1 none (the guided
## search's, `_cost_to_go`); empty when not guided.
var _dist := PackedInt32Array()
## The cost left's step, metres at a cost of 1 a metre.
const TOGO_UNIT: float = 0.0005


static func dir_index(v: Vector3) -> int:
	for i in 6:
		if Vector3(DIRS[i]).dot(v) > 0.99:
			return i
	return -1


func _search(r: Run) -> bool:
	var d0 := dir_index(r.from["direction"])
	var d1 := dir_index(r.to["direction"])
	if d0 < 0 or d1 < 0:
		r.why = "a port is not square to the body's axes"
		return false
	var s := spigot(r)
	var p0: Vector3 = r.from["position"]
	var p1: Vector3 = r.to["position"]
	var a := p0 + Vector3(DIRS[d0]) * s
	var b := p1 + Vector3(DIRS[d1]) * s
	# The legs: the start spigot's end, each via point, the end spigot's end.
	var marks: Array = [[a, d0, []]]
	for v: Array in r.via:
		var dv := dir_index(v[1])
		if dv < 0:
			r.why = "a via point's heading is not square to the body's axes"
			return false
		marks.append([v[0], dv, v[2] if v.size() > 2 else []])
	var pts := PackedVector3Array([p0])
	var k := -1
	r.steps = 0
	for i in marks.size():
		var last := i == marks.size() - 1
		# The parts passable round this leg's via points.
		var near: Array = []
		for m: Array in ([marks[i]] if last else [marks[i], marks[i + 1]]):
			if not (m[2] as Array).is_empty():
				near.append([m[0], m[2]])
		var leg := _leg(r, marks[i][0], marks[i][1], k, b if last else marks[i + 1][0], d1 ^ 1 if last else int(marks[i + 1][1]),
				d1 if last else -1, "" if marks.size() == 1 else " (leg %d of %d)" % [i + 1, marks.size()], near)
		if leg.is_empty():
			return false
		pts.append_array(leg["points"])
		k = leg["k"]
	pts.append(p1)
	r.points = _straighten(pts)
	return true


## One leg of run `r`'s search: from `a` heading `d0` (`k0` steps straight behind it; -1 a
## spigot's end, as straight as it needs) to `b`, arriving heading `arrive`; `end_dir` is the end
## spigot's direction on the last leg (a bend at `b` into the spigot then allowed), -1 on a leg to
## a via point (passed straight through); `near` the via points' passable parts ([point, part ids]
## each). Returns {points: a, the bends, b; k: steps straight at `b`}, or {} with `r.why` set.
func _leg(r: Run, a: Vector3, d0: int, k0: int, b: Vector3, arrive: int, end_dir: int, which: String,
		near: Array = []) -> Dictionary:
	# A leg straight on between two via points heading its way is taken as it is when nothing is
	# in its way (a long run's long stretches: no grid to fill).
	var k_line := ceili((2.0 * bend_radius(r) + 0.012) / RUN_STEP)
	if end_dir < 0 and d0 == arrive and (b - a).length() > cell and (b - a).normalized().dot(Vector3(DIRS[d0])) > 0.9999 \
			and _clear_line(r, a, b, near):
		return {"points": PackedVector3Array([a, b]), "k": mini((k_line if k0 < 0 else k0) + floori(a.distance_to(b) / RUN_STEP), k_line)}
	# And one square bend between two via points (round a corner the run was given) the same way.
	if end_dir < 0 and (d0 >> 1) != (arrive >> 1):
		var u0 := Vector3(DIRS[d0])
		var u1 := Vector3(DIRS[arrive])
		var corner := a + u0 * (b - a).dot(u0)
		var first := corner.distance_to(a)
		var then := (b - corner).dot(u1)
		var k_at := (k_line if k0 < 0 else k0) + floori(first / RUN_STEP + 0.001)
		if (b - corner - u1 * then).length() < 0.0005 and (corner - a).dot(u0) > 0.0 and then > 0.0 \
				and k_at >= k_line and then >= bend_radius(r) + 0.006 \
				and not (_along_z(d0, arrive) and _near_station(corner.z, bend_radius(r) + union_length(r) * 0.5 + 0.015)) \
				and _clear_line(r, a, corner, near) and _clear_line(r, corner, b, near):
			return {"points": PackedVector3Array([a, corner, b]), "k": mini(floori(then / RUN_STEP + 0.001), k_line)}
	var region := AABB(a, Vector3.ZERO).expand(b).grow(margin)
	for i in 3:
		_ax[i] = _axis(region.position[i], region.end[i], [a[i], b[i]])
	_n = Vector3i(_ax[0].size(), _ax[1].size(), _ax[2].size())
	# The region as the grid reaches (its last values run past it).
	var lo := Vector3(_ax[0][0], _ax[1][0], _ax[2][0])
	var hi := Vector3(_ax[0][_n.x - 1], _ax[1][_n.y - 1], _ax[2][_n.z - 1])
	region = AABB(lo, hi - lo).grow(0.001)
	_cells = PackedByteArray()
	_cells.resize(_n.x * _n.y * _n.z)
	_raster(r, region, near)
	var ia := _index_of(a)
	var ib := _index_of(b)
	var start := _flat(ia)
	var goal := _flat(ib)
	if _cells[start] & 1 or _cells[goal] & 1:
		var at := a if _cells[start] & 1 else b
		r.why = "a spigot's end is blocked (%s, at %s, by %s)%s" % ["start" if _cells[start] & 1 else "end", at, _blocker(r, at), which]
		return {}
	_dist = PackedInt32Array()
	if guided:
		_dist = _cost_to_go(goal)
		if _dist[start] < 0:
			r.why = "no way through (the ends are walled apart)%s" % which
			return {}
	var bend := bend_radius(r)
	var k_max := ceili((2.0 * bend + 0.012) / RUN_STEP)
	# A*: state = (cell * 6 + heading) * (k_max + 1) + metres-since-bend steps.
	var ks := k_max + 1
	# No bend into or out of a run along the body where its union at a station would not fit.
	var union_room := bend + union_length(r) * 0.5 + 0.015
	var g := {}
	var parent := {}
	var heap_f := PackedFloat64Array()
	var heap_s := PackedInt64Array()
	var s0 := (start * 6 + d0) * ks + (k_max if k0 < 0 else mini(k0, k_max))
	g[s0] = 0.0
	parent[s0] = -1
	_push(heap_f, heap_s, _h(ia, ib, start, d0), s0)
	var found := -1
	var steps := 0
	while not heap_s.is_empty():
		var top := _pop(heap_f, heap_s)
		var st: int = top[1]
		var gs: float = g[st]
		if float(top[0]) > gs + _h(_unflat(st / ks / 6), ib, st / ks / 6, (st / ks) % 6) + 1e-6:
			continue
		steps += 1
		if steps > max_steps:
			break
		var k := st % ks
		var heading := (st / ks) % 6
		var c := st / ks / 6
		if c == goal and (heading == arrive or (end_dir >= 0 and k == k_max and heading != end_dir
				and not (_along_z(heading, arrive) and _near_station(_pos(_unflat(c)).z, union_room)))):
			found = st
			break
		var at := _unflat(c)
		for d2 in 6:
			if d2 == (heading ^ 1):
				continue
			var turning := d2 != heading
			if turning and (k < k_max or (_along_z(heading, d2) and _near_station(_pos(at).z, union_room))):
				continue
			var nxt := at + DIRS[d2]
			if nxt.x < 0 or nxt.y < 0 or nxt.z < 0 or nxt.x >= _n.x or nxt.y >= _n.y or nxt.z >= _n.z:
				continue
			var nc := _flat(nxt)
			var flags := _cells[nc]
			if flags & 1:
				continue
			var length := _pos(nxt).distance_to(_pos(at))
			var cost := length * _cost(flags, _pos(nxt).y)
			if turning:
				cost += turn_cost
			var nk := mini((0 if turning else k) + floori(length / RUN_STEP + 0.001), k_max)
			var ns := (nc * 6 + d2) * ks + nk
			var ng := gs + cost
			if not g.has(ns) or ng < float(g[ns]) - 1e-9:
				g[ns] = ng
				parent[ns] = st
				_push(heap_f, heap_s, ng + _h(nxt, ib, nc, d2), ns)
	r.steps += steps
	if found < 0:
		r.why = "no way through (%d steps)%s" % [steps, which]
		if OS.has_environment("PIPE_DEBUG"):
			var reached := AABB(_pos(ia), Vector3.ZERO)
			for key: int in g:
				reached = reached.expand(_pos(_unflat(key / ks / 6)))
			print("PipeRouter: %s from %s to %s reached %s .. %s%s" % [r.name, a, b, reached.position, reached.end, which])
			for d2 in 6:
				for step in 4:
					var qq := ib + DIRS[d2] * (step + 1)
					if qq.x < 0 or qq.y < 0 or qq.z < 0 or qq.x >= _n.x or qq.y >= _n.y or qq.z >= _n.z:
						break
					if _cells[_flat(qq)] & 1:
						print("  from the end %s: blocked at %s by %s" % [DIRS[d2], _pos(qq), _blocker(r, _pos(qq))])
						break
		return {}
	# Back from the end: the grid points, and where the heading changes, the bends.
	var chain: Array[int] = []
	var u := found
	while u >= 0:
		chain.push_front(u)
		u = parent[u]
	var pts := PackedVector3Array()
	var last := d0
	for i in chain.size():
		var st: int = chain[i]
		var heading := (st / ks) % 6
		var here := _pos(_unflat(st / ks / 6))
		if i == 0:
			pts.append(here)
			continue
		if heading != last:
			# The bend is at the point before this one.
			var before := _pos(_unflat(chain[i - 1] / ks / 6))
			if pts[pts.size() - 1].distance_to(before) > 0.0005:
				pts.append(before)
			last = heading
	pts.append(b)
	return {"points": pts, "k": found % ks}


## Grid values from `lo` to `hi` every `cell`, with `must` among them (a regular value too
## near one gives way to it).
func _axis(lo: float, hi: float, must: Array) -> PackedFloat64Array:
	var vals: Array[float] = []
	for m: float in must:
		vals.append(m)
	var count := ceili((hi - lo) / cell)
	for i in count + 1:
		var v := lo + float(i) * cell
		var near := false
		for m: float in must:
			near = near or absf(v - m) < cell * 0.4
		if not near:
			vals.append(v)
	vals.sort()
	var out := PackedFloat64Array()
	for v in vals:
		if out.is_empty() or v - out[out.size() - 1] > 0.002:
			out.append(v)
	return out


func _flat(i: Vector3i) -> int:
	return (i.z * _n.y + i.y) * _n.x + i.x


func _unflat(c: int) -> Vector3i:
	return Vector3i(c % _n.x, (c / _n.x) % _n.y, c / _n.x / _n.y)


func _pos(i: Vector3i) -> Vector3:
	return Vector3(_ax[0][i.x], _ax[1][i.y], _ax[2][i.z])


func _index_of(p: Vector3) -> Vector3i:
	return Vector3i(_nearest(_ax[0], p.x), _nearest(_ax[1], p.y), _nearest(_ax[2], p.z))


static func _nearest(axis: PackedFloat64Array, v: float) -> int:
	var i := axis.bsearch(v)
	if i >= axis.size():
		return axis.size() - 1
	if i > 0 and absf(axis[i - 1] - v) < absf(axis[i] - v):
		return i - 1
	return i


## The first and last grid index along `axis` inside [lo, hi] (empty: x > y).
static func _range(axis: PackedFloat64Array, lo: float, hi: float) -> Vector2i:
	return Vector2i(axis.bsearch(lo), axis.bsearch(hi, false) - 1)


func _cost(flags: int, y: float) -> float:
	var c := hug_cost if flags & 2 else 1.0
	if y > low_y:
		c *= high_cost
	if flags & 4:
		c *= room_cost
	return c


## The search's guess of the cost left from grid point `i` (flat index `c`, heading `heading`)
## to `goal`: the straight line's metres, or guided the map's cost left and the bends owed.
func _h(i: Vector3i, goal: Vector3i, c: int = -1, heading: int = -1) -> float:
	if not _dist.is_empty() and c >= 0 and _dist[c] >= 0:
		return (float(_dist[c]) * TOGO_UNIT + turn_cost * _turns_left(i, goal, heading)) * heuristic
	var p := _pos(i)
	var q := _pos(goal)
	return (absf(p.x - q.x) + absf(p.y - q.y) + absf(p.z - q.z)) * heuristic


## The fewest bends a run at grid point `i` heading `heading` makes on its way to `goal`: one
## onto each other axis it must travel along, one more to come back along its own.
static func _turns_left(i: Vector3i, goal: Vector3i, heading: int) -> int:
	if heading < 0:
		return 0
	var axis := heading >> 1
	var turns := 0
	for a in 3:
		if a != axis and i[a] != goal[a]:
			turns += 1
	var ahead: int = goal[axis] - i[axis]
	if ahead != 0 and (ahead > 0) != (heading & 1 == 0):
		turns += 1 if turns > 0 else 2
	return turns


## The cost from every grid point to grid point `goal` the cheapest way through points not
## blocked (six ways, each point entered at the search's own cost a metre, turns aside), in
## steps of `TOGO_UNIT`; -1 where it can't get. Dial's buckets: the costs are small whole steps.
func _cost_to_go(goal: int) -> PackedInt32Array:
	var cells := _cells
	var total := cells.size()
	var nx := _n.x
	var ny := _n.y
	var nz := _n.z
	var nxy := nx * ny
	var ys: PackedFloat64Array = _ax[1]
	# A point's cost a metre to enter by its flags (beside a member 2, in a room 4) and whether
	# it is above low_y (1), in steps of TOGO_UNIT.
	var per_m := PackedFloat32Array()
	per_m.resize(8)
	for k in 8:
		var c := hug_cost if k & 2 else 1.0
		if k & 1:
			c *= high_cost
		if k & 4:
			c *= room_cost
		per_m[k] = c / TOGO_UNIT
	var high := PackedByteArray()
	high.resize(ny)
	for y in ny:
		high[y] = 1 if ys[y] > low_y else 0
	var gaps: Array = []
	var widest := cell
	for i in 3:
		var axis: PackedFloat64Array = _ax[i]
		var gap_i := PackedFloat32Array()
		gap_i.resize(maxi(axis.size() - 1, 0))
		for j in axis.size() - 1:
			gap_i[j] = axis[j + 1] - axis[j]
			widest = maxf(widest, gap_i[j])
		gaps.append(gap_i)
	var gx: PackedFloat32Array = gaps[0]
	var gy: PackedFloat32Array = gaps[1]
	var gz: PackedFloat32Array = gaps[2]
	var dearest := 0.0
	for k in 8:
		dearest = maxf(dearest, per_m[k])
	# Buckets by cost, round as many as the dearest single step needs.
	var count := ceili(widest * dearest) + 2
	var buckets: Array = []
	buckets.resize(count)
	for i in count:
		buckets[i] = []
	var dist := PackedInt32Array()
	dist.resize(total)
	dist.fill(-1)
	var done := PackedByteArray()
	done.resize(total)
	dist[goal] = 0
	(buckets[0] as Array).append(goal)
	var left := 1
	var at := 0
	while left > 0:
		var bucket: Array = buckets[at % count]
		if bucket.is_empty():
			at += 1
			continue
		var v: int = bucket.pop_back()
		left -= 1
		if done[v] or dist[v] != at:
			continue
		done[v] = 1
		var x := v % nx
		var y := (v / nx) % ny
		var z := v / nxy
		# Entering v from a neighbour u costs the step's length at v's own cost.
		var f := per_m[(cells[v] & 6) | high[y]]
		var u := v - 1
		var du := 0
		if x > 0 and not done[u] and not (cells[u] & 1):
			du = at + maxi(1, floori(gx[x - 1] * f))
			if dist[u] < 0 or du < dist[u]:
				dist[u] = du
				(buckets[du % count] as Array).append(u)
				left += 1
		u = v + 1
		if x < nx - 1 and not done[u] and not (cells[u] & 1):
			du = at + maxi(1, floori(gx[x] * f))
			if dist[u] < 0 or du < dist[u]:
				dist[u] = du
				(buckets[du % count] as Array).append(u)
				left += 1
		u = v - nx
		if y > 0 and not done[u] and not (cells[u] & 1):
			du = at + maxi(1, floori(gy[y - 1] * f))
			if dist[u] < 0 or du < dist[u]:
				dist[u] = du
				(buckets[du % count] as Array).append(u)
				left += 1
		u = v + nx
		if y < ny - 1 and not done[u] and not (cells[u] & 1):
			du = at + maxi(1, floori(gy[y] * f))
			if dist[u] < 0 or du < dist[u]:
				dist[u] = du
				(buckets[du % count] as Array).append(u)
				left += 1
		u = v - nxy
		if z > 0 and not done[u] and not (cells[u] & 1):
			du = at + maxi(1, floori(gz[z - 1] * f))
			if dist[u] < 0 or du < dist[u]:
				dist[u] = du
				(buckets[du % count] as Array).append(u)
				left += 1
		u = v + nxy
		if z < nz - 1 and not done[u] and not (cells[u] & 1):
			du = at + maxi(1, floori(gz[z] * f))
			if dist[u] < 0 or du < dist[u]:
				dist[u] = du
				(buckets[du % count] as Array).append(u)
				left += 1
	return dist


static func _push(keys: PackedFloat64Array, vals: PackedInt64Array, key: float, val: int) -> void:
	keys.append(key)
	vals.append(val)
	var i := keys.size() - 1
	while i > 0:
		var up := (i - 1) / 2
		if keys[up] <= keys[i]:
			break
		var tk := keys[up]
		keys[up] = keys[i]
		keys[i] = tk
		var tv := vals[up]
		vals[up] = vals[i]
		vals[i] = tv
		i = up


static func _pop(keys: PackedFloat64Array, vals: PackedInt64Array) -> Array:
	var out := [keys[0], vals[0]]
	var last := keys.size() - 1
	keys[0] = keys[last]
	vals[0] = vals[last]
	keys.resize(last)
	vals.resize(last)
	var i := 0
	while true:
		var l := i * 2 + 1
		var rr := l + 1
		var m := i
		if l < last and keys[l] < keys[m]:
			m = l
		if rr < last and keys[rr] < keys[m]:
			m = rr
		if m == i:
			break
		var tk := keys[m]
		keys[m] = keys[i]
		keys[i] = tk
		var tv := vals[m]
		vals[m] = vals[i]
		vals[i] = tv
		i = m
	return out


## Whether run `r` may lie straight from `a` to `b`: clear of every part (but its glands, and
## those it may pass near its ends and `near`'s via points) and every lead, as the grid would be.
func _clear_line(r: Run, a: Vector3, b: Vector3, near: Array) -> bool:
	var clear := maxf(r.radius + gap, r.radius * ShipParts.UNION_FLARE + 0.006)
	var ends: Array[Vector3] = [r.from["position"], r.to["position"]]
	var near_ends: Array[int] = [(r.from["part"] as PartData).id, (r.to["part"] as PartData).id]
	near_ends.append_array(r.through)
	for n: Array in near:
		ends.append(n[0])
		for id: int in n[1]:
			near_ends.append(id)
	var line := AABB(a, Vector3.ZERO).expand(b)
	var steps := maxi(1, ceili(a.distance_to(b) / (cell * 0.5)))
	# A turned part's box grown in its own space reaches up to sqrt(3) times as far past its
	# placed box: these boxes only pass parts on to the exact test, so they are grown twice.
	for e: Array in _entries_near(line.grow(clear * 2.0)):
		if not (e[4] as AABB).grow(clear * 2.0).intersects(line):
			continue
		var id: int = e[0]
		if r.glands.has(id):
			continue
		var box: AABB = (e[1] as AABB).grow(clear)
		var inv: Transform3D = e[3]
		var passable := near_ends.has(id)
		var placed := (e[4] as AABB).grow(clear * 2.0)
		for i in steps + 1:
			var p := a.lerp(b, float(i) / float(steps))
			if placed.has_point(p) and box.has_point(inv * p) and not (passable and _near_any(p, ends)):
				return false
	for lead: Array in avoid:
		var pts: PackedVector3Array = lead[0]
		var reach: float = float(lead[1]) + clear
		for i in pts.size() - 1:
			var q := Geometry3D.get_closest_points_between_segments(a, b, pts[i], pts[i + 1])
			if q[0].distance_to(q[1]) < reach:
				return false
	return true


## Every part with a look: [id, its look's box (part space), its transform, the inverse, the box
## placed (body space)], kept as the runs add theirs (parts are only added while pipes are laid).
func _part_index() -> Array:
	if model.parts.size() != _index_seen:
		for p: PartData in model.parts.values():
			if _indexed.has(p.id):
				continue
			_indexed[p.id] = []
			var vis := model.part_visual(p.id) as MeshInstance3D
			if vis == null or vis.mesh == null:
				continue
			var box: AABB = vis.mesh.get_aabb()
			var entry := [p.id, box, p.local_transform, p.local_transform.affine_inverse(), p.local_transform * box]
			_indexed[p.id] = entry
			_index.append(entry)
			# Filed in the 1 m cells its placed box covers.
			var placed: AABB = entry[4]
			var c0 := Vector3i((placed.position / INDEX_CELL).floor())
			var c1 := Vector3i((placed.end / INDEX_CELL).floor())
			for x in range(c0.x, c1.x + 1):
				for y in range(c0.y, c1.y + 1):
					for z in range(c0.z, c1.z + 1):
						var key := Vector3i(x, y, z)
						if not _index_cells.has(key):
							_index_cells[key] = []
						(_index_cells[key] as Array).append(_index.size() - 1)
		_index_seen = model.parts.size()
	return _index


## The index's entries whose placed boxes may meet `box` (body space), in the index's order.
func _entries_near(box: AABB) -> Array:
	_part_index()
	var c0 := Vector3i((box.position / INDEX_CELL).floor())
	var c1 := Vector3i((box.end / INDEX_CELL).floor())
	var picked := {}
	for x in range(c0.x, c1.x + 1):
		for y in range(c0.y, c1.y + 1):
			for z in range(c0.z, c1.z + 1):
				for i: int in _index_cells.get(Vector3i(x, y, z), []):
					picked[i] = true
	var order: Array = picked.keys()
	order.sort()
	var out: Array = []
	for i: int in order:
		out.append(_index[i])
	return out


## Marks the grid: blocked near every part (and lead), beside a member, inside a room; `near`
## ([point, part ids] each) the parts passable within pass_reach of a via point, as at the ends.
func _raster(r: Run, region: AABB, near: Array = []) -> void:
	# Clear of the pipe and of its unions' flanges.
	var clear := maxf(r.radius + gap, r.radius * ShipParts.UNION_FLARE + 0.006)
	var ends: Array[Vector3] = [r.from["position"], r.to["position"]]
	var near_ends: Array[int] = [(r.from["part"] as PartData).id, (r.to["part"] as PartData).id]
	near_ends.append_array(r.through)
	for n: Array in near:
		ends.append(n[0])
		for id: int in n[1]:
			near_ends.append(id)
	var near_region := region.grow((clear + hug) * 2.0)   # turned parts: see _clear_line
	for e: Array in _entries_near(near_region):
		if not (e[4] as AABB).intersects(near_region):
			continue
		var id: int = e[0]
		if r.glands.has(id):
			continue
		var box: AABB = e[1]
		var xf: Transform3D = e[2]
		var inv: Transform3D = e[3]
		var passable := near_ends.has(id)
		_mark_box(box.grow(clear), xf, inv, region, 1, passable, ends)
		if members.has(id):
			_mark_box(box.grow(clear + hug), xf, inv, region, 2, false, ends)
	for line: Array in avoid:
		var pts: PackedVector3Array = line[0]
		var reach: float = float(line[1]) + clear
		for i in pts.size() - 1:
			_mark_segment(pts[i], pts[i + 1], reach, region)
	for room in rooms:
		var hit := room.intersection(region)
		if not hit.has_volume():
			continue
		var rx := _range(_ax[0], hit.position.x, hit.end.x)
		var ry := _range(_ax[1], hit.position.y, hit.end.y)
		var rz := _range(_ax[2], hit.position.z, hit.end.z)
		for z in range(rz.x, rz.y + 1):
			for y in range(ry.x, ry.y + 1):
				for x in range(rx.x, rx.y + 1):
					var i := Vector3i(x, y, z)
					var p := _pos(i)
					# A spigot may stand in a room: its way out costs nothing extra (nor a via
					# point's way through a floor beside it).
					if _near_any(p, ends):
						continue
					var c := _flat(i)
					_cells[c] = _cells[c] | 4


## Sets `bit` on every grid point inside `box` (part space, placed by `xf`); a `passable`
## part leaves the points within pass_reach of the run's ends alone.
func _mark_box(box: AABB, xf: Transform3D, inv: Transform3D, region: AABB, bit: int, passable: bool,
		ends: Array[Vector3]) -> void:
	var world := (xf * box).intersection(region)
	if not world.has_volume():
		return
	var rx := _range(_ax[0], world.position.x, world.end.x)
	var ry := _range(_ax[1], world.position.y, world.end.y)
	var rz := _range(_ax[2], world.position.z, world.end.z)
	for z in range(rz.x, rz.y + 1):
		for y in range(ry.x, ry.y + 1):
			for x in range(rx.x, rx.y + 1):
				var i := Vector3i(x, y, z)
				var c := _flat(i)
				if _cells[c] & bit:
					continue
				var p := _pos(i)
				if not box.has_point(inv * p):
					continue
				if passable and _near_any(p, ends):
					continue
				_cells[c] = _cells[c] | bit


func _near_any(p: Vector3, ends: Array[Vector3]) -> bool:
	for e in ends:
		if p.distance_to(e) < pass_reach:
			return true
	return false


func _mark_segment(a: Vector3, b: Vector3, reach: float, region: AABB) -> void:
	var world := AABB(a, Vector3.ZERO).expand(b).grow(reach).intersection(region)
	if not world.has_volume():
		return
	var rx := _range(_ax[0], world.position.x, world.end.x)
	var ry := _range(_ax[1], world.position.y, world.end.y)
	var rz := _range(_ax[2], world.position.z, world.end.z)
	for z in range(rz.x, rz.y + 1):
		for y in range(ry.x, ry.y + 1):
			for x in range(rx.x, rx.y + 1):
				var i := Vector3i(x, y, z)
				var p := _pos(i)
				if Geometry3D.get_closest_point_to_segment(p, a, b).distance_to(p) < reach:
					var c := _flat(i)
					_cells[c] = _cells[c] | 1


## What keeps a run from `p` (debugging): the parts and leads within its clearance.
func _blocker(r: Run, p: Vector3) -> String:
	var clear := maxf(r.radius + gap, r.radius * ShipParts.UNION_FLARE + 0.006)
	var out: PackedStringArray = []
	for part: PartData in model.parts.values():
		var vis := model.part_visual(part.id) as MeshInstance3D
		if vis == null or vis.mesh == null:
			continue
		if vis.mesh.get_aabb().grow(clear).has_point(part.local_transform.affine_inverse() * p):
			out.append(part.path if part.path != "" else part.part_name)
	for line: Array in avoid:
		var pts: PackedVector3Array = line[0]
		for i in pts.size() - 1:
			if Geometry3D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p) < float(line[1]) + clear:
				out.append("a lead")
				break
	return ", ".join(out)


## Drops points on a straight line (and repeats).
static func _straighten(pts: PackedVector3Array) -> PackedVector3Array:
	var clean := PackedVector3Array()
	for p in pts:
		if clean.is_empty() or clean[clean.size() - 1].distance_to(p) > 0.0005:
			clean.append(p)
	var out := PackedVector3Array()
	for i in clean.size():
		if i > 0 and i < clean.size() - 1:
			var d1 := (clean[i] - clean[i - 1]).normalized()
			var d2 := (clean[i + 1] - clean[i]).normalized()
			if d1.dot(d2) > 0.999:
				continue
		out.append(clean[i])
	return out


# --- The parts ----------------------------------------------------------------------------

## Builds run `r`'s parts along its corners: a span per straight (split at each station it
## crosses, a union there), an elbow at each corner, clips, and its ends bolted to its ports.
func _build(r: Run) -> void:
	var phase_was := target.phase
	target.phase = "service"
	var bend := bend_radius(r)
	var pts := r.points
	var n := pts.size()
	var tag := "pipe:%s" % r.name
	var union_len := union_length(r)
	var pieces: Array = []   # [part, start, end] along the run, in order
	var elbow_at: Array = []   # per corner: [elbow part, tangent in, tangent out]
	for i in range(1, n - 1):
		var d_in := (pts[i] - pts[i - 1]).normalized()
		var d_out := (pts[i + 1] - pts[i]).normalized()
		var t_in := pts[i] - d_in * bend
		var x := d_in.cross(d_out).normalized()
		var xf := Transform3D(Basis(x, d_in, d_out), t_in)
		var elbow := target.pipe_part("PipeElbow", ShipParts.pipe_elbow_shape(r.radius, bend), xf, r.mat,
				"%s/elbow/%d" % [tag, r.elbows.size()])
		r.elbows.append(elbow)
		elbow_at.append([elbow, t_in, pts[i] + d_out * bend])
	var through_ids: Array[int] = r.through.duplicate()
	through_ids.append_array(r.glands)
	for v: Array in r.via:
		for id: int in (v[2] if v.size() > 2 else []):
			through_ids.append(id)
	var end_ids: Array[int] = [(r.from["part"] as PartData).id, (r.to["part"] as PartData).id]
	var passes: Array[int] = []   # what the run passes through anywhere: its glands, the floors at its via points
	passes.append_array(r.glands)
	for v: Array in r.via:
		for id: int in (v[2] if v.size() > 2 else []):
			passes.append(id)
	for leg in n - 1:
		var d := (pts[leg + 1] - pts[leg]).normalized()
		var a: Vector3 = pts[leg] if leg == 0 else (elbow_at[leg - 1][2] as Vector3)
		var b: Vector3 = pts[leg + 1] if leg == n - 2 else (elbow_at[leg][1] as Vector3)
		var length := (b - a).dot(d)
		if length < 0.005:
			r.why = "a stretch shorter than its bends"
			continue
		# The stations this leg crosses along the body: a union at each.
		var cuts: Array = []   # [metres along, label]
		if absf(d.z) > 0.99:
			for st: Array in stations:
				var z: float = st[0]
				# Crossed anywhere between the leg's corners (a bend there leaves no room: missed).
				if (z - pts[leg].z) * (z - pts[leg + 1].z) >= 0.0:
					continue
				var t := (z - a.z) / d.z
				var lo := union_len * 0.5 + 0.01
				if t < lo - 0.005 or t > length - lo + 0.005:
					r.missed.append(String(st[1]))
					continue
				var ct := clampf(t, lo, length - lo)
				# A union is no gland: one in a member the run passes through (a station's beam it
				# crosses) slides along it till it clears.
				if not passes.is_empty() and _union_hits(a + d * ct, d, union_len, r.radius, passes):
					for k in range(1, 31):
						var moved := -1.0
						for sgn: float in [1.0, -1.0]:
							var tt := ct + sgn * 0.02 * k
							if tt >= lo and tt <= length - lo and not _union_hits(a + d * tt, d, union_len, r.radius, passes):
								moved = tt
								break
						if moved >= 0.0:
							ct = moved
							break
				cuts.append([ct, String(st[1])])
		cuts.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
		var from_t := 0.0
		for cut: Array in cuts:
			var ct: float = cut[0]
			pieces.append([_span(r, a + d * from_t, a + d * (ct - union_len * 0.5), d, through_ids, end_ids), "span"])
			var label: String = cut[1]
			var upath := "%s/union:st:%s" % [tag, label]
			if r.crossed.has(label):
				upath += "/%d" % r.crossed.count(label)
			var union := target.pipe_part("PipeUnion", ShipParts.pipe_union_shape(r.radius, union_len),
					Transform3D(_along(d), a + d * ct), r.mat, upath)
			r.unions.append(union)
			r.crossed.append(label)
			pieces.append([union, "union"])
			from_t = ct + union_len * 0.5
		pieces.append([_span(r, a + d * from_t, b, d, through_ids, end_ids), "span"])
		if leg < n - 2:
			pieces.append([elbow_at[leg][0], "elbow"])
	# Joints along the run: span to elbow welded, span to union bolted at its flange.
	for i in pieces.size() - 1:
		var p: PartData = pieces[i][0]
		var q: PartData = pieces[i + 1][0]
		if p == null or q == null:
			continue
		var at := _meet(p, q)
		var span: PartData = p if pieces[i][1] == "span" else q
		var other: PartData = q if span == p else p
		if pieces[i][1] == "union" or pieces[i + 1][1] == "union":
			for k in 2:
				var side := _across(span) * r.radius * 1.6 * (1.0 if k == 0 else -1.0)
				target.join(other, span, ConnectionData.Kind.BOLT, at + side, side.normalized(), Vector3.ZERO, Vector2.ZERO,
						"%s/bolt:%s/%d" % [other.path, span.path.trim_prefix(tag + "/"), k])
		else:
			# A bead on the pipe's skin across the seam (its head on the surface, not inside the pipe).
			var up := _across(span).cross(_axis_of(span)).normalized()
			target.join(span, other, ConnectionData.Kind.WELD, at + up * r.radius, up, _across(span),
					Vector2(r.radius * 1.6, 0.008), "%s/weld:%s" % [span.path, other.path.trim_prefix(tag + "/")])
	# The ends, bolted to the parts at their spigots.
	var spans_in_order: Array[PartData] = []
	for pc: Array in pieces:
		if pc[1] == "span" and pc[0] != null:
			spans_in_order.append(pc[0])
	if not spans_in_order.is_empty():
		for e: Array in [[spans_in_order[0], r.from], [spans_in_order[spans_in_order.size() - 1], r.to]]:
			var span: PartData = e[0]
			var port: Dictionary = e[1]
			var holder: PartData = port["part"]
			for k in 2:
				var side := _across(span) * r.radius * 1.5 * (1.0 if k == 0 else -1.0)
				var c := target.join(span, holder, ConnectionData.Kind.BOLT, (port["position"] as Vector3) + side,
						-(port["direction"] as Vector3), Vector3.ZERO, Vector2.ZERO, "%s/bolt:%s/%d" % [span.path, holder.path, k])
				if c:
					r.ends.append(c)
	for span in r.spans:
		_clip(r, span)
	r.ok = r.why == "" and r.missed.is_empty()
	target.phase = phase_was


## Whether a union of `length` on a pipe of `radius` at `at` (heading `d`) runs into a part of
## `ids` (their looks, sampled at its ends, middle and flange's corners).
func _union_hits(at: Vector3, d: Vector3, length: float, radius: float, ids: Array[int]) -> bool:
	_part_index()
	var basis := _along(d)
	var fr := radius * ShipParts.UNION_FLARE + 0.006
	var half := length * 0.5 + 0.006
	var reach := AABB(at, Vector3.ZERO).grow(half + fr)
	for id: int in ids:
		var e: Array = _indexed.get(id, [])
		if e.is_empty() or not (e[4] as AABB).intersects(reach):
			continue
		var box: AABB = e[1]
		var inv: Transform3D = e[3]
		for ty: float in [-half, 0.0, half]:
			for tx: float in [-fr, 0.0, fr]:
				for tz: float in [-fr, 0.0, fr]:
					if box.has_point(inv * (at + basis * Vector3(tx, ty, tz))):
						return true
	return false


## A span from `a` to `b` (heading `d`) of run `r`: its collision only where it clears every
## part it passes (the parts near its ends), collars where it goes through a panel.
func _span(r: Run, a: Vector3, b: Vector3, d: Vector3, through: Array[int], end_ids: Array[int]) -> PartData:
	var length := a.distance_to(b)
	var mid := (a + b) * 0.5
	# Sample along it: where it lies in a part it passes, no collision (and a collar at each face).
	var passed: Array[int] = []
	# Only what reaches the span (the samples below test each part at every centimetre).
	_part_index()
	var reach := AABB(a, Vector3.ZERO).expand(b).grow((r.radius + 0.006) * 2.0)   # turned parts: see _clear_line
	for list: Array[int] in [through, end_ids]:
		for id: int in list:
			var e: Array = _indexed.get(id, [])
			if not e.is_empty() and (e[4] as AABB).intersects(reach):
				passed.append(id)
	var steps := maxi(2, ceili(length / 0.01))
	var solid: Array = []   # [y0, y1] part space (Y along it, from -length/2)
	var collars: Array[float] = []
	var run_start := -1.0
	var was_inside := false
	var clear_t: Array[float] = []
	for i in steps + 1:
		var t := length * float(i) / float(steps)
		var p := a + d * t
		var inside := false
		var in_panel := false
		var in_any := false
		for id: int in passed:
			var part: PartData = model.parts.get(id)
			if part == null:
				continue
			var vis := model.part_visual(id) as MeshInstance3D
			if vis == null or vis.mesh == null:
				continue
			var box: AABB = vis.mesh.get_aabb()
			var q := part.local_transform.affine_inverse() * p
			if box.grow(r.radius + 0.006).has_point(q):
				inside = true
			if box.has_point(q):
				in_any = true
				if through.has(id):
					in_panel = true
		if not in_any:
			clear_t.append(t)
		if not inside and run_start < 0.0:
			run_start = t
		if inside and run_start >= 0.0:
			if t - run_start > 0.02:
				solid.append([run_start - length * 0.5, t - length * 0.5])
			run_start = -1.0
		if in_panel != was_inside and i > 0:
			collars.append(t - length * 0.5)
		was_inside = in_panel
	if run_start >= 0.0 and length - run_start > 0.02:
		solid.append([run_start - length * 0.5, length * 0.5])
	# Wholly within what it passes (through a skin plate): a speck of collision where it is out.
	if solid.is_empty():
		var ct := length * 0.5 if clear_t.is_empty() else clear_t[clear_t.size() / 2]
		solid.append([ct - length * 0.5 - 0.0005, ct - length * 0.5 + 0.0005])
	# The ends that meet another pipe part keep a hair of gap.
	for s: Array in solid:
		s[0] = maxf(float(s[0]), -length * 0.5 + 0.006)
		s[1] = minf(float(s[1]), length * 0.5 - 0.006)
	var shape := ShipParts.pipe_shape(r.radius, length, solid, collars)
	var span := target.pipe_part("PipeSpan", shape, Transform3D(_along(d), mid), r.mat,
			"pipe:%s/span/%d" % [r.name, r.spans.size()])
	r.spans.append(span)
	if span:
		_bands(r, span, length, solid, collars)
	return span


## Paints span `span` of run `r` with its fluid's band (an arrow on it the way the fluid runs)
## BAND_IN from each end of a span `band_least` long or more, else (or where neither end is in
## the open) once in its middle if it is `band_one` long: only where the span is in the open and
## clear of a collar. Marks, looks only.
func _bands(r: Run, span: PartData, length: float, solid: Array, collars: Array[float]) -> void:
	if length < band_one:
		return
	var fluid := "jump" if r.name.begins_with("jump") else r.fluid
	var band := ShipParts.pipe_band_mesh(r.radius)
	var arrows := ShipParts.pipe_arrow_mesh(r.radius)
	var paint := ShipParts.pipe_band_material(fluid)
	var half := ShipParts.BAND_WIDTH * 0.5 + 0.01
	var spots: Array[float] = [0.0]
	if length >= band_least:
		spots = [-length * 0.5 + ShipParts.BAND_IN, length * 0.5 - ShipParts.BAND_IN]
	var laid := 0
	for pass_ in 2:
		for y: float in spots:
			var open := false
			for seg: Array in solid:
				if y - half >= float(seg[0]) and y + half <= float(seg[1]):
					open = true
			for c: float in collars:
				if absf(c - y) < half + 0.015:
					open = false
			if open:
				laid += 1
				var at := span.local_transform * Transform3D(Basis(), Vector3(0.0, y, 0.0))
				model.add_decor(span.id, band, paint, at)
				model.add_decor(span.id, arrows, ShipParts.pipe_arrow_material(), at)
		if laid > 0 or spots.size() == 1:
			return
		spots = [0.0]


## Clips span `span` of run `r` every clip_pitch to the member beside it, else the panel: a
## BOLT from the span to the holder, a band and a stem drawn on the span (a mark, so in the
## body's space like every mark, never the span's own).
func _clip(r: Run, span: PartData) -> void:
	var length := _length_of(span)
	if length < 0.2:
		return
	var count := maxi(1, roundi(length / clip_pitch))
	var axis := _axis_of(span)
	var mid := span.local_transform.origin
	var own: Dictionary = {}
	for list: Array in [r.spans, r.elbows, r.unions]:
		for p: PartData in list:
			own[p.id] = true
	var made := {}
	for m in count:
		var t := -length * 0.5 + length * (float(m) + 0.5) / float(count)
		var at := mid + axis * t
		var index := _entries_near(AABB(at, Vector3.ZERO).grow(r.radius + clip_reach))
		var best: PartData = null
		var best_d := INF
		var best_point := Vector3.ZERO
		for pass_members: bool in [true, false]:
			for e: Array in index:
				if not (e[4] as AABB).grow(r.radius + clip_reach).has_point(at):
					continue
				var p: PartData = model.parts.get(e[0])
				if p == null or own.has(p.id) or (members.has(p.id) != pass_members) or p.kind == PartData.Kind.GLASS:
					continue
				if not pass_members and p.kind == PartData.Kind.CONDUIT:
					continue
				var box: AABB = e[1]
				var local: Vector3 = (e[3] as Transform3D) * at
				var near := local.clamp(box.position, box.end)
				var dist := near.distance_to(local)
				if dist < best_d and dist <= r.radius + clip_reach:
					best_d = dist
					best = p
					best_point = (e[2] as Transform3D) * near
			if best:
				break
		if best == null:
			continue
		var toward := best_point - at
		toward -= axis * toward.dot(axis)
		var normal := toward.normalized() if toward.length() > 0.001 else _across(span)
		var n: int = made.get(best.path, 0)
		made[best.path] = n + 1
		var c := target.join(span, best, ConnectionData.Kind.BOLT, at + normal * r.radius, -normal, Vector3.ZERO,
				Vector2.ZERO, "%s/clip:%s/%d" % [span.path, best.path, n])
		if c:
			r.clips.append([c, span, best])
		var stem := maxf(toward.length() - r.radius, 0.0)
		model.add_decor(span.id, ShipParts.pipe_clip_mesh(r.radius, stem), ShipParts.mat("steel"),
				Transform3D(Basis(axis.cross(normal).normalized(), axis, normal), at))


## A basis whose Y runs along `d`.
static func _along(d: Vector3) -> Basis:
	var y := d.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


func _axis_of(span: PartData) -> Vector3:
	return span.local_transform.basis.y.normalized()


func _across(span: PartData) -> Vector3:
	return span.local_transform.basis.x.normalized()


func _length_of(span: PartData) -> float:
	var vis := model.part_visual(span.id) as MeshInstance3D
	return vis.mesh.get_aabb().size.y if vis and vis.mesh else 0.0


## Where two neighbouring pipe parts meet: the end of `p` nearest `q`'s middle.
func _meet(p: PartData, q: PartData) -> Vector3:
	var best := Vector3.ZERO
	var best_d := INF
	for part: PartData in [p, q]:
		var vis := model.part_visual(part.id) as MeshInstance3D
		var other: PartData = q if part == p else p
		if vis == null or vis.mesh == null:
			continue
		var ends := _ends_of(part)
		for e in ends:
			var d := INF
			for f in _ends_of(other):
				d = minf(d, e.distance_to(f))
			if d < best_d:
				best_d = d
				best = e
	return best


## A pipe part's two open ends (body space): a span's or union's along its Y, an elbow's from
## its origin and its far end.
func _ends_of(part: PartData) -> Array[Vector3]:
	var xf := part.local_transform
	if part.part_name == "PipeElbow":
		var bend: float = (model.part_visual(part.id) as MeshInstance3D).mesh.get_meta("bend", 0.0)
		return [xf.origin, xf * Vector3(0.0, bend, bend)]
	var half := _length_of(part) * 0.5
	return [xf * Vector3(0.0, -half, 0.0), xf * Vector3(0.0, half, 0.0)]


## One line per run, for tests and the log.
func report() -> Array[String]:
	var out: Array[String] = []
	for r in runs:
		var length := 0.0
		for i in r.points.size() - 1:
			length += r.points[i].distance_to(r.points[i + 1])
		out.append("pipe:%s (%s, %.0f mm): %s, %.2f m, %d spans, %d elbows, %d unions, %d clips, %d steps, %d ms%s" % [
				r.name, r.fluid, r.radius * 2000.0, "laid" if r.ok else "FAILED (%s)" % r.why, length, r.spans.size(),
				r.elbows.size(), r.unions.size(), r.clips.size(), r.steps, r.msec,
				"" if r.missed.is_empty() else ", no room for a union at %s" % r.missed])
	return out
