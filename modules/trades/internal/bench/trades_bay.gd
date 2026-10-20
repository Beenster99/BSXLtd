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
}
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

## Set before adding to the tree: you are in the shipyard working on the ship, not at a bench.
var in_yard := false
var worker: BenchWorker
var tool: StringName = &"hands"
## The tools on your hotbar (keys 1..n): TOOLS, and in the yard the tractor beam
## (flag "trades.tractor").
var hotbar: Array[StringName] = []
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


func _ready() -> void:
	if not in_yard:
		_build_room()
		_build_bench()
	hotbar.assign(TOOLS)
	if in_yard and Flags.is_on("trades.tractor"):
		hotbar.append(&"tractor")
	_build_worker()
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
	_focus = s
	if yard_bus:
		yard_bus.set_walker_active(yard, false)
		var feet := yard.global_transform * yard_bus.walker_position(yard) if yard else Vector3.ZERO
		worker.global_position = feet
	worker.face(ship_transform().origin + Vector3(0, -0.4, 0))
	worker.camera.current = true
	set_tool(&"hands")
	hint(s.start_hint())
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
	cycle_tool(step)


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
		return "%s walk  %s run  %s view  wheel/%s tool  LMB use  RMB take off  %s turn  %s menu" % [
				walk, k.call(Keys.RUN), k.call(TradesBus.KEY_VIEW), tools, turn, k.call(Keys.CANCEL)]
	return "%s walk  %s view  wheel/%s tool  LMB use (hold to carry)  LMB+wheel turn  MMB free/90°  RMB take off  %s amps  %s part  %s reset  %s menu" % [
			walk, k.call(TradesBus.KEY_VIEW), tools, turn, k.call(TradesBus.KEY_NEXT), k.call(TradesBus.KEY_RESET), k.call(Keys.CANCEL)]


func _unhandled_input(event: InputEvent) -> void:
	_handle_input(event)


func _handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if not (_focus and _focus.motion(event.relative)):
			worker.look(event.relative)
	elif event is InputEventMouseButton:
		if DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
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
			TradesBus.KEY_RESET, TradesBus.KEY_NEXT, Keys.INTERACT, Keys.CANCEL]
	for i in hotbar.size():
		out.append(TradesBus.KEY_TOOL + str(i + 1))
	return out


## A key action pressed (Keys / TradesBus.KEY_*).
func _on_action(action: String) -> void:
	if action.begins_with(TradesBus.KEY_TOOL):
		var i := int(action.trim_prefix(TradesBus.KEY_TOOL)) - 1
		if i >= 0 and i < hotbar.size():
			set_tool(hotbar[i])
		return
	match action:
		TradesBus.KEY_VIEW:
			worker.set_view(not worker.third_person)
		TradesBus.KEY_TURN_LEFT, TradesBus.KEY_TURN_RIGHT:
			if _focus and _focus.adjust(1 if action == TradesBus.KEY_TURN_RIGHT else -1):
				_refresh_hud()
		TradesBus.KEY_RESET:
			if _focus and not in_yard:
				_focus.reset()
				hide_result()
				hint(_focus.start_hint())
		Keys.CANCEL:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if Router.has_scene("main_menu"):
				Router.goto("main_menu")
		_:
			if _focus and _focus.key(action):
				_refresh_hud()


func _on_mouse_button(event: InputEventMouseButton) -> void:
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
			if event.pressed:
				toggle_turn_snap()
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				wheel(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)


# --- Every frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if in_yard:
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
	if _focus:
		_status_label.text = _focus.status_line()


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


func play(sound: StringName, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = _players.get(sound)
	if p == null or DisplayServer.get_name() == "headless":
		return
	p.pitch_scale = pitch
	p.play()


## A looping sound (the drill's whine, the welding arc) on or off.
func loop(sound: StringName, on: bool, pitch := 1.0) -> void:
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
	add_child(worker)
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
		&"torque_wrench": TradesTorqueWrench, &"drill": TradesDrill, &"rivet_squeezer": TradesRivetSqueezer,
		&"welder": TradesWeldTorch, &"wire_tool": TradesWireTool, &"tractor": TradesTractorTool,
	}
	for id: StringName in scripts:
		var t: TradesTool = (scripts[id] as GDScript).new()
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

	var cross := ColorRect.new()
	cross.color = TradesLook.HUD
	cross.custom_minimum_size = Vector2(4, 4)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)

	var keys := TradesLook.hud_label(15, TradesLook.HUD_DIM)
	keys.text = _keys_line()
	keys.position = Vector2(40, 36)
	root.add_child(keys)

	var box := VBoxContainer.new()
	box.position = Vector2(40, 80)
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
		label.text = "%d  %s" % [i + 1, String(TOOL_LABELS[hotbar[i]]).to_upper()]
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


func refresh_hud() -> void:
	_refresh_hud()


func _refresh_hud() -> void:
	if _tool_label == null:
		return
	_tool_label.text = "TOOL    %s" % String(TOOL_LABELS[tool]).to_upper()
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
