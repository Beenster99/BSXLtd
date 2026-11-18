extends Node3D
## The orbital yard (master plan Wave 1): the station's rooms with gravity (stage 1.1) and,
## outside, the weightless dock with its berths (stage 1.2, flag "yard.dock"), over a planet.
## Simple shapes first: the look comes in stage 1.5, the Void Salvage avatar in 1.3.
## Where everything is: YardLayout (api). Rooms are furnished by other modules through
## YardBus (the design room's contents belong to the Design Room module).

const Kit := preload("res://modules/yard/internal/yard_kit.gd")
const SpaceSky := preload("res://modules/yard/internal/space_sky.gd")
const Mover := preload("res://modules/yard/internal/yard_mover.gd")
const RackingHall := preload("res://modules/yard/internal/racking_hall.gd")
const Airlock := preload("res://modules/yard/internal/airlock.gd")
const Dock := preload("res://modules/yard/internal/dock.gd")

## Camera views for screenshots and tests: id -> [from, look at] (station space).
const VIEWS := {
	"station_outside": [Vector3(-95, 32, 55), Vector3(4, 1, -12)],
	"corridor": [Vector3(-31, 1.7, -2.0), Vector3(40, 1.4, -2.0)],
	"design_room": [Vector3(10.5, 2.4, -5.0), Vector3(-5, 1.0, -18)],
	"design_window": [Vector3(0, 1.7, -15), Vector3(0, -3, -80)],
	"racking_front": [Vector3(31, 2.0, -4.6), Vector3(24, 3.5, -20)],
	"racking_aisle": [Vector3(25.5, 5.5, -10.4), Vector3(25.5, 4.0, -29)],
	"contracts": [Vector3(-1.0, 1.7, 0.8), Vector3(-8, 1.0, 8)],
	"crew": [Vector3(1.0, 1.8, 0.8), Vector3(12, 0.8, 11)],
	"airlock": [Vector3(-29, 1.7, -2.0), Vector3(-40, 1.2, -2.0)],
	"dock": [Vector3(-170, 55, 35), Vector3(0, -5, -70)],
	"build_berth": [Vector3(58, 12, -45), Vector3(0, -3, -85)],
	"holding_berths": [Vector3(0, 45, -175), Vector3(0, -3, -80)],
	"station_from_berth": [Vector3(-8, -2, -72), Vector3(4, 3, -18)],
}
## Where you start: the corridor, by the design room's door.
const START := Vector3(4.0, 0.0, -1.5)

var kit: RefCounted
var sky: Node3D
var mover: CharacterBody3D
var view_camera: Camera3D
var racking: Node3D
var airlock: Node3D
var dock: Node3D
var design_root: Node3D
var _hint: Label
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
	airlock = Airlock.new()
	airlock.name = "Airlock"
	add_child(airlock)
	airlock.call("build", kit)
	if Flags.is_on(YardBus.DOCK):
		dock = Dock.new()
		dock.name = "Dock"
		add_child(dock)
		dock.call("build")
	mover = Mover.new()
	mover.name = "Mover"
	mover.set("gravity_at", Callable(YardLayout, "has_gravity"))
	add_child(mover)
	mover.call("place", START, Vector3(6.25, 1.5, -10))
	view_camera = Camera3D.new()
	view_camera.name = "ViewCamera"
	view_camera.far = 60000.0
	view_camera.fov = 70.0
	add_child(view_camera)
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
	if not VIEWS.has(id):
		return
	var v: Array = VIEWS[id]
	view_camera.position = v[0]
	view_camera.look_at(v[1])
	view_camera.current = true


func _process(_delta: float) -> void:
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


func _walk_again() -> void:
	if view_camera.current:
		(mover.get("camera") as Camera3D).current = true


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
	var hull: Material = k.paint(Kit.HULL, 0.15, 0.55)
	var wall: Material = k.paint(Kit.WALL, 0.1, 0.7)
	var deck: Material = k.paint(Kit.DECK, 0.0, 0.8)
	var dark: Material = k.paint(Kit.DARK, 0.4, 0.5)
	var orange: Material = k.paint(Kit.ORANGE, 0.1, 0.45)
	var pane: Material = k.glass()

	# Floors and ceilings, room by room (floor top at y = 0, 0.3 m thick).
	for id: String in YardLayout.ROOMS:
		var b: AABB = YardLayout.ROOMS[id].box
		var floor_mat: Material = k.paint(Color(0.28, 0.3, 0.35), 0.0, 0.7) if id == "design" else deck
		k.span(Vector3(b.position.x, -0.3, b.position.z), Vector3(b.end.x, 0.0, b.end.z), floor_mat)
		k.span(Vector3(b.position.x - 0.1, b.end.y, b.position.z - 0.1), Vector3(b.end.x + 0.1, b.end.y + 0.3, b.end.z + 0.1), hull)

	# Design room (x -12..12, z -22..-4, 6 m high): the window wall faces the dock.
	k.wall(true, -22.0, -12.1, 12.1, 0.0, 6.0, wall, [[-10.0, 10.0, 5.2, 0.9]], 0.2, pane)
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
	for x: float in [-7.0, 0.0, 7.0]:
		for z: float in [-18.0, -9.0]:
			k.ceiling_lamp(Vector3(x, 6.0, z), Vector2(3.0, 1.2), 1.3, 12.0)
	# Between the design room and the racking hall: solid hull.
	k.span(Vector3(12.1, 0.0, -22.0), Vector3(13.9, 6.0, -4.1), hull)

	# Corridor (x -34..46, z -4..0): the rooms' doors open off it.
	k.wall(true, -4.0, -34.0, -12.1, 0.0, 3.2, wall)
	k.wall(true, -4.0, 12.1, 14.0, 0.0, 3.2, wall)
	k.wall(true, 0.0, -34.0, 46.0, 0.0, 3.2, wall, [[-7.0, -5.0, 2.4], [9.0, 11.0, 2.4]])
	k.wall(false, 46.0, -4.0, 0.0, 0.0, 3.2, wall)
	for x in range(-30, 46, 6):
		k.ceiling_lamp(Vector3(x, 3.2, -2.0), Vector2(1.6, 0.4), 0.7, 6.0)
	for z: float in [-3.85, -0.15]:
		k.span(Vector3(-34.0, 0.0, z - 0.04), Vector3(46.0, 0.012, z + 0.04), orange, false)
	_door_frame(k, true, -4.0, 5.0, 7.5, 2.6, orange)
	_door_frame(k, true, -4.0, 28.0, 32.0, 3.0, orange)
	_door_frame(k, true, 0.0, -7.0, -5.0, 2.4, orange)
	_door_frame(k, true, 0.0, 9.0, 11.0, 2.4, orange)
	k.sign("DESIGN ROOM", Vector3(6.25, 2.85, -3.9), Vector3.BACK, 0.006)
	k.sign("RACKING HALL  ·  STOCK", Vector3(30.0, 3.05, -3.9), Vector3.BACK, 0.006)
	k.sign("CONTRACTS", Vector3(-6.0, 2.75, -0.1), Vector3.FORWARD, 0.006)
	k.sign("CREW", Vector3(10.0, 2.75, -0.1), Vector3.FORWARD, 0.006)
	k.sign("AIRLOCK  ·  DOCK", Vector3(-33.9, 2.75, -2.0), Vector3.RIGHT, 0.006)

	# Racking hall's shell (x 14..46, z -30..-4, 12 m high); its racks are RackingHall's.
	k.wall(true, -4.0, 14.0, 46.0, 0.0, 12.0, wall, [[28.0, 32.0, 3.0]])
	k.wall(true, -30.0, 13.9, 46.1, 0.0, 12.0, wall)
	k.wall(false, 14.0, -30.0, -4.0, 0.0, 12.0, wall)
	k.wall(false, 46.0, -30.0, -4.0, 0.0, 12.0, wall)
	for x: float in [20.0, 30.0, 40.0]:
		for z: float in [-26.0, -17.0, -8.0]:
			k.ceiling_lamp(Vector3(x, 12.0, z), Vector2(2.0, 0.6), 1.6, 16.0)
	# The cargo shutter to the dock (stage 7 brings deliveries through it).
	k.box(Vector3(12.0, 8.0, 0.1), Vector3(30.0, 4.0, -29.85), k.paint(Kit.STEEL, 0.5, 0.45), false)
	for i in 7:
		k.box(Vector3(12.0, 0.08, 0.04), Vector3(30.0, 0.6 + i * 1.15, -29.78), dark, false)
	k.box(Vector3(12.0, 8.0, 0.1), Vector3(30.0, 4.0, -30.15), k.paint(Kit.STEEL, 0.5, 0.45), false)

	# Contracts desk (x -12..0, z 0..10).
	k.wall(false, -12.0, 0.0, 10.0, 0.0, 3.2, wall)
	k.wall(false, 0.0, 0.0, 12.0, 0.0, 3.2, wall)
	k.wall(true, 10.0, -12.1, 0.0, 0.0, 3.2, wall, [[-10.0, -2.0, 2.6, 0.9]], 0.2, pane)
	_furnish_contracts(k)

	# Crew room (x 0..20, z 0..12).
	k.wall(false, 20.0, 0.0, 12.0, 0.0, 3.2, wall)
	k.wall(true, 12.0, -0.1, 20.1, 0.0, 3.2, wall, [[2.0, 18.0, 2.7, 0.8]], 0.2, pane)
	_furnish_crew(k)

	# Outside: the hull's colours and a name the dock can read.
	k.box(Vector3(30.0, 0.4, 26.0), Vector3(30.0, -0.5, -17.0), dark, false)
	k.sign("BSX LTD", Vector3(30.0, 9.5, -30.1), Vector3.FORWARD, 0.05, Kit.ORANGE, 96)
	k.sign("ORBITAL YARD", Vector3(30.0, 6.6, -30.1), Vector3.FORWARD, 0.025, Kit.HULL, 96)
	for x: float in [-30.0, 4.0]:
		k.box(Vector3(0.25, 7.0, 0.25), Vector3(x, 7.0, -2.0), dark, false)
		k.box(Vector3(0.35, 0.35, 0.35), Vector3(x, 10.6, -2.0), k.glow(Color(1.0, 0.25, 0.2), 6.0), false)
	# Solar wings and radiators on the roofs.
	for side: float in [-1.0, 1.0]:
		var wing_z := -2.0 + side * 9.0
		k.box(Vector3(16.0, 0.08, 6.0), Vector3(-24.0, 6.4, wing_z), k.paint(Color(0.12, 0.16, 0.3), 0.6, 0.25), false)
	k.box(Vector3(0.3, 3.2, 0.3), Vector3(-24.0, 4.8, -2.0), dark, false)
	k.box(Vector3(0.2, 0.2, 24.0), Vector3(-24.0, 6.4, -2.0), dark, false)
	for i in 4:
		k.box(Vector3(5.0, 2.4, 0.06), Vector3(18.0 + i * 7.5, 13.6, -17.0), k.paint(Kit.HULL, 0.2, 0.4), false)
		k.box(Vector3(0.2, 1.4, 0.2), Vector3(18.0 + i * 7.5, 12.7, -17.0), dark, false)
	# Running lights on the corners.
	for p: Vector3 in [Vector3(-40.2, 3.4, -5.2), Vector3(46.2, 12.3, -30.2), Vector3(46.2, 3.4, 12.2), Vector3(-12.2, 6.3, -22.2)]:
		k.box(Vector3(0.3, 0.3, 0.3), p, k.glow(Color(1.0, 0.25, 0.2), 6.0), false)


## The holotable's circle in the design room's middle, drawn on the floor (nothing stands in it).
func _mark_clear_circle(k) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = YardBus.DESIGN_CLEAR_RADIUS - 0.06
	tm.outer_radius = YardBus.DESIGN_CLEAR_RADIUS + 0.06
	tm.rings = 64
	ring.mesh = tm
	ring.scale = Vector3(1.0, 0.05, 1.0)
	ring.position = Vector3(0, 0.002, 0)
	ring.material_override = k.glow(Kit.ORANGE, 1.2)
	ring.name = "HoloCircle"
	design_root.add_child(ring)


func _door_frame(k, along_x: bool, at: float, a: float, b: float, h: float, mat: Material) -> void:
	if along_x:
		for x: float in [a, b]:
			k.box(Vector3(0.12, h, 0.3), Vector3(x, h * 0.5, at), mat, false)
		k.box(Vector3(b - a + 0.12, 0.12, 0.3), Vector3((a + b) * 0.5, h, at), mat, false)


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
	# A sofa facing the window onto the planet.
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
