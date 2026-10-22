extends AnimatableBody3D
## A transport cradle: the steel frame a hull rides in between the pad, the docks and the
## holding lane. Two side beams stand on four pedestals (the place's, not the cradle's); three
## cross beams between them carry rubber-padded saddles under the hull's belly. The dolly
## drives in under the cross beams, and four pins on their undersides drop into sockets on
## its deck; with every pin engaged it may lift the cradle (and the hull in it) off the
## pedestals. The pins are the cradle's state: `pins` (engaged or not, per pin).
##
## Cradle space: origin under the frame's middle at the beams' underside (on the pedestals'
## tops), -Z the hull's nose.

## The beams' underside over the ground while it stands on its pedestals, metres.
const REST := 1.6
## The frame: side beams along Z at x = +-SIDE_X, LENGTH long; cross beams at CROSS_Z.
const SIDE_X := 4.2
const LENGTH := 14.0
const CROSS_Z: Array[float] = [-4.6, 0.3, 3.0]
## Beam depths, metres: the side beams and the cross beams (the dolly's deck meets these).
const SIDE_H := 0.6
const CROSS_H := 0.5
## The saddles' tops over the cradle's origin, metres: a hull's belly sits here.
const SADDLE_TOP := 0.9
## Where the pedestals stand under the side beams (z), metres.
const PEDESTAL_Z: Array[float] = [-5.8, 5.8]
## The pins under the outer cross beams, cradle space (they meet the dolly's deck sockets).
const PINS: Array[Vector3] = [Vector3(-2.2, 0, -4.6), Vector3(2.2, 0, -4.6), Vector3(-2.2, 0, 3.0), Vector3(2.2, 0, 3.0)]

## Engaged (true) or drawn (false), one per PINS.
var pins: Array[bool] = [false, false, false, false]
## The hull in it, or null.
var load_node: Node3D
var _pin_meshes: Array[MeshInstance3D] = []


func _init() -> void:
	sync_to_physics = false
	var yellow := ShipSurface.of(ShipKit.paint(Color(0.95, 0.75, 0.1), 0.15, 0.5, "hazard_paint"))
	var dark := ShipSurface.of(ShipKit.paint(Color(0.15, 0.16, 0.18), 0.5, 0.5, "gunmetal"))
	var steel := ShipSurface.of(ShipKit.paint(Color(0.55, 0.57, 0.6), 0.85, 0.3, "chrome"))
	var rubber := ShipSurface.of(ShipKit.paint(Color(0.07, 0.07, 0.075), 0.0, 0.9, "rubber"))
	var along_z := Basis(Vector3.UP, PI * 0.5)
	for side: float in [-1.0, 1.0]:
		_part(PartShapes.i_beam(LENGTH, 0.4, SIDE_H, 0.04), Transform3D(along_z, Vector3(side * SIDE_X, SIDE_H * 0.5, 0)), yellow)
		_solid(Vector3(0.4, SIDE_H, LENGTH), Vector3(side * SIDE_X, SIDE_H * 0.5, 0))
		# Lifting eyes on the beam ends, for the cranes.
		for end: float in [-1.0, 1.0]:
			_part(PartShapes.ring(0.08, 0.16, 0.05, 12), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(side * (SIDE_X + 0.225), SIDE_H * 0.5, end * (LENGTH * 0.5 - 0.6))), steel)
	var cross_len := SIDE_X * 2.0 - 0.42
	for z: float in CROSS_Z:
		_part(PartShapes.i_beam(cross_len, 0.4, CROSS_H, 0.04), Transform3D(Basis(), Vector3(0, CROSS_H * 0.5, z)), yellow)
		_solid(Vector3(cross_len, CROSS_H, 0.4), Vector3(0, CROSS_H * 0.5, z))
		# Two saddles per beam, a steel block with a rubber pad on top.
		for x: float in [-1.4, 1.4]:
			var block := SADDLE_TOP - CROSS_H - 0.1
			_part(PartShapes.chamfer_box(Vector3(1.4, block, 0.5), 0.04), Transform3D(Basis(), Vector3(x, CROSS_H + block * 0.5, z)), dark)
			_part(PartShapes.chamfer_box(Vector3(1.5, 0.1, 0.6), 0.03), Transform3D(Basis(), Vector3(x, SADDLE_TOP - 0.05, z)), rubber)
			_solid(Vector3(1.5, SADDLE_TOP - CROSS_H, 0.6), Vector3(x, (CROSS_H + SADDLE_TOP) * 0.5, z))
	# The pins: a housing on the beam's web with the pin hanging under the bottom flange.
	for p: Vector3 in PINS:
		_part(PartShapes.chamfer_box(Vector3(0.36, 0.3, 0.5), 0.03), Transform3D(Basis(), p + Vector3(0, 0.17, 0)), dark)
		var pin := _part(WreckParts.pipe(0.07, 0.22, false), Transform3D(Basis(), p), steel)
		_pin_meshes.append(pin)
	_show_pins()


## Engages or draws pin `i`.
func set_pin(i: int, engaged: bool) -> void:
	pins[i] = engaged
	_show_pins()


func all_pins_engaged() -> bool:
	return not pins.has(false)


## Sets a hull in the saddles: `node`'s origin `offset` from the cradle's (its belly on the
## saddles). The hull rides with the cradle from then on.
func carry(node: Node3D, offset: Vector3) -> void:
	load_node = node
	add_child(node)
	node.position = offset


## Pins hang 0.12 m lower when engaged (down in the deck's sockets).
func _show_pins() -> void:
	for i in _pin_meshes.size():
		_pin_meshes[i].position.y = PINS[i].y - (0.12 if pins[i] else 0.0)


func _part(shape: PartShapes.PartShape, xform: Transform3D, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = shape.mesh
	mi.material_override = mat
	mi.transform = xform
	add_child(mi)
	return mi


func _solid(size: Vector3, at: Vector3) -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = at
	add_child(col)
