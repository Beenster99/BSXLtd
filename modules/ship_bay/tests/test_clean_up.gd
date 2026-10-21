extends ModuleTest
## Ship and Bay: CLEAN UP on the wrist's Machines channel (beenster, 0.3.8). Parts off the
## ship lie loose in the yard (Tools tells the bus, note_loose); CLEAN UP sends trolleys to
## collect them and sort each by its condition: good ones into the stores, worn ones to the
## refurbishment line's in-feed, scrap to the grinder. The line takes in-feed parts first,
## grinding ones straight into the grinder.
##   tools/run_tests.sh ship_bay


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var was_on := Flags.is_on("ship_bay.clean_up")
	Flags.set_flag("ship_bay.clean_up", true)
	check(ShipBayBus.clean_up_route(0.95) == "store" and ShipBayBus.clean_up_route(0.5) == "refurb" and ShipBayBus.clean_up_route(0.1) == "grind",
			"the trolleys sort by condition: stores, refurbishing, grinder")
	check(is_equal_approx(bus.fitted_condition("hold_panel_1"), 1.0), "with no work order a fitted part counts as new")
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	for i in 3:
		await get_tree().physics_frame
	yard.call("set_walker_active", false)
	var fleet: Node3D = yard.get("trolleys")
	for t: Node in (fleet.get("trolleys") as Dictionary).values():
		t.set("speed_scale", 5.0)
		t.set("accel", 12.0)
		t.set("turn_rate", 8.0)
		t.set("lift_speed", 6.0)
	var line: Node3D = yard.get("line")
	line.set("run_time", 0.2)
	line.set("travel_time", 0.05)

	var wrist: Node = fleet.get_script().WristMachines.new(fleet, false)
	yard.add_child(wrist)
	check(str(wrist.call("text")).contains("YARD CLEAR"), "with nothing lying about the wrist says the yard is clear")

	# Three parts lying in the courtyard, as Tools leaves them.
	var parts := {"loose_a": ["IonThruster", 0.95, Vector3(-6, 0.5, 12)], "loose_b": ["Gyroscope", 0.5, Vector3(6, 0.4, 12)],
			"loose_c": ["FuelPump", 0.1, Vector3(0, 0.4, 16)]}
	for slot: String in parts:
		var body := Node3D.new()
		body.name = slot
		yard.add_child(body)
		body.global_position = parts[slot][2]
		bus.note_loose(slot, parts[slot][0], parts[slot][1], body)
	check(bus.loose_parts().size() == 3, "the bus knows the loose parts: %s" % [bus.loose_parts()])
	wrist.call("refresh")
	var text := str(wrist.call("text"))
	check(text.contains("LOOSE PARTS 3") and text.contains("STORES 1") and text.contains("REFURB 1") and text.contains("GRINDER 1"),
			"the wrist counts them by where they'll go: %s" % text.left(120))

	var claimed := []
	var on_claim := func(slot: String, trolley: String) -> void: claimed.append([slot, trolley])
	bus.clean_up_claimed.connect(on_claim)
	wrist.call("clean_up")
	check(not claimed.is_empty(), "CLEAN UP sends trolleys for them: %s" % [claimed])

	for i in 7200:
		await get_tree().physics_frame
		if bus.loose_parts().is_empty() and _in_feed(bus).size() == 2 and bus.stock_count("IonThruster") == 1:
			break
	check(bus.stock_count("IonThruster") == 1 and float(bus.stock_at(bus.find_stock("IonThruster")[0]).condition) > 0.94,
			"the good thruster went into the stores")
	var fed := _in_feed(bus)
	var items := fed.values().map(func(c: Dictionary) -> String: return "%s:%s" % [c.item, c.route])
	check(fed.size() == 2 and items.has("Gyroscope:refurb") and items.has("FuelPump:grind"),
			"the worn gyroscope and the scrap pump are on the line's in-feed: %s" % [items])
	check(bus.loose_parts().is_empty() and not bus.cleaning, "the yard is clean")
	for id: String in fed:
		check(line.get("IN_SPOTS").any(func(p: Vector3) -> bool: return p.distance_to(bus.crate_position(id)) < 0.01),
				"%s stands on an in-feed pallet" % fed[id].item)
	var lots: Array = line.get("lots")
	check(not lots.is_empty() and lots[0].has("crate"), "the survey offers the in-feed before the stores: %s" % [lots])

	# The line takes them: the pump straight into the grinder, the gyroscope into the survey.
	bus.line_request("auto", {"on": true})
	var t := 0.0
	while t < 10.0 and (not _in_feed(bus).is_empty() or bus.dust_kg() <= 0.0):
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	check(bus.dust_kg() > 0.0, "the scrap pump went through the grinder into the dust (%.1f kg)" % bus.dust_kg())
	check(_in_feed(bus).is_empty(), "and the gyroscope went on down the line")
	bus.line_request("auto", {"on": false})

	bus.clean_up_claimed.disconnect(on_claim)
	wrist.queue_free()
	yard.queue_free()
	await frames(1)
	Flags.set_flag("ship_bay.clean_up", was_on)
	bus.reset_data()


func _in_feed(bus: ShipBayBus) -> Dictionary:
	var out := {}
	for id: String in bus.line_crates():
		if str(bus.line_crates()[id].line) == "in":
			out[id] = bus.line_crates()[id]
	return out
