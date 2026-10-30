extends RefCounted
## The company's books: cash, ledger, the parts market, orders, stock, contracts,
## reputation and the business clock. Owned by BusinessBus, which is the only caller;
## signals go out through the bus.

const SAVE_VERSION := 2
const MINUTES_PER_DAY := 1440
## How long a supplier's miss holds an order up the first time, real seconds. With the
## longest lead (45 s) a late order still arrives within a minute.
const DELAY_SECONDS := 15
## No delivery takes longer than this from the order, real seconds (old saves are cut to it).
const MAX_DELIVERY_SECONDS := 60
## What a player has in their wallet the first time they join, CR.
const WALLET_START := 1000
## The cheapest listing (credits) a supplier puts on a deal.
const DEAL_MIN_PRICE := 100
## Standing with a supplier from what the company has sold it (beenster, 0.3.19: selling to
## a lower bidder can be worth it to build up a supplier): [CR sold to it, name, percent off
## everything bought from it].
const SUPPLIER_TIERS := [[0, "New", 0], [5000, "Known", 2], [20000, "Regular", 4], [60000, "Partner", 6]]
const Company := preload("res://modules/business/internal/company.gd")

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
## sold_to() worked out from the ledger, and the ledger length it was worked out at.
var _sold := {}
var _sold_at := -1
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
## Each player's own money: player name -> CR. Players are known by name, so a wallet
## follows its owner from one session to the next.
var wallets: Dictionary = {}
## Owner, wages, payslips and loans.
var company: Company
## Testing: orders land the moment they're placed, on time and undamaged.
var instant_deliveries := false

var _bus: Node
var _next_order := 1


func _init(bus: Node, p_rules: BusinessRules, p_prices: PriceList, p_catalogue: MarketCatalogue, p_suppliers: Array) -> void:
	_bus = bus
	company = Company.new(self)
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
	_sold_at = -1
	orders = {}
	contracts = {}
	stock = {}
	days_in_debt = 0
	insolvent = false
	wallets = {}
	company.reset()
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


## A player's wallet, opened with the starting sum the first time they're seen.
func wallet(player: String) -> int:
	if not wallets.has(player):
		wallets[player] = WALLET_START
	return int(wallets[player])


## Moves money to a player's wallet from another's ("" = the company account, posted to the
## ledger as wages). Checks nothing: the host validated it.
func transfer(from: String, to: String, amount: int) -> void:
	if from == "":
		post(-amount, "wages", to)
	else:
		wallets[from] = wallet(from) - amount
		_bus.wallet_changed.emit(from, wallets[from], -amount)
	wallets[to] = wallet(to) + amount
	_bus.wallet_changed.emit(to, wallets[to], amount)


# --- Suppliers and staples ---

func visible_suppliers() -> Array[SupplierDef]:
	var out: Array[SupplierDef] = []
	var ids := suppliers.keys()
	ids.sort()
	for id in ids:
		var s: SupplierDef = suppliers[id]
		if reputation >= s.min_reputation and (s.flag == "" or Flags.is_on(s.flag)):
			out.append(s)
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
	var staple: MarketListing = listings.get("S-%s-%s" % [s.id, lines[0].part])
	q.eta_minute = minute + lead_minutes(staple.lead_seconds if staple else s.lead_seconds.y)
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
	if instant_deliveries:
		deliver_now()
	return o


## Testing: lands every order still on its way, now.
func deliver_now() -> void:
	for o: PartsOrder in orders.values():
		if o.state == PartsOrder.State.PLACED:
			o.eta_minute = minute
			o.eta_day = day
	_land_orders()


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
			staple.lead_seconds = _roll_lead(s, staple.id)
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
			l.lead_seconds = _roll_lead(s, id)
			listings[id] = l
	_cover_catalogue()
	_pick_deals()
	_bus.market_changed.emit()


## Every part Void Salvage builds is on sale every day, new, from every supplier you can
## see that deals in its category (so their prices can be compared), unless that supplier
## already lists it today.
func _cover_catalogue() -> void:
	var covered := {}
	for l: MarketListing in listings.values():
		covered["%s|%s" % [l.supplier_id, l.part]] = true
	for s in visible_suppliers():
		for category in s.categories:
			for part: String in catalogue.part_names(category):
				if covered.has("%s|%s" % [s.id, part]):
					continue
				var r := RandomNumberGenerator.new()
				r.seed = hash([market_seed, day, s.id, part, "cover"])
				var l := MarketListing.new()
				l.id = "C%d-%s-%s|%s" % [day, s.id, part, PartCondition.NEW]
				l.supplier_id = s.id
				l.part = part
				l.condition = PartCondition.NEW
				l.unit_price = trade_price(s, part, PartCondition.NEW)
				l.available = _stock_size(catalogue.value_of(part), r)
				l.lead_seconds = _roll_lead(s, l.id)
				listings[l.id] = l


## A listing's delivery time, real seconds, in its supplier's range (the same all day).
func _roll_lead(s: SupplierDef, listing_id: String) -> int:
	var r := RandomNumberGenerator.new()
	r.seed = hash([market_seed, day, listing_id, "lead"])
	return r.randi_range(s.lead_seconds.x, s.lead_seconds.y)


## Real seconds as business-clock minutes (the clock runs game_minutes_per_second).
func lead_minutes(seconds: int) -> int:
	return maxi(1, ceili(seconds * rules.game_minutes_per_second))


## Real seconds until a business-clock minute comes round, 0 once it has.
func seconds_until(at_minute: int) -> int:
	return maxi(0, ceili((at_minute - minute) / maxf(rules.game_minutes_per_second, 0.001)))


## Each supplier marks a few of today's listings down: its deals.
func _pick_deals() -> void:
	for s in visible_suppliers():
		if s.deals_per_day <= 0:
			continue
		var own: Array[MarketListing] = []
		for l: MarketListing in listings.values():
			# A deal on a part worth a few credits would only round to nonsense.
			if l.supplier_id == s.id and not l.id.begins_with("S-") and l.unit_price >= DEAL_MIN_PRICE:
				own.append(l)
		own.sort_custom(func(a: MarketListing, b: MarketListing) -> bool: return a.id < b.id)
		var r := RandomNumberGenerator.new()
		r.seed = hash([market_seed, day, s.id, "deals"])
		for i in mini(s.deals_per_day, own.size()):
			var l: MarketListing = own.pop_at(r.randi() % own.size())
			l.list_price = l.unit_price
			l.unit_price = maxi(1, roundi(l.unit_price * (100 - r.randi_range(s.deal_percent.x, s.deal_percent.y)) / 100.0))


## A catalogue part's price from a supplier today: Void Salvage's value, the supplier's
## trade share, the condition's discount, the day's swing for that part and `jitter`.
func trade_price(s: SupplierDef, part: String, condition: String, jitter := 0.0) -> int:
	var price := catalogue.value_of(part) * s.trade_factor * PartCondition.price_factor(condition)
	return maxi(1, roundi(price * house_factor(s, part) * day_swing(part) * (1.0 + jitter)))


## Where a supplier's own price for a part sits (1 +/- its price_spread): the same every
## day, so some suppliers are cheaper for some parts.
func house_factor(s: SupplierDef, part: String) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash([market_seed, s.id, part, "house"])
	return 1.0 + s.price_spread * r.randf_range(-1.0, 1.0)


## What a supplier pays today for one of a part in a condition the company sells it, or -1
## if it doesn't deal in that part.
func offer_price(s: SupplierDef, part: String, condition: String) -> int:
	if not catalogue.has_part(part) or not s.deals_in(catalogue.category_of(part)):
		return -1
	var price := catalogue.value_of(part) * s.buy_factor * PartCondition.price_factor(condition)
	return maxi(1, roundi(price * house_factor(s, part) * day_swing(part)))


## Every offer for a part in a condition today, best first: [{supplier_id, unit_price}].
func offers(part: String, condition: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in visible_suppliers():
		var p := offer_price(s, part, condition)
		if p > 0:
			out.append({"supplier_id": s.id, "unit_price": p})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.unit_price > b.unit_price or (a.unit_price == b.unit_price and a.supplier_id < b.supplier_id))
	return out


## Sells parts from stock to a supplier at today's offer.
func sell_stock(supplier_id: String, part: String, condition: String, qty: int) -> BusinessResult:
	var s: SupplierDef = suppliers.get(supplier_id)
	if s == null or not visible_suppliers().has(s):
		return BusinessResult.fail(ERR_DOES_NOT_EXIST, "no such buyer")
	var price := offer_price(s, part, condition)
	if price <= 0:
		return BusinessResult.fail(ERR_INVALID_PARAMETER, "%s doesn't buy %s" % [s.display_name, _name(part)])
	if qty < 1:
		return BusinessResult.fail(ERR_INVALID_PARAMETER, "sell at least one")
	if take_stock(part, qty, condition).is_empty():
		return BusinessResult.fail(ERR_UNAVAILABLE, "only %d %s %s in stock" % [int(stock.get(part, {}).get(condition, 0)), PartCondition.label(condition).to_lower(), _name(part)])
	post(price * qty, LedgerEntry.RESALE, supplier_id, "%d x %s (%s)" % [qty, _name(part), PartCondition.label(condition).to_lower()])
	var r := BusinessResult.success()
	r.cost = -price * qty
	return r


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
		q.eta_minute = maxi(q.eta_minute, minute + lead_minutes(l.lead_seconds))
	for id: String in wanted:
		var cost := line_cost(listings[id], int(wanted[id]))
		q.cost += cost
		q.saving += listings[id].unit_price * int(wanted[id]) - cost
	q.eta_day = q.eta_minute / MINUTES_PER_DAY
	q.ok = true
	return q


## What `qty` of one listing costs, less its supplier's bulk discount and the company's
## standing with it.
func line_cost(l: MarketListing, qty: int) -> int:
	var s: SupplierDef = suppliers.get(l.supplier_id)
	var off := s.bulk_off(qty) if s and not l.id.begins_with("S-") else 0
	off += loyalty_off(l.supplier_id)
	return roundi(l.unit_price * qty * (100 - off) / 100.0)


## CR the company has sold a supplier, ever (its sales in the ledger).
func sold_to(supplier_id: String) -> int:
	if _sold_at != ledger.size():
		_sold.clear()
		for e in ledger:
			if e.category == LedgerEntry.RESALE:
				_sold[e.ref] = int(_sold.get(e.ref, 0)) + e.amount
		_sold_at = ledger.size()
	return int(_sold.get(supplier_id, 0))


## The company's standing with a supplier: its SUPPLIER_TIERS entry, and the next one up
## ([] at the top): {name, off, sold, next_name, next_at}.
func standing_with(supplier_id: String) -> Dictionary:
	var sold := sold_to(supplier_id)
	var at := 0
	for i in SUPPLIER_TIERS.size():
		if sold >= int(SUPPLIER_TIERS[i][0]):
			at = i
	var out := {"name": SUPPLIER_TIERS[at][1], "off": int(SUPPLIER_TIERS[at][2]), "sold": sold, "next_name": "", "next_at": 0}
	if at + 1 < SUPPLIER_TIERS.size():
		out.next_name = SUPPLIER_TIERS[at + 1][1]
		out.next_at = int(SUPPLIER_TIERS[at + 1][0])
	return out


## Percent off everything bought from a supplier for the company's standing with it.
func loyalty_off(supplier_id: String) -> int:
	return int(standing_with(supplier_id).off)


## Buys a basket: one order per supplier, paid now, taken off today's listings.
func place_market_order(basket: Array, contract_id: String) -> BusinessResult:
	if insolvent:
		return BusinessResult.fail(ERR_UNAVAILABLE, "the company is insolvent")
	var q := quote_market(basket)
	if not q.ok:
		return BusinessResult.fail(ERR_INVALID_PARAMETER, q.reason)
	if q.cost > cash:
		return BusinessResult.fail(ERR_UNAVAILABLE, "not enough cash (%d needed, %d held)" % [q.cost, cash])
	var wanted := {}
	for line: Dictionary in basket:
		wanted[str(line.listing_id)] = int(wanted.get(str(line.listing_id), 0)) + int(line.qty)
	var by_supplier := {}
	for id: String in wanted:
		var l: MarketListing = listings[id]
		var qty: int = wanted[id]
		var cost := line_cost(l, qty)
		l.available -= qty
		if not by_supplier.has(l.supplier_id):
			by_supplier[l.supplier_id] = []
		by_supplier[l.supplier_id].append([OrderLine.new(l.part, qty, l.condition, roundi(float(cost) / qty)), l.lead_seconds, cost])
	var result := BusinessResult.success()
	result.cost = q.cost
	var ids := by_supplier.keys()
	ids.sort()
	for sid in ids:
		var lines: Array[OrderLine] = []
		var cost := 0
		var lead := 0
		for entry: Array in by_supplier[sid]:
			lines.append(entry[0])
			cost += int(entry[2])
			lead = maxi(lead, entry[1])
		var o := _open_order(sid, lines, cost, minute + lead_minutes(lead), contract_id)
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
		var on_time := instant_deliveries or rng.randf() < s.reliability
		if not on_time and not o.delayed:
			o.delayed = true
			o.eta_minute = minute + lead_minutes(DELAY_SECONDS)
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

## Books a won contract. The client pays up front for the parts (`materials`, CR at market
## value) plus goodwill, never more than the price; -1 materials (unpriced) falls back to
## deposit_percent of the price.
func accept_contract(contract_id: String, value: int, due_day: int, materials := -1) -> BusinessResult:
	if contracts.has(contract_id):
		return BusinessResult.fail(ERR_ALREADY_EXISTS, "contract %s already on the books" % contract_id)
	if value < 0:
		return BusinessResult.fail(ERR_INVALID_PARAMETER, "contract value must not be negative")
	var parts := 0
	var goodwill := 0
	if materials < 0:
		parts = value * rules.deposit_percent / 100
	else:
		parts = mini(materials, value)
		goodwill = mini(value * rules.goodwill_percent / 100, value - parts)
	var deposit := parts + goodwill
	contracts[contract_id] = {"value": value, "due_day": due_day, "deposit": deposit, "penalties": 0, "state": "open",
			"materials": parts if materials >= 0 else -1, "goodwill": goodwill}
	if parts > 0:
		post(parts, LedgerEntry.DEPOSIT, contract_id, "parts" if materials >= 0 else "")
	if goodwill > 0:
		post(goodwill, LedgerEntry.GOODWILL, contract_id)
	_bus.deposit_received.emit(contract_id, deposit)
	return BusinessResult.success()


## A large job's stages (plan stage S6): [{id, name, value}] in order. The job is priced as
## the sum of its stages, so the contract's value becomes that sum. Planning again before any
## stage is paid replaces the plan.
func plan_stages(contract_id: String, stages: Array) -> BusinessResult:
	var c: Dictionary = contracts.get(contract_id, {})
	if c.is_empty() or c.state != "open":
		return BusinessResult.fail(ERR_DOES_NOT_EXIST, "no open contract %s" % contract_id)
	if not c.get("stages_paid", {}).is_empty():
		return BusinessResult.fail(ERR_ALREADY_IN_USE, "contract %s has stages paid already" % contract_id)
	var plan: Array = []
	var total := 0
	for st: Variant in stages:
		var d: Dictionary = st if st is Dictionary else {}
		var id := str(d.get("id", ""))
		var value := int(d.get("value", -1))
		if id == "" or value < 0:
			return BusinessResult.fail(ERR_INVALID_PARAMETER, "a stage needs an id and a value of 0 or more")
		plan.append({"id": id, "name": str(d.get("name", id)), "value": value})
		total += value
	if plan.is_empty():
		return BusinessResult.fail(ERR_INVALID_PARAMETER, "no stages")
	c["stages"] = plan
	c["stages_paid"] = {}
	c.value = total
	return BusinessResult.success()


## What signing off a stage pays: its value less its share of the deposit already taken,
## so the stages and the handover together pay the job's value once. 0 for an unknown or
## paid stage.
func stage_payment(contract_id: String, stage_id: String) -> int:
	var c: Dictionary = contracts.get(contract_id, {})
	if c.is_empty() or c.get("stages_paid", {}).has(stage_id):
		return 0
	for st: Dictionary in c.get("stages", []):
		if st.id == stage_id:
			var deposit_share := int(st.value) * int(c.deposit) / maxi(1, int(c.value))
			return maxi(0, int(st.value) - deposit_share)
	return 0


## Pays a stage on sign-off. Each stage is paid once.
func sign_off_stage(contract_id: String, stage_id: String) -> BusinessResult:
	var c: Dictionary = contracts.get(contract_id, {})
	if c.is_empty() or c.state != "open":
		return BusinessResult.fail(ERR_DOES_NOT_EXIST, "no open contract %s" % contract_id)
	if not c.get("stages", []).any(func(st: Dictionary) -> bool: return st.id == stage_id):
		return BusinessResult.fail(ERR_DOES_NOT_EXIST, "contract %s has no stage %s" % [contract_id, stage_id])
	if c.stages_paid.has(stage_id):
		return BusinessResult.fail(ERR_ALREADY_EXISTS, "stage %s of %s is paid already" % [stage_id, contract_id])
	var amount := stage_payment(contract_id, stage_id)
	c.stages_paid[stage_id] = amount
	if amount > 0:
		post(amount, LedgerEntry.PAYMENT, contract_id, "stage %s" % stage_id)
	_bus.stage_payment_received.emit(contract_id, stage_id, amount)
	var r := BusinessResult.success()
	r.cost = amount
	return r


## What a contract's stages have paid so far, CR.
func stages_paid(contract_id: String) -> int:
	var total := 0
	for amount: Variant in contracts.get(contract_id, {}).get("stages_paid", {}).values():
		total += int(amount)
	return total


func hand_over(contract_id: String, quality: float, open_snags: int) -> BusinessResult:
	var c: Dictionary = contracts.get(contract_id, {})
	if c.is_empty() or c.state != "open":
		return BusinessResult.fail(ERR_DOES_NOT_EXIST, "no open contract %s" % contract_id)
	c.state = "done"
	var payment: int = c.value - c.deposit - c.penalties - stages_paid(contract_id)
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
	var out := c.duplicate(true)
	out["parts"] = parts
	out["stages_paid_total"] = stages_paid(contract_id)
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
	# The clock already reads the new day; wages and repayments belong to the one closing.
	company.pay_wages(_bus.crew_levels(), day - 1)
	company.collect_repayments(day - 1)
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
		"wallets": wallets.duplicate(),
		"company": company.save_data(),
	}


func load_data(d: Dictionary, from_version: int) -> void:
	reset()
	# Version 1 counted whole days and kept one stock count per part.
	minute = int(d.get("minute", int(d.get("day", 0)) * MINUTES_PER_DAY))
	cash = int(d.get("cash", rules.starting_cash))
	reputation = float(d.get("reputation", rules.starting_reputation))
	ledger = []
	_sold_at = -1
	for e in d.get("ledger", []):
		ledger.append(LedgerEntry.from_dict(e))
	for od in d.get("orders", []):
		var o := PartsOrder.from_dict(od)
		# Saves from when deliveries took hours: anything still on its way comes soon.
		if o.state == PartsOrder.State.PLACED and o.eta_minute > minute + lead_minutes(MAX_DELIVERY_SECONDS):
			o.eta_minute = minute + lead_minutes(MAX_DELIVERY_SECONDS)
			o.eta_day = o.eta_minute / MINUTES_PER_DAY
		orders[o.id] = o
	# JSON brings numbers back as floats; keep money whole.
	for id in d.get("contracts", {}):
		var c: Dictionary = d.contracts[id]
		contracts[id] = {
			"value": int(c.get("value", 0)), "due_day": int(c.get("due_day", 0)),
			"deposit": int(c.get("deposit", 0)), "penalties": int(c.get("penalties", 0)),
			"state": str(c.get("state", "open")),
			"materials": int(c.get("materials", -1)), "goodwill": int(c.get("goodwill", 0)),
		}
		if c.has("stages"):
			contracts[id]["stages"] = (c.stages as Array).duplicate(true)
			var paid := {}
			for stage_id: Variant in c.get("stages_paid", {}):
				paid[str(stage_id)] = int(c.stages_paid[stage_id])
			contracts[id]["stages_paid"] = paid
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
	company.load_data(d.get("company", {}))
	for player in d.get("wallets", {}):
		wallets[str(player)] = int(d.wallets[player])
	if d.has("listings"):
		listings = {}
		for ld in d.listings:
			var l := MarketListing.from_dict(ld)
			listings[l.id] = l
		_bus.market_changed.emit()
	else:
		refresh_market()
