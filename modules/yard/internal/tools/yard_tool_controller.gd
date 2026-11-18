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

## The hotbar, left to right (keys 1 to 8): Void Salvage's four, then BSX's tractor and tablet,
## and the tools that put joints in, the riveter and the welder (0.4.0 playtest).
const ORDER: Array[String] = ["grinder", "cutter", "socket", "grabber", "tractor", "tablet", "riveter", "welder"]
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
## A fastening tool put a joint in.
signal fastened(c: ConnectionData)

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
## Joints this rig's riveter and welder have put in (tests read it), and the plan being worked.
var fastened_count: int = 0
var plan: Dictionary = {}
var plan_body: YardWorkpiece
## How far through the job in hand is, 0..1 (a joint coming out, a fastening going in), or -1:
## the bar by the crosshair shows it (0.4.0 playtest). `work_label` names it.
var work_progress: float = -1.0
var work_label: String = ""
var work_stuck := false
## The work is going badly but going (a weld too fast or too slow): the bar turns red, no STUCK.
var work_warn := false
var _held_label := ""
var _held_stuck := false
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
var _grip_fx: YardFieldGrip
var _bar: ProgressBar
var _bar_label: Label
var _bar_root: Control
var _bar_fill: StyleBoxFlat
var _bar_hold: float = 0.0


func _ready() -> void:
	name = "Tools"
	rig = get_parent() as YardRig
	var hold := Node3D.new()
	hold.name = "ToolHold"
	hold.transform = str_to_var(HOLD)
	rig.head.add_child(hold)
	for tool: YardTool in [YardGrinder.new(), YardCutter.new(), YardSocket.new(), YardGrabber.new(), YardTractor.new(), YardTablet.new(),
			YardRiveter.new(), YardWelder.new()]:
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
	_grip_fx = YardFieldGrip.new()
	_grip_fx.name = "GripField"
	add_child(_grip_fx)
	_build_hotbar()
	_build_progress()
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


## The tool with this id, or null.
func get_tool(id: String) -> YardTool:
	for tool in tools:
		if tool.tool_id == id:
			return tool
	return null


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
	return not tool is YardGrabber and not tool is YardTablet and not tool is YardFastener


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
	work_progress = -1.0
	work_warn = false
	work_stuck = false
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
	if tool is YardFastener:
		_update_fastening(tool as YardFastener, hit, body, delta)
	elif tool is YardTablet:
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
	if trigger and targeted:
		work_progress = 1.0 - targeted.health_fraction()
		work_label = str(ConnectionData.KIND_NAMES[targeted.kind])
		work_stuck = targeted_seized or factor <= 0.0
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
		_bar_hold = 0.35
		_held_label = ""
		_held_stuck = false
		work_progress = 1.0
		lock = null
		lock_body = null


func _process(delta: float) -> void:
	# A screen that has the pointer (the design room's console) covers the hotbar.
	if _hotbar:
		(_hotbar.get_parent().get_parent() as CanvasLayer).visible = not HudSlots.pointer_claimed()
	_show_progress(delta)
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


# --- Riveter and welder ----------------------------------------------------------------

## A fastening tool: on a planned rivet or weld (the one under the aim, kept while the trigger
## holds and it stays in reach), the trigger puts it in at the tool's rate; its head rides out to
## the spot (along a weld's line as it goes). Pushes back as the other tools do.
func _update_fastening(tool: YardFastener, hit: Dictionary, body: YardWorkpiece, delta: float) -> void:
	_draw_beam(false)
	var touching := not hit.is_empty()
	if plan_body and (not is_instance_valid(plan_body) or not plan_body.planned.has(plan)):
		plan = {}
		plan_body = null
	if not trigger:
		plan = {}
		plan_body = null
		if tool is YardRiveter:
			(tool as YardRiveter).pressure = 0.0
	if plan.is_empty() and body and touching:
		var near := body.planned_near(hit.position, tool.plan_snap, tool.fasten_kind)
		if not near.is_empty():
			if trigger:
				plan = near
				plan_body = body
			tool.work_material = body.model.parts[int(near.a)].material if body.model.parts.has(int(near.a)) else "steel"
	if not plan.is_empty() and rest_bite(tool).distance_to(plan_body.planned_position(plan)) > tool.boom + arm_stretch + 0.4:
		plan = {}
		plan_body = null
	var on_plan := trigger and not plan.is_empty()
	if tool is YardWelder:
		_update_welding(tool as YardWelder, hit, on_plan, delta)
	else:
		_update_riveting(tool as YardRiveter, on_plan, delta)


## The welder (0.4.1 playtest): the bead follows where you aim, as fast as you move it. Steady
## along the chalk line lays a neat bead; too fast, a thin broken one; too slow, a fat burnt one.
func _update_welding(tool: YardWelder, hit: Dictionary, on_plan: bool, delta: float) -> void:
	var laid := false
	var pace := ""
	if on_plan and not hit.is_empty():
		var r := plan_body.weld_along(plan, hit.position, delta, tool.ideal_speed, tool.max_speed)
		laid = bool(r.laid) or String(r.pace) == "STEADY" or String(r.pace) == "TOO SLOW" or String(r.pace) == "TOO FAST"
		pace = r.pace
		tool.pace = pace
		tool.speed = float(r.speed)
		if bool(r.done):
			fastened_count += 1
			fastened.emit(plan_body.model.connections.back())
			work_progress = 1.0
			work_label = "WELD %s" % String(plan_body.last_weld.get("grade", ""))
			_bar_hold = 1.2
			_held_label = work_label
			_held_stuck = String(plan_body.last_weld.get("grade", "")) == "POOR"
			plan = {}
			plan_body = null
			on_plan = false
	var arc := on_plan and laid and pace != "OFF THE LINE"
	tool.set_working(trigger, not hit.is_empty() or arc)
	tool.fastening = arc
	tool.progress = float(plan.get("done", 0.0)) if on_plan else 0.0
	tool.biting = arc
	if tool.tool_voice:
		tool.tool_voice.feed(trigger, arc, arc, tool.progress, 1.0, 1.0)
	if not arc:
		_effects.update(false, Vector3.ZERO, Vector3.UP, tool, false)
		_effects.fasten(tool, Vector3.ZERO, Vector3.UP, false, delta)
		if on_plan:
			work_progress = tool.progress
			work_label = pace if pace != "" else "WELD"
			work_warn = true
		return
	var at := plan_body.planned_position(plan)
	var n := plan_body.planned_normal(plan)
	_work = [at, n]
	work_progress = tool.progress
	work_label = "WELD  %s" % pace
	work_warn = pace != "STEADY"
	_effects.fasten(tool, at, n, true, delta)
	rig.apply_central_force(-(at - aim_origin).normalized() * tool.push_force)


## The riveter (0.4.1 playtest): on a chalked rivet it builds up air pressure with a rising
## hiss, then punches the rivet home in one blow, loud, with a kick and a burst of sparks.
func _update_riveting(tool: YardRiveter, on_plan: bool, delta: float) -> void:
	tool.set_working(trigger, on_plan)
	tool.fastening = on_plan
	tool.biting = on_plan
	if on_plan:
		var factor := tool.hardness_factor(Materials.tier(tool.work_material)) if tool.work_material != "" else 1.0
		tool.pressure = minf(tool.pressure + delta / maxf(tool.charge_seconds, 0.05) * maxf(factor, 0.4), 1.0)
	else:
		tool.pressure = move_toward(tool.pressure, 0.0, delta * 3.0)
	tool.progress = tool.pressure
	if tool.tool_voice:
		tool.tool_voice.feed(trigger, on_plan, on_plan, tool.pressure, 1.0, 1.0)
	if not on_plan:
		_effects.update(false, Vector3.ZERO, Vector3.UP, tool, false)
		_effects.fasten(tool, Vector3.ZERO, Vector3.UP, false, delta)
		return
	var at := plan_body.planned_position(plan)
	var n := plan_body.planned_normal(plan)
	_work = [at, n]
	work_progress = tool.pressure
	work_label = "PRESSURE"
	_effects.fasten(tool, at, n, true, delta)
	if tool.pressure < 1.0:
		return
	# The punch: the rivet goes in, the gun kicks you back.
	plan_body.work_planned(plan, 1.0)
	fastened_count += 1
	fastened.emit(plan_body.model.connections.back())
	_effects.rivet_punch(tool, at, n)
	if tool.tool_voice:
		tool.tool_voice.punch()
	tool.punches += 1
	tool.pressure = 0.0
	rig.apply_central_impulse(-(at - aim_origin).normalized() * tool.kick)
	if rig.feel:
		rig.feel.set_rumble("hammer", rig.feel.hammer_rumble)
	work_progress = 1.0
	work_label = "RIVET IN"
	_held_label = work_label
	_held_stuck = false
	_bar_hold = 0.5
	plan = {}
	plan_body = null


# --- The progress bar by the crosshair --------------------------------------------------

func _build_progress() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WorkProgress"
	layer.layer = 5
	add_child(layer)
	_bar_root = Control.new()
	_bar_root.set_anchors_preset(Control.PRESET_CENTER)
	_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_bar_root)
	_bar = ProgressBar.new()
	_bar.name = "Bar"
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	_bar.position = Vector2(26, 18)
	_bar.size = Vector2(132, 9)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.03, 0.05, 0.06, 0.75)
	back.border_color = Color(0.45, 0.95, 1.0, 0.5)
	back.set_border_width_all(1)
	back.set_corner_radius_all(2)
	_bar_fill = StyleBoxFlat.new()
	_bar_fill.bg_color = Color(1.0, 0.62, 0.15)
	_bar_fill.set_corner_radius_all(2)
	_bar.add_theme_stylebox_override("background", back)
	_bar.add_theme_stylebox_override("fill", _bar_fill)
	_bar_root.add_child(_bar)
	_bar_label = Label.new()
	_bar_label.position = Vector2(26, 28)
	_bar_label.add_theme_font_override("font", ShipKit.mono_font())
	_bar_label.add_theme_font_size_override("font_size", 13)
	_bar_label.add_theme_color_override("font_color", Color(0.75, 1.0, 1.0))
	_bar_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_bar_label.add_theme_constant_override("outline_size", 4)
	_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_root.add_child(_bar_label)
	_bar_root.visible = false


## Is the bar showing now, and at what (tests read them).
func progress_shown() -> bool:
	return _bar_root != null and _bar_root.visible


func progress_value() -> float:
	return _bar.value if _bar else 0.0


func _show_progress(delta: float) -> void:
	if _bar_root == null:
		return
	_bar_hold = maxf(_bar_hold - delta, 0.0)
	var on := work_progress >= 0.0 and not HudSlots.pointer_claimed()
	if on:
		_bar.value = work_progress
		_bar_fill.bg_color = Color(1.0, 0.25, 0.15) if work_stuck or work_warn else Color(1.0, 0.62, 0.15)
		_bar_label.text = "%s  %d%%%s" % [work_label, int(round(work_progress * 100.0)), "  STUCK" if work_stuck else ""]
	elif _bar_hold > 0.0:
		_bar.value = 1.0
		_bar_fill.bg_color = Color(1.0, 0.4, 0.2) if _held_stuck else Color(0.35, 1.0, 0.5)
		_bar_label.text = _held_label if _held_label != "" else "%s  DONE" % work_label
	_bar_root.visible = on or _bar_hold > 0.0


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
		_grip_fx.release()
		return
	var body := grab_body
	var grip := body.global_transform * grab_point
	var hold := aim_origin + aim_dir * hold_distance
	var stretch := hold - grip
	if stretch.length() > grabber.break_distance:
		release_grab()
		_draw_beam(false)
		return
	# Void Salvage's grip (VX21): a shimmering shell on the load and tethers from the lens or claw.
	var tractor := grabber as YardTractor
	var tip := tractor.global_transform * Vector3(0, 0, -0.26) if tractor else (grabber as Node3D).global_position + aim_dir * 0.15
	_grip_fx.tether_width = 0.06 if tractor else 0.025
	_grip_fx.tether_bow = 0.1 if tractor else 0.08
	var from: Array[Vector3] = [tip]
	_grip_fx.hold(body, from, grip, clampf((stretch.length() / grabber.break_distance - 0.6) / 0.4, 0.0, 1.0))
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
	if _grip_fx:
		_grip_fx.release()


## Is the grip's field drawn now (holding, or fading out)? Tests read it.
func grip_showing() -> bool:
	return _grip_fx != null and _grip_fx.showing()


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
