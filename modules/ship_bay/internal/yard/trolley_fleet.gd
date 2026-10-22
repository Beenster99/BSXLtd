extends Node3D
## The yard's hover trolleys and what they are doing. Built by the shipyard on every peer:
## three trolleys (small, medium, large) parked in Deliveries, the picking lift in the
## stores, the two refurbishment lines' own trolleys ("a", "b") at the ends of their lines,
## and the route planner (YardNav) once the yard's collision is in.
##
## Commands come from ShipBayBus.command_trolley (every peer hears them). The peer driving a
## trolley (Multiplayer.drives "trolley:<id>": the host, or a player who claimed it for
## remote control) runs its job, plans its routes and moves it; the others follow the mover
## stream. Jobs: come to a player, put deliveries away (to the crate, load it, to its place
## in the stores, raise the deck, store it, lower, the next one), park, and fetch: the
## picking lift drives down the aisle to the goods, raises its carriage to the shelf, reaches
## in and pulls them off, comes out to its hand-over point and passes them to a free
## trolley, which brings them to whoever asked and waits there (bulk goods the large trolley
## fetches itself).
##
## Keys (rebindable in Settings > Key binds): T calls the medium trolley to you (Shift+T the large, Ctrl+T the small). F on a
## trolley takes it on remote control (arrow keys drive it, Page Up and Page Down raise and
## lower the deck, which you can ride for work at height); F on it again lets it go. F on a
## trolley that brought you goods takes them.

const Trolley := preload("res://modules/ship_bay/internal/yard/hover_trolley.gd")
const Nav := preload("res://modules/ship_bay/internal/yard/yard_nav.gd")
const Layout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")
const Screen := preload("res://modules/ship_bay/internal/yard/trolley_panel.gd")
const WristStock := preload("res://modules/ship_bay/internal/yard/wrist_stock.gd")
const WristMachines := preload("res://modules/ship_bay/internal/yard/wrist_machines.gd")
const RemoteView := preload("res://modules/ship_bay/internal/yard/remote_view.gd")
const RefurbLine := preload("res://modules/ship_bay/internal/yard/refurb_line.gd")
const CrusherPlant := preload("res://modules/ship_bay/internal/yard/crusher_plant.gd")
const CargoBeam := preload("res://modules/ship_bay/internal/yard/cargo_beam.gd")
const ItemLook := preload("res://modules/ship_bay/internal/yard/item_look.gd")
## While a clean-up has parts no trolley was free for, how often it asks again, seconds.
const CLEAN_UP_RETRY := 1.5

## Parking bays in Deliveries, by the east wall: trolley id -> [floor point, yaw]. The lift
## parks in the stores, each line's trolley under the end of its line.
const PARKING := {
	"s": [Vector3(-30.0, 0, 14.0), 0.0],
	"m": [Vector3(-33.6, 0, 14.0), 0.0],
	"l": [Vector3(-32.2, 0, -8.4), 0.0],
	"p": [Vector3(-3.2, 0, -33.0), 0.0],
	"a": [Vector3(35.0, 0, 15.6), 0.0],
	"b": [Vector3(45.0, 0, 15.6), 0.0],
}
## The stores' hand-in, in Deliveries east of the doorway into the stores: a trolley stands
## along the east wall, its nose to the partition (stores_in), and the picking lift beside it,
## facing it, loads or unloads it: [floor point, yaw].
const HANDOFF := [Vector3(-34.2, 0, -20.0), -PI * 0.5]
const HANDOFF_TROLLEY := [Vector3(-31.2, 0, -20.0), 0.0]
## The full-size trolley screen's size, pixels. (Every hall TV, Business's, shows trolley
## control as the wrist's Machines channel, so the yard has no trolley TV of its own.)
const TV_PIXELS := Vector2(1280, 720)
## How long a trolley waits held up before it plans a new way round, seconds.
const REPLAN_AFTER := 3.0
## How far behind you a following trolley keeps, past its own radius, metres.
const FOLLOW_GAP := 1.6

## How far the remote control's Page Up and Page Down move the deck per second, metres.
@export var remote_lift_rate := 0.8
## How much a pixel of mouse movement turns a trolley on remote (1 = full turn input).
@export var remote_mouse_turn := 0.06

var trolleys: Dictionary = {}       # id -> HoverTrolley
var jobs: Dictionary = {}           # id -> {do, phase, crate, place, goal, yaw}
var nav: Nav
## The trolley this player drives by remote control, or "".
var remote_id := ""
## The picture-in-picture window while driving on remote, else null.
var remote_view: CanvasLayer
## The trolley following this player ("" for none), and where it was last told they are.
var following := ""
var _follow_sent := Vector3.INF
var _follow_clock := 0.0
var _mouse_turn := 0.0
var yard: Node3D
var _bus: ShipBayBus
var _net: Node
var _reserved_places: Dictionary = {}   # location id -> trolley id
var _reserved_crates: Dictionary = {}   # crate id -> trolley id
## Aisle letter -> the trolley working in it. An aisle is one trolley wide: the others wait.
var _aisles: Dictionary = {}
## Fetches waiting for a trolley that is busy: id -> [args, ...].
var _queue: Dictionary = {}
## The screen a player opened with F on the TV (null when shut), and the one on the TV.
var panel: Screen
var _deck_send := 0.0
## Goods being beamed between trolleys, the floor and the shelves (presentation).
var beams: CargoBeam
## Where each crate was last drawn: crate id -> {"t": trolley id} or {"at": Vector3}, with
## its goods {item, qty, condition}; and those a trolley just gave up into the stores
## (crate_stored says where).
var _where: Dictionary = {}
var _left: Dictionary = {}
## Location id -> how many goods are still in the air on their way onto it (the shipyard
## draws the shelf without them till they land).
var arriving: Dictionary = {}
var _clean_clock := 0.0


func _ready() -> void:
	name = "Trolleys"
	_bus = Modules.bus("ship_bay") as ShipBayBus
	_net = Modules.bus("multiplayer")
	if _net and not _net.has_method("register_mover"):
		_net = null
	beams = CargoBeam.new()
	beams.name = "CargoBeams"
	add_child(beams)
	for id: String in ["s", "m", "l", "p", "a", "b"]:
		var t := Trolley.new()
		add_child(t)
		t.setup(id, PARKING[id][0], PARKING[id][1])
		var use := Callable(self, "use_trolley").bind(id)
		t.set_meta("ship_bay_use", use)
		t.deck.set_meta("ship_bay_use", use)
		t.screen_action.connect(_on_screen_action.bind(id))
		trolleys[id] = t
		jobs[id] = {}
		if _net:
			_net.call("register_mover", "trolley:" + id, t)
	# The wrist screen's Stock and Machines channels.
	if _bus:
		HudSlots.register_holo_channel("ship_bay.stock", "Stock", func(glass: bool) -> Control:
			return WristStock.new(_bus, self, glass), 20)
	HudSlots.register_holo_channel("ship_bay.machines", "Machines", func(glass: bool) -> Control:
		return WristMachines.new(self, glass), 40)
	if _bus:
		_bus.fleet = self
		_bus.part_beamed.connect(_on_beamed)
		_bus.trolley_command.connect(_on_command)
		_bus.crate_carried.connect(_on_carried)
		_bus.crate_stored.connect(_on_stored)
		_bus.crate_stored.connect(_beam_into_stores)
		_bus.stock_picked.connect(_beam_off_shelf)
		_bus.stock_changed.connect(_refresh_cargo)
		_refresh_cargo()
		# A trolley that was carrying a delivered crate when the game was saved finishes the job.
		for id: String in trolleys:
			var held := _bus.trolley_cargo(id)
			if held == "" or not _drives(id):
				continue
			var info := _bus.crate_info(held)
			if trolleys[id].is_picker() and not info.has("to"):
				jobs[id] = {"do": "put_away", "phase": "find"}
			elif not info.has("to"):
				_next_job(id, trolleys[id])
			elif trolleys[id].is_picker():
				# Picked goods still on the lift: hand them over.
				var to: Array = info["to"]
				jobs[id] = {"do": "fetch", "phase": "lowering", "crate": held, "to": Vector3(to[0], 0, to[1])}


func _exit_tree() -> void:
	HudSlots.unregister_holo_channel("ship_bay.stock")
	HudSlots.unregister_holo_channel("ship_bay.machines")
	if _bus:
		if _bus.fleet == self:
			_bus.fleet = null
		for pair: Array in [[_bus.part_beamed, _on_beamed], [_bus.trolley_command, _on_command], [_bus.crate_carried, _on_carried],
				[_bus.crate_stored, _on_stored], [_bus.stock_changed, _refresh_cargo],
				[_bus.crate_stored, _beam_into_stores], [_bus.stock_picked, _beam_off_shelf]]:
			if (pair[0] as Signal).is_connected(pair[1]):
				(pair[0] as Signal).disconnect(pair[1])
	if _net:
		for id: String in trolleys:
			_net.call("unregister_mover", "trolley:" + id)
		if remote_id != "":
			_net.call("release", "trolley:" + remote_id)


## Builds the route planner from the yard's collision (the trolleys themselves left out).
func build_nav() -> void:
	nav = Nav.new()
	var skip: Array = []
	for t: Node in trolleys.values():
		skip.append(t)
		skip.append(t.get("deck"))
	nav.build(yard if yard else get_parent(), skip)


func _physics_process(delta: float) -> void:
	if nav == null:
		build_nav()
	if _bus and _bus.cleaning:
		_clean_clock -= delta
		if _clean_clock <= 0.0:
			_clean_clock = CLEAN_UP_RETRY
			_bus.clean_up()
	_lead(delta)
	for id: String in trolleys:
		var t: Trolley = trolleys[id]
		t.lift_step(delta)
		if id != remote_id:
			_ride_keys(t, delta)
		t.driving = _drives(id)
		if not t.driving:
			t.sync_yaw()
			continue
		if id == remote_id:
			_remote_input(t, delta)
		else:
			t.drive_input = Vector2.ZERO
			t.boost = false
			_run_job(id, t)
		t.step(delta, _obstacles(t))
		if t.blocked_for > REPLAN_AFTER and not t.path.is_empty() and not _has_way(t):
			_go(t, t.path[t.path.size() - 1], t.final_yaw, true)
			t.blocked_for = 0.0
	_free_aisles()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if not (event.is_action_pressed("ship_bay.call_trolley") if InputMap.has_action("ship_bay.call_trolley") else key.physical_keycode == KEY_T):
		return
	var id := "l" if key.shift_pressed else ("s" if key.ctrl_pressed else "m")
	call_to_me(id)
	get_viewport().set_input_as_handled()


## Has the next part the ship in the bay is missing fetched to this player: the first empty
## slot that takes something the stores hold. False when there is nothing to fetch.
func fetch_for_ship() -> bool:
	var part := next_part_for_ship()
	if part == "":
		return false
	_bus.fetch_stock(part, 1, _player_position())
	return true


## The part the next empty slot of the ship in the bay takes and the stores hold ("" when
## none), leaving out parts already picked and on their way.
func next_part_for_ship() -> String:
	if _bus == null or _bus.ship == null:
		return ""
	var coming := {}
	for c: Dictionary in _bus.picked_crates().values():
		coming[c["item"]] = int(coming.get(c["item"], 0)) + int(c["qty"])
	for slot: MountSlot in _bus.get_slots():
		if _bus.get_slot_state(slot.slot_id) != ShipBayBus.SlotState.EMPTY:
			continue
		for part in slot.accepts:
			if _bus.stock_count(part) > 0 and int(coming.get(part, 0)) == 0:
				return part
	return ""


## Sends a trolley to where this player stands.
func call_to_me(id: String) -> void:
	if _bus:
		_bus.command_trolley(id, "come", {"to": _player_position()})


## FOLLOW ME: the trolley follows this player at a safe distance until told to stop (the
## button again, STOP FOLLOWING, or any other job for it).
func toggle_follow(id: String) -> void:
	if following == id:
		stop_following()
		if _bus:
			_bus.command_trolley(id, "stop")
		return
	stop_following()
	if remote_id == id:
		toggle_remote(id)
	following = id
	_follow_sent = _player_position()
	_follow_clock = 0.0
	trolleys[id].show_following(true)
	if _bus:
		_bus.command_trolley(id, "follow", {"to": _follow_sent, "by": _me()})


func stop_following() -> void:
	if following == "":
		return
	trolleys[following].show_following(false)
	following = ""


## While a trolley follows this player: tell its driver where they are as they move.
func _lead(delta: float) -> void:
	if following == "" or _bus == null:
		return
	_follow_clock -= delta
	if _follow_clock > 0.0:
		return
	_follow_clock = 0.3
	var here := _player_position()
	if here.distance_to(_follow_sent) > 0.5:
		_follow_sent = here
		_bus.command_trolley(following, "follow", {"to": here, "by": _me()})


## FAST on a trolley's screen: its fast mode on or off (every peer is told).
func toggle_fast(id: String) -> void:
	if _bus:
		_bus.command_trolley(id, "fast", {"on": not trolleys[id].fast})


func _me() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1


## F on a trolley: take the goods it brought you, or else take it on remote control (or let
## it go again).
func use_trolley(id: String) -> void:
	var held := _bus.trolley_cargo(id) if _bus else ""
	if held != "" and _bus.crate_info(held).has("to") and not trolleys[id].is_picker() and remote_id != id:
		_bus.collect_crate(held)
		return
	toggle_remote(id)


## A button on a trolley's own touch screen.
func _on_screen_action(action: String, id: String) -> void:
	match action:
		"call":
			toggle_follow(id)
		"fast":
			toggle_fast(id)
		"park":
			park(id)
		"remote":
			toggle_remote(id)


## Takes a trolley on remote control, or lets it go again. On remote its camera shows in a
## picture-in-picture window and W A S D and the mouse drive it; you stand still meanwhile.
func toggle_remote(id: String) -> void:
	if remote_id == id:
		remote_id = ""
		trolleys[id].drive_input = Vector2.ZERO
		if _net:
			_net.call("release", "trolley:" + id)
		if remote_view:
			remote_view.queue_free()
			remote_view = null
		_set_remote_driving(false)
		return
	if remote_id != "":
		toggle_remote(remote_id)
	if following == id:
		stop_following()
	remote_id = id
	if _bus:
		_bus.command_trolley(id, "stop")
	if _net:
		_net.call("claim", "trolley:" + id)
	remote_view = RemoteView.new()
	add_child(remote_view)
	remote_view.call("show_trolley", trolleys[id], str(trolleys[id].spec["name"]))
	_mouse_turn = 0.0
	_set_remote_driving(true)


func _set_remote_driving(on: bool) -> void:
	if _bus and _bus.remote_driving != on:
		_bus.remote_driving = on
		_bus.remote_driving_changed.emit(on)


## While on remote: the mouse turns the trolley instead of your head, and F hands it back.
func _input(event: InputEvent) -> void:
	if remote_id == "":
		return
	var motion := event as InputEventMouseMotion
	if motion:
		_mouse_turn += motion.relative.x
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and (event.is_action_pressed(Keys.INTERACT) if InputMap.has_action(Keys.INTERACT) else key.physical_keycode == KEY_F):
		toggle_remote(remote_id)
		get_viewport().set_input_as_handled()


## 1 while a bound action (or `key`, before the key map is in) is held.
func _held(action: String, key: Key) -> float:
	if InputMap.has_action(action):
		return 1.0 if Input.is_action_pressed(action) else 0.0
	return 1.0 if Input.is_physical_key_pressed(key) else 0.0


func _drives(id: String) -> bool:
	return _net == null or bool(_net.call("drives", "trolley:" + id))


## Where the player stands (the walker, or the camera when another module has the yard).
func player_position() -> Vector3:
	return _player_position()


func _player_position() -> Vector3:
	var walker := yard.get("walker") as Node3D if yard else null
	if walker and bool(yard.get("walker_active")):
		return walker.global_position
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3.ZERO


func _obstacles(t: Trolley) -> Array:
	var out: Array = []
	var walker := yard.get("walker") as Node3D if yard else null
	if walker and bool(yard.get("walker_active")):
		var p := walker.global_position
		var flat := Vector3(p.x - t.global_position.x, 0, p.z - t.global_position.z)
		# Riding on this trolley's deck is not being in its way.
		if flat.length() > t.radius() or p.y < 0.5:
			out.append([p, 0.4])
	for o: Trolley in trolleys.values():
		if o != t:
			out.append([o.global_position, o.radius()])
	return out


func _remote_input(t: Trolley, delta: float) -> void:
	var turn := _held(Keys.RIGHT, KEY_D) - _held(Keys.LEFT, KEY_A) + clampf(_mouse_turn * remote_mouse_turn, -1.0, 1.0)
	_mouse_turn = 0.0
	var drive := Vector2(clampf(turn, -1.0, 1.0), _held(Keys.FORWARD, KEY_W) - _held(Keys.BACK, KEY_S))
	t.drive_input = drive
	t.boost = _held(Keys.RUN, KEY_SHIFT) > 0.0
	_deck_keys(t, delta)
	if remote_view:
		remote_view.call("set_status", "DECK %.1f M" % t.deck_height)
	t.show_status("REMOTE")


## Up and Down (the raise and lower keys) move a trolley's deck: the one on remote, or the one
## you stand on.
func _deck_keys(t: Trolley, delta: float) -> void:
	var lift := _held("ship_bay.raise", KEY_UP) - _held("ship_bay.lower", KEY_DOWN)
	if lift == 0.0:
		return
	t.set_deck_target(t.deck_target + lift * remote_lift_rate * delta)
	_deck_send -= delta
	if _deck_send <= 0.0 and _bus:
		_deck_send = 0.25
		_bus.command_trolley(t.kind, "deck", {"height": t.deck_target + lift * remote_lift_rate * 0.25})


func _ride_keys(t: Trolley, delta: float) -> void:
	var walker := yard.get("walker") as Node3D if yard else null
	if walker == null or not bool(yard.get("walker_active")) or t.deck == null:
		return
	var local := t.deck.global_transform.affine_inverse() * walker.global_position
	var d: Vector2 = t.spec["deck"]
	if absf(local.x) < d.x * 0.5 + 0.1 and absf(local.z) < d.y * 0.5 + 0.1 and local.y > -0.2 and local.y < 0.6:
		_deck_keys(t, delta)


# --- Jobs (on the driving peer) ---------------------------------------------------------

func _on_command(id: String, command: String, args: Dictionary) -> void:
	var t: Trolley = trolleys.get(id)
	if t == null:
		return
	if command == "deck":
		t.set_deck_target(float(args.get("height", Trolley.DECK_MIN)))
		if args.has("reach"):
			t.reach(float(args["reach"]) != 0.0, float(args["reach"]))
		return
	if command == "fast":
		t.set_fast(bool(args.get("on", false)))
		return
	# Any other job for the trolley following this player (or someone else calling it to
	# follow them) ends the following here.
	if id == following and not (command == "follow" and int(args.get("by", 0)) == _me()):
		stop_following()
	if not _drives(id):
		return
	if command == "put_away" and t.is_picker():
		return   # the picking lift only fetches
	if t.is_line() and not ["put_away", "park", "deck", "come", "follow"].has(command):
		return   # a line's trolley only takes its line's goods to the stores
	if command == "shelve" and (not t.is_picker() or ["shelve", "fetch"].has(str((jobs[id] as Dictionary).get("do", ""))) \
			or (jobs[id] as Dictionary).has("shelve_from") or _bus.trolley_cargo(id) != ""):
		return   # busy: the trolley waiting at the hand-in asks again
	if command == "beam" and (["fetch", "deliver", "put_away", "beam", "to_line"].has(str((jobs[id] as Dictionary).get("do", ""))) \
			or _bus.trolley_goods(id) >= _bus.trolley_capacity(id)):
		var later := args.duplicate()
		later["command"] = "beam"
		(_queue.get_or_add(id, []) as Array).append(later)
		return
	if command == "fetch":
		# Bulk goods are too big for the lift: the large trolley fetches them itself.
		var mass := float(_bus.storage_items().get(str(args.get("item", "")), {}).get("mass", 0.0))
		if not t.carries(Layout.kind_for(mass)):
			if id != "l":
				_bus.command_trolley("l", "fetch", args)
			return
		# Busy fetching or carrying: it goes in the queue for after.
		if ["fetch", "deliver"].has((jobs[id] as Dictionary).get("do")) or _bus.trolley_cargo(id) != "":
			(_queue.get_or_add(id, []) as Array).append(args.duplicate())
			return
	if command == "follow" and str((jobs[id] as Dictionary).get("do", "")) == "follow":
		(jobs[id] as Dictionary)["to"] = args.get("to", t.global_position)
		return
	_release(id)
	t.path = PackedVector3Array()
	t.final_yaw = NAN
	match command:
		"follow":
			jobs[id] = {"do": "follow", "to": args.get("to", t.global_position)}
			t.show_status("FOLLOWING")
		"come":
			jobs[id] = {"do": "come"}
			_go_to_person(t, args.get("to", t.global_position))
			t.show_status("COMING")
		"put_away":
			jobs[id] = {"do": "put_away", "phase": "find"}
			if t.is_line():
				jobs[id]["unloading"] = true
		"park":
			jobs[id] = {"do": "park"}
			_go(t, PARKING[id][0], PARKING[id][1])
			t.show_status("PARKING")
		"fetch":
			jobs[id] = {"do": "fetch", "phase": "find", "item": str(args.get("item", "")),
					"qty": int(args.get("qty", 1)), "to": args.get("to", Vector3.ZERO)}
			t.show_status("FETCHING")
		"beam":
			var from: Vector3 = args.get("from", t.global_position)
			jobs[id] = {"do": "beam", "phase": "to_part", "slot": str(args.get("slot", "")), "component": str(args.get("component", "")),
					"condition": float(args.get("condition", 1.0)), "from": from, "route": str(args.get("route", "store"))}
			if _go_under(t, from):
				t.show_status("TO THE SHIP")
			else:
				# Nowhere near it to stand: the beam carries the part across to where it is.
				t.path = PackedVector3Array()
				t.final_yaw = NAN
				t.show_status("TAKING THE PART")
		"shelve":
			jobs[id] = {"do": "shelve", "from": str(args.get("from", "")), "phase": "to_handoff"}
		"deliver":
			jobs[id] = {"do": "deliver", "phase": "to_lift", "crate": str(args.get("crate", "")), "to": args.get("to", Vector3.ZERO)}
			var stand := stores_in(t)
			_go(t, stand[0], stand[1])
			t.show_status("TO PICKING LIFT")
		_:
			jobs[id] = {}
			t.show_status("STOPPED")


func _run_job(id: String, t: Trolley) -> void:
	var job: Dictionary = jobs[id]
	var waiting: Array = _queue.get(id, [])
	if not waiting.is_empty() and ["", "park"].has(str(job.get("do", ""))) \
			and (_bus.trolley_cargo(id) == "" or str((waiting[0] as Dictionary).get("command", "")) == "beam"):
		var next: Dictionary = waiting.pop_front()
		_on_command(id, str(next.get("command", "fetch")), next)
		return
	match str(job.get("do", "")):
		"come":
			if _arrived(t):
				jobs[id] = {}
				t.show_status("HERE")
		"follow":
			_follow(t, job)
		"park":
			if _arrived(t):
				jobs[id] = {}
				t.show_status("PARKED")
		"put_away":
			_put_away(id, t, job)
		"fetch":
			_fetch(id, t, job)
		"deliver":
			_deliver(id, t, job)
		"beam":
			_beam(id, t, job)
		"to_line":
			_to_line(id, t, job)
		"shelve":
			_shelve(id, t, job)


## Following a player: stays where it is while within a safe distance of them, else heads for
## a spot that far short of them (replanned once they have moved on a metre).
func _follow(t: Trolley, job: Dictionary) -> void:
	var to: Vector3 = job.get("to", t.global_position)
	var flat := to - t.global_position
	flat.y = 0.0
	var keep := t.radius() + FOLLOW_GAP
	if flat.length() <= keep + 0.4:
		if not t.path.is_empty():
			t.path = PackedVector3Array()
			t.final_yaw = NAN
		job.erase("goal")
	elif t.path.is_empty() or (job.get("goal", Vector3.INF) as Vector3).distance_to(to) > 1.0:
		job["goal"] = to
		_go(t, to - flat.normalized() * keep, atan2(-flat.x, -flat.z))
	t.show_status("FOLLOWING")


## The fetch job (the picking lift, or the large trolley for bulk goods).
func _fetch(id: String, t: Trolley, job: Dictionary) -> void:
	match str(job.get("phase", "")):
		"find":
			var place := ""
			for loc in _bus.find_stock(str(job["item"])):
				if place == "" or int(_bus.stock_at(loc).get("qty", 0)) >= int(job["qty"]):
					place = loc
					if int(_bus.stock_at(loc).get("qty", 0)) >= int(job["qty"]):
						break
			if place == "":
				_fail(id, t, "OUT OF STOCK")
				return
			var aisle := _aisle_of(place)
			if aisle != "" and _aisles.get(aisle, id) != id:
				t.show_status("WAITING FOR AISLE " + aisle)
				return
			if aisle != "":
				_aisles[aisle] = id
			job["place"] = place
			job["qty"] = mini(int(job["qty"]), int(_bus.stock_at(place).get("qty", 0)))
			job["phase"] = "to_shelf"
			var approach := _approach(place, t)
			if not _go(t, approach[0], approach[1]):
				_fail(id, t, "NO ROUTE")
				return
			t.show_status("TO " + place)
		"to_shelf":
			if _arrived(t):
				var loc: Dictionary = Layout.get_layout()["locations"][str(job["place"])]
				var side := 0.0
				if loc["kind"] != "bulk":
					side = signf(Layout.rack_x(str(loc["rack"])) - t.global_position.x)
				job["side"] = side
				job["phase"] = "raising"
				_bus.command_trolley(id, "deck", {"height": float((loc["at"] as Vector3).y) if t.is_picker() else Trolley.DECK_MIN})
				t.show_status("LIFTING")
		"raising":
			if t.deck_ready():
				_bus.command_trolley(id, "deck", {"height": t.deck_target, "reach": float(job["side"])})
				job["phase"] = "reaching"
				t.show_status("PICKING")
		"reaching":
			if t.fork_ready():
				job["phase"] = "picking"
				_bus.pick_stock(str(job["place"]), int(job["qty"]), job["to"], id)
		"picking":
			var held := _bus.trolley_cargo(id)
			if held != "" and beaming(id):
				return
			if held != "":
				job["crate"] = held
				job["phase"] = "lowering"
				_bus.command_trolley(id, "deck", {"height": Trolley.DECK_MIN, "reach": 0.0})
			elif _bus.stock_at(str(job["place"])).is_empty():
				job["phase"] = "find"   # someone took them first: look again
		"lowering":
			if t.deck_ready() and t.fork_ready():
				if t.is_picker():
					job["phase"] = "to_handoff"
					_go(t, HANDOFF[0], HANDOFF[1])
					t.show_status("TO HAND-OVER")
				else:
					job["phase"] = "bringing"
					_go_to_person(t, job["to"])
					t.show_status("BRINGING")
		"to_handoff":
			if _arrived(t):
				var kind := Layout.kind_for(float(_bus.crate_info(str(job["crate"])).get("mass", 0.0)))
				var courier := _free_courier(kind)
				if courier == "":
					t.show_status("WAITING FOR TROLLEY")
					return
				job["courier"] = courier
				job["phase"] = "handing"
				_bus.command_trolley(courier, "deliver", {"crate": job["crate"], "to": job["to"]})
				t.show_status("HANDING OVER")
		"handing":
			if _bus.trolley_cargo(id) == "":
				jobs[id] = {"do": "park"}
				_go(t, PARKING[id][0], PARKING[id][1])
				t.show_status("PARKING")
			elif jobs[str(job["courier"])].get("do") != "deliver":
				job["phase"] = "to_handoff"   # the courier was called away: find another
		"bringing":
			if _arrived(t):
				jobs[id] = {}
				t.show_status("HERE")


## A trolley taking a picked crate from the lift to someone.
func _deliver(id: String, t: Trolley, job: Dictionary) -> void:
	match str(job.get("phase", "")):
		"to_lift":
			if _arrived(t):
				job["phase"] = "loading"
				_bus.hand_crate(str(job["crate"]), id)
		"loading":
			if _bus.trolley_cargo(id) == str(job["crate"]) and not beaming(id):
				job["phase"] = "bringing"
				_go_to_person(t, job["to"])
				t.show_status("BRINGING")
		"bringing":
			if _arrived(t):
				jobs[id] = {}
				t.show_status("HERE")


## The smallest trolley free to carry goods of this kind out (not busy with a job, not
## holding anything, not on remote control).
func _free_courier(goods_kind: String) -> String:
	for id: String in ["s", "m", "l"]:
		var o: Trolley = trolleys[id]
		if o.carries(goods_kind) and (jobs[id] as Dictionary).get("do", "park") == "park" \
				and _bus.trolley_cargo(id) == "" and id != remote_id and _drives(id):
			return id
	return ""


## The beam job: drive over under the part freed off the ship, raise the deck to it, and
## ask for it to land (then part_beamed turns the job into putting it away).
func _beam(id: String, t: Trolley, job: Dictionary) -> void:
	match str(job.get("phase", "")):
		"to_part":
			if _arrived(t):
				var from: Vector3 = job["from"]
				job["phase"] = "lifting"
				_bus.command_trolley(id, "deck", {"height": clampf(from.y - 0.5, Trolley.DECK_MIN, float(t.spec["lift"]))})
				t.show_status("TAKING THE PART")
		"lifting":
			if t.deck_ready():
				job["phase"] = "landing"
				_bus.land_beamed(str(job["slot"]), id, str(job["component"]), float(job["condition"]), str(job.get("route", "store")))


## Plans a way to stand by the part at `from`: beside it first, then further round it.
func _go_under(t: Trolley, from: Vector3) -> bool:
	if nav == null:
		build_nav()
	var floor_at := Vector3(from.x, 0.0, from.z)
	var away := t.global_position - floor_at
	away.y = 0.0
	var start := atan2(away.x, away.z) if away.length() > 0.1 else 0.0
	for gap: float in [t.radius() + 1.0, t.radius() + 2.2, t.radius() + 3.5]:
		for k in 8:
			var a := start + (k + 1) / 2 * (PI / 4.0) * (1 if k % 2 == 0 else -1)
			var stand := floor_at + Vector3(sin(a), 0, cos(a)) * gap
			if not nav.call("is_free", stand, t.clearance()):
				continue
			if _go(t, stand, a):
				return true
	return false


func _on_beamed(crate_id: String, trolley_id: String, _component: String, _slot_id: String) -> void:
	if not trolleys.has(trolley_id) or not _drives(trolley_id):
		return
	_bus.command_trolley(trolley_id, "deck", {"height": Trolley.DECK_MIN})
	# More parts to pick up first (a clean-up gives a trolley as many as it has room for).
	var waiting: Array = _queue.get(trolley_id, [])
	if not waiting.is_empty() and str((waiting[0] as Dictionary).get("command", "")) == "beam":
		jobs[trolley_id] = {}
		_on_command(trolley_id, "beam", waiting.pop_front())
		return
	# Then the line's goods to the line, the rest to the stores.
	_next_job(trolley_id, trolleys[trolley_id])


## The line job: take a part for the lines to a free place for it and set it down there
## (the line's "feed"): worn parts to the pallets in a line's intake bay, scrap to the
## crusher's feed pad outside; it waits while they are full.
func _to_line(id: String, t: Trolley, job: Dictionary) -> void:
	var crate := str(job.get("crate", ""))
	match str(job.get("phase", "")):
		"find":
			if not t.deck_ready():
				return
			var grind := str(_bus.crate_info(crate).get("route", "")) == "grind"
			var place := _free_line_place(id, grind)
			if place.is_empty():
				t.show_status("CRUSHER PAD FULL" if grind else "INTAKE FULL")
				return
			job["line"] = place[0]
			job["spot"] = place[1]
			job["phase"] = "to_feed"
			if not _go(t, place[2], PI * 0.5):
				_fail(id, t, "NO ROUTE")
				return
			t.show_status("TO THE CRUSHER" if grind else "TO LINE " + str(place[0]).to_upper())
		"to_feed":
			if _arrived(t):
				job["phase"] = "setting_down"
				_bus.line_request("feed", {"crate": crate, "line": job["line"], "spot": job["spot"]})
		"setting_down":
			if not _bus.trolley_load(id).has(crate) and not beaming(id):
				_release(id)
				t.show_status("SET DOWN")
				_next_job(id, t)


## A place nothing stands on and no other trolley is headed for: [line ("a", "b" or
## "crusher"), spot, floor point], the line with the fewest waiting first; [] for none.
func _free_line_place(id: String, grind: bool) -> Array:
	var lines: Array = ["crusher"] if grind else ShipBayBus.LINES
	var best: Array = []
	var best_n := 1 << 30
	for line: String in lines:
		var spots: Array[Vector3] = CrusherPlant.FEED_SPOTS if line == "crusher" else RefurbLine.in_spots(line)
		var kind := "crush" if line == "crusher" else "in"
		var taken := {}
		for c: Dictionary in _bus.line_crates().values():
			if str(c.line) == kind and (line == "crusher" or str(c.get("line_id", "a")) == line):
				taken[int(c.get("line_spot", 0))] = true
		for o: String in jobs:
			var j: Dictionary = jobs[o]
			if o != id and str(j.get("do", "")) == "to_line" and j.has("spot") and str(j.get("line", "")) == line:
				taken[int(j["spot"])] = true
		for i in spots.size():
			if not taken.has(i) and taken.size() < best_n:
				best_n = taken.size()
				best = [line, i, spots[i]]
				break
	return best


## True while a line's trolley stands at the end of its line with nothing else to do.
func line_trolley_home(line: String) -> bool:
	var t: Trolley = trolleys.get(line)
	if t == null or line == remote_id:
		return false
	var job := str((jobs[line] as Dictionary).get("do", ""))
	var at: Vector3 = PARKING[line][0]
	return ["", "park"].has(job) and Vector2(t.global_position.x - at.x, t.global_position.z - at.z).length() < 1.0


## The smallest free hover trolley that carries `goods_kind` (the nearest of a size), or ""
## for none, leaving out the picking lift. `taken` lists the trolley of every part a trolley
## is already on its way for: one of those takes more while it has room.
func free_for_beam(goods_kind: String, from: Vector3, taken: Array = []) -> String:
	var best := ""
	var best_d := INF
	for id: String in trolleys:
		var t: Trolley = trolleys[id]
		if t.is_picker() or t.is_line() or not t.carries(goods_kind) or id == remote_id:
			continue
		var claimed := taken.count(id)
		var job := str((jobs[id] as Dictionary).get("do", ""))
		if claimed == 0 and (not ["", "park", "come"].has(job) or _bus.trolley_cargo(id) != ""):
			continue
		if _bus.trolley_goods(id) + claimed >= _bus.trolley_capacity(id):
			continue
		# A trolley already sent for parts takes more until it is full, before another goes.
		var d := t.global_position.distance_to(from) + float(t.radius()) * 1000.0 - claimed * 100000.0
		if d < best_d:
			best = id
			best_d = d
	return best


## The top of a trolley's deck, yard space; null for no such trolley.
func deck_position(id: String) -> Variant:
	var t: Trolley = trolleys.get(id)
	return t.to_global(Vector3(0, t.deck_height, 0)) if t else null


## Drives to stand by a person at `to`, facing them.
func _go_to_person(t: Trolley, to: Vector3) -> void:
	var from_them := t.global_position - to
	from_them.y = 0.0
	var stand := to + (from_them.normalized() if from_them.length() > 0.1 else Vector3.BACK) * (t.radius() + 1.0)
	_go(t, stand, atan2(stand.x - to.x, stand.z - to.z))


## Putting deliveries away: the trolley goes round the goods-in floor loading the crates it
## can take (up to its load), then sets its bulk goods down on their bays itself and brings
## the rest to the stores' hand-in, where the picking lift takes them off one by one and
## shelves them. The picking lift itself runs the shelving half (a held crate: to its place).
func _put_away(id: String, t: Trolley, job: Dictionary) -> void:
	match str(job.get("phase", "")):
		"find":
			var held := _bus.trolley_cargo(id)
			if t.is_picker():
				if held != "":
					job["crate"] = held
					_head_for_place(id, t, job)
				elif job.has("shelve_from"):
					jobs[id] = {"do": "shelve", "from": job["shelve_from"], "phase": "to_handoff"}
				else:
					jobs[id] = {"do": "park"}
					_go(t, PARKING[id][0], PARKING[id][1])
				return
			if job.get("unloading", false):
				_unload(id, t, job)
				return
			var crate := _next_crate(id, t)
			if crate == "":
				if _bus.trolley_load(id).is_empty():
					_release(id)
					jobs[id] = {"do": "park"}
					_go(t, PARKING[id][0], PARKING[id][1])
					t.show_status("ALL PUT AWAY")
					return
				job["unloading"] = true
				_unload(id, t, job)
				return
			_reserved_crates[crate] = id
			job["crate"] = crate
			job["phase"] = "to_crate"
			# It parks beside the goods and beams them up onto its deck.
			if not _go_under(t, _bus.crate_position(crate)) and not _go(t, _bus.crate_position(crate), NAN):
				_fail(id, t, "NO ROUTE")
				return
			t.show_status("TO CRATE")
		"to_crate":
			if _arrived(t):
				job["phase"] = "loading"
				job["wait"] = 0
				_bus.carry_crate(str(job["crate"]), id)
		"loading":
			# The crate came aboard (or someone else took it, or it didn't fit): look again,
			# once its goods have been beamed up.
			if beaming(id):
				t.show_status("BEAMING UP")
				return
			job["wait"] = int(job.get("wait", 0)) + 1
			var on := str(_bus.crate_info(str(job["crate"])).get("carrier", ""))
			if on != "" or int(job["wait"]) > 120:
				_reserved_crates.erase(str(job["crate"]))
				if on == "":
					(job.get_or_add("skip", []) as Array).append(str(job["crate"]))
				job.erase("crate")
				job["phase"] = "find"
				t.show_status("LOADED %d/%d" % [_bus.trolley_goods(id), _bus.trolley_capacity(id)])
		"to_place":
			if _arrived(t):
				var loc: Dictionary = Layout.get_layout()["locations"].get(str(job["place"]), {})
				job["phase"] = "raising"
				_bus.command_trolley(id, "deck", {"height": float((loc["at"] as Vector3).y) if not loc.is_empty() else Trolley.DECK_MIN})
				t.show_status("LIFTING")
		"raising":
			if t.deck_ready():
				job["phase"] = "storing"
				_bus.store_crate(str(job["crate"]), str(job["place"]))
		"lowering":
			if t.deck_ready() and not beaming(id):
				job["phase"] = "find"
		"waiting":
			_head_for_place(id, t, job)
		"to_stores":
			if _arrived(t):
				job["phase"] = "handing"
				job["asked"] = 0.0
				t.show_status("UNLOADING")
		"handing":
			# The picking lift takes the goods off one by one; ask it again if it is idle.
			if _rack_goods(id).is_empty():
				job["phase"] = "find"
				return
			var lift: Dictionary = jobs.get("p", {})
			if str(lift.get("do", "")) != "shelve" and not (str(lift.get("do", "")) == "put_away" and lift.get("shelve_from", "") == id):
				job["asked"] = float(job.get("asked", 0.0)) - get_physics_process_delta_time()
				if float(job["asked"]) <= 0.0:
					job["asked"] = 2.0
					_bus.command_trolley("p", "shelve", {"from": id})


## A loaded trolley's next stop: a bulk crate's bay (it sets those down itself), else the
## stores' hand-in for the picking lift, else nothing left (what next, by what is aboard).
func _unload(id: String, t: Trolley, job: Dictionary) -> void:
	for cid in _bus.trolley_load(id):
		var c := _bus.crate_info(cid)
		if Layout.kind_for(float(c.get("mass", 0.0))) == "bulk" and not ["refurb", "grind"].has(str(c.get("route", ""))):
			job["crate"] = cid
			_head_for_place(id, t, job)
			return
	if not _rack_goods(id).is_empty():
		var other := _hand_in_holder(id)
		if other != "":
			t.show_status("WAITING TO UNLOAD")
			return   # one trolley at the hand-in at a time
		job["phase"] = "to_stores"
		var stand := stores_in(t)
		if not _go(t, stand[0], stand[1]):
			_fail(id, t, "NO ROUTE")
			return
		t.show_status("TO THE STORES")
		return
	_release(id)
	_next_job(id, t)


## The crates on a trolley the picking lift shelves (not bulk, not bound for the line).
func _rack_goods(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for cid in _bus.trolley_load(id):
		var c := _bus.crate_info(cid)
		if Layout.kind_for(float(c.get("mass", 0.0))) != "bulk" and not ["refurb", "grind"].has(str(c.get("route", ""))):
			out.append(cid)
	return out


## Where a trolley stands for the picking lift to load or unload it: along Deliveries' east
## wall by the stores' doorway, its long side to the lift. [floor point, yaw].
func stores_in(t: Trolley) -> Array:
	var d: Vector2 = t.spec["deck"]
	return [Vector3(HANDOFF_TROLLEY[0].x, 0, -24.0 + 0.5 + d.y * 0.5), HANDOFF_TROLLEY[1]]


## The trolley holding the stores' hand-in (unloading there, or on its way), or "".
func _hand_in_holder(but: String) -> String:
	for o: String in jobs:
		if o == but:
			continue
		var j: Dictionary = jobs[o]
		if str(j.get("do", "")) == "put_away" and ["to_stores", "handing"].has(str(j.get("phase", ""))):
			return o
		if str(j.get("do", "")) == "deliver" and ["to_lift", "loading"].has(str(j.get("phase", ""))):
			return o
	return ""


## The picking lift shelving a trolley's goods: to the hand-over point, take the next crate
## off the trolley, put it away (the put_away job's shelving half), and back for the next.
func _shelve(id: String, t: Trolley, job: Dictionary) -> void:
	var from := str(job.get("from", ""))
	match str(job.get("phase", "")):
		"to_handoff":
			if _bus.trolley_cargo(id) != "":
				jobs[id] = {"do": "put_away", "phase": "find", "shelve_from": from}
				return
			job["phase"] = "going"
			_go(t, HANDOFF[0], HANDOFF[1])
			t.show_status("TO HAND-OVER")
		"going":
			if _arrived(t):
				job["phase"] = "taking"
		"taking":
			var goods := _rack_goods(from)
			var there: Dictionary = jobs.get(from, {})
			if goods.is_empty() or str(there.get("phase", "")) != "handing":
				jobs[id] = {"do": "park"}
				_go(t, PARKING[id][0], PARKING[id][1])
				t.show_status("PARKING")
				return
			job["crate"] = goods[0]
			job["phase"] = "took"
			job["wait"] = 0
			_bus.hand_crate(goods[0], id)
			t.show_status("TAKING " + str(_bus.crate_info(goods[0]).get("name", "")).to_upper().left(10))
		"took":
			if beaming(id):
				return
			job["wait"] = int(job.get("wait", 0)) + 1
			if _bus.trolley_cargo(id) == str(job["crate"]):
				jobs[id] = {"do": "put_away", "phase": "find", "shelve_from": from}
			elif int(job["wait"]) > 120:
				job["phase"] = "taking"


func _on_carried(_crate_id: String, trolley_id: String) -> void:
	var job: Dictionary = jobs.get(trolley_id, {})
	if job.get("do") == "put_away" and trolleys[trolley_id].is_picker() and _drives(trolley_id) and job.get("phase") == "find":
		_put_away(trolley_id, trolleys[trolley_id], job)


func _on_stored(crate_id: String, _location: String) -> void:
	for id: String in jobs:
		var job: Dictionary = jobs[id]
		if job.get("do") == "put_away" and job.get("crate") == crate_id and _drives(id):
			_release(id)
			job.erase("crate")
			job["phase"] = "lowering"
			_bus.command_trolley(id, "deck", {"height": Trolley.DECK_MIN})
			trolleys[id].show_status("STORED")


func _head_for_place(id: String, t: Trolley, job: Dictionary) -> void:
	var crate := _bus.crate_info(str(job["crate"]))
	var place := _free_place(id, str(crate.get("item", "")))
	if place == "":
		_fail(id, t, "STORES FULL")
		return
	var aisle := _aisle_of(place)
	if aisle != "" and _aisles.get(aisle, id) != id:
		job["phase"] = "waiting"
		t.show_status("WAITING FOR AISLE " + aisle)
		return
	if aisle != "":
		_aisles[aisle] = id
	_reserved_places[place] = id
	job["place"] = place
	job["phase"] = "to_place"
	var approach := _approach(place, t)
	if not _go(t, approach[0], approach[1]):
		_fail(id, t, "NO ROUTE")
		return
	t.show_status("TO " + place)


## The nearest waiting crate this trolley has room for whose goods have somewhere to go.
func _next_crate(id: String, t: Trolley) -> String:
	var best := ""
	var best_d := INF
	var skip: Array = (jobs[id] as Dictionary).get("skip", [])
	var crates := _bus.delivered_crates()
	for cid: String in crates:
		var c: Dictionary = crates[cid]
		if str(c.get("carrier", "")) != "" or (_reserved_crates.has(cid) and _reserved_crates[cid] != id) or skip.has(cid):
			continue
		if ["in", "crush"].has(str(c.get("line", ""))):
			continue   # waiting in a line's intake bay or on the crusher's pad, not for the stores
		if not t.carries(Layout.kind_for(float(c["mass"]))) or not _bus.trolley_has_room(id, cid):
			continue
		if _bus.place_for(str(c["item"])) == "":
			continue
		var d := t.global_position.distance_to(_bus.crate_position(cid))
		if d < best_d:
			best_d = d
			best = cid
	return best


## What a trolley with goods aboard does next: the line's goods to the line first, then the
## rest put away; nothing aboard: park.
func _next_job(id: String, t: Trolley) -> void:
	for cid in _bus.trolley_load(id):
		if ["refurb", "grind"].has(str(_bus.crate_info(cid).get("route", ""))):
			jobs[id] = {"do": "to_line", "phase": "find", "crate": cid}
			return
	if _bus.trolley_load(id).is_empty():
		jobs[id] = {"do": "park"}
		_go(t, PARKING[id][0], PARKING[id][1])
		t.show_status("PARKING")
		return
	jobs[id] = {"do": "put_away", "phase": "find", "unloading": true}


## Where an item would go now, skipping places other trolleys are already bound for.
func _free_place(id: String, item: String) -> String:
	var place := _bus.place_for(item)
	if place == "" or not _reserved_places.has(place) or _reserved_places[place] == id:
		return place
	# Another trolley is headed there with the same item: it stacks on the same place.
	for cid: String in _reserved_crates:
		if _reserved_crates[cid] == _reserved_places[place] and _bus.delivered_crates().get(cid, {}).get("item") == item:
			return place
	return ""


## Where a trolley stands to put goods on a place, and which way it faces: in the aisle
## beside a rack place, or in the lane in front of a bulk bay.
func _approach(place: String, t: Trolley) -> Array:
	var loc: Dictionary = Layout.get_layout()["locations"][place]
	var at: Vector3 = loc["at"]
	if loc["kind"] == "bulk":
		var face: Vector3 = loc["face"]
		var p := Vector3(at.x, 0, at.z) + face * (float(loc["size"].x) * 0.5 + t.clearance() + 0.35)
		return [p, 0.0]
	var aisle := str(loc["rack"]).substr(0, 1)
	return [Vector3(Layout.aisle_x(aisle), 0, at.z), 0.0]


func _go(t: Trolley, to: Vector3, yaw: float, around := false) -> bool:
	if nav == null:
		build_nav()
	var avoid: Array = []
	if around:
		for o: Trolley in trolleys.values():
			if o != t:
				avoid.append([o.global_position, o.radius() + 0.7])
	t.path = nav.route(t.global_position, to, t.clearance(), avoid)
	t.final_yaw = yaw
	var far := Vector2(to.x - t.global_position.x, to.z - t.global_position.z).length() > 0.3
	return not (t.path.is_empty() and far)


## Two trolleys stuck nose to nose: the one with goods aboard (or else the bigger) keeps
## its way and waits; the other plans a way round it. Round one standing still, always.
func _has_way(t: Trolley) -> bool:
	for o: Trolley in trolleys.values():
		if o == t:
			continue
		if o.global_position.distance_to(t.global_position) > o.radius() + t.radius() + 0.9:
			continue
		# One standing still (parked, unloading) won't move off: go round it.
		if o.path.is_empty() and o.drive_input == Vector2.ZERO:
			continue
		if _priority(t) > _priority(o):
			return true
	return false


func _priority(t: Trolley) -> int:
	return (10 if not t.cargo.is_empty() else 0) + Trolley.SPECS.keys().find(t.kind)


## The aisle a rack place is reached from, or "" for the bulk floor.
func _aisle_of(place: String) -> String:
	var loc: Dictionary = Layout.get_layout()["locations"].get(place, {})
	if loc.is_empty() or loc["kind"] == "bulk":
		return ""
	return str(loc["rack"]).substr(0, 1)


## Lets an aisle go once its trolley has put its goods away and come back out of the racks.
func _free_aisles() -> void:
	for aisle: String in _aisles.keys():
		var id: String = _aisles[aisle]
		var job: Dictionary = jobs.get(id, {})
		var working: bool = ["put_away", "fetch"].has(job.get("do")) and ["to_place", "raising", "storing", "lowering",
				"to_shelf", "reaching", "picking"].has(str(job.get("phase", "")))
		if not working and trolleys[id].global_position.z > Layout.RACK_Z0 + 0.5:
			_aisles.erase(aisle)


func _arrived(t: Trolley) -> bool:
	return t.path.is_empty() and is_nan(t.final_yaw)


func _fail(id: String, t: Trolley, why: String) -> void:
	_release(id)
	for aisle: String in _aisles.keys():
		if _aisles[aisle] == id:
			_aisles.erase(aisle)
	jobs[id] = {}
	t.path = PackedVector3Array()
	t.show_status(why)


func _release(id: String) -> void:
	for d: Dictionary in [_reserved_places, _reserved_crates]:
		for k: String in d.keys():
			if d[k] == id:
				d.erase(k)


func _refresh_cargo() -> void:
	if _bus == null:
		return
	_left.clear()
	var crates := _bus.delivered_crates()
	# Goods that moved since they were last drawn are beamed across.
	var now := {}
	for cid: String in crates:
		var c: Dictionary = crates[cid]
		var carrier := str(c.get("carrier", ""))
		now[cid] = {"t": carrier} if trolleys.has(carrier) else {"at": _bus.crate_position(cid)}
		now[cid].merge({"item": str(c.get("item", "")), "qty": int(c.get("qty", 1)), "condition": float(c.get("condition", 1.0))})
	for cid: String in _where:
		var was: Dictionary = _where[cid]
		var is_now: Dictionary = now.get(cid, {})
		if not was.has("t"):
			if is_now.has("t"):
				_beam_crate(cid, was["at"], trolleys[is_now["t"]], trolleys[is_now["t"]], [])
			continue
		var from: Trolley = trolleys.get(str(was["t"]))
		if from == null:
			continue
		if is_now.is_empty():
			_left[cid] = was   # into the stores (crate_stored follows), or collected
		elif is_now.has("t") and is_now["t"] != was["t"]:
			var to: Trolley = trolleys[is_now["t"]]
			_beam_crate(cid, from.deck, to, to if to.is_picker() else from, [from])
		elif is_now.has("at") and (is_now["at"] as Vector3) != Vector3.ZERO:
			_beam_crate(cid, from.deck, is_now["at"], from, [])
	_where = now
	_show_cargo()


## Draws each trolley's load, leaving out goods still being beamed onto it.
func _show_cargo() -> void:
	for id: String in trolleys:
		var t: Trolley = trolleys[id]
		var load := PackedStringArray()
		for cid in _bus.trolley_load(id):
			var f := beams.flight("crate:" + cid)
			if f.is_empty() or f["to"] != t.deck:
				load.append(cid)
		if load.is_empty():
			if not t.cargo.is_empty():
				t.set_cargo({})
			continue
		var key := ",".join(load)
		if t.cargo.get("key") == key:
			continue
		var lots: Array = []
		var mass := 0.0
		var first := _bus.crate_info(load[0])
		for cid in load:
			var c := _bus.crate_info(cid)
			lots.append({"item": str(c.get("item", "")), "count": int(c.get("qty", 1)), "condition": float(c.get("condition", 1.0))})
			mass += float(c.get("mass", 0.0)) * int(c.get("qty", 1))
		var name := "%s x%d" % [first.get("name", ""), int(first.get("qty", 1))]
		if load.size() > 1:
			name += "  +%d MORE" % (load.size() - 1)
		t.set_cargo({"key": key, "crate_id": load[0], "kind": Layout.kind_for(float(first.get("mass", 0.0))), "mass": mass,
				"name": name, "lots": lots})


## Beams a crate's goods from `from` to `to` (a point, or a trolley: onto its deck), the
## beam coming from `emitter`; `ends` are other trolleys that wait for it to land.
func _beam_crate(cid: String, from: Variant, to: Variant, emitter: Trolley, ends: Array, done := Callable()) -> void:
	var c := _bus.crate_info(cid)
	var lots := [{"item": str(c.get("item", "")), "count": int(c.get("qty", 1)),
			"look": ItemLook.look_for(float(c.get("condition", 1.0)))}]
	var target: Variant = (to as Trolley).deck if to is Trolley else to
	var all := ends.duplicate()
	if to is Trolley and not all.has(to):
		all.append(to)
	beams.fly("crate:" + cid, lots, from, target, emitter, all, func() -> void:
		_show_cargo()
		if done.is_valid():
			done.call())


## A crate a trolley carried went onto a shelf or bay: beam it across from the deck, the
## place drawn without it until it lands.
func _beam_into_stores(crate_id: String, location: String) -> void:
	var was: Dictionary = _left.get(crate_id, {})
	var from: Trolley = trolleys.get(str(was.get("t", "")))
	var loc: Dictionary = Layout.get_layout()["locations"].get(location, {})
	if from == null or loc.is_empty():
		return
	var qty := int(was.get("qty", 1))
	arriving[location] = int(arriving.get(location, 0)) + qty
	_redraw_stores()
	var lots := [{"item": str(was.get("item", "")), "count": qty, "look": ItemLook.look_for(float(was.get("condition", 1.0)))}]
	beams.fly("crate:" + crate_id, lots, from.deck, (loc["at"] as Vector3), from, [], func() -> void:
		arriving[location] = int(arriving.get(location, 0)) - qty
		if int(arriving[location]) <= 0:
			arriving.erase(location)
		_redraw_stores())


## Goods picked off a shelf onto the lift's fork: beam them across from the place.
func _beam_off_shelf(crate_id: String, location: String) -> void:
	var loc: Dictionary = Layout.get_layout()["locations"].get(location, {})
	var by := str(_bus.crate_info(crate_id).get("carrier", ""))
	if loc.is_empty() or not trolleys.has(by):
		return
	_beam_crate(crate_id, (loc["at"] as Vector3) + Vector3(0, 0.1, 0), trolleys[by], trolleys[by], [])
	_show_cargo()


func _redraw_stores() -> void:
	if yard and yard.has_method("_refresh_stores"):
		yard.call("_refresh_stores")


## True while goods are being beamed off or onto trolley `id` (it waits for them).
func beaming(id: String) -> bool:
	return trolleys.has(id) and beams.busy(trolleys[id])


# --- The screen --------------------------------------------------------------------------

## Parks one trolley.
func park(id: String) -> void:
	if _bus:
		_bus.command_trolley(id, "park")


func park_all() -> void:
	for id: String in trolleys:
		park(id)


## Every trolley puts deliveries away (the picking lift sits it out: it only picks).
func put_away_all() -> void:
	if _bus:
		for id: String in trolleys:
			_bus.command_trolley(id, "put_away")


## The trolley screen full size, with the mouse, until closed.
func open_panel() -> void:
	if panel:
		return
	var layer := CanvasLayer.new()
	layer.name = "TrolleyScreen"
	layer.layer = 20
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	panel = Screen.new()
	panel.setup(self, true)
	panel.size = TV_PIXELS
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	layer.add_child(panel)
	panel.close_requested.connect(close_panel)
	if yard:
		yard.call("set_walker_active", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_panel() -> void:
	if panel == null:
		return
	panel.get_parent().queue_free()
	panel = null
	if yard:
		yard.call("set_walker_active", true)
