extends Node3D
## The kit round the ship in the bay: wheeled boarding stairs up to the side door, a scissor
## lift beside the starboard flank for work at height, and a ground power unit on a cable to
## the ship's shore power socket. Use (F) works on the lift's two control boxes and the
## power unit's switch: each carries meta "ship_bay_use", a Callable the bay calls.
##
## Bay space: the ship's deck (y = 0 in ship space) is `deck` metres up; ship x and z are the
## bay's. Built by Bay._build_access once the ship is in.

## The lift's platform heights, deck top over the floor, metres: board, flank, roof.
@export var lift_levels: Array[float] = [0.35, 2.4, 4.5]
## How fast the lift platform rises and falls, metres per second.
@export var lift_speed := 0.6
## Power to the ship changed (the bay passes it to the bus).
signal power_switched(on: bool)

var deck := 1.6
var platform: AnimatableBody3D
var lift_level := 0
var lift_target := 0.35
var power_on := false
var _arms: Array[MeshInstance3D] = []
var _switch_lamp: MeshInstance3D
var _lit_on: Material
var _lit_off: Material
var _yellow: Material
var _steel: Material
var _dark: Material
var _rubber: Material
var _tread: Material
var _solid: StaticBody3D

const LIFT_X := Vector2(2.78, 4.18)     # platform's span across (x)
const LIFT_Z := Vector2(1.7, 4.3)       # and along the ship (z)
const BASE_TOP := 0.3
const STAGES := 3


## Builds round a ship whose side door sill and power socket are given in ship space.
func build(cradle_height: float, door_sill: Vector3, socket: Vector3) -> void:
	deck = cradle_height
	_yellow = ShipSurface.of(ShipKit.paint(Color(0.95, 0.75, 0.1), 0.15, 0.5, "hazard_paint"))
	_steel = ShipSurface.of(ShipKit.paint(Color(0.55, 0.57, 0.6), 0.85, 0.3, "chrome"))
	_dark = ShipSurface.of(ShipKit.paint(Color(0.15, 0.16, 0.18), 0.5, 0.5, "gunmetal"))
	_rubber = ShipSurface.of(ShipKit.paint(Color(0.07, 0.07, 0.075), 0.0, 0.9, "rubber"))
	_tread = ShipSurface.of(ShipKit.paint(Color(0.42, 0.44, 0.46), 0.8, 0.45))
	_lit_on = ShipKit.glow(Color(0.35, 1.0, 0.5), 2.5)
	_lit_off = ShipKit.glow(Color(1.0, 0.25, 0.12), 2.0)
	_solid = StaticBody3D.new()
	_solid.name = "Solid"
	add_child(_solid)
	_build_stairs(door_sill + Vector3(0, deck, 0))
	_build_lift()
	_build_power_unit(socket + Vector3(0, deck, 0))


# --- Boarding stairs ------------------------------------------------------------------------

## Wheeled stairs: a landing at the sill, a flight down away from the ship (-X), handrails.
func _build_stairs(sill: Vector3) -> void:
	var top := sill.y - 0.01
	var width := 1.1
	var z := sill.z
	var landing := Vector2(sill.x - 0.85, sill.x - 0.04)    # x span
	var run := 2.9
	var foot_x := landing.x - run
	var steps := 9
	# The landing: a grating deck on a box frame, its collision a slab.
	_part(WreckParts.grating(landing.y - landing.x, width), Transform3D(Basis(), Vector3((landing.x + landing.y) * 0.5, top, z)), _tread)
	_part(PartShapes.box(Vector3(landing.y - landing.x, 0.12, width + 0.06)),
			Transform3D(Basis(), Vector3((landing.x + landing.y) * 0.5, top - 0.08, z)), _yellow)
	_collide(Vector3(landing.y - landing.x, 0.1, width), Transform3D(Basis(), Vector3((landing.x + landing.y) * 0.5, top - 0.05, z)))
	# The flight: treads on two stringers, a ramp under them to walk on.
	var rise := top / float(steps)
	var going := run / float(steps)
	for i in steps:
		var y := rise * float(i + 1) - 0.02
		var x := foot_x + going * (float(i) + 0.5)
		_part(WreckParts.grating(going + 0.02, width - 0.08), Transform3D(Basis(), Vector3(x, y, z)), _tread)
		_part(PartShapes.box(Vector3(0.03, 0.03, width - 0.08)), Transform3D(Basis(), Vector3(x - going * 0.5 + 0.015, y - 0.01, z)), _yellow)
	var slope := atan2(top, run)
	var length := sqrt(top * top + run * run)
	var along := Basis(Vector3.BACK, slope)
	for side: float in [-1.0, 1.0]:
		_part(PartShapes.box(Vector3(length + 0.2, 0.22, 0.06)), Transform3D(along,
				Vector3(foot_x + run * 0.5, top * 0.5 - 0.05, z + side * (width * 0.5 + 0.03))), _yellow)
	# Its top face runs from the floor at the foot to the landing's top, no lip at either end.
	_collide(Vector3(length, 0.06, width), Transform3D(along, Vector3(foot_x + run * 0.5, top * 0.5, z) - along.y * 0.03))
	# Under the landing: legs on castors, braced.
	for lx: float in [landing.x + 0.08, landing.y - 0.08]:
		for side: float in [-1.0, 1.0]:
			var lz := z + side * (width * 0.5 - 0.02)
			_part(WreckParts.pipe(0.04, top - 0.25, false), Transform3D(Basis(), Vector3(lx, (top + 0.1) * 0.5, lz)), _yellow)
			_castor(Vector3(lx, 0, lz))
	for side: float in [-1.0, 1.0]:
		_castor(Vector3(foot_x + 0.15, 0, z + side * (width * 0.5 - 0.02)))
	# Handrails: posts up the flight and round the landing's open sides.
	var rail_h := 1.0
	for side: float in [-1.0, 1.0]:
		var rz := z + side * (width * 0.5 + 0.05)
		for k in 4:
			var t := float(k) / 3.0
			var p := Vector3(foot_x + run * t, top * t, rz)
			_part(WreckParts.pipe(0.022, rail_h, false), Transform3D(Basis(), p + Vector3(0, rail_h * 0.5, 0)), _steel)
		_part(WreckParts.pipe(0.025, length, false), Transform3D(along * Basis(Vector3.BACK, -PI * 0.5),
				Vector3(foot_x + run * 0.5, top * 0.5 + rail_h, rz)), _steel)
		_part(WreckParts.pipe(0.025, landing.y - landing.x, false), Transform3D(Basis(Vector3.BACK, PI * 0.5),
				Vector3((landing.x + landing.y) * 0.5, top + rail_h, rz)), _steel)
		_part(WreckParts.pipe(0.022, rail_h, false), Transform3D(Basis(), Vector3(landing.y - 0.05, top + rail_h * 0.5, rz)), _steel)
		_collide(Vector3(landing.y - foot_x, rail_h + top, 0.05), Transform3D(Basis(), Vector3((landing.y + foot_x) * 0.5, (rail_h + top) * 0.5, rz)), false)
	_sign("BOARDING", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(landing.x + 0.02, top + 0.55, z + width * 0.5 + 0.06)), 28)


func _castor(at: Vector3) -> void:
	_part(PartShapes.box(Vector3(0.12, 0.06, 0.12)), Transform3D(Basis(), at + Vector3(0, 0.17, 0)), _dark)
	_part(PartShapes.prism(12, 0.07, 0.05), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 0.07, 0)), _rubber)


# --- Scissor lift ---------------------------------------------------------------------------

func _build_lift() -> void:
	var cx := (LIFT_X.x + LIFT_X.y) * 0.5
	var cz := (LIFT_Z.x + LIFT_Z.y) * 0.5
	var w := LIFT_X.y - LIFT_X.x
	var l := LIFT_Z.y - LIFT_Z.x
	# The chassis on four wheels, outriggers down.
	_part(PartShapes.chamfer_box(Vector3(w - 0.1, BASE_TOP - 0.12, l - 0.2), 0.03), Transform3D(Basis(), Vector3(cx, 0.06 + (BASE_TOP - 0.12) * 0.5 + 0.06, cz)), _yellow)
	_collide(Vector3(w - 0.1, BASE_TOP, l - 0.2), Transform3D(Basis(), Vector3(cx, BASE_TOP * 0.5, cz)))
	for x: float in [LIFT_X.x + 0.12, LIFT_X.y - 0.12]:
		for z: float in [LIFT_Z.x + 0.3, LIFT_Z.y - 0.3]:
			_part(PartShapes.prism(14, 0.13, 0.1), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, 0.13, z)), _rubber)
			_part(PartShapes.box(Vector3(0.12, 0.05, 0.12)), Transform3D(Basis(), Vector3(x + signf(x - cx) * 0.1, 0.025, z)), _dark)
	# A ramp up onto the platform at its aft end (it rests just above the chassis).
	var ramp_len := 1.3
	var ramp_slope := atan2(lift_levels[0], ramp_len)
	var rb := Basis(Vector3.RIGHT, ramp_slope)
	_part(PartShapes.box(Vector3(w - 0.3, 0.04, ramp_len + 0.05)), Transform3D(rb, Vector3(cx, lift_levels[0] * 0.5, LIFT_Z.y + ramp_len * 0.5)), _tread)
	_collide(Vector3(w - 0.3, 0.04, ramp_len + 0.08), Transform3D(rb, Vector3(cx, lift_levels[0] * 0.5 - 0.02, LIFT_Z.y + ramp_len * 0.5)))
	# Ground controls on the chassis' outboard side.
	var ground_box := _control_box(Transform3D(Basis(), Vector3(LIFT_X.y + 0.02, 0.85, LIFT_Z.y - 0.4)), self, "LIFT")
	_part(WreckParts.pipe(0.03, 0.6, false), Transform3D(Basis(), Vector3(LIFT_X.y + 0.02, 0.45, LIFT_Z.y - 0.4)), _dark)
	ground_box.set_meta("ship_bay_use", lift_next)
	# The platform: a grating deck with toe boards and rails, the gate open at the ramp end.
	platform = AnimatableBody3D.new()
	platform.name = "LiftPlatform"
	platform.sync_to_physics = true
	add_child(platform)
	# Platform space: the deck top at y = 0.
	_part(WreckParts.grating(w, l), Transform3D(Basis(), Vector3(0, -0.02, 0)), _tread, platform)
	_part(PartShapes.box(Vector3(w + 0.04, 0.12, l + 0.04)), Transform3D(Basis(), Vector3(0, -0.08, 0)), _yellow, platform)
	_collide(Vector3(w, 0.1, l), Transform3D(Basis(), Vector3(0, -0.05, 0)), true, platform)
	var rail_h := 1.05
	for rail: Array in [[Vector3(-w * 0.5, 0, 0), Vector3(0.04, 0, l)], [Vector3(w * 0.5, 0, 0), Vector3(0.04, 0, l)],
			[Vector3(0, 0, -l * 0.5), Vector3(w, 0, 0.04)]]:
		var at: Vector3 = rail[0]
		var size: Vector3 = rail[1]
		for y: float in [rail_h, rail_h * 0.5]:
			_part(PartShapes.box(Vector3(maxf(size.x, 0.04), 0.04, maxf(size.z, 0.04))), Transform3D(Basis(), at + Vector3(0, y, 0)), _yellow, platform)
		_part(PartShapes.box(Vector3(maxf(size.x, 0.02), 0.12, maxf(size.z, 0.02))), Transform3D(Basis(), at + Vector3(0, 0.06, 0)), _yellow, platform)
		_collide(Vector3(maxf(size.x, 0.04), rail_h, maxf(size.z, 0.04)), Transform3D(Basis(), at + Vector3(0, rail_h * 0.5, 0)), true, platform)
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(-1, 0), Vector2(1, 0)]:
		_part(PartShapes.box(Vector3(0.04, rail_h, 0.04)), Transform3D(Basis(), Vector3(c.x * w * 0.5, rail_h * 0.5, c.y * l * 0.5)), _yellow, platform)
	var deck_box := _control_box(Transform3D(Basis(), Vector3(w * 0.5 + 0.02, rail_h - 0.1, -l * 0.25)), platform, "UP / DOWN")
	deck_box.set_meta("ship_bay_use", lift_next)
	# The scissor arms, two stacks (one each side), redrawn as the platform moves.
	var arm_mesh := PartShapes.box(Vector3(0.06, 0.08, 1.0)).mesh
	for side in 2:
		for stage in STAGES:
			for k in 2:
				var mi := MeshInstance3D.new()
				mi.mesh = arm_mesh
				mi.material_override = _yellow
				add_child(mi)
				_arms.append(mi)
	_set_platform(lift_levels[0])
	lift_target = lift_levels[0]


## Sends the lift to its next level (up through them, then back to the bottom).
func lift_next() -> void:
	lift_level = (lift_level + 1) % lift_levels.size()
	lift_target = lift_levels[lift_level]


func lift_height() -> float:
	return platform.position.y if platform else 0.0


func _physics_process(delta: float) -> void:
	if platform == null:
		return
	var y := platform.position.y
	if absf(y - lift_target) > 0.0005:
		_set_platform(move_toward(y, lift_target, lift_speed * delta))


func _set_platform(y: float) -> void:
	platform.position = Vector3((LIFT_X.x + LIFT_X.y) * 0.5, y, (LIFT_Z.x + LIFT_Z.y) * 0.5)
	var bottom := BASE_TOP + 0.02
	var h := maxf(y - 0.14 - bottom, 0.01)
	var stage_h := h / float(STAGES)
	var bar := LIFT_Z.y - LIFT_Z.x - 0.5
	var span := sqrt(maxf(bar * bar - stage_h * stage_h, 0.01))
	var cz := (LIFT_Z.x + LIFT_Z.y) * 0.5
	var i := 0
	for side in 2:
		var x := LIFT_X.x + 0.15 if side == 0 else LIFT_X.y - 0.15
		for stage in STAGES:
			for k in 2:
				var y0 := bottom + stage_h * float(stage)
				var a := Vector3(x, y0, cz - span * 0.5) if k == 0 else Vector3(x, y0 + stage_h, cz - span * 0.5)
				var b := Vector3(x, y0 + stage_h, cz + span * 0.5) if k == 0 else Vector3(x, y0, cz + span * 0.5)
				var dir := (b - a).normalized()
				var basis := Basis(Vector3.RIGHT, dir.cross(Vector3.RIGHT), dir * a.distance_to(b))
				_arms[i].transform = Transform3D(basis, (a + b) * 0.5 + Vector3(0.07 * (float(k) - 0.5), 0, 0))
				i += 1


# --- Ground power -------------------------------------------------------------------------

## A ground power unit on wheels with its cable up to the ship's socket; its switch powers
## the ship up and down.
func _build_power_unit(socket: Vector3) -> void:
	var at := Vector3(socket.x + 2.1, 0, socket.z + 1.6)
	var body := Vector3(1.0, 0.95, 1.5)
	_part(PartShapes.chamfer_box(body, 0.06), Transform3D(Basis(), at + Vector3(0, 0.25 + body.y * 0.5, 0)), _yellow)
	_part(PartShapes.louvre(0.7, 0.5, 0.04, 6), Transform3D(Basis(Vector3.BACK, -PI * 0.5), at + Vector3(body.x * 0.5 + 0.01, 0.75, 0.3)), _dark)
	_part(PartShapes.box(Vector3(0.9, 0.06, 1.4)), Transform3D(Basis(), at + Vector3(0, 0.25 + body.y + 0.03, 0)), _dark)
	for x: float in [-0.4, 0.4]:
		for z: float in [-0.55, 0.55]:
			_part(PartShapes.prism(14, 0.15, 0.1), Transform3D(Basis(Vector3.BACK, PI * 0.5), at + Vector3(x, 0.15, z)), _rubber)
	_part(PartShapes.box(Vector3(0.05, 0.05, 0.9)), Transform3D(Basis(), at + Vector3(0, 0.3, -body.z * 0.5 - 0.45)), _dark)
	_part(PartShapes.ring(0.06, 0.1, 0.04), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 0.3, -body.z * 0.5 - 0.92)), _dark)
	var col := _collide(body + Vector3(0, 0.25, 0), Transform3D(Basis(), at + Vector3(0, (body.y + 0.25) * 0.5, 0)))
	col.set_meta("ship_bay_use", toggle_power)
	# The panel on the side facing the ship's tail, its switch lamp red off, green on.
	var face := Transform3D(Basis(Vector3.UP, PI), at + Vector3(0, 0.95, body.z * 0.5 + 0.01))
	_part(PartShapes.box(Vector3(0.6, 0.4, 0.03)), face * Transform3D(Basis(), Vector3(0, 0, -0.015)), _dark)
	_switch_lamp = _part(PartShapes.box(Vector3(0.14, 0.14, 0.04)), face * Transform3D(Basis(), Vector3(0.15, 0.02, -0.03)), _lit_off)
	_sign("SHORE POWER\n400 Hz", face * Transform3D(Basis(Vector3.UP, PI), Vector3(-0.08, 0.05, -0.035)), 22)
	# The cable: from the unit's outlet up to the socket in a sag.
	var outlet := at + Vector3(-body.x * 0.5 - 0.02, 0.6, -0.3)
	var plug := socket + Vector3(0.12, -0.02, 0)
	var cable := ShipSurface.of(ShipKit.paint(Color(0.08, 0.08, 0.09), 0.0, 0.8, "rubber"))
	var n := 18
	var prev := outlet
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var p := outlet.lerp(plug, t) + Vector3(0, -0.9 * 4.0 * t * (1.0 - t), 0)
		p.y = maxf(p.y, 0.03)
		var d := p - prev
		_part(PartShapes.prism(8, 0.022, d.length() + 0.01), Transform3D(_along(d), (p + prev) * 0.5), cable)
		prev = p
	_part(PartShapes.prism(10, 0.05, 0.14), Transform3D(Basis(Vector3.BACK, PI * 0.5), plug + Vector3(0.02, 0, 0)), _dark)


func toggle_power() -> void:
	set_power(not power_on)


func set_power(on: bool) -> void:
	if on == power_on:
		return
	power_on = on
	if _switch_lamp:
		_switch_lamp.material_override = _lit_on if on else _lit_off
	power_switched.emit(on)


# --- Helpers ----------------------------------------------------------------------------------

## A control box (two buttons under a label) whose collision takes Use.
func _control_box(xform: Transform3D, parent: Node3D, title: String) -> CollisionShape3D:
	_part(PartShapes.chamfer_box(Vector3(0.12, 0.26, 0.2), 0.02), xform, _dark, parent)
	_part(PartShapes.box(Vector3(0.03, 0.06, 0.06)), xform * Transform3D(Basis(), Vector3(0.07, 0.05, 0)), ShipKit.glow(Color(0.35, 1.0, 0.5), 1.5), parent)
	_part(PartShapes.box(Vector3(0.03, 0.06, 0.06)), xform * Transform3D(Basis(), Vector3(0.07, -0.05, 0)), ShipKit.glow(Color(1.0, 0.6, 0.15), 1.5), parent)
	_sign(title, xform * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.065, 0.11, 0)), 14, parent)
	return _collide(Vector3(0.16, 0.3, 0.24), xform, true, parent)


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


## A collision box on the platform (when `parent` is it) or the kit's static body. A ray
## that hits it finds the shape node, so Use reads its meta.
func _collide(size: Vector3, xform: Transform3D, _solid_hint := true, parent: Node3D = null) -> CollisionShape3D:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.transform = xform
	(parent if parent is CollisionObject3D else _solid).add_child(col)
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
