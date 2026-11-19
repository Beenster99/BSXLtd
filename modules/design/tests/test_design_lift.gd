extends ModuleTest
## Design Room: lifts. A lift room stacked over another is one shaft: in walk-inside a platform
## rides it when you stand on it, a gate closes the shaft on every deck it isn't at, its doors
## open only where it stands, and someone by the door on another deck calls it.
##   tools/run_tests.sh design

const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")
const WalkBuild := preload("res://modules/design/internal/walk/walk_build.gd")


func run_tests() -> void:
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	var rec := bus.library.create("Lift test")
	check(bus.catalog.room("lift") != null and bus.catalog.room("lift").links_decks, "a lift is a room type that links decks")
	for op: Dictionary in [
		{"op": "add_room", "room": {"id": "r1", "type": "corridor", "deck": 0, "x": 0, "z": 0, "w": 6, "d": 2}},
		{"op": "add_room", "room": {"id": "r2", "type": "lift", "deck": 0, "x": 6, "z": 0, "w": 2.5, "d": 2.5}},
		{"op": "add_room", "room": {"id": "r3", "type": "lift", "deck": 1, "x": 6, "z": 0, "w": 2.5, "d": 2.5}},
		{"op": "add_room", "room": {"id": "r4", "type": "mess", "deck": 1, "x": 0, "z": 0, "w": 6, "d": 4}},
		{"op": "add_room", "room": {"id": "r5", "type": "airlock", "deck": 0, "x": 0, "z": 2, "w": 3, "d": 2}},
		{"op": "add_door", "door": {"a": "r1", "b": "r2", "deck": 0, "x": 6, "z": 1}},
		{"op": "add_door", "door": {"a": "r4", "b": "r3", "deck": 1, "x": 6, "z": 1}},
		{"op": "add_door", "door": {"a": "r1", "b": "r5", "deck": 0, "x": 1.5, "z": 2}},
		{"op": "add_door", "door": {"a": "r5", "b": "", "deck": 0, "x": 1.5, "z": 4}},
	]:
		bus.editor.do(op)
	var reach := DesignRules.reachable(rec, bus.catalog)
	check(reach.has("r4"), "the lift joins the decks: the mess on deck 2 can be reached")
	check(WalkBuild.stairwells(rec, bus.catalog) == {"r2": "r3"}, "the two lift rooms are one shaft")

	var room := Node3D.new()
	add_child(room)
	var f := Furnishing.new()
	room.add_child(f)
	f.setup(bus, Furnishing.stand_in_walls())
	f.open_walk()
	await frames(2)
	var walk: Node3D = f.walk
	var b: WalkBuild = walk.builder
	check(b.lifts.size() == 1 and (b.lifts[0].decks as Array) == [0, 1], "a platform for the shaft: %s" % [b.lifts.size()])
	var lift: Dictionary = b.lifts[0]
	var door_up := b.doors.filter(func(d): return d.has("lift") and int(d.deck) == 1)
	check(door_up.size() == 1, "the shaft's door on deck 2 belongs to the lift")
	check(not _gate_on(lift, 0) and _gate_on(lift, 1), "the shaft is gated on deck 2, open where the platform is")

	# Stand on it: it takes you up.
	walk.body.position = Vector3(7.25, 0.95, 1.25)
	walk.body.velocity = Vector3.ZERO
	await _physics(20)
	check(walk.body.is_on_floor(), "standing on the platform")
	await _physics(240)
	check(int(lift.at) == 1 and absf(float(walk.body.position.y) - 0.9 - rec.deck_height) < 0.2,
			"after a moment it rides you up to deck 2: at %d, feet %.2f" % [int(lift.at), walk.body.position.y - 0.9])
	check(_gate_on(lift, 0) and not _gate_on(lift, 1), "now deck 1's shaft is gated")
	await _physics(120)
	check(int(lift.at) == 1, "it waits for you to step off before going again")
	b.update_doors([Vector3(6, rec.deck_height + 1.0, 1)], 2.0)
	check(float(door_up[0].open) > 0.5, "its door opens on deck 2")
	var door_down := b.doors.filter(func(d): return d.has("lift") and int(d.deck) == 0)
	b.update_doors([Vector3(6, 1.0, 1)], 2.0)
	check(float(door_down[0].open) < 0.01, "and stays shut on deck 1, where the platform isn't")

	# Off at the top, then someone by the door below calls it down.
	walk.body.position = Vector3(3, rec.deck_height + 0.95, 1)
	await _physics(10)
	b.update_lifts([Vector3(5.0, 0.9, 1)], 0.1)
	check(int(lift.target) == 0, "someone by the door on deck 1 calls it")
	for i in 200:
		b.update_lifts([Vector3(5.0, 0.9, 1)], 1.0 / 60.0)
	check(int(lift.at) == 0, "and it comes down")
	f.close_walk()
	room.queue_free()
	await frames(2)


func _gate_on(lift: Dictionary, deck: int) -> bool:
	return not ((lift.gates[deck] as Node).get_child(0) as CollisionShape3D).disabled


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
