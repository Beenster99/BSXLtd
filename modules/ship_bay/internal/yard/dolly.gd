extends AnimatableBody3D
## A self-propelled modular transporter, like the crawlers that move rocket stages: a low
## flat deck on rows of wheel bogies, every bogie steered, hydraulic struts that lift the deck
## 1.5 m to pick a transport cradle (and the hull in it) off its pedestals. Two sizes (SPECS):
## the dolly for Dock 1 and sections, the crawler for whole hulls. A low cab at the front left
## corner (it passes under a cradle's cross beams), a power pack at the front right, amber
## beacons that flash while it moves or lifts, and a status screen on the cab.
##
## Steering (`mode`): "normal" (the ends steer opposite ways round a centre abeam the middle),
## "crab" (every bogie the same way, up to square across, for sliding sideways into a dock)
## and "carousel" (turning on the spot). Slow: walking pace loaded (`speed_loaded`).
##
## This node moves and draws. Transporters decides who drives it and checks the way (it stops
## dead for a person under the deck or anything within 0.5 m of where it is going), and
## handles the cradles. Every peer turns the bogies from how it actually moves (so copies
## placed by the Multiplayer mover stream steer and roll too) and follows `deck_target`.
## Dolly space: origin on the ground under the deck's middle, -Z its front (the cab's end).

const SPECS := {
	"dolly": {"name": "Transporter dolly", "letter": "D", "size": Vector2(6.0, 12.0), "lines": 4, "across": 2,
			"capacity_t": 400.0, "colour": Color(1.0, 0.55, 0.16)},
	"crawler": {"name": "Crawler", "letter": "C", "size": Vector2(14.0, 30.0), "lines": 10, "across": 4,
			"capacity_t": 3000.0, "colour": Color(0.95, 0.75, 0.1)},
}
const MODES: Array[String] = ["normal", "crab", "carousel"]
## The deck's top over the ground at its lowest, its lift and its thickness, metres.
const DECK_LOW := 1.0
const LIFT := 1.5
const DECK_T := 0.3
const WHEEL_R := 0.3
## The cab: width, roof height over the ground, depth (it stands off the deck's front), metres.
const CAB := Vector3(1.6, 1.5, 1.7)

## Top speed with a load and without, metres per second.
@export var speed_loaded := 1.0
@export var speed_empty := 1.5
## How fast it gets up to speed and stops, metres per second squared.
@export var accel := 0.35
## How fast the bogies swing to a new steering angle, radians per second.
@export var steer_rate := 0.6
## The ends' steering lock in normal mode, degrees.
@export var normal_lock := 30.0
## Turning on the spot: the corners' speed at full lock, metres per second.
@export var carousel_speed := 0.8
## How fast the deck rises and falls, metres per second.
@export var lift_speed := 0.15

var kind := "dolly"
var spec: Dictionary
var deck: AnimatableBody3D
var deck_height := DECK_LOW
var deck_target := DECK_LOW
var mode := "normal"
## Input this frame (the driving peer): drive -1 back .. 1 ahead, steer -1 left .. 1 right.
var drive := 0.0
var steer := 0.0
## The steering angle the bogies are set to: normal lock or crab angle (radians, + right).
var steer_angle := 0.0
## What it says on its screen, and why it stopped this step ("" when nothing stopped it; the
## driving peer clears it each step).
var status := "PARKED"
var stopped := ""
## The cradle it carries, or null; its transform in deck space while carried.
var load_cradle: Node3D
var load_offset := Transform3D.IDENTITY
## Where a seated driver's eye is (dolly space) and the cab's own collision shape.
var cab_eye := Vector3.ZERO
var cab_shape: CollisionShape3D
var cab_camera: Camera3D

var _speed := 0.0
var _spin := 0.0
var _bogies: Array[Dictionary] = []   # {swivel, wheels, strut, at: Vector2, roll}
var _struts: Array[MeshInstance3D] = []
var _beacons: Array[MeshInstance3D] = []
var _beacon_on: Material
var _beacon_off: Material
var _screen: Label3D
var _last := Transform3D.IDENTITY
var _clock := 0.0


func setup(p_kind: String, at: Vector3, yaw: float) -> void:
	kind = p_kind
	spec = SPECS[kind]
	name = "Transporter_" + kind
	add_to_group("gfx_interactable")
	set_meta("gfx_id", "transporter:" + kind)
	sync_to_physics = false
	_build()
	global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, 0.0, at.z))
	_last = global_transform
	_set_deck(DECK_LOW)


func size() -> Vector2:
	return spec["size"]


func speed() -> float:
	return _speed


func is_loaded() -> bool:
	return load_cradle != null


## The deck's sockets where a cradle's pins drop in (dolly space, on the deck's top).
func sockets() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for x: float in [-2.2, 2.2]:
		for z: float in [-3.8, 3.8]:
			out.append(Vector3(x, deck_height, z))
	return out


## Cycles the steering mode (only while stood still: the bogies swing round first).
func next_mode() -> void:
	mode = MODES[(MODES.find(mode) + 1) % MODES.size()]
	steer_angle = 0.0


## One physics step on the driving peer: steers, then moves unless `clear` (a Callable taking
## the local velocity and turn rate, returning "" or why not) says no.
func step(delta: float, clear: Callable) -> void:
	var lock := deg_to_rad(normal_lock) if mode == "normal" else PI * 0.5
	if mode != "carousel":
		steer_angle = move_toward(steer_angle, steer * lock, steer_rate * delta)
	var top := speed_loaded if load_cradle else speed_empty
	var lin := Vector3.ZERO
	var turn := 0.0
	if mode == "carousel":
		_speed = 0.0
		var corner := size().length() * 0.5
		_spin = move_toward(_spin, -steer * carousel_speed / corner, accel / corner * delta)
		turn = _spin
	else:
		_spin = 0.0
		_speed = move_toward(_speed, drive * top, accel * delta)
		if mode == "normal":
			lin = Vector3(0, 0, -_speed)
			turn = -_speed * tan(steer_angle) / _half_base()
		else:
			lin = Vector3(sin(steer_angle), 0, -cos(steer_angle)) * _speed
	if lin.length() < 0.0005 and absf(turn) < 0.0001:
		return
	var why: String = clear.call(lin, turn)
	if why != "":
		stopped = why
		_speed = 0.0
		_spin = 0.0
		return
	var xf := global_transform
	xf.origin += xf.basis * lin * delta
	xf.basis = Basis(Vector3.UP, turn * delta) * xf.basis
	global_transform = xf


## Stops at once (a person ran under it, the driver let go).
func halt() -> void:
	_speed = 0.0
	_spin = 0.0
	drive = 0.0
	steer = 0.0


func set_deck_target(h: float) -> void:
	deck_target = clampf(h, DECK_LOW, DECK_LOW + LIFT)


## Where this dolly would be after moving `lin` (dolly space) and turning `turn` for `t`.
func ahead(lin: Vector3, turn: float, t: float) -> Transform3D:
	var xf := global_transform
	xf.origin += xf.basis * lin * t
	xf.basis = Basis(Vector3.UP, turn * t) * xf.basis
	return xf


## How far the corners travel per second at this velocity and turn, metres.
func corner_speed(lin: Vector3, turn: float) -> float:
	return lin.length() + absf(turn) * size().length() * 0.5


func _half_base() -> float:
	return size().y * 0.5 - size().y / float(spec["lines"]) * 0.5


func _physics_process(delta: float) -> void:
	_clock += delta
	if not is_equal_approx(deck_height, deck_target):
		_set_deck(move_toward(deck_height, deck_target, lift_speed * delta))
	if load_cradle:
		load_cradle.global_transform = deck.global_transform * load_offset
	# The bogies follow how it actually moved since the last step.
	var xf := global_transform
	var lin := xf.basis.inverse() * (xf.origin - _last.origin) / maxf(delta, 0.0001)
	var turn := (_last.basis.inverse() * xf.basis).get_euler().y / maxf(delta, 0.0001)
	_last = xf
	var moving := lin.length() > 0.01 or absf(turn) > 0.001
	_turn_bogies(lin, turn, delta, moving)
	var busy := moving or not is_equal_approx(deck_height, deck_target)
	var flash := busy and fmod(_clock, 0.8) < 0.4
	for b: MeshInstance3D in _beacons:
		b.material_override = _beacon_on if flash else _beacon_off
	_screen.text = screen_text()


func screen_text() -> String:
	var pins := "--"
	if load_cradle:
		pins = "LOCKED"
	var load_t := float(load_cradle.get("load_t")) if load_cradle else 0.0
	return "%s  %s\nDECK %.2f M\nLOAD %d / %d T\nPINS %s\n%s" % [str(spec["letter"]), mode.to_upper(),
			deck_height - DECK_LOW, int(load_t), int(spec["capacity_t"]), pins, stopped if stopped != "" else status]


## Points each bogie along its own wheels' path (from the motion, or the steering setting
## when standing still) and rolls the wheels.
func _turn_bogies(lin: Vector3, turn: float, delta: float, moving: bool) -> void:
	for b: Dictionary in _bogies:
		var p: Vector2 = b.at
		var v := Vector3(lin.x + turn * p.y, 0, lin.z - turn * p.x)
		var roll := 0.0
		if not moving:
			v = _preview(p)
		else:
			roll = v.length() * delta / WHEEL_R
		if v.length() < 0.0001:
			continue
		var a := atan2(-v.x, -v.z)
		if absf(a) > PI * 0.5:
			a -= signf(a) * PI
			roll = -roll
		var swivel: Node3D = b.swivel
		swivel.rotation.y = a
		b.roll = float(b.roll) - roll
		for w: Node3D in b.wheels:
			w.rotation.x = float(b.roll)


## Which way a bogie at `p` points for the current mode and setting, standing still.
func _preview(p: Vector2) -> Vector3:
	match mode:
		"carousel":
			return Vector3(p.y, 0, -p.x)
		"crab":
			return Vector3(sin(steer_angle), 0, -cos(steer_angle))
	var t := -tan(steer_angle) / _half_base()
	return Vector3(t * p.y, 0, -1.0 - t * p.x)


func _set_deck(h: float) -> void:
	deck_height = h
	if deck:
		deck.position.y = h
	# Each strut runs from its bogie's beam up to the deck's underside.
	var base := WHEEL_R * 2.0 + 0.06
	var span := maxf(h - DECK_T - base, 0.05)
	for s: MeshInstance3D in _struts:
		s.scale = Vector3(1, span, 1)
		s.position.y = base + span * 0.5


func _build() -> void:
	var paint := ShipSurface.of(ShipKit.paint(spec["colour"], 0.2, 0.45, "gloss_paint"))
	var dark := ShipSurface.of(ShipKit.paint(Color(0.15, 0.16, 0.18), 0.5, 0.5, "gunmetal"))
	var steel := ShipSurface.of(ShipKit.paint(Color(0.55, 0.57, 0.6), 0.85, 0.3, "chrome"))
	var tyre := ShipSurface.of(ShipKit.paint(Color(0.07, 0.07, 0.075), 0.0, 0.9, "rubber"))
	var tread := ShipSurface.of(ShipKit.paint(Color(0.42, 0.44, 0.46), 0.8, 0.45, "rubber_tread"))
	_beacon_on = ShipKit.glow(Color(1.0, 0.62, 0.1), 4.0)
	_beacon_off = ShipSurface.of(ShipKit.paint(Color(0.5, 0.3, 0.08), 0.1, 0.4))
	var s := size()
	# The deck: its own body, raised and lowered on the struts. A tread-plate top on an
	# orange box with a dark rubbing strip round it.
	deck = AnimatableBody3D.new()
	deck.name = "Deck"
	deck.sync_to_physics = false
	add_child(deck)
	_mesh(deck, PartShapes.chamfer_box(Vector3(s.x, DECK_T - 0.02, s.y), 0.06), Vector3(0, -DECK_T * 0.5 - 0.01, 0), paint)
	_mesh(deck, PartShapes.box(Vector3(s.x - 0.3, 0.02, s.y - 0.3)), Vector3(0, -0.009, 0), tread)
	_mesh(deck, PartShapes.box(Vector3(s.x + 0.06, 0.12, s.y + 0.06)), Vector3(0, -DECK_T + 0.08, 0), dark)
	var deck_col := CollisionShape3D.new()
	deck_col.shape = _box_shape(Vector3(s.x, DECK_T, s.y))
	deck_col.position.y = -DECK_T * 0.5
	deck.add_child(deck_col)
	deck.set_meta("ship_bay_use", Callable())   # Transporters sets the real one
	# The sockets on the deck, ringed in yellow so the crew can see them line up.
	var yellow := ShipSurface.of(ShipKit.paint(Color(0.95, 0.75, 0.1), 0.15, 0.5, "hazard_paint"))
	for x: float in [-2.2, 2.2]:
		for z: float in [-3.8, 3.8]:
			_mesh(deck, PartShapes.ring(0.1, 0.22, 0.02, 16), Vector3(x, 0.002, z), yellow)
	# The bogies: a swivel under the deck with its wheel pair, a strut up to the deck.
	var lines := int(spec["lines"])
	var across := int(spec["across"])
	var pitch := s.y / float(lines)
	var spread := s.x / float(across)
	for i in lines:
		for j in across:
			var at := Vector2(-s.x * 0.5 + spread * (j + 0.5), -s.y * 0.5 + pitch * (i + 0.5))
			var swivel := Node3D.new()
			swivel.position = Vector3(at.x, 0, at.y)
			add_child(swivel)
			var wheels: Array[Node3D] = []
			for k: float in [-1.0, 1.0]:
				var w := Node3D.new()
				w.position = Vector3(k * 0.3, WHEEL_R, 0)
				swivel.add_child(w)
				_mesh(w, PartShapes.prism(14, WHEEL_R, 0.26), Vector3.ZERO, tyre, Basis(Vector3.FORWARD, PI * 0.5))
				_mesh(w, PartShapes.prism(8, WHEEL_R * 0.5, 0.28), Vector3.ZERO, steel, Basis(Vector3.FORWARD, PI * 0.5))
				wheels.append(w)
			_mesh(swivel, PartShapes.box(Vector3(0.9, 0.16, 0.3)), Vector3(0, WHEEL_R * 2.0 - 0.02, 0), dark)
			var strut := _mesh(swivel, WreckParts.pipe(0.1, 1.0, false), Vector3.ZERO, steel)
			_struts.append(strut)
			_bogies.append({"swivel": swivel, "wheels": wheels, "at": at, "roll": 0.0})
	var low := CollisionShape3D.new()
	low.shape = _box_shape(Vector3(s.x - 0.1, WHEEL_R * 2.0, s.y - 0.1))
	low.position.y = WHEEL_R + 0.05
	add_child(low)
	# The cab at the front left corner, standing off the deck's front, and the power pack at
	# the front right: both low enough to pass under a cradle's cross beams.
	var front := -s.y * 0.5 - CAB.z * 0.5 - 0.05
	var cab_at := Vector3(-s.x * 0.5 + CAB.x * 0.5, 0, front)
	_mesh(self, PartShapes.chamfer_box(Vector3(CAB.x, 0.5, CAB.z), 0.05), cab_at + Vector3(0, 0.45, 0), paint)
	_mesh(self, PartShapes.chamfer_box(Vector3(CAB.x, 0.08, CAB.z), 0.03), cab_at + Vector3(0, CAB.y - 0.04, 0), paint)
	for px: float in [-1.0, 1.0]:
		for pz: float in [-1.0, 1.0]:
			_mesh(self, PartShapes.box(Vector3(0.07, CAB.y - 0.78, 0.07)), cab_at + Vector3(px * (CAB.x * 0.5 - 0.06), 0.7 + (CAB.y - 0.78) * 0.5, pz * (CAB.z * 0.5 - 0.06)), dark)
	_mesh(self, PartShapes.chamfer_box(Vector3(0.6, 0.12, 0.6), 0.03), cab_at + Vector3(0, 0.76, 0.2), dark)   # the seat
	_mesh(self, PartShapes.chamfer_box(Vector3(0.6, 0.5, 0.1), 0.03), cab_at + Vector3(0, 1.0, 0.52), dark)    # its back
	_mesh(self, PartShapes.box(Vector3(1.2, 0.3, 0.3)), cab_at + Vector3(0, 0.85, -0.6), dark)                  # the dash
	for k: float in [-1.0, 1.0]:
		_beacons.append(_mesh(self, PartShapes.prism(10, 0.07, 0.06), cab_at + Vector3(k * 0.55, CAB.y + 0.03, 0), _beacon_off))
	cab_eye = cab_at + Vector3(0, 1.2, 0.15)
	_screen = Label3D.new()
	_screen.font_size = 40
	_screen.pixel_size = 0.0028
	_screen.modulate = Color(1.0, 0.75, 0.3)
	_screen.outline_size = 0
	_screen.shaded = false
	_screen.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_screen.position = cab_at + Vector3(0, 1.12, -0.47)
	_screen.rotation.x = -0.5
	add_child(_screen)
	cab_shape = CollisionShape3D.new()
	cab_shape.shape = _box_shape(Vector3(CAB.x, CAB.y - 0.1, CAB.z))
	cab_shape.position = cab_at + Vector3(0, (CAB.y + 0.1) * 0.5, 0)
	add_child(cab_shape)
	cab_camera = Camera3D.new()
	cab_camera.name = "CabCamera"
	cab_camera.position = cab_eye
	cab_camera.far = 6000.0
	add_child(cab_camera)
	var pack_at := Vector3(s.x * 0.5 - 1.0, 0, front)
	_mesh(self, WreckParts.machine_unit(Vector3(1.8, 1.0, CAB.z - 0.1)), pack_at + Vector3(0, 0.6, 0), dark)
	var pack := CollisionShape3D.new()
	pack.shape = _box_shape(Vector3(1.8, 1.0, CAB.z - 0.1))
	pack.position = pack_at + Vector3(0, 0.6, 0)
	add_child(pack)


func _mesh(parent: Node3D, shape: PartShapes.PartShape, at: Vector3, mat: Material, basis := Basis()) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = shape.mesh
	mi.material_override = mat
	mi.transform = Transform3D(basis, at)
	parent.add_child(mi)
	return mi


static func _box_shape(s: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = s
	return b
