extends ModuleTest
## Ship and Bay: CLEAN UP on the wrist's Machines channel (beenster, 0.3.8). Parts off the
## ship lie loose in the yard (Tools tells the bus, note_loose); CLEAN UP sends trolleys to
## collect them and sort each by its condition: good ones into the stores, worn ones to the
## refurbishment lines' intake bays, scrap out to the crusher's feed pad. The lines take
## their bays' parts first; the crusher takes what is on its pad by itself.
##   tools/run_tests.sh ship_bay


const RefurbLine := preload("res://modules/ship_bay/internal/yard/refurb_line.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var was_on := Flags.is_on("ship_bay.clean_up")
	Flags.set_flag("ship_bay.clean_up", true)
	# The lines wait (AUTO off, intake not run by itself) till the bay's parts are checked.
	var intake_was := Flags.is_on("ship_bay.refurb_runs_intake")
	Flags.set_flag("ship_bay.refurb_runs_intake", false)
	check(ShipBayBus.clean_up_route(0.95) == "store" and ShipBayBus.clean_up_route(0.5) == "refurb" and ShipBayBus.clean_up_route(0.1) == "grind",
			"the trolleys sort by condition: stores, refurbishing, crusher")
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
	check(text.contains("LOOSE PARTS 3") and text.contains("STORES 1") and text.contains("REFURB 1") and text.contains("CRUSHER 1"),
			"the wrist counts them by where they'll go: %s" % text.left(120))

	# With Tools' bodies lying on the decks (trades.parts_on_decks), no crate is drawn for a
	# beamed part, and the bus says when each leaves its trolley so Tools lets the body go.
	var decks_was := Flags.is_on("trades.parts_on_decks")
	Flags.set_flag("trades.parts_on_decks", true)
	var beamed := []
	var left := []
	var drawn := []
	var on_beamed := func(cid: String, tid: String, _c: String, _s: String) -> void:
		beamed.append(cid)
		var t: Node = (fleet.get("trolleys") as Dictionary)[tid]
		if not (t.get("cargo") as Dictionary).is_empty() and str((t.get("cargo") as Dictionary).get("key", "")).contains(cid):
			drawn.append(cid)
	var on_left := func(cid: String, _tid: String) -> void: left.append(cid)
	bus.part_beamed.connect(on_beamed, CONNECT_DEFERRED)
	bus.deck_part_left.connect(on_left)
	var claimed := []
	var on_claim := func(slot: String, trolley: String) -> void: claimed.append([slot, trolley])
	bus.clean_up_claimed.connect(on_claim)
	wrist.call("clean_up")
	check(not claimed.is_empty(), "CLEAN UP sends trolleys for them: %s" % [claimed])

	for i in 7200:
		await get_tree().physics_frame
		if bus.loose_parts().is_empty() and _in_feed(bus).size() == 1 and _at_crusher(bus) and bus.stock_count("IonThruster") == 1:
			break
	check(bus.stock_count("IonThruster") == 1 and float(bus.stock_at(bus.find_stock("IonThruster")[0]).condition) > 0.94,
			"the good thruster went into the stores")
	var fed := _in_feed(bus)
	var pad := _on_pad(bus)
	check(fed.size() == 1 and str(fed.values()[0].item) == "Gyroscope", "the worn gyroscope is in a line's intake bay: %s" % [fed])
	check(_at_crusher(bus), "the scrap pump went out to the crusher (on its pad or in it): %s %s" % [pad, bus.line_state().crusher])
	check(bus.loose_parts().is_empty() and not bus.cleaning, "the yard is clean")
	check(beamed.size() == 3 and drawn.is_empty(), "no crate is drawn on a deck for a beamed part: %s drawn of %s" % [drawn, beamed])
	check(beamed.all(func(c: String) -> bool: return left.has(c)), "each beamed part's leaving its trolley is announced: %s of %s" % [left, beamed])
	bus.part_beamed.disconnect(on_beamed)
	bus.deck_part_left.disconnect(on_left)
	Flags.set_flag("trades.parts_on_decks", decks_was)
	var bay := ""
	for id: String in fed:
		bay = str(fed[id].get("line_id", ""))
		check(RefurbLine.in_spots(bay).any(func(p: Vector3) -> bool: return p.distance_to(bus.crate_position(id)) < 0.01),
				"%s stands on an intake pallet of line %s" % [fed[id].item, bay])
	line = (yard.get("lines") as Dictionary).get(bay, line)
	line.set("run_time", 0.2)
	line.set("travel_time", 0.05)
	var lots: Array = line.get("lots")
	check(not lots.is_empty() and lots[0].has("crate"), "the survey offers the bay's parts before the stores: %s" % [lots])

	# With AUTO off the line still runs what trolleys set down in its bay (beenster, 0.3.18:
	# tidy up, and refurb sorts it by itself); the crusher takes the pump by itself.
	var crusher: Node3D = yard.get("crusher")
	crusher.set("crush_time", 0.3)
	crusher.set("feed_time", 0.1)
	check(not bool(bus.line_state().get("auto", false)), "AUTO is off")
	Flags.set_flag("ship_bay.refurb_runs_intake", true)
	var t := 0.0
	while t < 10.0 and (not _in_feed(bus).is_empty() or not _on_pad(bus).is_empty() or str(bus.line_state().crusher.state) != ""):
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	var dust := 0.0
	for m: String in bus.line_state().crusher.dust:
		dust += float(bus.line_state().crusher.dust[m])
	for m: String in bus.ingots():
		dust += int(bus.ingots()[m]) * ShipBayBus.INGOT_KG
	check(dust > 0.0, "the scrap pump went through the crusher (%.1f kg)" % dust)
	check(_in_feed(bus).is_empty(), "and the gyroscope went on down the line by itself")
	check(not bool(bus.line_state().get("auto", false)), "without AUTO being switched on")

	bus.clean_up_claimed.disconnect(on_claim)
	wrist.queue_free()
	yard.queue_free()
	await frames(1)
	Flags.set_flag("ship_bay.clean_up", was_on)
	Flags.set_flag("ship_bay.refurb_runs_intake", intake_was)
	bus.reset_data()


## True once the pump is on the crusher's pad or the crusher has taken it in.
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
