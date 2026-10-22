extends Node3D
## The yard's transporters (flag "ship_bay.dolly"): the dolly parked west of the pad and the
## crawler east of it (Dolly), the transport cradles on the apron (TransportCradle), and who
## drives what. Built by the shipyard on every peer after the apron.
##
## Driving, the way the hover trolleys are driven: F on the cab sits you in it (W A S D drive
## and steer, the mouse looks round, F gets out); F anywhere else on it takes it on remote
## control and you walk beside it (the arrow keys drive and steer, F on it again lets go).
## Either way M changes the steering mode (normal, crab, carousel) while it stands still and
## Page Up and Page Down raise and lower the deck. The driving peer (Multiplayer.drives
## "transporter:<kind>") moves it; the rest follow the mover stream and its state events.
##
## It stops dead for a person under the deck or in its way, or anything within 0.5 m of where
## it is going. To move a hull: drive in under its cradle, raise the deck until it meets the
## cross beams, throw the cradle's four pin levers (F on each, on the side beams), then raise
## it off the pedestals. It won't lift a cradle until every pin is in, and it sets one down
## where pedestals stand under it; draw the pins to drive away.

const Dolly := preload("res://modules/ship_bay/internal/yard/dolly.gd")
const Cradle := preload("res://modules/ship_bay/internal/yard/transport_cradle.gd")

## Where each one parks: [floor point, yaw].
const PARKING := {
	"dolly": [Vector3(-42, 0, 92), 0.0],
	"crawler": [Vector3(46, 0, 100), 0.0],
}
## How far ahead the way must be clear, metres (beenster's plan: 0.5 m).
const CLEARANCE := 0.5
## How close a dolly's sockets must be under a cradle's pins to engage them, metres.
const PIN_TOLERANCE := 0.25
## Seconds between deck and steering updates sent while something changes.
const SEND_EVERY := 0.25

## How much a pixel of mouse movement turns the cab view, radians.
@export var cab_look := 0.004

var transporters: Dictionary = {}   # kind -> Dolly
var cradles: Array[Node3D] = []
## The one this player drives: on remote ("remote") or from its cab ("cab"); else "".
var driving := ""
var how := ""
var yard: Node3D
var _bus: ShipBayBus
var _net: Node
var _send := 0.0
var _sent := {}
var _look := Vector2.ZERO
## Cradle pick-ups and set-downs asked for and not yet heard back: name -> seconds left.
var _asked := {}


func _ready() -> void:
	name = "Transporters"
	_bus = Modules.bus("ship_bay") as ShipBayBus
	_net = Modules.bus("multiplayer")
	if _net and not _net.has_method("register_mover"):
		_net = null
	for kind: String in PARKING:
		var d := Dolly.new()
		add_child(d)
		d.setup(kind, PARKING[kind][0], PARKING[kind][1])
		d.deck.set_meta("ship_bay_use", Callable(self, "toggle_remote").bind(kind))
		for shape: Node in d.get_children():
			if shape is CollisionShape3D:
				shape.set_meta("ship_bay_use", Callable(self, "toggle_remote").bind(kind))
		d.cab_shape.set_meta("ship_bay_use", Callable(self, "enter_cab").bind(kind))
		transporters[kind] = d
		if _net:
			_net.call("register_mover", "transporter:" + kind, d)
	var apron: Node = yard.get("apron") if yard else null
	if apron:
		cradles.append(apron.get("pad_cradle"))
		for c: Node3D in apron.get("holding_cradles") + apron.get("dock_cradles"):
			cradles.append(c)
	for c: Node3D in cradles:
		for i in (c as Cradle).levers.size():
			(c as Cradle).levers[i].set_meta("ship_bay_use", Callable(self, "throw_pin").bind(c.name, i))
	if _bus:
		_bus.transporter_state.connect(_on_state)
		_bus.cradle_state.connect(_on_cradle)
		_restore(_bus.transport_state)
		_bus.transport_restored.connect(_restore)


func _exit_tree() -> void:
	if driving != "":
		_let_go()
	if _bus:
		for pair: Array in [[_bus.transporter_state, _on_state], [_bus.cradle_state, _on_cradle], [_bus.transport_restored, _restore]]:
			if (pair[0] as Signal).is_connected(pair[1]):
				(pair[0] as Signal).disconnect(pair[1])
	if _net:
		for kind: String in transporters:
			_net.call("unregister_mover", "transporter:" + kind)


func _drives(kind: String) -> bool:
	return _net == null or bool(_net.call("drives", "transporter:" + kind))


func cradle(cradle_name: String) -> Node3D:
	for c: Node3D in cradles:
		if c.name == cradle_name:
			return c
	return null


# --- Taking the controls ------------------------------------------------------------------

## F on a transporter (not its cab): take it on remote control, or let it go again.
func toggle_remote(kind: String) -> void:
	if driving == kind and how == "remote":
		_let_go()
		return
	_take(kind, "remote")


## F on the cab: sit in it and drive (F again gets out).
func enter_cab(kind: String) -> void:
	if driving == kind and how == "cab":
		_let_go()
		return
	_take(kind, "cab")


func _take(kind: String, p_how: String) -> void:
	if driving != "":
		_let_go()
	driving = kind
	how = p_how
	if _net:
		_net.call("claim", "transporter:" + kind)
	var d: Dolly = transporters[kind]
	d.status = "CAB" if how == "cab" else "REMOTE"
	if how == "cab":
		if _bus:
			_bus.set_walker_active(yard, false)
		_look = Vector2.ZERO
		d.cab_camera.rotation = Vector3.ZERO
		d.cab_camera.current = true
	_send_state(d, true)


func _let_go() -> void:
	var d: Dolly = transporters[driving]
	d.halt()
	d.status = "PARKED"
	if how == "cab":
		d.cab_camera.current = false
		var walker := yard.get("walker") as Node3D if yard else null
		if walker:
			# Step down beside the cab, outside the deck.
			var s := d.size()
			var out := d.global_transform * Vector3(-s.x * 0.5 - 1.0, 0, -s.y * 0.5 - Dolly.CAB.z * 0.5)
			walker.call("place", out + Vector3(0, 0.1, 0), out + d.global_basis * Vector3(0, 1.6, -4))
		if _bus:
			_bus.set_walker_active(yard, true)
	_send_state(d, true)
	if _net:
		_net.call("release", "transporter:" + driving)
	driving = ""
	how = ""


func _input(event: InputEvent) -> void:
	if driving == "":
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if how == "cab" and (event.is_action_pressed(Keys.INTERACT) if InputMap.has_action(Keys.INTERACT) else key.physical_keycode == KEY_F):
			_let_go()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ship_bay.dolly_mode") if InputMap.has_action("ship_bay.dolly_mode") else key.physical_keycode == KEY_M:
			change_mode(driving)
			get_viewport().set_input_as_handled()
			return
	var motion := event as InputEventMouseMotion
	if motion and how == "cab":
		var d: Dolly = transporters[driving]
		_look.x = clampf(_look.x - motion.relative.x * cab_look, -2.2, 2.2)
		_look.y = clampf(_look.y - motion.relative.y * cab_look, -1.0, 0.8)
		d.cab_camera.rotation = Vector3(_look.y, _look.x, 0)
		get_viewport().set_input_as_handled()


## M: the next steering mode, only while it stands still.
func change_mode(kind: String) -> void:
	var d: Dolly = transporters[kind]
	if absf(d.speed()) > 0.01:
		return
	d.next_mode()
	_send_state(d, true)


func _held(action: String, key: Key) -> float:
	if InputMap.has_action(action):
		return 1.0 if Input.is_action_pressed(action) else 0.0
	return 1.0 if Input.is_physical_key_pressed(key) else 0.0


func _read_input(d: Dolly, delta: float) -> void:
	if how == "cab":
		d.drive = _held(Keys.FORWARD, KEY_W) - _held(Keys.BACK, KEY_S)
		d.steer = _held(Keys.RIGHT, KEY_D) - _held(Keys.LEFT, KEY_A)
	else:
		d.drive = _held("ship_bay.dolly_ahead", KEY_UP) - _held("ship_bay.dolly_back", KEY_DOWN)
		d.steer = _held("ship_bay.dolly_right", KEY_RIGHT) - _held("ship_bay.dolly_left", KEY_LEFT)
	var lift := _held("ship_bay.dolly_up", KEY_PAGEUP) - _held("ship_bay.dolly_down", KEY_PAGEDOWN)
	if lift != 0.0:
		d.set_deck_target(d.deck_height + lift * d.lift_speed * maxf(delta, 0.05) * 2.0)
	elif not is_equal_approx(d.deck_target, d.deck_height):
		d.set_deck_target(d.deck_height)


# --- Each step --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	for k: Variant in _asked.keys():
		_asked[k] = float(_asked[k]) - delta
	for kind: String in transporters:
		var d: Dolly = transporters[kind]
		if not _drives(kind):
			continue
		if driving == kind:
			_read_input(d, delta)
			if how == "cab":
				var walker := yard.get("walker") as Node3D if yard else null
				if walker:
					walker.global_position = d.global_transform * (d.cab_eye - Vector3(0, 1.0, 0))
		else:
			d.halt()
		d.stopped = ""
		_guard_deck(d)
		d.step(delta, _clear_way.bind(d))
	_send -= delta
	if _send <= 0.0:
		_send = SEND_EVERY
		for kind: String in transporters:
			if _drives(kind) and (driving == kind or transporters[kind].speed() != 0.0):
				_send_state(transporters[kind], false)


## Can `d` go on at this velocity and turn? "" if so, else why not (shown on its screen).
func _clear_way(lin: Vector3, turn: float, d: Dolly) -> String:
	var people := _people()
	var s := d.size()
	for p: Vector3 in people:
		var local := d.global_transform.affine_inverse() * p
		if absf(local.x) < s.x * 0.5 + 0.1 and absf(local.z) < s.y * 0.5 + 0.1 and local.y < d.deck_height - 0.3:
			return "STOP: PERSON UNDER"
	var under := _cradle_over(d)
	if under and not d.is_loaded() and (under as Cradle).engaged_count() > 0:
		return "STOP: DRAW PINS"
	var travel := d.corner_speed(lin, turn)
	if travel < 0.0001:
		return ""
	var next := d.ahead(lin, turn, CLEARANCE / travel)
	for p: Vector3 in people:
		var local := next.affine_inverse() * p
		if absf(local.x) < s.x * 0.5 and absf(local.z) < s.y * 0.5 + Dolly.CAB.z and local.y < d.deck_height + 0.2:
			return "STOP: PERSON IN THE WAY"
	var skip: Array[RID] = [d.get_rid(), d.deck.get_rid()]
	var walker := yard.get("walker") as CollisionObject3D if yard else null
	if walker:
		skip.append(walker.get_rid())
	var boxes: Array = [[Vector3(0, (0.15 + d.deck_height - 0.05) * 0.5, -Dolly.CAB.z * 0.5), Vector3(s.x, d.deck_height - 0.2, s.y + Dolly.CAB.z)]]
	if d.load_cradle:
		skip.append(d.load_cradle.get_rid())
		var hull := (d.load_cradle as Cradle).load_node as CollisionObject3D
		if hull:
			skip.append(hull.get_rid())
		# The cradle's frame and the hull on it, from the beams' underside up.
		var c_local := d.global_transform.affine_inverse() * d.load_cradle.global_transform
		var lc := d.load_cradle as Cradle
		var tall := lc.saddle_top + (4.0 if hull else 0.0)
		boxes.append([c_local * Vector3(0, tall * 0.5, 0), Vector3(lc.side_x * 2.0 + 0.6, tall, lc.length)])
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.exclude = skip
	for b: Array in boxes:
		var shape := BoxShape3D.new()
		shape.size = b[1]
		q.shape = shape
		q.transform = Transform3D(next.basis, next * (b[0] as Vector3))
		if not space.intersect_shape(q, 1).is_empty():
			return "STOP: CLEARANCE"
	return ""


## Where every player stands (feet): this one's walker and the others' avatars.
func _people() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var walker := yard.get("walker") as Node3D if yard else null
	if walker and how != "cab":
		out.append(walker.global_position)
	if _net and _net.has_method("peers") and _net.has_method("avatar_head"):
		for peer: int in (_net.call("peers") as Dictionary):
			var head := _net.call("avatar_head", peer) as Node3D
			if head:
				out.append(head.global_position - Vector3(0, 1.6, 0))
	return out


## The cradle whose frame stands over `d`'s deck, or null.
func _cradle_over(d: Dolly) -> Node3D:
	if d.load_cradle:
		return d.load_cradle
	for c: Node3D in cradles:
		var local := c.global_transform.affine_inverse() * d.global_position
		if absf(local.x) < (c as Cradle).side_x - 0.2 and absf(local.z) < (c as Cradle).length * 0.5 and c.global_position.y > d.deck_height - 0.05:
			return c
	return null


## True when `d`'s sockets sit under `c`'s pins (each within PIN_TOLERANCE, across the ground).
func aligned(d: Dolly, c: Node3D) -> bool:
	var sockets := d.sockets()
	for pin: Vector3 in Cradle.PINS:
		var at := d.global_transform.affine_inverse() * (c.global_transform * pin)
		var near := INF
		for s: Vector3 in sockets:
			near = minf(near, Vector2(at.x - s.x, at.z - s.z).length())
		if near > PIN_TOLERANCE:
			return false
	return true


## The deck meets a cradle: it stops at the cross beams until every pin is in, then picks the
## cradle up; lowering a carried cradle onto pedestals sets it down there.
func _guard_deck(d: Dolly) -> void:
	var c := _cradle_over(d)
	var people := _people()
	if d.deck_target < d.deck_height:
		var s := d.size()
		for p: Vector3 in people:
			var local := d.global_transform.affine_inverse() * p
			if absf(local.x) < s.x * 0.5 + 0.1 and absf(local.z) < s.y * 0.5 + 0.1 and local.y < d.deck_height - 0.3:
				d.set_deck_target(d.deck_height)
				d.stopped = "STOP: PERSON UNDER"
				return
	if c == null:
		return
	var cr := c as Cradle
	if d.load_cradle == null:
		var contact := c.global_position.y
		if d.deck_target > contact - 0.005:
			if aligned(d, c) and cr.all_pins_engaged():
				_pick_up(d, c)
			else:
				d.set_deck_target(contact - 0.005)
				d.stopped = "PINS %d/4" % cr.engaged_count() if aligned(d, c) else "NOT LINED UP"
		elif cr.engaged_count() > 0 and d.deck_target < d.deck_height:
			d.set_deck_target(d.deck_height)
			d.stopped = "DRAW PINS"
		return
	# Carrying: set it down where pedestals stand under it.
	if d.deck_target < d.deck_height:
		var top := _pedestal_top(c)
		if not is_nan(top) and d.deck_target <= top + 0.005:
			d.set_deck_target(top + 0.005)
			if d.deck_height <= top + 0.006:
				_set_down(d, c, top)


## The height of the pedestals' tops under every foot of `c`, or NAN if not all are there.
## (Each ray starts inside the cradle's own beam, which it skips, so it never starts inside a
## pedestal the cradle is just coming down on.)
func _pedestal_top(c: Node3D) -> float:
	var space := get_world_3d().direct_space_state
	var tops: Array[float] = []
	for foot: Vector3 in (c as Cradle).pedestal_points():
		var q := PhysicsRayQueryParameters3D.create(foot + Vector3(0, 0.3, 0), foot + Vector3(0, -2.0, 0))
		var skip: Array[RID] = [c.get_rid()]
		for d: Dolly in transporters.values():
			skip.append(d.get_rid())
			skip.append(d.deck.get_rid())
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty() or (hit.position as Vector3).y < 0.5:
			return NAN
		tops.append((hit.position as Vector3).y)
	return tops.min()


func _pick_up(d: Dolly, c: Node3D) -> void:
	d.set_deck_target(c.global_position.y - 0.005)
	if float(_asked.get(c.name, 0.0)) > 0.0:
		return
	_asked[c.name] = 1.0
	var payload := {"cradle": str(c.name), "dolly": d.kind, "xform": _xf(c.global_transform)}
	_cradle_event(payload)


func _set_down(d: Dolly, c: Node3D, top: float) -> void:
	if float(_asked.get(c.name, 0.0)) > 0.0:
		return
	_asked[c.name] = 1.0
	var xf := c.global_transform
	xf.origin.y = top
	_cradle_event({"cradle": str(c.name), "dolly": "", "xform": _xf(xf)})
	d.set_deck_target(top - 0.005)


## F on a pin lever: throw the pin, if a dolly is up against the cradle and lined up (to put
## it in) and the cradle isn't riding on it (to draw it).
func throw_pin(cradle_name: String, i: int) -> void:
	var c := cradle(cradle_name) as Cradle
	if c == null:
		return
	var engage := not c.pins[i]
	var ok := false
	for d: Dolly in transporters.values():
		if d.load_cradle == c:
			return   # locked under load
		if _cradle_over(d) == c and aligned(d, c) and d.deck_height > c.global_position.y - 0.03:
			ok = true
	if engage and not ok:
		return
	var pins: Array = c.pins.duplicate()
	pins[i] = engage
	_cradle_event({"cradle": cradle_name, "pins": pins})


# --- State across peers --------------------------------------------------------------------

func _send_state(d: Dolly, force: bool) -> void:
	var payload := {"kind": d.kind, "deck": snappedf(d.deck_target, 0.001), "mode": d.mode, "steer": snappedf(d.steer_angle, 0.001),
			"status": d.status}
	if not force and _sent.get(d.kind, {}) == payload:
		return
	_sent[d.kind] = payload
	if _bus:
		_bus.send_transporter(payload)


func _on_state(payload: Dictionary) -> void:
	var d: Dolly = transporters.get(str(payload.get("kind", "")))
	if d == null:
		return
	d.status = str(payload.get("status", d.status))
	if not _drives(d.kind):
		d.set_deck_target(float(payload.get("deck", d.deck_target)))
		d.mode = str(payload.get("mode", d.mode))
		d.steer_angle = float(payload.get("steer", d.steer_angle))
	_remember()


func _cradle_event(payload: Dictionary) -> void:
	if _bus:
		_bus.send_cradle(payload)


## A cradle changed on every peer: pins thrown, picked up by a dolly or set down.
func _on_cradle(payload: Dictionary) -> void:
	var c := cradle(str(payload.get("cradle", ""))) as Cradle
	if c == null:
		return
	if payload.has("pins"):
		var pins: Array = payload["pins"]
		for i in mini(pins.size(), c.pins.size()):
			c.pins[i] = bool(pins[i])
		c.show_pins()
	if payload.has("dolly"):
		_asked.erase(c.name)
		for d: Dolly in transporters.values():
			if d.load_cradle == c:
				d.load_cradle = null
		var xf := _unxf(payload.get("xform", []), c.global_transform)
		c.global_transform = xf
		var by: Dolly = transporters.get(str(payload["dolly"]))
		if by:
			by.load_cradle = c
			by.load_offset = by.deck.global_transform.affine_inverse() * xf
	_remember()


## Keeps where things are in the bus, for saves and late joiners.
func _remember() -> void:
	if _bus == null:
		return
	var out := {"cradles": {}, "transporters": {}}
	for c: Node3D in cradles:
		var on := ""
		for d: Dolly in transporters.values():
			if d.load_cradle == c:
				on = d.kind
		out.cradles[str(c.name)] = {"xform": _xf(c.global_transform), "pins": (c as Cradle).pins.duplicate(), "on": on}
	for d: Dolly in transporters.values():
		out.transporters[d.kind] = {"xform": _xf(d.global_transform), "deck": d.deck_target, "mode": d.mode}
	_bus.transport_state = out


func _restore(state: Dictionary) -> void:
	for kind: String in state.get("transporters", {}):
		var d: Dolly = transporters.get(kind)
		if d == null:
			continue
		var t: Dictionary = state.transporters[kind]
		d.global_transform = _unxf(t.get("xform", []), d.global_transform)
		d.set_deck_target(float(t.get("deck", Dolly.DECK_LOW)))
		d.deck_height = d.deck_target
		d.call("_set_deck", d.deck_target)
		d.mode = str(t.get("mode", "normal"))
	for cname: String in state.get("cradles", {}):
		var c := cradle(cname) as Cradle
		if c == null:
			continue
		var s: Dictionary = state.cradles[cname]
		c.global_transform = _unxf(s.get("xform", []), c.global_transform)
		var pins: Array = s.get("pins", [])
		for i in mini(pins.size(), c.pins.size()):
			c.pins[i] = bool(pins[i])
		c.show_pins()
		var by: Dolly = transporters.get(str(s.get("on", "")))
		if by:
			by.load_cradle = c
			by.load_offset = by.deck.global_transform.affine_inverse() * c.global_transform


## A transform as 12 floats (events and saves carry plain arrays), and back.
static func _xf(t: Transform3D) -> Array:
	return [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
			t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]


static func _unxf(a: Array, fallback: Transform3D) -> Transform3D:
	if a.size() != 12:
		return fallback
	return Transform3D(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8]), Vector3(a[9], a[10], a[11]))
