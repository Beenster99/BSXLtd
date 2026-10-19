extends Node3D
## The 0.1 bolting bench: a workshop corner with a bench, a plate, a four-hole bracket, a
## tray of bolts and a torque wrench. You walk up to it as the BSX worker (first or third
## person) and do the job with your own stretchy hands. All the rules live in BoltJoint; this
## script turns what your hands do into its calls and draws the result.
##
##   WASD walk, mouse look, V first/third person
##   1 hands: left click the bracket to pick it up (wheel turns it), click again to set it
##     on the plate. Click the tray to take a bolt, then hold left click on a hole: your hand
##     reaches out and screws it in. Aim at the hole's centre or it cross-threads and jams.
##   2 torque wrench: hold left click on a bolt and pull the mouse back until it clicks.
##   Right click backs a bolt out. Tab changes bolt, F the washer, R resets, Esc leaves.

const TUNING: BoltingTuning = preload("res://modules/trades/internal/bolting/bolting.tres")
const BENCH_TOP := 0.9
const PLATE_Y := BENCH_TOP + 0.012
## Hole positions on the bracket base (x, z), clockwise from far left.
const HOLES: Array[Vector2] = [Vector2(-0.04, -0.025), Vector2(0.04, -0.025), Vector2(0.04, 0.025), Vector2(-0.04, 0.025)]
const BRACKET_HOME := Vector3(0.3, BENCH_TOP, 0.08)
const BRACKET_HOME_YAW := 22.0
const TRAY := Vector3(-0.3, BENCH_TOP + 0.02, 0.1)
const WORKER_START := Vector3(0.0, 0.0, 0.58)
const PICK_HOLE_M := 0.03
const PICK_BRACKET_M := 0.08
const PICK_TRAY_M := 0.09
const TOOL_LABELS := {&"hands": "Hands", &"torque_wrench": "Torque wrench"}

const STEEL := Color("8d969e")
const DARK := Color("2b3138")
const PAINT := Color("f2a33a")

var joint: BoltJoint
var site: JointSite
var worker: BenchWorker
var wrench: TradesTorqueWrench
var tool: StringName = &"hands"
var fastener_index := 0
var with_washer := true

var _bracket: Node3D
var _bracket_yaw := BRACKET_HOME_YAW
var _carrying := false
var _bolt_in_hand := false
var _hand_bolt: Node3D
var _turning_hole := -1
var _pull_px := 0.0
var _bolts: Array[Node3D] = []
var _tilts: PackedFloat32Array
var _started := false
var _click_player: AudioStreamPlayer
var _tick_player: AudioStreamPlayer
var _tick_wait := 0.0
## Seconds the left hand stays out at the tray after taking a bolt.
var _left_busy := 0.0

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
	_build_worker()
	_build_audio()
	_build_hud()

	joint = BoltJoint.new(spec, HOLES.size(), TUNING)
	joint.changed.connect(_on_joint_changed)
	joint.wrench_clicked.connect(_on_wrench_clicked)
	joint.completed.connect(_on_joint_completed)
	_tilts.resize(HOLES.size())
	wrench.set_nm = spec.torque_target_nm
	_set_tool(&"hands")
	reset_bench()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func reset_bench() -> void:
	if joint.is_complete():
		_bus_remove()
	_stop_hands()
	joint.reset()
	var bus := _bus()
	joint.speed = 1.0 + (bus.modifier(1, &"bolt_speed") if bus else 0.0)
	_tilts.fill(0.0)
	_carrying = false
	_bolt_in_hand = false
	_started = false
	_bracket_yaw = BRACKET_HOME_YAW
	_bracket.position = BRACKET_HOME
	_bracket.rotation_degrees.y = _bracket_yaw
	_result_panel.visible = false
	worker.global_position = WORKER_START
	worker.face(Vector3(0.0, PLATE_Y, 0.0))
	_hint("Pick up the bracket and set it on the plate.")


func _process(delta: float) -> void:
	_update_carry(delta)
	_update_turning(delta)
	_update_wrench()
	_hand_bolt.visible = _bolt_in_hand


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if joint.pulling_hole() >= 0:
			_pull(event.relative.y)
		else:
			worker.look(event.relative)
	elif event is InputEventMouseButton:
		if DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		_on_mouse_button(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key(event.physical_keycode)


func _on_key(key: Key) -> void:
	match key:
		KEY_1:
			_set_tool(&"hands")
		KEY_2:
			_set_tool(&"torque_wrench")
		KEY_V:
			worker.set_view(not worker.third_person)
		KEY_TAB:
			fastener_index = (fastener_index + 1) % TradesStubFasteners.ids().size()
			_refresh_hud()
		KEY_F:
			with_washer = not with_washer
			_refresh_hud()
		KEY_R:
			reset_bench()
		KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if Router.has_scene("main_menu"):
				Router.goto("main_menu")


func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press()
			else:
				_release()
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_back_out()
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed and _carrying:
				_bracket_yaw = wrapf(_bracket_yaw + (4.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -4.0), -180.0, 180.0)


# --- What the hands do ---------------------------------------------------------------

func _press() -> void:
	if tool == &"torque_wrench":
		var hole := _hole_under_aim()
		if hole < 0:
			return
		if not worker.right_hand.can_reach(_hole_world(hole)):
			_hint("Too far. Step closer.")
		elif joint.begin_pull(hole):
			_pull_px = 0.0
			worker.look_locked = true
			_hint("Pull the mouse back. Stop at the click.")
		else:
			_hint("Screw that bolt in by hand first.")
		return
	if _carrying:
		_set_bracket_down()
		return
	if not joint.bracket_seated and _aim_distance(_bracket.global_position) < PICK_BRACKET_M:
		if worker.left_hand.can_reach(_bracket.global_position):
			_carrying = true
			_mark_started()
			_hint("Wheel turns it. Square it up over the plate and click to set it down.")
		else:
			_hint("Too far. Step closer.")
		return
	if _aim_distance(TRAY) < PICK_TRAY_M:
		if worker.left_hand.can_reach(TRAY):
			_bolt_in_hand = true
			_left_busy = 0.35
			worker.left_hand.reach_to(TRAY)
			_hint("Got a bolt. Hold left click on a hole to screw it in.")
		return
	var hole := _hole_under_aim()
	if hole < 0:
		return
	if not worker.right_hand.can_reach(_hole_world(hole)):
		_hint("Too far. Step closer.")
		return
	if joint.state[hole] == BoltJoint.Hole.EMPTY:
		if not _bolt_in_hand:
			_hint("Take a bolt from the tray first.")
			return
		var offset_mm := _aim_offset_mm(_hole_world(hole))
		_tilts[hole] = joint.tilt_for_offset(offset_mm)
	_turning_hole = hole
	worker.look_locked = true


func _release() -> void:
	if _turning_hole >= 0:
		_turning_hole = -1
		worker.look_locked = false
		worker.right_hand.come_back()
		worker.right_hand.set_grip(0.0)
		worker.right_hand.set_spin(0.0)
	if joint.pulling_hole() >= 0:
		var hole := joint.pulling_hole()
		joint.end_pull()
		worker.look_locked = false
		if joint.state[hole] != BoltJoint.Hole.TORQUED:
			_hint("Let go too early; that bolt is not at final torque.")


func _back_out() -> void:
	var hole := _hole_under_aim()
	if hole >= 0 and joint.state[hole] != BoltJoint.Hole.EMPTY:
		if joint.back_out(hole):
			_bus_remove()
			_result_panel.visible = false
		_hint("Bolt out.")
	elif tool == &"hands" and _aim_distance(_bracket.global_position) < PICK_BRACKET_M and joint.lift_bracket():
		_carrying = true


func _set_bracket_down() -> void:
	_carrying = false
	worker.left_hand.come_back()
	var offset_mm := _flat(_bracket.position).distance_to(_flat(site.position)) * 1000.0
	if joint.place_bracket(offset_mm, _bracket_yaw):
		_bracket.position = Vector3(site.position.x, PLATE_Y, site.position.z)
		_bracket_yaw = 0.0
		_bracket.rotation_degrees.y = 0.0
		_hint("Seated. Take a bolt from the tray.")
	else:
		_bracket.position.y = PLATE_Y if _over_plate(_bracket.position) else BENCH_TOP
		_hint("Not lined up with the holes. Pick it up again.")


## The bracket rides where you aim on the bench top, held out in your left hand.
func _update_carry(delta: float) -> void:
	if not _carrying:
		_left_busy -= delta
		if _left_busy <= 0.0:
			worker.left_hand.come_back()
			worker.left_hand.set_grip(0.5 if _bolt_in_hand else 0.0)
		return
	var hit: Variant = Plane(Vector3.UP, PLATE_Y + 0.01).intersects_ray(worker.aim_origin(), worker.aim_dir())
	var at: Vector3 = hit if hit != null else worker.aim_origin() + worker.aim_dir() * 0.6
	var shoulder := worker.left_hand.get_parent_node_3d().global_position
	var limit := TUNING.hand_reach_m + TUNING.hand_stretch_m * 0.8
	if at.distance_to(shoulder) > limit:
		at = shoulder + (at - shoulder).normalized() * limit
	_bracket.position = at
	_bracket.rotation_degrees.y = _bracket_yaw
	worker.left_hand.reach_to(at + Vector3(0, 0.012, 0.02))
	worker.left_hand.set_grip(0.6)


## While left click is held on a hole: the right hand is on the bolt, turning it.
func _update_turning(delta: float) -> void:
	if _turning_hole < 0:
		return
	var hole := _turning_hole
	worker.right_hand.reach_to(_hole_world(hole) + Vector3(0, 0.01, 0))
	worker.right_hand.set_grip(0.8)
	if not worker.right_hand.is_on_target():
		return
	var ids := TradesStubFasteners.ids()
	var result := joint.hand_turn(hole, _tilts[hole], ids[fastener_index], with_washer, delta)
	if joint.state[hole] != BoltJoint.Hole.EMPTY:
		_bolt_in_hand = false
	worker.right_hand.set_spin(joint.turns[hole] * TAU * 0.25)
	match result:
		&"bind":
			_hint("It's jammed. Cross-threaded? Right click to back it out.")
		&"started":
			_play(_tick_player, 0.6)
			_hint("Thread caught. Keep turning.")
		&"seated":
			_play(_tick_player, 1.3)
			_hint("Finger tight. Final torque with the torque wrench (2).")
			_release()
		&"turning":
			_mark_started()
			_tick_wait -= delta
			if _tick_wait <= 0.0:
				_tick_wait = 0.18
				_play(_tick_player, 1.0)
		&"":
			_release()


func _pull(relative_y: float) -> void:
	_pull_px = maxf(0.0, _pull_px + relative_y)
	joint.pull(_pull_px * TUNING.nm_per_px)


## The wrench: on its bolt while pulling (the right hand on its grip), else in the hand.
func _update_wrench() -> void:
	wrench.visible = tool == &"torque_wrench"
	if not wrench.visible:
		return
	var hole := joint.pulling_hole()
	if hole < 0:
		if _turning_hole < 0:
			worker.right_hand.come_back()
		worker.right_hand.set_grip(0.7)
		var palm := worker.right_hand.palm()
		wrench.global_transform = palm * Transform3D(Basis(), Vector3(0, -0.03, 0) - TradesTorqueWrench.GRIP)
		return
	var applied := _pull_px * TUNING.nm_per_px
	var swing := clampf(applied / site.spec.torque_target_nm, 0.0, 1.6) * 25.0
	# Handle points back toward the worker, swinging round the bolt as it's pulled.
	var to_worker := worker.global_position - _hole_world(hole)
	var yaw := atan2(to_worker.x, to_worker.z) + deg_to_rad(35.0 - swing)
	wrench.global_transform = Transform3D(Basis(Vector3.UP, yaw), _hole_world(hole) + Vector3(0, 0.004, 0))
	worker.right_hand.reach_to(wrench.global_transform * TradesTorqueWrench.GRIP + Vector3(0, 0.02, 0))
	worker.right_hand.set_grip(1.0)


func _stop_hands() -> void:
	_release()
	_turning_hole = -1
	if worker:
		worker.look_locked = false
		worker.left_hand.come_back()
		worker.right_hand.come_back()


func _on_hand_snapped() -> void:
	if _turning_hole >= 0 or joint.pulling_hole() >= 0:
		_release()
		_hint("Too far: your arm let go.")
	if _carrying:
		_set_bracket_down()


func _set_tool(id: StringName) -> void:
	_release()
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
	wrench.click()
	worker.kick(TUNING.click_kick)
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


## Release screenshot: bracket seated, two bolts torqued, the wrench mid-pull on a third,
## seen first person (or third person).
func stage_for_screenshot(third_person: bool = false) -> void:
	reset_bench()
	_bracket.position = Vector3(site.position.x, PLATE_Y, site.position.z)
	_bracket.rotation_degrees.y = 0.0
	_bracket_yaw = 0.0
	joint.place_bracket(0.0, 0.0)
	for hole in [0, 2, 1]:
		for i in 60:
			joint.hand_turn(hole, 0.0, site.spec.fastener_id, true, 0.1)
	for hole in [0, 2]:
		joint.begin_pull(hole)
		joint.pull(site.spec.torque_target_nm)
		joint.end_pull()
	_set_tool(&"torque_wrench")
	joint.begin_pull(1)
	_pull_px = 18.0 / TUNING.nm_per_px
	joint.pull(18.0)
	worker.set_view(third_person)
	worker.global_position = Vector3(0.05, 0.0, 0.56)
	worker.face(Vector3(0.0, PLATE_Y, 0.0))
	worker.left_hand.reach_to(_bracket.global_position + Vector3(-0.05, 0.012, 0.03))
	_hint("Pull the mouse back. Stop at the click.")
	for i in 30:
		await get_tree().process_frame


# --- Building the bench ---------------------------------------------------------------

func _build_room() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = BsxTheme.BG
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("9fb0c0")
	env.environment.ambient_light_energy = 0.35
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 25, 0)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-0.3, BENCH_TOP + 0.9, 0.3)
	lamp.light_color = Color("ffe2b8")
	lamp.omni_range = 3.0
	lamp.light_energy = 0.6
	add_child(lamp)

	var solid := StaticBody3D.new()
	solid.name = "Solid"
	add_child(solid)
	_add_solid_box(solid, Vector3(8, 0.1, 8), Vector3(0, -0.05, 0), Color("3b4048"))       # floor
	_add_solid_box(solid, Vector3(1.4, BENCH_TOP, 0.6), Vector3(0, BENCH_TOP / 2.0, -0.05), Color("5a4634"))
	_add_solid_box(solid, Vector3(8, 3.0, 0.1), Vector3(0, 1.5, -0.6), Color("3a4652"))    # back wall
	_add_box(Vector3(0.3, 0.012, 0.2), Vector3(0, BENCH_TOP + 0.006, 0), Color("4f575f"))  # plate
	_add_box(Vector3(0.16, 0.03, 0.1), TRAY - Vector3(0, 0.005, 0), DARK)                  # bolt tray
	for i in 6:
		var b := _bolt_mesh(self)
		b.position = TRAY + Vector3(-0.05 + (i % 3) * 0.05, 0.012, -0.025 + (i / 3) * 0.05)
		b.rotation_degrees.z = 90


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
		var parts := _bolt_mesh(bolt)
		parts.name = "Parts"
		_add_box(Vector3(0.0136, 0.0012, 0.0016), Vector3(0, 0.0118, 0), PAINT, parts).name = "Paint"
		var washer := _add_cylinder(0.008, 0.0016, Vector3(0, 0.0008, 0), Color("b9c0c6"), bolt)
		washer.name = "Washer"
		bolt.position = site.position + Vector3(HOLES[i].x, 0.006, HOLES[i].y)
		add_child(bolt)
		_bolts.append(bolt)


func _build_worker() -> void:
	worker = BenchWorker.new()
	worker.name = "Worker"
	add_child(worker)
	worker.left_hand.reach_m = TUNING.hand_reach_m
	worker.left_hand.stretch_m = TUNING.hand_stretch_m
	worker.right_hand.reach_m = TUNING.hand_reach_m
	worker.right_hand.stretch_m = TUNING.hand_stretch_m
	worker.left_hand.snapped.connect(_on_hand_snapped)
	worker.right_hand.snapped.connect(_on_hand_snapped)
	wrench = TradesTorqueWrench.new()
	wrench.top_level = true
	add_child(wrench)
	_hand_bolt = _bolt_mesh(self)
	_hand_bolt.name = "BoltInHand"
	worker.left_hand.held = _hand_bolt


func _build_audio() -> void:
	_click_player = AudioStreamPlayer.new()
	_click_player.stream = _noise_burst(0.05, 0.9, 900.0)
	add_child(_click_player)
	_tick_player = AudioStreamPlayer.new()
	_tick_player.stream = _noise_burst(0.025, 0.3, 2600.0)
	add_child(_tick_player)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = BsxTheme.get_theme()
	layer.add_child(root)

	var cross := ColorRect.new()
	cross.color = Color(1, 1, 1, 0.8)
	cross.custom_minimum_size = Vector2(6, 6)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)

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

	var help := BsxTheme.muted("WASD walk  ·  V view  ·  1 hands  2 torque wrench  ·  left click use  ·  right click back out  ·  wheel turn bracket  ·  Tab bolt  ·  F washer  ·  R reset  ·  Esc menu")
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
	var left := 1.0 - clampf(joint.turns[i] / joint.full_turns(), 0.0, 1.0)
	if s == BoltJoint.Hole.SEATED or s == BoltJoint.Hole.TORQUED:
		left = 0.0
	var parts := bolt.get_node("Parts") as Node3D
	parts.position.y = left * 0.02
	parts.rotation = Vector3(deg_to_rad(_tilts[i]) if joint.cross[i] else 0.0, joint.turns[i] * TAU, 0.0)
	var scale_d := TradesStubFasteners.diameter_m(joint.fastener[i]) / 0.008
	parts.scale = Vector3(scale_d, 1.0, scale_d)
	bolt.get_node("Washer").visible = joint.washer[i]
	parts.get_node("Paint").visible = s == BoltJoint.Hole.TORQUED


func _hole_world(hole: int) -> Vector3:
	return site.position + Vector3(HOLES[hole].x, 0.006, HOLES[hole].y)


## The hole nearest the aim line, within pick distance, or -1.
func _hole_under_aim() -> int:
	if not joint.bracket_seated:
		return -1
	var best := -1
	var best_d := PICK_HOLE_M
	for i in HOLES.size():
		var d := _aim_distance(_hole_world(i))
		if d < best_d:
			best = i
			best_d = d
	return best


## How far a point is from the aim line (metres), or INF if it is behind you or out of reach.
func _aim_distance(p: Vector3) -> float:
	var o := worker.aim_origin()
	var d := worker.aim_dir()
	var t := (p - o).dot(d)
	if t < 0.0 or t > 4.0:
		return INF
	return (o + d * t).distance_to(p)


## How far from a hole's centre the aim meets the bench top, in millimetres.
func _aim_offset_mm(p: Vector3) -> float:
	var hit: Variant = Plane(Vector3.UP, p.y).intersects_ray(worker.aim_origin(), worker.aim_dir())
	return _flat(hit).distance_to(_flat(p)) * 1000.0 if hit != null else 999.0


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


## A bolt: shank, hex head. Origin at the underside of the head.
func _bolt_mesh(parent: Node) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	_add_cylinder(0.004, 0.03, Vector3(0, -0.009, 0), STEEL, root)
	var head := _add_cylinder(0.0068, 0.0055, Vector3(0, 0.00875, 0), STEEL, root)
	(head.mesh as CylinderMesh).radial_segments = 6
	return root


func _add_solid_box(body: StaticBody3D, size: Vector3, pos: Vector3, color: Color) -> void:
	_add_box(size, pos, color)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	body.add_child(shape)


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


## A short decaying noise burst, low-passed to taste: the wrench click and thread ticks.
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
