extends ModuleTest
## Ship and Bay: the beam rack (Business and Tools, 0.3.28). The stock beam bars BSX buys
## (Shared Components' StockBeams, 6 and 12 m) each have a home on the cantilever rack M2 in
## the plate hall, across aisle M from M1 and backed onto P1: the 12 m bars low, a lane each,
## the 6 m ones two to a lane over them. Nothing else goes on it, and a delivery of bars goes
## there on the heavy lift.
##   tools/run_tests.sh ship_bay

const Layout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")
const ItemLook := preload("res://modules/ship_bay/internal/yard/item_look.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var layout := Layout.get_layout()
	var homes: Dictionary = layout["homes"]
	var locations: Dictionary = layout["locations"]
	var unhomed: Array = []
	var misplaced: Array = []
	var taken := {}
	for id: String in StockBeams.item_ids():
		var loc: Dictionary = locations.get(homes.get(id, ""), {})
		if loc.is_empty():
			unhomed.append(id)
			continue
		if str(loc["store"]) != "beam" or str(loc["rack"]) != "M2" or not Layout.fits(Layout.size_of(id), loc["size"]):
			misplaced.append(id)
		taken[loc["id"]] = true
	check(unhomed.is_empty() and StockBeams.item_ids().size() >= 78, "every stock bar has a home: %d, none missing %s" % [StockBeams.item_ids().size(), unhomed])
	check(misplaced.is_empty() and taken.size() == StockBeams.item_ids().size(), "on the beam rack, one place a bar, with room for it: %s" % [misplaced])
	var long_top := 0
	var short_low := 99
	for id: String in StockBeams.item_ids():
		var level := int(locations[homes[id]]["level"])
		if int(StockBeams.item(id)["length_mm"]) == 12000:
			long_top = maxi(long_top, level)
		else:
			short_low = mini(short_low, level)
	check(long_top <= short_low, "the 12 m bars low, the 6 m ones over them: 12 m up to level %d, 6 m from %d" % [long_top, short_low])
	# Two places side by side never overlap.
	var overlaps: Array = []
	var places: Array = taken.keys()
	for i in places.size():
		for j in range(i + 1, places.size()):
			var a: Dictionary = locations[places[i]]
			var b: Dictionary = locations[places[j]]
			var ba := AABB(a["at"] - Vector3(a["size"].x * 0.5, 0, a["size"].z * 0.5), a["size"])
			var bb := AABB(b["at"] - Vector3(b["size"].x * 0.5, 0, b["size"].z * 0.5), b["size"])
			if ba.intersects(bb):
				overlaps.append([places[i], places[j]])
	check(overlaps.is_empty(), "no two bars' places overlap: %s" % [overlaps.slice(0, 3)])
	var r := Layout.rack("M2")
	var west := float(r["x"]) - float(r["depth"]) * 0.5
	var east := float(r["x"]) + float(r["depth"]) * 0.5
	var aisle_east := Layout.aisle_x("M") + Layout.aisle_width("M") * 0.5
	var p1_west := Layout.rack_x("P1") - float(Layout.rack("P1")["depth"]) * 0.5
	check(west >= aisle_east - 0.01 and east <= p1_west + 0.01, "M2 stands between aisle M and P1: %.2f..%.2f between %.2f and %.2f" % [west, east, aisle_east, p1_west])
	check(Layout.lift_for_rack("M2") == "h" and Layout.hall_of("M2") == "plates", "the heavy lift works it, in the plate hall")
	check(Layout.kind_of("SteelBox_100x100x5_12000") == "bulk" and Layout.items().has("TitaniumAngle_50x50x5_6000"), "bars are in the catalogue, as bulk goods")
	# A bar and a length cut off one look like themselves, wherever they are (Tools, B2).
	var bar_size := ItemLook.size_of("SteelBox_100x100x5_6000")
	var piece := "SteelBox_100x100x5_6000:len:2500:45:90"
	check(is_equal_approx(bar_size.z, 6.0) and is_equal_approx(bar_size.x, 0.1), "a bar is drawn as itself, its length along z: %s" % bar_size)
	check(Layout.beam_piece(piece) == ["SteelBox_100x100x5_6000", 2.5] and Layout.size_of(piece).is_equal_approx(Vector3(0.1, 0.1, 2.5))
			and Layout.kind_for(20.0, piece) == "bulk" and is_equal_approx(ItemLook.size_of(piece).z, 2.5) and Layout.beam_piece("HullPlate:len:9").is_empty(),
			"a cut length is a piece of its bar: %s" % [Layout.size_of(piece)])
	var piece_at := bus.place_for(piece)
	check(piece_at != "" and str(locations[piece_at]["store"]) not in ["beam", "plate"], "and is shelved off the beam rack: %s" % piece_at)
	var strays: Array = []
	for item: String in Layout.items():
		if StockBeams.is_beam(item):
			continue
		var at := bus.place_for(item)
		if at != "" and str(locations[at]["store"]) == "beam":
			strays.append(item)
	check(strays.is_empty(), "nothing but bars goes on the beam rack: %s" % [strays.slice(0, 4)])

	Flags.set_flag("ship_bay.trucks", false)
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	for i in 3:
		await get_tree().physics_frame
	var space := yard.get_world_3d().direct_space_state
	var aisle := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(Layout.aisle_x("M"), 1.0, -28.0), Vector3(Layout.aisle_x("M"), 1.0, -42.0)))
	check(aisle.is_empty() or not yard.call("is_own_body", aisle.collider), "aisle M is clear down its length: %s" % aisle.get("position", ""))
	var fleet: Node3D = yard.get("trolleys")
	for t: Node in (fleet.get("trolleys") as Dictionary).values():
		t.set("speed_scale", 5.0)
		t.set("accel", 12.0)
		t.set("turn_rate", 8.0)
		t.set("lift_speed", 6.0)
	var bars := ["SteelIBeam_200x300x10_12000", "AlloyBox_50x50x3_6000"]
	var lines: Array = []
	for id: String in bars:
		lines.append({"item_id": id, "qty": 3, "condition": 1.0, "name": StockBeams.item(id)["name"], "grade": "new",
				"mass": StockBeams.item(id)["mass"]})
	bus.receive_delivery("PO-BEAMS", lines)
	for i in 12000:
		await get_tree().physics_frame
		if bus.delivered_crates().is_empty():
			break
	for id: String in bars:
		check(bus.stock_count(id) == 3 and Array(bus.find_stock(id)) == [homes[id]], "three %s on %s: %s" % [id, homes[id], bus.find_stock(id)])
	check(bus.delivered_crates().is_empty(), "nothing left on the floor: %s" % [bus.delivered_crates().keys()])
	yard.queue_free()
	await frames(3)
	Flags.set_flag("ship_bay.trucks", true)
	bus.reset_data()
