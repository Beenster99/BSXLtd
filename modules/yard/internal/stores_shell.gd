extends RefCounted
## The stores hall's shell (0.4.0 playtest): five times the old racking hall, x 14..84,
## z -64..-4, 16 m high. Its whole yard side (-Z) is open to the dock behind an air curtain, so
## bots carry parts straight out to the build berth; the east wall opens onto goods in, where
## haulers berth outside and their loads are set down in four marked bays before they are put
## away. The racks are RackingHall's.

const Kit := preload("res://modules/yard/internal/yard_kit.gd")
const AirCurtain := preload("res://modules/yard/internal/shaders/air_curtain.gdshader")

## The hall (station space; the same as YardLayout.ROOMS.racking).
const X0 := 14.0
const X1 := 84.0
const Z_YARD := -64.0
const Z_BACK := -4.0
const HEIGHT := 16.0
## The open face's clear height (a lintel above it), and goods in's opening in the east wall.
const OPEN_H := 14.0
const GOODS_IN_Z := Vector2(-57.0, -11.0)
const GOODS_IN_H := 12.0

var _kit


func build(kit, hull: Material, wall: Material, dark: Material, orange: Material) -> void:
	_kit = kit
	var k = kit
	var yellow: Material = k.paint(Color(1.0, 0.78, 0.1), 0.1, 0.6, "enamel")
	# The back wall onto the corridor (its door at x 28..32), the west wall, and the east wall
	# with goods in's opening.
	# (They stop under the ceiling, which runs over their tops.)
	var h := HEIGHT - 0.02
	k.wall(true, Z_BACK, X0, X1, 0.0, h, wall, [[28.0, 32.0, 3.0]])
	k.wall(false, X0, Z_YARD, Z_BACK, 0.0, h, wall)
	k.wall(false, X1, Z_YARD, Z_BACK, 0.0, h, wall, [[GOODS_IN_Z.x, GOODS_IN_Z.y, GOODS_IN_H]])
	# The yard side: a lintel over the open face on columns, and the air curtain under it.
	k.box(Vector3(X1 - X0 - 0.2, HEIGHT - OPEN_H - 0.02, 0.6), Vector3((X0 + X1) * 0.5, (HEIGHT - 0.02 + OPEN_H) * 0.5, Z_YARD + 0.25), hull)
	for x: float in [X0 + 0.45, 31.0, 49.0, 66.0, X1 - 0.45]:
		k.box(Vector3(0.7, OPEN_H, 0.7), Vector3(x, OPEN_H * 0.5, Z_YARD + 0.35), dark)
	_curtain(Vector3((X0 + X1) * 0.5, OPEN_H * 0.5, Z_YARD + 0.05), Vector2(X1 - X0 - 0.4, OPEN_H - 0.04), 0.0)
	_curtain(Vector3(X1 - 0.05, GOODS_IN_H * 0.5, (GOODS_IN_Z.x + GOODS_IN_Z.y) * 0.5), Vector2(GOODS_IN_Z.y - GOODS_IN_Z.x - 0.1, GOODS_IN_H - 0.04), PI * 0.5)
	# Hazard edges along both openings' sills.
	k.box(Vector3(X1 - X0 - 0.4, 0.012, 0.5), Vector3((X0 + X1) * 0.5, 0.006, Z_YARD + 0.95), k.paint(Color(1.0, 0.78, 0.1), 0.1, 0.6, "hazard_stripes"), false)
	k.box(Vector3(0.5, 0.012, GOODS_IN_Z.y - GOODS_IN_Z.x), Vector3(X1 - 0.6, 0.006, (GOODS_IN_Z.x + GOODS_IN_Z.y) * 0.5), k.paint(Color(1.0, 0.78, 0.1), 0.1, 0.6, "hazard_stripes"), false)
	# Roof trusses and lamps (no shadows; the hall's bounce light does the rest).
	for x: float in [20.5, 29.0, 38.0, 47.0, 58.5, 70.0, 78.0]:   # over the racks, lamps between
		k.box(Vector3(0.4, 0.9, Z_BACK - Z_YARD - 0.8), Vector3(x, HEIGHT - 0.47, (Z_YARD + Z_BACK) * 0.5 + 0.2), dark, false)
	for lx: float in [16.4, 24.8, 33.5, 42.7, 52.0, 63.8, 75.0]:   # over the aisles
		for lz: float in [-56.0, -42.0, -28.0, -14.0]:
			k.ceiling_lamp(Vector3(lx, HEIGHT, lz), Vector2(2.4, 0.7), 1.8, 24.0)
	# Goods in: four bays, one per hauler, marked out and numbered.
	for i in YardRackStore.GOODS_IN_BAYS.size():
		var b: AABB = YardRackStore.GOODS_IN_BAYS[i]
		_outline(b, yellow)
		k.sign("GOODS IN %d" % (i + 1), Vector3(X1 - 0.12, 13.0, b.get_center().z), Vector3.LEFT, 0.012, Color(1.0, 0.78, 0.1), 64)
	k.sign("GOODS IN", Vector3((X1 + 66.0) * 0.5, 13.2, Z_BACK - 0.12), Vector3.FORWARD, 0.03, Kit.ORANGE, 96)
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
			k.box(Vector3(0.1, 0.012, float(rack.z1) - float(rack.z0) + 1.0), Vector3(float(rack.x) + side * reach, 0.006, (float(rack.z0) + float(rack.z1)) * 0.5), yellow, false)
	# Outside: the hull under the hall, the name over the open face, haulers' berths at goods in.
	k.box(Vector3(X1 - X0, 0.4, Z_BACK - Z_YARD), Vector3((X0 + X1) * 0.5, -0.5, (Z_YARD + Z_BACK) * 0.5), dark, false)
	k.sign("BSX LTD", Vector3(40.0, 15.0, Z_YARD - 0.07), Vector3.FORWARD, 0.02, Kit.ORANGE, 96)
	k.sign("ORBITAL YARD  ·  STORES", Vector3(66.0, 15.0, Z_YARD - 0.07), Vector3.FORWARD, 0.012, Kit.HULL, 96)
	for p: Vector3 in YardRackStore.HAULER_BERTHS:
		for dz: float in [-4.5, 4.5]:
			k.box(Vector3(0.6, 0.6, 0.6), p + Vector3(-12.0, -5.0, dz), k.glow(Color(1.0, 0.78, 0.1), 6.0), false)
	for p: Vector3 in [Vector3(X1 + 0.2, HEIGHT + 0.3, Z_YARD - 0.2), Vector3(X0 - 0.2, HEIGHT + 0.3, Z_YARD - 0.2), Vector3(X1 + 0.2, HEIGHT + 0.3, Z_BACK + 0.2)]:
		k.box(Vector3(0.3, 0.3, 0.3), p, k.glow(Color(1.0, 0.25, 0.2), 6.0), false)


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
