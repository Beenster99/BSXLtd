extends ModuleTest
## Testing aid (business.debug): Settings > Gameplay > Testing > Instant deliveries lands a
## parts order the moment it's placed, on time and whole, and turning it on lands what's
## already on its way.
##   tools/run_tests.sh business


func run_tests() -> void:
	var saved := Flags.all()
	var was: Variant = Settings.get_value(BusinessBus.SETTINGS_SECTION, BusinessBus.INSTANT_KEY)
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "multiplayer": true,
			"business": true, "business.market": true, "business.economy": true, "business.debug": true})
	Modules.load_all()
	var bus := Modules.bus("business") as BusinessBus
	check(bus != null, "business loads")
	if bus == null:
		Flags.use(saved)
		Modules.load_all()
		return
	Settings.set_value(BusinessBus.SETTINGS_SECTION, BusinessBus.INSTANT_KEY, false)
	bus.reset()
	check(Menu.settings_sections(Menu.GAMEPLAY).any(func(s: Dictionary) -> bool: return s.id == BusinessBus.TESTING_SECTION),
			"Settings > Gameplay has a Testing section")
	var toggle := bus.call("_testing_section") as CheckButton
	check(toggle != null and not toggle.button_pressed, "with an Instant deliveries switch, off")

	# Off: an order waits for its lead time.
	var listing: MarketListing = bus.get_listings()[0]
	var r := bus.place_market_order([{"listing_id": listing.id, "qty": 1}])
	check(r.is_ok() and bus.get_order(r.order_id).state == PartsOrder.State.PLACED, "off, an order is on its way")
	var arrived: Array = []
	bus.delivery_arrived.connect(func(o: PartsOrder, damaged: Array[OrderLine]) -> void: arrived.append([o.id, damaged.size()]))

	# On: what's on its way lands at once, and new orders land as they're placed.
	toggle.button_pressed = true
	check(bus.instant_deliveries() and bus.get_order(r.order_id).state == PartsOrder.State.DELIVERED,
			"switching it on lands the waiting order")
	for l: MarketListing in bus.get_listings().slice(1, 6):
		var o := bus.place_market_order([{"listing_id": l.id, "qty": 1}])
		check(o.is_ok() and bus.get_order(o.order_id).state == PartsOrder.State.DELIVERED, "%s arrives at once" % l.part)
	check(arrived.size() == 6 and arrived.all(func(a: Array) -> bool: return a[1] == 0), "all on time and undamaged: %s" % str(arrived))
	check(bus.get_stock().has(listing.part), "and in stock")

	toggle.button_pressed = false
	check(not bus.instant_deliveries(), "switching it off goes back to lead times")
	toggle.free()
	Settings.set_value(BusinessBus.SETTINGS_SECTION, BusinessBus.INSTANT_KEY, was if was != null else false)
	bus.reset()
	Flags.use(saved)
	Modules.load_all()
