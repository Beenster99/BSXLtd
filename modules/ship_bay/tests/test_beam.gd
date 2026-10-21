extends ModuleTest
## Ship and Bay: parts beamed off the ship go to a hover trolley (Tools' tractor beam asks
## beam_to_trolley): the nearest free trolley big enough drives over, raises its deck to the
## part, the part lands on it as a crate (part_beamed) and it puts it away in the stores.
## Called off (cancel_beam) it parks; with none free the answer is "" so Tools asks again.
##   tools/run_tests.sh ship_bay


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	for i in 3:
		await get_tree().physics_frame
	yard.call("set_walker_active", false)
	var fleet: Node3D = yard.get("trolleys")
	var trolleys: Dictionary = fleet.get("trolleys")
	for t: Node in trolleys.values():
		t.set("speed_scale", 5.0)
		t.set("accel", 12.0)
		t.set("turn_rate", 8.0)
		t.set("lift_speed", 6.0)
	check(bus.trolley_deck_position("m") is Vector3 and bus.trolley_deck_position("x") == null, "the bus finds a trolley's deck")

	var beamed := []
	var on_beamed := func(crate_id: String, trolley_id: String, component: String, slot_id: String) -> void:
		beamed.append([crate_id, trolley_id, component, slot_id])
	bus.part_beamed.connect(on_beamed)
	var from := Vector3(-6.0, 2.2, 8.0)
	var id := bus.beam_to_trolley("hold_panel_1", "IonThruster", 0.9, from)
	check(id == "m", "a thruster (a pallet) gets the medium trolley: %s" % id)
	check(bus.beam_to_trolley("hold_panel_1", "IonThruster", 0.9, from) == id, "asking again for the same part gets the same trolley")
	for i in 2400:
		await get_tree().physics_frame
		if not beamed.is_empty():
			break
	var m: Node3D = trolleys["m"]
	var deck: Vector3 = bus.trolley_deck_position("m")
	check(beamed.size() == 1 and beamed[0][1] == "m" and beamed[0][2] == "IonThruster" and beamed[0][3] == "hold_panel_1",
			"the part landed on its deck: %s (%s at %s)" % [beamed, m.get("status"), m.global_position.snapped(Vector3.ONE * 0.1)])
	check(Vector2(deck.x - from.x, deck.z - from.z).length() < 3.0 and absf(deck.y - (from.y - 0.5)) < 0.3,
			"under the part with its deck raised to it: deck at %s" % deck.snapped(Vector3.ONE * 0.1))
	if not beamed.is_empty():
		check(bus.crate_info(str(beamed[0][0])).get("carrier") == "m" and is_equal_approx(float(bus.crate_info(str(beamed[0][0])).get("condition", 0)), 0.9),
				"it is a crate the trolley carries, in the part's condition")
	for i in 3600:
		await get_tree().physics_frame
		if bus.stock_count("IonThruster") == 1:
			break
	check(bus.stock_count("IonThruster") == 1 and bus.trolley_cargo("m") == "", "then it put the part away in the stores")

	# Called off: the player took the part with their own beam.
	var other := bus.beam_to_trolley("hold_panel_2", "M10", 1.0, from)
	check(other != "" and other != "p", "a bolt gets a trolley too (not the picking lift): %s" % other)
	await get_tree().physics_frame
	bus.cancel_beam("hold_panel_2")
	await get_tree().physics_frame
	check(str(fleet.get("jobs")[other].get("do", "")) == "park", "called off, it parks: %s" % [fleet.get("jobs")[other]])

	# Only the large trolley carries bulk goods: while it is busy there is none for a reactor.
	bus.command_trolley("l", "come", {"to": Vector3(-6, 0, 14)})
	fleet.call("toggle_remote", "l")
	check(bus.beam_to_trolley("hold_panel_3", "Reactor", 1.0, from) == "", "with the large trolley taken there is none for a reactor")
	fleet.call("toggle_remote", "l")
	check(bus.beam_to_trolley("hold_panel_3", "Reactor", 1.0, from) == "l", "and when it's free again it goes")
	for i in 2400:
		await get_tree().physics_frame
		if beamed.size() == 2:
			break
	var big: Vector3 = bus.trolley_deck_position("l")
	check(beamed.size() == 2 and Vector2(big.x - from.x, big.z - from.z).length() < 5.5,
			"the large one finds room to stand by the ship too: deck at %s" % big.snapped(Vector3.ONE * 0.1))

	bus.part_beamed.disconnect(on_beamed)
	yard.queue_free()
	await frames(1)
	bus.unload_ship()
	bus.reset_data()
