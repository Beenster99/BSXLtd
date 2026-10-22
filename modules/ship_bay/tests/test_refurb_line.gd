extends ModuleTest
## Ship and Bay: the refurbishment line in Pre-assembly. The survey takes a worn lot out of
## the stores and says grind or refurbish; a refurbished lot goes straightener -> bath ->
## coater and lands on an output pallet at 100% as a crate a trolley puts away; a ground
## one fills the dust vessel, which goes to the stores and gives Business its raw
## materials. By hand each machine runs on START and passes on with SEND ON; AUTO runs the
## lot. The line is saved with the bay.
##   tools/run_tests.sh ship_bay


const RefurbLineScript := preload("res://modules/ship_bay/internal/yard/refurb_line.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var scene := load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene
	var yard := scene.instantiate() as Node3D
	add_child(yard)
	await frames(3)
	var line: Node3D = yard.get("line")
	check(line != null, "a refurbishment line stands in the yard")
	var pre: AABB = yard.get("ROOMS")["preassembly"]["box"]
	var machines: Dictionary = line.get("machines") if line else {}
	for s: String in ShipBayBus.LINE_STATIONS:
		var m: Node3D = (machines.get(s, {}) as Dictionary).get("node")
		check(m != null and pre.has_point(m.global_position + Vector3(0, 0.5, 0)) and m.is_in_group("gfx_interactable"),
				"the %s stands in Pre-assembly and lights up under the pointer" % s)
	var tip := HudSlots.look_hint_for({"collider": (machines["bath"].node as Node).get_node("Body")})
	check(str(tip.get("title", "")) == "Chemical Bath" and str(tip.get("text", "")).contains("bare metal"), "looking at a machine says what it does: %s" % [tip])
	check(pre.has_point(line.get("DUST_SPOT") + Vector3(0, 0.5, 0)), "so does the dust vessel")
	var rooms := yard.get_tree().get_nodes_in_group("gfx_room")
	check(rooms.size() == 4 and (rooms[0].get_meta("gfx_box") is AABB), "the four halls are tagged for Graphics' room lighting")
	# Trolleys can reach what the line sets down: the large one the vessel, the medium the pallets.
	var nav: Object = (yard.get("trolleys") as Node).get("nav")
	var parked: Vector3 = (yard.get("trolleys") as Node).get("PARKING")["l"][0]
	for goal: Vector3 in [line.get("DUST_SPOT")] + (line.get("OUT_SPOTS") as Array):
		var path: PackedVector3Array = nav.call("route", parked, goal, 1.3)
		check(not path.is_empty() and path[path.size() - 1].distance_to(goal) < 1.0, "the large trolley has a way to %s: %s" % [goal, path[path.size() - 1] if not path.is_empty() else "none"])
	var survey: Node3D = machines["survey"].screen
	check(str(survey.call("text")).contains("NOTHING") or str(survey.call("text")).contains("Nothing"), "with nothing worn in the stores the survey says so")

	bus.receive_delivery("PO-60", [
		{"item_id": "IonThruster", "qty": 2, "condition": 0.15, "grade": "scrap"},
		{"item_id": "Gyroscope", "qty": 1, "condition": 0.5, "grade": "poor"},
		{"item_id": "BatteryRack", "qty": 1, "condition": 1.0, "grade": "new"}])
	for i in 3:
		bus.store_crate("PO-60/%d" % (i + 1))
	await frames(2)
	var lots: Array = line.get("lots")
	check(lots.size() == 2 and str(lots[0].item) == "IonThruster" and str(lots[0].route) == "grind" and str(lots[1].route) == "refurb",
			"the survey offers the two worn lots, worst first, the scrap one for grinding: %s" % [lots])
	line.set("run_time", 0.2)
	line.set("travel_time", 0.05)

	# By hand: the gyroscope through the refurbishing machines.
	survey.call("press", "next")
	survey.call("press", "go")
	check(bus.stock_count("Gyroscope") == 0 and str(bus.line_state().stations.survey.lot.item) == "Gyroscope", "LOAD takes the lot out of the stores into the survey")
	survey.call("press", "go")
	check(str(bus.line_state().stations.survey.state) == "running", "SCAN runs the survey")
	await _wait_for(bus, "survey", "done")
	check(str(survey.call("text")).contains("REFURBISH"), "then it says refurbish: %s" % survey.call("text"))
	survey.call("press", "go")
	await frames(2)
	check(bus.line_state().stations.survey.is_empty() and str(bus.line_state().stations.straightener.state) == "waiting", "SEND ON passes it to the straightener")
	for s: String in ["straightener", "bath", "coater"]:
		var screen: Node3D = machines[s].screen
		# The bath runs long enough to catch it mid-dip on a slow runner: wait for the hoist to
		# come down rather than a fixed few frames.
		line.set("run_time", 3.0 if s == "bath" else 0.2)
		screen.call("press", "go")
		if s == "bath":
			for i in 600:
				if (machines["bath"].spreader as Node3D).position.y < RefurbLineScript.BED + 0.3 or str(bus.line_state().stations.bath.state) != "running":
					break
				await get_tree().physics_frame
			var fizz: Array = machines["bath"].fizz
			check(fizz.all(func(p: CPUParticles3D) -> bool: return p.emitting) and (machines["bath"].fizz_sound as AudioStreamPlayer3D).playing,
					"the bath bubbles, steams and simmers while it runs")
			check((machines["bath"].spreader as Node3D).position.y < RefurbLineScript.BED + 0.5, "its hoist lowers the lot in")
		await _wait_for(bus, s, "done")
		if s == "bath":
			check(not (machines["bath"].fizz[0] as CPUParticles3D).emitting, "and goes still when it is done")
		var cond := float(bus.line_state().stations[s].lot.condition)
		check(absf(cond - float(ShipBayBus.LINE_AFTER[s])) < 0.001, "the %s brings it to %d%%" % [s, roundi(cond * 100.0)])
		screen.call("press", "go")
		await frames(2)
	line.set("run_time", 0.2)
	var out := bus.line_crates()
	check(out.size() == 1 and str(out.values()[0].line) == "out" and float(out.values()[0].condition) == 1.0 and str(out.values()[0].item) == "Gyroscope",
			"the coater sends it onto an output pallet at 100%%: %s" % [out])
	var crate: String = out.keys()[0] if out.size() > 0 else ""
	var at := bus.crate_position(crate)
	check(at.distance_to(line.get("OUT_SPOTS")[0]) < 0.01 and bus.delivered_crates().has(crate), "where trolleys find it like a delivery")
	check(str(machines["coater"].screen.call("text")).contains("EMPTY"), "and the coater is free again")

	# A trolley puts it away: it goes back into the stores like new.
	bus.carry_crate(crate, "m")
	bus.store_crate(crate)
	var gyro := bus.find_stock("Gyroscope")
	check(gyro.size() == 1 and float(bus.stock_at(gyro[0]).condition) == 1.0, "put away, it's back in stock at 100%")

	# The survey's call can be overridden; the grind branch fills the dust vessel.
	survey.call("press", "go")
	survey.call("press", "go")
	await _wait_for(bus, "survey", "done")
	check(str(bus.line_state().stations.survey.lot.route) == "grind" and str(survey.call("text")).contains("GRIND"), "the scrap ion thrusters are for grinding")
	survey.call("press", "route")
	check(str(bus.line_state().stations.survey.lot.route) == "refurb" and str(survey.call("text")).contains("YOUR CALL"), "ROUTE overrides it")
	survey.call("press", "route")
	survey.call("press", "go")
	await frames(2)
	check(str(bus.line_state().stations.grinder.state) == "waiting", "SEND ON passes it to the grinder")
	machines["grinder"].screen.call("press", "go")
	var turned := false
	var sparked := false
	for i in 20:
		await frames(1)
		var rotors: Array = machines["grinder"].rotors
		turned = turned or signf((rotors[0] as Node3D).rotation.x) == -signf((rotors[1] as Node3D).rotation.x) and absf((rotors[0] as Node3D).rotation.x) > 0.0
		sparked = sparked or (machines["grinder"].sparks as CPUParticles3D).emitting
	check(turned and sparked and (machines["grinder"].grind as AudioStreamPlayer3D).playing,
			"the grinder's rotors turn into each other, sparks fly and it crunches")
	await _wait_for(bus, "grinder", "")
	check(not (machines["grinder"].sparks as CPUParticles3D).emitting and not (machines["grinder"].grind as AudioStreamPlayer3D).playing,
			"and it stops when the lot is dust")
	var want := ShipBayBus.scrap_materials("IonThruster", 2)
	var kg := bus.dust_kg()
	var mass := float(bus.storage_items().get("IonThruster", {}).get("mass", 0.0))
	check(absf(kg - mass * 2.0 * ShipBayBus.RECOVERY) < 1.0 and float(bus.line_state().dust.get("steel", 0.0)) == float(want.get("steel", -1.0)),
			"the grinder turns it to dust in the vessel: %.1f kg of %.1f" % [kg, mass * 2.0])
	var got := []
	var on_scrap := func(item: String, qty: int, mats: Dictionary) -> void: got.append([item, qty, mats])
	bus.scrap_recycled.connect(on_scrap)
	var dust_screen: Node3D = line.get("dust_screen")
	dust_screen.call("press", "send")
	await frames(2)
	var vessel := ""
	for id: String in bus.line_crates():
		if str(bus.line_crates()[id].line) == "dust":
			vessel = id
	check(vessel != "" and bus.dust_kg() == 0.0 and bus.place_for(ShipBayBus.DUST_ITEM).begins_with("Z"),
			"SEND TO STORES makes the vessel a crate for the bulk floor: %s -> %s" % [vessel, bus.place_for(ShipBayBus.DUST_ITEM)])
	var fleet: Node = yard.get("trolleys")
	var sent := ""
	for t: String in ["s", "m", "l"]:
		if str(((fleet.get("jobs") as Dictionary).get(t, {}) as Dictionary).get("do", "")) == "put_away":
			sent = t
	check(sent != "", "and calls a trolley for it: %s" % [fleet.get("jobs")])
	fleet.set("jobs", {"s": {}, "m": {}, "l": {}, "p": {}})
	bus.carry_crate(vessel, "l")
	bus.store_crate(vessel, bus.place_for(ShipBayBus.DUST_ITEM))
	check(got.size() == 1 and str(got[0][0]) == ShipBayBus.DUST_ITEM and float((got[0][2] as Dictionary).get("steel", 0.0)) > 0.0
			and not bus.crate_info(vessel).size(), "in the stores its dust is raw materials for sale: %s" % [got])
	bus.scrap_recycled.disconnect(on_scrap)

	# The line is saved with the bay.
	bus.receive_delivery("PO-61", [{"item_id": "FuelPump", "qty": 1, "condition": 0.6, "grade": "used"}])
	bus.store_crate("PO-61/1")
	bus.line_request("load", {"location": bus.find_stock("FuelPump")[0]})
	var saved := bus.save_data()
	bus.reset_data()
	check(bus.line_state().stations.survey.is_empty(), "a new game starts with the line empty")
	bus.load_data(saved, ShipBayBus.SAVE_VERSION)
	check(str(bus.line_state().stations.survey.lot.item) == "FuelPump", "and a saved one comes back with its lots")

	# AUTO runs it all: scan, send, refurbish, onto a pallet.
	machines["bath"].screen.call("press", "auto")
	check(bool(bus.line_state().auto) and str(machines["coater"].screen.call("text")).contains("AUTO ON"), "AUTO on any screen runs the line")
	var t := 0.0
	while t < 8.0 and not _has_out(bus, "FuelPump"):
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	check(_has_out(bus, "FuelPump"), "on its own the fuel pump comes out refurbished (%.1f s)" % t)
	bus.line_request("auto", {"on": false})
	yard.queue_free()
	await frames(1)
	bus.reset_data()


func _has_out(bus: ShipBayBus, item: String) -> bool:
	for c: Dictionary in bus.line_crates().values():
		if str(c.item) == item and str(c.line) == "out":
			return true
	return false


## Waits (up to 3 s) for a machine's state ("" for empty).
func _wait_for(bus: ShipBayBus, station: String, state: String) -> void:
	var t := 0.0
	while t < 3.0 and str((bus.line_state().stations[station] as Dictionary).get("state", "")) != state:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
