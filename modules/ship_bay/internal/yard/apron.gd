extends Node3D
## The apron and the scrap end (S2 of the scrapyard plan, flag "ship_bay.apron"): a wide flat
## concrete apron south of the courtyard with the landing pad in its middle, Docks 2 and 3
## marked out either side of it (flat, no walls: beenster's call), the holding lane of three
## cradle bays along its east edge. (Scrap goes to the crusher house east of Pre-assembly.)
##
## Built by the shipyard before it draws (it hands itself to build()), from the yard's own
## parts and paints, so it batches with the rest. The transport cradles are their own bodies
## (TransportCradle): one stands empty on the pad, one waits in each holding bay. (The test
## Kestrel that sat on the pad is gone: beenster, 0.3.15.) Yard space, north -Z.

const Cradle := preload("res://modules/ship_bay/internal/yard/transport_cradle.gd")

## The apron's concrete (x, z), metres: from the courtyard's front strip south and east.
const AREA := Rect2(-125, 35, 300, 115)
## The landing pad's centre and radius, metres.
const PAD := Vector3(0, 0, 90)
const PAD_RADIUS := 30.0
## Docks 2 and 3, marked flat on the apron (x, z), metres: each takes one hull to 80 m.
const DOCKS := {"2": Rect2(-115, 44, 50, 96), "3": Rect2(65, 44, 50, 96)}
## Where the crawler's pedestals stand in a dock: pairs either side of its centre line at
## these offsets along it, metres.
const DOCK_PEDESTAL_X := 9.0
const DOCK_PEDESTAL_Z: Array[float] = [-36.0, -24.0, -12.0, 0.0, 12.0, 24.0, 36.0]
## The holding lane's bays along the apron's east edge (x, z), metres: one cradle each, of
## these sizes (TransportCradle.SIZES).
const HOLDING: Array[Rect2] = [Rect2(137, 42, 36, 32), Rect2(137, 78, 36, 32), Rect2(137, 114, 36, 32)]
const HOLDING_SIZES: PackedStringArray = ["s", "m", "m"]
## The holding cradles' heading: their ends face west (the apron) and east, radians.
const HOLDING_YAW := -PI * 0.5
## The docks that start with a large cradle on their pedestals.
const DOCK_CRADLES: PackedStringArray = ["3"]
## The pad's cradle (empty).
var pad_cradle: Node3D
## The holding lane's cradles, H1 to H3 (one small, two medium: HOLDING_SIZES).
var holding_cradles: Array[Node3D] = []
## Large cradles standing ready on the docks' pedestal rows (DOCK_CRADLES).
var dock_cradles: Array[Node3D] = []

var y: Node3D   # the shipyard


## Builds everything into `yard` (before it flushes its batches).
func build(yard: Node3D) -> void:
	name = "Apron"
	y = yard
	_build_ground()
	_build_pad()
	_build_docks()
	_build_holding()
	_build_masts()


# --- The apron ----------------------------------------------------------------------------

func _build_ground() -> void:
	var concrete: Material = y.get("_concrete")
	y.call("_block", Vector3(AREA.get_center().x, -0.01, AREA.get_center().y), Vector3(AREA.size.x, 0.04, AREA.size.y), concrete, false)
	y.call("_slab_joints", AREA, 0.0)


## Paint `size` (x, z) at `at` on the apron: its top `lift` metres over the concrete's.
func _line(at: Vector2, size: Vector2, mat: Material, lift := 0.011) -> void:
	y.call("_put", y.call("_box", Vector3(size.x, 0.01, size.y)), Transform3D(Basis(), Vector3(at.x, 0.005 + lift, at.y)), mat, false)


## A rectangle of lines round `r`, `w` wide, and corner chevrons inside.
func _outline(r: Rect2, w: float, mat: Material) -> void:
	for z: float in [r.position.y, r.end.y]:
		_line(Vector2(r.get_center().x, z), Vector2(r.size.x + w, w), mat)
	for x: float in [r.position.x, r.end.x]:
		_line(Vector2(x, r.get_center().y), Vector2(w, r.size.y - w), mat, 0.0118)


## A word painted flat on the ground, reading from the south.
func _floor_text(text: String, at: Vector3, height_m: float, colour: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.pixel_size = height_m / 96.0
	label.modulate = colour
	label.outline_size = 0
	label.position = at + Vector3(0, 0.025, 0)
	label.rotation = Vector3(-PI * 0.5, 0, 0)
	add_child(label)


func _build_pad() -> void:
	var paint: Material = y.call("_paint", Color(0.95, 0.75, 0.1), 0.0, 0.7, "satin_paint")
	var white: Material = y.call("_paint", Color(0.9, 0.9, 0.88), 0.0, 0.8)
	var ring: String = y.call("_lib", "ring/pad_edge", func() -> PartShapes.PartShape:
			return PartShapes.ring(PAD_RADIUS - 0.8, PAD_RADIUS, 0.01, 96))
	y.call("_put", ring, Transform3D(Basis(), PAD + Vector3(0, 0.016, 0)), paint, false)
	var inner: String = y.call("_lib", "ring/pad_inner", func() -> PartShapes.PartShape:
			return PartShapes.ring(PAD_RADIUS * 0.62, PAD_RADIUS * 0.62 + 0.4, 0.01, 72))
	y.call("_put", inner, Transform3D(Basis(), PAD + Vector3(0, 0.016, 0)), white, false)
	_floor_text("PAD", PAD + Vector3(0, 0, PAD_RADIUS * 0.8), 4.0, Color(0.95, 0.75, 0.1))
	# Edge lights round the rim.
	var stud: String = y.call("_box", Vector3(0.3, 0.04, 0.3))
	var lit: Material = y.call("_glow_mat", Color(0.4, 0.86, 1.0), 3.0)
	for i in 36:
		var a := TAU * i / 36.0
		y.call("_put", stud, Transform3D(Basis(Vector3.UP, a), PAD + Vector3(sin(a), 0, cos(a)) * (PAD_RADIUS + 0.8) + Vector3(0, 0.02, 0)), lit, false)
	_pedestals(PAD, 0.0)
	pad_cradle = _cradle("PadCradle", PAD)


## Docks 2 and 3: flat bays marked on the apron in hazard yellow with the crawler's pedestal
## rows down their middle, tie-down rings and a power pedestal at each corner.
func _build_docks() -> void:
	var paint: Material = y.call("_paint", Color(0.95, 0.75, 0.1), 0.0, 0.7, "satin_paint")
	var hazard: Material = y.get("_hazard")
	var bare: Material = y.get("_bare")
	var ring: String = y.call("_lib", "ring/tie_down", func() -> PartShapes.PartShape:
			return PartShapes.ring(0.1, 0.17, 0.04))
	var pedestal: String = y.call("_lib", "switch_cabinet/pedestal", func() -> PartShapes.PartShape:
			return WreckParts.switch_cabinet(Vector3(0.7, 1.4, 0.4), Color(1.0, 0.6, 0.15)))
	var cabinet: Material = y.call("_paint", Color(0.34, 0.37, 0.4), 0.35, 0.5)
	for id: String in DOCKS:
		var r: Rect2 = DOCKS[id]
		_outline(r, 0.4, paint)
		var c := Vector3(r.get_center().x, 0, r.get_center().y)
		_floor_text("DOCK " + id, Vector3(c.x, 0, r.end.y - 5.0), 3.2, Color(0.95, 0.75, 0.1))
		for z: float in DOCK_PEDESTAL_Z:
			for side: float in [-1.0, 1.0]:
				_pedestal(c + Vector3(side * DOCK_PEDESTAL_X, 0, z))
		if DOCK_CRADLES.has(id):
			dock_cradles.append(_cradle("DockCradle" + id, c, "l"))
		for x: float in [r.position.x + 4.0, r.end.x - 4.0]:
			for k in 5:
				y.call("_put", ring, Transform3D(Basis(), Vector3(x, 0.02, r.position.y + 12.0 + k * 18.0)), bare, false)
		for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			var inward := Vector2(signf(r.get_center().x - corner.x), signf(r.get_center().y - corner.y))
			var p := corner + inward * 1.6
			y.call("_put", pedestal, Transform3D(Basis(Vector3.UP, 0.0 if inward.y < 0.0 else PI), Vector3(p.x, 0.7, p.y)), cabinet)
			y.call("_put", y.call("_box", Vector3(1.0, 0.1, 0.7)), Transform3D(Basis(), Vector3(p.x, 0.05, p.y)), hazard, false)


## The holding lane: three bays outlined in white along the apron's east edge, each with a
## cradle on its pedestals waiting for a hull. The cradles lie east-west (HOLDING_YAW), so a
## transporter drives in under one from the open apron to the west; lying north-south, the
## bays either side left the 30 m crawler no room to line up.
func _build_holding() -> void:
	var white: Material = y.call("_paint", Color(0.9, 0.9, 0.88), 0.0, 0.8)
	for i in HOLDING.size():
		var r := HOLDING[i]
		_outline(r, 0.25, white)
		var c := Vector3(r.get_center().x, 0, r.get_center().y)
		_floor_text("H%d" % (i + 1), c + Vector3(-r.size.x * 0.5 + 3.0, 0, r.size.y * 0.5 - 3.0), 2.4, Color(0.9, 0.9, 0.88))
		_pedestals(c, HOLDING_YAW, HOLDING_SIZES[i])
		holding_cradles.append(_cradle("HoldingCradle%d" % (i + 1), c, HOLDING_SIZES[i], HOLDING_YAW))
	_floor_text("HOLDING", Vector3(HOLDING[0].get_center().x, 0, HOLDING[0].position.y - 3.0), 3.0, Color(0.9, 0.9, 0.88))


## A steel pedestal: a box stand on a base plate, its top `Cradle.REST` over the ground.
func _pedestal(at: Vector3) -> void:
	var stand: String = y.call("_lib", "cbox/pedestal", func() -> PartShapes.PartShape:
			return PartShapes.chamfer_box(Vector3(0.9, Cradle.REST - 0.06, 0.9), 0.05))
	y.call("_put", stand, Transform3D(Basis(), at + Vector3(0, 0.06 + (Cradle.REST - 0.06) * 0.5, 0)), y.get("_frame"))
	y.call("_put", y.call("_box", Vector3(1.3, 0.05, 1.3)), Transform3D(Basis(), at + Vector3(0, 0.035, 0)), y.get("_bare"), false)


## The pedestals a transport cradle of `size` centred at `at` stands on.
func _pedestals(at: Vector3, yaw: float, size := "s") -> void:
	var spec: Dictionary = Cradle.SIZES[size]
	for side: float in [-1.0, 1.0]:
		for z: float in spec.pedestal_z:
			_pedestal(at + Basis(Vector3.UP, yaw) * Vector3(side * float(spec.side_x), 0, z))


func _cradle(node_name: String, at: Vector3, size := "s", yaw := 0.0) -> Node3D:
	var c := Cradle.new(size)
	c.name = node_name
	add_child(c)
	c.global_transform = Transform3D(Basis(Vector3.UP, yaw), at + Vector3(0, Cradle.REST, 0))
	return c


## Floodlight masts over Docks 2 and 3 and the holding lane, like the apron's.
func _build_masts() -> void:
	var lattice: String = y.call("_lib", "truss/mast", func() -> PartShapes.PartShape:
			return PartShapes.truss(15.0, 0.6, 0.6, 10, 0.06))
	var head: String = y.call("_lib", "headlamp/flood", func() -> PartShapes.PartShape:
			return WreckParts.headlamp_bar(2.4, 4, Color(1.0, 0.93, 0.82)))
	var platform: String = y.call("_lib", "grating/mast", func() -> PartShapes.PartShape:
			return WreckParts.grating(1.6, 1.6))
	var galv: Material = y.get("_galv")
	var concrete: Material = y.get("_concrete")
	for mast: Array in [[Vector3(-122, 0, 92), Vector3(-90, 0, 92)], [Vector3(122, 0, 60), Vector3(90, 0, 92)],
			[Vector3(180, 0, 94), Vector3(155, 0, 94)], [Vector3(0, 0, 146), Vector3(0, 0, 100)]]:
		var foot: Vector3 = mast[0]
		y.call("_put", lattice, Transform3D(Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)), foot + Vector3(0, 7.5, 0)), galv)
		y.call("_put", y.call("_box", Vector3(1.4, 0.4, 1.4)), Transform3D(Basis(), foot + Vector3(0, 0.2, 0)), concrete)
		y.call("_put", platform, Transform3D(Basis(), foot + Vector3(0, 15.0, 0)), galv, false)
		var target: Vector3 = mast[1]
		var to := Vector3(target.x - foot.x, 0, target.z - foot.z).normalized()
		y.call("_floodlight", head, foot + Vector3(0, 15.6, 0) + to * 0.3, target)


# --- The cutting bay ----------------------------------------------------------------------
