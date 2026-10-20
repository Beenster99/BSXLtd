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
## deliveries hall: through ShipBayBus.receive_delivery() when Ship and Bay offers it, else as
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
## A player's wallet changed (a transfer in or out).
signal wallet_changed(player: String, balance: int, delta: int)
## A transfer the host refused, on the player who asked.
signal transfer_refused(reason: String)

const SAVE_SECTION := "business"
const DATA_DIR := "res://modules/business/internal/data"
const Books := preload("res://modules/business/internal/books.gd")
const YardFront := preload("res://modules/business/internal/yard/yard_front.gd")
const TerminalScreen := preload("res://modules/business/internal/ui/terminal_screen.gd")
const WristScreen := preload("res://modules/business/internal/ui/wrist_screen.gd")
## Business's channels on the wrist holo screen: id -> [tab name, page, order]. Orders holds
## the market, the purchase order and what's on order; Ship and Bay and Contracts sit
## between them at 20 to 40.
const SCREEN_CHANNELS := {
	"business.orders": ["Orders", "orders", 10],
	"business.accounts": ["Accounts", "accounts", 50],
}
const CASH_READOUT := "business.cash"
const TransferPanel := preload("res://modules/business/internal/ui/transfer_panel.gd")
## Sending money: host-validated, so every player's wallets agree.
const TRANSFER_EVENT := "business.transfer"
## The crew tab the transfer docket sits in (Multiplayer's).
const CREW_CHANNEL := "multiplayer.crew"
const TRANSFER_SECTION := "business.transfer"
## Node name of Business's things in the shipyard (monitors, fallback crates).
const YARD_NODE := "BusinessYard"

var _books: Books
## The open shipyard Business has furnished, or null; the clock runs while it is open.
var _yard: Node3D
var _clock_carry := 0.0
## The purchase order being built on the wrist, kept here so it survives closing the screen.
var wrist_basket: Dictionary = {}


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
	_offer_screen_channels()
	# Multiplayer may load after Business; wallets need its events.
	if not Modules.modules_ready.is_connected(_offer_wallets):
		Modules.modules_ready.connect(_offer_wallets, CONNECT_ONE_SHOT)


func unregister_module() -> void:
	var net := _net()
	if net:
		net.call("unregister_event", TRANSFER_EVENT)
		net.call("unregister_snapshot_provider", SAVE_SECTION)
	HudSlots.unregister_holo_section(CREW_CHANNEL, TRANSFER_SECTION)
	Saves.unregister_section(SAVE_SECTION)
	for id: String in SCREEN_CHANNELS:
		HudSlots.unregister_holo_channel(id)
	HudSlots.unregister_holo_readout(CASH_READOUT)


## Puts the terminal's channels on the wrist holo screen (HudSlots), so a player can order
## from anywhere in the yard.
func _offer_screen_channels() -> void:
	if not Flags.is_on("business.market"):
		return
	for id: String in SCREEN_CHANNELS:
		var spec: Array = SCREEN_CHANNELS[id]
		var page: String = spec[1]
		HudSlots.register_holo_channel(id, spec[0], func(glass: bool) -> Control: return WristScreen.new(self, page, glass), spec[2])
	HudSlots.register_holo_readout(CASH_READOUT, func() -> String: return "CR %s" % TerminalKit.money(get_cash()))


# --- Wallets ---------------------------------------------------------------------------

## Every player has a wallet of their own and can send money to the crew; the company account
## can pay crew too (posted as wages). Players are known by their profile name.
func _offer_wallets() -> void:
	if not Flags.is_on("business.wallets"):
		return
	var net := _net()
	if net == null:
		return
	net.call("register_event", TRANSFER_EVENT, _apply_transfer, _validate_transfer)
	net.call("register_snapshot_provider", SAVE_SECTION, self)
	if not net.is_connected("request_rejected", _on_request_rejected):
		net.connect("request_rejected", _on_request_rejected)
	HudSlots.register_holo_section(CREW_CHANNEL, TRANSFER_SECTION, "Transfer money", func(glass: bool) -> Control: return TransferPanel.new(self, glass))


## Multiplayer's bus when it's loaded. Business doesn't list multiplayer in depends_on (the
## yard runs without it, and so do other modules' tests), so its calls go by name.
func _net() -> Node:
	return Modules.bus("multiplayer")


## Tests stand a crew in here (peer id -> name) instead of a real session.
var test_crew: Dictionary = {}


## The players in the session, you included: peer id -> name.
func crew_names() -> Dictionary:
	if not test_crew.is_empty():
		return test_crew
	var out := {}
	var net := _net()
	if net:
		var peers: Dictionary = net.call("peers")
		for id: int in peers:
			out[id] = str(peers[id].get("name", "Player %d" % id)) if peers[id] is Dictionary else "Player %d" % id
	return out


## Name of a player in the session, "" if there's no such player.
func player_name(peer_id: int) -> String:
	return str(crew_names().get(peer_id, ""))


## The local player's name.
func my_name() -> String:
	return player_name(my_peer())


## The local player's peer id (1 when playing alone).
func my_peer() -> int:
	var net := _net()
	return int(net.call("local_peer_id")) if net else 1


## What a player holds, CR (a new player starts with Books.WALLET_START).
func get_wallet(player: String) -> int:
	return _books.wallet(player)


## Asks the host to send `amount` CR to the player `to_peer`, from your wallet or, with
## `from_company`, from the company account. The answer comes as wallet_changed or
## transfer_refused.
func request_transfer(to_peer: int, amount: int, from_company := false) -> void:
	var net := _net()
	if net == null:
		transfer_refused.emit("no crew to send to")
		return
	net.call("request", TRANSFER_EVENT, {"to": to_peer, "amount": amount, "company": from_company})


func _validate_transfer(sender: int, p: Dictionary) -> Variant:
	var from := player_name(sender)
	var to := player_name(int(p.get("to", 0)))
	var amount := int(p.get("amount", 0))
	var company := bool(p.get("company", false))
	if from == "" or to == "":
		return "that player isn't here"
	if to == from:
		return "you can't send money to yourself"
	if amount <= 0:
		return "enter an amount"
	if company:
		if _books.insolvent or amount > _books.cash:
			return "the company can't pay that"
	elif amount > _books.wallet(from):
		return "you only have %s CR" % TerminalKit.money(_books.wallet(from))
	return {"from": "" if company else from, "to": to, "amount": amount, "by": from}


func _apply_transfer(p: Dictionary) -> void:
	_books.transfer(str(p.from), str(p.to), int(p.amount))


func _on_request_rejected(event_name: String, reason: String) -> void:
	if event_name == TRANSFER_EVENT:
		transfer_refused.emit(reason)


## Joining players get everyone's wallets from the host.
func get_net_snapshot() -> Dictionary:
	return {"wallets": _books.wallets.duplicate()}


func apply_net_snapshot(data: Dictionary) -> void:
	for player in data.get("wallets", {}):
		_books.wallets[str(player)] = int(data.wallets[player])
		wallet_changed.emit(str(player), _books.wallets[str(player)], 0)


## A yard terminal on `channel` ("orders", "goods", "accounts"), laid out at 1280 x 800 and
## happy at any size; interactive takes the mouse and can place orders. It emits
## close_requested when the player is done with it.
func make_screen(interactive: bool, channel := "orders") -> Control:
	var screen: Control = TerminalScreen.new()
	screen.call("setup", self, interactive)
	screen.call("show_channel", channel)
	return screen


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
	wrist_basket.clear()
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
	if yard_bus and yard_bus.has_method("receive_delivery"):
		yard_bus.call("receive_delivery", order.id, delivery_lines(order, damaged))
	if _yard and is_instance_valid(_yard) and _yard.is_inside_tree():
		var hall: AABB = yard_bus.shipyard_rooms().get("deliveries", {}).get("box", AABB()) if yard_bus else AABB()
		Sfx.play("chime", hall.get_center() if hall.has_volume() else null)
	_refresh_yard()


## What lands in the deliveries hall for an order, in Ship and Bay's shape: one line per part
## and condition, less anything lost in transit. condition is 0..1 (1 = new); grade is the
## market's condition name; mass is per unit in kg (0 when the catalogue doesn't know it).
func delivery_lines(order: PartsOrder, damaged: Array[OrderLine] = []) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var cat := get_catalogue()
	for line in order.lines:
		var lost := 0
		for d in damaged:
			if d.part == line.part and d.condition == line.condition:
				lost += d.qty
		if line.qty - lost <= 0:
			continue
		var grade := line.condition if line.condition != "" else PartCondition.NEW
		lines.append({"item_id": line.part, "qty": line.qty - lost, "condition": 1.0 - PartCondition.wear_of(grade),
				"name": part_name(line.part), "grade": grade, "mass": cat.mass_of(line.part) if cat.has_part(line.part) else 0.0})
	return lines


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
	return yard_bus != null and yard_bus.has_method("receive_delivery")


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
