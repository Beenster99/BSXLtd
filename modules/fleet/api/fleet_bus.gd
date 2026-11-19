class_name FleetBus
extends Node
## TartanCo fleet module bus (Modules.bus("fleet")): the screen that watches TartanCo's worker
## bots in the yard (beenster, 19 Nov: "a detailed screen for us to monitor the fleet of
## tartanco bots"), on the design room's walls and the F1 wrist screen, and the orders players
## give the fleet: groups of bots, each with a priority and a task list from the build plan
## (FleetOrders). The orders are groundwork for auto-building (master plan Wave 6): the crew
## does not follow them yet.
##
##   var fleet := Modules.bus("fleet") as FleetBus
##   fleet.rows()                         # one Dictionary per bot (see rows())
##   fleet.orders                         # FleetOrders (groups and their tasks)
##   fleet.command({op = "group_add", name = "Hull crew"})   # shared with the crew, saved
##   fleet.plan_tasks()                   # the open design's build plan as tasks
##   fleet.orders_changed.connect(...)
##
## Features (Flags): "fleet" (the module), "fleet.screen" (the wall panel and wrist channel).

signal orders_changed

const SCREEN_FLAG := "fleet.screen"
const WALL_VIEW := "fleet"
const WALL_TITLE := "TARTANCO FLEET"
## The wrist screen's channel (HudSlots), after the parts market, contract fit and accounts.
const HOLO_CHANNEL := "fleet.bots"
const HOLO_ORDER := 45
const SAVE_SECTION := "fleet"
const SAVE_VERSION := 1
const NET_EVENT := "fleet.order"
const NET_SECTION := "fleet"
const Screen := preload("res://modules/fleet/internal/fleet_screen.gd")

## Condition bands (condition = 1 - wear). The crew slows past 40% wear and TartanCo is called
## at 75% (YardWorkers.slow_from, call_at).
const GOOD_FROM := 0.6
const POOR_BELOW := 0.25

var orders := FleetOrders.new()
## Stands in for the yard's bots in tests and captures: Callable() -> Array[Dictionary] of rows.
var source := Callable()
var _yard: YardBus
var _design: DesignBus
var _net: Object


func register_module() -> void:
	Saves.register_section(SAVE_SECTION, self)
	if Modules.ready_done:
		_hook_up()
	else:
		Modules.modules_ready.connect(_hook_up, CONNECT_ONE_SHOT)


func _hook_up() -> void:
	_yard = Modules.bus("yard") as YardBus
	_design = Modules.bus("design") as DesignBus
	hook_net(Modules.bus("multiplayer"))
	# A new game starts with no orders.
	Saves.game_started.connect(func(_slot: String, is_new: bool) -> void:
		if is_new:
			orders.from_dict({})
			orders_changed.emit())
	if not Flags.is_on(SCREEN_FLAG):
		return
	# The wall panel arrives with the design room's offered views (DesignBus.register_wall_view);
	# reached by name so the module runs on a design module without them.
	if _design and _design.has_method("register_wall_view"):
		_design.call("register_wall_view", WALL_VIEW, WALL_TITLE, make_screen)
	HudSlots.register_holo_channel(HOLO_CHANNEL, "TartanCo fleet",
			func(glass: bool) -> Control: return make_screen(150.0, glass), HOLO_ORDER)


func unregister_module() -> void:
	Saves.unregister_section(SAVE_SECTION)
	HudSlots.unregister_holo_channel(HOLO_CHANNEL)
	if _design and _design.has_method("unregister_wall_view"):
		_design.call("unregister_wall_view", WALL_VIEW)
	if _net:
		_net.call("unregister_event", NET_EVENT)
		_net.call("unregister_snapshot_provider", NET_SECTION)
		_net = null


## The fleet screen, its text sized for a wall drawn at px_per_m.
func make_screen(px_per_m: float, glass := false) -> Control:
	var s := Screen.new()
	s.setup(self, px_per_m, glass)
	return s


# --- The fleet ------------------------------------------------------------------------------

## One row per TartanCo bot in the yard ([] while no station is open):
## {serial, model, role, trade, state, state_name, job, condition (0..1), band ("good", "fair",
## "poor"), wear, charge (0..1), charging, productivity, errors, upgrades: [{id, name}],
## location, where (station-space Vector3), group (id or "")}.
func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if source.is_valid():
		out.assign(source.call())
	elif _yard:
		var st := _yard.station()
		for bot in _yard.worker_bots():
			out.append(row_for(bot.name, _yard.worker_condition(bot), _station_point(st, bot), {
					"role": str(bot.get_meta("role", "")), "model": str(bot.get_meta("tartanco_model", "")),
					"serial": str(bot.get_meta("serial", bot.name))}))
	for r in out:
		r.group = str(orders.group_of(str(r.serial)).get("id", ""))
	return out


func _station_point(st: Node3D, bot: Node3D) -> Vector3:
	if st and bot.is_inside_tree() and st.is_inside_tree():
		return st.to_local(bot.global_position)
	return bot.position


## A bot's row from YardBus.worker_condition (keys it lacks fall back) and its place.
static func row_for(node_name: String, c: Dictionary, where: Vector3, meta: Dictionary) -> Dictionary:
	var wear := float(c.get("wear", 0.0))
	var errors: Array = c.get("errors", [])
	var charging := bool(c.get("charging", false))
	var role := str(c.get("role", meta.get("role", "")))
	var state := str(c.get("state", ""))
	if state == "":
		state = "faulted" if not errors.is_empty() else ("charging" if charging else "active")
	var cond := clampf(1.0 - wear, 0.0, 1.0)
	return {"serial": str(c.get("serial", meta.get("serial", node_name))),
			"model": str(c.get("model", meta.get("model", ""))), "role": role,
			"trade": str(FleetOrders.TRADES.get(role, "Worker")),
			"state": state, "state_name": state_name(state), "job": str(c.get("job", "")),
			"condition": cond, "band": band(cond), "wear": wear,
			"charge": clampf(float(c.get("charge", 1.0)), 0.0, 1.0), "charging": charging,
			"productivity": float(c.get("productivity", 1.0)), "errors": errors.duplicate(),
			"upgrades": (c.get("upgrades", []) as Array).duplicate(true), "speed": float(c.get("speed", 1.0)),
			"location": location(where, state, node_name), "where": where}


static func band(cond: float) -> String:
	if cond >= GOOD_FROM:
		return "good"
	return "poor" if cond < POOR_BELOW else "fair"


static func state_name(state: String) -> String:
	return {"working": "WORKING", "idle": "STANDING BY", "to_dock": "TO CHARGE DOCK", "charging": "CHARGING",
			"faulted": "FAULT", "servicing": "WITH TARTANCO", "active": "ON SHIFT"}.get(state, state.to_upper())


## Where a bot is, in words: its charge dock, a berth, a station room or the open dock.
static func location(where: Vector3, state: String, node_name: String) -> String:
	if state == "charging" and node_name.begins_with("Worker"):
		return "Charge dock C%s, berth B1" % node_name.trim_prefix("Worker")
	for b: Dictionary in YardBus.berths():
		if (b.box as AABB).has_point(where):
			return "%s berth %s" % ["Build" if b.kind == "build" else "Holding", b.name]
	var room := YardBus.room_at(where)
	if room != "":
		return str(YardBus.rooms()[room].name)
	return "Open dock"


## Counts for the screen's header: bots, working, charging, faulted, poor, mean condition/charge.
func summary(list: Array[Dictionary]) -> Dictionary:
	var s := {"bots": list.size(), "working": 0, "charging": 0, "faulted": 0, "poor": 0, "condition": 0.0, "charge": 0.0}
	for r in list:
		match str(r.state):
			"working", "active":
				s.working += 1
			"charging", "to_dock":
				s.charging += 1
			"faulted":
				s.faulted += 1
		if r.band == "poor":
			s.poor += 1
		s.condition += float(r.condition)
		s.charge += float(r.charge)
	if not list.is_empty():
		s.condition /= list.size()
		s.charge /= list.size()
	return s


## The open design's build plan as work tasks ([] with no design open).
func plan_tasks() -> Array[Dictionary]:
	var t: DesignTotals = _design.totals() if _design else null
	return FleetOrders.plan_tasks(t.lines) if t else ([] as Array[Dictionary])


## The open design's name, or "".
func plan_name() -> String:
	var rec: DesignRecord = _design.library.current if _design else null
	return rec.name if rec else ""


# --- Orders, shared with the crew -------------------------------------------------------------

## Gives the fleet an order (FleetOrders.OPS): every player applies it in the same order.
func command(cmd: Dictionary) -> void:
	if _net and bool(_net.call("is_online")):
		_net.call("request", NET_EVENT, cmd)
		return
	var ok: Variant = _validate(1, cmd)
	if ok is Dictionary:
		_apply(ok)


## Plays through this Multiplayer bus (tests use a stand-in with the same calls).
func hook_net(net: Object) -> void:
	if net == null or not net.has_method("register_event"):
		return
	_net = net
	_net.call("register_event", NET_EVENT, _apply, _validate)
	_net.call("register_snapshot_provider", NET_SECTION, self)


func _validate(_sender: int, cmd: Dictionary) -> Variant:
	if not FleetOrders.OPS.has(str(cmd.get("op", ""))):
		return "not a fleet order"
	return cmd.duplicate(true)


func _apply(cmd: Dictionary) -> void:
	if orders.apply(cmd):
		orders_changed.emit()


func get_net_snapshot() -> Dictionary:
	return orders.to_dict()


func apply_net_snapshot(data: Dictionary) -> void:
	orders.from_dict(data)
	orders_changed.emit()


func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	return orders.to_dict()


func load_data(data: Dictionary, _from_version: int) -> void:
	orders.from_dict(data)
	orders_changed.emit()
