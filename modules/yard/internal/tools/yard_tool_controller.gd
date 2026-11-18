class_name YardToolController
extends Node
## The tools in your suit's right hand and the hotbar (stage 1.4): Void Salvage's grinder,
## cutter, socket and grabber (ToolController at Void Salvage 6523ae5, cut down to one player
## and the yard's YardWorkpiece bodies). A child "Tools" of the YardRig.
##
## 1 to 4 pick a tool, H puts it away, the wheel goes round the hotbar (with the grabber
## holding, it pushes the load out or pulls it in), the left mouse button works it. A joint
## tool locks onto the joint under the crosshair and its head rides out on its boom to it;
## the joint loses health at the tool's rate for its kind and breaks free. The tool pushes
## you back as hard as it pushes the work.

## The hotbar, left to right (keys 1 to 6): Void Salvage's four, then BSX's tractor and tablet.
const ORDER: Array[String] = ["grinder", "cutter", "socket", "grabber", "tractor", "tablet"]
## Where the tools are held (the rig's head space): Void Salvage's ToolHold.
const HOLD := "Transform3D(0.9594144, 0.07234603, 0.272562, 0.014606048, 0.9524863, -0.30423117, -0.28162146, 0.29586482, 0.91277236, 0.28, -0.37, -0.44)"

## How close to a joint the aim must land (m), and to a weld's seam.
@export var snap_radius: float = 0.3
@export var weld_snap: float = 0.08
## The boom's slack past its reach before it lets go (m), and how fast the head rides out.
@export var arm_stretch: float = 0.1
@export var arm_speed: float = 10.0
## The most a tool's push may speed a loose piece up (m/s²) and spin it (rad/s²).
@export var max_push_accel: float = 0.5
@export var max_push_spin: float = 0.3

signal tool_changed(index: int, holstered: bool)

var rig: YardRig
var tools: Array[YardTool] = []
var active_index: int = 0
var holstered := true
## The trigger now (the left mouse button, or `trigger_override` 0/1 in tests).
var trigger := false
var trigger_override: int = -1
var aim_origin := Vector3.ZERO
var aim_dir := Vector3.FORWARD
## The joint the crosshair is on (or the lock's), and its body.
var targeted: ConnectionData
var targeted_body: YardWorkpiece
var targeted_seized := false
## The joint the tool is locked onto while the trigger is held.
var lock: ConnectionData
var lock_body: YardWorkpiece
## Joints this rig's tools have broken (tests read it).
var broken: int = 0
## The grabber's hold.
var grab_body: RigidBody3D
var grab_point := Vector3.ZERO
var hold_distance: float = 2.5
var grab_turn := Quaternion.IDENTITY

var _effects: YardToolEffects
var _beam: MeshInstance3D
var _beam_mesh := ImmediateMesh.new()
var _work: Array = []
var _arm_level: float = 0.0
var _arm_target := Transform3D()
var _was_trigger := false
var _hotbar: HBoxContainer
var _field: MeshInstance3D


func _ready() -> void:
	name = "Tools"
	rig = get_parent() as YardRig
	var hold := Node3D.new()
	hold.name = "ToolHold"
	hold.transform = str_to_var(HOLD)
	rig.head.add_child(hold)
	for tool: YardTool in [YardGrinder.new(), YardCutter.new(), YardSocket.new(), YardGrabber.new(), YardTractor.new(), YardTablet.new()]:
		tool.position = -tool.grip
		tool.held_reach = (hold.transform * (tool.bite_point - tool.grip)).length()
		tool.visible = false
		tools.append(tool)
		hold.add_child(tool)
		tool.set_mark(1)
	_effects = YardToolEffects.new()
	_effects.name = "ToolEffects"
	add_child(_effects)
	_beam = MeshInstance3D.new()
	_beam.name = "GrabBeam"
	_beam.mesh = _beam_mesh
	_beam.top_level = true
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.albedo_color = Color(0.45, 0.85, 1.0, 0.8)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam.material_override = beam_mat
	add_child(_beam)
	_field = MeshInstance3D.new()
	_field.name = "TractorField"
	_field.mesh = _field_mesh()
	_field.top_level = true
	_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var field_mat := ShaderMaterial.new()
	field_mat.shader = preload("res://modules/yard/assets/tools_fx/tractor_field.gdshader")
	_field.material_override = field_mat
	_field.visible = false
	add_child(_field)
	_build_hotbar()
	holster(true)


func _unhandled_input(event: InputEvent) -> void:
	if HudSlots.pointer_claimed():
		return
	for i in ORDER.size():
		if event.is_action_pressed("yard.tool_%d" % (i + 1)):
			select_tool(i)
			return
	if event.is_action_pressed("yard.holster"):
		holster(not holstered)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var b := (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP:
			wheel(1)
		elif b == MOUSE_BUTTON_WHEEL_DOWN:
			wheel(-1)


## The wheel: with the grabber holding, up pushes the load out and down pulls it in; else it
## goes round the hotbar (and draws a tool put away).
func wheel(step: int) -> void:
	var grabber := active_tool() as YardGrabber
	if grabber and grab_body and not holstered:
		hold_distance = clampf(hold_distance + step * grabber.wheel_step, grabber.min_hold, grabber.max_hold)
		return
	if holstered:
		select_tool(active_index)
		return
	select_tool(posmod(active_index - step, tools.size()))


func select_tool(index: int) -> void:
	if index < 0 or index >= tools.size():
		return
	if index != active_index:
		release_grab()
		lock = null
		lock_body = null
		_arm_level = 0.0
	active_index = index
	holstered = false
	for tool in tools:
		tool.visible = tool == tools[active_index]
		tool.position = -tool.grip
		tool.basis = Basis()
		if tool.head:
			tool.head.transform = Transform3D(Basis(), tool.head_rest)
		tool.set_working(false, false)
	_show_in_hand()
	tool_changed.emit(active_index, holstered)


func active_tool() -> YardTool:
	return tools[active_index]


## Puts the tool away (the hand free) or draws it again.
func holster(on: bool) -> void:
	if not on:
		select_tool(active_index)
		return
	release_grab()
	lock = null
	lock_body = null
	_arm_level = 0.0
	_draw_beam(false)
	holstered = true
	for tool in tools:
		tool.visible = false
		tool.set_working(false, false)
	_show_in_hand()
	tool_changed.emit(active_index, holstered)


static func is_joint_tool(tool: YardTool) -> bool:
	return not tool is YardGrabber and not tool is YardTablet


func _show_in_hand() -> void:
	if rig.avatar:
		rig.avatar.tool_override = null if holstered else active_tool()
	_refresh_hotbar()


func _physics_process(delta: float) -> void:
	var free := not HudSlots.pointer_claimed()
	var held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	trigger = (held if trigger_override < 0 else trigger_override > 0) and free
	var aim := rig.head.global_transform
	aim_origin = aim.origin
	aim_dir = -aim.basis.z
	if holstered:
		trigger = false
		targeted = null
		targeted_body = null
		_work = []
		_was_trigger = false
		return
	var tool := active_tool()
	var hit := _cast_ray(tool.reach)
	var joint_tool := is_joint_tool(tool)
	_work = []
	targeted = null
	targeted_body = null
	var body := hit.get("collider") as YardWorkpiece if not hit.is_empty() else null
	if body and joint_tool:
		targeted = body.joint_near(hit.position, snap_radius, weld_snap)
		if targeted:
			targeted_body = body
	_update_lock(tool, joint_tool)
	if lock:
		targeted = lock
		targeted_body = lock_body
		body = lock_body
		hit = {"position": lock_body.joint_position(lock), "normal": lock_body.joint_normal(lock), "collider": lock_body}
	var socket := tool as YardSocket
	targeted_seized = targeted != null and socket != null and targeted.is_seized(socket.seized_chance) \
			and targeted.heat_now() < socket.loosen_heat
	if socket:
		socket.straining = targeted_seized
	var material := targeted_body.joint_material(targeted) if targeted else ""
	if material == "" and body:
		var part := body.part_at_hit(hit)
		material = part.material if part else ""
	var factor := tool.hardness_factor(Materials.tier(material)) if targeted and material != "" else 1.0
	tool.biting = targeted != null
	tool.work_material = material
	tool.work_factor = factor
	tool.work_kind = targeted.kind if targeted else -1
	tool.work_heat = targeted.heat_now() if targeted else 0.0
	if tool is YardTablet:
		_update_tablet(tool as YardTablet, hit)
	elif tool is YardGrabber:
		_update_grab(tool as YardGrabber, hit)
	else:
		_update_cutting(tool, hit, body, factor, delta)
	_was_trigger = trigger


func _update_lock(tool: YardTool, joint_tool: bool) -> void:
	if lock and (lock.is_broken() or not is_instance_valid(lock_body) or not lock_body.model.has_joint(lock)):
		lock = null
		lock_body = null
	if not joint_tool or not trigger:
		lock = null
		lock_body = null
		return
	if lock:
		if rest_bite(tool).distance_to(lock_body.joint_position(lock)) > tool.boom + arm_stretch:
			lock = null
			lock_body = null
		return
	if targeted:
		lock = targeted
		lock_body = targeted_body


## Where the tool's bite point is with its head in (world).
func rest_bite(tool: YardTool) -> Vector3:
	return tool.global_transform * tool.bite_point


func _update_cutting(tool: YardTool, hit: Dictionary, body: YardWorkpiece, factor: float, delta: float) -> void:
	_draw_beam(false)
	var touching := not hit.is_empty()
	var working := trigger and touching
	tool.set_working(trigger, touching)
	if tool.tool_voice and not tool is YardSocket:
		var through := 1.0 - targeted.health_fraction() if targeted else 0.0
		tool.tool_voice.feed(trigger, touching, targeted != null, through, factor, 1.0)
	if tool is YardSocket and (tool as YardSocket).voice:
		(tool as YardSocket).voice.feed(trigger, targeted != null, working and targeted_seized)
	if not working:
		_effects.update(false, Vector3.ZERO, Vector3.UP, tool, false)
		return
	_work = [hit.position, hit.normal]
	_effects.update(true, hit.position, hit.normal, tool, targeted != null)
	if tool is YardSocket and targeted_seized and rig.feel:
		rig.feel.set_rumble("hammer", rig.feel.hammer_rumble)
	elif rig.feel:
		rig.feel.set_rumble("hammer", 0.0)
	# The tool pushes the surface, the surface pushes you back.
	var push_dir := ((hit.position as Vector3) - aim_origin).normalized()
	rig.apply_central_force(-push_dir * tool.push_force)
	if targeted == null or targeted_body == null:
		return
	targeted_body.heat_joint(targeted, tool.heat_rate * delta)
	if targeted.kind == ConnectionData.Kind.BOLT and tool.bolt_heat_rate > 0.0:
		targeted.add_heat(tool.bolt_heat_rate * delta)
	if not targeted_body.freeze:
		var push := minf(tool.push_force, targeted_body.mass * max_push_accel)
		_push(targeted_body, push_dir * push, hit.position)
	if targeted_seized:
		return
	if targeted_body.damage_connection(targeted, tool.damage_rate(targeted.kind) * factor * tool.rate_factor() * delta):
		broken += 1
		lock = null
		lock_body = null


func _process(delta: float) -> void:
	if tools.is_empty():
		return
	var tool := active_tool()
	if tool == null or not tool.is_inside_tree():
		return
	var on := tool.head != null and not _work.is_empty() and tool.visible
	if on:
		var at: Vector3 = _work[0]
		var root := tool.global_transform * tool.head_rest
		# Point the head into the surface, leaning toward where it comes from.
		var dir := (-(_work[1] as Vector3) + (at - root).normalized()).normalized()
		if dir.length() < 0.1:
			dir = (at - root).normalized()
		var up := tool.global_basis.y
		if absf(dir.dot(up)) > 0.95:
			up = tool.global_basis.z
		var basis := Basis.looking_at(dir, up)
		var origin := at - basis * tool.head_bite()
		origin = root + (origin - root).limit_length(tool.boom + arm_stretch)
		_arm_target = tool.global_transform.affine_inverse() * Transform3D(basis, origin)
	_arm_level = move_toward(_arm_level, 1.0 if on else 0.0, delta * arm_speed)
	var eased := smoothstep(0.0, 1.0, _arm_level)
	if tool.head:
		var rest := Transform3D(Basis(), tool.head_rest)
		tool.head.transform = rest.interpolate_with(_arm_target, eased) if eased > 0.0 else rest
	var tension := 0.0
	if on:
		tension = clampf(rest_bite(tool).distance_to(_work[0]) / maxf(tool.boom + arm_stretch, 0.01), 0.0, 1.0)
	tool.draw_boom(tension)


# --- Beam tablet -----------------------------------------------------------------------

func _update_tablet(tablet: YardTablet, hit: Dictionary) -> void:
	_effects.update(false, Vector3.ZERO, Vector3.UP, tablet, false)
	_draw_beam(false)
	if trigger and not _was_trigger:
		tablet.toggle()
	var body := hit.get("collider") as YardWorkpiece if not hit.is_empty() else null
	if body:
		tablet.reading = body


# --- Grabber ---------------------------------------------------------------------------

func _update_grab(grabber: YardGrabber, hit: Dictionary) -> void:
	_effects.update(false, Vector3.ZERO, Vector3.UP, grabber, false)
	if trigger and not _was_trigger and not hit.is_empty():
		var body := hit.collider as RigidBody3D
		if body and not body.freeze:
			grab_body = body
			grab_point = body.global_transform.affine_inverse() * (hit.position as Vector3)
			hold_distance = clampf(aim_origin.distance_to(hit.position), grabber.min_hold, grabber.max_hold)
			grab_turn = Quaternion(_aim_frame().inverse() * body.global_basis.orthonormalized()).normalized()
	if not trigger or (grab_body and not is_instance_valid(grab_body)):
		release_grab()
	var holding := grab_body != null
	grabber.set_working(trigger, holding)
	grabber.set_gripping(holding)
	grabber.hold_range = hold_distance
	grabber.held_mass = grab_body.mass if holding else 0.0
	if grabber.tool_voice:
		grabber.tool_voice.feed(holding, holding, false, 0.0, 1.0, 1.0)
	if not holding:
		_effects.grab(false, Vector3.ZERO, Vector3.ZERO)
		_draw_beam(false)
		return
	var body := grab_body
	var grip := body.global_transform * grab_point
	var hold := aim_origin + aim_dir * hold_distance
	var stretch := hold - grip
	if stretch.length() > grabber.break_distance:
		release_grab()
		_draw_beam(false)
		return
	_draw_beam(true, grip)
	_effects.grab(true, grip, (grabber as Node3D).global_position + aim_dir * 0.25)
	# A spring-damper between the claw and the grip, sized by the pair's reduced mass (on a
	# deck your stance takes the reaction and only the load moves).
	var planted := rig.on_deck() and rig.grounded()
	var reduced := body.mass if planted else body.mass * rig.mass / (body.mass + rig.mass)
	var com := body.global_transform * body.center_of_mass
	var grip_velocity := body.linear_velocity + body.angular_velocity.cross(grip - com)
	var relative := grip_velocity - rig.linear_velocity
	var force := (stretch * grabber.stiffness - relative * grabber.damping) * reduced
	force = force.limit_length(grabber.planted_grip(false) if planted else grabber.grip_force(false))
	grabber.planted = planted
	if not planted:
		rig.apply_central_force(-force)
	body.apply_force(force, grip - body.global_position)
	# Keep the load turned as it was gripped relative to your aim, its spin calmed.
	var want := _aim_frame() * Basis(grab_turn)
	var off := (want * body.global_basis.orthonormalized().inverse()).get_rotation_quaternion()
	var angle := off.get_angle()
	if angle > PI:
		angle -= TAU
	var axis := off.get_axis() if absf(angle) > 0.0001 else Vector3.ZERO
	var spin := body.angular_velocity - rig.angular_velocity
	var turn := axis * angle * grabber.turn_stiffness - spin * grabber.spin_damping
	var own := body.global_basis.orthonormalized()
	var twist := grabber.grip_torque(false)
	var inertia := Basis.from_scale(body.mass * Vector3.ONE * 0.1)
	var torque := own.inverse() * (inertia * turn)
	body.apply_torque(own * torque.clamp(-Vector3.ONE * twist, Vector3.ONE * twist))


func release_grab() -> void:
	grab_body = null
	_draw_beam(false)


func _aim_frame() -> Basis:
	return rig.head.global_basis.orthonormalized()


func _push(body: RigidBody3D, force: Vector3, at: Vector3) -> void:
	body.apply_central_force(force)
	var torque := (at - body.global_transform * body.center_of_mass).cross(force)
	var spin := torque.length() / maxf(body.mass * 0.1, 0.01)
	if spin > max_push_spin:
		torque *= max_push_spin / spin
	body.apply_torque(torque)


func _draw_beam(on: bool, to := Vector3.ZERO) -> void:
	_beam_mesh.clear_surfaces()
	var tractor := active_tool() as YardTractor if not tools.is_empty() else null
	_field.visible = on and tractor != null
	if not on:
		return
	var tool_tip := (active_tool() as Node3D).global_position + aim_dir * 0.15
	if tractor:
		# The tractor's field: a soft cone from its lens out to the load.
		tool_tip = tractor.global_transform * Vector3(0, 0, -0.26)
		var length := tool_tip.distance_to(to)
		if length > 0.05:
			var dir := (to - tool_tip) / length
			var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
			_field.global_transform = Transform3D(Basis.looking_at(dir, up).scaled(Vector3(1, 1, length)), tool_tip)
		return
	_beam_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var side := aim_dir.cross(Vector3.UP).normalized() * 0.008
	if side.is_zero_approx():
		side = Vector3.RIGHT * 0.008
	for k: float in [-1.0, 0.0, 1.0]:
		_beam_mesh.surface_add_vertex(tool_tip + side * k)
		_beam_mesh.surface_add_vertex(to + side * k)
	_beam_mesh.surface_end()


## The tractor's field: an open cone a metre long down -Z (scaled to the load), its radius
## from the lens's to half a metre at the load; the shader draws it soft and moving.
static func _field_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 24
	var rings := 12
	for r in rings:
		for i in sides:
			var quad: Array = []
			for k: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var t := float(r + k.y) / rings
				var a := TAU * (i + k.x) / sides
				var radius := lerpf(0.03, 0.5, t)
				st.set_uv(Vector2(float(i + k.x) / sides, t))
				quad.append(Vector3(cos(a) * radius, sin(a) * radius, -t))
			for j: int in [0, 1, 2, 0, 2, 3]:
				st.set_uv(Vector2(0, -(quad[j] as Vector3).z))
				st.add_vertex(quad[j])
	st.generate_normals()
	return st.commit()


func _cast_ray(reach: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(aim_origin, aim_origin + aim_dir * reach)
	query.exclude = [rig.get_rid()]
	return rig.get_world_3d().direct_space_state.intersect_ray(query)


# --- Hotbar ----------------------------------------------------------------------------

func _build_hotbar() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Hotbar"
	add_child(layer)
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(anchor)
	_hotbar = HBoxContainer.new()
	_hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hotbar.position.y -= 24
	_hotbar.add_theme_constant_override("separation", 6)
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_hotbar)
	for i in tools.size():
		var slot := PanelContainer.new()
		slot.name = "Slot%d" % (i + 1)
		slot.custom_minimum_size = Vector2(118, 46)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.text = "%d  %s" % [i + 1, tools[i].tool_name]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", ShipKit.mono_font())
		label.add_theme_font_size_override("font_size", 15)
		slot.add_child(label)
		_hotbar.add_child(slot)
	_refresh_hotbar()


func _refresh_hotbar() -> void:
	if _hotbar == null:
		return
	for i in _hotbar.get_child_count():
		var slot := _hotbar.get_child(i) as PanelContainer
		var on := i == active_index and not holstered
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.04, 0.07, 0.09, 0.78) if not on else Color(0.08, 0.22, 0.26, 0.9)
		box.border_color = Color(0.45, 0.95, 1.0, 0.95) if on else Color(0.45, 0.95, 1.0, 0.25)
		box.set_border_width_all(2 if on else 1)
		box.set_corner_radius_all(4)
		slot.add_theme_stylebox_override("panel", box)
		(slot.get_child(0) as Label).modulate = Color(0.75, 1.0, 1.0) if on else Color(0.6, 0.7, 0.75)
