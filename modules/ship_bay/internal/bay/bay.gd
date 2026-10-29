extends Node3D
## The bay: a floor, a cradle and the loaded ship sitting on it, with a marker on every
## fastener (green tight, amber undone). Pieces of the model inside a slot's box hide while
## the slot is empty. Grey-box for now; Trades' tools work on it from release 0.3.

## Height of the ship's deck (y = 0 in ship space) over the bay floor, metres.
@export var cradle_height := 1.6
@export var ship_id := "vs_kestrel"
## Off when the bay sits inside another scene (the shipyard's courtyard), which brings its
## own ground, sky, sun and camera; the bay then adds only its cradles and the ship.
@export var standalone := true

## The fastener rings' one quiet colour and glow, tight or undone (beenster, 0.3.17: the
## green and amber rings hid the fasteners; Tools' look card says a joint's state). Matches
## Tools' TradesLook.QUIET_RING.
const QUIET_RING := Color(0.62, 0.74, 0.86)
const QUIET_GLOW := 0.35

const Access := preload("res://modules/ship_bay/internal/bay/bay_access.gd")
const TransportCradle := preload("res://modules/ship_bay/internal/yard/transport_cradle.gd")
const FileShip := preload("res://modules/ship_bay/internal/ships/file_ship_model.gd")
const ItemLook := preload("res://modules/ship_bay/internal/yard/item_look.gd")
const StorageLayout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")
## How far Use (F) reaches from the camera, metres.
const USE_REACH := 3.5

var ship_root: Node3D
## With ship_bay.bay_cradle (beenster, 0.3.19): the ship sits in a transport cradle ("BayCradle")
## on four pedestals instead of three fixed stands, so a transporter can drive it out; the
## ship rides with the cradle. Null with the flag off.
var cradle: Node3D
## Where the ship's origin sits off the bay's middle at the saddle tops' height (a wreck built from its file
## is set down on the saddles by its own belly; the Kestrel's deck is at the saddle tops).
var seat := Vector3.ZERO
## The ship's model (its root node), and the lift and power unit round it.
var model: Node3D
var access: Node3D
## slot_id -> Array of the model's MeshInstance3Ds inside its box.
var pieces: Dictionary = {}
## Slot id -> the ship body's collision shapes for its parts (file ships), off while the slot
## is EMPTY.
var colliders: Dictionary = {}
## joint_id -> MeshInstance3D marker.
var markers: Dictionary = {}
## joint_id -> its joint's path in the ship's file (a ship built from one).
var _joint_paths: Dictionary = {}
## Joints whose Void Salvage weld bead the bay never draws: inside walls and floors the
## loader bolts instead (LayoutLoader._bolted_inside).
var _no_file_head: Dictionary = {}
## CollisionShape3D -> its part's id in a file ship's model (built on the first inspect).
var _shape_parts: Dictionary = {}
var _bus: ShipBayBus
var _tight_mat := _quiet_ring()
var _loose_mat := _tight_mat
var _head_mat := ShipSurface.of(ShipKit.paint(Color(0.55, 0.57, 0.6), 0.85, 0.35))


func _ready() -> void:
	_bus = Modules.bus("ship_bay") as ShipBayBus
	if standalone:
		_build_stage()
	if Flags.is_on("ship_bay.bay_cradle"):
		_build_transport_cradle()
	else:
		_build_cradles()
	if _bus == null:
		return
	# An emptied bay (Settings > Debug > Ship) stays empty until the Kestrel is brought back.
	if (_bus.ship == null and not _bus.bay_cleared) or (_bus.ship and _bus.ship.ship_id != ship_id and _bus.ship.ship_id != ShipBayBus.WRECK_ID):
		_bus.load_ship(ship_id)
	_bus.ship_loaded.connect(_on_ship_changed)
	_bus.ship_unloaded.connect(_on_ship_changed)
	_bus.slot_state_changed.connect(_on_slot_changed)
	_bus.ship_power_changed.connect(_on_power)
	_bus.component_installed.connect(func(_s: String, _c: String) -> void: _refresh_markers())
	_bus.joint_changed.connect(_on_joint_changed)
	_bus.marker_focus_changed.connect(_on_marker_focus)
	_show_ship(_bus.ship)


func _exit_tree() -> void:
	if _bus and _bus.ship_loaded.is_connected(_on_ship_changed):
		_bus.ship_loaded.disconnect(_on_ship_changed)
		_bus.ship_unloaded.disconnect(_on_ship_changed)
	if _bus and _bus.slot_state_changed.is_connected(_on_slot_changed):
		_bus.slot_state_changed.disconnect(_on_slot_changed)
	if _bus and _bus.ship_power_changed.is_connected(_on_power):
		_bus.ship_power_changed.disconnect(_on_power)
	if _bus and _bus.marker_focus_changed.is_connected(_on_marker_focus):
		_bus.marker_focus_changed.disconnect(_on_marker_focus)
	if _bus and _bus.joint_changed.is_connected(_on_joint_changed):
		_bus.joint_changed.disconnect(_on_joint_changed)


## Three ship cradles, each an I-beam base on the floor with two posts, a head beam under
## the belly carried on hydraulic rams and a rubber pad on top (Void Salvage's parts on its
## ship surface). One box per cradle collides.
func _build_cradles() -> void:
	var top := cradle_height - 0.5
	var yellow := ShipSurface.of(ShipKit.paint(Color(0.95, 0.75, 0.1), 0.15, 0.5, "hazard_paint"))
	var steel := ShipSurface.of(ShipKit.paint(Color(0.55, 0.57, 0.6), 0.85, 0.3, "chrome"))
	var dark := ShipSurface.of(ShipKit.paint(Color(0.15, 0.16, 0.18), 0.5, 0.5, "gunmetal"))
	var rubber := ShipSurface.of(ShipKit.paint(Color(0.07, 0.07, 0.075), 0.0, 0.9, "rubber"))
	var upright := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	# Clear of the landing skids (z -1.6 and 5.2) and the belly jets.
	for z: float in [-3.4, 1.5, 4.2]:
		var cradle := Node3D.new()
		cradle.name = "Cradle"
		cradle.position = Vector3(0, 0, z)
		add_child(cradle)
		_part(cradle, PartShapes.i_beam(3.6, 0.6, 0.25, 0.03), Transform3D(Basis(), Vector3(0, 0.125, 0)), yellow)
		_part(cradle, PartShapes.i_beam(3.2, 0.45, 0.22, 0.03), Transform3D(Basis(), Vector3(0, top - 0.2, 0)), yellow)
		for x: float in [-1.35, 1.35]:
			_part(cradle, PartShapes.i_beam(top - 0.56, 0.4, 0.3, 0.03), Transform3D(upright, Vector3(x, 0.25 + (top - 0.56) * 0.5, 0)), yellow)
			_part(cradle, PartShapes.box(Vector3(0.6, 0.029, 0.8)), Transform3D(Basis(), Vector3(x, 0.0145, 0)), dark)   # under the flange tops
		for x: float in [-0.55, 0.55]:
			_part(cradle, WreckParts.pipe(0.09, top - 0.56, false), Transform3D(Basis(), Vector3(x, 0.25 + (top - 0.56) * 0.5, 0)), steel)
			_part(cradle, WreckParts.pipe(0.13, 0.3, true), Transform3D(Basis(), Vector3(x, 0.4, 0)), dark)
		_part(cradle, PartShapes.chamfer_box(Vector3(2.8, 0.1, 0.5), 0.03), Transform3D(Basis(), Vector3(0, top - 0.05, 0)), rubber)
		var solid := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = Vector3(3.2, top, 0.6)
		shape.position.y = top * 0.5
		solid.add_child(shape)
		cradle.add_child(solid)


## The transport cradle the ship sits in, on its four pedestals: the ship's deck then stands
## at the cradle's saddle tops (cradle_height follows).
func _build_transport_cradle() -> void:
	cradle = TransportCradle.new("s")
	cradle.name = "BayCradle"
	add_child(cradle)
	cradle.position = Vector3(0, TransportCradle.REST, 0)
	_build_pedestals()


## The pedestals under the cradle's side beams, for its size; cradle_height follows its
## saddle tops.
func _build_pedestals() -> void:
	cradle_height = TransportCradle.REST + float(cradle.get("saddle_top"))
	var old := get_node_or_null("Pedestals")
	if old:
		remove_child(old)
		old.queue_free()
	var frame := ShipSurface.of(ShipKit.paint(Color(0.34, 0.37, 0.4), 0.6, 0.45, "gunmetal"))
	var bare := ShipSurface.of(ShipKit.paint(Color(0.5, 0.52, 0.55), 0.7, 0.5))
	var stands := StaticBody3D.new()
	stands.name = "Pedestals"
	add_child(stands)
	var spots: Array[Vector3] = []
	for x: float in [-float(cradle.get("side_x")), float(cradle.get("side_x"))]:
		for z: float in cradle.get("pedestal_z"):
			spots.append(Vector3(x, 0, z + cradle_offset(str(cradle.get("size")))))
	for at: Vector3 in spots:
		var h := TransportCradle.REST - 0.06
		_part(stands, PartShapes.chamfer_box(Vector3(0.9, h, 0.9), 0.05), Transform3D(Basis(), at + Vector3(0, 0.06 + h * 0.5, 0)), frame)
		_part(stands, PartShapes.box(Vector3(1.3, 0.05, 1.3)), Transform3D(Basis(), at + Vector3(0, 0.035, 0)), bare)
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = Vector3(0.9, TransportCradle.REST, 0.9)
		shape.position = at + Vector3(0, TransportCradle.REST * 0.5, 0)
		stands.add_child(shape)


## The bay's cradle for a ship this long (metres): small up to the Kestrel's size, medium to
## 30 m, large beyond (Void Salvage's big wrecks, to 67 m).
static func cradle_size_for(ship_length: float) -> String:
	return "s" if ship_length <= 18.0 else ("m" if ship_length <= 30.0 else "l")


## How far south of the bay's middle a cradle of this size stands, metres: the large cradle is
## longer than the courtyard, so its north end stays NOSE_ROOM off the middle and the rest runs
## out over the front strip onto the apron (the courtyard's open south end).
static func cradle_offset(size_id: String) -> float:
	return maxf(float(TransportCradle.SIZES[size_id].length) * 0.5 - NOSE_ROOM, 0.0)


static func _part(parent: Node3D, shape: PartShapes.PartShape, xform: Transform3D, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = shape.mesh
	mi.material_override = mat
	mi.transform = xform
	parent.add_child(mi)


func _build_stage() -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mesh.mesh = plane
	floor_mesh.material_override = _paint(Color(0.22, 0.23, 0.25))
	add_child(floor_mesh)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.06, 0.08)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.52, 0.56)
	add_child(env)
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.position = Vector3(9.5, 5.5, 13.0)
	add_child(cam)
	cam.look_at(Vector3(0, cradle_height + 1.2, 2.5))


## The bay's ship came or went (Settings > Debug > Ship, or a load): show what's there now.
func _on_ship_changed(_id: String) -> void:
	var def := _bus.ship if _bus else null
	if def == null or model == null or model.get_meta("ship_id", "") != def.ship_id:
		_show_ship(def)


func _show_ship(def: ShipDefinition) -> void:
	if ship_root:
		ship_root.queue_free()
		ship_root = null
	model = null
	if access:
		access.queue_free()
		access = null
	pieces = {}
	markers = {}
	_joint_paths = {}
	_no_file_head = {}
	seat = Vector3.ZERO
	if cradle and cradle.get("load_node") != null and not is_instance_valid(cradle.get("load_node")):
		cradle.set("load_node", null)
	if def == null:
		if cradle:
			cradle.set("load_node", null)
			cradle.set("load_t", 0.0)
		return
	ship_root = Node3D.new()
	ship_root.name = "Ship"
	if def.model:
		model = def.model.instantiate() as Node3D
	elif not def.file.is_empty():
		model = FileShip.new(def.file, "Wreck")
		model.set_meta("look_hint", {"title": def.display_name, "text": "A random wreck, in for a look (Settings > Debug > Ship).", "keys": []})
	if model:
		model.set_meta("ship_id", def.ship_id)
		ship_root.add_child(model)
	var mass := 25.0
	if not def.file.is_empty():
		mass = float(def.file.get("stats", {}).get("mass_kg", 25000.0)) / 1000.0
	if cradle:
		var size := cradle_size_for(_ship_box(def).size.z)
		if cradle.get("size") != size:
			var was := cradle_offset(str(cradle.get("size")))
			cradle.set("load_node", null)
			cradle.call("resize", size)
			cradle.position.z += cradle_offset(size) - was
			_build_pedestals()
		if model and model.has_method("belly_under"):
			seat = _seat_on_cradle(model, def)
		cradle.call("carry", ship_root, Vector3(0, float(cradle.get("saddle_top")), -cradle_offset(size)) + seat)
		cradle.set("load_t", mass)
	else:
		if model and model.has_method("lowest_in"):
			var c := def.bounds.get_center()
			seat = Vector3(-c.x, maxf(0.05 - cradle_height - def.bounds.position.y, 0.0), -c.z)
		ship_root.position = Vector3(0, cradle_height, 0) + seat
		add_child(ship_root)
	pieces = model.call("slot_pieces", def) if model and model.has_method("slot_pieces") else pieces_by_slot(ship_root, def)
	colliders = model.call("slot_colliders", def) if model and model.has_method("slot_colliders") else {}
	ItemLook.part_source = _part_shape
	if _bus:
		_bus.part_info_source = _part_info
		_bus.inspect_source = _inspect
	_shape_parts = {}
	_build_access()
	for s in def.slots:
		for f in s.fasteners:
			var m := _fastener_marker(f, def.ship_id == ShipBayBus.WRECK_ID)
			ship_root.add_child(m)
			markers[f.joint_id] = m
			m.set_meta("kind", f.kind)
			if f.path != "" and not f.has_meta("copy"):
				_joint_paths[f.joint_id] = f.path
			if f.has_meta("inside"):
				_no_file_head[f.joint_id] = true
		_apply_slot(s.slot_id)
	_refresh_markers()
	if def.ship_id == ShipBayBus.WRECK_ID:
		_lift_markers.call_deferred(def)


## The top of the loaded ship (ship space), metres.
func _bus_bounds_top() -> float:
	return _ship_box(_bus.ship).end.y if _bus and _bus.ship else 0.0


## The box round the loaded ship (ship space): its surface's for a ship built from its file (the
## file's bounds count a turned plate's whole box, and once sat a wreck metres over the saddles).
func _ship_box(def: ShipDefinition) -> AABB:
	if model and model.has_method("surface_box"):
		var box: AABB = model.call("surface_box")
		if box.has_volume():
			return box
	return def.bounds


## How far north of the cradle's middle a ship's nose may reach, metres (the courtyard's north
## wall is 24 m off).
const NOSE_ROOM := 22.5


## The cradle's saddle pads (TransportCradle.SIZES `spec`), sampled across, in the space of a
## ship whose origin is `shift` (x, z) off the cradle's middle: [points (x, z), each one's pad
## top over the cradle (the outer saddles stand higher)].
static func saddle_points(spec: Dictionary, shift: Vector2) -> Array:
	var points: Array[Vector2] = []
	var tops: Array[float] = []
	var side_x := float(spec.side_x)
	for z: float in spec.cross_z:
		for x: float in spec.saddle_x:
			for dx: float in [-0.6, -0.3, 0.0, 0.3, 0.6]:
				for dz: float in [-0.2, 0.0, 0.2]:
					points.append(Vector2(x + dx, z + dz) - shift)
					tops.append(float(spec.saddle_top) + (0.0 if absf(x) < side_x * 0.5 else side_x * 0.04))
	return [points, tops]


## Where a ship built from its file sits on the cradle (off the saddle tops' middle): centred
## on it, its belly down on the saddles it meets first, and clear of the cradle's beams and
## the floor everywhere else (a landing leg between the cross beams hangs down into the frame).
func _seat_on_cradle(ship_model: Node3D, def: ShipDefinition) -> Vector3:
	var spec: Dictionary = TransportCradle.SIZES[str(cradle.get("size"))]
	var top := float(spec.saddle_top)
	var side_x := float(spec.side_x)
	var bounds := _ship_box(def)
	var c := bounds.get_center()
	var shift := Vector2(-c.x, -c.z)
	# A ship longer than the courtyard's floor north of the cradle moves south (the open end of
	# the yard), its nose clear of the north wall.
	shift.y += maxf(bounds.size.z * 0.5 - NOSE_ROOM, 0.0)
	# The cradle's own space (a large one stands south of the middle).
	var on := shift - Vector2(0, cradle_offset(str(cradle.get("size"))))
	var pads := saddle_points(spec, on)
	var points: Array[Vector2] = pads[0]
	var pad_top: Array[float] = pads[1]
	var belly: PackedFloat64Array = ship_model.call("belly_under", points)
	var y := -INF
	for k in points.size():
		if not is_inf(belly[k]):
			y = maxf(y, pad_top[k] - top - belly[k])
	if is_inf(y):
		y = -bounds.position.y
	# Clear of the beams: the cross beams and side beams' tops, and the floor.
	var flange := 0.4 if str(cradle.get("size")) == "s" else 0.6
	var beams: Array = []
	for z: float in spec.cross_z:
		beams.append([Rect2(-side_x, z - 0.2, side_x * 2.0, 0.4), float(spec.cross_h)])
	for sx: float in [-side_x, side_x]:
		beams.append([Rect2(sx - flange * 0.5, -float(spec.length) * 0.5, flange, float(spec.length)), float(spec.side_h)])
	for b: Array in beams:
		var r: Rect2 = b[0]
		var low: float = ship_model.call("lowest_in", Rect2(r.position - on, r.size))
		if not is_inf(low):
			y = maxf(y, float(b[1]) + 0.02 - top - low)
	y = maxf(y, -TransportCradle.REST + 0.05 - top - bounds.position.y)
	return Vector3(shift.x, y, shift.y)


## The scissor lift and the ground power unit, for a model that says where its
## side door and power socket are.
func _build_access() -> void:
	if access:
		access.queue_free()
		access = null
	if model == null or not model.has_method("access_points"):
		return
	var points: Dictionary = model.call("access_points")
	access = Access.new()
	access.name = "Access"
	add_child(access)
	var sill: Vector3 = points["side_door"] + seat
	var socket: Vector3 = points["power_socket"] + seat
	# The flank and roof stops go up with the ship (and a taller ship's roof is a stop of its
	# own, as high as the lift goes).
	var levels: Array[float] = []
	for h: float in access.get("lift_levels"):
		levels.append(h if h < 1.0 else h + cradle_height - 1.6 + seat.y)
	var roof := cradle_height + seat.y + _bus_bounds_top() - 0.1 if model is FileShip else 0.0
	if roof > levels[levels.size() - 1] + 1.0:
		levels.append(minf(roof, Access.MAX_LIFT))
	access.set("lift_levels", levels)
	if cradle:
		# Outboard of the cradle's side beam and its pin levers, with a gangway over them.
		var clear := float(cradle.get("side_x")) + 0.2 + 0.35 + 0.05
		access.call("build", cradle_height, sill, socket, ship_root, maxf(clear - absf(sill.x), 0.0),
				TransportCradle.REST + float(TransportCradle.SIZES[str(cradle.get("size"))].side_h) + 0.15)
	else:
		access.call("build", cradle_height, sill, socket, ship_root)
	access.connect("power_switched", func(on: bool) -> void:
		if _bus:
			_bus.set_ship_powered(on)
		else:
			_on_power(on))
	var on := _bus != null and _bus.ship_powered
	access.call("set_power", on)
	_on_power(on, true)


## The ship powered or not; `instant` skips its power-up sweep (on loading).
func _on_power(on: bool, instant := false) -> void:
	if model and model.has_method("set_powered"):
		model.call("set_powered", on, instant)
	if access:
		access.call("set_power", on)


func _unhandled_input(event: InputEvent) -> void:
	var use: bool = event.is_action_pressed(Keys.INTERACT) if InputMap.has_action(Keys.INTERACT) \
			else (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F)
	if not use or event.is_echo():
		return
	var cam := get_viewport().get_camera_3d()
	if cam and use_along(cam.global_position, -cam.global_basis.z):
		get_viewport().set_input_as_handled()


## Left click: with the power plug in hand it goes where you look; else the first clickable
## thing within reach (the plug, its hook). _input, so a held tool doesn't take the click.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	# A screen in front of the view (the wrist holo, a menu) keeps its clicks.
	if get_viewport().gui_get_hovered_control() != null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if click_along(cam.global_position, -cam.global_basis.z):
		get_viewport().set_input_as_handled()


## A left click along the ray (world space): places the plug in hand, or clicks the first
## clickable thing within reach. True if it did something.
func click_along(from: Vector3, direction: Vector3) -> bool:
	if access and bool(access.call("holding_plug")):
		access.call("place_plug", from, direction)
		return true
	return _call_along(from, direction, "ship_bay_click")


## Use (F): the first usable thing within reach along the ray (world space). True if one was.
func use_along(from: Vector3, direction: Vector3) -> bool:
	return _call_along(from, direction, "ship_bay_use")


func _call_along(from: Vector3, direction: Vector3, meta: String) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, from + direction.normalized() * USE_REACH)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return false
	var body := hit.collider as CollisionObject3D
	var owner_id := body.shape_find_owner(int(hit.shape)) if body else -1
	var node: Object = body.shape_owner_get_owner(owner_id) if owner_id >= 0 else null
	for n: Object in [node, body]:
		if n and n.has_meta(meta):
			(n.get_meta(meta) as Callable).call()
			return true
	return false


## A fastener as it looks on the ship: its head (a hex bolt, a domed rivet, a round plug) on
## a thin washer ring in one quiet pale blue, tight or undone. The ring is the marker
## (Tools' look card names the state); the head is its child, so hiding the ring hides both.
## `wide`: a wreck's, whose own Void Salvage bolt and rivet heads (about 3 cm across) hid a
## ring of the Kestrel's size (Tools, 0.3.27).
func _fastener_marker(f: FastenerPoint, wide := false) -> MeshInstance3D:
	var n := f.normal.normalized()
	if f.kind == "weld" and f.seam_up != Vector3.ZERO:
		# A weld is its bead along the seam on a thin strip lit by its state.
		var along := (f.seam_up - n * f.seam_up.dot(n)).normalized()
		var strip := MeshInstance3D.new()
		var length := maxf(f.seam_size.x, 0.02)
		var width := maxf(f.seam_size.y, 0.006)
		strip.mesh = PartShapes.box(Vector3(width + 0.005, 0.002, length)).mesh
		strip.transform = Transform3D(Basis(n.cross(along), n, along), f.position + n * 0.002)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bead := MeshInstance3D.new()
		bead.mesh = PartShapes.prism(6, width * 0.5, length - 0.004).mesh
		bead.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, width * 0.25, 0))
		bead.material_override = _head_mat
		strip.add_child(bead)
		return strip
	var side := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var x := side.cross(n).normalized()
	var ring := MeshInstance3D.new()
	var big := f.kind != "rivet"
	var r_in := (0.046 if wide else 0.026) if big else (0.036 if wide else 0.017)
	ring.mesh = PartShapes.ring(r_in, r_in + (0.005 if big or wide else 0.003), 0.003, 20 if wide else 16).mesh
	ring.transform = Transform3D(Basis(x, n, x.cross(n)), f.position + n * 0.002)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var head := MeshInstance3D.new()
	match f.kind:
		"rivet":
			head.mesh = PartShapes.dome(0.014, 0.009, 8, 2).mesh
			head.position.y = 0.0045
		"connector":
			head.mesh = PartShapes.prism(12, 0.04, 0.05).mesh
			head.position.y = 0.025
		_:
			head.mesh = PartShapes.prism(6, 0.021, 0.016).mesh
			head.position.y = 0.01
	head.material_override = _head_mat
	ring.add_child(head)
	return ring


## The model's mesh pieces whose centre lies in each slot's box (ship space), for a model
## that can't say which pieces are a slot's part (`slot_pieces`).
static func pieces_by_slot(root: Node3D, def: ShipDefinition) -> Dictionary:
	var out := {}
	for s in def.slots:
		out[s.slot_id] = []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var centre := _ship_xform(mi, root) * mi.mesh.get_aabb().get_center()
		for s in def.slots:
			if s.box.has_point(centre):
				(out[s.slot_id] as Array).append(mi)
				break
	return out


## A part of this ship by its shape key (ShipBayBus.part_shape_key), for ItemLook: its pieces'
## meshes as one, in ship space, and the first one's paint; [] when it isn't this ship's.
func _part_shape(key: String) -> Array:
	if _bus == null or ship_root == null:
		return []
	var mine := _bus.part_shape_key("-")
	if mine == "" or not key.begins_with(mine.trim_suffix("-")):
		return []
	var meshes: Array = pieces.get(key.trim_prefix(mine.trim_suffix("-")), [])
	var st := SurfaceTool.new()
	var paint: Material = null
	var any := false
	for mi: MeshInstance3D in meshes:
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		var xf := _ship_xform(mi, ship_root)
		for k in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_primitive_type(k) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			st.append_from(mi.mesh, k, xf)
			any = true
		if paint == null:
			paint = mi.material_override if mi.material_override else mi.mesh.surface_get_material(0)
	if not any:
		return []
	return [st.commit(), paint]


## A slot's part as the ship built it: {mass (kg), material (the heaviest piece's)}, {} for
## a ship that doesn't say (only one built from its file does).
func _part_info(slot_id: String) -> Dictionary:
	if _importer() == null or _bus == null or _bus.ship == null:
		return {}
	var paths := {}
	for s in _bus.ship.slots:
		if s.slot_id == slot_id:
			for p: String in s.parts:
				paths[p] = true
	var by_path: Dictionary = _importer().parts_by_path
	var kg := 0.0
	var material := ""
	var top := -1.0
	for p: String in paths:
		var part: PartData = by_path.get(p)
		if part == null:
			continue
		kg += part.mass
		if part.mass > top:
			top = part.mass
			material = part.material
	return {} if kg <= 0.0 else {"mass": snappedf(kg, 0.1), "material": material}


const FAULT_WORDS := {PartData.Fault.DEAD_LAMP: "dead lamp", PartData.Fault.BREACHED: "breached",
		PartData.Fault.BLOWN_SCREEN: "blown screen", PartData.Fault.CRACKED: "cracked",
		PartData.Fault.KINKED: "kinked", PartData.Fault.DOOR_HANGING: "door hanging",
		PartData.Fault.DOOR_OFF: "door off"}
const JOINT_WORDS := ["weld", "rivet", "bolt", "connector", "spot"]


## The Void Salvage build behind the ship in the bay: a wreck's (FileShip) or the Kestrel's,
## both built from a ship file; null for a ship that isn't.
func _importer() -> VsShipImport:
	var im: Variant = model.get("importer") if model != null and is_instance_valid(model) else null
	return im if im is VsShipImport else null


## ShipBayBus.inspect_at for the ship in this bay: the part a hit on the ship's body landed
## on, everything the file and the bay know of it; {} when the hit is on something else.
func _inspect(collider: Object, shape_idx: int, _point: Vector3) -> Dictionary:
	if _importer() == null or _bus == null or _bus.ship == null or not collider is CollisionObject3D:
		return {}
	var body := collider as CollisionObject3D
	if not is_instance_valid(ship_root) or not ship_root.is_ancestor_of(body):
		return {}
	var owner_id := body.shape_find_owner(shape_idx)
	if owner_id < 0:
		return {}
	var shape_node: Object = body.shape_owner_get_owner(owner_id)
	var im := _importer()
	if _shape_parts.is_empty():
		var pm := im.kit.model
		for id: int in pm._colliders:
			_shape_parts[pm._colliders[id]] = id
		for id: int in pm._extra_colliders:
			for c: Object in pm._extra_colliders[id]:
				_shape_parts[c] = id
	if not _shape_parts.has(shape_node):
		return {}
	var part: PartData = im.kit.model.parts.get(int(_shape_parts[shape_node]))
	if part == null:
		return {}
	return part_report(part, im)


## Everything about one part of the ship in the bay (inspect_at's keys).
func part_report(part: PartData, im: VsShipImport) -> Dictionary:
	var slot: MountSlot = null
	for s in _bus.ship.slots:
		if s.parts.has(part.path):
			slot = s
			break
	var entry: Dictionary = (WreckMaker.damage_of(_bus.ship.file).get("parts", {}) as Dictionary).get(part.path, {})
	var cond: Dictionary = entry.get("condition", {})
	var wear := float(cond.get("wear", part.wear))
	var scorch := float(cond.get("scorch", part.scorch))
	var condition := _bus.fitted_condition(slot.slot_id) if slot else ShipBayBus.wreck_part_condition(wear, scorch)
	var faults: Array[String] = []
	for f: int in FAULT_WORDS:
		if part.faults & f != 0:
			faults.append(str(FAULT_WORDS[f]))
	var joints := {}
	if slot:
		for f in slot.fasteners:
			var tally: Array = joints.get(f.kind, [0, 0])
			tally[1] += 1
			if _bus.is_joint_tight(f.joint_id):
				tally[0] += 1
			joints[f.kind] = tally
	else:
		for path: String in im.joints_by_path:
			var c: ConnectionData = im.joints_by_path[path]
			if c.part_a == part.id or c.part_b == part.id:
				var word: String = JOINT_WORDS[c.kind] if c.kind < JOINT_WORDS.size() else "joint"
				var tally: Array = joints.get(word, [0, 0])
				tally[1] += 1
				if c.health > 0.0:
					tally[0] += 1
				joints[word] = tally
	var items := StorageLayout.items()
	var item: String = slot.fitted if slot and items.has(slot.fitted) else part.part_name
	var removal := part.removal
	return {
		"slot_id": slot.slot_id if slot else "",
		"slot_state": str(ShipBayBus.SlotState.keys()[_bus.get_slot_state(slot.slot_id)]).to_lower() if slot else "",
		"path": part.path,
		"name": part.part_name,
		"display_name": slot.display_name if slot and slot.display_name != "" else part.part_name.capitalize(),
		"kind": str(PartData.Kind.keys()[part.kind]).to_lower(),
		"category": str(items.get(item, {}).get("category", "")),
		"material": part.material,
		"mass_kg": snappedf(part.mass, 0.1),
		"value_new": snappedf(part.value, 1.0),
		"value_now": snappedf(part.value * condition * PartData.REMOVAL_VALUE[removal], 1.0),
		"condition": condition,
		"wear": wear,
		"scorch": scorch,
		"removal": str(PartData.Removal.keys()[removal]).to_lower(),
		"faults": faults,
		"power": str(PartData.Power.keys()[part.power]).to_lower(),
		"power_level": part.source_level() if part.power == PartData.Power.SOURCE else 0.0,
		"fluid": part.fluid,
		"litres": snappedf(part.fluid_capacity * part.fluid_level, 0.1),
		"capacity_l": part.fluid_capacity,
		"hazard": part.kind == PartData.Kind.HAZARD,
		"joints": joints,
	}


static func _ship_xform(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _on_slot_changed(slot_id: String, _old: int, _new: int) -> void:
	_apply_slot(slot_id)
	_refresh_markers()


func _apply_slot(slot_id: String) -> void:
	var gone := _bus.get_slot_state(slot_id) == ShipBayBus.SlotState.EMPTY
	for mi: MeshInstance3D in pieces.get(slot_id, []):
		mi.visible = not gone
	for c: CollisionShape3D in colliders.get(slot_id, []):
		if is_instance_valid(c):
			c.set_deferred("disabled", gone)


## A wreck's fastener points sit a couple of centimetres under its plates' faces (Void
## Salvage's flush skin grows the plate's look out over its joints), so the bay's rings were
## buried with only a sliver showing (beenster via Tools, 0.3.27). Once the ship is in the
## physics space each ring (and weld strip) moves out along its normal onto the face a ray
## straight in finds, within LIFT_REACH.
const LIFT_REACH := 0.06   # m out from the point a ray starts, and how far in it looks


func _lift_markers(def: ShipDefinition) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or ship_root == null or not is_instance_valid(ship_root):
		return
	var space := get_world_3d().direct_space_state
	var xf := ship_root.global_transform
	for s in def.slots:
		for f in s.fasteners:
			var m: MeshInstance3D = markers.get(f.joint_id)
			if m == null:
				continue
			var n := f.normal.normalized()
			var q := PhysicsRayQueryParameters3D.create(xf * (f.position + n * LIFT_REACH), xf * (f.position - n * LIFT_REACH * 0.5))
			q.hit_back_faces = false
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				continue
			var out := (xf.affine_inverse() * (hit["position"] as Vector3) - f.position).dot(n)
			if out > 0.002:
				m.position = f.position + n * (out + 0.002)


func _refresh_markers() -> void:
	for id: String in markers:
		var m: MeshInstance3D = markers[id]
		_show_joint(id)
	_on_marker_focus(_bus.marker_focus_at, _bus.marker_focus_radius)


## A joint made or taken out: its marker shows it at once (the slot's state may not change).
func _on_joint_changed(joint_id: String, _made: bool) -> void:
	if markers.has(joint_id):
		_show_joint(joint_id)


## The ring (or weld strip) is lit by the joint's state; the head (or bead) on it shows only
## while the joint is made, so an undone bolt, a cut-out rivet or a ground-off weld leaves
## just its lit ring where it was (beenster, 0.3.20). An undone bolt or rivet leaves no ring
## either (ship_bay.gone_rings; beenster, 0.3.29: "when a rivet or bolt is removed so is its
## highlight"); welds and plugs keep theirs.
func _show_joint(joint_id: String) -> void:
	var m: MeshInstance3D = markers[joint_id]
	var tight := _bus.is_joint_tight(joint_id)
	var gone := not tight and Flags.is_on("ship_bay.gone_rings") and str(m.get_meta("kind", "")) in ["bolt", "rivet"]
	m.visible = _bus.get_slot_state(FastenerPoint.slot_of(joint_id)) != ShipBayBus.SlotState.EMPTY and not gone
	m.material_override = _tight_mat if tight else _loose_mat
	for head: Node in m.get_children():
		(head as Node3D).visible = tight
	_show_file_head(joint_id, tight)


## A ship built from its file draws every joint's own head too (Void Salvage's JointView):
## gone while the joint is undone, back when it is made (0.3.26: undone bolts and cut rivets
## stayed in place).
func _show_file_head(joint_id: String, tight: bool) -> void:
	var im := _importer()
	if im == null or not _joint_paths.has(joint_id):
		return
	var c := im.joint_at(str(_joint_paths[joint_id]))
	if c == null or im.kit == null or im.kit.model == null:
		return
	var pm := im.kit.model
	if not tight or _no_file_head.has(joint_id):
		var view := pm.forget_view(c)
		if view:
			view.clear()
	elif pm.joint_view(c) == null and pm.parts.has(c.part_a):
		pm.remake_view(c, pm.parts[c.part_a])


## Only the rings near the focus point show (ShipBayBus.set_marker_focus); the heads always
## do. A ring out of focus drops its mesh (the head is its child, so hiding it would hide both).
func _on_marker_focus(at: Vector3, radius_m: float) -> void:
	if ship_root == null:
		return
	var local := ship_root.global_transform.affine_inverse() * at
	for id: String in markers:
		var m: MeshInstance3D = markers[id]
		if not m.has_meta("ring_mesh"):
			m.set_meta("ring_mesh", m.mesh)
		var near := is_inf(radius_m) or m.position.distance_to(local) <= radius_m
		m.mesh = m.get_meta("ring_mesh") if near else null


static func _quiet_ring() -> StandardMaterial3D:
	var m := _paint(QUIET_RING, true)
	m.emission_energy_multiplier = QUIET_GLOW
	return m


static func _paint(c: Color, lit := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	if lit:
		m.emission_enabled = true
		m.emission = c
	return m
