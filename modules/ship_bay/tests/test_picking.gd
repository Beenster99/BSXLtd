extends ModuleTest
## Ship and Bay: the picking lift fetches goods off any shelf (up to the top level), hands
## them to a trolley that brings them to whoever asked, and they are taken off it; bulk
## goods the large trolley fetches itself.
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
	yard.call("set_walker_active", false)
	var fleet: Node3D = yard.get("trolleys")
	var trolleys: Dictionary = fleet.get("trolleys")
	check(trolleys.has("p"), "the stores have a picking lift")
	if not trolleys.has("p"):
		yard.queue_free()
		return
	var p: Node3D = trolleys["p"]
	check(bool(p.call("is_picker")) and float(p.get("spec")["lift"]) >= Layout.level_y(Layout.LEVELS),
			"its carriage reaches the top shelf")
	fleet.call("build_nav")
	var nav: RefCounted = fleet.get("nav")
	for at: Vector3 in [fleet.get("PARKING")["p"][0], fleet.get("HANDOFF")[0], fleet.get("HANDOFF_TROLLEY")[0]]:
		check(bool(nav.call("is_free", at, 0.85)), "room to stand at %s" % at)
	for t: Node in trolleys.values():
		t.set("speed_scale", 5.0)
		t.set("accel", 12.0)
		t.set("turn_rate", 8.0)
		t.set("lift_speed", 6.0)

	# Stock the stores: one item on a top shelf, bolts in a bin, a reactor on the bulk floor.
	bus.receive_delivery("PO-31", [
			{"item_id": "IonThruster", "qty": 2, "condition": 0.9, "name": "Ion thruster", "grade": "new", "mass": 311.0},
			{"item_id": "M10", "qty": 100, "condition": 1.0, "name": "M10 bolt", "grade": "new", "mass": 0.05},
			{"item_id": "Reactor", "qty": 1, "condition": 1.0, "name": "Reactor", "grade": "new", "mass": 11953.0}])
	var top := ""
	for loc: String in Layout.get_layout()["locations"]:
		var l: Dictionary = Layout.get_layout()["locations"][loc]
		if l["kind"] == "pallet" and l["home"] == "" and int(l["level"]) == Layout.LEVELS and str(l["rack"]).begins_with("B"):
			top = loc
			break
	bus.store_crate("PO-31/1", top)
	bus.store_crate("PO-31/2")
	bus.store_crate("PO-31/3")
	check(bus.stock_at(top).get("qty") == 2 and bus.stock_count("M10") == 100 and bus.stock_count("Reactor") == 1,
			"stocked: thrusters on %s, bolts, a reactor" % top)

	var picked := {}
	var collected := {}
	var on_pick := func(crate_id: String, loc: String) -> void: picked[crate_id] = loc
	var on_collect := func(crate_id: String, item: String, qty: int) -> void: collected[item] = qty
	bus.stock_picked.connect(on_pick)
	bus.crate_collected.connect(on_collect)

	# A thruster off the top shelf, brought out to someone in the courtyard.
	var me := Vector3(-6, 0, 14)
	bus.fetch_stock("IonThruster", 1, me)
	var high := 0.0
	var reached := 0.0
	var m: Node3D = trolleys["m"]
	for i in 6000:
		await get_tree().physics_frame
		high = maxf(high, float(p.get("deck_height")))
		reached = maxf(reached, float(p.get("fork_out")))
		if m.get("status") == "HERE" and bus.trolley_cargo("m") != "":
			break
	var level := (Layout.get_layout()["locations"][top]["at"] as Vector3).y
	check(high >= level - 0.02, "the lift raised its carriage to the top shelf: %.2f of %.2f" % [high, level])
	check(reached > 0.99, "and reached into the rack")
	check(picked.values() == [top], "picked off %s: %s" % [top, picked])
	check(bus.stock_at(top).get("qty") == 1, "one thruster left on the shelf")
	var cid := bus.trolley_cargo("m")
	var gap := Vector2(m.global_position.x - me.x, m.global_position.z - me.z).length()
	check(cid != "" and m.get("status") == "HERE" and gap < 2.6,
			"the medium trolley brought it: %.1f m away (%s; lift %s)" % [gap, m.get("status"), p.get("status")])
	check(bus.crate_info(cid).get("item") == "IonThruster" and is_equal_approx(float(bus.crate_info(cid).get("condition", 0)), 0.9),
			"the crate is the thruster, in the condition it was stored")
	check(bus.delivered_crates().is_empty() and bus.picked_crates().size() == 1, "picked goods are not deliveries")
	fleet.call("use_trolley", "m")
	check(collected == {"IonThruster": 1} and bus.trolley_cargo("m") == "", "F on the trolley takes it: %s" % [collected])
	check(fleet.get("remote_id") == "", "(and doesn't take the trolley on remote)")
	for i in 2400:
		await get_tree().physics_frame
		if p.get("status") == "PARKED":
			break
	check(p.get("status") == "PARKED", "the lift goes back to its bay: %s" % p.get("status"))

	# Bolts from the bins come on the small trolley; a reactor on the large one.
	bus.fetch_stock("M10", 40, me)
	bus.fetch_stock("Reactor", 1, me + Vector3(6, 0, 0))
	var s: Node3D = trolleys["s"]
	var l: Node3D = trolleys["l"]
	for i in 8000:
		await get_tree().physics_frame
		if s.get("status") == "HERE" and l.get("status") == "HERE" and bus.trolley_cargo("s") != "" and bus.trolley_cargo("l") != "":
			break
	check(bus.crate_info(bus.trolley_cargo("s")).get("qty") == 40, "40 bolts came on the small trolley (%s, lift %s)" % [s.get("status"), p.get("status")])
	check(bus.crate_info(bus.trolley_cargo("l")).get("item") == "Reactor", "the large trolley fetched the reactor itself (%s)" % l.get("status"))
	check(bus.stock_count("M10") == 60 and bus.stock_count("Reactor") == 0, "the stores are down by what left")
	var before := bus.picked_crates().size()
	bus.fetch_stock("Reactor", 1, me)
	for i in 30:
		await get_tree().physics_frame
	check(bus.picked_crates().size() == before and p.get("status") == "PARKED", "asking for what isn't in stock does nothing")

	# The console fetches what the ship is missing.
	check(fleet.has_method("fetch_for_ship"), "the console can fetch for the ship")

	bus.stock_picked.disconnect(on_pick)
	bus.crate_collected.disconnect(on_collect)
	yard.queue_free()
	await frames(1)
	bus.reset_data()
