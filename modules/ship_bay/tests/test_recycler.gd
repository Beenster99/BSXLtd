extends ModuleTest
## Ship and Bay: the recycler in Pre-assembly. Its screen lists stored goods in really bad
## condition, worst first, with the raw materials each breaks down into; RECYCLE takes the
## lot out of the stores and the bus says scrap_recycled with the materials (Business adds
## them to stock). Goods in fair condition never go in.
##   tools/run_tests.sh ship_bay


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var scene := load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene
	var yard := scene.instantiate() as Node3D
	add_child(yard)
	await frames(3)
	var rec: Node3D = yard.get("recycler")
	check(rec != null and (yard.get("ROOMS")["preassembly"]["box"] as AABB).has_point(rec.global_position + Vector3(0, 0.5, 0)),
			"a recycler stands in Pre-assembly")
	check(rec != null and rec.is_in_group("gfx_interactable"), "and lights up under the pointer (Graphics)")
	var screen: Node3D = rec.get("screen") if rec else null
	check(screen != null and str(screen.call("text")).contains("NOTHING POOR"), "with nothing poor in the stores it says so: %s" % (screen.call("text") if screen else ""))

	bus.receive_delivery("PO-50", [
		{"item_id": "IonThruster", "qty": 2, "condition": 0.15, "grade": "scrap"},
		{"item_id": "Gyroscope", "qty": 1, "condition": 0.3, "grade": "poor"},
		{"item_id": "BatteryRack", "qty": 1, "condition": 0.8, "grade": "used"}])
	for i in 3:
		bus.store_crate("PO-50/%d" % (i + 1))
	await frames(2)
	var lots: Array = rec.get("lots")
	check(lots.size() == 2 and str(lots[0].item) == "IonThruster", "it lists the two poor lots, worst first: %s" % [lots])
	var shown: String = screen.call("text")
	check(shown.contains("ION THRUSTER") and shown.contains("STEEL") and shown.contains("2 POOR LOTS"), "the screen shows the lot and what it breaks down into: %s" % shown)
	screen.call("press", "next")
	check(int(rec.get("pick")) == 1 and str(screen.call("text")).contains("GYROSCOPE"), "NEXT picks the next lot")
	screen.call("press", "prev")

	var got := []
	var on_scrap := func(item: String, qty: int, mats: Dictionary) -> void: got.append([item, qty, mats])
	bus.scrap_recycled.connect(on_scrap)
	rec.set("run_time", 0.4)
	screen.call("press", "go")
	await frames(2)
	check(bus.stock_count("IonThruster") == 0, "RECYCLE takes the lot out of the stores")
	check(got.size() == 1 and str(got[0][0]) == "IonThruster" and int(got[0][1]) == 2 and float((got[0][2] as Dictionary).get("steel", 0.0)) > 0.0,
			"and the bus says what came out: %s" % [got])
	var kg := 0.0
	for m: String in (got[0][2] as Dictionary) if got.size() > 0 else {}:
		kg += float(got[0][2][m])
	var mass := float(bus.storage_items().get("IonThruster", {}).get("mass", 0.0))
	check(absf(kg - mass * 2.0 * ShipBayBus.RECOVERY) < 1.0, "three quarters of its mass comes back: %.1f of %.1f kg" % [kg, mass * 2.0])
	check(float(rec.get("running")) > 0.0, "and it runs")
	screen.call("press", "go")
	check(got.size() == 1, "one lot at a time")
	await get_tree().create_timer(0.8).timeout
	check(float(rec.get("running")) <= 0.0 and (rec.get("lots") as Array).size() == 1, "then it's ready for the next: %d left" % (rec.get("lots") as Array).size())

	# Goods in fair condition are refused.
	var good := bus.find_stock("BatteryRack")
	if not good.is_empty():
		bus.recycle_stock(good[0])
	check(bus.stock_count("BatteryRack") == 1 and got.size() == 1, "goods in fair condition never go in")
	bus.scrap_recycled.disconnect(on_scrap)
	yard.queue_free()
	await frames(1)
	bus.reset_data()
