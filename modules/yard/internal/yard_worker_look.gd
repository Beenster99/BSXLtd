extends RefCounted
## What the yard's worker bots look like (0.4.1 playtest: "the worker bots who fix the ship up
## should be more functional, android style ... heavy bots with arms which articulate to help
## them do their work, holding objects and welding, riveting or bolting objects in place"):
## a heavy armoured android, one core in three trades, after beenster's reference sheets. A
## chest of layered plates over a ribbed waist, a visored head with stereo lamps, a backpack
## of tanks and reaction-control pods, clamp feet, and two arms of shoulder, upper arm, elbow,
## forearm and a tool on a quick-change wrist: W-3 the welder (a gimballed torch), R-3 the
## riveter (a rivet gun with its drum magazine) and F-3 the fitter (two grippers). The arms
## reach with two-bone IK (`reach`), so a tool tip goes where the work is. Built in code with
## YardToolMesh so they wear the suit's finish in BSX's yard livery; meshes built once, shared.

## TartanCo makes them (0.4.1 playtest): white-grey plates, near-black trim, yellow accents.
## TartanCo's own field engineers, who come out to service them, wear charcoal and red.
const LIVERY := {"id": "tartanco_worker", "plates": Color(0.84, 0.84, 0.82), "trim": Color(0.1, 0.1, 0.11), "accent": Color(0.96, 0.7, 0.1)}
const ENGINEER := {"id": "tartanco_engineer", "plates": Color(0.24, 0.25, 0.27), "trim": Color(0.08, 0.08, 0.09), "accent": Color(0.78, 0.12, 0.1)}
const MAKER := "TARTANCO"

## Each trade: its chest code, the tool on each wrist and its livery. E is TartanCo's engineer.
const ROLES := {
	"F": {"code": "F-3", "right": "gripper", "left": "gripper", "livery": LIVERY},
	"W": {"code": "W-3", "right": "torch", "left": "gripper", "livery": LIVERY},
	"R": {"code": "R-3", "right": "rivet_gun", "left": "gripper", "livery": LIVERY},
	"E": {"code": "TC-E", "right": "torch", "left": "gripper", "livery": ENGINEER},
}
## The right shoulder (worker space, m; the left mirrors it), the arm's bones and each tool's
## reach from the wrist to its tip.
const SHOULDER := Vector3(0.66, 0.86, -0.04)
const UPPER := 0.62
const FORE := 0.58
const TOOL_LEN := {"torch": 0.48, "rivet_gun": 0.64, "gripper": 0.36}
## Where the welder's umbilical leaves the backpack (worker space) and how many links it has.
const HOSE_PORT := Vector3(0.36, 0.92, 0.56)
const HOSE_LINKS := 7

static var _meshes: Dictionary = {}
static var _liveries: Dictionary = {}
static var _hose_mesh: CylinderMesh


static func meshes() -> Dictionary:
	if _meshes.is_empty():
		_meshes = _build()
	return _meshes


static func livery(brand: Dictionary = LIVERY) -> ShaderMaterial:
	var id: String = brand.id
	if not _liveries.has(id):
		var mat := YardSuitAssets.finish(YardSuitLook.default_look())
		mat.set_shader_parameter("plates", brand.plates)
		mat.set_shader_parameter("trim", brand.trim)
		mat.set_shader_parameter("accent", brand.accent)
		mat.set_shader_parameter("oxygen", Color(0.35, 0.9, 1.0))
		mat.set_shader_parameter("wear", 0.35)
		mat.set_shader_parameter("light_energy", 2.4)
		_liveries[id] = mat
	return _liveries[id]


## A worker of trade `role` ("F", "W" or "R"), numbered `number`. Its arms' parts are children
## named Upper/Fore/Hand + R or L, placed by `reach` and `rest` in global space each frame
## (call `rest` once it is in the tree).
static func make(role: String, number: String) -> Node3D:
	var spec: Dictionary = ROLES[role]
	var mat := livery(spec.livery)
	var m := meshes()
	var n := Node3D.new()
	n.set_meta("role", role)
	_mesh(n, "Body", m.body, mat)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.06, -0.02)
	n.add_child(head)
	_mesh(head, "HeadMesh", m.head, mat)
	var thrust := _mesh(n, "Thrust", m.thrust, mat)
	thrust.visible = false
	for side: String in ["R", "L"]:
		_mesh(n, "Upper" + side, m.upper, mat)
		_mesh(n, "Fore" + side, m.fore, mat)
		var tool: String = spec.right if side == "R" else spec.left
		var hand := _mesh(n, "Hand" + side, m[tool], mat)
		hand.set_meta("tool", tool)
	# Its code and number on the chest, the maker's name on the backpack and a shoulder (a
	# label reads from its +Z: the chest's is turned to face forward, -Z).
	var dark := (spec.livery.plates as Color).get_luminance() < 0.5
	var ink := Color(0.95, 0.95, 0.95) if dark else Color(0.08, 0.08, 0.09)
	for t: Array in [["%s\n%s" % [spec.code, number], Vector3(0, 0.72, -0.37), PI, 0.0034],
			[MAKER, Vector3(0, 0.78, 0.627), 0.0, 0.0018], [MAKER, Vector3(0.66 + 0.22, 0.9, -0.04), PI * 0.5, 0.0012],
			[MAKER, Vector3(-0.66 - 0.22, 0.9, -0.04), -PI * 0.5, 0.0012]]:
		var tag := Label3D.new()
		tag.name = "Code" if t[0] != MAKER else "Maker"
		tag.text = t[0]
		tag.font_size = 64
		tag.pixel_size = t[3]
		tag.outline_size = 0
		tag.line_spacing = -18.0
		tag.modulate = ink
		tag.position = t[1]
		tag.rotation.y = t[2]
		n.add_child(tag)
	# A fault lamp on the head and its readout over it, shown while it has an error.
	var fault := Label3D.new()
	fault.name = "Fault"
	fault.text = "ERROR"
	fault.font_size = 64
	fault.pixel_size = 0.004
	fault.outline_size = 10
	fault.modulate = Color(1.0, 0.25, 0.2)
	fault.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fault.no_depth_test = true
	fault.position = Vector3(0, 1.75, 0)
	fault.visible = false
	n.add_child(fault)
	if role == "W":
		if _hose_mesh == null:
			_hose_mesh = CylinderMesh.new()
			_hose_mesh.top_radius = 0.035
			_hose_mesh.bottom_radius = 0.035
			_hose_mesh.height = 1.0
			_hose_mesh.radial_segments = 10
			_hose_mesh.rings = 1
			var hm := StandardMaterial3D.new()
			hm.albedo_color = Color(0.06, 0.06, 0.07)
			hm.roughness = 0.6
			_hose_mesh.material = hm
		for i in HOSE_LINKS:
			var link := MeshInstance3D.new()
			link.name = "Hose%d" % i
			link.mesh = _hose_mesh
			n.add_child(link)
	return n


static func _mesh(parent: Node3D, name: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func tool_of(w: Node3D, side: String) -> String:
	var hand := w.get_node_or_null("Hand" + side)
	return String(hand.get_meta("tool", "gripper")) if hand else "gripper"


## The shoulder's centre in global space.
static func shoulder(w: Node3D, side: String) -> Vector3:
	var s := SHOULDER if side == "R" else Vector3(-SHOULDER.x, SHOULDER.y, SHOULDER.z)
	return w.global_transform * s


## Puts the arm's tool tip at `tip` (global), the tool pointing along `approach` (into the work):
## the hand turned to it, the wrist behind it, elbow and shoulder by two-bone IK with the elbow
## out and down. `kick` pulls the tool back along its line (m): the rivet gun's recoil.
static func reach(w: Node3D, side: String, tip: Vector3, approach: Vector3, kick := 0.0) -> void:
	var dir := approach.normalized() if approach.length() > 0.001 else -w.global_basis.z
	var wrist := tip - dir * (float(TOOL_LEN[tool_of(w, side)]) + kick)
	var sx := 1.0 if side == "R" else -1.0
	var b := w.global_basis.orthonormalized()
	var pole := (b.x * sx * 0.6 - b.y * 0.7 + b.z * 0.25).normalized()
	var s := shoulder(w, side)
	var to := wrist - s
	var d := clampf(to.length(), 0.08, UPPER + FORE - 0.002)
	var along := to.normalized() if to.length() > 0.001 else -b.y
	wrist = s + along * d
	var x := (UPPER * UPPER - FORE * FORE + d * d) / (2.0 * d)
	var h := sqrt(maxf(UPPER * UPPER - x * x, 0.0))
	var bend := (pole - along * pole.dot(along))
	bend = bend.normalized() if bend.length() > 0.001 else b.z
	var elbow := s + along * x + bend * h
	_bone(w.get_node("Upper" + side), s, elbow, b.x * sx)
	_bone(w.get_node("Fore" + side), elbow, wrist, b.x * sx)
	_bone(w.get_node("Hand" + side), wrist, wrist + dir, bend)


## The arm at rest: hanging, forearm forward, tool down and ahead.
static func rest(w: Node3D, side: String) -> void:
	var sx := 1.0 if side == "R" else -1.0
	var tip := w.global_transform * Vector3(sx * 0.62, -0.1, -0.85)
	reach(w, side, tip, w.global_basis * Vector3(0, -0.6, -0.8).normalized())


## The tool tip's place now (global).
static func tip_of(w: Node3D, side: String) -> Vector3:
	var hand := w.get_node("Hand" + side) as Node3D
	return hand.global_transform * Vector3(0, -float(TOOL_LEN[tool_of(w, side)]), 0)


## A bone whose mesh hangs along its -Y from its origin: placed at `from`, -Y towards `to`, its
## z turned towards `pole`.
static func _bone(node: Node3D, from: Vector3, to: Vector3, pole: Vector3) -> void:
	var y := from - to
	y = y.normalized() if y.length() > 0.0001 else Vector3.UP
	var z := pole - y * pole.dot(y)
	if z.length() < 0.001:
		z = y.cross(Vector3.RIGHT) if absf(y.x) < 0.9 else y.cross(Vector3.FORWARD)
	z = z.normalized()
	var x := y.cross(z)
	node.global_transform = Transform3D(Basis(x, y, z), from)


## Lays the welder's umbilical from the backpack to its torch's wrist: a sagging curve of links.
static func lay_hose(w: Node3D) -> void:
	if not w.has_node("Hose0"):
		return
	var a := w.global_transform * HOSE_PORT
	var hand := w.get_node("HandR") as Node3D
	var b := hand.global_transform * Vector3(0, -0.12, 0.06)
	var c := (a + b) * 0.5 + w.global_basis * Vector3(0.35, -0.55, 0.2)
	var prev := a
	for i in HOSE_LINKS:
		var t := float(i + 1) / HOSE_LINKS
		var p := a.lerp(c, t).lerp(c.lerp(b, t), t)
		var link := w.get_node("Hose%d" % i) as Node3D
		var len := prev.distance_to(p)
		var mid := (prev + p) * 0.5
		var y := (p - prev).normalized() if len > 0.001 else Vector3.UP
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		link.global_transform = Transform3D(Basis(x, y, x.cross(y)).scaled(Vector3(1, len + 0.02, 1)), mid)
		prev = p


static func _build() -> Dictionary:
	var m := YardToolMesh.new()
	_body(m)
	_head(m)
	_arm(m)
	_torch(m)
	_rivet_gun(m)
	_gripper(m)
	# Reaction-control flames: four pods on the backpack's corners, firing back and down.
	for p: Vector3 in [Vector3(0.46, 1.02, 0.5), Vector3(-0.46, 1.02, 0.5), Vector3(0.46, 0.2, 0.5), Vector3(-0.46, 0.2, 0.5)]:
		m.rod("thrust", "cyan", p + Vector3(0, 0, 0.12), p + Vector3(0, 0, 0.42), 0.05, 0.005, 12)
		m.rod("thrust", "lamp", p + Vector3(0, 0, 0.12), p + Vector3(0, 0, 0.24), 0.03, 0.004, 10)
	return m.meshes()


## Pelvis, waist, chest, shoulders' armour, backpack and the legs in a hovering stance.
static func _body(m: YardToolMesh) -> void:
	# Pelvis and hips.
	m.box("body", "plates", Vector3(0, -0.08, 0), Vector3(0.62, 0.24, 0.46), 0.05)
	m.box("body", "accent", Vector3(0, -0.08, -0.235), Vector3(0.3, 0.16, 0.02), 0.01)
	m.box("body", "trim", Vector3(0, 0.07, 0), Vector3(0.66, 0.05, 0.5), 0.015)
	# The waist: ribbed and dark, a pivot under the chest.
	m.rod("body", "gunmetal", Vector3(0, 0.08, 0), Vector3(0, 0.36, 0), 0.24, 0.27, 28)
	for k in 5:
		m.ring("body", "dark", Vector3(0, 0.12 + k * 0.055, 0), 0.25 + k * 0.004, 0.012, Vector3.UP, 28, 6)
	# The chest: a deep core, then the plates layered over it.
	m.box("body", "trim", Vector3(0, 0.66, 0.02), Vector3(0.98, 0.66, 0.66), 0.06)
	m.box("body", "plates", Vector3(0, 0.7, -0.29), Vector3(0.82, 0.52, 0.1), 0.05)
	m.box("body", "plates", Vector3(0, 0.44, -0.27), Vector3(0.64, 0.16, 0.1), 0.04)
	m.box("body", "plates", Vector3(0.43, 0.62, 0.02), Vector3(0.12, 0.5, 0.56), 0.04)
	m.box("body", "plates", Vector3(-0.43, 0.62, 0.02), Vector3(0.12, 0.5, 0.56), 0.04)
	m.box("body", "accent", Vector3(0.33, 0.92, -0.33), Vector3(0.14, 0.1, 0.03), 0.012)
	m.box("body", "accent", Vector3(-0.33, 0.92, -0.33), Vector3(0.14, 0.1, 0.03), 0.012)
	m.box("body", "dark", Vector3(0, 0.98, -0.3), Vector3(0.4, 0.05, 0.06), 0.012)
	# Panel lines and bolts across the chest plates.
	for y: float in [0.56, 0.86]:
		m.box("body", "dark", Vector3(0, y, -0.343), Vector3(0.7, 0.006, 0.006), 0.002)
	for p: Vector3 in [Vector3(0.36, 0.5, -0.345), Vector3(-0.36, 0.5, -0.345), Vector3(0.36, 0.88, -0.345), Vector3(-0.36, 0.88, -0.345)]:
		m.bolt("body", p, Vector3.FORWARD, 0.012)
	# Collar and neck.
	m.rod("body", "dark", Vector3(0, 0.96, -0.02), Vector3(0, 1.08, -0.02), 0.13, 0.1, 20)
	m.ring("body", "gunmetal", Vector3(0, 0.99, -0.02), 0.2, 0.03, Vector3.UP, 24, 6)
	# Shoulder armour each side: a big pauldron with its accent edge, over a joint housing.
	for sx: float in [1.0, -1.0]:
		var s := Vector3(SHOULDER.x * sx, SHOULDER.y, SHOULDER.z)
		m.rod("body", "dark", s - Vector3(sx * 0.16, 0, 0), s + Vector3(sx * 0.02, 0, 0), 0.15, -1.0, 24)
		m.box("body", "plates", s + Vector3(sx * 0.02, 0.17, 0), Vector3(0.36, 0.16, 0.48), 0.05)
		m.box("body", "plates", s + Vector3(sx * 0.16, 0.04, 0), Vector3(0.1, 0.24, 0.44), 0.035)
		m.box("body", "accent", s + Vector3(sx * 0.02, 0.26, 0), Vector3(0.3, 0.025, 0.42), 0.01)
		m.box("body", "dark", s + Vector3(sx * 0.215, 0.04, 0), Vector3(0.012, 0.16, 0.3), 0.004)
		# A hip joint and the leg: thigh forward, knee bent, shin back, a clamp foot.
		var hip := Vector3(sx * 0.24, -0.16, 0.0)
		var knee := Vector3(sx * 0.29, -0.66, -0.2)
		var ankle := Vector3(sx * 0.3, -1.12, 0.02)
		m.rod("body", "dark", hip - Vector3(sx * 0.12, 0, 0), hip + Vector3(sx * 0.1, 0, 0), 0.12, -1.0, 20)
		m.rod("body", "gunmetal", hip, knee, 0.1, 0.085, 18)
		m.box("body", "plates", (hip + knee) * 0.5 + Vector3(0, 0, -0.06), Vector3(0.24, 0.36, 0.16), 0.04, _along(knee - hip))
		m.box("body", "accent", (hip + knee) * 0.5 + Vector3(0, 0.02, -0.15), Vector3(0.14, 0.16, 0.02), 0.008, _along(knee - hip))
		m.rod("body", "dark", knee - Vector3(sx * 0.11, 0, 0), knee + Vector3(sx * 0.11, 0, 0), 0.11, -1.0, 20)
		m.box("body", "plates", knee + Vector3(0, 0.0, -0.1), Vector3(0.18, 0.16, 0.06), 0.03)
		m.rod("body", "gunmetal", knee, ankle, 0.085, 0.07, 18)
		m.box("body", "plates", (knee + ankle) * 0.5 + Vector3(0, 0, -0.07), Vector3(0.22, 0.38, 0.14), 0.04, _along(ankle - knee))
		m.box("body", "dark", (knee + ankle) * 0.5 + Vector3(0, 0, 0.07), Vector3(0.12, 0.3, 0.06), 0.02, _along(ankle - knee))
		m.rod("body", "dark", ankle - Vector3(sx * 0.09, 0, 0), ankle + Vector3(sx * 0.09, 0, 0), 0.08, -1.0, 16)
		m.box("body", "trim", ankle + Vector3(0, -0.1, -0.06), Vector3(0.26, 0.1, 0.44), 0.03)
		m.box("body", "accent", ankle + Vector3(0, -0.07, -0.25), Vector3(0.24, 0.07, 0.06), 0.015)
		for k in 3:
			m.box("body", "gunmetal", ankle + Vector3((k - 1) * 0.08, -0.16, -0.25), Vector3(0.05, 0.06, 0.1), 0.01)
		m.rod("body", "steel", ankle + Vector3(0, -0.155, 0.08), ankle + Vector3(0, -0.175, 0.08), 0.07, -1.0, 16)
	# The backpack: a frame, two tanks, a power pack, RCS pods at its corners, a work lamp.
	m.box("body", "gunmetal", Vector3(0, 0.62, 0.44), Vector3(0.78, 0.86, 0.24), 0.04)
	m.box("body", "plates", Vector3(0, 0.62, 0.58), Vector3(0.36, 0.7, 0.08), 0.03)
	m.box("body", "accent", Vector3(0, 0.95, 0.625), Vector3(0.3, 0.06, 0.012), 0.005)
	for sx: float in [1.0, -1.0]:
		m.rod("body", "steel", Vector3(sx * 0.27, 0.24, 0.62), Vector3(sx * 0.27, 0.98, 0.62), 0.11, -1.0, 20)
		m.rod("body", "dark", Vector3(sx * 0.27, 0.98, 0.62), Vector3(sx * 0.27, 1.04, 0.62), 0.05, -1.0, 12)
		m.ring("body", "accent", Vector3(sx * 0.27, 0.42, 0.62), 0.112, 0.012, Vector3.UP, 20, 5)
		for y: float in [1.02, 0.2]:
			var pod := Vector3(sx * 0.46, y, 0.5)
			m.box("body", "trim", pod, Vector3(0.16, 0.16, 0.18), 0.03)
			m.rod("body", "dark", pod + Vector3(0, 0, 0.09), pod + Vector3(0, 0, 0.14), 0.05, 0.06, 12)
			m.rod("body", "dark", pod + Vector3(sx * 0.08, 0, 0), pod + Vector3(sx * 0.13, 0, 0), 0.04, 0.05, 12)
	m.box("body", "trim", Vector3(0.36, 0.92, 0.56), Vector3(0.1, 0.1, 0.1), 0.02)
	# Status lamps down the backpack's edge.
	for k in 3:
		m.box("body", "accent_light", Vector3(-0.392, 0.5 + k * 0.08, 0.4), Vector3(0.006, 0.04, 0.05), 0.002)


## The head: a helmet block, its visor with two lamps, sensor pods each side, an antenna.
static func _head(m: YardToolMesh) -> void:
	m.box("head", "plates", Vector3(0, 0.14, 0.02), Vector3(0.38, 0.3, 0.4), 0.06)
	m.box("head", "accent", Vector3(0, 0.3, 0.0), Vector3(0.26, 0.04, 0.3), 0.015)
	m.box("head", "dark", Vector3(0, 0.12, -0.185), Vector3(0.32, 0.13, 0.04), 0.02)
	m.box("head", "glass", Vector3(0, 0.12, -0.207), Vector3(0.28, 0.08, 0.01), 0.004)
	for sx: float in [1.0, -1.0]:
		m.rod("head", "lamp", Vector3(sx * 0.08, 0.12, -0.2), Vector3(sx * 0.08, 0.12, -0.215), 0.026, -1.0, 14)
		m.rod("head", "gunmetal", Vector3(sx * 0.19, 0.14, 0.02), Vector3(sx * 0.25, 0.14, 0.02), 0.07, 0.06, 16)
		m.rod("head", "cyan", Vector3(sx * 0.25, 0.14, 0.02), Vector3(sx * 0.255, 0.14, 0.02), 0.035, -1.0, 12)
	m.box("head", "dark", Vector3(0, 0.02, -0.12), Vector3(0.22, 0.06, 0.12), 0.015)
	m.rod("head", "dark", Vector3(-0.13, 0.28, 0.14), Vector3(-0.13, 0.5, 0.16), 0.008, 0.004, 8)
	m.rod("head", "red_lamp", Vector3(-0.13, 0.5, 0.16), Vector3(-0.13, 0.52, 0.16), 0.014, -1.0, 8)


## One arm's two bones, each hanging along -Y from its joint (mirrors as it is).
static func _arm(m: YardToolMesh) -> void:
	m.rod("upper", "gunmetal", Vector3.ZERO, Vector3(0, -UPPER, 0), 0.085, 0.075, 18)
	m.box("upper", "plates", Vector3(0, -0.28, -0.02), Vector3(0.24, 0.36, 0.22), 0.045)
	m.box("upper", "accent", Vector3(0, -0.2, -0.135), Vector3(0.16, 0.12, 0.02), 0.008)
	m.box("upper", "dark", Vector3(0.125, -0.3, -0.02), Vector3(0.012, 0.24, 0.14), 0.004)
	m.rod("upper", "dark", Vector3(-0.12, -UPPER, 0), Vector3(0.12, -UPPER, 0), 0.1, -1.0, 20)
	m.ring("upper", "steel", Vector3(0.122, -UPPER, 0), 0.07, 0.012, Vector3.RIGHT, 18, 5)
	m.rod("fore", "gunmetal", Vector3.ZERO, Vector3(0, -FORE, 0), 0.075, 0.065, 18)
	m.box("fore", "plates", Vector3(0, -0.26, -0.01), Vector3(0.26, 0.4, 0.24), 0.05)
	m.box("fore", "accent", Vector3(0, -0.34, -0.135), Vector3(0.2, 0.14, 0.02), 0.008)
	m.box("fore", "trim", Vector3(0, -0.12, 0.12), Vector3(0.14, 0.12, 0.04), 0.012)
	m.rod("fore", "dark", Vector3(0, -0.47, 0), Vector3(0, -FORE, 0), 0.085, -1.0, 18)
	m.ring("fore", "accent", Vector3(0, -FORE + 0.01, 0), 0.085, 0.01, Vector3.UP, 20, 5)


## W-3's torch: a quick-change block, the gun body, a gimbal ring, a copper nozzle; the arc's tip
## at -TOOL_LEN.torch.
static func _torch(m: YardToolMesh) -> void:
	var tl: float = TOOL_LEN.torch
	m.box("torch", "trim", Vector3(0, -0.05, 0), Vector3(0.16, 0.1, 0.16), 0.02)
	m.rod("torch", "dark", Vector3(0, -0.08, 0), Vector3(0, -0.28, 0), 0.055, 0.045, 18)
	m.ring("torch", "accent", Vector3(0, -0.18, 0), 0.07, 0.016, Vector3.UP, 20, 6)
	m.rod("torch", "steel", Vector3(0, -0.28, 0), Vector3(0, -0.34, 0), 0.04, 0.034, 16)
	m.rod("torch", "copper", Vector3(0, -0.34, 0), Vector3(0, -tl + 0.02, 0), 0.03, 0.016, 16)
	m.rod("torch", "lamp", Vector3(0, -tl + 0.02, 0), Vector3(0, -tl, 0), 0.012, 0.006, 10)
	m.rod("torch", "dark", Vector3(0, -0.1, 0.06), Vector3(0, -0.02, 0.1), 0.03, -1.0, 10)


## R-3's rivet gun: a heavy barrel with its muzzle, the drum magazine on its side with a feed
## belt, a force-sensing collar.
static func _rivet_gun(m: YardToolMesh) -> void:
	var tl: float = TOOL_LEN.rivet_gun
	m.box("rivet_gun", "trim", Vector3(0, -0.05, 0), Vector3(0.18, 0.1, 0.18), 0.02)
	m.rod("rivet_gun", "gunmetal", Vector3(0, -0.08, 0), Vector3(0, -0.46, 0), 0.095, 0.085, 22)
	for k in 4:
		m.ring("rivet_gun", "dark", Vector3(0, -0.14 - k * 0.07, 0), 0.098, 0.01, Vector3.UP, 22, 5)
	m.box("rivet_gun", "accent", Vector3(0, -0.3, -0.09), Vector3(0.1, 0.16, 0.02), 0.006)
	m.rod("rivet_gun", "dark", Vector3(0, -0.46, 0), Vector3(0, -0.52, 0), 0.07, -1.0, 18)
	m.rod("rivet_gun", "steel", Vector3(0, -0.52, 0), Vector3(0, -tl, 0), 0.05, 0.04, 18)
	m.ring("rivet_gun", "steel", Vector3(0, -tl + 0.01, 0), 0.05, 0.008, Vector3.UP, 18, 5)
	m.rod("rivet_gun", "dark", Vector3(0.17, -0.22, -0.065), Vector3(0.17, -0.22, 0.065), 0.15, -1.0, 28)
	m.ring("rivet_gun", "accent", Vector3(0.17, -0.22, -0.068), 0.15, 0.014, Vector3.BACK, 28, 5)
	m.rod("rivet_gun", "steel", Vector3(0.17, -0.22, -0.07), Vector3(0.17, -0.22, -0.075), 0.05, -1.0, 14)
	for k in 6:
		m.box("rivet_gun", "brass", Vector3(0.09 - k * 0.0, -0.33 - k * 0.025, 0.0), Vector3(0.04, 0.018, 0.09), 0.004)
	m.rod("rivet_gun", "red_lamp", Vector3(-0.09, -0.4, -0.04), Vector3(-0.1, -0.4, -0.04), 0.012, -1.0, 8)


## F-3's gripper: a wrist block, a palm and two jaws with yellow pads, an alignment laser.
static func _gripper(m: YardToolMesh) -> void:
	m.box("gripper", "trim", Vector3(0, -0.05, 0), Vector3(0.16, 0.1, 0.16), 0.02)
	m.box("gripper", "gunmetal", Vector3(0, -0.14, 0), Vector3(0.26, 0.1, 0.14), 0.025)
	for sx: float in [1.0, -1.0]:
		m.box("gripper", "dark", Vector3(sx * 0.1, -0.25, 0), Vector3(0.05, 0.16, 0.1), 0.012)
		m.box("gripper", "accent", Vector3(sx * 0.085, -0.33, 0), Vector3(0.03, 0.08, 0.1), 0.008)
		m.rod("gripper", "steel", Vector3(sx * 0.13, -0.14, -0.07), Vector3(sx * 0.13, -0.14, 0.07), 0.025, -1.0, 12)
	m.rod("gripper", "red_lamp", Vector3(0, -0.19, -0.07), Vector3(0, -0.19, -0.08), 0.012, -1.0, 8)


## A basis that turns a box's y onto `dir`.
static func _along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := Vector3.RIGHT - y * y.x
	x = x.normalized()
	return Basis(x, y, x.cross(y))
