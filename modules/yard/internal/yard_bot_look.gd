extends RefCounted
## What the yard's hover bots look like (0.4.1 playtest: "make these a LOT more detailed"):
## a chassis of bevelled plates with panel lines and bolts, a sensor bar with headlamps, four
## ducted fans on struts with guards and spinning rotors, a tractor emitter underneath, a mast
## with a beacon, all built in code with YardToolMesh so they wear the suit's finish
## (player_finish.gdshader) in a livery: BSX's own (orange for the stores, teal for the yard)
## or a freight line's. Meshes are built once and shared.

## A livery: the body's paint (plates), its second colour (trim) and its lamps and stripes
## (accent). Freight lines, each delivery's brand, then BSX's own.
const BRANDS := [
	{"id": "halden", "name": "HALDEN FREIGHT", "plates": Color(0.16, 0.22, 0.36), "trim": Color(0.88, 0.88, 0.86), "accent": Color(1.0, 0.72, 0.15)},
	{"id": "orbis", "name": "ORBIS LOGISTICS", "plates": Color(0.9, 0.9, 0.92), "trim": Color(0.1, 0.42, 0.3), "accent": Color(0.3, 0.95, 0.55)},
	{"id": "vantor", "name": "VANTOR CARGO", "plates": Color(0.52, 0.07, 0.09), "trim": Color(0.14, 0.14, 0.16), "accent": Color(1.0, 0.86, 0.78)},
	{"id": "meridian", "name": "MERIDIAN SUPPLY", "plates": Color(0.86, 0.55, 0.12), "trim": Color(0.12, 0.13, 0.15), "accent": Color(0.3, 0.8, 1.0)},
]
const BSX_STORES := {"id": "bsx", "name": "BSX LTD", "plates": Color(0.9, 0.91, 0.92), "trim": Color(0.2, 0.21, 0.23), "accent": Color(1.0, 0.5, 0.12)}
const BSX_YARD := {"id": "bsx_yard", "name": "BSX LTD", "plates": Color(0.9, 0.91, 0.92), "trim": Color(0.2, 0.21, 0.23), "accent": Color(0.2, 0.85, 0.75)}

## Where the four fans sit (bot space, m).
const FANS := [Vector3(-0.74, 0.02, -0.7), Vector3(0.74, 0.02, -0.7), Vector3(-0.74, 0.02, 0.7), Vector3(0.74, 0.02, 0.7)]
const DUCT_R := 0.3

static var _meshes: Dictionary = {}
static var _liveries: Dictionary = {}


## The bot's meshes: "body" (all that stays still), "rotor" (one fan's blades, at its hub),
## "beacon" (the mast's lamp, flashed while working).
static func meshes() -> Dictionary:
	if _meshes.is_empty():
		_meshes = _build()
	return _meshes


## A livery's material (cached by its id).
static func livery(brand: Dictionary) -> ShaderMaterial:
	var id: String = brand.id
	if not _liveries.has(id):
		var mat := YardSuitAssets.finish(YardSuitLook.default_look())
		mat.set_shader_parameter("plates", brand.plates)
		mat.set_shader_parameter("trim", brand.trim)
		mat.set_shader_parameter("accent", brand.accent)
		mat.set_shader_parameter("oxygen", brand.accent)
		mat.set_shader_parameter("wear", 0.15)
		mat.set_shader_parameter("light_energy", 2.2)
		_liveries[id] = mat
	return _liveries[id]


## A whole bot in `brand`'s livery, numbered `number`: rotors under "Rotor*", its lamp "Beacon".
static func make(brand: Dictionary, number: String) -> Node3D:
	var n := Node3D.new()
	var mat := livery(brand)
	var m := meshes()
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = m.body
	body.material_override = mat
	n.add_child(body)
	for i in FANS.size():
		var r := MeshInstance3D.new()
		r.name = "Rotor%d" % i
		r.mesh = m.rotor
		r.material_override = mat
		r.position = FANS[i] + Vector3(0, -0.01, 0)
		r.rotation.y = float(i) * 0.7
		n.add_child(r)
	var beacon := MeshInstance3D.new()
	beacon.name = "Beacon"
	beacon.mesh = m.beacon
	beacon.material_override = mat
	n.add_child(beacon)
	for side: float in [-1.0, 1.0]:
		var tag := Label3D.new()
		tag.name = "Number"
		tag.text = number
		tag.font_size = 48
		tag.pixel_size = 0.0028
		tag.outline_size = 0
		tag.modulate = Color(0.08, 0.08, 0.09) if (brand.plates as Color).get_luminance() > 0.5 else Color(0.95, 0.95, 0.95)
		tag.position = Vector3(side * 0.462, 0.02, 0.18)
		tag.rotation.y = side * PI * 0.5
		n.add_child(tag)
	return n


## Spins a bot's rotors (fast while it works, idling else) and flashes its beacon.
static func animate(bot: Node3D, delta: float, working: bool) -> void:
	var rate := 38.0 if working else 14.0
	for i in FANS.size():
		var r := bot.get_node_or_null("Rotor%d" % i) as Node3D
		if r:
			r.rotation.y += rate * delta * (1.0 if i % 2 == 0 else -1.0)
	var beacon := bot.get_node_or_null("Beacon") as Node3D
	if beacon:
		beacon.visible = not working or int(Time.get_ticks_msec() / 400) % 2 == 0


static func _build() -> Dictionary:
	var m := YardToolMesh.new()
	# The chassis: a deep lower hull, a raised top shell, skirts in the livery's accent.
	m.box("body", "plates", Vector3(0, 0.0, 0), Vector3(0.9, 0.28, 1.12), 0.045)
	m.box("body", "plates", Vector3(0, 0.19, 0.04), Vector3(0.7, 0.12, 0.82), 0.04)
	m.box("body", "accent", Vector3(0, -0.11, 0), Vector3(0.93, 0.07, 1.15), 0.025)
	m.box("body", "trim", Vector3(0, 0.255, 0.04), Vector3(0.12, 0.02, 0.84), 0.008)
	for side: float in [-1.0, 1.0]:
		m.box("body", "trim", Vector3(side * 0.2, 0.255, 0.04), Vector3(0.05, 0.015, 0.76), 0.006)
		# Side panels: a recessed hatch with its seams, a grab handle, vents.
		m.box("body", "dark", Vector3(side * 0.452, 0.02, -0.18), Vector3(0.006, 0.17, 0.42), 0.002)
		m.box("body", "plates", Vector3(side * 0.454, 0.02, -0.18), Vector3(0.006, 0.15, 0.4), 0.003)
		m.rod("body", "steel", Vector3(side * 0.48, 0.07, -0.33), Vector3(side * 0.48, 0.07, -0.03), 0.012, -1.0, 10)
		for z: float in [-0.33, -0.03]:
			m.rod("body", "steel", Vector3(side * 0.455, 0.07, z), Vector3(side * 0.48, 0.07, z), 0.01, -1.0, 8)
		for k in 5:
			m.box("body", "dark", Vector3(side * 0.452, 0.02, 0.2 + k * 0.05), Vector3(0.008, 0.13, 0.018), 0.002)
		for z: float in [-0.5, 0.5]:
			m.bolt("body", Vector3(side * 0.3, 0.252, z * 0.76 + 0.04), Vector3.UP, 0.012)
	# Panel lines across the top shell.
	for z: float in [-0.22, 0.12, 0.38]:
		m.box("body", "dark", Vector3(0, 0.252, z), Vector3(0.68, 0.006, 0.008), 0.002)
	# The sensor bar at the front (-Z): glass, a lit strip, a headlamp each side.
	m.box("body", "dark", Vector3(0, 0.05, -0.575), Vector3(0.6, 0.13, 0.05), 0.012)
	m.box("body", "glass", Vector3(0, 0.07, -0.6), Vector3(0.44, 0.06, 0.01), 0.004)
	m.box("body", "cyan", Vector3(0, 0.005, -0.602), Vector3(0.4, 0.012, 0.006), 0.002)
	for side: float in [-1.0, 1.0]:
		m.rod("body", "dark", Vector3(side * 0.37, 0.06, -0.56), Vector3(side * 0.37, 0.06, -0.6), 0.045, -1.0, 16)
		m.rod("body", "lamp", Vector3(side * 0.37, 0.06, -0.6), Vector3(side * 0.37, 0.06, -0.607), 0.034, -1.0, 16)
	# The back: status lamps and a cooling grille.
	m.box("body", "dark", Vector3(0, 0.05, 0.57), Vector3(0.5, 0.14, 0.03), 0.01)
	for k in 6:
		m.box("body", "gunmetal", Vector3(-0.2 + k * 0.08, 0.05, 0.587), Vector3(0.05, 0.11, 0.008), 0.002)
	for side: float in [-1.0, 1.0]:
		m.box("body", "red_lamp", Vector3(side * 0.38, 0.06, 0.567), Vector3(0.07, 0.03, 0.01), 0.004)
		m.box("body", "accent_light", Vector3(side * 0.38, 0.0, 0.567), Vector3(0.07, 0.02, 0.01), 0.004)
	# Four ducted fans on struts, each with an inner lip, a guard and a lit rim underneath.
	for f: Vector3 in FANS:
		var corner := Vector3(signf(f.x) * 0.4, 0.0, signf(f.z) * 0.46)
		m.rod("body", "gunmetal", corner, f - (f - corner).normalized() * DUCT_R, 0.04, 0.032, 14)
		m.rod("body", "gunmetal", corner + Vector3(0, 0.09, 0), f - (f - corner).normalized() * DUCT_R + Vector3(0, 0.05, 0), 0.02, -1.0, 10)
		m.rod("body", "plates", f + Vector3(0, -0.08, 0), f + Vector3(0, 0.08, 0), DUCT_R + 0.06, DUCT_R + 0.05, 40)
		m.rod("body", "dark", f + Vector3(0, -0.085, 0), f + Vector3(0, 0.085, 0), DUCT_R + 0.002, -1.0, 40)
		m.ring("body", "trim", f + Vector3(0, 0.082, 0), DUCT_R + 0.03, 0.022, Vector3.UP, 40, 8)
		m.ring("body", "accent_light", f + Vector3(0, -0.085, 0), DUCT_R + 0.035, 0.008, Vector3.UP, 40, 6)
		m.rod("body", "dark", f + Vector3(0, -0.06, 0), f + Vector3(0, 0.02, 0), 0.06, 0.05, 20)
		for a: float in [0.0, PI * 0.5]:
			var d := Vector3(cos(a), 0, sin(a)) * DUCT_R
			m.rod("body", "steel", f - d + Vector3(0, 0.075, 0), f + d + Vector3(0, 0.075, 0), 0.008, -1.0, 8)
		m.ring("body", "steel", f + Vector3(0, 0.075, 0), DUCT_R * 0.55, 0.006, Vector3.UP, 32, 5)
	# Underneath: the tractor emitter, a lens in a ring, and two skid rails.
	m.rod("body", "gunmetal", Vector3(0, -0.14, 0), Vector3(0, -0.2, 0), 0.2, 0.17, 32)
	m.ring("body", "dark", Vector3(0, -0.2, 0), 0.16, 0.02, Vector3.UP, 32, 6)
	m.rod("body", "cyan", Vector3(0, -0.2, 0), Vector3(0, -0.235, 0), 0.13, 0.08, 32)
	for side: float in [-1.0, 1.0]:
		m.box("body", "gunmetal", Vector3(side * 0.3, -0.17, 0), Vector3(0.05, 0.05, 0.9), 0.012)
	# The mast: a short post, an antenna, the beacon (its own piece).
	m.rod("body", "gunmetal", Vector3(0.24, 0.25, 0.32), Vector3(0.24, 0.42, 0.32), 0.02, -1.0, 12)
	m.rod("body", "dark", Vector3(-0.26, 0.25, 0.36), Vector3(-0.26, 0.62, 0.36), 0.006, 0.003, 8)
	m.rod("body", "accent", Vector3(-0.26, 0.62, 0.36), Vector3(-0.26, 0.64, 0.36), 0.012, -1.0, 8)
	m.rod("beacon", "dark", Vector3(0.24, 0.42, 0.32), Vector3(0.24, 0.44, 0.32), 0.04, -1.0, 16)
	m.rod("beacon", "accent_light", Vector3(0.24, 0.44, 0.32), Vector3(0.24, 0.5, 0.32), 0.032, 0.022, 16)
	# A rotor: hub and five blades, pitched.
	m.rod("rotor", "steel", Vector3(0, -0.03, 0), Vector3(0, 0.03, 0), 0.05, 0.04, 20)
	for k in 5:
		var a := TAU * k / 5.0
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.32)
		m.box("rotor", "gunmetal", Basis(Vector3.UP, a) * Vector3(0, 0, -DUCT_R * 0.55), Vector3(0.075, 0.012, DUCT_R * 0.82), 0.004, b)
	return m.meshes()
