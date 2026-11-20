extends ModuleTest
## Contracts: ship contracts (plan 4.3 to 4.6). BSX quotes a design for a ship order, the
## client signs it off and pays in stages (deposit, keel, fit-out, delivery), the surveyors'
## trial moves the delivery payment and standing with the client, and the accounts screen
## reads each open contract's payment profile.
##   tools/run_tests.sh contracts


func run_tests() -> void:
	_quote()
	_plan()
	_trial()
	_flow()


func _order() -> Dictionary:
	for o: Dictionary in ShipOrders.for_cycle(5):
		if not o.locked:
			return o
	return ShipOrders.for_cycle(5)[0]


func _quote() -> void:
	var o := _order()
	var budget := int(o.budget)
	var cheap := ShipOrders.quote(o, budget * 0.5)
	check(int(cheap.price) <= budget and int(cheap.price) >= int(budget * 0.5), "a quote is the build plus the yard's fee, never over the budget")
	check(int(cheap.margin) == int(cheap.price) - int(cheap.cost) and not cheap.over_budget, "the margin is what is left over the build")
	var dear := ShipOrders.quote(o, budget * 1.3)
	check(dear.over_budget and int(dear.price) <= budget and int(dear.margin) < 0, "a build dearer than the budget loses the yard money, and says so")


func _plan() -> void:
	var total := 0.0
	for st: Dictionary in ShipOrders.PAYMENT_STAGES:
		total += float(st.share)
	check(is_equal_approx(total, 1.0), "the stages add up to the whole price")
	var plan := ShipOrders.payment_plan(1_234_567, 10, 50)
	var sum := 0
	for st: Dictionary in plan:
		sum += int(st.value)
		check(str(st.trigger) != "", "stage %s says what sets it off" % st.id)
	check(sum == 1_234_567, "the payments add up to the price exactly: %d" % sum)
	check(plan.size() == 4 and plan[0].id == "deposit" and plan[3].id == "delivery", "deposit first, delivery last")
	check(int(plan[0].expected_day) == 10 and int(plan[3].expected_day) == 50 and int(plan[1].expected_day) < int(plan[2].expected_day),
			"stages fall due in order between signing and the due day")
	check(int(plan[3].value) > int(plan[1].value), "the delivery is the biggest payment")


func _trial() -> void:
	var rows := [
		{"key": "speed", "label": "Speed", "need": 100.0, "have": 140.0, "ok": true, "share": 1.0},
		{"key": "crew", "label": "Crew", "need": 6.0, "have": 6.0, "ok": true, "share": 1.0},
		{"key": "budget", "label": "Cost", "need": 1000.0, "have": 500.0, "ok": true, "share": 1.0},
		{"key": "clause:medbay", "label": "Medbay", "need": 1.0, "have": 1.0, "ok": true, "share": 1.0, "clause": true},
	]
	var good := ShipOrders.trial(rows, 1_000_000)
	check(good.met and good.grade == "A" and good.beats == ["Speed"], "a ship to spec that beats one demand by a quarter: grade A, one beat")
	check(int(good.bonus) == 30_000 and int(good.adjustment) == 30_000, "beating a demand earns a bonus on delivery")
	check(int(good.standing) > ShipOrders.STANDING_DELIVERED, "and more standing than a plain delivery")
	rows[1] = {"key": "crew", "label": "Crew", "need": 6.0, "have": 4.0, "ok": false, "share": 0.66}
	var miss := ShipOrders.trial(rows, 1_000_000, 3)
	check(not miss.met and miss.misses == ["Crew"] and int(miss.holdback) == 50_000 and int(miss.late) == 30_000,
			"a miss holds back a share and days late take theirs")
	check(miss.grade != "A" and int(miss.standing) < int(good.standing), "a miss costs grade and standing")
	var r := ShipOrders.trial_range(_order(), 1_000_000)
	check(int(r.bonus) > 0 and int(r.holdback) > 0, "an order shows what the trial could add and take away")


func _flow() -> void:
	var bus := Modules.bus("contracts") as ContractsBus
	if bus == null or not Flags.is_on(ContractsBus.SHIP_CONTRACTS_FLAG) or not Flags.is_on(ContractsBus.SHIP_ORDERS_FLAG):
		return
	var order := {}
	for o: Dictionary in bus.ship_orders():
		if bus.ship_sign_problem(o) == "":
			order = o
			break
	if order.is_empty():
		check(false, "an order on the board can be signed")
		return
	var staged: Array = []
	var paid: Array = []
	var adjusted: Array = []
	var handed: Array = []
	var on_staged := func(id: String, stages: Array, due: int) -> void: staged.append([id, stages, due])
	var on_paid := func(id: String, st: String) -> void: paid.append(st)
	var on_adj := func(id: String, amount: int, why: String) -> void: adjusted.append(amount)
	var on_hand := func(id: String, q: float, snags: int) -> void: handed.append(id)
	bus.contract_accepted_staged.connect(on_staged)
	bus.stage_signed_off.connect(on_paid)
	bus.contract_adjusted.connect(on_adj)
	bus.contract_handed_over.connect(on_hand)
	var cost := int(float(order.budget) * 0.6)
	bus.request_sign_ship(order, "d1", "Test design", cost)
	var c := bus.ship_contract_for(str(order.id))
	check(not c.is_empty() and c.state == "building", "the client signs the quote: a ship contract")
	check(staged.size() == 1 and (staged[0][1] as Array).size() == 4 and int(staged[0][2]) == int(c.due_day),
			"Business hears of it with its four stages and due day")
	check(bus.ship_sign_problem(order) != "", "an order is signed once")
	var prof := bus.payment_profiles()
	check(prof.size() >= 1 and str(prof[0].contract_id) == str(c.id) and bool(prof[0].stages[0].paid) and not bool(prof[0].stages[1].paid),
			"the payment profile has the deposit paid and the keel to come")
	check(int(prof[0].parts_to_buy) == cost and prof[0].trial.has("bonus"), "and the parts to buy and the trial's range")
	check(not bus.pay_ship_stage(str(c.id), "fit_out"), "stages are paid in order")
	check(bus.pay_ship_stage(str(c.id), "keel") and paid == ["keel"], "the keel is paid when it is laid")
	var saved := bus.save_data()
	bus.load_data(saved, ContractsBus.SAVE_VERSION)
	check(bool(bus.ship_contract(str(c.id)).stages[1].paid), "ship contracts are saved")
	bus.track_build(str(c.id))
	bus._pay_due_stages(int(c.due_day) + 5)
	check(bus.is_build_tracked(str(c.id)) and paid == ["keel"], "a contract the build tracks is left to the build: the stand-in pays nothing")
	var asked: Array = []
	bus.register_trial_rows("test", func(id: String) -> Array:
		asked.append(id)
		return [{"key": "workmanship", "label": "Workmanship", "need": 1.0, "have": 1.0, "ok": true, "share": 1.0}])
	var client := str(order.client)
	var before := bus.standing_of(client)
	var rows := [{"key": "speed", "label": "Speed", "need": 10.0, "have": 20.0, "ok": true, "share": 1.0}]
	bus.request_deliver_ship(str(c.id), rows)
	c = bus.ship_contract(str(c.id))
	check(c.state == "delivered" and paid == ["keel", "fit_out"], "delivery pays any stage still owed first")
	check(asked == [str(c.id)], "the trial asks other modules for their rows (the build's workmanship)")
	bus.register_trial_rows("test", Callable())
	check(adjusted.size() == 1 and adjusted[0] > 0 and handed == [str(c.id)], "the trial's bonus comes before the handover")
	check(bus.standing_of(client) > before, "a ship delivered to spec raises standing with the client")
	check(bus.payment_profiles().all(func(p: Dictionary) -> bool: return p.contract_id != c.id), "a delivered contract leaves the forecast")
	bus.contract_accepted_staged.disconnect(on_staged)
	bus.stage_signed_off.disconnect(on_paid)
	bus.contract_adjusted.disconnect(on_adj)
	bus.contract_handed_over.disconnect(on_hand)
