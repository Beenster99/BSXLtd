extends ModuleTest
## Design Room: a ship order's contract from the console (Wave 4, plan 4.3 to 4.6). The
## design is quoted against the order, SEND QUOTE signs it (the deposit paid), CONTRACT
## DETAILS shows each payment with its amount, trigger and state and what the trial can do,
## and DELIVER FOR TRIAL scores the design and pays the delivery.
##   tools/run_tests.sh design

const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")
const DesignConsole := preload("res://modules/design/internal/console/design_console.gd")


func run_tests() -> void:
	_motion_rows()
	var contracts := Modules.bus("contracts") as ContractsBus
	if contracts == null or not Flags.is_on(ContractsBus.SHIP_CONTRACTS_FLAG) or not Flags.is_on(ContractsBus.SHIP_ORDERS_FLAG):
		check(true, "ship contracts are off")
		return
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	var holo := HoloTable.new()
	add_child(holo)
	holo.setup(bus)
	var layer := CanvasLayer.new()
	add_child(layer)
	var console := DesignConsole.new()
	layer.add_child(console)
	console.setup(bus, holo)
	await frames(2)
	var order := {}
	for o: Dictionary in contracts.ship_orders():
		if contracts.ship_sign_problem(o) == "":
			order = o
			break
	check(not order.is_empty(), "an order on the board can be signed")
	if order.is_empty():
		return
	console.set_order(order)
	await frames(1)
	var rec := bus.library.current
	var send := console.find_child("SendQuote", true, false) as Button
	var quote := console.find_child("QuoteLine", true, false) as Label
	check(send != null and not send.disabled and quote != null and quote.text.begins_with("QUOTE"), "the order shows the quote and SEND QUOTE")
	console.toggle_contract_terms()
	var page := console.find_child("ContractTerms", true, false)
	check(page != null and page.find_child("Stage_deposit", true, false) != null and page.find_child("Stage_delivery", true, false) != null,
			"CONTRACT DETAILS shows the payments before signing")
	console.toggle_contract_terms()
	await frames(1)
	send.pressed.emit()
	await frames(1)
	var c := contracts.ship_contract_for(str(order.id))
	check(not c.is_empty() and str(c.design_id) == rec.id, "SEND QUOTE signs the contract for this design")
	check(int(c.price) <= int(order.budget) and bool(c.stages[0].paid), "at no more than the budget, the deposit paid")
	check(console.find_child("DeliverTrial", true, false) != null and console.find_child("SendQuote", true, false) == null,
			"once signed the console offers DELIVER FOR TRIAL")
	console.toggle_contract_terms()
	page = console.find_child("ContractTerms", true, false)
	var labels := _texts(page)
	check(labels.contains("PAID DAY") and labels.contains("NEXT DUE") and labels.contains("THE TRIAL"),
			"the details page says which payments are paid and which is due next, and what the trial does")
	console.toggle_contract_terms()
	console.deliver_for_trial()
	await frames(2)
	c = contracts.ship_contract_for(str(order.id))
	check(c.state == "delivered" and not (c.trial as Dictionary).is_empty(), "DELIVER FOR TRIAL puts her through the trial")
	check(str(c.trial.grade) in ["A", "B", "C", "D", "E"] and (c.stages as Array).all(func(st: Dictionary) -> bool: return st.paid),
			"she gets a grade and every payment is in: %s" % [c.trial])
	console.toggle_contract_terms()
	labels = _texts(console.find_child("ContractTerms", true, false))
	check(labels.contains("GRADE") and labels.contains("DELIVERED"), "the details page shows the trial's result")
	console.toggle_contract_terms()


func _texts(n: Node) -> String:
	var out := ""
	if n == null:
		return out
	if n is Label:
		out += (n as Label).text + "\n"
	for c in n.get_children():
		out += _texts(c)
	return out


## The surveyors' cycle of the moving parts reads as two trial rows.
func _motion_rows() -> void:
	check(DesignContractCheck.motion_rows({}).is_empty(), "nothing moves, no legs: no motion rows")
	var rows := DesignContractCheck.motion_rows({"parts": [{"name": "Ramp", "clear": true}, {"name": "Bay doors", "clear": false}],
			"ground": {"legs": 3, "problems": [{"severity": DesignRules.ERROR, "text": "tips"}]}})
	check(rows.size() == 2 and not rows[0].ok and rows[0].notes == ["Bay doors"] and not rows[1].ok,
			"a part that clashes or a ship that tips fails its trial row")
	var ok := DesignContractCheck.motion_rows({"parts": [{"name": "Ramp", "clear": true}], "ground": {"legs": 4, "problems": []}})
	check(ok.all(func(r: Dictionary) -> bool: return r.ok), "parts that move clear and a ship that stands pass")
	var t := ShipOrders.trial(rows, 1_000_000)
	check((t.misses as Array).has("Moving parts cycle clear"), "the trial counts a clash as a miss")
