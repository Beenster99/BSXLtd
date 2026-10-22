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
	check(trolleys.keys() == ["s", "m", "l", "p", "a", "b"], "small, medium, large, the picking lift and the two lines' trolleys: %s" % [trolleys.keys()])
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
	# The aisles are the picking lift's: it shelves what the trolleys bring to the stores.
	var lift: Node3D = trolleys["p"]
	var place := bus.home_location("IonThruster")
	var to := Vector3(Layout.aisle_x(str(place).substr(0, 1)), 0, (Layout.get_layout()["locations"][place]["at"] as Vector3).z)
	var from: Vector3 = fleet.get("HANDOFF")[0]
	var path: PackedVector3Array = nav.call("route", from, to, lift.call("radius"))
	check(path.size() >= 2 and path[path.size() - 1].distance_to(to) < 0.1, "a route from the stores' doorway down aisle %s: %d points" % [str(place).substr(0, 1), path.size()])
	var clear := true
	var prev := from
	for p in path:
		for k in 10:
			if not bool(nav.call("is_free", prev.lerp(p, k / 10.0), float(lift.call("radius")) - 0.05)):
				clear = false
		prev = p
	check(clear, "the route keeps the lift clear of walls and racks")
	var stand: Array = fleet.call("stores_in", trolleys["l"])
	check(not (nav.call("route", trolleys["l"].global_position, stand[0], trolleys["l"].call("radius")) as PackedVector3Array).is_empty(),
			"the large trolley has a way to the stores' hand-in")
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
	var shelved := {}
	var on_carry := func(crate_id: String, trolley_id: String) -> void:
		if not carried.has(crate_id):
			carried[crate_id] = trolley_id
		elif trolley_id == "p":
			shelved[crate_id] = true
	bus.crate_carried.connect(on_carry)
	for id: String in ["s", "m", "l", "p"]:
		bus.command_trolley(id, "put_away")
	var beams: Node = fleet.get("beams")
	var flown := {}
	var beside := {}
	for i in 5400:
		await get_tree().physics_frame
		for id: String in trolleys:
			lifted[id] = maxf(float(lifted.get(id, 0.0)), float(trolleys[id].get("deck_height")))
		for f: Dictionary in beams.get("flights"):
			flown[f["key"]] = true
			if f["from"] is Vector3 and not beside.has(f["key"]):
				var gap: Vector3 = (f["emitter"] as Node3D).global_position - (f["from"] as Vector3)
				gap.y = 0.0
				beside[f["key"]] = gap.length()
		if bus.delivered_crates().is_empty():
			break
	var states := {}
	for id: String in trolleys:
		states[id] = "%s at %s" % [trolleys[id].get("status"), trolleys[id].global_position.snapped(Vector3(0.1, 0.1, 0.1))]
	check(bus.delivered_crates().is_empty(), "every crate put away: %s (%s)" % [bus.delivered_crates().keys(), states])
	check(carried.size() == 3 and carried.values().all(func(by: String) -> bool: return by != "p"),
			"hover trolleys load them off the goods-in floor: %s" % [carried])
	check(shelved.has("PO-21/1") and shelved.has("PO-21/2") and not shelved.has("PO-21/3"),
			"the picking lift takes the shelf goods off the trolley, the reactor goes on the floor with it: %s" % [shelved])
	check(bus.stock_at(bus.home_location("IonThruster")).get("qty") == 2, "the thrusters are on their home")
	check(flown.size() >= 3, "goods are beamed on and off the trolleys, not just moved: %s" % [flown.keys()])
	check(not beside.is_empty() and beside.values().all(func(d: float) -> bool: return d > 1.5),
			"a trolley parks beside goods on the floor and beams them up: %s" % [beside])
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

	# Its own touch screen in the TV style: letter, status, FOLLOW ME / PARK / FAST / REMOTE CONTROL.
	var own: Node3D = m.get("screen")
	var own_text: String = own.call("text") if own else ""
	check(own_text.contains("TROLLEY M") and own_text.contains("FOLLOW ME") and own_text.contains("FAST") and own_text.contains("REMOTE CONTROL"),
			"the trolley carries a touch screen: %s" % own_text)

	# FOLLOW ME: it follows you at a safe distance until told to stop.
	own.call("press", "call")
	await get_tree().physics_frame
	check(str(fleet.get("jobs")["m"].get("do", "")) == "follow" and fleet.get("following") == "m" and str(own.call("text")).contains("STOP FOLLOWING"),
			"FOLLOW ME has it follow you: %s" % [fleet.get("jobs")["m"]])
	fleet.set("following", "")   # the test moves "you" itself from here
	var lead := Vector3(-6, 0, 4)
	bus.command_trolley("m", "follow", {"to": lead})
	var close := INF
	for i in 1800:
		await get_tree().physics_frame
		close = minf(close, Vector2(m.global_position.x - lead.x, m.global_position.z - lead.z).length())
		if i > 600 and (m.get("path") as PackedVector3Array).is_empty():
			break
	var held := Vector2(m.global_position.x - lead.x, m.global_position.z - lead.z).length()
	check(held < float(m.call("radius")) + 2.6 and close > float(m.call("radius")) + 0.8,
			"it caught up and keeps a safe distance: %.1f m now, never under %.1f m" % [held, close])
	fleet.set("following", "m")
	own.call("press", "call")
	await get_tree().physics_frame
	check(fleet.get("following") == "" and str(fleet.get("jobs")["m"].get("do", "")) != "follow" and str(own.call("text")).contains("FOLLOW ME"),
			"pressed again, it stops following")

	# FAST: fast mode on and off.
	own.call("press", "fast")
	await get_tree().physics_frame
	check(bool(m.get("fast")), "FAST puts it in fast mode")
	own.call("press", "fast")
	await get_tree().physics_frame
	check(not bool(m.get("fast")), "and out again")

	# The large trolley's deck goes up as high as the others now.
	check(float(trolleys["l"].get("spec")["lift"]) >= 7.5, "the large trolley's deck rises to %.1f m" % trolleys["l"].get("spec")["lift"])

	# Remote control: DRIVE on its screen takes it and opens its camera in a picture-in-picture
	# window; W drives it, the mouse turns it, you stand still; F lets it go.
	own.call("press", "remote")
	check(fleet.get("remote_id") == "m", "taken on remote control")
	var view: CanvasLayer = fleet.get("remote_view")
	check(view != null and (view.get("camera") as Camera3D) != null and bus.remote_driving, "its camera shows in a picture-in-picture window, and you stand still")
	var start := m.global_position
	var yaw0 := float(m.call("yaw"))
	Input.action_press(Keys.FORWARD)
	var spin := InputEventMouseMotion.new()
	spin.relative = Vector2(40, 0)
	for i in 120:
		fleet.call("_input", spin)
		await get_tree().physics_frame
	Input.action_release(Keys.FORWARD)
	check(m.global_position.distance_to(start) > 0.5, "W drives it forward: %.2f m" % m.global_position.distance_to(start))
	var deck0 := float(m.get("deck_height"))
	Input.action_press("ship_bay.raise")
	for i in 60:
		await get_tree().physics_frame
	Input.action_release("ship_bay.raise")
	check(float(m.get("deck_height")) > deck0 + 0.3, "the Up key raises its deck: %.2f -> %.2f m" % [deck0, m.get("deck_height")])
	check(absf(wrapf(float(m.call("yaw")) - yaw0, -PI, PI)) > 0.3, "the mouse turns it")
	await frames(1)
	var cam := view.get("camera") as Camera3D
	check(cam.global_position.distance_to(m.global_position) < 3.0 + (m.get("spec")["deck"] as Vector2).y and (-cam.global_basis.z).dot(-m.global_basis.z) > 0.5,
			"the window's camera rides behind it looking ahead")
	var f := InputEventKey.new()
	f.physical_keycode = KEY_F
	f.keycode = KEY_F
	f.pressed = true
	fleet.call("_input", f)
	check(fleet.get("remote_id") == "" and fleet.get("remote_view") == null and not bus.remote_driving, "F hands it back and the window closes")

	# No trolley TV of its own: Business's hall TVs show the Machines channel. The full-size
	# screen still opens.
	check(fleet.get_node_or_null("TrolleyTV") == null, "the yard's own trolley TV is gone")
	fleet.call("open_panel")
	var screen: Control = fleet.get("panel")
	check(screen != null and screen.is_visible_in_tree(), "F on it opens the trolley screen")
	if screen:
		var shown: String = screen.call("text")
		check(shown.contains("SMALL") and shown.contains("PICKING LIFT") and shown.contains("PUT AWAY DELIVERIES"),
				"it lists every vehicle and the yard's keys")
		screen.call("select", "s")
		screen.call("press", "call")
		await get_tree().physics_frame
		check(not (fleet.get("jobs")["s"] as Dictionary).is_empty(), "CALL TO ME sends the small trolley: %s" % [fleet.get("jobs")["s"]])
		screen.call("press", "park_all")
		await get_tree().physics_frame
		check(str(fleet.get("jobs")["s"].get("do", "")) == "park", "PARK ALL parks them")
		screen.call("select", "l")
		screen.call("press", "remote")
		check(fleet.get("remote_id") == "l" and fleet.get("panel") == null, "REMOTE CONTROL takes the large one and shuts the screen")
		fleet.call("toggle_remote", "l")

	# On the wrist: Stock lists what the stores hold, Machines every yard machine.
	check(HudSlots.holo_channel("ship_bay.trolleys").is_empty(), "the old trolleys channel is gone")
	bus.set_part_values(func(item: String) -> int: return {"IonThruster": 1000, "M10": 2}.get(item, -1))
	var stock_ch := HudSlots.holo_channel("ship_bay.stock")
	check(not stock_ch.is_empty(), "the wrist screen has a Stock channel")
	if not stock_ch.is_empty():
		var wrist: Control = (stock_ch["factory"] as Callable).call(true)
		add_child(wrist)
		await frames(2)
		var shown: String = wrist.call("text")
		check(shown.contains("Ion thruster") and shown.contains("M10 bolt") and shown.contains("Reactor"), "it lists the stores' lines: %s" % shown.left(300))
		check(shown.contains("2,200"), "and values them from what prices the parts (2 thrusters + 100 bolts = CR 2,200)")
		check(wrist.get_combined_minimum_size().x <= 900.0 and wrist.get_combined_minimum_size().y <= 560.0,
				"it fits the wrist screen's pane: %s" % wrist.get_combined_minimum_size())
		wrist.set("query", "ion")
		wrist.call("refresh")
		check((wrist.call("shown") as Array).size() == 1, "the search narrows it to the thrusters")
		wrist.call("select", bus.home_location("IonThruster"))
		wrist.call("press", "bring")
		await get_tree().physics_frame
		check(str(fleet.get("jobs")["p"].get("do", "")) == "fetch" and str(fleet.get("jobs")["p"].get("item", "")) == "IonThruster",
				"BRING ONE TO ME sends the picking lift for it: %s" % [fleet.get("jobs")["p"]])
		wrist.queue_free()
	var machines_ch := HudSlots.holo_channel("ship_bay.machines")
	check(not machines_ch.is_empty(), "and a Machines channel")
	if not machines_ch.is_empty():
		var wrist: Control = (machines_ch["factory"] as Callable).call(true)
		add_child(wrist)
		await frames(2)
		var shown: String = wrist.call("text")
		check(shown.contains("Small hover trolley") and shown.contains("Picking lift") and shown.contains("FOLLOW ME") and shown.contains("REMOTE CONTROL") and shown.contains("FAST"),
				"it lists the machines with their buttons: %s" % shown.left(300))
		check(wrist.get_combined_minimum_size().x <= 900.0 and wrist.get_combined_minimum_size().y <= 560.0,
				"it fits the wrist screen's pane: %s" % wrist.get_combined_minimum_size())
		var closed := [false]
		wrist.connect("close_requested", func() -> void: closed[0] = true)
		wrist.call("press", "trolley:s", "come")
		await get_tree().physics_frame
		check(str(fleet.get("jobs")["s"].get("do", "")) == "follow", "FOLLOW ME has the small trolley follow you")
		wrist.call("press", "trolley:s", "come")
		await get_tree().physics_frame
		check(fleet.get("following") == "", "and STOP FOLLOWING lets it go")
		wrist.call("press", "trolley:m", "drive")
		check(fleet.get("remote_id") == "m" and closed[0], "REMOTE CONTROL takes the medium one and puts the wrist away")
		fleet.call("toggle_remote", "m")
		wrist.queue_free()
	bus.set_part_values(Callable())

	bus.crate_carried.disconnect(on_carry)
	yard.queue_free()
	await frames(1)
	bus.reset_data()
