extends Node3D
## A BSX RF-2 refurbisher (and the bigger RF-2H that works the heavy stand), BSX's own work drone
## (beenster, 20 Nov: "they are not part of TartanCo - BSX owns them", with a reference picture
## to raise their fidelity to). A hovering salvage drone in weathered cream paint with BSX's red
## stripe over a domed hood; under the hood's lip a big camera eye in a brass-ringed housing and
## amber lamps; a riveted body with armour side plates, vents and a hazard strip; twin ducted
## thruster pods on gimbals either side, their turbines glowing blue and spinning up with the
## thrust; a scrap rack on its back with carry handles and a load of offcut plates; the charge
## pad it docks up into its charger with; hoses and cables everywhere; and two articulated arms
## in worn yellow sleeves: a screw vice that clamps the part it carries and a tool arm whose head
## changes with the stage (scanner, nut runner, pressure-washer lance, welding torch, test
## probe, cut-off grinder). The RF-2H is the same drone bigger, with a second stripe and hazard
## sleeves. Built with RefurbMesh: a few meshes, one surface per paint. Presentation only: the
## works moves it to the RefurbWorks state each frame.

const Paint := preload("res://modules/refurb/internal/refurb_paint.gd")
const Kit := preload("res://modules/refurb/internal/refurb_mesh.gd")
## The drone's meshes are built this much bigger (finer weathering; RefurbMesh.grain).
const GRAIN := 5.0

const TOOLS: PackedStringArray = ["scanner", "nut_runner", "blaster", "welder", "probe", "cutter"]
const SHOULDER_R := Vector3(0.3, -0.24, -0.16)
const SHOULDER_L := Vector3(-0.3, -0.24, -0.16)
const UPPER := 0.5
const FORE := 0.5
## Drawn this much bigger than its parts are listed (a 1.4 m drone; the RF-2H 1.8 m).
const SIZE := 1.4
const HEAVY_SIZE := 1.8
## The thruster pods: their middle (x either side) and radius.
const POD_AT := Vector3(0.62, 0.02, -0.04)
const POD_R := 0.17
## Where each tool's working tip is, along its head (-Z).
const TIP := {"scanner": 0.13, "nut_runner": 0.27, "blaster": 0.34, "welder": 0.27, "probe": 0.26, "cutter": 0.25}
## BSX's livery on the drones: cream, worn, with a red stripe.
const CREAM := Color(0.76, 0.71, 0.6)
const STRIPE := Color(0.6, 0.19, 0.14)
const SLEEVE := Color(0.84, 0.58, 0.08)
const DARK := Color(0.15, 0.15, 0.16)

static var _mats: Dictionary = {}

var serial := ""
var tool := ""
var heavy := false
var size := SIZE
## Where the tool's tip is (global), for effects.
var tip := Vector3.ZERO
## Which way the tool works (global, unit), for effects.
var tip_dir := Vector3.FORWARD
## The camera eye's lens (global): the inspection's scan beams come from it.
var eye := Vector3.ZERO
## Where the tool's head points (global; INF: straight on along the forearm). The pressure
## washer's lance turns at the wrist to point its jet at the part.
var aim_point := Vector3.INF

var _arm_r: Node3D
var _arm_l: Node3D
var _fore_r: Node3D
var _fore_l: Node3D
var _jaw: Node3D
var _heads: Dictionary = {}
var _disc: Node3D
var _charge_bar: MeshInstance3D
var _charge_mat: StandardMaterial3D
var _rotors: Array[Node3D] = []
var _glow_mat: StandardMaterial3D
var _antenna_lamp: StandardMaterial3D
var _bob := 0.0
var _spin := 0.0
var _thrust := 0.0
var _heading := Basis()
var _pitch := 0.0


## A weathered paint: the salvage surface's own wear (chipped paint, bare metal, rust) at `wear`.
static func worn(c: Color, wear: float, finish := "satin_paint", metal := 0.1, rough := 0.55) -> ShaderMaterial:
	var key := "%s/%s/%s" % [c.to_html(), wear, finish]
	if not _mats.has(key):
		var m := Paint.paint(c, metal, rough, finish).duplicate() as ShaderMaterial
		m.set_shader_parameter("condition", Vector4(wear, 0.0, 3.0, float(_mats.size()) * 0.37))
		_mats[key] = m
	return _mats[key]


static func glass(c: Color) -> StandardMaterial3D:
	var key := "glass/" + c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = 0.35
		m.roughness = 0.04
		m.clearcoat_enabled = true
		m.clearcoat = 1.0
		m.rim_enabled = true
		m.rim = 0.6
		m.rim_tint = 0.8
		m.emission_enabled = true
		m.emission = Color(c.r * 0.5, c.g * 0.3, c.b * 0.9)
		m.emission_energy_multiplier = 0.6
		_mats[key] = m
	return _mats[key]


static func _kit() -> Kit:
	var k := Kit.new()
	k.grain = GRAIN
	return k


func build(serial_no: String, is_heavy := false) -> void:
	serial = serial_no
	heavy = is_heavy
	size = HEAVY_SIZE if heavy else SIZE
	name = ("RF2H_" if heavy else "RF2_") + serial_no.get_slice("/", 1)
	var cream := worn(CREAM, 0.5)
	var stripe := worn(STRIPE, 0.62)
	var dark := worn(DARK, 0.45, "gunmetal", 0.7, 0.5)
	var steel := worn(Paint.STEEL, 0.55, "brushed_steel", 0.8, 0.35)
	var brass := worn(Color(0.72, 0.56, 0.3), 0.3, "brass", 0.8, 0.35)
	var rubber := Paint.paint(Color(0.07, 0.07, 0.07), 0.0, 0.9, "satin_paint")
	var hazard := Paint.paint(Paint.HAZARD, 0.1, 0.6, "hazard_stripes")
	var amber := Paint.glow(Color(1.0, 0.62, 0.18), 4.0)
	var k := _kit()
	var Z := Basis(Vector3.RIGHT, PI * 0.5)    # a cylinder along Z
	var X := Basis(Vector3.FORWARD, PI * 0.5)  # a cylinder along X

	# The body: a riveted chamfered box, a neck under the hood, armour side plates with vents
	# and a hazard strip, a belly plate.
	k.box(cream, Vector3(0.66, 0.4, 0.78), Transform3D(Basis(), Vector3(0, -0.04, 0.02)), 0.06)
	k.box(dark, Vector3(0.44, 0.2, 0.36), Transform3D(Basis(), Vector3(0, 0.2, -0.13)), 0.03)
	for s: float in [-1.0, 1.0]:
		k.box(cream, Vector3(0.05, 0.28, 0.44), Transform3D(Basis(), Vector3(s * 0.348, -0.02, -0.07)), 0.018)
		for v in 4:
			k.box(dark, Vector3(0.012, 0.028, 0.16), Transform3D(Basis(), Vector3(s * 0.377, 0.07 - v * 0.045, -0.15)), 0.004)
		k.box(hazard, Vector3(0.012, 0.035, 0.34), Transform3D(Basis(), Vector3(s * 0.377, -0.125, -0.07)), 0.0)
		# The pod's pylon and gimbal.
		k.box(dark, Vector3(0.2, 0.13, 0.2), Transform3D(Basis(), Vector3(s * 0.43, 0.02, -0.04)), 0.025)
		k.cyl(brass, 0.085, 0.05, Transform3D(X, Vector3(s * 0.5, 0.02, -0.04)), 18)
		k.cyl(dark, 0.07, 0.04, Transform3D(X, Vector3(s * 0.545, 0.02, -0.04)), 18)
		_pod(k, s, cream, stripe, dark, steel, brass)
		# Body rivets along the side plate's edges.
		for r in 6:
			_rivet(k, steel, Vector3(s * 0.374, 0.105, -0.26 + r * 0.076), Vector3(s, 0, 0))
			_rivet(k, steel, Vector3(s * 0.374, -0.145, -0.26 + r * 0.076), Vector3(s, 0, 0))
	k.box(dark, Vector3(0.52, 0.05, 0.6), Transform3D(Basis(), Vector3(0, -0.262, 0.04)), 0.02)
	for s: float in [-1.0, 1.0]:
		k.box(amber, Vector3(0.08, 0.025, 0.02), Transform3D(Basis(), Vector3(s * 0.15, -0.2, -0.372)), 0.0)
	# The rear: a panel with rivets, a vent grille and the charge bar's bezel.
	k.box(dark, Vector3(0.44, 0.22, 0.03), Transform3D(Basis(), Vector3(0, -0.06, 0.408)), 0.01)
	for v in 5:
		k.box(steel, Vector3(0.3, 0.012, 0.02), Transform3D(Basis(), Vector3(0, -0.12 + v * 0.03, 0.428)), 0.0)
	for c: Vector2 in [Vector2(-0.2, 0.03), Vector2(0.2, 0.03), Vector2(-0.2, -0.15), Vector2(0.2, -0.15)]:
		_rivet(k, steel, Vector3(c.x, c.y, 0.424), Vector3.BACK)
	# The hood: a domed shell over the front, a red stripe over it (two on the RF-2H), rivets
	# round its lip, amber lamps under it.
	var lip := func(u: float) -> float: return 1.62 - 0.17 * pow(u / 1.25, 2.0)
	var stripe_lip := func(u: float) -> float: return float(lip.call(u)) - 0.02
	k.shell(cream, Vector3(0, 0.02, -0.02), Vector3(0.4, 0.36, 0.56), -1.25, 1.25, lip, 0.028, Transform3D(), 30, 14)
	k.shell(stripe, Vector3(0, 0.02, -0.02), Vector3(0.4, 0.36, 0.56), 0.1, 0.42, stripe_lip, 0.0, Transform3D(), 6, 14, 0.003, false)
	if heavy:
		k.shell(stripe, Vector3(0, 0.02, -0.02), Vector3(0.4, 0.36, 0.56), -0.42, -0.24, stripe_lip, 0.0, Transform3D(), 4, 14, 0.003, false)
	for r in 9:
		var u := lerpf(-1.1, 1.1, r / 8.0)
		var v := float(lip.call(u)) - 0.09
		var dir := Vector3(sin(v) * sin(u), cos(v), -sin(v) * cos(u))
		var n := Vector3(dir.x / 0.4, dir.y / 0.36, dir.z / 0.56).normalized()
		_rivet(k, steel, Vector3(0, 0.02, -0.02) + Vector3(dir.x * 0.4, dir.y * 0.36, dir.z * 0.56), n)
	for s: float in [-1.0, 1.0]:
		k.box(dark, Vector3(0.09, 0.04, 0.05), Transform3D(Basis(), Vector3(s * 0.2, 0.025, -0.47)), 0.01)
		k.box(amber, Vector3(0.07, 0.022, 0.012), Transform3D(Basis(), Vector3(s * 0.2, 0.025, -0.499)), 0.0)
	# The eye: a deep housing, brass rings, a big lens with an amber iris behind it, and a small
	# rangefinder lens beside it.
	k.cyl(dark, 0.16, 0.14, Transform3D(Z, Vector3(0, -0.05, -0.43)), 24)
	k.torus(brass, 0.15, 0.022, Transform3D(Z, Vector3(0, -0.05, -0.5)), 28, 8)
	k.torus(dark, 0.122, 0.014, Transform3D(Z, Vector3(0, -0.05, -0.515)), 24, 6)
	k.torus(Paint.glow(Color(1.0, 0.6, 0.15), 2.5), 0.07, 0.008, Transform3D(Z, Vector3(0, -0.05, -0.508)), 20, 5)
	k.sphere(glass(Color(0.16, 0.08, 0.22)), 0.105, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(1.0, 0.45, 1.0)), Vector3(0, -0.05, -0.5)), 24, 6, 1.2)
	k.cyl(dark, 0.035, 0.05, Transform3D(Z, Vector3(0.17, -0.15, -0.395)), 12)
	k.sphere(glass(Color(0.1, 0.14, 0.2)), 0.025, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.17, -0.15, -0.42)), 12, 4, 1.4)
	# The scrap rack on its back: a frame of tube on posts, carry handles, a hazard plate on its
	# front rail, and a load of offcut plates.
	var r0 := Vector3(-0.29, 0.2, 0.1)
	var r1 := Vector3(0.29, 0.2, 0.44)
	for y: float in [r0.y, r0.y + 0.14]:
		k.tube(steel, PackedVector3Array([Vector3(r0.x, y, r0.z), Vector3(r1.x, y, r0.z)]), 0.012, 6, 1)
		k.tube(steel, PackedVector3Array([Vector3(r0.x, y, r1.z), Vector3(r1.x, y, r1.z)]), 0.012, 6, 1)
		k.tube(steel, PackedVector3Array([Vector3(r0.x, y, r0.z), Vector3(r0.x, y, r1.z)]), 0.012, 6, 1)
		k.tube(steel, PackedVector3Array([Vector3(r1.x, y, r0.z), Vector3(r1.x, y, r1.z)]), 0.012, 6, 1)
	for c: Vector2 in [Vector2(r0.x, r0.z), Vector2(r1.x, r0.z), Vector2(r0.x, r1.z), Vector2(r1.x, r1.z), Vector2(r0.x, 0.27), Vector2(r1.x, 0.27)]:
		k.cyl(steel, 0.013, 0.17, Transform3D(Basis(), Vector3(c.x, r0.y + 0.07, c.y)), 6)
	k.box(hazard, Vector3(0.3, 0.05, 0.012), Transform3D(Basis(), Vector3(0, r0.y + 0.07, r0.z - 0.016)), 0.0)
	for s: float in [-1.0, 1.0]:
		k.tube(steel, PackedVector3Array([Vector3(s * 0.2, 0.34, 0.16), Vector3(s * 0.2, 0.42, 0.18), Vector3(s * 0.2, 0.42, 0.34), Vector3(s * 0.2, 0.34, 0.37)]), 0.012, 6, 4)
	var plates := [[Color(0.42, 0.26, 0.16), 0.9, "rust", Vector3(0.24, 0.2, 0.012), Vector3(-0.14, 0.32, 0.24), Vector3(0.3, 0.2, 0.1)],
			[Color(0.42, 0.5, 0.4), 0.7, "satin_paint", Vector3(0.22, 0.24, 0.012), Vector3(0.1, 0.33, 0.36), Vector3(-0.35, -0.3, 0.05)],
			[Color(0.55, 0.56, 0.58), 0.5, "galvanised", Vector3(0.2, 0.16, 0.012), Vector3(0.14, 0.3, 0.2), Vector3(0.45, 0.15, -0.12)],
			[Color(0.5, 0.3, 0.2), 0.8, "rust", Vector3(0.18, 0.28, 0.014), Vector3(-0.08, 0.36, 0.4), Vector3(-0.25, 0.4, 0.15)],
			[CREAM, 0.7, "satin_paint", Vector3(0.16, 0.14, 0.012), Vector3(-0.2, 0.3, 0.33), Vector3(0.2, -0.6, 0.0)]]
	for p: Array in plates:
		var m := worn(p[0], p[1], p[2], 0.4 if p[2] != "satin_paint" else 0.1, 0.7)
		var e: Vector3 = p[5]
		k.box(m, p[3], Transform3D(Basis.from_euler(e), p[4]), 0.004)
	# The charge pad on its back (it docks up into its charger by it), with copper contacts.
	k.cyl(dark, 0.03, 0.16, Transform3D(Basis(), Vector3(0, 0.34, 0.06)), 10)
	k.box(dark, Vector3(0.3, 0.03, 0.18), Transform3D(Basis(), Vector3(0, 0.425, 0.06)), 0.008)
	for s: float in [-1.0, 1.0]:
		k.box(Paint.paint(Color(0.72, 0.45, 0.25), 0.9, 0.3, "copper"), Vector3(0.08, 0.012, 0.08), Transform3D(Basis(), Vector3(s * 0.09, 0.445, 0.06)), 0.0)
	# The antenna on the rack's back corner.
	k.cyl(steel, 0.008, 0.3, Transform3D(Basis(), Vector3(-0.26, 0.42, 0.42)), 6)
	k.cyl(dark, 0.02, 0.04, Transform3D(Basis(), Vector3(-0.26, 0.28, 0.42)), 8)
	# Hoses and cables: from the body down to the shoulders and along the belly.
	for s: float in [-1.0, 1.0]:
		k.tube(rubber, PackedVector3Array([Vector3(s * 0.33, -0.06, 0.12), Vector3(s * 0.38, -0.16, 0.0), Vector3(s * 0.36, -0.24, -0.1), Vector3(s * 0.3, -0.26, -0.16)]), 0.016, 8, 5)
		k.tube(rubber, PackedVector3Array([Vector3(s * 0.12, -0.28, 0.32), Vector3(s * 0.2, -0.31, 0.1), Vector3(s * 0.26, -0.3, -0.1), Vector3(s * 0.3, -0.27, -0.16)]), 0.012, 8, 5)
		k.tube(rubber, PackedVector3Array([Vector3(s * 0.25, 0.12, 0.3), Vector3(s * 0.36, 0.08, 0.24), Vector3(s * 0.42, 0.06, 0.08)]), 0.013, 8, 5)
	# The shoulders: housings under the body's front corners.
	for at: Vector3 in [SHOULDER_R, SHOULDER_L]:
		k.cyl(dark, 0.075, 0.13, Transform3D(X, at + Vector3(signf(at.x) * 0.02, 0.01, 0.0)), 16)
		k.cyl(brass, 0.082, 0.025, Transform3D(X, at + Vector3(signf(at.x) * -0.045, 0.01, 0.0)), 16)
	k.commit(self, "Body")
	# The lamps that change: the antenna's, the charge bar, the turbines' glow.
	_antenna_lamp = StandardMaterial3D.new()
	_antenna_lamp.emission_enabled = true
	_antenna_lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	Paint.ball(self, 0.02, Vector3(-0.26, 0.58, 0.42), _antenna_lamp, Vector3.ONE, "AntennaLamp")
	_charge_mat = StandardMaterial3D.new()
	_charge_mat.emission_enabled = true
	_charge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_charge_bar = Paint.box(self, Vector3(0.3, 0.035, 0.012), Vector3(0, 0.03, 0.43), _charge_mat, "Charge")
	# The BSX stencil on its flanks.
	for s: float in [-1.0, 1.0]:
		var l := Paint.label(self, ("BSX  RF-2H\n" if heavy else "BSX  RF-2\n") + serial.get_slice("/", 1), Vector3(s * 0.384, -0.06, 0.16), 0.0016, Color(0.18, 0.17, 0.16), 40, Vector3(s, 0, 0))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The arms.
	_arm_r = _arm(SHOULDER_R, cream, dark, steel, brass, rubber)
	_arm_l = _arm(SHOULDER_L, cream, dark, steel, brass, rubber)
	_fore_r = _arm_r.get_node("Fore")
	_fore_l = _arm_l.get_node("Fore")
	_vice(dark, steel, brass)
	for t in TOOLS:
		var h := Node3D.new()
		h.name = t
		h.position = Vector3(0, 0, -FORE)
		h.visible = false
		_fore_r.add_child(h)
		_heads[t] = h
		_tool_head(t, h, dark, steel, brass, rubber)


## A thruster pod on side `s`: a banded can with a red stripe, a front intake with its turbine
## and blue glow, a nozzle at the back.
func _pod(k: Kit, s: float, cream: Material, stripe: Material, dark: Material, steel: Material, brass: Material) -> void:
	var Z := Basis(Vector3.RIGHT, PI * 0.5)
	var at := Vector3(s * POD_AT.x, POD_AT.y, POD_AT.z)
	k.cyl(cream, POD_R, 0.4, Transform3D(Z, at), 28, -1.0, false)
	k.sphere(cream, POD_R, Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.0, 0.45, 1.0)), at + Vector3(0, 0, 0.2)), 28, 6, PI * 0.5)
	k.cyl(stripe, POD_R + 0.004, 0.09, Transform3D(Z, at + Vector3(0, 0, -0.04)), 28, -1.0, false)
	for z: float in [-0.13, 0.08]:
		k.torus(dark, POD_R + 0.004, 0.012, Transform3D(Z, at + Vector3(0, 0, z)), 28, 6)
	# The front intake: a thick lip, a dark throat, the glow and the turbine.
	k.torus(cream, POD_R - 0.025, 0.03, Transform3D(Z, at + Vector3(0, 0, -0.2)), 28, 8)
	k.cyl(dark, POD_R - 0.04, 0.12, Transform3D(Z, at + Vector3(0, 0, -0.15)), 24, -1.0, false)
	k.torus(steel, POD_R - 0.05, 0.008, Transform3D(Z, at + Vector3(0, 0, -0.19)), 24, 5)
	# The nozzle out of its back: a dark cone with a brass ring.
	k.cyl(dark, 0.09, 0.08, Transform3D(Z, at + Vector3(0, 0, 0.28)), 20, 0.11, false)
	k.torus(brass, 0.11, 0.01, Transform3D(Z, at + Vector3(0, 0, 0.32)), 20, 5)
	for r in 8:
		var a := TAU * r / 8.0
		_rivet(k, steel, at + Vector3(cos(a) * POD_R, sin(a) * POD_R, 0.13), Vector3(cos(a), sin(a), 0))
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.albedo_color = Color(0.35, 0.75, 1.0)
		_glow_mat.emission_enabled = true
		_glow_mat.emission = Color(0.35, 0.75, 1.0)
		_glow_mat.emission_energy_multiplier = 3.0
	# The glow inside the intake and out of the nozzle.
	var g := Paint.rod(self, POD_R - 0.045, 0.01, at + Vector3(0, 0, -0.1), _glow_mat, Z, "Glow")
	g.set_meta("gfx_coplanar_ok", true)
	var n := Paint.rod(self, 0.075, 0.01, at + Vector3(0, 0, 0.305), _glow_mat, Z, "NozzleGlow")
	n.set_meta("gfx_coplanar_ok", true)
	var rotor := Node3D.new()
	rotor.name = "Turbine"
	rotor.position = at + Vector3(0, 0, -0.14)
	add_child(rotor)
	var rk := _kit()
	rk.cyl(dark, 0.035, 0.05, Transform3D(Z, Vector3.ZERO), 12)
	rk.sphere(steel, 0.032, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.025)), 12, 4, PI * 0.5)
	for b in 9:
		var a := TAU * b / 9.0
		rk.box(steel, Vector3(0.012, POD_R - 0.09, 0.03), Transform3D(Basis(Vector3.BACK, a) * Basis(Vector3.UP, 0.5), Basis(Vector3.BACK, a) * Vector3(0, (POD_R - 0.09) * 0.5 + 0.03, 0)), 0.0)
	rk.commit(rotor)
	_rotors.append(rotor)


## A rivet head at `at` on a surface facing `n`.
func _rivet(k: Kit, mat: Material, at: Vector3, n: Vector3) -> void:
	var up := n.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	var b := Basis(side, up, side.cross(up)).scaled(Vector3(1.0, 0.5, 1.0))
	k.sphere(mat, 0.009, Transform3D(b, at), 6, 2, PI * 0.5)


## An arm: an upper arm in a worn sleeve with its ram and hose, an elbow, a steel forearm.
func _arm(at: Vector3, cream: Material, dark: Material, steel: Material, brass: Material, rubber: Material) -> Node3D:
	var X := Basis(Vector3.FORWARD, PI * 0.5)
	var Z := Basis(Vector3.RIGHT, PI * 0.5)
	var sleeve := Paint.paint(Paint.HAZARD, 0.1, 0.6, "hazard_stripes") if heavy else worn(SLEEVE, 0.6)
	var arm := Node3D.new()
	arm.position = at
	add_child(arm)
	var k := _kit()
	k.sphere(dark, 0.085, Transform3D(), 14, 7)
	k.box(cream, Vector3(0.13, 0.13, UPPER - 0.14), Transform3D(Basis(), Vector3(0, 0, -UPPER * 0.5)), 0.022)
	k.box(sleeve, Vector3(0.142, 0.142, 0.13), Transform3D(Basis(), Vector3(0, 0, -UPPER * 0.6)), 0.02)
	k.cyl(steel, 0.016, UPPER * 0.55, Transform3D(Z, Vector3(0, 0.088, -UPPER * 0.48)), 8)
	k.cyl(dark, 0.026, UPPER * 0.28, Transform3D(Z, Vector3(0, 0.088, -UPPER * 0.22)), 10)
	k.tube(rubber, PackedVector3Array([Vector3(0.07, -0.03, -0.02), Vector3(0.088, -0.05, -UPPER * 0.3), Vector3(0.084, -0.04, -UPPER * 0.7), Vector3(0.06, 0.0, -UPPER + 0.02)]), 0.011, 6, 5)
	for z: float in [-0.09, -UPPER + 0.09]:
		for s: float in [-1.0, 1.0]:
			_rivet(k, steel, Vector3(s * 0.066, 0.0, z), Vector3(s, 0, 0))
	k.commit(arm)
	var fore := Node3D.new()
	fore.name = "Fore"
	fore.position = Vector3(0, 0, -UPPER)
	arm.add_child(fore)
	var f := _kit()
	f.cyl(dark, 0.072, 0.15, Transform3D(X, Vector3.ZERO), 16)
	f.cyl(brass, 0.077, 0.02, Transform3D(X, Vector3(0.06, 0, 0)), 16)
	f.cyl(brass, 0.077, 0.02, Transform3D(X, Vector3(-0.06, 0, 0)), 16)
	f.box(cream, Vector3(0.105, 0.105, FORE - 0.12), Transform3D(Basis(), Vector3(0, 0, -FORE * 0.5)), 0.015)
	f.box(sleeve, Vector3(0.119, 0.119, 0.11), Transform3D(Basis(), Vector3(0, 0, -FORE * 0.38)), 0.018)
	f.tube(rubber, PackedVector3Array([Vector3(0.0, 0.07, 0.03), Vector3(0.0, 0.078, -FORE * 0.4), Vector3(0.0, 0.06, -FORE + 0.06)]), 0.009, 6, 5)
	f.cyl(dark, 0.048, 0.06, Transform3D(Z, Vector3(0, 0, -FORE + 0.04)), 14)
	f.torus(steel, 0.048, 0.008, Transform3D(Z, Vector3(0, 0, -FORE + 0.012)), 14, 4)
	f.commit(fore)
	return arm


## The screw vice on the left arm: a block, a fixed jaw, a moving jaw on its screw, a T-handle.
func _vice(dark: Material, steel: Material, brass: Material) -> void:
	var v := Node3D.new()
	v.name = "Vice"
	v.position = Vector3(0, 0, -FORE)
	_fore_l.add_child(v)
	var k := _kit()
	k.box(dark, Vector3(0.1, 0.16, 0.08), Transform3D(Basis(), Vector3(0, 0, -0.05)), 0.012)
	k.box(steel, Vector3(0.12, 0.04, 0.1), Transform3D(Basis(), Vector3(0, 0.07, -0.13)), 0.01)
	k.box(Paint.paint(Color(0.2, 0.2, 0.21), 0.6, 0.7, "tread_diamond_steel"), Vector3(0.11, 0.012, 0.09), Transform3D(Basis(), Vector3(0, 0.044, -0.13)), 0.0)
	k.cyl(steel, 0.012, 0.3, Transform3D(Basis(), Vector3(0, -0.02, -0.13)), 8)
	k.cyl(brass, 0.022, 0.03, Transform3D(Basis(), Vector3(0, -0.1, -0.13)), 10)
	k.cyl(steel, 0.008, 0.14, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, -0.17, -0.13)), 6)
	for s: float in [-1.0, 1.0]:
		k.sphere(steel, 0.016, Transform3D(Basis(), Vector3(s * 0.07, -0.17, -0.13)), 8, 4)
	k.commit(v)
	_jaw = Node3D.new()
	_jaw.name = "Jaw"
	_jaw.position = Vector3(0, -0.02, -0.13)
	v.add_child(_jaw)
	var j := _kit()
	j.box(steel, Vector3(0.12, 0.04, 0.1), Transform3D(), 0.01)
	j.box(Paint.paint(Color(0.2, 0.2, 0.21), 0.6, 0.7, "tread_diamond_steel"), Vector3(0.11, 0.012, 0.09), Transform3D(Basis(), Vector3(0, 0.026, 0)), 0.0)
	j.commit(_jaw)


func _tool_head(t: String, h: Node3D, dark: Material, steel: Material, brass: Material, rubber: Material) -> void:
	var Z := Basis(Vector3.RIGHT, PI * 0.5)   # a cylinder along Z
	var X := Basis(Vector3.FORWARD, PI * 0.5)
	var yellow := worn(SLEEVE, 0.5)
	var k := _kit()
	match t:
		"scanner":
			k.box(dark, Vector3(0.18, 0.12, 0.1), Transform3D(Basis(), Vector3(0, 0, -0.05)), 0.015)
			k.box(Paint.glow(Color(0.3, 0.8, 1.0), 5.0), Vector3(0.14, 0.03, 0.01), Transform3D(Basis(), Vector3(0, 0.025, -0.104)), 0.0)
			k.cyl(dark, 0.03, 0.03, Transform3D(Z, Vector3(-0.05, -0.025, -0.105)), 12)
			k.sphere(glass(Color(0.2, 0.1, 0.1)), 0.022, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(-0.05, -0.025, -0.12)), 10, 3, 1.2)
			k.box(Paint.glow(Color(1.0, 0.2, 0.15), 3.0), Vector3(0.03, 0.02, 0.01), Transform3D(Basis(), Vector3(0.05, -0.025, -0.104)), 0.0)
		"nut_runner":
			k.cyl(yellow, 0.055, 0.14, Transform3D(Z, Vector3(0, 0, -0.07)), 16)
			k.box(dark, Vector3(0.05, 0.12, 0.06), Transform3D(Basis(), Vector3(0, 0.07, -0.06)), 0.01)
			k.cyl(dark, 0.045, 0.04, Transform3D(Z, Vector3(0, 0, -0.16)), 14)
			k.cyl(steel, 0.03, 0.06, Transform3D(Z, Vector3(0, 0, -0.2)), 12)
			k.cyl(steel, 0.024, 0.05, Transform3D(Z, Vector3(0, 0, -0.245)), 6)
		"blaster":
			# A pressure-washer lance: a trigger body, the lance, its nozzle, the hose.
			k.box(dark, Vector3(0.08, 0.1, 0.1), Transform3D(Basis(), Vector3(0, 0, -0.05)), 0.012)
			k.cyl(yellow, 0.03, 0.06, Transform3D(Z, Vector3(0, 0, -0.12)), 12)
			k.cyl(steel, 0.012, 0.18, Transform3D(Z, Vector3(0, 0, -0.24)), 8)
			k.cyl(brass, 0.02, 0.03, Transform3D(Z, Vector3(0, 0, -0.33)), 10, 0.014)
			k.tube(rubber, PackedVector3Array([Vector3(0, -0.05, -0.04), Vector3(0, -0.09, 0.05), Vector3(0.03, -0.06, 0.25), Vector3(0.05, 0.0, 0.45)]), 0.014, 8, 5)
		"welder":
			k.cyl(dark, 0.035, 0.12, Transform3D(Z, Vector3(0, 0, -0.06)), 12)
			k.tube(steel, PackedVector3Array([Vector3(0, 0, -0.11), Vector3(0, 0, -0.17), Vector3(0, -0.03, -0.22), Vector3(0, -0.05, -0.25)]), 0.016, 8, 5)
			k.cyl(brass, 0.02, 0.04, Transform3D(Basis(Vector3.RIGHT, PI * 0.72), Vector3(0, -0.055, -0.262)), 10, 0.012)
			k.tube(rubber, PackedVector3Array([Vector3(-0.03, 0.03, -0.02), Vector3(-0.05, 0.06, 0.15), Vector3(-0.04, 0.04, 0.45)]), 0.01, 6, 5)
		"probe":
			k.box(dark, Vector3(0.1, 0.08, 0.08), Transform3D(Basis(), Vector3(0, 0, -0.04)), 0.012)
			for s: float in [-1.0, 1.0]:
				k.cyl(steel, 0.008, 0.16, Transform3D(Z, Vector3(s * 0.03, 0, -0.16)), 6)
				k.sphere(Paint.paint(Color(0.85, 0.15, 0.1), 0.2, 0.5) if s < 0.0 else dark, 0.013, Transform3D(Basis(), Vector3(s * 0.03, 0, -0.245)), 8, 4)
			k.box(Paint.glow(Color(0.3, 1.0, 0.45), 4.0), Vector3(0.03, 0.012, 0.03), Transform3D(Basis(), Vector3(0, 0.046, -0.04)), 0.0)
		"cutter":
			# A cut-off grinder: the motor, the gearhead, the guard, the spinning disc.
			k.cyl(yellow, 0.045, 0.1, Transform3D(Z, Vector3(0, 0, -0.05)), 14)
			for r in 4:
				k.torus(dark, 0.046, 0.005, Transform3D(Z, Vector3(0, 0, -0.02 - r * 0.018)), 14, 4)
			k.box(dark, Vector3(0.09, 0.07, 0.07), Transform3D(Basis(), Vector3(0, 0, -0.13)), 0.012)
			k.torus(steel, 0.11, 0.012, Transform3D(X, Vector3(0.0, 0, -0.16)), 20, 5, PI * 0.9)
			_disc = Node3D.new()
			_disc.name = "Disc"
			_disc.position = Vector3(0.05, 0, -0.16)
			h.add_child(_disc)
			var d := _kit()
			d.cyl(Paint.paint(Color(0.38, 0.35, 0.32), 0.3, 0.9, "cast_iron"), 0.1, 0.008, Transform3D(X, Vector3.ZERO), 28)
			d.cyl(steel, 0.025, 0.016, Transform3D(X, Vector3.ZERO), 10)
			d.commit(_disc)
	k.commit(h)


## Drawn at `pos` (global), turned to `face` (global point; INF keeps its heading), with its tool
## arm reaching for `work` (global; INF tucks it) and its vice for `hold` (INF tucks it).
## Docked, it hangs still in its charger with its turbines idling.
func pose(pos: Vector3, face: Vector3, work: Vector3, hold: Vector3, charge: float, charging: bool, tool_name: String, delta: float, docked := false) -> void:
	_bob += delta
	var phase := float(serial.hash() % 100) * 0.07
	var bob := 0.0 if docked else sin(_bob * 1.7 + phase) * 0.035
	global_position = pos + Vector3(0, bob, 0)
	if face.is_finite():
		var flat := Vector3(face.x - pos.x, 0, face.z - pos.z)
		if flat.length() > 0.05:
			var want := Basis.looking_at(flat.normalized(), Vector3.UP)
			_heading = _heading.slerp(want, clampf(delta * 3.0, 0.0, 1.0)).orthonormalized()
	# Scanning, it noses down (or up) so its eye looks at the part.
	var want_pitch := 0.0
	if tool_name == "scanner" and work.is_finite() and face.is_finite():
		var flat_d := Vector2(face.x - pos.x, face.z - pos.z).length()
		want_pitch = clampf(atan2(face.y - pos.y, maxf(flat_d, 0.3)), -0.7, 0.35)
	_pitch = lerpf(_pitch, want_pitch, clampf(delta * 3.0, 0.0, 1.0))
	basis = (_heading * Basis(Vector3.RIGHT, _pitch)).scaled(Vector3.ONE * size)
	eye = global_transform * Vector3(0, -0.05, -0.56)
	_reach(_arm_r, _fore_r, work, Vector3(0.1, -0.55, -0.55))
	_reach(_arm_l, _fore_l, hold, Vector3(-0.1, -0.6, -0.5))
	# The vice closes on a part it carries.
	var shut := -0.0 if hold.is_finite() else -0.06
	_jaw.position.y = lerpf(_jaw.position.y, -0.02 + shut, clampf(delta * 6.0, 0.0, 1.0))
	set_tool(tool_name)
	# Turbines: idling on the charger, spinning up with the thrust.
	_spin += delta * (5.0 if docked else 40.0 + 34.0 * _thrust)
	for r in _rotors.size():
		_rotors[r].rotation.z = _spin * (1.0 if r % 2 == 0 else -1.0)
	if _disc:
		_disc.rotation.x -= delta * (90.0 if tool == "cutter" and work.is_finite() else 4.0)
	var c := Color(0.25, 1.0, 0.35) if charge > 0.6 else (Color(1.0, 0.7, 0.1) if charge > 0.3 else Color(1.0, 0.2, 0.1))
	if charging:
		c = Color(1.0, 0.7, 0.1) if fmod(_bob, 1.0) < 0.6 else Color(0.3, 0.2, 0.05)
	_charge_mat.albedo_color = c
	_charge_mat.emission = c
	_charge_bar.scale.x = maxf(charge, 0.05)
	_charge_bar.position.x = -0.15 * (1.0 - maxf(charge, 0.05))
	var blink := fmod(_bob + phase, 1.4) < 0.12
	var ac := Color(1.0, 0.25, 0.15) if blink else Color(0.2, 0.05, 0.03)
	_antenna_lamp.albedo_color = ac
	_antenna_lamp.emission = ac
	var head: Node3D = _heads.get(tool, null)
	if head:
		head.basis = Basis()
		if aim_point.is_finite():
			var local := (_fore_r.global_transform.affine_inverse().basis * (aim_point - head.global_position)).normalized()
			if local.length() > 0.5:
				head.basis = Basis.looking_at(local, Vector3.UP if absf(local.y) < 0.95 else Vector3.RIGHT)
		tip = head.global_transform * Vector3(0, 0, -float(TIP.get(tool, 0.26)))
		tip_dir = -(head.global_basis.z).normalized()
	else:
		tip = _fore_r.global_transform * Vector3(0, 0, -FORE)
		tip_dir = -(_fore_r.global_basis.z).normalized()


func set_tool(t: String) -> void:
	if t == tool:
		return
	tool = t
	for h: String in _heads:
		(_heads[h] as Node3D).visible = h == t


## Two-bone reach: the upper arm and forearm bend to put the hand at `target` (global), or rest
## at `rest` (body space) for INF.
func _reach(arm: Node3D, fore: Node3D, target: Vector3, rest: Vector3) -> void:
	var t_local := to_local(target) if target.is_finite() else rest + arm.position
	var from := arm.position
	var gap := t_local - from
	var d := clampf(gap.length(), 0.15, UPPER + FORE - 0.01)
	var dir := gap.normalized() if gap.length() > 0.001 else Vector3.FORWARD
	# The elbow bends outwards and up.
	var side := signf(arm.position.x)
	var pole := Vector3(side * 0.6, 0.5, 0.2).normalized()
	var a := acos(clampf((UPPER * UPPER + d * d - FORE * FORE) / (2.0 * UPPER * d), -1.0, 1.0))
	var bend := (pole - dir * pole.dot(dir)).normalized()
	if bend.length() < 0.01:
		bend = Vector3.UP
	var elbow := from + (dir * cos(a) + bend * sin(a)) * UPPER
	var hand := from + dir * d
	_aim(arm, from, elbow)
	fore.global_transform = Transform3D(_look(global_basis.orthonormalized() * (hand - elbow).normalized(), global_basis.orthonormalized() * bend).scaled(Vector3.ONE * size), to_global(elbow))


func _aim(node: Node3D, from: Vector3, to: Vector3) -> void:
	var dir := (to - from).normalized()
	node.transform = Transform3D(_look(dir, Vector3.UP), from)


static func _look(dir: Vector3, up: Vector3) -> Basis:
	if absf(dir.dot(up.normalized())) > 0.98:
		up = Vector3.RIGHT
	return Basis.looking_at(dir, up)


## The turbines' glow brightens while it flies.
func thrust(amount: float) -> void:
	_thrust = amount
	if _glow_mat:
		_glow_mat.emission_energy_multiplier = 2.0 + amount * 6.0
