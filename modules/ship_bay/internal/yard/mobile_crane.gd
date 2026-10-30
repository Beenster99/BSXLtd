extends Node3D
## A mobile crane by Dock 2 or 3 (S6, flag "ship_bay.sections"): an eight-wheeled carrier with
## a cab at the front, four outriggers, a slewing superstructure with its own cab and a
## counterweight, a telescopic boom that luffs to reach and a hook block on its rope. It lifts
## a hull section cut free onto its stand into an empty transport cradle within reach (on
## its pedestals or on the dolly), which a transporter then takes away.
##
## This node moves and draws. YardShips picks the section and the cradle and seats the
## section when it is set down (`lift`); every peer runs the same moves from the same hull
## state. It drives out from where it parks to beside the section, puts its outriggers down,
## swings over the section, lowers the hook, lifts it clear, slews to the cradle, sets it in
## the saddles and drives home again. Crane space: origin on the ground under the carrier's
## middle, -Z its front (the carrier cab's end).

## The boom's length, how far out the hook can reach (across the ground from the slewing
## ring) and the slewing ring's pivot over the carrier's middle, metres.
const BOOM := 42.0
const REACH := 30.0
const PIVOT := Vector3(0, 3.4, 1.5)
## The slings from the hook down to a load's top, metres.
const SLING := 3.0
## The carrier: width, length; the outriggers' reach out each side, metres.
const CARRIER := Vector2(3.0, 13.0)
const OUTRIGGER := 3.0

## Travel speed between jobs, metres per second.
@export var drive_speed := 4.0
## How fast the superstructure slews, radians per second.
@export var slew_rate := 0.3
## How fast the hook goes up and down and in and out, metres per second.
@export var hoist_speed := 2.0

## Where it parks (ground point; it faces north).
var home := Vector3.ZERO
var busy := false
## What it says on its screen.
var status := "READY"
var body: AnimatableBody3D
## Pressed F on it (YardShips sets this).
var on_use: Callable

## The pose: the carrier's ground point, the boom's heading (world yaw, radians), the hook's
## reach across the ground from the pivot and its height, the load's heading, the outriggers
## (0 in .. 1 down).
var _pose := {"p": Vector3.ZERO, "a": 0.0, "r": 8.0, "hy": 12.0, "yaw": 0.0, "out": 0.0}
var _legs: Array[Dictionary] = []
var _leg_from := {}
var _leg_t := 0.0
var _leg_dur := 0.0
var _load: Node3D
## The load's lowest broad point's middle and its top, in its own space.
var _load_centre := Vector3.ZERO
var _load_top := 0.0
var _load_half := Vector2.ONE

var _slew: Node3D
var _boom: Node3D
var _boom_parts: Array[MeshInstance3D] = []
var _hook: MeshInstance3D
var _rope: MeshInstance3D
var _slings: Array[MeshInstance3D] = []
var _outriggers: Array[Node3D] = []
var _screen: Label3D


func setup(at: Vector3) -> void:
	home = at
	_build()
	_pose["p"] = at
	_pose["a"] = 0.0
	_apply()


func look_hint() -> Dictionary:
	return {"title": "Mobile crane", "text": "Lifts a hull section off its stand into an empty transport cradle within %d m (on its pedestals or on the dolly). %s" % [int(REACH), status],
			"keys": [] if busy else [["F", "Lift the next section"]]}


## Lifts `load` (a section on its stand) and sets it at `to` (its world transform in the
## cradle's saddles), working from `spot` (the carrier's ground point). `centre` is the
## middle of the load's lowest broad part in its own space, `top` its top and `half` half its
## size across (x, z); `done` is called the moment it is set down.
func lift(load: Node3D, to: Transform3D, spot: Vector3, centre: Vector3, top: float, half: Vector2, done: Callable) -> void:
	busy = true
	_load = null
	_load_centre = centre
	_load_top = top
	_load_half = half
	var from := load.global_transform
	var from_yaw := from.basis.get_euler().y
	var to_yaw := to.basis.get_euler().y
	var pick := from * centre
	var drop := to * centre
	var pick_hy := from.origin.y + top + SLING
	var drop_hy := to.origin.y + top + SLING
	var clear := maxf(pick_hy, drop_hy) + 2.0
	_legs.clear()
	_queue({"p": spot, "hy": clear}, "DRIVING")
	_queue({"out": 1.0}, "SETTING UP")
	_queue(_aim(spot, pick).merged({"hy": clear}), "SWINGING OVER")
	_queue({"hy": pick_hy}, "LOWERING THE HOOK", func() -> void:
			_load = load
			_pose["yaw"] = from_yaw)
	_queue({"hy": clear}, "LIFTING")
	_queue(_aim(spot, drop).merged({"yaw": from_yaw + wrapf(to_yaw - from_yaw, -PI, PI)}), "SLEWING")
	_queue({"hy": drop_hy}, "SETTING DOWN", func() -> void:
			_load = null
			done.call())
	_queue({"hy": clear}, "CLEAR")
	_queue({"out": 0.0}, "PACKING UP")
	_queue({"p": home, "a": 0.0, "r": 8.0}, "DRIVING HOME", func() -> void:
			busy = false
			status = "READY")
	_start_leg()


## Whether the hook reaches `at` (world) from a carrier at `spot`.
static func reaches(spot: Vector3, at: Vector3) -> bool:
	var pivot := spot + PIVOT
	return Vector2(at.x - pivot.x, at.z - pivot.z).length() <= REACH


## Stops at once where it is and parks (the load it held went away).
func abandon() -> void:
	_load = null
	_legs.clear()
	_queue({"out": 0.0}, "PACKING UP")
	_queue({"p": home, "a": 0.0, "r": 8.0}, "DRIVING HOME", func() -> void:
			busy = false
			status = "READY")
	_start_leg()


func _aim(spot: Vector3, at: Vector3) -> Dictionary:
	var pivot := spot + PIVOT
	var d := Vector2(at.x - pivot.x, at.z - pivot.z)
	return {"a": atan2(-d.x, -d.y), "r": clampf(d.length(), 4.0, REACH)}


func _queue(to: Dictionary, what: String, then := Callable()) -> void:
	_legs.append({"to": to, "status": what, "then": then})


func _start_leg() -> void:
	if _legs.is_empty():
		set_process(false)
		return
	var leg: Dictionary = _legs[0]
	status = str(leg["status"])
	_leg_from = _pose.duplicate()
	_leg_t = 0.0
	var to: Dictionary = leg["to"]
	var dur := 0.5
	if to.has("p"):
		dur = maxf(dur, ((to["p"] as Vector3) - (_pose["p"] as Vector3)).length() / drive_speed)
	if to.has("a"):
		dur = maxf(dur, absf(wrapf(float(to["a"]) - float(_pose["a"]), -PI, PI)) / slew_rate)
	if to.has("yaw"):
		dur = maxf(dur, absf(float(to["yaw"]) - float(_pose["yaw"])) / slew_rate)
	if to.has("r"):
		dur = maxf(dur, absf(float(to["r"]) - float(_pose["r"])) / hoist_speed)
	if to.has("hy"):
		dur = maxf(dur, absf(float(to["hy"]) - float(_pose["hy"])) / hoist_speed)
	if to.has("out"):
		dur = maxf(dur, 2.0)
	_leg_dur = dur
	set_process(true)


func _process(delta: float) -> void:
	if _legs.is_empty():
		set_process(false)
		return
	if _load != null and not is_instance_valid(_load):
		abandon()
		return
	_leg_t += delta
	var k := smoothstep(0.0, 1.0, clampf(_leg_t / _leg_dur, 0.0, 1.0))
	var leg: Dictionary = _legs[0]
	for key: String in leg["to"]:
		var a: Variant = _leg_from[key]
		var b: Variant = leg["to"][key]
		if key == "a":
			_pose[key] = lerp_angle(float(a), float(b), k)
		elif a is Vector3:
			_pose[key] = (a as Vector3).lerp(b, k)
		else:
			_pose[key] = lerpf(float(a), float(b), k)
	_apply()
	if _leg_t >= _leg_dur:
		_legs.pop_front()
		var then: Callable = leg["then"]
		if then.is_valid():
			then.call()
		_start_leg()


## Puts every moving part where the pose says, and the load on the hook.
func _apply() -> void:
	var p: Vector3 = _pose["p"]
	global_position = p
	var a := float(_pose["a"])
	_slew.rotation.y = a
	var r := float(_pose["r"])
	var hy := float(_pose["hy"])
	var lean := acos(clampf(r / BOOM, 0.0, 1.0))
	_boom.rotation.x = lean
	var pivot := p + PIVOT
	var dir := Vector3(-sin(a), 0, -cos(a))
	var tip := pivot + dir * cos(lean) * BOOM + Vector3.UP * sin(lean) * BOOM
	var hook := Vector3(tip.x, minf(hy, tip.y - 1.5), tip.z)
	_hook.global_position = hook
	_line(_rope, hook + Vector3(0, 0.6, 0), tip)
	for i in _outriggers.size():
		var o := _outriggers[i]
		var side := -1.0 if i % 2 == 0 else 1.0
		o.position.x = side * (CARRIER.x * 0.5 + OUTRIGGER * float(_pose["out"]) - 0.3)
	var held := _load != null and is_instance_valid(_load)
	for s: MeshInstance3D in _slings:
		s.visible = held
	if not held:
		_screen.text = "CRANE\n" + status
		return
	var yaw := float(_pose["yaw"])
	var basis := Basis(Vector3.UP, yaw)
	var origin := hook - Vector3(0, _load_top + SLING - _load_centre.y, 0) - basis * Vector3(_load_centre.x, _load_centre.y, _load_centre.z)
	_load.global_transform = Transform3D(basis, origin)
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	for i in 4:
		var c: Vector2 = corners[i]
		var at := _load.global_transform * Vector3(_load_centre.x + c.x * _load_half.x * 0.7, _load_top, _load_centre.z + c.y * _load_half.y * 0.7)
		_line(_slings[i], at, hook)
	_screen.text = "CRANE\n" + status


## Stretches `mi` (a unit-tall box) from `a` up to `b`.
static func _line(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.01:
		mi.visible = false
		return
	mi.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, d / len)) * Basis.from_scale(Vector3(1, len, 1)), (a + b) * 0.5)


# --- The look -------------------------------------------------------------------------------

func _mat(c: Color, metal := 0.2, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = PartShapes.box(size).mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material, basis := Basis()) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 16
	mi.mesh = m
	mi.material_override = mat
	mi.transform = Transform3D(basis, at)
	parent.add_child(mi)
	return mi


func _build() -> void:
	var yellow := _mat(Color(0.96, 0.72, 0.08), 0.2, 0.5)
	var dark := _mat(Color(0.16, 0.17, 0.18), 0.3, 0.7)
	var steel := _mat(Color(0.55, 0.57, 0.6), 0.7, 0.4)
	var glass := _mat(Color(0.2, 0.3, 0.38), 0.1, 0.1)
	var tyre := _mat(Color(0.07, 0.07, 0.07), 0.0, 0.9)
	var rope := _mat(Color(0.3, 0.3, 0.32), 0.6, 0.5)
	body = AnimatableBody3D.new()
	body.sync_to_physics = false
	add_child(body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(CARRIER.x, 2.6, CARRIER.y)
	col.shape = shape
	col.position = Vector3(0, 1.5, 0)
	body.add_child(col)
	for n: Node in [body, col]:
		n.set_meta("ship_bay_use", Callable(self, "_used"))
	# The carrier: chassis, cab, wheels, a hazard-striped tail.
	_box(self, Vector3(CARRIER.x, 1.0, CARRIER.y), Vector3(0, 1.6, 0), yellow)
	_box(self, Vector3(CARRIER.x - 0.4, 0.5, CARRIER.y - 1.0), Vector3(0, 0.9, 0), dark)
	var cab := _box(self, Vector3(2.6, 1.9, 2.0), Vector3(0, 2.9, -CARRIER.y * 0.5 + 1.0), yellow)
	_box(cab, Vector3(2.3, 0.9, 0.05), Vector3(0, 0.3, -1.01), glass)
	for i in 4:
		var z := -4.6 + i * 2.0 + (3.2 if i >= 2 else 0.0)
		for side: float in [-1.0, 1.0]:
			_cyl(self, 0.65, 0.5, Vector3(side * (CARRIER.x * 0.5 - 0.1), 0.65, z), tyre, Basis(Vector3.BACK, PI * 0.5))
	# Outriggers: a beam out each side at each end with a jack and a pad.
	for z: float in [-CARRIER.y * 0.5 + 2.6, CARRIER.y * 0.5 - 0.8]:
		for side: float in [-1.0, 1.0]:
			var o := Node3D.new()
			add_child(o)
			o.position = Vector3(side * (CARRIER.x * 0.5 - 0.3), 1.4, z)
			_box(o, Vector3(1.0, 0.4, 0.4), Vector3(-side * 0.5, 0, 0), yellow)
			_box(o, Vector3(0.3, 1.2, 0.3), Vector3(0, -0.7, 0), steel)
			_box(o, Vector3(0.8, 0.1, 0.8), Vector3(0, -1.35, 0), dark)
			_outriggers.append(o)
	# The superstructure: slewing ring, deck, operator's cab, counterweight.
	_slew = Node3D.new()
	add_child(_slew)
	_slew.position = Vector3(0, 2.1, PIVOT.z)
	_cyl(_slew, 1.3, 0.3, Vector3(0, 0.15, 0), dark)
	_box(_slew, Vector3(2.8, 1.0, 5.4), Vector3(0, 0.8, 1.2), yellow)
	var op := _box(_slew, Vector3(1.0, 1.7, 1.6), Vector3(-1.0, 1.8, -0.8), yellow)
	_box(op, Vector3(0.8, 1.0, 0.05), Vector3(0, 0.2, -0.81), glass)
	_box(_slew, Vector3(2.8, 1.4, 1.4), Vector3(0, 1.0, 3.6), dark)
	_screen = Label3D.new()
	_screen.font_size = 48
	_screen.pixel_size = 0.006
	_screen.modulate = Color(1.0, 0.8, 0.3)
	_screen.position = Vector3(0.0, 2.0, 3.0)
	_screen.rotation.y = 0.0
	_slew.add_child(_screen)
	# The boom: three telescoping sections from the pivot (it luffs about x).
	_boom = Node3D.new()
	_slew.add_child(_boom)
	_boom.position = Vector3(0, PIVOT.y - 2.1, 0)
	var sections := [[1.3, 0.0, 15.0], [1.0, 14.0, 15.0], [0.75, 28.0, 14.0]]
	for s: Array in sections:
		_boom_parts.append(_box(_boom, Vector3(float(s[0]), float(s[0]) * 1.2, float(s[2])), Vector3(0, 0, -float(s[1]) - float(s[2]) * 0.5), yellow))
	_box(_boom, Vector3(0.9, 0.9, 0.9), Vector3(0, 0, -BOOM + 0.4), dark)   # the sheave head
	_cyl(_boom, 0.35, 0.6, Vector3(0, -2.0, -6.0), steel, Basis(Vector3.RIGHT, -0.9))   # the luffing ram
	_hook = MeshInstance3D.new()
	_hook.mesh = PartShapes.box(Vector3(0.7, 1.0, 0.5)).mesh
	_hook.material_override = yellow
	add_child(_hook)
	_rope = _box(self, Vector3(0.08, 1.0, 0.08), Vector3.ZERO, rope)
	_rope.top_level = true
	_hook.top_level = true
	for i in 4:
		var s := _box(self, Vector3(0.06, 1.0, 0.06), Vector3.ZERO, rope)
		s.top_level = true
		s.visible = false
		_slings.append(s)


func _used() -> void:
	if not busy and on_use.is_valid():
		on_use.call()
