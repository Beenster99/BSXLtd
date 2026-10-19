extends ModuleTest
## Business: quotes, orders and deliveries, contract money, rent and penalties, reputation,
## insolvency and the save round trip.
##   tools/run_tests.sh business

var bus: BusinessBus
var events: Array[String] = []


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "business": true})
	Modules.load_all()
	bus = Modules.bus("business") as BusinessBus
	check(bus != null, "business bus loads when its flag is on")
	if bus == null:
		Flags.use(saved)
		Modules.load_all()
		return
	for sig in ["order_placed", "order_delayed", "delivery_arrived", "rent_charged",
			"penalty_applied", "insolvency_warning", "went_insolvent"]:
		bus.connect(sig, func(_a = null, _b = null, _c = null): events.append(sig))

	var kessler := _supplier("kessler_fasteners")
	var reliability := kessler.reliability
	_test_fresh_company()
	_test_quotes()
	_test_orders(kessler)
	_test_contracts()
	_test_insolvency()
	_test_saves()
	kessler.reliability = reliability

	bus.reset()
	Flags.use(saved)
	Modules.load_all()


func _test_fresh_company() -> void:
	var rules := bus.get_rules()
	check(bus.get_cash() == rules.starting_cash, "starts with the starting cash")
	check(is_equal_approx(bus.get_reputation(), rules.starting_reputation), "starts with the starting reputation")
	check(bus.get_day() == 0, "starts on day 0")
	var ids := bus.get_suppliers().map(func(s): return s.id)
	check("kessler_fasteners" in ids and "orbital_surplus" in ids, "open suppliers listed: %s" % str(ids))
	check(not ids.has("halden_drive"), "reputation-gated supplier hidden at the start")


func _test_quotes() -> void:
	var q := bus.quote("kessler_fasteners", _lines("M10", 100))
	check(q.ok and q.cost == 200, "fasteners priced from the price list: %d" % q.cost)
	check(q.eta_day == 1, "24 hour lead time arrives next day")
	q = bus.quote("orbital_surplus", _lines("DeckPlate", 2))
	check(q.ok and q.cost == 288 and q.eta_day == 3, "surplus discount and 72 hour lead: %d day %d" % [q.cost, q.eta_day])
	check(not bus.quote("kessler_fasteners", _lines("IonThruster", 1)).ok, "can't buy what a supplier doesn't sell")
	check(not bus.quote("halden_drive", _lines("IonThruster", 1)).ok, "can't buy from a hidden supplier")
	check(not bus.quote("kessler_fasteners", _lines("M10", 0)).ok, "zero quantity refused")


func _test_orders(kessler: SupplierDef) -> void:
	bus.reset()
	events.clear()
	var start := bus.get_cash()
	var r := bus.place_order("kessler_fasteners", _lines("M10", 100))
	check(r.is_ok() and r.order_id != "", "order placed")
	check(bus.get_cash() == start - 200, "order paid on placing")
	check(bus.get_ledger().back().category == LedgerEntry.PARTS, "ledger shows the parts spend")
	check("order_placed" in events, "order_placed emitted")

	var too_big := bus.place_order("orbital_surplus", _lines("DeckPlate", 1000))
	check(not too_big.is_ok() and bus.get_cash() == start - 200, "unaffordable order refused, nothing charged")

	kessler.reliability = 1.0
	bus.advance_day()
	check(bus.get_order(r.order_id).state == PartsOrder.State.DELIVERED, "reliable order arrives on time")
	check(bus.get_stock().get("M10") == 100, "delivered parts go into stock")
	check("rent_charged" in events and bus.get_cash() == start - 200 - 400, "bay rent charged each day")
	check(bus.use_stock("M10", 40).is_ok() and bus.get_stock().M10 == 60, "fitting uses stock")
	check(not bus.use_stock("M10", 61).is_ok() and bus.get_stock().M10 == 60, "can't use more than is in stock")

	kessler.reliability = 0.0
	var late := bus.place_order("kessler_fasteners", _lines("M12", 10))
	bus.advance_day()
	check(bus.get_order(late.order_id).delayed and "order_delayed" in events, "unreliable order delayed once")
	bus.advance_day()
	check(bus.get_order(late.order_id).state == PartsOrder.State.DELIVERED, "delayed order arrives next day")
	check(bus.get_stock().get("M12") == 9, "one damaged item kept out of stock")

	var cancelled := bus.place_order("kessler_fasteners", _lines("M10", 50))
	var before := bus.get_cash()
	check(bus.cancel_order(cancelled.order_id).is_ok(), "open order cancelled")
	check(bus.get_cash() == before + 75, "cancellation refunds the supplier's share")
	check(not bus.cancel_order(cancelled.order_id).is_ok(), "can't cancel twice")


func _test_contracts() -> void:
	bus.reset()
	events.clear()
	var start := bus.get_cash()
	check(bus.on_contract_accepted("VS-1", 10000, 1).is_ok(), "contract accepted")
	check(bus.get_cash() == start + 3000, "30% deposit on acceptance")
	check(not bus.on_contract_accepted("VS-1", 10000, 1).is_ok(), "same contract can't be booked twice")
	bus.place_order("kessler_fasteners", _lines("M10", 100), "VS-1")

	for i in 3:
		bus.advance_day()
	var bal := bus.get_contract_balance("VS-1")
	check(bal.penalties == 500 and "penalty_applied" in events, "late penalties after the due day: %d" % bal.penalties)
	check(bal.parts == 200 and bal.margin == 10000 - 500 - 200, "contract margin counts parts and penalties")

	var cash := bus.get_cash()
	var rep := bus.get_reputation()
	check(bus.on_contract_handed_over("VS-1", 0.9, 1).is_ok(), "contract handed over")
	check(bus.get_cash() == cash + 10000 - 3000 - 500, "final payment less deposit and penalties")
	# (0.9 - 0.6) * 20 - 2 days late * 2 - 1 snag * 1 = 1
	check(is_equal_approx(bus.get_reputation(), rep + 1.0), "reputation from quality, lateness and snags: %f" % bus.get_reputation())
	check(not bus.on_contract_handed_over("VS-1", 0.9, 0).is_ok(), "can't hand over twice")

	bus.on_contract_accepted("VS-2", 2000, 10)
	cash = bus.get_cash()
	rep = bus.get_reputation()
	check(bus.on_contract_cancelled("VS-2", false).is_ok(), "BSX can walk away")
	check(bus.get_cash() == cash - 600 and is_equal_approx(bus.get_reputation(), rep - 5.0), "walking away returns the deposit and costs reputation")
	bus.on_contract_accepted("VS-3", 2000, 10)
	cash = bus.get_cash()
	bus.on_contract_cancelled("VS-3", true)
	check(bus.get_cash() == cash, "client cancelling forfeits the deposit")

	# Late penalties stop at the cap (25% of 2000 = 500).
	bus.on_contract_accepted("VS-4", 2000, bus.get_day())
	for i in 5:
		bus.advance_day()
	check(bus.get_contract_balance("VS-4").penalties == 500, "late penalties capped")


func _test_insolvency() -> void:
	bus.reset()
	events.clear()
	check(bus.charge(bus.get_cash(), LedgerEntry.UPGRADE).is_ok(), "charge spends cash")
	check(not bus.charge(1, LedgerEntry.UPGRADE).is_ok(), "charge refuses to overdraw")
	for i in bus.get_rules().insolvency_grace_days - 1:
		bus.advance_day()
	check("insolvency_warning" in events and not bus.is_insolvent(), "warnings during the grace period")
	bus.advance_day()
	check(bus.is_insolvent() and "went_insolvent" in events, "insolvent after the grace period")
	check(not bus.place_order("kessler_fasteners", _lines("M10", 1)).is_ok(), "an insolvent company can't order")


func _test_saves() -> void:
	bus.reset()
	_supplier("kessler_fasteners").reliability = 1.0
	bus.on_contract_accepted("VS-9", 5000, 4)
	var r := bus.place_order("kessler_fasteners", _lines("M10", 10), "VS-9")
	bus.advance_day()
	bus.place_order("orbital_surplus", _lines("DeckPlate", 1))
	# Through JSON, as Saves writes it.
	var data: Dictionary = JSON.parse_string(JSON.stringify(bus.save_data()))
	var cash := bus.get_cash()
	var ledger_size := bus.get_ledger().size()
	bus.reset()
	bus.load_data(data, bus.save_version())
	check(bus.get_cash() == cash and bus.get_day() == 1, "cash and day restored")
	check(bus.get_ledger().size() == ledger_size, "ledger restored")
	check(bus.get_order(r.order_id).state == PartsOrder.State.DELIVERED, "orders restored")
	check(bus.get_stock().get("M10") == 10, "stock restored")
	check(bus.get_contract_balance("VS-9").deposit == 1500, "contracts restored")
	var next := bus.place_order("kessler_fasteners", _lines("M10", 1))
	check(next.order_id == "PO-0003", "order numbers carry on after a load: %s" % next.order_id)


func _supplier(id: String) -> SupplierDef:
	return load("res://modules/business/internal/data/suppliers/%s.tres" % id)


func _lines(part: String, qty: int) -> Array[OrderLine]:
	var out: Array[OrderLine] = [OrderLine.new(part, qty)]
	return out
