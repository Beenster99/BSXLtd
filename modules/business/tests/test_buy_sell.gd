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


## Puts `qty` of a part on the stores' shelves, as a delivery the trolleys put away.
func _shelve(part: String, qty: int) -> void:
	var yard := Modules.bus("ship_bay") as ShipBayBus
	var before := yard.delivered_crates().keys()
	yard.receive_delivery("PO-SHELF-%s-%d" % [part, qty], [{"item_id": part, "qty": qty, "condition": 0.6, "name": part, "grade": PartCondition.USED, "mass": 10.0}])
	for id: String in yard.delivered_crates():
		if not id in before:
			yard.store_crate(id)


func _test_selling() -> void:
	bus.add_stock("IonThruster", 3, PartCondition.USED, "test")
	# Not on a shelf yet: not stock to sell (beenster, 0.3.19).
	check(bus.shelved_count("IonThruster") == 0, "nothing on the shelves yet")
	var w0 := Wrist.new(bus, "orders", true)
	w0.mode = "sell"
	check(not w0.stock_lines("").any(func(d: Dictionary) -> bool: return d.part == "IonThruster"), "so the Sell list leaves it out")
	w0.free()
	var early := bus.get_offers("IonThruster", PartCondition.USED)
	check(not bus.sell_stock(early[0].supplier_id, "IonThruster", PartCondition.USED, 1).is_ok(), "and it can't be sold")
	_shelve("IonThruster", 3)
	check(bus.shelved_count("IonThruster") == 3, "put away, it's on the shelves: %d" % bus.shelved_count("IonThruster"))
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
	_test_standing(offers[0].supplier_id)


## Selling to a company builds standing with it, which takes a little off what it sells you.
func _test_standing(buyer: String) -> void:
	var st := bus.standing_with(buyer)
	check(st.sold > 0 and st.name == "New" and st.off == 0 and st.next_name == "Known", "a first sale: still New, %s" % str(st))
	var l: MarketListing = null
	for each in bus.get_listings(""):
		if each.supplier_id == buyer and each.unit_price >= 500 and each.available >= 1:
			l = each
			break
	var before := bus.listing_cost(l, 1) if l else 0
	(bus.get("_books") as Object).call("post", 20000, LedgerEntry.RESALE, buyer, "test sales")
	st = bus.standing_with(buyer)
	check(st.name == "Regular" and st.off == 4 and st.next_name == "Partner", "20,000 sold: a Regular, 4%% off: %s" % str(st))
	if l:
		check(bus.listing_cost(l, 1) < before and bus.listing_cost(l, 1) == roundi(l.unit_price * 0.96), "which comes off buying there: %d < %d" % [bus.listing_cost(l, 1), before])


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
	# Picking the buyer: click a stock line, its buyers show with their own SELL buttons.
	bus.add_stock("IonThruster", 2, PartCondition.USED, "test")
	_shelve("IonThruster", 2)
	var offers := bus.get_offers("IonThruster", PartCondition.USED)
	w.pick_stock("IonThruster|used")
	await frames(1)
	var buyers := (w.get("_side") as Node).find_child("Buyers", true, false)
	check(buyers != null, "clicking a stock line shows its buyers")
	if buyers and offers.size() >= 2:
		var second: String = offers[1].supplier_id
		var to := buyers.find_child("SellTo_" + ("%s_IonThruster_used" % second).validate_node_name(), true, false) as Button
		check(to != null and buyers.find_children("SellTo_*", "Button", true, false).size() == offers.size(), "one SELL per buyer: %d" % offers.size())
		if to:
			to.pressed.emit()
			await frames(1)
			check(bus.get_ledger(bus.get_day()).any(func(e: LedgerEntry) -> bool: return e.category == LedgerEntry.RESALE and e.ref == second),
					"selling to the second-best buyer sells to it")
	# Deals: the terms of a deal, its bulk prices and the standing there.
	w.mode = "buy"
	w.category = "deals"
	w.refresh()
	await frames(1)
	var terms := (w.get("_side") as Node).find_child("Terms", true, false)
	check(terms != null, "DEALS explains itself beside the list")
	var deal: MarketListing = w.shown_listings()[0]
	w.pick_listing(deal.id)
	await frames(1)
	terms = (w.get("_side") as Node).find_child("Terms", true, false)
	var said := " ".join(terms.find_children("*", "Label", true, false).map(func(x: Label) -> String: return x.text)) if terms else ""
	check("%d%% OFF" % deal.deal_off() in said and T_money(deal.list_price) in said and "EACH" in said, "a picked deal shows what's off, the old price and the price each: %s" % said)
	var tiers: Array = w.bulk_tiers(deal)
	if not tiers.is_empty():
		check("BUY %d OR MORE" % tiers[0].x in said, "and its bulk prices")
	w.queue_free()


func T_money(n: int) -> String:
	return (load("res://modules/ui/api/terminal_kit.gd") as GDScript).call("money", n)
