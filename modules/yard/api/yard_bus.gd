class_name YardBus
extends Node
## Orbital yard module bus (Modules.bus("yard")). The place the game happens: a station with
## gravity (design room, contracts desk, stores hall, crew room, airlock) and,
## outside its windows, the weightless dock with one build berth and two holding berths, in
## deep space. Master plan Wave 1, stages 1.1 (station) and 1.2 (dock).
##
## Station space: metres, floor y = 0, -Z towards the dock, +X towards the racking hall.
##
## Other modules furnish rooms through this bus instead of reaching into the scene:
##   var yard := Modules.bus("yard") as YardBus
##   yard.station_ready.connect(func(station): ...)
##   var root := yard.design_room_root()        # add the design room's contents here
##   for w in yard.design_room_walls(): ...      # {id, transform, size} whole wall planes for screens
## The design room's root sits at the room's floor centre: +X right, -Z towards the window,
## y = 0 the floor. Its middle rectangle (DESIGN_CLEAR_SIZE) is left empty for the holotable.

## The station scene was built (and its rooms are ready to furnish).
signal station_ready(station: Node3D)
## The scene closed.
signal station_closed
## Worker bots in the build berth need TartanCo (one faulted, or worn past its call point): the
## bots to see to (Node3Ds, see worker_bots). Sent once until they've all been seen to. While
## anything is connected here, the yard's own stand-in service visit stays away and the
## listener (the TartanCo maintenance ship) does the servicing:
##   yard.workers_need_service.connect(func(bots): ...)
##   yard.worker_condition(bot)      # {productivity 0..1, errors: Array[String], wear, model, serial}
##   yard.begin_worker_service(bot)  # it stops work and keeps still: yours to move or hold
##   yard.end_worker_service(bot)    # as new, its errors cleared, back to work
## Each bot has metas "tartanco_model" (W-3, R-3, B-3, F-3) and "serial".
signal workers_need_service(bots: Array)
## The yard's shared clock: an event was logged for a tick (see yard_sim.gd).
signal sim_logged(entry: Dictionary)
## The shared clock started again from another moment (a new session's yard).
signal sim_reset

const SCENE := "yard.station"
const SCENE_PATH := "res://modules/yard/internal/station.tscn"
const FLAG := "yard"
## Stage flags (each needs "yard" on too).
const STATION := "yard.station"
const DOCK := "yard.dock"
const RACKING := "yard.racking"
## The freight lines' own couriers, haulers and freighters (19 Nov), else the 0.4.1 looks.
const DELIVERY_SHIPS := "yard.delivery_ships"

## The design room's inside (m): width (x), the side walls' height, depth (z).
const DESIGN_ROOM_SIZE := Vector3(24, 6, 18)
## The top of its glass barrel vault, which runs from the window to the back (m over the floor).
const DESIGN_ROOM_PEAK := 11.0
## The mezzanine along its back wall: its deck's top over the floor and its depth (m).
const DESIGN_MEZZANINE_Y := 3.4
const DESIGN_MEZZANINE_DEPTH := 4.0
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

## The yard's shared clock (co-op sync, 19 Nov): tick 0 on the host's clock (s, the Multiplayer
## module's server_time), -1 until known, and what players did, stamped with the tick it
## happens at: [{kind, tick, n, peer, ...}] in order. The station's YardSim runs to it.
const SIM_EVENT := "yard.sim"
const SIM_TICK := 1.0 / 60.0
## How far ahead the host stamps what a player does (ticks: half a second, for the trip out).
const SIM_LEAD := 30
var sim_epoch := -1.0
var sim_log: Array[Dictionary] = []
var _sim_n := 0
var _net: Object


func register_module() -> void:
	if not Flags.is_on(STATION):
		return
	Router.register_scene(SCENE, SCENE_PATH)
	Router.set_loading_title(SCENE, "Orbital yard")
	# The new game starts in the orbital yard, ahead of the old yard by the sea (priority 10).
	Menu.set_start(SCENE, 20)
	_hook_net.call_deferred()
	Keys.register("yard.up", "Fly up (in zero g)", KEY_SPACE, "Orbital yard")
	Keys.register("yard.down", "Fly down (in zero g)", KEY_CTRL, "Orbital yard")
	Keys.register("yard.brake", "Stop drifting (in zero g)", KEY_X, "Orbital yard")
	Keys.register("yard.roll_left", "Roll left (in zero g)", KEY_Q, "Orbital yard")
	Keys.register("yard.roll_right", "Roll right (in zero g)", KEY_E, "Orbital yard")
	Keys.register("yard.dampeners", "Suit dampeners on / off", KEY_Z, "Orbital yard")
	Keys.register("yard.lamp", "Helmet lamp", KEY_L, "Orbital yard")
	Keys.register("yard.view", "First / third person", KEY_V, "Orbital yard")
	var names := ["grinder", "cutter", "socket", "grabber", "tractor", "beam tablet", "riveter", "welder"]
	for i in names.size():
		Keys.register("yard.tool_%d" % (i + 1), "Tool %d (%s)" % [i + 1, names[i]], KEY_1 + i, "Orbital yard")
	Keys.register("yard.holster", "Put the tool away", KEY_H, "Orbital yard")
	Keys.register("yard.kit", "Call a mover bot with the next kit", KEY_K, "Orbital yard")
	for view: String in ["station_outside", "corridor", "design_room", "design_vault", "design_mezzanine", "design_window", "design_lock", "stores_hall",
			"stores_long", "stores_components", "stores_heavy", "stores_goods_in", "stores_yard_side",
			"stores_deliveries", "stores_put_away", "stores_to_yard", "contracts", "crew", "airlock"]:
		Shots.register("yard_" + view, SCENE, func(scene: Node) -> void: scene.call("show_view", view))
	if Flags.is_on(DOCK):
		for view: String in ["dock", "build_berth", "holding_berths", "station_from_berth"]:
			Shots.register("yard_" + view, SCENE, func(scene: Node) -> void: scene.call("show_view", view))


func unregister_module() -> void:
	Menu.clear_start(SCENE)


## The open station scene, or null.
func station() -> Node3D:
	return _station if is_instance_valid(_station) else null


## Buys parts for the stores: [{part, qty}...] (YardRackStore.PARTS ids). Haulers bring them
## to goods in and bots put them away. Nothing happens while no station is open.
func order_parts(items: Array) -> void:
	sim_request({"kind": "order", "items": items})


## Asks for parts at the yard side: bots take them off the racks and out to the build berth.
func send_to_yard(items: Array) -> void:
	sim_request({"kind": "send", "items": items})


func _traffic() -> Node:
	var s := station()
	return s.get("traffic") as Node if s else null


## Where the design room's contents go (see the header), or null while no station is open.
func design_room_root() -> Node3D:
	var s := station()
	return s.get_node_or_null("DesignRoomRoot") as Node3D if s else null


func design_room_size() -> Vector3:
	return DESIGN_ROOM_SIZE


## The design room's walls as whole planes for screens (0.4.0 playtest: "the walls themselves
## should be interactive"), in the room root's space: {id, transform, size (Vector2, m)}, the
## convention the old mounts had (origin the plane's middle on the wall's face, -Z into the
## room). Nothing of the station's stands on them. Ids: wall_left, wall_right (the side walls
## in front of the stair and the mezzanine), wall_back_low_left and wall_back_low_right
## (under the mezzanine, either side of the corridor door), wall_back_high (above it).
static func design_room_walls() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var half := DESIGN_ROOM_SIZE * 0.5
	var c := DESIGN_ROOM_CENTRE
	# Side walls: from just off the window wall to in front of the stair's landing.
	var z0 := -21.7 - c.z
	var z1 := -9.8 - c.z
	var side := Vector2(z1 - z0, 5.5)
	out.append({"id": "wall_left", "size": side,
			"transform": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-half.x + 0.06, 0.3 + side.y * 0.5, (z0 + z1) * 0.5))})
	out.append({"id": "wall_right", "size": side,
			"transform": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(half.x - 0.06, 0.3 + side.y * 0.5, (z0 + z1) * 0.5))})
	# The back wall (z = +9 in the root), under the mezzanine either side of the door
	# (x 5..7.5) and above it.
	var back := half.z - 0.06
	for p: Array in [["wall_back_low_left", -11.7, 4.8], ["wall_back_low_right", 7.7, 11.7]]:
		var x0: float = p[1]
		var x1: float = p[2]
		out.append({"id": p[0], "size": Vector2(x1 - x0, 2.7),
				"transform": Transform3D(Basis.IDENTITY, Vector3((x0 + x1) * 0.5, 0.3 + 1.35, back))})
	out.append({"id": "wall_back_high", "size": Vector2(23.4, 2.2),
			"transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 4.7, back))})
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
	_hook_net()
	sim_start()
	var crew := _workers()
	if crew and crew.has_signal("service_needed"):
		crew.connect("service_needed", func(bots: Array) -> void: workers_need_service.emit(bots))
	station_ready.emit(s)


## The worker bots building in the build berth (TartanCo's androids), [] while no station is
## open.
func worker_bots() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var crew := _workers()
	if crew:
		out.assign(crew.call("bots"))
	return out


## A worker bot's condition: {productivity 0..1 (0 while it has an error), errors, wear, model,
## serial}, or {} for a node that isn't one.
func worker_condition(bot: Node3D) -> Dictionary:
	var crew := _workers()
	return crew.call("condition", bot) if crew else {}


## TartanCo's engineers take a worker bot: it puts its job down and keeps still till
## end_worker_service. False if it isn't one.
func begin_worker_service(bot: Node3D) -> bool:
	var crew := _workers()
	return bool(crew.call("begin_service", bot)) if crew else false


## TartanCo's engineers are done with a worker bot: as new, back to work.
func end_worker_service(bot: Node3D) -> void:
	var crew := _workers()
	if crew:
		crew.call("end_service", bot)


func _workers() -> Node:
	var s := station()
	return s.get("workers") as Node if s else null


func _station_closed(s: Node3D) -> void:
	if _station == s:
		_station = null
		station_closed.emit()


# --- The shared clock ------------------------------------------------------------------------

func _hook_net() -> void:
	if _net != null and is_instance_valid(_net):
		return
	_net = Modules.bus("multiplayer")
	if _net == null:
		return
	_net.call("register_event", SIM_EVENT, _sim_apply, _sim_validate)
	_net.call("register_snapshot_provider", "yard", self)
	if _net.has_signal("session_ended"):
		_net.connect("session_ended", _on_session_ended)


## Plays through this Multiplayer bus (tests run two players in one process).
func use_net(net: Object) -> void:
	_net = net
	_net.call("register_event", SIM_EVENT, _sim_apply, _sim_validate)
	_net.call("register_snapshot_provider", "yard", self)


func _now() -> float:
	return float(_net.call("server_time")) if _net else Time.get_ticks_usec() / 1_000_000.0


## The tick the yard should be at now, or -1 while the clock is not known.
func sim_target_tick() -> int:
	if sim_epoch < 0.0:
		return -1
	# A guest's clock is the host's only once a ping has come back.
	if _net and bool(_net.call("is_online")) and not bool(_net.call("is_host")) and float(_net.call("round_trip")) <= 0.0:
		return -1
	return maxi(-1, floori((_now() - sim_epoch) / SIM_TICK))


## The station opened: start the clock, or ask the host for the one the others are on.
func sim_start() -> void:
	if _net == null or not bool(_net.call("is_online")):
		sim_epoch = _now()
		sim_log.clear()
		return
	if not bool(_net.call("is_host")):
		sim_epoch = -1.0   # wait for the host's answer
	sim_request({"kind": "epoch"})


## Asks for something to happen in the yard at a tick every player agrees on.
func sim_request(entry: Dictionary) -> void:
	if _net:
		_net.call("request", SIM_EVENT, entry)
		return
	var out: Variant = _sim_validate(1, entry)
	if out is Dictionary:
		_sim_apply(out)


func _sim_validate(sender: int, p: Dictionary) -> Variant:
	var out := p.duplicate(true)
	if String(p.get("kind", "")) == "epoch":
		out.fresh = sim_epoch < 0.0 or not _anyone_in_yard(sender)
		out.epoch = _now() + 0.1 if out.fresh else sim_epoch
		return out
	if sim_epoch < 0.0:
		return "the yard's clock has not started"
	_sim_n += 1
	out.n = _sim_n
	out.peer = sender
	var online := _net != null and bool(_net.call("is_online"))
	out.tick = maxi(0, sim_target_tick()) + (SIM_LEAD if online else 0)
	return out


func _sim_apply(p: Dictionary) -> void:
	if String(p.get("kind", "")) == "epoch":
		var changed := not is_equal_approx(float(p.epoch), sim_epoch)
		if bool(p.get("fresh", false)):
			sim_log.clear()
		sim_epoch = float(p.epoch)
		if changed:
			sim_reset.emit()
		return
	var at := sim_log.size()
	while at > 0 and int(sim_log[at - 1].tick) > int(p.tick):
		at -= 1
	sim_log.insert(at, p)
	sim_logged.emit(p)


## Someone other than `sender` has the yard open (the host's own station, or a player's held
## state says so).
func _anyone_in_yard(sender: int) -> bool:
	var me := int(_net.call("local_peer_id")) if _net else 1
	if sender != me and station() != null:
		return true
	if _net == null or not bool(_net.call("is_online")):
		return false
	for peer: int in _net.call("peers"):
		if peer != sender and peer != me and bool((_net.call("held", peer) as Dictionary).get("yard", false)):
			return true
	return false


## A guest left the host's session: the clock goes on from where it is on this machine's own.
func _on_session_ended(_reason: String = "") -> void:
	if sim_epoch < 0.0 or station() == null:
		sim_epoch = -1.0
		return
	var sim: Node = station().get("sim")
	var at := int(sim.get("tick")) if sim else 0
	# The Multiplayer module's clock is this machine's own again now.
	sim_epoch = _now() - at * SIM_TICK


func get_net_snapshot() -> Dictionary:
	return {"epoch": sim_epoch, "log": sim_log.duplicate(true)}


func apply_net_snapshot(data: Dictionary) -> void:
	var epoch := float(data.get("epoch", -1.0))
	if is_equal_approx(epoch, sim_epoch):
		return
	sim_epoch = epoch
	sim_log.assign(data.get("log", []))
	sim_reset.emit()
