extends RefCounted
## The company's books: cash, ledger, the parts market, orders, stock, contracts,
## reputation and the business clock. Owned by BusinessBus, which is the only caller;
## signals go out through the bus.

const SAVE_VERSION := 2
const MINUTES_PER_DAY := 1440
## How long a supplier's miss holds an order up the first time.
const DELAY_MINUTES := 12 * 60

var rules: BusinessRules
var prices: PriceList
var catalogue: MarketCatalogue
var suppliers: Dictionary = {}  # id -> SupplierDef
var rng := RandomNumberGenerator.new()

## Game minutes since the company started; the business day is minute / 1440.
var minute := 0
var day: int:
	get:
		return minute / MINUTES_PER_DAY
var cash := 0
var reputation := 50.0
var ledger: Array[LedgerEntry] = []
var orders: Dictionary = {}  # id -> PartsOrder
## Contract id -> {value, due_day, deposit, penalties, state}; state is open, done or cancelled.
var contracts: Dictionary = {}
## Delivered parts on hand: part -> {condition: count}.
var stock: Dictionary = {}
## Today's market: listing id -> MarketListing.
var listings: Dictionary = {}
var market_seed := 0
var days_in_debt := 0
var insolvent := false

var _bus: Node
var _next_order := 1


func _init(bus: Node, p_rules: BusinessRules, p_prices: PriceList, p_catalogue: MarketCatalogue, p_suppliers: Array) -> void:
	_bus = bus
	rules = p_rules
	prices = p_prices
	catalogue = p_catalogue
	for s in p_suppliers:
		suppliers[s.id] = s
	reset()


## A fresh company: starting cash and reputation, day 0, an empty store, today's market.
func reset() -> void:
	minute = 0
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
	market_seed = rng.randi()
	refresh_market()


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


# --- Suppliers and staples ---

func visible_suppliers() -> Array[SupplierDef]:
	var out: Array[SupplierDef] = []
	var ids := suppliers.keys()
	ids.sort()
	for id in ids:
		if reputation >= suppliers[id].min_reputation:
			out.append(suppliers[id])
	return out


## A staple order (a supplier's `parts`, priced from the PriceList), new, any quantity.
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
			q.reason = "%s does not stock %s" % [s.display_name, line.part]
			return q
		if line.qty < 1:
			q.reason = "quantity of %s must be at least 1" % line.part
			return q
		line.unit_price = staple_price(s, line.part)
		line.condition = PartCondition.NEW
		q.cost += line.unit_price * line.qty
	q.eta_minute = minute + s.lead_hours * 60
	q.eta_day = q.eta_minute / MINUTES_PER_DAY
	q.ok = true
	return q


func staple_price(s: SupplierDef, part: String) -> int:
	return maxi(1, roundi(prices.price_of(part) * float(s.parts[part])))


func place_order(supplier_id: String, lines: Array[OrderLine], contract_id: String) -> BusinessResult:
	if insolvent:
		return BusinessResult.fail(ERR_UNAVAILABLE, "the company is insolvent")
	var q := quote(supplier_id, lines)
	if not q.ok:
		return BusinessResult.fail(ERR_INVALID_PARAMETER, q.reason)
	if q.cost > cash:
		return BusinessResult.fail(ERR_UNAVAILABLE, "not enough cash (%d needed, %d held)" % [q.cost, cash])
	var o := _open_order(supplier_id, lines, q.cost, q.eta_minute, contract_id)
	var r := BusinessResult.success(o.id)
	r.order_ids = [o.id]
	r.cost = o.cost
	return r


func _open_order(supplier_id: String, lines: Array[OrderLine], cost: int, eta_minute: int, contract_id: String) -> PartsOrder:
	var o := PartsOrder.new()
	o.id = "PO-%04d" % _next_order
	_next_order += 1
	o.supplier_id = supplier_id
	o.lines = lines.duplicate()
	o.cost = cost
	o.placed_minute = minute
	o.placed_day = day
	o.eta_minute = eta_minute
	o.eta_day = eta_minute / MINUTES_PER_DAY
	o.contract_id = contract_id
	orders[o.id] = o
	post(-o.cost, LedgerEntry.PARTS, o.id, suppliers[supplier_id].display_name)
	_bus.order_placed.emit(o)
	return o


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


# --- The parts market ---

## Today's listings, rebuilt each business day from every open supplier: catalogue parts in
## the categories it deals in, in mixed condition, at a trade price that swings a little
## day to day; plus its staples, new and plentiful.
func refresh_market() -> void:
	listings = {}
	for s in visible_suppliers():
		for part: String in s.parts:
			if prices.price_of(part) < 0:
				continue
			var staple := MarketListing.new()
			staple.id = "S-%s-%s" % [s.id, part]
			staple.supplier_id = s.id
			staple.part = part
			staple.unit_price = staple_price(s, part)
			staple.available = 999
			staple.lead_hours = s.lead_hours
			listings[staple.id] = staple
		var pool := PackedStringArray()
		for c in s.categories:
			pool.append_array(catalogue.part_names(c))
		if pool.is_empty() or s.listings_per_day <= 0:
			continue
		var r := RandomNumberGenerator.new()
		r.seed = hash([market_seed, day, s.id])
		for i in s.listings_per_day:
			var part := pool[r.randi() % pool.size()]
			var condition := _pick_condition(s, r)
			var key := "%s|%s" % [part, condition]
			var id := "L%d-%s-%s" % [day, s.id, key]
			if listings.has(id):
				continue
			var l := MarketListing.new()
			l.id = id
			l.supplier_id = s.id
			l.part = part
			l.condition = condition
			l.unit_price = trade_price(s, part, condition, r.randf_range(-0.03, 0.03))
			l.available = _stock_size(catalogue.value_of(part), r)
			l.lead_hours = s.lead_hours
			listings[id] = l
	_bus.market_changed.emit()


## A catalogue part's price from a supplier today: Void Salvage's value, the supplier's
## trade share, the condition's discount, the day's swing for that part and `jitter`.
func trade_price(s: SupplierDef, part: String, condition: String, jitter := 0.0) -> int:
	var price := catalogue.value_of(part) * s.trade_factor * PartCondition.price_factor(condition)
	return maxi(1, roundi(price * day_swing(part) * (1.0 + jitter)))


## 1 +/- the day's swing for a part: the same for every supplier, new each day.
func day_swing(part: String) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash([market_seed, day, part])
	return 1.0 + rules.daily_price_swing * r.randf_range(-1.0, 1.0)


func _pick_condition(s: SupplierDef, r: RandomNumberGenerator) -> String:
	var total := 0.0
	for c in s.conditions:
		total += float(s.conditions[c])
	var roll := r.randf() * total
	for c: String in PartCondition.ALL:
		if not s.conditions.has(c):
			continue
		roll -= float(s.conditions[c])
		if roll <= 0.0:
			return c
	return PartCondition.NEW


static func _stock_size(value: int, r: RandomNumberGenerator) -> int:
	if value < 100:
		return r.randi_range(10, 60)
	if value < 1000:
		return r.randi_range(2, 12)
	if value < 10000:
		return r.randi_range(1, 4)
	return r.randi_range(1, 2)


## A basket of {listing_id, qty} lines: what it costs and when the last of it arrives.
func quote_market(basket: Array) -> PartsQuote:
	var q := PartsQuote.new()
	if basket.is_empty():
		q.reason = "the basket is empty"
		return q
	var wanted := {}
	for line: Dictionary in basket:
		var l: MarketListing = listings.get(str(line.get("listing_id", "")))
		var qty := int(line.get("qty", 0))
		if l == null:
			q.reason = "that listing has gone"
			return q
		if qty < 1:
			q.reason = "quantity of %s must be at least 1" % catalogue.display_name(l.part)
			return q
		wanted[l.id] = int(wanted.get(l.id, 0)) + qty
		if wanted[l.id] > l.available:
			q.reason = "only %d %s left" % [l.available, _name(l.part)]
			return q
		q.cost += l.unit_price * qty
		q.eta_minute = maxi(q.eta_minute, minute + l.lead_hours * 60)
	q.eta_day = q.eta_minute / MINUTES_PER_DAY
	q.ok = true
	return q


## Buys a basket: one order per supplier, paid now, taken off today's listings.
func place_market_order(basket: Array, contract_id: String) -> BusinessResult:
	if insolvent:
		return BusinessResult.fail(ERR_UNAVAILABLE, "the company is insolvent")
	var q := quote_market(basket)
	if not q.ok:
		return BusinessResult.fail(ERR_INVALID_PARAMETER, q.reason)
	if q.cost > cash:
		return BusinessResult.fail(ERR_UNAVAILABLE, "not enough cash (%d needed, %d held)" % [q.cost, cash])
	var by_supplier := {}
	for line: Dictionary in basket:
		var l: MarketListing = listings[str(line.listing_id)]
		var qty := int(line.qty)
		l.available -= qty
		if not by_supplier.has(l.supplier_id):
			by_supplier[l.supplier_id] = []
		by_supplier[l.supplier_id].append([OrderLine.new(l.part, qty, l.condition, l.unit_price), l.lead_hours])
	var result := BusinessResult.success()
	result.cost = q.cost
	var ids := by_supplier.keys()
	ids.sort()
	for sid in ids:
		var lines: Array[OrderLine] = []
		var cost := 0
		var lead := 0
		for pair: Array in by_supplier[sid]:
			lines.append(pair[0])
			cost += pair[0].unit_price * pair[0].qty
			lead = maxi(lead, pair[1])
		var o := _open_order(sid, lines, cost, minute + lead * 60, contract_id)
		result.order_ids.append(o.id)
	result.order_id = result.order_ids[0]
	_bus.market_changed.emit()
	return result


func _name(part: String) -> String:
	return catalogue.display_name(part) if catalogue.has_part(part) else part


# --- Stock ---

func stock_total(part: String) -> int:
	var n := 0
	for c in stock.get(part, {}):
		n += int(stock[part][c])
	return n


func add_stock(part: String, condition: String, qty: int) -> void:
	if qty <= 0:
		return
	if not stock.has(part):
		stock[part] = {}
	stock[part][condition] = int(stock[part].get(condition, 0)) + qty


## Takes `qty` of a part from stock, best condition first unless one is named. Returns what
## was taken ({condition: count}), or {} without changing anything if there aren't enough.
func take_stock(part: String, qty: int, condition := "") -> Dictionary:
	var have: Dictionary = stock.get(part, {})
	var count := int(have.get(condition, 0)) if condition != "" else stock_total(part)
	if qty < 1 or count < qty:
		return {}
	var taken := {}
	var left := qty
	for c: String in ([condition] if condition != "" else Array(PartCondition.ALL)):
		var n := mini(left, int(have.get(c, 0)))
		if n <= 0:
			continue
		have[c] -= n
		if have[c] == 0:
			have.erase(c)
		taken[c] = n
		left -= n
	if have.is_empty():
		stock.erase(part)
	return taken


func _land_orders() -> void:
	var ids := orders.keys()
	ids.sort()
	for id in ids:
		var o: PartsOrder = orders[id]
		if o.state != PartsOrder.State.PLACED or o.eta_minute > minute:
			continue
		var s: SupplierDef = suppliers[o.supplier_id]
		var on_time := rng.randf() < s.reliability
		if not on_time and not o.delayed:
			o.delayed = true
			o.eta_minute = minute + DELAY_MINUTES
			o.eta_day = o.eta_minute / MINUTES_PER_DAY
			_bus.order_delayed.emit(o)
			continue
		var damaged: Array[OrderLine] = []
		if not on_time:
			damaged.append(OrderLine.new(o.lines[0].part, 1, o.lines[0].condition, o.lines[0].unit_price))
		o.state = PartsOrder.State.DELIVERED
		for line in o.lines:
			add_stock(line.part, line.condition, line.qty)
		for line in damaged:
			take_stock(line.part, line.qty, line.condition)
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


# --- The business clock ---

## Moves the clock on: deliveries land as their time comes, and each midnight closes the
## day (rent, late penalties, the solvency check, a new market).
func advance_minutes(n: int) -> void:
	var target := minute + maxi(0, n)
	while minute < target:
		var midnight := (day + 1) * MINUTES_PER_DAY
		minute = mini(target, midnight)
		_land_orders()
		if minute == midnight:
			_close_day()
	_bus.clock_changed.emit(minute)


func advance_day() -> void:
	advance_minutes((day + 1) * MINUTES_PER_DAY - minute)


func _close_day() -> void:
	if rules.bay_rent_per_day > 0:
		post(-rules.bay_rent_per_day, LedgerEntry.RENT)
		_bus.rent_charged.emit(day, rules.bay_rent_per_day)
	_charge_late_penalties()
	_check_solvency()
	refresh_market()
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
		"minute": minute, "cash": cash, "reputation": reputation,
		"ledger": ledger.map(func(e): return e.to_dict()),
		"orders": orders.values().map(func(o): return o.to_dict()),
		"contracts": contracts.duplicate(true), "stock": stock.duplicate(true),
		"market_seed": market_seed, "listings": listings.values().map(func(l): return l.to_dict()),
		"days_in_debt": days_in_debt, "insolvent": insolvent, "next_order": _next_order,
	}


func load_data(d: Dictionary, from_version: int) -> void:
	reset()
	# Version 1 counted whole days and kept one stock count per part.
	minute = int(d.get("minute", int(d.get("day", 0)) * MINUTES_PER_DAY))
	cash = int(d.get("cash", rules.starting_cash))
	reputation = float(d.get("reputation", rules.starting_reputation))
	ledger = []
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
		var held: Variant = d.stock[part]
		if from_version < 2 or not held is Dictionary:
			add_stock(part, PartCondition.NEW, int(held))
		else:
			for c in held:
				add_stock(part, str(c), int(held[c]))
	days_in_debt = int(d.get("days_in_debt", 0))
	insolvent = bool(d.get("insolvent", false))
	_next_order = int(d.get("next_order", orders.size() + 1))
	market_seed = int(d.get("market_seed", market_seed))
	if d.has("listings"):
		listings = {}
		for ld in d.listings:
			var l := MarketListing.from_dict(ld)
			listings[l.id] = l
		_bus.market_changed.emit()
	else:
		refresh_market()
