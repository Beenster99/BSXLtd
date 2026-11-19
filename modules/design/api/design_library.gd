class_name DesignLibrary
extends RefCounted
## The company's saved designs (plan 2.7): save under a name, start a new one in the same
## session, reopen, copy, rename and delete. One design is open at a time (`current`); it is
## the working copy everyone edits, and save_current() stores it under its name. The game's
## save keeps both the stored designs and the working copy, so an autosave never loses work
## that was not saved by name yet.
##
## Saves provider for the "design" section (Saves.register_section).

signal list_changed
## A different design is open now (or none: current == null).
signal opened(record: DesignRecord)
## The open design was edited (the op as applied) or saved.
signal edited(op: Dictionary)
signal stored(design_id: String)
## The ready-made modules changed (saved, renamed, removed).
signal modules_changed

const SAVE_VERSION := 1

## design id -> the stored record's dict (with "saved_at").
var _stored: Dictionary = {}
var current: DesignRecord
## The open design has edits not yet saved under its name.
var dirty := false
var _next := 1
## Ready-made modules (beenster, 18 Nov): a room with its parts, saved under a name, dropped
## into any design. module id -> {id, name, room: {type, w, d, name}, components: [{type, x, z,
## rot}] and runs: [{kind, points}] relative to the room's corner, saved_at}.
var _modules: Dictionary = {}
var _next_module := 1


# Listing

## Saved designs, newest first: [{id, name, saved_at, rooms, components}].
func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in _stored:
		var s: Dictionary = _stored[id]
		out.append({"id": id, "name": str(s.get("name", id)), "saved_at": int(s.get("saved_at", 0)),
				"rooms": (s.get("rooms", []) as Array).size(),
				"components": (s.get("components", []) as Array).size()})
	out.sort_custom(func(a, b):
		if a.saved_at != b.saved_at:
			return a.saved_at > b.saved_at
		return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return out


func has(design_id: String) -> bool:
	return _stored.has(design_id)


## Whether a stored design already uses this name (case ignored).
func name_taken(design_name: String, except_id: String = "") -> bool:
	for id: String in _stored:
		if id != except_id and str(_stored[id].get("name", "")).to_lower() == design_name.strip_edges().to_lower():
			return true
	return false


## A name no stored design uses: "Hauler", "Hauler 2", ...
func free_name(base: String) -> String:
	var clean := base.strip_edges()
	if clean == "":
		clean = "New design"
	var candidate := clean
	var n := 2
	while name_taken(candidate):
		candidate = "%s %d" % [clean, n]
		n += 1
	return candidate


# Changing the list

## Starts a new empty design, stored at once so it shows in the list, and opens it.
func create(design_name: String = "") -> DesignRecord:
	var rec := DesignRecord.new(_new_id(), free_name(design_name))
	_store(rec)
	_open(rec)
	return rec


## Opens a stored design (the working copy of any other is dropped: save it first).
func open(design_id: String) -> DesignRecord:
	if not _stored.has(design_id):
		return null
	_open(DesignRecord.from_dict(_stored[design_id]))
	return current


## Stores the open design under its name.
func save_current() -> void:
	if current == null:
		return
	_store(current)
	dirty = false
	edited.emit({})


## Saves the open design as a new one under another name and opens that.
func save_as(design_name: String) -> DesignRecord:
	if current == null:
		return null
	var copy := current.duplicate_record(_new_id(), free_name(design_name))
	_store(copy)
	_open(copy)
	return copy


## Opens a design someone else in the session has open (designing together): the working copy
## is theirs, under its own id, or "crew_<id>" where that id names a different design of
## ours, so saving it never writes over one of ours. Not stored until saved.
func adopt(data: Dictionary) -> DesignRecord:
	var rec := DesignRecord.from_dict(data)
	if _stored.has(rec.id) and str(_stored[rec.id].get("name", "")) != rec.name and not rec.id.begins_with("crew_"):
		rec.id = "crew_" + rec.id
	_open(rec)
	return rec


## Copies a stored design under a new name (not opened).
func copy(design_id: String, design_name: String = "") -> String:
	if not _stored.has(design_id):
		return ""
	var src := DesignRecord.from_dict(_stored[design_id])
	var base := design_name if design_name.strip_edges() != "" else src.name + " copy"
	var rec := src.duplicate_record(_new_id(), free_name(base))
	_store(rec)
	return rec.id


func rename(design_id: String, design_name: String) -> bool:
	var clean := design_name.strip_edges()
	if not _stored.has(design_id) or clean == "" or name_taken(clean, design_id):
		return false
	_stored[design_id]["name"] = clean
	if current and current.id == design_id:
		current.name = clean
		edited.emit({})
	list_changed.emit()
	return true


func remove(design_id: String) -> bool:
	if not _stored.has(design_id):
		return false
	_stored.erase(design_id)
	if current and current.id == design_id:
		_open(null)
	list_changed.emit()
	return true


# Ready-made modules

## Saves a room of the open design, with its components and the runs inside it, as a module.
## Returns its id ("" if the room isn't there). A taken name gets a number.
func save_module(module_name: String, room_id: String) -> String:
	if current == null or not current.rooms.has(room_id):
		return ""
	var r: Dictionary = current.rooms[room_id]
	var corner := Vector2(float(r.x), float(r.z))
	var rect := Rect2(corner, Vector2(float(r.w), float(r.d)))
	var comps: Array = []
	for c: Dictionary in current.components.values():
		if c.room == room_id:
			comps.append({"type": c.type, "x": float(c.x) - corner.x, "z": float(c.z) - corner.y, "rot": int(c.rot)})
	comps.sort_custom(func(a, b): return [a.type, a.x, a.z] < [b.type, b.x, b.z])
	var runs: Array = []
	for w: Dictionary in current.runs.values():
		if int(w.deck) != int(r.deck):
			continue
		var pts := DesignServices.points(w)
		if Array(pts).all(func(p: Vector2) -> bool: return rect.grow(0.01).has_point(p)):
			var rel: Array = []
			for p in pts:
				rel.append([p.x - corner.x, p.y - corner.y])
			runs.append({"kind": w.kind, "points": rel})
	var id := "module_%d" % _next_module
	_next_module += 1
	while _modules.has(id):
		id = "module_%d" % _next_module
		_next_module += 1
	var clean := module_name.strip_edges()
	if clean == "":
		clean = str(r.get("name", "")) if str(r.get("name", "")) != "" else str(r.type).capitalize()
	var taken := func(n: String) -> bool:
		return _modules.values().any(func(m): return str(m.name).to_lower() == n.to_lower())
	var final_name := clean
	var n := 2
	while taken.call(final_name):
		final_name = "%s %d" % [clean, n]
		n += 1
	_modules[id] = {"id": id, "name": final_name, "saved_at": int(Time.get_unix_time_from_system()),
			"room": {"type": r.type, "w": float(r.w), "d": float(r.d), "name": str(r.get("name", ""))},
			"components": comps, "runs": runs}
	modules_changed.emit()
	return id


## A module someone else in the session saved (designing together): kept under its own id,
## or a new one where ours already uses it for another module. The same module again (same
## name, room and parts) is not kept twice. Returns its id here.
func receive_module(m: Dictionary) -> String:
	var mod := m.duplicate(true)
	for have: Dictionary in _modules.values():
		if str(have.name) == str(mod.get("name", "")) and have.get("room") == mod.get("room") \
				and have.get("components") == mod.get("components"):
			return str(have.id)
	var id := str(mod.get("id", ""))
	if id == "" or _modules.has(id):
		id = "module_%d" % _next_module
		while _modules.has(id):
			_next_module += 1
			id = "module_%d" % _next_module
	mod["id"] = id
	_modules[id] = mod
	modules_changed.emit()
	return id


## A design someone else in the session saved: listed here too (not opened), under its own
## id, or "crew_<id>" where that id names a different design of ours.
func receive_design(data: Dictionary) -> String:
	var d := data.duplicate(true)
	var id := str(d.get("id", ""))
	if id == "":
		return ""
	if _stored.has(id) and str(_stored[id].get("name", "")) != str(d.get("name", "")) and not id.begins_with("crew_"):
		id = "crew_" + id
		d["id"] = id
	_stored[id] = d
	list_changed.emit()
	return id


## Every saved design, as stored (for sharing with the crew).
func stored_design(design_id: String) -> Dictionary:
	return _stored.get(design_id, {})


## Modules, by name: [{id, name, room, components, runs}].
func modules() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Dictionary in _modules.values():
		out.append(m)
	out.sort_custom(func(a, b): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return out


func module(module_id: String) -> Dictionary:
	return _modules.get(module_id, {})


func remove_module(module_id: String) -> bool:
	if not _modules.erase(module_id):
		return false
	modules_changed.emit()
	return true


func rename_module(module_id: String, module_name: String) -> bool:
	var clean := module_name.strip_edges()
	if not _modules.has(module_id) or clean == "":
		return false
	_modules[module_id].name = clean
	modules_changed.emit()
	return true


## The op that drops a module into `rec`, its room centred on `at` (snapped to the grid) on
## `deck`: one batch, so one undo takes it all away. {} for an unknown module.
func place_module_op(module_id: String, rec: DesignRecord, deck: int, at: Vector2) -> Dictionary:
	var m: Dictionary = _modules.get(module_id, {})
	if m.is_empty() or rec == null:
		return {}
	var size := Vector2(float(m.room.w), float(m.room.d))
	var corner := (at - size * 0.5).snapped(Vector2.ONE * rec.grid)
	var rid := rec.peek_id("r")
	var ops: Array = [{"op": "add_room", "room": {"id": rid, "type": m.room.type, "deck": deck,
			"x": corner.x, "z": corner.y, "w": size.x, "d": size.y, "name": m.room.get("name", "")}}]
	for c: Dictionary in m.components:
		ops.append({"op": "add_component", "component": {"type": c.type, "room": rid,
				"x": corner.x + float(c.x), "z": corner.y + float(c.z), "rot": int(c.rot)}})
	for w: Dictionary in m.get("runs", []):
		var pts: Array = []
		for p: Array in w.points:
			pts.append([corner.x + float(p[0]), corner.y + float(p[1])])
		ops.append({"op": "add_run", "run": {"kind": w.kind, "deck": deck, "points": pts}})
	return {"op": "batch", "ops": ops}


# Saves provider

func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	var designs: Array = []
	for item in list():
		designs.append(_stored[item.id].duplicate(true))
	var mods: Array = []
	for m in modules():
		mods.append(m.duplicate(true))
	var data := {"designs": designs, "next": _next, "modules": mods, "next_module": _next_module}
	if current:
		data["open"] = current.id
		if dirty:
			data["working"] = current.to_dict()
	return data


func load_data(data: Dictionary, _from_version: int) -> void:
	_stored = {}
	_next = int(data.get("next", 1))
	for d: Dictionary in data.get("designs", []):
		_stored[str(d.get("id", ""))] = d.duplicate(true)
	_stored.erase("")
	_modules = {}
	_next_module = int(data.get("next_module", 1))
	for m: Dictionary in data.get("modules", []):
		_modules[str(m.get("id", ""))] = m.duplicate(true)
	_modules.erase("")
	modules_changed.emit()
	var open_id := str(data.get("open", ""))
	var working: Dictionary = data.get("working", {})
	if not working.is_empty() and str(working.get("id", "")) == open_id:
		_open(DesignRecord.from_dict(working))
		dirty = true
	elif _stored.has(open_id):
		_open(DesignRecord.from_dict(_stored[open_id]))
	else:
		_open(null)
	list_changed.emit()


func reset_data() -> void:
	load_data({}, SAVE_VERSION)


# Internals

func _store(rec: DesignRecord) -> void:
	var d := rec.to_dict()
	d["saved_at"] = int(Time.get_unix_time_from_system())
	# Two saves in one second still list newest first.
	for s: Dictionary in _stored.values():
		if s.get("id") != rec.id:
			d.saved_at = maxi(d.saved_at, int(s.get("saved_at", 0)) + 1) if int(s.get("saved_at", 0)) >= d.saved_at else d.saved_at
	_stored[rec.id] = d
	stored.emit(rec.id)
	list_changed.emit()


func _open(rec: DesignRecord) -> void:
	if current and current.changed.is_connected(_on_changed):
		current.changed.disconnect(_on_changed)
	current = rec
	dirty = false
	if current:
		current.changed.connect(_on_changed)
	opened.emit(current)


func _on_changed(op: Dictionary) -> void:
	dirty = true
	edited.emit(op)


func _new_id() -> String:
	var id := "design_%d" % _next
	_next += 1
	while _stored.has(id):
		id = "design_%d" % _next
		_next += 1
	return id
