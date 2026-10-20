class_name TradesBus
extends Node
## Tools module bus (Modules.bus("trades"); shown to players as Tools, its id stays "trades").
## The hands-on tools the player owns: bolting, riveting, welding, wiring, lifting and fitting.
## Other modules use this module only through this folder: signals here, and resource
## classes placed next to it. Everything else lives in internal/.
## Trades reports what was built (JointResult measurements); Quality decides if it is good.

signal tool_equipped(peer_id: int, tool_id: StringName)
signal joint_started(joint_id: StringName, trade: StringName, peer_id: int)
## 0..1, for HUDs and spectators.
signal joint_progress(joint_id: StringName, progress: float)
signal joint_completed(result: JointResult)
## The joint was taken apart for rework; any record of it is stale.
signal joint_removed(joint_id: StringName)

const WORKBENCH := "workbench"
const BENCH_SCENE := "res://modules/trades/internal/bench/workbench.tscn"
## The trades on the workbench, each behind its flag "trades.<trade>".
const TRADES: Array[String] = ["bolting", "riveting", "welding", "wiring"]
## Where the bench stands in Ship and Bay's shipyard (behind the flag "trades.shipyard").
const YARD_SPOT := "bench_preassembly"
## The yard spot is the back of the bench's tool board; the bench's own origin is this far
## in front of it (metres).
const YARD_BOARD_DEPTH := 0.59
## The group Ship and Bay knows other modules' nodes in the yard by.
const YARD_GUEST_GROUP := "yard_guest"

var _sites: Dictionary = {}
var _results: Dictionary = {}
var _modifiers: Dictionary = {}  # str(player_id) -> {effect_key: value}


func register_module() -> void:
	var order := 10
	for trade: String in TRADES:
		if not Flags.is_on("trades." + trade):
			continue
		if not Router.has_scene(WORKBENCH):
			Router.register_scene(WORKBENCH, BENCH_SCENE)
		Menu.register_entry("bench_" + trade, trade.capitalize(), WORKBENCH, order, {"trade": trade}, "Workbench")
		order += 1
		Shots.register(trade + "_bench", WORKBENCH,
				func(scene: Node) -> void: scene.call("stage_for_screenshot", StringName(trade), false), 40)
		Shots.register(trade + "_bench_third_person", WORKBENCH,
				func(scene: Node) -> void: scene.call("stage_for_screenshot", StringName(trade), true), 40)
	if Flags.is_on("trades.shipyard"):
		var yard_bus := Modules.bus("ship_bay") as ShipBayBus
		if yard_bus and not yard_bus.shipyard_ready.is_connected(_on_shipyard_ready):
			yard_bus.shipyard_ready.connect(_on_shipyard_ready)
		if Router.has_scene(ShipBayBus.SHIPYARD_SCENE):
			Shots.register("tools_bench_in_shipyard", ShipBayBus.SHIPYARD_SCENE,
					func(scene: Node) -> void: scene.get_node("ToolsBench").call("stage_for_screenshot", &"welding", true), 40)


## Ship and Bay built its shipyard: stand the bench at our spot in Pre-assembly.
func _on_shipyard_ready(yard: Node3D) -> void:
	var yard_bus := Modules.bus("ship_bay") as ShipBayBus
	var bench: Node3D = load(BENCH_SCENE).instantiate()
	bench.set("in_yard", true)
	bench.name = "ToolsBench"
	# Ship and Bay's clear-spot checks leave out what other modules put there.
	bench.add_to_group(YARD_GUEST_GROUP)
	bench.transform = yard_bus.shipyard_spot(YARD_SPOT) * Transform3D(Basis(), Vector3(0, 0, YARD_BOARD_DEPTH))
	yard.add_child(bench)


func register_site(site: JointSite) -> void:
	_sites[site.joint_id] = site


func unregister_site(site: JointSite) -> void:
	if _sites.get(site.joint_id) == site:
		_sites.erase(site.joint_id)


func site(joint_id: StringName) -> JointSite:
	return _sites.get(joint_id)


## Last result for a joint, or null if it is not finished (or was taken apart).
func get_result(joint_id: StringName) -> JointResult:
	return _results.get(joint_id)


func is_tool_enabled(tool_id: StringName) -> bool:
	match tool_id:
		&"hands":
			return TRADES.any(func(t: String) -> bool: return Flags.is_on("trades." + t))
		&"torque_wrench":
			return Flags.is_on("trades.bolting")
		&"drill", &"rivet_squeezer":
			return Flags.is_on("trades.riveting")
		&"welder":
			return Flags.is_on("trades.welding")
		&"wire_tool":
			return Flags.is_on("trades.wiring")
	return false


## Progression pushes each player's skill effects down here, since Trades can't call up.
## Trades reads "bolt_speed" and "rivet_speed" (share faster turning and drilling). Unknown keys are kept and ignored.
func set_player_modifiers(player_id: Variant, effects: Dictionary) -> void:
	_modifiers[str(player_id)] = effects.duplicate()


func modifier(player_id: Variant, effect_key: StringName, default: float = 0.0) -> float:
	return float(_modifiers.get(str(player_id), {}).get(effect_key, default))


## Called by the module's own tools when a joint is finished.
func complete_joint(joint_site: JointSite, measurements: Dictionary, peer_id: int = 1) -> JointResult:
	var r := JointResult.new()
	r.joint_id = joint_site.joint_id
	r.trade = joint_site.spec.trade
	r.component_id = joint_site.component_id
	r.mount_id = joint_site.mount_id
	r.measurements = measurements
	r.peer_id = peer_id
	r.time = int(Time.get_unix_time_from_system())
	_results[r.joint_id] = r
	joint_completed.emit(r)
	return r


## Called by the module's own tools when a finished joint is taken apart.
func remove_joint(joint_id: StringName) -> void:
	if _results.erase(joint_id):
		joint_removed.emit(joint_id)
