extends ModuleTest
## Ship and Bay: the storage hall has a labelled home for every part BSX can buy, starts
## empty on a new game, takes Business's deliveries into the Deliveries hall, puts crates
## away on their homes (or spare places), gives stock out, and saves it all.
##   tools/run_tests.sh ship_bay

const Layout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	check(bus.get("_net") != null or not Modules.is_loaded("multiplayer"), "changes to the stores go through Multiplayer")

	# The layout: a home for every item, one item to a home, each of the right kind.
	var items := bus.storage_items()
	var locations := bus.storage_locations()
	check(items.size() >= 190, "the stores know every part BSX can buy: %d" % items.size())
	check(items.has("IonThruster") and items.has("M10") and items.has("tow_winch"), "parts, fasteners and ship modules")
	var homes := {}
	var wrong := PackedStringArray()
	for id: String in items:
		var loc := bus.home_location(id)
		if loc == "" or homes.has(loc):
			wrong.append(id)
			continue
		homes[loc] = id
		if locations[loc]["kind"] != Layout.kind_for(float(items[id]["mass"])):
			wrong.append(id)
	check(wrong.is_empty(), "every part has its own home of its kind: %s" % [wrong])
	check(bus.home_location("M10").begins_with("D2-0"), "fasteners are in the bins in D2: %s" % bus.home_location("M10"))
	check(bus.home_location("CutterDrum").begins_with("Z-"), "a cutter drum goes on the bulk floor")
	var spare := 0
	for loc: String in locations:
		if locations[loc]["home"] == "":
			spare += 1
	check(spare > 50, "spare places for anything new: %d" % spare)
	# Inside a bay the heavier parts are lower.
	var upside_down := PackedStringArray()
	for loc: String in locations:
		var l: Dictionary = locations[loc]
		if l["kind"] != "pallet" or l["home"] == "":
			continue
		var above := "%s-%02d-%d-%d" % [l["rack"], l["bay"], int(l["level"]) + 1, l["pos"]]
		if locations.has(above) and locations[above]["home"] != "" \
				and float(items[locations[above]["home"]]["mass"]) > float(items[l["home"]]["mass"]):
			upside_down.append(loc)
	check(upside_down.is_empty(), "heavy parts low, light ones high: %s" % [upside_down])

	# A new game: nothing in the stores.
	check(bus.delivered_crates().is_empty() and bus.stock_count("IonThruster") == 0, "a new game's stores are empty")

	# A delivery lands as a crate per line on the goods-in spots.
	var landed: Array = []
	var on_land := func(order_id: String, crate_ids: PackedStringArray) -> void: landed.append([order_id, crate_ids])
	bus.delivery_landed.connect(on_land)
	bus.receive_delivery("PO-7", [
			{"item_id": "IonThruster", "qty": 2, "condition": 1.0, "name": "Ion thruster", "grade": "new", "mass": 311.0},
			{"item_id": "M10", "qty": 200, "condition": 1.0, "name": "M10 bolt", "grade": "new", "mass": 0.05},
			{"item_id": "MysteryWidget", "qty": 1, "condition": 0.7, "name": "Mystery widget", "grade": "used", "mass": 120.0}])
	check(landed.size() == 1 and (landed[0][1] as PackedStringArray).size() == 3, "delivery_landed with three crates: %s" % [landed])
	var crates := bus.delivered_crates()
	check(crates.size() == 3 and crates.has("PO-7/1"), "three crates wait in Deliveries: %s" % [crates.keys()])
	var hall: AABB = bus.shipyard_rooms()["deliveries"]["box"]
	var a := bus.crate_position("PO-7/1")
	var b := bus.crate_position("PO-7/2")
	check(hall.has_point(a + Vector3(0, 0.5, 0)) and a.distance_to(b) > 1.5, "each on its own spot in the hall: %s %s" % [a, b])
	check(bus.place_for("IonThruster") == bus.home_location("IonThruster"), "a crate of ion thrusters is bound for their home")

	# Put away: goods go on their home; an unknown part goes to a spare place.
	var stored: Array = []
	var on_store := func(crate_id: String, loc: String) -> void: stored.append([crate_id, loc])
	bus.crate_stored.connect(on_store)
	bus.store_crate("PO-7/1")
	bus.store_crate("PO-7/2")
	bus.store_crate("PO-7/3")
	check(stored.size() == 3, "all three put away: %s" % [stored])
	var home := bus.home_location("IonThruster")
	check(bus.stock_at(home).get("qty") == 2, "two ion thrusters on %s" % home)
	check(bus.stock_count("M10") == 200, "200 M10 bolts in their bin")
	var odd := bus.find_stock("MysteryWidget")
	check(odd.size() == 1 and locations[odd[0]]["home"] == "" and locations[odd[0]]["kind"] == "pallet",
			"an unknown part goes on a spare pallet place: %s" % [odd])
	check(bus.delivered_crates().is_empty(), "the hall is clear")

	# More of the same joins what is there; stock comes out again.
	bus.receive_delivery("PO-8", [{"item_id": "IonThruster", "qty": 1, "condition": 0.7, "grade": "used"}])
	bus.store_crate("PO-8/1")
	check(bus.stock_at(home).get("qty") == 3, "a third thruster joins them")
	check(absf(float(bus.stock_at(home)["condition"]) - 0.9) < 0.001, "condition is the average: %s" % bus.stock_at(home)["condition"])
	bus.take_stock("IonThruster", 2)
	check(bus.stock_count("IonThruster") == 1, "two taken out to fit")
	bus.take_stock("IonThruster", 5)
	check(bus.stock_count("IonThruster") == 1, "can't take more than there is")

	# Saved with the bay, and a new game empties it.
	bus.receive_delivery("PO-9", [{"item_id": "Reactor", "qty": 1, "mass": 11953.0}])
	var saved := JSON.parse_string(JSON.stringify(bus.save_data())) as Dictionary
	bus.reset_data()
	check(bus.stock_count("M10") == 0 and bus.delivered_crates().is_empty(), "reset_data empties the stores")
	bus.load_data(saved, ShipBayBus.SAVE_VERSION)
	check(bus.stock_count("M10") == 200 and bus.stock_count("IonThruster") == 1, "a load puts the stock back")
	check(bus.delivered_crates().has("PO-9/1"), "and the crate still waiting in Deliveries")

	# In the yard: the racks stand, the aisles are clear, the goods and crates are drawn.
	var scene := load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene
	var yard := scene.instantiate() as Node3D
	add_child(yard)
	await frames(3)
	for i in 2:
		await get_tree().physics_frame
	var space := yard.get_world_3d().direct_space_state
	var z := Layout.bay_z(2)
	for aisle: String in ["A", "B", "C", "D"]:
		var x := Layout.aisle_x(aisle)
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 1, Layout.TRANSFER_Z), Vector3(x, 1, Layout.BACK_Z)))
		check(down.is_empty(), "aisle %s is clear end to end: %s" % [aisle, down.get("position", "")])
		var across := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 1, z), Vector3(x - 3.0, 1, z)))
		check(not across.is_empty(), "a rack stands beside aisle %s" % aisle)
	var transfer := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-36, 1, Layout.TRANSFER_Z), Vector3(-2, 1, Layout.TRANSFER_Z)))
	check(transfer.is_empty(), "the transfer aisle is clear: %s" % transfer.get("position", ""))
	var stores: Node3D = yard.get_node("Stores")
	check(stores.get_node_or_null("Crate_PO-9_1") != null, "the waiting crate is labelled in the hall")
	check(stores.get_child_count() >= 4, "goods drawn on the shelves: %d" % stores.get_child_count())
	var labels: Node3D = yard.get_node("Labels")
	check(labels.get_child_count() >= locations.size(), "every place is labelled: %d" % labels.get_child_count())
	bus.store_crate("PO-9/1")
	check(stores.get_node_or_null("Crate_PO-9_1") == null, "a crate put away leaves the hall")
	yard.queue_free()
	await frames(1)
	bus.delivery_landed.disconnect(on_land)
	bus.crate_stored.disconnect(on_store)
	bus.reset_data()
