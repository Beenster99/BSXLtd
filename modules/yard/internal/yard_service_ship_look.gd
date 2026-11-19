extends RefCounted
## TartanCo's robot service ship, TS-1 (beenster's sheet of 19 Nov: "this is what a TartanCo
## maintenance ship looks like"): a long hull of white-grey blocks with safety-yellow trim and
## dark frame rings, a tapered command nose with its windscreen band, a parts store with pods on
## top and a docking collar, three robot service bays open down her starboard side behind
## roller shutters (each with a cradle, a jointed handling arm on a roof rail, consoles and a
## tool bench, a transfer rail along the deck), a workshop and test labs with lit windows,
## engineering aft, four engine pods and a main engine. 78 m long, in TartanCo's livery: white
## over grey, yellow, and the firm's own tartan. Built in code with tartanco_mesh.gd, once.
##
## The ship node's space (what YardService flies): origin at the middle bay's deck, her bow to
## +X, the bays open to +Z. Her model is drawn in its own space (bow -Z, bays open +X, the
## bays' deck at DECK_Y) and turned into it by MODEL.

const Kit := preload("res://modules/yard/internal/tartanco_mesh.gd")

const LENGTH := 78.0
const BEAM := 12.0
const DECK_Y := -3.0
const ROOF_Y := 4.6
const OPEN_X := 6.0
## The three service bays' centres along the model's z (each BAY_LEN long).
const BAYS := [-5.0, 3.0, 11.0]
const BAY_LEN := 8.0
## The bay's cradle: where a bot stands to be worked on (model space off the bay's centre).
const CRADLE := Vector3(-1.4, 0.0, 0.0)
## Where the handling arm hangs from its roof rail (model space off the bay's centre).
const ARM_BASE := Vector3(-2.6, ROOF_Y - 0.2, 2.4)
## The model in the ship node's space: bow -Z to +X, bays +X to +Z, the middle bay's deck on
## the origin.
const MODEL := Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(3.0, 3.0, 0.0))
## The engines' nozzles (model space): position, radius.
const NOZZLES := [
	[Vector3(7.6, 4.8, 38.6), 1.5], [Vector3(-7.6, 4.8, 38.6), 1.5],
	[Vector3(7.6, -3.6, 38.6), 1.5], [Vector3(-7.6, -3.6, 38.6), 1.5],
	[Vector3(0.0, 0.6, 34.6), 2.2],
]
## Running lights: position, stock.
const NAV_LIGHTS := [
	[Vector3(-6.4, 0.6, -24.0), "red_lamp"], [Vector3(6.4, 0.6, -24.0), "green_lamp"],
	[Vector3(0.0, 9.2, 22.0), "lamp"], [Vector3(-9.9, 0.6, 30.0), "red_lamp"], [Vector3(9.9, 0.6, 30.0), "green_lamp"],
]

static var _meshes: Dictionary = {}
static var _plume: StandardMaterial3D


## "hull" (all that stays still), "shutter" (one bay's roller door, hanging from its top edge
## at the origin), and the handling arm's parts from their joints: "arm" (the trolley),
## "arm_upper", "arm_fore", "arm_head".
static func meshes() -> Dictionary:
	if _meshes.is_empty():
		_meshes = _build()
	return _meshes


## The ship: "Model" (her hull, "Shutter<i>" over each bay, "Arm<i>" in each, "BayLamp<i>",
## her name), and "Glow" (her engines' plumes, shown while she flies).
static func make() -> Node3D:
	var n := Node3D.new()
	n.name = "TartanCoShip"
	var model := Node3D.new()
	model.name = "Model"
	model.transform = MODEL
	n.add_child(model)
	var m := meshes()
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = m.hull
	model.add_child(hull)
	for i in BAYS.size():
		var bz: float = BAYS[i]
		var sh := MeshInstance3D.new()
		sh.name = "Shutter%d" % i
		sh.mesh = m.shutter
		sh.position = Vector3(OPEN_X + 0.1, ROOF_Y, bz)
		model.add_child(sh)
		model.add_child(_make_arm(i, m))
		var lamp := OmniLight3D.new()
		lamp.name = "BayLamp%d" % i
		lamp.position = Vector3(0.5, ROOF_Y - 1.0, bz)
		lamp.light_color = Color(1.0, 0.95, 0.85)
		lamp.omni_range = 8.0
		lamp.light_energy = 0.0
		model.add_child(lamp)
		var num := Label3D.new()
		num.text = "BAY %d" % (i + 1)
		num.font_size = 96
		num.pixel_size = 0.008
		num.outline_size = 0
		num.modulate = Color(0.08, 0.08, 0.09)
		num.position = Vector3(OPEN_X + 0.05, ROOF_Y + 2.1, bz)
		num.rotation.y = PI * 0.5
		model.add_child(num)
	# Her name down her port side and under the bays, the yard's ships' way.
	for t: Array in [["TARTANCO", Vector3(-6.36, 3.2, 3.0), 0.04, -1.0], ["ROBOT SERVICE", Vector3(-6.36, 1.6, 3.0), 0.016, -1.0],
			["TARTANCO", Vector3(6.3, 2.2, 21.0), 0.022, 1.0], ["TS-1", Vector3(5.56, 3.6, -27.0), 0.02, 1.0],
			["TS-1", Vector3(-5.56, 3.6, -27.0), 0.02, -1.0]]:
		var tag := Label3D.new()
		tag.text = t[0]
		tag.font_size = 128
		tag.pixel_size = t[2]
		tag.outline_size = 0
		tag.modulate = Color(0.08, 0.08, 0.09)
		tag.position = t[1]
		tag.rotation.y = PI * 0.5 * float(t[3])
		if t[0] == "TARTANCO" and float(t[3]) > 0.0:
			tag.position.x = 6.36
		model.add_child(tag)
	var glow := Node3D.new()
	glow.name = "Glow"
	model.add_child(glow)
	for nz: Array in NOZZLES:
		var plume := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = float(nz[1]) * 0.9
		cone.bottom_radius = 0.05
		cone.height = float(nz[1]) * 7.0
		cone.radial_segments = 16
		cone.rings = 1
		cone.cap_top = false
		cone.cap_bottom = false
		plume.mesh = cone
		plume.material_override = _plume_material()
		plume.rotation.x = PI * 0.5
		plume.position = (nz[0] as Vector3) + Vector3(0, 0, cone.height * 0.5)
		plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.add_child(plume)
	return n


static func _make_arm(i: int, m: Dictionary) -> Node3D:
	var arm := Node3D.new()
	arm.name = "Arm%d" % i
	arm.position = ARM_BASE + Vector3(0, 0, BAYS[i])
	var a := MeshInstance3D.new()
	a.mesh = m.arm
	arm.add_child(a)
	var up := Node3D.new()
	up.name = "Upper"
	up.position = Vector3(0, -0.45, 0)
	arm.add_child(up)
	var ui := MeshInstance3D.new()
	ui.mesh = m.arm_upper
	up.add_child(ui)
	var fo := Node3D.new()
	fo.name = "Fore"
	fo.position = Vector3(0, -2.0, 0)
	up.add_child(fo)
	var fi := MeshInstance3D.new()
	fi.mesh = m.arm_fore
	fo.add_child(fi)
	var hd := Node3D.new()
	hd.name = "Head"
	hd.position = Vector3(0, -1.7, 0)
	fo.add_child(hd)
	var hi := MeshInstance3D.new()
	hi.mesh = m.arm_head
	hd.add_child(hi)
	pose_arm_local(arm, 0.0, 0.0)
	return arm


## Bay `i`'s arm: `work` 0 parked up under the roof, 1 down over the cradle; `t` (s) sways it
## across the bot while it works.
static func pose_arm(ship: Node3D, i: int, work: float, t: float) -> void:
	pose_arm_local(ship.get_node("Model/Arm%d" % i) as Node3D, work, t)


static func pose_arm_local(arm: Node3D, work: float, t: float) -> void:
	var k := clampf(work, 0.0, 1.0)
	arm.rotation.y = lerpf(0.0, 0.35 * sin(t * 0.9), k)
	(arm.get_node("Upper") as Node3D).rotation.x = lerpf(1.35, 0.55 + 0.12 * sin(t * 1.7), k)
	(arm.get_node("Upper/Fore") as Node3D).rotation.x = lerpf(-2.6, -1.25 + 0.2 * sin(t * 2.3), k)


## Where bay `i`'s arm's tool is now (global).
static func arm_tip(ship: Node3D, i: int) -> Vector3:
	var head := ship.get_node("Model/Arm%d/Upper/Fore/Head" % i) as Node3D
	return head.global_transform * Vector3(0, -0.75, 0)


## The shutters at `open` (0 down, 1 rolled up) and the bays lit to match.
static func open_door(ship: Node3D, open: float) -> void:
	var k := clampf(open, 0.0, 1.0)
	for i in BAYS.size():
		var sh := ship.get_node("Model/Shutter%d" % i) as Node3D
		sh.scale.y = lerpf(1.0, 0.05, k)
		sh.visible = k < 0.999
		(ship.get_node("Model/BayLamp%d" % i) as OmniLight3D).light_energy = 1.8 * k


## Where a bot stands in bay `i`'s cradle (ship node space; facing out of the bay is +Z).
static func cradle(i: int) -> Vector3:
	return MODEL * (CRADLE + Vector3(0, DECK_Y + 0.3, BAYS[i]))


## Just outside bay `i`'s open side (ship node space), where the way in starts.
static func bay_mouth(i: int) -> Vector3:
	return MODEL * Vector3(OPEN_X + 2.5, DECK_Y + 1.6, BAYS[i])


## Where an engineer waits aboard in bay `i` (ship node space), by its consoles.
static func berth_spot(i: int) -> Vector3:
	return MODEL * Vector3(2.6, DECK_Y + 0.95, float(BAYS[i]) + 2.2)


static func _plume_material() -> StandardMaterial3D:
	if _plume == null:
		_plume = StandardMaterial3D.new()
		_plume.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_plume.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_plume.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_plume.cull_mode = BaseMaterial3D.CULL_DISABLED
		_plume.albedo_color = Color(0.45, 0.7, 1.0, 0.35)
	return _plume


static func _build() -> Dictionary:
	var m := Kit.new()
	_nose(m)
	_parts_store(m)
	_service_bays(m)
	_workshop(m)
	_engineering(m)
	_engines(m)
	_details(m)
	_modules(m)
	_shutter(m)
	_arm(m)
	return m.meshes()


static func _nose(m) -> void:
	var k := "hull"
	var c := Vector2(0, 0.6)
	# The tapered nose, its windscreen band, the command block.
	m.section(k, "paint", c, -39.0, Vector2(1.6, 1.4), -35.0, Vector2(3.6, 3.0), 0.35)
	m.section(k, "dark", c, -35.0, Vector2(3.6, 3.0), -33.6, Vector2(4.3, 3.7), 0.35, false)
	m.section(k, "glass", c + Vector2(0, 0.05), -34.9, Vector2(3.65, 3.05), -33.7, Vector2(4.3, 3.7), 0.35, false)
	m.section(k, "paint", c, -33.6, Vector2(4.3, 3.7), -30.5, Vector2(5.5, 4.8), 0.32)
	m.section(k, "paint", c, -30.5, Vector2(5.5, 4.8), -21.5, Vector2(5.5, 4.8), 0.32)
	# Yellow chevrons on the nose's flanks.
	for s: float in [-1.0, 1.0]:
		m.box(k, "yellow", Vector3(s * 4.95, 0.6, -32.0), Vector3(0.12, 3.2, 1.2), 0.03, Basis(Vector3.UP, s * 0.36))
		m.box(k, "yellow", Vector3(s * 5.56, 0.6, -29.6), Vector3(0.08, 4.2, 0.6), 0.02)
		# Command deck windows down each side, and the tartan band under them.
		for i in 5:
			m.box(k, "window", Vector3(s * 5.53, 2.2, -29.0 + i * 1.5), Vector3(0.08, 0.7, 1.1), 0.02)
		m.box(k, "tartan", Vector3(s * 5.52, 0.4, -25.8), Vector3(0.06, 1.4, 8.0), 0.01)
		m.box(k, "dark", Vector3(s * 5.54, -0.4, -25.8), Vector3(0.05, 0.12, 8.0), 0.01)
	# Panel lines round the command block.
	for z: float in [-27.5, -24.0]:
		m.section(k, "panel", c, z - 0.06, Vector2(5.56, 4.86), z + 0.06, Vector2(5.56, 4.86), 0.32, false)
	# The neck to the stores: a dark truss core with yellow frames.
	m.box(k, "dark", Vector3(0, 0.6, -19.8), Vector3(5.0, 5.0, 3.6), 0.1)
	for z: float in [-21.0, -18.6]:
		m.box(k, "gunmetal", Vector3(0, 0.6, z), Vector3(8.0, 7.0, 0.4), 0.08)
	for s: float in [-1.0, 1.0]:
		m.bar(k, "yellow", Vector3(s * 3.8, -2.6, -21.0), Vector3(s * 3.8, 3.8, -18.6), 0.3)
		m.bar(k, "yellow", Vector3(s * 3.8, 3.8, -21.0), Vector3(s * 3.8, -2.6, -18.6), 0.3)
		m.cylinder(k, "steel", Vector3(s * 1.6, -2.4, -19.8), 3.6, 0.35)
		m.cylinder(k, "steel", Vector3(s * 1.6, 3.6, -19.8), 3.6, 0.35)


static func _parts_store(m) -> void:
	var k := "hull"
	m.box(k, "paint", Vector3(0, 0.6, -13.5), Vector3(12.4, 10.6, 9.0), 0.5)
	# Panel seams and the yellow corner guards.
	for z: float in [-15.5, -11.5]:
		m.box(k, "panel", Vector3(0, 0.6, z), Vector3(12.46, 10.66, 0.1), 0.45)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			m.box(k, "yellow", Vector3(sx * 5.9, 0.6 + sy * 4.9, -13.5), Vector3(0.9, 1.0, 9.1), 0.2)
	# The parts pods on top, each with its hatch and a lamp.
	for i in 3:
		var z := -16.4 + i * 2.9
		for s: float in [-1.0, 1.0]:
			var at := Vector3(s * 2.9, 7.1, z)
			m.box(k, "panel", at, Vector3(4.4, 2.4, 2.4), 0.2)
			m.box(k, "yellow", at + Vector3(s * 2.22, 0.3, 0), Vector3(0.06, 0.5, 2.0), 0.02)
			m.box(k, "dark", at + Vector3(0, 1.22, 0), Vector3(3.6, 0.06, 1.8), 0.02)
	# The docking collar on her port side, and the inventory bay's door.
	m.cylinder(k, "dark", Vector3(-6.9, 0.6, -13.5), 1.4, 2.0, 2.0, 20, Basis(Vector3.UP, PI * 0.5))
	m.cylinder(k, "yellow", Vector3(-7.7, 0.6, -13.5), 0.3, 2.15, 2.15, 20, Basis(Vector3.UP, PI * 0.5))
	m.cylinder(k, "gunmetal", Vector3(-7.85, 0.6, -13.5), 0.1, 1.5, 1.5, 20, Basis(Vector3.UP, PI * 0.5))
	m.box(k, "dark", Vector3(6.24, 0.0, -13.5), Vector3(0.1, 5.0, 5.0), 0.05)
	m.box(k, "yellow", Vector3(6.28, 0.0, -13.5), Vector3(0.06, 5.2, 0.3), 0.02)
	# The handling arm folded under her (for work outside).
	var base := Vector3(1.0, -4.8, -12.0)
	m.cylinder(k, "dark", base, 0.8, 1.0, 1.0, 14, Basis(Vector3.RIGHT, PI * 0.5))
	m.bar(k, "yellow", base + Vector3(0, -0.5, 0), base + Vector3(-2.5, -1.4, -4.0), 0.55)
	m.bar(k, "yellow", base + Vector3(-2.5, -1.4, -4.0), base + Vector3(-0.8, -1.9, -7.0), 0.45)
	m.ball(k, "dark", base + Vector3(-2.5, -1.4, -4.0), Vector3(0.45, 0.45, 0.45))
	m.box(k, "gunmetal", base + Vector3(-0.8, -2.1, -7.4), Vector3(1.0, 0.7, 1.2), 0.1)


static func _service_bays(m) -> void:
	var k := "hull"
	var z0: float = BAYS[0] - BAY_LEN * 0.5
	var z1: float = BAYS[BAYS.size() - 1] + BAY_LEN * 0.5
	var zc := (z0 + z1) * 0.5
	var zl := z1 - z0
	# Deck, keel, roof, top hull, back wall.
	m.box(k, "grey", Vector3(0, DECK_Y - 0.6, zc), Vector3(BEAM, 1.2, zl), 0.1)
	m.box(k, "paint", Vector3(-0.4, DECK_Y - 2.4, zc), Vector3(BEAM - 1.6, 2.4, zl - 0.6), 0.6)
	m.box(k, "grey", Vector3(0, ROOF_Y + 0.6, zc), Vector3(BEAM, 1.2, zl), 0.1)
	m.box(k, "paint", Vector3(-0.3, ROOF_Y + 2.1, zc), Vector3(BEAM - 0.8, 1.8, zl - 0.4), 0.5)
	m.box(k, "panel", Vector3(-5.5, 0.8, zc), Vector3(0.6, ROOF_Y - DECK_Y, zl), 0.05)
	m.box(k, "paint", Vector3(-6.0, 0.8, zc), Vector3(0.6, ROOF_Y - DECK_Y + 2.2, zl), 0.25)
	# Her port side outside: ribs, the tartan band and her name.
	for i in 7:
		m.box(k, "grey", Vector3(-6.35, 0.8, z0 + 2.0 + i * 3.33), Vector3(0.2, 9.0, 0.5), 0.05)
	m.box(k, "tartan", Vector3(-6.32, -1.2, zc), Vector3(0.06, 1.6, zl - 1.0), 0.01)
	m.box(k, "yellow", Vector3(-6.33, -0.25, zc), Vector3(0.05, 0.2, zl - 1.0), 0.01)
	# The deck: tread plate, the transfer rail and the yellow hazard edge down the open side.
	m.box(k, "dark", Vector3(0.2, DECK_Y + 0.01, zc), Vector3(BEAM - 1.6, 0.02, zl - 0.4), 0.0)
	for x: float in [0.9, 2.1]:
		m.box(k, "steel", Vector3(x, DECK_Y + 0.08, zc), Vector3(0.18, 0.16, zl - 0.6), 0.03)
	m.box(k, "yellow", Vector3(1.5, DECK_Y + 0.03, zc), Vector3(0.8, 0.04, zl - 0.6), 0.0)
	var z := z0 + 0.25
	var stripe := false
	while z < z1 - 0.2:
		m.box(k, "yellow" if stripe else "dark", Vector3(OPEN_X - 0.25, DECK_Y + 0.04, z + 0.25), Vector3(0.5, 0.06, 0.5), 0.0)
		m.box(k, "yellow" if not stripe else "dark", Vector3(OPEN_X - 0.25, ROOF_Y - 0.04, z + 0.25), Vector3(0.5, 0.06, 0.5), 0.0)
		stripe = not stripe
		z += 0.5
	# Frames between and at the ends of the bays: a column at the open side, a partition.
	var frames: Array = [z0]
	for i in BAYS.size():
		frames.append(float(BAYS[i]) + BAY_LEN * 0.5)
	for fz: float in frames:
		var end := is_equal_approx(fz, z0) or is_equal_approx(fz, z1)
		m.box(k, "yellow", Vector3(OPEN_X - 0.4, 0.8, fz), Vector3(0.8, ROOF_Y - DECK_Y, 0.8), 0.12)
		for y in range(0, 8, 2):
			m.box(k, "dark", Vector3(OPEN_X - 0.4, DECK_Y + 0.5 + y, fz), Vector3(0.84, 0.5, 0.84), 0.0)
		if end:
			m.box(k, "paint", Vector3(0, 0.8, fz), Vector3(BEAM, ROOF_Y - DECK_Y + 1.0, 0.6), 0.1)
		else:
			m.box(k, "panel", Vector3(-3.0, 0.8, fz), Vector3(5.0, ROOF_Y - DECK_Y, 0.3), 0.05)
			m.box(k, "gunmetal", Vector3(1.5, ROOF_Y - 0.4, fz), Vector3(8.0, 0.8, 0.5), 0.05)
	# In each bay: the cradle a bot stands in, consoles, ceiling lamps, the arm's rail.
	for bz: float in BAYS:
		var c := Vector3(CRADLE.x, DECK_Y, bz)
		m.box(k, "gunmetal", c + Vector3(0, 0.12, 0), Vector3(2.6, 0.24, 2.6), 0.06)
		m.box(k, "yellow", c + Vector3(0, 0.25, 0), Vector3(2.0, 0.04, 2.0), 0.0)
		for s: float in [-1.0, 1.0]:
			m.box(k, "gunmetal", c + Vector3(-1.1, 2.0, s * 1.2), Vector3(0.3, 4.0, 0.3), 0.05)
			m.bar(k, "yellow", c + Vector3(-1.1, 2.9, s * 1.2), c + Vector3(-0.2, 2.9, s * 0.7), 0.16)
			m.box(k, "dark", c + Vector3(-0.15, 2.9, s * 0.62), Vector3(0.3, 0.5, 0.18), 0.04)
		m.box(k, "gunmetal", c + Vector3(-1.1, 4.1, 0), Vector3(0.4, 0.3, 2.8), 0.05)
		# Consoles on the back wall, a bench of tools.
		m.box(k, "gunmetal", Vector3(-5.0, 1.2 + DECK_Y + 2.0, bz + 2.6), Vector3(0.3, 1.4, 2.0), 0.04)
		m.box(k, "screen", Vector3(-4.84, 1.25 + DECK_Y + 2.0, bz + 2.6), Vector3(0.02, 1.1, 1.7), 0.0)
		m.box(k, "screen", Vector3(-4.84, DECK_Y + 2.4, bz - 2.6), Vector3(0.02, 0.8, 1.2), 0.0)
		m.box(k, "grey", Vector3(-4.6, DECK_Y + 0.5, bz - 2.6), Vector3(1.4, 1.0, 2.2), 0.05)
		m.box(k, "dark", Vector3(-4.6, DECK_Y + 1.02, bz - 2.6), Vector3(1.4, 0.04, 2.2), 0.0)
		for i in 3:
			m.box(k, "yellow", Vector3(-4.3, DECK_Y + 1.14, bz - 3.3 + i * 0.7), Vector3(0.5, 0.2, 0.25), 0.03)
		for lx: float in [-3.0, 0.5, 3.8]:
			m.box(k, "lamp", Vector3(lx, ROOF_Y - 0.03, bz), Vector3(0.5, 0.06, BAY_LEN - 2.0), 0.0)
		m.box(k, "steel", Vector3(ARM_BASE.x, ROOF_Y - 0.08, bz), Vector3(0.5, 0.16, BAY_LEN - 1.2), 0.03)


static func _workshop(m) -> void:
	var k := "hull"
	m.box(k, "paint", Vector3(0, 0.6, 21.0), Vector3(12.6, 10.6, 12.0), 0.5)
	for z: float in [17.6, 24.4]:
		m.box(k, "panel", Vector3(0, 0.6, z), Vector3(12.66, 10.66, 0.1), 0.45)
	for sx: float in [-1.0, 1.0]:
		m.box(k, "yellow", Vector3(sx * 6.0, -4.1, 21.0), Vector3(0.9, 0.9, 12.1), 0.2)
	# The workshop and labs' lit windows on her open side; the tartan band to port.
	for row in 2:
		for i in 4:
			var at := Vector3(6.31, -1.6 + row * 3.2, 16.6 + i * 2.9)
			m.box(k, "dark", at, Vector3(0.06, 1.9, 2.3), 0.02)
			m.box(k, "window", at + Vector3(0.02, 0, 0), Vector3(0.04, 1.6, 2.0), 0.0)
	m.box(k, "tartan", Vector3(-6.31, 1.2, 21.0), Vector3(0.06, 2.0, 10.4), 0.01)
	m.box(k, "yellow", Vector3(-6.32, 0.1, 21.0), Vector3(0.05, 0.2, 10.4), 0.01)
	# A row of radiators and boxes on her back.
	for i in 4:
		m.box(k, "panel", Vector3(-2.4 + (i % 2) * 4.8, 6.6, 17.6 + (i / 2) * 5.6), Vector3(3.6, 1.6, 3.8), 0.2)
	m.box(k, "gunmetal", Vector3(0, 6.3, 21.0), Vector3(1.2, 1.0, 11.0), 0.1)


static func _engineering(m) -> void:
	var k := "hull"
	var c := Vector2(0, 0.6)
	m.section(k, "paint", c, 27.0, Vector2(5.8, 5.0), 31.5, Vector2(5.2, 4.6), 0.32)
	m.section(k, "dark", c, 31.5, Vector2(4.4, 4.0), 32.6, Vector2(3.4, 3.2), 0.32)
	m.box(k, "yellow", Vector3(0, 5.25, 29.0), Vector3(4.0, 0.2, 3.0), 0.05)
	# The main engine's bell and its glow.
	m.cylinder(k, "gunmetal", Vector3(0, 0.6, 33.6), 2.0, 1.8, 2.6, 20)
	m.cylinder(k, "glow", Vector3(0, 0.6, 34.55), 0.06, 2.2, 2.2, 20)
	# Pylons out to the engine pods.
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var y := 0.6 + sy * 4.2
			m.bar(k, "gunmetal", Vector3(sx * 4.6, 0.6 + sy * 2.4, 27.8), Vector3(sx * 6.0, y, 26.8), 0.9)
			m.bar(k, "gunmetal", Vector3(sx * 4.6, 0.6 + sy * 2.4, 31.0), Vector3(sx * 6.0, y, 32.0), 0.9)
			m.bar(k, "yellow", Vector3(sx * 4.0, 0.6 + sy * 1.6, 29.4), Vector3(sx * 6.0, y, 29.4), 0.5)


static func _engines(m) -> void:
	var k := "hull"
	for n: Array in NOZZLES:
		var at: Vector3 = n[0]
		if absf(at.x) < 1.0:
			continue
		var p := Vector3(at.x, at.y, 0)
		m.cylinder(k, "paint", p + Vector3(0, 0, 21.4), 2.4, 1.0, 2.2, 18)
		m.cylinder(k, "paint", p + Vector3(0, 0, 29.0), 12.8, 2.3, 2.3, 18)
		for bz: float in [24.4, 33.4]:
			m.cylinder(k, "yellow", p + Vector3(0, 0, bz), 1.2, 2.36, 2.36, 18)
		m.cylinder(k, "dark", p + Vector3(0, 0, 26.6), 0.4, 2.34, 2.34, 18)
		m.cylinder(k, "dark", p + Vector3(0, 0, 35.9), 0.6, 2.3, 2.1, 18)
		m.cylinder(k, "gunmetal", p + Vector3(0, 0, 37.3), 2.4, 1.5, 2.0, 18)
		m.cylinder(k, "glow", p + Vector3(0, 0, 38.4), 0.05, 1.6, 1.6, 18)
		# Ribs along the pod.
		for i in 4:
			var t := TAU * (float(i) + 0.5) / 4.0
			m.box(k, "grey", p + Vector3(cos(t) * 2.28, sin(t) * 2.28, 29.0), Vector3(0.3, 0.3, 8.0), 0.05, Basis(Vector3.BACK, t))


static func _details(m) -> void:
	var k := "hull"
	# The dish and masts on the command block.
	m.cylinder(k, "gunmetal", Vector3(0, 5.9, -26.0), 1.4, 0.15)
	m.cylinder(k, "steel", Vector3(0, 6.8, -26.0), 0.25, 1.4, 0.2, 16, Basis(Vector3.RIGHT, -PI * 0.5 + 0.3))
	m.bar(k, "steel", Vector3(2.5, 5.4, -28.0), Vector3(2.5, 8.6, -28.0), 0.08)
	m.bar(k, "steel", Vector3(-2.2, 5.4, -23.5), Vector3(-2.2, 7.6, -23.5), 0.08)
	m.bar(k, "steel", Vector3(0, 7.2, 21.0), Vector3(0, 9.1, 22.0), 0.1)
	for l: Array in NAV_LIGHTS:
		m.ball(k, l[1], l[0], Vector3(0.18, 0.18, 0.18), 4, 8)
	# Floodlights along the bays' head, aimed out of the open side.
	for bz: float in BAYS:
		for dz: float in [-2.4, 2.4]:
			m.box(k, "gunmetal", Vector3(OPEN_X + 0.15, ROOF_Y + 0.9, bz + dz), Vector3(0.5, 0.5, 0.9), 0.08)
			m.box(k, "lamp", Vector3(OPEN_X + 0.42, ROOF_Y + 0.9, bz + dz), Vector3(0.04, 0.36, 0.7), 0.0)
	# Thruster quads at her corners.
	for at: Vector3 in [Vector3(5.2, 5.0, -22.5), Vector3(-5.2, 5.0, -22.5), Vector3(5.2, -3.8, -22.5), Vector3(-5.2, -3.8, -22.5),
			Vector3(6.0, 5.4, 26.0), Vector3(-6.0, 5.4, 26.0), Vector3(6.0, -4.2, 26.0), Vector3(-6.0, -4.2, 26.0)]:
		m.box(k, "gunmetal", at, Vector3(0.9, 0.9, 0.9), 0.1)
		m.cylinder(k, "dark", at + Vector3(signf(at.x) * 0.55, 0, 0), 0.3, 0.22, 0.3, 8, Basis(Vector3.UP, PI * 0.5))


static func _modules(m) -> void:
	# The sheet's busy outline: dark frame rings between her blocks, humped modules along her
	# back and keel, service boxes down her port side.
	var k := "hull"
	for z: float in [-30.6, -21.4, -9.2, 15.2, 26.9]:
		m.box(k, "dark", Vector3(0, 0.7, z), Vector3(13.4, 11.6, 0.7), 0.3)
		m.box(k, "gunmetal", Vector3(0, 0.7, z), Vector3(13.0, 11.2, 1.2), 0.3)
		for s: float in [-1.0, 1.0]:
			m.box(k, "yellow", Vector3(s * 6.6, 0.7, z), Vector3(0.3, 2.4, 1.0), 0.05)
	var back := [[-6.0, 2.6, 3.2], [-1.0, 3.4, 2.8], [4.6, 2.8, 3.0], [10.4, 3.2, 2.6], [19.0, 2.2, 3.4], [23.6, 2.8, 2.4]]
	for b: Array in back:
		var z: float = b[0]
		var at := Vector3(-1.2 if int(z) % 2 == 0 else 1.0, ROOF_Y + 3.0 + float(b[2]) * 0.5, z)
		if z > 15.0:
			at.y = 5.9 + float(b[2]) * 0.5
		m.box(k, "panel", at, Vector3(6.0, b[2], b[1] * 1.4), 0.3)
		m.box(k, "dark", at + Vector3(0, float(b[2]) * 0.5 + 0.02, 0), Vector3(4.6, 0.05, float(b[1]) * 1.1), 0.0)
		m.box(k, "yellow", at + Vector3(3.02, 0, 0), Vector3(0.06, 0.3, float(b[1]) * 1.2), 0.01)
	for z: float in [-15.0, -12.0, 18.5, 23.5]:
		m.box(k, "panel", Vector3(0, -5.6, z), Vector3(7.0, 2.2, 2.4), 0.25)
		m.box(k, "dark", Vector3(0, -6.72, z), Vector3(5.0, 0.05, 1.8), 0.0)
	for z: float in [-6.0, 0.0, 6.0, 12.0]:
		m.box(k, "grey", Vector3(-6.9, -3.2, z), Vector3(1.4, 2.2, 4.4), 0.2)
		m.box(k, "yellow", Vector3(-7.62, -3.2, z), Vector3(0.05, 0.25, 3.6), 0.01)
		m.box(k, "grey", Vector3(-6.9, 4.4, z + 1.5), Vector3(1.2, 1.6, 2.8), 0.2)
	# Pipes along her flanks.
	for y: float in [-4.6, 5.9]:
		m.cylinder(k, "steel", Vector3(-6.5, y, 3.0), 34.0, 0.18)
		m.cylinder(k, "gunmetal", Vector3(6.4, y + (0.6 if y > 0.0 else -0.4), 3.0), 34.0, 0.16)


static func _shutter(m) -> void:
	# One bay's roller door: slats hanging down from the origin (its top edge), facing +X.
	var k := "shutter"
	var h := ROOF_Y - DECK_Y
	var y := 0.0
	var i := 0
	while y < h - 0.01:
		m.box(k, "panel" if i % 2 == 0 else "grey", Vector3(0, -y - 0.2, 0), Vector3(0.12, 0.4, BAY_LEN - 0.9), 0.03)
		y += 0.4
		i += 1
	m.box(k, "yellow", Vector3(0.07, -h + 0.25, 0), Vector3(0.06, 0.5, BAY_LEN - 0.9), 0.01)
	m.box(k, "tartan", Vector3(0.07, -h * 0.45, 0), Vector3(0.04, 1.2, BAY_LEN - 2.0), 0.0)


static func _arm(m) -> void:
	# The handling arm in three parts, each from its own joint: the base on its trolley turns
	# about Y; the upper arm hangs from the shoulder; the forearm from the elbow; the head.
	m.box("arm", "gunmetal", Vector3(0, 0.0, 0), Vector3(0.9, 0.4, 1.2), 0.08)
	m.cylinder("arm", "dark", Vector3(0, -0.45, 0), 0.6, 0.38, 0.38, 14, Basis(Vector3.RIGHT, PI * 0.5))
	m.box("arm_upper", "yellow", Vector3(0, -1.0, 0), Vector3(0.42, 2.0, 0.42), 0.08)
	m.cylinder("arm_upper", "dark", Vector3(0, 0, 0), 0.6, 0.3, 0.3, 12, Basis(Vector3.UP, PI * 0.5))
	m.box("arm_fore", "yellow", Vector3(0, -0.85, 0), Vector3(0.34, 1.7, 0.34), 0.07)
	m.cylinder("arm_fore", "dark", Vector3(0, 0, 0), 0.5, 0.26, 0.26, 12, Basis(Vector3.UP, PI * 0.5))
	m.box("arm_head", "gunmetal", Vector3(0, -0.2, 0), Vector3(0.36, 0.4, 0.36), 0.05)
	m.cylinder("arm_head", "steel", Vector3(0, -0.55, 0), 0.4, 0.08, 0.03, 8, Basis(Vector3.RIGHT, PI * 0.5))
	m.box("arm_head", "screen", Vector3(0, -0.3, -0.19), Vector3(0.14, 0.08, 0.01), 0.0)
