class_name TradesTestStand
extends Node3D
## A tool test stand in the yard (beenster, 2026-10-22: "add a few parts somewhere in the yard
## so that I can try the tools out"), behind the flag "trades.test_stand". A steel practice
## panel on two posts in the Pre-assembly wing (Ship and Bay's spot "bench_preassembly"),
## with every kind of joint on it to try each tool on: M12 and M10 bolts, two rows of rivets,
## two weld seams and a power, a data and a fuel plug. Some start made, so there's something
## to take off too.
##
## Its joints are FastenerPoints like the ship's, worked by the same station
## (TradesShipJoints), but they're practice only: the station keeps their state itself
## (`practice`), and neither Ship and Bay nor Quality hears about them. Stand space: metres,
## the origin on the floor under the panel's front face, +Z out toward where you stand.

## The slot every practice joint belongs to ("test_stand/<n>").
const SLOT := "test_stand"
const PANEL := Vector2(2.4, 1.3)
## The panel's lower edge above the floor, and its thickness (metres).
const PANEL_FROM := 0.55
const PANEL_T := 0.03
const RED := Color(0.85, 0.2, 0.15)
const AMBER := Color(1.0, 0.62, 0.15)
const GREEN := Color(0.3, 1.0, 0.45)

## The practice joints, in stand space.
var joints: Array[FastenerPoint] = []
## Joints that start made.
var made_at_start := {}
## joint_id -> true while made; the station sets it (TradesShipJoints.practice).
var is_made: Callable

var _markers := {}
## Where the player points (world) and how near it a ring must be to show (m); INF shows all.
var focus := Vector3.ZERO
var focus_radius := INF
var _ring_on: StandardMaterial3D
var _ring_off: StandardMaterial3D
var _head: StandardMaterial3D


func _init() -> void:
	name = "TestStand"
	top_level = true
	_lay_out()


func _ready() -> void:
	_ring_on = TradesLook.glow(GREEN, 0.9)
	_ring_off = TradesLook.glow(AMBER, 0.9)
	_head = TradesLook.metal(Color(0.62, 0.64, 0.66), 0.9, 0.35)
	_build_frame()
	for f in joints:
		var m := _marker(f)
		add_child(m)
		_markers[f.joint_id] = m
	_show()


func _process(_delta: float) -> void:
	_show()


## Every joint's marker as it stands now: a lit ring, green when made and amber when not,
## with the bolt head, rivet head, bead or plug in place only while it's made.
func _show() -> void:
	for f in joints:
		var on := bool(is_made.call(f.joint_id)) if is_made.is_valid() else made_at_start.has(f.joint_id)
		var m := _markers.get(f.joint_id) as MeshInstance3D
		if m == null:
			continue
		m.material_override = _ring_on if on else _ring_off
		(m.get_child(0) as Node3D).visible = on
		# Only the rings near where you point are lit (trades.near_rings); the heads stay.
		m.transparency = 0.0 if focus_radius == INF or (global_transform * f.position).distance_to(focus) <= focus_radius else 1.0


func _lay_out() -> void:
	var n := 0
	var front := PANEL_T
	# Bolts down the left: M12 (made) over M10 (loose).
	for row: Array in [["M12", 1.55, true], ["M10", 1.25, false]]:
		for x: float in [-1.0, -0.85, -0.7]:
			n += 1
			_add("b%d" % n, "bolt", row[0], Vector3(x, row[1], front), row[2])
	# Rivets in the middle: the top row set, the bottom row empty.
	for row: Array in [[1.55, true], [1.3, false]]:
		for i in 6:
			n += 1
			_add("r%d" % n, "rivet", "RIVET_4", Vector3(-0.42 + i * 0.12, row[0], front), row[1])
	# Two weld seams along the bottom: one welded, one open.
	for row: Array in [[1.0, true], [0.8, false]]:
		n += 1
		var f := _add("w%d" % n, "weld", "", Vector3(-0.15, row[0], front), row[1])
		f.seam_up = Vector3.RIGHT
		f.seam_size = Vector2(0.5, 0.012)
	# Plugs on the right: power and data wire up on the diagram, fuel just pushes home.
	for plug: Array in [["power", 0.55], ["data", 0.8], ["fuel", 1.02]]:
		n += 1
		_add("p%d" % n, "connector", plug[0], Vector3(plug[1], 1.4, front + 0.06), false)


func _add(id: String, kind: String, spec: String, at: Vector3, made: bool) -> FastenerPoint:
	var f := FastenerPoint.new()
	f.joint_id = "%s/%s" % [SLOT, id]
	f.kind = kind
	f.spec = spec
	f.position = at
	f.normal = Vector3.BACK
	joints.append(f)
	if made:
		made_at_start[f.joint_id] = true
	return f


# --- The look ---------------------------------------------------------------------------------

func _build_frame() -> void:
	var steel := TradesLook.metal(Color(0.74, 0.75, 0.76), 0.25, 0.55)
	var dark := TradesLook.metal(TradesLook.DARK, 0.6, 0.5)
	var orange := TradesLook.metal(TradesLook.TRIM, 0.3, 0.45)
	var mid_y := PANEL_FROM + PANEL.y * 0.5
	_box(Vector3(PANEL.x, PANEL.y, PANEL_T), Vector3(0, mid_y, PANEL_T * 0.5), steel)
	# An orange edge round the panel, two posts on feet, a cross bar behind.
	_box(Vector3(PANEL.x + 0.04, 0.04, 0.05), Vector3(0, PANEL_FROM + PANEL.y + 0.02, 0.0), orange)
	_box(Vector3(PANEL.x + 0.04, 0.04, 0.05), Vector3(0, PANEL_FROM - 0.02, 0.0), orange)
	for x: float in [-PANEL.x * 0.5 - 0.05, PANEL.x * 0.5 + 0.05]:
		_box(Vector3(0.08, PANEL_FROM + PANEL.y + 0.15, 0.08), Vector3(x, (PANEL_FROM + PANEL.y + 0.15) * 0.5, 0.0), dark)
		_box(Vector3(0.14, 0.04, 0.7), Vector3(x, 0.02, 0.0), dark)
	_box(Vector3(PANEL.x, 0.06, 0.06), Vector3(0, PANEL_FROM + 0.25, -0.08), dark)
	# Seam lines where the welds go, and a socket box for each plug.
	for f in joints:
		if f.kind == "weld":
			_box(Vector3(f.seam_size.x + 0.04, 0.004, 0.002), f.position + Vector3(0, 0, 0.001), dark)
		elif f.kind == "connector":
			_box(Vector3(0.14, 0.14, 0.06), f.position - Vector3(0, 0, 0.03), dark)
			_label(f.spec.to_upper(), f.position + Vector3(0, -0.11, -0.0), 28)
	# What's where, and the sign on top.
	_label("BOLTS  M12 / M10", Vector3(-0.85, 1.72, PANEL_T + 0.002), 30)
	_label("RIVETS", Vector3(-0.12, 1.72, PANEL_T + 0.002), 30)
	_label("WELDS", Vector3(-0.15, 1.13, PANEL_T + 0.002), 30)
	_label("PLUGS", Vector3(0.79, 1.72, PANEL_T + 0.002), 30)
	var top := PANEL_FROM + PANEL.y
	_box(Vector3(1.5, 0.3, 0.03), Vector3(0, top + 0.24, 0.0), dark)
	var sign := _label("BSX  TOOL TEST STAND", Vector3(0, top + 0.28, 0.017), 64)
	sign.modulate = TradesLook.TRIM
	var note := _label("Practice only: nothing here goes on a ship", Vector3(0, top + 0.16, 0.017), 26)
	note.modulate = TradesLook.SHELL
	# Something to stand against.
	var body := StaticBody3D.new()
	body.name = "Body"
	add_child(body)
	for box: Array in [[Vector3(PANEL.x + 0.3, PANEL_FROM + PANEL.y + 0.15, 0.1), Vector3(0, (PANEL_FROM + PANEL.y + 0.15) * 0.5, 0.0)]]:
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = box[0]
		shape.shape = b
		shape.position = box[1]
		body.add_child(shape)


## A fastener's marker: a thin ring (or strip, for a weld) lit by its state, with the head as
## its first child (shown only while the joint is made).
func _marker(f: FastenerPoint) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var head := MeshInstance3D.new()
	head.material_override = _head
	# The ring's +Y is out of the panel (+Z).
	var out := Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
	ring.transform = Transform3D(out, f.position + Vector3(0, 0, 0.002))
	match f.kind:
		"weld":
			var strip := BoxMesh.new()
			strip.size = Vector3(f.seam_size.x, 0.003, f.seam_size.y + 0.012)
			ring.mesh = strip
			var bead := CapsuleMesh.new()
			bead.radius = f.seam_size.y * 0.5
			bead.height = f.seam_size.x
			bead.radial_segments = 6
			bead.rings = 2
			head.mesh = bead
			head.rotation = Vector3(0, 0, PI * 0.5)
			head.position.y = f.seam_size.y * 0.2
		"rivet":
			ring.mesh = _ring(0.016, 0.022)
			var dome := SphereMesh.new()
			dome.radius = 0.012
			dome.height = 0.012
			dome.is_hemisphere = true
			dome.radial_segments = 10
			dome.rings = 3
			head.mesh = dome
		"connector":
			ring.mesh = _ring(0.034, 0.042)
			var plug := CylinderMesh.new()
			plug.top_radius = 0.03
			plug.bottom_radius = 0.032
			plug.height = 0.06
			plug.radial_segments = 12
			head.mesh = plug
			head.position.y = 0.03
		_:
			ring.mesh = _ring(0.024, 0.034)
			var hex := CylinderMesh.new()
			hex.top_radius = 0.021
			hex.bottom_radius = 0.021
			hex.height = 0.016
			hex.radial_segments = 6
			head.mesh = hex
			head.position.y = 0.01
	ring.add_child(head)
	return ring


static func _ring(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 16
	t.ring_segments = 4
	return t


func _box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	add_child(m)
	return m


func _label(text: String, at: Vector3, font_size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = TradesLook.mono_font()
	l.font_size = font_size
	l.pixel_size = 0.0015
	l.modulate = Color(0.12, 0.13, 0.15)
	l.outline_size = 0
	l.position = at
	add_child(l)
	return l
