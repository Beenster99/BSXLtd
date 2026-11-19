extends Node3D
## A TartanCo RF-2 refurbisher: a hovering work drone (the androids walk the berth's ribs; these
## fly), white plates, near-black trim, ochre arms, four thruster pods, a sensor brow with a
## visor strip, a claw arm that carries the part and a tool arm whose head changes with the
## stage: scanner, nut runner, grit blaster, welding torch, test probe. Presentation only: the
## shop moves it to the RefurbWorks state each frame.

const Paint := preload("res://modules/refurb/internal/refurb_paint.gd")

const TOOLS: PackedStringArray = ["scanner", "nut_runner", "blaster", "welder", "probe"]
const SHOULDER_R := Vector3(0.42, -0.08, -0.18)
const SHOULDER_L := Vector3(-0.42, -0.08, -0.18)
const UPPER := 0.5
const FORE := 0.5
## Drawn this much bigger than its parts are listed (a 1.4 m drone).
const SIZE := 1.4

var serial := ""
var tool := ""
## Where the tool's tip is (global), for effects.
var tip := Vector3.ZERO

var _arm_r: Node3D
var _arm_l: Node3D
var _fore_r: Node3D
var _fore_l: Node3D
var _heads: Dictionary = {}
var _charge_bar: MeshInstance3D
var _charge_mat: StandardMaterial3D
var _pods: Array[MeshInstance3D] = []
var _bob := 0.0
var _heading := Basis()


func build(serial_no: String) -> void:
	serial = serial_no
	name = "RF2_" + serial_no.get_slice("/", 1)
	var plates := Paint.paint(Paint.PLATES, 0.15, 0.45, "satin_paint")
	var trim := Paint.paint(Paint.TRIM, 0.4, 0.5, "gunmetal")
	var ochre := Paint.paint(Paint.OCHRE, 0.2, 0.5, "satin_paint")
	var steel := Paint.paint(Paint.STEEL, 0.8, 0.35, "brushed_steel")
	# The body: a rounded shell over a dark belly band, the sensor brow at the front (-Z).
	Paint.ball(self, 0.5, Vector3.ZERO, plates, Vector3(1.0, 0.72, 1.15), "Shell")
	Paint.rod(self, 0.47, 0.1, Vector3(0, -0.06, 0), trim, Basis(), "Band").scale = Vector3(1.0, 1.0, 1.14)
	Paint.ball(self, 0.3, Vector3(0, 0.3, 0.05), ochre, Vector3(1.2, 0.35, 1.3), "Spine")
	Paint.box(self, Vector3(0.46, 0.17, 0.16), Vector3(0, 0.08, -0.55), trim, "Brow")
	Paint.box(self, Vector3(0.38, 0.04, 0.02), Vector3(0, 0.1, -0.635), Paint.glow(Color(0.35, 0.85, 1.0), 4.0), "Visor")
	Paint.box(self, Vector3(0.06, 0.06, 0.02), Vector3(0.16, 0.0, -0.635), Paint.glow(Color(1.0, 0.45, 0.1), 3.0))
	# Four thruster pods under the shell's corners, their nozzles glowing down.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var at := Vector3(sx * 0.42, -0.2, sz * 0.4)
			Paint.rod(self, 0.09, 0.22, at, trim)
			var g := Paint.rod(self, 0.06, 0.03, at - Vector3(0, 0.12, 0), Paint.glow(Color(0.45, 0.7, 1.0), 2.5))
			_pods.append(g)
	# Charge bar on its back, and the serial.
	Paint.box(self, Vector3(0.34, 0.07, 0.03), Vector3(0, 0.12, 0.575), trim)
	_charge_mat = StandardMaterial3D.new()
	_charge_mat.emission_enabled = true
	_charge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_charge_bar = Paint.box(self, Vector3(0.3, 0.045, 0.02), Vector3(0, 0.12, 0.59), _charge_mat, "Charge")
	for side: float in [-1.0, 1.0]:
		var l := Paint.label(self, "TARTANCO\n" + serial, Vector3(side * 0.505, 0.02, 0.05), 0.0028, Color(0.12, 0.12, 0.13), 40, Vector3(side, 0, 0))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Arms: a shoulder ball, an ochre upper arm, a steel forearm; the right carries the tools.
	_arm_r = _arm(SHOULDER_R, trim, ochre)
	_arm_l = _arm(SHOULDER_L, trim, ochre)
	_fore_r = _arm_r.get_node("Fore")
	_fore_l = _arm_l.get_node("Fore")
	var claw := Node3D.new()
	claw.name = "Claw"
	claw.position = Vector3(0, 0, -FORE)
	_fore_l.add_child(claw)
	for s: float in [-1.0, 1.0]:
		Paint.box(claw, Vector3(0.03, 0.05, 0.16), Vector3(s * 0.06, 0, -0.07), steel).rotation.y = s * 0.3
	for t in TOOLS:
		var h := Node3D.new()
		h.name = t
		h.position = Vector3(0, 0, -FORE)
		h.visible = false
		_fore_r.add_child(h)
		_heads[t] = h
		_tool_head(t, h, trim, steel)


func _arm(at: Vector3, trim: Material, ochre: Material) -> Node3D:
	var arm := Node3D.new()
	arm.position = at
	add_child(arm)
	Paint.ball(arm, 0.09, Vector3.ZERO, trim)
	Paint.box(arm, Vector3(0.09, 0.09, UPPER), Vector3(0, 0, -UPPER * 0.5), ochre)
	var fore := Node3D.new()
	fore.name = "Fore"
	fore.position = Vector3(0, 0, -UPPER)
	arm.add_child(fore)
	Paint.ball(fore, 0.065, Vector3.ZERO, trim)
	Paint.box(fore, Vector3(0.07, 0.07, FORE), Vector3(0, 0, -FORE * 0.5), Paint.paint(Paint.STEEL, 0.8, 0.35, "brushed_steel"))
	return arm


func _tool_head(t: String, h: Node3D, trim: Material, steel: Material) -> void:
	var down := Basis(Vector3.RIGHT, PI * 0.5)   # a cylinder along -Z
	match t:
		"scanner":
			Paint.box(h, Vector3(0.16, 0.1, 0.1), Vector3(0, 0, -0.05), trim)
			Paint.box(h, Vector3(0.12, 0.03, 0.01), Vector3(0, 0, -0.105), Paint.glow(Color(0.3, 0.8, 1.0), 5.0))
		"nut_runner":
			Paint.rod(h, 0.055, 0.16, Vector3(0, 0, -0.08), trim, down)
			Paint.rod(h, 0.025, 0.1, Vector3(0, 0, -0.2), steel, down)
		"blaster":
			Paint.rod(h, 0.05, 0.12, Vector3(0, 0, -0.06), trim, down)
			Paint.rod(h, 0.025, 0.16, Vector3(0, 0, -0.2), Paint.paint(Paint.OCHRE, 0.2, 0.5), down, "", 0.045)
			Paint.rod(h, 0.012, 0.5, Vector3(0.06, 0.05, 0.2), trim, down)   # the grit hose
		"welder":
			Paint.rod(h, 0.035, 0.18, Vector3(0, 0, -0.09), trim, down)
			Paint.rod(h, 0.018, 0.1, Vector3(0, -0.02, -0.21), Paint.paint(Color(0.72, 0.45, 0.25), 0.9, 0.3, "copper"), down, "", 0.008)
		"probe":
			Paint.box(h, Vector3(0.1, 0.08, 0.08), Vector3(0, 0, -0.04), trim)
			for s: float in [-1.0, 1.0]:
				Paint.rod(h, 0.01, 0.16, Vector3(s * 0.03, 0, -0.16), steel, down)
			Paint.box(h, Vector3(0.03, 0.03, 0.01), Vector3(0, 0.045, -0.04), Paint.glow(Color(0.3, 1.0, 0.45), 4.0))


## Drawn at `pos` (global), turned to `face` (global point; INF keeps its heading), with its tool
## arm reaching for `work` (global; INF tucks it) and its claw for `hold` (INF tucks it).
func pose(pos: Vector3, face: Vector3, work: Vector3, hold: Vector3, charge: float, charging: bool, tool_name: String, delta: float) -> void:
	_bob += delta
	var phase := float(serial.hash() % 100) * 0.07
	global_position = pos + Vector3(0, sin(_bob * 1.7 + phase) * 0.035, 0)
	if face.is_finite():
		var flat := Vector3(face.x - pos.x, 0, face.z - pos.z)
		if flat.length() > 0.05:
			var want := Basis.looking_at(flat.normalized(), Vector3.UP)
			_heading = _heading.slerp(want, clampf(delta * 3.0, 0.0, 1.0)).orthonormalized()
	basis = _heading.scaled(Vector3.ONE * SIZE)
	_reach(_arm_r, _fore_r, work, Vector3(0.1, -0.5, -0.6))
	_reach(_arm_l, _fore_l, hold, Vector3(-0.1, -0.6, -0.5))
	set_tool(tool_name)
	var c := Color(0.25, 1.0, 0.35) if charge > 0.6 else (Color(1.0, 0.7, 0.1) if charge > 0.3 else Color(1.0, 0.2, 0.1))
	if charging:
		c = Color(1.0, 0.7, 0.1) if fmod(_bob, 1.0) < 0.6 else Color(0.3, 0.2, 0.05)
	_charge_mat.albedo_color = c
	_charge_mat.emission = c
	_charge_bar.scale.x = maxf(charge, 0.05)
	_charge_bar.position.x = -0.15 * (1.0 - maxf(charge, 0.05))
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
	fore.global_transform = Transform3D(_look(global_basis * (hand - elbow).normalized(), global_basis * bend).scaled(Vector3.ONE * SIZE), to_global(elbow))


func _aim(node: Node3D, from: Vector3, to: Vector3) -> void:
	var dir := (to - from).normalized()
	node.transform = Transform3D(_look(dir, Vector3.UP), from)


static func _look(dir: Vector3, up: Vector3) -> Basis:
	if absf(dir.dot(up.normalized())) > 0.98:
		up = Vector3.RIGHT
	return Basis.looking_at(dir, up)


## The thrusters flare while it flies.
func thrust(amount: float) -> void:
	for g in _pods:
		g.scale = Vector3(1.0, 1.0 + amount * 6.0, 1.0)
