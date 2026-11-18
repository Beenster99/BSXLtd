class_name YardBus
extends Node
## Orbital yard module bus (Modules.bus("yard")). The place the game happens: a station with
## gravity (design room, contracts desk, racking hall for stock, crew room, airlock) and,
## outside its windows, the weightless dock with one build berth and two holding berths over
## a planet. Master plan Wave 1, stages 1.1 (station) and 1.2 (dock).
##
## Station space: metres, floor y = 0, -Z towards the dock, +X towards the racking hall.
##
## Other modules furnish rooms through this bus instead of reaching into the scene:
##   var yard := Modules.bus("yard") as YardBus
##   yard.station_ready.connect(func(station): ...)
##   var root := yard.design_room_root()        # add the design room's contents here
##   for m in yard.design_room_mounts(): ...     # {id, transform, size} TV and whiteboard spots
## The design room's root sits at the room's floor centre: +X right, -Z towards the window,
## y = 0 the floor. Its middle rectangle (DESIGN_CLEAR_SIZE) is left empty for the holotable.

## The station scene was built (and its rooms are ready to furnish).
signal station_ready(station: Node3D)
## The scene closed.
signal station_closed

const SCENE := "yard.station"
const SCENE_PATH := "res://modules/yard/internal/station.tscn"
const FLAG := "yard"
## Stage flags (each needs "yard" on too).
const STATION := "yard.station"
const DOCK := "yard.dock"
const RACKING := "yard.racking"

## The design room's inside (m): width (x), height, depth (z).
const DESIGN_ROOM_SIZE := Vector3(24, 6, 18)
## Its floor centre in station space.
const DESIGN_ROOM_CENTRE := Vector3(0, 0, -13)
## The clear rectangle in its middle, kept free for the holotable (m: along x, along z),
## centred on the room root and marked on the floor.
const DESIGN_CLEAR_SIZE := Vector2(10, 6)
## The old clear circle's radius (m): the rectangle holds it. Kept until the design room's
## test reads DESIGN_CLEAR_SIZE.
const DESIGN_CLEAR_RADIUS := 3.0

## The racking hall's store (shared by the scene and anyone who asks while it is open).
var rack_store: YardRackStore
var _station: Node3D


func register_module() -> void:
	if not Flags.is_on(STATION):
		return
	Router.register_scene(SCENE, SCENE_PATH)
	# The new game starts in the orbital yard, ahead of the old yard by the sea (priority 10).
	Menu.set_start(SCENE, 20)
	Keys.register("yard.up", "Fly up (in zero g)", KEY_SPACE, "Orbital yard")
	Keys.register("yard.down", "Fly down (in zero g)", KEY_CTRL, "Orbital yard")
	Keys.register("yard.brake", "Stop drifting (in zero g)", KEY_X, "Orbital yard")
	Keys.register("yard.roll_left", "Roll left (in zero g)", KEY_Q, "Orbital yard")
	Keys.register("yard.roll_right", "Roll right (in zero g)", KEY_E, "Orbital yard")
	Keys.register("yard.dampeners", "Suit dampeners on / off", KEY_Z, "Orbital yard")
	Keys.register("yard.lamp", "Helmet lamp", KEY_L, "Orbital yard")
	Keys.register("yard.view", "First / third person", KEY_V, "Orbital yard")
	var names := ["grinder", "cutter", "socket", "grabber", "tractor", "beam tablet"]
	for i in names.size():
		Keys.register("yard.tool_%d" % (i + 1), "Tool %d (%s)" % [i + 1, names[i]], KEY_1 + i, "Orbital yard")
	Keys.register("yard.holster", "Put the tool away", KEY_H, "Orbital yard")
	for view: String in ["station_outside", "corridor", "design_room", "design_window", "racking_front",
			"racking_aisle", "contracts", "crew", "airlock"]:
		Shots.register("yard_" + view, SCENE, func(scene: Node) -> void: scene.call("show_view", view))
	if Flags.is_on(DOCK):
		for view: String in ["dock", "build_berth", "holding_berths", "station_from_berth"]:
			Shots.register("yard_" + view, SCENE, func(scene: Node) -> void: scene.call("show_view", view))


func unregister_module() -> void:
	Menu.clear_start(SCENE)


## The open station scene, or null.
func station() -> Node3D:
	return _station if is_instance_valid(_station) else null


## Where the design room's contents go (see the header), or null while no station is open.
func design_room_root() -> Node3D:
	var s := station()
	return s.get_node_or_null("DesignRoomRoot") as Node3D if s else null


func design_room_size() -> Vector3:
	return DESIGN_ROOM_SIZE


## The design room's wall spots, in the room root's space: {id, transform, size (Vector2,
## m)}. The transform's origin is the spot's middle on the wall's face and its -Z points
## into the room (a screen there faces the room). Ids are stable: tv_left_1..3,
## tv_right_1..3 (front to back), whiteboard.
static func design_room_mounts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var half := DESIGN_ROOM_SIZE * 0.5
	for i in 3:
		var z := -5.0 + 4.5 * i   # towards the window first
		# Left wall (x = -12): facing +X, so -Z of the spot points +X.
		out.append({"id": "tv_left_%d" % (i + 1), "size": Vector2(2.4, 1.4),
				"transform": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-half.x + 0.06, 2.2, z))})
		out.append({"id": "tv_right_%d" % (i + 1), "size": Vector2(2.4, 1.4),
				"transform": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(half.x - 0.06, 2.2, z))})
	# The back wall (z = +9, the corridor side), left of the door: facing -Z already.
	out.append({"id": "whiteboard", "size": Vector2(10, 3),
			"transform": Transform3D(Basis.IDENTITY, Vector3(-4.0, 2.2, half.z - 0.06))})
	return out


## Station rooms by id: {name, box (AABB, station space)}.
static func rooms() -> Dictionary:
	return YardLayout.ROOMS.duplicate(true)


## The room a station-space point is in, or "" (outside, in the dock).
static func room_at(point: Vector3) -> String:
	return YardLayout.room_at(point)


## True where the station's gravity holds (inside its hull), false in the weightless dock.
static func has_gravity(point: Vector3) -> bool:
	return YardLayout.has_gravity(point)


## The dock's berths: {id, name, kind ("build" or "holding"), box (AABB, station space)}.
static func berths() -> Array[Dictionary]:
	return YardLayout.berths()


func _station_opened(s: Node3D) -> void:
	_station = s
	station_ready.emit(s)


func _station_closed(s: Node3D) -> void:
	if _station == s:
		_station = null
		station_closed.emit()
