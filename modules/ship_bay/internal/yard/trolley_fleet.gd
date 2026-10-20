extends Node3D
## The yard's hover trolleys and what they are doing. Built by the shipyard on every peer:
## three trolleys (small, medium, large) parked in Deliveries, a TROLLEYS console on the
## hall's east wall, and the route planner (YardNav) once the yard's collision is in.
##
## Commands come from ShipBayBus.command_trolley (every peer hears them). The peer driving a
## trolley (Multiplayer.drives "trolley:<id>": the host, or a player who claimed it for
## remote control) runs its job, plans its routes and moves it; the others follow the mover
## stream. Jobs: come to a player, put deliveries away (to the crate, load it, to its place
## in the stores, raise the deck, store it, lower, the next one), park.
##
## Keys: T calls the medium trolley to you (Shift+T the large, Ctrl+T the small). F on a
## trolley takes it on remote control (arrow keys drive it, Page Up and Page Down raise and
## lower the deck, which you can ride for work at height); F on it again lets it go.

const Trolley := preload("res://modules/ship_bay/internal/yard/hover_trolley.gd")
const Nav := preload("res://modules/ship_bay/internal/yard/yard_nav.gd")
const Layout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")

## Parking bays in Deliveries, by the east wall: trolley id -> [floor point, yaw].
const PARKING := {
	"s": [Vector3(-31.0, 0, -20.0), PI * 0.5],
	"m": [Vector3(-31.0, 0, -16.5), PI * 0.5],
	"l": [Vector3(-32.0, 0, -10.0), 0.0],
}
## The TROLLEYS console on Deliveries' east wall (facing -X into the hall).
const CONSOLE := Vector3(-28.32, 1.45, 8.6)
## How long a trolley waits held up before it plans a new way round, seconds.
const REPLAN_AFTER := 3.0

## How far the remote control's Page Up and Page Down move the deck per second, metres.
@export var remote_lift_rate := 0.8

var trolleys: Dictionary = {}       # id -> HoverTrolley
var jobs: Dictionary = {}           # id -> {do, phase, crate, place, goal, yaw}
var nav: Nav
## The trolley this player drives by remote control, or "".
var remote_id := ""
var yard: Node3D
var _bus: ShipBayBus
var _net: Node
var _reserved_places: Dictionary = {}   # location id -> trolley id
var _reserved_crates: Dictionary = {}   # crate id -> trolley id
## Aisle letter -> the trolley working in it. An aisle is one trolley wide: the others wait.
var _aisles: Dictionary = {}
var _hud: Label
var _console_text: Label3D
var _deck_send := 0.0
var _console_tick := 0.0


func _ready() -> void:
	name = "Trolleys"
	_bus = Modules.bus("ship_bay") as ShipBayBus
	_net = Modules.bus("multiplayer")
	if _net and not _net.has_method("register_mover"):
		_net = null
	for id: String in ["s", "m", "l"]:
		var t := Trolley.new()
		add_child(t)
		t.setup(id, PARKING[id][0], PARKING[id][1])
		var use := Callable(self, "toggle_remote").bind(id)
		t.set_meta("ship_bay_use", use)
		t.deck.set_meta("ship_bay_use", use)
		trolleys[id] = t
		jobs[id] = {}
		if _net:
			_net.call("register_mover", "trolley:" + id, t)
	_build_console()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(24, 24)
	_hud.add_theme_font_size_override("font_size", 18)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	_hud.visible = false
	layer.add_child(_hud)
	if _bus:
		_bus.trolley_command.connect(_on_command)
		_bus.crate_carried.connect(_on_carried)
		_bus.crate_stored.connect(_on_stored)
		_bus.stock_changed.connect(_refresh_cargo)
		_refresh_cargo()
		# A trolley that was carrying a crate when the game was saved finishes the job.
		for id: String in trolleys:
			if _bus.trolley_cargo(id) != "" and _drives(id):
				jobs[id] = {"do": "put_away", "phase": "find"}


func _exit_tree() -> void:
	if _bus:
		for pair: Array in [[_bus.trolley_command, _on_command], [_bus.crate_carried, _on_carried],
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
	for id: String in trolleys:
		var t: Trolley = trolleys[id]
		t.lift_step(delta)
		t.driving = _drives(id)
		if not t.driving:
			t.sync_yaw()
			continue
		if id == remote_id:
			_remote_input(t, delta)
		else:
			t.drive_input = Vector2.ZERO
			_run_job(id, t)
		t.step(delta, _obstacles(t))
		if t.blocked_for > REPLAN_AFTER and not t.path.is_empty() and not _has_way(t):
			_go(t, t.path[t.path.size() - 1], t.final_yaw, true)
			t.blocked_for = 0.0
	_free_aisles()
	_console_tick -= delta
	if _console_tick <= 0.0:
		_console_tick = 0.5
		_refresh_console()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_T:
		return
	var id := "l" if key.shift_pressed else ("s" if key.ctrl_pressed else "m")
	call_to_me(id)
	get_viewport().set_input_as_handled()


## Sends a trolley to where this player stands.
func call_to_me(id: String) -> void:
	if _bus:
		_bus.command_trolley(id, "come", {"to": _player_position()})


## F on a trolley: take it on remote control, or let it go again.
func toggle_remote(id: String) -> void:
	if remote_id == id:
		remote_id = ""
		trolleys[id].drive_input = Vector2.ZERO
		if _net:
			_net.call("release", "trolley:" + id)
		_hud.visible = false
		return
	if remote_id != "":
		toggle_remote(remote_id)
	remote_id = id
	if _bus:
		_bus.command_trolley(id, "stop")
	if _net:
		_net.call("claim", "trolley:" + id)
	_hud.text = "Remote control: %s\nArrow keys drive  ·  Page Up / Page Down raise and lower the deck\nF on the trolley lets it go" % trolleys[id].spec["name"]
	_hud.visible = true


func _drives(id: String) -> bool:
	return _net == null or bool(_net.call("drives", "trolley:" + id))


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
	var drive := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_UP):
		drive.y += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN):
		drive.y -= 1.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		drive.x -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT):
		drive.x += 1.0
	t.drive_input = drive
	var lift := 0.0
	if Input.is_physical_key_pressed(KEY_PAGEUP):
		lift += 1.0
	if Input.is_physical_key_pressed(KEY_PAGEDOWN):
		lift -= 1.0
	if lift != 0.0:
		t.set_deck_target(t.deck_target + lift * remote_lift_rate * delta)
		_deck_send -= delta
		if _deck_send <= 0.0:
			_deck_send = 0.25
			_bus.command_trolley(t.kind, "deck", {"height": t.deck_target + lift * remote_lift_rate * 0.25})
	t.show_status("REMOTE")


# --- Jobs (on the driving peer) ---------------------------------------------------------

func _on_command(id: String, command: String, args: Dictionary) -> void:
	var t: Trolley = trolleys.get(id)
	if t == null:
		return
	if command == "deck":
		t.set_deck_target(float(args.get("height", Trolley.DECK_MIN)))
		return
	if not _drives(id):
		return
	_release(id)
	t.path = PackedVector3Array()
	t.final_yaw = NAN
	match command:
		"come":
			var to: Vector3 = args.get("to", t.global_position)
			var from_player := t.global_position - to
			from_player.y = 0.0
			var stand := to + (from_player.normalized() if from_player.length() > 0.1 else Vector3.BACK) * (t.radius() + 1.0)
			jobs[id] = {"do": "come"}
			_go(t, stand, atan2(stand.x - to.x, stand.z - to.z))
			t.show_status("COMING")
		"put_away":
			jobs[id] = {"do": "put_away", "phase": "find"}
		"park":
			jobs[id] = {"do": "park"}
			_go(t, PARKING[id][0], PARKING[id][1])
			t.show_status("PARKING")
		_:
			jobs[id] = {}
			t.show_status("STOPPED")


func _run_job(id: String, t: Trolley) -> void:
	var job: Dictionary = jobs[id]
	match str(job.get("do", "")):
		"come":
			if _arrived(t):
				jobs[id] = {}
				t.show_status("HERE")
		"park":
			if _arrived(t):
				jobs[id] = {}
				t.show_status("PARKED")
		"put_away":
			_put_away(id, t, job)


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
	var crate: Dictionary = _bus.delivered_crates().get(str(job["crate"]), {})
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
		var working: bool = job.get("do") == "put_away" and ["to_place", "raising", "storing", "lowering"].has(str(job.get("phase", "")))
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
	var crates := _bus.delivered_crates()
	for id: String in trolleys:
		var t: Trolley = trolleys[id]
		var cid := _bus.trolley_cargo(id)
		if cid == "":
			if not t.cargo.is_empty():
				t.set_cargo({})
			continue
		if t.cargo.get("crate_id") == cid:
			continue
		var c: Dictionary = crates[cid]
		t.set_cargo({"crate_id": cid, "kind": Layout.kind_for(float(c["mass"])), "mass": float(c["mass"]) * (int(c["qty"]) if Layout.kind_for(float(c["mass"])) == "bin" else 1),
				"name": c["name"]})


# --- The console -------------------------------------------------------------------------

func _build_console() -> void:
	var holder := Node3D.new()
	holder.name = "TrolleyConsole"
	holder.position = CONSOLE
	holder.rotation.y = -PI * 0.5
	add_child(holder)
	var dark := ShipSurface.of(ShipKit.paint(Color(0.12, 0.13, 0.15), 0.4, 0.5, "satin_paint"))
	var glass := ShipKit.paint(Color(0.02, 0.03, 0.04), 0.0, 0.25)
	_panel(holder, Vector3(1.9, 1.5, 0.08), Vector3(0, 0, 0.04), dark)
	_panel(holder, Vector3(1.75, 0.62, 0.01), Vector3(0, 0.35, 0.085), glass)
	var title := _label(holder, "HOVER TROLLEYS", Vector3(0, 0.62, 0.095), 30, Color(1.0, 0.6, 0.2))
	title.name = "Title"
	_console_text = _label(holder, "", Vector3(0, 0.33, 0.095), 22, Color(0.45, 0.95, 1.0))
	var buttons := [
		["PUT AWAY\nDELIVERIES", Vector3(-0.6, -0.2, 0), func() -> void:
			for id: String in trolleys:
				_bus.command_trolley(id, "put_away")],
		["PARK ALL", Vector3(0.0, -0.2, 0), func() -> void:
			for id: String in trolleys:
				_bus.command_trolley(id, "park")],
		["CALL S", Vector3(0.6, -0.2, 0), func() -> void: call_to_me("s")],
		["CALL M", Vector3(-0.3, -0.52, 0), func() -> void: call_to_me("m")],
		["CALL L", Vector3(0.3, -0.52, 0), func() -> void: call_to_me("l")],
	]
	var body := StaticBody3D.new()
	body.name = "Buttons"
	holder.add_child(body)
	var lit := ShipKit.glow(Color(1.0, 0.55, 0.16), 1.6)
	for b: Array in buttons:
		var at: Vector3 = b[1] + Vector3(0, 0, 0.11)
		_panel(holder, Vector3(0.5, 0.24, 0.05), at, lit)
		var l := _label(holder, b[0], at + Vector3(0, 0, 0.03), 18, Color(0.08, 0.06, 0.04))
		l.outline_size = 0
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.5, 0.24, 0.08)
		col.shape = shape
		col.position = at
		col.set_meta("ship_bay_use", b[2])
		col.name = "Button_" + str(b[0]).replace("\n", "_").replace(" ", "_")
		body.add_child(col)


func _refresh_console() -> void:
	if _console_text == null:
		return
	var lines := PackedStringArray()
	for id: String in ["s", "m", "l"]:
		var t: Trolley = trolleys[id]
		lines.append("%s  %-14s deck %.1f m" % [t.spec["letter"], t.status if t.status != "" else "READY", t.deck_height])
	var waiting := 0
	if _bus:
		for c: Dictionary in _bus.delivered_crates().values():
			if str(c.get("carrier", "")) == "":
				waiting += 1
	lines.append("%d crate%s waiting in goods in" % [waiting, "" if waiting == 1 else "s"])
	_console_text.text = "\n".join(lines)


func _panel(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)


func _label(parent: Node3D, text: String, at: Vector3, size: int, colour: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = ShipKit.mono_font()
	l.font_size = size
	l.pixel_size = 0.0035
	l.modulate = colour
	l.outline_size = 4
	l.shaded = false
	l.position = at
	parent.add_child(l)
	return l
