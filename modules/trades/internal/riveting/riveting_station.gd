extends TradesStation
## Riveting: a steel strap lapped on a sheet in a fixture, five rivet positions marked down
## the strap, and a tray of 3.2 mm rivets. Drill each mark (hold still, or the hole goes
## oversize), deburr it with your hands, set a rivet from the tray, then squeeze its tail
## into a head with the squeezer, watching the gauge. All the rules live in RivetJoint.
##
##   Tab picks the rivet length.

const BENCH_TOP := TradesBay.BENCH_TOP
## The fixture holds the work off the bench so the squeezer's yoke can reach under it.
const WORK_Y := BENCH_TOP + 0.04
const SHEET_MM := 1.6
## Top of the strap, where the marks are.
const TOP_Y := WORK_Y + SHEET_MM * 2.0 / 1000.0
const MARKS: Array[float] = [-0.06, -0.03, 0.0, 0.03, 0.06]
const LINE_Z := 0.0
const TRAY := Vector3(-0.3, BENCH_TOP + 0.02, 0.1)
const PICK_MARK_M := 0.012
const PICK_TRAY_M := 0.09
## Stands in for a hole that can't be picked (far below the floor).
const FAR := Vector3(0, -1000, 0)
## The bit wanders no further than this from the mark you aimed at.
const MAX_OFFSET_MM := 6.0
## Squeeze per pixel of mouse pulled back.
const SQUEEZE_PER_PX := 0.0025

var joint: RivetJoint
var site: JointSite
var length_index := 1

var STEEL := TradesLook.paint(Color(0.62, 0.64, 0.66), 0.8, 0.3, "brushed_steel")
var ZINC := TradesLook.paint(Color(0.7, 0.72, 0.74), 0.7, 0.4, "galvanised")
var ALLOY := TradesLook.paint(Color(0.8, 0.81, 0.82), 0.85, 0.3)
var DARK := TradesLook.paint(TradesLook.DARK, 0.55, 0.5)
var HOLE := TradesLook.paint(Color(0.03, 0.03, 0.035), 0.2, 0.8)
var BURR := TradesLook.paint(Color(0.92, 0.92, 0.9), 0.95, 0.15)
var MARK := TradesLook.glow(TradesLook.TRIM, 0.6)

## Where each hole actually went (station space, on the strap's top).
var _hole_at: Array[Vector3] = []
var _rivets: Array[Node3D] = []
var _hole_marks: Array[Node3D] = []
var _rivet_in_hand := false
var _hand_rivet: Node3D
var _drilling := -1
var _drill_offset := Vector3.ZERO
var _wobble_px := 0.0
var _deburring := -1
var _pull_px := 0.0
var _started := false
var _left_busy := 0.0


func build() -> void:
	title = "Riveting"
	half_width = 0.55
	var spec := JointSpec.new()
	spec.trade = &"RIVET"
	spec.fastener_id = &"rivet_3.2_ad"
	spec.torque_target_nm = 0.0
	spec.needs_washer = false
	joint = RivetJoint.new(spec, MARKS.size())
	joint.changed.connect(_on_joint_changed)
	joint.completed.connect(_on_joint_completed)
	_build_parts()
	_build_site(spec)
	_hand_rivet = _rivet_mesh(self, 8.0)
	_hand_rivet.top_level = true
	_hand_rivet.visible = false
	reset()


func tools() -> Array[StringName]:
	return [&"hands", &"drill", &"rivet_squeezer"]


func status_line() -> String:
	return "RIVET   %.1f x %d MM%s" % [joint.rivet_d_mm, roundi(RivetJoint.LENGTHS[length_index]),
			"  IN HAND" if _rivet_in_hand else ""]


func start_hint() -> String:
	return "Drill (3) each orange mark. Hold still while it cuts."


func key(k: Key) -> bool:
	if k == KEY_TAB:
		length_index = (length_index + 1) % RivetJoint.LENGTHS.size()
		return true
	return false


func is_busy() -> bool:
	return _drilling >= 0 or _deburring >= 0 or joint.squeezing_hole() >= 0


func reset() -> void:
	if joint.is_complete():
		_bus_remove()
	_stop_hands()
	var bus := bay.bus()
	joint.speed = 1.0 + (bus.modifier(1, &"rivet_speed") if bus else 0.0)
	joint.reset()
	_rivet_in_hand = false
	_started = false
	for i in MARKS.size():
		_hole_at[i] = Vector3(MARKS[i], TOP_Y, LINE_Z)
	_on_joint_changed()


func motion(relative: Vector2) -> bool:
	if _drilling >= 0:
		_wobble_px += relative.length()
		return true
	if joint.squeezing_hole() >= 0:
		_pull_px = maxf(0.0, _pull_px + relative.y)
		joint.press(_pull_px * SQUEEZE_PER_PX)
		return true
	return _deburring >= 0


func press(tool: StringName) -> void:
	var worker := bay.worker
	match tool:
		&"drill":
			var hole := _mark_under_aim()
			if hole < 0:
				return
			if not worker.right_hand.can_reach(world(_hole_at[hole])):
				bay.hint("Too far. Step closer.")
				return
			var hit: Variant = bay.aim_on(Plane(Vector3.UP, world(_hole_at[hole]).y))
			var off := to_local(hit) - _hole_at[hole] if hit != null else Vector3.ZERO
			off.y = 0.0
			_drill_offset = off.limit_length(MAX_OFFSET_MM / 1000.0)
			_drilling = hole
			_wobble_px = 0.0
			worker.look_locked = true
			_mark_started()
			bay.hint("Drilling. Keep the mouse still.")
		&"rivet_squeezer":
			var hole := _hole_under_aim(true)
			if hole < 0:
				return
			if not worker.right_hand.can_reach(world(_hole_at[hole])):
				bay.hint("Too far. Step closer.")
			elif joint.begin_squeeze(hole):
				_pull_px = joint.squeeze[hole] / SQUEEZE_PER_PX
				worker.look_locked = true
				bay.hint("Pull the mouse back to squeeze. Watch the head on the gauge.")
			else:
				bay.hint("Set a rivet in that hole first (hands, 1).")
		&"hands":
			_press_hands()
		_:
			bay.hint("Riveting takes your hands (1), the drill (3) and the squeezer (4).")


func _press_hands() -> void:
	var worker := bay.worker
	if bay.aim_distance(world(TRAY)) < PICK_TRAY_M:
		if worker.left_hand.can_reach(world(TRAY)):
			_rivet_in_hand = true
			_left_busy = 0.35
			worker.left_hand.reach_to(world(TRAY))
			bay.hint("Got a %d mm rivet. Click a drilled hole to set it." % roundi(RivetJoint.LENGTHS[length_index]))
		else:
			bay.hint("Too far. Step closer.")
		return
	var hole := _hole_under_aim(false)
	if hole < 0 or joint.state[hole] != RivetJoint.Hole.DRILLED:
		return
	if not worker.right_hand.can_reach(world(_hole_at[hole])):
		bay.hint("Too far. Step closer.")
		return
	if _rivet_in_hand:
		joint.insert(hole, RivetJoint.LENGTHS[length_index])
		_rivet_in_hand = false
		worker.right_hand.reach_to(world(_hole_at[hole]) + Vector3(0, 0.01, 0))
		_left_busy = 0.3
		bay.play(&"tick", 1.4)
		bay.hint("Rivet set. Squeeze it with the squeezer (4)." if joint.deburred[hole] \
				else "Rivet set in a rough hole. Deburr first next time.")
		return
	_deburring = hole
	worker.look_locked = true
	bay.hint("Deburring. Hold it.")


func release() -> void:
	var worker := bay.worker
	if _drilling >= 0:
		_drilling = -1
		worker.look_locked = false
		worker.right_hand.come_back()
		worker.right_hand.set_grip(0.0)
		bay.loop(&"drill", false)
		(bay.tool_node(&"drill") as TradesDrill).spin = 0.0
	if _deburring >= 0:
		_deburring = -1
		worker.look_locked = false
		worker.right_hand.come_back()
		worker.right_hand.set_spin(0.0)
	if joint.squeezing_hole() >= 0:
		joint.end_squeeze()
		worker.look_locked = false
		worker.right_hand.come_back()
		bay.play(&"clunk", 0.8)


func back_out(tool: StringName) -> void:
	if tool != &"drill":
		if tool == &"hands" and _rivet_in_hand:
			_rivet_in_hand = false
			bay.hint("Rivet back in the tray.")
		return
	var hole := _hole_under_aim(true)
	if hole < 0:
		return
	if joint.drill_out(hole):
		_bus_remove()
		bay.hide_result()
	bay.hint("Rivet drilled out. The hole is a little bigger now; deburr it again.")


func update(delta: float) -> void:
	var worker := bay.worker
	if _left_busy > 0.0:
		_left_busy -= delta
		if _left_busy <= 0.0:
			worker.left_hand.come_back()
			worker.left_hand.set_grip(0.5 if _rivet_in_hand else 0.0)
			if _drilling < 0 and _deburring < 0 and joint.squeezing_hole() < 0:
				worker.right_hand.come_back()
	_hand_rivet.visible = _rivet_in_hand
	if _rivet_in_hand:
		_hand_rivet.global_position = worker.left_hand.palm() * Vector3(0, -0.02, -0.06)
	_update_drill(delta)
	_update_deburr(delta)
	_update_squeezer()


func _update_drill(delta: float) -> void:
	var drill := bay.tool_node(&"drill") as TradesDrill
	if _drilling < 0:
		return
	var worker := bay.worker
	var hole := _drilling
	var at := world(_hole_at[hole] + _drill_offset)
	var depth := joint.drill_progress(hole) * SHEET_MM * 2.0 / 1000.0
	var xform := Transform3D(Basis(Vector3.UP, _face_yaw(at)), at + Vector3(0, -depth, 0))
	bay.place_tool(&"drill", xform)
	worker.right_hand.reach_to(xform * TradesDrill.GRIP)
	worker.right_hand.set_grip(1.0)
	if not worker.right_hand.is_on_target():
		return
	drill.spin = 1.0
	bay.loop(&"drill", true)
	var result := joint.drill(hole, Vector2(_drill_offset.x, _drill_offset.z).length() * 1000.0, _wobble_px, delta)
	_wobble_px = 0.0
	if result == &"through":
		_hole_at[hole] += _drill_offset
		_hole_at[hole].y = TOP_Y
		_on_joint_changed()
		release()
		bay.hint("Through. Deburr the hole with your hands (1), then set a rivet.")


func _update_deburr(delta: float) -> void:
	if _deburring < 0:
		return
	var worker := bay.worker
	worker.right_hand.reach_to(world(_hole_at[_deburring]) + Vector3(0, 0.012, 0))
	worker.right_hand.set_grip(0.8)
	if not worker.right_hand.is_on_target():
		return
	worker.right_hand.set_spin(sin(Time.get_ticks_msec() * 0.012) * 0.8)
	if joint.deburr(_deburring, delta):
		release()
		bay.hint("Clean. Take a rivet from the tray (Tab picks the length).")


func _update_squeezer() -> void:
	var squeezer := bay.tool_node(&"rivet_squeezer") as TradesRivetSqueezer
	var hole := joint.squeezing_hole()
	if hole < 0:
		squeezer.head_mm = -1.0
		squeezer.closed = 0.0
		return
	squeezer.head_mm = joint.head_height_mm(hole)
	squeezer.dia_mm = joint.head_dia_mm(hole)
	squeezer.closed = joint.squeeze[hole] / joint.max_squeeze
	var at := world(_hole_at[hole]) + Vector3(0, joint.head_height_mm(hole) / 1000.0, 0)
	var xform := Transform3D(Basis(Vector3.UP, _face_yaw(at)), at)
	bay.place_tool(&"rivet_squeezer", xform)
	bay.worker.right_hand.reach_to(xform * TradesRivetSqueezer.GRIP + Vector3(0, 0.015, 0))
	bay.worker.right_hand.set_grip(0.6 + 0.4 * squeezer.closed)


## Turn a tool on the work so its handle points back at the worker.
func _face_yaw(at: Vector3) -> float:
	var to_worker := bay.worker.global_position - at
	return atan2(to_worker.x, to_worker.z)


func _stop_hands() -> void:
	release()
	if bay and bay.worker:
		bay.worker.look_locked = false
		bay.worker.left_hand.come_back()
		bay.worker.right_hand.come_back()


func _mark_started() -> void:
	if _started:
		return
	_started = true
	var bus := bay.bus()
	if bus:
		bus.joint_started.emit(site.joint_id, site.spec.trade, 1)


func _on_joint_changed() -> void:
	if _rivets.is_empty():
		return
	for i in MARKS.size():
		_pose_hole(i)
	var bus := bay.bus()
	if bus and _started:
		bus.joint_progress.emit(site.joint_id, joint.progress())


func _on_joint_completed() -> void:
	var m := joint.measurements()
	var bus := bay.bus()
	if bus:
		bus.complete_joint(site, m)
	var lines: PackedStringArray = ["RIVETED JOINT COMPLETE", ""]
	for i in MARKS.size():
		var notes: PackedStringArray = []
		if m.cracked_head[i]:
			notes.append("cracked")
		if not m.seated[i]:
			notes.append("not drawn tight")
		if not m.deburred[i]:
			notes.append("burr")
		lines.append("Rivet %d: head %.2f x %.2f mm, hole +%.2f %s" % [i + 1, m.head_height_mm[i],
				m.head_dia_mm[i], m.hole_fit_mm[i], ", ".join(notes)])
	lines.append("Target head: %.1f high x %.1f mm across" % [m.head_height_target_mm, m.head_dia_target_mm])
	bay.show_result(lines)
	bay.hint("Done.")


## Release screenshot: every hole drilled and deburred, rivets set, three squeezed and the
## squeezer closing on the fourth.
func stage_for_screenshot() -> void:
	for i in MARKS.size():
		while joint.drill(i, 0.3, 0.0, 0.1) == &"drilling":
			pass
		while not joint.deburr(i, 0.1):
			pass
		joint.insert(i, 8.0)
	for i in 3:
		joint.begin_squeeze(i)
		joint.press(0.667)
		joint.end_squeeze()
	bay.set_tool(&"rivet_squeezer")
	joint.begin_squeeze(3)
	_pull_px = 0.45 / SQUEEZE_PER_PX
	joint.press(0.45)
	bay.hint("Pull the mouse back to squeeze. Watch the head on the gauge.")


func screenshot_view() -> Array[Vector3]:
	return [Vector3(0.06, 0.0, 0.36), Vector3(0.01, WORK_Y, 0.0)]


# --- Building --------------------------------------------------------------------------

func _build_parts() -> void:
	# Fixture: a dark base with two raised jaws; the sheet across them, the strap lapped on top.
	paint_box(Vector3(0.26, 0.012, 0.12), Vector3(0, BENCH_TOP + 0.006, 0), DARK)
	for x: float in [-0.11, 0.11]:
		paint_box(Vector3(0.03, 0.028, 0.1), Vector3(x, BENCH_TOP + 0.026, 0), DARK)
		paint_cylinder(0.006, 0.01, Vector3(x, WORK_Y + 0.008, 0.03), STEEL)                # clamp knobs
		paint_box(Vector3(0.03, 0.006, 0.02), Vector3(x, WORK_Y + 0.003, 0.03), STEEL)
	paint_box(Vector3(0.22, SHEET_MM / 1000.0, 0.1), Vector3(0, WORK_Y + SHEET_MM / 2000.0, 0.02), ZINC)
	paint_box(Vector3(0.2, SHEET_MM / 1000.0, 0.035), Vector3(0, WORK_Y + SHEET_MM * 1.5 / 1000.0, LINE_Z), STEEL)
	# Tray of rivets: three bins, short to long.
	paint_box(Vector3(0.16, 0.025, 0.08), TRAY - Vector3(0, 0.008, 0), DARK)
	for b in 3:
		var bin_x := -0.05 + b * 0.05
		bench_label("%d" % roundi(RivetJoint.LENGTHS[b]), TRAY + Vector3(bin_x, 0.006, 0.03))
		for i in 4:
			var r := _rivet_mesh(self, RivetJoint.LENGTHS[b])
			r.position = TRAY + Vector3(bin_x - 0.012 + (i % 2) * 0.024, 0.005, -0.012 + (i / 2) * 0.016)
			r.rotation_degrees.z = 90


func _build_site(spec: JointSpec) -> void:
	site = JointSite.new()
	site.name = "LapJoint"
	site.joint_id = &"bench_lap"
	site.spec = spec
	add_child(site)
	for i in MARKS.size():
		var m := Marker3D.new()
		m.name = "Hole%d" % i
		m.position = Vector3(MARKS[i], TOP_Y, LINE_Z)
		site.add_child(m)
		_hole_at.append(m.position)
		bench_label(str(i + 1), Vector3(MARKS[i], TOP_Y + 0.0005, LINE_Z + 0.026))
		# The mark: an orange cross scribed on the strap.
		var mark := Node3D.new()
		mark.position = m.position + Vector3(0, 0.0003, 0)
		add_child(mark)
		paint_box(Vector3(0.008, 0.0004, 0.0012), Vector3.ZERO, MARK, mark)
		paint_box(Vector3(0.0012, 0.0004, 0.008), Vector3.ZERO, MARK, mark)
		_hole_marks.append(mark)
		# The hole once drilled (with its burr until deburred), and the rivet in it.
		var hole := Node3D.new()
		hole.name = "Drilled%d" % i
		add_child(hole)
		paint_cylinder(0.00165, 0.0005, Vector3(0, 0.0002, 0), HOLE, hole, 12).name = "Bore"
		var burr := paint_cylinder(0.0024, 0.0004, Vector3(0, 0.0003, 0), BURR, hole, 12)
		burr.name = "Burr"
		var rivet := Node3D.new()
		rivet.name = "Rivet%d" % i
		add_child(rivet)
		paint_cylinder(0.0016, 1.0, Vector3(0, 0.5, 0), ALLOY, rivet, 12).name = "Head"
		paint_cylinder(0.0029, 0.0012, Vector3(0, -SHEET_MM * 2.0 / 1000.0 - 0.0006, 0), ALLOY, rivet, 12)
		_rivets.append(rivet)


## A loose rivet: shank and a domed factory head. Origin under the head.
func _rivet_mesh(parent: Node, length: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	paint_cylinder(0.0016, length / 1000.0, Vector3(0, length / 2000.0, 0), ALLOY, root, 10)
	paint_cylinder(0.0029, 0.0012, Vector3(0, -0.0006, 0), ALLOY, root, 10)
	return root


func _pose_hole(i: int) -> void:
	var s := joint.state[i]
	var drilled := get_node("Drilled%d" % i) as Node3D
	drilled.visible = s == RivetJoint.Hole.DRILLED
	drilled.position = _hole_at[i]
	var bore_r := (joint.rivet_d_mm + joint.clearance_mm[i]) / 2000.0
	(drilled.get_node("Bore") as MeshInstance3D).scale = Vector3(bore_r / 0.00165, 1, bore_r / 0.00165)
	drilled.get_node("Burr").visible = not joint.deburred[i]
	_hole_marks[i].visible = s == RivetJoint.Hole.MARKED
	var rivet := _rivets[i]
	rivet.visible = s == RivetJoint.Hole.RIVET or s == RivetJoint.Hole.FORMED
	rivet.position = _hole_at[i]
	if rivet.visible:
		var head := rivet.get_node("Head") as MeshInstance3D
		var r := joint.head_dia_mm(i) / 2000.0
		head.scale = Vector3(r / 0.0016, joint.head_height_mm(i) / 1000.0, r / 0.0016)
		head.position.y = joint.head_height_mm(i) / 2000.0


## The undrilled mark nearest the aim, within pick distance, or -1.
func _mark_under_aim() -> int:
	var points: Array = []
	for i in MARKS.size():
		points.append(world(_hole_at[i]) if joint.state[i] == RivetJoint.Hole.MARKED else FAR)
	return bay.pick(points, PICK_MARK_M)


## The drilled hole nearest the aim (with a rivet in it, or empty), or -1.
func _hole_under_aim(with_rivet: bool) -> int:
	var points: Array = []
	for i in MARKS.size():
		var s := joint.state[i]
		var ok := (s == RivetJoint.Hole.RIVET or s == RivetJoint.Hole.FORMED) if with_rivet else s == RivetJoint.Hole.DRILLED
		points.append(world(_hole_at[i]) if ok else FAR)
	return bay.pick(points, PICK_MARK_M)


func _bus_remove() -> void:
	var bus := bay.bus()
	if bus:
		bus.remove_joint(site.joint_id)
