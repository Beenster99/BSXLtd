extends Node3D
## The kit round the ship in the bay: a scissor lift you drive round the hull and raise, a
## ground power unit on wheels whose cable you clip to the hull by hand, and mobile scaffold
## rigs (scaffold_rig.gd) you set up as big as you need, drive in to the hull and back out. The lift starts
## at the side door with its platform down: walk up its ramp, press UP on the platform's
## control box and it stops level with the door sill, so you can walk aboard (there are no
## stairs). UP and DOWN on either control box send the platform to the next stop (board,
## door sill, flank, roof) and stop it if it's moving; F on a box's body takes the lift for
## driving: the arrow keys drive and turn it, Page Up and Page Down raise and lower it
## smoothly. Neither vehicle drives or lifts into anything: it stops at the hull, the
## cradles and walls.
##
## The power unit: F on its handle tows it (the arrow keys again). F on the plug on its hook
## takes the plug in your hand; F on the ship's hull clips it there (a magnetic plug: any
## point of the hull within the cable's reach); F on it again takes it back, F on the hook
## hangs it up. Its switch turns the power on; the ship is powered while the switch is on
## and the plug is on the hull. Drive the unit out of the cable's reach and the plug pops
## off and reels in.
##
## Every Use target carries meta "ship_bay_use", a Callable the bay calls. While the plug is
## in your hand the bay hands F to `place_plug` instead. Bay space: the ship's deck (y = 0 in
## ship space) is `deck` metres up; ship x and z are the bay's. Built by Bay._build_access.
## Multiplayer: the lift, its platform, the unit and the plug are movers ("bay_lift",
## "bay_lift_deck", "bay_unit", "bay_plug"); whoever drives one claims it.

## Power to the ship changed (the bay passes it to the bus).
signal power_switched(on: bool)

## The lift's stops, platform top over the floor, metres: board, flank, roof. The door sill's
## height is added as a stop when the lift is built.
@export var lift_levels: Array[float] = [0.35, 2.4, 4.5]
## How fast the lift platform rises and falls, metres per second.
@export var lift_speed := 0.6
## Driving speed and turn rate of the lift and the power unit (m/s, rad/s).
@export var drive_speed := 0.9
@export var turn_speed := 0.7
## The power unit's cable, metres from its outlet.
@export var cable_length := 14.0

const W := 1.4           # the lift platform across (local x; +X is its open work face)
const L := 2.6           # and along (local z; its ramp is at +Z)
const BASE_TOP := 0.3
const STAGES := 3
const RAIL_H := 1.05
const RAMP := 1.3
## Collision bottoms of the vehicles over the floor, so driving never scrapes it, metres.
const CLEAR := 0.06
const UNIT_BODY := Vector3(1.0, 0.95, 1.5)
## Where the cable leaves the unit and the plug's hook (unit space).
const OUTLET := Vector3(-0.53, 0.6, -0.3)
const HOOK := Vector3(-0.6, 0.85, 0.15)
const CABLE_SEGMENTS := 24
const USE_REACH := 3.5
const Rig := preload("res://modules/ship_bay/internal/bay/scaffold_rig.gd")
## Where the scaffold rigs stand to start with (bay space, the ship's starboard side, out of
## the way): [origin, yaw]. Each rig runs along its z from its origin; yaw PI turns its open
## work face to the ship.
const RIG_PARKING := [[Vector3(7.6, 0, -1.0), PI], [Vector3(7.6, 0, 5.2), PI]]

var deck := 1.6
## The lift: its root (moved when driven), chassis and platform bodies, the platform's target.
var lift: Node3D
var chassis: AnimatableBody3D
var platform: AnimatableBody3D
var lift_target := 0.35
var stops: Array[float] = []
## The power unit and its plug. plug_state: "hook", "hand" or "hull".
var unit: Node3D
var unit_body: AnimatableBody3D
var plug: Node3D
var plug_state := "hook"
var switch_on := false
## True while the ship is powered: the switch on and the plug on the hull.
var power_on := false
## The scaffold rigs round the bay.
var scaffolds: Array[Node3D] = []
## The vehicle this player drives: "", "lift", "unit" or "rig<i>".
var driving := ""
## The ship's root (in the bay): the plug clips only to it.
var ship: Node3D
var _arms: Array[MeshInstance3D] = []
var _gate: CollisionShape3D
var _gate_bar: MeshInstance3D
var _cable: Array[MeshInstance3D] = []
var _switch_lamp: MeshInstance3D
var _socket := Vector3.ZERO          # the ship's power socket, bay space
var _plug_body: StaticBody3D
var _plug_shape: CollisionShape3D
var _hud: Label
var _hums: Dictionary = {}       # vehicle -> AudioStreamPlayer3D
var _net: Node
var _lit_on: Material
var _lit_wait: Material
var _lit_off: Material
var _yellow: Material
var _steel: Material
var _dark: Material
var _rubber: Material
var _tread: Material


## Builds round a ship whose side door sill and power socket are given in ship space.
func build(cradle_height: float, door_sill: Vector3, socket: Vector3, ship_root: Node3D = null) -> void:
	deck = cradle_height
	ship = ship_root
	_yellow = ShipSurface.of(ShipKit.paint(Color(0.95, 0.75, 0.1), 0.15, 0.5, "hazard_paint"))
	_steel = ShipSurface.of(ShipKit.paint(Color(0.55, 0.57, 0.6), 0.85, 0.3, "chrome"))
	_dark = ShipSurface.of(ShipKit.paint(Color(0.15, 0.16, 0.18), 0.5, 0.5, "gunmetal"))
	_rubber = ShipSurface.of(ShipKit.paint(Color(0.07, 0.07, 0.075), 0.0, 0.9, "rubber"))
	_tread = ShipSurface.of(ShipKit.paint(Color(0.42, 0.44, 0.46), 0.8, 0.45))
	_lit_on = ShipKit.glow(Color(0.35, 1.0, 0.5), 2.5)
	_lit_wait = ShipKit.glow(Color(1.0, 0.7, 0.15), 2.2)
	_lit_off = ShipKit.glow(Color(1.0, 0.25, 0.12), 2.0)
	var sill := door_sill + Vector3(0, deck, 0)
	for h: float in lift_levels + [sill.y]:
		if not stops.has(h):
			stops.append(h)
	stops.sort()
	# The lift stands at the side door, its open face to the hull (the door is on -X, so the
	# lift's +X faces +X: it stands outboard of the sill).
	_build_lift(Transform3D(Basis(), Vector3(sill.x - 0.03 - W * 0.5, 0, sill.z)))
	_build_power_unit(socket + Vector3(0, deck, 0))
	for i in RIG_PARKING.size():
		var rig: Node3D = Rig.new()
		rig.name = "Scaffold%d" % (i + 1)
		rig.set("label", str(i + 1))
		rig.transform = Transform3D(Basis(Vector3.UP, RIG_PARKING[i][1]), RIG_PARKING[i][0])
		add_child(rig)
		rig.connect("change_requested", _ask_rig.bind(i))
		rig.connect("drive_requested", toggle_drive.bind("rig%d" % i))
		scaffolds.append(rig)
	var bus := Modules.bus("ship_bay") as ShipBayBus
	if bus:
		bus.kit_changed.connect(_on_kit)
	_net = Modules.bus("multiplayer")
	if _net and not _net.has_method("register_mover"):
		_net = null
	if _net:
		for pair: Array in [["bay_lift", lift], ["bay_lift_deck", platform], ["bay_unit", unit], ["bay_plug", plug]]:
			_net.call("register_mover", pair[0], pair[1])
		for i in scaffolds.size():
			_net.call("register_mover", "bay_rig%d" % i, scaffolds[i])
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hud = BsxTheme.hud_label("", 18)
	_hud.position = Vector2(24, 24)
	_hud.visible = false
	layer.add_child(_hud)


func _exit_tree() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	if bus and bus.kit_changed.is_connected(_on_kit):
		bus.kit_changed.disconnect(_on_kit)
	if _net:
		var ids: Array = ["bay_lift", "bay_lift_deck", "bay_unit", "bay_plug"]
		for i in scaffolds.size():
			ids.append("bay_rig%d" % i)
		for id: String in ids:
			_net.call("unregister_mover", id)
			if bool(_net.call("is_mine", id)):
				_net.call("release", id)


# --- Scissor lift ---------------------------------------------------------------------------

func _build_lift(at: Transform3D) -> void:
	lift = Node3D.new()
	lift.name = "ScissorLift"
	lift.transform = at
	add_child(lift)
	chassis = AnimatableBody3D.new()
	chassis.name = "Chassis"
	chassis.sync_to_physics = false
	chassis.set_meta("surface", "metal")
	lift.add_child(chassis)
	# The chassis on four wheels.
	_part(PartShapes.chamfer_box(Vector3(W - 0.1, BASE_TOP - 0.12, L - 0.2), 0.03), Transform3D(Basis(), Vector3(0, 0.12 + (BASE_TOP - 0.12) * 0.5, 0)), _yellow, chassis)
	_collide(Vector3(W - 0.1, BASE_TOP - CLEAR, L - 0.2), Transform3D(Basis(), Vector3(0, (BASE_TOP + CLEAR) * 0.5, 0)), chassis)
	for x: float in [-W * 0.5 + 0.12, W * 0.5 - 0.12]:
		for z: float in [-L * 0.5 + 0.3, L * 0.5 - 0.3]:
			_part(PartShapes.prism(14, 0.13, 0.1), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, 0.13, z)), _rubber, chassis)
	# A ramp up onto the platform at its +Z end (the platform rests at the first stop).
	var low := stops[0]
	var slope := atan2(low - CLEAR, RAMP)
	var rb := Basis(Vector3.RIGHT, slope)
	var ramp_at := Vector3(0, (low + CLEAR) * 0.5, L * 0.5 + RAMP * 0.5)
	_part(PartShapes.box(Vector3(W - 0.3, 0.04, RAMP + 0.05)), Transform3D(rb, ramp_at + Vector3(0, 0.0, 0)), _tread, chassis)
	_collide(Vector3(W - 0.3, 0.04, RAMP + 0.08), Transform3D(rb, ramp_at - rb.y * 0.02), chassis)
	# Ground controls on the outboard side, by the ramp.
	var ground := Transform3D(Basis(Vector3.UP, PI), Vector3(-W * 0.5 - 0.06, 0.85, L * 0.5 - 0.4))
	_control_box(ground, chassis, "LIFT")
	_part(WreckParts.pipe(0.03, 0.6, false), Transform3D(Basis(), Vector3(-W * 0.5 - 0.06, 0.45, L * 0.5 - 0.4)), _dark, chassis)

	# The platform: a grating deck with toe boards and rails on three sides; its +X side (the
	# work face, to the hull) is open and its +Z side has a gate bar that closes once it's up.
	platform = AnimatableBody3D.new()
	platform.name = "LiftPlatform"
	platform.sync_to_physics = false
	platform.set_meta("surface", "grating")
	lift.add_child(platform)
	_part(WreckParts.grating(W, L), Transform3D(Basis(), Vector3(0, -0.02, 0)), _tread, platform)
	_part(PartShapes.box(Vector3(W + 0.04, 0.12, L + 0.04)), Transform3D(Basis(), Vector3(0, -0.08, 0)), _yellow, platform)
	_collide(Vector3(W, 0.1, L), Transform3D(Basis(), Vector3(0, -0.05, 0)), platform)
	for rail: Array in [[Vector3(-W * 0.5, 0, 0), Vector3(0.04, 0, L)], [Vector3(0, 0, -L * 0.5), Vector3(W, 0, 0.04)]]:
		var r_at: Vector3 = rail[0]
		var size: Vector3 = rail[1]
		for y: float in [RAIL_H, RAIL_H * 0.5]:
			_part(PartShapes.box(Vector3(maxf(size.x, 0.04), 0.04, maxf(size.z, 0.04))), Transform3D(Basis(), r_at + Vector3(0, y, 0)), _yellow, platform)
		_part(PartShapes.box(Vector3(maxf(size.x, 0.02), 0.12, maxf(size.z, 0.02))), Transform3D(Basis(), r_at + Vector3(0, 0.06, 0)), _yellow, platform)
		_collide(Vector3(maxf(size.x, 0.04), RAIL_H, maxf(size.z, 0.04)), Transform3D(Basis(), r_at + Vector3(0, RAIL_H * 0.5, 0)), platform)
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(-1, 0)]:
		_part(PartShapes.box(Vector3(0.04, RAIL_H, 0.04)), Transform3D(Basis(), Vector3(c.x * W * 0.5, RAIL_H * 0.5, c.y * L * 0.5)), _yellow, platform)
	_gate_bar = _part(PartShapes.box(Vector3(W, 0.04, 0.04)), Transform3D(Basis(), Vector3(0, RAIL_H, L * 0.5)), _yellow, platform)
	_gate = _collide(Vector3(W, RAIL_H, 0.04), Transform3D(Basis(), Vector3(0, RAIL_H * 0.5, L * 0.5)), platform)
	_control_box(Transform3D(Basis(Vector3.UP, PI), Vector3(-W * 0.5 - 0.06, RAIL_H - 0.1, -L * 0.25)), platform, "UP / DOWN")
	# The scissor arms, two stacks (one each side), redrawn as the platform moves.
	var arm_mesh := PartShapes.box(Vector3(0.06, 0.08, 1.0)).mesh
	for side in 2:
		for stage in STAGES:
			for k in 2:
				var mi := MeshInstance3D.new()
				mi.mesh = arm_mesh
				mi.material_override = _yellow
				lift.add_child(mi)
				_arms.append(mi)
	lift_target = stops[0]
	_set_platform(stops[0])


## UP on a control box: on to the next stop above (or stop where it is, if moving).
func lift_up() -> void:
	_step_lift(1)


## DOWN on a control box: down to the next stop below (or stop where it is, if moving).
func lift_down() -> void:
	_step_lift(-1)


func _step_lift(way: int) -> void:
	_claim("bay_lift_deck")
	var y := lift_height()
	if absf(lift_target - y) > 0.01:
		lift_target = y
		return
	var next := y
	for h: float in stops:
		if way > 0 and h > y + 0.02:
			next = h
			break
		if way < 0 and h < y - 0.02:
			next = h
	lift_target = next
	Sfx.play("click", platform)


## Puts the platform at `h` at once (screenshots, saves).
func set_lift_height(h: float) -> void:
	lift_target = clampf(h, stops[0], stops[stops.size() - 1])
	_set_platform(lift_target)


## Platform top over the floor, metres.
func lift_height() -> float:
	return platform.position.y if platform else 0.0


func _set_platform(y: float) -> void:
	platform.position = Vector3(0, y, 0)
	var raised := y > stops[0] + 0.2
	_gate.disabled = not raised
	_gate_bar.visible = raised
	var bottom := BASE_TOP + 0.02
	var h := maxf(y - 0.14 - bottom, 0.01)
	var stage_h := h / float(STAGES)
	var bar := L - 0.5
	var span := sqrt(maxf(bar * bar - stage_h * stage_h, 0.01))
	var i := 0
	for side in 2:
		var x := -W * 0.5 + 0.15 if side == 0 else W * 0.5 - 0.15
		for stage in STAGES:
			for k in 2:
				var y0 := bottom + stage_h * float(stage)
				var a := Vector3(x, y0, -span * 0.5) if k == 0 else Vector3(x, y0 + stage_h, -span * 0.5)
				var b := Vector3(x, y0 + stage_h, span * 0.5) if k == 0 else Vector3(x, y0, span * 0.5)
				var dir := (b - a).normalized()
				var basis := Basis(Vector3.RIGHT, dir.cross(Vector3.RIGHT), dir * a.distance_to(b))
				_arms[i].transform = Transform3D(basis, (a + b) * 0.5 + Vector3(0.07 * (float(k) - 0.5), 0, 0))
				i += 1


# --- Driving ----------------------------------------------------------------------------------

## F on a control box's body (the lift) or the unit's handle: take it for driving, or let it go.
func toggle_drive(which: String) -> void:
	if driving == which:
		_let_go()
		return
	if driving != "":
		_let_go()
	driving = which
	for id: String in _movers_of(which):
		_claim(id)
	if which == "lift":
		_hud.text = "Driving the scissor lift\nArrow keys drive  ·  %s / %s raise and lower\nF on its controls lets it go" \
				% [_key_name("ship_bay.raise", "Page Up"), _key_name("ship_bay.lower", "Page Down")]
	elif which == "unit":
		_hud.text = "Towing the power unit\nArrow keys drive\nF on its handle lets it go"
	else:
		_hud.text = "Moving scaffold %s\nUp / Down along it  ·  Left / Right sideways  ·  hold %s to turn\nMOVE on its post lets it go" \
				% [_root_of(which).get("label"), _key_name(Keys.RUN, "Shift")]
	_hud.visible = true
	Sfx.play("click", _root_of(which))


func _let_go() -> void:
	if _net:
		for id: String in _movers_of(driving):
			_net.call("release", id)
	driving = ""
	_hud.visible = false


func _movers_of(which: String) -> Array:
	if which == "lift":
		return ["bay_lift", "bay_lift_deck"]
	if which == "unit":
		return ["bay_unit"]
	return ["bay_" + which] if which.begins_with("rig") else []


## The root node a vehicle moves by, and the bodies that ride on it.
func _root_of(which: String) -> Node3D:
	if which == "lift":
		return lift
	if which == "unit":
		return unit
	var i := which.trim_prefix("rig").to_int()
	return scaffolds[i] if which.begins_with("rig") and i < scaffolds.size() else null


func _bodies_of(which: String) -> Array:
	if which == "lift":
		return [chassis, platform]
	if which == "unit":
		return [unit_body]
	var rig := _root_of(which)
	return [rig.get("body")] if rig else []


## Drives `which` by `forward` (metres, along its -Z), `side` (metres, along its +X: the
## scaffold rigs' castors swivel) and turns it by `turn` (radians, to the left) if nothing is
## in the way. True if it moved. Tests and the keys call it.
func drive(which: String, forward: float, turn: float, side := 0.0) -> bool:
	var root := _root_of(which)
	var bodies := _bodies_of(which)
	if root == null:
		return false
	var from := root.global_transform
	var basis := from.basis.rotated(Vector3.UP, turn)
	var to := Transform3D(basis, from.origin - basis.z * forward + basis.x * side)
	if not _clear(bodies, from, to):
		return false
	root.global_transform = to
	_cable_dirty()
	return true


## Whether `bodies` (each riding on a root at `from`) could move with the root to `to`
## without running into anything but each other and people.
func _clear(bodies: Array, from: Transform3D, to: Transform3D) -> bool:
	var own: Array[RID] = []
	for b: CollisionObject3D in bodies:
		own.append(b.get_rid())
	for b: CollisionObject3D in bodies:
		var rel := from.affine_inverse() * b.global_transform
		var target := to * rel
		var params := PhysicsTestMotionParameters3D.new()
		params.from = Transform3D(target.basis, b.global_transform.origin)
		params.motion = target.origin - b.global_transform.origin
		params.exclude_bodies = own
		params.max_collisions = 8
		params.recovery_as_collision = true
		params.margin = 0.002
		var result := PhysicsTestMotionResult3D.new()
		if PhysicsServer3D.body_test_motion(b.get_rid(), params, result):
			for i in result.get_collision_count():
				if not (result.get_collider(i) is CharacterBody3D):
					return false
	return true


func _physics_process(delta: float) -> void:
	if platform == null:
		return
	# The platform toward its target, stopping where something is in the way.
	var y := lift_height()
	var moving_deck := false
	if _drives("bay_lift_deck"):
		if driving == "lift":
			var lift_in := _axis("ship_bay.raise", KEY_PAGEUP, "ship_bay.lower", KEY_PAGEDOWN)
			if lift_in != 0.0:
				lift_target = clampf(y + lift_in * lift_speed * 0.25, stops[0], stops[stops.size() - 1])
		if absf(y - lift_target) > 0.0005:
			var ny := move_toward(y, lift_target, lift_speed * delta)
			if _clear_lift(ny - y):
				_set_platform(ny)
				moving_deck = true
			else:
				lift_target = y
				Sfx.play("error", platform)
	else:
		_set_platform(y)
	# The vehicle this player drives.
	var moving := ""
	if driving != "" and _drives(_movers_of(driving)[0]):
		var fwd := _axis("ship_bay.drive_forward", KEY_UP, "ship_bay.drive_back", KEY_DOWN)
		var turn := _axis("ship_bay.drive_left", KEY_LEFT, "ship_bay.drive_right", KEY_RIGHT)
		var side := 0.0
		# A rig crabs sideways on its castors (towards its work face with right); holding run
		# turns it instead.
		if driving.begins_with("rig") and _held(Keys.RUN, KEY_SHIFT) == 0.0:
			side = -turn * drive_speed * delta
			turn = 0.0
		if fwd != 0.0 or turn != 0.0 or side != 0.0:
			if drive(driving, fwd * drive_speed * delta, turn * turn_speed * delta, side):
				moving = driving
	_hum("lift", moving_deck or moving == "lift")
	_hum("unit", moving == "unit")
	for i in scaffolds.size():
		_hum("rig%d" % i, moving == "rig%d" % i)
	_update_plug()


func _clear_lift(dy: float) -> bool:
	var params := PhysicsTestMotionParameters3D.new()
	params.from = platform.global_transform
	params.motion = Vector3(0, dy, 0)
	params.exclude_bodies = [chassis.get_rid(), platform.get_rid()] as Array[RID]
	params.max_collisions = 8
	params.margin = 0.002
	var result := PhysicsTestMotionResult3D.new()
	if PhysicsServer3D.body_test_motion(platform.get_rid(), params, result):
		for i in result.get_collision_count():
			if not (result.get_collider(i) is CharacterBody3D):
				return false
	return true


func _hum(which: String, on: bool) -> void:
	if on and not _hums.has(which):
		_hums[which] = Sfx.loop("servo", _root_of(which))
	elif not on and _hums.has(which):
		(_hums[which] as Node).queue_free()
		_hums.erase(which)


# --- Scaffold rigs --------------------------------------------------------------------------

## A rig's post asked for a change (checked there): send it to every peer.
func _ask_rig(bays: int, lifts: int, ends: int, i: int) -> void:
	var payload := {"rig": i, "bays": bays, "lifts": lifts, "ends": ends}
	var bus := Modules.bus("ship_bay") as ShipBayBus
	if bus:
		bus.change_kit(payload)
	else:
		_on_kit(payload)


func _on_kit(payload: Dictionary) -> void:
	var i := int(payload.get("rig", -1))
	if i >= 0 and i < scaffolds.size():
		scaffolds[i].call("configure", int(payload["bays"]), int(payload["lifts"]), int(payload["ends"]))


# --- Ground power -------------------------------------------------------------------------

## A ground power unit on wheels, a tow handle, a switch panel, and a cable on a hook.
func _build_power_unit(socket: Vector3) -> void:
	_socket = socket
	unit = Node3D.new()
	unit.name = "PowerUnit"
	unit.position = Vector3(socket.x + 2.1, 0, socket.z + 1.6)
	add_child(unit)
	unit_body = AnimatableBody3D.new()
	unit_body.name = "Body"
	unit_body.sync_to_physics = false
	unit.add_child(unit_body)
	var body := UNIT_BODY
	var u := unit_body
	_part(PartShapes.chamfer_box(body, 0.06), Transform3D(Basis(), Vector3(0, 0.25 + body.y * 0.5, 0)), _yellow, u)
	_part(PartShapes.louvre(0.7, 0.5, 0.04, 6), Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(body.x * 0.5 + 0.01, 0.75, 0.3)), _dark, u)
	_part(PartShapes.box(Vector3(0.9, 0.06, 1.4)), Transform3D(Basis(), Vector3(0, 0.25 + body.y + 0.03, 0)), _dark, u)
	for x: float in [-0.4, 0.4]:
		for z: float in [-0.55, 0.55]:
			_part(PartShapes.prism(14, 0.15, 0.1), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, 0.15, z)), _rubber, u)
	_collide(Vector3(body.x, 0.25 + body.y + 0.06 - CLEAR, body.z), Transform3D(Basis(), Vector3(0, (0.25 + body.y + 0.06 + CLEAR) * 0.5, 0)), u)
	# The tow bar and an upright handle at its end: F on the handle tows the unit.
	_part(PartShapes.box(Vector3(0.05, 0.05, 0.75)), Transform3D(Basis(), Vector3(0, 0.3, -body.z * 0.5 - 0.37)), _dark, u)
	var handle := Vector3(0, 0.62, -body.z * 0.5 - 0.75)
	_part(WreckParts.pipe(0.025, 0.66, false), Transform3D(Basis(), handle), _dark, u)
	_part(WreckParts.pipe(0.03, 0.4, false), Transform3D(Basis(Vector3.BACK, PI * 0.5), handle + Vector3(0, 0.33, 0)), _rubber, u)
	_collide(Vector3(0.45, 0.75, 0.14), Transform3D(Basis(), handle), u).set_meta("ship_bay_use", toggle_drive.bind("unit"))
	# The panel on the +Z face: its switch lamp red off, amber on with the plug off the hull,
	# green while it powers the ship. F on the panel flips the switch.
	var face := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.95, body.z * 0.5 + 0.01))
	_part(PartShapes.box(Vector3(0.6, 0.4, 0.03)), face * Transform3D(Basis(), Vector3(0, 0, -0.015)), _dark, u)
	_switch_lamp = _part(PartShapes.box(Vector3(0.14, 0.14, 0.04)), face * Transform3D(Basis(), Vector3(0.15, 0.02, -0.03)), _lit_off, u)
	_sign("SHORE POWER\n400 Hz", face * Transform3D(Basis(Vector3.UP, PI), Vector3(-0.08, 0.05, -0.035)), 22, u)
	_collide(Vector3(0.64, 0.44, 0.06), face * Transform3D(Basis(), Vector3(0, 0, -0.02)), u).set_meta("ship_bay_use", toggle_power)
	# The outlet and the plug's hook on the -X side.
	_part(PartShapes.box(Vector3(0.06, 0.12, 0.12)), Transform3D(Basis(), OUTLET), _dark, u)
	_part(PartShapes.box(Vector3(0.12, 0.04, 0.06)), Transform3D(Basis(), HOOK + Vector3(0.04, -0.08, 0)), _steel, u)
	_collide(Vector3(0.24, 0.3, 0.24), Transform3D(Basis(), HOOK), u).set_meta("ship_bay_use", use_plug)
	# The plug: a magnetic puck on the cable's end.
	plug = Node3D.new()
	plug.name = "Plug"
	add_child(plug)
	_part(PartShapes.prism(14, 0.06, 0.08), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.04)), _dark, plug)
	_part(PartShapes.prism(14, 0.045, 0.012), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.086)), _lit_wait, plug)
	_plug_body = StaticBody3D.new()
	plug.add_child(_plug_body)
	_plug_shape = _collide(Vector3(0.16, 0.16, 0.12), Transform3D(Basis(), Vector3(0, 0, -0.04)), _plug_body)
	_plug_shape.set_meta("ship_bay_use", use_plug)
	# The cable, redrawn when anything at its ends moves.
	var cable := ShipSurface.of(ShipKit.paint(Color(0.08, 0.08, 0.09), 0.0, 0.8, "rubber"))
	var seg := PartShapes.prism(8, 0.022, 1.0).mesh
	for i in CABLE_SEGMENTS:
		var mi := MeshInstance3D.new()
		mi.mesh = seg
		mi.material_override = cable
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_cable.append(mi)
	_place_plug_on_hook()


## F on the plug or its hook: take the plug off the hook or the hull, or hang it up again.
func use_plug() -> void:
	if plug_state == "hand":
		plug_state = "hook"
		_place_plug_on_hook()
		Sfx.play("clunk", plug)
	else:
		plug_state = "hand"
		_claim("bay_plug")
		Sfx.play("click", plug)
	# In hand it is no obstacle (nor something your own F lands on).
	_plug_shape.disabled = plug_state == "hand"
	_update_power()


## True while the plug is in this player's hand (the bay sends F to place_plug then).
func holding_plug() -> bool:
	return plug_state == "hand"


## F with the plug in hand, looking along `direction` from `from` (world space): on the
## ship's hull within the cable's reach it clips on there; on the hook it hangs up. True if
## it went somewhere.
func place_plug(from: Vector3, direction: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, from + direction.normalized() * USE_REACH)
	q.exclude = [_plug_body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		Sfx.play("error", plug)
		return false
	var body := hit.collider as Node
	if body == unit_body:
		use_plug()
		return true
	var point: Vector3 = hit.position
	if ship and body and ship.is_ancestor_of(body) and point.distance_to(unit_body.to_global(OUTLET)) <= cable_length:
		clip_plug(point, hit.normal)
		return true
	Sfx.play("error", plug)
	return false


## Clips the plug onto the hull at `point` (world), its face on the surface with `normal`.
func clip_plug(point: Vector3, normal: Vector3) -> void:
	var n := normal.normalized()
	var up := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var x := up.cross(n).normalized()
	plug.global_transform = Transform3D(Basis(x, n.cross(x), n), point + n * 0.006 + n * 0.086)
	plug_state = "hull"
	_plug_shape.disabled = false
	_claim("bay_plug")
	Sfx.play("clunk", plug)
	_cable_dirty()
	_update_power()


func _place_plug_on_hook() -> void:
	plug.global_transform = unit_body.global_transform * Transform3D(Basis(Vector3.UP, PI * 0.5), HOOK + Vector3(0, -0.2, 0))
	_cable_dirty()


func _update_plug() -> void:
	if plug == null:
		return
	if _drives("bay_plug"):
		match plug_state:
			"hook":
				_place_plug_on_hook()
			"hand":
				var cam := get_viewport().get_camera_3d()
				if cam:
					var b := cam.global_basis
					plug.global_transform = Transform3D(b, cam.global_position - b.z * 0.55 - b.y * 0.28 + b.x * 0.18)
					_cable_dirty()
			"hull":
				if plug.global_position.distance_to(unit_body.to_global(OUTLET)) > cable_length + 0.2:
					# Out of reach: it pops off and reels in.
					plug_state = "hook"
					_place_plug_on_hook()
					Sfx.play("thud", plug)
					_update_power()
	_draw_cable()


var _cable_from := Vector3.INF
var _cable_to := Vector3.INF


func _cable_dirty() -> void:
	_cable_from = Vector3.INF


func _draw_cable() -> void:
	var a := unit_body.to_global(OUTLET)
	var b := plug.global_transform * Vector3(0, 0, 0.0)
	if a.is_equal_approx(_cable_from) and b.is_equal_approx(_cable_to):
		return
	_cable_from = a
	_cable_to = b
	var d := a.distance_to(b)
	var sag := sqrt(maxf(cable_length * cable_length - d * d, 0.0)) * 0.35
	var prev := a
	for i in CABLE_SEGMENTS:
		var t := float(i + 1) / float(CABLE_SEGMENTS)
		var p := a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
		p.y = maxf(p.y, 0.025)
		var seg := p - prev
		var mi := _cable[i]
		var basis := _along(seg) if seg.length() > 0.0001 else Basis()
		mi.global_transform = Transform3D(basis.scaled_local(Vector3(1, seg.length() + 0.01, 1)), (p + prev) * 0.5)
		prev = p


func toggle_power() -> void:
	switch_on = not switch_on
	Sfx.play("click", unit)
	_update_power()


## Power from outside (the bus, a save): on means switched on and plugged into the ship's
## socket; off switches the unit off (the plug stays where it is).
func set_power(on: bool) -> void:
	if on == power_on:
		return
	switch_on = on
	if on and plug_state != "hull":
		clip_plug(to_global(_socket), Vector3.RIGHT)
	_update_power()


func _update_power() -> void:
	var on := switch_on and plug_state == "hull"
	if _switch_lamp:
		_switch_lamp.material_override = _lit_on if on else (_lit_wait if switch_on else _lit_off)
	if on == power_on:
		return
	power_on = on
	power_switched.emit(on)


# --- Helpers ----------------------------------------------------------------------------------

## A control box with an UP (green) and a DOWN (amber) button under a label. F on a button
## steps the platform; F on the box takes the lift for driving.
func _control_box(xform: Transform3D, parent: CollisionObject3D, title: String) -> void:
	_part(PartShapes.chamfer_box(Vector3(0.12, 0.26, 0.2), 0.02), xform, _dark, parent)
	_part(PartShapes.box(Vector3(0.03, 0.06, 0.06)), xform * Transform3D(Basis(), Vector3(0.07, 0.05, 0)), ShipKit.glow(Color(0.35, 1.0, 0.5), 1.5), parent)
	_part(PartShapes.box(Vector3(0.03, 0.06, 0.06)), xform * Transform3D(Basis(), Vector3(0.07, -0.05, 0)), ShipKit.glow(Color(1.0, 0.6, 0.15), 1.5), parent)
	_sign(title, xform * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.065, 0.11, 0)), 14, parent)
	_sign("UP", xform * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.087, 0.05, -0.065)), 12, parent)
	_sign("DN", xform * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.087, -0.05, -0.065)), 12, parent)
	_collide(Vector3(0.12, 0.3, 0.24), xform, parent).set_meta("ship_bay_use", toggle_drive.bind("lift"))
	_collide(Vector3(0.05, 0.08, 0.1), xform * Transform3D(Basis(), Vector3(0.085, 0.05, 0)), parent).set_meta("ship_bay_use", lift_up)
	_collide(Vector3(0.05, 0.08, 0.1), xform * Transform3D(Basis(), Vector3(0.085, -0.05, 0)), parent).set_meta("ship_bay_use", lift_down)


func _drives(id: String) -> bool:
	return _net == null or bool(_net.call("drives", id))


func _claim(id: String) -> void:
	if _net and not bool(_net.call("is_mine", id)):
		_net.call("claim", id)


## A key pair as an axis (+1 for the first): the bound actions, or the keys before Core's
## key map is in.
func _axis(plus: String, plus_key: Key, minus: String, minus_key: Key) -> float:
	return _held(plus, plus_key) - _held(minus, minus_key)


func _held(action: String, key: Key) -> float:
	if InputMap.has_action(action):
		return 1.0 if Input.is_action_pressed(action) else 0.0
	return 1.0 if Input.is_physical_key_pressed(key) else 0.0


func _key_name(action: String, fallback: String) -> String:
	var keys := get_node_or_null("/root/Keys")
	return str(keys.call("key_name", action)) if keys and bool(keys.call("has", action)) else fallback


## A basis with its Y along `d`.
static func _along(d: Vector3) -> Basis:
	var y := d.normalized()
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	return Basis(x, y, x.cross(y))


func _part(shape: PartShapes.PartShape, xform: Transform3D, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = shape.mesh
	mi.material_override = mat
	mi.transform = xform
	(parent if parent else self).add_child(mi)
	return mi


## A collision box on a body. A ray that hits it finds the shape node, so Use reads its meta.
func _collide(size: Vector3, xform: Transform3D, parent: CollisionObject3D) -> CollisionShape3D:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.transform = xform
	parent.add_child(col)
	return col


func _sign(text: String, xform: Transform3D, size: int, parent: Node3D = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = ShipKit.mono_font()
	l.font_size = size
	l.pixel_size = 0.0018
	l.modulate = Color(0.1, 0.1, 0.1) if size >= 28 else Color(1.0, 0.85, 0.5)
	l.outline_size = 0
	l.transform = xform
	(parent if parent else self).add_child(l)
	return l
