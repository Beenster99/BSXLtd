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
##   {op = "set_room", id, fields = {x?, z?, w?, d?, deck?, name?, type?, outline?}}
##     outline: a shaped room's corners, [[u, v], ...] m from its x, z corner, inside its w x d
##     box, square-cornered; absent (or null) for a plain rectangle. A new w or d stretches it.
##   {op = "remove_room", id}            # its doors and components go with it
##   {op = "add_door", door = {id?, a, b, deck, x, z}}     # b = "" is a door to space
##   {op = "remove_door", id}
##   {op = "set_door", id, fields = {kind?, x?, z?}}   # kind: DesignCatalog.DOOR_KINDS
##   {op = "add_component", component = {id?, type, room, x, z, rot?}}
##   {op = "set_component", id, fields = {...}}
##   {op = "remove_component", id}
##   {op = "add_run", run = {id?, kind, deck, points = [[x, z], ...]}}   # a wire or pipe
##   {op = "set_run", id, fields = {...}}
##   {op = "remove_run", id}
##   {op = "set_hull", deck, points = [[x, z], ...]}   # the hull's outline on a deck ([] clears it)
##   {op = "shift_decks", by}   # every deck moved up by `by` (1: a new empty deck under the lowest)
##   {op = "add_wall", wall = {id?, deck, a = [x, z], b = [x, z]}}   # an inner wall drawn anywhere
##   {op = "remove_wall", id}
##   {op = "set_wall", id, fields = {a?, b?}}   # an end moved
##   {op = "add_beam", beam = {id?, deck, a = [x, z], b = [x, z]}}   # a beam under the deckhead
##   {op = "remove_beam", id}
##   {op = "set_beam", id, fields = {a?, b?}}
##   {op = "add_mount", mount = {id?, type, deck, x, z, angle}}   # a part on the outside of the hull
##   {op = "set_mount", id, fields = {...}}
##   {op = "remove_mount", id}
##   {op = "add_pin", pin = {id?, deck, x, z, text}}   # a note pinned to the ship
##   {op = "set_pin", id, fields = {text?, x?, z?}}
##   {op = "remove_pin", id}
##   {op = "add_layer", layer = {id?, name, visible?, order?}}   # a whiteboard layer
##   {op = "set_layer", id, fields = {name?, visible?, order?}}
##   {op = "remove_layer", id}           # its strokes go with it
##   {op = "add_stroke", stroke = {id?, layer, tool, colour, width, points = [[x, y], ...]}}
##   {op = "remove_stroke", id}
##   {op = "set_meta", fields = {name?, notes?, grid?, deck_height?, structure? (merged), order?,
##       livery? (merged; a null value takes that key out), livery_set? (the whole livery)}}
##   {op = "batch", ops = [...]}         # applied in order, undone in reverse
## The undo of a remove re-adds what was removed with its old id, so ids stay stable.

signal changed(op: Dictionary)

const FORMAT := 1
## Grid steps the designer can pick, m.
const GRIDS: PackedFloat32Array = [0.05, 0.1, 0.25, 0.5, 1.0, 2.0]

var id := ""
var name := "New design"
var notes := ""
## The ship order this design answers (ShipOrders: {id, client_name, title, demands, pay,
## days, ...}), {} for none: the data channel scores the design against its demands.
var order: Dictionary = {}
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
## The designers' changes to the proposed structure (DesignFrame): key -> value.
##   "panel:<z>:<edge>" -> {glass: bool}     the hull panel over edge <edge> of the bay at z
##   "section:<z>" -> {grow: [port, starboard, roof, belly]}   the ring nearest z pushed out, m
var frame_edits: Dictionary = {}
## Her paint and markings (DesignLivery, the outside designer stage 4): {base, trim, stripe,
## stripe_at, pattern, number, show_name, client}; {} for the yard's bare alloy.
var livery: Dictionary = {}
## Parts fitted on the outside of the hull (thrusters, engines): id -> {id, type, deck, x, z,
## angle}, (x, z) on the hull's side and `angle` the way its front faces (radians, from +X
## towards +Z: the hull's outward normal where it was fitted).
var mounts: Dictionary = {}
## Notes pinned to the ship (plan 3.4): id -> {id, deck, x, z, text}.
var pins: Dictionary = {}
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
			var rid := str(op.get("id", ""))
			var f: Dictionary = (op.get("fields", {}) as Dictionary).duplicate(true)
			var was: Dictionary = rooms.get(rid, {})
			if not was.is_empty() and was.get("outline") is Array and not f.has("outline") \
					and (f.has("w") or f.has("d")):
				var sx := float(f.get("w", was.w)) / maxf(float(was.w), 0.01)
				var sz := float(f.get("d", was.d)) / maxf(float(was.d), 0.01)
				var pts: Array = []
				for p: Array in was.outline:
					pts.append([snappedf(float(p[0]) * sx, 0.01), snappedf(float(p[1]) * sz, 0.01)])
				f["outline"] = pts
			return _set_fields(rooms, rid, f, "set_room")
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
		"set_door":
			return _set_fields(doors, str(op.get("id", "")), op.get("fields", {}), "set_door")
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
		"set_frame":
			var key := str(op.get("key", ""))
			if key == "":
				return {}
			var was: Variant = frame_edits.get(key)
			var value: Variant = op.get("value")
			if value is Dictionary and not (value as Dictionary).is_empty():
				if was is Dictionary and was == value:
					return {}
				frame_edits[key] = (value as Dictionary).duplicate(true)
			elif was == null:
				return {}
			else:
				frame_edits.erase(key)
			return {"op": "set_frame", "key": key, "value": (was as Dictionary).duplicate(true) if was is Dictionary else null}
		"shift_decks":
			# Everything up (or down) a deck: a new empty deck under the lowest.
			var by := int(op.get("by", 0))
			if by == 0:
				return {}
			for table: Dictionary in [rooms, doors, runs, walls, beams, mounts]:
				for e: Dictionary in table.values():
					if int(e.get("deck", 0)) + by < 0:
						return {}
			for k in hull:
				if int(k) + by < 0:
					return {}
			for table: Dictionary in [rooms, doors, runs, walls, beams, mounts]:
				for e: Dictionary in table.values():
					e["deck"] = int(e.get("deck", 0)) + by
			var moved := {}
			for k in hull:
				moved[str(int(k) + by)] = hull[k]
			hull = moved
			return {"op": "shift_decks", "by": -by}
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
		"set_wall", "set_beam":
			var table := walls if op.op == "set_wall" else beams
			var eid := str(op.get("id", ""))
			var f: Dictionary = op.get("fields", {}).duplicate(true)
			if not table.has(eid):
				return {}
			for end: String in ["a", "b"]:
				if f.has(end):
					var v: Array = f[end]
					if v.size() < 2:
						return {}
					f[end] = [float(v[0]), float(v[1])]
			var e: Dictionary = table[eid]
			var na: Array = f.get("a", e.a)
			var nb: Array = f.get("b", e.b)
			if Vector2(float(na[0]), float(na[1])).distance_to(Vector2(float(nb[0]), float(nb[1]))) < 0.1:
				return {}
			return _set_fields(table, eid, f, str(op.op))
		"remove_wall":
			return _remove_entry(walls, str(op.get("id", "")), "wall", "add_wall")
		"remove_beam":
			return _remove_entry(beams, str(op.get("id", "")), "beam", "add_beam")
		"add_mount":
			var m: Dictionary = op.get("mount", {}).duplicate()
			if str(m.get("type", "")) == "":
				return {}
			m["deck"] = int(m.get("deck", 0))
			m["x"] = float(m.get("x", 0.0))
			m["z"] = float(m.get("z", 0.0))
			m["angle"] = float(m.get("angle", 0.0))
			return _add_entry(mounts, m, "h", "mount", "remove_mount")
		"set_mount":
			return _set_fields(mounts, str(op.get("id", "")), op.get("fields", {}), "set_mount")
		"remove_mount":
			return _remove_entry(mounts, str(op.get("id", "")), "mount", "add_mount")
		"add_pin":
			var nt: Dictionary = op.get("pin", {}).duplicate()
			if str(nt.get("text", "")).strip_edges() == "":
				return {}
			nt["deck"] = int(nt.get("deck", 0))
			nt["x"] = float(nt.get("x", 0.0))
			nt["z"] = float(nt.get("z", 0.0))
			nt["text"] = str(nt.text).strip_edges().left(200)
			return _add_entry(pins, nt, "n", "pin", "remove_pin")
		"set_pin":
			return _set_fields(pins, str(op.get("id", "")), op.get("fields", {}), "set_pin")
		"remove_pin":
			return _remove_entry(pins, str(op.get("id", "")), "pin", "add_pin")
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
	var r := room.duplicate(true)
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
	# Its outline pulled in a hair, every corner inside the hull and no side crossing it.
	var poly := room_poly(r)
	var inset := Geometry2D.offset_polygon(poly, -0.01)
	if not inset.is_empty():
		poly = inset[0]
	for c in poly:
		if not Geometry2D.is_point_in_polygon(c, outline):
			return false
	if not Geometry2D.intersect_polyline_with_polygon(poly + PackedVector2Array([poly[0]]), outline).size() == 1:
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
			"order":
				old.order = order.duplicate(true)
				order = (fields.order as Dictionary).duplicate(true) if fields.order is Dictionary else {}
			"structure":
				old.structure = structure.duplicate()
				for k2 in (fields.structure as Dictionary):
					structure[k2] = fields.structure[k2]
			"livery", "livery_set":
				if not old.has("livery_set"):
					old.livery_set = livery.duplicate(true)
				if str(k) == "livery_set":
					livery = (fields[k] as Dictionary).duplicate(true) if fields[k] is Dictionary else {}
				else:
					for k2 in (fields.livery as Dictionary):
						if fields.livery[k2] == null:
							livery.erase(k2)
						else:
							livery[k2] = fields.livery[k2]
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

## The ID shown for a placed object (beenster, 19 Nov: "every object placed in the ship to have
## a unique ID"): its record id upper-cased (R4 a room, C12 a component, H3 a hull mount, D7 a
## door, W2 a service run, I5 an inner wall, B1 a beam). Every kind draws from one counter, so
## no two objects in a design share one.
static func tag(eid: String) -> String:
	return eid.to_upper()


## A room's floor as a polygon (ship space): its outline if it is shaped, else its box.
static func room_poly(r: Dictionary) -> PackedVector2Array:
	var x := float(r.x)
	var z := float(r.z)
	var out := PackedVector2Array()
	if r.get("outline") is Array and (r.outline as Array).size() >= 3:
		for p: Array in r.outline:
			out.append(Vector2(x + float(p[0]), z + float(p[1])))
		return out
	var w := float(r.w)
	var d := float(r.d)
	return PackedVector2Array([Vector2(x, z), Vector2(x + w, z), Vector2(x + w, z + d), Vector2(x, z + d)])


static func is_shaped(r: Dictionary) -> bool:
	return r.get("outline") is Array and (r.outline as Array).size() >= 3


## Whether p is on a room's floor (its edges count, as Rect2.has_point's start edges do).
static func room_has(r: Dictionary, p: Vector2) -> bool:
	var box := Rect2(r.x, r.z, r.w, r.d)
	if not box.has_point(p):
		return false
	if not is_shaped(r):
		return true
	var poly := room_poly(r)
	if Geometry2D.is_point_in_polygon(p, poly):
		return true
	for i in poly.size():
		if Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()]).distance_to(p) < 0.001:
			return true
	return false


## Whether every side of a room runs along x or z (a box, an L, a U...: false once a side slants).
static func is_square(r: Dictionary) -> bool:
	var poly := room_poly(r)
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if absf(a.x - b.x) > 0.001 and absf(a.y - b.y) > 0.001:
			return false
	return true


## A square-cornered room's floor as rectangles that tile it (just its box when it isn't
## shaped): cut on every corner's line, and the cells inside kept. A room with a slanted side
## has the rectangles wholly on its floor only; build it from room_poly.
static func room_cells(r: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not is_shaped(r):
		out.append(Rect2(r.x, r.z, r.w, r.d))
		return out
	var poly := room_poly(r)
	var xs: Array[float] = []
	var zs: Array[float] = []
	for p in poly:
		if not xs.any(func(v: float) -> bool: return absf(v - p.x) < 0.001):
			xs.append(p.x)
		if not zs.any(func(v: float) -> bool: return absf(v - p.y) < 0.001):
			zs.append(p.y)
	xs.sort()
	zs.sort()
	var square := is_square(r)
	for i in xs.size() - 1:
		for k in zs.size() - 1:
			var c := Rect2(xs[i], zs[k], xs[i + 1] - xs[i], zs[k + 1] - zs[k])
			if square and Geometry2D.is_point_in_polygon(c.get_center(), poly) \
					or not square and _area_of(Geometry2D.clip_polygons(_rect_poly(c), poly)) < 0.001:
				out.append(c)
	return out


static func _rect_poly(c: Rect2) -> PackedVector2Array:
	return PackedVector2Array([c.position, Vector2(c.end.x, c.position.y), c.end, Vector2(c.position.x, c.end.y)])


## The area of clip results: outlines less the holes in them, m2.
static func _area_of(polys: Array[PackedVector2Array]) -> float:
	var a := 0.0
	for q in polys:
		a += -absf(_signed_area(q)) if Geometry2D.is_polygon_clockwise(q) else absf(_signed_area(q))
	return maxf(a, 0.0)


static func _signed_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a * 0.5


## A room's floor area, m2.
static func room_area(r: Dictionary) -> float:
	return absf(_signed_area(room_poly(r)))


## Whether two rooms' floors overlap (more than a sliver).
static func rooms_overlap(a: Dictionary, b: Dictionary) -> bool:
	if not Rect2(a.x, a.z, a.w, a.d).intersects(Rect2(b.x, b.z, b.w, b.d)):
		return false
	var area := 0.0
	for q in Geometry2D.intersect_polygons(room_poly(a), room_poly(b)):
		area += absf(_signed_area(q))
	return area > 0.01


## Whether a rectangle lies wholly on a room's floor.
static func room_encloses(r: Dictionary, rect: Rect2) -> bool:
	var box := Rect2(r.x, r.z, r.w, r.d).grow(0.01)
	if not box.encloses(rect):
		return false
	if not is_shaped(r):
		return true
	return _area_of(Geometry2D.clip_polygons(_rect_poly(rect), room_poly(r))) <= 0.02


## Which way a room's side runs at p (the side nearest it), as a unit vector.
static func side_at(r: Dictionary, p: Vector2) -> Vector2:
	var poly := room_poly(r)
	var best := Vector2.RIGHT
	var near := INF
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if a.distance_to(b) < 0.001:
			continue
		var dist := Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)
		if dist < near:
			near = dist
			best = (b - a).normalized()
	return best


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
		if room_has(r, p):
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
	const EPS := 0.01
	var pa := room_poly(a)
	var pb := room_poly(b)
	var best := PackedVector2Array()
	var best_len := maxf(min_len, EPS)
	# Two sides touch where they lie on one line (at any angle) and overlap along it.
	for i in pa.size():
		var a0 := pa[i]
		var a1 := pa[(i + 1) % pa.size()]
		var la := a0.distance_to(a1)
		if la < EPS:
			continue
		var along := (a1 - a0) / la
		for k in pb.size():
			var b0 := pb[k]
			var b1 := pb[(k + 1) % pb.size()]
			if absf(along.cross(b0 - a0)) > EPS or absf(along.cross(b1 - a0)) > EPS:
				continue
			var t0 := maxf(0.0, minf((b0 - a0).dot(along), (b1 - a0).dot(along)))
			var t1 := minf(la, maxf((b0 - a0).dot(along), (b1 - a0).dot(along)))
			if t1 - t0 > best_len:
				best_len = t1 - t0
				var p0 := a0 + along * t0
				var p1 := a0 + along * t1
				# From the low end, as a box's sides are listed.
				best = PackedVector2Array([p0, p1]) if p0.x + p0.y <= p1.x + p1.y else PackedVector2Array([p1, p0])
	return best


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
		"format": FORMAT, "id": id, "name": name, "notes": notes, "grid": grid, "order": order.duplicate(true),
		"deck_height": deck_height, "next": _next,
		"rooms": _sorted(rooms), "doors": _sorted(doors), "components": _sorted(components),
		"runs": _sorted(runs), "structure": structure.duplicate(),
		"sketch_layers": _sorted(sketch_layers), "strokes": _sorted(strokes),
		"hull": hull.duplicate(true), "frame_edits": frame_edits.duplicate(true), "livery": livery.duplicate(true), "walls": _sorted(walls), "beams": _sorted(beams), "mounts": _sorted(mounts), "pins": _sorted(pins),
	}


static func from_dict(data: Dictionary) -> DesignRecord:
	var d := DesignRecord.new(str(data.get("id", "")), str(data.get("name", "New design")))
	d.notes = str(data.get("notes", ""))
	var o: Variant = data.get("order", {})
	d.order = (o as Dictionary).duplicate(true) if o is Dictionary else {}
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
	d.frame_edits = (data.get("frame_edits", {}) as Dictionary).duplicate(true)
	d.livery = (data.get("livery", {}) as Dictionary).duplicate(true)
	for wv: Dictionary in data.get("walls", []):
		var wall := wv.duplicate(true)
		wall.deck = int(wall.get("deck", 0))
		d.walls[str(wall.id)] = wall
	for bv: Dictionary in data.get("beams", []):
		var beam := bv.duplicate(true)
		beam.deck = int(beam.get("deck", 0))
		d.beams[str(beam.id)] = beam
	for mv: Dictionary in data.get("mounts", []):
		var m := mv.duplicate(true)
		m.deck = int(m.get("deck", 0))
		d.mounts[str(m.id)] = m
	for nv: Dictionary in data.get("pins", []):
		var nt := nv.duplicate(true)
		nt.deck = int(nt.get("deck", 0))
		d.pins[str(nt.id)] = nt
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
	for table: Dictionary in [d.rooms, d.doors, d.components, d.runs, d.sketch_layers, d.strokes, d.walls, d.beams, d.mounts, d.pins]:
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
