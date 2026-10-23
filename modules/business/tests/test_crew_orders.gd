extends ModuleTest
## Crew orders (0.3.16 playtest): only the host keeps the books, so a crew member's market
## order or cancellation goes to the host as a request, the host checks and places it, and
## everyone gets the host's books back (on joining too).
##   tools/run_tests.sh business


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "multiplayer": true,
			"business": true, "business.market": true, "business.economy": true})
	Modules.load_all()
	var bus := Modules.bus("business") as BusinessBus
	var net := Modules.bus("multiplayer")
	check(bus != null and net != null, "business and multiplayer load")
	if bus == null or net == null:
		Flags.use(saved)
		Modules.load_all()
		return
	bus.reset()
	bus.test_crew = {1: "Ana", 2: "Ben"}
	var refused: Array[String] = []
	bus.order_refused.connect(func(why: String) -> void: refused.append(why))
	var picks := bus.get_listings().filter(func(l: MarketListing) -> bool:
			return not l.id.begins_with("S-") and l.available >= 2 and l.unit_price < 5000)
	check(picks.size() >= 1, "something on the market to buy")
	if picks.is_empty():
		_done(saved)
		return

	# The host checks what a crew member sends.
	var ok: Variant = bus.call("_validate_order", 2, {"kind": "market", "basket": [{"listing_id": picks[0].id, "qty": 1}]})
	check(ok is Dictionary and ok.kind == "market", "the host accepts Ben's order: %s" % str(ok))
	var bad: Variant = bus.call("_validate_order", 2, {"kind": "market", "basket": [{"listing_id": "nope", "qty": 1}]})
	check(bad is String and bad != "", "an unknown listing is refused: %s" % str(bad))
	var big: Variant = bus.call("_validate_order", 2, {"kind": "market", "basket": [{"listing_id": picks[0].id, "qty": 100000}]})
	check(big is String, "more than the market holds is refused: %s" % str(big))
	check(bus.call("_validate_order", 2, {"kind": "cancel", "order": "PO-none"}) is String, "an unknown order can't be cancelled")
	check(bus.call("_validate_order", 9, {"kind": "market", "basket": []}) is String, "someone who isn't here is refused")

	# Sent through Multiplayer (a session of one applies at once): the host places it.
	var orders_before := bus.get_orders(PartsOrder.State.PLACED).size()
	var cash := bus.get_cash()
	net.call("request", BusinessBus.ORDER_EVENT, {"kind": "market", "basket": [{"listing_id": picks[0].id, "qty": 1}], "contract": ""})
	var open := bus.get_orders(PartsOrder.State.PLACED)
	check(open.size() == orders_before + 1 and bus.get_cash() < cash, "the host places a crew order: %d -> %d" % [orders_before, open.size()])
	if open.size() > orders_before:
		var id: String = open.back().id
		net.call("request", BusinessBus.ORDER_EVENT, {"kind": "cancel", "order": id})
		check(bus.get_orders(PartsOrder.State.PLACED).size() == orders_before, "and cancels one")
	net.call("request", BusinessBus.ORDER_EVENT, {"kind": "market", "basket": [{"listing_id": "nope", "qty": 1}]})
	check(refused.size() == 1, "a refusal reaches the screen as order_refused: %s" % str(refused))

	# Everyone else gets the host's books: on joining, and with every change after.
	bus.place_market_order([{"listing_id": picks[0].id, "qty": 1}])
	var snap := bus.get_net_snapshot()
	check(snap.has("books"), "the join snapshot carries the books")
	var host_cash := bus.get_cash()
	var host_orders := bus.get_orders(PartsOrder.State.PLACED).size()
	var host_left := bus.get_listing(picks[0].id).available
	bus.reset()
	bus.apply_net_snapshot(snap)
	check(bus.get_cash() == host_cash and bus.get_orders(PartsOrder.State.PLACED).size() == host_orders,
			"a joining player sees the host's cash and orders")
	check(bus.get_listing(picks[0].id) != null and bus.get_listing(picks[0].id).available == host_left,
			"and the host's market")
	_done(saved)


func _done(saved: Dictionary) -> void:
	var bus := Modules.bus("business") as BusinessBus
	if bus:
		bus.test_crew = {}
		bus.reset()
	Flags.use(saved)
	Modules.load_all()
