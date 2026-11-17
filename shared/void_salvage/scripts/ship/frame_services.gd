class_name FrameServices
extends RefCounted
## How a frame build's services are laid (docs/SHIP_FRAME_PLAN.md 4.5), shared by the frame builds
## (KestrelShip, MantaShip): every unit's ports in ship space (ShipParts.ports), the
## lamps' drivers, the lead graph (FrameGraph: the design fills its lanes) and the leads asked of
## it, each leaving its unit at a port and through the panel the unit is fixed to, a conduit up
## the cavity behind wall kit with no lane in reach; the doors' sweeps kept clear; then the pipes
## (PipeRouter) from port to port. The design decides where the loom runs and who is what on the
## grid; this does the bookkeeping both ships share. It works on the kit, not the ship (shared since
## F7c): the ship's rooms and its doors' slides and swings are read off the body the kit builds into
## when they are needed (`layout`).

var kit: ShipKit
var model: PartModel
var fit: FrameMounts
## The lanes and the routes.
var graph: FrameGraph
## Every lead asked for: {device: path, target, route, port, goal (the target's port name, or "")}.
var leads: Array[Dictionary] = []
## The vertical runs behind wall kit with no frame lane in reach: [from, to] (ship space).
var conduits: Array = []
## Each unit's ports in ship space ({name, fluid, radius, position, direction}), by its path.
var unit_ports: Dictionary = {}
## The lamps' drivers.
var lamp_drivers: Array[PartData] = []
## The pipes: the router and its runs.
var pipes: PipeRouter
## The lane kinds a conduit may join at its top (or foot).
var conduit_kinds: Array = ["ring", "stringer", "deck"]
## Where a conduit may run when neither up nor down reaches a lane: along the back of the panel
## a unit is fixed to (the Manta's roof lamps' drivers, a bay's length from the nearest ring),
## every way that reaches one (the router takes the cheaper).
var conduit_ways: Array[Vector3] = []


func _init(into: ShipKit, mounts: FrameMounts) -> void:
	kit = into
	model = into.model
	fit = mounts


## One of the tables of the body the kit builds into, as it stands now (the design fills them as it
## builds): "rooms" (an Array of AABB, ship space), "moves" ({state key: {tag: slide}}) and "hinges"
## ({state key: {tag: [pivot, axis, angle]}}), as a ship keeps them. A body without one has none.
func layout(key: String) -> Variant:
	var v: Variant = kit.body.get(key)
	if v == null:
		return [] if key == "rooms" else {}
	return v


## A driver over each lamp, on the panel it hangs under (a ceiling, a lining), `offset` metres
## to the side of the lamp's middle; the lamp's look rides on that panel and its tail runs up
## through it to the driver.
func fit_lamp_drivers(offset: float) -> void:
	var lamps: Array[Dictionary] = []
	for u: Dictionary in kit.units:
		if String(u["name"]) == "lamp" and u.has("onto"):
			lamps.append(u)
	for u: Dictionary in lamps:
		var onto: PartData = u["onto"]
		var lamp_box: AABB = u["box"]
		var top := fit.part_box(onto).end.y
		var at := Vector3(lamp_box.get_center().x + offset, top + 0.005, lamp_box.get_center().z)
		ShipParts.lamp_driver(kit, Transform3D(Basis(), at))
		var driver: PartData = kit.units[kit.units.size() - 1].get("part")
		if driver:
			lamp_drivers.append(driver)


## Every unit's ports in ship space (`unit_ports`).
func collect_ports() -> void:
	for u: Dictionary in kit.units:
		unit_ports[u["path"]] = unit_ports_of(u)


## A unit's ports in ship space: ShipParts.ports in its frame; the map screen's at its post's
## foot (its screen is on a post the cockpit adds); a lamp's over its housing.
func unit_ports_of(u: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var unit_name := String(u["name"])
	var frame: Variant = u.get("frame")
	var args: Array = u.get("args", [])
	if unit_name == "map_screen" and u.has("part"):
		var b := fit.part_box(u["part"])
		out.append(ShipParts._port("power", "", 0.008, Vector3(b.get_center().x, b.position.y, b.get_center().z), Vector3.DOWN))
		return out
	if unit_name == "lamp" and not args.is_empty():
		frame = Transform3D(Basis(), args[0])
	if not frame is Transform3D:
		return out
	var xf: Transform3D = frame
	for port: Dictionary in ShipParts.ports(unit_name, args):
		var q := port.duplicate()
		q["position"] = xf * (port["position"] as Vector3)
		q["direction"] = (xf.basis * (port["direction"] as Vector3)).normalized()
		out.append(q)
	return out


## The port named `port_name` of the unit at `path` (ship space), or {}.
func port_of(path: String, port_name: String) -> Dictionary:
	for port: Dictionary in unit_ports.get(path, []):
		if port["name"] == port_name:
			return port
	return {}


## The unit's part at `path`, or null.
func part_of(path: String) -> PartData:
	for u: Dictionary in kit.units:
		if u["path"] == path and u.has("part"):
			return u["part"]
	return null


## A new graph on the ship's parts, nothing on a lane where a door's leaf runs. The design adds
## its lanes, then asks for leads and calls `route`.
func begin_graph() -> FrameGraph:
	graph = FrameGraph.new(model, kit.power_lead)
	graph.keep_out = door_sweeps()
	return graph


## Routes every lead asked for, the plugs stamped "service".
func route() -> void:
	kit.phase = "service"
	graph.route_all()
	kit.phase = ""


## Asks the graph for a lead from the unit at `path`, leaving at its port `port_name`, to
## `target` (a part, arriving at its port `goal_port`, or the loom's spans); through the panels
## the unit is fixed to and the one behind its port. A wall unit with no frame lane in reach
## gets a conduit up the cavity behind it.
func lead(path: String, target: Variant, port_name: String, goal_port: String = "") -> void:
	var device: PartData = null
	for p: PartData in model.parts.values():
		if p.path == path:
			device = p
			break
	var port := port_of(path, port_name)
	if device == null or port.is_empty():
		return
	var through: Array[int] = through_of(path, port)
	var hints := {"stud": port["position"], "through": through, "path": "lead:%s" % path}
	if target is PartData and goal_port != "":
		var goal := port_of((target as PartData).path, goal_port)
		if goal.is_empty():
			for u: Dictionary in kit.units:
				if u.get("part") == target:
					goal = port_of(u["path"], goal_port)
		if not goal.is_empty():
			hints["goal"] = goal["position"]
			through.append_array(through_of((target as PartData).path, goal))
	conduit_if_needed(port, through)
	var r := graph.lead(device, target, hints)
	leads.append({"device": path, "target": target, "route": r, "port": port, "goal": goal_port})


## What a lead from the unit at `path` leaving at `port` may pass: the parts the unit is tacked
## to, and whatever panel lies right behind the port (the lining a pump's manifold stands
## against); for a lamp driver, the lining over it.
func through_of(path: String, port: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var onto: Array = (fit.tacks.get(path, {}) as Dictionary).get("onto", [])
	for m: Dictionary in fit.mounts:
		var p: PartData = m["part"]
		if onto.has(p.path) and not out.has(p.id):
			out.append(p.id)
	var behind := (port["position"] as Vector3) + (port["direction"] as Vector3) * 0.03
	for m: Dictionary in fit.mounts:
		var p: PartData = m["part"]
		if (m["box"] as AABB).grow(0.005).has_point(behind) and not out.has(p.id):
			out.append(p.id)
	if path.begins_with("fitting:lamp_driver"):
		var up := (port["position"] as Vector3) + Vector3(0.0, 0.25, 0.0)
		for m: Dictionary in fit.mounts:
			var p: PartData = m["part"]
			if m["kind"] == "lining" and (m["box"] as AABB).end.y > (port["position"] as Vector3).y \
					and (m["box"] as AABB).grow(0.02).has_point(Vector3(up.x, (m["box"] as AABB).get_center().y, up.z)) \
					and not out.has(p.id):
				out.append(p.id)
	return out


## A unit on a wall with no lane within a free hop of its port: a conduit lane from just
## behind the panel straight up the cavity until the hull's lanes are in reach (the shoulder's
## stringer), joined onto them there; else down.
func conduit_if_needed(port: Dictionary, through: Array[int]) -> void:
	var at: Vector3 = port["position"]
	var dir: Vector3 = port["direction"]
	if absf(dir.y) > 0.5:
		return
	for l in graph.lanes:
		var q := l.point(l.nearest_t(at))
		if q.distance_to(at) <= FrameGraph.TAIL_MAX * 0.8 and not graph.blocked(at, q, through, true):
			return
	var c0 := at + dir * 0.07
	for way: Vector3 in [Vector3.UP, Vector3.DOWN]:
		var c1 := _conduit_end(c0, way, through)
		if c1 != c0:
			_conduit(c0, c1, dir, through)
			return
	for way: Vector3 in conduit_ways:
		var c1 := _conduit_end(c0, way, through)
		if c1 != c0:
			_conduit(c0, c1, dir, through)


## How far a conduit from `c0` along `way` runs before a lane is in reach (in 10 cm steps, up to
## 3 m, never into a room or through anything but `through`): its end, or `c0` if none.
func _conduit_end(c0: Vector3, way: Vector3, through: Array[int]) -> Vector3:
	for k in 30:
		var c1 := c0 + way * 0.1 * float(k + 1)
		if graph.blocked(c0, c1, through, true) or _in_room(c1):
			break
		for l in graph.lanes:
			if not l.kind in conduit_kinds:
				continue
			var q := l.point(l.nearest_t(c1))
			if q.distance_to(c1) <= 0.3 and not graph.blocked(c1, q, through, true):
				return c1
	return c0


func _conduit(c0: Vector3, c1: Vector3, dir: Vector3, through: Array[int]) -> void:
	var lane := graph.add_lane("conduit", c0, c1, -dir, Vector3.BACK, null)
	lane.exempt = through
	lane.through_deck = true
	graph.link_nearest(c1, conduit_kinds, through, true, 2, 0.3)
	conduits.append([c0, c1])


## Whether `p` is inside one of the ship's rooms (a conduit runs in the cavities).
func _in_room(p: Vector3) -> bool:
	for room: AABB in layout("rooms"):
		if room.grow(-0.05).has_point(p):
			return true
	return false


## Where the doors' leaves run (ship space boxes): each leaf's box swept along its slide or
## through its swing, so no lead is laid where a leaf would cut it.
func door_sweeps() -> Array[AABB]:
	var out: Array[AABB] = []
	var moves: Dictionary = layout("moves")
	var hinges: Dictionary = layout("hinges")
	for key: String in moves:
		for tag: String in moves[key]:
			var slide: Vector3 = moves[key][tag]
			for piece: Dictionary in kit.tagged.get(tag, []):
				if not piece.has("part"):
					continue
				var b := fit.part_box(model.parts[piece["part"]])
				out.append(b.merge(AABB(b.position + slide, b.size)))
	for key: String in hinges:
		for tag: String in hinges[key]:
			var h: Array = hinges[key][tag]
			for piece: Dictionary in kit.tagged.get(tag, []):
				if not piece.has("part"):
					continue
				var b := fit.part_box(model.parts[piece["part"]])
				var swept := b
				for k in 5:
					var turn := Basis(h[1] as Vector3, float(h[2]) * float(k + 1) / 5.0)
					var xf := Transform3D(turn, (h[0] as Vector3) - turn * (h[0] as Vector3))
					swept = swept.merge(xf * b)
				out.append(swept)
	return out


## A pipe's end on the unit at `path`: its port `port_name` with the unit's part, or {}.
func pipe_end(path: String, port_name: String) -> Dictionary:
	var port := port_of(path, port_name)
	if port.is_empty():
		return {}
	for u: Dictionary in kit.units:
		if u["path"] == path and u.has("part"):
			var out := port.duplicate()
			out["part"] = u["part"]
			return out
	return {}


## Lays `runs` ([name, fluid, from unit, its port, to unit, its port, optionally the glands: parts
## it passes anywhere, by id or a point in the panel; then optionally the points it passes on its
## way, [position, direction] each], in that order) with a
## PipeRouter clear of every part and lead before it, clipped to the frame: `stations` [z, label]
## for the unions, the rooms above their floors (each room's box reaches 0.2 m under its floor)
## costly, pipes dearer over `low_y`; `heuristic` the search's greed (PipeRouter.heuristic). Warns
## for a run with no port or one it could not lay.
func lay_pipes(runs: Array, stations: Array, low_y: float, heuristic: float = 1.0) -> void:
	pipes = PipeRouter.new(kit)
	pipes.heuristic = heuristic
	for room: AABB in layout("rooms"):
		pipes.rooms.append(AABB(room.position + Vector3(0, 0.2, 0), room.size - Vector3(0, 0.2, 0)))
	pipes.low_y = low_y
	for p: PartData in model.parts.values():
		if p.kind == PartData.Kind.FRAME:
			pipes.members[p.id] = true
	for st: Array in stations:
		pipes.stations.append([float(st[0]), String(st[1])])
	for ld: Dictionary in leads:
		var r: FrameGraph.Route = ld["route"]
		if r and r.points.size() >= 2:
			pipes.avoid.append([r.points, FrameGraph.LEAD_RADIUS])
	var fuel := ShipKit.paint(Color(0.7, 0.56, 0.36), 0.8, 0.35)
	var coolant := ShipKit.paint(Color(0.42, 0.56, 0.66), 0.7, 0.4)
	for run: Array in runs:
		var from := pipe_end(run[2], run[3])
		var to := pipe_end(run[4], run[5])
		if from.is_empty() or to.is_empty():
			push_warning("%s: pipe %s has no port at one end" % [kit.body.name, run[0]])
			continue
		var through: Array[int] = []
		for e: Array in [[run[2], from], [run[4], to]]:
			for id in through_of(e[0], e[1]):
				if not through.has(id):
					through.append(id)
		# A run's optional seventh entry: the parts it passes anywhere (glands), each a part id or a
		# point (ship space) in the panel it names.
		var glands: Array[int] = []
		for g: Variant in (run[6] if run.size() > 6 else []):
			if g is int:
				if not glands.has(g):
					glands.append(g)
				continue
			for m: Dictionary in fit.mounts:
				var p: PartData = m["part"]
				if (m["box"] as AABB).grow(0.005).has_point(g) and not glands.has(p.id):
					glands.append(p.id)
		# Its optional eighth: the points it passes on its way ([position, direction] each, ship space).
		pipes.run(run[0], from["fluid"], from["radius"], from, to, fuel if from["fluid"] == "fuel" else coolant, through,
				glands, run[7] if run.size() > 7 else [])
	pipes.lay_all()
	for line in pipes.report():
		if not line.contains(": laid"):
			push_warning("%s: %s" % [kit.body.name, line])
