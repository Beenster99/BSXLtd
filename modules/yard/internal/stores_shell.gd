extends RefCounted
## The stores hall's shell (0.4.0 playtest): five times the old racking hall, x 14..84,
## z -64..-4, 16 m high. Its whole yard side (-Z) is open to the dock behind an air curtain, so
## bots carry parts straight out to the build berth; the east wall opens onto goods in, where
## haulers berth outside and their loads are set down in four marked bays before they are put
## away. The racks are RackingHall's. Since the 0.4.1 playtest it has two storeys: an upper deck
## at YardRackStore.UPPER_FLOOR_Y over the racks' half of the hall, the same racks again on it,
## and over goods in a well open floor to roof that the bots rise and drop through, with a
## stair up beside it.

const Kit := preload("res://modules/yard/internal/yard_kit.gd")
const AirCurtain := preload("res://modules/yard/internal/shaders/air_curtain.gdshader")

## The hall (station space; the same as YardLayout.ROOMS.racking).
const X0 := 14.0
const X1 := 84.0
const Z_YARD := -64.0
const Z_BACK := -4.0
const HEIGHT := 32.4
## The upper deck: its top, its thickness, and its east edge (the well past it).
const DECK_Y := YardRackStore.UPPER_FLOOR_Y
const DECK_T := 0.4
const DECK_X1 := YardRackStore.UPPER_EDGE_X
## Each storey's open face's clear height (a lintel above it), and goods in's opening in the
## east wall.
const OPEN_H := 14.0
const GOODS_IN_Z := Vector2(-57.0, -11.0)
const GOODS_IN_H := 12.0
## The stair up to the deck: its width (m), each step's rise, and where it starts and lands
## along z (it climbs towards the yard side).
const STAIR_W := 1.6
const STEP_RISE := 0.2
const STAIR_BOTTOM_Z := -6.0
const STAIR_TOP_Z := -34.0

var _kit


func build(kit, hull: Material, wall: Material, dark: Material, orange: Material) -> void:
	_kit = kit
	var k = kit
	var yellow: Material = k.paint(Color(1.0, 0.78, 0.1), 0.1, 0.6, "enamel")
	# The back wall onto the corridor (its door at x 28..32; the refurb annex's at x 68..82), the
	# west wall, and the east wall
	# with goods in's opening.
	# (They stop under the ceiling, which runs over their tops.)
	var h := HEIGHT - 0.02
	k.wall(true, Z_BACK, X0, X1, 0.0, h, wall, [[28.0, 32.0, 3.0], [68.0, 82.0, 12.0]])
	k.wall(false, X0, Z_YARD, Z_BACK, 0.0, h, wall)
	k.wall(false, X1, Z_YARD, Z_BACK, 0.0, h, wall, [[GOODS_IN_Z.x, GOODS_IN_Z.y, GOODS_IN_H]])
	# The yard side, both storeys: a lintel over each open face on columns, the air curtain
	# under it.
	for base: float in [0.0, DECK_Y]:
		var lintel_top := (DECK_Y - DECK_T) if base == 0.0 else HEIGHT - 0.02
		k.box(Vector3(X1 - X0 - 0.2, lintel_top - (base + OPEN_H), 0.6), Vector3((X0 + X1) * 0.5, (lintel_top + base + OPEN_H) * 0.5, Z_YARD + 0.25), hull)
		for x: float in [X0 + 0.45, 31.0, 49.0, 66.0, X1 - 0.45]:
			k.box(Vector3(0.7, OPEN_H, 0.7), Vector3(x, base + OPEN_H * 0.5, Z_YARD + 0.35), dark)
		_curtain(Vector3((X0 + X1) * 0.5, base + OPEN_H * 0.5, Z_YARD + 0.05), Vector2(X1 - X0 - 0.4, OPEN_H - 0.04), 0.0)
		k.box(Vector3(X1 - X0 - 0.4, 0.012, 0.5), Vector3((X0 + X1) * 0.5, base + 0.006, Z_YARD + 0.95), k.paint(Color(1.0, 0.78, 0.1), 0.1, 0.6, "hazard_stripes"), false)
	_curtain(Vector3(X1 - 0.05, GOODS_IN_H * 0.5, (GOODS_IN_Z.x + GOODS_IN_Z.y) * 0.5), Vector2(GOODS_IN_Z.y - GOODS_IN_Z.x - 0.1, GOODS_IN_H - 0.04), PI * 0.5)
	k.box(Vector3(0.5, 0.012, GOODS_IN_Z.y - GOODS_IN_Z.x), Vector3(X1 - 0.6, 0.006, (GOODS_IN_Z.x + GOODS_IN_Z.y) * 0.5), k.paint(Color(1.0, 0.78, 0.1), 0.1, 0.6, "hazard_stripes"), false)
	_deck(k, hull, dark, yellow)
	# Roof trusses and lamps under each storey's ceiling (no shadows; the hall's bounce light
	# does the rest). Over the well the lamps hang from the roof.
	var ceilings := [DECK_Y - DECK_T, HEIGHT]
	for c: float in ceilings:
		for x: float in [20.5, 29.0, 38.0, 47.0, 58.5]:   # over the racks, lamps between
			k.box(Vector3(0.4, 0.5, Z_BACK - Z_YARD - 1.4), Vector3(x, c - 0.27, (Z_YARD + Z_BACK) * 0.5 + 0.5), dark, false)
		for lx: float in [16.4, 24.8, 33.5, 42.7, 52.0, 62.4]:   # over the aisles
			for lz: float in [-56.0, -42.0, -28.0, -14.0]:
				_lamp(k, Vector3(lx, c, lz), c - (DECK_Y if c > DECK_Y else 0.0))
	for x: float in [70.0, 78.0]:
		k.box(Vector3(0.4, 0.9, Z_BACK - Z_YARD - 0.8), Vector3(x, HEIGHT - 0.47, (Z_YARD + Z_BACK) * 0.5 + 0.2), dark, false)
	for lz: float in [-56.0, -42.0, -28.0, -14.0]:
		_lamp(k, Vector3(75.0, HEIGHT, lz), HEIGHT - DECK_Y)
		_fill(Vector3(75.0, DECK_Y - 2.0, lz))   # the well's ground floor, under the deck's height
	# Goods in: four bays, one per hauler, marked out and numbered.
	for i in YardRackStore.GOODS_IN_BAYS.size():
		var b: AABB = YardRackStore.GOODS_IN_BAYS[i]
		_outline(b, yellow)
		k.sign("GOODS IN %d" % (i + 1), Vector3(X1 - 0.12, 13.0, b.get_center().z), Vector3.LEFT, 0.012, Color(1.0, 0.78, 0.1), 64)
	k.sign("GOODS IN", Vector3((X1 + 66.0) * 0.5, 13.2, Z_BACK - 0.12), Vector3.FORWARD, 0.03, Kit.ORANGE, 96)
	k.sign("LEVEL 1", Vector3(X0 + 4.0, 13.5, Z_BACK - 0.12), Vector3.FORWARD, 0.02, Kit.ORANGE, 96)
	k.sign("LEVEL 2", Vector3(X0 + 4.0, DECK_Y + 13.5, Z_BACK - 0.12), Vector3.FORWARD, 0.02, Kit.ORANGE, 96)
	# The yard side: four bays where bots set parts down for the build berth.
	var teal: Material = k.paint(Color(0.2, 0.75, 0.7), 0.1, 0.6, "enamel")
	for i in YardRackStore.DISPATCH_BAYS.size():
		var b: AABB = YardRackStore.DISPATCH_BAYS[i]
		_outline(b, teal)
	# Aisle lines down the hall between the racks.
	for r in YardRackStore.RACKS.size():
		var rack: Dictionary = YardRackStore.RACKS[r]
		var reach := float(rack.depth) + (0.55 if int(rack.kind) == YardRackStore.LONG else 0.3)
		for side: float in [-1.0, 1.0]:
			k.box(Vector3(0.1, 0.012, float(rack.z1) - float(rack.z0) + 1.0), Vector3(float(rack.x) + side * reach, float(rack.base) + 0.006, (float(rack.z0) + float(rack.z1)) * 0.5), yellow, false)
	# Outside: the hull under the hall, the name over the open face, haulers' berths at goods in.
	k.box(Vector3(X1 - X0, 0.4, Z_BACK - Z_YARD), Vector3((X0 + X1) * 0.5, -0.5, (Z_YARD + Z_BACK) * 0.5), dark, false)
	k.sign("BSX LTD", Vector3(40.0, HEIGHT - 1.2, Z_YARD - 0.07), Vector3.FORWARD, 0.03, Kit.ORANGE, 96)
	k.sign("DEEP SPACE YARD  ·  STORES", Vector3(68.0, HEIGHT - 1.2, Z_YARD - 0.07), Vector3.FORWARD, 0.014, Kit.HULL, 96)
	k.sign("LEVEL 1", Vector3(22.0, DECK_Y - 1.2, Z_YARD - 0.07), Vector3.FORWARD, 0.012, Kit.HULL, 96)
	k.sign("LEVEL 2", Vector3(22.0, HEIGHT - 1.2, Z_YARD - 0.07), Vector3.FORWARD, 0.012, Kit.HULL, 96)
	for p: Vector3 in YardRackStore.HAULER_BERTHS:
		for dz: float in [-4.5, 4.5]:
			k.box(Vector3(0.6, 0.6, 0.6), p + Vector3(-12.0, -5.0, dz), k.glow(Color(1.0, 0.78, 0.1), 6.0), false)
	for p: Vector3 in [Vector3(X1 + 0.2, HEIGHT + 0.3, Z_YARD - 0.2), Vector3(X0 - 0.2, HEIGHT + 0.3, Z_YARD - 0.2), Vector3(X1 + 0.2, HEIGHT + 0.3, Z_BACK + 0.2)]:
		k.box(Vector3(0.3, 0.3, 0.3), p, k.glow(Color(1.0, 0.25, 0.2), 6.0), false)


## The upper deck: a slab over the racks' half of the hall (ceiling under, tread on top), a
## rail with a hazard edge along its well side and its open face, and a stair up beside the
## well from the back corner.
func _deck(k, hull: Material, dark: Material, yellow: Material) -> void:
	var tread: Material = k.paint(Color(0.5, 0.52, 0.55), 0.2, 0.55, "tread_diamond_paint")
	var under: Material = k.paint(Color(0.84, 0.86, 0.88), 0.05, 0.7, "plastic_textured")
	var bottom := DECK_Y - DECK_T
	k.slab(Vector3(X0 + 0.02, bottom + 0.03, Z_YARD + 0.6), Vector3(DECK_X1, DECK_Y, Z_BACK - 0.02), tread)
	k.slab(Vector3(X0 + 0.02, bottom, Z_YARD + 0.6), Vector3(DECK_X1, bottom + 0.02, Z_BACK - 0.02), under, 6.0, false)
	# Its edge over the well: a hull-white fascia, a hazard edge and a rail (gap at the stair).
	k.box(Vector3(0.2, DECK_T - 0.04, Z_BACK - Z_YARD - 0.62), Vector3(DECK_X1 + 0.1, bottom + DECK_T * 0.5, (Z_YARD + 0.6 + Z_BACK) * 0.5), hull, false)
	var hazard: Material = k.paint(Color(1.0, 0.78, 0.1), 0.1, 0.6, "hazard_stripes")
	k.box(Vector3(0.5, 0.012, Z_BACK - Z_YARD - 0.8), Vector3(DECK_X1 - 0.35, DECK_Y + 0.006, (Z_YARD + Z_BACK) * 0.5 + 0.3), hazard, false)
	for run: Vector2 in [Vector2(Z_YARD + 0.8, STAIR_TOP_Z - 1.6), Vector2(STAIR_TOP_Z + 0.2, Z_BACK - 0.3)]:
		_rail(Vector3(DECK_X1 - 0.12, DECK_Y, run.x), Vector3(DECK_X1 - 0.12, DECK_Y, run.y), yellow, dark)
	# The stair: along the well's west side from the back corner up to the deck, under a rail.
	var steps := int(ceil(DECK_Y / STEP_RISE))
	var run := (STAIR_BOTTOM_Z - STAIR_TOP_Z) / steps
	var x := DECK_X1 + 0.12 + STAIR_W * 0.5
	for i in steps:
		var y_top := DECK_Y * float(i + 1) / steps
		var z := STAIR_BOTTOM_Z - run * (i + 0.5)
		k.box(Vector3(STAIR_W, 0.08, run + 0.02), Vector3(x, y_top - 0.04, z), tread, false)
		k.box(Vector3(STAIR_W - 0.1, DECK_Y / steps - 0.08, 0.03), Vector3(x, y_top - DECK_Y / steps * 0.5 - 0.04, z + run * 0.5 - 0.02), dark, false)
	# Stringers, the ramp you walk up, and its rail on the open side.
	var mid := Vector3(x, DECK_Y * 0.5, (STAIR_BOTTOM_Z + STAIR_TOP_Z) * 0.5)
	var length := Vector2(STAIR_BOTTOM_Z - STAIR_TOP_Z, DECK_Y).length()
	var tilt := atan2(DECK_Y, STAIR_BOTTOM_Z - STAIR_TOP_Z)
	for dx: float in [-1.0, 1.0]:
		var stringer: MeshInstance3D = k.box(Vector3(0.12, 0.45, length), mid + Vector3(dx * (STAIR_W * 0.5 + 0.06), -0.3, 0.0), dark, false)
		stringer.rotation.x = tilt
	var ramp := CollisionShape3D.new()
	ramp.name = "StairRamp"
	var shape := BoxShape3D.new()
	shape.size = Vector3(STAIR_W, 0.2, length)
	ramp.shape = shape
	ramp.position = mid - Vector3(0, 0.12, 0)
	ramp.rotation.x = tilt
	_kit.body.add_child(ramp)
	_rail(Vector3(x + STAIR_W * 0.5 + 0.05, 0.0, STAIR_BOTTOM_Z), Vector3(x + STAIR_W * 0.5 + 0.05, DECK_Y, STAIR_TOP_Z), yellow, dark)


## A safety rail from `a` to `b` (its foot): posts every 2 m, a top rail and a knee rail.
func _rail(a: Vector3, b: Vector3, yellow: Material, dark: Material) -> void:
	var d := b - a
	var n := maxi(1, int(ceil(d.length() / 2.0)))
	for i in n + 1:
		var p := a + d * (float(i) / n)
		_kit.box(Vector3(0.06, 1.1, 0.06), p + Vector3(0, 0.55, 0), dark, false)
	for h: float in [1.1, 0.55]:
		var bar: MeshInstance3D = _kit.box(Vector3(0.06, 0.06, d.length()), (a + b) * 0.5 + Vector3(0, h, 0), yellow, false)
		bar.basis = Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.BACK)


## A painted outline round a floor bay: four strips that do not overlap at the corners.
func _outline(b: AABB, mat: Material) -> void:
	var w := 0.14
	var c := b.get_center()
	for dz: float in [-1.0, 1.0]:
		_kit.box(Vector3(b.size.x, 0.012, w), Vector3(c.x, 0.006, c.z + dz * (b.size.z - w) * 0.5), mat, false)
	for dx: float in [-1.0, 1.0]:
		_kit.box(Vector3(w, 0.012, b.size.z - w * 2.0 - 0.02), Vector3(c.x + dx * (b.size.x - w) * 0.5, 0.006, c.z), mat, false)


## The shimmer that holds the hall's air in across an opening: drawn only, nothing solid.
func _curtain(centre: Vector3, size: Vector2, yaw: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "AirCurtain"
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = AirCurtain
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = centre
	mi.rotation.y = yaw
	_kit.root.add_child(mi)


## A ceiling lamp lighting its own storey: a spot just long enough to reach its floor, so the
## upper storey's lamps don't shine on through the deck (no shadows) onto the racks under it,
## and narrower than the kit's (68 degrees, whose bounds put some 50 lights on a floor tile).
func _lamp(k, at: Vector3, drop: float) -> void:
	var spot: SpotLight3D = k.ceiling_lamp(at, Vector2(2.4, 0.7), 2.4, 1.0)
	spot.spot_range = drop + 0.5
	spot.spot_angle = 50.0
	spot.spot_angle_attenuation = 0.5
	spot.spot_attenuation = 0.5


## A fill light with no lamp of its own (the well's ground floor, too far under the roof's).
func _fill(at: Vector3) -> void:
	var omni := OmniLight3D.new()
	omni.name = "WellFill"
	omni.position = at
	omni.omni_range = 15.0
	omni.omni_attenuation = 0.6
	omni.light_energy = 1.2
	omni.light_specular = 0.0
	omni.light_color = Color(1.0, 0.97, 0.92)
	omni.set_meta("gfx_fixed", true)
	_kit.root.add_child(omni)
