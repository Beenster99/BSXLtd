extends Node3D
## A TartanCo RF-2 refurbisher (and the bigger RF-2H that works the heavy stand): a hovering work
## drone (the androids walk the berth's ribs; these fly). A rounded shell in TartanCo's white
## (the RF-2H in ochre with hazard bands) over a dark belly band with cooling vents; four ducted
## fans on struts, their rotors spinning and their downwash glowing with the thrust; nav lamps;
## a sensor brow with a three-lens camera cluster, a visor strip and a work lamp; an antenna; the
## charge contacts on its back that it docks up into its charger with; a stowed tool carousel
## under its belly; and two arms with a hydraulic ram along each: a three-fingered gripper that
## carries the part and a tool arm whose head changes with the stage (scanner, nut runner, grit
## blaster, welding torch, test probe, plasma cutter). Presentation only: the works moves it to
## the RefurbWorks state each frame.

const Paint := preload("res://modules/refurb/internal/refurb_paint.gd")

const TOOLS: PackedStringArray = ["scanner", "nut_runner", "blaster", "welder", "probe", "cutter"]
const SHOULDER_R := Vector3(0.4, -0.12, -0.26)
const SHOULDER_L := Vector3(-0.4, -0.12, -0.26)
const UPPER := 0.5
const FORE := 0.5
## Drawn this much bigger than its parts are listed (a 1.4 m drone; the RF-2H 1.8 m).
const SIZE := 1.4
const HEAVY_SIZE := 1.8
const FAN_AT := Vector2(0.56, 0.5)
const FAN_R := 0.2

var serial := ""
var tool := ""
var heavy := false
var size := SIZE
## Where the tool's tip is (global), for effects.
var tip := Vector3.ZERO

var _arm_r: Node3D
var _arm_l: Node3D
var _fore_r: Node3D
var _fore_l: Node3D
var _fingers: Array[Node3D] = []
var _heads: Dictionary = {}
var _charge_bar: MeshInstance3D
var _charge_mat: StandardMaterial3D
var _rotors: Array[Node3D] = []
var _wash: Array[MeshInstance3D] = []
var _antenna_lamp: StandardMaterial3D
var _bob := 0.0
var _spin := 0.0
var _thrust := 0.0
var _heading := Basis()


func build(serial_no: String, is_heavy := false) -> void:
	serial = serial_no
	heavy = is_heavy
	size = HEAVY_SIZE if heavy else SIZE
	name = ("RF2H_" if heavy else "RF2_") + serial_no.get_slice("/", 1)
	var shell_c := Paint.OCHRE if heavy else Paint.PLATES
	var spine_c := Paint.PLATES if heavy else Paint.OCHRE
	var plates := Paint.paint(shell_c, 0.15, 0.45, "satin_paint")
	var trim := Paint.paint(Paint.TRIM, 0.4, 0.5, "gunmetal")
	var spine := Paint.paint(spine_c, 0.2, 0.5, "satin_paint")
	var steel := Paint.paint(Paint.STEEL, 0.8, 0.35, "brushed_steel")
	var copper := Paint.paint(Color(0.72, 0.45, 0.25), 0.9, 0.3, "copper")
	var lens := Paint.paint(Color(0.04, 0.05, 0.07), 0.9, 0.08, "gunmetal")
	# The body: a rounded shell over a dark belly band, side plates and a spine.
	Paint.ball(self, 0.5, Vector3.ZERO, plates, Vector3(1.0, 0.72, 1.15), "Shell")
	Paint.rod(self, 0.47, 0.1, Vector3(0, -0.06, 0), trim, Basis(), "Band").scale = Vector3(1.0, 1.0, 1.14)
	Paint.ball(self, 0.3, Vector3(0, 0.3, 0.05), spine, Vector3(1.2, 0.35, 1.3), "Spine")
	var side_plates := Paint.paint(Paint.HAZARD, 0.1, 0.6, "hazard_stripes") if heavy else plates
	for side: float in [-1.0, 1.0]:
		var plate := Paint.box(self, Vector3(0.05, 0.22, 0.5), Vector3(side * 0.47, 0.1, 0.02), side_plates, "SidePlate")
		plate.rotation.z = side * -0.35
		for k in 4:   # cooling slats in the band
			Paint.box(self, Vector3(0.02, 0.05, 0.08), Vector3(side * 0.485, -0.06, 0.18 + k * 0.1), steel)
	# The sensor brow at the front (-Z): a visor strip, three camera lenses, a work lamp.
	Paint.box(self, Vector3(0.46, 0.17, 0.16), Vector3(0, 0.08, -0.55), trim, "Brow")
	Paint.box(self, Vector3(0.38, 0.035, 0.02), Vector3(0, 0.135, -0.635), Paint.glow(Color(0.35, 0.85, 1.0), 4.0), "Visor")
	var down := Basis(Vector3.RIGHT, PI * 0.5)   # a cylinder along Z
	for k in 3:
		var x := (k - 1) * 0.11
		var r := 0.04 if k == 1 else 0.028
		Paint.rod(self, r + 0.012, 0.05, Vector3(x, 0.05, -0.645), trim, down)
		Paint.rod(self, r, 0.02, Vector3(x, 0.05, -0.675), lens, down)
	Paint.box(self, Vector3(0.16, 0.04, 0.02), Vector3(0, -0.01, -0.635), Paint.glow(Color(1.0, 0.95, 0.85), 5.0), "WorkLamp")
	Paint.box(self, Vector3(0.05, 0.05, 0.02), Vector3(0.19, 0.0, -0.635), Paint.glow(Color(1.0, 0.45, 0.1), 3.0))
	# The antenna and its lamp, the charge contacts on its back, the charge bar and serial.
	Paint.rod(self, 0.012, 0.3, Vector3(-0.16, 0.48, 0.32), steel)
	_antenna_lamp = StandardMaterial3D.new()
	_antenna_lamp.emission_enabled = true
	_antenna_lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	Paint.ball(self, 0.025, Vector3(-0.16, 0.64, 0.32), _antenna_lamp)
	Paint.box(self, Vector3(0.36, 0.035, 0.24), Vector3(0, 0.405, 0.02), trim, "Contacts")
	for s: float in [-1.0, 1.0]:
		Paint.box(self, Vector3(0.09, 0.02, 0.09), Vector3(s * 0.11, 0.43, 0.02), copper)
	Paint.box(self, Vector3(0.34, 0.07, 0.03), Vector3(0, 0.12, 0.575), trim)
	_charge_mat = StandardMaterial3D.new()
	_charge_mat.emission_enabled = true
	_charge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_charge_bar = Paint.box(self, Vector3(0.3, 0.045, 0.02), Vector3(0, 0.12, 0.59), _charge_mat, "Charge")
	for side: float in [-1.0, 1.0]:
		var l := Paint.label(self, ("TARTANCO  RF-2H\n" if heavy else "TARTANCO\n") + serial, Vector3(side * 0.505, 0.02, -0.12), 0.0026, Color(0.12, 0.12, 0.13), 40, Vector3(side, 0, 0))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Four ducted fans on struts: a ring duct, a hub with three blades, the downwash's glow, and
	# nav lamps on the front ducts (red port, green starboard) and white on the back.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var at := Vector3(sx * FAN_AT.x, -0.12, sz * FAN_AT.y)
			var strut := Paint.box(self, Vector3(0.3, 0.06, 0.08), Vector3(sx * 0.4, -0.1, sz * 0.36), trim)
			strut.rotation.y = -sx * sz * 0.75
			var duct := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = FAN_R
			tm.outer_radius = FAN_R + 0.055
			tm.rings = 20
			tm.ring_segments = 8
			duct.mesh = tm
			duct.material_override = plates if not heavy else trim
			duct.position = at
			duct.scale = Vector3(1.0, 1.6, 1.0)
			add_child(duct)
			var rotor := Node3D.new()
			rotor.position = at
			add_child(rotor)
			Paint.rod(rotor, 0.045, 0.08, Vector3.ZERO, trim)
			for k in 3:
				var blade := Paint.box(rotor, Vector3(FAN_R - 0.03, 0.012, 0.06), Vector3(0, 0, 0), steel)
				blade.position = Basis(Vector3.UP, k * TAU / 3.0) * Vector3((FAN_R - 0.03) * 0.5 + 0.03, 0, 0)
				blade.basis = Basis(Vector3.UP, k * TAU / 3.0) * Basis(Vector3.RIGHT, 0.35)
			_rotors.append(rotor)
			var wash := Paint.rod(self, FAN_R - 0.01, 0.02, at - Vector3(0, 0.07, 0), Paint.glow(Color(0.45, 0.7, 1.0), 1.6))
			wash.set_meta("gfx_coplanar_ok", true)
			_wash.append(wash)
			var nav := Color(1.0, 0.15, 0.1) if sx < 0.0 else Color(0.2, 1.0, 0.35)
			if sz > 0.0:
				nav = Color(1.0, 1.0, 1.0)
			Paint.ball(self, 0.022, at + Vector3(sx * (FAN_R + 0.06), 0, 0), Paint.glow(nav, 4.0, true))
	# Under the belly: a sensor pod and the stowed tool carousel.
	Paint.ball(self, 0.12, Vector3(0, -0.32, -0.25), trim, Vector3(1.0, 0.6, 1.0))
	Paint.box(self, Vector3(0.12, 0.02, 0.06), Vector3(0, -0.36, -0.33), Paint.glow(Color(1.0, 0.2, 0.15), 3.0))
	Paint.rod(self, 0.16, 0.1, Vector3(0, -0.32, 0.18), trim)
	for k in 5:
		var a := k * TAU / 5.0
		Paint.rod(self, 0.025, 0.12, Vector3(cos(a) * 0.12, -0.42, 0.18 + sin(a) * 0.12), steel if k % 2 == 0 else copper)
	# Arms: a shoulder housing, an upper arm with its ram, a steel forearm with a wrist ring; the
	# left ends in the gripper, the right carries the tools.
	var arm_c := Paint.paint(Paint.TRIM if heavy else Paint.OCHRE, 0.2, 0.5, "satin_paint")
	_arm_r = _arm(SHOULDER_R, trim, arm_c, steel)
	_arm_l = _arm(SHOULDER_L, trim, arm_c, steel)
	_fore_r = _arm_r.get_node("Fore")
	_fore_l = _arm_l.get_node("Fore")
	var grip := Node3D.new()
	grip.name = "Gripper"
	grip.position = Vector3(0, 0, -FORE)
	_fore_l.add_child(grip)
	Paint.rod(grip, 0.05, 0.06, Vector3(0, 0, -0.02), trim, down)
	for k in 3:
		var finger := Node3D.new()
		finger.basis = Basis(Vector3.BACK, k * TAU / 3.0)
		finger.position = Vector3(0, 0, -0.05)
		grip.add_child(finger)
		var hinge := Node3D.new()
		hinge.position = Vector3(0, 0.04, 0)
		finger.add_child(hinge)
		Paint.box(hinge, Vector3(0.025, 0.02, 0.11), Vector3(0, 0, -0.055), steel)
		Paint.box(hinge, Vector3(0.025, 0.02, 0.06), Vector3(0, -0.02, -0.12), trim).rotation.x = 0.6
		_fingers.append(hinge)
	for t in TOOLS:
		var h := Node3D.new()
		h.name = t
		h.position = Vector3(0, 0, -FORE)
		h.visible = false
		_fore_r.add_child(h)
		_heads[t] = h
		_tool_head(t, h, trim, steel, copper)


func _arm(at: Vector3, trim: Material, arm_c: Material, steel: Material) -> Node3D:
	Paint.box(self, Vector3(0.16, 0.14, 0.18), at + Vector3(signf(at.x) * -0.04, 0.025, 0.0), trim)
	var arm := Node3D.new()
	arm.position = at
	add_child(arm)
	Paint.ball(arm, 0.09, Vector3.ZERO, trim)
	Paint.box(arm, Vector3(0.09, 0.09, UPPER - 0.06), Vector3(0, 0, -UPPER * 0.5), arm_c)
	Paint.rod(arm, 0.02, UPPER * 0.6, Vector3(0, 0.07, -UPPER * 0.45), steel, Basis(Vector3.RIGHT, PI * 0.5))
	Paint.rod(arm, 0.032, UPPER * 0.3, Vector3(0, 0.07, -UPPER * 0.2), trim, Basis(Vector3.RIGHT, PI * 0.5))
	var fore := Node3D.new()
	fore.name = "Fore"
	fore.position = Vector3(0, 0, -UPPER)
	arm.add_child(fore)
	Paint.ball(fore, 0.065, Vector3.ZERO, trim)
	Paint.box(fore, Vector3(0.07, 0.07, FORE - 0.06), Vector3(0, 0, -FORE * 0.5), steel)
	Paint.rod(fore, 0.045, 0.04, Vector3(0, 0, -FORE + 0.03), trim, Basis(Vector3.RIGHT, PI * 0.5))
	return arm


func _tool_head(t: String, h: Node3D, trim: Material, steel: Material, copper: Material) -> void:
	var down := Basis(Vector3.RIGHT, PI * 0.5)   # a cylinder along -Z
	match t:
		"scanner":
			Paint.box(h, Vector3(0.18, 0.11, 0.1), Vector3(0, 0, -0.05), trim)
			Paint.box(h, Vector3(0.14, 0.035, 0.01), Vector3(0, 0.01, -0.105), Paint.glow(Color(0.3, 0.8, 1.0), 5.0))
			Paint.rod(h, 0.025, 0.02, Vector3(0.06, -0.03, -0.105), Paint.glow(Color(1.0, 0.2, 0.15), 3.0), down)
		"nut_runner":
			Paint.rod(h, 0.055, 0.14, Vector3(0, 0, -0.07), trim, down)
			Paint.box(h, Vector3(0.05, 0.12, 0.06), Vector3(0, 0.07, -0.06), trim)
			Paint.rod(h, 0.03, 0.08, Vector3(0, 0, -0.18), steel, down)
			Paint.rod(h, 0.022, 0.05, Vector3(0, 0, -0.245), steel, down)
		"blaster":
			Paint.rod(h, 0.05, 0.12, Vector3(0, 0, -0.06), trim, down)
			Paint.rod(h, 0.025, 0.16, Vector3(0, 0, -0.2), Paint.paint(Paint.OCHRE, 0.2, 0.5), down, "", 0.045)
			Paint.rod(h, 0.014, 0.5, Vector3(0.06, 0.05, 0.2), trim, down)   # the grit hose
		"welder":
			Paint.rod(h, 0.035, 0.18, Vector3(0, 0, -0.09), trim, down)
			Paint.rod(h, 0.018, 0.1, Vector3(0, -0.02, -0.21), copper, down, "", 0.008)
			Paint.rod(h, 0.01, 0.45, Vector3(-0.04, 0.04, 0.2), Paint.paint(Color(0.1, 0.1, 0.1), 0.0, 0.8), down)   # its cable
		"probe":
			Paint.box(h, Vector3(0.1, 0.08, 0.08), Vector3(0, 0, -0.04), trim)
			for s: float in [-1.0, 1.0]:
				Paint.rod(h, 0.01, 0.16, Vector3(s * 0.03, 0, -0.16), steel, down)
				Paint.ball(h, 0.014, Vector3(s * 0.03, 0, -0.245), Paint.paint(Color(0.85, 0.15, 0.1), 0.2, 0.5) if s < 0.0 else trim)
			Paint.box(h, Vector3(0.03, 0.03, 0.01), Vector3(0, 0.045, -0.04), Paint.glow(Color(0.3, 1.0, 0.45), 4.0))
		"cutter":
			Paint.rod(h, 0.04, 0.16, Vector3(0, 0, -0.08), trim, down)
			Paint.rod(h, 0.03, 0.06, Vector3(0, 0, -0.19), Paint.paint(Color(0.85, 0.3, 0.1), 0.3, 0.5), down)
			Paint.rod(h, 0.012, 0.06, Vector3(0, 0, -0.245), copper, down, "", 0.006)
			Paint.rod(h, 0.012, 0.45, Vector3(0.05, 0.04, 0.2), Paint.paint(Color(0.1, 0.1, 0.1), 0.0, 0.8), down)


## Drawn at `pos` (global), turned to `face` (global point; INF keeps its heading), with its tool
## arm reaching for `work` (global; INF tucks it) and its gripper for `hold` (INF tucks it).
## Docked, it hangs still in its charger with its fans idling.
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
	basis = _heading.scaled(Vector3.ONE * size)
	_reach(_arm_r, _fore_r, work, Vector3(0.1, -0.5, -0.6))
	_reach(_arm_l, _fore_l, hold, Vector3(-0.1, -0.6, -0.5))
	# The gripper closes on a part it carries.
	var close := 0.55 if hold.is_finite() else 0.15
	for f in _fingers:
		f.rotation.x = lerpf(f.rotation.x, close, clampf(delta * 6.0, 0.0, 1.0))
	set_tool(tool_name)
	# Fans: idling on the charger, spinning up with the thrust.
	_spin += delta * (6.0 if docked else 38.0 + 30.0 * _thrust)
	for k in _rotors.size():
		_rotors[k].rotation.y = _spin * (1.0 if k % 2 == 0 else -1.0)
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
	tip = head.global_transform * Vector3(0, 0, -0.26) if head else _fore_r.global_transform * Vector3(0, 0, -FORE)


func set_tool(t: String) -> void:
	if t == tool:
		return
	tool = t
	for k: String in _heads:
		(_heads[k] as Node3D).visible = k == t


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


## The fans' downwash brightens and stretches while it flies.
func thrust(amount: float) -> void:
	_thrust = amount
	for g in _wash:
		g.scale = Vector3(1.0, 1.0 + amount * 5.0, 1.0)
		g.position.y = -0.19 - amount * 0.05
