extends ModuleTest
## Ship and Bay: Settings > Debug > Ship's "Random wreck in the bay" (beenster, 26 Oct) rolls
## a small generated wreck and builds it on the bay's cradle in place of the Kestrel, the same
## on every machine; "Bring the Kestrel back" puts things back.
##   tools/run_tests.sh ship_bay

const DebugPanel := preload("res://modules/ship_bay/internal/ui/debug_ships_panel.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var a := ShipBayBus.random_wreck(42)
	check(a == ShipBayBus.random_wreck(42) and ShipGenerator.is_generated(str(a.design)), "the same roll gives the same wreck: %s" % [a])
	check(not (a.events as Array).is_empty() and (a.events as Array).size() <= 3, "with one to three wreck events: %s" % [a.events])
	var was := Flags.is_on("ship_bay.bay_cradle")
	Flags.set_flag("ship_bay.bay_cradle", true)
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	var bay: Node3D = yard.get("bay")
	var panel := DebugPanel.new(bus)
	add_child(panel)
	check(bus.ship != null and bay.get("ship_root") != null, "the Kestrel is in the bay")
	(panel.get_node("Wreck") as Button).pressed.emit()
	await frames(2)
	var wreck: Node3D = bay.get("wreck")
	check(bus.ship == null and bay.get("ship_root") == null, "the Kestrel goes")
	check(wreck != null and wreck.get_child_count() > 10, "a wreck is built in its place: %d pieces" % (wreck.get_child_count() if wreck else 0))
	var c: Node3D = bay.get("cradle")
	check(c != null and c.get("load_node") == wreck, "on the bay's cradle, so the dolly can move it")
	check((bus.snapshot().get("bay_wreck", {}) as Dictionary) == bus.bay_wreck and not bus.bay_wreck.is_empty(), "it goes in the save")
	check(str((panel.get_node("Wreck") as Button).text) == "Another random wreck", "the button offers another")
	var first := bus.bay_wreck.duplicate(true)
	(panel.get_node("Wreck") as Button).pressed.emit()
	await frames(2)
	check(bus.bay_wreck != first and is_instance_valid(bay.get("wreck")) and bay.get("wreck") != wreck, "another press rolls another")
	# A late joiner builds the same one.
	var snap := bus.snapshot()
	bus.restore({})
	await frames(1)
	check(bay.get("wreck") == null, "restored empty: no wreck")
	bus.restore(snap)
	await frames(1)
	check(bay.get("wreck") != null and (bay.get("wreck") as Node).get_meta("wreck") == snap.bay_wreck, "restored: the same wreck again")
	(panel.get_node("Kestrel") as Button).pressed.emit()
	await frames(2)
	check(bus.ship != null and bay.get("wreck") == null and bus.bay_wreck.is_empty(), "Bring the Kestrel back: the wreck goes, the Kestrel returns")
	panel.queue_free()
	yard.queue_free()
	await frames(2)
	Flags.set_flag("ship_bay.bay_cradle", was)
	bus.reset_data()
