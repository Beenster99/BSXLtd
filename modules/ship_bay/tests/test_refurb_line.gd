extends ModuleTest
## Ship and Bay: the two refurbishment lines in Pre-assembly and the crusher bay outside.
## A survey takes a worn lot out of the stores (or its intake bay) and says scrap or
## refurbish; a refurbished lot goes straightener -> bath -> coater onto the line's own
## trolley at 100%, which takes up to 50 to the stores; scrap goes onto the bay's red scrap zone
## for a trolley to take to the crusher, which breaks it to dust the smelter casts into
## ingots for the ingot yard (Business's raw materials). By hand each machine runs on START
## and passes on with SEND ON; AUTO runs both lines. The lines are saved with the bay.
##   tools/run_tests.sh ship_bay


const RefurbLineScript := preload("res://modules/ship_bay/internal/yard/refurb_line.gd")
const Crusher := preload("res://modules/ship_bay/internal/yard/crusher_plant.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	# These checks run the machines by hand: the bay's lots don't run on by themselves here.
	var intake_was := Flags.is_on("ship_bay.refurb_runs_intake")
	Flags.set_flag("ship_bay.refurb_runs_intake", false)
	var scene := load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene
	var yard := scene.instantiate() as Node3D
	add_child(yard)
	await frames(3)
	var lines: Dictionary = yard.get("lines")
	check(lines.keys() == ["a", "b"], "two refurbishment lines stand in the yard")
	var line: Node3D = lines["a"]
	var pre: AABB = yard.get("ROOMS")["preassembly"]["box"]
	for id: String in lines:
		var ms: Dictionary = (lines[id] as Node3D).get("machines")
		for s: String in ShipBayBus.LINE_STATIONS:
			var m: Node3D = (ms.get(s, {}) as Dictionary).get("node")
			check(m != null and pre.has_point(m.global_position + Vector3(0, 0.5, 0)) and m.is_in_group("gfx_interactable"),
					"line %s's %s stands in Pre-assembly and lights up under the pointer" % [id, s])
	var machines: Dictionary = line.get("machines")
	# Big enough for big goods.
	check(RefurbLineScript.WIDTH * RefurbLineScript.SCALE.x > 2.8 and RefurbLineScript.LENGTH * RefurbLineScript.SCALE.z > 5.0,
			"the machines take big goods: %.1f x %.1f m beds" % [RefurbLineScript.WIDTH * RefurbLineScript.SCALE.x, RefurbLineScript.LENGTH * RefurbLineScript.SCALE.z])
	var tip := HudSlots.look_hint_for({"collider": (machines["bath"].node as Node).get_node("Body")})
	check(str(tip.get("title", "")) == "Chemical Bath" and str(tip.get("text", "")).contains("bare metal"), "looking at a machine says what it does: %s" % [tip])
	var rooms := yard.get_tree().get_nodes_in_group("gfx_room")
	check(rooms.size() == 5 and (rooms[0].get_meta("gfx_box") is AABB), "the five halls are tagged for Graphics' room lighting")
	# The intake bay fits the large trolley, and trolleys have ways to the bays and outside.
	var trolley_spec: Dictionary = preload("res://modules/ship_bay/internal/yard/hover_trolley.gd").SPECS
	var deck_l: Vector2 = trolley_spec["l"]["deck"]
	check(RefurbLineScript.BAY_HALF * 2.0 > deck_l.y + 0.5 and RefurbLineScript.BAY_Z.y - RefurbLineScript.BAY_Z.x > deck_l.x + 1.5,
			"the intake bay fits the large trolley")
	var fleet: Node = yard.get("trolleys")
	var nav: Object = fleet.get("nav")
	var parked: Vector3 = fleet.get("PARKING")["l"][0]
	check(RefurbLineScript.in_spots("a").size() == 6 and Crusher.feed_spots().size() == 5,
			"each line's intake and the crusher's pad are one drop area with room for several parts")
	var goals: Array = RefurbLineScript.in_spots("a") + RefurbLineScript.in_spots("b") + [RefurbLineScript.scrap_spot("b")] + Crusher.feed_spots()
	for goal: Vector3 in goals:
		var path: PackedVector3Array = nav.call("route", parked, goal, 1.3)
		check(not path.is_empty() and path[path.size() - 1].distance_to(goal) < 1.0, "the large trolley has a way to %s: %s" % [goal, path[path.size() - 1] if not path.is_empty() else "none"])
	for id: String in ["a", "b"]:
		var from: Vector3 = fleet.get("PARKING")[id][0]
		var to: Array = fleet.call("stores_in", (fleet.get("trolleys") as Dictionary)[id])
		var path: PackedVector3Array = nav.call("route", from, to[0], 1.3)
		check(not path.is_empty() and path[path.size() - 1].distance_to(to[0]) < 1.0, "line %s's trolley has a way to the stores" % id)
	var survey: Node3D = machines["survey"].screen
	check(str(survey.call("text")).contains("Nothing"), "with nothing worn in the stores the survey says so")

	bus.receive_delivery("PO-60", [
		{"item_id": "IonThruster", "qty": 2, "condition": 0.15, "grade": "scrap"},
		{"item_id": "Gyroscope", "qty": 1, "condition": 0.5, "grade": "poor"},
		{"item_id": "BatteryRack", "qty": 1, "condition": 1.0, "grade": "new"}])
	for i in 3:
		bus.store_crate("PO-60/%d" % (i + 1))
	await frames(2)
	var lots: Array = line.get("lots")
	check(lots.size() == 2 and str(lots[0].item) == "IonThruster" and str(lots[0].route) == "grind" and str(lots[1].route) == "refurb",
			"the survey offers the two worn lots, worst first, the scrap one to scrap: %s" % [lots])
	line.set("run_time", 0.2)
	line.set("travel_time", 0.05)

	# By hand: the gyroscope through the refurbishing machines.
	survey.call("press", "next")
	survey.call("press", "go")
	check(bus.stock_count("Gyroscope") == 0 and str(_st(bus, "survey").lot.item) == "Gyroscope", "LOAD takes the lot out of the stores into the survey")
	survey.call("press", "go")
	check(str(_st(bus, "survey").state) == "running", "SCAN runs the survey")
	await _wait_for(bus, "survey", "done")
	check(str(survey.call("text")).contains("REFURBISH"), "then it says refurbish: %s" % survey.call("text"))
	survey.call("press", "go")
	await frames(2)
	check(_st(bus, "survey").is_empty() and str(_st(bus, "straightener").state) == "waiting", "SEND ON passes it to the straightener")
	for s: String in ["straightener", "bath", "coater"]:
		var screen: Node3D = machines[s].screen
		# The bath runs long enough to catch it mid-dip on a slow runner: wait for the hoist to
		# come down rather than a fixed few frames.
		line.set("run_time", 3.0 if s == "bath" else 0.2)
		screen.call("press", "go")
		if s == "bath":
			for i in 600:
				if (machines["bath"].spreader as Node3D).position.y < RefurbLineScript.BED + 0.3 or str(_st(bus, "bath").state) != "running":
					break
				await get_tree().physics_frame
			var fizz: Array = machines["bath"].fizz
			check(fizz.all(func(p: CPUParticles3D) -> bool: return p.emitting) and (machines["bath"].fizz_sound as AudioStreamPlayer3D).playing,
					"the bath bubbles, steams and simmers while it runs")
			check((machines["bath"].spreader as Node3D).position.y < RefurbLineScript.BED + 0.5, "its hoist lowers the lot in")
		await _wait_for(bus, s, "done")
		if s == "bath":
			check(not (machines["bath"].fizz[0] as CPUParticles3D).emitting, "and goes still when it is done")
		var cond := float(_st(bus, s).lot.condition)
		check(absf(cond - float(ShipBayBus.LINE_AFTER[s])) < 0.001, "the %s brings it to %d%%" % [s, roundi(cond * 100.0)])
		screen.call("press", "go")
		await frames(2)
	line.set("run_time", 0.2)
	var load := bus.trolley_load("a")
	check(load.size() == 1 and float(bus.crate_info(load[0]).condition) == 1.0 and str(bus.crate_info(load[0]).item) == "Gyroscope",
			"the coater sends it onto line A's trolley at 100%%: %s" % [load])
	check(bus.trolley_capacity("a") == 50, "which takes 50")
	check(str(machines["coater"].screen.call("text")).contains("EMPTY"), "and the coater is free again")
	var end_screen: Node3D = line.get("end_screen")
	check(str(end_screen.call("text")).contains("1 / 50"), "the end screen counts what is on it: %s" % end_screen.call("text"))
	end_screen.call("press", "send")
	await frames(2)
	check(str((fleet.get("jobs") as Dictionary)["a"].get("do", "")) == "put_away", "SEND TO STORES sends it off to the stores")
	# (The trolley's run to the stores is test_trolleys' job.) Shelved, it's back like new.
	fleet.set("jobs", {"s": {}, "m": {}, "l": {}, "p": {}, "h": {}, "a": {}, "b": {}, "p2": {}, "p3": {}, "p4": {}, "p5": {}, "p6": {}, "p7": {}})
	bus.store_crate(load[0])
	var gyro := bus.find_stock("Gyroscope")
	check(gyro.size() == 1 and float(bus.stock_at(gyro[0]).condition) == 1.0, "put away, it's back in stock at 100%")

	# The survey's call can be overridden; scrap goes onto the red scrap zone for the crusher.
	survey.call("press", "go")
	survey.call("press", "go")
	await _wait_for(bus, "survey", "done")
	check(str(_st(bus, "survey").lot.route) == "grind" and str(survey.call("text")).contains("SCRAP"), "the scrap ion thrusters are for the crusher")
	survey.call("press", "route")
	check(str(_st(bus, "survey").lot.route) == "refurb" and str(survey.call("text")).contains("YOUR CALL"), "ROUTE overrides it")
	survey.call("press", "route")
	survey.call("press", "go")
	await frames(2)
	var scrap := ""
	for id: String in bus.line_crates():
		if str(bus.line_crates()[id].line) == "scrap":
			scrap = id
	check(scrap != "" and bus.crate_position(scrap).distance_to(RefurbLineScript.scrap_spot("a")) < 0.01 and _st(bus, "survey").is_empty(),
			"SEND ON sets it on line A's scrap zone: %s" % scrap)
	await get_tree().create_timer(0.7).timeout
	var called := ""
	for t: String in ["s", "m", "l"]:
		if str(((fleet.get("jobs") as Dictionary).get(t, {}) as Dictionary).get("do", "")) == "put_away":
			called = t
	check(called != "", "and a trolley is called for it: %s" % [fleet.get("jobs")])
	check(str(((fleet.get("jobs") as Dictionary)["a"] as Dictionary).get("do", "")) == "" and str(((fleet.get("jobs") as Dictionary)["b"] as Dictionary).get("do", "")) == "",
			"(never a line's own trolley)")
	# The trolley's part: it sets the scrap down on the crusher's pad.
	fleet.set("jobs", {"s": {}, "m": {}, "l": {}, "p": {}, "h": {}, "a": {}, "b": {}, "p2": {}, "p3": {}, "p4": {}, "p5": {}, "p6": {}, "p7": {}})
	bus.carry_crate(scrap, "l")
	bus.line_request("feed", {"crate": scrap, "line": "crusher"})
	check(str(bus.crate_info(scrap).get("line", "")) == "crush" and bus.crate_position(scrap).distance_to(Crusher.feed_spots()[0]) < 0.01,
			"set down on the crusher's feed pad")
	var crusher: Node3D = yard.get("crusher")
	crusher.set("crush_time", 1.0)
	crusher.set("feed_time", 0.2)
	# Dust left from earlier lots, so this one tops a steel ingot up.
	((bus.get("_line") as Dictionary)["crusher"]["dust"] as Dictionary)["steel"] = 49.0
	var got := []
	var on_scrap := func(item: String, qty: int, mats: Dictionary) -> void: got.append([item, qty, mats])
	bus.scrap_recycled.connect(on_scrap)
	var turned := false
	var sparked := false
	var t := 0.0
	while t < 1.5 and str(bus.line_state().crusher.state) != "running":
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	check(str(bus.line_state().crusher.state) == "running" and not bus.line_crates().has(scrap), "the crusher takes it off the pad by itself")
	while t < 4.0 and str(bus.line_state().crusher.state) == "running":
		await frames(1)
		var rotors: Array = crusher.get("_rotors")
		turned = turned or signf((rotors[0] as Node3D).rotation.x) == -signf((rotors[1] as Node3D).rotation.x) and absf((rotors[0] as Node3D).rotation.x) > 0.0
		sparked = sparked or (crusher.get("_sparks") as CPUParticles3D).emitting
		t += get_process_delta_time()
	check(turned and sparked, "its rotors turn into each other and sparks fly")
	var mass := float(bus.storage_items().get("IonThruster", {}).get("mass", 0.0))
	var steel := 49.0 + float(ShipBayBus.scrap_materials("IonThruster", 2).get("steel", 0.0))
	var ingots := bus.ingots()
	check(str(bus.line_state().crusher.state) == "" and int(ingots.get("steel", 0)) == floori(steel / ShipBayBus.INGOT_KG) and int(ingots.get("steel", 0)) > 0,
			"the smelter casts its dust into ingots: %s from %.0f kg" % [ingots, mass * 2.0])
	check(absf(float(bus.line_state().crusher.dust.get("steel", 0.0)) - fmod(steel, ShipBayBus.INGOT_KG)) < 0.2, "the rest waits in the smelter for the next lot")
	check(got.size() == 1 and str(got[0][0]) == ShipBayBus.INGOT_ITEM and float((got[0][2] as Dictionary).get("steel", 0.0)) == floori(steel / ShipBayBus.INGOT_KG) * ShipBayBus.INGOT_KG,
			"cast ingots are raw materials for sale: %s" % [got])
	var labels: Dictionary = crusher.get("_zone_labels")
	check(str((labels["steel"] as Label3D).text).contains("%d INGOTS" % int(ingots.get("steel", 0))), "the ingot yard's steel zone shows them")
	bus.scrap_recycled.disconnect(on_scrap)

	# The lines are saved with the bay.
	bus.receive_delivery("PO-61", [{"item_id": "FuelPump", "qty": 1, "condition": 0.6, "grade": "used"}])
	bus.store_crate("PO-61/1")
	bus.line_request("load", {"line": "b", "location": bus.find_stock("FuelPump")[0]})
	var saved := bus.save_data()
	bus.reset_data()
	check(_st(bus, "survey", "b").is_empty() and bus.ingots().is_empty(), "a new game starts with the lines and the ingot yard empty")
	bus.load_data(saved, ShipBayBus.SAVE_VERSION)
	check(str(_st(bus, "survey", "b").lot.item) == "FuelPump" and int(bus.ingots().get("steel", 0)) == int(ingots.get("steel", 0)),
			"and a saved one comes back with its lots and ingots")

	# AUTO runs it all: scan, send, refurbish, onto line B's trolley.
	var line_b: Node3D = lines["b"]
	line_b.set("run_time", 0.2)
	line_b.set("travel_time", 0.05)
	machines["bath"].screen.call("press", "auto")
	check(bool(bus.line_state().auto) and str((line_b.get("machines") as Dictionary)["coater"].screen.call("text")).contains("AUTO ON"), "AUTO on any screen runs both lines")
	t = 0.0
	while t < 8.0 and not _on_trolley(bus, "b", "FuelPump"):
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	check(_on_trolley(bus, "b", "FuelPump"), "on its own the fuel pump comes out refurbished onto line B's trolley (%.1f s)" % t)
	t = 0.0
	while t < 3.0 and str((fleet.get("jobs") as Dictionary)["b"].get("do", "")) != "put_away":
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	check(str((fleet.get("jobs") as Dictionary)["b"].get("do", "")) == "put_away", "and with the line run dry the trolley takes it to the stores")
	bus.line_request("auto", {"on": false})
	Flags.set_flag("ship_bay.refurb_runs_intake", intake_was)
	yard.queue_free()
	await frames(1)
	bus.reset_data()


func _st(bus: ShipBayBus, station: String, line := "a") -> Dictionary:
	return bus.line_state().lines[line].stations[station]


func _on_trolley(bus: ShipBayBus, trolley: String, item: String) -> bool:
	for cid in bus.trolley_load(trolley):
		if str(bus.crate_info(cid).get("item", "")) == item:
			return true
	return false


## Waits (up to 3 s) for a machine's state ("" for empty).
func _wait_for(bus: ShipBayBus, station: String, state: String, line := "a") -> void:
	var t := 0.0
	while t < 3.0 and str(_st(bus, station, line).get("state", "")) != state:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
