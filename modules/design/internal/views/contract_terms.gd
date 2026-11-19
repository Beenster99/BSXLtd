extends PanelContainer
## The contract details page (Wave 4, staged payments): what a ship order pays and when. The
## price BSX quotes for the open design (its parts at cost and the yard's fee, never over the
## client's budget), each payment with its amount, what sets it off and its day, which are
## paid and which is due next, and what the surveyors' trial can add to the delivery payment
## or take away. Before signing it shows the quote as it would be signed today; after the
## trial, its result. Shown full screen from the design console (CONTRACT DETAILS).

const T := preload("res://modules/ui/api/terminal_kit.gd")

var font := 17
var _body: VBoxContainer


## order: the ship order; contract: ContractsBus.ship_contract ({} before signing); cost: the
## open design's parts at cost; today: the business day.
func setup(order: Dictionary, contract: Dictionary, cost: int, today: int, base_font := 17) -> void:
	font = base_font
	name = "ContractTerms"
	add_theme_stylebox_override("panel", T.box(T.KIOSK, T.EDGE, 2, font * 0.7))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", _s(0.6))
	scroll.add_child(_body)
	_fill(order, contract, cost, today)


func _s(k: float) -> int:
	return int(roundf(font * k))


func _fill(order: Dictionary, contract: Dictionary, cost: int, today: int) -> void:
	var signed := not contract.is_empty()
	var price := int(contract.price) if signed else int(ShipOrders.quote(order, cost).price)
	var built_cost := int(contract.cost) if signed else cost
	var budget := int(order.get("budget", order.get("demands", {}).get("budget", 0)))
	var stages: Array = contract.stages if signed \
			else ShipOrders.payment_plan(price, today, today + maxi(1, int(order.get("days", 30))))
	# The order and where the contract stands.
	_body.add_child(T.label(str(order.get("title", "Ship order")), "display_bold", _s(1.6), T.TEXT))
	var who := "%s · %s" % [str(order.get("client_name", "")).to_upper(), str(ShipOrders.SIZES.get(str(order.get("size", "")), {}).get("name", "")).to_upper()]
	_body.add_child(T.label(who, "mono_medium", _s(0.85), T.DIM))
	var state := "QUOTE: as it would be signed today (day %d). The client signs off the design and pays the deposit." % today
	var colour := T.CYAN
	if signed and contract.state == "delivered":
		state = "DELIVERED on day %d. The trial is done and every payment is in." % int(contract.trial.get("day", today))
		colour = T.GOOD
	elif signed:
		state = "SIGNED on day %d for the design \"%s\". Due day %d (%s)." % [int(contract.start_day), str(contract.design_name),
				int(contract.due_day), _days_left(int(contract.due_day) - today)]
		colour = T.ORANGE
	_body.add_child(_wrap(state, "body_medium", _s(1.0), colour))
	_body.add_child(T.HazardRule.new(font * 0.35))
	# The money.
	var figs := HBoxContainer.new()
	figs.add_theme_constant_override("separation", _s(0.5))
	for f: Array in [["PRICE", price, T.TEXT], ["CLIENT'S BUDGET", budget, T.DIM], ["BUILD AT COST", built_cost, T.DIM],
			["YARD'S MARGIN", price - built_cost, T.GOOD if price >= built_cost else T.BAD]]:
		var fig := T.figure(str(f[0]), "CR " + T.money(int(f[1])), f[2])
		fig.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		figs.add_child(fig)
	_body.add_child(figs)
	if built_cost > budget and budget > 0:
		_body.add_child(_wrap("The build costs more than the client will pay: the price stops at the budget and the yard makes a loss of CR %s." %
				T.money(built_cost - price), "body_medium", _s(0.95), T.BAD))
	# The payments.
	_body.add_child(_heading("PAYMENTS"))
	var next := ""
	for st: Dictionary in stages:
		if not signed or not bool(st.get("paid", false)):
			next = str(st.id)
			break
	for st: Dictionary in stages:
		_body.add_child(_stage_row(st, signed, next, today, contract))
	# The trial.
	_body.add_child(_heading("THE TRIAL"))
	if signed and contract.state == "delivered":
		_trial_result(contract.trial, stages.back())
	else:
		_trial_terms(order, price, stages.back())


func _days_left(n: int) -> String:
	if n > 0:
		return "%d days to go" % n
	return "due today" if n == 0 else "%d days late" % -n


func _stage_row(st: Dictionary, signed: bool, next: String, today: int, contract: Dictionary) -> Control:
	var paid := bool(st.get("paid", false))
	var status := "DUE LATER"
	var colour := T.DIM
	if paid:
		var amount := int(st.get("paid_value", st.value))
		status = "PAID DAY %d" % int(st.paid_day) + ("  ·  CR %s" % T.money(amount) if amount != int(st.value) else "")
		colour = T.GOOD
	elif str(st.id) == next:
		status = "NEXT DUE" if signed else "ON SIGNING"
		colour = T.ORANGE
		if signed and int(st.expected_day) < today and contract.get("state", "") == "building":
			status = "OVERDUE"
			colour = T.BAD
	if not signed and str(st.id) == "deposit":
		status = "ON SIGNING"
		colour = T.ORANGE
	var cells := [
		T.cell_text(str(st.name).to_upper(), str(st.trigger)),
		T.cell("%d%%" % roundi(float(st.share) * 100.0), _s(4.0), T.DIM),
		T.cell("CR " + T.money(int(st.value)), _s(9.0), T.TEXT, "mono_medium"),
		T.cell("day %d" % int(st.expected_day), _s(5.5), T.DIM),
		T.cell(status, _s(15.0), colour, "mono_medium"),
	]
	(cells[0] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := T.row(cells, str(st.id) == next)
	row.name = "Stage_" + str(st.id)
	return row


func _trial_terms(order: Dictionary, price: int, delivery: Dictionary) -> void:
	var r := ShipOrders.trial_range(order, price)
	var value := int(delivery.value)
	var lines := [
		"The surveyors test the finished ship against every demand and clause before the delivery payment of CR %s is made." % T.money(value),
		"Each demand beaten by %d%% or more: + %d%% of the price (CR %s), up to %d of them: up to + CR %s." % [
			roundi(ShipOrders.BEAT_BY * 100.0), roundi(ShipOrders.BONUS_PER_BEAT * 100.0), T.money(roundi(price * ShipOrders.BONUS_PER_BEAT)),
			ShipOrders.BONUS_MAX, T.money(int(r.bonus))],
		"Each demand or clause missed: %d%% of the price held back (CR %s), lost if she is handed over anyway. Missing all %d: - CR %s." % [
			roundi(ShipOrders.HOLDBACK_PER_MISS * 100.0), T.money(roundi(price * ShipOrders.HOLDBACK_PER_MISS)),
			ShipOrders.criteria_count(order), T.money(mini(int(r.holdback), value))],
		"Each day late: %d%% of the price (CR %s)." % [roundi(ShipOrders.LATE_PER_DAY * 100.0), T.money(roundi(price * ShipOrders.LATE_PER_DAY))],
	]
	for l: String in lines:
		_body.add_child(_wrap(l, "body", _s(0.95), T.TEXT))
	var low := maxi(0, value - int(r.holdback))
	_body.add_child(_wrap("The delivery payment: CR %s at best, CR %s on spec, CR %s at worst (on time)." % [
			T.money(value + int(r.bonus)), T.money(value), T.money(low)], "body_medium", _s(1.0), T.CYAN))
	_body.add_child(_wrap("Standing with the client: + %d for a ship to spec, + %d for each demand beaten, - %d for each miss, - %d a day late." % [
			ShipOrders.STANDING_DELIVERED, ShipOrders.STANDING_PER_BEAT, ShipOrders.STANDING_PER_MISS, ShipOrders.STANDING_PER_LATE],
			"body", _s(0.9), T.DIM))


func _trial_result(t: Dictionary, delivery: Dictionary) -> void:
	var grade_colour := T.GOOD if str(t.grade) in ["A", "B"] else (T.AMBER if str(t.grade) == "C" else T.BAD)
	_body.add_child(T.label("GRADE %s" % str(t.grade), "display_bold", _s(1.4), grade_colour))
	if not (t.beats as Array).is_empty():
		_body.add_child(_wrap("Beat the order on %s: + CR %s." % [", ".join(t.beats), T.money(int(t.bonus))], "body", _s(0.95), T.GOOD))
	if not (t.misses as Array).is_empty():
		_body.add_child(_wrap("Missed %s: CR %s held back." % [", ".join(t.misses), T.money(int(t.holdback))], "body", _s(0.95), T.BAD))
	if int(t.late) > 0:
		_body.add_child(_wrap("%d days late: - CR %s." % [int(t.days_late), T.money(int(t.late))], "body", _s(0.95), T.BAD))
	_body.add_child(_wrap("Delivery payment: CR %s (CR %s on spec). Standing with the client %s%d." % [
			T.money(int(delivery.get("paid_value", delivery.value))), T.money(int(delivery.value)),
			"+" if int(t.standing) >= 0 else "", int(t.standing)], "body_medium", _s(1.0), T.CYAN))


func _heading(text: String) -> Label:
	return T.label(text, "display_medium", _s(1.05), T.DIM)


func _wrap(text: String, face: String, size: int, colour: Color) -> Label:
	var l := T.label(text, face, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
