extends RefCounted
## What a freight line's hauler looks like (0.4.1 playtest: "likewise with the delivery
## trucks ... maybe each delivery has a different brand"): a 16 m hold of plated walls on
## outside ribs, saddle tanks, roof radiators, a dish and beacons, a cab with its glazing,
## thruster quads and floodlit mouth, in the line's livery (YardBotLook.BRANDS), its name
## down both sides. Built in code with YardToolMesh, once (the livery is the material).
## Hauler space: +X the cab, the hold open at -X, the hold floor's top at y = -2.8.

const BotLook := preload("res://modules/yard/internal/yard_bot_look.gd")

static var _meshes: Dictionary = {}


## "hull" (all of it but the ramp) and "ramp" (hinged at its foot, standing up +Y).
static func meshes() -> Dictionary:
	if _meshes.is_empty():
		_meshes = _build()
	return _meshes


static func _build() -> Dictionary:
	var m := YardToolMesh.new()
	var k := "hull"
	# The hold: deck, roof and walls, open at the west end.
	m.box(k, "dark", Vector3(0, -3.0, 0), Vector3(16.0, 0.4, 7.6), 0.05)
	m.box(k, "plates", Vector3(0, 3.25, 0), Vector3(16.0, 0.5, 8.2), 0.12)
	for side: float in [-1.0, 1.0]:
		var z := side * 3.95
		m.box(k, "plates", Vector3(0, 0.0, z), Vector3(16.0, 6.6, 0.3), 0.08)
		# Outside ribs every 2 m, a livery band and its pinstripe, hatch seams.
		var x := -7.6
		while x <= 7.7:
			m.box(k, "trim", Vector3(x, 0.15, side * 4.17), Vector3(0.32, 6.9, 0.16), 0.04)
			x += 2.0
		m.box(k, "accent", Vector3(0, 1.6, side * 4.14), Vector3(15.6, 0.7, 0.06), 0.02)
		m.box(k, "trim", Vector3(0, 1.1, side * 4.14), Vector3(15.6, 0.12, 0.06), 0.02)
		for hx: float in [-4.6, 0.6]:
			m.box(k, "dark", Vector3(hx, -1.0, side * 4.12), Vector3(3.2, 0.04, 0.04), 0.01)
			m.box(k, "dark", Vector3(hx, -2.6, side * 4.12), Vector3(3.2, 0.04, 0.04), 0.01)
			for dx: float in [-1.6, 1.6]:
				m.box(k, "dark", Vector3(hx + dx, -1.8, side * 4.12), Vector3(0.04, 1.6, 0.04), 0.01)
		# A saddle tank along each lower side on straps, a pipe run above it.
		m.rod(k, "plates", Vector3(-6.0, -2.3, side * 4.85), Vector3(5.5, -2.3, side * 4.85), 0.62, -1.0, 28)
		m.rod(k, "trim", Vector3(-6.3, -2.3, side * 4.85), Vector3(-6.0, -2.3, side * 4.85), 0.45, 0.62, 28)
		m.rod(k, "trim", Vector3(5.5, -2.3, side * 4.85), Vector3(5.8, -2.3, side * 4.85), 0.62, 0.45, 28)
		for sx: float in [-4.0, 0.0, 4.0]:
			m.ring(k, "gunmetal", Vector3(sx, -2.3, side * 4.85), 0.64, 0.05, Vector3.RIGHT, 28, 6)
		m.rod(k, "steel", Vector3(-7.5, 2.7, side * 4.3), Vector3(7.5, 2.7, side * 4.3), 0.09, -1.0, 12)
		m.rod(k, "copper", Vector3(-7.5, 2.4, side * 4.3), Vector3(7.5, 2.4, side * 4.3), 0.06, -1.0, 12)
		# Floodlights over the hold's mouth and landing lamps under it.
		m.box(k, "dark", Vector3(-8.1, 2.6, side * 3.2), Vector3(0.4, 0.4, 0.7), 0.05)
		m.box(k, "lamp", Vector3(-8.32, 2.6, side * 3.2), Vector3(0.04, 0.3, 0.6), 0.02)
		m.box(k, "lamp", Vector3(4.0, -3.24, side * 2.8), Vector3(0.8, 0.06, 0.3), 0.02)
		# Thruster quads at the corners.
		for qx: float in [-7.4, 7.4]:
			var c := Vector3(qx, 2.4, side * 4.55)
			m.box(k, "gunmetal", c, Vector3(0.7, 0.7, 0.5), 0.08)
			for d: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3(signf(qx), 0, 0), Vector3(0, 0, side)]:
				m.rod(k, "dark", c + d * 0.3, c + d * 0.55, 0.08, 0.13, 12)
	# The hold's lamp strips inside, under the roof.
	for side: float in [-1.0, 1.0]:
		m.box(k, "lamp", Vector3(-2.0, 2.9, side * 3.6), Vector3(10.0, 0.1, 0.1), 0.02)
	# The roof: two radiator banks, a dish, a mast with beacons, a walkway rail.
	for rx: float in [-4.5, 1.5]:
		m.box(k, "gunmetal", Vector3(rx, 3.62, 0), Vector3(4.2, 0.24, 5.4), 0.04)
		for f in 14:
			m.box(k, "steel", Vector3(rx - 1.95 + f * 0.3, 3.95, 0), Vector3(0.05, 0.5, 5.2), 0.01)
	m.rod(k, "gunmetal", Vector3(6.2, 3.5, -2.4), Vector3(6.2, 4.6, -2.4), 0.08, -1.0, 12)
	m.rod(k, "plates", Vector3(6.2, 4.6, -2.4), Vector3(5.9, 5.0, -2.4), 0.06, 0.9, 32)
	m.ring(k, "trim", Vector3(5.9, 5.0, -2.4), 0.88, 0.04, Vector3(-0.6, 0.8, 0).normalized(), 32, 6)
	m.rod(k, "dark", Vector3(6.6, 3.5, 2.6), Vector3(6.6, 6.2, 2.6), 0.04, 0.02, 8)
	m.rod(k, "red_lamp", Vector3(6.6, 6.2, 2.6), Vector3(6.6, 6.35, 2.6), 0.08, -1.0, 12)
	for bx: float in [-7.8, 7.6]:
		for side: float in [-1.0, 1.0]:
			m.rod(k, "red_lamp", Vector3(bx, 3.5, side * 3.9), Vector3(bx, 3.68, side * 3.9), 0.07, -1.0, 12)
	# The bulkhead between hold and cab, and the cab: a stepped nose, glazing in frames, a
	# sensor blister, the line's colour round its brow.
	m.box(k, "dark", Vector3(8.05, 0.2, 0), Vector3(0.3, 7.0, 8.6), 0.05)
	m.box(k, "plates", Vector3(10.5, 0.4, 0), Vector3(4.9, 5.4, 6.4), 0.3)
	m.box(k, "plates", Vector3(13.4, -0.2, 0), Vector3(1.6, 3.6, 5.2), 0.4)
	m.box(k, "accent", Vector3(10.6, 2.6, 0), Vector3(5.0, 0.4, 6.5), 0.1)
	m.box(k, "glass", Vector3(13.0, 1.6, 0), Vector3(0.9, 1.3, 4.6), 0.08)
	for gz: float in [-1.55, 0.0, 1.55]:
		m.box(k, "trim", Vector3(13.4, 1.6, gz), Vector3(0.12, 1.4, 0.12), 0.03)
	m.box(k, "trim", Vector3(13.4, 2.28, 0), Vector3(0.14, 0.12, 4.7), 0.03)
	for side: float in [-1.0, 1.0]:
		m.box(k, "glass", Vector3(11.4, 1.6, side * 3.21), Vector3(2.2, 0.9, 0.04), 0.04)
		m.box(k, "lamp", Vector3(14.22, -1.2, side * 1.9), Vector3(0.05, 0.25, 0.6), 0.02)
	m.rod(k, "dark", Vector3(10.0, 3.1, 0), Vector3(10.0, 3.5, 0), 0.7, 0.5, 24)
	m.rod(k, "cyan", Vector3(10.0, 3.5, 0), Vector3(10.0, 3.56, 0), 0.5, 0.36, 24)
	# Engine pylons (the bells are the parts' own engine bells, drawn beside).
	for dz: float in [-2.2, 2.2]:
		m.box(k, "trim", Vector3(13.6, -1.0, dz), Vector3(1.2, 1.2, 1.2), 0.1)
	# The ramp: a ribbed plate with the line's stripe across its top and its hinge.
	var r := "ramp"
	m.box(r, "plates", Vector3(0, 3.0, 0), Vector3(0.25, 6.0, 7.4), 0.05)
	for rz: float in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		m.box(r, "trim", Vector3(-0.17, 3.0, rz), Vector3(0.1, 5.8, 0.18), 0.02)
	m.box(r, "accent", Vector3(-0.15, 5.6, 0), Vector3(0.08, 0.4, 7.42), 0.02)
	m.rod(r, "steel", Vector3(0, 0.0, -3.7), Vector3(0, 0.0, 3.7), 0.14, -1.0, 16)
	return m.meshes()
