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
##   {op = "set_meta", fields = {name?, notes?, grid?, deck_height?}}
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
	return {"op": undo_op, key: old.duplicate()}


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
	return {} if old.is_empty() else {"op": "set_meta", "fields": old}


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
	return out


func snap(v: float) -> float:
	return snappedf(v, grid)


# Saving

func to_dict() -> Dictionary:
	return {
		"format": FORMAT, "id": id, "name": name, "notes": notes, "grid": grid,
		"deck_height": deck_height, "next": _next,
		"rooms": _sorted(rooms), "doors": _sorted(doors), "components": _sorted(components),
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
	d._next = int(data.get("next", 1))
	for table: Dictionary in [d.rooms, d.doors, d.components]:
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
		out.append(table[k].duplicate())
	return out
