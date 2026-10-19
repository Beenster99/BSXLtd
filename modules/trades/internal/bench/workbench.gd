extends Node3D
## The 0.1 bolting bench: a plate, a four-hole bracket, a tray of bolts and three tools.
## Builds its own geometry so it runs with nothing but the Trades folder. All the rules live
## in BoltJoint; this script turns mouse and keys into its calls and draws the result.
##
## Controls: 1 hands, 2 ratchet, 3 torque wrench. Hands: drag the bracket onto the plate
## (wheel turns it), then aim at a hole and wheel up to start a bolt. Ratchet: wheel up on a
## started bolt. Torque wrench: press on a bolt and drag down until it clicks. Right click
## backs a bolt out. Tab changes bolt, F toggles the washer, R resets, Esc leaves.

const TUNING: BoltingTuning = preload("res://modules/trades/internal/bolting/bolting.tres")
const BENCH_TOP := 0.9
const PLATE_Y := BENCH_TOP + 0.012
## Hole positions on the bracket base (x, z), clockwise from far left.
const HOLES: Array[Vector2] = [Vector2(-0.04, -0.025), Vector2(0.04, -0.025), Vector2(0.04, 0.025), Vector2(-0.04, 0.025)]
const BRACKET_HOME := Vector3(0.3, BENCH_TOP, 0.04)
const BRACKET_HOME_YAW := 22.0
const PICK_HOLE_M := 0.016
const PICK_BRACKET_M := 0.07
const TOOLS: Array[StringName] = [&"hands", &"ratchet", &"torque_wrench"]
const TOOL_LABELS := {&"hands": "Hands", &"ratchet": "Ratchet", &"torque_wrench": "Torque wrench (25 Nm)"}

const STEEL := Color("8d969e")
const DARK := Color("2b3138")
const PAINT := Color("f2a33a")

var joint: BoltJoint
var site: JointSite
var tool: StringName = &"hands"
var fastener_index := 0
var with_washer := true

var _camera: Camera3D
var _camera_rest: Vector3
var _bracket: Node3D
var _bracket_yaw := BRACKET_HOME_YAW
var _carrying := false
var _carry_offset := Vector3.ZERO
var _cursor := Vector3.ZERO
var _bolts: Array[Node3D] = []
var _tilts: PackedFloat32Array
var _wrench: Node3D
var _pull_start_y := 0.0
var _pull_applied := 0.0
var _started := false
var _click_player: AudioStreamPlayer
var _tick_player: AudioStreamPlayer

var _tool_label: Label
var _bolt_label: Label
var _hint_label: Label
var _result_panel: PanelContainer
var _result_label: Label


func _ready() -> void:
	var spec := JointSpec.new()
	spec.fastener_id = &"bolt_m8x25_8.8"
	spec.torque_target_nm = 25.0
	spec.sequence = PackedInt32Array([0, 2, 1, 3])
	spec.needs_washer = true

	_build_room()
	_build_site(spec)
	_build_bracket()
	_build_bolts()
	_build_wrench()
	_build_audio()
	_build_hud()

	joint = BoltJoint.new(spec, HOLES.size(), TUNING)
	joint.changed.connect(_on_joint_changed)
	joint.wrench_clicked.connect(_on_wrench_clicked)
	joint.completed.connect(_on_joint_completed)
	_tilts.resize(HOLES.size())
	_set_tool(&"hands")
	reset_bench()


func reset_bench() -> void:
	if joint.is_complete():
		_bus_remove()
	joint.reset()
	var bus := _bus()
	joint.speed = 1.0 + (bus.modifier(1, &"bolt_speed") if bus else 0.0)
	_tilts.fill(0.0)
	_carrying = false
	_started = false
	_bracket_yaw = BRACKET_HOME_YAW
	_bracket.position = BRACKET_HOME
	_bracket.rotation_degrees.y = _bracket_yaw
	_result_panel.visible = false
	_hint("Pick up the bracket and set it on the plate.")


func _process(delta: float) -> void:
	_camera.position = _camera.position.lerp(_camera_rest, minf(1.0, delta * 14.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_on_mouse_moved(event.position)
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key(event.keycode)


func _on_key(key: Key) -> void:
	match key:
		KEY_1, KEY_2, KEY_3:
			_set_tool(TOOLS[key - KEY_1])
		KEY_TAB:
			var ids := TradesStubFasteners.ids()
			fastener_index = (fastener_index + 1) % ids.size()
			_refresh_hud()
		KEY_F:
			with_washer = not with_washer
			_refresh_hud()
		KEY_R:
			reset_bench()
		KEY_ESCAPE:
			if Router.has_scene("main_menu"):
				Router.goto("main_menu")


func _on_mouse_moved(screen: Vector2) -> void:
	_cursor = _cursor_on_plate(screen)
	if _carrying:
		var p := _cursor + _carry_offset
		_bracket.position = Vector3(p.x, PLATE_Y + 0.004, p.z)
	if joint.pulling_hole() >= 0:
		_pull_applied = maxf(0.0, screen.y - _pull_start_y) * TUNING.nm_per_px
		joint.pull(_pull_applied)
		_pose_wrench(joint.pulling_hole(), _pull_applied)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	_cursor = _cursor_on_plate(event.position)
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position)
		else:
			_release()
	elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_back_out()
	elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_wheel(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)


func _press(screen: Vector2) -> void:
	match tool:
		&"hands":
			if not joint.bracket_seated and _flat(_cursor).distance_to(_flat(_bracket.position)) < PICK_BRACKET_M:
				_carrying = true
				_carry_offset = _bracket.position - _cursor
				_carry_offset.y = 0.0
				_hint("Wheel turns it. Square it up over the plate and let go.")
		&"torque_wrench":
			var hole := _hole_under_cursor()
			if hole >= 0 and joint.begin_pull(hole):
				_pull_start_y = screen.y
				_pull_applied = 0.0
				_wrench.visible = true
				_pose_wrench(hole, 0.0)
				_hint("Drag down to pull. Stop at the click.")
			elif hole >= 0:
				_hint("Run that bolt down with the ratchet first.")


func _release() -> void:
	if _carrying:
		_carrying = false
		var offset_mm := _flat(_bracket.position).distance_to(_flat(site.global_position)) * 1000.0
		if joint.place_bracket(offset_mm, _bracket_yaw):
			_bracket.position = Vector3(site.position.x, PLATE_Y, site.position.z)
			_bracket_yaw = 0.0
			_bracket.rotation_degrees.y = 0.0
			_mark_started()
			_hint("Seated. Take a bolt and start it by hand: aim at the hole centre and wheel up.")
		else:
			_bracket.position.y = PLATE_Y if _over_plate(_bracket.position) else BENCH_TOP
			_hint("Not lined up with the holes. Pick it up again.")
	if joint.pulling_hole() >= 0:
		var hole := joint.pulling_hole()
		joint.end_pull()
		_wrench.visible = false
		if joint.state[hole] != BoltJoint.Hole.TORQUED:
			_hint("Let go too early; that bolt is not at final torque.")


func _wheel(direction: int) -> void:
	if _carrying:
		_bracket_yaw = wrapf(_bracket_yaw + direction * 3.0, -180.0, 180.0)
		_bracket.rotation_degrees.y = _bracket_yaw
		return
	if direction < 0:
		return
	var hole := _hole_under_cursor()
	if hole < 0:
		return
	match tool:
		&"hands":
			var offset_mm := _flat(_cursor).distance_to(_flat(_hole_world(hole))) * 1000.0
			if joint.state[hole] == BoltJoint.Hole.EMPTY:
				_tilts[hole] = joint.tilt_for_offset(offset_mm)
			var ids := TradesStubFasteners.ids()
			match joint.hand_turn(hole, _tilts[hole], ids[fastener_index], with_washer):
				&"bind":
					_hint("It's binding. Cross-threaded? Right click to back it out.")
				&"started":
					_play(_tick_player, 0.6)
					_hint("Started. Switch to the ratchet (2) to run it down.")
				&"turning":
					_mark_started()
		&"ratchet":
			match joint.ratchet(hole):
				&"seated":
					_play(_tick_player, 1.4)
					_hint("Snug. Final torque with the torque wrench (3).")
				&"turning":
					_play(_tick_player, 1.0)
				&"":
					if joint.state[hole] == BoltJoint.Hole.STARTING:
						_hint("Start it by hand first, or it will cross-thread.")


func _back_out() -> void:
	var hole := _hole_under_cursor()
	if hole >= 0 and joint.state[hole] != BoltJoint.Hole.EMPTY:
		if joint.back_out(hole):
			_bus_remove()
			_result_panel.visible = false
		_hint("Bolt out.")
	elif tool == &"hands" and joint.lift_bracket():
		_carrying = true
		_carry_offset = Vector3.ZERO


func _set_tool(id: StringName) -> void:
	tool = id
	var bus := _bus()
	if bus:
		bus.tool_equipped.emit(1, id)
	_refresh_hud()


func _mark_started() -> void:
	if _started:
		return
	_started = true
	var bus := _bus()
	if bus:
		bus.joint_started.emit(site.joint_id, site.spec.trade, 1)


func _on_joint_changed() -> void:
	for i in _bolts.size():
		_pose_bolt(i)
	var bus := _bus()
	if bus and _started:
		bus.joint_progress.emit(site.joint_id, joint.progress())


func _on_wrench_clicked(_hole: int) -> void:
	_play(_click_player, 1.0)
	_camera.position.y -= TUNING.click_kick
	_hint("Click. Let go now.")


func _on_joint_completed() -> void:
	var m := joint.measurements()
	var bus := _bus()
	if bus:
		bus.complete_joint(site, m)
	var lines: PackedStringArray = ["Joint complete", ""]
	var torques: Array = m.torque_nm
	for i in torques.size():
		var notes: PackedStringArray = []
		if m.cross_threaded[i]:
			notes.append("cross-threaded")
		if not m.washer[i]:
			notes.append("no washer")
		if m.fastener_ids[i] != site.spec.fastener_id:
			notes.append(TradesStubFasteners.label(m.fastener_ids[i]))
		lines.append("Bolt %d: %.1f Nm %s" % [i + 1, torques[i], ", ".join(notes)])
	lines.append("Target: %.0f Nm" % m.torque_target_nm)
	lines.append("Order: %s %s" % [_one_based(m.sequence), "(as specified)" if m.sequence_ok else "(not the specified order)"])
	lines.append("Bracket offset: %.1f mm" % m.misalign_mm)
	lines.append("")
	lines.append("Quality grades this joint." if Modules.is_loaded("quality") else "Grading arrives with the Quality module.")
	lines.append("R to reset the bench.")
	_result_label.text = "\n".join(lines)
	_result_panel.visible = true
	_hint("Done.")


## Release screenshot: bracket seated, two bolts torqued, the wrench on a third.
func stage_for_screenshot() -> void:
	reset_bench()
	_bracket.position = Vector3(site.position.x, PLATE_Y, site.position.z)
	_bracket.rotation_degrees.y = 0.0
	_bracket_yaw = 0.0
	joint.place_bracket(0.0, 0.0)
	for hole in [0, 2, 1]:
		for i in 12:
			joint.hand_turn(hole, 0.0, site.spec.fastener_id, true)
		for i in 10:
			joint.ratchet(hole)
	for hole in [0, 2]:
		joint.begin_pull(hole)
		joint.pull(site.spec.torque_target_nm)
		joint.end_pull()
	_set_tool(&"torque_wrench")
	_wrench.visible = true
	_pose_wrench(1, 18.0)
	_hint("Drag down to pull. Stop at the click.")


# --- Building the bench ---------------------------------------------------------------

func _build_room() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = BsxTheme.BG
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("9fb0c0")
	env.environment.ambient_light_energy = 0.3
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-0.2, BENCH_TOP + 0.6, 0.2)
	lamp.light_color = Color("ffe2b8")
	lamp.omni_range = 2.0
	lamp.light_energy = 0.5
	add_child(lamp)

	_add_box(Vector3(1.2, BENCH_TOP, 0.6), Vector3(0, BENCH_TOP / 2.0, 0), Color("5a4634"))
	_add_box(Vector3(0.3, 0.012, 0.2), Vector3(0, BENCH_TOP + 0.006, 0), Color("4f575f"))
	# Bolt tray and pegboard, for the look of a workshop.
	_add_box(Vector3(0.14, 0.02, 0.08), Vector3(-0.32, BENCH_TOP + 0.01, 0.12), DARK)
	_add_box(Vector3(1.2, 0.6, 0.02), Vector3(0, BENCH_TOP + 0.3, -0.3), Color("3a4652"))

	_camera = Camera3D.new()
	_camera.fov = 45.0
	add_child(_camera)
	_camera.position = Vector3(0.0, BENCH_TOP + 0.45, 0.42)
	_camera.look_at(Vector3(0.04, PLATE_Y, -0.01))
	_camera_rest = _camera.position
	_camera.current = true


func _build_site(spec: JointSpec) -> void:
	site = JointSite.new()
	site.name = "BracketJoint"
	site.joint_id = &"bench_bracket"
	site.spec = spec
	site.position = Vector3(0.0, PLATE_Y, 0.0)
	for i in HOLES.size():
		var m := Marker3D.new()
		m.name = "Hole%d" % i
		m.position = Vector3(HOLES[i].x, 0.0, HOLES[i].y)
		site.add_child(m)
		_add_cylinder(0.0045, 0.001, m.position + Vector3(0, 0.0005, 0), DARK, site)
		var seq := Label3D.new()
		seq.text = str(spec.sequence.find(i) + 1)
		seq.font_size = 48
		seq.pixel_size = 0.0004
		seq.modulate = Color(PAINT, 0.8)
		seq.rotation_degrees.x = -90
		seq.position = m.position + Vector3(signf(HOLES[i].x) * 0.035, 0.001, 0.0)
		site.add_child(seq)
	add_child(site)


func _build_bracket() -> void:
	_bracket = Node3D.new()
	_bracket.name = "Bracket"
	add_child(_bracket)
	_add_box(Vector3(0.12, 0.006, 0.08), Vector3(0, 0.003, 0), STEEL, _bracket)
	_add_box(Vector3(0.12, 0.08, 0.006), Vector3(0, 0.04, -0.037), STEEL, _bracket)
	for h in HOLES:
		_add_cylinder(0.0048, 0.001, Vector3(h.x, 0.0062, h.y), DARK, _bracket)


func _build_bolts() -> void:
	for i in HOLES.size():
		var bolt := Node3D.new()
		bolt.name = "Bolt%d" % i
		var parts := Node3D.new()
		parts.name = "Parts"
		bolt.add_child(parts)
		_add_cylinder(0.004, 0.03, Vector3(0, -0.009, 0), STEEL, parts).name = "Shaft"
		var head := _add_cylinder(0.0068, 0.0055, Vector3(0, 0.00875, 0), STEEL, parts)
		head.name = "Head"
		(head.mesh as CylinderMesh).radial_segments = 6
		_add_box(Vector3(0.0136, 0.0012, 0.0016), Vector3(0, 0.0118, 0), PAINT, parts).name = "Paint"
		var washer := _add_cylinder(0.008, 0.0016, Vector3(0, 0.0008, 0), Color("b9c0c6"), bolt)
		washer.name = "Washer"
		bolt.position = site.position + Vector3(HOLES[i].x, 0.006, HOLES[i].y)
		add_child(bolt)
		_bolts.append(bolt)


func _build_wrench() -> void:
	_wrench = Node3D.new()
	_wrench.name = "TorqueWrench"
	_add_cylinder(0.011, 0.014, Vector3(0, 0.016, 0), DARK, _wrench)
	_add_box(Vector3(0.2, 0.012, 0.016), Vector3(0.11, 0.022, 0), Color("c33c2e"), _wrench)
	_add_box(Vector3(0.07, 0.02, 0.022), Vector3(0.2, 0.022, 0), Color("1a1a1a"), _wrench)
	_wrench.visible = false
	add_child(_wrench)


func _build_audio() -> void:
	_click_player = AudioStreamPlayer.new()
	_click_player.stream = _noise_burst(0.05, 0.9, 900.0)
	add_child(_click_player)
	_tick_player = AudioStreamPlayer.new()
	_tick_player.stream = _noise_burst(0.025, 0.35, 2600.0)
	add_child(_tick_player)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = BsxTheme.get_theme()
	layer.add_child(root)

	var info := PanelContainer.new()
	info.position = Vector2(24, 24)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(info)
	var box := VBoxContainer.new()
	info.add_child(box)
	box.add_child(BsxTheme.title("Workbench", 34))
	_tool_label = Label.new()
	_bolt_label = Label.new()
	_hint_label = BsxTheme.muted("")
	_hint_label.custom_minimum_size.x = 520
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	for l in [_tool_label, _bolt_label, _hint_label]:
		box.add_child(l)

	var help := BsxTheme.muted("1 hands  2 ratchet  3 torque wrench  ·  Tab bolt  ·  F washer  ·  right click back out  ·  R reset  ·  Esc menu")
	help.add_theme_font_size_override("font_size", 18)
	root.add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)

	_result_panel = PanelContainer.new()
	_result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_result_panel)
	_result_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_result_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_result_label = Label.new()
	_result_panel.add_child(_result_label)


# --- Helpers ----------------------------------------------------------------------------

func _refresh_hud() -> void:
	if _tool_label == null:
		return
	_tool_label.text = "Tool: %s" % TOOL_LABELS[tool]
	var ids := TradesStubFasteners.ids()
	_bolt_label.text = "Bolt: %s, %s" % [TradesStubFasteners.label(ids[fastener_index]),
			"with washer" if with_washer else "no washer"]


func _hint(text: String) -> void:
	_hint_label.text = text


func _pose_bolt(i: int) -> void:
	var bolt := _bolts[i]
	var s := joint.state[i]
	bolt.visible = s != BoltJoint.Hole.EMPTY
	if not bolt.visible:
		return
	var full_turns := TUNING.hand_start_turns + TUNING.run_down_turns
	var left := 1.0 - clampf(joint.turns[i] / full_turns, 0.0, 1.0)
	if s == BoltJoint.Hole.SEATED or s == BoltJoint.Hole.TORQUED:
		left = 0.0
	var parts := bolt.get_node("Parts") as Node3D
	parts.position.y = left * 0.02
	parts.rotation = Vector3(deg_to_rad(_tilts[i]) if joint.cross[i] else 0.0, joint.turns[i] * TAU, 0.0)
	var scale_d := TradesStubFasteners.diameter_m(joint.fastener[i]) / 0.008
	parts.scale = Vector3(scale_d, 1.0, scale_d)
	bolt.get_node("Washer").visible = joint.washer[i]
	parts.get_node("Paint").visible = s == BoltJoint.Hole.TORQUED


func _pose_wrench(hole: int, applied: float) -> void:
	_wrench.position = _hole_world(hole) + Vector3(0, 0.008, 0)
	var swing := clampf(applied / site.spec.torque_target_nm, 0.0, 1.6) * 18.0
	_wrench.rotation_degrees = Vector3(0, -10.0 - swing, 0)


func _hole_world(hole: int) -> Vector3:
	return site.position + Vector3(HOLES[hole].x, 0.006, HOLES[hole].y)


func _hole_under_cursor() -> int:
	if not joint.bracket_seated:
		return -1
	var best := -1
	var best_d := PICK_HOLE_M
	for i in HOLES.size():
		var d := _flat(_cursor).distance_to(_flat(_hole_world(i)))
		if d < best_d:
			best = i
			best_d = d
	return best


func _cursor_on_plate(screen: Vector2) -> Vector3:
	var from := _camera.project_ray_origin(screen)
	var dir := _camera.project_ray_normal(screen)
	var hit: Variant = Plane(Vector3.UP, PLATE_Y + 0.006).intersects_ray(from, dir)
	return hit if hit != null else _cursor


func _over_plate(p: Vector3) -> bool:
	return absf(p.x) < 0.15 and absf(p.z) < 0.1


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _one_based(seq: PackedInt32Array) -> String:
	var parts: PackedStringArray = []
	for i in seq:
		parts.append(str(i + 1))
	return "-".join(parts)


func _bus() -> TradesBus:
	return Modules.bus("trades") as TradesBus


func _bus_remove() -> void:
	var bus := _bus()
	if bus:
		bus.remove_joint(site.joint_id)


func _play(player: AudioStreamPlayer, pitch: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	player.pitch_scale = pitch
	player.play()


func _add_box(size: Vector3, pos: Vector3, color: Color, parent: Node = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh(mesh, pos, color, parent)


func _add_cylinder(radius: float, height: float, pos: Vector3, color: Color, parent: Node = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	return _add_mesh(mesh, pos, color, parent)


func _add_mesh(mesh: PrimitiveMesh, pos: Vector3, color: Color, parent: Node) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.6 if color == STEEL else 0.1
	mat.roughness = 0.45
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


## A short decaying noise burst, low-passed to taste: the wrench click and ratchet ticks.
static func _noise_burst(seconds: float, volume: float, cutoff_hz: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var a := clampf(TAU * cutoff_hz / rate, 0.0, 1.0)
	var y := 0.0
	for i in n:
		y += a * (rng.randf_range(-1.0, 1.0) - y)
		var env := exp(-6.0 * float(i) / n)
		data.encode_s16(i * 2, int(clampf(y * env * volume * 3.0, -1.0, 1.0) * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
