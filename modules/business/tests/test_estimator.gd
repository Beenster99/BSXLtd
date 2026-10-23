extends ModuleTest
## The cost estimator on the Buy/Sell page (beenster, 23 Oct): ESTIMATE swaps the purchase
## order for an estimate; + on a part prices it there at any quantity, less bulk discounts,
## without ordering anything; ORDER THESE copies it onto the purchase order.
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
	var w := Wrist.new(bus, "orders", true)
	w.size = Vector2(1100, 560)
	add_child(w)
	await frames(2)

	var est := w.find_child("Estimate", true, false) as Button
	check(est != null, "the Buy page has an ESTIMATE button")
	est.pressed.emit()
	await frames(1)
	check(w.estimating and w.find_child("Estimator", true, false) != null, "it opens the estimator")
	check(w.find_child("PlaceOrder", true, false) == null, "in place of the purchase order")

	# A listing with a bulk tier, priced past its stock.
	var pick: MarketListing = null
	for l in bus.get_listings():
		var s := bus.supplier(l.supplier_id)
		if not l.id.begins_with("S-") and l.available > 0 and s.bulk_percent.size() > 0:
			pick = l
			break
	check(pick != null, "a listing to price")
	if pick == null:
		_done(w, saved)
		return
	var add := w.find_child("Estimate_" + pick.id, true, false) as Button
	if add == null:
		w.add_to_estimate(pick.id, 1)
	else:
		add.pressed.emit()
	await frames(1)
	check(int(bus.wrist_estimate.get(pick.id, 0)) == 1 and bus.wrist_basket.is_empty(), "+ adds to the estimate, not the order")
	var big := pick.available + 200
	w.add_to_estimate(pick.id, big - 1)
	await frames(1)
	var t := w.estimate_total()
	check(int(bus.wrist_estimate[pick.id]) == big, "an estimate isn't limited by stock: %d" % big)
	check(t.cost == bus.listing_cost(pick, big) and t.cost < pick.unit_price * big, "costed less bulk: %d of %d" % [t.cost, pick.unit_price * big])
	var shown := w.find_child("EstimateTotal", true, false) as Label
	check(shown != null and shown.text == "%s CR" % T_money(t.cost), "the total shows: %s" % (shown.text if shown else "none"))

	var cash := bus.get_cash()
	var orders := bus.get_orders().size()
	check(bus.get_cash() == cash and bus.get_orders().size() == orders, "nothing ordered or paid")

	# Closing keeps it; it is still there when reopened.
	w.toggle_estimator()
	await frames(1)
	check(not w.estimating and w.find_child("PlaceOrder", true, false) != null, "CLOSE brings back the purchase order")
	w.toggle_estimator()
	await frames(1)
	check(int(bus.wrist_estimate.get(pick.id, 0)) == big, "the estimate is kept")

	# ORDER THESE: onto the purchase order, as many as are in stock.
	w.order_estimate()
	await frames(1)
	check(int(bus.wrist_basket.get(pick.id, 0)) == pick.available, "ORDER THESE fills the order up to stock: %d" % int(bus.wrist_basket.get(pick.id, 0)))
	check(not w.estimating and str(w.get("_message")).contains("not in stock"), "and says what's short: %s" % w.get("_message"))

	# The cheapest supplier for the same part is noted.
	var by_key := {}
	for l in bus.get_listings():
		var key := "%s|%s" % [l.part, l.condition]
		if by_key.has(key) and (by_key[key] as MarketListing).unit_price != l.unit_price:
			var dear: MarketListing = l if l.unit_price > (by_key[key] as MarketListing).unit_price else by_key[key]
			w.clear_estimate()
			w.add_to_estimate(dear.id, 1)
			check(w.estimate_total().cheaper > 0, "a dearer supplier's line shows a saving elsewhere")
			break
		by_key[key] = l
	w.clear_estimate()
	check(bus.wrist_estimate.is_empty(), "CLEAR empties it")
	_done(w, saved)


func T_money(n: int) -> String:
	return (load("res://modules/ui/api/terminal_kit.gd") as GDScript).call("money", n)


func _done(w: Node, saved: Dictionary) -> void:
	w.queue_free()
	Flags.use(saved)
	Modules.load_all()
