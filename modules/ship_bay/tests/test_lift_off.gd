extends ModuleTest
## Ship and Bay: a player's beam can take goods off any trolley (beenster, 0.3.19). Drawn
## trolley loads, floor crates and shelf stock carry look boxes with the part's catalogue id
## (and the crate's), so the look card and Tools' beam find them; lift_off_trolley takes a
## crate off its trolley and out of stock, without deck_part_left, and the trolley goes on.
##   tools/run_tests.sh ship_bay


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	Flags.set_flag("ship_bay.trucks", false)
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	for i in 3:
		await get_tree().physics_frame
	var fleet: Node3D = yard.get("trolleys")
	for t: Node in (fleet.get("trolleys") as Dictionary).values():
		t.set("speed_scale", 5.0)
		t.set("accel", 12.0)
		t.set("turn_rate", 8.0)
		t.set("lift_speed", 6.0)
	bus.receive_delivery("PO-LIFT", [{"item_id": "Gyroscope", "qty": 1, "condition": 0.8, "name": "Gyroscope", "grade": "used", "mass": 120.0},
			{"item_id": "FuelPump", "qty": 1, "condition": 1.0, "name": "Fuel pump", "grade": "new", "mass": 60.0}])
	await frames(2)
	var floor_boxes := _boxes(yard).filter(func(a: Area3D) -> bool: return a.has_meta("crate_id"))
	check(floor_boxes.size() >= 1 and floor_boxes.all(func(a: Area3D) -> bool: return str(a.get_meta("component")) != "" and a.has_meta("condition")),
			"delivered crates on the floor carry look boxes with their part and crate: %d" % floor_boxes.size())
	# Wait for a trolley to take one aboard.
	var carrier := ""
	var crate := ""
	for i in 3600:
		await get_tree().physics_frame
		for id: String in bus.delivered_crates():
			var by := str(bus.delivered_crates()[id].get("carrier", ""))
			if by != "":
				carrier = by
				crate = id
		if carrier != "":
			break
	check(carrier != "", "a trolley takes a crate aboard")
	if carrier == "":
		yard.queue_free()
		Flags.set_flag("ship_bay.trucks", true)
		return
	var t: Node3D = (fleet.get("trolleys") as Dictionary)[carrier]
	var on_deck: Array = []
	for i in 240:
		await get_tree().physics_frame
		on_deck = _boxes(t).filter(func(a: Area3D) -> bool: return str(a.get_meta("crate_id", "")) == crate)
		if not on_deck.is_empty():
			break
	check(not on_deck.is_empty() and str(on_deck[0].get_meta("component")) != "", "the load drawn on its deck has a look box with the crate's id")
	var left := []
	var on_left := func(cid: String, _tid: String) -> void: left.append(cid)
	bus.deck_part_left.connect(on_left)
	check(not bus.lift_off_trolley("no-such-crate"), "a crate that isn't on a trolley can't be lifted off")
	check(bus.lift_off_trolley(crate), "a player's beam lifts the crate off")
	await frames(2)
	check(bus.crate_info(crate).is_empty() and not bus.trolley_load(carrier).has(crate) and bus.lifted_off(crate),
			"it is off the trolley and out of stock")
	check(left.is_empty(), "no deck_part_left for a lifted crate")
	bus.deck_part_left.disconnect(on_left)
	# The trolley carries on: the other crate still goes away.
	for i in 7200:
		await get_tree().physics_frame
		if bus.delivered_crates().is_empty():
			break
	check(bus.delivered_crates().is_empty(), "the trolleys still put the rest away: %s" % [bus.delivered_crates().keys()])
	var shelf: Array = []
	for i in 600:
		await get_tree().physics_frame
		shelf = _boxes(yard).filter(func(a: Area3D) -> bool: return a.has_meta("location"))
		if not shelf.is_empty():
			break
	shelf = _boxes(yard).filter(func(a: Area3D) -> bool: return a.has_meta("location"))
	check(not shelf.is_empty() and shelf.all(func(a: Area3D) -> bool: return str(a.get_meta("component")) != ""),
			"stock on the shelves carries look boxes with its part: %d %s %s" % [shelf.size(), bus.stocked_locations(), _boxes(yard).size()])
	yard.queue_free()
	Flags.set_flag("ship_bay.trucks", true)


func _boxes(root: Node) -> Array:
	return root.find_children("*", "Area3D", true, false).filter(func(a: Node) -> bool: return a.has_meta("look_only"))
