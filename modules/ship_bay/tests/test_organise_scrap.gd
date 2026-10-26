extends ModuleTest
## Ship and Bay: ORGANISE SCRAP on the small, medium and large trolleys (beenster, 0.3.20).
## In that mode a trolley roams the courtyard and takes every loose part it can carry where
## its condition says: the stores, a refurb line's drop area or the crusher's. PARK ends it.
## Also: goods drawn on a deck sit on it, not over it.
##   tools/run_tests.sh ship_bay


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var flags := ["ship_bay.clean_up", "ship_bay.organise_scrap"]
	var was := flags.map(func(f: String) -> bool: return Flags.is_on(f))
	for f: String in flags:
		Flags.set_flag(f, true)
	var intake_was := Flags.is_on("ship_bay.refurb_runs_intake")
	Flags.set_flag("ship_bay.refurb_runs_intake", false)
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	for i in 3:
		await get_tree().physics_frame
	yard.call("set_walker_active", false)
	var fleet: Node3D = yard.get("trolleys")
	var all: Dictionary = fleet.get("trolleys")
	for t: Node in all.values():
		t.set("speed_scale", 5.0)
		t.set("accel", 12.0)
		t.set("turn_rate", 8.0)
		t.set("lift_speed", 6.0)

	# Goods drawn on a deck sit on the grating.
	var p: Node3D = all["p"]
	p.call("set_cargo", {"lots": [{"item": "Gyroscope", "count": 2, "condition": 0.8}]})
	var low := INF
	for m: Node in (p.get("deck") as Node3D).find_children("*", "MeshInstance3D", true, false):
		if (m as Node).get_parent() == p.get("deck"):
			continue   # the deck's own plate and frame
		var mi := m as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb()
		low = minf(low, box.position.y)
	var deck_top := (p.get("deck") as Node3D).global_position.y
	check(absf(low - deck_top) < 0.01, "goods on a deck sit on it: %.3f m over" % (low - deck_top))
	p.call("set_cargo", {})

	# Every yard trolley has the button; pressed, it lights and the trolley roams.
	for id: String in ["s", "m", "l"]:
		var screen: Node = all[id].get("screen")
		check((screen.get("buttons") as Dictionary).has("organise"), "trolley %s has ORGANISE SCRAP" % id.to_upper())
		screen.call("press", "organise")
	await frames(2)
	check(bus.is_organising("s") and bus.is_organising("m") and bus.is_organising("l"), "pressed, each is organising")
	var lit := str(((all["m"].get("screen") as Node).get("buttons") as Dictionary)["organise"].text)
	check(lit == "ORGANISING SCRAP", "its button says so: %s" % lit)
	var roamed := false
	var start: Vector3 = (all["m"] as Node3D).global_position
	for i in 600:
		await get_tree().physics_frame
		if (all["m"] as Node3D).global_position.distance_to(start) > 2.0:
			roamed = true
			break
	check(roamed, "with nothing lying about it roams the courtyard")
	check(bus.snapshot().get("organising", []).size() == 3, "the mode goes in the save")

	# Three parts drop in the courtyard: they're taken where their condition says.
	var parts := {"loose_a": ["IonThruster", 0.95, Vector3(-6, 0.5, 12)], "loose_b": ["Gyroscope", 0.5, Vector3(6, 0.4, 12)],
			"loose_c": ["FuelPump", 0.1, Vector3(0, 0.4, 16)]}
	for slot: String in parts:
		var body := Node3D.new()
		body.name = slot
		yard.add_child(body)
		body.global_position = parts[slot][2]
		bus.note_loose(slot, parts[slot][0], parts[slot][1], body)
	var claimed := []
	var on_claim := func(slot: String, trolley: String) -> void: claimed.append([slot, trolley])
	bus.clean_up_claimed.connect(on_claim)
	for i in 7200:
		await get_tree().physics_frame
		if bus.loose_parts().is_empty() and _in_feed(bus).size() == 1 and _at_crusher(bus) and bus.stock_count("IonThruster") == 1:
			break
	check(claimed.size() == 3, "organising trolleys went for every part by themselves: %s" % [claimed])
	check(bus.stock_count("IonThruster") == 1, "the good thruster went into the stores")
	var fed := _in_feed(bus)
	check(fed.size() == 1 and str(fed.values()[0].item) == "Gyroscope", "the worn gyroscope went to a refurb line: %s" % [fed])
	check(_at_crusher(bus), "the scrap pump went to the crusher: %s" % [bus.line_state().crusher])
	bus.clean_up_claimed.disconnect(on_claim)

	# PARK ends it.
	(all["m"].get("screen") as Node).call("press", "park")
	await frames(2)
	check(not bus.is_organising("m") and bus.is_organising("s"), "PARK takes it out of organise mode")

	yard.queue_free()
	await frames(1)
	for i in flags.size():
		Flags.set_flag(flags[i], was[i])
	Flags.set_flag("ship_bay.refurb_runs_intake", intake_was)
	bus.reset_data()


func _at_crusher(bus: ShipBayBus) -> bool:
	var pad := _on_pad(bus)
	if pad.size() == 1 and str(pad.values()[0].item) == "FuelPump":
		return true
	var crusher: Dictionary = bus.line_state().crusher
	return str((crusher.get("lot", {}) as Dictionary).get("item", "")) == "FuelPump" or not (crusher.dust as Dictionary).is_empty() or not (crusher.ingots as Dictionary).is_empty()


func _on_pad(bus: ShipBayBus) -> Dictionary:
	var out := {}
	for id: String in bus.line_crates():
		if str(bus.line_crates()[id].line) == "crush":
			out[id] = bus.line_crates()[id]
	return out


func _in_feed(bus: ShipBayBus) -> Dictionary:
	var out := {}
	for id: String in bus.line_crates():
		if str(bus.line_crates()[id].line) == "in":
			out[id] = bus.line_crates()[id]
	return out
