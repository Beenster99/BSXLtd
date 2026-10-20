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
## The same bench also stands in Ship and Bay's shipyard (in_yard, added by TradesBus at the
## Pre-assembly spot): there it has no room of its own, only a tool board behind it, and it
## waits while you walk the yard. Step up to it and press F and your worker takes over at
## the bench; Esc steps back into the yard.

const BENCH_TOP := 0.9
## The bench runs along X from -BENCH_HALF to BENCH_HALF, its front edge at z = BENCH_FRONT.
const BENCH_HALF := 2.3
const BENCH_FRONT := 0.27
## The hotbar, in order (keys 1..6).
const TOOLS: Array[StringName] = [&"hands", &"torque_wrench", &"drill", &"rivet_squeezer", &"welder", &"wire_tool"]
const TOOL_LABELS := {
	&"hands": "Hands", &"torque_wrench": "Torque wrench", &"drill": "Drill",
	&"rivet_squeezer": "Squeezer", &"welder": "Welder", &"wire_tool": "Crimper",
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

## How far in front of the bench the yard walker can be to step up to it (metres).
const STEP_UP_M := 1.8

## Set before adding to the tree: the bench stands in the shipyard instead of its own bay.
var in_yard := false
## In the yard: you are working at the bench (your worker has the controls and the view).
var active := true
var worker: BenchWorker
var tool: StringName = &"hands"
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
var _prompt: CanvasLayer
var _yard_camera: Camera3D


func _ready() -> void:
	var yard_camera := get_viewport().get_camera_3d()
	if in_yard:
		_build_tool_board()
	else:
		_build_room()
	_build_bench()
	_build_worker()
	_build_tools()
	_build_audio()
	_build_hud()
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
	if in_yard:
		_build_prompt()
		_yard_camera = yard_camera
		leave_bench()
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	var i := TOOLS.find(tool)
	set_tool(TOOLS[posmod(i + step, TOOLS.size())])


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


## In the yard: your worker steps up to the bench where the yard walker stands, and takes
## the controls and the view.
func take_bench() -> void:
	if active:
		return
	_yard_camera = get_viewport().get_camera_3d()
	_yard_walker(false)
	active = true
	worker.process_mode = Node.PROCESS_MODE_INHERIT
	worker.visible = true
	var x := 0.0
	if _yard_camera:
		x = clampf(to_local(_yard_camera.global_position).x, -BENCH_HALF + 0.3, BENCH_HALF - 0.3)
	worker.global_position = to_global(Vector3(x, 0.0, 0.58))
	worker.face(to_global(Vector3(x, BENCH_TOP, 0.0)))
	worker.camera.current = true
	_hud.visible = true
	_prompt.visible = false
	_focus = station_under_aim()
	if _focus:
		hint(_focus.start_hint())
	_refresh_hud()


## In the yard: put down what you hold and step back; the yard walker has the controls again.
func leave_bench() -> void:
	if _pressed:
		_pressed.release()
		_pressed = null
	active = false
	worker.process_mode = Node.PROCESS_MODE_DISABLED
	worker.visible = false
	for id: StringName in tool_nodes:
		(tool_nodes[id] as Node3D).visible = false
	_hud.visible = false
	if is_instance_valid(_yard_camera):
		_yard_camera.current = true
	_yard_walker(true)


## The yard walker is standing in front of the bench (judged by the view it gives).
func yard_walker_near() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam == worker.camera:
		return false
	var p := to_local(cam.global_position)
	return absf(p.x) < BENCH_HALF + 0.3 and p.z > BENCH_FRONT and p.z < BENCH_FRONT + STEP_UP_M


## Ship and Bay's hand-over hook, once it has one: stop (or restart) its walker.
func _yard_walker(on: bool) -> void:
	var bus := Modules.bus("ship_bay")
	if bus and bus.has_method("set_walker_active"):
		bus.call("set_walker_active", get_parent(), on)


## Every station back to its start.
func reset_all() -> void:
	for s in stations:
		s.reset()
	hide_result()


# --- Input ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not in_yard:
		_handle_input(event)


## In the yard the bench sees input before the yard does: all of it while you work here,
## and only F (step up) while you walk the yard in front of it.
func _input(event: InputEvent) -> void:
	if not in_yard:
		return
	if active:
		_handle_input(event)
		get_viewport().set_input_as_handled()
	elif _is_key(event, KEY_F) and yard_walker_near():
		take_bench()
		get_viewport().set_input_as_handled()


static func _is_key(event: InputEvent, k: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == k


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
		_on_key(event.physical_keycode)


func _on_key(k: Key) -> void:
	if k >= KEY_1 and k < KEY_1 + TOOLS.size():
		set_tool(TOOLS[k - KEY_1])
		return
	match k:
		KEY_V:
			worker.set_view(not worker.third_person)
		KEY_Q, KEY_E:
			if _focus and _focus.adjust(1 if k == KEY_E else -1):
				_refresh_hud()
		KEY_R:
			if _focus:
				_focus.reset()
				hide_result()
				hint(_focus.start_hint())
		KEY_ESCAPE:
			if in_yard:
				leave_bench()
				return
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if Router.has_scene("main_menu"):
				Router.goto("main_menu")
		_:
			if _focus and _focus.key(k):
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
	if not active:
		_prompt.visible = yard_walker_near()
		return
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
	if in_yard:
		take_bench()
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
		hand.stretch_m = HAND_STRETCH_M
		hand.snapped.connect(_on_hand_snapped)


func _on_hand_snapped() -> void:
	if _focus:
		_focus.on_hand_snapped()
	hint("Too far: your arm let go.")


func _build_tools() -> void:
	var scripts := {
		&"torque_wrench": TradesTorqueWrench, &"drill": TradesDrill, &"rivet_squeezer": TradesRivetSqueezer,
		&"welder": TradesWeldTorch, &"wire_tool": TradesWireTool,
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


## In the yard: a tool board standing behind the bench where the bay has its wall, so the
## station signs have somewhere to hang: a dark frame on two feet, warm-white panels, a lit
## edge strip and the name board.
func _build_tool_board() -> void:
	var shell := TradesLook.paint(TradesLook.SHELL.darkened(0.25), 0.25, 0.42)
	var dark := TradesLook.paint(TradesLook.DARK, 0.55, 0.5)
	var trim := TradesLook.paint(TradesLook.TRIM, 0.3, 0.45)
	var solid := StaticBody3D.new()
	solid.name = "BoardSolid"
	add_child(solid)
	var width := BENCH_HALF * 2.0 + 0.3
	_solid_box(solid, Vector3(width, 2.8, 0.04), Vector3(0, 1.4, -0.565), dark)
	for side: float in [-1.0, 1.0]:
		_solid_box(solid, Vector3(0.08, 0.04, 0.5), Vector3(side * (width * 0.5 - 0.06), 0.02, -0.4), dark)
	var x := -BENCH_HALF
	while x < BENCH_HALF - 0.1:
		_box(Vector3(0.7, 1.05, 0.02), Vector3(x + 0.375, 1.75, -0.54), shell)
		x += 0.75
	_box(Vector3(width, 0.012, 0.006), Vector3(0, 1.2, -0.528), TradesLook.glow(TradesLook.EDGE, 1.6))
	_box(Vector3(width, 0.04, 0.006), Vector3(0, 0.06, -0.542), trim)
	_name_board("BSX LTD  //  TOOLS", Vector3(0.0, 2.6, -0.525), 1.2, dark, trim)


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
	keys.text = "WASD walk  V view  wheel/1-6 tool  LMB use (hold to carry)  LMB+wheel turn  MMB free/90°  RMB take off  Q/E amps  Tab part  R reset  Esc %s" % ("yard" if in_yard else "menu")
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
	for i in TOOLS.size():
		var slot := PanelContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := TradesLook.hud_label(18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(112, 0)
		label.text = "%d  %s" % [i + 1, String(TOOL_LABELS[TOOLS[i]]).to_upper()]
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


## In the yard: the line that asks you to step up to the bench, shown while you stand at it.
func _build_prompt() -> void:
	_prompt = CanvasLayer.new()
	_prompt.visible = false
	add_child(_prompt)
	var label := TradesLook.hud_label(24)
	label.text = "F  WORK AT THE TOOLS BENCH"
	_prompt.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 140)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _refresh_hud() -> void:
	if _tool_label == null:
		return
	_tool_label.text = "TOOL    %s" % String(TOOL_LABELS[tool]).to_upper()
	if tool == &"hands":
		_tool_label.text += "    TURN %s" % ("90°" if turn_snap else "FREE")
	_status_label.text = _focus.status_line() if _focus else ""
	var useful: Array[StringName] = _focus.tools() if _focus else TOOLS
	for i in _slots.size():
		var on := TOOLS[i] == tool
		_slots[i].add_theme_stylebox_override("panel", TradesLook.slot_style(on))
		var c := TradesLook.HUD if on else TradesLook.HUD_DIM
		if not on and not useful.has(TOOLS[i]):
			c = Color(c, 0.15)
		_slot_labels[i].label_settings.font_color = c
