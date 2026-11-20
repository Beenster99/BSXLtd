extends ModuleTest
## Master plan 7.6, selling parts: the lines the yard trades in, buy-back always under the day's
## cheapest price (no buy-then-sell on one day pays, at any standing or volume), a glut fetches
## less each, a market that swings over months (buy at a low, sell at a later high), buying new or
## one of the day's second-hand lots (the refurb works' bill apart), selling to the best buyer, trading in the accounts; it
## saves and loads.
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
	var hull_lines := lines.filter(func(l: Dictionary) -> bool: return str(l.kind) == "hull")
	check(hull_lines.size() >= 3 and lines.all(func(l: Dictionary) -> bool: return not TradeBook.SKIP.has(str(l.key))),
			"plates, beams and fixings trade too, welds do not (%d hull lines)" % hull_lines.size())
	check(TradeBook.buy_qty(hull_lines[0]) == TradeBook.BUY_STOCK if not hull_lines.is_empty() else false, "hull stock is bought fifty at a time")
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
	# A market: prices swing over months; buying new at a low and selling at a later high pays.
	var swings := 0
	var timing := 0
	for l: Dictionary in lines:
		var lo := INF
		var hi := -INF
		var low_buy := INF
		var paid := false
		for d in range(day0, day0 + 180, 2):
			var m := TradeBook.market(l, d)
			lo = minf(lo, m)
			hi = maxf(hi, m)
			var b := TradeBook.buy_quote(l, 5, vendors, best_standing, d, cat)
			var o := TradeBook.offers(l, 5, vendors, d, cat)
			if not b.is_empty():
				low_buy = minf(low_buy, float(b.unit))
			if not o.is_empty() and float(o[0].each) > low_buy:
				paid = true
		if hi / lo > 1.3:
			swings += 1
		if paid:
			timing += 1
	check(swings == lines.size(), "every part's market swings by more than 30%% over half a year (%d of %d)" % [swings, lines.size()])
	check(timing * 2 > lines.size(), "buying new at a low and selling at a later high pays for most parts (%d of %d)" % [timing, lines.size()])
	check(TradeBook.market(l0, day0) == TradeBook.market(l0, day0), "the market is the same on every machine")

	# Second-hand lots: a few a day, each bought once; new can always be bought.
	var lots := orders.trade_lots()
	check(lots.size() == TradeBook.LOTS_A_DAY or not Flags.is_on(OrdersBus.USED_FLAG), "%d refurbished lots on offer today (%s)" % [lots.size(), str(lots)])
	check(TradeBook.lots(lines, day0) == TradeBook.lots(lines, day0), "the same lots on every machine")
	var other := false
	for d in range(day0 + 1, day0 + 8):
		other = other or TradeBook.lots(lines, d) != TradeBook.lots(lines, day0)
	check(other, "different parts on other days")
	var cash := int(biz.call("get_cash")) if biz else 0
	orders.trade_buy(key, 5)
	check(orders.orders.size() == 1 and str(orders.orders[0].cid) == OrdersBus.STOCK, "bought 5 new for stock: an order")
	if biz:
		check(int(biz.call("get_cash")) < cash, "paid for")
	orders.orders.clear()
	var off := ""
	for l: Dictionary in lines:
		if not lots.has(str(l.key)):
			off = str(l.key)
			break
	orders.trade_buy(off, TradeBook.LOT_SIZE, true)
	check(orders.orders.is_empty(), "a part with no lot today cannot be bought")
	if lots.is_empty():
		return
	var used_key: String = lots[0]
	var u := orders.trade_used_quote(used_key, TradeBook.LOT_SIZE)
	var n := orders.trade_buy_quote(used_key, TradeBook.LOT_SIZE)
	check(float(u.parts) < float(n.unit) and float(u.refurb) > 0.0 and is_equal_approx(float(u.unit), float(u.parts))
			and float(u.refurb_lo) < float(u.refurb) and float(u.refurb) < float(u.refurb_hi),
			"a lot's parts come cheaper than new, the refurb bill an estimate apart (%.0f + %.0f to %.0f refurb against %.0f new)" % [
				float(u.parts), float(u.refurb_lo), float(u.refurb_hi), float(n.unit)])
	orders.trade_buy(used_key, TradeBook.LOT_SIZE, true)
	check(orders.orders.size() == 1 and str(orders.orders[0].cid) == OrdersBus.STOCK, "bought a lot for stock: an order")
	check(not orders.trade_lots().has(used_key), "and that lot is gone for today")
	orders.trade_buy(used_key, TradeBook.LOT_SIZE, true)
	check(orders.orders.size() == 1, "it cannot be bought twice")
	orders.trade_sell(used_key, 1)
	check(orders.sales.is_empty(), "nothing to sell before it comes in")
	var o: Dictionary = orders.orders.back()
	o.due = orders.now_minute()
	orders.deliver_due()
	check(int(orders.holdings.get(used_key, 0)) == 0, "in the works, not held yet")
	var spent_before := int(o.total)
	var cash_before := int(biz.call("get_cash")) if biz else 0
	for i in TradeBook.LOT_SIZE:
		orders._on_certified(str(o.lines[0].type), {})
	check(int(orders.holdings.get(used_key, 0)) == TradeBook.LOT_SIZE, "certified, the yard holds them to sell")
	var bills := float(o.lines[0].refurb_paid)
	check(bills >= float(u.refurb_lo) * TradeBook.LOT_SIZE - 1.0 and bills <= float(u.refurb_hi) * TradeBook.LOT_SIZE + 1.0
			and int(o.total) == spent_before + int(bills), "the real refurb bills fall in the estimate (CR %.0f for %d)" % [bills, TradeBook.LOT_SIZE])
	if biz:
		check(int(biz.call("get_cash")) < cash_before, "and are paid as each comes out of the works")
	var same := TradeBook.refurb_bill(1000.0, 7, 1) == TradeBook.refurb_bill(1000.0, 7, 1)
	var varies := false
	for i in range(2, 8):
		varies = varies or TradeBook.refurb_bill(1000.0, 7, i) != TradeBook.refurb_bill(1000.0, 7, 1)
	check(same and varies, "each part's condition differs, the same on every machine")
	var best := orders.trade_offers(used_key, 2)
	var high := 0.0
	for v in orders.trade_trend(used_key, 14):
		high = maxf(high, v)
	check(not best.is_empty() and high > float(u.unit) + float(u.refurb), "a buyer for them, paying more than they cost on a good day (today CR %.0f, best of 14 days CR %.0f, against CR %.0f)" % [float(best[0].each) if not best.is_empty() else 0.0, high, float(u.unit)])
	cash = int(biz.call("get_cash")) if biz else 0
	orders.trade_sell(used_key, 2)
	check(int(orders.holdings.get(used_key, 0)) == 3 and orders.sales.size() == 1, "sold 2 to the best buyer")
	if biz:
		check(int(biz.call("get_cash")) > cash, "and paid for them")
		check(str(biz.call("account_group", OrdersBus.TRADING)) == "sales", "trading shows as its own line in the accounts' sales")
	var t := orders.trade_totals()
	check(int(t.spent) > 0 and int(t.earned) > 0, "trading's money in and out (%s)" % str(t))
	key = used_key

	# The trade advisor: tips that say which way a price goes, mostly right.
	var tips := orders.trade_tips()
	check(not tips.is_empty() and tips.all(func(t: Dictionary) -> bool: return str(t.text) != ""), "the trade advisor has tips (%d)" % tips.size())
	var right := 0
	var told := 0
	for l: Dictionary in lines:
		for d in range(day0, day0 + 60, 5):
			var look := TradeBook.outlook(l, vendors, d, cat)
			if look.is_empty():
				continue
			var now := TradeBook.offers(l, 1, vendors, d, cat)
			var then := TradeBook.offers(l, 1, vendors, d + int(look.ahead), cat)
			told += 1
			if (float(then[0].each) > float(now[0].each)) == (float(look.change) > 0.0):
				right += 1
	check(told > 10 and right == told, "the advisor is right about which way prices go (%d of %d)" % [right, told])
	var held_key := int(orders.holdings.get(key, 0))
	var saved := orders.save_data()
	orders.reset_data()
	orders.load_data(saved, OrdersBus.SAVE_VERSION)
	check(int(orders.holdings.get(key, 0)) == held_key and orders.sales.size() == 1 and not orders.trade_lots().has(key), "holdings and sales keep across a save")
	var screen := orders.make_trade_screen(150.0)
	add_child(screen)
	await frames(1)
	check(screen.get_child_count() > 0, "the trading screen draws")
	screen.queue_free()
	orders.reset_data()
