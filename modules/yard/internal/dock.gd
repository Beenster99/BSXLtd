extends Node3D
## The weightless dock outside the station's windows (stage 1.2): one build berth in front
## of the design room and a holding berth either side, open lattice frames lit by
## floodlights, joined by a dock arm that runs back to the station. Ships are built in the
## berths from Wave 5; for now they stand empty. Where they are: YardLayout.BERTHS.

const Kit := preload("res://modules/yard/internal/yard_kit.gd")
const Solar := preload("res://modules/yard/internal/solar_array.gd")

## Floodlight brightness and reach.
@export var flood_energy := 6.0
@export var flood_range := 70.0
## How often the berths' marker lamps blink (s).
@export var blink_period := 1.6

var kit
var berth_nodes: Dictionary = {}
var _blinkers: Array[MeshInstance3D] = []
## Every floodlight: {berth, pan (Node3D, turns about y), tilt (Node3D, turns about its x),
## spot, aim (where it is turning to, station space)}.
var floods: Array[Dictionary] = []
## How fast the floods turn to a new aim (rad/s).
@export var flood_turn_speed := 0.6
var _time := 0.0


func build() -> void:
	kit = Kit.new(self, "DockBody")
	for b: Dictionary in YardLayout.BERTHS:
		_berth(b)
	_dock_arm()


func _process(delta: float) -> void:
	_time += delta
	for f: Dictionary in floods:
		_turn_flood(f, delta)
	var on := fmod(_time, blink_period) < blink_period * 0.3
	for b in _blinkers:
		b.visible = on


func _berth(b: Dictionary) -> void:
	var box: AABB = b.box
	var build_berth: bool = b.kind == "build"
	var node := Node3D.new()
	node.name = "Berth_" + str(b.id)
	add_child(node)
	berth_nodes[b.id] = node
	var white: Material = kit.paint(Kit.HULL, 0.2, 0.4, "gloss_paint")
	var orange: Material = kit.paint(Kit.ORANGE, 0.15, 0.4, "hazard_paint")
	var dark: Material = kit.paint(Kit.DARK, 0.7, 0.45, "gunmetal")
	var beam := 0.9 if build_berth else 0.7
	var lo := box.position
	var hi := box.end
	# The frame's edges: the long ones white, the end rings orange.
	for y: float in [lo.y, hi.y]:
		for z: float in [lo.z, hi.z]:
			kit.span(Vector3(lo.x, y - beam * 0.5, z - beam * 0.5), Vector3(hi.x, y + beam * 0.5, z + beam * 0.5), white)
	for x: float in [lo.x, hi.x]:
		for y: float in [lo.y, hi.y]:
			kit.span(Vector3(x - beam * 0.5, y - beam * 0.5, lo.z), Vector3(x + beam * 0.5, y + beam * 0.5, hi.z), orange)
		for z: float in [lo.z, hi.z]:
			kit.span(Vector3(x - beam * 0.5, lo.y, z - beam * 0.5), Vector3(x + beam * 0.5, hi.y, z + beam * 0.5), orange)
	# Ribs along the berth, with clamp arms reaching in to hold a hull.
	var ribs := int(box.size.x / 10.0)
	for i in range(1, ribs):
		var x := lo.x + box.size.x * float(i) / float(ribs)
		for z: float in [lo.z, hi.z]:
			kit.span(Vector3(x - 0.3, lo.y, z - 0.3), Vector3(x + 0.3, hi.y, z + 0.3), dark)
			var inward := 1.0 if z == lo.z else -1.0
			for y: float in [lo.y + box.size.y * 0.3, lo.y + box.size.y * 0.7]:
				kit.box(Vector3(0.4, 0.4, 3.0), Vector3(x, y, z + inward * 1.7), orange)
				kit.box(Vector3(1.0, 1.0, 0.3), Vector3(x, y, z + inward * 3.3), dark)
		for y: float in [lo.y, hi.y]:
			kit.span(Vector3(x - 0.3, y - 0.3, lo.z), Vector3(x + 0.3, y + 0.3, hi.z), dark)
	# The berth's name, big, on its station-side face and over its top.
	var name_at := Vector3(box.get_center().x, hi.y + 2.6, hi.z)
	var label: Label3D = kit.sign(str(b.name), name_at, Vector3.BACK, 0.08 if build_berth else 0.06, Kit.ORANGE, 128)
	label.shaded = false
	kit.box(Vector3(0.6, 2.2, 0.6), Vector3(name_at.x, hi.y + 1.1, hi.z), dark)
	# Floodlights on all eight corners (0.4.1 playtest: "movable flood lights on all corners not
	# just top"), each on a pan and tilt yoke, aimed at the berth's middle.
	var centre := box.get_center()
	for x: float in [lo.x, hi.x]:
		for y: float in [lo.y, hi.y]:
			for z: float in [lo.z, hi.z]:
				var at := Vector3(x, y + (1.6 if y == hi.y else -1.6), z)
				_flood(node, at, centre, build_berth, dark)
	# Blinking marker lamps on the bottom corners.
	for x: float in [lo.x, hi.x]:
		for z: float in [lo.z, hi.z]:
			var colour := Color(0.2, 1.0, 0.3) if x == hi.x else Color(1.0, 0.2, 0.15)
			var lamp: MeshInstance3D = kit.box(Vector3(0.6, 0.6, 0.6), Vector3(x, lo.y - 0.8, z), kit.glow(colour, 8.0), false)
			_blinkers.append(lamp)


## A truss along the berths' station side, and two arms back to the station's underside.
func _dock_arm() -> void:
	var white: Material = kit.paint(Kit.HULL, 0.2, 0.4, "gloss_paint")
	var dark: Material = kit.paint(Kit.DARK, 0.7, 0.45, "galvanised")
	var z := -66.0
	var y := -16.0
	_truss(Vector3(-100, y, z), Vector3(100, y, z), white, dark)
	_truss(Vector3(-6.0, y, z), Vector3(-6.0, -1.2, -21.0), white, dark)
	_truss(Vector3(30.0, y, z), Vector3(30.0, -1.2, -29.0), white, dark)
	# Solar wings off both ends of the arm, up and down, turned to the sun.
	var sun_h := Vector3(0.55, 0.0, -0.35).normalized()
	var face := Basis(sun_h.cross(Vector3.UP), sun_h, Vector3.UP)
	for x: float in [-106.0, 106.0]:
		_truss(Vector3(x - signf(x) * 5.0, y, z), Vector3(x, y, z), white, dark)
		kit.box(Vector3(0.5, 76.0, 0.5), Vector3(x, y, z), dark, false)
		for up: float in [-1.0, 1.0]:
			Solar.build(self, "ArmSolar_%d_%d" % [int(x), int(up)], Vector3(x, y + up * 20.5, z), face, 4, 11)
	# Walkway lamps along the arm, so you can find your way out in the dark.
	for i in range(-9, 10):
		kit.box(Vector3(0.25, 0.25, 0.25), Vector3(i * 10.0, y + 1.3, z), kit.glow(Color(0.4, 0.8, 1.0), 5.0), false)


## A square truss of four chords from `a` to `b` with rungs every 3 m.
func _truss(a: Vector3, b: Vector3, chord_mat: Material, rung_mat: Material) -> void:
	var holder := Node3D.new()
	add_child(holder)
	var length := a.distance_to(b)
	var mid := (a + b) * 0.5
	holder.position = mid
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	holder.basis = Basis.looking_at(dir, up)
	for sx: float in [-0.7, 0.7]:
		for sy: float in [-0.7, 0.7]:
			kit.box(Vector3(0.25, 0.25, length), Vector3(sx, sy, 0), chord_mat, true, holder)
	var n := int(length / 3.0)
	for i in n + 1:
		var zz := -length * 0.5 + length * float(i) / float(maxi(n, 1))
		kit.box(Vector3(1.6, 0.12, 0.12), Vector3(0, 0.7, zz), rung_mat, false, holder)
		kit.box(Vector3(1.6, 0.12, 0.12), Vector3(0, -0.7, zz), rung_mat, false, holder)
		kit.box(Vector3(0.12, 1.6, 0.12), Vector3(0.7, 0, zz), rung_mat, false, holder)
		kit.box(Vector3(0.12, 1.6, 0.12), Vector3(-0.7, 0, zz), rung_mat, false, holder)


## Points a berth's floodlights at `target` (station space; they turn there at
## flood_turn_speed), or back at the berth's middle with Vector3.INF.
func aim_floods(berth_id: String, target := Vector3.INF) -> void:
	for f: Dictionary in floods:
		if f.berth == berth_id:
			f.aim = f.home if target == Vector3.INF else target


## A floodlight: a bracket on the frame, a yoke that pans, a head that tilts, its lens lit and
## its spot inside it.
func _flood(berth: Node3D, at: Vector3, target: Vector3, build_berth: bool, dark: Material) -> void:
	var grey: Material = kit.paint(Color(0.3, 0.32, 0.35), 0.6, 0.4, "gunmetal")
	var down := at.y < target.y
	var mount := Node3D.new()
	mount.name = "Flood"
	mount.position = at
	berth.add_child(mount)
	_piece(mount, Vector3(1.4, 0.3, 1.4), Vector3(0, -0.85 if not down else 0.85, 0), dark)
	_piece(mount, Vector3(0.3, 0.6, 0.3), Vector3(0, -0.55 if not down else 0.55, 0), grey)
	var pan := Node3D.new()
	pan.name = "Pan"
	mount.add_child(pan)
	for sx: float in [-0.75, 0.75]:
		_piece(pan, Vector3(0.12, 1.0, 0.3), Vector3(sx, 0, 0), grey)
	_piece(pan, Vector3(1.4, 0.14, 0.26), Vector3(0, -0.5 if not down else 0.5, 0), grey)
	var tilt := Node3D.new()
	tilt.name = "Tilt"
	pan.add_child(tilt)
	_piece(tilt, Vector3(1.3, 0.9, 0.7), Vector3(0, 0, 0.1), dark)
	_piece(tilt, Vector3(1.4, 1.0, 0.12), Vector3(0, 0, -0.3), grey)
	_piece(tilt, Vector3(1.16, 0.76, 0.04), Vector3(0, 0, -0.37), kit.glow(Kit.LAMP, 4.0))
	for fy: float in [-0.3, -0.1, 0.1, 0.3]:   # cooling fins on its back
		_piece(tilt, Vector3(1.2, 0.04, 0.3), Vector3(0, fy, 0.58), grey)
	var spot := SpotLight3D.new()
	spot.light_energy = flood_energy * 0.7
	spot.spot_range = flood_range if build_berth else flood_range * 0.8
	spot.spot_angle = 36.0
	spot.light_color = Color(1.0, 0.96, 0.88)
	spot.shadow_enabled = false
	spot.position = Vector3(0, 0, -0.45)
	tilt.add_child(spot)
	var f := {"berth": String(berth.name).trim_prefix("Berth_"), "pan": pan, "tilt": tilt, "spot": spot, "home": target, "aim": target}
	floods.append(f)
	_turn_flood(f, 1000.0)


## Turns a flood towards its aim, pan about y and tilt about x, by at most flood_turn_speed.
func _turn_flood(f: Dictionary, delta: float) -> void:
	var pan: Node3D = f.pan
	var tilt: Node3D = f.tilt
	if not pan.is_inside_tree():
		return
	var to: Vector3 = f.aim - pan.global_position
	if to.length() < 0.01:
		return
	var want_yaw := atan2(-to.x, -to.z)
	var want_pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var step := flood_turn_speed * delta
	pan.rotation.y = rotate_toward(pan.rotation.y, want_yaw, step)
	tilt.rotation.x = rotate_toward(tilt.rotation.x, want_pitch, step)


func _piece(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi
