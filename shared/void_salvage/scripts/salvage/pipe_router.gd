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
## Give up a run after this many search steps.
var max_steps: int = 3000000

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


func _init(into: FrameTarget = null) -> void:
	target = into
	if into:
		model = into.parts_model()


## Asks for a run named `run_name` of `fluid` and `radius` from `from` to `to` ({part,
## position, direction}: a port in body space on its part), passing `through` near its ends.
## Laid in the order asked, each clear of those before it, by `lay_all`.
func run(run_name: String, fluid: String, radius: float, from: Dictionary, to: Dictionary,
		mat: Material, through: Array[int] = []) -> Run:
	var r := Run.new()
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
	if target:
		target.begin_builder("pipes")
	_lay_all()
	if target:
		target.end_builder()


func _lay_all() -> void:
	for r in runs:
		var t := Time.get_ticks_msec()
		if _search(r):
			_build(r)
		r.msec = Time.get_ticks_msec() - t


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
	_raster(r, region)
	var ia := _index_of(a)
	var ib := _index_of(b)
	var start := _flat(ia)
	var goal := _flat(ib)
	if _cells[start] & 1 or _cells[goal] & 1:
		var at := a if _cells[start] & 1 else b
		r.why = "a spigot's end is blocked (%s, at %s, by %s)" % ["start" if _cells[start] & 1 else "end", at, _blocker(r, at)]
		return false
	var bend := bend_radius(r)
	var k_max := ceili((2.0 * bend + 0.012) / RUN_STEP)
	var arrive := d1 ^ 1   # heading into the end spigot: opposite its direction
	# A*: state = (cell * 6 + heading) * (k_max + 1) + metres-since-bend steps.
	var ks := k_max + 1
	# No bend into or out of a run along the body where its union at a station would not fit.
	var union_room := bend + union_length(r) * 0.5 + 0.015
	var g := {}
	var parent := {}
	var heap_f := PackedFloat64Array()
	var heap_s := PackedInt64Array()
	var s0 := (start * 6 + d0) * ks + k_max
	g[s0] = 0.0
	parent[s0] = -1
	_push(heap_f, heap_s, _h(ia, ib), s0)
	var found := -1
	var steps := 0
	while not heap_s.is_empty():
		var top := _pop(heap_f, heap_s)
		var st: int = top[1]
		var gs: float = g[st]
		if float(top[0]) > gs + _h(_unflat(st / ks / 6), ib) + 1e-6:
			continue
		steps += 1
		if steps > max_steps:
			break
		var k := st % ks
		var heading := (st / ks) % 6
		var c := st / ks / 6
		if c == goal and (heading == arrive or (k == k_max and heading != d1
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
				_push(heap_f, heap_s, ng + _h(nxt, ib), ns)
	r.steps = steps
	if found < 0:
		r.why = "no way through (%d steps)" % steps
		if OS.has_environment("PIPE_DEBUG"):
			var reached := AABB(_pos(ia), Vector3.ZERO)
			for key: int in g:
				reached = reached.expand(_pos(_unflat(key / ks / 6)))
			print("PipeRouter: %s from %s to %s reached %s .. %s" % [r.name, a, b, reached.position, reached.end])
			for d2 in 6:
				var q := ib + DIRS[d2]
				for step in 4:
					var qq := ib + DIRS[d2] * (step + 1)
					if qq.x < 0 or qq.y < 0 or qq.z < 0 or qq.x >= _n.x or qq.y >= _n.y or qq.z >= _n.z:
						break
					if _cells[_flat(qq)] & 1:
						print("  from the end %s: blocked at %s by %s" % [DIRS[d2], _pos(qq), _blocker(r, _pos(qq))])
						break
		return false
	# Back from the end: the grid points, and where the heading changes, the bends.
	var chain: Array[int] = []
	var u := found
	while u >= 0:
		chain.push_front(u)
		u = parent[u]
	var pts := PackedVector3Array([p0])
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
	pts.append(p1)
	r.points = _straighten(pts)
	return true


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


func _h(i: Vector3i, goal: Vector3i) -> float:
	var p := _pos(i)
	var q := _pos(goal)
	return (absf(p.x - q.x) + absf(p.y - q.y) + absf(p.z - q.z)) * heuristic


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


## Marks the grid: blocked near every part (and lead), beside a member, inside a room.
func _raster(r: Run, region: AABB) -> void:
	# Clear of the pipe and of its unions' flanges.
	var clear := maxf(r.radius + gap, r.radius * ShipParts.UNION_FLARE + 0.006)
	var ends: Array[Vector3] = [r.from["position"], r.to["position"]]
	var near_ends: Array[int] = [(r.from["part"] as PartData).id, (r.to["part"] as PartData).id]
	near_ends.append_array(r.through)
	for p: PartData in model.parts.values():
		var vis := model.part_visual(p.id) as MeshInstance3D
		if vis == null or vis.mesh == null:
			continue
		var box: AABB = vis.mesh.get_aabb()
		var xf := p.local_transform
		var inv := xf.affine_inverse()
		var passable := near_ends.has(p.id)
		_mark_box(box.grow(clear), xf, inv, region, 1, passable, ends)
		if members.has(p.id):
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
					# A spigot may stand in a room: its way out costs nothing extra.
					if p.distance_to(ends[0]) < pass_reach or p.distance_to(ends[1]) < pass_reach:
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
				if passable and (p.distance_to(ends[0]) < pass_reach or p.distance_to(ends[1]) < pass_reach):
					continue
				_cells[c] = _cells[c] | bit


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
	var end_ids: Array[int] = [(r.from["part"] as PartData).id, (r.to["part"] as PartData).id]
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
				cuts.append([clampf(t, lo, length - lo), String(st[1])])
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


## A span from `a` to `b` (heading `d`) of run `r`: its collision only where it clears every
## part it passes (the parts near its ends), collars where it goes through a panel.
func _span(r: Run, a: Vector3, b: Vector3, d: Vector3, through: Array[int], end_ids: Array[int]) -> PartData:
	var length := a.distance_to(b)
	var mid := (a + b) * 0.5
	# Sample along it: where it lies in a part it passes, no collision (and a collar at each face).
	var passed: Array[int] = []
	passed.append_array(through)
	passed.append_array(end_ids)
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
	return span


## Clips span `span` of run `r` every clip_pitch to the member beside it, else the panel: a
## BOLT from the span to the holder, a band and a stem drawn on the span.
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
		var best: PartData = null
		var best_d := INF
		var best_point := Vector3.ZERO
		for pass_members: bool in [true, false]:
			for p: PartData in model.parts.values():
				if own.has(p.id) or (members.has(p.id) != pass_members) or p.kind == PartData.Kind.GLASS:
					continue
				if not pass_members and p.kind == PartData.Kind.CONDUIT:
					continue
				var vis := model.part_visual(p.id) as MeshInstance3D
				if vis == null or vis.mesh == null:
					continue
				var box: AABB = vis.mesh.get_aabb()
				var local := p.local_transform.affine_inverse() * at
				var near := local.clamp(box.position, box.end)
				var dist := near.distance_to(local)
				if dist < best_d and dist <= r.radius + clip_reach:
					best_d = dist
					best = p
					best_point = p.local_transform * near
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
				span.local_transform.affine_inverse() * Transform3D(Basis(axis.cross(normal).normalized(), axis, normal), at))


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
