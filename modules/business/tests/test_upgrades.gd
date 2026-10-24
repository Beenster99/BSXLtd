extends ModuleTest
## Component Upgrades U1 (beenster, 24 Oct): Corvane Field Works sells BSX's attractor coil
## add-ons (quantum cores Q1-Q3, field emitter arrays F1-F3 and the control board, keyed on
## Shared Components' upgrade rules ids) behind business.upgrades, and Business prices an upgraded coil at tiers 1 to 3.
##   tools/run_tests.sh business


func run_tests() -> void:
	var saved := Flags.all()
	var flags := {"core": true, "ui": true, "contracts": true, "ship_bay": true,
			"business": true, "business.market": true}
	Flags.use(flags)
	Modules.load_all()
	var bus := Modules.bus("business") as BusinessBus
	check(bus != null, "business loads")
	if bus == null:
		Flags.use(saved)
		Modules.load_all()
		return
	bus.reset()
	var ids := bus.get_suppliers().map(func(s): return s.id)
	check(not ids.has(BusinessBus.UPGRADE_SUPPLIER), "the add-on supplier waits on its flag")

	flags["business.upgrades"] = true
	Flags.use(flags)
	bus.reset()
	ids = bus.get_suppliers().map(func(s): return s.id)
	check(ids.has(BusinessBus.UPGRADE_SUPPLIER), "Corvane Field Works trades with the flag on")

	# The add-ons: on the market under "upgrades", named, orderable like any part.
	check(bus.upgrade_units() == PackedStringArray(["attractor_coil"]), "U1 upgrades the attractor coil: %s" % str(bus.upgrade_units()))
	check(bus.upgrade_tiers("attractor_coil") == [1, 2, 3], "in three tiers")
	var listed := bus.get_listings("upgrades").map(func(l): return l.part)
	for part in ["quantum_core_1", "quantum_core_2", "quantum_core_3", "field_emitter_1", "field_emitter_2",
			"field_emitter_3", "control_board"]:
		check(listed.has(part), "%s is on sale" % part)
		check(bus.part_name(part) != part, "%s has a name: %s" % [part, bus.part_name(part)])
	check(bus.get_listings("upgrades").all(func(l): return l.supplier_id == BusinessBus.UPGRADE_SUPPLIER),
			"only from BSX's own supplier")
	var t1 := bus.upgrade_parts("attractor_coil", 1)
	var t3 := bus.upgrade_parts("attractor_coil", 3)
	check(t1.has("quantum_core_1") and t1.has("field_emitter_1") and t1.has("control_board"), "tier 1: Q1, F1 and a board")
	check(t3.size() == 3 and t3.has("quantum_core_3") and t3.has("field_emitter_3"), "tier 3: Q3, F3 and a board: %s" % str(t3))
	var lines: Array[OrderLine] = []
	for part: String in t1:
		lines.append(OrderLine.new(part, int(t1[part])))
	var q := bus.quote(BusinessBus.UPGRADE_SUPPLIER, lines)
	check(q.ok and q.cost > 0, "the tier 1 kit can be ordered: %d CR" % q.cost)

	# Prices: each tier dearer; a good pass sells for more than a scraped one; a fail for 0.
	var p := bus.upgrade_tiers("attractor_coil").map(func(t): return bus.upgrade_price("attractor_coil", t))
	check(p[0] > 0 and p[0] < p[1] and p[1] < p[2], "tiers 1-3 cost more each: %s" % str(p))
	var a := bus.upgrade_quote("attractor_coil", 1)
	check(a.ok and a.price >= a.parts and a.labour == a.joints * 150, "parts, markup and labour per joint: %s" % str(a))
	check(bus.upgrade_price("attractor_coil", 2, 1.0) < bus.upgrade_price("attractor_coil", 2, 1.05), "scraping a pass sells for less")
	check(bus.upgrade_price("attractor_coil", 2, 1.2) > bus.upgrade_price("attractor_coil", 2, 1.05), "beating the rating sells for more")
	check(bus.upgrade_price("attractor_coil", 2, 1.5) == bus.upgrade_price("attractor_coil", 2, 1.2), "up to a cap")
	check(bus.upgrade_price("attractor_coil", 2, 0.9) == 0 and not bus.upgrade_quote("attractor_coil", 2, 0.9).ok, "a failed test sells for nothing")
	check(bus.upgrade_price("attractor_coil", 1, 1.05, true) > p[0], "a stock unit adds the coil's own value")
	check(not bus.upgrade_quote("main_engine", 1).ok and bus.upgrade_tiers("main_engine").is_empty(), "units not in U1 aren't priced")

	Flags.use(saved)
	Modules.load_all()
