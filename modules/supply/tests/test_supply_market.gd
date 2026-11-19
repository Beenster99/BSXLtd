extends ModuleTest
## Parts market: every vendor prices the open design's lines (or says it can't), prices are the
## same for the same day, deals take money off, standing and volume move waits and prices, the
## optimiser's three plans are in order, and the wall panel shows it all and answers clicks.
##   tools/run_tests.sh supply

const MarketScreen := preload("res://modules/supply/internal/market_screen.gd")


func run_tests() -> void:
	var design := Modules.bus("design") as DesignBus
	var bus := Modules.bus("supply") as SupplyBus
	check(bus != null and design != null, "the supply and design modules are loaded")
	if bus == null or design == null:
		return
	check(bus.vendors.size() >= 5, "the vendors load: %d" % bus.vendors.size())
	bus.reset_data()
	design.library.reset_data()
	design.open_sample()
	var lines := bus.lines()
	check(lines.size() >= 5, "the sample's parts list gives lines to buy: %d" % lines.size())
	var comp := {}
	for l in lines:
		if l.kind == "component":
			comp = l
			break
	check(not comp.is_empty() and str(comp.category) != "", "a component line has its catalogue category: %s" % [comp])

	# Prices: the same day gives the same price; the market moves over months.
	var any := {}
	for l in lines:
		if SupplyMarket.supplies(bus.vendor("meridian"), l):
			any = l
			break
	var mer := bus.vendor("meridian")
	check(SupplyMarket.list_price(mer, any, 410) == SupplyMarket.list_price(mer, any, 410), "a day's price is the same each time")
	var hist := SupplyMarket.history(mer, any, 410, 180, bus.catalog())
	check(hist.size() == 180, "history covers 180 days: %d" % hist.size())
	var lo := INF
	var hi := -INF
	for p in hist:
		lo = minf(lo, p)
		hi = maxf(hi, p)
	check(hi > lo * 1.01 and hi < lo * 2.0, "prices move over six months, within reason: %.0f..%.0f" % [lo, hi])

	# Deals take money off; volume and standing move prices and waits.
	var found_deal := false
	for day in range(400, 470):
		for vend in bus.vendors:
			for l in lines:
				var q := SupplyMarket.quote(vend, l, day, 20, bus.catalog())
				if not q.is_empty() and int(q.deal_off) > 0:
					found_deal = true
					check(float(q.unit) < float(q.list_unit), "a deal lowers the price")
					break
			if found_deal:
				break
		if found_deal:
			break
	check(found_deal, "some line of the sample is on a deal within ten weeks")
	var one := comp.duplicate()
	one.units = 1
	one.qty = 1.0
	one.grade = "S" if str(comp.grade) != "" else ""
	var big := one.duplicate()
	big.units = 30
	big.qty = 30.0
	var q_small := SupplyMarket.quote(mer, one, 410, 20, bus.catalog())
	var q_big := SupplyMarket.quote(mer, big, 410, 20, bus.catalog())
	check(int(q_big.lead) > int(q_small.lead), "buying past a vendor's stock waits longer: %d > %d" % [q_big.lead, q_small.lead])
	check(int(q_big.volume_off) > int(q_small.volume_off), "volume earns a discount")
	var q_pref := SupplyMarket.quote(mer, one, 410, 90, bus.catalog())
	check(float(q_pref.unit) < float(q_small.unit) and int(q_pref.lead) < int(q_small.lead) and float(q_pref.on_time) > float(q_small.on_time),
			"preferred standing is cheaper, quicker and surer")
	var graded := {}
	for l in lines:
		if str(l.grade) != "":
			graded = l.duplicate()
			break
	if not graded.is_empty():
		graded.grade = "P"
		check(SupplyMarket.quote(bus.vendor("kettlemoor"), graded, 410, 20, bus.catalog()).is_empty(),
				"a vendor that doesn't sell a grade doesn't quote it")

	# The optimiser.
	var opt := bus.optimiser()
	check(opt.rows.size() + opt.unsupplied.size() == lines.size(), "every line is weighed")
	var c := float(opt.plans[SupplyOptimiser.CHEAPEST].total)
	var m := float(opt.plans[SupplyOptimiser.MEDIAN].total)
	check(c > 0.0 and c <= m + 0.01, "cheapest is no dearer than the median: %.0f <= %.0f" % [c, m])
	check(float(opt.plans[SupplyOptimiser.RELIABLE].worst) >= float(opt.plans[SupplyOptimiser.CHEAPEST].worst) - 0.0001,
			"most reliable's shakiest line is at least as sure as cheapest's")
	check(bus.optimiser() == opt, "the optimiser isn't run again with nothing changed")
	bus.advance_day()
	check(bus.optimiser() != opt, "a new market day runs it again")
	var before := bus.optimiser()
	bus.set_standing("meridian", 80)
	check(bus.optimiser() != before, "a change of standing runs it again")
	var saved := bus.save_data()
	bus.reset_data()
	bus.load_data(saved, SupplyBus.SAVE_VERSION)
	check(is_equal_approx(bus.standing_of("meridian"), 80.0), "standing saves")
	var business := Modules.bus("business")
	if business and business.has_method("get_day"):
		bus.sync_day()
		check(bus.day == SupplyBus.START_DAY + int(business.call("get_day")),
				"the market day follows the business day (on guests too): %d" % bus.day)
	else:
		check(bus.day == SupplyBus.START_DAY + 1, "the day saves without the business module")

	# The wall panel: offered to the design room's walls, and it works.
	check(design.wall_views.has(SupplyBus.WALL_VIEW), "the market is offered to the walls")
	var wrist: Dictionary = HudSlots.holo_channel(SupplyBus.HOLO_CHANNEL)
	check(not wrist.is_empty() and (wrist.factory as Callable).call(false) is MarketScreen, "the market is a wrist channel too")
	var board := (design.wall_views[SupplyBus.WALL_VIEW].make as Callable).call(150.0) as Control
	add_child(board)
	board.size = Vector2(1100, 800)
	var screen := board as MarketScreen
	check(screen != null, "the wall panel is the market screen")
	if screen == null:
		return
	await frames(3)
	check(screen.notes.size() >= 3, "the optimiser writes notes: %s" % [screen.notes])
	screen.select(str(bus.optimiser().rows[0].line.key))
	check(screen.selected != MarketScreen.DESIGN_ROW and screen._chart.series.size() >= 1, "picking a line charts each vendor's price")
	screen.set_span(180)
	check(screen._chart.days == 180, "the chart spans 180 days")
	screen.set_plan(SupplyOptimiser.RELIABLE)
	check(screen.find_child("Plan_reliable", true, false) != null, "the plan cards are there")
	screen.select(MarketScreen.DESIGN_ROW)
	check(screen._chart.series.size() == 2, "the whole design charts cheapest and median")
	var rows := 0
	for ch in screen._table.get_children():
		rows += 1
	check(rows == bus.optimiser().rows.size() + bus.optimiser().unsupplied.size() + 1, "a row per line, plus the whole design")
	var ids := MarketScreen.placed_ids(design.library.current)
	var n_ids := 0
	for k in ids:
		n_ids += (ids[k] as PackedStringArray).size()
	check(n_ids == design.library.current.components.size() + design.library.current.mounts.size(),
			"every placed object's ID is on a parts line: %d" % n_ids)
	# A design edit refreshes it.
	var n_before := bus.optimiser().rows.size()
	var rec := design.library.current
	var any_comp: Dictionary = rec.components.values()[0]
	var opt_before := bus.optimiser()
	design.editor.do({"op": "remove_component", "id": str(any_comp.id)})
	await frames(3)
	check(bus.optimiser() != opt_before and bus.optimiser().rows.size() <= n_before, "an edit runs the optimiser again")
	board.queue_free()
