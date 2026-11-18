extends RefCounted
## The bulk freighter (0.4.1 playtest: "it's possible that a MASSIVE delivery ship arrives with
## a vast side door for bots to move goods"): 72 m long, 34 m high, berthed alongside goods in
## with a 60 m by 14 m door down her side whose leaves part into her hull above and her keel below, her hold floodlit and
## stacked with loads, a bridge tower aft, six engines, in a freight line's livery. Built in
## code with YardToolMesh, once (the livery is the material).
## Her space: origin at the middle of her hold floor (its top at y = 0), +X away from the
## station, her door in the -X face, her bow to -Z.

const HALF := Vector3(15.0, 0.0, 36.0)   # half her beam (x) and length (z), m
const DOOR_X := -15.0                    # her door face
const DOOR := Vector2(60.0, 14.0)         # the door's opening: along z, high (m)
const HOLD := AABB(Vector3(-14.5, 0.0, -30.0), Vector3(27.0, 14.0, 60.0))

static var _meshes: Dictionary = {}


## "hull" (all of her but the door) and the door's two leaves, "door_top" and "door_bottom",
## at their closed places.
static func meshes() -> Dictionary:
	if _meshes.is_empty():
		_meshes = _build()
	return _meshes


static func _build() -> Dictionary:
	var m := YardToolMesh.new()
	var k := "hull"
	var hx := HALF.x
	var hz := HALF.z
	var top := 25.0
	var keel := -9.0
	# The hull round her hold: under it, over it, her far side, the door's frame either end.
	m.box(k, "plates", Vector3(0, (keel - 0.4) * 0.5, 0), Vector3(hx * 2.0, -keel - 0.4, hz * 2.0), 0.4)
	m.box(k, "plates", Vector3(0, (14.6 + top) * 0.5, 0), Vector3(hx * 2.0, top - 14.6, hz * 2.0), 0.4)
	m.box(k, "plates", Vector3(hx - 1.0, 7.3, 0), Vector3(2.0, 14.6, hz * 2.0), 0.2)
	for side: float in [-1.0, 1.0]:
		m.box(k, "plates", Vector3(0, 7.3, side * (DOOR.x * 0.5 + (hz - DOOR.x * 0.5) * 0.5)), Vector3(hx * 2.0, 14.6, hz - DOOR.x * 0.5), 0.3)
		m.box(k, "trim", Vector3(DOOR_X - 0.1, 7.0, side * (DOOR.x * 0.5 + 0.4)), Vector3(0.6, 14.4, 0.8), 0.1)
	# The hold: tread floor with lanes, a ribbed back wall, ceiling beams and lamp strips.
	m.box(k, "dark", Vector3(-1.0, -0.2, 0), Vector3(27.0, 0.4, DOOR.x), 0.05)
	for lz in range(-27, 28, 9):
		m.box(k, "accent", Vector3(-1.0, 0.01, float(lz)), Vector3(26.0, 0.012, 0.2), 0.002)
	m.box(k, "gunmetal", Vector3(hx - 2.1, 7.0, 0), Vector3(0.2, 14.0, DOOR.x), 0.04)
	for rz in range(-28, 29, 4):
		m.box(k, "trim", Vector3(hx - 2.3, 7.0, float(rz)), Vector3(0.3, 14.0, 0.35), 0.05)
	m.box(k, "gunmetal", Vector3(-1.0, 14.4, 0), Vector3(27.0, 0.4, DOOR.x), 0.05)
	for bx in range(-12, 13, 6):
		m.box(k, "trim", Vector3(float(bx), 13.9, 0), Vector3(0.5, 0.7, DOOR.x), 0.08)
		m.box(k, "lamp", Vector3(float(bx) + 2.6, 14.17, 0), Vector3(0.4, 0.06, DOOR.x - 4.0), 0.02)
	# Her side round the door: the line's band and pinstripe over it, ribs, hazard edges,
	# floodlights in the door's head, a hazard sill.
	m.box(k, "accent", Vector3(DOOR_X - 0.08, 16.6, 0), Vector3(0.2, 2.4, hz * 2.0 - 1.0), 0.05)
	m.box(k, "trim", Vector3(DOOR_X - 0.08, 15.0, 0), Vector3(0.2, 0.3, hz * 2.0 - 1.0), 0.04)
	var x := -hz + 3.0
	while x <= hz - 2.9:
		m.box(k, "trim", Vector3(DOOR_X - 0.25, (17.9 + top) * 0.5, x), Vector3(0.5, top - 17.9, 0.6), 0.08)
		m.box(k, "trim", Vector3(DOOR_X - 0.25, (keel - 0.4) * 0.5, x), Vector3(0.5, -keel - 0.4, 0.6), 0.08)
		x += 6.0
	for lz in range(-27, 28, 6):
		m.box(k, "dark", Vector3(DOOR_X - 0.1, 14.1, float(lz)), Vector3(0.6, 0.5, 1.2), 0.06)
		m.box(k, "lamp", Vector3(DOOR_X - 0.42, 14.1, float(lz)), Vector3(0.04, 0.35, 1.0), 0.02)
	m.box(k, "accent_light", Vector3(DOOR_X - 0.05, -0.15, 0), Vector3(0.3, 0.1, DOOR.x - 0.5), 0.02)
	# Bow and stern: a raked prow, six engines aft in their cowls, their glow.
	m.box(k, "plates", Vector3(0, 6.0, -hz - 3.0), Vector3(hx * 2.0 - 4.0, top - keel - 6.0, 6.0), 0.8)
	m.box(k, "accent", Vector3(0, 6.0, -hz - 6.2), Vector3(hx * 2.0 - 10.0, top - keel - 14.0, 0.6), 0.3)
	m.box(k, "trim", Vector3(0, 6.0, hz + 1.5), Vector3(hx * 2.0 - 2.0, top - keel - 2.0, 3.0), 0.5)
	for ex: float in [-9.0, 0.0, 9.0]:
		for ey: float in [-2.0, 15.0]:
			var c := Vector3(ex, ey, hz + 3.0)
			m.rod(k, "gunmetal", c, c + Vector3(0, 0, 2.5), 4.0, 3.6, 40)
			m.rod(k, "dark", c + Vector3(0, 0, 2.5), c + Vector3(0, 0, 8.0), 2.4, 3.6, 40)
			m.rod(k, "cyan", c + Vector3(0, 0, 2.6), c + Vector3(0, 0, 2.7), 2.3, 2.3, 40)
	# Up top: radiator banks along her back, a bridge tower aft with its glazing, masts, a dish.
	for rz: float in [-24.0, -8.0, 8.0]:
		m.box(k, "gunmetal", Vector3(0, top + 0.3, rz), Vector3(20.0, 0.6, 12.0), 0.1)
		for f in 20:
			m.box(k, "steel", Vector3(-9.5 + f * 1.0, top + 1.2, rz), Vector3(0.12, 1.4, 11.6), 0.03)
	m.box(k, "plates", Vector3(2.0, top + 4.5, 24.0), Vector3(18.0, 9.0, 12.0), 0.5)
	m.box(k, "accent", Vector3(2.0, top + 8.2, 24.0), Vector3(18.2, 0.8, 12.2), 0.2)
	m.box(k, "glass", Vector3(2.0, top + 6.0, 17.95), Vector3(16.0, 1.8, 0.2), 0.1)
	m.box(k, "glass", Vector3(-7.05, top + 6.0, 24.0), Vector3(0.2, 1.8, 10.0), 0.1)
	for gx in range(-6, 11, 3):
		m.box(k, "trim", Vector3(float(gx), top + 6.0, 17.85), Vector3(0.25, 2.0, 0.3), 0.05)
	m.rod(k, "gunmetal", Vector3(8.0, top + 9.0, 26.0), Vector3(8.0, top + 16.0, 26.0), 0.25, 0.12, 12)
	m.rod(k, "red_lamp", Vector3(8.0, top + 16.0, 26.0), Vector3(8.0, top + 16.5, 26.0), 0.3, -1.0, 12)
	m.rod(k, "gunmetal", Vector3(-3.0, top + 9.0, 27.0), Vector3(-3.0, top + 11.0, 27.0), 0.3, -1.0, 12)
	m.rod(k, "plates", Vector3(-3.0, top + 11.0, 27.0), Vector3(-3.6, top + 12.5, 27.0), 0.2, 3.0, 40)
	m.ring(k, "trim", Vector3(-3.6, top + 12.5, 27.0), 2.95, 0.12, Vector3(-0.4, 0.9, 0).normalized(), 40, 6)
	# Navigation lamps at her corners and a beacon line along her back.
	for side: float in [-1.0, 1.0]:
		m.rod(k, "red_lamp", Vector3(side * (hx - 1.0), top, -hz + 0.5), Vector3(side * (hx - 1.0), top + 0.6, -hz + 0.5), 0.4, -1.0, 12)
		m.rod(k, "lamp", Vector3(side * (hx - 1.0), top, hz - 0.5), Vector3(side * (hx - 1.0), top + 0.6, hz - 0.5), 0.4, -1.0, 12)
	# The door: two leaves just inside her side, each half the opening's height, ribbed across
	# with a hazard band where they meet; the top leaf slides up into her hull over the hold,
	# the bottom one down into her keel.
	var half := DOOR.y * 0.5
	for leaf: String in ["door_top", "door_bottom"]:
		var y0 := half if leaf == "door_top" else 0.0
		m.box(leaf, "plates", Vector3(DOOR_X + 0.5, y0 + half * 0.5, 0), Vector3(0.5, half, DOOR.x), 0.08)
		for ry in [1.4, 3.5, 5.6]:
			m.box(leaf, "trim", Vector3(DOOR_X + 0.2, y0 + float(ry), 0), Vector3(0.2, 0.4, DOOR.x - 0.6), 0.05)
		var seam_y := y0 + (0.35 if leaf == "door_top" else half - 0.35)
		m.box(leaf, "accent", Vector3(DOOR_X + 0.2, seam_y, 0), Vector3(0.16, 0.7, DOOR.x - 0.6), 0.03)
	return m.meshes()
