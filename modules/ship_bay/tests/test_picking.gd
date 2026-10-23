extends ModuleTest
## Ship and Bay: the picking lift fetches goods off any shelf (up to the top level), hands
## them to a trolley that brings them to whoever asked, and they are taken off it; bulk
## goods the heavy lift fetches off the large and heavy racks and hands over the same way.
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
	check(trolleys.has("h") and bool(trolleys["h"].call("is_picker")) and trolleys["h"].call("carries", "bulk"), "and a heavy lift for the big parts")
	var h: Node3D = trolleys["h"]
	for at: Vector3 in [fleet.get("PARKING")["h"][0], fleet.get("HANDOFFS")["h"][0]]:
		check(bool(nav.call("is_free", at, float(h.call("clearance")))), "room for the heavy lift at %s" % at)
	check(float(h.get("spec")["lift"]) >= Layout.level_y(3, "H1"), "its carriage reaches the heavy racks' top level")
	for t: Node in trolleys.values():
		t.set("speed_scale", 5.0)
		t.set("accel", 12.0)
		t.set("turn_rate", 8.0)
		t.set("lift_speed", 6.0)

	# Stock the stores: one item on a top shelf, bolts in a bin, a reactor on a heavy rack.
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
	# Whichever hauler is free and smallest brings it.
	var courier := func(item: String) -> String:
		for id: String in ["s", "m", "l"]:
			var held := bus.trolley_cargo(id)
			if held != "" and bus.crate_info(held).get("item") == item and trolleys[id].get("status") == "HERE":
				return id
		return ""
	var by := ""
	for i in 6000:
		await get_tree().physics_frame
		high = maxf(high, float(p.get("deck_height")))
		reached = maxf(reached, float(p.get("fork_out")))
		by = courier.call("IonThruster")
		if by != "":
			break
	var m: Node3D = trolleys.get(by if by != "" else "s")
	var level := (Layout.get_layout()["locations"][top]["at"] as Vector3).y
	check(high >= level - 0.02, "the lift raised its carriage to the top shelf: %.2f of %.2f" % [high, level])
	check(reached > 0.99, "and reached into the rack")
	check(picked.values() == [top], "picked off %s: %s" % [top, picked])
	check(bus.stock_at(top).get("qty") == 1, "one thruster left on the shelf")
	var cid := bus.trolley_cargo(by)
	var gap := Vector2(m.global_position.x - me.x, m.global_position.z - me.z).length()
	var come_gap: float = float(m.call("radius")) + float(fleet.get("COME_GAP"))
	check(cid != "" and m.get("status") == "HERE" and gap < come_gap + 0.6,
			"a trolley (%s) brought it: %.1f m away (%s; lift %s)" % [by, gap, m.get("status"), p.get("status")])
	check(bus.crate_info(cid).get("item") == "IonThruster" and is_equal_approx(float(bus.crate_info(cid).get("condition", 0)), 0.9),
			"the crate is the thruster, in the condition it was stored")
	check(bus.delivered_crates().is_empty() and bus.picked_crates().size() == 1, "picked goods are not deliveries")
	fleet.call("use_trolley", by)
	check(collected == {"IonThruster": 1} and bus.trolley_cargo(by) == "", "F on the trolley takes it: %s" % [collected])
	check(fleet.get("remote_id") == "", "(and doesn't take the trolley on remote)")
	for i in 2400:
		await get_tree().physics_frame
		if p.get("status") == "PARKED":
			break
	check(p.get("status") == "PARKED", "the lift goes back to its bay: %s" % p.get("status"))

	# Bolts from the bins come on a trolley; the heavy lift takes the reactor off its rack
	# and hands it to a trolley too.
	bus.fetch_stock("M10", 40, me)
	bus.fetch_stock("Reactor", 1, me + Vector3(6, 0, 0))
	var bolts := ""
	var reactor := ""
	var h_high := 0.0
	for i in 9000:
		await get_tree().physics_frame
		h_high = maxf(h_high, float(h.get("fork_out")))
		bolts = courier.call("M10")
		reactor = courier.call("Reactor")
		if bolts != "" and reactor != "":
			break
	check(bolts != "" and bus.crate_info(bus.trolley_cargo(bolts)).get("qty") == 40, "40 bolts came on a trolley (%s, lift %s)" % [bolts, p.get("status")])
	check(reactor != "" and h_high > 0.99, "the heavy lift picked the reactor and a trolley brought it (%s, heavy lift %s)" % [reactor, h.get("status")])
	check(bus.stock_count("M10") == 60 and bus.stock_count("Reactor") == 0, "the stores are down by what left")
	var before := bus.picked_crates().size()
	bus.fetch_stock("Reactor", 1, me)
	for i in 30:
		await get_tree().physics_frame
	check(bus.picked_crates().size() == before and p.get("status") == "PARKED", "asking for what isn't in stock does nothing")

	# Store 2: goods kept only there are fetched by its own picking lift, which hands them
	# over in the courtyard outside its door.
	var p7: Node3D = trolleys.get("p7")
	check(p7 != null and bool(p7.call("is_picker")), "Store 2 has its own picking lift")
	for at: Vector3 in [fleet.get("PARKING")["p7"][0], fleet.get("HANDOFFS")["p7"][0], fleet.get("HANDOFF_TROLLEYS")["p7"][0]]:
		check(bool(nav.call("is_free", at, 0.85)), "room to stand at %s" % at)
	var spare := ""
	for loc: String in Layout.get_layout()["locations"]:
		var l: Dictionary = Layout.get_layout()["locations"][loc]
		if l["kind"] == "pallet" and str(l["rack"]).begins_with("E") and int(l["level"]) == 2:
			spare = loc
			break
	var item := ""
	for id: String in Layout.items():
		if id != "IonThruster" and Layout.kind_of(id) == "pallet":
			item = id
			break
	var mass := float(Layout.items()[item].get("mass", 50.0))
	bus.receive_delivery("PO-32", [{"item_id": item, "qty": 1, "condition": 1.0, "name": item, "grade": "new", "mass": mass}])
	bus.store_crate("PO-32/1", spare)
	check(bus.stock_at(spare).get("qty") == 1, "stocked %s on %s in Store 2" % [item, spare])
	bus.fetch_stock(item, 1, me)
	var store_2_by := ""
	for i in 9000:
		await get_tree().physics_frame
		store_2_by = courier.call(item)
		if store_2_by != "":
			break
	check(picked.get(bus.trolley_cargo(store_2_by) if store_2_by != "" else "", "") == spare,
			"Store 2's lift picked it off %s and a trolley brought it (%s, lift %s, p %s)" % [spare, store_2_by, p7.get("status"), p.get("status")])
	if store_2_by != "":
		fleet.call("use_trolley", store_2_by)

	# The console fetches what the ship is missing.
	check(fleet.has_method("fetch_for_ship"), "the console can fetch for the ship")

	bus.stock_picked.disconnect(on_pick)
	bus.crate_collected.disconnect(on_collect)
	yard.queue_free()
	await frames(1)
	bus.reset_data()
