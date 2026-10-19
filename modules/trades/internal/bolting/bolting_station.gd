extends TradesStation
## Bolting: a steel plate, a four-hole angle bracket beside it and a tray of bolts. Set the
## bracket on the plate (hands; the wheel turns it), screw each bolt in by hand (aim at the
## hole's centre or it cross-threads and jams), then torque them with the torque wrench in
## the order on the plate. All the rules live in BoltJoint.
##
##   Tab changes bolt, F the washer.

const TUNING: BoltingTuning = preload("res://modules/trades/internal/bolting/bolting.tres")
const BENCH_TOP := TradesBay.BENCH_TOP
const PLATE_Y := BENCH_TOP + 0.012
## Hole positions on the bracket base (x, z), clockwise from far left.
const HOLES: Array[Vector2] = [Vector2(-0.04, -0.025), Vector2(0.04, -0.025), Vector2(0.04, 0.025), Vector2(-0.04, 0.025)]
const BRACKET_HOME := Vector3(0.3, BENCH_TOP, 0.08)
const BRACKET_HOME_YAW := 22.0
const TRAY := Vector3(-0.3, BENCH_TOP + 0.02, 0.1)
const PICK_HOLE_M := 0.03
const PICK_BRACKET_M := 0.08
const PICK_TRAY_M := 0.09

var joint: BoltJoint
var site: JointSite
var wrench: TradesTorqueWrench
var fastener_index := 0
var with_washer := true

var STEEL := TradesLook.paint(Color(0.62, 0.64, 0.66), 0.8, 0.3, "brushed_steel")
var ZINC := TradesLook.paint(Color(0.7, 0.72, 0.74), 0.7, 0.4, "galvanised")
var DARK := TradesLook.paint(TradesLook.DARK, 0.55, 0.5)
var PAINT := TradesLook.paint(TradesLook.TRIM, 0.3, 0.45)

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
var _tick_wait := 0.0
## Seconds the left hand stays out at the tray after taking a bolt.
var _left_busy := 0.0


func build() -> void:
	title = "Bolting"
	half_width = 0.55
	var spec := JointSpec.new()
	spec.trade = &"BOLT"
	spec.fastener_id = &"bolt_m8x25_8.8"
	spec.torque_target_nm = 25.0
	spec.sequence = PackedInt32Array([0, 2, 1, 3])
	spec.needs_washer = true
	_build_parts()
	_build_site(spec)
	_build_bracket()
	_build_bolts()
	_hand_bolt = _bolt_mesh(self)
	_hand_bolt.name = "BoltInHand"
	_hand_bolt.top_level = true
	_hand_bolt.visible = false
	wrench = bay.tool_node(&"torque_wrench") as TradesTorqueWrench
	joint = BoltJoint.new(spec, HOLES.size(), TUNING)
	joint.changed.connect(_on_joint_changed)
	joint.wrench_clicked.connect(_on_wrench_clicked)
	joint.completed.connect(_on_joint_completed)
	_tilts.resize(HOLES.size())
	wrench.set_nm = spec.torque_target_nm
	reset()


func tools() -> Array[StringName]:
	return [&"hands", &"torque_wrench"]


func status_line() -> String:
	var ids := TradesStubFasteners.ids()
	return "BOLT    %s  %s" % [TradesStubFasteners.label(ids[fastener_index]).to_upper(),
			"+ WASHER" if with_washer else "NO WASHER"]


func start_hint() -> String:
	if not joint.bracket_seated:
		return "Pick up the bracket and set it on the plate."
	return "Take a bolt from the tray and screw it in by hand. Torque wrench is 2."


func key(k: Key) -> bool:
	match k:
		KEY_TAB:
			fastener_index = (fastener_index + 1) % TradesStubFasteners.ids().size()
			return true
		KEY_F:
			with_washer = not with_washer
			return true
	return false


func is_busy() -> bool:
	return _carrying or _turning_hole >= 0 or joint.pulling_hole() >= 0


func reset() -> void:
	if joint.is_complete():
		_bus_remove()
	_stop_hands()
	joint.reset()
	var bus := bay.bus()
	joint.speed = 1.0 + (bus.modifier(1, &"bolt_speed") if bus else 0.0)
	_tilts.fill(0.0)
	_carrying = false
	_bolt_in_hand = false
	_started = false
	_bracket_yaw = BRACKET_HOME_YAW
	_bracket.position = BRACKET_HOME
	_bracket.rotation_degrees.y = _bracket_yaw


func motion(relative: Vector2) -> bool:
	if joint.pulling_hole() < 0:
		return false
	_pull_px = maxf(0.0, _pull_px + relative.y)
	joint.pull(_pull_px * TUNING.nm_per_px)
	return true


func wheel(step: int) -> bool:
	if not _carrying:
		return false
	_bracket_yaw = wrapf(_bracket_yaw + 4.0 * step, -180.0, 180.0)
	return true


func update(delta: float) -> void:
	_update_carry(delta)
	_update_turning(delta)
	_update_wrench()
	_hand_bolt.visible = _bolt_in_hand
	if _bolt_in_hand:
		_hand_bolt.global_position = bay.worker.left_hand.palm() * Vector3(0, -0.02, -0.06)


# --- What the hands do ---------------------------------------------------------------

func press(tool: StringName) -> void:
	var worker := bay.worker
	if tool == &"torque_wrench":
		var hole := _hole_under_aim()
		if hole < 0:
			return
		if not worker.right_hand.can_reach(_hole_world(hole)):
			bay.hint("Too far. Step closer.")
		elif joint.begin_pull(hole):
			_pull_px = 0.0
			worker.look_locked = true
			bay.hint("Pull the mouse back. Stop at the click.")
		else:
			bay.hint("Screw that bolt in by hand first.")
		return
	if tool != &"hands":
		bay.hint("Bolting takes your hands (1) and the torque wrench (2).")
		return
	if _carrying:
		_set_bracket_down()
		return
	if not joint.bracket_seated and bay.aim_distance(_bracket.global_position) < PICK_BRACKET_M:
		if worker.left_hand.can_reach(_bracket.global_position):
			_carrying = true
			_mark_started()
			bay.hint("Wheel turns it. Square it up over the plate and click to set it down.")
		else:
			bay.hint("Too far. Step closer.")
		return
	if bay.aim_distance(world(TRAY)) < PICK_TRAY_M:
		if worker.left_hand.can_reach(world(TRAY)):
			_bolt_in_hand = true
			_left_busy = 0.35
			worker.left_hand.reach_to(world(TRAY))
			bay.hint("Got a bolt. Hold left click on a hole to screw it in.")
		return
	var hole := _hole_under_aim()
	if hole < 0:
		return
	if not worker.right_hand.can_reach(_hole_world(hole)):
		bay.hint("Too far. Step closer.")
		return
	if joint.state[hole] == BoltJoint.Hole.EMPTY:
		if not _bolt_in_hand:
			bay.hint("Take a bolt from the tray first.")
			return
		var offset_mm := _aim_offset_mm(_hole_world(hole))
		_tilts[hole] = joint.tilt_for_offset(offset_mm)
	_turning_hole = hole
	worker.look_locked = true


func release() -> void:
	var worker := bay.worker
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
			bay.hint("Let go too early; that bolt is not at final torque.")


func back_out(tool: StringName) -> void:
	var hole := _hole_under_aim()
	if hole >= 0 and joint.state[hole] != BoltJoint.Hole.EMPTY:
		if joint.back_out(hole):
			_bus_remove()
			bay.hide_result()
		bay.hint("Bolt out.")
	elif tool == &"hands" and bay.aim_distance(_bracket.global_position) < PICK_BRACKET_M and joint.lift_bracket():
		_carrying = true


func on_hand_snapped() -> void:
	if _turning_hole >= 0 or joint.pulling_hole() >= 0:
		release()
	if _carrying:
		_set_bracket_down()


func _set_bracket_down() -> void:
	_carrying = false
	bay.worker.left_hand.come_back()
	var offset_mm := _flat(_bracket.position).distance_to(_flat(site.position)) * 1000.0
	if joint.place_bracket(offset_mm, _bracket_yaw):
		_bracket.position = Vector3(site.position.x, PLATE_Y, site.position.z)
		_bracket_yaw = 0.0
		_bracket.rotation_degrees.y = 0.0
		bay.hint("Seated. Take a bolt from the tray.")
	else:
		_bracket.position.y = PLATE_Y if _over_plate(_bracket.position) else BENCH_TOP
		bay.hint("Not lined up with the holes. Pick it up again.")


## The bracket rides where you aim on the bench top, held out in your left hand.
func _update_carry(delta: float) -> void:
	var worker := bay.worker
	if not _carrying:
		if _left_busy > 0.0:
			_left_busy -= delta
			if _left_busy <= 0.0:
				worker.left_hand.come_back()
				worker.left_hand.set_grip(0.5 if _bolt_in_hand else 0.0)
		return
	var hit: Variant = bay.aim_on(Plane(Vector3.UP, PLATE_Y + 0.01))
	var at: Vector3 = hit if hit != null else worker.aim_origin() + worker.aim_dir() * 0.6
	var shoulder := worker.left_hand.get_parent_node_3d().global_position
	var limit := TradesBay.HAND_REACH_M + TradesBay.HAND_STRETCH_M * 0.8
	if at.distance_to(shoulder) > limit:
		at = shoulder + (at - shoulder).normalized() * limit
	_bracket.global_position = at
	_bracket.rotation_degrees.y = _bracket_yaw
	worker.left_hand.reach_to(at + Vector3(0, 0.012, 0.02))
	worker.left_hand.set_grip(0.6)


## While left click is held on a hole: the right hand is on the bolt, turning it.
func _update_turning(delta: float) -> void:
	if _turning_hole < 0:
		return
	var worker := bay.worker
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
			bay.hint("It's jammed. Cross-threaded? Right click to back it out.")
		&"started":
			bay.play(&"tick", 0.6)
			bay.hint("Thread caught. Keep turning.")
		&"seated":
			bay.play(&"tick", 1.3)
			bay.hint("Finger tight. Final torque with the torque wrench (2).")
			release()
		&"turning":
			_mark_started()
			_tick_wait -= delta
			if _tick_wait <= 0.0:
				_tick_wait = 0.18
				bay.play(&"tick", 1.0)
		&"":
			release()


## The wrench on its bolt while pulling (the right hand on its grip); otherwise the bay
## carries it.
func _update_wrench() -> void:
	var hole := joint.pulling_hole()
	wrench.applied_nm = _pull_px * TUNING.nm_per_px if hole >= 0 else 0.0
	if hole < 0:
		return
	var worker := bay.worker
	var applied := _pull_px * TUNING.nm_per_px
	var swing := clampf(applied / site.spec.torque_target_nm, 0.0, 1.6) * 25.0
	# Handle points back toward the worker, swinging round the bolt as it's pulled.
	var to_worker := worker.global_position - _hole_world(hole)
	var yaw := atan2(to_worker.x, to_worker.z) + deg_to_rad(35.0 - swing)
	var xform := Transform3D(Basis(Vector3.UP, yaw), _hole_world(hole) + Vector3(0, 0.004, 0))
	bay.place_tool(&"torque_wrench", xform)
	worker.right_hand.reach_to(xform * TradesTorqueWrench.GRIP + Vector3(0, 0.02, 0))
	worker.right_hand.set_grip(1.0)


func _stop_hands() -> void:
	release()
	_turning_hole = -1
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
	for i in _bolts.size():
		_pose_bolt(i)
	var bus := bay.bus()
	if bus and _started:
		bus.joint_progress.emit(site.joint_id, joint.progress())


func _on_wrench_clicked(_hole: int) -> void:
	bay.play(&"click")
	wrench.click()
	bay.worker.kick(TUNING.click_kick)
	bay.hint("Click. Let go now.")


func _on_joint_completed() -> void:
	var m := joint.measurements()
	var bus := bay.bus()
	if bus:
		bus.complete_joint(site, m)
	var lines: PackedStringArray = ["BOLTED JOINT COMPLETE", ""]
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
	bay.show_result(lines)
	bay.hint("Done.")


## Release screenshot: bracket seated, two bolts torqued, the wrench mid-pull on a third.
func stage_for_screenshot() -> void:
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
	bay.set_tool(&"torque_wrench")
	joint.begin_pull(1)
	_pull_px = 18.0 / TUNING.nm_per_px
	joint.pull(18.0)
	bay.worker.left_hand.reach_to(_bracket.global_position + Vector3(-0.05, 0.012, 0.03))
	bay.hint("Pull the mouse back. Stop at the click.")


# --- Building --------------------------------------------------------------------------

func _build_parts() -> void:
	paint_box(Vector3(0.3, 0.012, 0.2), Vector3(0, BENCH_TOP + 0.006, 0), ZINC)            # plate
	for x: float in [-0.13, 0.13]:
		for z: float in [-0.085, 0.085]:
			paint_cylinder(0.006, 0.003, Vector3(x, BENCH_TOP + 0.013, z), STEEL)         # plate screws
	paint_box(Vector3(0.16, 0.03, 0.1), TRAY - Vector3(0, 0.005, 0), DARK)               # bolt tray
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
		paint_cylinder(0.0045, 0.001, m.position + Vector3(0, 0.0005, 0), DARK, site)
		bench_label(str(spec.sequence.find(i) + 1), m.position + Vector3(signf(HOLES[i].x) * 0.035, 0.001, 0.0), site)
	add_child(site)


func _build_bracket() -> void:
	_bracket = Node3D.new()
	_bracket.name = "Bracket"
	add_child(_bracket)
	paint_box(Vector3(0.12, 0.006, 0.08), Vector3(0, 0.003, 0), STEEL, _bracket)
	paint_box(Vector3(0.12, 0.08, 0.006), Vector3(0, 0.04, -0.037), STEEL, _bracket)
	for h in HOLES:
		paint_cylinder(0.0048, 0.001, Vector3(h.x, 0.0062, h.y), DARK, _bracket)


func _build_bolts() -> void:
	for i in HOLES.size():
		var bolt := Node3D.new()
		bolt.name = "Bolt%d" % i
		var parts := _bolt_mesh(bolt)
		parts.name = "Parts"
		paint_box(Vector3(0.0136, 0.0012, 0.0016), Vector3(0, 0.0118, 0), PAINT, parts).name = "Paint"
		var washer := paint_cylinder(0.008, 0.0016, Vector3(0, 0.0008, 0), ZINC, bolt)
		washer.name = "Washer"
		bolt.position = site.position + Vector3(HOLES[i].x, 0.006, HOLES[i].y)
		add_child(bolt)
		_bolts.append(bolt)


# --- Helpers ----------------------------------------------------------------------------

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


## A bolt: shank, hex head. Origin at the underside of the head.
func _bolt_mesh(parent: Node) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	paint_cylinder(0.004, 0.03, Vector3(0, -0.009, 0), STEEL, root)
	var head := paint_cylinder(0.0068, 0.0055, Vector3(0, 0.00875, 0), STEEL, root)
	(head.mesh as CylinderMesh).radial_segments = 6
	return root


func _hole_world(hole: int) -> Vector3:
	return world(site.position + Vector3(HOLES[hole].x, 0.006, HOLES[hole].y))


## The hole nearest the aim line, within pick distance, or -1.
func _hole_under_aim() -> int:
	if not joint.bracket_seated:
		return -1
	var points: Array = []
	for i in HOLES.size():
		points.append(_hole_world(i))
	return bay.pick(points, PICK_HOLE_M)


## How far from a hole's centre the aim meets the bench top, in millimetres.
func _aim_offset_mm(p: Vector3) -> float:
	var hit: Variant = bay.aim_on(Plane(Vector3.UP, p.y))
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


func _bus_remove() -> void:
	var bus := bay.bus()
	if bus:
		bus.remove_joint(site.joint_id)
