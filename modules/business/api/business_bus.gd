class_name BusinessBus
extends Node
## Business module bus (Modules.bus("business")). Money, the parts market, suppliers,
## deliveries, bay rent, penalties and reputation.
## Other modules use this module only through this folder: signals here, and resource
## classes placed next to it. Everything else lives in internal/.
##
## Money is whole credits (int); negative amounts go out. Time is the business clock in game
## minutes: it runs while the shipyard is open (rules.game_minutes_per_second) and tests move
## it with advance_minutes() / advance_day(). Calls that change anything run on the host
## only and return ERR_UNAUTHORIZED elsewhere; clients follow along through the signals.
##
## The parts market: each business day every open supplier lists catalogue parts
## (MarketCatalogue, from Void Salvage's PartCatalog) in mixed condition at a trade price
## that swings a little day to day. A basket of {listing_id, qty} lines is quoted with
## quote_market() and bought with place_market_order(). Orders land in the shipyard's
## deliveries hall: through ShipBayBus.deliver_goods() when Ship and Bay offers it, else as
## Business's own crates. Players buy at the wall monitors Business puts in the yard.
##
## When the business flag is off this bus doesn't exist, so callers check
## Modules.is_loaded("business") and treat money as free when it isn't.

signal cash_changed(balance: int, delta: int, category: String)
signal ledger_entry_added(entry: LedgerEntry)

signal deposit_received(contract_id: String, amount: int)
signal final_payment_received(contract_id: String, amount: int)

signal order_placed(order: PartsOrder)
signal order_delayed(order: PartsOrder)
signal order_cancelled(order: PartsOrder, refund: int)
## `damaged` lists items that arrived unusable; they are not added to stock.
signal delivery_arrived(order: PartsOrder, damaged: Array[OrderLine])

signal rent_charged(day: int, amount: int)
signal penalty_applied(contract_id: String, amount: int, reason: String)
signal reputation_changed(value: float, delta: float, reason: String)
signal insolvency_warning(days_left: int)
signal went_insolvent
## Answers to request_purchase, keyed by the caller's order id.
signal purchase_completed(order_id: String)
signal purchase_failed(order_id: String, reason: String)
signal day_closed(day: int)
## Today's listings changed (a new day, or something was bought).
signal market_changed
## The business clock moved (game minutes since the company started).
signal clock_changed(minute: int)

const SAVE_SECTION := "business"
const DATA_DIR := "res://modules/business/internal/data"
const Books := preload("res://modules/business/internal/books.gd")
const YardFront := preload("res://modules/business/internal/yard/yard_front.gd")
## Node name of Business's things in the shipyard (monitors, fallback crates).
const YARD_NODE := "BusinessYard"

var _books: Books
## The open shipyard Business has furnished, or null; the clock runs while it is open.
var _yard: Node3D
var _clock_carry := 0.0


func _init() -> void:
	var suppliers: Array[SupplierDef] = []
	for file in ResourceLoader.list_directory(DATA_DIR + "/suppliers"):
		var s := load("%s/suppliers/%s" % [DATA_DIR, file]) as SupplierDef
		if s:
			suppliers.append(s)
	_books = Books.new(self, load(DATA_DIR + "/business_rules.tres"), load(DATA_DIR + "/prices.tres"),
			load(DATA_DIR + "/market_catalogue.tres"), suppliers)


func register_module() -> void:
	Saves.register_section(SAVE_SECTION, self)
	_listen_to_contracts()
	var yard_bus := Modules.bus("ship_bay") as ShipBayBus
	if yard_bus and Flags.is_on("business.market") and not yard_bus.shipyard_ready.is_connected(_on_shipyard_ready):
		yard_bus.shipyard_ready.connect(_on_shipyard_ready)
	delivery_arrived.connect(_on_delivery_arrived)
	if Flags.is_on("business.market") and Router.has_scene(ShipBayBus.SHIPYARD_SCENE):
		Shots.register("business_terminal", ShipBayBus.SHIPYARD_SCENE, _shot_terminal, 40)
		Shots.register("business_wall_monitor", ShipBayBus.SHIPYARD_SCENE, _shot_monitor, 40)
		Shots.register("business_goods_in", ShipBayBus.SHIPYARD_SCENE, _shot_goods, 40)


func unregister_module() -> void:
	Saves.unregister_section(SAVE_SECTION)


func _process(delta: float) -> void:
	if _yard == null or not is_instance_valid(_yard) or not _yard.is_inside_tree() or not _is_authority():
		return
	_clock_carry += delta * _books.rules.game_minutes_per_second
	if _clock_carry >= 1.0:
		var whole := int(_clock_carry)
		_clock_carry -= whole
		_books.advance_minutes(whole)


# --- Reads (any peer) ---

func get_day() -> int:
	return _books.day


## Game minutes since the company started.
func get_minute() -> int:
	return _books.minute


## "DAY 3  14:20".
func get_clock_text() -> String:
	var m := _books.minute % Books.MINUTES_PER_DAY
	return "DAY %d  %02d:%02d" % [_books.day + 1, m / 60, m % 60]


func get_cash() -> int:
	return _books.cash


func can_afford(amount: int) -> bool:
	return amount <= _books.cash


func get_ledger(since_day := 0) -> Array[LedgerEntry]:
	return _books.ledger.filter(func(e): return e.day >= since_day)


## 0 to 100.
func get_reputation() -> float:
	return _books.reputation


func is_insolvent() -> bool:
	return _books.insolvent


func get_rules() -> BusinessRules:
	return _books.rules


## Suppliers the company's reputation unlocks, by id.
func get_suppliers() -> Array[SupplierDef]:
	return _books.visible_suppliers()


func quote(supplier_id: String, lines: Array[OrderLine]) -> PartsQuote:
	return _books.quote(supplier_id, lines)


func get_order(order_id: String) -> PartsOrder:
	return _books.orders.get(order_id)


## Every order, optionally only those in one state (PartsOrder.State), oldest first.
func get_orders(state := -1) -> Array[PartsOrder]:
	var out: Array[PartsOrder] = []
	var ids := _books.orders.keys()
	ids.sort()
	for id in ids:
		if state < 0 or _books.orders[id].state == state:
			out.append(_books.orders[id])
	return out


## Delivered parts on hand (part -> count, any condition).
func get_stock() -> Dictionary:
	var out := {}
	for part in _books.stock:
		out[part] = _books.stock_total(part)
	return out


## Delivered parts on hand by condition (part -> {condition: count}).
func get_stock_detail() -> Dictionary:
	return _books.stock.duplicate(true)


## The parts the market deals in (Void Salvage's catalogue).
func get_catalogue() -> MarketCatalogue:
	return _books.catalogue


## Today's market, cheapest first with staples (fasteners, category "staples") after the
## catalogue parts; optionally one category's or one supplier's.
func get_listings(category := "", supplier_id := "") -> Array[MarketListing]:
	var out: Array[MarketListing] = []
	for l: MarketListing in _books.listings.values():
		if supplier_id != "" and l.supplier_id != supplier_id:
			continue
		if category != "" and listing_category(l) != category:
			continue
		out.append(l)
	out.sort_custom(func(a: MarketListing, b: MarketListing) -> bool:
		var sa := a.id.begins_with("S-")
		var sb := b.id.begins_with("S-")
		if sa != sb:
			return sb
		return a.unit_price < b.unit_price or (a.unit_price == b.unit_price and a.id < b.id))
	return out


func get_listing(listing_id: String) -> MarketListing:
	return _books.listings.get(listing_id)


## A listing's catalogue category, or "staples" for a supplier's counter goods.
func listing_category(l: MarketListing) -> String:
	return _books.catalogue.category_of(l.part) if _books.catalogue.has_part(l.part) else "staples"


func part_name(part: String) -> String:
	if _books.catalogue.has_part(part):
		return _books.catalogue.display_name(part)
	return str(_books.prices.names.get(part, part))


func supplier(supplier_id: String) -> SupplierDef:
	return _books.suppliers.get(supplier_id)


## What a basket of {listing_id, qty} lines costs and when the last of it arrives.
func quote_market(basket: Array) -> PartsQuote:
	return _books.quote_market(basket)


## {value, due_day, deposit, penalties, parts, margin, state}, or {} for an unknown contract.
func get_contract_balance(contract_id: String) -> Dictionary:
	return _books.contract_balance(contract_id)


# --- Changes (host only) ---

func place_order(supplier_id: String, lines: Array[OrderLine], contract_id := "") -> BusinessResult:
	if not _is_authority():
		return _not_host()
	return _books.place_order(supplier_id, lines, contract_id)


## Buys a basket of {listing_id, qty} lines from today's market: one order per supplier,
## paid now. result.order_ids lists them, result.cost is the bill.
func place_market_order(basket: Array, contract_id := "") -> BusinessResult:
	if not _is_authority():
		return _not_host()
	return _books.place_market_order(basket, contract_id)


func cancel_order(order_id: String) -> BusinessResult:
	if not _is_authority():
		return _not_host()
	return _books.cancel_order(order_id)


## Takes delivered parts out of stock as they are fitted, best condition first unless one
## is named. Fails without changing anything if there aren't enough.
func use_stock(part: String, qty := 1, condition := "") -> BusinessResult:
	if not _is_authority():
		return _not_host()
	if _books.take_stock(part, qty, condition).is_empty():
		return BusinessResult.fail(ERR_UNAVAILABLE, "only %d %s in stock" % [_books.stock_total(part), part])
	_refresh_yard()
	return BusinessResult.success()


## Money out for anything without its own call (Progression's tool upgrades, say).
func charge(amount: int, category: String, ref := "") -> BusinessResult:
	if not _is_authority():
		return _not_host()
	if amount < 0:
		return BusinessResult.fail(ERR_INVALID_PARAMETER, "charge a positive amount")
	if amount > _books.cash:
		return BusinessResult.fail(ERR_UNAVAILABLE, "not enough cash")
	_books.post(-amount, category, ref)
	return BusinessResult.success()


func credit(amount: int, category: String, ref := "") -> BusinessResult:
	if not _is_authority():
		return _not_host()
	if amount < 0:
		return BusinessResult.fail(ERR_INVALID_PARAMETER, "credit a positive amount")
	_books.post(amount, category, ref)
	return BusinessResult.success()


## Buys something priced in the PriceList under `price_ref` (Progression's
## "upgrade.<id>" entries, say). Answers with purchase_completed(order_id) or
## purchase_failed(order_id, reason), reason one of unknown_price, insufficient_funds,
## insolvent or not_host.
func request_purchase(price_ref: StringName, order_id: String) -> void:
	var reason := ""
	var price := _books.prices.price_of(price_ref)
	if not _is_authority():
		reason = "not_host"
	elif price < 0:
		reason = "unknown_price"
	elif _books.insolvent:
		reason = "insolvent"
	elif price > _books.cash:
		reason = "insufficient_funds"
	if reason != "":
		purchase_failed.emit(order_id, reason)
		return
	_books.post(-price, LedgerEntry.UPGRADE, order_id, String(price_ref))
	purchase_completed.emit(order_id)


## Moves the business clock on: deliveries land when due; each midnight charges rent and
## late penalties, checks solvency and opens a new market. Runs by itself while the yard
## is open.
func advance_minutes(minutes: int) -> void:
	if _is_authority():
		_books.advance_minutes(minutes)


## Runs the clock to the next midnight.
func advance_day() -> void:
	if _is_authority():
		_books.advance_day()


## Books a contract's deposit. Called from Contracts' contract_accepted signal when it has
## one; public so tests and the sandbox can drive it.
func on_contract_accepted(contract_id: String, value: int, due_day: int) -> BusinessResult:
	if not _is_authority():
		return _not_host()
	return _books.accept_contract(contract_id, value, due_day)


## Pays the rest of a contract and moves reputation. quality is 0-1.
func on_contract_handed_over(contract_id: String, quality: float, open_snags: int) -> BusinessResult:
	if not _is_authority():
		return _not_host()
	return _books.hand_over(contract_id, quality, open_snags)


func on_contract_cancelled(contract_id: String, by_client: bool) -> BusinessResult:
	if not _is_authority():
		return _not_host()
	return _books.cancel_contract(contract_id, by_client)


## Back to a fresh company (new game): starting cash, an empty store, today's market.
func reset() -> void:
	_books.reset()
	_refresh_yard()


# --- Saves provider ---

func save_version() -> int:
	return Books.SAVE_VERSION


func save_data() -> Dictionary:
	return _books.save_data()


func load_data(data: Dictionary, from_version: int) -> void:
	_books.load_data(data, from_version)
	cash_changed.emit(_books.cash, 0, "load")
	reputation_changed.emit(_books.reputation, 0.0, "load")
	clock_changed.emit(_books.minute)
	_refresh_yard()


# --- The shipyard ---

## Ship and Bay built its shipyard: put up the ordering monitors and the goods-in crates.
func _on_shipyard_ready(yard: Node3D) -> void:
	_yard = yard
	var old := yard.get_node_or_null(YARD_NODE)
	if old:
		old.free()
	var front: Node3D = YardFront.new()
	front.name = YARD_NODE
	# Ship and Bay counts nodes in this group as other modules' (its own tests skip them).
	front.add_to_group("yard_guest")
	yard.add_child(front)
	front.call("setup", self, yard)


func _on_delivery_arrived(order: PartsOrder, damaged: Array[OrderLine]) -> void:
	var yard_bus := Modules.bus("ship_bay")
	if yard_bus and yard_bus.has_method("deliver_goods"):
		var items: Array[Dictionary] = []
		for line in order.lines:
			var lost := 0
			for d in damaged:
				if d.part == line.part and d.condition == line.condition:
					lost += d.qty
			if line.qty - lost > 0:
				items.append({"part": line.part, "qty": line.qty - lost, "condition": line.condition, "order_id": order.id})
		yard_bus.call("deliver_goods", order.id, items)
	_refresh_yard()


func _front(scene: Node) -> Node:
	return scene.find_child(YARD_NODE, true, false)


func _shot_terminal(scene: Node) -> void:
	var front := _front(scene)
	if front == null:
		return
	var screen: Control = front.call("open_terminal")
	var picked := 0
	for l in get_listings():
		if l.available >= 2 and picked < 4 and not l.id.begins_with("S-"):
			screen.call("add_to_basket", l.id, 1 + picked % 2)
			picked += 1


func _shot_monitor(scene: Node) -> void:
	var front := _front(scene)
	if front:
		front.call("stage_monitor_view", 0)


func _shot_goods(scene: Node) -> void:
	var front := _front(scene)
	if front == null:
		return
	var basket := []
	for l in get_listings():
		if basket.size() < 7 and l.available > 0 and l.unit_price < 2500:
			basket.append({"listing_id": l.id, "qty": mini(l.available, 3)})
	place_market_order(basket)
	for i in 5:
		advance_day()
	front.call("stage_goods_view")


## True when Ship and Bay takes deliveries itself, so Business stacks no crates of its own.
func ship_bay_takes_deliveries() -> bool:
	var yard_bus := Modules.bus("ship_bay")
	return yard_bus != null and yard_bus.has_method("deliver_goods")


func _refresh_yard() -> void:
	if _yard and is_instance_valid(_yard):
		var front := _yard.get_node_or_null(YARD_NODE)
		if front:
			front.call("refresh_goods")


# --- Internals ---

## Contracts has no signals yet. When it adds contract_accepted(id, value, due_day),
## contract_handed_over(id, quality, open_snags) and contract_cancelled(id, by_client),
## Business picks them up with no change here.
func _listen_to_contracts() -> void:
	var contracts := Modules.bus("contracts")
	if contracts == null:
		return
	var hooks := {
		"contract_accepted": on_contract_accepted,
		"contract_handed_over": on_contract_handed_over,
		"contract_cancelled": on_contract_cancelled,
	}
	for sig in hooks:
		if contracts.has_signal(sig) and not contracts.is_connected(sig, hooks[sig]):
			contracts.connect(sig, hooks[sig])


func _is_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _not_host() -> BusinessResult:
	return BusinessResult.fail(ERR_UNAUTHORIZED, "only the host changes the books")
