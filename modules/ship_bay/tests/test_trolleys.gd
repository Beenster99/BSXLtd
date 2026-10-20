extends ModuleTest
## Ship and Bay: the hover trolleys plan routes round the yard, put delivered crates away on
## their places (raising the deck to the shelf), come when called, lift their decks, and
## can be taken on remote control.
##   tools/run_tests.sh ship_bay

const Layout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var scene := load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene
	var yard := scene.instantiate() as Node3D
	add_child(yard)
	await frames(3)
	for i in 3:
		await get_tree().physics_frame
	var fleet: Node3D = yard.get("trolleys")
	check(fleet != null, "the yard has its trolleys")
	if fleet == null:
		yard.queue_free()
		return
	var trolleys: Dictionary = fleet.get("trolleys")
	check(trolleys.keys() == ["s", "m", "l", "p"], "small, medium, large and the picking lift: %s" % [trolleys.keys()])
	var hall: AABB = bus.shipyard_rooms()["deliveries"]["box"]
	var haulers: Array = [trolleys["s"], trolleys["m"], trolleys["l"]]
	check(haulers.all(func(t: Node3D) -> bool: return hall.has_point(t.global_position + Vector3(0, 1, 0))),
			"parked in Deliveries")
	check((bus.shipyard_rooms()["stock"]["box"] as AABB).has_point(trolleys["p"].global_position + Vector3(0, 1, 0)), "the lift in the stores")
	# The walker stays out of the way at the far end of the courtyard.
	yard.call("set_walker_active", false)

	# Routes: through the doors, down the aisles, clear of everything.
	var nav: RefCounted = fleet.get("nav")
	check(nav != null, "the route planner is built")
	var m: Node3D = trolleys["m"]
	var place := bus.home_location("IonThruster")
	var to := Vector3(Layout.aisle_x(str(place).substr(0, 1)), 0, (Layout.get_layout()["locations"][place]["at"] as Vector3).z)
	var path: PackedVector3Array = nav.call("route", m.global_position, to, m.call("radius"))
	check(path.size() >= 2 and path[path.size() - 1].distance_to(to) < 0.1, "a route from Deliveries down aisle %s: %d points" % [str(place).substr(0, 1), path.size()])
	var clear := true
	var prev := m.global_position
	for p in path:
		for k in 10:
			if not bool(nav.call("is_free", prev.lerp(p, k / 10.0), float(m.call("radius")) - 0.05)):
				clear = false
		prev = p
	check(clear, "the route keeps its trolley clear of walls and racks")
	var court: PackedVector3Array = nav.call("route", m.global_position, Vector3(-6, 0, 16), float(trolleys["l"].call("radius")))
	check(not court.is_empty(), "even the large trolley finds a way into the courtyard")
	check(not bool(nav.call("is_free", Vector3(Layout.rack_x("B1"), 0, Layout.bay_z(2)), 0.3)), "racks are in the way")

	# Put deliveries away: a pallet, a bin and a bulk crate, each by the trolley that fits.
	for t: Node in trolleys.values():
		t.set("speed_scale", 5.0)
		t.set("accel", 12.0)
		t.set("turn_rate", 8.0)
		t.set("lift_speed", 6.0)
	bus.receive_delivery("PO-21", [
			{"item_id": "IonThruster", "qty": 2, "condition": 1.0, "name": "Ion thruster", "grade": "new", "mass": 311.0},
			{"item_id": "M10", "qty": 100, "condition": 1.0, "name": "M10 bolt", "grade": "new", "mass": 0.05},
			{"item_id": "Reactor", "qty": 1, "condition": 1.0, "name": "Reactor", "grade": "new", "mass": 11953.0}])
	var carried := {}
	var lifted := {}
	var on_carry := func(crate_id: String, trolley_id: String) -> void: carried[crate_id] = trolley_id
	bus.crate_carried.connect(on_carry)
	for id: String in ["s", "m", "l", "p"]:
		bus.command_trolley(id, "put_away")
	for i in 5400:
		await get_tree().physics_frame
		for id: String in trolleys:
			lifted[id] = maxf(float(lifted.get(id, 0.0)), float(trolleys[id].get("deck_height")))
		if bus.delivered_crates().is_empty():
			break
	var states := {}
	for id: String in trolleys:
		states[id] = "%s at %s" % [trolleys[id].get("status"), trolleys[id].global_position.snapped(Vector3(0.1, 0.1, 0.1))]
	check(bus.delivered_crates().is_empty(), "every crate put away: %s (%s)" % [bus.delivered_crates().keys(), states])
	check(carried.get("PO-21/1") == "m" and carried.get("PO-21/2") == "s" and carried.get("PO-21/3") == "l",
			"each carried by the trolley its size needs: %s" % [carried])
	check(bus.stock_at(bus.home_location("IonThruster")).get("qty") == 2, "the thrusters are on their home")
	check(bus.stock_count("M10") == 100 and bus.stock_count("Reactor") == 1, "the bolts in their bin, the reactor on the bulk floor")
	var level: float = (Layout.get_layout()["locations"][place]["at"] as Vector3).y
	check(float(lifted["m"]) >= level - 0.02, "the medium trolley raised its deck to the shelf: %.2f of %.2f" % [lifted["m"], level])
	# Then they go home and park.
	for i in 2400:
		await get_tree().physics_frame
		if trolleys.values().all(func(t: Node) -> bool: return t.get("status") == "PARKED" or t.get("status") == "ALL PUT AWAY" and (t.get("path") as PackedVector3Array).is_empty()):
			break
	check(haulers.all(func(t: Node3D) -> bool: return hall.has_point(t.global_position + Vector3(0, 1, 0))), "back in Deliveries")

	# Called: the medium trolley comes out to someone in the courtyard and waits by them.
	var me := Vector3(-6, 0, 14)
	bus.command_trolley("m", "come", {"to": me})
	for i in 2400:
		await get_tree().physics_frame
		if m.get("status") == "HERE":
			break
	var gap := Vector2(m.global_position.x - me.x, m.global_position.z - me.z).length()
	check(m.get("status") == "HERE" and gap < 2.6, "the medium trolley came: %.1f m away (%s)" % [gap, m.get("status")])

	# Its deck rises for work at height and comes down again.
	bus.command_trolley("m", "deck", {"height": 5.0})
	for i in 120:
		await get_tree().physics_frame
	check(absf(float(m.get("deck_height")) - 5.0) < 0.01, "deck up to 5 m: %.2f" % m.get("deck_height"))
	bus.command_trolley("m", "deck", {"height": 0.0})
	for i in 120:
		await get_tree().physics_frame
	check(float(m.get("deck_height")) < 0.75, "and down again")

	# Remote control: F on it takes it, the arrow keys drive it, F again lets it go.
	fleet.call("toggle_remote", "m")
	check(fleet.get("remote_id") == "m", "taken on remote control")
	var start := m.global_position
	m.set("drive_input", Vector2(0, 1))
	fleet.set("remote_id", "m")
	for i in 60:
		m.call("step", 1.0 / 60.0, [])
	check(m.global_position.distance_to(start) > 0.5, "it drives forward under remote control")
	fleet.call("toggle_remote", "m")
	check(fleet.get("remote_id") == "", "and lets go")

	bus.crate_carried.disconnect(on_carry)
	yard.queue_free()
	await frames(1)
	bus.reset_data()
