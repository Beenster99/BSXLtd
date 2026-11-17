extends Node3D
## The weightless dock outside the station's windows (stage 1.2): one build berth in front
## of the design room and a holding berth either side, open lattice frames lit by
## floodlights, joined by a dock arm that runs back to the station. Ships are built in the
## berths from Wave 5; for now they stand empty. Where they are: YardLayout.BERTHS.

const Kit := preload("res://modules/yard/internal/yard_kit.gd")

## Floodlight brightness and reach.
@export var flood_energy := 6.0
@export var flood_range := 70.0
## How often the berths' marker lamps blink (s).
@export var blink_period := 1.6

var kit
var berth_nodes: Dictionary = {}
var _blinkers: Array[MeshInstance3D] = []
var _time := 0.0


func build() -> void:
	kit = Kit.new(self, "DockBody")
	for b: Dictionary in YardLayout.BERTHS:
		_berth(b)
	_dock_arm()


func _process(delta: float) -> void:
	_time += delta
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
	var white: Material = kit.paint(Kit.HULL, 0.2, 0.5)
	var orange: Material = kit.paint(Kit.ORANGE, 0.15, 0.45)
	var dark: Material = kit.paint(Kit.DARK, 0.5, 0.45)
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
	# Floodlights on the top corners, aimed at the berth's middle.
	var centre := box.get_center()
	for x: float in [lo.x, hi.x]:
		for z: float in [lo.z, hi.z]:
			var at := Vector3(x, hi.y + 1.5, z)
			kit.box(Vector3(1.2, 0.8, 1.2), at, kit.glow(Kit.LAMP, 4.0), false)
			var spot := SpotLight3D.new()
			spot.light_energy = flood_energy
			spot.spot_range = flood_range if build_berth else flood_range * 0.8
			spot.spot_angle = 40.0
			spot.light_color = Color(1.0, 0.96, 0.88)
			spot.shadow_enabled = false
			add_child(spot)
			spot.look_at_from_position(at, centre, Vector3.UP)
	# Blinking marker lamps on the bottom corners.
	for x: float in [lo.x, hi.x]:
		for z: float in [lo.z, hi.z]:
			var colour := Color(0.2, 1.0, 0.3) if x == hi.x else Color(1.0, 0.2, 0.15)
			var lamp: MeshInstance3D = kit.box(Vector3(0.6, 0.6, 0.6), Vector3(x, lo.y - 0.8, z), kit.glow(colour, 8.0), false)
			_blinkers.append(lamp)


## A truss along the berths' station side, and two arms back to the station's underside.
func _dock_arm() -> void:
	var white: Material = kit.paint(Kit.HULL, 0.2, 0.5)
	var dark: Material = kit.paint(Kit.DARK, 0.5, 0.45)
	var z := -66.0
	var y := -16.0
	_truss(Vector3(-100, y, z), Vector3(100, y, z), white, dark)
	_truss(Vector3(-6.0, y, z), Vector3(-6.0, -1.2, -21.0), white, dark)
	_truss(Vector3(30.0, y, z), Vector3(30.0, -1.2, -29.0), white, dark)
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
