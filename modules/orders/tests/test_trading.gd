extends ModuleTest
## Master plan 7.6, selling parts: the lines the yard trades in, buy-back always under the day's
## cheapest price (no buy-then-sell on one day pays, at any standing or volume), a glut fetches
## less each, buying for stock (new and a second-hand lot through the refurb works), selling to
## the best buyer, trading in the accounts; it saves and loads.
##   tools/run_tests.sh orders


func run_tests() -> void:
	for f: String in [OrdersBus.FLAG, OrdersBus.USED_FLAG, OrdersBus.SELL_FLAG]:
		Flags.set_flag(f, true)
	var orders := Modules.bus("orders") as OrdersBus
	var supply := Modules.bus("supply") as SupplyBus
	check(orders != null and supply != null, "the orders and supply modules are loaded")
	if orders == null or supply == null:
		return
	orders.reset_data()
	var biz := Modules.bus("business")
	if biz:
		biz.call("credit", 50000000, "test", "test cash")
	var lines := orders.trade_lines()
	check(lines.size() >= 5, "the yard trades in parts (%d)" % lines.size())
	if lines.is_empty():
		return
	var cat := orders.catalog()
	var vendors: Array = supply.get("vendors")

	# The exploit check: every part, a month of days, any volume, the best standing.
	var worst := -INF
	var worst_at := ""
	var best_standing := {}
	for v: SupplyVendor in vendors:
		best_standing[v.id] = TradeBook.BEST_STANDING
	var day0 := orders.market_day()
	for l: Dictionary in lines:
		for d in range(day0, day0 + 30, 3):
			for qty: int in [1, 5, 40, 400]:
				var buy := TradeBook.buy_quote(l, qty, vendors, best_standing, d, cat)
				var offers := TradeBook.offers(l, qty, vendors, d, cat)
				if buy.is_empty() or offers.is_empty():
					continue
				# A buyer on shift takes 5% off what the yard pays.
				var margin := float(offers[0].each) - float(buy.unit) * 0.95
				if margin > worst:
					worst = margin
					worst_at = "%s day %d x%d: sell %.0f, buy %.0f" % [str(l.name), d, qty, float(offers[0].each), float(buy.unit) * 0.95]
	check(worst < 0.0, "no buy-then-sell on one day pays (closest: %s)" % worst_at)
	var l0: Dictionary = lines[0]
	var key := str(l0.key)
	var one := orders.trade_offers(key, 1)
	var many := orders.trade_offers(key, 30)
	check(not one.is_empty() and float(many[0].each) < float(one[0].each), "selling many at once fetches less each (%.0f against %.0f)" % [float(many[0].each), float(one[0].each)])
	var trend := orders.trade_trend(key, 14)
	var moves := false
	for v in trend:
		moves = moves or absf(v - trend[0]) > 0.5
	check(trend.size() == 14 and moves, "the buy-back moves from day to day (time a sale)")

	# Buy for stock, it comes in, sell it.
	var cash := int(biz.call("get_cash")) if biz else 0
	orders.trade_buy(key, 5)
	check(orders.orders.size() == 1 and str(orders.orders[0].cid) == OrdersBus.STOCK, "bought for stock: an order")
	if biz:
		check(int(biz.call("get_cash")) < cash, "paid for")
	orders.trade_sell(key, 1)
	check(orders.sales.is_empty(), "nothing to sell before it comes in")
	for o: Dictionary in orders.orders:
		o.due = orders.now_minute()
	orders.deliver_due()
	check(int(orders.holdings.get(key, 0)) == 5, "in: the yard holds 5")
	cash = int(biz.call("get_cash")) if biz else 0
	orders.trade_sell(key, 2)
	check(int(orders.holdings.get(key, 0)) == 3 and orders.sales.size() == 1, "sold 2 to the best buyer")
	if biz:
		check(int(biz.call("get_cash")) > cash, "and paid for them")
		check(str(biz.call("account_group", OrdersBus.TRADING)) == "sales", "trading shows as its own line in the accounts' sales")
	var t := orders.trade_totals()
	check(int(t.spent) > 0 and int(t.earned) > 0 and int(t.net) < 0, "buy and sell straight away and the yard is down (%s)" % str(t))

	# A second-hand lot: cheaper, through the works, counted once certified.
	var refurb := Modules.bus("refurb")
	var used_key := ""
	for l: Dictionary in lines:
		if not orders.trade_used_quote(str(l.key), 5).is_empty():
			used_key = str(l.key)
			break
	if refurb:
		check(used_key != "", "a second-hand lot can be had")
	if used_key != "":
		var u := orders.trade_used_quote(used_key, 5)
		var n := orders.trade_buy_quote(used_key, 5)
		check(float(u.unit) < float(n.unit), "a used lot comes cheaper than new, refurb and all (%.0f against %.0f)" % [float(u.unit), float(n.unit)])
		var u1 := orders.trade_used_quote(used_key, 1)
		check(float(u.unit) < float(u1.unit), "and cheaper still in bulk")
		var held_before := int(orders.holdings.get(used_key, 0))
		orders.trade_buy(used_key, 5, true)
		var o: Dictionary = orders.orders.back()
		o.due = orders.now_minute()
		orders.deliver_due()
		check(int(orders.holdings.get(used_key, 0)) == held_before, "in the works, not held yet")
		for i in 5:
			orders._on_certified(str(o.lines[0].type), {})
		check(int(orders.holdings.get(used_key, 0)) == held_before + 5, "certified, the yard holds them to sell")
		var best := orders.trade_offers(used_key, 5)
		if not best.is_empty():
			print("trading: a used lot of %s at CR %.0f each sells for CR %.0f each; new costs CR %.0f" % [used_key, float(u.unit), float(best[0].each), float(n.unit)])
		check(not best.is_empty(), "and a buyer for them (CR %.0f each against CR %.0f paid)" % [float(best[0].each) if not best.is_empty() else 0.0, float(u.unit)])

	var held_key := int(orders.holdings.get(key, 0))
	var saved := orders.save_data()
	orders.reset_data()
	orders.load_data(saved, OrdersBus.SAVE_VERSION)
	check(int(orders.holdings.get(key, 0)) == held_key and orders.sales.size() == 1, "holdings and sales keep across a save")
	var screen := orders.make_trade_screen(150.0)
	add_child(screen)
	await frames(1)
	check(screen.get_child_count() > 0, "the trading screen draws")
	screen.queue_free()
	orders.reset_data()
