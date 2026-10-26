extends ModuleTest
## beenster, 26 Oct: "copy the behaviours of the cutter (for removing rivets), wrench
## (although ours should still have a torque value which is set by player) ... unweld should
## just be a point and click hold ... our welder should be more of a skill game ... keep our
## grabber but make it quieter" (trades.vs_tools, trades.weld_skill, trades.quiet_tractor).

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
const FLAGS := ["trades.vs_tools", "trades.weld_skill", "trades.quiet_tractor", "trades.power_wrench",
		"trades.torque_kept", "trades.cutter", "trades.slim_hotbar", "trades.rivet_heat", "trades.unweld",
		"trades.trace_weld", "trades.weld_from_end", "trades.tractor"]


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var saved := {}
	for flag: String in FLAGS:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	ship_bus.load_ship("vs_kestrel")
	var yard := _fake_yard()
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var station := rig.ship_station()
	var got: Array = []
	var on_done := func(r: JointResult) -> void: got.append(r)
	bus.joint_completed.connect(on_done)

	check(rig.hotbar.has(&"cutter"), "the cutter is back on the yard's hotbar: %s" % str(rig.hotbar))
	check(is_equal_approx(rig._loops[&"beam"].volume_db, TradesTractor.QUIET_DB), "the tractor's hum is quieter")
	check(JointSpec.new().sequence is PackedInt32Array, "a joint spec's order is a packed array")

	# The wrench: a tight bolt spins out, rising as it backs out; let go and it carries on.
	var wrench := rig.tool_node(&"torque_wrench") as TradesPowerWrench
	var b := _first(station, "bolt", true)
	var f := station.points[b]
	var at := station.points_world[b]
	var target := TradesShipJoints.torque_target(f.spec)
	_aim_at(rig, station, b)
	rig.set_tool(&"torque_wrench")
	rig._on_action(TradesBus.KEY_MODE)
	check(not wrench.undo, "no mode to switch")
	station.press(&"torque_wrench")
	check(station.is_busy(), "hold on a tight bolt: it turns")
	_run(station, TradesShipJoints.UNDO_S * 0.5)
	var lift := (wrench.global_position - at).length()
	check(lift > TradesShipJoints.BOLT_TRAVEL_M * 0.3 and station._shank.visible,
			"the wrench rides up the bolt as it backs out (%.3f m)" % lift)
	check(wrench.undo and wrench.panel_state() == "UNDOING", "its display says it's undoing")
	check(ship_bus.is_joint_tight(f.joint_id), "half way out it's still in")
	station.release()
	check(not station.is_busy() and not station._shank.visible, "let go: it stops")
	station.press(&"torque_wrench")
	_run(station, TradesShipJoints.UNDO_S * 0.55)
	check(not ship_bus.is_joint_tight(f.joint_id) and not station.is_busy(), "hold again: it carries on and comes out")

	# A loose bolt runs in to the setting and clicks off by itself.
	wrench.set_nm = target
	station.update(0.0)
	station.press(&"torque_wrench")
	_run(station, TradesShipJoints.SPIN_S * 0.5)
	check(wrench.applied_nm > 0.0 and wrench.applied_nm < target, "running in, the torque climbs (%.0f N m)" % wrench.applied_nm)
	_run(station, TradesShipJoints.SPIN_S * 0.55)
	check(ship_bus.is_joint_tight(f.joint_id) and not station.is_busy(), "at the setting the clutch clicks and it's in")
	check(ship_bus.joint_quality(f.joint_id) > 0.95, "set right: a good bolt")
	check(got.size() == 1 and got[0].trade == &"BOLT" and is_equal_approx(float(got[0].measurements.torque_nm[0]), target),
			"Quality gets the torque")
	_undo_bolt(station)
	wrench.set_nm = TradesShipJoints.torque_range(f.spec).y * 1.5
	station.press(&"torque_wrench")
	_run(station, TradesShipJoints.SPIN_S + 0.05)
	check(ship_bus.is_joint_tight(f.joint_id) and ship_bus.joint_quality(f.joint_id) < 0.8,
			"set too high: in, but poor (%.2f)" % ship_bus.joint_quality(f.joint_id))
	# Drift the aim off and it slips off, keeping what's done.
	station.press(&"torque_wrench")
	_run(station, 0.4)
	rig.worker.face(at + Vector3(0, 1.5, 0))
	station.update(0.05)
	check(not station.is_busy() and station._kept_s.has(f.joint_id + ":out"), "aim off the bolt and the wrench slips off it")
	_aim_at(rig, station, b)
	var tips := "\n".join(rig.context_tips())
	check(tips.contains("spin it out") and not tips.contains("switch to"), "the tips: %s" % tips.replace("\n", " | "))

	# The cutter: the disc spins up, then bites and grinds the rivet's head off.
	var r := _first(station, "rivet", true)
	var rf := station.points[r]
	_aim_at(rig, station, r)
	rig.set_tool(&"cutter")
	var cutter := rig.tool_node(&"cutter") as TradesCutter
	station.press(&"cutter")
	_run(station, TradesShipJoints.SPIN_UP_S * 0.5)
	check(station.is_busy() and cutter.spin > 0.0 and cutter.spin < 1.0 and not cutter.biting, "the disc spins up first")
	_run(station, TradesShipJoints.SPIN_UP_S * 0.6 + 0.1)
	check(cutter.biting and cutter.panel_state() == "GRINDING", "then it bites")
	_run(station, TradesShipJoints.GRIND_S)
	check(not ship_bus.is_joint_tight(rf.joint_id) and not station.is_busy(), "and grinds the head off")
	cutter._process(1.0)
	check(cutter.heat == 0.0 or not cutter.biting, "it cools once it's out of the work")

	# Unweld: point anywhere on a weld and hold.
	var w := _traced_weld(station)
	var wf := station.points[w]
	var wat := station.points_world[w]
	var along := (station.ship_xform.basis * wf.seam_up).normalized()
	_aim_at(rig, station, w)
	rig.set_tool(&"welder")
	var torch := rig.tool_node(&"welder") as TradesWeldTorch
	torch.unweld = false
	rig.worker.face(wat + along * wf.seam_size.x * 0.1)
	station.update(0.0)
	station.press(&"welder")
	check(station.is_busy(), "hold on the middle of a weld: the arc cuts it, no end to start from")
	_run(station, TradesShipJoints.UNWELD_S + 0.05)
	check(not ship_bus.is_joint_tight(wf.joint_id) and station.hot_beads() > 0, "and it's cut out, glowing")

	# Welding at a steady pace near the line: a good weld.
	got.clear()
	var steady := _weld_run(rig, station, w, TradesShipJoints.WELD_SPEED_MM_S)
	check(ship_bus.is_joint_tight(wf.joint_id), "a steady run along the seam welds it")
	check(steady > 0.9, "a good weld at an even pace (%.2f)" % steady)
	var m: Dictionary = got[0].measurements if got.size() == 1 else {}
	check(got.size() == 1 and got[0].trade == &"WELD" and not bool(m.get("burn_through", true))
			and float(m.get("penetration", 0.0)) > 0.9, "Quality gets the readings: %s" % str(m))
	var speeds: Array = m.get("travel_speed_mm_s", [])
	var mean := 0.0
	for v: float in speeds:
		mean += v / maxi(1, speeds.size())
	check(absf(mean - TradesShipJoints.WELD_SPEED_MM_S) < 15.0, "the travel speed it reports (%.0f mm/s)" % mean)

	# Too fast: nothing takes.
	_cut(station, rig, w)
	var fast := _weld_run(rig, station, w, TradesShipJoints.WELD_SPEED_MM_S * 6.0)
	check(fast < 0.0 and station.trace_progress(wf) < 0.2, "sweep it too fast and the bead doesn't take (%.2f)" % station.trace_progress(wf))
	station._traced.erase(wf.joint_id)
	station._dwell.erase(wf.joint_id)
	station._off.erase(wf.joint_id)

	# Too slow: lumpy, and it burns through where it lingers.
	got.clear()
	var slow := _weld_run(rig, station, w, TradesShipJoints.WELD_SPEED_MM_S / 4.0)
	check(slow >= 0.0 and slow < 0.5, "crawl along it and the weld comes out poor (%.2f)" % slow)
	check(got.size() == 1 and bool(got[0].measurements.burn_through), "and Quality hears it burned through")
	check(TradesShipJoints.bin_quality(1.0, 0.0) == 1.0 and TradesShipJoints.bin_quality(1.0, 50.0) < 0.6,
			"off the line the arc runs long and the bead is worse")

	bus.joint_completed.disconnect(on_done)
	yard.queue_free()
	await frames(1)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


## Runs the arc from one end of weld i to the other at `mm_s`; the quality it came out (-1 if
## it didn't finish).
func _weld_run(rig: TradesBay, station: TradesShipJoints, i: int, mm_s: float) -> float:
	var f := station.points[i]
	var at := station.points_world[i]
	var along := (station.ship_xform.basis * f.seam_up).normalized()
	var half := f.seam_size.x * 0.5
	rig.worker.face(at - along * half)
	station.update(0.0)
	station.press(&"welder")
	if not station.is_busy():
		return -1.0
	var s := -half
	var step := 1.0 / 60.0
	while s < half + 0.01 and station.is_busy():
		s += mm_s / 1000.0 * step
		rig.worker.face(at + along * minf(s, half))
		station.update(step)
	# Linger at the far end until it takes.
	var t := 0.0
	while station.is_busy() and t < 3.0:
		station.update(step)
		t += step
	station.release()
	return Modules.bus("ship_bay").joint_quality(f.joint_id) if station.is_tight(f) else -1.0


func _cut(station: TradesShipJoints, rig: TradesBay, i: int) -> void:
	_aim_at(rig, station, i)
	station.press(&"welder")
	_run(station, TradesShipJoints.UNWELD_S + 0.05)


func _undo_bolt(station: TradesShipJoints) -> void:
	station.press(&"torque_wrench")
	_run(station, TradesShipJoints.UNDO_S + 0.05)


func _run(station: TradesShipJoints, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		station.update(minf(0.05, left))
		left -= 0.05


func _first(station: TradesShipJoints, kind: String, tight: bool) -> int:
	for i in station.points.size():
		var f := station.points[i]
		if f.kind == kind and not TradesShipJoints.is_practice(f) and not station.is_rig(f) and station.is_tight(f) == tight:
			return i
	return -1


## A made weld on the ship along a seam of a usual length.
func _traced_weld(station: TradesShipJoints) -> int:
	for i in station.points.size():
		var f := station.points[i]
		if f.kind == "weld" and station.traces(f) and f.seam_size.x > 0.1 and f.seam_size.x < 0.3 \
				and not TradesShipJoints.is_practice(f) and station.is_tight(f):
			return i
	return -1


func _aim_at(rig: TradesBay, station: TradesShipJoints, i: int) -> void:
	var at := station.points_world[i]
	var n := station.ship_xform.basis * station.points[i].normal
	var out := Vector3(n.x, 0.0, n.z)
	if out.length() < 0.2:
		out = Vector3(at.x, 0.0, at.z) - Vector3(station.ship_xform.origin.x, 0.0, station.ship_xform.origin.z)
	var feet := at + out.normalized() * 0.9
	feet.y = 0.0
	rig.worker.global_position = feet
	rig.worker.face(at)
	station.update(0.0)


func _fake_yard() -> Node3D:
	var script := GDScript.new()
	script.source_code = FAKE_YARD
	script.reload()
	var yard := Node3D.new()
	yard.set_script(script)
	var walker := CharacterBody3D.new()
	walker.position = Vector3(3, 0, 6)
	yard.set("walker", walker)
	yard.add_child(walker)
	return yard
