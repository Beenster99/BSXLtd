extends ModuleTest
## Ship and Bay: each delivery comes on a hover truck in a haulage company's livery that
## drives in, backs onto a truck door, sets its crates down and drives away; until then
## its crates aren't on the goods-in floor and the trolleys leave them be.
##   tools/run_tests.sh ship_bay

const Trucks := preload("res://modules/ship_bay/internal/yard/delivery_trucks.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	check(Trucks.BRANDS.size() >= 4, "several haulage companies: %d" % Trucks.BRANDS.size())
	var names := {}
	for b: Dictionary in Trucks.BRANDS:
		names[b["name"]] = true
	check(names.size() == Trucks.BRANDS.size(), "each with its own name")
	check(Trucks.brand_for("PO-77") == Trucks.brand_for("PO-77"), "an order's company is the same on every peer")

	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	yard.call("set_walker_active", false)
	var trucks: Node3D = yard.get("trucks")
	check(trucks != null and (trucks.get("runs") as Array).is_empty(), "no truck stands at the docks until a delivery comes")
	trucks.set("time_scale", 8.0)
	# Keep the trolleys out of it: only the truck is under test here.
	var fleet: Node3D = yard.get("trolleys")
	fleet.set("auto_put_away", false)

	bus.receive_delivery("PO-77", [{"item_id": "IonThruster", "qty": 1, "condition": 1.0, "name": "Ion thruster", "grade": "new", "mass": 311.0}])
	await frames(2)
	var crate: String = bus.delivered_crates().keys()[0] if not bus.delivered_crates().is_empty() else ""
	check(crate != "" and bool(trucks.call("is_arriving", crate)), "the crate is on its truck")
	var stores: Node3D = yard.get_node("Stores")
	check(stores.get_node_or_null("Crate_" + crate.replace("/", "_")) == null, "not yet on the goods-in floor")
	var runs: Array = trucks.get("runs")
	check(runs.size() == 1, "a truck sets off")
	if runs.is_empty():
		yard.queue_free()
		return
	var truck: Node3D = runs[0]["body"]
	check(str(truck.get_meta("brand", "")) == str(Trucks.brand_for("PO-77")["name"]), "in its company's livery: %s" % truck.get_meta("brand", ""))
	var start := truck.global_position
	check(start.x < -100.0 and absf(start.z - 30.0) < 0.1, "it starts out along the road: %s" % start)
	var docked_at := Vector3.INF
	var took := INF
	for i in 6000:
		await get_tree().physics_frame
		if not bool(trucks.call("is_arriving", crate)):
			docked_at = truck.global_position
			took = float(runs[0]["age"])
			break
	var dock: Vector3 = trucks.call("_dock_xform", Trucks.DOCKS[0]).origin
	check(docked_at.distance_to(dock) < 0.2, "it backed onto the truck door before unloading: %s (dock %s)" % [docked_at, dock])
	check(truck.global_transform.basis.z.dot(Vector3.RIGHT) > 0.99, "rear to the door")
	# beenster, 23 Oct: the truck turns up within a minute; Business lands orders by 45 s.
	check(took < 16.0, "at the door %.1f s after the order lands" % took)
	await frames(2)
	check(stores.get_node_or_null("Crate_" + crate.replace("/", "_")) != null, "the crate is on the goods-in floor now")
	for i in 9000:
		await get_tree().physics_frame
		if (trucks.get("runs") as Array).is_empty():
			break
	check((trucks.get("runs") as Array).is_empty() and not is_instance_valid(truck), "and the truck drives away")

	# Two deliveries at once take both doors.
	bus.receive_delivery("PO-78", [{"item_id": "M10", "qty": 10, "condition": 1.0, "name": "M10 bolt", "grade": "new", "mass": 0.05}])
	bus.receive_delivery("PO-79", [{"item_id": "M10", "qty": 10, "condition": 1.0, "name": "M10 bolt", "grade": "new", "mass": 0.05}])
	await frames(2)
	runs = trucks.get("runs")
	check(runs.size() == 2 and int(runs[0]["dock"]) != int(runs[1]["dock"]), "two trucks, a door each")

	# With the flag off, deliveries land at once.
	Flags.set_flag("ship_bay.trucks", false)
	bus.receive_delivery("PO-80", [{"item_id": "M10", "qty": 5, "condition": 1.0, "name": "M10 bolt", "grade": "new", "mass": 0.05}])
	await frames(2)
	var landed := false
	for cid: String in bus.delivered_crates():
		if str(bus.delivered_crates()[cid].get("order_id", "")) == "PO-80":
			landed = not bool(trucks.call("is_arriving", cid))
	check(landed, "no truck with the flag off")
	Flags.set_flag("ship_bay.trucks", true)
	yard.queue_free()
	await frames(1)
	bus.reset_data()
