extends RefCounted
## The company's books: cash, ledger, orders, contracts, reputation and the business day.
## Owned by BusinessBus, which is the only caller; signals go out through the bus.

const SAVE_VERSION := 1

var rules: BusinessRules
var prices: PriceList
var suppliers: Dictionary = {}  # id -> SupplierDef
var rng := RandomNumberGenerator.new()

var day := 0
var cash := 0
var reputation := 50.0
var ledger: Array[LedgerEntry] = []
var orders: Dictionary = {}  # id -> PartsOrder
## Contract id -> {value, due_day, deposit, penalties, state}; state is open, done or cancelled.
var contracts: Dictionary = {}
var stock: Dictionary = {}  # part -> count delivered and not yet used
var days_in_debt := 0
var insolvent := false

var _bus: Node
var _next_order := 1


func _init(bus: Node, p_rules: BusinessRules, p_prices: PriceList, p_suppliers: Array) -> void:
	_bus = bus
	rules = p_rules
	prices = p_prices
	for s in p_suppliers:
		suppliers[s.id] = s
	reset()


## A fresh company: starting cash and reputation, day 0, nothing on the books.
func reset() -> void:
	day = 0
	cash = rules.starting_cash
	reputation = rules.starting_reputation
	ledger = []
	orders = {}
	contracts = {}
	stock = {}
	days_in_debt = 0
	insolvent = false
	_next_order = 1
	rng.randomize()


# --- Money ---

func post(amount: int, category: String, ref := "", note := "") -> void:
	var e := LedgerEntry.new()
	e.day = day
	e.amount = amount
	e.category = category
	e.ref = ref
	e.note = note
	ledger.append(e)
	cash += amount
	_bus.ledger_entry_added.emit(e)
	_bus.cash_changed.emit(cash, amount, category)


# --- Suppliers and orders ---

func visible_suppliers() -> Array[SupplierDef]:
	var out: Array[SupplierDef] = []
	var ids := suppliers.keys()
	ids.sort()
	for id in ids:
		if reputation >= suppliers[id].min_reputation:
			out.append(suppliers[id])
	return out


func quote(supplier_id: String, lines: Array[OrderLine]) -> PartsQuote:
	var q := PartsQuote.new()
	var s: SupplierDef = suppliers.get(supplier_id)
	if s == null or reputation < s.min_reputation:
		q.reason = "unknown supplier %s" % supplier_id
		return q
	if lines.is_empty():
		q.reason = "nothing to order"
		return q
	for line in lines:
		var base := prices.price_of(line.part)
		if not s.sells(line.part) or base < 0:
			q.reason = "%s does not sell %s" % [s.display_name, line.part]
			return q
		if line.qty < 1:
			q.reason = "quantity of %s must be at least 1" % line.part
			return q
		q.cost += roundi(base * float(s.parts[line.part])) * line.qty
	q.eta_day = day + maxi(1, ceili(s.lead_hours / 24.0))
	q.ok = true
	return q


func place_order(supplier_id: String, lines: Array[OrderLine], contract_id: String) -> BusinessResult:
	if insolvent:
		return BusinessResult.fail(ERR_UNAVAILABLE, "the company is insolvent")
	var q := quote(supplier_id, lines)
	if not q.ok:
		return BusinessResult.fail(ERR_INVALID_PARAMETER, q.reason)
	if q.cost > cash:
		return BusinessResult.fail(ERR_UNAVAILABLE, "not enough cash (%d needed, %d held)" % [q.cost, cash])
	var o := PartsOrder.new()
	o.id = "PO-%04d" % _next_order
	_next_order += 1
	o.supplier_id = supplier_id
	o.lines = lines.duplicate()
	o.cost = q.cost
	o.placed_day = day
	o.eta_day = q.eta_day
	o.contract_id = contract_id
	orders[o.id] = o
	post(-o.cost, LedgerEntry.PARTS, o.id, suppliers[supplier_id].display_name)
	_bus.order_placed.emit(o)
	return BusinessResult.success(o.id)


func cancel_order(order_id: String) -> BusinessResult:
	var o: PartsOrder = orders.get(order_id)
	if o == null:
		return BusinessResult.fail(ERR_DOES_NOT_EXIST, "no order %s" % order_id)
	if o.state != PartsOrder.State.PLACED:
		return BusinessResult.fail(ERR_ALREADY_EXISTS, "order %s already closed" % order_id)
	o.state = PartsOrder.State.CANCELLED
	var s: SupplierDef = suppliers[o.supplier_id]
	var refund := o.cost * s.cancellation_refund_percent / 100
	if refund > 0:
		post(refund, LedgerEntry.REFUND, o.id, "cancelled order")
	_bus.order_cancelled.emit(o, refund)
	return BusinessResult.success()


func _land_orders() -> void:
	var ids := orders.keys()
	ids.sort()
	for id in ids:
		var o: PartsOrder = orders[id]
		if o.state != PartsOrder.State.PLACED or o.eta_day > day:
			continue
		var s: SupplierDef = suppliers[o.supplier_id]
		var on_time := rng.randf() < s.reliability
		if not on_time and not o.delayed:
			o.delayed = true
			o.eta_day = day + 1
			_bus.order_delayed.emit(o)
			continue
		var damaged: Array[OrderLine] = []
		if not on_time:
			damaged.append(OrderLine.new(o.lines[0].part, 1))
		o.state = PartsOrder.State.DELIVERED
		for line in o.lines:
			stock[line.part] = int(stock.get(line.part, 0)) + line.qty
		for line in damaged:
			stock[line.part] -= line.qty
		_bus.delivery_arrived.emit(o, damaged)


# --- Contracts ---

func accept_contract(contract_id: String, value: int, due_day: int) -> BusinessResult:
	if contracts.has(contract_id):
		return BusinessResult.fail(ERR_ALREADY_EXISTS, "contract %s already on the books" % contract_id)
	if value < 0:
		return BusinessResult.fail(ERR_INVALID_PARAMETER, "contract value must not be negative")
	var deposit := value * rules.deposit_percent / 100
	contracts[contract_id] = {"value": value, "due_day": due_day, "deposit": deposit, "penalties": 0, "state": "open"}
	if deposit > 0:
		post(deposit, LedgerEntry.DEPOSIT, contract_id)
	_bus.deposit_received.emit(contract_id, deposit)
	return BusinessResult.success()


func hand_over(contract_id: String, quality: float, open_snags: int) -> BusinessResult:
	var c: Dictionary = contracts.get(contract_id, {})
	if c.is_empty() or c.state != "open":
		return BusinessResult.fail(ERR_DOES_NOT_EXIST, "no open contract %s" % contract_id)
	c.state = "done"
	var payment: int = c.value - c.deposit - c.penalties
	if payment != 0:
		post(payment, LedgerEntry.PAYMENT, contract_id, "handover")
	_bus.final_payment_received.emit(contract_id, payment)
	var late_days := maxi(0, day - int(c.due_day))
	var delta := (clampf(quality, 0.0, 1.0) - rules.quality_par) * rules.rep_per_quality
	delta -= late_days * rules.rep_per_late_day + open_snags * rules.rep_per_open_snag
	change_reputation(delta, "handover %s" % contract_id)
	return BusinessResult.success()


func cancel_contract(contract_id: String, by_client: bool) -> BusinessResult:
	var c: Dictionary = contracts.get(contract_id, {})
	if c.is_empty() or c.state != "open":
		return BusinessResult.fail(ERR_DOES_NOT_EXIST, "no open contract %s" % contract_id)
	c.state = "cancelled"
	# The client walking away forfeits their deposit; BSX walking away returns it and
	# costs reputation.
	if not by_client:
		if c.deposit > 0:
			post(-c.deposit, LedgerEntry.REFUND, contract_id, "deposit returned")
		change_reputation(-rules.rep_for_cancelling, "cancelled %s" % contract_id)
	return BusinessResult.success()


func contract_balance(contract_id: String) -> Dictionary:
	var c: Dictionary = contracts.get(contract_id, {})
	if c.is_empty():
		return {}
	var parts := 0
	for o in orders.values():
		if o.contract_id == contract_id and o.state != PartsOrder.State.CANCELLED:
			parts += o.cost
	var out := c.duplicate()
	out["parts"] = parts
	out["margin"] = c.value - c.penalties - parts
	return out


func _charge_late_penalties() -> void:
	var ids := contracts.keys()
	ids.sort()
	for id in ids:
		var c: Dictionary = contracts[id]
		if c.state != "open" or day <= int(c.due_day):
			continue
		var cap: int = c.value * rules.late_penalty_cap_percent / 100
		var amount := mini(rules.late_penalty_per_day, cap - c.penalties)
		if amount <= 0:
			continue
		# Penalties come off the final payment rather than out of cash now.
		c.penalties += amount
		_bus.penalty_applied.emit(id, amount, "late")


# --- Reputation ---

func change_reputation(delta: float, reason: String) -> void:
	var before := reputation
	reputation = clampf(reputation + delta, 0.0, 100.0)
	if not is_equal_approx(before, reputation):
		_bus.reputation_changed.emit(reputation, reputation - before, reason)


# --- The business day ---

func advance_day() -> void:
	day += 1
	if rules.bay_rent_per_day > 0:
		post(-rules.bay_rent_per_day, LedgerEntry.RENT)
		_bus.rent_charged.emit(day, rules.bay_rent_per_day)
	_charge_late_penalties()
	_land_orders()
	_check_solvency()
	_bus.day_closed.emit(day)


func _check_solvency() -> void:
	if insolvent:
		return
	if cash >= 0:
		days_in_debt = 0
		return
	days_in_debt += 1
	var left := rules.insolvency_grace_days - days_in_debt
	if left > 0:
		_bus.insolvency_warning.emit(left)
	else:
		insolvent = true
		_bus.went_insolvent.emit()


# --- Saves ---

func save_data() -> Dictionary:
	return {
		"day": day, "cash": cash, "reputation": reputation,
		"ledger": ledger.map(func(e): return e.to_dict()),
		"orders": orders.values().map(func(o): return o.to_dict()),
		"contracts": contracts.duplicate(true), "stock": stock.duplicate(),
		"days_in_debt": days_in_debt, "insolvent": insolvent, "next_order": _next_order,
	}


func load_data(d: Dictionary, _from_version: int) -> void:
	reset()
	day = int(d.get("day", 0))
	cash = int(d.get("cash", rules.starting_cash))
	reputation = float(d.get("reputation", rules.starting_reputation))
	for e in d.get("ledger", []):
		ledger.append(LedgerEntry.from_dict(e))
	for od in d.get("orders", []):
		var o := PartsOrder.from_dict(od)
		orders[o.id] = o
	# JSON brings numbers back as floats; keep money whole.
	for id in d.get("contracts", {}):
		var c: Dictionary = d.contracts[id]
		contracts[id] = {
			"value": int(c.get("value", 0)), "due_day": int(c.get("due_day", 0)),
			"deposit": int(c.get("deposit", 0)), "penalties": int(c.get("penalties", 0)),
			"state": str(c.get("state", "open")),
		}
	for part in d.get("stock", {}):
		stock[part] = int(d.stock[part])
	days_in_debt = int(d.get("days_in_debt", 0))
	insolvent = bool(d.get("insolvent", false))
	_next_order = int(d.get("next_order", orders.size() + 1))
