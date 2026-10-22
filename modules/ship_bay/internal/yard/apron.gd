extends Node3D
## The apron and the scrap end (S2 of the scrapyard plan, flag "ship_bay.apron"): a wide flat
## concrete apron south of the courtyard with the landing pad in its middle, Docks 2 and 3
## marked out either side of it (flat, no walls: beenster's call), the holding lane of three
## cradle bays along its east edge, and west of the horseshoe, by Deliveries, the cutting bay
## (a roofed shed open to the road) with the scrap lane behind it (bale press, bales and
## ingot pallets, skips by material, a weighbridge).
##
## Built by the shipyard before it draws (it hands itself to build()), from the yard's own
## parts and paints, so it batches with the rest. The transport cradles are their own bodies
## (TransportCradle): one on the pad holds a test hulk (the Kestrel for now), one waits in
## each holding bay. Yard space, north -Z.

const Cradle := preload("res://modules/ship_bay/internal/yard/transport_cradle.gd")
const KESTREL := preload("res://modules/ship_bay/internal/ships/kestrel/kestrel.tscn")

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
## The holding lane's bays along the apron's east edge (x, z), metres: one cradle each.
const HOLDING: Array[Rect2] = [Rect2(130, 42, 36, 32), Rect2(130, 78, 36, 32), Rect2(130, 114, 36, 32)]
## The cutting bay's shed (x, z footprint) and eaves height, metres; its door is the south
## wall's middle, onto the road.
const CUTTING := Rect2(-110, 0, 30, 24)
const CUTTING_H := 12.0
const CUTTING_DOOR := Vector2(22.0, 10.0)   # width, height, metres
## The scrap lane behind the cutting bay (x, z), metres.
const SCRAP := Rect2(-110, -26, 30, 22)
## The test hulk's place in its cradle (cradle space): the Kestrel's belly on the saddles,
## its saddle stations where the bay's cradles hold it.
const HULK_OFFSET := Vector3(0, Cradle.SADDLE_TOP + 0.5, -1.2)
## Scrap metals and their bale colours.
const SCRAP_METALS := {"STEEL": Color(0.46, 0.47, 0.49), "ALLOY": Color(0.72, 0.74, 0.78),
		"COPPER": Color(0.72, 0.42, 0.24), "TITANIUM": Color(0.56, 0.58, 0.66)}

## The pad's cradle, with the hulk in it.
var pad_cradle: Node3D
## The holding lane's cradles, H1 to H3.
var holding_cradles: Array[Node3D] = []
## The test hulk on the pad.
var hulk: Node3D

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
	_build_cutting_bay()
	_build_scrap_lane()


# --- The apron ----------------------------------------------------------------------------

func _build_ground() -> void:
	var concrete: Material = y.get("_concrete")
	y.call("_block", Vector3(AREA.get_center().x, -0.01, AREA.get_center().y), Vector3(AREA.size.x, 0.04, AREA.size.y), concrete, false)
	y.call("_slab_joints", AREA, 0.0)
	# Concrete under the cutting bay and the scrap lane, out to the road.
	var west := Rect2(SCRAP.position.x - 2.0, SCRAP.position.y - 2.0, SCRAP.size.x + 4.0, 25.5 - (SCRAP.position.y - 2.0))
	y.call("_block", Vector3(west.get_center().x, -0.01, west.get_center().y), Vector3(west.size.x, 0.04, west.size.y), concrete, false)
	y.call("_slab_joints", west, 0.0)


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
	hulk = KESTREL.instantiate() as Node3D
	hulk.name = "Hulk"
	(pad_cradle as Cradle).carry(hulk, HULK_OFFSET)


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
		for x: float in [r.position.x + 4.0, r.end.x - 4.0]:
			for k in 5:
				y.call("_put", ring, Transform3D(Basis(), Vector3(x, 0.02, r.position.y + 12.0 + k * 18.0)), bare, false)
		for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			var inward := Vector2(signf(r.get_center().x - corner.x), signf(r.get_center().y - corner.y))
			var p := corner + inward * 1.6
			y.call("_put", pedestal, Transform3D(Basis(Vector3.UP, 0.0 if inward.y < 0.0 else PI), Vector3(p.x, 0.7, p.y)), cabinet)
			y.call("_put", y.call("_box", Vector3(1.0, 0.1, 0.7)), Transform3D(Basis(), Vector3(p.x, 0.05, p.y)), hazard, false)


## The holding lane: three bays outlined in white along the apron's east edge, each with a
## cradle on its pedestals waiting for a hull.
func _build_holding() -> void:
	var white: Material = y.call("_paint", Color(0.9, 0.9, 0.88), 0.0, 0.8)
	for i in HOLDING.size():
		var r := HOLDING[i]
		_outline(r, 0.25, white)
		var c := Vector3(r.get_center().x, 0, r.get_center().y)
		_floor_text("H%d" % (i + 1), c + Vector3(-r.size.x * 0.5 + 3.0, 0, r.size.y * 0.5 - 3.0), 2.4, Color(0.9, 0.9, 0.88))
		_pedestals(c, 0.0)
		holding_cradles.append(_cradle("HoldingCradle%d" % (i + 1), c))
	_floor_text("HOLDING", Vector3(HOLDING[0].get_center().x, 0, HOLDING[0].position.y - 3.0), 3.0, Color(0.9, 0.9, 0.88))


## A steel pedestal: a box stand on a base plate, its top `Cradle.REST` over the ground.
func _pedestal(at: Vector3) -> void:
	var stand: String = y.call("_lib", "cbox/pedestal", func() -> PartShapes.PartShape:
			return PartShapes.chamfer_box(Vector3(0.9, Cradle.REST - 0.06, 0.9), 0.05))
	y.call("_put", stand, Transform3D(Basis(), at + Vector3(0, 0.06 + (Cradle.REST - 0.06) * 0.5, 0)), y.get("_frame"))
	y.call("_put", y.call("_box", Vector3(1.3, 0.05, 1.3)), Transform3D(Basis(), at + Vector3(0, 0.035, 0)), y.get("_bare"), false)


## The four pedestals a transport cradle centred at `at` stands on.
func _pedestals(at: Vector3, yaw: float) -> void:
	for side: float in [-1.0, 1.0]:
		for z: float in Cradle.PEDESTAL_Z:
			_pedestal(at + Basis(Vector3.UP, yaw) * Vector3(side * Cradle.SIDE_X, 0, z))


func _cradle(node_name: String, at: Vector3) -> Node3D:
	var c := Cradle.new()
	c.name = node_name
	add_child(c)
	c.global_transform = Transform3D(Basis(), at + Vector3(0, Cradle.REST, 0))
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
			[Vector3(172, 0, 94), Vector3(148, 0, 94)], [Vector3(0, 0, 146), Vector3(0, 0, 100)]]:
		var foot: Vector3 = mast[0]
		y.call("_put", lattice, Transform3D(Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)), foot + Vector3(0, 7.5, 0)), galv)
		y.call("_put", y.call("_box", Vector3(1.4, 0.4, 1.4)), Transform3D(Basis(), foot + Vector3(0, 0.2, 0)), concrete)
		y.call("_put", platform, Transform3D(Basis(), foot + Vector3(0, 15.0, 0)), galv, false)
		var target: Vector3 = mast[1]
		var to := Vector3(target.x - foot.x, 0, target.z - foot.z).normalized()
		y.call("_floodlight", head, foot + Vector3(0, 15.6, 0) + to * 0.3, target)


# --- The cutting bay ----------------------------------------------------------------------

## A tall clad shed on a portal frame, open to the south through a wide door with its roller
## shutter rolled up, a cutting grid on the floor, a fume hood and duct over it, lamps.
func _build_cutting_bay() -> void:
	var r := CUTTING
	var t := 0.3
	var clad: Material = y.call("_paint", Color(0.36, 0.39, 0.42), 0.4, 0.55, "satin_paint")
	var frame: Material = y.get("_frame")
	var hazard: Material = y.get("_hazard")
	var top := CUTTING_H - 0.02
	# Walls: west and east full depth, north between them, south either side of the door and
	# over it. Each wall stops short of the roof's underside.
	y.call("_block", Vector3(r.position.x + t * 0.5, top * 0.5, r.get_center().y), Vector3(t, top, r.size.y), clad)
	y.call("_block", Vector3(r.end.x - t * 0.5, top * 0.5, r.get_center().y), Vector3(t, top, r.size.y), clad)
	y.call("_block", Vector3(r.get_center().x, top * 0.5, r.position.y + t * 0.5), Vector3(r.size.x - t * 2.0, top, t), clad)
	var side := (r.size.x - t * 2.0 - CUTTING_DOOR.x) * 0.5
	for k: float in [-1.0, 1.0]:
		y.call("_block", Vector3(r.get_center().x + k * (CUTTING_DOOR.x + side) * 0.5, top * 0.5, r.end.y - t * 0.5), Vector3(side, top, t), clad)
	y.call("_block", Vector3(r.get_center().x, (CUTTING_DOOR.y + top) * 0.5, r.end.y - t * 0.5), Vector3(CUTTING_DOOR.x, top - CUTTING_DOOR.y, t), clad)
	# The roof, overhanging, and an orange fascia along its front.
	y.call("_block", Vector3(r.get_center().x, CUTTING_H + 0.15, r.get_center().y), Vector3(r.size.x + 0.8, 0.3, r.size.y + 0.8), y.call("_paint", Color(0.3, 0.32, 0.34), 0.4, 0.6, "satin_paint"))
	y.call("_put", y.call("_box", Vector3(r.size.x + 0.84, 0.5, 0.1)), Transform3D(Basis(), Vector3(r.get_center().x, CUTTING_H + 0.1, r.end.y + 0.45)), y.get("_trim"), false)
	# Portal frames inside: columns against the long walls every 6 m and a rafter across.
	var col: String = y.call("_lib", "ibeam/cutting_col", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(top - 0.5, 0.4, 0.5, 0.03))
	var rafter: String = y.call("_lib", "ibeam/cutting_rafter", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(r.size.x - t * 2.0 - 0.02, 0.4, 0.5, 0.03))
	var upright := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	var z := r.position.y + 3.0
	while z < r.end.y - 1.0:
		for k: float in [-1.0, 1.0]:
			var x := r.get_center().x + k * (r.size.x * 0.5 - t - 0.27)
			y.call("_put", col, Transform3D(upright, Vector3(x, (top - 0.5) * 0.5, z)), frame, false)
		y.call("_put", rafter, Transform3D(Basis(), Vector3(r.get_center().x, top - 0.26, z)), frame, false)
		z += 6.0
	# The rolled-up shutter over the door and hazard stripes up its jambs.
	y.call("_put", y.call("_lib", "prism/shutter_roll", func() -> PartShapes.PartShape:
			return PartShapes.prism(16, 0.45, CUTTING_DOOR.x + 0.6)), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(r.get_center().x, CUTTING_DOOR.y + 0.5, r.end.y - t - 0.5)), y.get("_frame"), false)
	for k: float in [-1.0, 1.0]:
		var jamb := r.get_center().x + k * (CUTTING_DOOR.x * 0.5 + 0.1)
		for i in 5:
			y.call("_put", y.call("_box", Vector3(0.2, 0.6, 0.06)), Transform3D(Basis(), Vector3(jamb, 0.4 + i * 1.2, r.end.y + 0.031)), hazard, false)
	y.call("_sign", "CUTTING BAY", Vector3(r.get_center().x, CUTTING_DOOR.y + 1.0, r.end.y + 0.12), 0.0, 0.9)
	# The cutting grid: a grating on trestles, with a slag tray under it.
	var grid: String = y.call("_lib", "grating/cutting", func() -> PartShapes.PartShape:
			return WreckParts.grating(8.0, 16.0, 0.08))
	var gc := Vector3(r.get_center().x, 0, r.get_center().y - 1.0)
	y.call("_put", grid, Transform3D(Basis(Vector3.UP, PI * 0.5), gc + Vector3(0, 0.9, 0)), y.get("_galv"), false)
	y.call("_put", y.call("_box", Vector3(15.6, 0.3, 7.6)), Transform3D(Basis(), gc + Vector3(0, 0.15, 0)), y.call("_paint", Color(0.12, 0.11, 0.1), 0.6, 0.7, "gunmetal"))
	for dx: float in [-6.5, -2.2, 2.2, 6.5]:
		for dz: float in [-3.2, 3.2]:
			y.call("_put", y.call("_box", Vector3(0.3, 0.55, 0.3)), Transform3D(Basis(), gc + Vector3(dx, 0.575, dz)), frame)
	y.call("_collide", gc + Vector3(0, 0.45, 0), Vector3(16, 0.9, 8))
	# The fume hood over the grid and its duct out through the north wall.
	y.call("_put", y.call("_lib", "cone/fume_hood", func() -> PartShapes.PartShape:
			return PartShapes.frustum(3.0, 0.8, 1.6, 4)), Transform3D(Basis(Vector3.UP, PI * 0.25), gc + Vector3(0, 7.2, 0)), y.get("_galv"), false)
	y.call("_put", y.call("_lib", "pipe/fume_duct", func() -> PartShapes.PartShape:
			return WreckParts.pipe(0.6, 2.4)), Transform3D(Basis(), gc + Vector3(0, 9.2, 0)), y.get("_galv"), false)
	var run := gc.z - r.position.y + 0.5
	y.call("_put", y.call("_lib", "pipe/fume_run", func() -> PartShapes.PartShape:
			return WreckParts.pipe(0.6, run)), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(gc.x, 10.4, gc.z - run * 0.5)), y.get("_galv"), false)
	# Lamps under the rafters (shadowless, they burn all day).
	for p: Vector3 in [gc + Vector3(-6, 9.5, -6), gc + Vector3(6, 9.5, -6), gc + Vector3(-6, 9.5, 6), gc + Vector3(6, 9.5, 6)]:
		var lamp := OmniLight3D.new()
		lamp.position = p
		lamp.light_color = Color(1.0, 0.93, 0.82)
		lamp.light_energy = 2.0
		lamp.omni_range = 16.0   # m
		lamp.shadow_enabled = false
		lamp.set_meta("gfx_no_shadow", true)
		add_child(lamp)
		y.call("_put", y.call("_box", Vector3(1.4, 0.12, 0.4)), Transform3D(Basis(), p + Vector3(0, 0.1, 0)), y.call("_glow_mat", Color(1.0, 0.93, 0.82), 2.5), false)


# --- The scrap lane -----------------------------------------------------------------------

## Behind the cutting bay: the bale press with its hopper, bales stacked by metal, pallets of
## ingots, a skip per metal, a weighbridge by the road.
func _build_scrap_lane() -> void:
	var r := SCRAP
	var parts: Material = y.get("_parts")
	var press: String = y.call("_lib", "machine/bale_press", func() -> PartShapes.PartShape:
			return WreckParts.machine_unit(Vector3(7.0, 3.2, 3.4), Color(1.0, 0.6, 0.15)))
	var press_at := Vector3(r.position.x + 6.0, 1.6, r.position.y + 4.0)
	y.call("_put", press, Transform3D(Basis(), press_at), parts)
	y.call("_put", y.call("_lib", "cone/press_hopper", func() -> PartShapes.PartShape:
			return PartShapes.frustum(1.0, 2.0, 1.8, 4)), Transform3D(Basis(Vector3.UP, PI * 0.25), press_at + Vector3(-1.8, 2.5, 0)), y.get("_hazard"), false)
	y.call("_sign", "SCRAP LANE", Vector3(r.get_center().x, 4.4, r.position.y + 0.3), 0.0, 0.7)
	for k: float in [-1.0, 1.0]:
		y.call("_put", y.call("_box", Vector3(0.16, 3.95, 0.16)), Transform3D(Basis(), Vector3(r.get_center().x + k * 2.0, 1.975, r.position.y + 0.13)), y.get("_frame"))
	# Bales by metal, in stacks, and an ingot pallet beside each stack.
	var bale: String = y.call("_lib", "cbox/bale", func() -> PartShapes.PartShape:
			return PartShapes.chamfer_box(Vector3(1.2, 1.0, 1.2), 0.08))
	var pallet: String = y.call("_box", Vector3(1.2, 0.14, 1.0))
	var ingot: String = y.call("_lib", "cbox/ingot", func() -> PartShapes.PartShape:
			return PartShapes.chamfer_box(Vector3(0.5, 0.12, 0.16), 0.03))
	var wood: Material = y.get("_wood")
	var i := 0
	for metal: String in SCRAP_METALS:
		var colour: Color = SCRAP_METALS[metal]
		var mat: Material = y.call("_paint", colour, 0.75, 0.55, "bare_steel")
		var base := Vector3(r.position.x + 3.0 + i * 6.5, 0, r.end.y - 6.0)
		for k in 4:
			var at := base + Vector3((k % 2) * 1.3, 0.5 + floorf(k / 2.0) * 1.01, 0)
			y.call("_put", bale, Transform3D(Basis(), at), mat)
		var p := base + Vector3(3.2, 0, 0)
		y.call("_put", pallet, Transform3D(Basis(), p + Vector3(0, 0.07, 0)), wood)
		for layer in 3:
			for n in 5:
				var flip := layer % 2 == 1
				var off := Vector3((n - 2) * 0.22, 0.2 + layer * 0.121, 0.0) if not flip else Vector3(0.0, 0.2 + layer * 0.121, (n - 2) * 0.19)
				y.call("_put", ingot, Transform3D(Basis(Vector3.UP, PI * 0.5) if not flip else Basis(), p + off), mat, false)
		# The skip for this metal, its name on the side.
		_skip(Vector3(base.x + 1.6, 0, r.end.y - 1.8), metal)
		i += 1
	# The weighbridge: a steel deck flush with a dark frame, a readout on a post.
	var wb := Vector3(r.end.x - 4.0, 0, r.position.y + 4.0)
	y.call("_put", y.call("_box", Vector3(4.0, 0.06, 7.0)), Transform3D(Basis(), wb + Vector3(0, 0.03, 0)), y.call("_paint", Color(0.55, 0.57, 0.6), 0.6, 0.5, "rubber_tread"), false)
	y.call("_put", y.call("_box", Vector3(4.3, 0.04, 7.3)), Transform3D(Basis(), wb + Vector3(0, 0.02, 0)), y.get("_frame"), false)
	y.call("_screen", wb + Vector3(-2.8, 1.5, -3.0), "WEIGHBRIDGE\n0 KG", PI * 0.5)
	y.call("_put", y.call("_box", Vector3(0.14, 1.2, 0.14)), Transform3D(Basis(), wb + Vector3(-2.8, 0.6, -3.0)), y.get("_frame"))


## An open skip: a floor and four sloping-in walls, its metal written on the side facing south.
func _skip(at: Vector3, metal: String) -> void:
	var paint: Material = y.call("_paint", Color(0.2, 0.36, 0.56), 0.3, 0.6, "satin_paint")
	var size := Vector3(2.6, 1.3, 1.6)
	y.call("_put", y.call("_box", Vector3(size.x, 0.1, size.z)), Transform3D(Basis(), at + Vector3(0, 0.05, 0)), paint)
	for k: float in [-1.0, 1.0]:
		y.call("_put", y.call("_box", Vector3(size.x, size.y, 0.08)), Transform3D(Basis(), at + Vector3(0, size.y * 0.5 + 0.1, k * (size.z * 0.5 - 0.04))), paint)
		y.call("_put", y.call("_box", Vector3(0.08, size.y, size.z - 0.16)), Transform3D(Basis(), at + Vector3(k * (size.x * 0.5 - 0.04), size.y * 0.5 + 0.1, 0)), paint)
	var tag: Label3D = y.call("_tag", metal, at + Vector3(0, 0.85, size.z * 0.5 + 0.01), 0.36, Vector3(0, 0, 1))
	tag.modulate = Color(0.95, 0.95, 0.92)
