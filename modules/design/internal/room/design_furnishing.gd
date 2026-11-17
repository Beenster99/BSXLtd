extends Node3D
## Everything the design module puts in the design room: the holotable in the middle, the
## wall TVs on the room's mounts, and the design console that opens when you use the table.
## Added under YardBus.design_room_root() in the station, or under the stand-in room in the
## design.room scene. Node space is the room's: floor centre, +X right, -Z to the window.

const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")
const PlanView := preload("res://modules/design/internal/views/plan_view.gd")
const DataChannel := preload("res://modules/design/internal/views/data_channel.gd")
const DesignConsole := preload("res://modules/design/internal/console/design_console.gd")

## What each wall TV shows: mount id -> [view, deck].
const TV_VIEWS := {
	"tv_left_1": ["plan", 0], "tv_left_2": ["side", 0], "tv_left_3": ["end", 0],
	"tv_right_1": ["data", 0], "tv_right_2": ["plan", 1], "tv_right_3": ["side", 0],
}
## The mouse claim while the console is open (HudSlots).
const POINTER := "design.console"

## The design room's inside, m (the station's design room is this size).
const ROOM_SIZE := Vector3(24, 6, 18)

signal console_opened
signal console_closed

var bus: DesignBus
var holo: HoloTable
var console: DesignConsole
var tvs: Dictionary = {}  # mount id -> TouchScreen
var _layer: CanvasLayer


func setup(design_bus: DesignBus, mounts: Array[Dictionary]) -> void:
	bus = design_bus
	name = "DesignFurnishing"
	holo = HoloTable.new()
	holo.name = "HoloTable"
	add_child(holo)
	holo.setup(bus)
	_add_use_body()
	for m in mounts:
		_add_tv(m)
	_layer = CanvasLayer.new()
	_layer.name = "ConsoleLayer"
	_layer.layer = 5
	add_child(_layer)
	console = DesignConsole.new()
	console.name = "Console"
	_layer.add_child(console)
	console.setup(bus, holo)
	console.leave_requested.connect(close_console)
	console.visible = false


## The station's wall spots, for the stand-in room when the yard module is off. Same ids and
## convention as the yard's: origin on the wall face, -Z into the room.
static func stand_in_mounts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var half := ROOM_SIZE * 0.5
	for i in 3:
		var z := -5.0 + 4.5 * i
		out.append({"id": "tv_left_%d" % (i + 1), "size": Vector2(2.4, 1.4),
				"transform": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-half.x + 0.06, 2.2, z))})
		out.append({"id": "tv_right_%d" % (i + 1), "size": Vector2(2.4, 1.4),
				"transform": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(half.x - 0.06, 2.2, z))})
	out.append({"id": "whiteboard", "size": Vector2(10, 3),
			"transform": Transform3D(Basis.IDENTITY, Vector3(-4.0, 2.2, half.z - 0.06))})
	return out


func is_console_open() -> bool:
	return console != null and console.visible


func open_console() -> void:
	if console == null or console.visible:
		return
	console.visible = true
	HudSlots.claim_pointer(POINTER)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	console.plan.frame_all.call_deferred()
	console_opened.emit()


func close_console() -> void:
	if console == null or not console.visible:
		return
	console.visible = false
	HudSlots.release_pointer(POINTER)
	console_closed.emit()


func _exit_tree() -> void:
	HudSlots.release_pointer(POINTER)


func _input(event: InputEvent) -> void:
	# Esc leaves the console before anything else sees it (the pause menu, the station).
	if is_console_open() and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		if console._library_panel.visible:
			console._toggle_library()
		else:
			close_console()
		get_viewport().set_input_as_handled()


## A body round the table that the player's view finds: "E  Use the holotable".
func _add_use_body() -> void:
	var body := StaticBody3D.new()
	body.name = "TableUse"
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = HoloTable.TABLE_RADIUS
	cyl.height = HoloTable.TABLE_HEIGHT
	shape.shape = cyl
	shape.position.y = HoloTable.TABLE_HEIGHT * 0.5
	body.add_child(shape)
	body.set_meta("yard_use", open_console)
	body.set_meta("yard_hint", func() -> String:
		var rec := bus.library.current
		return "%s  Design at the holotable%s" % [Keys.prompt(Keys.INTERACT),
				("  (" + rec.name + ")") if rec else ""])
	holo.add_child(body)


## A wall TV on a room mount. Mounts face into the room along their -Z; a TouchScreen faces
## its +Z, so it is turned round.
func _add_tv(m: Dictionary) -> void:
	var spec: Array = TV_VIEWS.get(str(m.id), [])
	if spec.is_empty():
		return  # the whiteboard comes in Wave 3
	var sz: Vector2 = m.size
	var px := Vector2i(1280, int(1280.0 * sz.y / sz.x))
	var content: Control
	if spec[0] == "data":
		var dc := DataChannel.new()
		dc.setup(bus, false)
		content = dc
	else:
		var pv := PlanView.new()
		pv.setup(bus, spec[0], false)
		pv.deck = spec[1]
		pv.auto_frame = true
		content = pv
	var tv := TouchScreen.new(content, px, sz)
	tv.name = "TV_" + str(m.id)
	tv.transform = (m.transform as Transform3D) * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -0.08))
	add_child(tv)
	tvs[m.id] = tv
