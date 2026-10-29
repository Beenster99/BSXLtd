class_name TradesExtinguishers
extends Node3D
## The yard's fire extinguishers are real (beenster, 0.3.23: "make the fire extinguishers which
## are on the walls like actual fire extinguishers which players can interact with"). Behind
## trades.extinguishers.
##
## Each fire point on the walls (Ship and Bay's ShipBayBus.fire_points(): where a bottle's foot
## sits, -Z out of the wall) has a bracket with a red stored-pressure extinguisher on it: a
## bottle, a squeeze valve with its safety pin, a gauge, a hose and a horn. Look at one and F
## takes it off the wall into your right hand; hold the left mouse button to spray a white
## cloud where you look (it hisses, kicks a little and empties in `spray_s`); F again hangs it
## on any empty bracket you look at, or else stands it on the floor in front of you, where F
## picks it up again. Hung on a bracket it's serviced back to full. Picking a tool off the
## hotbar while you hold one stands it down first.
## Who holds which one, and where the rest stand, is shared (event trades.extinguisher, a
## snapshot for late joiners); a crewmate's spray shows on their avatar's copy.

## Event and snapshot section (Multiplayer's "<module>.<thing>").
const EVENT := "trades.extinguisher"
const SECTION := "trades_extinguishers"
## Where one can be: on its bracket, in a player's hand, standing on the floor.
const ON_WALL := "wall"
const IN_HAND := "hand"
const ON_FLOOR := "floor"
## The bottle: radius and height of the body (m), as the yard drew them.
const RADIUS := 0.08
const BODY_H := 0.5
## Reach to take or hang one (m from the eye).
const REACH_M := 2.4

## Seconds of spray in a full bottle, and to service an empty one back to full on its bracket.
@export var spray_s := 14.0
@export var refill_s := 20.0
## The cloud: how far it carries (m) and how fast it leaves the horn (m/s).
@export var spray_reach_m := 4.0
@export var spray_speed := 7.0
## The hiss (dB) and how hard it kicks back (view kick, m a second).
@export var hiss_db := -10.0
@export var kick_per_s := 0.02

var bay: Node  # TradesBay
## The fire points: where each bracket is (set before build(), else asked of Ship and Bay).
var spots: Array[Transform3D] = []
## Every extinguisher: {id, node (its look), where, peer (holder), at (floor xform), home (its
## bracket's index), charge 0..1}.
var units: Array[Dictionary] = []
## Spraying now (this player).
var spraying := false
## The one in your hand (index into units) or -1.
var held := -1

var _net: Node
var _brackets: Array[Node3D] = []
var _cloud: GPUParticles3D
var _hiss: AudioStreamPlayer3D
var _sputter: AudioStreamPlayer3D
## Crewmates' sprays, by peer: the cloud on their copy.
var _crew_clouds := {}


static func enabled() -> bool:
	return Flags.is_on("trades.extinguishers")


## Ship and Bay's fire points, or none (its bus doesn't have them yet).
static func fire_points() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var bus := Modules.bus("ship_bay")
	if bus and bus.has_method("fire_points"):
		for t: Variant in bus.call("fire_points"):
			if t is Transform3D:
				out.append(t)
	return out


## Brackets and extinguishers at every spot; joins the crew's events when online.
func build(net: Node = null) -> void:
	if spots.is_empty():
		spots = fire_points()
	for i in spots.size():
		var bracket := _bracket_look()
		bracket.name = "Bracket%d" % i
		bracket.transform = spots[i]
		add_child(bracket)
		_brackets.append(bracket)
		var node := _make(i)
		units.append({"id": i, "node": node, "where": ON_WALL, "peer": 0, "at": Transform3D(),
				"home": i, "charge": 1.0})
		_place(i)
	_cloud = _make_cloud()
	add_child(_cloud)
	_hiss = AudioStreamPlayer3D.new()
	_hiss.name = "Hiss"
	_hiss.stream = TradesSounds.hum(0.5, 0.45, 40.0, 9000.0)
	_hiss.volume_db = hiss_db
	_hiss.max_distance = 30.0
	add_child(_hiss)
	_sputter = AudioStreamPlayer3D.new()
	_sputter.name = "Sputter"
	_sputter.stream = TradesSounds.rattle(0.5, 0.3, 300.0, 9.0)
	_sputter.volume_db = hiss_db - 4.0
	add_child(_sputter)
	HudSlots.register_look_hint("trades.extinguisher", func(hit: Dictionary) -> Dictionary: return look_hint(hit), 5)
	_net = net
	if _net:
		_net.call("register_event", EVENT, _apply, _validate)
		if _net.has_method("register_snapshot_provider"):
			_net.call("register_snapshot_provider", SECTION, self)
		if _net.has_signal("held_changed"):
			_net.connect("held_changed", _on_crew_held)


func _exit_tree() -> void:
	HudSlots.unregister_look_hint("trades.extinguisher")
	if _net:
		_net.call("unregister_event", EVENT)
		if _net.has_method("unregister_snapshot_provider"):
			_net.call("unregister_snapshot_provider", SECTION)
		if _net.has_signal("held_changed") and _net.is_connected("held_changed", _on_crew_held):
			_net.disconnect("held_changed", _on_crew_held)


# --- Aiming -----------------------------------------------------------------------------

## The extinguisher you're looking at within reach (not one in anybody's hand), or -1.
func aimed_unit() -> int:
	var best := -1
	var best_d := REACH_M
	for i in units.size():
		var u: Dictionary = units[i]
		if u.where == IN_HAND:
			continue
		var d := _ray_hits(_centre(i), RADIUS + 0.06, ((u.node as Node3D).get_node("Body") as StaticBody3D).get_rid())
		if d >= 0.0 and d < best_d:
			best_d = d
			best = i
	return best


## The empty bracket you're looking at within reach, or -1.
func aimed_bracket() -> int:
	var best := -1
	var best_d := REACH_M
	for k in _brackets.size():
		if _on_bracket(k) >= 0:
			continue
		var d := _ray_hits(spots[k] * Vector3(0, BODY_H * 0.5, -RADIUS - 0.02), RADIUS + 0.12)
		if d >= 0.0 and d < best_d:
			best_d = d
			best = k
	return best


## Distance along the view ray to its closest pass by `point`, if it passes within `radius`
## and nothing solid (but `own`, the thing itself) is in between; else -1.
func _ray_hits(point: Vector3, radius: float, own := RID()) -> float:
	var w := _worker()
	if w == null:
		return -1.0
	var from: Vector3 = w.call("aim_origin")
	var dir: Vector3 = w.call("aim_dir")
	var t := (point - from).dot(dir)
	if t <= 0.0:
		return -1.0
	if (from + dir * t).distance_to(point) > radius:
		return -1.0
	var space := w.get_world_3d().direct_space_state if w.is_inside_tree() else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * maxf(t - radius - 0.05, 0.0))
		q.exclude = [w.get_rid(), own] if own.is_valid() else [w.get_rid()]
		if not space.intersect_ray(q).is_empty():
			return -1.0
	return t


func _on_bracket(k: int) -> int:
	for i in units.size():
		if units[i].where == ON_WALL and int(units[i].home) == k:
			return i
	return -1


# --- Doing ------------------------------------------------------------------------------

## F: take the one you look at, or hang yours on an empty bracket you look at, or stand it on
## the floor. True when it did something.
func interact() -> bool:
	if held >= 0:
		var k := aimed_bracket()
		if k >= 0:
			_ask({"id": held, "act": "hang", "home": k, "charge": float(units[held].charge)})
		else:
			_ask({"id": held, "act": "drop", "at": _floor_spot(), "charge": float(units[held].charge)})
		return true
	var i := aimed_unit()
	if i < 0:
		return false
	_ask({"id": i, "act": "take"})
	return true


## Stand it down (picking a tool while holding one): on the floor in front of you.
func put_down() -> void:
	if held >= 0:
		_ask({"id": held, "act": "drop", "at": _floor_spot(), "charge": float(units[held].charge)})


func set_spraying(on: bool) -> void:
	spraying = on and held >= 0


func holding() -> bool:
	return held >= 0


func charge_of(i: int) -> float:
	return float(units[i].charge) if i >= 0 and i < units.size() else 0.0


func _floor_spot() -> Transform3D:
	var w := _worker()
	var ahead := -w.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	var at := w.global_position + ahead * 0.6
	var space := w.get_world_3d().direct_space_state if w.is_inside_tree() else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.0, at + Vector3.DOWN * 3.0)
		q.exclude = [w.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			at = hit.position
	return Transform3D(Basis(Vector3.UP, atan2(ahead.x, ahead.z)), at)


func _ask(p: Dictionary) -> void:
	if _net and bool(_net.call("is_online")):
		_net.call("request", EVENT, p)
		return
	var v: Variant = _validate(_local_peer(), p)
	if v is Dictionary:
		_apply(v)


func _validate(sender: int, p: Dictionary) -> Variant:
	var i := int(p.get("id", -1))
	if i < 0 or i >= units.size():
		return "no such extinguisher"
	var u: Dictionary = units[i]
	var out := {"id": i, "act": str(p.get("act", "")), "peer": sender}
	match out.act:
		"take":
			if u.where == IN_HAND:
				return "someone has it"
			for v: Dictionary in units:
				if v.where == IN_HAND and int(v.peer) == sender:
					return "your hand is full"
		"hang":
			var k := int(p.get("home", -1))
			if u.where != IN_HAND or int(u.peer) != sender:
				return "not yours"
			if k < 0 or k >= spots.size() or _on_bracket(k) >= 0:
				return "no empty bracket"
			out.home = k
			out.charge = clampf(float(p.get("charge", u.charge)), 0.0, 1.0)
		"drop":
			if u.where != IN_HAND or int(u.peer) != sender:
				return "not yours"
			if not p.get("at") is Transform3D:
				return "nowhere to put it"
			out.at = p.at
			out.charge = clampf(float(p.get("charge", u.charge)), 0.0, 1.0)
		_:
			return "unknown"
	return out


func _apply(p: Dictionary) -> void:
	var i := int(p.id)
	var u: Dictionary = units[i]
	var mine := int(p.peer) == _local_peer()
	match str(p.act):
		"take":
			u.where = IN_HAND
			u.peer = int(p.peer)
			if mine:
				held = i
				if bay and bay.has_method("set_tool"):
					bay.call("set_tool", &"hands")
		"hang":
			u.where = ON_WALL
			u.home = int(p.home)
			u.peer = 0
			u.charge = float(p.charge)
			if mine:
				held = -1
				spraying = false
		"drop":
			u.where = ON_FLOOR
			u.at = p.at
			u.peer = 0
			u.charge = float(p.charge)
			if mine:
				held = -1
				spraying = false
	_place(i)


func _local_peer() -> int:
	return int(_net.call("local_peer_id")) if _net and bool(_net.call("is_online")) else 1


# --- Every frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	for i in units.size():
		var u: Dictionary = units[i]
		if u.where == ON_WALL and float(u.charge) < 1.0:
			u.charge = minf(1.0, float(u.charge) + delta / maxf(refill_s, 0.1))
		if u.where == IN_HAND:
			_place(i)
		_show_gauge(i)
	var flowing := false
	if held >= 0 and spraying:
		var u: Dictionary = units[held]
		if float(u.charge) > 0.0:
			u.charge = maxf(0.0, float(u.charge) - delta / maxf(spray_s, 0.1))
			flowing = true
			var w := _worker()
			if w and w.has_method("kick"):
				w.call("kick", kick_per_s * delta)
	_cloud.emitting = flowing
	if flowing:
		_cloud.global_transform = _horn(held)
	_loop(_hiss, flowing)
	_loop(_sputter, held >= 0 and spraying and not flowing)
	for peer: int in _crew_clouds:
		var c: Dictionary = _crew_clouds[peer]
		var i := _held_by(peer)
		var on: bool = c.on and i >= 0
		(c.cloud as GPUParticles3D).emitting = on
		if on:
			(c.cloud as GPUParticles3D).global_transform = _horn(i)


func _loop(p: AudioStreamPlayer3D, on: bool) -> void:
	if on == p.playing or DisplayServer.get_name() == "headless":
		return
	if on:
		p.play()
	else:
		p.stop()


## What the crew's avatars show (TradesCrew shares it with the rest of what you hold).
func held_state() -> Dictionary:
	return {"spray": spraying and held >= 0 and float(units[held].charge) > 0.0}


func _on_crew_held(peer: int, state: Dictionary) -> void:
	if peer == _local_peer():
		return
	var c: Dictionary = _crew_clouds.get(peer, {})
	if not is_instance_valid(c.get("cloud")):
		c.cloud = _make_cloud()
		add_child(c.cloud)
	c.on = bool(state.get("spray", false))
	_crew_clouds[peer] = c


func _held_by(peer: int) -> int:
	for i in units.size():
		if units[i].where == IN_HAND and int(units[i].peer) == peer:
			return i
	return -1


# --- Where each one is ------------------------------------------------------------------

func _place(i: int) -> void:
	var u: Dictionary = units[i]
	var node: Node3D = u.node
	var body := node.get_node("Body") as StaticBody3D
	match str(u.where):
		ON_WALL:
			# Turned so its horn faces the room.
			node.global_transform = spots[int(u.home)] * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -RADIUS - 0.02))
			body.process_mode = Node.PROCESS_MODE_INHERIT
		ON_FLOOR:
			node.global_transform = u.at
			body.process_mode = Node.PROCESS_MODE_INHERIT
		IN_HAND:
			body.process_mode = Node.PROCESS_MODE_DISABLED
			var hand: Variant = _hand_of(int(u.peer))
			if hand is Transform3D:
				node.global_transform = hand
	# In your own hand: your helmet torch casts no shadow of it (Graphics' "gfx_held").
	var in_mine := str(u.where) == IN_HAND and int(u.peer) == _local_peer()
	if in_mine != node.is_in_group("gfx_held"):
		if in_mine:
			node.add_to_group("gfx_held")
		else:
			node.remove_from_group("gfx_held")
	node.visible = true


## Where a holder's extinguisher goes: hung from the right hand by its handle, the horn
## pointing where they look.
func _hand_of(peer: int) -> Variant:
	var palm: Transform3D
	var face: Basis
	if peer == _local_peer():
		var w := _worker()
		if w == null:
			return null
		palm = (w.get("right_hand") as Node).call("palm")
		var dir: Vector3 = w.call("aim_dir")
		var flat := Vector3(dir.x, 0.0, dir.z)
		# The horn (on the bottle's +Z side) toward where you look.
		face = Basis.looking_at(-flat.normalized() if flat.length() > 0.01 else Vector3.BACK, Vector3.UP)
	else:
		var hand := _net.call("avatar_hand", peer, true) as Node3D if _net and _net.has_method("avatar_hand") else null
		if hand == null:
			return null
		palm = hand.global_transform.orthonormalized()
		face = palm.basis
	# The handle's grip is at the top of the valve: hang the bottle under the palm.
	return Transform3D(face, palm.origin - Vector3(0, BODY_H + 0.1, 0))


## The horn's mouth on extinguisher i: -Z is the way the cloud goes.
func _horn(i: int) -> Transform3D:
	var node: Node3D = units[i].node
	var horn := node.get_node_or_null("Horn") as Node3D
	var at := horn.global_position if horn else node.global_position
	var dir := Vector3.FORWARD
	if int(units[i].peer) == _local_peer() and units[i].where == IN_HAND and _worker():
		dir = _worker().call("aim_dir")
	elif horn:
		dir = -horn.global_basis.z
	return Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.BACK), at)


func _centre(i: int) -> Vector3:
	return (units[i].node as Node3D).global_transform * Vector3(0, BODY_H * 0.5, 0)


func _worker() -> Node3D:
	return bay.get("worker") as Node3D if bay else null


func _show_gauge(i: int) -> void:
	var needle := (units[i].node as Node3D).get_node_or_null("Gauge/Needle") as Node3D
	if needle:
		# Full points up-right in the green, empty down-left in the red.
		needle.rotation.z = lerpf(2.2, -0.6, float(units[i].charge))


# --- Snapshot for late joiners ------------------------------------------------------------

func get_net_snapshot() -> Dictionary:
	var out := []
	for u: Dictionary in units:
		out.append({"where": u.where, "peer": u.peer, "at": u.at, "home": u.home, "charge": u.charge})
	return {"units": out}


func apply_net_snapshot(data: Dictionary) -> void:
	var rows: Array = data.get("units", [])
	for i in mini(rows.size(), units.size()):
		var r: Dictionary = rows[i]
		var u: Dictionary = units[i]
		u.where = str(r.get("where", ON_WALL))
		u.peer = int(r.get("peer", 0))
		u.at = r.get("at", Transform3D()) if r.get("at") is Transform3D else Transform3D()
		u.home = int(r.get("home", i))
		u.charge = float(r.get("charge", 1.0))
		_place(i)


# --- Look hints -------------------------------------------------------------------------

func look_hint(_hit: Dictionary) -> Dictionary:
	if held >= 0:
		var pct := roundi(charge_of(held) * 100.0)
		var keys: Array = [["LMB", "spray (hold)"]]
		keys.append([Keys.INTERACT, "hang it on the bracket" if aimed_bracket() >= 0 else "stand it on the floor"])
		return {"title": "Fire extinguisher", "text": "%d%% left%s" % [pct, "  ·  EMPTY" if pct == 0 else ""], "keys": keys}
	var i := aimed_unit()
	if i < 0:
		return {}
	var where := "on its bracket" if units[i].where == ON_WALL else "on the floor"
	return {"title": "Fire extinguisher", "text": "Stored-pressure foam, 6 kg, %s. %d%% full." % [where, roundi(charge_of(i) * 100.0)],
			"keys": [[Keys.INTERACT, "take it"]]}


# --- Looks ------------------------------------------------------------------------------

func _make(i: int) -> Node3D:
	var node := build_look()
	node.name = "Extinguisher%d" % i
	var body := StaticBody3D.new()
	body.name = "Body"
	body.set_meta("extinguisher", i)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = BODY_H
	shape.shape = cyl
	shape.position.y = BODY_H * 0.5
	body.add_child(shape)
	node.add_child(body)
	add_child(node)
	return node


## One extinguisher's look, foot at the origin, horn toward -Z: a red bottle with a domed
## shoulder, a black squeeze valve with its lever, a yellow safety pin and tag, a gauge, a hose
## down the side to a black horn clipped to the bottle, and the label band.
static func build_look() -> Node3D:
	var root := Node3D.new()
	var red := _mat(Color(0.75, 0.06, 0.04), 0.25, 0.3)
	var black := _mat(Color(0.05, 0.05, 0.05), 0.1, 0.6)
	var steel := _mat(Color(0.7, 0.71, 0.72), 0.9, 0.25)
	var label := _mat(Color(0.95, 0.93, 0.85), 0.0, 0.7)
	var yellow := _mat(Color(0.95, 0.75, 0.05), 0.2, 0.5)
	var dial := _mat(Color(0.97, 0.97, 0.95), 0.0, 0.5)
	root.add_child(_mesh(_cyl(RADIUS, BODY_H - RADIUS * 0.5), red, Vector3(0, (BODY_H - RADIUS * 0.5) * 0.5, 0)))
	var dome := SphereMesh.new()
	dome.radius = RADIUS
	dome.height = RADIUS
	dome.is_hemisphere = true
	root.add_child(_mesh(dome, red, Vector3(0, BODY_H - RADIUS * 0.5, 0)))
	root.add_child(_mesh(_cyl(RADIUS + 0.004, 0.02), black, Vector3(0, 0.01, 0)))  # the foot ring
	root.add_child(_mesh(_cyl(RADIUS + 0.002, 0.16), label, Vector3(0, 0.24, 0)))  # the label band
	root.add_child(_mesh(_box(Vector3(0.05, 0.03, 0.002)), red, Vector3(0, 0.26, -RADIUS - 0.003)))
	# The valve head: neck, body, the fixed handle and the squeeze lever over it.
	var top := BODY_H + 0.02
	root.add_child(_mesh(_cyl(0.022, 0.05), steel, Vector3(0, top, 0)))
	root.add_child(_mesh(_box(Vector3(0.05, 0.05, 0.08)), black, Vector3(0, top + 0.045, 0)))
	var handle := _mesh(_box(Vector3(0.03, 0.012, 0.14)), black, Vector3(0, top + 0.06, 0.07))
	handle.rotation.x = deg_to_rad(-8.0)
	root.add_child(handle)
	var lever := _mesh(_box(Vector3(0.028, 0.01, 0.14)), steel, Vector3(0, top + 0.09, 0.06))
	lever.rotation.x = deg_to_rad(12.0)
	root.add_child(lever)
	# The safety pin through the head, its ring and a tag.
	var pin := _mesh(_cyl(0.003, 0.07), steel, Vector3(0, top + 0.05, -0.01))
	pin.rotation.z = PI * 0.5
	root.add_child(pin)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.011
	ring.outer_radius = 0.015
	var r := _mesh(ring, yellow, Vector3(0.045, top + 0.05, -0.01))
	r.rotation.z = PI * 0.5
	root.add_child(r)
	root.add_child(_mesh(_box(Vector3(0.002, 0.03, 0.02)), yellow, Vector3(0.06, top + 0.025, -0.01)))
	# The gauge on the head's front, its needle turned by the charge.
	var gauge := Node3D.new()
	gauge.name = "Gauge"
	gauge.position = Vector3(0, top + 0.045, -0.045)
	gauge.rotation.x = PI * 0.5
	gauge.add_child(_mesh(_cyl(0.017, 0.008), steel, Vector3.ZERO))
	gauge.add_child(_mesh(_cyl(0.014, 0.002), dial, Vector3(0, -0.005, 0)))
	var green := _mesh(_box(Vector3(0.012, 0.001, 0.004)), _mat(Color(0.1, 0.7, 0.2), 0.0, 0.5), Vector3(0.006, -0.0065, -0.006))
	gauge.add_child(green)
	var needle := Node3D.new()
	needle.name = "Needle"
	needle.position.y = -0.007
	var tip := _mesh(_box(Vector3(0.012, 0.001, 0.0015)), _mat(Color(0.8, 0.05, 0.05), 0.0, 0.5), Vector3(0.006, 0, 0))
	needle.add_child(tip)
	gauge.add_child(needle)
	root.add_child(gauge)
	# The hose out of the head's back, down the side, and the horn clipped to the bottle.
	var hose_a := _mesh(_cyl(0.008, 0.08), black, Vector3(0, top + 0.02, 0.06))
	hose_a.rotation.x = deg_to_rad(60.0)
	root.add_child(hose_a)
	root.add_child(_mesh(_cyl(0.008, 0.36), black, Vector3(0.0, 0.34, RADIUS + 0.014)))
	var horn := Node3D.new()
	horn.name = "Horn"
	horn.position = Vector3(0.0, 0.14, RADIUS + 0.03)
	horn.rotation.x = deg_to_rad(-90.0)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.012
	cone.bottom_radius = 0.035
	cone.height = 0.16
	var horn_mesh := _mesh(cone, black, Vector3(0, 0, 0))
	horn_mesh.rotation.x = deg_to_rad(90.0)
	horn.add_child(horn_mesh)
	root.add_child(horn)
	root.add_child(_mesh(_box(Vector3(0.03, 0.02, 0.02)), black, Vector3(0, 0.22, RADIUS + 0.008)))
	return root


static func _bracket_look() -> Node3D:
	var root := Node3D.new()
	var black := _mat(Color(0.08, 0.08, 0.08), 0.4, 0.5)
	# A wall plate, a strap round the bottle and a hook under the valve.
	root.add_child(_mesh(_box(Vector3(0.1, 0.4, 0.012)), black, Vector3(0, 0.3, -0.006)))
	root.add_child(_mesh(_box(Vector3(0.05, 0.02, 0.07)), black, Vector3(0, BODY_H - 0.04, -0.035)))
	root.add_child(_mesh(_box(Vector3(RADIUS * 2.2, 0.025, 0.012)), black, Vector3(0, 0.3, -RADIUS * 2.0 - 0.03)))
	return root


func _make_cloud() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Spray"
	p.amount = 220
	p.lifetime = spray_reach_m / spray_speed * 1.6
	p.emitting = false
	p.local_coords = false
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0, -1)
	m.spread = 9.0
	m.initial_velocity_min = spray_speed * 0.8
	m.initial_velocity_max = spray_speed * 1.1
	m.damping_min = spray_speed * 0.5
	m.damping_max = spray_speed * 0.8
	m.gravity = Vector3(0, -1.2, 0)
	m.scale_min = 0.6
	m.scale_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.15))
	grow.add_point(Vector2(1, 1.0))
	var tex := CurveTexture.new()
	tex.curve = grow
	m.scale_curve = tex
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.75))
	fade.set_color(1, Color(0.95, 0.96, 1.0, 0.0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	m.color_ramp = ft
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _puff()
	q.material = mat
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	return p


## A soft round puff texture for the cloud.
static func _puff() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


static func _mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


static func _mesh(mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	return m


static func _cyl(radius: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = h
	c.radial_segments = 18
	return c


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
