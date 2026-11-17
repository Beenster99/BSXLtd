extends ModuleTest
## Design Room: the design record, its ops and undo, the editor's per-person undo and the
## library's named saves.
##   tools/run_tests.sh design


func run_tests() -> void:
	_record_ops()
	_editor_undo()
	_library()
	_saves_section()


func _record_ops() -> void:
	var d := DesignRecord.new("t", "Test")
	var seen: Array = []
	d.changed.connect(func(op: Dictionary) -> void: seen.append(op.op))
	var u1 := d.apply({"op": "add_room", "room": {"type": "bridge", "deck": 0, "x": 0, "z": -4, "w": 5, "d": 4}})
	check(d.rooms.size() == 1 and u1.op == "remove_room", "add_room adds and undoes by removing: %s" % [u1])
	var rid: String = u1.id
	d.apply({"op": "add_room", "room": {"type": "corridor", "deck": 0, "x": 1, "z": 0, "w": 2, "d": 6}})
	d.apply({"op": "add_component", "component": {"type": "pilot_console", "room": rid, "x": 2.5, "z": -3}})
	var door_undo := d.apply({"op": "add_door", "door": {"a": rid, "b": "r2", "deck": 0, "x": 2, "z": 0}})
	check(d.doors.size() == 1 and d.components.size() == 1, "door and component added")
	check(d.apply({"op": "add_component", "component": {"type": "bunk", "room": "nope", "x": 0, "z": 0}}).is_empty(),
			"a component needs a room that exists")
	var set_undo := d.apply({"op": "set_room", "id": rid, "fields": {"w": 6.0}})
	check(float(d.rooms[rid].w) == 6.0 and float(set_undo.fields.w) == 5.0, "set_room returns the old value")
	d.apply(set_undo)
	check(float(d.rooms[rid].w) == 5.0, "undoing set_room puts it back")
	var before := d.to_dict()
	var rm_undo := d.apply({"op": "remove_room", "id": rid})
	check(not d.rooms.has(rid) and d.doors.is_empty() and d.components.is_empty(),
			"removing a room takes its doors and components with it")
	d.apply(rm_undo)
	check(JSON.stringify(d.to_dict()) == JSON.stringify(before), "undoing a room removal restores it exactly, ids and all")
	check(not door_undo.is_empty(), "door undo exists")
	var copy := DesignRecord.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	check(JSON.stringify(copy.to_dict()) == JSON.stringify(d.to_dict()), "a record survives JSON round trip")
	var fresh := copy.apply({"op": "add_room", "room": {"type": "cargo", "x": 10, "z": 0, "w": 4, "d": 4}})
	check(not d.rooms.has(fresh.id) and not before.rooms.any(func(r): return r.id == fresh.id),
			"a reloaded record never reuses an id: %s" % fresh.id)
	var batch := d.apply({"op": "batch", "ops": [
			{"op": "set_meta", "fields": {"name": "Renamed", "grid": 0.5}},
			{"op": "add_room", "room": {"type": "fuel", "x": -6, "z": 0, "w": 3, "d": 3}}]})
	check(d.name == "Renamed" and d.grid == 0.5 and d.rooms.size() == 3, "a batch applies every op")
	d.apply(batch)
	check(d.name == "Test" and d.grid == 1.0 and d.rooms.size() == 2, "a batch undoes as one")
	check(seen.size() >= 8, "every applied op is announced: %d" % seen.size())
	check(d.shared_wall(rid, "r2", 1.0).size() == 2, "bridge and corridor share a wall")
	check(d.room_at(0, Vector2(2, -2)) == rid, "room_at finds the bridge")


func _editor_undo() -> void:
	var lib := DesignLibrary.new()
	var ed := DesignEditor.new(lib)
	lib.create("Undo test")
	ed.do({"op": "add_room", "room": {"type": "bridge", "x": 0, "z": 0, "w": 4, "d": 4}}, "ann")
	ed.do({"op": "add_room", "room": {"type": "cargo", "x": 4, "z": 0, "w": 4, "d": 4}}, "bob")
	check(ed.undo("ann") and lib.current.rooms.size() == 1, "Ann's undo takes back her room only")
	check(lib.current.rooms.values()[0].type == "cargo", "Bob's room stays")
	check(ed.redo("ann") and lib.current.rooms.size() == 2, "Ann's redo puts it back")
	check(lib.dirty, "edits mark the design unsaved")
	var bob_room: String = lib.current.rooms.values().filter(func(r): return r.type == "cargo")[0].id
	ed.do({"op": "remove_room", "id": bob_room}, "ann")
	check(ed.undo("bob") == false, "Bob's undo of a room Ann removed since is skipped")
	check(not ed.can_undo("bob"), "and his history is spent")


func _library() -> void:
	var lib := DesignLibrary.new()
	var a := lib.create("Hauler")
	check(lib.current == a and lib.list().size() == 1, "create stores and opens")
	a.apply({"op": "add_room", "room": {"type": "bridge", "x": 0, "z": 0, "w": 4, "d": 4}})
	check(lib.dirty, "editing marks it unsaved")
	lib.save_current()
	check(not lib.dirty and lib.list()[0].rooms == 1, "save_current stores the rooms")
	var b := lib.create("Hauler")
	check(b.name == "Hauler 2", "a second design with the same name gets a number: %s" % b.name)
	check(lib.list()[0].id == b.id, "newest first")
	var cid := lib.copy(a.id)
	check(lib.has(cid) and lib.list().any(func(x): return x.name == "Hauler copy"), "copy makes Hauler copy")
	check(lib.rename(cid, "Tug") and not lib.rename(cid, "hauler"), "rename refuses a name in use")
	var reopened := lib.open(a.id)
	check(reopened.rooms.size() == 1 and reopened != a, "open reads the stored copy")
	var c := lib.save_as("Hauler Mk2")
	check(c.rooms.size() == 1 and lib.current == c and lib.list().size() == 4, "save_as stores a copy and opens it")
	check(lib.remove(c.id) and lib.current == null and lib.list().size() == 3, "deleting the open design closes it")


func _saves_section() -> void:
	var lib := DesignLibrary.new()
	var a := lib.create("Kept")
	a.apply({"op": "add_room", "room": {"type": "bridge", "x": 0, "z": 0, "w": 4, "d": 4}})
	lib.save_current()
	a.apply({"op": "add_room", "room": {"type": "cargo", "x": 4, "z": 0, "w": 4, "d": 4}})
	var data: Dictionary = JSON.parse_string(JSON.stringify(lib.save_data()))
	var lib2 := DesignLibrary.new()
	lib2.load_data(data, DesignLibrary.SAVE_VERSION)
	check(lib2.current != null and lib2.current.rooms.size() == 2 and lib2.dirty,
			"an autosave keeps unsaved edits of the open design")
	check(lib2.list()[0].rooms == 1, "and the stored version as it was saved")
	lib2.reset_data()
	check(lib2.list().is_empty() and lib2.current == null, "a new game starts with no designs")
	var bus := Modules.bus("design") as DesignBus
	check(bus != null, "the design module loads")
	if bus:
		check(bus.catalog.rooms.size() >= 10 and bus.catalog.parts.size() >= 10,
				"catalogue has rooms and components: %d %d" % [bus.catalog.rooms.size(), bus.catalog.parts.size()])
