extends ModuleTest
## Buy/Sell (0.3.16 playtest): suppliers price the same part differently, run daily deals and
## give bulk discounts; the company sells its stock to other companies at their offers.
##   tools/run_tests.sh business

const Wrist := preload("res://modules/business/internal/ui/wrist_screen.gd")

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
	bus.reset()
	_test_supplier_prices()
	_test_deals()
	_test_bulk()
	_test_selling()
	await _test_page()
	bus.reset()
	Flags.use(saved)
	Modules.load_all()


func _test_supplier_prices() -> void:
	# The same part new from two suppliers, at different prices.
	var by_part := {}
	for l in bus.get_listings():
		if l.condition == PartCondition.NEW and not l.id.begins_with("S-"):
			if not by_part.has(l.part):
				by_part[l.part] = {}
			by_part[l.part][l.supplier_id] = l.unit_price
	var compared := 0
	var differ := 0
	for part: String in by_part:
		if by_part[part].size() >= 2:
			compared += 1
			var prices: Array = by_part[part].values()
			if prices.min() != prices.max():
				differ += 1
	check(compared > 200, "many parts are on sale from more than one supplier: %d" % compared)
	check(differ > compared * 0.8, "and their prices differ: %d of %d" % [differ, compared])


func _test_deals() -> void:
	var deals := bus.get_listings().filter(func(l: MarketListing) -> bool: return l.list_price > l.unit_price)
	check(deals.size() >= 8, "suppliers run deals today: %d" % deals.size())
	for l: MarketListing in deals:
		var s := bus.supplier(l.supplier_id)
		check(l.deal_off() >= s.deal_percent.x - 1 and l.deal_off() <= s.deal_percent.y + 1, "%s is %d%% off" % [l.id, l.deal_off()])


func _test_bulk() -> void:
	# A cheap listing with enough stock for its supplier's biggest bulk price.
	var l: MarketListing = null
	var big := 0
	for each in bus.get_listings():
		if each.id.begins_with("S-") or each.unit_price >= 200:
			continue
		var top := 0
		for n in bus.supplier(each.supplier_id).bulk_percent:
			top = maxi(top, int(n))
		if top > 0 and each.available >= top:
			l = each
			big = top
			break
	check(l != null, "a cheap listing with plenty of stock")
	if l == null:
		return
	check(bus.listing_cost(l, 1) == l.unit_price, "one costs the unit price")
	var q := bus.quote_market([{"listing_id": l.id, "qty": big}])
	check(q.ok and q.cost < l.unit_price * big and q.saving > 0, "buying %d is cheaper each: %d < %d" % [big, q.cost, l.unit_price * big])
	var cash := bus.get_cash()
	var r := bus.place_market_order([{"listing_id": l.id, "qty": big}])
	check(r.is_ok() and bus.get_cash() == cash - q.cost, "the bulk price is what's paid")


func _test_selling() -> void:
	bus.add_stock("IonThruster", 3, PartCondition.USED, "test")
	var offers := bus.get_offers("IonThruster", PartCondition.USED)
	check(offers.size() >= 1, "companies offer for a used ion thruster: %s" % str(offers))
	for i in offers.size() - 1:
		check(offers[i].unit_price >= offers[i + 1].unit_price, "best offer first")
	var cheapest_new := 1 << 30
	for l in bus.get_listings():
		if l.part == "IonThruster" and l.condition == PartCondition.NEW and l.list_price == 0:
			cheapest_new = mini(cheapest_new, l.unit_price)
	check(offers[0].unit_price < cheapest_new, "they pay less than a new one costs: %d < %d" % [offers[0].unit_price, cheapest_new])
	var cash := bus.get_cash()
	var r := bus.sell_stock(offers[0].supplier_id, "IonThruster", PartCondition.USED, 2)
	check(r.is_ok() and bus.get_cash() == cash + offers[0].unit_price * 2, "selling two pays the offer: %s" % r.message)
	check(int(bus.get_stock_detail().get("IonThruster", {}).get(PartCondition.USED, 0)) == 1, "and takes them from stock")
	check(bus.get_ledger(bus.get_day()).any(func(e: LedgerEntry) -> bool: return e.category == LedgerEntry.RESALE), "the sale is in the ledger")
	check(not bus.sell_stock(offers[0].supplier_id, "IonThruster", PartCondition.USED, 5).is_ok(), "can't sell more than is held")
	check(not bus.sell_stock("kessler_fasteners", "IonThruster", PartCondition.USED, 1).is_ok(), "a company that doesn't deal in engines won't buy one")
	check(bus.call("_validate_order", 1, {"kind": "sell", "supplier": offers[0].supplier_id, "part": "IonThruster", "condition": PartCondition.USED, "qty": 1}) is Dictionary,
			"the host takes a crew member's sale")
	check(bus.call("_validate_order", 1, {"kind": "sell", "supplier": offers[0].supplier_id, "part": "IonThruster", "condition": PartCondition.USED, "qty": 9}) is String,
			"but not more than is held")


func _test_page() -> void:
	var w := Wrist.new(bus, "orders", true)
	w.size = Vector2(980, 480)
	add_child(w)
	await frames(2)
	var list: VBoxContainer = w.get("_list")
	check(w.call("_categories").has("deals"), "a DEALS chip on the buy side")
	w.category = "deals"
	w.refresh()
	check(not w.shown_listings().is_empty() and w.shown_listings().all(func(l: MarketListing) -> bool: return l.deal_off() > 0), "DEALS shows only deals")
	w.category = ""
	w.mode = "sell"
	w.refresh()
	await frames(1)
	var lines := w.stock_lines("")
	check(lines.any(func(d: Dictionary) -> bool: return d.part == "IonThruster"), "SELL lists the stock: %d lines" % lines.size())
	var button := list.find_child("Sell_IonThruster_used", true, false) as Button
	check(button != null, "with a SELL button")
	if button:
		var cash := bus.get_cash()
		button.pressed.emit()
		await frames(1)
		check(bus.get_cash() > cash and int(bus.get_stock_detail().get("IonThruster", {}).get("used", 0)) == 0, "which sells to the best offer")
		check(w.get_node_or_null("../") != null and (w.get("_side") as Node).find_child("Sales", true, false) != null, "and today's sales show beside it")
	w.queue_free()
