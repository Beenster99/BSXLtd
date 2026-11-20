class_name CompanyBus
extends Node
## The company (master plan Wave 8: the game holding together over many sessions).
##   8.1 Growth: the yard's rank (Workshop, Yard, Shipworks, Consortium) rises with the ships it
##       has delivered and its reputation, and each rank opens more: a holding berth, room for
##       more bots, the specialist bots, bigger ship classes on the board.
##   8.2 Clients: rival yards bid for the same orders (BSX signs at the lowest rival bid unless
##       the client knows it well), and a client pleased with a ship comes back with a repeat
##       order, a little richer.
##   8.3 Crew: each player takes a role (foreman, buyer, welder, launch master) that helps the
##       yard while they are on shift; a share of each ship's trial bonus goes to the crew.
##   8.4 Launch: the crew names the ship; at delivery the bots line up, a bottle breaks on her
##       bow and she leaves the berth under her own power; the yard keeps a record of every ship
##       it built (its trophy shelf, each plaque signed by the crew).
## 8.5 (our ships as Void Salvage wrecks) waits for Dan.
##
##   var co := Modules.bus("company") as CompanyBus
##   co.rank()                     # {id, name, ships, reputation, bots, holding, sizes}
##   co.rival_bids(order)          # [{yard, name, price}] cheapest first
##   co.name_ship(cid, "Kestrel's Pride")
##   co.record                     # every ship delivered
##
## Flags: "company" (the module), "company.growth" (ranks gate berths, bots and ship classes),
## "company.rivals" (rival yards' bids), "company.launch" (the send-off).

signal changed
signal launched(entry: Dictionary)

const FLAG := "company"
const GROWTH_FLAG := "company.growth"
const RIVALS_FLAG := "company.rivals"
const LAUNCH_FLAG := "company.launch"
const SAVE_SECTION := "company"
const SAVE_VERSION := 1
const ASK_EVENT := "company.ask"
const STATE_EVENT := "company.state"
const LAUNCH_EVENT := "company.launch"
const WALL_VIEW := "company"
const WALL_SHELF := "trophies"
const HOLO_CHANNEL := "company.yard"
const CompanyScreen := preload("res://modules/company/internal/company_screen.gd")
const Launch := preload("res://modules/company/internal/launch.gd")

## The yard's ranks, lowest first: ships delivered and reputation (0-100) to reach it, bots it
## can keep, holding berths, ship sizes it may sign (ShipOrders.SIZES), bot types it can buy.
const RANKS: Array = [
	{"id": "workshop", "name": "Workshop", "ships": 0, "reputation": 0.0, "bots": 12, "holding": 1,
			"sizes": ["small", "medium"], "bots_new": []},
	{"id": "yard", "name": "Yard", "ships": 1, "reputation": 25.0, "bots": 16, "holding": 2,
			"sizes": ["small", "medium", "large"], "bots_new": ["frame_tech", "fitout_tech"]},
	{"id": "shipworks", "name": "Shipworks", "ships": 3, "reputation": 50.0, "bots": 24, "holding": 2,
			"sizes": ["small", "medium", "large", "capital"], "bots_new": []},
	{"id": "consortium", "name": "Consortium", "ships": 6, "reputation": 75.0, "bots": 32, "holding": 2,
			"sizes": ["small", "medium", "large", "capital", "mega"], "bots_new": []},
]
## Rival yards: their name, line, and the share of the client's budget they bid (lo, hi).
const RIVALS: Array = [
	{"id": "harrow", "name": "Harrow Dockyards", "line": "big, slow and cheap", "bid": Vector2(0.84, 0.97)},
	{"id": "calloway", "name": "Calloway & Vine", "line": "fine work at a fine price", "bid": Vector2(0.95, 1.08)},
	{"id": "ostrava", "name": "Ostrava Orbital", "line": "hungry for work", "bid": Vector2(0.8, 1.02)},
	{"id": "kelso", "name": "Kelso Brothers", "line": "a family yard of the old school", "bid": Vector2(0.9, 1.0)},
]
## How many rivals bid for one order, and the client level (ContractsBus.level_of) from which a
## client signs with BSX at its own price, rivals or not.
const RIVALS_PER_ORDER := 2
const LOYAL_LEVEL := 2
## A repeat order: a client whose ship scored this well at her trial comes back with this much
## more budget.
const REPEAT_QUALITY := 0.75
const REPEAT_BUDGET := 1.1
## Crew roles: id -> {name, what it does, perk key and factor}.
const ROLES := {
	"foreman": {"name": "Foreman", "what": "The bots work 10% faster while a foreman is on shift.", "perk": "bots", "factor": 1.1},
	"buyer": {"name": "Buyer", "what": "Parts orders cost 5% less while a buyer is on shift.", "perk": "parts", "factor": 0.95},
	"welder": {"name": "Welder", "what": "Hand fastenings go in a little better (+5% quality).", "perk": "hand", "factor": 1.05},
	"launch": {"name": "Launch master", "what": "The crew's share of each trial bonus is doubled.", "perk": "share", "factor": 2.0},
}
## The crew's share of a ship's trial bonus, split between the players on shift.
const CREW_SHARE := 0.05

## Every ship delivered: {cid, name, design, client, day, quality, workmanship, jobs, price, crew
## (the names that signed her plate), side (a few hundred [z, y, w, h] rects: her miniature)}.
var record: Array = []
## Build id -> the name the crew gave her.
var names: Dictionary = {}
## Player name -> role id.
var roles: Dictionary = {}

var _net: Object
var _contracts: Object
var _business: Object
var _build: Object
var _launch: Node3D


func register_module() -> void:
	Saves.register_section(SAVE_SECTION, self)
	HudSlots.register_holo_channel(HOLO_CHANNEL, "The company",
			func(_glass: bool = false) -> Control: return make_screen(150.0), 55)
	Menu.register_settings_section(Menu.DEBUG, "company.debug", "Company", _debug_panel, 38)
	if Modules.ready_done:
		_hook_up()
	else:
		Modules.modules_ready.connect(_hook_up, CONNECT_ONE_SHOT)


func unregister_module() -> void:
	Saves.unregister_section(SAVE_SECTION)
	HudSlots.unregister_holo_channel(HOLO_CHANNEL)
	var design := Modules.bus("design")
	if design:
		design.call("unregister_wall_view", WALL_VIEW)
		design.call("unregister_wall_view", WALL_SHELF)


func _hook_up() -> void:
	_contracts = Modules.bus("contracts")
	_business = Modules.bus("business")
	_build = Modules.bus("build")
	hook_net(Modules.bus("multiplayer"))
	if _contracts:
		if _contracts.has_method("register_sign_check"):
			_contracts.call("register_sign_check", "company", sign_check)
			_contracts.call("register_price_rule", "company", price_rule)
			_contracts.call("register_order_source", "company", repeat_orders)
		if _contracts.has_signal("contract_handed_over"):
			_contracts.connect("contract_handed_over", _on_handed_over)
	var design := Modules.bus("design")
	if design:
		design.call("register_wall_view", WALL_VIEW, "THE COMPANY", make_screen)
		design.call("register_wall_view", WALL_SHELF, "TROPHY SHELF", func(px: float) -> Control: return make_screen(px, "SHELF"))
	_add_help()


func hook_net(net: Object) -> void:
	_net = net
	if _net == null:
		return
	_net.call("register_event", ASK_EVENT, _apply_ask, _validate_ask)
	_net.call("register_event", STATE_EVENT, _apply_state, func(_s: int, p: Dictionary) -> Variant: return p)
	_net.call("register_event", LAUNCH_EVENT, _apply_launch, func(_s: int, p: Dictionary) -> Variant: return p)
	_net.call("register_snapshot_provider", SAVE_SECTION, self)


func is_host() -> bool:
	return _net == null or not bool(_net.call("is_online")) or bool(_net.call("is_host"))


func _online() -> bool:
	return _net != null and bool(_net.call("is_online"))


func make_screen(px_per_m: float, page := "RANK") -> Control:
	var s := CompanyScreen.new()
	s.setup(self, px_per_m, page)
	return s


# --- 8.1 Growth ---------------------------------------------------------------------------------

func reputation() -> float:
	return float(_business.call("get_reputation")) if _business and _business.has_method("get_reputation") else 0.0


## The yard's rank now: RANKS' entry with "index".
func rank() -> Dictionary:
	var at := 0
	for i in RANKS.size():
		var r: Dictionary = RANKS[i]
		if record.size() >= int(r.ships) and reputation() >= float(r.reputation):
			at = i
	var out: Dictionary = (RANKS[at] as Dictionary).duplicate(true)
	out["index"] = at
	return out


## The rank after this one, or {} at the top.
func next_rank() -> Dictionary:
	var i := int(rank().index) + 1
	return (RANKS[i] as Dictionary).duplicate(true) if i < RANKS.size() else {}


func _growth() -> bool:
	return Flags.is_on(GROWTH_FLAG)


## Bots the yard can keep (BotsBus asks before a buy).
func bot_cap() -> int:
	return int(rank().bots) if _growth() else 999


## Why bot type `type_id` can't be bought yet ("" if it can).
func bot_unlock(type_id: String) -> String:
	if not _growth():
		return ""
	var have := int(rank().index)
	for i in RANKS.size():
		if (RANKS[i].bots_new as Array).has(type_id) and i > have:
			return "the %s comes with the rank of %s" % [type_id.replace("_", " "), str(RANKS[i].name)]
	return ""


## Holding berths open (BuildBus asks).
func holding_berths() -> int:
	return int(rank().holding) if _growth() else 2


## A ship order's sign check (ContractsBus): her size is open at the yard's rank.
func sign_check(order: Dictionary) -> String:
	if not _growth():
		return ""
	var size := str(order.get("size", "small"))
	var r := rank()
	if (r.sizes as Array).has(size):
		return ""
	for i in RANKS.size():
		if (RANKS[i].sizes as Array).has(size):
			return "a %s ship needs a yard of the rank of %s (BSX is a %s)" % [size, str(RANKS[i].name), str(r.name)]
	return ""


# --- 8.2 Clients: rivals and repeat orders -------------------------------------------------------

## The rival yards bidding for `order`, cheapest first: [{yard, name, line, price}]. The same on
## every machine (from the order's id).
func rival_bids(order: Dictionary) -> Array:
	var out: Array = []
	if not Flags.is_on(RIVALS_FLAG):
		return out
	var budget := float(order.get("budget", (order.get("demands", {}) as Dictionary).get("budget", 0.0)))
	if budget <= 0.0:
		return out
	var id := str(order.get("id", ""))
	var picks: Array = []
	var start := absi(hash(id)) % RIVALS.size()
	for i in RIVALS_PER_ORDER:
		picks.append(RIVALS[(start + i * 3) % RIVALS.size()])
	for r: Dictionary in picks:
		var u := float(absi(hash(id + str(r.id))) % 1000) / 1000.0
		var share := lerpf((r.bid as Vector2).x, (r.bid as Vector2).y, u)
		out.append({"yard": str(r.id), "name": str(r.name), "line": str(r.line), "price": roundi(budget * share / 1000.0) * 1000})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.price) < int(b.price))
	return out


## ContractsBus' price rule: BSX signs at no more than the lowest rival bid, unless the client
## knows the yard well (level LOYAL_LEVEL) or it is a repeat order.
func price_rule(order: Dictionary, price: int) -> int:
	if bool(order.get("repeat", false)) or _client_level(str(order.get("client", ""))) >= LOYAL_LEVEL:
		return price
	var bids := rival_bids(order)
	if bids.is_empty():
		return price
	return mini(price, int(bids[0].price))


func _client_level(client: String) -> int:
	return int(_contracts.call("level_of", client)) if _contracts and _contracts.has_method("level_of") else 0


## Repeat orders (ContractsBus' order source): a client pleased with a ship comes back with one
## like it, a little richer, until it is signed.
func repeat_orders() -> Array:
	var out: Array = []
	if _contracts == null:
		return out
	for e: Dictionary in record:
		if float(e.get("quality", 0.0)) < REPEAT_QUALITY:
			continue
		var c: Dictionary = _contracts.call("ship_contract", str(e.cid))
		var o: Dictionary = (c.get("order", {}) as Dictionary).duplicate(true)
		if o.is_empty() or bool(o.get("repeat", false)):
			continue
		o.id = "rep_%s" % str(o.get("id", e.cid))
		o["repeat"] = true
		o["title"] = "Repeat order: %s" % str(o.get("title", e.design))
		if o.has("budget"):
			o.budget = roundi(float(o.budget) * REPEAT_BUDGET)
		if o.has("demands") and (o.demands as Dictionary).has("budget"):
			o.demands.budget = roundi(float(o.demands.budget) * REPEAT_BUDGET)
		out.append(o)
	return out


# --- 8.3 Crew roles ---------------------------------------------------------------------------------

## The players on shift now (the business module's crew), or just this player.
func crew() -> Array:
	var out: Array = []
	if _business and _business.has_method("crew_names"):
		for n: Variant in (_business.call("crew_names") as Dictionary).values():
			out.append(str(n))
	if out.is_empty():
		out.append(me())
	return out


func me() -> String:
	var n := ""
	if _business and _business.has_method("player_name"):
		n = str(_business.call("player_name", multiplayer.get_unique_id() if _online() else 1))
	return n if n != "" else "You"


## A role's factor while someone on shift has it (1.0 otherwise): "bots", "parts", "hand", "share".
func perk(key: String) -> float:
	var on := crew()
	for who: String in roles:
		var r: Dictionary = ROLES.get(str(roles[who]), {})
		if str(r.get("perk", "")) == key and on.has(who):
			return float(r.factor)
	return 1.0


func set_role(who: String, role: String) -> void:
	_ask({"what": "role", "who": who, "role": role})


# --- 8.4 Launch -------------------------------------------------------------------------------

func name_ship(cid: String, ship_name: String) -> void:
	_ask({"what": "name", "cid": cid, "name": ship_name.strip_edges().left(32)})


func name_of(cid: String) -> String:
	return str(names.get(cid, ""))


## The ship was handed over (ContractsBus): the host writes her in the record, pays the crew
## their share, and every machine sees her off.
func _on_handed_over(contract_id: String, quality: float, _snags: int) -> void:
	if not is_host():
		return
	var c: Dictionary = _contracts.call("ship_contract", contract_id) if _contracts else {}
	var entry := {"cid": contract_id, "name": name_of(contract_id) if name_of(contract_id) != "" else str(c.get("design_name", "Unnamed")),
			"design": str(c.get("design_name", "")), "client": str((c.get("order", {}) as Dictionary).get("client_name",
			(c.get("order", {}) as Dictionary).get("client", ""))), "day": int(_contracts.call("today")) if _contracts else 0,
			"quality": snappedf(quality, 0.01), "price": int(c.get("price", 0)), "crew": crew(), "jobs": 0, "workmanship": -1.0,
			"side": []}
	if _build and (_build.get("builds") as Dictionary).has(contract_id):
		var p: Dictionary = _build.call("progress", contract_id)
		entry.jobs = int(p.get("jobs_done", 0))
		entry.workmanship = snappedf(float(p.get("workmanship", -1.0)), 0.01)
		entry.side = side_of(contract_id)
	record.append(entry)
	_share_bonus(c, entry)
	if _online():
		_net.call("host_emit", LAUNCH_EVENT, {"entry": entry})
	else:
		_apply_launch({"entry": entry})


func _apply_launch(p: Dictionary) -> void:
	var entry: Dictionary = p.get("entry", {})
	if not is_host():
		record.append(entry)
	changed.emit()
	launched.emit(entry)
	if Flags.is_on(LAUNCH_FLAG):
		send_off(str(entry.get("cid", "")), str(entry.get("name", "")))


## Her miniature: the side view of every part fixed so far, as [z, y, w, h] (m), a few hundred at most.
func side_of(cid: String) -> Array:
	var out: Array = []
	var bp: Object = _build.call("blueprint", cid) if _build else null
	var b: Dictionary = (_build.get("builds") as Dictionary).get(cid, {}) if _build else {}
	if bp == null:
		return out
	var pl: BuildPlan = _build.call("plan", cid)
	var ids: Array = []
	for j: int in b.get("landed", []):
		ids.append_array(pl.jobs[j].parts)
	var step := maxi(1, ids.size() / 400)
	for i in range(0, ids.size(), step):
		var box: AABB = bp.call("box_of", int(ids[i]))
		out.append([snappedf(box.position.z, 0.01), snappedf(-box.end.y, 0.01), snappedf(box.size.z, 0.01), snappedf(box.size.y, 0.01)])
	return out


## The trial bonus' crew share, split between the players on shift (a launch master doubles it).
func _share_bonus(c: Dictionary, entry: Dictionary) -> void:
	if _business == null or not _business.has_method("request_bonus") or not _online():
		return
	var bonus := int((c.get("trial", {}) as Dictionary).get("bonus", 0))
	var pot := roundi(bonus * CREW_SHARE * perk("share"))
	var peers: Dictionary = _business.call("crew_names")
	if pot <= 0 or peers.is_empty():
		return
	var each := pot / peers.size()
	for peer: int in peers:
		_business.call("request_bonus", peer, each, "Launch bonus: %s" % str(entry.name))


## The send-off in the open station: the bots line up, a bottle breaks on her bow and she leaves
## the build berth under her own power.
func send_off(cid: String, ship_name: String) -> void:
	var yard := Modules.bus("yard")
	var st: Node3D = yard.call("station") if yard and yard.has_method("station") else null
	if st == null or _build == null or not (_build.get("builds") as Dictionary).has(cid):
		return
	var view: Node3D = _build.call("ship_view", cid)
	if view == null:
		return
	if _launch and is_instance_valid(_launch):
		_launch.queue_free()
	_launch = Launch.new()
	_launch.name = "Launch"
	st.add_child(_launch)
	_launch.transform = _build.call("berth_xf", "B1")
	_launch.call("setup", view, ship_name)
	var bots := Modules.bus("bots")
	if bots and bots.has_method("line_up"):
		bots.call("line_up", Launch.SECONDS)
	var berth: Node3D = _build.get("berth")
	if berth and is_instance_valid(berth) and str(berth.get("contract")) == cid:
		berth.visible = false


# --- Asking ---------------------------------------------------------------------------------------

func _ask(p: Dictionary) -> void:
	if _online():
		_net.call("request", ASK_EVENT, p)
		return
	var ok: Variant = _validate_ask(1, p)
	if ok is Dictionary:
		_apply_ask(ok)


func _validate_ask(_sender: int, p: Dictionary) -> Variant:
	match str(p.get("what", "")):
		"name":
			if str(p.get("name", "")) == "":
				return "give her a name"
		"role":
			if str(p.get("role", "")) != "" and not ROLES.has(str(p.role)):
				return "no such role"
		_:
			return "unknown ask"
	return p


func _apply_ask(p: Dictionary) -> void:
	match str(p.what):
		"name":
			names[str(p.cid)] = str(p.name)
		"role":
			if str(p.role) == "":
				roles.erase(str(p.who))
			else:
				roles[str(p.who)] = str(p.role)
	changed.emit()
	if is_host() and _online():
		_net.call("host_emit", STATE_EVENT, save_data())


func _apply_state(p: Dictionary) -> void:
	if not is_host():
		load_data(p, SAVE_VERSION)


# --- 8.6 Polish: the help pages --------------------------------------------------------------------

func _add_help() -> void:
	var help := Modules.bus("help")
	if help == null or not help.has_method("add_topic"):
		return
	help.call("add_topic", "bots", "Build bots",
			"Bigger ships are built in the berth by the yard's bots. Open the BOT BOARD (a wall in the design room, or the wrist) to see the crew, set the rule cards that say what they do first, buy specialists in the SHOP and watch the work. Welders weld four times as fast as a yardhand; haulers fetch parts; inspectors make poor fastenings again. Fly to the glowing pieces and press F to take a job yourself, or TAKE OVER one on the WORK page. Bots low on charge dock in the bot bay beside the build berth.", 30)
	help.call("add_topic", "orders", "Ordering parts",
			"A ship's parts list comes to PARTS ORDERS (a wall in the design room, or the wrist). Click a vendor's quote to take a line from them, or ½ to split it between two. The calculator sums the cheapest, the most reliable and the median plans against your own mix. PLACE ORDER buys it; EXPRESS brings it today for 35% more. Each stage of the build waits until its parts are in. Components can be bought second-hand: cheaper, and refurbished in the annex before they count.", 31)
	help.call("add_topic", "berths", "Holding berths",
			"Only the ship in the build berth (B1) is worked. On the Build plan page, TUG TO H1 or H2 takes a part-built ship to a holding berth to free the build berth for another contract; tug her back when you are ready. Holding berths open as the company grows.", 32)
	help.call("add_topic", "company", "The company",
			"THE COMPANY page shows the yard's rank: deliver ships and earn reputation to rise from Workshop to Yard, Shipworks and Consortium. Each rank opens holding berths, more bots, specialist bots and bigger ship classes. Rival yards bid for the same orders: you sign at the lowest rival bid unless the client knows you well. Pleased clients come back with repeat orders. Take a crew role (foreman, buyer, welder, launch master), name your ship before her trial, and every ship you deliver goes on the trophy shelf, signed by the crew.", 33)


# --- Saving -----------------------------------------------------------------------------------------

func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	return {"record": record.duplicate(true), "names": names.duplicate(), "roles": roles.duplicate()}


func load_data(data: Dictionary, _from_version: int) -> void:
	record = (data.get("record", []) as Array).duplicate(true)
	names = (data.get("names", {}) as Dictionary).duplicate()
	roles = (data.get("roles", {}) as Dictionary).duplicate()
	changed.emit()


func reset_data() -> void:
	load_data({}, SAVE_VERSION)


func get_net_snapshot() -> Dictionary:
	return save_data()


func apply_net_snapshot(data: Dictionary) -> void:
	load_data(data, SAVE_VERSION)


func _debug_panel() -> Control:
	var box := VBoxContainer.new()
	for row: Array in [["Company: a ship delivered (record)", func() -> void:
				record.append({"cid": "debug_%d" % record.size(), "name": "Debug %d" % (record.size() + 1), "design": "Debug",
						"client": "", "day": 0, "quality": 0.9, "price": 1000000, "crew": crew(), "jobs": 0, "workmanship": 0.8, "side": []})
				changed.emit()],
			["Company: launch the build in the berth", func() -> void:
				var cid := str(_build.get("current")) if _build else ""
				if cid != "":
					send_off(cid, name_of(cid) if name_of(cid) != "" else "Test launch")]]:
		var b := Button.new()
		b.text = row[0]
		b.pressed.connect(row[1])
		box.add_child(b)
	return box
