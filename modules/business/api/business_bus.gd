class_name BusinessBus
extends Node
## Business module bus (Modules.bus("business")). Money, suppliers, deliveries, bay rent, penalties and reputation.
## Other modules use this module only through this folder: signals here, and resource
## classes placed next to it. Everything else lives in internal/.
##
## Money is whole credits (int); negative amounts go out. Time is the business day, moved on
## by advance_day(). Calls that change anything run on the host only (or with no network
## peer) and return ERR_UNAUTHORIZED elsewhere; clients follow along through the signals.
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

const SAVE_SECTION := "business"
const DATA_DIR := "res://modules/business/internal/data"
const Books := preload("res://modules/business/internal/books.gd")

var _books: Books


func _init() -> void:
	var suppliers: Array[SupplierDef] = []
	for file in ResourceLoader.list_directory(DATA_DIR + "/suppliers"):
		var s := load("%s/suppliers/%s" % [DATA_DIR, file]) as SupplierDef
		if s:
			suppliers.append(s)
	_books = Books.new(self, load(DATA_DIR + "/business_rules.tres"), load(DATA_DIR + "/prices.tres"), suppliers)


func register_module() -> void:
	Saves.register_section(SAVE_SECTION, self)
	_listen_to_contracts()


func unregister_module() -> void:
	Saves.unregister_section(SAVE_SECTION)


# --- Reads (any peer) ---

func get_day() -> int:
	return _books.day


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


## Delivered parts on hand (part -> count).
func get_stock() -> Dictionary:
	return _books.stock.duplicate()


## {value, due_day, deposit, penalties, parts, margin, state}, or {} for an unknown contract.
func get_contract_balance(contract_id: String) -> Dictionary:
	return _books.contract_balance(contract_id)


# --- Changes (host only) ---

func place_order(supplier_id: String, lines: Array[OrderLine], contract_id := "") -> BusinessResult:
	if not _is_authority():
		return _not_host()
	return _books.place_order(supplier_id, lines, contract_id)


func cancel_order(order_id: String) -> BusinessResult:
	if not _is_authority():
		return _not_host()
	return _books.cancel_order(order_id)


## Takes delivered parts out of stock as they are fitted. Fails without changing anything
## if there aren't enough.
func use_stock(part: String, qty := 1) -> BusinessResult:
	if not _is_authority():
		return _not_host()
	if int(_books.stock.get(part, 0)) < qty:
		return BusinessResult.fail(ERR_UNAVAILABLE, "only %d %s in stock" % [int(_books.stock.get(part, 0)), part])
	_books.stock[part] -= qty
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


## Ends the business day: rent, late penalties, deliveries, the solvency check.
## Until Core has a game clock, whoever runs the day (a bay "end shift" action, tests)
## calls this.
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


## Back to a fresh company (new game).
func reset() -> void:
	_books.reset()


# --- Saves provider ---

func save_version() -> int:
	return Books.SAVE_VERSION


func save_data() -> Dictionary:
	return _books.save_data()


func load_data(data: Dictionary, from_version: int) -> void:
	_books.load_data(data, from_version)
	cash_changed.emit(_books.cash, 0, "load")
	reputation_changed.emit(_books.reputation, 0.0, "load")


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
