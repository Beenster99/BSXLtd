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

const SAVE_VERSION := 1

## design id -> the stored record's dict (with "saved_at").
var _stored: Dictionary = {}
var current: DesignRecord
## The open design has edits not yet saved under its name.
var dirty := false
var _next := 1


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


# Saves provider

func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	var designs: Array = []
	for item in list():
		designs.append(_stored[item.id].duplicate(true))
	var data := {"designs": designs, "next": _next}
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
