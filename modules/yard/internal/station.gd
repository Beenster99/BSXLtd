extends Node3D
## The orbital yard (master plan Wave 1): the station's rooms with gravity (stage 1.1) and,
## outside, the weightless dock with its berths (stage 1.2, flag "yard.dock"), over a planet.
## Simple shapes first: the look comes in stage 1.5. You are in the Void Salvage suit (YardRig, 1.3).
## Where everything is: YardLayout (api). Rooms are furnished by other modules through
## YardBus (the design room's contents belong to the Design Room module).

const Kit := preload("res://modules/yard/internal/yard_kit.gd")
const SpaceSky := preload("res://modules/yard/internal/space_sky.gd")
const RackingHall := preload("res://modules/yard/internal/racking_hall.gd")
const Airlock := preload("res://modules/yard/internal/airlock.gd")
const Dock := preload("res://modules/yard/internal/dock.gd")
const PracticeFrame := preload("res://modules/yard/internal/tools/yard_practice_frame.gd")
## Where the practice frame floats: just out of the airlock (station space).
const PRACTICE_AT := Vector3(-47.5, -0.6, -2.0)

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
## Views of you in the suit: id -> [your feet, where you face, the camera, lamp on] (station space).
const SUIT_VIEWS := {
	"suit_corridor": [Vector3(-12, 0, -2.0), Vector3(-30, 1.5, -2.0), Vector3(-15.2, 1.6, -2.6), false],
	"suit_back": [Vector3(-12, 0, -2.0), Vector3(-30, 1.5, -2.0), Vector3(-8.6, 2.0, -1.4), false],
	"suit_dock": [Vector3(-52, -1.5, -40), Vector3(-30, -8, -95), Vector3(-49.0, -0.4, -43.2), true],
}
## Screenshot points at the practice frame (stage 1.4): the grinder on a rivet, seen from the
## side, and the same from your own eyes with the hotbar.
const TOOL_VIEWS := ["tools_grinder", "tools_first_person", "tools_tractor", "tools_tractor_close", "tools_tablet"]
## Where you start: the corridor, by the design room's door.
const START := Vector3(4.0, 0.0, -1.5)

var kit: RefCounted
var sky: Node3D
## You: the Void Salvage suit and jet-rig (YardRig). Named "Mover" as the stand-in was.
var mover: YardRig
var view_camera: Camera3D
var racking: Node3D
var airlock: Node3D
var dock: Node3D
## The practice frame for the hand tools (with the dock).
var practice: Node3D
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
		practice = PracticeFrame.new()
		practice.position = PRACTICE_AT
		practice.rotation.y = PI * 0.5   # its panels face the airlock
		add_child(practice)
	mover = YardRig.new()
	mover.name = "Mover"
	mover.gravity_at = Callable(YardLayout, "has_gravity")
	add_child(mover)
	mover.place(START, Vector3(6.25, 1.5, -10))
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
	var v: Array = VIEWS[id]
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
		k.span(Vector3(b.position.x - 0.1, b.end.y, b.position.z - 0.1), Vector3(b.end.x + 0.1, b.end.y + 0.3, b.end.z + 0.1), hull)
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
		for ix in nx:
			for iz in nz:
				var bounce := OmniLight3D.new()
				bounce.name = "Bounce_%d_%d" % [ix, iz]
				bounce.position = Vector3(b.position.x + cell.x * (ix + 0.5), b.end.y * 0.55, b.position.z + cell.y * (iz + 0.5))
				bounce.omni_range = cell.length() * 0.6 + b.end.y * 0.6
				bounce.omni_attenuation = 0.35
				bounce.light_energy = 0.32
				bounce.light_specular = 0.0
				bounce.light_color = Color(0.92, 0.95, 1.0)
				room.add_child(bounce)

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
