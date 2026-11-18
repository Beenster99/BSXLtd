class_name YardTool
extends Node3D
## Base for a hand tool, held one-handed in the suit's right glove (the rig's "ToolHold":
## the tool sits with its `grip` there; the left hand stays free to carry things).
##
## A tool wears joints down at a rate that depends on the joint kind, so picking the right
## tool for the joint matters. Subclasses set the numbers and build their own look.
##
## Tools that work up close (grinder, socket, cutter, plasma torch) carry their working head
## on an extending wrist. The logical head (`head`, built between `begin_head` and
## `end_head`) still reaches up to `boom` metres to the work. YardToolArt carries the complete
## tool and its fitted hand on that transform; the elastic section spans back to the cuff.
## Reach, contact, damage and the better marks' extra extension keep their existing rules.

enum BoomKind { TELESCOPE, HOSE }

@export var tool_name: String = "TOOL"
@export_group("Damage per second, by joint kind")
@export var rivet_rate: float = 10.0
@export var bolt_rate: float = 10.0
@export var weld_rate: float = 10.0
## Loom connectors (the plugs joining wiring loom spans at each frame ring).
@export var connector_rate: float = 10.0
## Spot welds (the tacks holding a fitting to a deck plate: ConnectionData.Kind.SPOT).
## 0 by default: only the tools that grind or cut set one.
@export var spot_rate: float = 0.0
## (FS2) How fast it takes a hull plate's seam weld off along its line, metres a second, held on the bead and moved
## along it (0: it can't). A stretch of bead under the disc is gone in the time the tool takes to pass over it at
## this speed; faster, and it leaves bead behind.
@export var follow_speed: float = 0.0
@export_group("Hardness")
## The tool's hardness (Mk I = 1): it works materials up to this tier at full speed
## (Materials.TABLE: steel and alloy are 1, titanium 2, ceramic 3, Veil alloy 4). Set by
## its mark (set_mark), from MARKS.
@export var hardness: int = 1
## Share of its rate on a material one tier harder (0.25 = a quarter); 0 makes that a
## hard stop too. Two or more tiers harder, it only sparks.
@export var under_tier_rate: float = 0.25
@export_group("Handling")
## How far the tool reaches from the camera, in metres. Short: you have to fly in close.
## A boom tool's is worked out: from the eye to its bite point at rest, plus the boom.
@export var reach: float = 3.5
## Where the right hand grips the tool (tool space, m): the palm's centre on the handle.
@export var grip := Vector3.ZERO
## How far the working head reaches out of the tool on its boom (m, Mk I; 0 = no boom).
## Each mark adds its MARKS "reach".
@export var boom: float = 0.0
## How the head is carried out: a telescoping arm, or a hose.
@export var boom_kind: BoomKind = BoomKind.TELESCOPE
## Push between tool and surface while working, in newtons. You get pushed back by the
## same amount, so you have to thrust in to stay on the job.
@export var push_force: float = 45.0
## Where the tool bites, in its own space (metres; -Z points out of the tool). The tool arm
## puts this point on the joint it locks onto.
@export var bite_point := Vector3(0.0, 0.0, -0.35)
## How quickly a worked joint glows (1.0 = full glow), per second.
@export var heat_rate: float = 1.4
## How quickly it heats a bolt enough to free a seized one (1.0 = fully hot), per second.
## Only the cutter's torch does (0 = no real heat).
@export var bolt_heat_rate: float = 0.0
@export_group("Look and sound")
@export var spark_color := Color(1.0, 0.55, 0.15)
@export var light_color := Color(1.0, 0.6, 0.25)
## How bright the glow where the tool bites is (1.0 = the cutter's), 0..1+.
@export var light_strength: float = 1.0
## How bright the sparks are (1.0 = full), 0..1.
@export var spark_strength: float = 1.0
## Share of the full spark spray thrown while biting into a joint, 0..1.
@export var spark_amount: float = 1.0
## False for tools that don't throw sparks or glow at all (the socket).
@export var sparks: bool = true

## Per mark (Mk I, II, III; docs/ECONOMY_PLAN.md 3.10): joint rates x, hardness tier,
## reach + (metres: a boom tool's boom), heat x (a better tool runs cooler). Subclasses add their own in
## _apply_mark (the torch's speed, the grabber's force, the launcher's limpets).
const MARKS: Array[Dictionary] = [
	{"rate": 1.0, "hardness": 1, "reach": 0.0, "heat": 1.0},
	{"rate": 1.4, "hardness": 2, "reach": 0.5, "heat": 0.85},
	{"rate": 2.0, "hardness": 3, "reach": 1.0, "heat": 0.7},
]
## The highest mark this tool comes in (the battery has only one).
var max_mark: int = 3
## Its id in the player's profile ("grinder", "socket"...; Profile.TOOL_IDS).
var tool_id: String = ""
## Its mark (1..max_mark), and whether this player owns it at all (unowned tools are greyed
## on the hotbar and can't be picked). ToolController.set_loadout sets both.
var mark: int = 1
var owned: bool = true
var _base: Dictionary = {}
## The working head that rides the boom (null: no boom), and where it rests (tool space:
## the boom's root, at the tool's nose).
var head: Node3D
var head_rest := Vector3.ZERO
## Its sound as the whole crew hears it (AU2): an emitter on the head, or on the tool when it
## has none (`add_voice`). Null on the limpet launcher, whose launch LimpetSystem plays for all.
var tool_voice: YardToolVoice
## From the eye to the bite point with the head at rest (m): set by the ToolController
## that holds the tool, so `reach` can be worked out.
var held_reach: float = 0.0
var _into: Node3D
## Baked artwork follows the authoritative working head, with a fitted hand at its handle.
var art: YardToolArt


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_install_art.call_deferred()


func _install_art() -> void:
	if art != null or tool_id.is_empty():
		return
	art = YardToolArt.new()
	art.tool = self
	art.position = -head_rest if head else Vector3.ZERO
	(head if head else self).add_child(art)

## True while the trigger is held. `in_contact` is true when the tool is touching something.
var working := false
var in_contact := false
## What the tool is on, for its looks (ToolController sets these every step, on every
## machine): biting a joint, the material there (the joint's harder part, or the part under
## the crosshair; "" = nothing), how fast it works it (Materials.tool_factor), the joint's
## kind (-1 = none) and how hot it is (0..1).
var biting := false
var work_material: String = ""
var work_factor: float = 1.0
var work_kind: int = -1
var work_heat: float = 0.0


## Makes this tool Mk `m`: its base numbers (as built) times the mark's row.
func set_mark(m: int) -> void:
	if _base.is_empty():
		_base = {"rivet": rivet_rate, "bolt": bolt_rate, "weld": weld_rate, "connector": connector_rate,
				"spot": spot_rate, "follow": follow_speed, "reach": reach, "heat": heat_rate, "bolt_heat": bolt_heat_rate, "boom": boom}
	mark = clampi(m, 1, max_mark)
	var row: Dictionary = MARKS[mark - 1]
	rivet_rate = float(_base["rivet"]) * float(row["rate"])
	bolt_rate = float(_base["bolt"]) * float(row["rate"])
	weld_rate = float(_base["weld"]) * float(row["rate"])
	connector_rate = float(_base["connector"]) * float(row["rate"])
	spot_rate = float(_base["spot"]) * float(row["rate"])
	follow_speed = float(_base["follow"]) * float(row["rate"])
	if float(_base["boom"]) > 0.0:
		boom = float(_base["boom"]) + float(row["reach"])
		reach = held_reach + boom if held_reach > 0.0 else float(_base["reach"])
	else:
		reach = float(_base["reach"]) + float(row["reach"])
	heat_rate = float(_base["heat"]) * float(row["heat"])
	bolt_heat_rate = float(_base["bolt_heat"]) * float(row["rate"])
	hardness = int(row["hardness"])
	_apply_mark(row)


## Override: what else the mark changes (row from MARKS; `_base` holds what you saved).
func _apply_mark(_row: Dictionary) -> void:
	pass


## How fast this tool works something of hardness `tier` (1 = full rate, 0 = not at all).
func hardness_factor(tier: int) -> float:
	return Materials.tool_factor(hardness, tier, under_tier_rate)


## Damage per second this tool does to a joint of `kind`.
func damage_rate(kind: ConnectionData.Kind) -> float:
	match kind:
		ConnectionData.Kind.RIVET:
			return rivet_rate
		ConnectionData.Kind.BOLT:
			return bolt_rate
		ConnectionData.Kind.CONNECTOR:
			return connector_rate
		ConnectionData.Kind.SPOT:
			return spot_rate
	return weld_rate


## A share of its damage rate the tool works at now, from its own state (SF3: a grinder's disc
## glazed on stock too hard for it); 1.0 unless a tool overrides it. The host's copy decides.
func rate_factor() -> float:
	return 1.0


func set_working(is_working: bool, contact: bool) -> void:
	working = is_working
	in_contact = contact


static func metal(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


## The bite point in the head's own space (the head's origin is the boom's root).
func head_bite() -> Vector3:
	return bite_point - head_rest


# --- Building a look --------------------------------------------------------------------
## Every tool is built in code from boxes and cylinders (grey-box rule), tool space:
## -Z points out of the tool toward the work, +Y up. Positions are always given in tool
## space, also for the head's parts.

## Parts built from here to `end_head` ride the boom's head, which rests at `root`.
func begin_head(root: Vector3) -> void:
	head = Node3D.new()
	head.name = "Head"
	head.position = root
	head_rest = root
	add_child(head)
	_into = head


func end_head() -> void:
	_into = null


## Puts a YardToolVoice of `kind` (a YardToolVoice.KINDS key) on the head, or on the tool when it has
## none. Called from a tool's _ready, after its head is built.
func add_voice(kind: String) -> YardToolVoice:
	tool_voice = YardToolVoice.new()
	tool_voice.kind = kind
	(head if head else self as Node3D).add_child(tool_voice)
	return tool_voice


## Pieces of the boom: telescoping tubes, or hose segments.
const TUBES: int = 3
const HOSE_SEGMENTS: int = 10
var _boom_parts: Array[MeshInstance3D] = []
var _boom_mat: StandardMaterial3D


## Draws the boom from the tool's nose to wherever the head is now: three telescoping tubes,
## or a hose that leaves the nose along the tool and comes into the head from behind. It
## glows amber, then red, as `tension` (0..1, how far out of its reach) nears 1.
func draw_boom(tension: float) -> void:
	if art:
		art.set_tension(tension)
		for part in _boom_parts:
			part.visible = false
		return
	if head == null:
		return
	if _boom_parts.is_empty():
		_build_boom()
	var a := global_transform * head_rest
	var b := head.global_position
	var length := a.distance_to(b)
	for part in _boom_parts:
		part.visible = false
	var warn := smoothstep(0.7, 1.0, tension)
	_boom_mat.emission = Color(1.0, 0.55, 0.1).lerp(Color(1.0, 0.1, 0.05), smoothstep(0.85, 1.0, tension)) * warn
	_boom_mat.emission_energy_multiplier = 1.5 * warn
	if length < 0.02:
		return
	if boom_kind == BoomKind.TELESCOPE:
		var along := (b - a) / length
		for i in TUBES:
			# Each tube a third of the way, overlapping into the next.
			var from := a + along * maxf(0.0, length * float(i) / TUBES - 0.015)
			var to := a + along * minf(length, length * float(i + 1) / TUBES + 0.02)
			_segment(_boom_parts[i], from, to)
		return
	var p1 := a - global_basis.z * length * 0.45
	var p2 := b + head.global_basis.z * length * 0.45
	var last := a
	for i in HOSE_SEGMENTS:
		var t := float(i + 1) / HOSE_SEGMENTS
		var u := 1.0 - t
		var p := a * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + b * t * t * t
		_segment(_boom_parts[i], last, p)
		last = p


func _build_boom() -> void:
	var tube := boom_kind == BoomKind.TELESCOPE
	_boom_mat = metal(Color(0.55, 0.56, 0.58), 0.85, 0.35) if tube else metal(Color(0.12, 0.12, 0.13), 0.0, 0.8)
	_boom_mat.emission_enabled = true
	_boom_mat.emission = Color.BLACK
	# Each piece a unit-long cylinder stretched between two points every frame.
	for i in (TUBES if tube else HOSE_SEGMENTS):
		var mesh := CylinderMesh.new()
		mesh.top_radius = (0.03 - 0.006 * i) if tube else 0.016
		mesh.bottom_radius = mesh.top_radius
		mesh.height = 1.0
		mesh.radial_segments = 10 if tube else 8
		mesh.rings = 1
		var part := MeshInstance3D.new()
		part.name = "Boom%d" % i
		part.mesh = mesh
		part.material_override = _boom_mat
		part.top_level = true
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.visible = false
		add_child(part)
		_boom_parts.append(part)


static func _segment(part: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length < 0.001:
		return
	var along := (b - a) / length
	var side := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized()
	part.global_transform = Transform3D(Basis(side, along, side.cross(along)).scaled_local(Vector3(1.0, length, 1.0)),
			(a + b) * 0.5)
	part.visible = true


## Adds a built piece to the tool, or to the head while building it (from tool space).
func attach(n: Node3D) -> void:
	if _into:
		n.position -= head_rest
		_into.add_child(n)
	else:
		add_child(n)

## A box at `at`, turned by `rot` (radians), painted `mat`.
func box(size: Vector3, at: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.rotation = rot
	attach(m)
	return m


## A cylinder `radius` by `length` (along its own Y, so rot X 90 degrees lays it along Z).
func cylinder(radius: float, length: float, at: Vector3, rot: Vector3, mat: Material,
		radial: int = 16, top_radius: float = -1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = radial
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.rotation = rot
	attach(m)
	return m


## A cylinder from `a` to `b` (tool space), `radius` thick (tapering to `top_radius` at b).
func rod(a: Vector3, b: Vector3, radius: float, mat: Material, radial: int = 12,
		top_radius: float = -1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = radial
	mesh.rings = 1
	m.mesh = mesh
	m.material_override = mat
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.95 else Vector3.RIGHT).normalized()
	m.basis = Basis(side, up, side.cross(up))
	m.position = (a + b) * 0.5
	attach(m)
	return m


## A ball `radius` across at `at` (tool space), squashed by `squash`.
func ball(radius: float, at: Vector3, mat: Material, squash := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.scale = squash
	attach(m)
	return m


## A small lit screen on the tool showing `readout_text()`: a dark panel at `at` (its
## centre), `size` metres (width, height), tilted up and back toward the wearer's eye.
var _readout: Label3D


func readout(at: Vector3, size: Vector2, color := Color(0.45, 0.95, 1.0)) -> void:
	var panel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, size.y, 0.008)
	panel.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.03, 0.04)
	mat.metallic = 0.2
	mat.roughness = 0.25
	panel.material_override = mat
	# Face the eye: it sits up, to the left and behind the hand holding the tool.
	var to_eye := Vector3(-0.4, 0.55, 0.75).normalized()
	panel.basis = Basis.looking_at(-to_eye, Vector3.UP)
	panel.position = at
	add_child(panel)
	_readout = Label3D.new()
	_readout.font = ShipKit.mono_font()
	_readout.font_size = 48
	_readout.pixel_size = size.y / 3.6 / 48.0
	_readout.modulate = color
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_readout.position = Vector3(-size.x * 0.46, 0.0, 0.006)
	_readout.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.add_child(_readout)


## Up to three short lines for the tool's screen (override; "" = no screen).
func readout_text() -> String:
	return ""


func _physics_process(_delta: float) -> void:
	if _readout and visible:
		_readout.text = readout_text()
