extends RefCounted
## TartanCo's robot service ship (0.4.1 playtest: "the name of the company that produces these
## worker robots is TartanCo ... TartanCo arrive in a space ship and perform the maintenance on
## our bots at the yard"), after beenster's sheet: a long segmented hull of white-grey armoured
## modules with yellow bands, a faceted command module at the bow, spare-parts pods along her
## back, three robot service bays amidships behind a side door that lifts, a workshop module,
## and four engines aft in their nacelles. 66 m long. Built in code with YardToolMesh, once
## (the livery is the material).
## Her space: origin at the middle of her service bays' floor, her bow to +X, the bays open to +Z.

const LIVERY := {"id": "tartanco", "plates": Color(0.8, 0.8, 0.78), "trim": Color(0.13, 0.13, 0.15), "accent": Color(0.96, 0.7, 0.1)}
## The bays' opening (along x, high) and where the door lifts to.
const BAYS := Vector2(18.0, 6.0)
const DOOR_LIFT := 6.4
## Her half beam (z) and the hull's top and bottom (y), m.
const HALF_Z := 4.5
const TOP := 7.5
const KEEL := -2.0

static var _meshes: Dictionary = {}
static var _livery: ShaderMaterial


static func meshes() -> Dictionary:
	if _meshes.is_empty():
		_meshes = _build()
	return _meshes


static func livery() -> ShaderMaterial:
	if _livery == null:
		var mat := YardSuitAssets.finish(YardSuitLook.default_look())
		mat.set_shader_parameter("plates", LIVERY.plates)
		mat.set_shader_parameter("trim", LIVERY.trim)
		mat.set_shader_parameter("accent", LIVERY.accent)
		mat.set_shader_parameter("oxygen", Color(0.35, 0.9, 1.0))
		mat.set_shader_parameter("wear", 0.3)
		mat.set_shader_parameter("light_energy", 3.0)
		_livery = mat
	return _livery


## The ship: her hull, her door (a child "Door" that `open_door` lifts), engine glow ("Glow"),
## lamps in her bays and her name down both sides.
static func make() -> Node3D:
	var n := Node3D.new()
	n.name = "TartanCoShip"
	var m := meshes()
	var mat := livery()
	for key: String in ["hull", "door", "glow"]:
		var mi := MeshInstance3D.new()
		mi.name = {"hull": "Hull", "door": "Door", "glow": "Glow"}[key]
		mi.mesh = m[key]
		mi.material_override = mat
		n.add_child(mi)
	for i in 3:
		var lamp := OmniLight3D.new()
		lamp.name = "BayLamp%d" % i
		lamp.position = Vector3(-6.0 + i * 6.0, 4.6, 1.2)
		lamp.light_color = Color(1.0, 0.93, 0.8)
		lamp.light_energy = 0.0
		lamp.omni_range = 8.0
		n.add_child(lamp)
	for side: float in [1.0, -1.0]:
		for t: Array in [["TARTANCO", Vector3(-17.0, 4.2, 0), 0.03], ["ROBOT SERVICE", Vector3(-17.0, 2.4, 0), 0.012],
				["TS-1", Vector3(17.5, 3.6, 0), 0.026]]:
			var tag := Label3D.new()
			tag.text = t[0]
			tag.font_size = 128
			tag.pixel_size = t[2]
			tag.outline_size = 0
			tag.modulate = Color(0.1, 0.1, 0.11)
			tag.position = (t[1] as Vector3) + Vector3(0, 0, side * (HALF_Z + 0.06))
			tag.rotation.y = 0.0 if side > 0.0 else PI
			n.add_child(tag)
	return n


## The door at `open` (0 shut, 1 lifted clear) and her bays lit to match.
static func open_door(ship: Node3D, open: float) -> void:
	(ship.get_node("Door") as Node3D).position.y = DOOR_LIFT * clampf(open, 0.0, 1.0)
	for i in 3:
		(ship.get_node("BayLamp%d" % i) as OmniLight3D).light_energy = 1.6 * clampf(open, 0.0, 1.0)


static func _build() -> Dictionary:
	var m := YardToolMesh.new()
	var k := "hull"
	var hz := HALF_Z
	var mid_y := (TOP + KEEL) * 0.5
	var h := TOP - KEEL
	# The service bays amidships: floor, roof, back wall, frames between the bays, open to +Z.
	var bx := BAYS.x * 0.5
	m.box(k, "trim", Vector3(0, -1.0, 0), Vector3(BAYS.x + 0.6, 2.0, hz * 2.0), 0.1)
	m.box(k, "plates", Vector3(0, BAYS.y + 0.75, 0), Vector3(BAYS.x + 0.6, h - BAYS.y - 2.0 + 0.5, hz * 2.0), 0.2)
	m.box(k, "dark", Vector3(0, BAYS.y * 0.5, -hz + 0.4), Vector3(BAYS.x, BAYS.y, 0.8), 0.05)
	m.box(k, "gunmetal", Vector3(0, 0.02, 0.5), Vector3(BAYS.x, 0.04, hz * 2.0 - 1.0), 0.01)
	for i in 4:
		var x := -bx + i * BAYS.x / 3.0
		m.box(k, "trim", Vector3(x, BAYS.y * 0.5, 0), Vector3(0.5, BAYS.y, hz * 2.0 - 0.2), 0.06)
		m.box(k, "accent", Vector3(x, BAYS.y * 0.5, hz - 0.12), Vector3(0.55, BAYS.y - 0.4, 0.06), 0.02)
	# In each bay: a robot cradle on the transfer rail, two yellow handling arms, screens.
	m.box(k, "steel", Vector3(0, 0.12, -hz + 2.0), Vector3(BAYS.x, 0.16, 0.3), 0.02)
	for i in 3:
		var c := Vector3(-6.0 + i * 6.0, 0, -hz + 2.0)
		m.box(k, "gunmetal", c + Vector3(0, 0.4, 0), Vector3(1.6, 0.5, 1.4), 0.08)
		m.box(k, "dark", c + Vector3(0, 1.8, -0.6), Vector3(1.2, 2.6, 0.3), 0.05)
		for sx: float in [-1.0, 1.0]:
			var base := c + Vector3(sx * 2.2, BAYS.y - 0.2, 0.8)
			var elbow := base + Vector3(sx * 0.2, -1.6, 0.9)
			var tip := elbow + Vector3(-sx * 0.8, -1.2, 0.3)
			m.box(k, "gunmetal", base + Vector3(0, 0.1, 0), Vector3(0.6, 0.2, 0.6), 0.04)
			m.rod(k, "accent", base, elbow, 0.16, 0.14, 14)
			m.rod(k, "dark", elbow - Vector3(0, 0, 0.2), elbow + Vector3(0, 0, 0.2), 0.2, -1.0, 14)
			m.rod(k, "accent", elbow, tip, 0.12, 0.1, 14)
			m.box(k, "dark", tip, Vector3(0.3, 0.3, 0.3), 0.05)
		m.box(k, "cyan", c + Vector3(1.8, 3.4, -1.05), Vector3(1.4, 0.8, 0.04), 0.01)
		m.box(k, "lamp", c + Vector3(0, BAYS.y - 0.08, 2.0), Vector3(3.0, 0.06, 0.4), 0.01)
	# The modules fore and aft of the bays: big armoured boxes, each with yellow bands, panel
	# lines and bolted plates; a faceted command module at the bow.
	var modules := [Vector2(bx + 0.3, bx + 8.0), Vector2(bx + 8.4, bx + 14.0), Vector2(-bx - 8.0, -bx - 0.3), Vector2(-bx - 15.0, -bx - 8.4)]
	for j in modules.size():
		var span: Vector2 = modules[j]
		var c := Vector3((span.x + span.y) * 0.5, mid_y, 0)
		var w := absf(span.y - span.x)
		m.box(k, "plates", c, Vector3(w, h, hz * 2.0), 0.35)
		m.box(k, "trim", c + Vector3(0, 0, 0), Vector3(w + 0.2, h - 1.4, hz * 2.0 + 0.2), 0.2)
		m.box(k, "plates", c + Vector3(0, 0, 0), Vector3(w - 0.4, h - 0.6, hz * 2.0 + 0.5), 0.3)
		m.box(k, "accent", c + Vector3(w * 0.5 - 0.6, 0, 0), Vector3(0.5, h - 0.4, hz * 2.0 + 0.6), 0.05)
		for side: float in [1.0, -1.0]:
			for yy: float in [KEEL + 1.4, TOP - 1.6]:
				m.box(k, "dark", Vector3(c.x, yy, side * (hz + 0.265)), Vector3(w - 0.8, 0.05, 0.02), 0.005)
			for xx: float in [c.x - w * 0.25, c.x + w * 0.25]:
				m.box(k, "dark", Vector3(xx, mid_y, side * (hz + 0.265)), Vector3(0.05, h - 1.0, 0.02), 0.005)
			# Little lit ports.
			for q in 4:
				m.box(k, "accent_light", Vector3(c.x - w * 0.35 + q * w * 0.12, KEEL + 0.8, side * (hz + 0.27)), Vector3(0.3, 0.12, 0.02), 0.01)
		# Spare-parts pods along her back.
		for q in int(w / 3.0):
			var pod := Vector3(span.x + signf(span.y - span.x) * (1.6 + q * 3.0), TOP + 0.9, (q % 2) * 1.6 - 0.8)
			m.box(k, "trim" if q % 2 == 0 else "plates", pod, Vector3(2.4, 1.8, 2.6), 0.15)
			m.box(k, "accent", pod + Vector3(0, 0.92, 0), Vector3(1.6, 0.04, 1.8), 0.02)
	# The command module: a tapering, faceted bow with a lit window band.
	var bow := bx + 14.0
	m.box(k, "plates", Vector3(bow + 3.0, mid_y + 0.2, 0), Vector3(6.0, h - 1.0, hz * 2.0 - 0.6), 0.4)
	m.box(k, "plates", Vector3(bow + 7.0, mid_y + 0.6, 0), Vector3(3.0, h - 3.0, hz * 2.0 - 2.4), 0.5)
	for side: float in [1.0, -1.0]:
		m.box(k, "plates", Vector3(bow + 6.4, mid_y + 0.4, side * (hz - 1.6)), Vector3(4.2, h - 2.4, 1.6), 0.3, Basis(Vector3.UP, side * 0.5))
	m.box(k, "trim", Vector3(bow + 8.6, mid_y + 1.4, 0), Vector3(0.4, 1.6, 4.4), 0.1)
	m.box(k, "cyan", Vector3(bow + 8.82, mid_y + 1.4, 0), Vector3(0.04, 1.0, 3.8), 0.01)
	m.box(k, "accent", Vector3(bow + 5.8, TOP - 0.2, 0), Vector3(1.0, 0.3, 5.0), 0.05)
	# A docking collar under the bow and an external handling arm.
	m.rod(k, "gunmetal", Vector3(bow + 2.0, KEEL, 0), Vector3(bow + 2.0, KEEL - 1.2, 0), 1.3, 1.1, 24)
	m.ring(k, "accent", Vector3(bow + 2.0, KEEL - 1.2, 0), 1.1, 0.12, Vector3.UP, 24, 6)
	# Aft: the engine section and four nacelles with bells.
	var aft := -bx - 15.0
	m.box(k, "trim", Vector3(aft - 3.0, mid_y, 0), Vector3(6.0, h - 1.2, hz * 2.0 - 1.0), 0.3)
	for p: Vector2 in [Vector2(TOP - 0.6, 3.4), Vector2(TOP - 0.6, -3.4), Vector2(KEEL + 0.4, 3.4), Vector2(KEEL + 0.4, -3.4)]:
		var a := Vector3(aft - 1.0, p.x, p.y)
		m.rod(k, "plates", a, a - Vector3(8.0, 0, 0), 1.7, 1.6, 28)
		m.ring(k, "accent", a - Vector3(2.0, 0, 0), 1.72, 0.1, Vector3.RIGHT, 28, 6)
		m.ring(k, "accent", a - Vector3(6.0, 0, 0), 1.65, 0.1, Vector3.RIGHT, 28, 6)
		m.rod(k, "dark", a - Vector3(8.0, 0, 0), a - Vector3(10.0, 0, 0), 1.3, 1.65, 28)
		m.rod("glow", "cyan", a - Vector3(9.9, 0, 0), a - Vector3(10.0, 0, 0), 1.2, -1.0, 24)
	# The door: a ribbed panel over the bays' opening, yellow-edged.
	m.box("door", "plates", Vector3(0, BAYS.y * 0.5, hz + 0.1), Vector3(BAYS.x + 0.4, BAYS.y + 0.2, 0.3), 0.08)
	for i in 6:
		m.box("door", "trim", Vector3(-bx + 1.5 + i * 3.0, BAYS.y * 0.5, hz + 0.27), Vector3(0.2, BAYS.y - 0.4, 0.05), 0.02)
	m.box("door", "accent", Vector3(0, 0.15, hz + 0.27), Vector3(BAYS.x + 0.4, 0.2, 0.06), 0.02)
	return m.meshes()
