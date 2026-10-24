extends ModuleTest
## Ship and Bay: Settings > Debug > Ship (beenster, 24 Oct) stands a Manta on Dock 2 and takes
## the Kestrel out of the bay and back; both are saved and sent to players who join.
##   tools/run_tests.sh ship_bay

const ShipsPanel := preload("res://modules/ship_bay/internal/ui/debug_ships_panel.gd")
const YardShips := preload("res://modules/ship_bay/internal/yard/yard_ships.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	check(Menu.settings_sections(Menu.DEBUG).any(func(c: Variant) -> bool: return c.id == ShipBayBus.DEBUG_SECTION),
			"the Debug page has a Ship section")
	var view := (load("res://modules/ship_bay/internal/bay/bay.tscn") as PackedScene).instantiate() as Node3D
	add_child(view)
	await frames(2)
	check(bus.ship != null and view.get("model") != null, "the Kestrel starts in the bay")
	var panel := ShipsPanel.new(bus)
	add_child(panel)
	var manta_button := panel.get_node("Manta") as Button
	var kestrel_button := panel.get_node("Kestrel") as Button
	check(manta_button.text == "Spawn a Manta on Dock 2" and kestrel_button.text == "Remove the Kestrel", "the buttons say what they do")

	var yard := YardShips.new()
	add_child(yard)
	manta_button.pressed.emit()
	await frames(1)
	check(bus.yard_ships == PackedStringArray(["manta"]), "the Manta is on the apron")
	var manta: RigidBody3D = yard.ships.get("manta")
	check(manta != null and manta.freeze, "and stands there, frozen")
	if manta:
		var importer: VsShipImport = manta.get_meta("importer")
		check(importer.errors.is_empty() and importer.parts_by_path.size() > 1000,
				"built whole from its file: %d parts" % importer.parts_by_path.size())
		check(manta.find_children("*", "CollisionShape3D", true, false).size() > 100, "solid to walk in")
		check(absf(manta.position.x - YardShips.PLACES["manta"].x) < 0.01 and manta.position.y > 1.0, "on Dock 2, standing on its lowest point")
	check(manta_button.text == "Remove the Manta", "its button now takes it away")

	kestrel_button.pressed.emit()
	await frames(1)
	check(bus.ship == null and bus.bay_cleared and view.get("model") == null and view.get("access") == null,
			"the Kestrel, its lift and power unit leave the bay")
	check(kestrel_button.text == "Bring the Kestrel back", "and its button brings it back")
	var saved := bus.snapshot()
	check(saved.get("yard_ships") == ["manta"] and bool(saved.get("bay_cleared")) and not saved.has("ship_id"), "both are saved: %s" % [saved.keys()])
	# A bay opened again stays empty.
	var again := (load("res://modules/ship_bay/internal/bay/bay.tscn") as PackedScene).instantiate() as Node3D
	add_child(again)
	await frames(1)
	check(bus.ship == null and again.get("model") == null, "a bay opened now stays empty")
	again.queue_free()

	kestrel_button.pressed.emit()
	await frames(1)
	check(bus.ship != null and bus.ship.ship_id == "vs_kestrel" and view.get("model") != null and view.get("access") != null,
			"the Kestrel comes back with its lift and power unit")
	manta_button.pressed.emit()
	await frames(2)
	check(bus.yard_ships.is_empty() and yard.ships.is_empty(), "and the Manta goes")
	bus.restore(saved)
	await frames(1)
	check(bus.ship == null and yard.ships.has("manta"), "a load puts both back as they were saved")
	bus.debug_ship("restore_bay")
	bus.debug_ship("remove", "manta")
	bus.debug_ship("spawn", "kestrel_wreck")
	check(bus.yard_ships.is_empty(), "only known designs stand on the apron")
	panel.queue_free()
	yard.queue_free()
	view.queue_free()
	await frames(1)
	bus.unload_ship()
