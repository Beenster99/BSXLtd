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
##
## Three sizes (SIZES), by the hulls the yard takes in: "s" for small ships like the Kestrel
## (the constants below), "m" for medium ships (40 to 400 t, to 30 m) and "l" for large ones
## (400 to 3,000 t, to 80 m). Every size keeps the dolly's four pins in the same places, so
## the one dolly lifts any of them.

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

## The sizes: side beams at +-side_x, length long and side_h deep; cross beams at cross_z,
## cross_h deep, with saddles at saddle_x whose tops are saddle_top up; pedestals at
## pedestal_z under each side beam. Metres.
const SIZES := {
	"s": {"name": "SMALL", "side_x": SIDE_X, "length": LENGTH, "side_h": SIDE_H, "cross_h": CROSS_H, "cross_z": CROSS_Z,
			"saddle_top": SADDLE_TOP, "saddle_x": [-1.4, 1.4], "pedestal_z": PEDESTAL_Z},
	"m": {"name": "MEDIUM", "side_x": 8.0, "length": 30.0, "side_h": 0.9, "cross_h": 0.6,
			"cross_z": [-13.0, -8.8, -4.6, 3.0, 7.8, 12.6], "saddle_top": 1.3, "saddle_x": [-4.6, -1.6, 1.6, 4.6],
			"pedestal_z": [-12.0, 0.0, 12.0]},
	"l": {"name": "LARGE", "side_x": 9.0, "length": 78.0, "side_h": 1.3, "cross_h": 0.8,
			"cross_z": [-36.0, -28.0, -20.0, -12.0, -4.6, 3.0, 12.0, 20.0, 28.0, 36.0], "saddle_top": 1.9,
			"saddle_x": [-6.0, -2.4, 2.4, 6.0], "pedestal_z": [-36.0, -24.0, -12.0, 0.0, 12.0, 24.0, 36.0]},
}

## This cradle's size (SIZES) and its measures.
var size := "s"
var side_x := SIDE_X
var length := LENGTH
var saddle_top := SADDLE_TOP
var pedestal_z: Array = PEDESTAL_Z
## Engaged (true) or drawn (false), one per PINS.
var pins: Array[bool] = [false, false, false, false]
## The hull in it, or null, and what it weighs, tonnes.
var load_node: Node3D
var load_t := 0.0
## The pin levers on the side beams' outer faces, one per pin: F on one throws it (the yard's
## Transporters sets their "ship_bay_use").
var levers: Array[CollisionShape3D] = []
var _pin_meshes: Array[MeshInstance3D] = []
var _handles: Array[MeshInstance3D] = []
var _in_mat: Material
var _out_mat: Material


func _init(size_id := "s") -> void:
	sync_to_physics = false
	size = size_id if SIZES.has(size_id) else "s"
	var spec: Dictionary = SIZES[size]
	side_x = spec.side_x
	length = spec.length
	saddle_top = spec.saddle_top
	pedestal_z = spec.pedestal_z
	var side_h: float = spec.side_h
	var cross_h: float = spec.cross_h
	var yellow := ShipSurface.of(ShipKit.paint(Color(0.95, 0.75, 0.1), 0.15, 0.5, "hazard_paint"))
	var dark := ShipSurface.of(ShipKit.paint(Color(0.15, 0.16, 0.18), 0.5, 0.5, "gunmetal"))
	var steel := ShipSurface.of(ShipKit.paint(Color(0.55, 0.57, 0.6), 0.85, 0.3, "chrome"))
	var rubber := ShipSurface.of(ShipKit.paint(Color(0.07, 0.07, 0.075), 0.0, 0.9, "rubber"))
	var along_z := Basis(Vector3.UP, PI * 0.5)
	var flange := 0.4 if size == "s" else (0.6 if size == "m" else 0.8)
	for side: float in [-1.0, 1.0]:
		_part(PartShapes.i_beam(length, flange, side_h, 0.04), Transform3D(along_z, Vector3(side * side_x, side_h * 0.5, 0)), yellow)
		_solid(Vector3(flange, side_h, length), Vector3(side * side_x, side_h * 0.5, 0))
		# Lifting eyes on the beam ends, for the cranes.
		for end: float in [-1.0, 1.0]:
			_part(PartShapes.ring(0.08, 0.16, 0.05, 12), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(side * (side_x + flange * 0.5 + 0.025), side_h * 0.5, end * (length * 0.5 - 0.6))), steel)
	var cross_len := side_x * 2.0 - flange - 0.02
	for z: float in spec.cross_z:
		_part(PartShapes.i_beam(cross_len, 0.4, cross_h, 0.04), Transform3D(Basis(), Vector3(0, cross_h * 0.5, z)), yellow)
		_solid(Vector3(cross_len, cross_h, 0.4), Vector3(0, cross_h * 0.5, z))
		# Saddles along each beam, a steel block with a rubber pad on top; the outer ones
		# stand a little higher, so the belly sits in a shallow V.
		for x: float in spec.saddle_x:
			var top := saddle_top + (0.0 if absf(x) < side_x * 0.5 else (side_x * 0.04))
			var block := top - cross_h - 0.1
			_part(PartShapes.chamfer_box(Vector3(1.4, block, 0.5), 0.04), Transform3D(Basis(), Vector3(x, cross_h + block * 0.5, z)), dark)
			_part(PartShapes.chamfer_box(Vector3(1.5, 0.1, 0.6), 0.03), Transform3D(Basis(), Vector3(x, top - 0.05, z)), rubber)
			_solid(Vector3(1.5, top - cross_h, 0.6), Vector3(x, (cross_h + top) * 0.5, z))
	if size != "s":
		# Its size stencilled on the side beams' outer faces.
		for side: float in [-1.0, 1.0]:
			var tag := Label3D.new()
			tag.text = "%s CRADLE" % spec.name
			tag.font_size = 96
			tag.pixel_size = side_h * 0.5 / 96.0
			tag.modulate = Color(0.1, 0.1, 0.1)
			tag.shaded = true
			tag.double_sided = false
			tag.position = Vector3(side * (side_x + flange * 0.5 + 0.012), side_h * 0.5, length * 0.25)
			tag.rotation.y = side * PI * 0.5
			add_child(tag)
	# The pins: a housing on the beam's web with the pin hanging under the bottom flange.
	for p: Vector3 in PINS:
		_part(PartShapes.chamfer_box(Vector3(0.36, 0.3, 0.5), 0.03), Transform3D(Basis(), p + Vector3(0, 0.17, 0)), dark)
		var pin := _part(WreckParts.pipe(0.07, 0.22, false), Transform3D(Basis(), p), steel)
		_pin_meshes.append(pin)
	# Each pin's lever on the side beam's outer face beside it: a dark box with a handle that
	# shows green when the pin is in, red when it is drawn.
	_in_mat = ShipKit.glow(Color(0.3, 1.0, 0.45), 2.0)
	_out_mat = ShipKit.glow(Color(1.0, 0.25, 0.15), 2.0)
	for p: Vector3 in PINS:
		var out := signf(p.x) * (side_x + flange * 0.5)
		var at := Vector3(out + signf(p.x) * 0.08, side_h * 0.5, p.z)
		_part(PartShapes.chamfer_box(Vector3(0.16, 0.36, 0.3), 0.02), Transform3D(Basis(), at), dark)
		_handles.append(_part(PartShapes.box(Vector3(0.06, 0.08, 0.22)), Transform3D(Basis(), at + Vector3(signf(p.x) * 0.11, 0.08, 0)), _out_mat))
		var lever := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.3, 0.4, 0.4)
		lever.shape = box
		lever.position = at + Vector3(signf(p.x) * 0.07, 0, 0)
		add_child(lever)
		levers.append(lever)
	show_pins()


## Engages or draws pin `i`.
func set_pin(i: int, engaged: bool) -> void:
	pins[i] = engaged
	show_pins()


func all_pins_engaged() -> bool:
	return not pins.has(false)


## Where its pedestals should be under it (world space, on their tops).
func pedestal_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for x: float in [-side_x, side_x]:
		for z: float in pedestal_z:
			out.append(global_transform * Vector3(x, 0, z))
	return out


## Sets a hull in the saddles: `node`'s origin `offset` from the cradle's (its belly on the
## saddles). The hull rides with the cradle from then on.
func carry(node: Node3D, offset: Vector3) -> void:
	load_node = node
	add_child(node)
	node.position = offset


## Draws the pins (they hang 0.12 m lower when engaged, down in the deck's sockets) and
## their levers.
func show_pins() -> void:
	for i in _pin_meshes.size():
		_pin_meshes[i].position.y = PINS[i].y - (0.12 if pins[i] else 0.0)
		_handles[i].material_override = _in_mat if pins[i] else _out_mat
		_handles[i].rotation.x = 0.0 if pins[i] else 0.6


func engaged_count() -> int:
	return pins.count(true)


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
