class_name TradesBay
extends Node3D
## The tools bay: one long bench in a BSX fitting bay with a station for each kind of job
## (bolting, riveting, welding, wiring). You walk along it as the BSX worker (first or
## third person, V) with your own stretchy hands. You own every tool: the mouse wheel (or
## 1-6) picks one, and you work at whichever station you are looking at. Hold left click
## with your hands on a part to carry it; the wheel then turns it instead, freely or in
## quarter turns (middle click swaps). The bay owns the worker, the tools, the HUD and the
## input; each station (TradesStation) owns its parts, its joint rules and what the tools
## do there.
##
##   WASD walk, mouse look, V first/third person, wheel or 1-6 tools, R resets the
##   station, left click use (hold to carry), wheel while carrying turns it, middle click
##   free or 90 degree turning, right click take off, Q/E set the machine, Esc leaves.
##
## In Ship and Bay's shipyard (in_yard, added by TradesBus) there is no bench: this is you,
## the BSX worker, walking the yard (Shift runs) with every tool to hand, and the one
## station is the ship itself (TradesShipJoints): the tools work on its real joints. The
## yard's own walker stands down for good.

const BENCH_TOP := 0.9
## The bench runs along X from -BENCH_HALF to BENCH_HALF, its front edge at z = BENCH_FRONT.
const BENCH_HALF := 2.3
const BENCH_FRONT := 0.27
## The hotbar, in order (keys 1..6).
const TOOLS: Array[StringName] = [&"hands", &"torque_wrench", &"drill", &"rivet_squeezer", &"welder", &"wire_tool"]
const TOOL_LABELS := {
	&"hands": "Hands", &"torque_wrench": "Torque wrench", &"drill": "Drill",
	&"rivet_squeezer": "Squeezer", &"welder": "Welder", &"wire_tool": "Crimper", &"tractor": "Tractor",
	&"cutter": "Cutter",
}
## The tools trades.slim_hotbar leaves off the yard's hotbar.
const SLIM_DROPS: Array[StringName] = [&"drill", &"wire_tool", &"cutter"]
## A tool's name on the hotbar and its display: the wrench is the powered one with
## trades.power_wrench, the squeezer the rivet gun in the yard with trades.power_riveter
## (the bench's riveting lesson keeps the hand squeezer).
static func label_of(id: StringName, yard := true) -> String:
	if id == &"torque_wrench" and TradesShipJoints.powered():
		return "Power wrench"
	if id == &"rivet_squeezer" and yard and Flags.is_on("trades.power_riveter"):
		return "Rivet gun"
	return String(TOOL_LABELS.get(id, id))


## The stations, left to right: id, script, where along the bench, and the flag that ships it.
const STATIONS := [
	[&"bolting", preload("res://modules/trades/internal/bolting/bolting_station.gd"), -1.7, "trades.bolting"],
	[&"riveting", preload("res://modules/trades/internal/riveting/riveting_station.gd"), -0.57, "trades.riveting"],
	[&"welding", preload("res://modules/trades/internal/welding/welding_station.gd"), 0.57, "trades.welding"],
	[&"wiring", preload("res://modules/trades/internal/wiring/wiring_station.gd"), 1.7, "trades.wiring"],
]
const HAND_REACH_M := 0.9
const HAND_STRETCH_M := 0.9
## In the yard the arms stretch further, up to the joints on a ship's roof from the floor (metres).
const YARD_STRETCH_M := 3.4
## Bolts on the ship (Ship and Bay's FastenerPoints) are in ship space; without the yard
## telling us where the ship is, it sits this far over the yard's origin (the bay's cradles).
const YARD_SHIP_AT := Vector3(0, 1.6, 0)
## The upgrade rig (Component Upgrades U1): Ship and Bay's spot, origin on its deck.
const RIG_SPOT := "rig_emitter"
## How high the inside of Ship and Bay's stand-in housing is clear from (m).
const BARE_FLOOR_M := 0.09
## Where the tool test stand goes (Ship and Bay's shipyard_spot: the Pre-assembly wing).
const TEST_STAND_SPOT := "bench_preassembly"

## Set before adding to the tree: you are in the shipyard working on the ship, not at a bench.
var in_yard := false
## The trolleys' screen was up last frame (see _keep_the_yard).
var _screen_was_up := false
var worker: BenchWorker
var tool: StringName = &"hands"
## The tools on your hotbar (keys 1..n): TOOLS, and in the yard the tractor beam
## (flag "trades.tractor").
var hotbar: Array[StringName] = []
## Sparks off the tools, and rivets popping out (presentation only).
var sparks: TradesSparks
## The wheel turns a held part in quarter turns (true) or a few degrees a notch.
var turn_snap := false
var stations: Array[TradesStation] = []
## The tool meshes by id (no entry for hands).
var tool_nodes: Dictionary = {}

var _focus: TradesStation
var _pressed: TradesStation
var _placed: Dictionary = {}
var _players: Dictionary = {}
var _loops: Dictionary = {}

var _tool_label: Label
var _status_label: Label
var _hint_label: Label
var _slots: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _result_panel: PanelContainer
var _result_label: Label
var _hud: CanvasLayer
## Looking through the welding shield in first person, and how far down it is (0..1).
var _weld_view: TradesWeldingView
var _helmet := 0.0
## The shield's toggle (trades.helmet_toggle): down until you lift it.
var helmet_lowered := false
## Seconds since the arc went out (the shield stays down a moment).
var _arc_off_s := 10.0
## Other players' arcs, by peer: {at, cutting, light, glow, helmet}.
var remote_torches := {}
## The crew seeing and hearing each other's tools (trades.crew_tools), in the yard.
var crew: TradesCrew
## The yard's real fire extinguishers (trades.extinguishers).
var extinguishers: TradesExtinguishers
## The tool loop sounding now ("" for none), whether or not it can be heard here.
var _looping := &""
## What we last told the others about our arc, and when.
var _torch_sent := {}
var _torch_sent_s := 0.0
## The tool panel (the tool in hand's readings, bottom right) and the inspect panel (hold
## Tab: key data of what you're looking at).
var _tool_panel: PanelContainer
var _tool_title: Label
var _tool_text: Label
var _tool_state: Label
var _tool_bar: ColorRect
var _tool_light: ColorRect
var _inspect_panel: PanelContainer
var _inspect_label: Label


## Its look hint provider's id (HudSlots.register_look_hint).
const LOOK_HINT_ID := "trades.tool"


func _ready() -> void:
	HudSlots.register_look_hint(LOOK_HINT_ID, func(hit: Dictionary) -> Dictionary: return look_hint(hit), 10)
	if not in_yard:
		_build_room()
		_build_bench()
	hotbar.assign(TOOLS)
	if in_yard and Flags.is_on("trades.slim_hotbar"):
		# beenster, 22 Oct: welds come out with the welder's unweld, rivets by heating them
		# with the welder, and plugs are wired by hand; so no drill, crimper or cutter.
		hotbar.assign(hotbar.filter(func(t: StringName) -> bool: return not t in SLIM_DROPS))
	if in_yard and Flags.is_on("trades.tractor"):
		hotbar.append(&"tractor")
	# trades.vs_tools brings the cutter back for rivets (beenster, 0.3.18).
	if in_yard and Flags.is_on("trades.cutter") and (not Flags.is_on("trades.slim_hotbar") or TradesShipJoints.vs_tools()):
		hotbar.append(&"cutter")
	_build_worker()
	sparks = TradesSparks.new()
	sparks.name = "Sparks"
	sparks.exclude.append(worker.get_rid())
	add_child(sparks)
	_build_tools()
	_build_audio()
	_build_hud()
	if in_yard:
		_enter_yard()
		return
	for row: Array in STATIONS:
		if not Flags.is_on(row[3]):
			continue
		var s: TradesStation = (row[1] as GDScript).new()
		s.id = row[0]
		s.bay = self
		s.position = Vector3(row[2], 0.0, 0.0)
		s.name = String(row[0]).capitalize().replace(" ", "") + "Station"
		add_child(s)
		s.build()
		_build_station_dressing(s)
		stations.append(s)
	set_tool(&"hands")
	# The menu opens the bay at one trade's station (Router.args {"trade": "welding"}).
	var start := station(StringName(Router.args.get("trade", "")))
	if start == null and not stations.is_empty():
		start = stations[0]
	if start:
		_walk_to(start)
		_focus = start
		hint(_focus.start_hint())
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## In the yard: the ship is the station, the worker stands where the yard's walker stood and
## takes the view and the controls for good.
func _enter_yard() -> void:
	var yard := get_parent() as Node3D
	var yard_bus := Modules.bus("ship_bay") as ShipBayBus
	var walker := yard.get("walker") as PhysicsBody3D if yard else null
	if walker:
		worker.add_collision_exception_with(walker)
	var s := TradesShipJoints.new()
	s.id = &"ship"
	s.bay = self
	s.name = "ShipJoints"
	add_child(s)
	s.ship_xform = ship_transform()
	s.build()
	stations.append(s)
	if Flags.is_on("trades.test_stand") and yard and yard_bus:
		s.add_test_stand(yard.global_transform * yard_bus.shipyard_spot(TEST_STAND_SPOT))
	if Flags.is_on("trades.unit_mounts") and yard and yard_bus and yard_bus.has_signal("rig_changed"):
		# Ship and Bay's upgrade rig: its hold-down bolts are worked like the ship's, and a
		# unit put on it opens up for its add-ons here (TradesUnitWork).
		s.rigs[RIG_SPOT] = yard.global_transform * yard_bus.shipyard_spot(RIG_SPOT)
		yard_bus.connect("rig_changed", _on_rig_changed)
		s.refresh_points()
	_focus = s
	if yard_bus:
		yard_bus.set_walker_active(yard, false)
		var feet := yard.global_transform * yard_bus.walker_position(yard) if yard else Vector3.ZERO
		worker.global_position = feet
	worker.face(ship_transform().origin + Vector3(0, -0.4, 0))
	worker.camera.current = true
	set_tool(&"hands")
	var net := _net()
	if TradesExtinguishers.enabled() and yard and yard_bus and yard_bus.has_method("fire_points"):
		extinguishers = TradesExtinguishers.new()
		extinguishers.name = "Extinguishers"
		extinguishers.bay = self
		for t: Transform3D in TradesExtinguishers.fire_points():
			extinguishers.spots.append(yard.global_transform * t)
		add_child(extinguishers)
		extinguishers.build(net)
	if net:
		net.call("register_event", TORCH_EVENT, _apply_torch, _validate_torch)
		if TradesCrew.enabled():
			crew = TradesCrew.new()
			crew.name = "Crew"
			crew.bay = self
			add_child(crew)
			crew.start(net)
	hint(s.start_hint())
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## A unit went on or came off an upgrade rig (Ship and Bay's rig_changed).
func _on_rig_changed(rig_id: String, state: Dictionary) -> void:
	var s := ship_station()
	if s == null or not s.rigs.has(rig_id):
		return
	var unit_id := str(state.get("unit", ""))
	if unit_id == "":
		if s.unit and s.unit.rig_id == rig_id:
			s.remove_unit()
	elif s.unit == null or s.unit.rig_id != rig_id or s.unit.unit_id != unit_id:
		# The rig builds the unit when it hears the same signal: look once it has.
		_place_unit.call_deferred(rig_id, unit_id, int(state.get("tier", 3)))
	s.refresh_points()


## Puts the unit on the rig to work: on Shared Components' coil as the rig built it
## (rig_unit), else on our own, set in the rig's housing stand-in (clear from 0.12 m up).
func _place_unit(rig_id: String, unit_id: String, tier: int) -> void:
	var s := ship_station()
	var yard_bus := Modules.bus("ship_bay") as ShipBayBus
	if s == null or yard_bus == null or str(yard_bus.rig_state(rig_id).get("unit", "")) != unit_id:
		return
	var rec := yard_bus.rig_unit(rig_id)
	var kit := rec.get("kit") as ShipKit
	if kit and kit.model and is_instance_valid(kit.model.body):
		s.add_unit(rig_id, unit_id, tier, kit.model.body.global_transform, true, rec)
	else:
		var at: Transform3D = s.rigs[rig_id]
		s.add_unit(rig_id, unit_id, tier, at.translated_local(Vector3(0, BARE_FLOOR_M, 0)), true)


## True while you drive a hover trolley on remote (Ship and Bay): W A S D and the mouse are
## the trolley's, so the worker stands still.
func _remote_driving() -> bool:
	var yard_bus := Modules.bus("ship_bay")
	return in_yard and yard_bus != null and bool(yard_bus.get("remote_driving"))


## You are the worker in the yard for good. The trolleys' screen hands the yard's own walker
## back when it closes, which used to leave you as that walker at the yard's start point with
## the worker's hands floating where you stood (0.3.6): when the walker comes back as that
## screen closes, stand it down again and take the view and the mouse back. Anyone else
## handing the walker back on purpose (Ship and Bay's own tests) keeps it.
func _keep_the_yard() -> void:
	var yard := get_parent() as Node3D
	var yard_bus := Modules.bus("ship_bay") as ShipBayBus
	var fleet: Object = yard_bus.get("fleet") if yard_bus else null
	var screen_up := is_instance_valid(fleet) and fleet.get("panel") != null
	var closed := _screen_was_up and not screen_up
	_screen_was_up = screen_up
	if yard == null or not closed or not bool(yard.get("walker_active")):
		return
	if yard_bus:
		yard_bus.set_walker_active(yard, false)
	worker.camera.current = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Where the ship in the yard is (ship space to world): from Ship and Bay once it says, else
## over the yard's origin at the cradles' height.
func ship_transform() -> Transform3D:
	var yard := get_parent() as Node3D
	var yard_bus := Modules.bus("ship_bay")
	var base := yard.global_transform if yard else Transform3D.IDENTITY
	if yard and yard_bus and yard_bus.has_method("ship_transform"):
		# Ship space to yard space.
		return base * (yard_bus.call("ship_transform", yard) as Transform3D)
	return base * Transform3D(Basis(), YARD_SHIP_AT)


## The ship's station (in the yard), or null.
func ship_station() -> TradesShipJoints:
	return station(&"ship") as TradesShipJoints


func _exit_tree() -> void:
	var net := _net()
	if net and in_yard:
		net.call("unregister_event", TORCH_EVENT)
	if crew:
		crew.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	HudSlots.unregister_look_hint(LOOK_HINT_ID)
	_clear_info()
	# A screenshot may have left Tab held down.
	if InputMap.has_action(TradesBus.KEY_INSPECT):
		Input.action_release(TradesBus.KEY_INSPECT)


func station(station_id: StringName) -> TradesStation:
	for s in stations:
		if s.id == station_id:
			return s
	return null


## The station you are working at (mid-action, or the one you are looking at).
func focus() -> TradesStation:
	return _focus


func set_tool(id: StringName) -> void:
	if _pressed:
		_pressed.release()
		_pressed = null
	tool = id
	var bus := bus()
	if bus:
		bus.tool_equipped.emit(1, id)
	_refresh_hud()


## The next tool along the hotbar (+1) or the one before (-1), wrapping round. Not while a
## hand or tool is busy on the work.
func cycle_tool(step: int) -> void:
	if _focus and _focus.is_busy():
		return
	var i := hotbar.find(tool)
	set_tool(hotbar[posmod(i + step, hotbar.size())])


## One wheel notch: turns the part your hands hold while left click is down, otherwise
## moves along the hotbar.
func wheel(step: int) -> void:
	if _pressed and _pressed.turn_held(step, turn_snap):
		return
	# The beam keeps hold after you let go of the button (beenster, 0.3.14): the wheel still
	# pulls the part in or pushes it out rather than changing tools.
	if _pressed == null and tool == &"tractor" and _focus and _focus.turn_held(step, turn_snap):
		return
	if _pressed == null and _focus and _focus.wheel_setting(tool, step):
		_refresh_hud()
		return
	cycle_tool(step)


## The powered tool in hand between its modes (the wrench: fasten / undo).
func toggle_mode() -> void:
	var t := tool_node(tool)
	if in_yard and TradesShipJoints.vs_tools() and (t is TradesPowerWrench or t is TradesWeldTorch):
		# trades.vs_tools: the tool picks by itself from what it's aimed at.
		hint("No mode to switch: on a tight bolt the wrench takes it out, on a loose one it runs it in." if t is TradesPowerWrench
				else "No mode to switch: hold on an open seam to weld it, on a weld to cut it out.")
	elif t is TradesPowerWrench:
		var w := t as TradesPowerWrench
		w.undo = not w.undo
		play(&"tick")
		hint("Wrench in undo: it takes bolts out." if w.undo else "Wrench in fasten: it runs bolts in.")
		_refresh_hud()


	elif t is TradesWeldTorch and in_yard:
		var torch := t as TradesWeldTorch
		torch.unweld = not torch.unweld
		play(&"tick")
		hint("Welder on unweld: left click cuts welds out." if torch.unweld else "Welder on weld: left click lays a bead.")
		_refresh_hud()


## Middle click: turning held parts freely or in quarter turns.
func toggle_turn_snap() -> void:
	turn_snap = not turn_snap
	hint("Turning in 90 degree steps." if turn_snap else "Turning freely.")
	_refresh_hud()


## Every station back to its start.
func reset_all() -> void:
	for s in stations:
		s.reset()
	hide_result()


# --- Input ------------------------------------------------------------------------------

## The keys strip on the HUD, from where the keys are bound now.
func _keys_line() -> String:
	var k := func(action: String) -> String: return Keys.key_name(action)
	var walk: String = "".join([k.call(Keys.FORWARD), k.call(Keys.LEFT), k.call(Keys.BACK), k.call(Keys.RIGHT)])
	var tools := "%s-%s" % [k.call(TradesBus.KEY_TOOL + "1"), k.call(TradesBus.KEY_TOOL + str(hotbar.size()))]
	var turn := "%s/%s" % [k.call(TradesBus.KEY_TURN_LEFT), k.call(TradesBus.KEY_TURN_RIGHT)]
	if in_yard:
		var details := "  %s part details" % k.call(TradesBus.KEY_INSPECT) if Flags.is_on("trades.inspect") else ""
		return "%s walk  %s run  %s jump / climb  %s view  wheel/%s tool  LMB use  RMB take off  %s turn%s  %s pause" % [
				walk, k.call(Keys.RUN), k.call(Keys.JUMP), k.call(TradesBus.KEY_VIEW), tools, turn,
				details, k.call(Keys.CANCEL)]
	return "%s walk  %s view  wheel/%s tool  LMB use (hold to carry)  LMB+wheel turn  MMB free/90°  RMB take off  %s amps  %s part  %s reset  %s pause" % [
			walk, k.call(TradesBus.KEY_VIEW), tools, turn, k.call(TradesBus.KEY_NEXT), k.call(TradesBus.KEY_RESET), k.call(Keys.CANCEL)]


func _unhandled_input(event: InputEvent) -> void:
	_handle_input(event)


func _handle_input(event: InputEvent) -> void:
	# A screen with the mouse (the wrist screen, the pause menu, an aimed touch screen) or a
	# trolley driven on remote has the mouse: no looking, no capturing it, no tools.
	if event is InputEventMouse and (HudSlots.pointer_claimed() or _remote_driving()):
		return
	if event is InputEventMouseMotion:
		if not (_focus and _focus.motion(event.relative)):
			worker.look(event.relative)
	elif event is InputEventMouseButton:
		if DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			# Only a press takes the mouse back: a screen's click lets go on its release.
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		_on_mouse_button(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		for action in _actions():
			if InputMap.has_action(action) and event.is_action_pressed(action, false, true):
				_on_action(action)
				return


## The key actions the bay reads (Settings > Key binds can move any of them).
func _actions() -> Array[String]:
	var out: Array[String] = [TradesBus.KEY_VIEW, TradesBus.KEY_TURN_LEFT, TradesBus.KEY_TURN_RIGHT,
			TradesBus.KEY_RESET, TradesBus.KEY_NEXT, TradesBus.KEY_MODE, TradesBus.KEY_HELMET, Keys.INTERACT, Keys.CANCEL]
	for i in hotbar.size():
		out.append(TradesBus.KEY_TOOL + str(i + 1))
	return out


## A key action pressed (Keys / TradesBus.KEY_*).
func _on_action(action: String) -> void:
	if action.begins_with(TradesBus.KEY_TOOL):
		var i := int(action.trim_prefix(TradesBus.KEY_TOOL)) - 1
		if i >= 0 and i < hotbar.size():
			if extinguishers and extinguishers.holding():
				extinguishers.put_down()
			set_tool(hotbar[i])
		return
	if action == Keys.INTERACT and extinguishers and extinguishers.interact():
		return
	match action:
		TradesBus.KEY_VIEW:
			worker.set_view(not worker.third_person)
		TradesBus.KEY_TURN_LEFT, TradesBus.KEY_TURN_RIGHT:
			if _focus and _focus.adjust(1 if action == TradesBus.KEY_TURN_RIGHT else -1):
				_refresh_hud()
		TradesBus.KEY_MODE:
			toggle_mode()
		TradesBus.KEY_HELMET:
			if Flags.is_on("trades.helmet_toggle") and Flags.is_on("trades.weld_helmet"):
				helmet_lowered = not helmet_lowered
				play(&"tick")
		TradesBus.KEY_RESET:
			if _focus and not in_yard:
				_focus.reset()
				hide_result()
				hint(_focus.start_hint())
		Keys.CANCEL:
			# The pause menu (Resume, Save, Main menu, Quit): you stay where you are.
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			Menu.open_pause()
			get_viewport().set_input_as_handled()
		_:
			if _focus and _focus.key(action):
				_refresh_hud()


func _on_mouse_button(event: InputEventMouseButton) -> void:
	if extinguishers and extinguishers.holding() and event.button_index == MOUSE_BUTTON_LEFT:
		extinguishers.set_spraying(event.pressed)
		return
	if _focus == null:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = _focus
				_focus.press(tool)
			elif _pressed:
				_pressed.release()
				_pressed = null
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_focus.back_out(tool)
		MOUSE_BUTTON_MIDDLE:
			# In the yard the middle button is the crew's ping (Graphics).
			if event.pressed and not in_yard:
				toggle_turn_snap()
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				wheel(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)


# --- Every frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if in_yard:
		_keep_the_yard()
		# The yard's still views (its screenshots) borrow the screen: no HUD over them.
		_hud.visible = get_viewport().get_camera_3d() == worker.camera
	_update_focus()
	_placed.clear()
	for s in stations:
		s.update(delta)
	# Tools nobody put on the work ride in the right hand; the rest are put away.
	for id: StringName in tool_nodes:
		var t: TradesTool = tool_nodes[id]
		t.visible = id == tool
		if t.visible and not _placed.has(id):
			t.global_transform = t.carried(worker.right_hand.palm())
	_scale_reach(delta)
	if _focus:
		_status_label.text = _focus.status_line()
	worker.held_still = _remote_driving()
	update_helmet(delta)
	TradesTool.first_person = not worker.third_person
	_update_remote_torches()
	_update_tool_panel()
	_update_inspect()
	_post_info()


## Out on the work, first person, the tool in use and the hand on it are drawn up toward the
## size they'd look in your hand, so they don't shrink to nothing at arm's length (beenster,
## 0.3.15: "they seem to be very small in your hands when the elastic hands reach out").
## Scaled about the tool's working end, so it stays on the joint. trades.reach_scale.
## Within REACH_NEAR_M of the eye they're true size (they're near enough to read); further
## out they grow with the distance, up to REACH_MAX.
const REACH_NEAR_M := 1.0
const REACH_MAX := 1.6
var reach_scale := 1.0


func _scale_reach(delta: float) -> void:
	var t: TradesTool = tool_nodes.get(tool)
	var want := 1.0
	if Flags.is_on("trades.reach_scale") and t and _placed.has(tool) and not worker.third_person:
		var d := worker.camera.global_position.distance_to(t.global_position)
		want = clampf(d / REACH_NEAR_M, 1.0, REACH_MAX)
	reach_scale = move_toward(reach_scale, want, delta * 4.0) if delta > 0.0 else want
	worker.right_hand.size = reach_scale
	if t and _placed.has(tool) and reach_scale != 1.0:
		var o := t.global_position
		t.global_transform = t.global_transform.scaled_local(Vector3.ONE * reach_scale)
		# The hand closes on the grip where the bigger tool has it.
		var hand := worker.right_hand
		if hand.out:
			hand.target = o + (hand.target - o) * reach_scale


## Width of the tool panel's fill bar (pixels).
const TOOL_BAR_PX := 300.0


func _update_tool_panel() -> void:
	if _tool_panel == null:
		return
	var t: TradesTool = tool_nodes.get(tool)
	_tool_title.text = label_of(tool, in_yard).to_upper()
	var rows: Array = t.panel_rows() if t else []
	var lines := PackedStringArray()
	for r: Array in rows:
		lines.append("%-9s %s" % [r[0], r[1]])
	_tool_text.text = "\n".join(lines)
	_tool_text.visible = not lines.is_empty()
	var state := t.panel_state() if t else ("HOLDING" if _focus and _focus.is_busy() else "READY")
	_tool_state.text = state
	var fill := t.readout_fill() if t else -1.0
	_tool_bar.get_parent().visible = fill >= 0.0
	_tool_bar.size.x = TOOL_BAR_PX * clampf(fill, 0.0, 1.0)
	var alert := t.readout_alert() if t else false
	_tool_light.color = Color(1.0, 0.55, 0.15) if alert else Color(0.25, 0.12, 0.05)


func _update_inspect() -> void:
	if _inspect_panel == null:
		return
	var on := InputMap.has_action(TradesBus.KEY_INSPECT) and Input.is_action_pressed(TradesBus.KEY_INSPECT)
	_inspect_panel.visible = on
	if not on:
		_inspect_label.text = ""
		return
	var lines := _focus.inspect_lines() if _focus else PackedStringArray()
	if lines.is_empty():
		lines = PackedStringArray(["Look at a part or a joint."])
	_inspect_label.text = "\n".join(lines)


## What the tool panel and the inspect panel show now (tests).
func tool_panel_text() -> String:
	return "%s\n%s\n%s" % [_tool_title.text, _tool_text.text, _tool_state.text] if _tool_panel else ""


func inspect_text() -> String:
	return _inspect_label.text if _inspect_panel and _inspect_panel.visible else ""


## The ids of Tools' cards in the HUD's right-hand panel (UI's HudSlots.set_info).
const INFO_TOOL := "trades.tool"
const INFO_HINT := "trades.hint"
const INFO_PART := "trades.part"


## The mouse in the tips (TradesStation.actions); keys go by their bound names.
const CLICK := "Left click"
const HOLD_CLICK := "Hold left click"
const RIGHT_CLICK := "Right click"
const HOLD_RIGHT := "Hold right click"
const WHEEL := "Mouse wheel"


## The action that takes up a tool from the hotbar, or "-" when it isn't on it.
func tool_action(id: StringName) -> String:
	var i := hotbar.find(id)
	return TradesBus.KEY_TOOL + str(i + 1) if i >= 0 else "-"


## The key that takes up a tool from the hotbar ("2"), or "-".
func tool_key(id: StringName) -> String:
	var action := tool_action(id)
	return Keys.key_name(action) if Keys.has(action) else action


## What the hint card shows for the tool in hand on what you're looking at (UI's look hint,
## HudSlots.register_look_hint): {title, keys}, or {} while there's nothing to do.
func look_hint(hit := {}) -> Dictionary:
	if _focus == null or not _hud.visible:
		return {}
	var keys := _focus.actions(tool)
	var info := part_info(hit)
	if keys.is_empty() and (info.is_empty() or (_own_hint(hit) and not _hit_is_part(hit))):
		# Nothing to do here, or it has its own card (a door button on the ship, a machine).
		return {}
	if Flags.is_on("trades.inspect") and not Flags.is_on("trades.part_info") and InputMap.has_action(TradesBus.KEY_INSPECT) \
			and not _focus.inspect_lines().is_empty():
		keys.append([TradesBus.KEY_INSPECT, "part details (hold)"])
	var title := _focus.aim_title(tool) if not keys.is_empty() else ""
	# The spec of what you're looking at, tool in hand (beenster, 2026-10-22).
	var spec := _focus.aim_spec(tool) if Flags.is_on("trades.hover_specs") else ""
	if title == "" and not info.is_empty():
		title = info[0].capitalize()
		info.remove_at(0)
	var text := spec
	if not info.is_empty():
		text += ("\n\n" if text != "" else "") + "\n".join(info)
	return {"title": title if title != "" else _focus.title, "text": text, "keys": keys}


## trades.part_info (beenster, 0.3.19: "When I look at a part (anywhere in the game) I must be
## able to see its information on the right hand panel"): the details of the part under the
## aim, always on the look card, not only while the inspect key is held: a part on the ship,
## loose or on a trolley (TradesShipJoints.inspect_lines), else anything carrying meta
## "component" (TradesShipJoints.component_lines). Empty for none.
func part_info(hit: Dictionary) -> PackedStringArray:
	if not Flags.is_on("trades.part_info") or _focus == null:
		return PackedStringArray()
	var lines := _focus.inspect_lines()
	if lines.is_empty() and hit.get("collider") is Node:
		lines = TradesShipJoints.component_lines(hit.get("collider") as Node)
	return lines


## The thing under the view has its own look card (a method or meta "look_hint").
static func _own_hint(hit: Dictionary) -> bool:
	var n := hit.get("collider") as Node
	while n != null:
		if n.has_method("look_hint") or n.has_meta("look_hint"):
			return true
		n = n.get_parent()
	return false


## The thing under the view is a part (meta "component"), so its details win over its card.
static func _hit_is_part(hit: Dictionary) -> bool:
	var n := hit.get("collider") as Node
	while n != null:
		if n.has_meta("component"):
			return true
		n = n.get_parent()
	return false


## What you can do now with the tool in your hand on what you're looking at, with its keys
## (beenster, 0.3.7: no walking keys all the time, only tips for the thing under the aim).
## Empty while there's nothing to do.
func context_tips() -> PackedStringArray:
	var out := PackedStringArray()
	for r: Array in look_hint().get("keys", []):
		var key := str(r[0])
		out.append("%s: %s" % [Keys.key_name(key) if Keys.has(key) else key, r[1]])
	return out


## What used to be text top left (the tool, what you're working on, the hint, the keys) and
## the part details go to the HUD's one see-through panel on the right (beenster, 0.3.6:
## the top-left text overlapped itself). The labels stay as the text's holders. What you can
## do with the tool on what's under the aim is UI's look card, from look_hint().
func _post_info() -> void:
	if not _hud.visible:
		_clear_info()
		return
	var status := _status_label.text
	HudSlots.set_info(INFO_TOOL, "Tool", _tool_label.text.trim_prefix("TOOL").strip_edges()
			+ ("\n" + status if status != "" else ""), 10)
	if hint_showing():
		HudSlots.set_info(INFO_HINT, "Next", _hint_label.text, 11)
	else:
		HudSlots.clear_info(INFO_HINT)
	if _inspect_label and _inspect_label.text != "":
		HudSlots.set_info(INFO_PART, "Part details", _inspect_label.text, 12)
	else:
		HudSlots.clear_info(INFO_PART)


func _clear_info() -> void:
	for id: String in [INFO_TOOL, INFO_HINT, INFO_PART]:
		HudSlots.clear_info(id)


func _update_focus() -> void:
	if _focus and _focus.is_busy():
		return
	var next := station_under_aim()
	if next != _focus and next != null:
		_focus = next
		hint(_focus.start_hint())
		_refresh_hud()


## The station whose stretch of bench the aim falls on (or the nearest to it).
func station_under_aim() -> TradesStation:
	if stations.is_empty():
		return null
	if in_yard:
		return stations[0]
	var hit: Variant = Plane(Vector3.UP, BENCH_TOP + 0.05).intersects_ray(worker.aim_origin(), worker.aim_dir())
	var x: float = (hit as Vector3).x if hit != null else worker.global_position.x
	var best: TradesStation = stations[0]
	for s in stations:
		if absf(x - s.position.x) < absf(x - best.position.x):
			best = s
	return best


# --- Services for stations ----------------------------------------------------------------

func hint(text: String) -> void:
	_hint_label.text = text
	_hint_at = Time.get_ticks_msec()
	_hint_on = _focus.aim_key() if _focus else ""


## How long a hint stays up in the yard's right-hand panel (seconds): long enough to read,
## then the panel keeps only what's under the aim.
const HINT_S := 6.0
var _hint_at := 0
## What the aim was on when the hint came up (TradesStation.aim_key): with trades.hint_stays
## the hint stays for as long as you keep looking at it (beenster, 0.3.15: "this should be
## there for as long as i look at the object").
var _hint_on := ""


## Whether the yard's right-hand panel still shows the last hint.
func hint_showing() -> bool:
	if _hint_label.text == "":
		return false
	if not in_yard or Time.get_ticks_msec() - _hint_at < HINT_S * 1000.0:
		return true
	return Flags.is_on("trades.hint_stays") and _hint_on != "" and _focus != null and _focus.aim_key() == _hint_on


## A station put this tool on the work this frame (so the bay leaves it there).
func place_tool(id: StringName, xform: Transform3D) -> void:
	var t: TradesTool = tool_nodes.get(id)
	if t:
		t.global_transform = xform
		_placed[id] = true


func tool_node(id: StringName) -> TradesTool:
	return tool_nodes.get(id)


## How far a point is from the aim line (metres), or INF if it is behind you or out of reach.
func aim_distance(p: Vector3) -> float:
	var o := worker.aim_origin()
	var d := worker.aim_dir()
	var t := (p - o).dot(d)
	if t < 0.0 or t > 4.0:
		return INF
	return (o + d * t).distance_to(p)


## Where the aim meets a plane, or null.
func aim_on(plane: Plane) -> Variant:
	return plane.intersects_ray(worker.aim_origin(), worker.aim_dir())


## The nearest of `points` to the aim line within `pick_m`, or -1.
func pick(points: Array, pick_m: float) -> int:
	var best := -1
	var best_d := pick_m
	for i in points.size():
		var d := aim_distance(points[i])
		if d < best_d:
			best = i
			best_d = d
	return best


func play(sound: StringName, pitch := 1.0, db := 0.0) -> void:
	var p: AudioStreamPlayer = _players.get(sound)
	if p == null or DisplayServer.get_name() == "headless":
		return
	p.pitch_scale = pitch
	p.volume_db = db
	p.play()


## A looping sound (the drill's whine, the welding arc) on or off.
func loop(sound: StringName, on: bool, pitch := 1.0) -> void:
	if on:
		_looping = sound
	elif _looping == sound:
		_looping = &""
	var p: AudioStreamPlayer = _loops.get(sound)
	if p == null or DisplayServer.get_name() == "headless":
		return
	p.pitch_scale = pitch
	if on and not p.playing:
		p.play()
	elif not on and p.playing:
		p.stop()


func show_result(lines: PackedStringArray) -> void:
	lines.append("")
	lines.append("Quality grades this joint." if Modules.is_loaded("quality") else "Grading arrives with the Quality module.")
	lines.append("R to reset the station.")
	_result_label.text = "\n".join(lines)
	_result_panel.visible = true


func hide_result() -> void:
	_result_panel.visible = false


func bus() -> TradesBus:
	return Modules.bus("trades") as TradesBus


## Release screenshot of one station mid-job, first or third person.
func stage_for_screenshot(station_id: StringName = &"bolting", third_person: bool = false) -> void:
	var s := station(station_id)
	if s == null:
		return
	reset_all()
	_focus = s
	await s.stage_for_screenshot()
	var view := s.screenshot_view()
	worker.set_view(third_person)
	worker.global_position = s.to_global(view[0])
	worker.face(s.to_global(view[1]))
	_focus = s
	_refresh_hud()
	for i in 30:
		await get_tree().process_frame


## Release screenshot in the yard: the worker at the ship with a joint of `kind` mid-job.
func stage_on_ship(kind: String = "bolt", third_person: bool = false) -> void:
	var s := ship_station()
	if s == null:
		return
	s.reset()
	var view := s.stage_joint(kind, 2.2 if third_person else 1.5)
	if view.is_empty():
		return
	set_tool(s._tool_held)
	worker.set_view(third_person)
	worker.global_position = view[0]
	worker.face(view[1])
	for i in 30:
		await get_tree().process_frame


## Release screenshot in the yard: looking at a joint on the ship with Tab held, its part's
## details up.
func stage_inspect() -> void:
	var s := ship_station()
	if s == null:
		return
	var view := s.stage_joint("bolt", 1.5)
	if view.is_empty():
		return
	s.reset()
	s.aimed = -1
	set_tool(&"torque_wrench")
	worker.set_view(false)
	worker.global_position = view[0]
	worker.face(view[1])
	Input.action_press(TradesBus.KEY_INSPECT)
	for i in 30:
		await get_tree().process_frame


## Release screenshot in the yard: the tool test stand, from just in front of it (first
## person, aiming at a bolt with the power wrench) or from behind you (third person).
func stage_test_stand(third_person: bool = false) -> void:
	var s := ship_station()
	if s == null or s.test_stand == null:
		return
	var stand := s.test_stand
	var at := stand.global_transform * Vector3(0, 1.25, 0)
	var feet := stand.global_transform * Vector3(-0.5 if not third_person else 0.0, 0.0, 1.0 if not third_person else 1.7)
	worker.global_position = feet
	worker.face(stand.global_transform * Vector3(-0.85, 1.25, 0) if not third_person else at)
	worker.set_view(third_person)
	set_tool(&"torque_wrench")
	for i in 30:
		await get_tree().process_frame


## Release screenshot in the yard: an engine off the ship and up in the tractor beam.
func stage_tractor(third_person: bool = true) -> void:
	var s := ship_station()
	var yard_bus := Modules.bus("ship_bay") as ShipBayBus
	if s == null or yard_bus == null or yard_bus.get_slots().is_empty():
		return
	var slot := yard_bus.get_slots()[0]
	for f in yard_bus.get_fasteners(slot.slot_id):
		yard_bus.note_joint_removed(f.joint_id)
	var part: TradesLoosePart = s.tractor.loose.get(slot.slot_id)
	if part == null:
		return
	var out := (s.ship_xform * slot.mount).basis.z
	out = Vector3(out.x, 0.0, out.z).normalized()
	# Take hold in first person (the aim is the view), then step back and look on.
	worker.set_view(false)
	worker.global_position = Vector3(part.centre().x, global_position.y, part.centre().z) + out * 2.6
	worker.face(part.centre())
	set_tool(&"tractor")
	_focus = s
	s.press(&"tractor")
	worker.set_view(third_person)
	worker.global_position += out * 1.2
	worker.look(Vector2(0, -60))
	for i in 40:
		await get_tree().process_frame


# --- Building the bay -------------------------------------------------------------------

func _walk_to(s: TradesStation) -> void:
	worker.global_position = s.to_global(Vector3(0.0, 0.0, 0.58))
	worker.face(s.to_global(Vector3(0.0, BENCH_TOP, 0.0)))


func _build_worker() -> void:
	worker = BenchWorker.new()
	worker.name = "Worker"
	worker.agile = Flags.is_on("trades.jump")
	add_child(worker)
	if in_yard and Flags.is_on("trades.hover_board"):
		worker.board = TradesHoverBoard.new()
		worker.board.name = "HoverBoard"
		worker.add_child(worker.board)
	for hand: StretchHand in [worker.left_hand, worker.right_hand]:
		hand.reach_m = HAND_REACH_M
		hand.stretch_m = YARD_STRETCH_M if in_yard else HAND_STRETCH_M
		hand.snapped.connect(_on_hand_snapped)


func _on_hand_snapped() -> void:
	if _focus:
		_focus.on_hand_snapped()
	hint("Too far: your arm let go.")


func _build_tools() -> void:
	var scripts := {
		&"torque_wrench": TradesPowerWrench if TradesShipJoints.powered() else TradesTorqueWrench, &"drill": TradesDrill, &"rivet_squeezer": TradesRivetGun if in_yard and Flags.is_on("trades.power_riveter") else TradesRivetSqueezer,
		&"welder": TradesWeldTorch, &"wire_tool": TradesWireTool, &"tractor": TradesTractorTool, &"cutter": TradesCutter,
	}
	for id: StringName in scripts:
		var t: TradesTool = (scripts[id] as GDScript).new()
		t.title = label_of(id, in_yard)
		t.top_level = true
		t.visible = false
		add_child(t)
		tool_nodes[id] = t


func _build_audio() -> void:
	_players[&"click"] = _player(TradesSounds.burst(0.05, 0.9, 900.0))
	_players[&"tick"] = _player(TradesSounds.burst(0.025, 0.3, 2600.0))
	_players[&"clunk"] = _player(TradesSounds.burst(0.09, 0.8, 500.0))
	_loops[&"drill"] = _player(TradesSounds.hum(0.5, 0.25, 180.0, 2200.0))
	_loops[&"arc"] = _player(TradesSounds.hum(0.5, 0.35, 120.0, 6000.0))
	_loops[&"beam"] = _player(TradesSounds.hum(0.5, 0.2, 70.0, 900.0))
	# trades.quiet_tractor (beenster, 0.3.18: "keep our grabber but make it quieter").
	if Flags.is_on("trades.quiet_tractor"):
		_loops[&"beam"].volume_db = TradesTractor.QUIET_DB
	_loops[&"impact"] = _player(TradesSounds.rattle(0.5, 0.35, 95.0, 22.0))
	_players[&"stall"] = _player(TradesSounds.burst(0.25, 0.7, 300.0))
	_loops[&"pressure"] = _player(TradesSounds.hum(0.5, 0.18, 60.0, 4000.0))
	_loops[&"grind"] = _player(TradesSounds.hum(0.5, 0.4, 180.0, 7000.0))
	_players[&"punch"] = _player(TradesSounds.burst(0.12, 1.0, 1400.0))
	_players[&"pop"] = _player(TradesSounds.burst(0.06, 0.8, 1800.0))


func _player(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	return p


func _build_room() -> void:
	var env := WorldEnvironment.new()
	env.environment = TradesLook.environment()
	add_child(env)

	# A BSX fitting bay, fitted out like a Void Salvage ship's hold: deck plate, warm-white
	# wall panels on dark frames, lit edge strips and a name board.
	var deck := TradesLook.paint(Color(0.32, 0.33, 0.35), 0.6, 0.55, "galvanised")
	var shell := TradesLook.paint(TradesLook.SHELL.darkened(0.4), 0.25, 0.42)
	var dark := TradesLook.paint(TradesLook.DARK, 0.55, 0.5)
	var trim := TradesLook.paint(TradesLook.TRIM, 0.3, 0.45)
	var edge := TradesLook.glow(TradesLook.EDGE, 1.6)
	var solid := StaticBody3D.new()
	solid.name = "Solid"
	add_child(solid)
	var wall_x := -BENCH_HALF - 0.45
	_solid_box(solid, Vector3(12, 0.1, 8), Vector3(0, -0.05, 2.0), deck)
	_solid_box(solid, Vector3(12, 3.0, 0.1), Vector3(0, 1.5, -0.6), dark)                # back wall frame
	_solid_box(solid, Vector3(0.1, 3.0, 8), Vector3(wall_x, 1.5, 3.4), dark)             # side wall frame
	var x := wall_x + 0.45
	while x < 5.0:
		_box(Vector3(0.7, 1.05, 0.02), Vector3(x, 1.75, -0.54), shell)                     # wall panels
		_box(Vector3(0.7, 0.5, 0.02), Vector3(x, 0.4, -0.54), shell)
		x += 0.75
	for z: float in [-0.15, 0.6, 1.35, 2.1]:
		_box(Vector3(0.02, 1.05, 0.7), Vector3(wall_x + 0.06, 1.75, z), shell)
	for y: float in [1.2, 2.3]:
		_box(Vector3(12, 0.012, 0.006), Vector3(0, y, -0.528), edge)                     # edge strips
	_box(Vector3(0.006, 0.012, 8), Vector3(wall_x + 0.072, 1.2, 3.4), edge)
	_box(Vector3(12, 0.04, 0.006), Vector3(0, 0.06, -0.548), trim)                       # kick strip
	_name_board("BSX LTD  //  FITTING BAY 1", Vector3(0.0, 2.6, -0.525), 1.4, dark, trim)

	# Cool ceiling strips over the walkway.
	for sx: float in [-1.6, 0.0, 1.6]:
		var at := Vector3(sx, 2.9, 1.4)
		_box(Vector3(0.9, 0.025, 0.12), at, TradesLook.glow(Color(0.9, 0.95, 1.0), 3.0))
		var strip := OmniLight3D.new()
		strip.position = at + Vector3(0, -0.25, 0)
		strip.light_color = Color(0.92, 0.96, 1.0)
		strip.light_energy = 0.25
		strip.omni_range = 3.5
		add_child(strip)


## The bench: a dark pedestal, a steel top with a lit front edge and an orange trim band.
func _build_bench() -> void:
	var dark := TradesLook.paint(TradesLook.DARK, 0.55, 0.5)
	var trim := TradesLook.paint(TradesLook.TRIM, 0.3, 0.45)
	var top := TradesLook.paint(TradesLook.TOP.darkened(0.35), 0.3, 0.3, "brushed_steel")
	var edge := TradesLook.glow(TradesLook.EDGE, 1.6)
	var solid := StaticBody3D.new()
	solid.name = "BenchSolid"
	add_child(solid)
	var length := BENCH_HALF * 2.0
	_solid_box(solid, Vector3(length, BENCH_TOP - 0.03, 0.6), Vector3(0, (BENCH_TOP - 0.03) / 2.0, -0.05), dark)
	_box(Vector3(length + 0.04, 0.03, 0.64), Vector3(0, BENCH_TOP - 0.015, -0.05), top)
	_box(Vector3(length + 0.04, 0.006, 0.004), Vector3(0, BENCH_TOP - 0.02, BENCH_FRONT + 0.002), edge)
	_box(Vector3(length, 0.05, 0.004), Vector3(0, BENCH_TOP - 0.09, BENCH_FRONT - 0.018), trim)


## Each station's sign on the wall and strip lamp over its stretch of bench.
func _build_station_dressing(s: TradesStation) -> void:
	var dark := TradesLook.paint(TradesLook.DARK, 0.55, 0.5)
	var trim := TradesLook.paint(TradesLook.TRIM, 0.3, 0.45)
	_name_board(s.title.to_upper(), s.position + Vector3(0, 1.62, -0.525), 0.5, dark, trim)
	var lamp_at := s.position + Vector3(0.0, 2.25, -0.05)
	_box(Vector3(0.98, 0.06, 0.22), lamp_at + Vector3(0, 0.04, 0), dark)
	_box(Vector3(0.9, 0.025, 0.12), lamp_at, TradesLook.glow(TradesLook.WARM, 2.2))
	var edge := TradesLook.glow(TradesLook.EDGE, 1.6)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.96, 0.008, 0.008), lamp_at + Vector3(0, 0.012, side * 0.105), edge)
	var lamp := OmniLight3D.new()
	lamp.position = lamp_at + Vector3(0, -0.25, 0)
	lamp.light_color = Color(1.0, 0.84, 0.66)
	lamp.light_energy = 0.45
	lamp.omni_range = 2.2
	lamp.shadow_enabled = true
	add_child(lamp)


## A name board (ShipParts.name_board): a dark plate, the name in lit letters, a trim band.
func _name_board(text: String, at: Vector3, width: float, dark: Material, trim: Material) -> void:
	_box(Vector3(width, 0.2, 0.02), at, dark)
	_box(Vector3(width, 0.025, 0.022), at + Vector3(0, -0.085, 0), trim)
	var label := Label3D.new()
	label.font = TradesLook.mono_font()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.0011
	label.modulate = TradesLook.EDGE
	label.position = at + Vector3(0, 0.015, 0.012)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)


func _solid_box(body: StaticBody3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	_box(size, pos, mat)
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	shape.position = pos
	body.add_child(shape)


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)
	return mi


# --- HUD ----------------------------------------------------------------------------------

## The HUD in Void Salvage's style (Hud): cyan monospace readout lines top left, the hotbar
## of boxed slots along the bottom, a small key line, the result card top right.
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	_hud = layer
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_weld_view = TradesWeldingView.new()
	root.add_child(_weld_view)

	var cross := ColorRect.new()
	cross.color = TradesLook.HUD
	cross.custom_minimum_size = Vector2(4, 4)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)

	var keys := TradesLook.hud_label(15, TradesLook.HUD_DIM)
	keys.text = _keys_line()
	keys.position = Vector2(40, 36)
	keys.visible = false   # in the right-hand panel (_post_info)
	root.add_child(keys)

	var box := VBoxContainer.new()
	box.position = Vector2(40, 80)
	box.visible = false    # in the right-hand panel (_post_info)
	box.add_theme_constant_override("separation", 4)
	root.add_child(box)
	_tool_label = TradesLook.hud_label(26)
	_status_label = TradesLook.hud_label(26)
	_hint_label = TradesLook.hud_label(20, TradesLook.HUD_WARN)
	_hint_label.custom_minimum_size.x = 620
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_tool_label)
	box.add_child(_status_label)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	box.add_child(gap)
	box.add_child(_hint_label)

	var bar := HBoxContainer.new()
	bar.name = "Hotbar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 10)
	root.add_child(bar)
	for i in hotbar.size():
		var slot := PanelContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := TradesLook.hud_label(18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(112, 0)
		label.text = "%d  %s" % [i + 1, label_of(hotbar[i], in_yard).to_upper()]
		slot.add_child(label)
		bar.add_child(slot)
		_slots.append(slot)
		_slot_labels.append(label)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 32)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_result_panel = PanelContainer.new()
	_result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := TradesLook.slot_style(false)
	card.bg_color = Color(0.0, 0.02, 0.04, 0.75)
	card.set_content_margin_all(18)
	_result_panel.add_theme_stylebox_override("panel", card)
	root.add_child(_result_panel)
	_result_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
	_result_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_result_label = TradesLook.hud_label(18)
	_result_panel.add_child(_result_label)
	_result_panel.visible = false

	# The readings live on the tool's own display now; the HUD panel only without one.
	if Flags.is_on("trades.tool_panel") and not Flags.is_on("trades.tool_display"):
		_build_tool_panel(root)
	if Flags.is_on("trades.inspect"):
		_inspect_panel = _card()
		root.add_child(_inspect_panel)
		_inspect_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
		_inspect_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_inspect_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		var details := VBoxContainer.new()
		details.add_theme_constant_override("separation", 6)
		_inspect_panel.add_child(details)
		var head := TradesLook.hud_label(16, TradesLook.HUD_WARN)
		head.text = "PART DETAILS"
		details.add_child(head)
		_inspect_label = TradesLook.hud_label(20)
		details.add_child(_inspect_label)
		_inspect_panel.visible = false
		_inspect_panel.modulate.a = 0.0   # shown in the right-hand panel (_post_info)


## The tool in hand's readings, large and labelled, bottom right over the hotbar: its name,
## each reading (torque, amps, rpm...), a fill bar with the status light, and what it's doing.
func _build_tool_panel(root: Control) -> void:
	_tool_panel = _card()
	root.add_child(_tool_panel)
	_tool_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
	_tool_panel.offset_bottom = -110
	_tool_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tool_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_tool_panel.add_child(box)
	_tool_title = TradesLook.hud_label(18, TradesLook.HUD_WARN)
	box.add_child(_tool_title)
	_tool_text = TradesLook.hud_label(26)
	box.add_child(_tool_text)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 10)
	box.add_child(bar_row)
	var track := ColorRect.new()
	track.color = Color(0.62, 0.9, 1.0, 0.15)
	track.custom_minimum_size = Vector2(TOOL_BAR_PX, 10)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(track)
	_tool_bar = ColorRect.new()
	_tool_bar.color = TradesLook.HUD
	_tool_bar.size = Vector2(0, 10)
	track.add_child(_tool_bar)
	_tool_light = ColorRect.new()
	_tool_light.custom_minimum_size = Vector2(14, 14)
	_tool_light.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(_tool_light)
	_tool_state = TradesLook.hud_label(20, TradesLook.HUD_DIM)
	box.add_child(_tool_state)


func _card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := TradesLook.slot_style(false)
	card.bg_color = Color(0.0, 0.02, 0.04, 0.75)
	card.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", card)
	return panel


func refresh_hud() -> void:
	_refresh_hud()


func _refresh_hud() -> void:
	if _tool_label == null:
		return
	_tool_label.text = "TOOL    %s" % label_of(tool, in_yard).to_upper()
	if tool == &"hands" and not in_yard:
		_tool_label.text += "    TURN %s" % ("90°" if turn_snap else "FREE")
	_status_label.text = _focus.status_line() if _focus else ""
	var useful: Array[StringName] = _focus.tools() if _focus else hotbar
	for i in _slots.size():
		var on := hotbar[i] == tool
		_slots[i].add_theme_stylebox_override("panel", TradesLook.slot_style(on))
		var c := TradesLook.HUD if on else TradesLook.HUD_DIM
		if not on and not useful.has(hotbar[i]):
			c = Color(c, 0.15)
		_slot_labels[i].label_settings.font_color = c


# --- The welding shield, and other players' arcs --------------------------------------------

## The event that tells everyone where your arc is (beenster, 0.3.7: "this should be seen by
## all players"): {on, at, cutting}; the host stamps the sender's peer.
const TORCH_EVENT := "trades.torch"
## How fast the shield flicks down and lifts (per second), and how long it stays down after
## the arc goes out (s).
const HELMET_DOWN_RATE := 9.0
const HELMET_UP_RATE := 3.5
const HELMET_HOLD_S := 0.4
## How fast it comes down on its key (per second; beenster 0.3.16: slower), trades.helmet_toggle.
const HELMET_LOWER_RATE := 2.2
## How often a moving arc is sent (s) and how far it must have moved (m).
const TORCH_SEND_S := 0.2
const TORCH_SEND_M := 0.02


## The shield comes down while the arc is lit (welding or unwelding) and lifts after; in first
## person you look out through its glass. Tells the other players when your arc changes.
func update_helmet(delta: float) -> void:
	var torch := tool_node(&"welder") as TradesWeldTorch
	var lit := torch != null and torch.lit
	# Heating a rivet out is a small, short glow: the shield stays up (beenster, 2026-10-22).
	_arc_off_s = 0.0 if lit and not torch.on_rivet else _arc_off_s + delta
	var want := 1.0 if _arc_off_s < HELMET_HOLD_S and Flags.is_on("trades.weld_helmet") else 0.0
	var down_rate := HELMET_DOWN_RATE
	if Flags.is_on("trades.helmet_toggle") and Flags.is_on("trades.weld_helmet"):
		# The shield is yours to drop (its key) before you strike, and stays till you lift it.
		# Strike with it up and it still comes down, so you never weld bare-eyed.
		if lit and not torch.on_rivet:
			if not helmet_lowered:
				hint("%s drops the shield before you strike." % Keys.key_name(TradesBus.KEY_HELMET))
			helmet_lowered = true
		want = 1.0 if helmet_lowered else 0.0
		down_rate = HELMET_LOWER_RATE
	_helmet = move_toward(_helmet, want, delta * (down_rate if want > _helmet else HELMET_UP_RATE))
	if worker.welding_helmet:
		worker.welding_helmet.down = _helmet
	if _weld_view:
		_weld_view.down = 0.0 if worker.third_person or not worker.camera.current else _helmet
	if sparks and Flags.is_on("trades.weld_from_end"):
		sparks.dim = 0.0 if worker.third_person else _helmet
	_send_torch(lit, torch.global_position if lit else Vector3.ZERO, lit and torch.cutting, delta, lit and not torch.on_rivet)


## Whether Tools' HUD is up (the player's own view, not a still or a menu camera).
func hud_showing() -> bool:
	return _hud != null and _hud.visible


## How far down your shield is (0..1).
func helmet_down() -> float:
	return _helmet


## The tool loop sounding now (&"" for none).
func looping() -> StringName:
	return _looping


## A tool loop's sound, for a crewmate's tool to play (null for none).
func loop_stream(sound: StringName) -> AudioStream:
	var p: AudioStreamPlayer = _loops.get(sound)
	return p.stream if p else null


## A crewmate's shield down or up (TradesCrew, from what they share): on their avatar's head.
func crew_helmet(peer: int, down: bool, head: Node3D = null) -> void:
	var r := _remote(peer)
	r.crew_shield = down
	_fit_remote_helmet(peer, r, head)


func _send_torch(on: bool, at: Vector3, cutting: bool, delta: float, shield := true) -> void:
	var net := _net()
	if net == null or not in_yard or not bool(net.call("is_online")):
		return
	_torch_sent_s += delta
	var was_on := bool(_torch_sent.get("on", false))
	if on == was_on and (not on or _torch_sent_s < TORCH_SEND_S
			or (at.distance_to(_torch_sent.get("at", Vector3.ZERO)) < TORCH_SEND_M and cutting == bool(_torch_sent.get("cutting")))):
		return
	_torch_sent = {"on": on, "at": at, "cutting": cutting, "shield": shield}
	_torch_sent_s = 0.0
	net.call("request", TORCH_EVENT, _torch_sent)


func _validate_torch(sender: int, p: Dictionary) -> Variant:
	if not p.get("at") is Vector3:
		return "no arc position"
	return {"peer": sender, "on": bool(p.get("on")), "at": p.at, "cutting": bool(p.get("cutting")),
			"shield": bool(p.get("shield", true))}


## Another player's arc lit, moved or out: draw it, its sparks and their shield.
func _apply_torch(p: Dictionary) -> void:
	var net := _net()
	var peer := int(p.get("peer", 0))
	if net and peer == int(net.call("local_peer_id")):
		return
	var r := _remote(peer)
	r.on = bool(p.on)
	r.at = p.at as Vector3
	r.cutting = bool(p.cutting)
	r.shield = bool(p.get("shield", true))
	_fit_remote_helmet(peer, r)


## A crewmate's arc light, glow and shield, made on first need.
func _remote(peer: int) -> Dictionary:
	var r: Dictionary = remote_torches.get(peer, {})
	if r.is_empty():
		var light := OmniLight3D.new()
		light.light_color = Color(0.7, 0.85, 1.0)
		light.omni_range = 3.0
		light.top_level = true
		add_child(light)
		var glow := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.012
		ball.height = 0.024
		glow.mesh = ball
		glow.material_override = TradesLook.glow(Color(0.75, 0.9, 1.0), 8.0)
		glow.top_level = true
		add_child(glow)
		r = {"light": light, "glow": glow, "helmet": null, "on": false, "crew_shield": false}
		remote_torches[peer] = r
	return r


## Their shield, on Multiplayer's avatar of them when it offers the head.
## Avatars are rebuilt now and then (a scene change): fetch the head again when ours is gone.
func _fit_remote_helmet(peer: int, r: Dictionary, head: Node3D = null) -> void:
	var net := _net()
	if not is_instance_valid(r.helmet) and head == null and net and net.has_method("avatar_head"):
		head = net.call("avatar_head", peer) as Node3D
	if not is_instance_valid(r.helmet):
		if head:
			var h := TradesWeldingHelmet.new()
			head.add_child(h)
			r.helmet = h


func _update_remote_torches() -> void:
	for peer: int in remote_torches.keys():
		var r: Dictionary = remote_torches[peer]
		var light := r.light as OmniLight3D
		var glow := r.glow as MeshInstance3D
		var on := bool(r.get("on", false))
		light.visible = on
		glow.visible = on
		if is_instance_valid(r.helmet):
			var h := r.helmet as TradesWeldingHelmet
			var want := 1.0 if (on and bool(r.get("shield", true))) or bool(r.get("crew_shield", false)) else 0.0
			h.down = move_toward(h.down, want, get_process_delta_time() * HELMET_DOWN_RATE)
		if not on:
			continue
		var at: Vector3 = r.at
		light.global_position = at + Vector3(0, 0.05, 0)
		light.light_energy = 1.0 + randf() * 0.8
		glow.global_position = at
		if sparks:
			if Flags.is_on("trades.molten"):
				sparks.emit_weld(at, Vector3.UP, TradesShipJoints.weld_sparks(r.cutting), 3.2, 0.9)
			else:
				sparks.emit(at, Vector3.UP, TradesShipJoints.SPARKS_CUT if r.cutting else TradesShipJoints.SPARKS_WELD, 3.2, 0.9)


## Remote arcs drawn now (tests).
func remote_arcs() -> int:
	var n := 0
	for r: Dictionary in remote_torches.values():
		n += 1 if r.get("on", false) else 0
	return n


## Multiplayer's bus, when it is loaded.
func _net() -> Node:
	var net: Node = Modules.bus("multiplayer")
	return net if net and net.has_method("register_event") else null
