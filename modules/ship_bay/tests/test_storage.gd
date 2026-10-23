extends ModuleTest
## Ship and Bay: the storage hall has a labelled home for every small part BSX can buy and a
## large or heavy rack place for every big one, starts
## empty on a new game, takes Business's deliveries into the Deliveries hall, puts crates
## away on their homes (or spare places), gives stock out, and saves it all.
##   tools/run_tests.sh ship_bay

const Layout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	check(bus.get("_net") != null or not Modules.is_loaded("multiplayer"), "changes to the stores go through Multiplayer")

	# The layout: a home for every small item, one item to a home, each of the right kind and
	# big enough for it; every big item fits a place on the large or heavy racks.
	var items := bus.storage_items()
	var locations := bus.storage_locations()
	check(items.size() >= 190, "the stores know every part BSX can buy: %d" % items.size())
	check(items.has("IonThruster") and items.has("M10") and items.has("tow_winch"), "parts, fasteners and ship modules")
	# Store 2, the old Material prep hall: small racks D and E (its own picking lift), large
	# racks Y and Z and heavy racks J (the heavy lift's), every home still in Stock.
	for r: String in ["D1", "D2", "E1", "E2", "Y1", "Y2", "Z1", "Z2", "J1", "J2"]:
		check(Layout.hall_of(r) == "prep" and not Layout.rack(r).is_empty(), "rack %s stands in Store 2" % r)
	check(Layout.lift_for_rack("D1") == "p7" and Layout.lift_for_rack("C2") == "p" and Layout.lift_for_rack("Y2") == "h"
			and Layout.lift_for_rack("J1") == "h", "Store 2's picking lift works D and E, the heavy lift Y, Z and J")
	var in_store_2 := 0
	var homed_there := 0
	for loc: Dictionary in locations.values():
		if Layout.hall_of(str(loc["rack"])) == "prep":
			in_store_2 += 1
			homed_there += 1 if str(loc["home"]) != "" else 0
	check(in_store_2 >= 150 and homed_there == 0, "Store 2 is all spare shelves: %d places, %d homes" % [in_store_2, homed_there])
	var look: GDScript = load("res://modules/ship_bay/internal/yard/item_look.gd")
	var stale := PackedStringArray()
	for id: String in items:
		if Layout.size_of(id).distance_to(look.call("size_of", id)) > 0.01:
			stale.append(id)
	check(stale.is_empty(), "item_sizes.json matches how each part is drawn (run make_item_sizes.gd): %s" % [stale])
	var homes := {}
	var wrong := PackedStringArray()
	var bulk := 0
	for id: String in items:
		var kind := Layout.kind_of(id)
		var loc := bus.home_location(id)
		if kind == "bulk":
			bulk += 1
			var place := bus.place_for(id)
			if loc != "" or place == "" or locations[place]["kind"] != "bulk" or not Layout.fits(Layout.size_of(id), locations[place]["size"]):
				wrong.append(id)
			continue
		if loc == "" or homes.has(loc):
			wrong.append(id)
			continue
		homes[loc] = id
		if locations[loc]["kind"] != kind or (kind == "pallet" and not Layout.fits(Layout.size_of(id), locations[loc]["size"])):
			wrong.append(id)
	check(wrong.is_empty(), "every part has its own home, or a big rack place, that it fits: %s" % [wrong])
	check(bulk > 50, "the big parts go on the large and heavy racks: %d" % bulk)
	check(bus.home_location("M10").begins_with("C2-0"), "fasteners are in the bins in C2: %s" % bus.home_location("M10"))
	check(bus.place_for("CutterDrum").begins_with("H") and bus.place_for("CutterDrum").ends_with("-1-1"), "a cutter drum goes on a heavy rack's ground level: %s" % bus.place_for("CutterDrum"))
	check(bus.place_for("DrillMotor").begins_with("W") or bus.place_for("DrillMotor").begins_with("X"), "a drill motor on a large rack: %s" % bus.place_for("DrillMotor"))
	check(locations[bus.place_for("CargoContainer")]["size"].z > 5.0, "a cargo container takes a long bay: %s" % bus.place_for("CargoContainer"))
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
	var parked: Array[RID] = []
	for t: Node in (yard.get("trolleys").get("trolleys") as Dictionary).values():
		parked.append((t as CollisionObject3D).get_rid())
	for aisle: String in ["A", "B", "C", "W", "X", "H", "D", "E", "Y", "Z", "J"]:
		var x := Layout.aisle_x(aisle)
		var ray := PhysicsRayQueryParameters3D.create(Vector3(x, 1, Layout.TRANSFER_Z), Vector3(x, 1, Layout.BACK_Z))
		ray.exclude = parked   # the lifts park at the back of their aisles
		var down := space.intersect_ray(ray)
		check(down.is_empty(), "aisle %s is clear end to end: %s" % [aisle, down.get("position", "")])
		var across := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 1, z), Vector3(x - Layout.aisle_width(aisle) * 0.5 - 1.0, 1, z)))
		check(not across.is_empty(), "a rack stands beside aisle %s" % aisle)
	var transfer := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-36, 1, Layout.TRANSFER_Z), Vector3(-2, 1, Layout.TRANSFER_Z)))
	check(transfer.is_empty(), "the transfer aisle is clear: %s" % transfer.get("position", ""))
	# Store 2 (beenster, 0.3.15): its transfer aisle, and the lane down its west wall from
	# Stock's doorway to its back cross aisle.
	transfer = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2, 1, Layout.TRANSFER_Z), Vector3(48, 1, Layout.TRANSFER_Z)))
	check(transfer.is_empty(), "Store 2's transfer aisle is clear: %s" % transfer.get("position", ""))
	var lane := PhysicsRayQueryParameters3D.create(Vector3(1.6, 1, Layout.TRANSFER_Z), Vector3(1.6, 1, Layout.BACK_Z))
	lane.exclude = parked
	check(space.intersect_ray(lane).is_empty(), "Store 2's west lane is clear end to end")
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
