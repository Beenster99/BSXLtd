extends ModuleTest
## Ship and Bay: the plate hall (beenster, 0.3.23 and 0.3.24). West of Stock, through a door
## off its transfer aisle: five open plate racks round the plasma cutting bed's place, one a
## material (steel P1, alloy P2, titanium Q1, glass R1, crystal R2), a bay a size and a level
## a thickness, a home for every stock plate (Shared Components' StockPlates) and nothing
## else on them. Delivered plates go there on the heavy lift; crushed plates and
## sheet parts give back their own material.
##   tools/run_tests.sh ship_bay

const Layout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")
const Yard := preload("res://modules/ship_bay/internal/yard/shipyard.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var layout := Layout.get_layout()
	var homes: Dictionary = layout["homes"]
	var locations: Dictionary = layout["locations"]
	var unhomed: Array = []
	var misplaced: Array = []
	for pid: String in StockPlates.item_ids():
		var loc: Dictionary = locations.get(homes.get(pid, ""), {})
		if loc.is_empty():
			unhomed.append(pid)
			continue
		var kind := str(StockPlates.item(pid)["kind"])
		var rack := str(loc["rack"])
		if str(loc["store"]) != "plate" or str(Layout.rack(rack)["plate_kind"]) != kind or not Layout.fits(Layout.size_of(pid), loc["size"]):
			misplaced.append(pid)
	check(unhomed.is_empty() and StockPlates.item_ids().size() > 80, "every stock plate has a home: %d, none missing %s" % [StockPlates.item_ids().size(), unhomed])
	check(misplaced.is_empty(), "on its own material's rack, with room for it: %s" % [misplaced])
	var materials := {}
	var bays_ok := true
	for pid: String in StockPlates.item_ids():
		var loc: Dictionary = locations[homes[pid]]
		var p := StockPlates.item(pid)
		materials[str(loc["rack"])] = (materials.get(str(loc["rack"]), {}) as Dictionary).merged({str(p["material"]): true})
		for other: String in StockPlates.item_ids("", str(p["kind"])):
			var same_size := other.left(other.rfind("_")) == pid.left(pid.rfind("_"))
			if same_size != (int(locations[homes[other]]["bay"]) == int(loc["bay"])):
				bays_ok = false
	check(materials.size() == 5 and materials.values().all(func(m: Dictionary) -> bool: return m.size() == 1),
			"one rack a material: %s" % [materials])
	check(bays_ok, "a bay holds one size, every thickness of it")
	var steel := homes["SteelPlate_3000x1500_12"] as String
	var thin := homes["SteelPlate_3000x1500_2"] as String
	check(int(locations[steel]["level"]) < int(locations[thin]["level"]), "the thick ones low: %s under %s" % [steel, thin])
	check(Layout.lift_for_rack("Q1") == "h" and Layout.hall_of("R2") == "plates" and Layout.hall_of("Q1") == "plates" and Layout.hall_of("H1") == "stock",
			"the heavy lift works the plate racks in the plate hall")
	check(Layout.kind_of("GlassPlate_2000x1000_10") == "bulk" and Layout.items().has("TitaniumPlate_1000x1000_5"), "plates are in the catalogue, as bulk goods")
	check(bus.place_for("SteelPlate_2500x1250_5") == homes["SteelPlate_2500x1250_5"], "a delivered plate goes to its home")
	var strays: Array = []
	for item: String in Layout.items():
		if StockPlates.is_plate(item):
			continue
		var at := bus.place_for(item)
		if at != "" and str(locations[at]["store"]) == "plate":
			strays.append(item)
	check(strays.is_empty(), "nothing but plates goes on the plate racks: %s" % [strays])
	var bed_at := bus.cutting_bed_spot().origin
	var half := ShipBayBus.CUTTING_BED_ROOM * 0.5
	var q_edge := Layout.aisle_x("Q") + Layout.aisle_width("Q") * 0.5
	var r_back := Layout.rack_x("R1") - float(Layout.rack("R1")["depth"]) * 0.5
	check(bed_at.x - half.x >= q_edge and bed_at.x + half.x <= r_back and bed_at.z + half.z <= Layout.RACK_Z0 + 1.0,
			"the cutting bed's room stays out of aisle Q, off R1 and clear of the way in: x %.2f..%.2f between %.2f and %.2f" % [bed_at.x - half.x, bed_at.x + half.x, q_edge, r_back])
	check(Yard.room_at(Vector3(-67, 1, -33)) == "plates" and Yard.room_at(bus.cutting_bed_spot().origin + Vector3.UP) == "plates",
			"the plate hall is a room, the cutting bed's spot in it")
	var crushed := ShipBayBus.scrap_materials("TitaniumPlate_2000x1000_8", 2)
	check(crushed.keys() == ["titanium"] and is_equal_approx(float(crushed["titanium"]),
			snappedf(float(StockPlates.item("TitaniumPlate_2000x1000_8")["mass"]) * 2 * StockPlates.RECOVERY, 0.1)),
			"a crushed plate gives back its own metal: %s" % [crushed])
	check(ShipBayBus.scrap_materials("HullPlate", 1, 200.0, "alloy") == {"alloy": 150.0}, "a hull plate off a wreck its own material")
	check(ShipBayBus.scrap_materials("WindowPane", 1, 40.0, "steel") == {"glass": 30.0}, "a window pane glass")

	Flags.set_flag("ship_bay.trucks", false)
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	for i in 3:
		await get_tree().physics_frame
	var space := yard.get_world_3d().direct_space_state
	var door := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-46, 1, Yard.PLATE_DOOR.x), Vector3(-54, 1, Yard.PLATE_DOOR.x)))
	check(door.is_empty() or not yard.call("is_own_body", door.collider), "Stock's door into the plate hall is open: %s" % door.get("position", ""))
	var high := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-46, 9.5, Yard.PLATE_DOOR.x), Vector3(-54, 9.5, Yard.PLATE_DOOR.x)))
	check(high.is_empty(), "tall enough for the heavy lift's mast: %s" % high.get("position", ""))
	for ray: Array in [[Vector3(-80, 1, -33), Vector3(-90, 1, -33), "west"], [Vector3(-67, 1, -40), Vector3(-67, 1, -50), "north"],
			[Vector3(-67, 1, -23), Vector3(-67, 1, -17), "south"]]:
		check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(ray[0], ray[1])).is_empty(), "the plate hall has its %s wall" % ray[2])
	var bed := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = ShipBayBus.CUTTING_BED_ROOM - Vector3(0.1, 0.2, 0.1)
	bed.shape = box
	bed.transform = bus.cutting_bed_spot() * Transform3D(Basis.IDENTITY, Vector3(0, ShipBayBus.CUTTING_BED_ROOM.y * 0.5 + 0.1, 0))
	var hits := space.intersect_shape(bed).filter(func(hit: Dictionary) -> bool: return yard.call("is_own_body", hit.collider))
	check(hits.is_empty(), "the cutting bed's room is clear: %d in the way" % hits.size())

	# A delivery of plates: the heavy lift takes them through the door onto their homes.
	var fleet: Node3D = yard.get("trolleys")
	for t: Node in (fleet.get("trolleys") as Dictionary).values():
		t.set("speed_scale", 5.0)
		t.set("accel", 12.0)
		t.set("turn_rate", 8.0)
		t.set("lift_speed", 6.0)
	var lines: Array = []
	for pid: String in ["SteelPlate_2500x1250_5", "GlassPlate_1000x1000_6"]:
		lines.append({"item_id": pid, "qty": 4, "condition": 1.0, "name": StockPlates.item(pid)["name"], "grade": "new",
				"mass": StockPlates.item(pid)["mass"]})
	bus.receive_delivery("PO-PLATES", lines)
	for i in 12000:
		await get_tree().physics_frame
		if bus.delivered_crates().is_empty():
			break
	for pid: String in ["SteelPlate_2500x1250_5", "GlassPlate_1000x1000_6"]:
		check(bus.stock_count(pid) == 4 and Array(bus.find_stock(pid)) == [homes[pid]], "four %s on %s: %s" % [pid, homes[pid], bus.find_stock(pid)])
	check(bus.delivered_crates().is_empty(), "nothing left on the floor: %s" % [bus.delivered_crates().keys()])
	yard.queue_free()
	await frames(3)
	Flags.set_flag("ship_bay.trucks", true)
	bus.reset_data()
