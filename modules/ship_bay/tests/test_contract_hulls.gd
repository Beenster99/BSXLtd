extends ModuleTest
## Ship and Bay: every hull or wreck a contract brings in arrives on a transport cradle
## (beenster, 0.3.19), so a transporter can move it about: the smallest free cradle that fits
## it (the pad's, the holding lane's, a dock's); with none free it waits for a job to close.
##   tools/run_tests.sh ship_bay


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	check(ShipBayBus.cradle_size_for(25000.0, 12.0) == "s" and ShipBayBus.cradle_size_for(120000.0, 26.0) == "m"
			and ShipBayBus.cradle_size_for(900000.0, 60.0) == "l" and ShipBayBus.cradle_size_for(20000.0, 22.0) == "m",
			"the cradle size goes by mass and length")
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	var small := {"type": "wreck", "design": ShipGenerator.design_id(11, "S", "courier"), "seed": 11, "events": "scrap",
			"name": "test wreck", "mass_kg": 20000.0}
	var length := ShipBayBus.hull_length(small)
	check(length > 2.0, "a generated hull's length comes from its file: %.1f m" % length)
	small["mass_kg"] = 20000.0 if length <= 15.0 else small["mass_kg"]
	bus.call("_on_subject_due", "J-1", small)
	await frames(3)
	var h1: Dictionary = bus.hulls.get("J-1", {})
	var want := "PadCradle" if ShipBayBus.cradle_size_for(20000.0, length) == "s" else "HoldingCradle2"
	check(str(h1.get("cradle", "")) == want, "the wreck is delivered onto the %s: %s" % [want, h1])
	var cradle: Node3D = yard.find_child(str(h1.get("cradle", "-")), true, false)
	var hull: Node3D = (yard.get("yard_ships") as Node).get("hulls").get("J-1")
	check(cradle != null and hull != null and hull.get_parent() == cradle and cradle.get("load_node") == hull,
			"its hull stands in the cradle and rides with it")
	if hull:
		var top := float(cradle.get("saddle_top"))
		var low := INF
		for s: Node in hull.find_children("*", "CollisionShape3D", true, false):
			low = minf(low, (s as Node3D).global_position.y)
		check(hull.global_position.y > cradle.global_position.y, "it sits up on the saddles, over the cradle: %.2f over %.2f (saddles +%.2f)" % [hull.global_position.y, cradle.global_position.y, top])
	bus.call("_on_subject_due", "J-2", small)
	await frames(3)
	check(str(bus.hulls.get("J-2", {}).get("cradle", "")) not in ["", str(h1.get("cradle", ""))], "a second one gets another cradle: %s" % [bus.hulls.get("J-2")])
	# Fill every cradle, then one more waits.
	var n := 3
	while bus.free_cradle_for(20000.0, length) != "":
		bus.call("_on_subject_due", "J-%d" % n, small)
		n += 1
	bus.call("_on_subject_due", "J-WAIT", small)
	check(not bus.hulls.has("J-WAIT") and bus.hull_queue.size() == 1, "with every cradle taken the next one waits")
	bus.call("_on_job_closed", "J-1")
	await frames(3)
	check(not bus.hulls.has("J-1") and str(bus.hulls.get("J-WAIT", {}).get("cradle", "")) == str(h1.get("cradle", "")),
			"a job closing takes its hull away and the waiting one takes its cradle")
	check(not is_instance_valid(hull) or hull.is_queued_for_deletion(), "the old hull is gone")
	# Saved and loaded.
	var saved := bus.snapshot()
	bus.reset_data()
	check(bus.hulls.is_empty(), "a new game has no hulls")
	bus.restore(saved)
	check(bus.hulls.has("J-WAIT") and bus.hulls.size() == n - 1, "the hulls come back with a save: %d" % bus.hulls.size())
	yard.queue_free()
	bus.reset_data()
