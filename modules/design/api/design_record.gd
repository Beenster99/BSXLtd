class_name DesignRecord
extends RefCounted
## One ship design: everything the design room shows, in one record (plan 2.1). The plan
## views, the holotable, the TVs and the data channel all read this same record, so they can
## never disagree. It is changed only through apply(op), which returns the op that undoes it:
## the same ops will travel between players for shared editing (Wave 3).
##
## Space: metres, ship space. +X starboard, -Z forward (bow), y up. Deck 0 is the lowest
## deck; deck n's floor is at n * deck_height. A room is a rectangle on one deck, given by
## its corner nearest -X -Z (x, z) and its size (w, d), snapped to the grid.
##
## Ops (every op is a Dictionary with "op"):
##   {op = "add_room", room = {id?, type, deck, x, z, w, d, name?}}
##   {op = "set_room", id, fields = {x?, z?, w?, d?, deck?, name?, type?}}
##   {op = "remove_room", id}            # its doors and components go with it
##   {op = "add_door", door = {id?, a, b, deck, x, z}}     # b = "" is a door to space
##   {op = "remove_door", id}
##   {op = "add_component", component = {id?, type, room, x, z, rot?}}
##   {op = "set_component", id, fields = {...}}
##   {op = "remove_component", id}
##   {op = "add_run", run = {id?, kind, deck, points = [[x, z], ...]}}   # a wire or pipe
##   {op = "set_run", id, fields = {...}}
##   {op = "remove_run", id}
##   {op = "set_hull", deck, points = [[x, z], ...]}   # the hull's outline on a deck ([] clears it)
##   {op = "add_wall", wall = {id?, deck, a = [x, z], b = [x, z]}}   # an inner wall drawn anywhere
##   {op = "remove_wall", id}
##   {op = "add_beam", beam = {id?, deck, a = [x, z], b = [x, z]}}   # a beam under the deckhead
##   {op = "remove_beam", id}
##   {op = "add_layer", layer = {id?, name, visible?, order?}}   # a whiteboard layer
##   {op = "set_layer", id, fields = {name?, visible?, order?}}
##   {op = "remove_layer", id}           # its strokes go with it
##   {op = "add_stroke", stroke = {id?, layer, tool, colour, width, points = [[x, y], ...]}}
##   {op = "remove_stroke", id}
##   {op = "set_meta", fields = {name?, notes?, grid?, deck_height?, structure? (merged)}}
##   {op = "batch", ops = [...]}         # applied in order, undone in reverse
## The undo of a remove re-adds what was removed with its old id, so ids stay stable.

signal changed(op: Dictionary)

const FORMAT := 1
## Grid steps the designer can pick, m.
const GRIDS: PackedFloat32Array = [0.5, 1.0, 2.0]

var id := ""
var name := "New design"
var notes := ""
## Grid step, m. Swappable; rooms already placed keep their size.
var grid := 1.0
## Floor to floor, m.
var deck_height := 3.0
## room id -> {id, type, deck, x, z, w, d, name}
var rooms: Dictionary = {}
## door id -> {id, a, b, deck, x, z}
var doors: Dictionary = {}
## component id -> {id, type, room, x, z, rot}
var components: Dictionary = {}
## run id -> {id, kind ("wire", "fuel"...: DesignServices.KINDS), deck, points: [[x, z], ...]}
## A wire or pipe on one deck, a line through its points; runs meet where they touch, and
## carry on to the deck above or below where one ends over the other's end (a riser).
var runs: Dictionary = {}
## How the hull is built round the rooms (DesignStructure.OPTIONS): frame weight, frame
## spacing (m), outer hull plating and inner walls.
var structure := {"frame": "standard", "spacing": 2.0, "hull": "standard", "inner": "panel"}
## The hull: deck (as a string) -> its outline, [[x, z], ...], a closed polygon. Rooms on a
## deck with an outline must sit inside it, its sides are the outer hull, and the deck is
## plated all the way out to it. A deck with no outline is hulled round its rooms as before.
var hull: Dictionary = {}
## Inner walls drawn anywhere: wall id -> {id, deck, a: [x, z], b: [x, z]}.
var walls: Dictionary = {}
## Beams placed by hand under a deckhead: beam id -> {id, deck, a: [x, z], b: [x, z]}.
var beams: Dictionary = {}
## The design's whiteboard (Whiteboard view): layer id -> {id, name, visible, order}, drawn
## lowest order first, and stroke id -> {id, layer, tool ("pen", "marker", "line", "box"),
## colour (html), width (board units), points: [[x, y], ...]} in board units (Whiteboard.BOARD).
var sketch_layers: Dictionary = {}
var strokes: Dictionary = {}
var _next := 1


func _init(design_id: String = "", design_name: String = "New design") -> void:
	id = design_id
	name = design_name


# Applying edits

## Applies an op and returns its undo ({} if the op did nothing or was refused).
func apply(op: Dictionary) -> Dictionary:
	var undo := _apply(op)
	if not undo.is_empty():
		changed.emit(op)
	return undo


func _apply(op: Dictionary) -> Dictionary:
	match str(op.get("op", "")):
		"add_room":
			return _add_room(op.get("room", {}))
		"set_room":
			return _set_fields(rooms, str(op.get("id", "")), op.get("fields", {}), "set_room")
		"remove_room":
			return _remove_room(str(op.get("id", "")))
		"add_door":
			var door: Dictionary = op.get("door", {}).duplicate()
			if not rooms.has(str(door.get("a", ""))):
				return {}
			door["deck"] = int(door.get("deck", rooms[str(door.a)].deck))
			door["b"] = str(door.get("b", ""))
			door["x"] = float(door.get("x", 0.0))
			door["z"] = float(door.get("z", 0.0))
			return _add_entry(doors, door, "d", "door", "remove_door")
		"remove_door":
			return _remove_entry(doors, str(op.get("id", "")), "door", "add_door")
		"add_component":
			var c: Dictionary = op.get("component", {}).duplicate()
			if not rooms.has(str(c.get("room", ""))):
				return {}
			c["rot"] = int(c.get("rot", 0))
			c["x"] = float(c.get("x", 0.0))
			c["z"] = float(c.get("z", 0.0))
			return _add_entry(components, c, "c", "component", "remove_component")
		"set_component":
			return _set_fields(components, str(op.get("id", "")), op.get("fields", {}), "set_component")
		"remove_component":
			return _remove_entry(components, str(op.get("id", "")), "component", "add_component")
		"add_run":
			var run: Dictionary = op.get("run", {}).duplicate(true)
			var pts: Array = []
			for p: Variant in run.get("points", []):
				pts.append([float(p[0]), float(p[1])])
			if pts.size() < 2 or str(run.get("kind", "")) == "":
				return {}
			run["points"] = pts
			run["deck"] = int(run.get("deck", 0))
			return _add_entry(runs, run, "w", "run", "remove_run")
		"set_run":
			return _set_fields(runs, str(op.get("id", "")), op.get("fields", {}), "set_run")
		"remove_run":
			return _remove_entry(runs, str(op.get("id", "")), "run", "add_run")
		"set_hull":
			var dk := str(int(op.get("deck", 0)))
			var outline: Array = []
			for p: Variant in op.get("points", []):
				outline.append([float(p[0]), float(p[1])])
			if outline.size() in [1, 2]:
				return {}
			var was: Array = hull.get(dk, [])
			if outline.is_empty():
				if not hull.has(dk):
					return {}
				hull.erase(dk)
			else:
				hull[dk] = outline
			return {"op": "set_hull", "deck": int(dk), "points": was.duplicate(true)}
		"add_wall", "add_beam":
			var key := "wall" if op.op == "add_wall" else "beam"
			var e: Dictionary = op.get(key, {}).duplicate(true)
			var a: Array = e.get("a", [])
			var b: Array = e.get("b", [])
			if a.size() < 2 or b.size() < 2 or Vector2(float(a[0]), float(a[1])).distance_to(Vector2(float(b[0]), float(b[1]))) < 0.1:
				return {}
			e["a"] = [float(a[0]), float(a[1])]
			e["b"] = [float(b[0]), float(b[1])]
			e["deck"] = int(e.get("deck", 0))
			if key == "wall":
				return _add_entry(walls, e, "i", "wall", "remove_wall")
			return _add_entry(beams, e, "b", "beam", "remove_beam")
		"remove_wall":
			return _remove_entry(walls, str(op.get("id", "")), "wall", "add_wall")
		"remove_beam":
			return _remove_entry(beams, str(op.get("id", "")), "beam", "add_beam")
		"add_layer":
			var layer: Dictionary = op.get("layer", {}).duplicate()
			layer["name"] = str(layer.get("name", "Layer"))
			layer["visible"] = bool(layer.get("visible", true))
			if not layer.has("order"):
				var top := -1
				for l: Dictionary in sketch_layers.values():
					top = maxi(top, int(l.order))
				layer["order"] = top + 1
			layer["order"] = int(layer.order)
			return _add_entry(sketch_layers, layer, "l", "layer", "remove_layer")
		"set_layer":
			return _set_fields(sketch_layers, str(op.get("id", "")), op.get("fields", {}), "set_layer")
		"remove_layer":
			return _remove_layer(str(op.get("id", "")))
		"add_stroke":
			var k: Dictionary = op.get("stroke", {}).duplicate(true)
			var spts: Array = []
			for p: Variant in k.get("points", []):
				spts.append([float(p[0]), float(p[1])])
			if spts.is_empty() or not sketch_layers.has(str(k.get("layer", ""))):
				return {}
			k["points"] = spts
			k["tool"] = str(k.get("tool", "pen"))
			k["colour"] = str(k.get("colour", "ffffff"))
			k["width"] = float(k.get("width", 4.0))
			return _add_entry(strokes, k, "k", "stroke", "remove_stroke")
		"remove_stroke":
			return _remove_entry(strokes, str(op.get("id", "")), "stroke", "add_stroke")
		"set_meta":
			return _set_meta(op.get("fields", {}))
		"batch":
			var undos: Array = []
			for sub: Dictionary in op.get("ops", []):
				var u := _apply(sub)
				if not u.is_empty():
					undos.push_front(u)
			return {} if undos.is_empty() else {"op": "batch", "ops": undos}
	return {}


func _add_room(room: Dictionary) -> Dictionary:
	var r := room.duplicate()
	if str(r.get("type", "")) == "":
		return {}
	r["deck"] = int(r.get("deck", 0))
	for k in ["x", "z"]:
		r[k] = float(r.get(k, 0.0))
	for k in ["w", "d"]:
		r[k] = maxf(float(r.get(k, grid)), 0.5)
	if not r.has("name"):
		r["name"] = ""
	return _add_entry(rooms, r, "r", "room", "remove_room")


func _remove_room(room_id: String) -> Dictionary:
	if not rooms.has(room_id):
		return {}
	var ops: Array = []
	for d: Dictionary in doors.values():
		if d.a == room_id or d.b == room_id:
			ops.append({"op": "remove_door", "id": d.id})
	for c: Dictionary in components.values():
		if c.room == room_id:
			ops.append({"op": "remove_component", "id": c.id})
	var undos: Array = []
	for sub in ops:
		undos.push_front(_apply(sub))
	undos.push_front({"op": "add_room", "room": rooms[room_id].duplicate()})
	rooms.erase(room_id)
	# Re-adding goes room first, then its doors and components.
	return {"op": "batch", "ops": undos}


func _remove_layer(layer_id: String) -> Dictionary:
	if not sketch_layers.has(layer_id):
		return {}
	var undos: Array = []
	for k: Dictionary in strokes.values().duplicate():
		if str(k.layer) == layer_id:
			undos.push_front(_apply({"op": "remove_stroke", "id": k.id}))
	undos.push_front({"op": "add_layer", "layer": sketch_layers[layer_id].duplicate()})
	sketch_layers.erase(layer_id)
	return {"op": "batch", "ops": undos}


## The hull's outline on a deck, or [] if it's hulled round its rooms.
func hull_outline(deck: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Array in hull.get(str(deck), []):
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


## Whether a room's floor lies inside its deck's hull (true where the deck has no outline).
func room_in_hull(room_id: String) -> bool:
	var r: Dictionary = rooms.get(room_id, {})
	var outline := hull_outline(int(r.get("deck", 0)))
	if r.is_empty() or outline.size() < 3:
		return true
	var rect := Rect2(r.x, r.z, r.w, r.d).grow(-0.01)
	for c in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		if not Geometry2D.is_point_in_polygon(c, outline):
			return false
	return true


## A starting hull for a deck: round its rooms, `margin` m out, the corners cut at 45 degrees.
## Returns points for set_hull ([] if the deck has no rooms).
func hull_round_rooms(deck: int, margin: float = 0.5) -> Array:
	var pts := PackedVector2Array()
	for r: Dictionary in rooms_on(deck):
		var rect := Rect2(r.x, r.z, r.w, r.d).grow(margin)
		for c in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			pts.append(c)
	if pts.size() < 3:
		return []
	var ring := Geometry2D.convex_hull(pts)
	var out: Array = []
	for i in ring.size() - 1:  # convex_hull repeats the first point at the end
		out.append([snappedf(ring[i].x, 0.01), snappedf(ring[i].y, 0.01)])
	return out


## Whiteboard layers, lowest first.
func layers_in_order() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l: Dictionary in sketch_layers.values():
		out.append(l)
	out.sort_custom(func(a, b): return int(a.order) < int(b.order))
	return out


func _add_entry(table: Dictionary, entry: Dictionary, prefix: String, _key: String,
		undo_op: String) -> Dictionary:
	var e := entry.duplicate()
	var eid := str(e.get("id", ""))
	if eid == "" or table.has(eid):
		eid = _new_id(prefix)
	e["id"] = eid
	table[eid] = e
	_bump_next(eid)
	return {"op": undo_op, "id": eid}


func _remove_entry(table: Dictionary, eid: String, key: String, undo_op: String) -> Dictionary:
	if not table.has(eid):
		return {}
	var old: Dictionary = table[eid]
	table.erase(eid)
	return {"op": undo_op, key: old.duplicate(true)}


func _set_fields(table: Dictionary, eid: String, fields: Dictionary, op_name: String) -> Dictionary:
	if not table.has(eid) or fields.is_empty():
		return {}
	var entry: Dictionary = table[eid]
	var old := {}
	for k in fields:
		if k == "id":
			continue
		old[k] = entry.get(k)
		entry[k] = fields[k]
	return {"op": op_name, "id": eid, "fields": old}


func _set_meta(fields: Dictionary) -> Dictionary:
	var old := {}
	for k in fields:
		match str(k):
			"name":
				old.name = name
				name = str(fields.name)
			"notes":
				old.notes = notes
				notes = str(fields.notes)
			"grid":
				old.grid = grid
				grid = float(fields.grid)
			"deck_height":
				old.deck_height = deck_height
				deck_height = maxf(float(fields.deck_height), 2.0)
			"structure":
				old.structure = structure.duplicate()
				for k2 in (fields.structure as Dictionary):
					structure[k2] = fields.structure[k2]
	return {} if old.is_empty() else {"op": "set_meta", "fields": old}


## The id the next new entry with `prefix` will get (for ops that name what they add, so later
## ops in the same batch can point at it).
func peek_id(prefix: String) -> String:
	return "%s%d" % [prefix, _next]


func _new_id(prefix: String) -> String:
	var eid := "%s%d" % [prefix, _next]
	_next += 1
	return eid


func _bump_next(eid: String) -> void:
	var digits := eid.substr(1)
	if digits.is_valid_int():
		_next = maxi(_next, int(digits) + 1)


# Queries

func room_rect(room_id: String) -> Rect2:
	var r: Dictionary = rooms.get(room_id, {})
	if r.is_empty():
		return Rect2()
	return Rect2(r.x, r.z, r.w, r.d)


## Rooms on one deck, in id order.
func rooms_on(deck: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in rooms.values():
		if int(r.deck) == deck:
			out.append(r)
	out.sort_custom(func(a, b): return str(a.id).naturalnocasecmp_to(str(b.id)) < 0)
	return out


## The room on `deck` under the point (x, z), or "" for none.
func room_at(deck: int, p: Vector2) -> String:
	for r in rooms_on(deck):
		if Rect2(r.x, r.z, r.w, r.d).has_point(p):
			return r.id
	return ""


## Decks in use, lowest first ([0] for an empty design).
func decks() -> PackedInt32Array:
	var seen := {}
	for r: Dictionary in rooms.values():
		seen[int(r.deck)] = true
	for dk: String in hull:
		seen[int(dk)] = true
	var out := PackedInt32Array(seen.keys())
	out.sort()
	return out if out.size() > 0 else PackedInt32Array([0])


## Where two rooms on one deck touch: the shared stretch of wall, as two points, or [] if they
## don't share a wall at least `min_len` long.
func shared_wall(a_id: String, b_id: String, min_len: float = 0.0) -> PackedVector2Array:
	var a: Dictionary = rooms.get(a_id, {})
	var b: Dictionary = rooms.get(b_id, {})
	if a.is_empty() or b.is_empty() or int(a.deck) != int(b.deck):
		return PackedVector2Array()
	var ra := Rect2(a.x, a.z, a.w, a.d)
	var rb := Rect2(b.x, b.z, b.w, b.d)
	const EPS := 0.01
	# Side by side across X.
	for pair in [[ra.end.x, rb.position.x], [rb.end.x, ra.position.x]]:
		if absf(pair[0] - pair[1]) < EPS:
			var z0 := maxf(ra.position.y, rb.position.y)
			var z1 := minf(ra.end.y, rb.end.y)
			if z1 - z0 > maxf(min_len, EPS):
				return PackedVector2Array([Vector2(pair[0], z0), Vector2(pair[0], z1)])
	for pair in [[ra.end.y, rb.position.y], [rb.end.y, ra.position.y]]:
		if absf(pair[0] - pair[1]) < EPS:
			var x0 := maxf(ra.position.x, rb.position.x)
			var x1 := minf(ra.end.x, rb.end.x)
			if x1 - x0 > maxf(min_len, EPS):
				return PackedVector2Array([Vector2(x0, pair[0]), Vector2(x1, pair[0])])
	return PackedVector2Array()


## The design's footprint over every deck, m (x, z, w, d), or an empty rect.
func bounds() -> Rect2:
	var out := Rect2()
	var first := true
	for r: Dictionary in rooms.values():
		var rr := Rect2(r.x, r.z, r.w, r.d)
		out = rr if first else out.merge(rr)
		first = false
	for dk: String in hull:
		for p: Array in hull[dk]:
			var v := Vector2(float(p[0]), float(p[1]))
			out = Rect2(v, Vector2.ZERO) if first else out.expand(v)
			first = false
	return out


func snap(v: float) -> float:
	return snappedf(v, grid)


# Saving

func to_dict() -> Dictionary:
	return {
		"format": FORMAT, "id": id, "name": name, "notes": notes, "grid": grid,
		"deck_height": deck_height, "next": _next,
		"rooms": _sorted(rooms), "doors": _sorted(doors), "components": _sorted(components),
		"runs": _sorted(runs), "structure": structure.duplicate(),
		"sketch_layers": _sorted(sketch_layers), "strokes": _sorted(strokes),
		"hull": hull.duplicate(true), "walls": _sorted(walls), "beams": _sorted(beams),
	}


static func from_dict(data: Dictionary) -> DesignRecord:
	var d := DesignRecord.new(str(data.get("id", "")), str(data.get("name", "New design")))
	d.notes = str(data.get("notes", ""))
	d.grid = float(data.get("grid", 1.0))
	d.deck_height = float(data.get("deck_height", 3.0))
	for r: Dictionary in data.get("rooms", []):
		var room := r.duplicate()
		room.deck = int(room.get("deck", 0))
		d.rooms[str(room.id)] = room
	for x: Dictionary in data.get("doors", []):
		var door := x.duplicate()
		door.deck = int(door.get("deck", 0))
		d.doors[str(door.id)] = door
	for c: Dictionary in data.get("components", []):
		var comp := c.duplicate()
		comp.rot = int(comp.get("rot", 0))
		d.components[str(comp.id)] = comp
	for w: Dictionary in data.get("runs", []):
		var run := w.duplicate(true)
		run.deck = int(run.get("deck", 0))
		d.runs[str(run.id)] = run
	var hd: Dictionary = data.get("hull", {})
	for dk in hd:
		d.hull[str(dk)] = (hd[dk] as Array).duplicate(true)
	for wv: Dictionary in data.get("walls", []):
		var wall := wv.duplicate(true)
		wall.deck = int(wall.get("deck", 0))
		d.walls[str(wall.id)] = wall
	for bv: Dictionary in data.get("beams", []):
		var beam := bv.duplicate(true)
		beam.deck = int(beam.get("deck", 0))
		d.beams[str(beam.id)] = beam
	for l: Dictionary in data.get("sketch_layers", []):
		var layer := l.duplicate()
		layer.order = int(layer.get("order", 0))
		layer.visible = bool(layer.get("visible", true))
		d.sketch_layers[str(layer.id)] = layer
	for k: Dictionary in data.get("strokes", []):
		d.strokes[str(k.id)] = k.duplicate(true)
	var st: Dictionary = data.get("structure", {})
	for k in st:
		d.structure[k] = st[k]
	d.structure.spacing = float(d.structure.spacing)
	d._next = int(data.get("next", 1))
	for table: Dictionary in [d.rooms, d.doors, d.components, d.runs, d.sketch_layers, d.strokes, d.walls, d.beams]:
		for eid: String in table:
			d._bump_next(eid)
	return d


func duplicate_record(new_id: String, new_name: String) -> DesignRecord:
	var copy := DesignRecord.from_dict(to_dict())
	copy.id = new_id
	copy.name = new_name
	return copy


func _sorted(table: Dictionary) -> Array:
	var keys := table.keys()
	keys.sort_custom(func(a, b): return str(a).naturalnocasecmp_to(str(b)) < 0)
	var out: Array = []
	for k in keys:
		out.append(table[k].duplicate(true))
	return out
