class_name OrdersBus
extends Node
## Ordering a build's parts and their deliveries (master plan Wave 7: 7.1 ordering from the
## design, 7.2 automated deliveries, 7.3 worn parts and refurbishing). Each build in the yard
## (BuildBus.builds) has a parts list from its design (OrderBook.lines_for): you choose where
## each line comes from, splitting it across vendors if you like (100 plates from one, 50 from
## another), or take a plan the calculator works out (cheapest, most reliable, median), and
## place the order. The company pays, each vendor's share comes on the day its quote says (or
## late: a vendor's reliability is how often it doesn't), its loads go into the stores (the
## haulers bring them in), and a build's stage can't start in the berth till its parts are in.
## A second-hand component goes through the refurb works first, cheaper and slower.
##
##   var orders := Modules.bus("orders") as OrdersBus
##   orders.lines(cid)                     # the build's lines, each with need, ordered, arrived
##   orders.use_plan(cid, "cheapest")      # every line split to the plan's vendor
##   orders.set_split(cid, key, vendor, qty)
##   orders.place(cid, express)            # buys what is split and not ordered yet
##   orders.stage_ready(cid, "frame")      # the build waits on this (BuildBus.parts_ready)
##
## Features (Flags): "orders" (the module), "orders.gate" (builds wait for their parts),
## "orders.used" (second-hand parts through the refurb works).

signal changed
signal arrived(order: Dictionary)

const FLAG := "orders"
const GATE_FLAG := "orders.gate"
const USED_FLAG := "orders.used"
const SAVE_SECTION := "orders"
const SAVE_VERSION := 1
const ASK_EVENT := "orders.ask"
const STATE_EVENT := "orders.state"
const WALL_VIEW := "orders"
const HOLO_CHANNEL := "orders.book"
const USED := "used"
## How often the host looks for deliveries due (s).
const CHECK_EVERY := 1.0
## A vendor's standing goes up this much for each order placed with it, and a little more
## for each CR 100,000 of it.
const STANDING_PER_ORDER := 0.6
const STANDING_PER_100K := 0.4
const OrdersScreen := preload("res://modules/orders/internal/orders_screen.gd")

## Build id -> {line key -> [{vendor, qty, used}]}: where each line is to come from.
var splits: Dictionary = {}
## Every order placed: {id, cid, vendor, minute (placed), due (minute it comes), late (days),
## express, lines: [{key, name, qty, unit, used}], total, arrived (bool), refurb: {type: count}}.
var orders: Array = []
## Builds whose parts it waits for (a build started with the gate on, before anything landed).
var tracked: Dictionary = {}
## Build id -> stages whose parts went out to the berth from the stores.
var sent: Dictionary = {}
var next_id := 1

var _net: Object
var _build: Object
var _supply: Object
var _business: Object
var _refurb: Object
var _time: Object
var _lines: Dictionary = {}   # cid -> Array[Dictionary]
var _check_in := 0.0


func register_module() -> void:
	Saves.register_section(SAVE_SECTION, self)
	HudSlots.register_holo_channel(HOLO_CHANNEL, "Parts orders",
			func(_glass: bool = false) -> Control: return make_screen(150.0), 25)
	Menu.register_settings_section(Menu.DEBUG, "orders.debug", "Orders", _debug_panel, 37)
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


func _hook_up() -> void:
	_build = Modules.bus("build")
	_supply = Modules.bus("supply")
	_business = Modules.bus("business")
	_refurb = Modules.bus("refurb")
	_time = Modules.bus("time")
	hook_net(Modules.bus("multiplayer"))
	if _build:
		_build.connect("build_changed", _on_build_changed)
	if _refurb and _refurb.has_signal("part_certified"):
		_refurb.connect("part_certified", _on_certified)
	var design := Modules.bus("design")
	if design:
		design.call("register_wall_view", WALL_VIEW, "PARTS ORDERS", make_screen)


func hook_net(net: Object) -> void:
	_net = net
	if _net == null:
		return
	_net.call("register_event", ASK_EVENT, _apply_ask, _validate_ask)
	_net.call("register_event", STATE_EVENT, _apply_state, _validate_state)
	_net.call("register_snapshot_provider", SAVE_SECTION, self)


func is_host() -> bool:
	return _net == null or not bool(_net.call("is_online")) or bool(_net.call("is_host"))


func make_screen(px_per_m: float) -> Control:
	var s := OrdersScreen.new()
	s.setup(self, px_per_m)
	return s


# --- The time -----------------------------------------------------------------------------------

## Game minutes since the company began (the time module's clock, else the business day's).
func now_minute() -> int:
	if _time and _time.has_method("now_minute"):
		return int(_time.call("now_minute"))
	if _business and _business.has_method("get_day"):
		return int(_business.call("get_day")) * 1440
	return 0


func market_day() -> int:
	return int(_supply.get("day")) if _supply else 0


# --- A build's parts list ------------------------------------------------------------------------

func catalog() -> DesignCatalog:
	var design := Modules.bus("design")
	return design.get("catalog") if design else DesignCatalog.load_default()


## Build `cid`'s lines to buy (OrderBook.lines_for), each with "need" (qty), "split" (qty split
## to vendors so far), "ordered" and "arrived" (qty).
func lines(cid: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _build == null or not (_build.get("builds") as Dictionary).has(cid):
		return out
	if not _lines.has(cid):
		_lines[cid] = OrderBook.lines_for((_build.get("builds")[cid] as Dictionary).get("design", {}), catalog())
	var sp: Dictionary = splits.get(cid, {})
	var ord := _ordered(cid)
	var arr := _arrived(cid)
	for l: Dictionary in _lines[cid]:
		var e := l.duplicate()
		e["need"] = float(l.qty)
		var s := 0.0
		for p: Dictionary in sp.get(str(l.key), []):
			s += float(p.qty)
		e["split"] = s
		e["ordered"] = float(ord.get(str(l.key), 0.0))
		e["arrived"] = float(arr.get(str(l.key), 0.0))
		out.append(e)
	return out


func line(cid: String, key: String) -> Dictionary:
	for l in lines(cid):
		if str(l.key) == key:
			return l
	return {}


## Every vendor's quote for what is still to order of `line` today, cheapest first; a
## second-hand quote ("used") among them where it can be had.
func quotes(cid: String, l: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _supply == null:
		return out
	var cat := catalog()
	var buyer := _buyer()
	for v: SupplyVendor in _supply.get("vendors"):
		var q := SupplyMarket.quote(v, l, market_day(), float(_supply.call("standing_of", v.id)), cat)
		if not q.is_empty():
			if buyer < 1.0:
				q.unit = float(q.unit) * buyer
				if q.has("total"):
					q.total = float(q.total) * buyer
			q["name"] = v.display_name
			q["colour"] = v.colour
			out.append(q)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.unit) < float(b.unit))
	if Flags.is_on(USED_FLAG) and OrderBook.can_buy_used(l) and not out.is_empty():
		var est := _refurb_estimate(OrderBook.used_type(l))
		if not est.is_empty():
			var mid: Dictionary = out[floori((out.size() - 1) / 2.0)]
			var u := OrderBook.used_quote(l, float(l.qty), float(mid.unit), float(est.get("cost", 0.0)))
			u["name"] = "Second-hand (refurbished here)"
			u["colour"] = Color("c8a26a")
			out.append(u)
	return out


## A buyer on shift (the company's crew roles) gets the vendors' parts a little cheaper.
func _buyer() -> float:
	var co := Modules.bus("company")
	return float(co.call("perk", "parts")) if co and co.has_method("perk") else 1.0


func _refurb_estimate(type_id: String) -> Dictionary:
	if _refurb == null or not _refurb.has_method("estimate"):
		return {}
	return _refurb.call("estimate", type_id, OrderBook.USED_CONDITION)


## What build `cid`'s lines cost and when they come under a plan (SupplyOptimiser's CHEAPEST,
## RELIABLE, MEDIAN) or as split now ("mine"): {total, lead (days, longest), on_time, lines}.
func plan_sums(cid: String) -> Dictionary:
	var out := {}
	var ls := _to_order(cid)
	if ls.is_empty() or _supply == null:
		return out
	var o := SupplyOptimiser.run(ls, _supply.get("vendors"), _standing(), market_day(), catalog())
	for p: String in SupplyOptimiser.PLANS:
		out[p] = o.plans[p]
	var mine := {"total": 0.0, "lead": 0, "on_time": 1.0, "lines": 0}
	for l in lines(cid):
		for p: Dictionary in (splits.get(cid, {}) as Dictionary).get(str(l.key), []):
			var q := _quote_of(cid, l, str(p.vendor))
			if q.is_empty():
				continue
			mine.total = float(mine.total) + float(q.unit) * float(p.qty)
			mine.lead = maxi(int(mine.lead), int(q.lead))
			mine.on_time = float(mine.on_time) * float(q.on_time)
			mine.lines = int(mine.lines) + 1
	out["mine"] = mine
	return out


## The lines of build `cid` with something still to order, the quantity left as their qty.
func _to_order(cid: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l in lines(cid):
		var left := float(l.need) - float(l.ordered)
		if left > 0.0001:
			var e := l.duplicate()
			e.qty = left
			var pack := float(l.need) / maxf(1.0, float(l.units))
			e.units = maxi(1, ceili(left / maxf(pack, 0.0001) - 0.0001))
			out.append(e)
	return out


func _quote_of(cid: String, l: Dictionary, vendor: String) -> Dictionary:
	for q in quotes(cid, l):
		if str(q.vendor) == vendor:
			return q
	return {}


func _standing() -> Dictionary:
	var out := {}
	if _supply:
		for v: SupplyVendor in _supply.get("vendors"):
			out[v.id] = float(_supply.call("standing_of", v.id))
	return out


func _ordered(cid: String) -> Dictionary:
	var out := {}
	for o: Dictionary in orders:
		if str(o.cid) == cid:
			for l: Dictionary in o.lines:
				out[str(l.key)] = float(out.get(str(l.key), 0.0)) + float(l.qty)
	return out


## What has come in, line by line: a second-hand line counts once the works has certified it.
func _arrived(cid: String) -> Dictionary:
	var out := {}
	for o: Dictionary in orders:
		if str(o.cid) != cid or not bool(o.arrived):
			continue
		for l: Dictionary in o.lines:
			var q := float(l.qty)
			if bool(l.get("used", false)):
				q = maxf(0.0, q - float(l.get("refurbing", 0)))
			out[str(l.key)] = float(out.get(str(l.key), 0.0)) + q
	return out


# --- What a build waits for ----------------------------------------------------------------------

## Whether build `cid` waits for its ordered parts (started with the gate on).
func gated(cid: String) -> bool:
	return Flags.is_on(GATE_FLAG) and tracked.has(cid)


## Whether the parts for `stage` of build `cid` are all in (always, for a build that doesn't wait).
func stage_ready(cid: String, stage: String) -> bool:
	if not gated(cid):
		return true
	for l in lines(cid):
		if str(l.stage) == stage and float(l.arrived) < float(l.need) - 0.001:
			return false
	return true


## Why `stage` of build `cid` can't start: "" when it can, else a line for the berth's card
## ("Frame parts not ordered", "Plates and walls parts due in 2 days").
func stage_wait(cid: String, stage: String) -> String:
	if stage_ready(cid, stage):
		return ""
	var name := str((BuildPlan.STAGES.get(stage, {}) as Dictionary).get("name", stage))
	var unordered := false
	var due := -1
	for l in lines(cid):
		if str(l.stage) != stage or float(l.arrived) >= float(l.need) - 0.001:
			continue
		if float(l.ordered) < float(l.need) - 0.001:
			unordered = true
	for o: Dictionary in orders:
		if str(o.cid) == cid and not bool(o.arrived) and (o.lines as Array).any(func(x: Dictionary) -> bool: return str(_stage_of_key(cid, str(x.key))) == stage):
			due = maxi(due, int(o.due) + int(o.late) * 1440)
	if unordered:
		return "%s parts not ordered: order them at the parts orders screen" % name
	if due < 0:
		return "%s parts in the refurb works" % name
	return "%s parts due %s" % [name, when(due)]


func _stage_of_key(cid: String, key: String) -> String:
	for l: Dictionary in _lines.get(cid, []):
		if str(l.key) == key:
			return str(l.stage)
	return ""


## A minute as words from now: "in 3 h", "in 2 days", "now".
func when(minute: int) -> String:
	var left := minute - now_minute()
	if left <= 0:
		return "now"
	if left < 60:
		return "in %d min" % left
	if left < 1440:
		return "in %d h" % ceili(left / 60.0)
	var d := ceili(left / 1440.0)
	return "in %d day%s" % [d, "" if d == 1 else "s"]


# --- Asking (through the host) ----------------------------------------------------------------

## Line `key` of build `cid`: `qty` of it from `vendor` (0 takes the vendor off the line).
func set_split(cid: String, key: String, vendor: String, qty: float) -> void:
	_ask({"what": "split", "cid": cid, "key": key, "vendor": vendor, "qty": qty})


## Every line still to order split whole to the vendor plan `plan` picks for it.
func use_plan(cid: String, plan: String) -> void:
	_ask({"what": "plan", "cid": cid, "plan": plan})


func clear_splits(cid: String) -> void:
	_ask({"what": "clear", "cid": cid})


## Buys what is split for build `cid` and not ordered yet, one order a vendor. `express`: it
## comes today, dearer.
func place(cid: String, express := false) -> void:
	_ask({"what": "place", "cid": cid, "express": express})


## The cheapest plan, placed at once (the berth's and the board's one button).
func order_cheapest(cid: String, express := false) -> void:
	use_plan(cid, SupplyOptimiser.CHEAPEST)
	place(cid, express)


func _ask(p: Dictionary) -> void:
	if _net and bool(_net.call("is_online")):
		_net.call("request", ASK_EVENT, p)
		return
	var ok: Variant = _validate_ask(1, p)
	if ok is Dictionary:
		_apply_ask(ok)


func _validate_ask(_sender: int, p: Dictionary) -> Variant:
	var cid := str(p.get("cid", ""))
	if _build == null or not (_build.get("builds") as Dictionary).has(cid):
		return "no such build"
	match str(p.get("what", "")):
		"split":
			if line(cid, str(p.get("key", ""))).is_empty():
				return "no such line"
		"place":
			var cost := _place_cost(cid, bool(p.get("express", false)))
			if cost <= 0:
				return "nothing split to order"
			if _business and _business.has_method("can_afford") and not bool(_business.call("can_afford", cost)):
				return "not enough cash"
			# The host fixes the price it charges.
			p["cost"] = cost
		"plan", "clear":
			pass
		_:
			return "unknown ask"
	return p


func _apply_ask(p: Dictionary) -> void:
	var cid := str(p.cid)
	match str(p.what):
		"split":
			var sp: Dictionary = splits.get_or_add(cid, {})
			var parts: Array = sp.get_or_add(str(p.key), [])
			var l := line(cid, str(p.key))
			for e: Dictionary in parts.duplicate():
				if str(e.vendor) == str(p.vendor):
					parts.erase(e)
			var others := 0.0
			for e: Dictionary in parts:
				others += float(e.qty)
			var room := maxf(0.0, float(l.need) - float(l.ordered) - others)
			var q := minf(float(p.qty), room)
			if q > 0.0001:
				parts.append({"vendor": str(p.vendor), "qty": q, "used": str(p.vendor) == USED})
		"plan":
			var sp: Dictionary = splits.get_or_add(cid, {})
			var ls := _to_order(cid)
			if ls.is_empty() or _supply == null:
				return
			var o := SupplyOptimiser.run(ls, _supply.get("vendors"), _standing(), market_day(), catalog())
			for r: Dictionary in o.rows:
				var q: Dictionary = r.picks.get(str(p.plan), {})
				if not q.is_empty():
					sp[str(r.line.key)] = [{"vendor": str(q.vendor), "qty": float(r.line.qty), "used": false}]
		"clear":
			splits.erase(cid)
		"place":
			_place(cid, bool(p.get("express", false)), int(p.get("cost", 0)))
	_changed()


## The orders splits make: vendor -> {lines, total, lead, on_time}.
func _drafts(cid: String, express: bool) -> Dictionary:
	var out := {}
	for l in lines(cid):
		for e: Dictionary in (splits.get(cid, {}) as Dictionary).get(str(l.key), []):
			var q := _quote_of(cid, l, str(e.vendor))
			if q.is_empty() or float(e.qty) <= 0.0:
				continue
			var d: Dictionary = out.get_or_add(str(e.vendor), {"lines": [], "total": 0.0, "lead": 0, "on_time": 1.0,
					"name": str(q.get("name", e.vendor))})
			var unit := float(q.unit) * (OrderBook.EXPRESS_FACTOR if express else 1.0)
			(d.lines as Array).append({"key": str(l.key), "name": str(l.name), "qty": float(e.qty), "unit": unit,
					"used": bool(e.get("used", false)), "type": OrderBook.used_type(l) if bool(e.get("used", false)) else ""})
			d.total = float(d.total) + unit * float(e.qty)
			d.lead = maxi(int(d.lead), int(q.lead))
			d.on_time = minf(float(d.on_time), float(q.on_time))
	return out


func _place_cost(cid: String, express: bool) -> int:
	var t := 0.0
	for d: Dictionary in _drafts(cid, express).values():
		t += float(d.total)
	return roundi(t)


func _place(cid: String, express: bool, cost: int) -> void:
	var drafts := _drafts(cid, express)
	if drafts.is_empty():
		return
	if is_host() and _business and _business.has_method("charge") and cost > 0:
		var r: Object = _business.call("charge", cost, "parts", "Parts for %s" % _build_name(cid))
		if r and r.has_method("is_ok") and not bool(r.call("is_ok")):
			return
	var now := now_minute()
	for vendor: String in drafts:
		var d: Dictionary = drafts[vendor]
		var id := next_id
		next_id += 1
		var late := 0
		if not express:
			# Each vendor comes on time as often as its quote says; when not, a day to three late.
			var r := OrderBook.roll(id, vendor)
			if r >= roundi(float(d.on_time) * 1000.0):
				late = 1 + r % 3
		var due := now + (OrderBook.EXPRESS_MINUTES if express else int(d.lead) * 1440)
		orders.append({"id": id, "cid": cid, "vendor": vendor, "name": str(d.name), "minute": now, "due": due,
				"late": late, "express": express, "lines": d.lines, "total": roundi(float(d.total)), "arrived": false})
		if vendor != USED and _supply and _supply.has_method("set_standing"):
			_supply.call("set_standing", vendor, float(_supply.call("standing_of", vendor)) + STANDING_PER_ORDER
					+ STANDING_PER_100K * float(d.total) / 100000.0)
	splits.erase(cid)


func _build_name(cid: String) -> String:
	var b: Dictionary = (_build.get("builds") as Dictionary).get(cid, {}) if _build else {}
	return str(b.get("design_name", cid))


# --- Deliveries ----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_check_in -= delta
	if _check_in > 0.0:
		return
	_check_in = CHECK_EVERY
	if not is_host():
		return
	deliver_due()
	_send_ready()


## Brings in every order due by now (the host).
func deliver_due() -> void:
	var now := now_minute()
	var any := false
	for o: Dictionary in orders:
		if bool(o.arrived) or int(o.due) + int(o.late) * 1440 > now:
			continue
		_arrive(o)
		any = true
	if any:
		_changed()


func _arrive(o: Dictionary) -> void:
	o.arrived = true
	var cat := catalog()
	for l: Dictionary in o.lines:
		var full := line(str(o.cid), str(l.key))
		if bool(l.get("used", false)):
			# Second-hand: into the refurb works, a unit at a time; it counts once certified.
			var n := ceili(float(l.qty) - 0.001)
			if _refurb and _refurb.has_method("receive_used") and Flags.is_on(USED_FLAG):
				l["refurbing"] = n
				for i in n:
					_refurb.call("receive_used", str(l.type), OrderBook.USED_CONDITION, "parts order %d" % int(o.id))
			continue
		# Its loads go to the stores: the company's books gain them and the haulers bring them in.
		if _business and _business.has_method("add_stock") and not full.is_empty():
			var loads := OrderBook.rack_loads(full, float(l.qty), cat)
			for part: String in loads:
				_business.call("add_stock", part, int(loads[part]), "new", "parts order")
	arrived.emit(o)


## The refurb works certified a part: a second-hand line waiting on one of its kind counts it.
func _on_certified(type_id: String, _lot: Dictionary) -> void:
	if not is_host():
		return
	var base := type_id.get_slice(":", 0)
	for o: Dictionary in orders:
		if not bool(o.arrived):
			continue
		for l: Dictionary in o.lines:
			if int(l.get("refurbing", 0)) > 0 and str(l.get("type", "")).get_slice(":", 0) == base:
				l.refurbing = int(l.refurbing) - 1
				_changed()
				return


## Once a stage of the build in the berth has its parts in, they go out to the berth: the
## stores' bots take them off the racks to the yard side (the books use them).
func _send_ready() -> void:
	if _build == null:
		return
	var cid := str(_build.get("current"))
	if cid == "" or not gated(cid):
		return
	var p: Dictionary = _build.call("progress", cid)
	var stage := str(p.get("stage", ""))
	var done: Array = sent.get_or_add(cid, [])
	if stage == "" or done.has(stage) or not stage_ready(cid, stage):
		return
	done.append(stage)
	if _business and _business.has_method("get_stock") and _business.has_method("use_stock"):
		var stock: Dictionary = _business.call("get_stock")
		var cat := catalog()
		for l in lines(cid):
			if str(l.stage) != stage:
				continue
			var loads := OrderBook.rack_loads(l, float(l.need), cat)
			for part: String in loads:
				var n := mini(int(loads[part]), int(stock.get(part, 0)))
				if n > 0:
					_business.call("use_stock", part, n)
					stock[part] = int(stock.get(part, 0)) - n
	_changed()


func _on_build_changed() -> void:
	if _build == null:
		return
	var builds: Dictionary = _build.get("builds")
	for cid: String in _lines.keys():
		if not builds.has(cid):
			_lines.erase(cid)
	# A build that comes in with the gate on, nothing landed yet, waits for its parts (not the
	# sample builds: they are for trying the berth out).
	if Flags.is_on(GATE_FLAG) and is_host():
		var any := false
		for cid: String in builds:
			if tracked.has(cid) or BuildBus.is_sample(cid) or not (builds[cid].landed as Array).is_empty():
				continue
			tracked[cid] = true
			any = true
		if any:
			_changed()


func _changed() -> void:
	changed.emit()
	if _build and _build.has_method("refresh_parts"):
		# The berth's card and the bots read stage_ready: tell them.
		_build.call("refresh_parts")
	if is_host() and _net and bool(_net.call("is_online")):
		_net.call("host_emit", STATE_EVENT, save_data())


func _validate_state(_sender: int, p: Dictionary) -> Variant:
	return p


func _apply_state(p: Dictionary) -> void:
	if is_host():
		return
	load_data(p, SAVE_VERSION)


## Track build `cid` for parts (tests; a build started before the gate came on).
func track(cid: String) -> void:
	tracked[cid] = true
	_changed()


# --- Saving -------------------------------------------------------------------------------------

func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	return {"splits": splits.duplicate(true), "orders": orders.duplicate(true), "tracked": tracked.duplicate(),
			"sent": sent.duplicate(true), "next": next_id}


func load_data(data: Dictionary, _from_version: int) -> void:
	splits = (data.get("splits", {}) as Dictionary).duplicate(true)
	orders = (data.get("orders", []) as Array).duplicate(true)
	tracked = (data.get("tracked", {}) as Dictionary).duplicate()
	sent = (data.get("sent", {}) as Dictionary).duplicate(true)
	next_id = int(data.get("next", 1))
	_lines.clear()
	changed.emit()


func reset_data() -> void:
	load_data({}, SAVE_VERSION)


func get_net_snapshot() -> Dictionary:
	return save_data()


func apply_net_snapshot(data: Dictionary) -> void:
	load_data(data, SAVE_VERSION)


# --- Debug ---------------------------------------------------------------------------------------

func _debug_panel() -> Control:
	var box := VBoxContainer.new()
	for row: Array in [["Orders: order the cheapest plan for the berth's build", func() -> void:
				order_cheapest(str(_build.get("current")))],
			["Orders: express the cheapest plan", func() -> void: order_cheapest(str(_build.get("current")), true)],
			["Orders: everything due arrives now", func() -> void:
				for o: Dictionary in orders:
					o.due = mini(int(o.due), now_minute())
					o.late = 0
				deliver_due()]]:
		var b := Button.new()
		b.text = row[0]
		b.pressed.connect(row[1])
		box.add_child(b)
	return box
