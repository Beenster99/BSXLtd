extends Node3D
## The orbital yard (master plan Wave 1): the station's rooms with gravity (stage 1.1) and,
## outside, the weightless dock with its berths (stage 1.2, flag "yard.dock"), in deep space.
## Simple shapes first: the look comes in stage 1.5. You are in the Void Salvage suit (YardRig, 1.3).
## Where everything is: YardLayout (api). Rooms are furnished by other modules through
## YardBus (the design room's contents belong to the Design Room module).

const Kit := preload("res://modules/yard/internal/yard_kit.gd")
const SpaceSky := preload("res://modules/yard/internal/space_sky.gd")
const RackingHall := preload("res://modules/yard/internal/racking_hall.gd")
const StoresShell := preload("res://modules/yard/internal/stores_shell.gd")
const StoresTraffic := preload("res://modules/yard/internal/stores_traffic.gd")
const Airlock := preload("res://modules/yard/internal/airlock.gd")
const DesignLock := preload("res://modules/yard/internal/design_lock.gd")
const DesignShell := preload("res://modules/yard/internal/design_shell.gd")
const Dock := preload("res://modules/yard/internal/dock.gd")
const Solar := preload("res://modules/yard/internal/solar_array.gd")
const Quarters := preload("res://modules/yard/internal/quarters.gd")
const YardWorkers := preload("res://modules/yard/internal/yard_workers.gd")
const LivedIn := preload("res://modules/yard/internal/lived_in.gd")
const PracticeFrame := preload("res://modules/yard/internal/tools/yard_practice_frame.gd")
## Where the practice frame floats: just out of the airlock (station space).
const PRACTICE_AT := Vector3(-47.5, -0.6, -2.0)

## Camera views for screenshots and tests: id -> [from, look at] (station space).
const VIEWS := {
	"station_outside": [Vector3(-95, 32, 55), Vector3(4, 1, -12)],
	"corridor": [Vector3(-31, 1.7, -2.0), Vector3(40, 1.4, -2.0)],
	"quarters": [Vector3(21.2, 2.3, 6.0), Vector3(40, 0.9, 4.0)],
	"quarters_cabin": [Vector3(31.3, 1.7, 7.9), Vector3(27.5, 0.8, 11.2)],
	"dock_floods": [Vector3(-48, 22, -60), Vector3(0, -3, -85)],
	"dock_solar": [Vector3(70, 10, -30), Vector3(106, -10, -66)],
	"stores_roof": [Vector3(0, 52, 10), Vector3(48, 32, -36)],
	"sky_galaxy": [Vector3(0, 1.7, -15), Vector3(-35, 42, -84)],
	"workers": [Vector3(-1.0, 4.0, -77.0), Vector3(-12.0, 0.0, -85.0)],
	"crew_lived_in": [Vector3(17.5, 1.8, 10.5), Vector3(4, 1.0, 1.5)],
	"corridor_services": [Vector3(-31, 2.0, -2.0), Vector3(10, 2.8, -1.0)],
	"design_room": [Vector3(9.5, 5.2, -5.5), Vector3(-4, 1.2, -18)],
	"design_vault": [Vector3(7, 1.7, -20.5), Vector3(-3, 7.5, -8)],
	"design_mezzanine": [Vector3(-2, 1.7, -17), Vector3(-6, 3.0, -6)],
	"design_window": [Vector3(0, 1.7, -15), Vector3(0, -3, -80)],
	"design_lock": [Vector3(-3.5, 2.0, -15.5), Vector3(-11, 1.2, -22.5)],
	"design_lock_outside": [Vector3(-4.5, 1.2, -31), Vector3(-11, 1.4, -23.5)],
	"stores_hall": [Vector3(16, 11, -6), Vector3(52, 2, -40)],
	"stores_long": [Vector3(24.8, 1.7, -55), Vector3(24.8, 2.5, -20)],
	"stores_components": [Vector3(42.5, 3.0, -56), Vector3(46, 2.0, -30)],
	"stores_heavy": [Vector3(52, 6.5, -58), Vector3(59, 0.5, -36)],
	"stores_goods_in": [Vector3(64, 6, -60), Vector3(84, 3, -32)],
	"stores_yard_side": [Vector3(36, 14, -96), Vector3(46, 14, -40)],
	"stores_upper": [Vector3(16, 27, -6), Vector3(52, 18, -40)],
	"stores_upper_long": [Vector3(24.8, 17.7, -55), Vector3(24.8, 18.5, -20)],
	"stores_stair": [Vector3(72.0, 2.5, -8.0), Vector3(65.0, 7.0, -24.0)],
	"stores_bot": [Vector3(69.2, 9.5, -53.6), Vector3(71.0, 9.0, -52.0)],
	"stores_ship": [Vector3(58, 34, -112), Vector3(108, 6, -34)],
	"stores_ship_hold": [Vector3(78, 7, -16), Vector3(104, 4, -44)],
	"stores_well": [Vector3(82, 4, -60), Vector3(66, 18, -20)],
	"stores_deliveries": [Vector3(70, 13, -64), Vector3(92, 2, -32)],
	"stores_hauler": [Vector3(90, 10, -66), Vector3(104, 4, -50)],
	"stores_put_away": [Vector3(64, 9, -6), Vector3(48, 3, -40)],
	"stores_to_yard": [Vector3(48, 6, -82), Vector3(30, 4, -58)],
	"contracts": [Vector3(-1.0, 1.7, 0.8), Vector3(-8, 1.0, 8)],
	"crew": [Vector3(1.0, 1.8, 0.8), Vector3(12, 0.8, 11)],
	"airlock": [Vector3(-29, 1.7, -2.0), Vector3(-40, 1.2, -2.0)],
	"dock": [Vector3(-170, 55, 35), Vector3(0, -5, -70)],
	"build_berth": [Vector3(45, 10, -72), Vector3(0, -3, -85)],
	"holding_berths": [Vector3(0, 45, -175), Vector3(0, -3, -80)],
	"station_from_berth": [Vector3(-8, -2, -72), Vector3(4, 3, -18)],
}
## Views of the stores at work: id -> seconds into a contract's deliveries (stage 1.7).
## (0.4.1: the demo brings the freighter first, about 27 s in, open till about 105 s, then
## two haulers about 140 s in.)
const BUSY_VIEWS := {"stores_ship": 50.0, "stores_ship_hold": 62.0, "stores_well": 90.0, "stores_deliveries": 141.0,
		"stores_hauler": 143.5, "stores_put_away": 150.0, "stores_to_yard": 170.0}
## What a demo contract buys (0.4.0 playtest: "when we start a new contract and start to buy
## the parts this should be a busy area"), and what the yard then asks for first.
const DEMO_ORDER := [
	{"part": "HullPlate", "qty": 36}, {"part": "BoxBeam", "qty": 18}, {"part": "DeckPlate", "qty": 20},
	{"part": "Pipe", "qty": 30}, {"part": "Girder", "qty": 16}, {"part": "JunctionBox", "qty": 16},
	{"part": "SwitchCabinet", "qty": 4}, {"part": "BatteryRack", "qty": 2}, {"part": "Generator", "qty": 2},
	{"part": "HydrogenEngine", "qty": 2}, {"part": "FuelTank", "qty": 3}, {"part": "SideThruster", "qty": 4},
	{"part": "Radiator", "qty": 8}, {"part": "ArmourSlab", "qty": 8}, {"part": "FuelValve", "qty": 20},
	{"part": "Gyroscope", "qty": 1}, {"part": "Reactor", "qty": 1},
	# More than the freighter carries: the rest follows by hauler.
	{"part": "HullPlate", "qty": 48}, {"part": "Pipe", "qty": 20}, {"part": "DeckPlate", "qty": 20},
]
const DEMO_TO_YARD := [
	{"part": "BoxBeam", "qty": 12}, {"part": "Girder", "qty": 8}, {"part": "HullPlate", "qty": 24},
	{"part": "HydrogenEngine", "qty": 1}, {"part": "FuelTank", "qty": 2}, {"part": "DeckPlate", "qty": 10},
]

## Views of you in the suit: id -> [your feet, where you face, the camera, lamp on] (station space).
const SUIT_VIEWS := {
	"suit_corridor": [Vector3(-12, 0, -2.0), Vector3(-30, 1.5, -2.0), Vector3(-15.2, 1.6, -2.6), false],
	"suit_back": [Vector3(-12, 0, -2.0), Vector3(-30, 1.5, -2.0), Vector3(-8.6, 2.0, -1.4), false],
	"suit_dock": [Vector3(-52, -1.5, -40), Vector3(-30, -8, -95), Vector3(-49.0, -0.4, -43.2), true],
}
## Screenshot points at the practice frame (stage 1.4): the grinder on a rivet, seen from the
## side, and the same from your own eyes with the hotbar.
const TOOL_VIEWS := ["tools_grinder", "tools_first_person", "tools_tractor", "tools_tractor_close", "tools_tablet",
		"tools_riveter", "tools_welder", "tools_welder_first_person", "tools_weld_bead", "tools_weld_rushed"]
## Friends in the yard (stage 1.6), stood in: id -> [the camera, look at, [name, feet, facing,
## held state] for each] (station space).
const CREW_VIEWS := {
	"crew_corridor": [Vector3(-5.0, 1.7, -2.4), Vector3(-14, 1.0, -2.0), [
		["Dan", Vector3(-8.5, 0, -1.2), Vector3(-2, 1.6, -2.4), {"deck": true, "tool": "grinder"}],
		["Sam", Vector3(-11.5, 0, -3.0), Vector3(-2, 1.6, -2.4), {"deck": true, "tool": "tablet"}]]],
	"crew_dock": [Vector3(-56.5, 0.3, -36.0), Vector3(-47.5, -1.0, -42.0), [
		["Dan", Vector3(-49.5, -0.5, -39.0), Vector3(-47.5, -1.0, -2.0), {"deck": false, "tool": "tractor", "lamp": true}],
		["Sam", Vector3(-52.5, 1.2, -44.0), Vector3(-56.5, 0.3, -36.0), {"deck": false, "tool": "", "lamp": true}]]],
}
## Where you start: the corridor, by the design room's door.
const START := Vector3(4.0, 0.0, -1.5)

var kit: RefCounted
var sky: Node3D
## You: the Void Salvage suit and jet-rig (YardRig). Named "Mover" as the stand-in was.
var mover: YardRig
## Friends in the yard (stage 1.6).
var crew: YardCrew
var view_camera: Camera3D
var racking: Node3D
## Goods in's haulers and the stores' bots.
var traffic: Node3D
var airlock: Node3D
## The design room's own airlock out to the dock.
var design_lock: Node3D
var dock: Node3D
## The practice frame for the hand tools (with the dock).
var practice: Node3D
var design_root: Node3D
var _hint: Label
var _note: Label
var _note_left := 0.0
var _next_kit := 0
var workers: Node3D
var _weld_drive: Dictionary = {}
var _bus: Node


func _ready() -> void:
	name = "Station"
	sky = SpaceSky.new()
	add_child(sky)
	kit = Kit.new(self, "StationBody")
	_build_station()
	if Flags.is_on(YardBus.RACKING):
		racking = RackingHall.new()
		racking.name = "RackingHall"
		add_child(racking)
		racking.call("build", kit, _rack_store())
		traffic = StoresTraffic.new()
		traffic.name = "StoresTraffic"
		add_child(traffic)
		traffic.call("build", _rack_store())
		if Flags.is_on(YardBus.DOCK):
			workers = YardWorkers.new()
			add_child(workers)
			workers.call("build", traffic)
	airlock = Airlock.new()
	airlock.name = "Airlock"
	add_child(airlock)
	airlock.call("build", kit)
	design_lock = DesignLock.new()
	design_lock.name = "DesignLock"
	add_child(design_lock)
	design_lock.call("build", kit)
	if Flags.is_on(YardBus.DOCK):
		dock = Dock.new()
		dock.name = "Dock"
		add_child(dock)
		dock.call("build")
		practice = PracticeFrame.new()
		practice.position = PRACTICE_AT
		practice.rotation.y = PI * 0.5   # its panels face the airlock
		add_child(practice)
	mover = YardRig.new()
	mover.name = "Mover"
	mover.gravity_at = Callable(YardLayout, "has_gravity")
	add_child(mover)
	mover.place(START, Vector3(6.25, 1.5, -10))
	crew = YardCrew.new()
	crew.rig = mover
	add_child(crew)
	view_camera = Camera3D.new()
	view_camera.name = "ViewCamera"
	view_camera.far = 60000.0
	view_camera.fov = 70.0
	add_child(view_camera)
	if YardSounds.enabled():
		add_child(YardSounds.new().setup(self))
	_build_hud()
	_bus = Modules.bus("yard")
	if _bus:
		_bus.call("_station_opened", self)
	var start: String = Router.args.get("view", "")
	if start != "":
		show_view(start)
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	if _bus and is_instance_valid(_bus):
		_bus.call("_station_closed", self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _rack_store() -> YardRackStore:
	var bus := Modules.bus("yard")
	var store: YardRackStore = bus.get("rack_store") if bus else null
	if store == null:
		store = YardRackStore.new()
		store.fill_demo()
		if bus:
			bus.set("rack_store", store)
	return store


func show_view(id: String) -> void:
	if CREW_VIEWS.has(id):
		_show_crew_view(id)
		return
	if id in TOOL_VIEWS:
		_show_tool_view(id)
		return
	if mover.tools:
		mover.tools.trigger_override = -1
		mover.tools.holster(true)
	if SUIT_VIEWS.has(id):
		var s: Array = SUIT_VIEWS[id]
		mover.place(s[0], s[1])
		mover.lamp.visible = s[3]
		view_camera.position = s[2]
		view_camera.look_at(mover.global_position + Vector3(0, 0.1, 0))
		view_camera.current = true
		return
	if not VIEWS.has(id):
		return
	if id in BUSY_VIEWS and traffic:
		_busy_stores(BUSY_VIEWS[id])
	var v: Array = VIEWS[id]
	view_camera.position = v[0]
	view_camera.look_at(v[1])
	view_camera.current = true


## Starts a demo contract: buys its parts, and the yard asks for its first ones (F at the
## contracts desk, and the busy views).
func start_demo_contract() -> void:
	if traffic == null:
		return
	traffic.call("order", DEMO_ORDER)
	traffic.call("send_to_yard", DEMO_TO_YARD)


func _contract_hint() -> String:
	if traffic == null:
		return ""
	if bool(traffic.call("busy")):
		return "Deliveries are coming in to goods in..."
	return "%s  Start a contract: buy its parts" % Keys.prompt(Keys.INTERACT)


## The stores `seconds` into a demo contract (for the busy views), run on in small steps.
func _busy_stores(seconds: float) -> void:
	if not bool(traffic.get_meta("demo_started", false)):
		traffic.set_meta("demo_started", true)
		start_demo_contract()
	var done := float(traffic.get_meta("demo_seconds", 0.0))
	while done < seconds:
		traffic.call("step", 0.05)
		done += 0.05
	traffic.set_meta("demo_seconds", done)


## Runs weld `p` by hand at the welder's steady pace to `share` of its length (the views).
func _lay_weld(fit: YardWorkpiece, p: Dictionary, share: float, pace := 1.0) -> void:
	var welder := mover.tools.get_tool("welder") as YardWelder
	var length := (p.seam_size as Vector2).x
	var dt := 1.0 / 60.0
	var s := 0.0
	while s < length * share and fit.planned.has(p):
		s += welder.ideal_speed * pace * dt
		var at := fit.global_transform * ((p.at as Vector3) + (p.seam_up as Vector3) * (s - length * 0.5))
		fit.weld_along(p, at, dt, welder.ideal_speed, welder.max_speed)


## Two friends stood in, in their suits, and you out of the way.
func _show_crew_view(id: String) -> void:
	var v: Array = CREW_VIEWS[id]
	var colours: Array[Color] = [Color("6fc8e8"), Color("7fd47a")]
	var i := 0
	for f: Array in v[2]:
		crew.show_stand_in(f[0], colours[i % colours.size()], f[1], f[2], f[3])
		i += 1
	mover.place(Vector3(30, 0, -1.5), Vector3(40, 1.5, -1.5))
	view_camera.position = v[0]
	view_camera.look_at(v[1])
	view_camera.current = true


## Floats in front of the riveted panel's first rivet with the grinder running on it; or holds
## the loose bracket with the tractor; or reads the frame on the beam tablet, raised.
func _show_tool_view(id: String) -> void:
	if practice == null:
		return
	var frame := practice.get("frame") as YardWorkpiece
	if id.begins_with("tools_tractor"):
		var bracket := practice.get("bracket") as YardWorkpiece
		var b_at := bracket.global_transform * bracket.center_of_mass
		var away := frame.global_basis.x
		var head_at := b_at + away * 6.0 + Vector3(0, 0.6, 0)
		mover.place(head_at - Vector3(0, YardRig.FEET + YardRig.EYE, 0), b_at)
		mover.lamp.visible = true
		mover.tools.select_tool(4)
		mover.tools.trigger_override = 1
		var across := away.cross(Vector3.UP).normalized()
		if id == "tools_tractor_close":
			# In front of the suit and off to its right, looking back at the tool in its hand.
			var aim := (b_at - head_at).normalized()
			var right := aim.cross(Vector3.UP).normalized()
			view_camera.position = to_local(head_at + aim * 0.95 + right * 0.55 - Vector3(0, 0.2, 0))
			view_camera.look_at(head_at + aim * 0.45 + right * 0.28 - Vector3(0, 0.35, 0))
		else:
			view_camera.position = to_local(head_at + across * 3.2 + away * 1.5 + Vector3(0, 0.8, 0))
			view_camera.look_at(head_at.lerp(b_at, 0.45))
		view_camera.current = true
		return
	if id in ["tools_riveter", "tools_welder", "tools_welder_first_person", "tools_weld_bead", "tools_weld_rushed"]:
		# The fitting frame (built afresh for each view): a rivet or a weld half in, the tool on it.
		_weld_drive = {}
		practice.call("rebuild")
		var fit := practice.get("fit") as YardWorkpiece
		var kind := ConnectionData.Kind.RIVET if id == "tools_riveter" else ConnectionData.Kind.WELD
		var plan: Dictionary = {}
		for p: Dictionary in fit.planned:
			if int(p.kind) == kind:
				plan = p
				break
		if plan.is_empty():
			return
		if kind == ConnectionData.Kind.WELD:
			# One weld run neat to the end, the next half run, steady, the gun on it.
			var other: Dictionary = {}
			for p: Dictionary in fit.planned:
				if int(p.kind) == kind and p != plan:
					other = p
			if not other.is_empty():
				_lay_weld(fit, other, 1.0)
			if id in ["tools_weld_bead", "tools_weld_rushed"]:
				# Close up: the neat bead beside one rushed at three and a half times the pace.
				_lay_weld(fit, plan, 1.0, 2.6)
				mover.tools.holster(true)
				var a := fit.global_transform * (other.at as Vector3)
				var b := fit.global_transform * (plan.at as Vector3)
				var n := fit.planned_normal(plan)
				# Up close on one, a little off to the side so the ripples stand out.
				var on := a if id == "tools_weld_bead" else b
				var out := (a - b).normalized() * (1.0 if id == "tools_weld_bead" else -1.0)
				view_camera.position = to_local(on + n * 0.17 + out * 0.12 + Vector3(0, 0.06, 0))
				view_camera.look_at(on)
				view_camera.current = true
				return
			_lay_weld(fit, plan, 0.3)
			_weld_drive = {"fit": fit, "plan": plan}
		else:
			(mover.tools.get_tool("riveter") as YardRiveter).charge_seconds = 60.0
			(mover.tools.get_tool("riveter") as YardRiveter).pressure = 0.7
		var at := fit.planned_position(plan)
		var normal := fit.planned_normal(plan)
		var head := at + normal * 0.9 + Vector3(0, 0.15, 0)
		mover.place(head - Vector3(0, YardRig.FEET + YardRig.EYE, 0), at)
		mover.lamp.visible = false   # the arc lights it

		mover.tools.select_tool(6 if kind == ConnectionData.Kind.RIVET else 7)
		mover.tools.trigger_override = 1
		if id == "tools_welder_first_person":
			mover.camera.current = true
			return
		var side := normal.cross(Vector3.UP).normalized()
		view_camera.position = to_local(head - side * 1.5 + Vector3(0, 0.45, 0) - normal * 0.1)
		view_camera.look_at(at.lerp(head, 0.4))
		view_camera.current = true
		return
	if id == "tools_tablet":
		var f_at := frame.global_transform * Vector3(0.0, 1.3, 0.08)
		mover.place(f_at + frame.global_basis.z * 2.2 - Vector3(0, YardRig.FEET + YardRig.EYE, 0), f_at)
		mover.lamp.visible = true
		mover.tools.select_tool(5)
		(mover.tools.active_tool() as YardTablet).up = true
		mover.camera.current = true
		return
	var rivet: ConnectionData = null
	for c: ConnectionData in frame.model.connections:
		if c.kind == ConnectionData.Kind.RIVET:
			rivet = c
			break
	if rivet == null:
		return
	var at := frame.joint_position(rivet)
	var normal := frame.joint_normal(rivet)
	var head := at + normal * 0.9
	mover.place(head - Vector3(0, YardRig.FEET + YardRig.EYE, 0), at)
	mover.lamp.visible = true
	mover.tools.select_tool(0)
	mover.tools.trigger_override = 1
	if id == "tools_first_person":
		mover.camera.current = true
		return
	var side := normal.cross(Vector3.UP).normalized()
	view_camera.position = to_local(head + side * 1.6 + Vector3(0, 0.5, 0) - normal * 0.2)
	view_camera.look_at(at.lerp(head, 0.45))
	view_camera.current = true


## A weld view's hand: the aim carried on along the seam at the welder's steady pace.
func _physics_process(_delta: float) -> void:
	if _weld_drive.is_empty():
		return
	var fit := _weld_drive.fit as YardWorkpiece
	var p: Dictionary = _weld_drive.plan
	if not is_instance_valid(fit) or not fit.planned.has(p):
		_weld_drive = {}
		return
	var length := (p.seam_size as Vector2).x
	var welder := mover.tools.get_tool("welder") as YardWelder
	_weld_drive.s = float(_weld_drive.get("s", float(p.get("front", 0.0)))) + float(p.get("dir", 1.0)) * welder.ideal_speed * _delta
	var front := minf(float(_weld_drive.s), length * 0.97)
	var at := fit.global_transform * ((p.at as Vector3) + (p.seam_up as Vector3) * (clampf(front, 0.0, length) - length * 0.5))
	var head := at + fit.planned_normal(p) * 0.9 + Vector3(0, 0.15, 0)
	mover.place(head - Vector3(0, YardRig.FEET + YardRig.EYE, 0), at)


func _process(delta: float) -> void:
	if _note and _note_left > 0.0:
		_note_left -= delta
		_note.visible = _note_left > 0.0
	if _hint and mover:
		var h: String = mover.call("hint")
		_hint.text = h
		_hint.visible = h != "" and not view_camera.current


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			mover.call("look", event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if HudSlots.pointer_claimed():
			return
		_walk_again()
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			Menu.open_pause()
			return
		_walk_again()
		if event.is_action_pressed(Keys.INTERACT) and not HudSlots.pointer_claimed():
			mover.call("use")
		elif event.is_action_pressed("yard.kit"):
			call_kit()


## Calls a mover bot with the next kit (YardKits, in turn) to wherever you are; says so on
## the HUD. Returns the kit's id ("" without the stores).
func call_kit() -> String:
	if traffic == null:
		return ""
	var ids := YardKits.ids()
	var kit: String = ids[_next_kit % ids.size()]
	_next_kit += 1
	var id := int(traffic.call("deliver_kit", kit, mover))
	if _note:
		_note.text = "Mover bot on its way with a %s" % YardKits.display_name(kit).to_lower() if id >= 0 else "No stock for a %s" % YardKits.display_name(kit).to_lower()
		_note_left = 4.0
		_note.visible = true
	return kit


func _walk_again() -> void:
	if view_camera.current:
		mover.camera.current = true


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	add_child(layer)
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.7)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position -= Vector2(2, 2)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dot)
	_note = Label.new()
	_note.name = "KitNote"
	_note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_note.offset_top = 60
	_note.offset_bottom = 100
	_note.offset_left = -300
	_note.offset_right = 300
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 20)
	_note.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	_note.add_theme_color_override("font_outline_color", Color.BLACK)
	_note.add_theme_constant_override("outline_size", 6)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.visible = false
	layer.add_child(_note)
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -120
	_hint.offset_bottom = -80
	_hint.offset_left = -300
	_hint.offset_right = 300
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hint)


# --- The station's rooms (stage 1.1) -------------------------------------------------------

func _build_station() -> void:
	var k = kit
	# Void Salvage's finishes (stage 1.5): gloss white hull, satin walls, steel tread decks.
	var hull: Material = k.paint(Kit.HULL, 0.15, 0.4, "gloss_paint")
	var wall: Material = k.paint(Kit.WALL, 0.1, 0.6, "satin_paint")
	var deck: Material = k.paint(Color(0.5, 0.52, 0.55), 0.2, 0.55, "tread_diamond_paint")
	var dark: Material = k.paint(Kit.DARK, 0.7, 0.45, "gunmetal")
	var orange: Material = k.paint(Kit.ORANGE, 0.1, 0.4, "enamel")
	var ceiling: Material = k.paint(Color(0.84, 0.86, 0.88), 0.05, 0.7, "plastic_textured")
	var pane: Material = k.glass()

	# Floors and ceilings, room by room (floor top at y = 0, 0.3 m thick), each room tagged so
	# the graphics module lights it with bounce light and a reflection probe.
	for id: String in YardLayout.ROOMS:
		var b: AABB = YardLayout.ROOMS[id].box
		var floor_mat: Material = k.paint(Color(0.34, 0.38, 0.44), 0.0, 0.5, "plastic_textured") if id == "design" else deck
		k.slab(Vector3(b.position.x, -0.3, b.position.z), Vector3(b.end.x, 0.0, b.end.z), floor_mat)
		if id != "design":   # the design room's roof is its glass vault (DesignShell)
			# (the quarters' roof a millimetre up where it meets the crew room's)
			var lift := 0.001 if id == "quarters" else 0.0
			k.span(Vector3(b.position.x - 0.095, b.end.y + lift, b.position.z - 0.095), Vector3(b.end.x + 0.095, b.end.y + 0.3 + lift, b.end.z + 0.095), hull)
			k.slab(Vector3(b.position.x, b.end.y - 0.02, b.position.z), Vector3(b.end.x, b.end.y, b.end.z), ceiling, 6.0, false)
		var room := Node3D.new()
		room.name = "Room_%s" % id
		room.add_to_group("gfx_room")
		room.set_meta("gfx_box", AABB(Vector3(b.position.x, 0.0, b.position.z), Vector3(b.size.x, b.end.y, b.size.z)))
		add_child(room)
		# The light the room's pale walls and ceiling throw back: a soft, broad fill with no
		# highlight of its own (the graphics module's bounce light adds to it where it runs).
		# Split into cells about 12 m across, so no floor tile carries more lights than the
		# compatibility renderer draws on one mesh (8).
		var nx := maxi(1, ceili(b.size.x / 12.0))
		var nz := maxi(1, ceili(b.size.z / 12.0))
		var cell := Vector2(b.size.x / nx, b.size.z / nz)
		# A tall room with a deck in it (the stores' two storeys) gets a layer a storey.
		var storeys := maxi(1, ceili(b.end.y / 17.0))
		var storey_h := b.end.y / storeys
		for ix in nx:
			for iz in nz:
				for iy in storeys:
					var bounce := OmniLight3D.new()
					bounce.name = "Bounce_%d_%d" % [ix, iz] if iy == 0 else "Bounce_%d_%d_%d" % [ix, iz, iy]
					bounce.position = Vector3(b.position.x + cell.x * (ix + 0.5), storey_h * (iy + 0.55), b.position.z + cell.y * (iz + 0.5))
					bounce.omni_range = cell.length() * 0.6 + storey_h * 0.6
					bounce.omni_attenuation = 0.35
					bounce.light_energy = 0.32
					bounce.light_specular = 0.0
					bounce.light_color = Color(0.92, 0.95, 1.0)
					room.add_child(bounce)

	# Design room (x -12..12, z -22..-4, walls 6 m high under a glass vault): the window wall
	# faces the dock.
	var lock_x := YardLayout.DESIGN_LOCK_DOOR_X
	k.wall(true, -22.0, -12.1, 12.1, 0.0, 6.0, wall, [[lock_x.x, lock_x.y, YardLayout.DESIGN_LOCK_DOOR_H], [-10.0, 10.0, 5.2, 0.9]], 0.2, pane)
	for x: float in [-5.0, 0.0, 5.0]:
		k.box(Vector3(0.12, 4.3, 0.16), Vector3(x, 3.05, -22.0), dark)
	k.wall(false, -12.0, -22.0, -4.0, 0.0, 6.0, wall)
	k.wall(false, 12.0, -22.0, -4.0, 0.0, 6.0, wall)
	k.wall(true, -4.0, -12.1, 12.1, 0.0, 6.0, wall, [[5.0, 7.5, 2.6]])
	design_root = Node3D.new()
	design_root.name = "DesignRoomRoot"
	design_root.position = YardBus.DESIGN_ROOM_CENTRE
	add_child(design_root)
	_mark_clear_circle(k)
	DesignShell.new().build(k, hull, wall, dark, deck)
	# Between the design room and the racking hall: solid hull.
	k.span(Vector3(12.1, 0.0, -22.0), Vector3(13.9, 6.0, -4.1), hull)

	# Corridor (x -34..46, z -4..0): the rooms' doors open off it.
	k.wall(true, -4.0, -34.0, -12.1, 0.0, 3.2, wall)
	k.wall(true, -4.0, 12.1, 14.0, 0.0, 3.2, wall)
	k.wall(true, 0.0, -34.0, 46.0, 0.0, 3.2, wall, [[-7.0, -5.0, 2.4], [9.0, 11.0, 2.4], [31.0, 33.0, 2.4]])
	k.wall(false, 46.0, -4.0, 0.0, 0.0, 3.2, wall)
	for x in range(-30, 46, 6):
		if x != 18:   # the one at x 18 flickers (LivedIn)
			k.ceiling_lamp(Vector3(x, 3.2, -2.0), Vector2(1.6, 0.4), 0.7, 6.0)
	for z: float in [-3.85, -0.15]:
		k.span(Vector3(-34.0, 0.0, z - 0.04), Vector3(46.0, 0.012, z + 0.04), orange, false)
	# Along both walls: a dark skirting, a lower wall in darker satin with an orange line along
	# its top, and a cove light strip under the ceiling (stage 1.5).
	var lower: Material = k.paint(Color(0.46, 0.5, 0.56), 0.15, 0.55, "satin_paint")
	var strip: Material = k.glow(Color(0.75, 0.9, 1.0), 1.6)
	var north_gaps := [[5.0, 7.5, 2.6], [28.0, 32.0, 3.0]]
	var south_gaps := [[-7.0, -5.0, 2.4], [9.0, 11.0, 2.4]]
	for side: Array in [[-4.0, 0.11, north_gaps], [0.0, -0.11, south_gaps]]:
		var at: float = side[0]
		var out: float = side[1]
		k.trim(true, at, -34.0, 46.0, 0.0, 0.12, out, dark, side[2])
		k.trim(true, at, -34.0, 46.0, 0.12, 0.98, out * 0.95, lower, side[2])
		k.trim(true, at, -34.0, 46.0, 1.1, 0.05, out * 1.1, orange, side[2])
		k.trim(true, at, -34.0, 46.0, 3.02, 0.04, out * 1.1, strip, side[2])
	_door_frame(k, true, -4.0, 5.0, 7.5, 2.6, orange)
	_door_frame(k, true, -4.0, 28.0, 32.0, 3.0, orange)
	_door_frame(k, true, 0.0, -7.0, -5.0, 2.4, orange)
	_door_frame(k, true, 0.0, 9.0, 11.0, 2.4, orange)
	_door_frame(k, true, 0.0, 31.0, 33.0, 2.4, orange)
	k.sign("DESIGN ROOM", Vector3(6.25, 2.85, -3.9), Vector3.BACK, 0.006)
	k.sign("STORES  ·  GOODS IN", Vector3(30.0, 3.05, -3.9), Vector3.BACK, 0.006)
	k.sign("CONTRACTS", Vector3(-6.0, 2.75, -0.1), Vector3.FORWARD, 0.006)
	k.sign("CREW", Vector3(10.0, 2.75, -0.1), Vector3.FORWARD, 0.006)
	k.sign("QUARTERS", Vector3(32.0, 2.75, -0.1), Vector3.FORWARD, 0.006)
	k.sign("AIRLOCK  ·  DOCK", Vector3(-33.9, 2.75, -2.0), Vector3.RIGHT, 0.006)

	# The stores hall's shell (x 14..84, z -64..-4, 16 m high, open to the yard); its racks
	# are RackingHall's.
	StoresShell.new().build(k, hull, wall, dark, orange)

	# Contracts desk (x -12..0, z 0..10).
	k.wall(false, -12.0, 0.0, 10.0, 0.0, 3.2, wall)
	k.wall(false, 0.0, 0.0, 12.0, 0.0, 3.2, wall)
	k.wall(true, 10.0, -12.1, 0.0, 0.0, 3.2, wall, [[-10.0, -2.0, 2.6, 0.9]], 0.2, pane)
	_furnish_contracts(k)

	# Crew room (x 0..20, z 0..12).
	k.wall(false, 20.0, 0.0, 12.0, 0.0, 3.2, wall, [[5.2, 6.8, 2.4]])
	k.wall(true, 12.0, -0.1, 20.1, 0.0, 3.2, wall, [[2.0, 18.0, 2.7, 0.8]], 0.2, pane)
	_furnish_crew(k)

	# Sleeping quarters (x 20..44, z 0..12): eight cabins off a soft-lit aisle.
	k.wall(false, 44.0, 0.0, 12.1, 0.0, 3.17, wall)
	k.wall(true, 12.0, 20.1, 43.9, 0.0, 3.17, wall, [[22.6, 23.6, 2.2, 1.2], [28.6, 29.6, 2.2, 1.2], [34.6, 35.6, 2.2, 1.2], [40.6, 41.6, 2.2, 1.2]], 0.2, pane)
	Quarters.new().build(k, self)

	# What makes it lived in: service runs, steam, mugs, plants, wear, drips and dust.
	LivedIn.new().build(k, self)

	# Outside: the hull's colours and a name the dock can read.
	for x: float in [-30.0, 4.0]:
		k.box(Vector3(0.25, 7.0, 0.25), Vector3(x, 7.0, -2.0), dark, false)
		k.box(Vector3(0.35, 0.35, 0.35), Vector3(x, 10.6, -2.0), k.glow(Color(1.0, 0.25, 0.2), 6.0), false)
	# Solar wings and radiators on the roofs.
	for side: float in [-1.0, 1.0]:
		var wing_z := -2.0 + side * 9.0
		Solar.build(self, "SolarWing%d" % int(side), Vector3(-24.0, 6.7, wing_z), Basis(), 9, 2)
	# The stores' roof: six arrays on low frames, tipped to the sun.
	if Flags.is_on(YardBus.RACKING):
		var roof := YardLayout.ROOMS["racking"].box as AABB
		var tilt := Basis(Vector3.BACK, -0.35)
		for x: float in [26.0, 46.0, 66.0]:
			for z: float in [-51.0, -21.0]:
				var at := Vector3(x, roof.end.y + 1.6, z)
				Solar.build(self, "StoresSolar_%d_%d" % [int(x), int(-z)], at, tilt, 10, 6)
				for lx: float in [-6.0, 6.0]:
					for lz: float in [-8.0, 8.0]:
						var leg := at + tilt * Vector3(lx, 0, lz)
						var h := leg.y - roof.end.y - 0.3
						k.box(Vector3(0.16, h, 0.16), Vector3(leg.x, roof.end.y + 0.3 + h * 0.5, leg.z), dark, false)
	k.box(Vector3(0.3, 3.2, 0.3), Vector3(-24.0, 4.8, -2.0), dark, false)
	k.box(Vector3(0.2, 0.2, 24.0), Vector3(-24.0, 6.4, -2.0), dark, false)
	for i in 4:
		k.box(Vector3(5.0, 2.4, 0.06), Vector3(24.0 + i * 12.0, 17.6, -34.0), k.paint(Kit.HULL, 0.2, 0.4), false)
		k.box(Vector3(0.2, 1.4, 0.2), Vector3(24.0 + i * 12.0, 17.0, -34.0), dark, false)
	# Running lights on the corners.
	for p: Vector3 in [Vector3(-40.2, 3.4, -5.2), Vector3(46.2, 3.4, 12.2), Vector3(-12.2, 6.3, -22.2)]:
		k.box(Vector3(0.3, 0.3, 0.3), p, k.glow(Color(1.0, 0.25, 0.2), 6.0), false)


## The holotable's rectangle in the design room's middle, drawn on the floor (nothing stands in it).
func _mark_clear_circle(k) -> void:
	var mark := Node3D.new()
	mark.name = "HoloCircle"
	design_root.add_child(mark)
	var size := YardBus.DESIGN_CLEAR_SIZE
	var line := 0.12
	var mat: Material = k.glow(Kit.ORANGE, 1.2)
	for side: float in [-1.0, 1.0]:
		for along_x: bool in [true, false]:
			var bar := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(size.x + line, 0.004, line) if along_x else Vector3(line, 0.004, size.y - line)
			bar.mesh = bm
			bar.position = Vector3(0, 0.002, side * size.y * 0.5) if along_x else Vector3(side * size.x * 0.5, 0.002, 0)
			bar.material_override = mat
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mark.add_child(bar)


func _door_frame(k, along_x: bool, at: float, a: float, b: float, h: float, mat: Material) -> void:
	if along_x:
		for x: float in [a, b]:
			k.box(Vector3(0.12, h - 0.06, 0.3), Vector3(x, (h - 0.06) * 0.5, at), mat, false)
		# The head sits on the jambs, a touch deeper, so no face of one lies flush on the other's.
		k.box(Vector3(b - a + 0.12, 0.12, 0.304), Vector3((a + b) * 0.5, h, at), mat, false)


func _furnish_contracts(k) -> void:
	var desk: Material = k.paint(Color(0.85, 0.86, 0.88), 0.1, 0.5)
	var dark: Material = k.paint(Kit.DARK, 0.3, 0.5)
	var seat: Material = k.paint(Color(0.2, 0.3, 0.45), 0.0, 0.8)
	# The desk: a long counter facing the door, a screen on it, two chairs behind.
	k.span(Vector3(-10.0, 0.0, 5.0), Vector3(-4.0, 1.05, 5.8), desk)
	k.span(Vector3(-10.05, 1.05, 4.95), Vector3(-3.95, 1.1, 5.85), k.paint(Kit.ORANGE, 0.1, 0.45), false)
	for x: float in [-8.5, -5.5]:
		k.box(Vector3(0.9, 0.55, 0.05), Vector3(x, 1.45, 5.55), k.glow(Color(0.2, 0.55, 0.9), 1.5), false)
		k.box(Vector3(0.6, 0.5, 0.6), Vector3(x, 0.25, 7.0), seat)
		k.box(Vector3(0.6, 0.7, 0.1), Vector3(x, 0.85, 7.35), seat)
	# F at the desk starts a demo contract: its parts are bought and delivered to goods in.
	var area := Area3D.new()
	area.name = "Use_contract"
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.2, 0.8, 1.0)
	cs.shape = shape
	area.add_child(cs)
	area.position = Vector3(-7.0, 1.45, 5.4)
	area.set_meta("yard_use", start_demo_contract)
	area.set_meta("yard_hint", _contract_hint)
	area.add_to_group("gfx_interactable")
	area.set_meta("gfx_id", "contracts_desk")
	add_child(area)
	# The contracts board on the wall by the door, and two visitors' chairs.
	k.box(Vector3(0.06, 1.6, 3.2), Vector3(-11.85, 1.7, 3.0), dark, false)
	k.box(Vector3(0.02, 1.4, 3.0), Vector3(-11.8, 1.7, 3.0), k.glow(Color(0.15, 0.35, 0.6), 1.2), false)
	k.sign("CONTRACTS", Vector3(-11.79, 2.2, 3.0), Vector3.RIGHT, 0.006, Color.WHITE)
	for x: float in [-8.0, -6.0]:
		k.box(Vector3(0.6, 0.45, 0.6), Vector3(x, 0.225, 3.4), seat)
	k.ceiling_lamp(Vector3(-6.0, 3.2, 3.0), Vector2(2.0, 0.6), 0.9, 8.0)
	k.ceiling_lamp(Vector3(-6.0, 3.2, 7.5), Vector2(2.0, 0.6), 0.9, 8.0)


func _furnish_crew(k) -> void:
	var table: Material = k.paint(Color(0.78, 0.74, 0.68), 0.0, 0.6)
	var bench: Material = k.paint(Color(0.3, 0.32, 0.36), 0.3, 0.6)
	var sofa: Material = k.paint(Color(0.75, 0.38, 0.12), 0.0, 0.85)
	var locker: Material = k.paint(Color(0.35, 0.45, 0.55), 0.4, 0.5)
	# Two mess tables with benches.
	for z: float in [3.5, 7.0]:
		k.box(Vector3(3.0, 0.06, 1.0), Vector3(6.0, 0.75, z), table)
		k.box(Vector3(0.1, 0.72, 0.6), Vector3(6.0, 0.36, z), bench)
		for dz: float in [-0.85, 0.85]:
			k.box(Vector3(3.0, 0.45, 0.35), Vector3(6.0, 0.225, z + dz), bench)
	# A sofa facing the window onto the dock and the galaxy beyond.
	k.box(Vector3(4.0, 0.45, 0.9), Vector3(13.0, 0.225, 8.8), sofa)
	k.box(Vector3(4.0, 0.5, 0.25), Vector3(13.0, 0.7, 8.3), sofa)
	# Lockers along the east wall.
	for i in 6:
		k.box(Vector3(0.5, 2.0, 0.55), Vector3(19.65, 1.0, 1.0 + i * 0.6), locker)
	# The kitchen counter and the coffee machine everyone gathers round.
	k.span(Vector3(1.0, 0.0, 0.2), Vector3(4.5, 0.95, 0.85), bench)
	k.box(Vector3(0.45, 0.6, 0.4), Vector3(3.8, 1.25, 0.55), k.paint(Kit.DARK, 0.6, 0.35))
	k.box(Vector3(0.12, 0.05, 0.02), Vector3(3.8, 1.4, 0.76), k.glow(Color(0.3, 1.0, 0.5), 3.0), false)
	k.sign("COFFEE", Vector3(3.8, 1.65, 0.751), Vector3.BACK, 0.0035, Color.WHITE)
	k.ceiling_lamp(Vector3(6.0, 3.2, 5.0), Vector2(2.0, 0.6), 0.9, 9.0)
	k.ceiling_lamp(Vector3(14.0, 3.2, 5.0), Vector2(2.0, 0.6), 0.9, 9.0)
	var warm := OmniLight3D.new()
	warm.position = Vector3(13.0, 1.6, 10.5)
	warm.light_color = Color(1.0, 0.75, 0.5)
	warm.light_energy = 0.6
	warm.omni_range = 6.0
	add_child(warm)
