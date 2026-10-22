class_name TradesWiringTablet
extends Node3D
## The wiring tool opened out (beenster, 2026-10-22: "the wiring tool is quite elaborate, it
## unfolds in front of you to create a small working space where the other hand can grab the
## coloured wires and put them in their sockets, the screen is steadied"). Its two leaves swing
## open out of your right hand into a flat screen held in the air in front of you on steady
## arms, and stay put while you work on it: your view holds still and the mouse is free. The
## screen shows TradesWiringPanel; your left hand follows the pointer over it and carries the
## wire you drag. Esc or CLOSE folds it away.

signal closed

## The screen (metres) and how far in front of the eye and below the view's middle it stands.
const SIZE_M := Vector2(0.6, 0.356)
const AHEAD_M := 0.5
const BELOW_M := 0.06
## Seconds to unfold.
const UNFOLD_S := 0.45

var panel: TradesWiringPanel
var viewport: SubViewport
## 0 folded in the hand, 1 open.
var opened := 0.0
var worker: BenchWorker
## The screen's resting place in the worker's body space, fixed when it opens: it holds
## still however you turn your head, and comes along if you're nudged.
var rest_local := Transform3D.IDENTITY

var _leaves: Array[Node3D] = []
var _screen: Node3D
var _arms: Array[MeshInstance3D] = []
var _closing := false


func _init(p_panel: TradesWiringPanel, p_worker: BenchWorker) -> void:
	panel = p_panel
	worker = p_worker
	name = "WiringTablet"
	top_level = true


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "Picture"
	viewport.size = Vector2i(TradesWiringPanel.CARD)
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.handle_input_locally = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(panel)
	_screen = Node3D.new()
	_screen.name = "Screen"
	add_child(_screen)
	var dark := TradesLook.metal(TradesLook.DARK, 0.6, 0.4)
	var rubber := TradesLook.metal(Color(0.07, 0.07, 0.08), 0.0, 0.85)
	var orange := TradesLook.metal(TradesLook.TRIM, 0.3, 0.45)
	# Two leaves hinged at the middle, each with half the picture.
	for side: int in [-1, 1]:
		var leaf := Node3D.new()
		leaf.name = "Leaf%s" % ("L" if side < 0 else "R")
		_screen.add_child(leaf)
		_leaves.append(leaf)
		var half := Vector2(SIZE_M.x * 0.5, SIZE_M.y)
		var back := _box(Vector3(half.x + 0.014, half.y + 0.024, 0.012), Vector3(side * half.x * 0.5, 0, -0.008), rubber, leaf)
		back.name = "Back"
		_box(Vector3(half.x + 0.016, 0.006, 0.014), Vector3(side * half.x * 0.5, half.y * 0.5 + 0.012, -0.008), orange, leaf)
		var glass := MeshInstance3D.new()
		glass.name = "Glass"
		var quad := QuadMesh.new()
		quad.size = half
		glass.mesh = quad
		glass.position = Vector3(side * half.x * 0.5, 0, 0.0)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = viewport.get_texture()
		mat.uv1_scale = Vector3(0.5, 1, 1)
		mat.uv1_offset = Vector3(0.0 if side < 0 else 0.5, 0, 0)
		glass.material_override = mat
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		leaf.add_child(glass)
	# The hinge down the middle and the steady arms back to the grip in your right hand.
	_cyl(0.008, SIZE_M.y + 0.03, Vector3(0, 0, -0.008), Vector3.ZERO, dark, _screen)
	for i in 2:
		var arm := _cyl(0.006, 1.0, Vector3.ZERO, Vector3.ZERO, dark, self)
		arm.top_level = true
		_arms.append(arm)
	rest_local = worker.global_transform.affine_inverse() * _eye_rest()
	_pose()


func _process(delta: float) -> void:
	if _closing:
		opened = move_toward(opened, 0.0, delta / (UNFOLD_S * 0.7))
		if opened <= 0.0:
			closed.emit()
			queue_free()
	else:
		opened = move_toward(opened, 1.0, delta / UNFOLD_S)
	_pose()
	_hands()


## Folds it away; `closed` follows when it's in your hand.
func fold() -> void:
	_closing = true


func is_open() -> bool:
	return opened >= 1.0 and not _closing


## Where the screen stands: in front of the eye where you're looking, a little below the
## middle of the view, turned to face the eye and level side to side.
func _eye_rest() -> Transform3D:
	var cam := worker.camera
	var eye := cam.global_position
	var view := cam.global_basis
	var at := eye - view.z * AHEAD_M - view.y * BELOW_M
	var z := (eye - at).normalized()
	var x := Vector3.UP.cross(z)
	x = x.normalized() if x.length() > 0.1 else view.x
	return Transform3D(Basis(x, z.cross(x), z), at)


## Unfolding: the folded leaves come out of the right hand and open flat on their hinge.
func _pose() -> void:
	var e := smoothstep(0.0, 1.0, opened)
	var rest := worker.global_transform * rest_local
	var grip := worker.right_hand.palm().origin
	global_transform = Transform3D(rest.basis, grip.lerp(rest.origin, e))
	_screen.scale = Vector3.ONE * lerpf(0.35, 1.0, e)
	var fold_angle := lerpf(PI * 0.5, 0.0, e)
	_leaves[0].rotation.y = fold_angle
	_leaves[1].rotation.y = -fold_angle
	# The steady arms run from the grip to the screen's lower corners.
	for i in 2:
		var corner := _screen.global_transform * Vector3((i * 2 - 1) * SIZE_M.x * 0.3, -SIZE_M.y * 0.5, -0.01)
		_lay(_arms[i], grip, corner)


## The right hand holds the grip under the screen; the left hand follows the pointer over it
## and carries the wire you drag.
func _hands() -> void:
	if not is_open():
		return
	worker.right_hand.reach_to(global_transform * Vector3(SIZE_M.x * 0.42, -SIZE_M.y * 0.62, -0.03), global_basis.z)
	var board := panel.board
	var px := board.get_global_rect().position + board.pointer
	var on := to_world(px) + global_basis.z * 0.04
	worker.left_hand.reach_to(on, global_basis.z)
	worker.left_hand.set_grip(0.9 if board.dragging >= 0 else 0.3)


## A pixel of the picture as a point on the screen (world).
func to_world(px: Vector2) -> Vector3:
	var uv := px / TradesWiringPanel.CARD
	return _screen.global_transform * Vector3((uv.x - 0.5) * SIZE_M.x, (0.5 - uv.y) * SIZE_M.y, 0.0)


## Where a ray meets the picture, in pixels; (-1, -1) off it.
func ray_px(from: Vector3, dir: Vector3) -> Vector2:
	var n := _screen.global_basis.z.normalized()
	var denom := dir.dot(n)
	if absf(denom) < 0.001:
		return Vector2(-1, -1)
	var t := (_screen.global_position - from).dot(n) / denom
	if t <= 0.0:
		return Vector2(-1, -1)
	var local := _screen.to_local(from + dir * t)
	var uv := Vector2(local.x / SIZE_M.x + 0.5, 0.5 - local.y / SIZE_M.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return Vector2(-1, -1)
	return uv * TradesWiringPanel.CARD


## The free mouse works the picture; Esc folds it away.
func _input(event: InputEvent) -> void:
	if not event is InputEventMouse:
		if event.is_action_pressed(Keys.CANCEL) and not event.is_echo():
			panel.close_requested.emit()
			get_viewport().set_input_as_handled()
		return
	if not is_open():
		get_viewport().set_input_as_handled()
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mouse := (event as InputEventMouse).position
	var px := ray_px(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))
	if px.x < 0.0:
		# Off the screen a drag still follows along its edge, and letting go drops it there.
		if panel.board.dragging < 0:
			get_viewport().set_input_as_handled()
			return
		px = Vector2(-50, -50)
	var ev := event.duplicate() as InputEventMouse
	ev.position = px
	ev.global_position = px
	viewport.push_input(ev, true)
	get_viewport().set_input_as_handled()


func _box(size: Vector3, at: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


func _cyl(radius: float, length: float, at: Vector3, rot: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.rotation = rot
	parent.add_child(m)
	return m


## Stretches a unit rod from a to b (world).
static func _lay(rod: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var along := b - a
	var length := along.length()
	rod.visible = length > 0.01
	if not rod.visible:
		return
	var y := along / length
	var side := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	rod.global_transform = Transform3D(Basis(side, y * length, side.cross(y)), a + along * 0.5)
