extends Node3D
## The design room on its own, for working on it without the station: a stand-in shell the
## size of the station's design room (24 m wide, 18 m deep, 6 m high, window wall to -Z) with
## the same furnishing the station gets (holotable, interactive walls on YardBus's wall planes, console).
##
## Tab switches between the console and looking round the room. Esc opens the pause menu.

const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")

const ROOM_SIZE := Furnishing.ROOM_SIZE

var bus: DesignBus
var furnishing: Furnishing
var holo: Node3D
var console: Control
var camera: Camera3D
var walls: Dictionary = {}
var room_view := false
var _look_turn := 0.0
var _look_pitch := -0.25


func _ready() -> void:
	bus = Modules.bus("design") as DesignBus
	add_child(SpaceLook.world_environment())
	_build_shell()
	camera = Camera3D.new()
	camera.name = "RoomCamera"
	camera.fov = 70.0
	add_child(camera)
	camera.current = true
	furnishing = Furnishing.new()
	add_child(furnishing)
	furnishing.setup(bus, bus.room_walls())
	holo = furnishing.holo
	console = furnishing.console
	walls = furnishing.walls
	furnishing.console_closed.connect(func() -> void: set_room_view(true))
	furnishing.console_opened.connect(func() -> void: set_room_view(false))
	furnishing.open_console()
	_place_camera()


func set_room_view(on: bool) -> void:
	room_view = on
	if on:
		furnishing.close_console()
	else:
		furnishing.open_console()
	_place_camera()


func _unhandled_input(event: InputEvent) -> void:
	if furnishing.is_walking():
		return
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
		# Between the sill and the header, so no face lies on theirs.
		_slab(shell, Vector3(-half.x + i * 4.0, 1.0 + (ROOM_SIZE.y - 1.8) * 0.5, -half.z - 0.1),
				Vector3(0.25, ROOM_SIZE.y - 1.8, 0.35), wall_mat)
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
