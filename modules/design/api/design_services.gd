class_name DesignServices
extends RefCounted
## Wires and pipes (plan 2.2: "pipes, wire routes and the rest"). A run is a line on one deck
## (DesignRecord.runs). Runs of one kind join where they touch, and carry on up or down where
## one ends over another's end on the next deck (a riser). A component is on a run when the
## run passes through its footprint. A network is everything joined to a source: power
## sources for wires, the fuel pump for fuel. route() lays runs for everything not yet on one,
## through the rooms (and up and down the stairwells), so a whole ship can be wired in a click.

## kind -> {name, colour, cost / mass / hours per m, what feeds it (part field), and the sign
## of that field for a source (+1) or a user (-1)}.
const KINDS := {
	"wire": {"name": "Wiring", "colour": Color(0.45, 1.0, 0.5), "cost": 18.0, "mass": 1.6, "hours": 0.05,
			"field": "power", "layer": "wiring"},
	"fuel": {"name": "Fuel pipe", "colour": Color(1.0, 0.55, 0.25), "cost": 40.0, "mass": 4.5, "hours": 0.12,
			"field": "fuel", "layer": "pipes"},
}
## How close runs (or a run and a footprint) must come to join, m.
const JOIN := 0.3
## The router's cell, m.
const CELL := 0.5


static func is_source(pt: DesignPartType, kind: String) -> bool:
	return pt != null and float(pt.get(str(KINDS[kind].field))) > 0.0


static func is_user(pt: DesignPartType, kind: String) -> bool:
	return pt != null and float(pt.get(str(KINDS[kind].field))) < 0.0


static func points(run: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Array in run.get("points", []):
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


static func length(run: Dictionary) -> float:
	var pts := points(run)
	var l := 0.0
	for i in pts.size() - 1:
		l += pts[i].distance_to(pts[i + 1])
	return l


## What is on a working network of `kind`: {components: {id: true}, runs: {id: true}}.
static func connected(d: DesignRecord, cat: DesignCatalog, kind: String) -> Dictionary:
	var comps := {}
	var runs := {}
	var comp_deck := {}
	for c: Dictionary in d.components.values():
		var r: Dictionary = d.rooms.get(str(c.room), {})
		if not r.is_empty():
			comp_deck[c.id] = int(r.deck)
	var my_runs: Array[Dictionary] = []
	for w: Dictionary in d.runs.values():
		if str(w.kind) == kind:
			my_runs.append(w)
	# Flood from the sources through runs and the parts on them.
	var queue: Array = []
	for c: Dictionary in d.components.values():
		if comp_deck.has(c.id) and is_source(cat.part(str(c.type)), kind):
			comps[c.id] = true
			queue.append(["c", c.id])
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		if item[0] == "c":
			var c: Dictionary = d.components[item[1]]
			var f := DesignRules.footprint(c, cat.part(str(c.type))).grow(JOIN)
			for w in my_runs:
				if not runs.has(w.id) and int(w.deck) == int(comp_deck[c.id]) and _hits_rect(points(w), f):
					runs[w.id] = true
					queue.append(["w", w.id])
		else:
			var w: Dictionary = d.runs[item[1]]
			var pts := points(w)
			for o in my_runs:
				if not runs.has(o.id) and _joins(w, o):
					runs[o.id] = true
					queue.append(["w", o.id])
			for c: Dictionary in d.components.values():
				if comps.has(c.id) or not comp_deck.has(c.id) or int(comp_deck[c.id]) != int(w.deck):
					continue
				var pt := cat.part(str(c.type))
				if pt and _hits_rect(pts, DesignRules.footprint(c, pt).grow(JOIN)):
					comps[c.id] = true
					queue.append(["c", c.id])
	return {"components": comps, "runs": runs}


## Users of `kind` not on a working network: [component ids].
static func cut_off(d: DesignRecord, cat: DesignCatalog, kind: String) -> Array:
	var on: Dictionary = connected(d, cat, kind).components
	var out: Array = []
	for c: Dictionary in d.components.values():
		if not on.has(c.id) and is_user(cat.part(str(c.type)), kind) and d.rooms.has(str(c.room)):
			out.append(c.id)
	out.sort()
	return out


## Runs that reach every user of `kind` not yet on a network, laid through the rooms (and up
## and down stairwells) from the nearest point already on one. Returns run dicts for add_run;
## users no route reaches (no source, or walled off) are left out.
static func route(d: DesignRecord, cat: DesignCatalog, kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var net := connected(d, cat, kind)
	if net.components.is_empty():
		return out
	var b := d.bounds()
	if b.size == Vector2.ZERO:
		return out
	var origin := b.position
	var nx := int(ceil(b.size.x / CELL))
	var nz := int(ceil(b.size.y / CELL))
	var decks := d.decks()
	# Which cells are inside a room, and which are in a stairwell (risers go there).
	var open := {}
	var riser := {}
	for deck in decks:
		for ix in nx:
			for iz in nz:
				var p := origin + Vector2(ix + 0.5, iz + 0.5) * CELL
				var rid := d.room_at(deck, p)
				if rid == "":
					continue
				open[Vector3i(ix, deck, iz)] = true
				var rt := cat.room(str(d.rooms[rid].type))
				if rt and rt.links_decks:
					riser[Vector3i(ix, deck, iz)] = true
	var seeds := {}
	for cid: String in net.components:
		_mark_footprint(d, cat, cid, origin, open, seeds)
	for wid: String in net.runs:
		_mark_run(d.runs[wid], origin, seeds)
	var pending := cut_off(d, cat, kind)
	for cid: String in pending:
		var targets := {}
		_mark_footprint(d, cat, cid, origin, open, targets)
		if targets.is_empty():
			continue
		var path := _search(seeds, targets, open, riser)
		if path.is_empty():
			continue
		for run in _to_runs(path, origin, kind):
			out.append(run)
			_mark_run(run, origin, seeds)
		for cell in path:
			seeds[cell] = true
		for cell in targets:
			seeds[cell] = true
	return out


static func _search(seeds: Dictionary, targets: Dictionary, open: Dictionary, riser: Dictionary) -> Array:
	var came := {}
	var queue: Array = []
	for s: Vector3i in seeds:
		if open.has(s):
			came[s] = s
			queue.append(s)
	var head := 0
	var dirs := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	while head < queue.size():
		var cur: Vector3i = queue[head]
		head += 1
		if targets.has(cur):
			var path: Array = [cur]
			while came[path[0]] != path[0]:
				path.push_front(came[path[0]])
			return path
		var steps: Array = []
		for dv: Vector3i in dirs:
			steps.append(cur + dv)
		if riser.has(cur):
			steps.append(cur + Vector3i(0, 1, 0))
			steps.append(cur + Vector3i(0, -1, 0))
		for n: Vector3i in steps:
			if open.has(n) and not came.has(n) and (n.y == cur.y or riser.has(n)):
				came[n] = cur
				queue.append(n)
	return []


## A cell path as runs: one per deck stretch, its corners only.
static func _to_runs(path: Array, origin: Vector2, kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var stretch: Array = []
	for i in path.size():
		var cell: Vector3i = path[i]
		if not stretch.is_empty() and (stretch[0] as Vector3i).y != cell.y:
			_close(stretch, origin, kind, out)
			stretch = []
		stretch.append(cell)
	_close(stretch, origin, kind, out)
	return out


static func _close(stretch: Array, origin: Vector2, kind: String, out: Array[Dictionary]) -> void:
	if stretch.is_empty():
		return
	var pts: Array = []
	for i in stretch.size():
		var c: Vector3i = stretch[i]
		if i > 0 and i < stretch.size() - 1:
			var a: Vector3i = stretch[i - 1]
			var b: Vector3i = stretch[i + 1]
			if (c - a) == (b - c):
				continue
		var p := origin + Vector2(c.x + 0.5, c.z + 0.5) * CELL
		pts.append([p.x, p.y])
	if pts.size() == 1:
		# A riser landing: a short stub so the run has a line to draw and join.
		pts.append([pts[0][0] + 0.01, pts[0][1]])
	out.append({"kind": kind, "deck": (stretch[0] as Vector3i).y, "points": pts})


static func _mark_footprint(d: DesignRecord, cat: DesignCatalog, cid: String, origin: Vector2, open: Dictionary,
		into: Dictionary) -> void:
	var c: Dictionary = d.components.get(cid, {})
	var pt := cat.part(str(c.get("type", "")))
	if pt == null or not d.rooms.has(str(c.room)):
		return
	var deck := int(d.rooms[str(c.room)].deck)
	var f := DesignRules.footprint(c, pt)
	var lo := ((f.position - origin) / CELL).floor()
	var hi := ((f.end - origin) / CELL).ceil()
	for ix in range(int(lo.x), int(hi.x)):
		for iz in range(int(lo.y), int(hi.y)):
			var cell := Vector3i(ix, deck, iz)
			if open.has(cell):
				into[cell] = true


static func _mark_run(run: Dictionary, origin: Vector2, into: Dictionary) -> void:
	var pts := points(run)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var n := maxi(int(ceil(a.distance_to(b) / (CELL * 0.5))), 1)
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			var c := ((p - origin) / CELL).floor()
			into[Vector3i(int(c.x), int(run.deck), int(c.y))] = true


static func _joins(a: Dictionary, b: Dictionary) -> bool:
	var pa := points(a)
	var pb := points(b)
	var da := int(a.deck)
	var db := int(b.deck)
	if da == db:
		for i in pa.size() - 1:
			for j in pb.size() - 1:
				if _seg_dist(pa[i], pa[i + 1], pb[j], pb[j + 1]) <= JOIN:
					return true
		return false
	if absi(da - db) != 1:
		return false
	# A riser: an end of one over a point of the other.
	for e in [pa[0], pa[pa.size() - 1]]:
		for j in pb.size() - 1:
			if _point_seg(e, pb[j], pb[j + 1]) <= JOIN:
				return true
	for e in [pb[0], pb[pb.size() - 1]]:
		for i in pa.size() - 1:
			if _point_seg(e, pa[i], pa[i + 1]) <= JOIN:
				return true
	return false


static func _hits_rect(pts: PackedVector2Array, r: Rect2) -> bool:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		if r.has_point(a) or r.has_point(b):
			return true
		var n := maxi(int(ceil(a.distance_to(b) / 0.1)), 1)
		for k in n:
			if r.has_point(a.lerp(b, float(k) / n)):
				return true
	return false


static func _point_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


static func _seg_dist(a: Vector2, b: Vector2, c: Vector2, e: Vector2) -> float:
	var pts := Geometry2D.get_closest_points_between_segments(a, b, c, e)
	return pts[0].distance_to(pts[1])
