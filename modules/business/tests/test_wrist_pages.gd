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
	var list: VBoxContainer = orders.get("_list")
	var headings := list.get_children().filter(func(c: Node) -> bool: return c.name.begins_with("Heading_"))
	var cats := {}
	for l in bus.get_listings():
		cats[bus.listing_category(l)] = true
	check(headings.size() == cats.size(), "a heading per category: %d of %d" % [headings.size(), cats.size()])
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
	books.call("deliver_now")
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

	# Goods in: the store grouped by category, with chips and a search.
	bus.add_stock("raw_steel", 420)
	var goods := Wrist.new(bus, "goods", true)
	goods.size = Vector2(860, 420)
	add_child(goods)
	await frames(2)
	var store: VBoxContainer = goods.get("_store")
	check(store.get_children().any(func(c: Node) -> bool: return c.name == "Heading_materials"), "raw materials under their own heading")
	check(store.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == "420 KG"), "kilos read as kilos")
	goods.store_category = "materials"
	goods.call("_refresh_goods")
	check(store.get_children().filter(func(c: Node) -> bool: return c.name.begins_with("Heading_")).size() == 1, "a store category filters it")
	goods.store_category = ""
	goods.store_query = "zzz"
	goods.call("_refresh_goods")
	await frames(1)
	check(store.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == "Nothing matches."), "and the search")
	goods.queue_free()

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
