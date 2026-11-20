extends RefCounted
## How each type of build bot looks (master plan 6.4: "Every type has its own body, tools,
## movement and sound. Detailed models with moving arms, lights, wear and paint"). Built in code
## from primitive shapes, in the bot's paint with its wear (bot_wear.gdshader), dark trim, bare
## steel, rubber and glowing eyes, jets and work lamps.
##
## A look is a Node3D, facing -Z, about a metre and a half across (the hauler and the plater are
## bigger). Its parts, by name, for BotView to move:
##   Body, Head (turns to the work), ArmL / ArmR (and ArmL2 / ArmR2: the plater's), each with an
##   "Elbow" and a "Tip" (where the tool's sparks, flash or beam start), Cargo (a crate of parts,
##   hidden till it carries one), Lamp (a work light), and meta "jets" (the thruster glows) and
##   "eyes" (the eye glows), "family", "tool".

const WEAR_SHADER := preload("res://modules/bots/internal/bot_wear.gdshader")

## family -> how it is built: body (shape, size), head, arms (count, lengths, tool), jets, extras.
const FAMILIES := {
	"general": {"body": "drum", "size": Vector3(1.1, 0.9, 1.1), "head": "cam", "arms": 2, "upper": 0.55, "fore": 0.5, "tool": "gripper", "jets": 4, "extra": ["battery", "stripes"]},
	"welder": {"body": "capsule", "size": Vector3(0.8, 1.2, 0.8), "head": "visor", "arms": 2, "upper": 0.7, "fore": 0.65, "tool": "torch", "jets": 2, "extra": ["gas_bottles"]},
	"riveter": {"body": "box", "size": Vector3(1.2, 0.9, 1.0), "head": "slot", "arms": 2, "upper": 0.45, "fore": 0.45, "tool": "rivet", "jets": 4, "extra": ["magazine"]},
	"plater": {"body": "frame", "size": Vector3(1.8, 0.5, 1.4), "head": "cam", "arms": 4, "upper": 0.6, "fore": 0.55, "tool": "suction", "jets": 4, "extra": ["stripes"]},
	"wirer": {"body": "sphere", "size": Vector3(0.9, 0.9, 0.9), "head": "none", "arms": 1, "upper": 0.6, "fore": 0.55, "tool": "clip", "jets": 2, "extra": ["reel"]},
	"pipe_fitter": {"body": "box", "size": Vector3(1.0, 1.0, 1.1), "head": "cam", "arms": 2, "upper": 0.55, "fore": 0.5, "tool": "clamp", "jets": 4, "extra": ["pipe_rack"]},
	"hauler": {"body": "cargo", "size": Vector3(2.2, 1.2, 1.8), "head": "slot", "arms": 2, "upper": 0.6, "fore": 0.6, "tool": "gripper", "jets": 4, "extra": ["big_jets"]},
	"inspector": {"body": "sphere", "size": Vector3(0.75, 0.75, 0.75), "head": "eye", "arms": 0, "upper": 0.0, "fore": 0.0, "tool": "scanner", "jets": 3, "extra": ["antenna", "halo"]},
	"refurbisher": {"body": "drum", "size": Vector3(1.0, 1.0, 1.0), "head": "cam", "arms": 2, "upper": 0.55, "fore": 0.55, "tool": "lance", "jets": 4, "extra": ["tool_tray"]},
	"frame_tech": {"body": "box", "size": Vector3(1.3, 1.1, 1.2), "head": "visor", "arms": 2, "upper": 0.65, "fore": 0.6, "tool": "torch_rivet", "jets": 4, "extra": ["gas_bottles", "stripes"]},
	"fitout_tech": {"body": "drum", "size": Vector3(1.2, 1.0, 1.2), "head": "cam", "arms": 2, "upper": 0.6, "fore": 0.55, "tool": "socket_clip", "jets": 4, "extra": ["reel", "stripes"]},
}

const TRIM := Color(0.12, 0.13, 0.14)
const STEEL := Color(0.66, 0.68, 0.7)
const RUBBER := Color(0.06, 0.06, 0.06)
const EYE := Color(0.35, 0.85, 1.0)
const JET := Color(0.45, 0.7, 1.0)
const LAMP := Color(1.0, 0.92, 0.78)
const HAZARD := Color(0.92, 0.74, 0.12)

static var _mats: Dictionary = {}


## A bot's look: `family` (BotTypes' family), painted `paint`, at `mark` (1 to 3), worn `wear`.
static func make(family: String, paint: Color, mark := 1, wear := 0.0, seed_value := 0) -> Node3D:
	var f: Dictionary = FAMILIES.get(family, FAMILIES.general)
	var root := Node3D.new()
	root.name = "BotLook"
	root.set_meta("family", family)
	root.set_meta("tool", str(f.tool))
	var skin := painted(paint, wear, seed_value)
	var trim := _mat(TRIM, 0.6, 0.55)
	var steel := _mat(STEEL, 0.9, 0.3)
	var rubber := _mat(RUBBER, 0.0, 0.9)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var size: Vector3 = f.size
	_body(body, str(f.body), size, skin, trim, steel)
	var eyes: Array = []
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, size.y * 0.5 + 0.08, -size.z * 0.18)
	body.add_child(head)
	_head(head, str(f.head), skin, trim, steel, eyes, size)
	# Arms, from the shoulders at the front.
	var n := int(f.arms)
	var sides: Array = []
	match n:
		1:
			sides = [[0.0, -0.05, "ArmR"]]
		2:
			sides = [[-1.0, 0.0, "ArmL"], [1.0, 0.0, "ArmR"]]
		4:
			sides = [[-1.0, -0.25, "ArmL"], [1.0, -0.25, "ArmR"], [-1.0, 0.25, "ArmL2"], [1.0, 0.25, "ArmR2"]]
	var tools := str(f.tool).split("_")
	for i in sides.size():
		var s: Array = sides[i]
		var tool := str(tools[i % tools.size()]) if tools.size() > 1 and str(f.tool) in ["torch_rivet", "socket_clip"] else str(f.tool)
		if str(f.tool) == "torch" and i == 0 and n == 2:
			tool = "filler"
		var arm := _arm(str(s[2]), float(f.upper), float(f.fore), tool, trim, steel, rubber, skin)
		arm.position = Vector3(float(s[0]) * (size.x * 0.5 + 0.02), -0.02, -size.z * 0.3 + float(s[1]) * size.z)
		body.add_child(arm)
	# Thrusters round the bottom.
	var jets: Array = []
	var jn := int(f.jets)
	var big := (f.extra as Array).has("big_jets")
	for i in jn:
		var a := TAU * float(i) / float(jn) + PI * 0.25
		var pod := Node3D.new()
		pod.name = "Jet%d" % i
		pod.position = Vector3(cos(a) * size.x * 0.5, -size.y * 0.42, sin(a) * size.z * 0.5)
		body.add_child(pod)
		var r := 0.16 if big else 0.1
		_add(pod, _cyl(r, r * 1.25, r * 2.4), trim, Vector3.ZERO)
		_add(pod, _cyl(r * 1.05, r * 0.8, 0.05), steel, Vector3(0, -r * 1.25, 0))
		var glow := _add(pod, _cyl(r * 0.75, r * 0.4, 0.04), _glow(JET, 2.0), Vector3(0, -r * 1.3, 0))
		jets.append(glow)
	root.set_meta("jets", jets)
	for e: String in f.extra:
		_extra(body, e, size, skin, trim, steel, rubber, paint)
	# Marks: Mk2 a chevron, Mk3 armour and a second lamp.
	if mark >= 2:
		var chev := _add(body, _box(Vector3(size.x * 0.55, 0.06, 0.02)), _mat(Color(0.86, 0.68, 0.2), 0.7, 0.35),
				Vector3(0, size.y * 0.18, -size.z * 0.5 - 0.012))
		chev.name = "Chevron"
	if mark >= 3:
		for sx: float in [-1.0, 1.0]:
			_add(body, _box(Vector3(0.04, size.y * 0.6, size.z * 0.6)), trim, Vector3(sx * (size.x * 0.5 + 0.03), 0.02, 0.0))
	# The work lamp on the head, and the cargo it carries.
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = LAMP
	lamp.light_energy = 0.9 if mark < 3 else 1.3
	lamp.omni_range = 4.5
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, 0.1, -0.35)
	head.add_child(lamp)
	var cargo := Node3D.new()
	cargo.name = "Cargo"
	cargo.visible = false
	cargo.position = Vector3(0, -size.y * 0.5 - 0.45, 0) if family != "hauler" else Vector3(0, -0.05, 0.1)
	body.add_child(cargo)
	_add(cargo, _box(Vector3(0.9, 0.55, 0.7)), _mat(Color(0.42, 0.44, 0.4), 0.3, 0.7), Vector3.ZERO)
	_add(cargo, _box(Vector3(0.95, 0.06, 0.75)), _mat(HAZARD, 0.2, 0.6), Vector3(0, 0.25, 0))
	for sx: float in [-0.32, 0.32]:
		_add(cargo, _box(Vector3(0.1, 0.58, 0.74)), steel, Vector3(sx, 0, 0))
	root.set_meta("eyes", eyes)
	root.set_meta("skin", skin)
	return root


## The paint of a bot: its colour with its wear (seeded so no two bots chip alike).
static func painted(paint: Color, wear: float, seed_value := 0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WEAR_SHADER
	m.set_shader_parameter("paint", paint)
	m.set_shader_parameter("wear", clampf(wear, 0.0, 1.0) * 0.8 + 0.08)
	m.set_shader_parameter("grime", 0.25 + clampf(wear, 0.0, 1.0) * 0.5)
	m.set_shader_parameter("seed", float(seed_value % 97) * 0.137)
	return m


# --- Moving it ---------------------------------------------------------------------------------

## Poses `look` at time `t` (s): `work` 0..1 how hard it works (arms reach and tap), `speed` its
## flying speed (m/s: the jets burn brighter, it leans into the way it goes), `lean` its velocity
## in its own space.
static func animate(look: Node3D, t: float, work: float, speed: float, lean := Vector3.ZERO) -> void:
	var body := look.get_node_or_null("Body") as Node3D
	if body == null:
		return
	var bob := sin(t * 2.1 + look.get_instance_id() % 7) * 0.035
	body.position.y = bob
	body.rotation = Vector3(clampf(lean.z * 0.06, -0.25, 0.25), 0.0, clampf(-lean.x * 0.06, -0.25, 0.25))
	for n: String in ["ArmL", "ArmR", "ArmL2", "ArmR2"]:
		var arm := body.get_node_or_null(n) as Node3D
		if arm == null:
			continue
		var side := -1.0 if n.begins_with("ArmL") else 1.0
		var phase := t * (7.0 if work > 0.5 else 1.4) + (0.0 if side > 0.0 else 1.3)
		var reach := lerpf(-0.25, -1.25, work)
		arm.rotation = Vector3(reach + sin(phase) * lerpf(0.08, 0.12, work), side * lerpf(0.15, 0.05, work), side * lerpf(0.25, 0.08, work))
		var elbow := arm.get_node_or_null("Elbow") as Node3D
		if elbow:
			elbow.rotation = Vector3(lerpf(-0.9, -0.35, work) + cos(phase * 1.3) * 0.06 * work, 0, 0)
	var head := body.get_node_or_null("Head") as Node3D
	if head:
		head.rotation.y = sin(t * 0.7) * lerpf(0.35, 0.08, work)
		head.rotation.x = lerpf(0.0, 0.35, work)
	var glow := clampf(0.6 + speed * 0.35, 0.6, 4.0)
	for j: MeshInstance3D in look.get_meta("jets", []):
		var m := j.material_override as StandardMaterial3D
		if m:
			m.emission_energy_multiplier = glow
		j.scale = Vector3(1, 1, 1) * clampf(0.8 + speed * 0.08, 0.8, 1.6)


## The tool tips of a look (where the work's sparks start): Node3Ds.
static func tips(look: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in look.find_children("Tip", "Node3D", true, false):
		out.append(n as Node3D)
	return out


# --- Building it -------------------------------------------------------------------------------

static func _body(body: Node3D, shape: String, size: Vector3, skin: Material, trim: Material, steel: Material) -> void:
	match shape:
		"drum":
			_add(body, _cyl(size.x * 0.5, size.x * 0.5, size.y * 0.8), skin, Vector3.ZERO)
			_add(body, _sphere(size.x * 0.48, size.y * 0.38), skin, Vector3(0, size.y * 0.38, 0))
			_add(body, _cyl(size.x * 0.52, size.x * 0.52, 0.07), trim, Vector3(0, -size.y * 0.4, 0))
			_add(body, _cyl(size.x * 0.515, size.x * 0.515, 0.05), trim, Vector3(0, size.y * 0.12, 0))
			# Access panels and a vent grille on the front.
			_add(body, _box(Vector3(size.x * 0.4, size.y * 0.32, 0.03)), trim, Vector3(0, -0.08, -size.z * 0.5 + 0.02))
			for i in 4:
				_add(body, _box(Vector3(size.x * 0.32, 0.018, 0.035)), steel, Vector3(0, -0.18 + i * 0.06, -size.z * 0.5 + 0.005))
		"capsule":
			var c := CapsuleMesh.new()
			c.radius = size.x * 0.5
			c.height = size.y
			_add(body, c, skin, Vector3.ZERO)
			_add(body, _cyl(size.x * 0.52, size.x * 0.52, 0.06), trim, Vector3(0, -size.y * 0.1, 0))
			_add(body, _box(Vector3(size.x * 0.5, size.y * 0.25, 0.04)), trim, Vector3(0, -size.y * 0.25, -size.z * 0.45))
		"box":
			_add(body, _box(size * Vector3(1, 0.85, 1)), skin, Vector3.ZERO)
			_add(body, _box(Vector3(size.x * 1.02, 0.08, size.z * 1.02)), trim, Vector3(0, -size.y * 0.42, 0))
			_add(body, _box(Vector3(size.x * 0.86, 0.12, size.z * 0.86)), skin, Vector3(0, size.y * 0.47, 0))
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					_add(body, _box(Vector3(0.08, size.y * 0.86, 0.08)), trim, Vector3(sx * size.x * 0.48, 0, sz * size.z * 0.48))
			_add(body, _box(Vector3(size.x * 0.5, size.y * 0.3, 0.03)), trim, Vector3(0, -0.05, -size.z * 0.5 - 0.005))
		"frame":
			# The plater: an open deck frame with a core box in the middle.
			for sz: float in [-1.0, 1.0]:
				_add(body, _box(Vector3(size.x, 0.1, 0.12)), skin, Vector3(0, 0, sz * size.z * 0.45))
			for sx: float in [-1.0, 1.0]:
				_add(body, _box(Vector3(0.12, 0.1, size.z)), skin, Vector3(sx * size.x * 0.45, 0, 0))
			_add(body, _box(Vector3(size.x * 0.45, size.y, size.z * 0.5)), skin, Vector3.ZERO)
			_add(body, _box(Vector3(size.x * 0.47, 0.06, size.z * 0.52)), trim, Vector3(0, -size.y * 0.5, 0))
			_add(body, _box(Vector3(size.x * 0.3, size.y * 0.5, 0.03)), trim, Vector3(0, 0, -size.z * 0.25 - 0.01))
		"sphere":
			_add(body, _sphere(size.x * 0.5, size.y * 0.5), skin, Vector3.ZERO)
			var band := TorusMesh.new()
			band.inner_radius = size.x * 0.47
			band.outer_radius = size.x * 0.54
			_add(body, band, trim, Vector3.ZERO)
		"cargo":
			# The hauler: a cab at the front and an open cargo frame behind.
			_add(body, _box(Vector3(size.x * 0.7, size.y * 0.55, size.z * 0.32)), skin, Vector3(0, size.y * 0.15, -size.z * 0.36))
			for sx: float in [-1.0, 1.0]:
				_add(body, _box(Vector3(0.12, 0.12, size.z)), skin, Vector3(sx * size.x * 0.45, size.y * 0.35, 0))
				_add(body, _box(Vector3(0.12, 0.12, size.z)), skin, Vector3(sx * size.x * 0.45, -size.y * 0.35, 0))
				for sz: float in [-0.5, 0.5]:
					_add(body, _box(Vector3(0.12, size.y * 0.7, 0.12)), trim, Vector3(sx * size.x * 0.45, 0, sz * size.z * 0.9))
			for sz: float in [-0.5, 0.5]:
				_add(body, _box(Vector3(size.x * 0.9, 0.1, 0.1)), skin, Vector3(0, size.y * 0.35, sz * size.z * 0.9))
			_add(body, _box(Vector3(size.x * 0.66, 0.04, size.z * 0.6)), steel, Vector3(0, -size.y * 0.32, 0.1))


static func _head(head: Node3D, kind: String, skin: Material, trim: Material, steel: Material, eyes: Array, size: Vector3) -> void:
	match kind:
		"cam":
			_add(head, _cyl(0.06, 0.06, 0.16), trim, Vector3(0, -0.04, 0))
			_add(head, _box(Vector3(0.34, 0.2, 0.26)), skin, Vector3(0, 0.08, 0))
			var e := _add(head, _cyl(0.07, 0.07, 0.05), _glow(EYE, 3.0), Vector3(0.07, 0.08, -0.14), Vector3(PI * 0.5, 0, 0))
			var e2 := _add(head, _cyl(0.04, 0.04, 0.05), _glow(EYE, 2.0), Vector3(-0.09, 0.1, -0.14), Vector3(PI * 0.5, 0, 0))
			_add(head, _cyl(0.085, 0.085, 0.03), steel, Vector3(0.07, 0.08, -0.125), Vector3(PI * 0.5, 0, 0))
			eyes.append_array([e, e2])
		"visor":
			_add(head, _sphere(0.2, 0.17), skin, Vector3(0, 0.1, 0))
			var v := _add(head, _box(Vector3(0.3, 0.09, 0.05)), _glow(Color(1.0, 0.55, 0.2), 2.5), Vector3(0, 0.12, -0.17))
			_add(head, _box(Vector3(0.34, 0.13, 0.04)), trim, Vector3(0, 0.12, -0.15))
			eyes.append(v)
		"slot":
			_add(head, _box(Vector3(0.5, 0.14, 0.2)), trim, Vector3(0, 0.02, -size.z * 0.3))
			var s := _add(head, _box(Vector3(0.38, 0.04, 0.03)), _glow(Color(1.0, 0.3, 0.2), 3.0), Vector3(0, 0.03, -size.z * 0.3 - 0.1))
			eyes.append(s)
		"eye":
			head.position = Vector3(0, 0, -size.z * 0.42)
			_add(head, _cyl(0.2, 0.2, 0.08), trim, Vector3.ZERO, Vector3(PI * 0.5, 0, 0))
			var e := _add(head, _sphere(0.13, 0.13), _glow(EYE, 3.5), Vector3(0, 0, -0.03))
			var ring := TorusMesh.new()
			ring.inner_radius = 0.17
			ring.outer_radius = 0.21
			_add(head, ring, _glow(Color(0.6, 1.0, 0.7), 1.8), Vector3(0, 0, -0.05), Vector3(PI * 0.5, 0, 0))
			eyes.append(e)


## An arm: a shoulder joint, an upper arm, an elbow, a forearm, and a tool at the tip.
static func _arm(arm_name: String, upper: float, fore: float, tool: String, trim: Material, steel: Material,
		rubber: Material, skin: Material) -> Node3D:
	var arm := Node3D.new()
	arm.name = arm_name
	_add(arm, _sphere(0.085, 0.085), trim, Vector3.ZERO)
	_add(arm, _box(Vector3(0.09, 0.09, upper)), skin, Vector3(0, 0, -upper * 0.5))
	_add(arm, _cyl(0.025, 0.025, upper * 0.85), steel, Vector3(0.06, 0, -upper * 0.5), Vector3(PI * 0.5, 0, 0))
	var elbow := Node3D.new()
	elbow.name = "Elbow"
	elbow.position = Vector3(0, 0, -upper)
	arm.add_child(elbow)
	_add(elbow, _cyl(0.07, 0.07, 0.12), trim, Vector3.ZERO, Vector3(0, 0, PI * 0.5))
	_add(elbow, _box(Vector3(0.07, 0.07, fore)), steel, Vector3(0, 0, -fore * 0.5))
	var tip := Node3D.new()
	tip.name = "Tip"
	tip.position = Vector3(0, 0, -fore - 0.08)
	elbow.add_child(tip)
	match tool:
		"torch":
			_add(tip, _cyl(0.04, 0.025, 0.18), steel, Vector3(0, 0, 0.02), Vector3(PI * 0.5, 0, 0))
			_add(tip, _cyl(0.05, 0.05, 0.08), trim, Vector3(0, 0, 0.12), Vector3(PI * 0.5, 0, 0))
		"filler":
			var spool := TorusMesh.new()
			spool.inner_radius = 0.04
			spool.outer_radius = 0.09
			_add(tip, spool, _mat(Color(0.75, 0.5, 0.25), 0.8, 0.35), Vector3(0, 0, 0.05), Vector3(0, 0, PI * 0.5))
		"rivet":
			_add(tip, _cyl(0.06, 0.06, 0.2), trim, Vector3(0, 0, 0.05), Vector3(PI * 0.5, 0, 0))
			_add(tip, _cyl(0.02, 0.02, 0.08), steel, Vector3(0, 0, -0.08), Vector3(PI * 0.5, 0, 0))
			_add(tip, _box(Vector3(0.04, 0.12, 0.05)), trim, Vector3(0, -0.08, 0.08))
		"socket":
			_add(tip, _cyl(0.055, 0.055, 0.16), trim, Vector3(0, 0, 0.04), Vector3(PI * 0.5, 0, 0))
			_add(tip, _cyl(0.035, 0.035, 0.06), steel, Vector3(0, 0, -0.07), Vector3(PI * 0.5, 0, 0))
		"suction":
			_add(tip, _cyl(0.14, 0.12, 0.04), rubber, Vector3(0, 0, -0.02), Vector3(PI * 0.5, 0, 0))
			_add(tip, _cyl(0.04, 0.04, 0.08), steel, Vector3(0, 0, 0.04), Vector3(PI * 0.5, 0, 0))
		"clip":
			_add(tip, _box(Vector3(0.08, 0.06, 0.12)), trim, Vector3(0, 0, 0.02))
			_add(tip, _box(Vector3(0.02, 0.05, 0.05)), steel, Vector3(0, 0, -0.06))
		"clamp":
			for sx: float in [-1.0, 1.0]:
				_add(tip, _box(Vector3(0.03, 0.07, 0.18)), steel, Vector3(sx * 0.06, 0, -0.02))
			_add(tip, _box(Vector3(0.16, 0.06, 0.05)), trim, Vector3(0, 0, 0.07))
		"lance":
			_add(tip, _cyl(0.025, 0.02, 0.35), steel, Vector3(0, 0, -0.08), Vector3(PI * 0.5, 0, 0))
			_add(tip, _cyl(0.05, 0.05, 0.08), _mat(Color(0.85, 0.75, 0.2), 0.3, 0.5), Vector3(0, 0, 0.08), Vector3(PI * 0.5, 0, 0))
		_:
			# A three-fingered gripper.
			_add(tip, _cyl(0.06, 0.06, 0.05), trim, Vector3(0, 0, 0.04), Vector3(PI * 0.5, 0, 0))
			for i in 3:
				var a := TAU * float(i) / 3.0
				_add(tip, _box(Vector3(0.025, 0.025, 0.12)), steel, Vector3(cos(a) * 0.045, sin(a) * 0.045, -0.05))
	return arm


static func _extra(body: Node3D, what: String, size: Vector3, skin: Material, trim: Material, steel: Material,
		rubber: Material, paint: Color) -> void:
	match what:
		"battery":
			_add(body, _box(Vector3(size.x * 0.5, size.y * 0.45, 0.22)), trim, Vector3(0, 0, size.z * 0.5 + 0.08))
			_add(body, _box(Vector3(size.x * 0.12, 0.05, 0.03)), _glow(Color(0.4, 1.0, 0.5), 2.0), Vector3(0, 0.12, size.z * 0.5 + 0.2))
		"stripes":
			for i in 5:
				var x := (float(i) - 2.0) * size.x * 0.16
				_add(body, _box(Vector3(size.x * 0.07, 0.06, 0.02)), _mat(TRIM if i % 2 else HAZARD, 0.2, 0.6),
						Vector3(x, -size.y * 0.3, -size.z * 0.5 - 0.01))
		"gas_bottles":
			for sx: float in [-0.15, 0.15]:
				_add(body, _cyl(0.09, 0.09, size.y * 0.6), _mat(Color(0.2, 0.45, 0.25) if sx < 0.0 else Color(0.7, 0.2, 0.15), 0.3, 0.5),
						Vector3(sx, 0.0, size.z * 0.5 + 0.06))
				_add(body, _cyl(0.04, 0.04, 0.06), steel, Vector3(sx, size.y * 0.32, size.z * 0.5 + 0.06))
		"magazine":
			_add(body, _cyl(0.22, 0.22, 0.16), trim, Vector3(0, size.y * 0.5 + 0.08, 0.15))
			_add(body, _cyl(0.18, 0.18, 0.18), steel, Vector3(0, size.y * 0.5 + 0.08, 0.15))
		"reel":
			var reel := TorusMesh.new()
			reel.inner_radius = 0.12
			reel.outer_radius = 0.26
			_add(body, reel, _mat(Color(0.85, 0.3, 0.1), 0.2, 0.6), Vector3(0, 0.0, size.z * 0.5 + 0.05), Vector3(PI * 0.5, 0, 0))
			_add(body, _cyl(0.12, 0.12, 0.2), trim, Vector3(0, 0.0, size.z * 0.5 + 0.05), Vector3(PI * 0.5, 0, 0))
		"pipe_rack":
			for i in 3:
				_add(body, _cyl(0.05, 0.05, size.x * 0.9), steel, Vector3(0, size.y * 0.5 + 0.06, (float(i) - 1.0) * 0.14), Vector3(0, 0, PI * 0.5))
		"big_jets":
			for sx: float in [-1.0, 1.0]:
				_add(body, _cyl(0.2, 0.26, 0.5), trim, Vector3(sx * size.x * 0.52, 0, size.z * 0.38), Vector3(PI * 0.5, 0, 0))
		"antenna":
			_add(body, _cyl(0.012, 0.012, 0.5), steel, Vector3(0.12, size.y * 0.6, 0.1))
			_add(body, _sphere(0.03, 0.03), _glow(Color(1.0, 0.3, 0.2), 3.0), Vector3(0.12, size.y * 0.6 + 0.25, 0.1))
		"halo":
			var ring := TorusMesh.new()
			ring.inner_radius = size.x * 0.62
			ring.outer_radius = size.x * 0.68
			_add(body, ring, trim, Vector3(0, -size.y * 0.15, 0))
		"tool_tray":
			_add(body, _box(Vector3(size.x * 0.7, 0.06, 0.3)), steel, Vector3(0, -size.y * 0.1, size.z * 0.55))
			for i in 3:
				_add(body, _box(Vector3(0.06, 0.12, 0.06)), _mat(paint.darkened(0.3), 0.4, 0.5), Vector3((float(i) - 1.0) * 0.18, -size.y * 0.02, size.z * 0.55))


static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 20
	c.rings = 1
	return c


static func _sphere(r: float, h: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h * 2.0
	s.radial_segments = 20
	s.rings = 10
	return s


static func _mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var key := "%s/%.2f/%.2f" % [c.to_html(), metal, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	_mats[key] = m
	return m


static func _glow(c: Color, energy: float) -> StandardMaterial3D:
	# Not shared: each glow is turned up and down on its own (the jets).
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
