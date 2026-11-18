extends RefCounted
## Ready-made designs for tests, screenshots and the Debug tab: a two-deck skiff that passes
## every rule.

const SKIFF_OPS := [
	{"op": "add_room", "room": {"id": "r1", "type": "bridge", "x": -2, "z": -10, "w": 5, "d": 4, "name": "Bridge"}},
	{"op": "add_room", "room": {"id": "r2", "type": "corridor", "x": -1, "z": -6, "w": 2, "d": 10}},
	{"op": "add_room", "room": {"id": "r3", "type": "quarters", "x": 1, "z": -6, "w": 4, "d": 4}},
	{"op": "add_room", "room": {"id": "r4", "type": "cargo", "x": -7, "z": -6, "w": 6, "d": 6, "name": "Main hold"}},
	{"op": "add_room", "room": {"id": "r5", "type": "engineering", "x": 1, "z": -2, "w": 6, "d": 6}},
	{"op": "add_room", "room": {"id": "r6", "type": "airlock", "x": -1, "z": 4, "w": 3, "d": 2}},
	{"op": "add_room", "room": {"id": "r7", "type": "stairs", "x": -3, "z": 0, "w": 2, "d": 4}},
	{"op": "add_room", "room": {"id": "r8", "type": "stairs", "deck": 1, "x": -3, "z": 0, "w": 2, "d": 4}},
	{"op": "add_room", "room": {"id": "r9", "type": "mess", "deck": 1, "x": -1, "z": -4, "w": 5, "d": 4}},
	{"op": "add_room", "room": {"id": "r10", "type": "medbay", "deck": 1, "x": -1, "z": 0, "w": 4, "d": 4}},
	{"op": "add_room", "room": {"id": "r11", "type": "fuel", "deck": 1, "x": -7, "z": 0, "w": 4, "d": 4}},
	{"op": "add_door", "door": {"a": "r1", "b": "r2", "x": 0, "z": -6}},
	{"op": "add_door", "door": {"a": "r2", "b": "r3", "x": 1, "z": -4}},
	{"op": "add_door", "door": {"a": "r2", "b": "r4", "x": -1, "z": -2}},
	{"op": "add_door", "door": {"a": "r2", "b": "r5", "x": 1, "z": 1}},
	{"op": "add_door", "door": {"a": "r2", "b": "r6", "x": 0, "z": 4}},
	{"op": "add_door", "door": {"a": "r6", "b": "", "x": 0.5, "z": 6}},
	{"op": "add_door", "door": {"a": "r2", "b": "r7", "x": -1, "z": 2}},
	{"op": "add_door", "door": {"a": "r8", "b": "r10", "deck": 1, "x": -1, "z": 2}},
	{"op": "add_door", "door": {"a": "r10", "b": "r9", "deck": 1, "x": 1, "z": 0}},
	{"op": "add_component", "component": {"id": "c1", "type": "pilot_console", "room": "r1", "x": 0.5, "z": -9.4, "rot": 2}},
	{"op": "add_component", "component": {"id": "c2", "type": "reactor_small", "room": "r5", "x": 3, "z": 2.5}},
	{"op": "add_component", "component": {"id": "c3", "type": "main_engine", "room": "r5", "x": 5.6, "z": 2.6}},
	{"op": "add_component", "component": {"id": "c4", "type": "bunk", "room": "r3", "x": 3.9, "z": -5, "rot": 1}},
	{"op": "add_component", "component": {"id": "c5", "type": "bunk", "room": "r3", "x": 3.9, "z": -3, "rot": 1}},
	{"op": "add_component", "component": {"id": "c6", "type": "life_support", "room": "r5", "x": 2, "z": -1.5, "rot": 2}},
	{"op": "add_component", "component": {"id": "c7", "type": "nav_console", "room": "r1", "x": -1, "z": -9.4, "rot": 2}},
	{"op": "add_component", "component": {"id": "c8", "type": "cargo_rack", "room": "r4", "x": -6, "z": -4, "rot": 3}},
	{"op": "add_component", "component": {"id": "c9", "type": "galley", "room": "r9", "x": 1.5, "z": -3.65, "rot": 2}},
	{"op": "add_component", "component": {"id": "c10", "type": "med_pod", "room": "r10", "x": 1.8, "z": 2, "rot": 1}},
	{"op": "add_component", "component": {"id": "c11", "type": "fuel_pump", "room": "r11", "x": -4.5, "z": 2, "rot": 3}},
]


## Builds the skiff into `rec` (an empty record). With the catalogue it is wired and piped too
## (DesignServices.route).
static func skiff(rec: DesignRecord, cat: DesignCatalog = null) -> void:
	for op: Dictionary in SKIFF_OPS:
		rec.apply(op)
	if cat == null:
		return
	for kind: String in DesignServices.KINDS:
		for run in DesignServices.route(rec, cat, kind):
			rec.apply({"op": "add_run", "run": run})
