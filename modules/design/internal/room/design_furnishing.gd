extends Node3D
## Everything the design module puts in the design room: the holotable in the middle, the
## walls as interactive screens (each a WallBoard of panels over the whole wall plane), and the
## design console that opens when you use the table.
## Added under YardBus.design_room_root() in the station, or under the stand-in room in the
## design.room scene. Node space is the room's: floor centre, +X right, -Z to the window.

const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")
const WallBoard := preload("res://modules/design/internal/room/wall_board.gd")
const DesignConsole := preload("res://modules/design/internal/console/design_console.gd")
const WalkInside := preload("res://modules/design/internal/walk/walk_inside.gd")

## What each wall's panels show at first: wall id -> [[view, share of the width], ...].
## Anyone can change a panel with its < and > (WallBoard.views()).
## Walls split into screens of their own (beenster, 22 Nov: "the two long wall screens can
## contain 4 screens in each. The other two wall screens only 2"): "wall_back_high" is the first,
## then "wall_back_high_2" and on, left to right as seen from the room.
const WALL_LAYOUT := {
	"wall_left": [["plan:0", 1.0]],
	"wall_left_2": [["fit", 1.0]],
	"wall_right": [["market", 1.0]],
	"wall_right_2": [["plan:1", 1.0]],
	"wall_back_low_left": [["whiteboard", 1.0]],
	"wall_back_low_left_2": [["plan:0", 1.0]],
	"wall_back_low_left_3": [["modules", 1.0]],
	"wall_back_low_left_4": [["data", 1.0]],
	"wall_back_high": [["side", 1.0]],
	"wall_back_high_2": [["end", 1.0]],
	"wall_back_high_3": [["accounts", 1.0]],
	"wall_back_high_4": [["plan:1", 1.0]],
	"wall_back_low_right": [["data", 1.0]],
}
## How many screens each wall is split into: the two really long ones (the 16 m low back wall
## left of the door and the 23 m one above it) four, the side walls two.
const WALL_SPLIT := {"wall_back_low_left": 4, "wall_back_high": 4, "wall_left": 2, "wall_right": 2}
## The bare wall between two screens of a split wall, m.
const SPLIT_GAP := 0.35
## Pixels per metre on the walls (an 18 m wall is 2,700 px across).
const WALL_PX_PER_M := 150.0
## How far from a wall it can be used, m (the room is 24 m across).
const WALL_REACH := 12.0

## The mouse claim while the console is open (HudSlots).
const POINTER := "design.console"
const FULL_POINTER := "design.fullscreen"
## Pixels per metre a panel is drawn at full screen (its text a little bigger than on the wall).
const FULL_PX_PER_M := 140.0
## The mouse claim while walking inside the design.
const WALK_POINTER := "design.walk"

## How near the table (its middle, across the floor) the holotable keys work, m. The table
## is 7 m by 3.4 m, so this is about an arm's length off its long edge.
const TABLE_REACH := 4.5
## Turning with the arrow keys, radians a second.
const TURN_RATE := 1.6
## Zooming with the arrow keys: times bigger a second.
const ZOOM_RATE := 1.8
const ZOOM_MIN := 0.4
const ZOOM_MAX := 4.0
## Each Page Down cuts away this share of the model's height from the top.
const CUT_STEP := 0.2
## What N steps through: the layers as they were set, every layer, then each layer alone.
const LAYER_VIEWS: PackedStringArray = ["as set", "everything", "rooms", "frame", "plates",
		"components", "wiring", "pipes", "power"]

## The design room's inside, m (the station's design room is this size).
const ROOM_SIZE := Vector3(24, 6, 18)

signal console_opened
signal console_closed
signal walk_opened
signal walk_closed

var bus: DesignBus
var holo: HoloTable
var console: DesignConsole
var walls: Dictionary = {}  # wall id -> TouchScreen (its content a WallBoard)
var boards: Dictionary = {}  # wall id -> its WallBoard
var plane_of: Dictionary = {}  # wall id -> the wall plane it stands on (a split wall's screens share one)
var _layer: CanvasLayer
## Walk-inside mode while it's open, else null.
var walk: WalkInside
var _camera_before: Camera3D
## Where N is in LAYER_VIEWS, and the layers as they were before the first press.
var layer_view := 0
var _layers_as_set: Dictionary = {}
## A wall panel shown full screen (F at a wall), or null; and which wall and panel it is.
var fullscreen: Control
var full_from := {}


func setup(design_bus: DesignBus, wall_planes: Array[Dictionary]) -> void:
	bus = design_bus
	name = "DesignFurnishing"
	holo = HoloTable.new()
	holo.name = "HoloTable"
	add_child(holo)
	holo.setup(bus)
	holo.share()
	_add_use_body()
	for w in wall_planes:
		_add_wall(w)
	_layer = CanvasLayer.new()
	_layer.name = "ConsoleLayer"
	_layer.layer = 5
	add_child(_layer)
	console = DesignConsole.new()
	console.name = "Console"
	_layer.add_child(console)
	console.setup(bus, holo)
	console.leave_requested.connect(close_console)
	console.walk_requested.connect(open_walk)
	console.visible = false


## The design room's wall planes, for when the yard module has none (the stand-in room, or a
## station from before its creative shell). Same ids and convention as YardBus's
## design_room_walls(): origin at the plane's middle on the wall face, -Z into the room, size
## in m. The corridor door is at room x 5 to 7.5 in the back wall; the mezzanine at 3.4 m.
static func stand_in_walls() -> Array[Dictionary]:
	var half := ROOM_SIZE * 0.5
	var face := 0.06
	var side := Vector2(ROOM_SIZE.z - 1.0, 5.2)
	var low_l := Vector2(4.6 - (-half.x + 0.5), 3.0)
	var low_r := Vector2((half.x - 0.5) - 7.9, 3.0)
	return [
		{"id": "wall_left", "size": side,
				"transform": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-half.x + face, 0.4 + side.y * 0.5, 0))},
		{"id": "wall_right", "size": side,
				"transform": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(half.x - face, 0.4 + side.y * 0.5, 0))},
		{"id": "wall_back_low_left", "size": low_l,
				"transform": Transform3D(Basis.IDENTITY, Vector3(-half.x + 0.5 + low_l.x * 0.5, 0.3 + low_l.y * 0.5, half.z - face))},
		{"id": "wall_back_low_right", "size": low_r,
				"transform": Transform3D(Basis.IDENTITY, Vector3(7.9 + low_r.x * 0.5, 0.3 + low_r.y * 0.5, half.z - face))},
		{"id": "wall_back_high", "size": Vector2(ROOM_SIZE.x - 1.0, 2.2),
				"transform": Transform3D(Basis.IDENTITY, Vector3(0, 3.6 + 1.1, half.z - face))},
	] as Array[Dictionary]


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


func is_walking() -> bool:
	return walk != null


## Walk-inside mode: leaves the console for the open design at full size, around you.
func open_walk() -> void:
	if walk or bus.library.current == null:
		return
	HudSlots.claim_pointer(WALK_POINTER)
	_camera_before = get_viewport().get_camera_3d()
	close_console()
	walk = WalkInside.new()
	add_child(walk)
	walk.setup(bus, global_transform)
	walk.camera.current = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	walk_opened.emit()


## Back from walking inside to the console at the table.
func close_walk() -> void:
	if walk == null:
		return
	remove_child(walk)
	walk.queue_free()
	walk = null
	if is_instance_valid(_camera_before):
		_camera_before.current = true
	_camera_before = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	open_console()
	HudSlots.release_pointer(WALK_POINTER)
	walk_closed.emit()


func _exit_tree() -> void:
	HudSlots.release_pointer(POINTER)
	HudSlots.release_pointer(FULL_POINTER)
	HudSlots.release_pointer(WALK_POINTER)


## True when the player stands at the table with the console shut: the holotable keys work.
func at_table() -> bool:
	if holo == null or walk or is_console_open() or not is_inside_tree():
		return false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var d := holo.to_local(cam.global_position)
	return Vector2(d.x, d.z).length() <= TABLE_REACH


func _process(delta: float) -> void:
	if not at_table():
		return
	var spin := Input.get_action_strength(DesignBus.KEY_HOLO_RIGHT) \
			- Input.get_action_strength(DesignBus.KEY_HOLO_LEFT)
	if spin != 0.0:
		holo.turn += spin * TURN_RATE * delta
	var grow := Input.get_action_strength(DesignBus.KEY_HOLO_IN) \
			- Input.get_action_strength(DesignBus.KEY_HOLO_OUT)
	if grow != 0.0:
		holo.zoom = clampf(holo.zoom * pow(ZOOM_RATE, grow * delta), ZOOM_MIN, ZOOM_MAX)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not at_table():
		return
	if event.is_action_pressed(DesignBus.KEY_HOLO_LAYER):
		next_layer_view()
	elif event.is_action_pressed(DesignBus.KEY_HOLO_CUT_DOWN):
		holo.set_cut(holo.cut - CUT_STEP)
	elif event.is_action_pressed(DesignBus.KEY_HOLO_CUT_UP):
		holo.set_cut(holo.cut + CUT_STEP)
	elif event.is_action_pressed(DesignBus.KEY_HOLO_SEND):
		send_view_to_wall()
	else:
		return
	get_viewport().set_input_as_handled()


## J at the table (plan 3.3): what the hologram shows put up on the wall you face, on that
## wall's widest panel: the plan of the top deck left when it is cut down, else the side or the
## end elevation, whichever way you are looking at the ship. Returns [wall id, view] or [].
func send_view_to_wall() -> Array:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var rec: DesignRecord = bus.library.current
	if cam == null or rec == null or boards.is_empty():
		return []
	var look := -cam.global_basis.z
	var view := ""
	if holo.cut < 0.999:
		var levels: PackedInt32Array = rec.decks()
		var height := (levels[levels.size() - 1] + 1) * rec.deck_height
		view = "plan:%d" % clampi(int(floor(holo.cut * height / rec.deck_height - 0.01)), 0, levels[levels.size() - 1])
	else:
		var ship := holo.model.get_node_or_null("Ship") as Node3D
		var along := (ship.global_basis.z if ship else Vector3.FORWARD).normalized()
		view = "end" if absf(look.normalized().dot(along)) > 0.7 else "side"
	var best := ""
	var best_dot := -INF
	for id: String in walls:
		var screen := walls[id] as Node3D
		var facing := screen.global_basis.z.normalized()  # out of the wall, into the room
		# The screen looked most straight at: a split wall's screens are told apart by where
		# each one is, not only the way the wall faces.
		var to := (screen.global_position - cam.global_position).normalized()
		var d := look.normalized().dot(-facing) + look.normalized().dot(to)
		if d > best_dot:
			best_dot = d
			best = id
	var board: WallBoard = boards[best]
	var widest := 0
	for i in board.panels.size():
		if float(board.panels[i].share) > float(board.panels[widest].share):
			widest = i
	board.set_view(widest, view)
	return [best, view]


## N at the table: the next of LAYER_VIEWS on the hologram. Returns its name.
func next_layer_view() -> String:
	if layer_view == 0:
		_layers_as_set = holo.layers.duplicate()
	layer_view = (layer_view + 1) % LAYER_VIEWS.size()
	var view := LAYER_VIEWS[layer_view]
	for layer: String in HoloTable.LAYERS:
		var on: bool
		match view:
			"as set": on = bool(_layers_as_set.get(layer, false))
			"everything": on = true
			_: on = layer == view
		holo.set_layer(layer, on)
	return view


## "Rooms", "Everything": what N shows now, for the hint.
func layer_view_name() -> String:
	var view := LAYER_VIEWS[layer_view]
	if HoloTable.LAYER_NAMES.has(view):
		return HoloTable.LAYER_NAMES[view] + " only"
	return view.capitalize()


## The wall the view (or free mouse) is on, "" for none.
func aimed_wall() -> String:
	var cur := TouchScreen.current()
	for id: String in walls:
		if walls[id] == cur:
			return id
	return ""


## F at a wall (beenster, 20 Nov: "press F ... go full screen, like at the holotable"): the
## panel under the pointer fills the screen, with the free mouse, its < and > working, and
## anything it changes shared as on the wall. F or Esc puts it back.
func open_fullscreen(wall_id: String, panel := -1) -> bool:
	if fullscreen or walk or is_console_open() or not boards.has(wall_id):
		return false
	var board: WallBoard = boards[wall_id]
	var i := panel
	if i < 0:
		i = board.panel_at((walls[wall_id] as TouchScreen).pointer_px)
	if i < 0:
		i = 0
		for k in board.panels.size():
			if float(board.panels[k].share) > float(board.panels[i].share):
				i = k
	var page := PanelContainer.new()
	page.name = "WallFullScreen"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_stylebox_override("panel", WallBoard.T.box(Color(0.02, 0.05, 0.09, 0.97), WallBoard.T.EDGE, 0, 0.0))
	var col := VBoxContainer.new()
	page.add_child(col)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	col.add_child(bar)
	bar.add_child(WallBoard.T.label("WALL SCREEN, FULL", "display_bold", 18, WallBoard.T.ORANGE))
	var tip := WallBoard.T.label("%s or Esc to go back" % Keys.prompt(Keys.INTERACT), "body", 15, WallBoard.T.DIM)
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(tip)
	var back := WallBoard.T.button("BACK", false, 16)
	back.name = "Back"
	back.pressed.connect(close_fullscreen)
	bar.add_child(back)
	var full := WallBoard.new()
	full.local = true
	full.size_flags_vertical = Control.SIZE_EXPAND_FILL
	full.setup(bus, wall_id + "_full", [[str(board.panels[i].view), 1.0]], FULL_PX_PER_M)
	col.add_child(full)
	var layer := CanvasLayer.new()
	layer.name = "FullScreenLayer"
	layer.layer = 6
	layer.add_child(page)
	add_child(layer)
	fullscreen = page
	full_from = {"wall": wall_id, "panel": i, "board": full}
	HudSlots.claim_pointer(FULL_POINTER)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return true


## Back from full screen to the room; the wall panel takes the view it was left on.
func close_fullscreen() -> void:
	if fullscreen == null:
		return
	var full: WallBoard = full_from.get("board")
	if full and boards.has(str(full_from.wall)):
		var view := str(full.panels[0].view)
		var board: WallBoard = boards[str(full_from.wall)]
		var i := int(full_from.panel)
		if i < board.panels.size() and str(board.panels[i].view) != view:
			board.set_view(i, view)
	var layer := fullscreen.get_parent()
	layer.queue_free()
	fullscreen = null
	full_from = {}
	HudSlots.release_pointer(FULL_POINTER)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_fullscreen() -> bool:
	return fullscreen != null


func _input(event: InputEvent) -> void:
	if fullscreen and event.is_pressed() and not event.is_echo() and (event.is_action_pressed(Keys.INTERACT)
			or (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE)):
		close_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if not fullscreen and not walk and not is_console_open() and event.is_action_pressed(Keys.INTERACT) \
			and not event.is_echo() and aimed_wall() != "":
		if open_fullscreen(aimed_wall()):
			get_viewport().set_input_as_handled()
			return
	if walk and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		close_walk()
		get_viewport().set_input_as_handled()
		return
	# Esc leaves the console before anything else sees it (the pause menu, the station).
	if is_console_open() and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		if console._library_panel.visible:
			console._toggle_library()
		elif console.plan.cancel():
			pass  # Esc first drops a half-drawn run, then the tool in hand
		else:
			close_console()
		get_viewport().set_input_as_handled()


## A body over the table that the player's view finds: "E  Design at the holotable".
func _add_use_body() -> void:
	var body := StaticBody3D.new()
	body.name = "TableUse"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HoloTable.TABLE_SIZE.x, HoloTable.TABLE_HEIGHT, HoloTable.TABLE_SIZE.y)
	shape.shape = box
	shape.position.y = HoloTable.TABLE_HEIGHT * 0.5
	body.add_child(shape)
	body.set_meta("yard_use", open_console)
	body.set_meta("yard_hint", func() -> String:
		var rec := bus.library.current
		return "%s  Design at the holotable%s\n%s%s turn   %s%s zoom   %s layers: %s   %s%s cut   %s to the wall" % [
				Keys.prompt(Keys.INTERACT), ("  (" + rec.name + ")") if rec else "",
				Keys.prompt(DesignBus.KEY_HOLO_LEFT), Keys.prompt(DesignBus.KEY_HOLO_RIGHT),
				Keys.prompt(DesignBus.KEY_HOLO_IN), Keys.prompt(DesignBus.KEY_HOLO_OUT),
				Keys.prompt(DesignBus.KEY_HOLO_LAYER), layer_view_name(),
				Keys.prompt(DesignBus.KEY_HOLO_CUT_UP), Keys.prompt(DesignBus.KEY_HOLO_CUT_DOWN),
				Keys.prompt(DesignBus.KEY_HOLO_SEND)])
	holo.add_child(body)


## A wall plane as its screens (split()).
func _add_wall(w: Dictionary) -> void:
	for part in split(w):
		_add_screen(part, str(w.id))


## A wall plane as the screens on it: itself, or for a long wall (WALL_SPLIT) that many planes
## side by side with SPLIT_GAP of bare wall between, the first on the left as seen from the room.
static func split(w: Dictionary) -> Array[Dictionary]:
	var n := int(WALL_SPLIT.get(str(w.id), 1))
	if n <= 1:
		return [w] as Array[Dictionary]
	var sz: Vector2 = w.size
	var each := (sz.x - SPLIT_GAP * (n - 1)) / n
	var out: Array[Dictionary] = []
	for i in n:
		# Planes face -Z, so from the room their +X is on the left.
		var x := sz.x * 0.5 - each * 0.5 - i * (each + SPLIT_GAP)
		out.append({"id": str(w.id) if i == 0 else "%s_%d" % [w.id, i + 1], "size": Vector2(each, sz.y),
				"transform": (w.transform as Transform3D) * Transform3D(Basis.IDENTITY, Vector3(x, 0, 0))})
	return out


## One screen over a plane. Planes face into the room along their -Z; a TouchScreen faces
## its +Z, so it is turned round, and stands 8 cm off the wall's face.
func _add_screen(w: Dictionary, plane_id: String) -> void:
	var layout: Array = WALL_LAYOUT.get(str(w.id), [["plan:0", 0.5], ["data", 0.5]])
	var sz: Vector2 = w.size
	var px := Vector2i(int(sz.x * WALL_PX_PER_M), int(sz.y * WALL_PX_PER_M))
	var board := WallBoard.new()
	board.setup(bus, str(w.id), layout, WALL_PX_PER_M)
	var screen := TouchScreen.new(board, px, sz)
	screen.name = "Wall_" + str(w.id)
	screen.reach = WALL_REACH
	screen.hint = {"title": "Design wall", "keys": [["LMB", "Press < or > to change a panel"],
			[Keys.prompt(Keys.INTERACT), "Full screen"]]}
	screen.transform = (w.transform as Transform3D) * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -0.08))
	add_child(screen)
	walls[w.id] = screen
	boards[w.id] = board
	plane_of[w.id] = plane_id
