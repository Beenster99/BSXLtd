extends ModuleTest
## The wrist pages for many records (0.3.14 feedback): Orders groups the market by category
## and lists deliveries, on order or delivered, filtered by the same category; Goods in
## groups and filters the store; Accounts sums money in and out by kind over a day, week or
## month with a day-by-day graph.
##   tools/run_tests.sh business

const Wrist := preload("res://modules/business/internal/ui/wrist_screen.gd")


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true,
			"business": true, "business.market": true, "business.economy": true})
	Modules.load_all()
	var bus := Modules.bus("business") as BusinessBus
	check(bus != null, "business loads")
	if bus == null:
		Flags.use(saved)
		Modules.load_all()
		return
	bus.reset()
	var books: RefCounted = bus.get("_books")

	# Orders: every category under its heading; picking one filters the market.
	var orders := Wrist.new(bus, "orders", true)
	orders.size = Vector2(860, 420)
	add_child(orders)
	await frames(2)
	# A countdown label freed with its page doesn't trip the clock's tick.
	var gone := Label.new()
	orders.call("_count_down", gone, 10)
	gone.free()
	orders.call("_tick_countdowns")
	check((orders.get("_countdowns") as Array).all(func(l: Variant) -> bool: return is_instance_valid(l)), "a freed countdown is dropped on the next tick")
	var list: VBoxContainer = orders.get("_list")
	var entries: Array = orders.get("_entries")
	var cats := {}
	for l in bus.get_listings():
		cats[bus.listing_category(l)] = true
	var heads := entries.filter(func(e: Variant) -> bool: return e is String)
	check(heads.size() == cats.size(), "a heading per category: %d of %d" % [heads.size(), cats.size()])
	check(list.get_children().any(func(c: Node) -> bool: return c.name.begins_with("Heading_")), "headings drawn in the list")
	# Every Void Salvage part is on sale and ALL lists every one (beenster, 0.3.17), building
	# only the lines in view.
	check(entries.size() - heads.size() == bus.get_listings().size(), "ALL lists every listing: %d of %d" % [entries.size() - heads.size(), bus.get_listings().size()])
	check(list.get_child_count() < 200, "but builds only the lines near the view: %d" % list.get_child_count())
	var last_l: MarketListing = entries[entries.size() - 1]
	check(list.find_child("Add_" + last_l.id, true, false) == null, "the last line isn't built at the top")
	var scroll := list.get_parent() as ScrollContainer
	await frames(1)
	scroll.get_v_scroll_bar().value = scroll.get_v_scroll_bar().max_value
	orders.call("_on_list_scrolled", float(list.get_combined_minimum_size().y))
	await frames(1)
	check(list.find_child("Add_" + last_l.id, true, false) != null, "scrolled to the end, the last line is there")
	var drawn: float = list.get_combined_minimum_size().y
	var laid: PackedFloat32Array = orders.get("_offsets")
	check(absf(drawn - (laid[laid.size() - 1] - 3.0)) < 2.0, "the list keeps its full height while windowed: %.0f of %.0f" % [drawn, laid[laid.size() - 1] - 3.0])
	orders.category = "hull"
	orders.refresh()
	entries = orders.get("_entries")
	check(entries.size() == bus.get_listings("hull").size() and entries.all(func(e: Variant) -> bool: return e is MarketListing),
			"a category lists all of it, no headings: %d" % entries.size())
	orders.query = "ion thruster"
	orders.category = ""
	orders.refresh()
	check(orders.shown_listings().any(func(l: MarketListing) -> bool: return l.part == "IonThruster"), "search finds a part by name")
	orders.query = ""
	var cat: String = bus.listing_category(orders.shown_listings()[0])
	orders.category = cat
	orders.refresh()
	check(orders.shown_listings().all(func(l: MarketListing) -> bool: return bus.listing_category(l) == cat), "a category filters the market")
	var row_label := list.get_child(0).find_children("*", "Label", true, false)[0] as Label
	check(row_label.get_theme_font_size("font_size") < 19, "rows are drawn smaller: %d" % row_label.get_theme_font_size("font_size"))

	# Deliveries: two orders in different categories, one landed.
	orders.category = ""
	var by_cat := {}
	for l in bus.get_listings():
		var c := bus.listing_category(l)
		if c != "staples" and not by_cat.has(c):
			by_cat[c] = l
	var picks: Array = by_cat.values().slice(0, 2)
	check(picks.size() == 2, "two categories on the market")
	var first := bus.place_market_order([{"listing_id": picks[0].id, "qty": 1}])
	var second := bus.place_market_order([{"listing_id": picks[1].id, "qty": 1}])
	check(first.is_ok() and second.is_ok(), "two orders placed")
	check(orders.shown_deliveries().size() == 2, "both are on order")
	books.set("instant_deliveries", true)
	books.call("deliver_now")
	books.set("instant_deliveries", false)
	check(orders.shown_deliveries().is_empty(), "then nothing is on order")
	orders.deliveries = "delivered"
	check(orders.shown_deliveries().size() == 2, "and both show as delivered")
	orders.category = bus.listing_category(picks[0])
	check(orders.shown_deliveries().size() == 1 and orders.shown_deliveries()[0].id == first.order_id,
			"the category filters the deliveries too")
	orders.refresh()
	await frames(1)
	check(orders.find_child("Deliveries", true, false) != null and orders.find_child("DeliveryChips", true, false) != null,
			"the Deliveries docket has on order and delivered chips")
	orders.queue_free()

	# Goods in is gone (beenster, 0.3.19): no wrist channel for it.
	check(not BusinessBus.SCREEN_CHANNELS.has("business.goods"), "no Goods in page on the wrist")

	# Accounts: money by kind over a period, and a graph.
	bus.reset()
	books.call("accept_contract", "JOB-1", 10000, 30)
	books.call("advance_day")
	books.call("post", -300, LedgerEntry.WAGES, "", "Ana")
	books.call("post", 500, LedgerEntry.SCRAP, "", "steel")
	var week := bus.accounts_summary(7)
	check(week.days.size() == 2 and week.groups.contracts["in"] == 3000 and week.groups.wages.out == 300 and week.groups.sales["in"] == 500,
			"a week by kind: %s" % str(week.groups))
	check(week.groups.rent.out == bus.get_rules().bay_rent_per_day, "the day's rent is in")
	check(week.net == week.income - week.outgoings and week.income == 3500, "in, out and net add up: %s" % str(week))
	var today := bus.accounts_summary(1)
	check(today.days.size() == 1 and today.groups.contracts["in"] == 0 and today.income == 500, "today leaves yesterday out")
	check(BusinessBus.account_group("loan") == "loans" and BusinessBus.account_group("debug") == "other", "kinds are grouped")
	var accounts := Wrist.new(bus, "accounts", true)
	accounts.size = Vector2(860, 420)
	add_child(accounts)
	await frames(2)
	check(accounts.find_child("DayBars", true, false) != null and accounts.find_child("PeriodChips", true, false) != null,
			"a graph and day, week, month chips")
	check(accounts.find_child("Group_wages", true, false) != null, "a line per kind")
	accounts.period = "month"
	accounts.refresh()
	await frames(1)
	check((accounts.find_child("DayBars", true, false) as Control).get("days").size() == 2, "the graph runs from day one")
	check(accounts.size.y <= 421, "it still fits the wrist pane: %s" % accounts.size)
	accounts.queue_free()

	bus.reset()
	Flags.use(saved)
	Modules.load_all()
