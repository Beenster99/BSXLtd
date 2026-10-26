extends AnimatableBody3D
## A hover trolley: a chassis floating on four lift pads, a telescopic mast under a railed
## grating deck, a control box with its size letter, a status lamp and a rotating orange
## beacon, and a low hover hum that rises a little as it moves. Three sizes (SPECS):
## every deck rises to the top rack level for work at height (you can ride them); the large
## one also carries bulk parts. The picking lift ("p", and the heavy lift "h") is the same chassis
## with a tall twin-column mast: its carriage rides up the columns to any shelf and a shuttle
## fork reaches sideways into the rack to pull goods off it.
##
## This node only moves and draws. TrolleyFleet decides where it goes: on the peer that
## drives it (Multiplayer.drives), it follows `path` or remote-control input; everywhere else
## the Multiplayer mover stream places it. The deck's height follows `deck_target`, which
## every peer is told, so all copies raise and lower it the same way.

const Touch := preload("res://modules/ship_bay/internal/kit/touch_screen.gd")
const T := preload("res://modules/ui/api/terminal_kit.gd")
const ItemLook := preload("res://modules/ship_bay/internal/yard/item_look.gd")

## A button on its touch screen was pressed: "call" (follow me), "park", "fast" or "remote"
## (the fleet acts).
signal screen_action(action: String)

const SPECS := {
	"s": {"name": "Small hover trolley", "letter": "S", "deck": Vector2(2.6, 4.4), "radius": 1.3,
			"speed": 1.8, "lift": 7.6, "carries": ["bin", "pallet", "bulk"], "colour": Color(0.25, 0.62, 0.85)},
	"m": {"name": "Medium hover trolley", "letter": "M", "deck": Vector2(2.8, 6.4), "radius": 1.4, "clear": 1.3,
			"speed": 1.6, "lift": 7.6, "carries": ["bin", "pallet", "bulk"], "colour": Color(1.0, 0.55, 0.16)},
	"l": {"name": "Large hover trolley", "letter": "L", "deck": Vector2(3.0, 8.8), "radius": 1.45, "clear": 1.3,
			"speed": 1.4, "lift": 7.6, "carries": ["bin", "pallet", "bulk"], "colour": Color(0.95, 0.75, 0.1)},
	"p": {"name": "Picking lift", "letter": "P", "deck": Vector2(1.1, 1.3), "radius": 0.8,
			"speed": 1.8, "lift": 7.6, "carries": ["bin", "pallet"], "colour": Color(0.9, 0.91, 0.9), "picker": true},
	# Five more picking lifts that put deliveries away straight off the goods-in floor
	# (beenster, 0.3.15: the big trolleys stand parked in the yard unless you send them).
	# Store 2's picking lift: works aisles D and E there.
	"p7": {"name": "Store 2 picking lift", "letter": "P7", "deck": Vector2(1.1, 1.3), "radius": 0.8,
			"speed": 1.8, "lift": 7.6, "carries": ["bin", "pallet"], "colour": Color(0.9, 0.91, 0.9), "picker": true, "title": "STORE 2 PICKER"},
	"p2": {"name": "Picking lift 2", "letter": "P2", "deck": Vector2(1.1, 1.3), "radius": 0.8,
			"speed": 1.8, "lift": 7.6, "carries": ["bin", "pallet"], "colour": Color(0.9, 0.91, 0.9), "picker": true, "putaway": true},
	"p3": {"name": "Picking lift 3", "letter": "P3", "deck": Vector2(1.1, 1.3), "radius": 0.8,
			"speed": 1.8, "lift": 7.6, "carries": ["bin", "pallet"], "colour": Color(0.9, 0.91, 0.9), "picker": true, "putaway": true},
	"p4": {"name": "Picking lift 4", "letter": "P4", "deck": Vector2(1.1, 1.3), "radius": 0.8,
			"speed": 1.8, "lift": 7.6, "carries": ["bin", "pallet"], "colour": Color(0.9, 0.91, 0.9), "picker": true, "putaway": true},
	"p5": {"name": "Picking lift 5", "letter": "P5", "deck": Vector2(1.1, 1.3), "radius": 0.8,
			"speed": 1.8, "lift": 7.6, "carries": ["bin", "pallet"], "colour": Color(0.9, 0.91, 0.9), "picker": true, "putaway": true},
	"p6": {"name": "Picking lift 6", "letter": "P6", "deck": Vector2(1.1, 1.3), "radius": 0.8,
			"speed": 1.8, "lift": 7.6, "carries": ["bin", "pallet"], "colour": Color(0.9, 0.91, 0.9), "picker": true, "putaway": true},
	# The heavy lift works the large and heavy racks (aisles W, X and H): a broad deck, a
	# stout mast and a long fork for the big machines.
	# 2.4 m wide so it fits down the large-parts aisles W and X (3.3 m between the racks'
	# faces): at 3.0 m it found no way in and never shelved anything there (0.3.19).
	"h": {"name": "Heavy lift", "letter": "H", "deck": Vector2(2.4, 3.4), "radius": 1.9, "clear": 1.45,
			"speed": 1.2, "lift": 7.4, "carries": ["bulk"], "colour": Color(0.95, 0.42, 0.12), "picker": true,
			"mast": 9.3, "reach": 2.0},
	# The refurbishment lines' own trolleys: finished lots are stacked on them at the end
	# of their line, and they take them to the stores.
	"a": {"name": "Line A trolley", "letter": "A", "deck": Vector2(3.4, 10.0), "radius": 1.7, "clear": 1.3,
			"speed": 1.3, "lift": 7.6, "carries": ["bin", "pallet", "bulk"], "colour": Color(0.3, 0.78, 0.42), "line": "a"},
	"b": {"name": "Line B trolley", "letter": "B", "deck": Vector2(3.4, 10.0), "radius": 1.7, "clear": 1.3,
			"speed": 1.3, "lift": 7.6, "carries": ["bin", "pallet", "bulk"], "colour": Color(0.62, 0.45, 0.92), "line": "b"},
}
## The yard's own trolleys (small, medium, large): open decks, and they tidy the yard.
const YARD: PackedStringArray = ["s", "m", "l"]
## The picking lift's mast height over the floor (under the aisle signs), metres.
const PICKER_MAST := 8.9
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
## How much faster it goes in fast mode (FAST on its screen, or Shift while on remote).
@export var fast_scale := 2.2
## The beacon's turns per second, and its light's reach (metres).
@export var beacon_spin := 1.1
@export var beacon_range := 6.0
## The hum's loudness standing still, decibels, and how far it carries (metres).
@export var hum_db := -30.0
@export var hum_reach := 18.0

## Fast mode: top speed times fast_scale (every peer is told, like the deck).
var fast := false
## Fast while on remote with Run held (only the driving peer, which moves it).
var boost := false
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
var _chains: Array[MeshInstance3D] = []
## The picking lift's shuttle fork, how far out it is (0 in .. 1 into the rack) and which side.
var _fork: Node3D
var fork_out := 0.0
var fork_target := 0.0
var fork_side := 1.0
var _cargo_mesh: Node3D
var _lamp: MeshInstance3D
## The beacon's turning reflector (with its light), and the hum.
var beacon: Node3D
var hum: AudioStreamPlayer3D
var _was_at := Vector3.INF
## The touch screen on its control box (TV style): its letter, status and buttons.
var screen: Node3D
var _shown := ""
var _mats: Dictionary = {}


func setup(p_kind: String, at: Vector3, yaw: float) -> void:
	kind = p_kind
	spec = SPECS[kind]
	name = "Trolley_" + kind.to_upper()
	# Graphics lights what you can use under the pointer, and finds it again for pings.
	add_to_group("gfx_interactable")
	set_meta("gfx_id", "trolley:" + kind)
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
		"beacon": ShipKit.glow(Color(1.0, 0.55, 0.12), 6.0),
		"amber_glass": _amber_glass(),
		"crate": ShipSurface.of(ShipKit.paint(Color(0.6, 0.5, 0.36), 0.15, 0.6)),
	}
	_build()
	global_transform = Transform3D(Basis(Vector3.UP, _yaw), Vector3(at.x, 0.0, at.z))
	_set_deck(DECK_MIN)


## Its speed along its nose this moment, metres per second (negative backing up).
func speed() -> float:
	return _speed


func radius() -> float:
	return float(spec["radius"])


## How much room it needs either side on a route, metres: the bigger trolleys squeeze down
## the bulk floor's lanes with a hand's width to spare.
func clearance() -> float:
	return float(spec.get("clear", spec["radius"]))


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
	# The goods themselves, as they are, each lot stacked neatly on the deck.
	var d: Vector2 = spec["deck"]
	_cargo_mesh = Node3D.new()
	_cargo_mesh.name = "Cargo"
	_cargo_mesh.position = Vector3(0, 0.06, 0)
	deck.add_child(_cargo_mesh)
	var lots: Array = []
	for lot: Dictionary in cargo.get("lots", [cargo]):
		lots.append({"item": lot.get("item", ""), "count": lot.get("count", 1), "look": ItemLook.look_for(float(lot.get("condition", 1.0)))})
	for placed: Array in ItemLook.stack_lots(lots, Vector2(d.x - 0.12, d.y - 0.12), 2.4):
		var n := ItemLook.make(str(placed[0]), placed[1])
		n.transform = placed[2]
		_cargo_mesh.add_child(n)


## Moves it for one physics step: remote input or the path, slowing for `obstacles`
## (floor points with a radius each: [[Vector3, float], ...]).
func step(delta: float, obstacles: Array) -> void:
	var top := float(spec["speed"]) * speed_scale * (fast_scale if fast or boost else 1.0)
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


## Raises or lowers the deck toward deck_target (every peer runs this), and slides the
## picking lift's fork.
func lift_step(delta: float) -> void:
	if not is_equal_approx(deck_height, deck_target):
		_set_deck(move_toward(deck_height, deck_target, lift_speed * delta))
	if _fork and not is_equal_approx(fork_out, fork_target):
		fork_out = move_toward(fork_out, fork_target, delta * 1.5)
		_fork.position.x = fork_side * fork_out * float(spec.get("reach", 1.0))


## The picking lift's fork: out into the rack on `side` (+1 the trolley's right, -1 its left)
## or back in.
func reach(out: bool, side := 1.0) -> void:
	fork_target = 1.0 if out else 0.0
	if out:
		fork_side = side


func fork_ready() -> bool:
	return _fork == null or is_equal_approx(fork_out, fork_target)


func is_picker() -> bool:
	return bool(spec.get("picker", false))


## True for a refurbishment line's own trolley.
func is_line() -> bool:
	return spec.has("line")


## Fast mode on or off; the FAST button lights while it is on.
func set_fast(on: bool) -> void:
	fast = on
	if screen:
		screen.call("set_button", "fast", "FAST", on)


## The FOLLOW ME button reads STOP FOLLOWING while it follows you.
func show_following(on: bool) -> void:
	if screen:
		screen.call("set_button", "call", "STOP FOLLOWING" if on else "FOLLOW ME", on)


func set_deck_target(h: float) -> void:
	deck_target = clampf(h, DECK_MIN, float(spec["lift"]))


func deck_ready() -> bool:
	return absf(deck_height - deck_target) < 0.01


## Follows the stream on peers that don't drive it: keep the yaw in step.
func sync_yaw() -> void:
	_yaw = global_basis.get_euler().y


func show_status(text: String) -> void:
	status = text
	if screen and text != _shown:
		_shown = text
		var colour := T.CYAN if text == "REMOTE" or text == "FOLLOWING" else (T.GOOD if ["PARKED", "ALL PUT AWAY", "HERE", "STOPPED"].has(text) else T.AMBER)
		screen.call("set_status", text.left(14), colour)
	if _lamp:
		_lamp.material_override = _mats["go"] if not path.is_empty() or drive_input != Vector2.ZERO else _mats["wait"]


## Every peer: the beacon turns, and the hum lifts in pitch and loudness with speed.
func _process(delta: float) -> void:
	if beacon:
		beacon.rotate_y(TAU * beacon_spin * delta)
	if hum and delta > 0.0:
		var moved := 0.0 if _was_at == Vector3.INF else (global_position - _was_at).length() / delta
		_was_at = global_position
		var k := clampf(moved / 2.0, 0.0, 1.0)
		hum.pitch_scale = lerpf(hum.pitch_scale, 1.0 + 0.3 * k, minf(1.0, delta * 4.0))
		hum.volume_db = hum_db + 5.0 * k


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
	_lamp = _box(Vector3(0.08, 0.06, 0.08), Vector3(minf(d.x * 0.3, 0.4) - 0.08, CHASSIS_TOP + 0.53, front + 0.1), _mats["wait"])
	_build_beacon(Vector3(-(minf(d.x * 0.3, 0.4) - 0.1), CHASSIS_TOP + 0.5, front + 0.1))
	hum = Sfx.loop("hover_drive", self, hum_db)
	hum.name = "Hum"
	hum.unit_size = 2.5
	hum.max_distance = hum_reach
	var box_w := minf(d.x * 0.6, 0.8)
	screen = Touch.new()
	screen.name = "Screen"
	screen.transform = Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -0.25), Vector3(0, CHASSIS_TOP + 0.26, front - 0.055))
	add_child(screen)
	screen.call("setup", Vector2(box_w - 0.06, 0.36), "TROLLEY %s" % spec["letter"] if not spec.get("picker", false) else str(spec.get("title", "PICKER" if kind == "p" else ("PICKER %s" % kind.substr(1) if spec.has("putaway") else "HEAVY LIFT"))), 2)
	for b: Array in [["call", "FOLLOW ME"], ["park", "PARK"], ["fast", "FAST"], ["remote", "REMOTE CONTROL"]]:
		screen.call("add_button", b[0], b[1], func() -> void: screen_action.emit(b[0]), b[0] == "remote")
	# The yard trolleys tidy the yard: every loose part off a ship to refurb, which sorts it.
	if kind in YARD and Flags.is_on("ship_bay.tidy_to_refurb"):
		screen.call("add_button", "tidy", "TIDY UP TO REFURB", func() -> void: screen_action.emit("tidy"))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(d.x, CHASSIS_TOP - HOVER + 0.5, d.y)
	col.shape = shape
	col.position = Vector3(0, (HOVER + CHASSIS_TOP + 0.5) * 0.5, 0)
	add_child(col)
	# The deck: a grating plate on a frame; the line trolleys have a waist rail round three
	# sides (not the back). The yard trolleys have none, so parts stack on an open deck
	# (beenster, 0.3.18).
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
	if is_picker():
		_build_picker(d)
	elif not (kind == "l" or (kind in YARD and Flags.is_on("ship_bay.open_trolley_decks"))):
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
	for i in (0 if is_picker() else MAST_SECTIONS):
		var w := minf(d.x, d.y) * (0.42 - 0.07 * i)
		_mast.append(_box(Vector3(w, 0.1, w), Vector3.ZERO, _mats["steel"] if i % 2 else _mats["dark"]))


## Two lattice columns up the back with a head beam and a beacon, a stripe down each, the
## carriage on the deck (a frame round the columns) and the shuttle fork on it.
## The beacon: a squat base, an amber dome, and inside it a reflector and a spot light that
## turn round (beacon) so the orange sweeps the floor and walls round the trolley.
func _build_beacon(at: Vector3) -> void:
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.07
	bm.bottom_radius = 0.08
	bm.height = 0.04
	bm.radial_segments = 12
	base.mesh = bm
	base.material_override = _mats["dark"]
	base.position = at + Vector3(0, 0.02, 0)
	add_child(base)
	var dome := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.05
	dm.bottom_radius = 0.065
	dm.height = 0.11
	dm.radial_segments = 12
	dome.mesh = dm
	dome.material_override = _mats["amber_glass"]
	dome.position = at + Vector3(0, 0.095, 0)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)
	beacon = Node3D.new()
	beacon.name = "Beacon"
	beacon.position = at + Vector3(0, 0.09, 0)
	add_child(beacon)
	_box(Vector3(0.02, 0.07, 0.07), Vector3(-0.02, 0, 0), _mats["steel"], beacon)
	_box(Vector3(0.03, 0.04, 0.04), Vector3(0.005, 0, 0), _mats["beacon"], beacon)
	var light := SpotLight3D.new()
	light.name = "BeaconLight"
	light.light_color = Color(1.0, 0.55, 0.12)
	light.light_energy = 2.5
	light.spot_range = beacon_range
	light.spot_angle = 22.0
	light.shadow_enabled = false
	light.set_meta("gfx_no_shadow", true)
	# Points out along +X, tipped a little down to the floor.
	light.transform = Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, -0.25), Vector3(0.03, 0, 0))
	beacon.add_child(light)


func _build_picker(d: Vector2) -> void:
	var mast := float(spec.get("mast", PICKER_MAST))
	var back := d.y * 0.5 - 0.12
	var stripe := ShipSurface.of(ShipKit.paint(Color(1.0, 0.5, 0.12), 0.2, 0.45, "gloss_paint"))
	for sx: float in [-1.0, 1.0]:
		var x := sx * (d.x * 0.5 - 0.1)
		_box(Vector3(0.16, mast - CHASSIS_TOP, 0.16), Vector3(x, (CHASSIS_TOP + mast) * 0.5, back), _mats["body"])
		_box(Vector3(0.05, mast - CHASSIS_TOP - 0.4, 0.02), Vector3(x, (CHASSIS_TOP + mast) * 0.5, back + 0.09), stripe)
		# Lattice: a brace every 0.9 m between the column and a slim back rail.
		_box(Vector3(0.05, mast - CHASSIS_TOP, 0.05), Vector3(x, (CHASSIS_TOP + mast) * 0.5, back + 0.32), _mats["steel"])
		var y := CHASSIS_TOP + 0.45
		while y < mast - 0.3:
			_box(Vector3(0.03, 0.03, 0.3), Vector3(x, y, back + 0.17), _mats["steel"])
			y += 0.9
	_box(Vector3(d.x, 0.18, 0.5), Vector3(0, mast, back + 0.12), _mats["dark"])
	_box(Vector3(0.12, 0.12, 0.12), Vector3(0, mast + 0.15, back + 0.12), _mats["wait"])
	# The carriage rides the columns with the deck; the fork slides out of it sideways.
	_box(Vector3(d.x, 0.6, 0.1), Vector3(0, 0.3, d.y * 0.5 - 0.2), _mats["dark"], deck)
	_fork = Node3D.new()
	_fork.name = "Fork"
	deck.add_child(_fork)
	for sz: float in [-0.3, 0.3]:
		_box(Vector3(d.x + 0.2, 0.05, 0.12), Vector3(0, 0.03, sz), _mats["steel"], _fork)
	# A spine along the fork's middle (off with ship_bay.flat_lift_forks: the load sits on
	# flat tines, beenster 0.3.19).
	if not Flags.is_on("ship_bay.flat_lift_forks"):
		_box(Vector3(0.06, 0.25, d.y * 0.6), Vector3(0, 0.15, 0), _mats["body"], _fork)
	_detail_picker(d, mast, back, stripe)


## The picking lift's finer parts (beenster, 0.3.15: "more fidelity on the picking trolley"):
## a crosshead with twin pulleys and lift chains down to the carriage, guide rollers and a
## side-shift on the carriage, tines with a load backrest, an energy chain up the back of the
## mast, a counterweight with hazard chevrons, a battery box with a charge bar, corner
## bumpers, and a sensor puck and scanner bar for finding its way.
func _detail_picker(d: Vector2, mast: float, back: float, stripe: Material) -> void:
	var hazard := ShipSurface.of(ShipKit.paint(Color(0.95, 0.75, 0.1), 0.2, 0.5, "gloss_paint"))
	var chain := ShipSurface.of(ShipKit.paint(Color(0.2, 0.2, 0.22), 0.8, 0.4, "gunmetal"))
	var col_x := d.x * 0.5 - 0.1
	# Column faces: a flange down each column's front, bolt plates at the foot and head.
	for sx: float in [-1.0, 1.0]:
		var x := sx * col_x
		_box(Vector3(0.2, mast - CHASSIS_TOP - 0.1, 0.02), Vector3(x, (CHASSIS_TOP + mast) * 0.5, back - 0.09), _mats["steel"])
		for y: float in [CHASSIS_TOP + 0.06, mast - 0.16]:
			_box(Vector3(0.26, 0.08, 0.26), Vector3(x, y, back), _mats["dark"])
	# The crosshead: twin pulleys over the columns, chains down to the carriage (_set_deck
	# keeps their length).
	for sx: float in [-1.0, 1.0]:
		var x := sx * (col_x - 0.16)
		_cyl(0.09, 0.06, Vector3(x, mast + 0.02, back - 0.05), _mats["steel"], null, Basis(Vector3.BACK, PI * 0.5))
		var run := _box(Vector3(0.03, 1.0, 0.03), Vector3(x, mast * 0.5, back - 0.05), chain)
		run.name = "LiftChain"
		_chains.append(run)
	# Energy chain: links up the back of the mast carrying the carriage's power and data.
	var link := Vector3(0.12, 0.1, 0.06)
	var y := CHASSIS_TOP + 0.2
	while y < mast - 0.2:
		_box(link, Vector3(0.0, y, back + 0.36), chain if int(y * 10.0) % 2 == 0 else _mats["dark"])
		y += 0.13
	_box(Vector3(0.14, mast - CHASSIS_TOP - 0.2, 0.02), Vector3(0, (CHASSIS_TOP + mast) * 0.5, back + 0.4), _mats["dark"])
	# The carriage: guide rollers on each column, a side-shift plate, a backrest over the tines.
	for sx: float in [-1.0, 1.0]:
		for ry: float in [0.1, 0.5]:
			_cyl(0.05, 0.05, Vector3(sx * (col_x - 0.12), ry, d.y * 0.5 - 0.16), _mats["steel"], deck, Basis(Vector3.BACK, PI * 0.5))
	_box(Vector3(d.x * 0.7, 0.14, 0.06), Vector3(0, 0.52, d.y * 0.5 - 0.27), stripe, deck)
	_cyl(0.035, 0.4, Vector3(d.x * 0.25, 0.3, d.y * 0.5 - 0.3), _mats["steel"], deck, Basis.IDENTITY)
	for sz: float in [-0.3, 0.3]:
		# Tine tips and a short backrest at the fork's root.
		_box(Vector3(0.06, 0.04, 0.12), Vector3((d.x + 0.2) * 0.5 + 0.03, 0.02, sz), _mats["dark"], _fork)
		_box(Vector3(0.06, 0.04, 0.12), Vector3(-(d.x + 0.2) * 0.5 - 0.03, 0.02, sz), _mats["dark"], _fork)
	if not Flags.is_on("ship_bay.flat_lift_forks"):
		_box(Vector3(0.04, 0.4, d.y * 0.7), Vector3(0, 0.45, 0), _mats["steel"], _fork)
	# The base: a counterweight under the mast with hazard chevrons, a battery box with its
	# charge bar, yellow corner bumpers, a scanner bar and a sensor puck at the front.
	var front := -d.y * 0.5
	_box(Vector3(d.x - 0.1, 0.28, 0.34), Vector3(0, CHASSIS_TOP + 0.14, back - 0.12), _mats["dark"])
	for k in 4:
		var cx := -d.x * 0.36 + k * d.x * 0.24
		_box(Vector3(0.1, 0.22, 0.02), Vector3(cx, CHASSIS_TOP + 0.14, back - 0.3),
				hazard if k % 2 == 0 else _mats["dark"]).rotation.z = 0.6
	_box(Vector3(0.36, 0.22, 0.28), Vector3(d.x * 0.22, CHASSIS_TOP + 0.11, front + 0.48), _mats["dark"])
	_box(Vector3(0.24, 0.04, 0.01), Vector3(d.x * 0.22, CHASSIS_TOP + 0.15, front + 0.335), _mats["go"])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(Vector3(0.12, 0.14, 0.12), Vector3(sx * (d.x * 0.5 + 0.02), HOVER + 0.1, sz * (d.y * 0.5 + 0.02)), hazard)
	_box(Vector3(d.x * 0.5, 0.05, 0.05), Vector3(0, HOVER + 0.12, front - 0.03), _mats["pad"])
	_cyl(0.06, 0.07, Vector3(0, mast + 0.27, back + 0.12), _mats["dark"], null, Basis.IDENTITY)
	_cyl(0.045, 0.03, Vector3(0, mast + 0.32, back + 0.12), _mats["pad"], null, Basis.IDENTITY)


func _cyl(radius: float, height: float, at: Vector3, mat: Material, parent: Node3D, basis: Basis) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 12
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	mi.transform = Transform3D(basis, at)
	(parent if parent else self).add_child(mi)
	return mi


func _set_deck(h: float) -> void:
	deck_height = h
	deck.position = Vector3(0, h, 0)
	# Each section slides out of the one below; they share the rise and keep an overlap.
	var bottom := CHASSIS_TOP
	var rise := maxf(h - 0.12 - bottom, 0.05)
	var overlap := 0.08
	var each := rise / MAST_SECTIONS + overlap
	for i in _mast.size():
		var sec := _mast[i]
		var y0 := bottom + i * (each - overlap)
		(sec.mesh as BoxMesh).size.y = each
		sec.position = Vector3(0, y0 + each * 0.5, 0)
	# A picking lift's chains run from its crosshead down to the carriage.
	var top := float(spec.get("mast", PICKER_MAST))
	for run in _chains:
		var length := maxf(top - (h + 0.6), 0.05)
		(run.mesh as BoxMesh).size.y = length
		run.position.y = h + 0.6 + length * 0.5


func _box(size: Vector3, at: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	(parent if parent else self).add_child(mi)
	return mi


static var _amber: StandardMaterial3D


## The beacon's dome: see-through amber with a faint glow of its own.
static func _amber_glass() -> StandardMaterial3D:
	if _amber == null:
		_amber = StandardMaterial3D.new()
		_amber.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_amber.albedo_color = Color(1.0, 0.5, 0.08, 0.55)
		_amber.roughness = 0.15
		_amber.emission_enabled = true
		_amber.emission = Color(1.0, 0.45, 0.05)
		_amber.emission_energy_multiplier = 0.8
	return _amber
