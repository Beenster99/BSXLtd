extends ModuleTest
## Business: the parts market (Void Salvage's catalogue at trade prices, mixed condition,
## a daily swing), market orders with quantities and a bill, deliveries by condition, the
## business clock, and saves from before the market.
##   tools/run_tests.sh business

var bus: BusinessBus


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "business": true, "business.market": true})
	Modules.load_all()
	bus = Modules.bus("business") as BusinessBus
	check(bus != null, "business loads")
	if bus == null:
		Flags.use(saved)
		Modules.load_all()
		return
	var reliabilities := {}
	for s: SupplierDef in bus.get_suppliers():
		reliabilities[s] = s.reliability
	bus.reset()

	_test_catalogue()
	_test_listings()
	_test_every_part()
	_test_market_order()
	_test_clock()
	_test_old_save()

	for s: SupplierDef in reliabilities:
		s.reliability = reliabilities[s]
	bus.reset()
	Flags.use(saved)
	Modules.load_all()


func _test_catalogue() -> void:
	var cat := bus.get_catalogue()
	check(cat.parts.size() > 100, "the market knows Void Salvage's parts: %d" % cat.parts.size())
	check(cat.has_part("IonThruster") and cat.category_of("IonThruster") == "engines", "parts keep Void Salvage's names and categories")
	check(cat.value_of("MainEngine") > cat.value_of("HullPlate"), "an engine is worth more than a plate")
	check(cat.source_commit.length() == 40, "the catalogue records the Void Salvage commit it came from")


## beenster (0.3.16): every part Void Salvage builds is buyable on the Orders page, every day.
func _test_every_part() -> void:
	var cat := bus.get_catalogue()
	check(cat.parts.size() >= 900, "the catalogue holds every part Void Salvage builds: %d" % cat.parts.size())
	for d in 3:
		var on_sale := {}
		for l in bus.get_listings():
			if l.available > 0:
				on_sale[l.part] = true
		var missing: Array[String] = []
		for part in cat.part_names():
			if not on_sale.has(part):
				missing.append(part)
		check(missing.is_empty(), "day %d: every part is on sale (%d missing: %s)" % [bus.get_day(), missing.size(), str(missing.slice(0, 5))])
		bus.advance_minutes(1440)
	bus.reset()


func _test_listings() -> void:
	var all := bus.get_listings()
	check(all.size() > 40, "a full market on day one: %d listings" % all.size())
	var conditions := {}
	var hidden := 0
	for l in all:
		conditions[l.condition] = true
		if l.supplier_id == "halden_drive":
			hidden += 1
		check(l.unit_price > 0 and l.available > 0, "%s has a price and stock" % l.id)
	check(conditions.size() >= 3, "parts in several conditions: %s" % str(conditions.keys()))
	check(hidden == 0, "a reputation-gated supplier lists nothing yet")
	check(all.size() < 2 or all[0].unit_price <= all[1].unit_price, "cheapest first")
	check(all.back().id.begins_with("S-") and not all[0].id.begins_with("S-"), "staples after the catalogue parts")
	check(bus.part_name("M10") == "M10 bolts" and bus.part_name("IonThruster") == "Ion thruster", "parts read by name")
	# The day's market is random, so filter by a category it has today.
	var cat := bus.listing_category(all[0])
	var in_cat := bus.get_listings(cat)
	check(not in_cat.is_empty() and in_cat.all(func(l): return bus.listing_category(l) == cat), "filter by category (%s)" % cat)
	var staples := bus.get_listings("staples")
	check(staples.any(func(l): return l.part == "M10"), "fasteners always on the counter")

	# Trade price: Void Salvage's value x the supplier's share x the condition x the day.
	var ring := bus.supplier("ringside_exchange")
	var books: RefCounted = bus.get("_books")
	for cond: String in PartCondition.ALL:
		var p: int = books.trade_price(ring, "MainEngine", cond)
		var expect := bus.get_catalogue().value_of("MainEngine") * ring.trade_factor * PartCondition.price_factor(cond)
		check(absf(p - expect) <= expect * 0.07 + 1, "%s main engine near %d: %d" % [cond, expect, p])
	check(books.trade_price(ring, "MainEngine", PartCondition.DAMAGED) < books.trade_price(ring, "MainEngine", PartCondition.NEW) * 0.5,
			"damaged parts are much cheaper")
	var swings := {}
	for d in 6:
		swings[books.trade_price(ring, "MainEngine", PartCondition.NEW)] = true
		books.minute += 1440
	books.minute = 0
	check(swings.size() > 1, "trade prices move from day to day: %s" % str(swings.keys()))


func _test_market_order() -> void:
	bus.reset()
	var a: MarketListing
	var b: MarketListing
	for l in bus.get_listings():
		if l.id.begins_with("S-") or l.unit_price > 3000:
			continue
		if a == null and l.available >= 2:
			a = l
		elif a and b == null and l.supplier_id != a.supplier_id:
			b = l
	check(a != null and b != null, "two affordable listings from two suppliers")
	if a == null or b == null:
		return
	var basket := [{"listing_id": a.id, "qty": 2}, {"listing_id": b.id, "qty": 1}]
	var q := bus.quote_market(basket)
	check(q.ok and q.cost == a.unit_price * 2 + b.unit_price, "the bill adds up: %d" % q.cost)
	var too_many := bus.quote_market([{"listing_id": a.id, "qty": a.available + 1}])
	check(not too_many.ok and too_many.reason.begins_with("only"), "can't buy more than is listed")
	check(not bus.quote_market([{"listing_id": "nope", "qty": 1}]).ok, "a vanished listing is refused")

	var cash := bus.get_cash()
	var left := a.available
	var r := bus.place_market_order(basket)
	check(r.is_ok() and r.order_ids.size() == 2, "one order per supplier: %s" % str(r.order_ids))
	check(bus.get_cash() == cash - q.cost and r.cost == q.cost, "paid the bill")
	check(bus.get_listing(a.id).available == left - 2, "bought stock comes off the listing")
	var order := bus.get_order(r.order_ids[0])
	check(order.lines[0].condition != "" and order.lines[0].unit_price > 0, "orders keep each part's condition and price")

	for s: SupplierDef in bus.get_suppliers():
		s.reliability = 1.0
	for i in 4:
		bus.advance_day()
	check(bus.get_orders(PartsOrder.State.DELIVERED).size() == 2, "both orders land")
	var detail := bus.get_stock_detail()
	check(int(detail.get(a.part, {}).get(a.condition, 0)) >= 2, "stock is kept by condition: %s" % str(detail.get(a.part)))
	check(bus.get_stock()[a.part] >= 2, "and counted per part")
	var landed := bus.delivery_lines(order)
	check(landed.size() == order.lines.size() and landed[0].item_id == order.lines[0].part and landed[0].name == bus.part_name(order.lines[0].part),
			"delivery lines in Ship and Bay's shape: %s" % str(landed))
	var lc: float = landed[0].condition
	check(lc > 0.0 and lc <= 1.0 and is_equal_approx(lc, 1.0 - PartCondition.wear_of(order.lines[0].condition)), "condition as 0..1 for the crate")
	var lost: Array[OrderLine] = [OrderLine.new(order.lines[0].part, order.lines[0].qty, order.lines[0].condition)]
	check(bus.delivery_lines(order, lost).size() == order.lines.size() - 1, "parts lost in transit don't land")
	check(bus.use_stock(a.part, 1, a.condition).is_ok(), "use a named condition")
	check(not bus.use_stock(a.part, 1, "no_such_condition").is_ok(), "an unknown condition has none")

	bus.reset()
	bus.charge(bus.get_cash() - 10, LedgerEntry.UPGRADE)
	var dear := bus.get_listings().filter(func(l): return l.unit_price > 10)[0] as MarketListing
	var refused := bus.place_market_order([{"listing_id": dear.id, "qty": 1}])
	check(not refused.is_ok() and bus.get_cash() == 10, "can't order what you can't pay for")


func _test_clock() -> void:
	bus.reset()
	var first := bus.get_listings().map(func(l): return l.id)
	bus.advance_minutes(90)
	check(bus.get_minute() == 90 and bus.get_day() == 0 and bus.get_clock_text() == "DAY 1  01:30", "the clock reads %s" % bus.get_clock_text())
	var cash := bus.get_cash()
	bus.advance_minutes(1440)
	check(bus.get_day() == 1 and bus.get_cash() == cash - bus.get_rules().bay_rent_per_day, "midnight charges rent")
	var next := bus.get_listings().map(func(l): return l.id)
	check(next != first, "a new market each day")

	var kessler := bus.supplier("kessler_fasteners")
	kessler.reliability = 1.0
	var at := bus.get_minute()
	var r := bus.place_order("kessler_fasteners", _lines("M10", 10))
	bus.advance_minutes(kessler.lead_hours * 60 - 1)
	check(bus.get_order(r.order_id).state == PartsOrder.State.PLACED, "not before its time")
	bus.advance_minutes(1)
	check(bus.get_order(r.order_id).state == PartsOrder.State.DELIVERED and bus.get_minute() == at + kessler.lead_hours * 60, "lands to the minute")


func _test_old_save() -> void:
	# A version 1 save: whole days, one stock count per part, no market.
	var v1 := {"day": 3, "cash": 15000.0, "reputation": 55.0, "ledger": [], "orders": [
			{"id": "PO-0001", "supplier_id": "kessler_fasteners", "lines": [{"part": "M10", "qty": 5}],
			"cost": 10, "placed_day": 2, "eta_day": 3, "state": 1}],
			"contracts": {}, "stock": {"M10": 5.0}, "days_in_debt": 0, "insolvent": false, "next_order": 2}
	bus.load_data(v1, 1)
	check(bus.get_day() == 3 and bus.get_minute() == 3 * 1440, "version 1 days become minutes")
	check(bus.get_stock_detail().get("M10", {}).get("new") == 5, "version 1 stock counts as new")
	check(bus.get_order("PO-0001").eta_minute == 3 * 1440, "version 1 orders get minute times")
	check(not bus.get_listings().is_empty(), "a market opens on an old save")
	check(bus.save_version() == 2, "saves are version 2")


func _lines(part: String, qty: int) -> Array[OrderLine]:
	var out: Array[OrderLine] = [OrderLine.new(part, qty)]
	return out
