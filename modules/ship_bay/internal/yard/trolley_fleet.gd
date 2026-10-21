extends Node3D
## The yard's hover trolleys and what they are doing. Built by the shipyard on every peer:
## three trolleys (small, medium, large) parked in Deliveries and the picking lift in the
## stores, and the route planner (YardNav) once the yard's collision is in.
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
## While a clean-up has parts no trolley was free for, how often it asks again, seconds.
const CLEAN_UP_RETRY := 1.5

## Parking bays in Deliveries, by the east wall: trolley id -> [floor point, yaw].
const PARKING := {
	"s": [Vector3(-31.0, 0, -20.0), PI * 0.5],
	"m": [Vector3(-31.0, 0, -16.5), PI * 0.5],
	"l": [Vector3(-32.0, 0, -10.0), 0.0],
	"p": [Vector3(-3.2, 0, -33.0), 0.0],
}
## Where the picking lift hands goods over (at the east end of the stores' front lane, facing
## west) and where the trolley taking them stands (facing it): [floor point, yaw].
const HANDOFF := [Vector3(-3.2, 0, -27.0), PI * 0.5]
const HANDOFF_TROLLEY := [Vector3(-6.0, 0, -27.0), -PI * 0.5]
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
var _clean_clock := 0.0


func _ready() -> void:
	name = "Trolleys"
	_bus = Modules.bus("ship_bay") as ShipBayBus
	_net = Modules.bus("multiplayer")
	if _net and not _net.has_method("register_mover"):
		_net = null
	for id: String in ["s", "m", "l", "p"]:
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
		_bus.stock_changed.connect(_refresh_cargo)
		_refresh_cargo()
		# A trolley that was carrying a delivered crate when the game was saved finishes the job.
		for id: String in trolleys:
			var held := _bus.trolley_cargo(id)
			if held == "" or not _drives(id):
				continue
			var info := _bus.crate_info(held)
			if ["refurb", "grind"].has(str(info.get("route", ""))):
				jobs[id] = {"do": "to_line", "phase": "find", "crate": held}
			elif not info.has("to"):
				jobs[id] = {"do": "put_away", "phase": "find"}
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
				[_bus.crate_stored, _on_stored], [_bus.stock_changed, _refresh_cargo]]:
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
	if command == "beam" and (["fetch", "deliver", "put_away", "beam", "to_line"].has(str((jobs[id] as Dictionary).get("do", ""))) or _bus.trolley_cargo(id) != ""):
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
		"deliver":
			jobs[id] = {"do": "deliver", "phase": "to_lift", "crate": str(args.get("crate", "")), "to": args.get("to", Vector3.ZERO)}
			_go(t, HANDOFF_TROLLEY[0], HANDOFF_TROLLEY[1])
			t.show_status("TO PICKING LIFT")
		_:
			jobs[id] = {}
			t.show_status("STOPPED")


func _run_job(id: String, t: Trolley) -> void:
	var job: Dictionary = jobs[id]
	var waiting: Array = _queue.get(id, [])
	if not waiting.is_empty() and ["", "park"].has(str(job.get("do", ""))) and _bus.trolley_cargo(id) == "":
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
			if _bus.trolley_cargo(id) == str(job["crate"]):
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
			if not nav.call("is_free", stand, t.radius()):
				continue
			if _go(t, stand, a):
				return true
	return false


func _on_beamed(crate_id: String, trolley_id: String, _component: String, _slot_id: String) -> void:
	if not trolleys.has(trolley_id) or not _drives(trolley_id):
		return
	_bus.command_trolley(trolley_id, "deck", {"height": Trolley.DECK_MIN})
	if ["refurb", "grind"].has(str(_bus.crate_info(crate_id).get("route", ""))):
		# A clean-up sorted it for the line: to the in-feed by the grinder.
		jobs[trolley_id] = {"do": "to_line", "phase": "find", "crate": crate_id}
		return
	jobs[trolley_id] = {"do": "put_away", "phase": "find", "crate": crate_id}


## The clean-up's line job: take a part sorted for the line to a free in-feed pallet and set
## it down there (the line's "feed"), waiting while the in-feed is full.
func _to_line(id: String, t: Trolley, job: Dictionary) -> void:
	var crate := str(job.get("crate", ""))
	match str(job.get("phase", "")):
		"find":
			if not t.deck_ready():
				return
			var spot := _free_in_spot(id)
			if spot < 0:
				t.show_status("IN-FEED FULL")
				return
			job["spot"] = spot
			job["phase"] = "to_feed"
			if not _go(t, RefurbLine.IN_SPOTS[spot], PI * 0.5):
				_fail(id, t, "NO ROUTE")
				return
			t.show_status("TO THE LINE")
		"to_feed":
			if _arrived(t):
				job["phase"] = "setting_down"
				_bus.line_request("feed", {"crate": crate})
		"setting_down":
			if _bus.trolley_cargo(id) != crate:
				_release(id)
				jobs[id] = {"do": "park"}
				_go(t, PARKING[id][0], PARKING[id][1])
				t.show_status("AT THE LINE")


## An in-feed pallet nothing stands on and no other trolley is headed for, or -1.
func _free_in_spot(id: String) -> int:
	var taken := {}
	for c: Dictionary in _bus.line_crates().values():
		if str(c.line) == "in":
			taken[int(c.get("in_spot", 0))] = true
	for o: String in jobs:
		if o != id and str((jobs[o] as Dictionary).get("do", "")) == "to_line" and (jobs[o] as Dictionary).has("spot"):
			taken[int(jobs[o]["spot"])] = true
	for i in RefurbLine.IN_SPOTS.size():
		if not taken.has(i):
			return i
	return -1


## The smallest free hover trolley that carries `goods_kind` (the nearest of a size), or ""
## for none, leaving out the picking lift and the ids in `taken`.
func free_for_beam(goods_kind: String, from: Vector3, taken: Array = []) -> String:
	var best := ""
	var best_d := INF
	for id: String in trolleys:
		var t: Trolley = trolleys[id]
		if t.is_picker() or not t.carries(goods_kind) or taken.has(id) or id == remote_id:
			continue
		if not ["", "park", "come"].has(str((jobs[id] as Dictionary).get("do", ""))) or _bus.trolley_cargo(id) != "":
			continue
		var d := t.global_position.distance_to(from) + float(t.radius()) * 1000.0
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


func _put_away(id: String, t: Trolley, job: Dictionary) -> void:
	match str(job.get("phase", "")):
		"find":
			var held := _bus.trolley_cargo(id)
			if held != "":
				job["crate"] = held
				_head_for_place(id, t, job)
				return
			var crate := _next_crate(id, t)
			if crate == "" and _waits_for_aisle(id, t):
				t.show_status("WAITING FOR AISLE")
				return
			if crate == "":
				_release(id)
				jobs[id] = {"do": "park"}
				_go(t, PARKING[id][0], PARKING[id][1])
				t.show_status("ALL PUT AWAY")
				return
			_reserved_crates[crate] = id
			job["crate"] = crate
			job["phase"] = "to_crate"
			if not _go(t, _bus.crate_position(crate), NAN):
				_fail(id, t, "NO ROUTE")
				return
			t.show_status("TO CRATE")
		"to_crate":
			if _arrived(t):
				job["phase"] = "loading"
				_bus.carry_crate(str(job["crate"]), id)
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
			if t.deck_ready():
				job["phase"] = "find"
		"waiting":
			_head_for_place(id, t, job)


func _on_carried(crate_id: String, trolley_id: String) -> void:
	var job: Dictionary = jobs.get(trolley_id, {})
	if job.get("do") == "put_away" and job.get("crate") == crate_id and _drives(trolley_id):
		_head_for_place(trolley_id, trolleys[trolley_id], job)


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


## The nearest waiting crate this trolley can carry whose goods have somewhere to go.
func _next_crate(id: String, t: Trolley) -> String:
	var best := ""
	var best_d := INF
	var crates := _bus.delivered_crates()
	for cid: String in crates:
		var c: Dictionary = crates[cid]
		if str(c.get("carrier", "")) != "" or (_reserved_crates.has(cid) and _reserved_crates[cid] != id):
			continue
		if str(c.get("line", "")) == "in":
			continue   # waiting on the line's in-feed, not for the stores
		if not t.carries(Layout.kind_for(float(c["mass"]))):
			continue
		# Leave a crate for a smaller trolley that is free to take it.
		if _smaller_free(t, Layout.kind_for(float(c["mass"]))):
			continue
		var place := _free_place(id, str(c["item"]))
		if place == "" or _aisles.get(_aisle_of(place), id) != id:
			continue
		var d := t.global_position.distance_to(_bus.crate_position(cid))
		if d < best_d:
			best_d = d
			best = cid
	return best


func _smaller_free(t: Trolley, goods_kind: String) -> bool:
	for o: Trolley in trolleys.values():
		if o != t and o.carries(goods_kind) and float(o.spec["radius"]) < t.radius() \
				and jobs[o.kind].get("do") == "put_away":
			return true
	return false


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
		var p := Vector3(at.x, 0, at.z) + face * (float(loc["size"].x) * 0.5 + 1.65)
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
	t.path = nav.route(t.global_position, to, t.radius(), avoid)
	t.final_yaw = yaw
	var far := Vector2(to.x - t.global_position.x, to.z - t.global_position.z).length() > 0.3
	return not (t.path.is_empty() and far)


## Two trolleys stuck nose to nose: the one with goods aboard (or else the bigger) keeps
## its way and waits; the other plans a way round it.
func _has_way(t: Trolley) -> bool:
	for o: Trolley in trolleys.values():
		if o == t:
			continue
		if o.global_position.distance_to(t.global_position) > o.radius() + t.radius() + 0.9:
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


## Is a crate this trolley could carry held back only because its aisle is busy?
func _waits_for_aisle(id: String, t: Trolley) -> bool:
	var crates := _bus.delivered_crates()
	for cid: String in crates:
		var c: Dictionary = crates[cid]
		if str(c.get("carrier", "")) != "" or not t.carries(Layout.kind_for(float(c["mass"]))) \
				or _smaller_free(t, Layout.kind_for(float(c["mass"]))):
			continue
		var held: String = _aisles.get(_aisle_of(_bus.place_for(str(c["item"]))), id)
		if held != id:
			return true
	return false


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
	for id: String in trolleys:
		var t: Trolley = trolleys[id]
		var cid := _bus.trolley_cargo(id)
		if cid == "":
			if not t.cargo.is_empty():
				t.set_cargo({})
			continue
		if t.cargo.get("crate_id") == cid:
			continue
		var c := _bus.crate_info(cid)
		t.set_cargo({"crate_id": cid, "kind": Layout.kind_for(float(c["mass"])), "mass": float(c["mass"]) * (int(c["qty"]) if Layout.kind_for(float(c["mass"])) == "bin" else 1),
				"name": c["name"]})


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
