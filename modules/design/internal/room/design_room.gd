extends Node3D
## The design room (plan Wave 2): the holotable in the middle, wall TVs showing the design's
## plans, elevations and numbers, and the design console you work at. Until the Yard's
## station shell is in (YardBus.design_room_root), this scene builds a stand-in room of the
## same size: 24 m wide (x), 18 m deep (z), 6 m high, window wall towards -Z.
##
## Tab switches between the console and looking round the room. Esc opens the pause menu.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")
const PlanView := preload("res://modules/design/internal/views/plan_view.gd")
const DataChannel := preload("res://modules/design/internal/views/data_channel.gd")
const DesignConsole := preload("res://modules/design/internal/console/design_console.gd")

const ROOM_SIZE := Vector3(24, 6, 18)
## What each wall TV shows: [mount id, view, deck].
const TV_VIEWS := [
	["tv_left_1", "plan", 0], ["tv_left_2", "side", 0], ["tv_left_3", "end", 0],
	["tv_right_1", "data", 0], ["tv_right_2", "plan", 1], ["tv_right_3", "side", 0],
]

var bus: DesignBus
var holo: HoloTable
var console: DesignConsole
var camera: Camera3D
var tvs: Dictionary = {}  # mount id -> TouchScreen
var room_view := false
var _look_turn := 0.0
var _look_pitch := -0.25
var _layer: CanvasLayer


func _ready() -> void:
	bus = Modules.bus("design") as DesignBus
	add_child(SpaceLook.world_environment())
	_build_shell()
	holo = HoloTable.new()
	holo.name = "HoloTable"
	add_child(holo)
	holo.setup(bus)
	for m in mounts():
		_add_tv(m)
	camera = Camera3D.new()
	camera.name = "RoomCamera"
	camera.fov = 70.0
	add_child(camera)
	camera.current = true
	_layer = CanvasLayer.new()
	_layer.name = "ConsoleLayer"
	add_child(_layer)
	console = DesignConsole.new()
	console.name = "Console"
	_layer.add_child(console)
	console.setup(bus, holo)
	console.leave_requested.connect(func() -> void: set_room_view(true))
	_place_camera()


## Wall spots for TVs and the whiteboard: {id, transform (facing into the room, +Z of the
## screen towards the middle), size}. The Yard's shell will hand these over.
func mounts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var half := ROOM_SIZE * 0.5
	for i in 3:
		var z := -5.0 + i * 5.0
		out.append({"id": "tv_left_%d" % (i + 1), "size": Vector2(2.4, 1.4),
				"transform": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-half.x + 0.08, 2.3, z))})
		out.append({"id": "tv_right_%d" % (i + 1), "size": Vector2(2.4, 1.4),
				"transform": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(half.x - 0.08, 2.3, z))})
	out.append({"id": "whiteboard", "size": Vector2(10, 3),
			"transform": Transform3D(Basis(Vector3.UP, PI), Vector3(0, 2.4, half.z - 0.08))})
	return out


func set_room_view(on: bool) -> void:
	room_view = on
	console.visible = not on
	_place_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			set_room_view(not room_view)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			Menu.open_pause()
			get_viewport().set_input_as_handled()
	elif room_view and event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		_look_turn -= event.relative.x * 0.004
		_look_pitch = clampf(_look_pitch - event.relative.y * 0.004, -1.0, 0.6)
		_place_camera()


func _place_camera() -> void:
	if camera == null:
		return
	# Standing at the console side of the table, looking over it to the window wall.
	camera.position = Vector3(0, 1.7, 5.6) if not room_view else Vector3(6.5, 2.4, 7.5)
	camera.rotation = Vector3(_look_pitch, _look_turn + (0.0 if not room_view else 0.55), 0)


func _add_tv(m: Dictionary) -> void:
	var view := ""
	var deck := 0
	for spec in TV_VIEWS:
		if spec[0] == m.id:
			view = spec[1]
			deck = spec[2]
	if view == "":
		return  # the whiteboard is Wave 3
	var sz: Vector2 = m.size
	var px := Vector2i(1280, int(1280.0 * sz.y / sz.x))
	var content: Control
	if view == "data":
		var dc := DataChannel.new()
		dc.setup(bus, false)
		content = dc
	else:
		var pv := PlanView.new()
		pv.setup(bus, view, false)
		pv.deck = deck
		pv.auto_frame = true
		content = pv
	var tv := TouchScreen.new(content, px, sz)
	tv.name = "TV_" + str(m.id)
	tv.transform = m.transform
	add_child(tv)
	tvs[m.id] = tv


# The stand-in room: floor, walls, ceiling, a window wall, lamps.

func _build_shell() -> void:
	var shell := Node3D.new()
	shell.name = "StandInShell"
	add_child(shell)
	var half := ROOM_SIZE * 0.5
	var floor_mat := _mat(Color(0.16, 0.17, 0.19), 0.8, 0.3)
	var wall_mat := _mat(Color(0.28, 0.3, 0.33), 0.7, 0.2)
	var ceil_mat := _mat(Color(0.12, 0.13, 0.15), 0.9, 0.1)
	_slab(shell, Vector3(0, -0.1, 0), Vector3(ROOM_SIZE.x, 0.2, ROOM_SIZE.z), floor_mat)
	_slab(shell, Vector3(0, ROOM_SIZE.y + 0.1, 0), Vector3(ROOM_SIZE.x, 0.2, ROOM_SIZE.z), ceil_mat)
	_slab(shell, Vector3(-half.x - 0.1, half.y, 0), Vector3(0.2, ROOM_SIZE.y, ROOM_SIZE.z), wall_mat)
	_slab(shell, Vector3(half.x + 0.1, half.y, 0), Vector3(0.2, ROOM_SIZE.y, ROOM_SIZE.z), wall_mat)
	_slab(shell, Vector3(0, half.y, half.z + 0.1), Vector3(ROOM_SIZE.x, ROOM_SIZE.y, 0.2), wall_mat)
	# Window wall: sill and header, mullions, open to the stars between.
	_slab(shell, Vector3(0, 0.5, -half.z - 0.1), Vector3(ROOM_SIZE.x, 1.0, 0.3), wall_mat)
	_slab(shell, Vector3(0, ROOM_SIZE.y - 0.4, -half.z - 0.1), Vector3(ROOM_SIZE.x, 0.8, 0.3), wall_mat)
	for i in 7:
		_slab(shell, Vector3(-half.x + i * 4.0, half.y, -half.z - 0.1), Vector3(0.25, ROOM_SIZE.y, 0.35), wall_mat)
	# The raised ring round the table.
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.0
	cyl.bottom_radius = 3.0
	cyl.height = 0.1
	cyl.radial_segments = 64
	ring.mesh = cyl
	ring.position.y = 0.05
	ring.material_override = _mat(Color(0.22, 0.24, 0.27), 0.6, 0.5)
	shell.add_child(ring)
	for x in [-7.0, 0.0, 7.0]:
		for z in [-4.0, 4.0]:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(x, ROOM_SIZE.y - 0.3, z)
			lamp.light_energy = 2.2
			lamp.omni_range = 12.0
			lamp.light_color = Color(1.0, 0.95, 0.88)
			shell.add_child(lamp)
			_slab(shell, lamp.position + Vector3(0, 0.22, 0), Vector3(1.2, 0.05, 0.4), _glow(Color(1.0, 0.95, 0.85)))


func _mat(col: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m


func _glow(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	return m


func _slab(parent: Node3D, pos: Vector3, sz: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
