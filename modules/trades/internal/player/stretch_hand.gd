class_name StretchHand
extends Node3D
## One of the worker's hands: a symbolic glove at the end of an elastic arm. At rest it sits
## on its mount in front of the camera. reach_to() sends it out to a point in the world; the
## sleeve stretches behind it and glows amber, then red, as it nears full stretch. Past
## that it lets go (snapped is emitted) and springs back.
##
## Void Salvage's tool arm stretches the same way, and looks the same: the dark metal arm
## (ToolController) ending in the salvager suit's glove (PlayerModel's suit and frame).
## For now (flag "trades.sphere_hands") the glove is a plain ball in the suit's colour with
## an orange band: the arm still ends where the glove's palm would be, so tools sit the same.

signal snapped

## Where the hand sits on its mount, in the mount's space.
const REST := Vector3(0.0, 0.0, 0.0)
## The stand-in ball hand's radius (metres).
const SPHERE_R := 0.042

## How quickly the hand slides out and back (1/s).
@export var speed := 9.0
## Mirror for the left hand.
@export var left := false

var reach_m := 0.9
var stretch_m := 0.9
## Where the hand is going (world space), and whether it is out at all.
var target := Vector3.ZERO
var target_normal := Vector3.UP
var out := false
## 0 at rest, 1 on the target.
var level := 0.0
## What the hand holds, carried at its palm (any Node3D; null for nothing).
var held: Node3D
## Where the stretchy forearm starts (world): the body's elbow in third person, or INF for
## the mount in front of the camera (first person).
var arm_root := Vector3.INF

var _glove: Node3D
var _fingers: Array[Node3D] = []
var _sleeve: MeshInstance3D
var _sleeve_mat: StandardMaterial3D
var _grip := 0.0
var _spin := 0.0


func _ready() -> void:
	_glove = Node3D.new()
	_glove.name = "Glove"
	add_child(_glove)
	var glove := TradesLook.metal(TradesLook.SUIT, 0.0, 0.75)
	var frame := TradesLook.metal(TradesLook.FRAME, 0.8, 0.4)
	var accent := TradesLook.metal(TradesLook.TRIM, 0.4, 0.5)
	accent.emission_enabled = true
	accent.emission = TradesLook.TRIM
	accent.emission_energy_multiplier = 0.5
	if Flags.is_on("trades.sphere_hands"):
		_build_sphere(glove, accent)
	else:
		_build_glove(glove, frame, accent)
	_sleeve_mat = TradesLook.metal(TradesLook.ARM, 0.6, 0.45)
	_sleeve_mat.emission_enabled = true
	_sleeve_mat.emission = Color.BLACK
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.016
	mesh.bottom_radius = 0.024
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 1
	_sleeve = MeshInstance3D.new()
	_sleeve.name = "Sleeve"
	_sleeve.mesh = mesh
	_sleeve.material_override = _sleeve_mat
	_sleeve.top_level = true
	_sleeve.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sleeve.visible = false
	add_child(_sleeve)


## The stand-in hand: a ball where the palm is, banded round its middle.
func _build_sphere(mat: Material, accent: Material) -> void:
	var ball := MeshInstance3D.new()
	ball.name = "Ball"
	var mesh := SphereMesh.new()
	mesh.radius = SPHERE_R
	mesh.height = SPHERE_R * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	ball.mesh = mesh
	ball.material_override = mat
	_glove.add_child(ball)
	var band := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = SPHERE_R * 0.97
	ring.outer_radius = SPHERE_R * 1.07
	ring.rings = 20
	ring.ring_segments = 6
	band.mesh = ring
	band.material_override = accent
	band.rotation.x = PI * 0.5
	_glove.add_child(band)


func _build_glove(glove: Material, frame: Material, accent: Material) -> void:
	var side := -1.0 if left else 1.0
	_box(Vector3(0.08, 0.03, 0.09), Vector3(0, 0, -0.01), glove, _glove)
	_box(Vector3(0.06, 0.008, 0.05), Vector3(0, 0.018, -0.012), frame, _glove)      # back plate
	_box(Vector3(0.03, 0.004, 0.012), Vector3(0, 0.024, 0.0), accent, _glove)       # colour flash
	var cuff := MeshInstance3D.new()
	var cuff_mesh := CylinderMesh.new()
	cuff_mesh.top_radius = 0.034
	cuff_mesh.bottom_radius = 0.036
	cuff_mesh.height = 0.04
	cuff_mesh.radial_segments = 12
	cuff.mesh = cuff_mesh
	cuff.material_override = frame
	cuff.position = Vector3(0, 0, 0.055)
	cuff.rotation.x = PI * 0.5
	_glove.add_child(cuff)
	for i in 4:
		var f := Node3D.new()
		f.position = Vector3((i - 1.5) * 0.02, 0.0, -0.056)
		_glove.add_child(f)
		_box(Vector3(0.016, 0.019, 0.05), Vector3(0, 0, -0.022), glove, f)
		_box(Vector3(0.012, 0.004, 0.014), Vector3(0, 0.011, -0.012), frame, f)    # knuckle plate
		_fingers.append(f)
	var thumb := Node3D.new()
	thumb.position = Vector3(-0.043 * side, 0.0, -0.005)
	thumb.rotation.y = deg_to_rad(35.0) * side
	_glove.add_child(thumb)
	_box(Vector3(0.017, 0.019, 0.046), Vector3(0, 0, -0.02), glove, thumb)
	_fingers.append(thumb)


## Send the hand out to `point` (world space), palm down onto a surface facing `normal`.
func reach_to(point: Vector3, normal: Vector3 = Vector3.UP) -> void:
	target = point
	target_normal = normal
	out = true


func come_back() -> void:
	out = false


func is_on_target() -> bool:
	return out and level >= 0.999


## How far along its stretch the arm is, 0..1 (1 = about to let go).
func tension() -> float:
	var d := _shoulder().distance_to(target)
	return clampf((d - reach_m) / maxf(0.01, stretch_m), 0.0, 1.0)


## The glove's transform in the world (fingers along -Z, back of the hand +Y).
func palm() -> Transform3D:
	return _glove.global_transform


func can_reach(point: Vector3) -> bool:
	return _shoulder().distance_to(point) <= reach_m + stretch_m


## Close the fingers (0 open, 1 fist) and turn the wrist about the reach axis (radians).
func set_grip(amount: float) -> void:
	_grip = clampf(amount, 0.0, 1.0)


func set_spin(radians: float) -> void:
	_spin = radians


func _process(delta: float) -> void:
	if out and not can_reach(target):
		out = false
		snapped.emit()
	level = move_toward(level, 1.0 if out else 0.0, delta * speed)
	var eased := smoothstep(0.0, 1.0, level)
	var rest := get_parent_node_3d().global_transform * Transform3D(Basis(), REST) if get_parent_node_3d() else Transform3D()
	var at := rest
	if eased > 0.0:
		var from := rest.origin
		var dir := (target - from).normalized() if target.distance_to(from) > 0.01 else -rest.basis.z
		# Lean the palm onto the surface, fingers pointing along the reach.
		var up := target_normal if absf(target_normal.dot(dir)) < 0.95 else rest.basis.y
		var on := Transform3D(Basis.looking_at(dir, up), target + target_normal * 0.02)
		at = rest.interpolate_with(on, eased)
	_glove.global_transform = at
	_glove.rotate_object_local(Vector3.FORWARD, _spin)
	for f in _fingers:
		f.rotation.x = -_grip * 1.2
	if held:
		held.global_position = _glove.global_transform * Vector3(0, -0.02, -0.06)
	var elbow := arm_root.is_finite()
	_draw_sleeve(arm_root if elbow else rest.origin, _glove.global_transform * Vector3(0, 0, 0.08), 1.0 if elbow else eased)


func _draw_sleeve(a: Vector3, b: Vector3, eased: float) -> void:
	var length := a.distance_to(b)
	_sleeve.visible = eased > 0.0 and length > 0.06 and visible
	if not _sleeve.visible:
		return
	var along := (b - a) / length
	var side := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized()
	_sleeve.global_transform = Transform3D(Basis(side, along, side.cross(along)).scaled_local(Vector3(1.0, length, 1.0)), (a + b) * 0.5)
	var warn := smoothstep(0.6, 1.0, tension()) if out else 0.0
	_sleeve_mat.emission = Color(1.0, 0.55, 0.1).lerp(Color(1.0, 0.1, 0.05), smoothstep(0.85, 1.0, tension())) * warn
	_sleeve_mat.emission_energy_multiplier = 1.5 * warn


## The shoulder the arm stretches from: the mount, pulled back toward the body.
func _shoulder() -> Vector3:
	var p := get_parent_node_3d()
	return p.global_transform * Vector3(0, 0.1, 0.35) if p else global_position


func _box(size: Vector3, at: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m

