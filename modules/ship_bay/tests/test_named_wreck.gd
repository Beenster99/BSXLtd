extends ModuleTest
## Ship and Bay: Settings > Debug > Ship lists every Void Salvage wreck design by name, the
## Patience training hulk too, and puts the one picked in the bay (beenster, 0.3.31: "how do i
## spawn the patience" / "please add pick a particular wreck").
##   tools/run_tests.sh ship_bay


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var ids: Array = ShipBayBus.wreck_choices().map(func(c: Array) -> String: return str(c[0]))
	check(ids.has("vsw:patience") and ids.size() == VsWreckLibrary.index().size(),
			"the list has every packed design, the Patience too (%d)" % ids.size())
	check(not VsWreckLibrary.designs().has("vsw:patience"), "the random buttons still never roll the training hulk")
	var w := ShipBayBus.named_wreck("vsw:patience", 3)
	check(str(w.get("design", "")) == "vsw:patience" and ShipBayBus.WRECK_SIZES.has(str(w.get("size", ""))) and str(w.get("name", "")).contains("Patience"),
			"a named wreck is that design: %s" % [w])
	check(ShipBayBus.named_wreck("vsw:nothing").is_empty(), "an unknown design gives no wreck")
	var panel := (load("res://modules/ship_bay/internal/ui/debug_ships_panel.gd") as GDScript).new(bus) as Control
	add_child(panel)
	await frames(2)
	var pick := panel.find_child("WreckPick", true, false) as OptionButton
	check(pick != null and pick.item_count == ids.size() and pick.get_item_text(pick.selected).contains("Patience"),
			"Settings > Debug > Ship has the wreck list, on the Patience to start")
	(panel.find_child("WreckNamed", true, false) as Button).pressed.emit()
	await frames(2)
	check(bus.ship != null and bus.ship.ship_id == ShipBayBus.WRECK_ID and str(bus.bay_wreck.get("design", "")) == "vsw:patience",
			"Put it in the bay: the Patience is the bay's ship (%s)" % [bus.ship.display_name if bus.ship else "none"])
	bus.debug_ship("restore_bay")
	panel.queue_free()
	await frames(1)
