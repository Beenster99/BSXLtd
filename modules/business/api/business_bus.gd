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
## Parts put into stock from the yard (Ship and Bay's recycler turning scrap into raw
## materials), not from a delivery.
signal stock_added(part: String, condition: String, qty: int, source: String)
## The business clock moved (game minutes since the company started).
signal clock_changed(minute: int)
## A player's wallet changed (a transfer in or out).
signal wallet_changed(player: String, balance: int, delta: int)
## A transfer the host refused, on the player who asked.
signal transfer_refused(reason: String)
## A day's pay went out to a player: the payslip {day, level, wage, bonuses, total}.
signal payslip_issued(player: String, slip: Dictionary)
signal bonus_awarded(player: String, amount: int, note: String, by: String)
signal loan_taken(loan: Dictionary)
## A repayment went to a loan; balance 0 means it's paid off.
signal loan_repaid(loan_id: String, amount: int, balance: int)
signal owner_changed(player: String)
## The host refused a company request (owner, bonus, loan) from this player.
signal company_refused(reason: String)

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
	"business.goods": ["Goods in", "goods", 30],
	"business.accounts": ["Accounts", "accounts", 50],
}
const CASH_READOUT := "business.cash"
const TransferPanel := preload("res://modules/business/internal/ui/transfer_panel.gd")
## Sending money: host-validated, so every player's wallets agree.
const TRANSFER_EVENT := "business.transfer"
## The crew tab the transfer docket sits in (Multiplayer's).
const CREW_CHANNEL := "multiplayer.crew"
const TRANSFER_SECTION := "business.transfer"
## Company requests, checked by the host: who owns it, bonuses, loans and paying one off.
const OWNER_EVENT := "business.owner"
const BONUS_EVENT := "business.bonus"
const LOAN_EVENT := "business.loan"
const SETTLE_EVENT := "business.settle"
## The longest note a bonus may carry.
const NOTE_MAX := 140
## The Settings menu: a Company page (owner, bonuses, loans) and payslips on Character.
const COMPANY_PAGE := "business.company"
const PAYSLIPS_SECTION := "business.payslips"
const CompanyPanel := preload("res://modules/business/internal/ui/company_panel.gd")
## Node name of Business's things in the shipyard (monitors, fallback crates).
const YARD_NODE := "BusinessYard"
## Settings > Gameplay > Testing (flag business.debug): orders arrive the moment they're
## placed. The host's setting is the one that counts; it delivers.
const SETTINGS_SECTION := "business"
const INSTANT_KEY := "instant_deliveries"
const TESTING_SECTION := "business.testing"

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
	# Ship and Bay's wrist Stock prices what's held at Void Salvage's value for a new part.
	if yard_bus and yard_bus.has_method("set_part_values"):
		yard_bus.call("set_part_values", func(item_id: String) -> int: return get_catalogue().value_of(item_id))
	# The recycler's raw materials come into stock by the kilo.
	if yard_bus and yard_bus.has_signal("scrap_recycled") and not yard_bus.is_connected("scrap_recycled", _on_scrap_recycled):
		yard_bus.connect("scrap_recycled", _on_scrap_recycled)
	if Flags.is_on("business.market") and Router.has_scene(ShipBayBus.SHIPYARD_SCENE):
		Shots.register("business_terminal", ShipBayBus.SHIPYARD_SCENE, _shot_terminal, 40)
		Shots.register("business_wall_monitor", ShipBayBus.SHIPYARD_SCENE, _shot_monitor, 40)
		Shots.register("business_goods_in", ShipBayBus.SHIPYARD_SCENE, _shot_goods, 40)
	_offer_screen_channels()
	if Flags.is_on("business.debug"):
		Settings.register(SETTINGS_SECTION, {INSTANT_KEY: false})
		if not Settings.changed.is_connected(_on_setting_changed):
			Settings.changed.connect(_on_setting_changed)
		_books.instant_deliveries = bool(Settings.get_value(SETTINGS_SECTION, INSTANT_KEY))
		Menu.register_settings_section(Menu.GAMEPLAY, TESTING_SECTION, "Testing", _testing_section, 90)
	if Flags.is_on("business.economy"):
		Menu.register_settings_page(COMPANY_PAGE, "Company", func() -> Control: return CompanyPanel.new(self, "company", false), 20)
		Menu.register_settings_section(Menu.CHARACTER, PAYSLIPS_SECTION, "Payslips", func() -> Control: return CompanyPanel.new(self, "payslips", false), 30)
	# Multiplayer may load after Business; wallets need its events.
	if not Modules.modules_ready.is_connected(_offer_wallets):
		Modules.modules_ready.connect(_offer_wallets, CONNECT_ONE_SHOT)


func unregister_module() -> void:
	var yard_bus := Modules.bus("ship_bay")
	if yard_bus and yard_bus.has_signal("scrap_recycled") and yard_bus.is_connected("scrap_recycled", _on_scrap_recycled):
		yard_bus.disconnect("scrap_recycled", _on_scrap_recycled)
	var net := _net()
	if net:
		for e in [TRANSFER_EVENT, OWNER_EVENT, BONUS_EVENT, LOAN_EVENT, SETTLE_EVENT]:
			net.call("unregister_event", e)
		net.call("unregister_snapshot_provider", SAVE_SECTION)
	HudSlots.unregister_holo_section(CREW_CHANNEL, TRANSFER_SECTION)
	Menu.unregister_settings_page(COMPANY_PAGE)
	Menu.unregister_settings_section(Menu.GAMEPLAY, TESTING_SECTION)
	if Settings.changed.is_connected(_on_setting_changed):
		Settings.changed.disconnect(_on_setting_changed)
	Menu.unregister_settings_section(Menu.CHARACTER, PAYSLIPS_SECTION)
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
	if Flags.is_on("business.economy"):
		net.call("register_event", OWNER_EVENT, _apply_owner, _validate_owner)
		net.call("register_event", BONUS_EVENT, _apply_bonus, _validate_bonus)
		net.call("register_event", LOAN_EVENT, _apply_loan, _validate_loan)
		net.call("register_event", SETTLE_EVENT, _apply_settle, _validate_settle)
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
	elif event_name in [OWNER_EVENT, BONUS_EVENT, LOAN_EVENT, SETTLE_EVENT]:
		company_refused.emit(reason)


# --- The company: owner, wages, bonuses, payslips, loans ---------------------------------

## Tests set players' skill levels here (name -> level) instead of asking Progression.
var test_levels: Dictionary = {}


## Who owns the company: the named owner, else whoever hosts.
func company_owner() -> String:
	return _books.company.owner if _books.company.owner != "" else player_name(1)


func is_owner(player: String) -> bool:
	return player != "" and player == company_owner()


## A player's skill level for pay: their levels in every skill added up (Progression's,
## when it's running; 0 otherwise).
func player_level(player: String) -> int:
	if test_levels.has(player):
		return int(test_levels[player])
	var progression := Modules.bus("progression")
	if progression == null or not progression.has_method("skills"):
		return 0
	var peer := -1
	var crew := crew_names()
	for id: int in crew:
		if crew[id] == player:
			peer = id
	if peer < 0:
		return 0
	var total := 0
	for skill in progression.call("skills"):
		total += int(progression.call("skill_level", StringName(str(peer)), skill.id))
	return total


## Everyone on shift and their level, for the day's wages (none with the economy off).
func crew_levels() -> Dictionary:
	var out := {}
	if not Flags.is_on("business.economy"):
		return out
	for id: int in crew_names():
		var player := player_name(id)
		out[player] = player_level(player)
	return out


func wage_for(level: int) -> int:
	return _books.company.wage_for(level)


## A player's payslips, newest last.
func get_payslips(player: String) -> Array:
	return (_books.company.payslips.get(player, []) as Array).duplicate(true)


func get_loans() -> Array[Dictionary]:
	return _books.company.loans.duplicate(true)


## How much more the company may borrow.
func loan_room() -> int:
	return _books.company.loan_room(_books.reputation)


## {monthly, total} for a loan of `amount` over `months`.
func loan_quote(amount: int, months: int) -> Dictionary:
	var m := _books.company.monthly_for(amount, maxi(1, months), _books.rules.loan_apr_percent)
	return {"monthly": m, "total": m * maxi(1, months), "apr": _books.rules.loan_apr_percent}


## What paying a loan off now would cost.
func settle_amount(loan_id: String) -> int:
	var loan := _books.company.find_loan(loan_id)
	return _books.company.settle_amount(loan) if not loan.is_empty() else 0


func request_owner(to_peer: int) -> void:
	_company_request(OWNER_EVENT, {"to": to_peer})


func request_bonus(to_peer: int, amount: int, note: String) -> void:
	_company_request(BONUS_EVENT, {"to": to_peer, "amount": amount, "note": note})


func request_loan(amount: int, months: int) -> void:
	_company_request(LOAN_EVENT, {"amount": amount, "months": months})


func request_settle(loan_id: String) -> void:
	_company_request(SETTLE_EVENT, {"loan": loan_id})


func _company_request(event_name: String, payload: Dictionary) -> void:
	var net := _net()
	if net == null or not Flags.is_on("business.economy"):
		company_refused.emit("the company books aren't open")
		return
	net.call("request", event_name, payload)


## Only the owner, or the host when no one else is, runs the company.
func _check_owner(sender: int) -> String:
	var who := player_name(sender)
	if who == "":
		return "that player isn't here"
	if not is_owner(who):
		return "only the owner (%s) can do that" % company_owner()
	return ""


func _validate_owner(sender: int, p: Dictionary) -> Variant:
	var who := player_name(sender)
	if not is_owner(who) and sender != 1:
		return "only the owner or the host can hand the company over"
	var to := player_name(int(p.get("to", 0)))
	if to == "":
		return "that player isn't here"
	return {"owner": to}


func _apply_owner(p: Dictionary) -> void:
	_books.company.owner = str(p.owner)
	owner_changed.emit(_books.company.owner)


func _validate_bonus(sender: int, p: Dictionary) -> Variant:
	var why := _check_owner(sender)
	if why != "":
		return why
	var to := player_name(int(p.get("to", 0)))
	var amount := int(p.get("amount", 0))
	var note := str(p.get("note", "")).strip_edges().left(NOTE_MAX)
	if to == "":
		return "pick a crew member"
	if amount <= 0:
		return "enter an amount"
	if _books.insolvent or amount > _books.cash:
		return "the company can't pay that"
	return {"to": to, "amount": amount, "note": note, "by": player_name(sender)}


func _apply_bonus(p: Dictionary) -> void:
	_books.company.award_bonus(str(p.to), int(p.amount), str(p.note), str(p.by), _books.day)


func _validate_loan(sender: int, p: Dictionary) -> Variant:
	var why := _check_owner(sender)
	if why != "":
		return why
	var amount := int(p.get("amount", 0))
	var months := int(p.get("months", 0))
	var r := _books.rules
	if months < 1 or months > r.loan_months_max:
		return "a loan runs 1 to %d months" % r.loan_months_max
	if amount < r.loan_min:
		return "the bank lends from %s CR" % TerminalKit.money(r.loan_min)
	if amount > loan_room():
		return "the bank will lend up to %s CR more" % TerminalKit.money(loan_room())
	return {"amount": amount, "months": months}


func _apply_loan(p: Dictionary) -> void:
	_books.company.take_loan(int(p.amount), int(p.months), _books.day)


func _validate_settle(sender: int, p: Dictionary) -> Variant:
	var why := _check_owner(sender)
	if why != "":
		return why
	var loan := _books.company.find_loan(str(p.get("loan", "")))
	if loan.is_empty():
		return "no such loan"
	if _books.company.settle_amount(loan) > _books.cash:
		return "the company can't pay it off yet"
	return {"loan": loan.id}


func _apply_settle(p: Dictionary) -> void:
	_books.company.settle(str(p.loan))


## Joining players get everyone's wallets from the host.
func get_net_snapshot() -> Dictionary:
	return {"wallets": _books.wallets.duplicate(), "company": _books.company.save_data()}


func apply_net_snapshot(data: Dictionary) -> void:
	if data.has("company"):
		_books.company.load_data(data.company)
		owner_changed.emit(company_owner())
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


## Ledger categories grouped the way the Accounts page shows them, in its order.
const ACCOUNT_GROUPS := {
	"contracts": ["deposit", "goodwill", "payment", "penalty"],
	"sales": ["scrap", "salvage"],
	"parts": ["parts", "refund"],
	"wages": ["wages", "bonus"],
	"rent": ["rent"],
	"loans": ["loan", "repayment"],
}


## The Accounts page group a ledger category falls in ("other" for the rest).
static func account_group(category: String) -> String:
	for g: String in ACCOUNT_GROUPS:
		if category in ACCOUNT_GROUPS[g]:
			return g
	return "other"


## Money in and out over the last `days` game days up to today: {income, outgoings, net,
## groups: {group: {in, out}} (every group, in ACCOUNT_GROUPS order then "other"),
## days: [{day, in, out}] oldest first}. Outgoings are positive numbers.
func accounts_summary(days: int) -> Dictionary:
	var today := get_day()
	var first := maxi(0, today - maxi(1, days) + 1)
	var groups := {}
	for g: String in ACCOUNT_GROUPS.keys() + ["other"]:
		groups[g] = {"in": 0, "out": 0}
	var per_day: Array = []
	for d in range(first, today + 1):
		per_day.append({"day": d, "in": 0, "out": 0})
	var income := 0
	var out := 0
	for e: LedgerEntry in _books.ledger:
		if e.day < first or e.day > today:
			continue
		var side := "in" if e.amount > 0 else "out"
		groups[account_group(e.category)][side] += absi(e.amount)
		per_day[e.day - first][side] += absi(e.amount)
		if e.amount > 0:
			income += e.amount
		else:
			out -= e.amount
	return {"income": income, "outgoings": out, "net": income - out, "groups": groups, "days": per_day}


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


## Stock id for a raw material held by the kilo ("raw_steel": kg of steel).
const RAW_PREFIX := "raw_"


## Ship and Bay's recycler turned an item into materials (Void Salvage material id -> kg).
## Every peer hears it; the host puts the kilos into stock as "raw_<material>".
func _on_scrap_recycled(item_id: String, _qty: int, materials: Dictionary) -> void:
	if not _is_authority():
		return
	for material: String in materials:
		var kg := roundi(float(materials[material]))
		if kg > 0:
			add_stock(RAW_PREFIX + material, kg, PartCondition.NEW, "recycler:" + item_id)


## Puts parts into stock that didn't come by delivery: Ship and Bay's recycler hands its raw
## materials over here. Host only. Returns how many of that part are now in stock.
##   Modules.bus("business").call("add_stock", "steel_plate", 4, "new", "recycler")
func add_stock(part: String, qty: int, condition := "new", source := "recycler") -> int:
	if not _is_authority() or part == "" or qty <= 0 or not condition in PartCondition.ALL:
		return _books.stock_total(part)
	_books.add_stock(part, condition, qty)
	stock_added.emit(part, condition, qty, source)
	return _books.stock_total(part)


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
	if part.begins_with(RAW_PREFIX):
		return "%s (raw, kg)" % part.trim_prefix(RAW_PREFIX).capitalize()
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
	var materials := -1
	if Flags.is_on("business.economy"):
		materials = job_materials(contract_id)
		# Jobs whose parts aren't on the market (ship modules) still get goodwill, on top of
		# the deposit share standing in for the parts.
		if materials < 0:
			materials = value * get_rules().deposit_percent / 100
	return _books.accept_contract(contract_id, value, due_day, materials)


## What the parts BSX supplies for a job cost at market value, CR; -1 if the job or its
## manifest isn't known. Parts the client sends are left out.
func job_materials(contract_id: String) -> int:
	var contracts := Modules.bus("contracts") as ContractsBus
	var job := contracts.get_job(contract_id) if contracts else null
	if job == null or job.order == null or job.order.manifest.is_empty():
		return -1
	var total := 0
	var priced := false
	for line: ManifestLine in job.order.manifest:
		if line.supplied_by != "bsx" or line.component == null:
			continue
		var each := get_catalogue().value_of(line.component.id)
		if each > 0:
			total += each * line.qty
			priced = true
	# Ship modules (a tow winch) aren't market parts; those jobs fall back to the deposit share.
	return total if priced else -1


## Pays the rest of a contract and moves reputation. quality is 0-1. With contracts.kinds
## on, the job's recoveries (stripped parts, see take_recoveries) come into stock too;
## `recoveries` stands in for the job's own list when given (tests, the sandbox).
func on_contract_handed_over(contract_id: String, quality: float, open_snags: int,
		recoveries: Array = []) -> BusinessResult:
	if not _is_authority():
		return _not_host()
	var result := _books.hand_over(contract_id, quality, open_snags)
	if result.is_ok() and Flags.is_on("contracts.kinds"):
		_take_recoveries(contract_id, recoveries if not recoveries.is_empty() else job_recoveries(contract_id))
	return result


# --- Testing ---

func instant_deliveries() -> bool:
	return _books.instant_deliveries


## Turns instant deliveries on or off; turning them on lands everything already on its way.
func set_instant_deliveries(on: bool) -> void:
	_books.instant_deliveries = on
	if on and _is_authority():
		_books.deliver_now()


func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	if section == SETTINGS_SECTION and key == INSTANT_KEY:
		set_instant_deliveries(bool(value))


func _testing_section() -> Control:
	var t := CheckButton.new()
	t.name = "InstantDeliveries"
	t.text = "Instant deliveries: parts orders arrive as soon as they're placed (host)"
	t.button_pressed = bool(Settings.get_value(SETTINGS_SECTION, INSTANT_KEY))
	t.toggled.connect(func(on: bool) -> void: Settings.set_value(SETTINGS_SECTION, INSTANT_KEY, on))
	return t


# --- Scrapyard: break, scrap, refurbish and dispose jobs ---

## Job sizes, smallest first: a part on a bench, a ship in Dock 1, a hull in the big docks.
const JOB_SIZES: PackedStringArray = ["small", "medium", "large"]
## What a work order is for: "fit" (today's loop), "break", "scrap", "refurbish" or
## "dispose". "fit" for an unknown job or an order from before kinds.
func job_kind(contract_id: String) -> String:
	var job := _job(contract_id)
	var kind: Variant = job.order.get("kind") if job and job.order else null
	return str(kind) if kind is String and kind != "" else "fit"


## What has come out of a job so far (Contracts' job.recoveries): each {component
## {id, material} or material, kg, condition (0-1), disposition (returned, kept, scrapped,
## destroyed)}. [] for a fit job or an unknown one.
func job_recoveries(contract_id: String) -> Array:
	var job := _job(contract_id)
	var list: Variant = job.get("recoveries") if job else null
	return list if list is Array else []


## Labour for a job of this kind and size, CR, rounded to the hundred. t (0-1) places it
## within the size's range in the rules; the kind's factor scales it.
func labour_price(kind: String, size: String, t := 0.5) -> int:
	var r := get_rules()
	var span: Vector2i = {"medium": r.labour_medium, "large": r.labour_large}.get(size, r.labour_small)
	var base := lerpf(span.x, span.y, clampf(t, 0.0, 1.0)) * float(r.labour_kind_factor.get(kind, 1.0))
	return roundi(base / 100.0) * 100


## What the metal broker pays for kg of a material, CR: "bale" or "ingot". 0 for a
## material Void Salvage doesn't know.
func scrap_value(material: String, kg: float, form := "bale") -> int:
	if not Materials.TABLE.has(material) or kg <= 0.0:
		return 0
	var per := get_rules().scrap_per_kg * float(Materials.TABLE[material]["price"])
	if form == "ingot":
		per *= get_rules().ingot_factor
	return roundi(per * kg)


## The stock condition a stripped part goes in at: used, or damaged below the rules' line.
func recovery_condition(condition: float) -> String:
	return PartCondition.USED if condition >= get_rules().recovered_used_from else PartCondition.DAMAGED


## What one stripped part is worth on the shelf, CR (its new price at that condition's
## share); 0 for a part with no price.
func recovery_value(part: String, condition: float) -> int:
	var each := _books.catalogue.value_of(part)
	if each <= 0:
		each = _books.prices.price_of(part)
	if each <= 0:
		return 0
	return roundi(each * PartCondition.price_factor(recovery_condition(condition)))


## Sells kg of a raw material from stock to the metal broker. Host only.
func sell_scrap(material: String, kg: int, form := "bale") -> BusinessResult:
	if not _is_authority():
		return _not_host()
	var value := scrap_value(material, kg, form)
	if value <= 0:
		return BusinessResult.fail(ERR_INVALID_PARAMETER, "nobody buys %s" % material)
	if _books.take_stock(RAW_PREFIX + material, kg).is_empty():
		return BusinessResult.fail(ERR_DOES_NOT_EXIST, "not %d kg of %s in stock" % [kg, material])
	_books.post(value, LedgerEntry.SCRAP, "", "%d kg %s %s" % [kg, material, form])
	var r := BusinessResult.success()
	r.cost = -value
	return r


## Takes what a handed-over job left BSX into stock: parts "kept" go in used or damaged,
## kilos "kept" go in as raw material, less what the client's wants still claim of that
## material (Contracts counts kept kilos towards them). Parts and lots "scrapped" go in as
## kilos of their material when the order leaves the rest to BSX. Returned, destroyed and
## unknown lines add nothing.
func _take_recoveries(contract_id: String, recoveries: Array) -> void:
	var source := "contract:" + contract_id
	var job := _job(contract_id)
	var owed := {}  # material -> kg the client still wants out of the kept kilos
	for w: Variant in (job.order.get("wants") if job and job.order and job.order.get("wants") is Array else []):
		if w is Dictionary and w.get("what") == "material":
			owed[str(w.material)] = float(owed.get(str(w.material), 0.0)) + float(w.get("kg", 0.0))
	for rec: Variant in recoveries:
		if rec is Dictionary and rec.get("disposition") == "returned" and rec.has("material"):
			owed[str(rec.material)] = float(owed.get(str(rec.material), 0.0)) - float(rec.get("kg", 0.0))
	var bsx_keeps := str(job.order.get("keeps")) != "client" if job and job.order else true
	var kept := {}  # material -> kg kept as lots
	var scrapped := {}  # material -> kg cut up
	for rec: Variant in recoveries:
		if not rec is Dictionary:
			continue
		var d := rec as Dictionary
		var component: Variant = d.get("component")
		var is_part := component is Dictionary and str(component.get("id", "")) != ""
		var material := str(component.get("material", "")) if is_part else str(d.get("material", ""))
		match d.get("disposition"):
			"kept":
				if is_part:
					add_stock(str(component.id), 1, recovery_condition(float(d.get("condition", 1.0))), source)
				elif Materials.TABLE.has(material):
					kept[material] = float(kept.get(material, 0.0)) + float(d.get("kg", 0.0))
			"scrapped":
				if bsx_keeps and Materials.TABLE.has(material):
					scrapped[material] = float(scrapped.get(material, 0.0)) + float(d.get("kg", 0.0))
	for material: String in kept:
		kept[material] = maxf(0.0, kept[material] - maxf(0.0, float(owed.get(material, 0.0))))
	for material: String in scrapped:
		kept[material] = float(kept.get(material, 0.0)) + scrapped[material]
	for material: String in kept:
		var kg := roundi(kept[material])
		if kg > 0:
			add_stock(RAW_PREFIX + material, kg, PartCondition.NEW, source)


func _job(contract_id: String) -> ContractJob:
	var contracts := Modules.bus("contracts") as ContractsBus
	return contracts.get_job(contract_id) if contracts else null


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
	# The purchase order is the wrist's (shared with the TVs): fill it, then open on it.
	wrist_basket.clear()
	for l in get_listings():
		if l.available >= 2 and wrist_basket.size() < 4 and not l.id.begins_with("S-"):
			wrist_basket[l.id] = 1 + wrist_basket.size() % 2
	front.call("open_terminal")


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
