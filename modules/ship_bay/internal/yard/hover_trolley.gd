extends AnimatableBody3D
## A hover trolley: a chassis floating on four lift pads, a scissor stage under a railed
## grating deck, a control box with its size letter and a status lamp. Three sizes (SPECS):
## small and medium decks rise to the top rack level for work at height (you can ride
## them), the large one carries bulk parts low.
##
## This node only moves and draws. TrolleyFleet decides where it goes: on the peer that
## drives it (Multiplayer.drives), it follows `path` or remote-control input; everywhere else
## the Multiplayer mover stream places it. The deck's height follows `deck_target`, which
## every peer is told, so all copies raise and lower it the same way.

const SPECS := {
	"s": {"name": "Small hover trolley", "letter": "S", "deck": Vector2(0.8, 1.1), "radius": 0.6,
			"speed": 2.4, "lift": 7.6, "carries": ["bin"], "colour": Color(0.25, 0.62, 0.85)},
	"m": {"name": "Medium hover trolley", "letter": "M", "deck": Vector2(1.25, 1.7), "radius": 0.85,
			"speed": 2.0, "lift": 7.6, "carries": ["bin", "pallet"], "colour": Color(1.0, 0.55, 0.16)},
	"l": {"name": "Large hover trolley", "letter": "L", "deck": Vector2(2.6, 4.4), "radius": 1.3,
			"speed": 1.4, "lift": 2.5, "carries": ["bin", "pallet", "bulk"], "colour": Color(0.95, 0.75, 0.1)},
}
## Chassis underside and top over the floor while hovering, metres.
const HOVER := 0.32
const CHASSIS_TOP := 0.62
## The deck's lowest height (its top over the floor), metres.
const DECK_MIN := 0.7
const MAST_SECTIONS := 4

## Top speed scale for this trolley (1 = its spec's speed), and its turn rate (rad/s).
@export var speed_scale := 1.0
@export var turn_rate := 1.8
## Acceleration, metres per second squared, and the deck's lift speed, metres per second.
@export var accel := 1.6
@export var lift_speed := 0.8

var kind := "m"
var spec: Dictionary
var deck: AnimatableBody3D
var deck_height := DECK_MIN
var deck_target := DECK_MIN
## Way-points still to reach (yard space, on the floor); the last may carry a final yaw.
var path := PackedVector3Array()
var final_yaw := NAN
## Remote-control input this frame: x turn (-1 left .. 1 right), y drive (1 forward).
var drive_input := Vector2.ZERO
## True on the peer running this trolley's motion.
var driving := true
## Held back by something in the way (seconds so far).
var blocked_for := 0.0
## What sits on the deck: {} or {crate_id, kind, mass, category, name}.
var cargo: Dictionary = {}
var status := "PARKED"

var _speed := 0.0
var _yaw := 0.0
var _mast: Array[MeshInstance3D] = []
var _cargo_mesh: MeshInstance3D
var _lamp: MeshInstance3D
var _screen: Label3D
var _mats: Dictionary = {}


func setup(p_kind: String, at: Vector3, yaw: float) -> void:
	kind = p_kind
	spec = SPECS[kind]
	name = "Trolley_" + kind.to_upper()
	sync_to_physics = false
	_yaw = yaw
	_mats = {
		"body": ShipSurface.of(ShipKit.paint(spec["colour"], 0.2, 0.45, "gloss_paint")),
		"dark": ShipSurface.of(ShipKit.paint(Color(0.15, 0.16, 0.18), 0.5, 0.5, "gunmetal")),
		"steel": ShipSurface.of(ShipKit.paint(Color(0.55, 0.57, 0.6), 0.8, 0.35, "chrome")),
		"tread": ShipSurface.of(ShipKit.paint(Color(0.42, 0.44, 0.46), 0.8, 0.45)),
		"pad": ShipKit.glow(Color(0.35, 0.85, 1.0), 3.0),
		"go": ShipKit.glow(Color(0.35, 1.0, 0.5), 2.5),
		"wait": ShipKit.glow(Color(1.0, 0.7, 0.15), 2.5),
		"crate": ShipSurface.of(ShipKit.paint(Color(0.6, 0.5, 0.36), 0.15, 0.6)),
	}
	_build()
	global_transform = Transform3D(Basis(Vector3.UP, _yaw), Vector3(at.x, 0.0, at.z))
	_set_deck(DECK_MIN)


func radius() -> float:
	return float(spec["radius"])


func yaw() -> float:
	return _yaw


func is_idle() -> bool:
	return path.is_empty() and cargo.is_empty() and drive_input == Vector2.ZERO


## Can it carry goods of this kind ("bin", "pallet", "bulk")?
func carries(goods_kind: String) -> bool:
	return (spec["carries"] as Array).has(goods_kind)


## Stands it somewhere at once with its deck at `deck` metres (screenshots and set pieces).
func pose(at: Vector3, yaw: float, deck: float) -> void:
	path = PackedVector3Array()
	final_yaw = NAN
	_speed = 0.0
	_yaw = yaw
	global_transform = Transform3D(Basis(Vector3.UP, _yaw), Vector3(at.x, 0.0, at.z))
	set_deck_target(deck)
	_set_deck(deck_target)


func set_cargo(c: Dictionary) -> void:
	cargo = c.duplicate()
	if _cargo_mesh:
		_cargo_mesh.queue_free()
		_cargo_mesh = null
	if cargo.is_empty():
		return
	var d: Vector2 = spec["deck"]
	var box := BoxMesh.new()
	var mass := float(cargo.get("mass", 100.0))
	match str(cargo.get("kind", "pallet")):
		"bin":
			box.size = Vector3(0.6, 0.32, 0.9)
		"bulk":
			box.size = Vector3(minf(d.x - 0.2, 2.3), clampf(1.0 + mass / 15000.0, 1.0, 2.4), minf(d.y - 0.3, 3.8))
		_:
			box.size = Vector3(minf(d.x - 0.15, 1.0), clampf(0.35 + mass / 2500.0, 0.35, 1.35), minf(d.y - 0.2, 1.2))
	_cargo_mesh = MeshInstance3D.new()
	_cargo_mesh.name = "Cargo"
	_cargo_mesh.mesh = box
	_cargo_mesh.material_override = _mats["crate"]
	_cargo_mesh.position = Vector3(0, 0.06 + box.size.y * 0.5, 0)
	deck.add_child(_cargo_mesh)


## Moves it for one physics step: remote input or the path, slowing for `obstacles`
## (floor points with a radius each: [[Vector3, float], ...]).
func step(delta: float, obstacles: Array) -> void:
	var top := float(spec["speed"]) * speed_scale
	var want := 0.0
	var turn := 0.0
	var here := global_position
	if drive_input != Vector2.ZERO:
		want = drive_input.y * top * 0.6
		turn = -drive_input.x * turn_rate
		_speed = move_toward(_speed, want, accel * delta)
		_yaw += turn * delta
	elif not path.is_empty():
		var to := path[0] - here
		to.y = 0.0
		var dist := to.length()
		var last := path.size() == 1
		if dist < (0.08 if last else 0.6):
			path.remove_at(0)
			if path.is_empty():
				_speed = 0.0
		else:
			var heading := atan2(-to.x, -to.z)
			var err := wrapf(heading - _yaw, -PI, PI)
			_yaw += clampf(err, -turn_rate * delta, turn_rate * delta)
			# Turn on the spot when facing well away; ease in to the last point.
			var aligned := clampf(1.0 - absf(err) / 0.9, 0.0, 1.0)
			want = top * aligned
			if last:
				want = minf(want, sqrt(2.0 * accel * dist) + 0.05)
			_speed = move_toward(_speed, want, accel * delta)
	elif not is_nan(final_yaw):
		var err := wrapf(final_yaw - _yaw, -PI, PI)
		_yaw += clampf(err, -turn_rate * delta, turn_rate * delta)
		if absf(err) < 0.01:
			_yaw = final_yaw
			final_yaw = NAN
		_speed = 0.0
	else:
		_speed = move_toward(_speed, 0.0, accel * 2.0 * delta)
	var forward := -Basis(Vector3.UP, _yaw).z
	# Something close ahead (a person, another trolley): stop and wait.
	var held := false
	var going := signf(_speed) if _speed != 0.0 else 1.0
	for o: Array in obstacles:
		var away: Vector3 = o[0] - here
		away.y = 0.0
		var along := away.dot(forward * going)
		var aside := sqrt(maxf(away.length_squared() - along * along, 0.0))
		# Only what is in the lane ahead counts: passing beside something is fine.
		if away.length() - float(o[1]) - radius() < 0.6 and along > 0.0 and aside < float(o[1]) + radius() + 0.2 and want != 0.0:
			_speed = 0.0
			held = true
			break
	blocked_for = blocked_for + delta if held else 0.0
	var next := here + forward * _speed * delta
	global_transform = Transform3D(Basis(Vector3.UP, _yaw), Vector3(next.x, 0.0, next.z))


## Raises or lowers the deck toward deck_target (every peer runs this).
func lift_step(delta: float) -> void:
	if not is_equal_approx(deck_height, deck_target):
		_set_deck(move_toward(deck_height, deck_target, lift_speed * delta))


func set_deck_target(h: float) -> void:
	deck_target = clampf(h, DECK_MIN, float(spec["lift"]))


func deck_ready() -> bool:
	return absf(deck_height - deck_target) < 0.01


## Follows the stream on peers that don't drive it: keep the yaw in step.
func sync_yaw() -> void:
	_yaw = global_basis.get_euler().y


func show_status(text: String) -> void:
	status = text
	if _screen:
		_screen.text = "%s\n%s" % [spec["letter"], text]
	if _lamp:
		_lamp.material_override = _mats["go"] if not path.is_empty() or drive_input != Vector2.ZERO else _mats["wait"]


func _build() -> void:
	var d: Vector2 = spec["deck"]
	var body_h := CHASSIS_TOP - HOVER
	_box(Vector3(d.x, body_h, d.y), Vector3(0, HOVER + body_h * 0.5, 0), _mats["body"])
	_box(Vector3(d.x + 0.04, 0.05, d.y + 0.04), Vector3(0, CHASSIS_TOP - 0.02, 0), _mats["dark"])
	# Bump strips along the sides, the lift pads under the corners.
	for sx: float in [-0.5, 0.5]:
		_box(Vector3(0.05, 0.1, d.y - 0.1), Vector3(sx * (d.x + 0.05), HOVER + 0.08, 0), _mats["dark"])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var pad := CylinderMesh.new()
			pad.top_radius = minf(d.x, d.y) * 0.16
			pad.bottom_radius = pad.top_radius * 1.1
			pad.height = 0.06
			var mi := MeshInstance3D.new()
			mi.mesh = pad
			mi.material_override = _mats["pad"]
			mi.position = Vector3(sx * (d.x * 0.5 - pad.top_radius - 0.05), HOVER - 0.02, sz * (d.y * 0.5 - pad.top_radius - 0.05))
			add_child(mi)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.35, 0.85, 1.0)
	glow.light_energy = 0.6
	glow.omni_range = maxf(d.x, d.y)
	glow.position = Vector3(0, 0.12, 0)
	glow.shadow_enabled = false
	glow.set_meta("gfx_no_shadow", true)
	add_child(glow)
	# The control box on the front end, with the size letter and a status screen.
	var front := -d.y * 0.5
	_box(Vector3(minf(d.x * 0.6, 0.8), 0.5, 0.18), Vector3(0, CHASSIS_TOP + 0.25, front + 0.1), _mats["dark"])
	_lamp = _box(Vector3(0.08, 0.08, 0.04), Vector3(minf(d.x * 0.3, 0.4) - 0.08, CHASSIS_TOP + 0.44, front - 0.005), _mats["wait"])
	_screen = Label3D.new()
	_screen.font = ShipKit.mono_font()
	_screen.font_size = 40
	_screen.pixel_size = 0.0035
	_screen.modulate = Color(0.45, 0.95, 1.0)
	_screen.outline_size = 0
	_screen.shaded = false
	_screen.position = Vector3(-0.05, CHASSIS_TOP + 0.25, front - 0.01)
	_screen.rotation.y = PI
	add_child(_screen)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(d.x, CHASSIS_TOP - HOVER + 0.5, d.y)
	col.shape = shape
	col.position = Vector3(0, (HOVER + CHASSIS_TOP + 0.5) * 0.5, 0)
	add_child(col)
	# The deck: a grating plate on a frame, a waist rail round three sides (not the back).
	deck = AnimatableBody3D.new()
	deck.name = "Deck"
	deck.sync_to_physics = false
	add_child(deck)
	var plate := MeshInstance3D.new()
	plate.mesh = WreckParts.grating(d.x, d.y, 0.04).mesh
	plate.material_override = _mats["tread"]
	plate.position.y = -0.02
	deck.add_child(plate)
	var frame := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(d.x, 0.08, d.y)
	frame.mesh = fb
	frame.material_override = _mats["body"]
	frame.position.y = -0.08
	deck.add_child(frame)
	if kind != "l":
		var post := Vector3(0.04, 1.0, 0.04)
		for p: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			_box(post, Vector3(p.x * (d.x * 0.5 - 0.03), 0.5, p.y * (d.y * 0.5 - 0.03)), _mats["body"], deck)
		_box(Vector3(d.x, 0.04, 0.04), Vector3(0, 1.0, -d.y * 0.5 + 0.03), _mats["body"], deck)
		for sx: float in [-1.0, 1.0]:
			_box(Vector3(0.04, 0.04, d.y), Vector3(sx * (d.x * 0.5 - 0.03), 1.0, 0), _mats["body"], deck)
	var dcol := CollisionShape3D.new()
	var dshape := BoxShape3D.new()
	dshape.size = Vector3(d.x, 0.12, d.y)
	dcol.shape = dshape
	dcol.position.y = -0.06
	deck.add_child(dcol)
	# The mast: nested telescopic sections from the chassis up under the deck.
	for i in MAST_SECTIONS:
		var w := minf(d.x, d.y) * (0.42 - 0.07 * i)
		_mast.append(_box(Vector3(w, 0.1, w), Vector3.ZERO, _mats["steel"] if i % 2 else _mats["dark"]))


func _set_deck(h: float) -> void:
	deck_height = h
	deck.position = Vector3(0, h, 0)
	# Each section slides out of the one below; they share the rise and keep an overlap.
	var bottom := CHASSIS_TOP
	var rise := maxf(h - 0.12 - bottom, 0.05)
	var overlap := 0.08
	var each := rise / MAST_SECTIONS + overlap
	for i in MAST_SECTIONS:
		var sec := _mast[i]
		var y0 := bottom + i * (each - overlap)
		(sec.mesh as BoxMesh).size.y = each
		sec.position = Vector3(0, y0 + each * 0.5, 0)


func _box(size: Vector3, at: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	(parent if parent else self).add_child(mi)
	return mi
