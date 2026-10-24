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
## A player's tractor beam moved a loose part (yard space is the world here), or let go of it
## (holding false). Multiplayer can mirror the part from this.
signal part_beamed(peer_id: int, slot_id: String, xform: Transform3D, holding: bool)
## Component Upgrades (trades.unit_mounts): a joint inside a unit on an upgrade rig was made
## or taken out ("unit_<rig>_<mount>/<b1|w1|c1...>"; quality 0..1 as for ship joints).
signal unit_joint_changed(rig_id: String, joint_id: String, made: bool, quality: float)
## The unit on a rig changed: its state as unit_state() gives it ({} once it's off the rig).
signal unit_changed(rig_id: String, state: Dictionary)

const WORKBENCH := "workbench"
const BENCH_SCENE := "res://modules/trades/internal/bench/workbench.tscn"
## The trades, each behind its flag "trades.<trade>". Their practice bench is no longer on
## the menu: the work happens on the ship in the yard.
const TRADES: Array[String] = ["bolting", "riveting", "welding", "wiring"]
## What we add to Ship and Bay's shipyard (behind the flag "trades.shipyard"): you, the
## worker with the tools.
const YARD_RIG := "ToolsRig"
## The group Ship and Bay knows other modules' nodes in the yard by.
const YARD_GUEST_GROUP := "yard_guest"
## The Tools keys, input actions in Settings > Key binds ("Tools"); walking, F and Esc are
## Core's (Keys.FORWARD..., Keys.INTERACT, Keys.CANCEL).
const KEY_TOOL := "trades.tool_"         # + 1..9: pick a tool off the hotbar
const KEY_VIEW := "trades.view"
const KEY_TURN_LEFT := "trades.turn_left"
const KEY_TURN_RIGHT := "trades.turn_right"
## Held: the mouse turns the part in the tractor beam instead of the view.
const KEY_ROTATE := "trades.rotate"
## Held: the key data of the part or joint you are looking at.
const KEY_INSPECT := "trades.inspect"
## The practice bench's: start the job again, the next part in the tray.
const KEY_RESET := "trades.reset"
const KEY_NEXT := "trades.next"
const KEY_MODE := "trades.mode"           # the powered tools' mode: fasten / undo
const KEY_HELMET := "trades.helmet"       # the welding shield up / down
const KEY_GROUP := "Tools"
## The wrist screen's Specs channel: torque windows and rivet heights (its flag too).
const SPECS_CHANNEL := "trades.specs"
const HOTBAR_KEYS := 9

var _sites: Dictionary = {}
var _results: Dictionary = {}
var _modifiers: Dictionary = {}  # str(player_id) -> {effect_key: value}
var _units: Dictionary = {}  # rig_id -> unit_state()


func register_module() -> void:
	for i in HOTBAR_KEYS:
		Keys.register(KEY_TOOL + str(i + 1), "Tool %d" % (i + 1), (KEY_1 + i) as Key, KEY_GROUP)
	Keys.register(KEY_VIEW, "First / third person", KEY_V, KEY_GROUP)
	Keys.register(KEY_TURN_LEFT, "Turn left / amps down", KEY_Q, KEY_GROUP)
	Keys.register(KEY_TURN_RIGHT, "Turn right / amps up", KEY_E, KEY_GROUP)
	Keys.register(KEY_ROTATE, "Rotate the part in the beam (hold)", KEY_R, KEY_GROUP)
	Keys.register(KEY_INSPECT, "Show part details (hold)", KEY_TAB, KEY_GROUP)
	Keys.register(KEY_RESET, "Start the bench job again", KEY_BACKSPACE, KEY_GROUP)
	Keys.register(KEY_NEXT, "Next part in the tray", KEY_G, KEY_GROUP)
	Keys.register(KEY_MODE, "Tool mode: fasten / undo", KEY_X, KEY_GROUP)
	Keys.register(KEY_HELMET, "Welding shield up / down", KEY_H, KEY_GROUP)
	if Flags.is_on(SPECS_CHANNEL):
		HudSlots.register_holo_channel(SPECS_CHANNEL, "Specs",
				func(glass: bool) -> Control: return TradesSpecsScreen.new(glass), 55)
	if TRADES.any(func(t: String) -> bool: return Flags.is_on("trades." + t)):
		Router.register_scene(WORKBENCH, BENCH_SCENE)
	if Flags.is_on("trades.shipyard"):
		var yard_bus := Modules.bus("ship_bay") as ShipBayBus
		if yard_bus and not yard_bus.shipyard_ready.is_connected(_on_shipyard_ready):
			yard_bus.shipyard_ready.connect(_on_shipyard_ready)
		if Router.has_scene(ShipBayBus.SHIPYARD_SCENE):
			for shot: Array in [["bolt", false], ["bolt", true], ["connector", false]]:
				Shots.register("tools_%s_on_kestrel%s" % [shot[0], "_third_person" if shot[1] else ""], ShipBayBus.SHIPYARD_SCENE,
						func(scene: Node) -> void: await scene.get_node(YARD_RIG).call("stage_on_ship", shot[0], shot[1]), 40)
			if Flags.is_on("trades.inspect"):
				Shots.register("tools_inspect_part", ShipBayBus.SHIPYARD_SCENE,
						func(scene: Node) -> void: await scene.get_node(YARD_RIG).call("stage_inspect"), 40)
			if Flags.is_on("trades.test_stand"):
				for third: bool in [false, true]:
					Shots.register("tools_test_stand%s" % ("_third_person" if third else ""), ShipBayBus.SHIPYARD_SCENE,
							func(scene: Node) -> void: await scene.get_node(YARD_RIG).call("stage_test_stand", third), 40)
			if Flags.is_on("trades.tractor"):
				Shots.register("tools_tractor_lifting_engine", ShipBayBus.SHIPYARD_SCENE,
						func(scene: Node) -> void: await scene.get_node(YARD_RIG).call("stage_tractor", true), 40)


## Ship and Bay built its shipyard: put you in it, the worker with every tool to hand.
func _on_shipyard_ready(yard: Node3D) -> void:
	var rig: Node3D = load(BENCH_SCENE).instantiate()
	rig.set("in_yard", true)
	rig.name = YARD_RIG
	rig.add_to_group(YARD_GUEST_GROUP)
	yard.add_child(rig)


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
		&"tractor":
			return Flags.is_on("trades.tractor")
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


## The unit on an upgrade rig as Tools has it: {unit (id), tier, open (cover off), seats (the
## add-on seats it has: "core", "emitter", "board"), fitted (seat -> the add-on part in it,
## Shared Components' id: "quantum_core_3", "field_emitter_3", "control_board"),
## joints (joint_id -> quality 0..1, or -1.0 while not made)}; {} with no unit on the rig.
func unit_state(rig_id: String) -> Dictionary:
	return (_units.get(rig_id, {}) as Dictionary).duplicate(true)


## Called by the module's own station when a unit's joints or add-ons change.
func note_unit(rig_id: String, state: Dictionary) -> void:
	if state.is_empty():
		_units.erase(rig_id)
	else:
		_units[rig_id] = state.duplicate(true)
	unit_changed.emit(rig_id, state)


## Called by the module's own tools when a finished joint is taken apart.
func remove_joint(joint_id: StringName) -> void:
	if _results.erase(joint_id):
		joint_removed.emit(joint_id)
