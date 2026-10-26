extends ModuleTest
## Ship and Bay: stock sold to another company (Business, beenster 0.3.19) leaves the yard.
## dispatch_stock sends the picking lift for the goods, a trolley takes them to the south
## truck door, and a truck in the buyer's name backs up, beams them aboard and drives off:
## stock_dispatched then. With no yard up the goods just go.
##   tools/run_tests.sh ship_bay


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	Flags.set_flag("ship_bay.trucks", false)
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	for i in 3:
		await get_tree().physics_frame
	var fleet: Node3D = yard.get("trolleys")
	for t: Node in (fleet.get("trolleys") as Dictionary).values():
		t.set("speed_scale", 5.0)
		t.set("accel", 12.0)
		t.set("turn_rate", 8.0)
		t.set("lift_speed", 6.0)
	var trucks: Node3D = yard.get("trucks")
	trucks.set("time_scale", 6.0)
	bus.receive_delivery("PO-SELL", [{"item_id": "Gyroscope", "qty": 2, "condition": 0.8, "name": "Gyroscope", "grade": "used", "mass": 120.0}])
	for i in 7200:
		await get_tree().physics_frame
		if bus.delivered_crates().is_empty() and bus.stock_count("Gyroscope") == 2:
			break
	check(bus.stock_count("Gyroscope") == 2, "two gyroscopes are in the stores to sell")
	check(not bus.dispatch_stock("S-0", "Gyroscope", 0.8, 3, "Dusty Docks"), "a sale of more than the stores hold is refused")
	var gone := []
	var on_gone := func(sale: String) -> void: gone.append(sale)
	bus.stock_dispatched.connect(on_gone)
	Flags.set_flag("ship_bay.trucks", true)
	check(bus.dispatch_stock("S-1", "Gyroscope", 0.8, 1, "Dusty Docks"), "a sale of one goes ahead")
	check(not bus.dispatch_stock("S-1", "Gyroscope", 0.8, 1, "Dusty Docks"), "the same sale can't go twice")
	var truck_seen := false
	var at_door := false
	for i in 14400:
		await get_tree().physics_frame
		for r: Dictionary in trucks.get("runs"):
			if str(r.get("sale", "")) == "S-1" and str((r["body"] as Node).get_meta("brand", "")) == "DUSTY DOCKS":
				truck_seen = true
		var sale: Dictionary = bus.sales.get("S-1", {})
		if str(sale.get("state", "")) == "ready":
			var c := bus.crate_info(str(sale.get("crate", "")))
			var by: Node3D = (fleet.get("trolleys") as Dictionary).get(str(c.get("carrier", "")))
			at_door = at_door or (by != null and Vector2(by.global_position.x, by.global_position.z).distance_to(Vector2(ShipBayBus.SALE_SPOT.x, ShipBayBus.SALE_SPOT.z)) < 4.0)
		if not gone.is_empty():
			break
	check(bus.stock_count("Gyroscope") == 1, "one gyroscope left the shelves")
	check(truck_seen, "a truck in the buyer's name came for it")
	check(at_door, "a trolley brought it to the truck door")
	check(gone == ["S-1"] and not bus.sales.has("S-1"), "stock_dispatched once the truck drove off: %s" % [gone])
	check(bus.delivered_crates().is_empty(), "nothing is left on a trolley or the floor: %s" % [bus.delivered_crates()])
	yard.queue_free()
	await frames(3)
	# No yard: the goods go at once.
	gone.clear()
	check(bus.dispatch_stock("S-2", "Gyroscope", 0.8, 1, "Elsewhere"), "with no yard up a sale still goes")
	await frames(2)
	check(gone == ["S-2"] and bus.stock_count("Gyroscope") == 0, "and is dispatched at once: %s" % [gone])
	bus.stock_dispatched.disconnect(on_gone)
	Flags.set_flag("ship_bay.trucks", true)
