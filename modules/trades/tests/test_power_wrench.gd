extends ModuleTest
## The powered wrench on the ship (beenster, 0.3.7): the wheel sets its torque on its display,
## the trigger runs the bolt in to the clutch, held on too long strips the thread, X puts it
## in undo, a stall wants the trigger let go and pulled again, the bolt's spec is on the
## wrist's Specs channel, and Quality gets the readings.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var saved := {}
	for flag: String in ["trades.power_wrench", "trades.specs"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	ship_bus.load_ship("vs_kestrel")
	var yard := _fake_yard()
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var station := rig.ship_station()
	var wrench := rig.tool_node(&"torque_wrench") as TradesPowerWrench
	check(wrench != null and TradesBay.label_of(&"torque_wrench") == "Power wrench", "the wrench is the powered one")

	var i := _first(station, "bolt")
	var f := station.points[i]
	var spec := TradesShipJoints.torque_range(f.spec)
	var target := TradesShipJoints.torque_target(f.spec)
	_aim_at(rig, station, i)
	rig.set_tool(&"torque_wrench")
	check(station.aimed == i and ship_bus.is_joint_tight(f.joint_id), "aimed at a tight bolt")

	# Undo mode takes it out.
	check(not wrench.undo, "it starts in fasten")
	station.press(&"torque_wrench")
	check(not station.is_busy(), "fasten on a tight bolt does nothing")
	rig._on_action(TradesBus.KEY_MODE)
	check(wrench.undo, "%s switches it to undo" % Keys.key_name(TradesBus.KEY_MODE))
	station.press(&"torque_wrench")
	_run(station, TradesShipJoints.BREAK_S + 0.05)
	check(not ship_bus.is_joint_tight(f.joint_id), "undo runs the bolt out")
	rig._on_action(TradesBus.KEY_MODE)

	# The wheel sets the torque on its display.
	wrench.set_nm = 20.0
	rig.wheel(-1)
	check(is_equal_approx(wrench.set_nm, 21.0), "wheel up on a bolt sets the torque up a newton metre")
	check(rig.tool == &"torque_wrench", "and doesn't change the tool")
	check(wrench.display_text().contains("21 N m") or wrench.readout_text().contains("21"), "the setting is on its display")

	# Set right, run it in and let go at the clutch: a good bolt, and Quality hears.
	wrench.set_nm = target
	var got: Array = []
	var on_done := func(r: JointResult) -> void: got.append(r)
	bus.joint_completed.connect(on_done)
	station._stall_at = -1.0
	station.press(&"torque_wrench")
	station._stall_at = -1.0
	_run(station, TradesShipJoints.RUN_S * 0.5)
	check(wrench.state == TradesPowerWrench.State.RUNNING and wrench.applied_nm > 0.0 and wrench.applied_nm < target,
			"running: the torque climbs (%.0f N m)" % wrench.applied_nm)
	_run(station, TradesShipJoints.RUN_S * 0.6)
	check(wrench.state == TradesPowerWrench.State.CLUTCH, "at the setting the clutch slips")
	station.release()
	check(ship_bus.is_joint_tight(f.joint_id) and ship_bus.joint_quality(f.joint_id) > 0.95, "let go: tight, at the spec")
	check(got.size() == 1 and got[0].trade == &"BOLT" and is_equal_approx(float(got[0].measurements.torque_nm[0]), target)
			and float(got[0].measurements.torque_target_nm) == target, "Quality gets the torque and the target")

	# Set too high: in, but marked down.
	_undo(rig, station)
	wrench.set_nm = spec.y * 1.5
	_fasten(station)
	station.release()
	check(ship_bus.is_joint_tight(f.joint_id) and ship_bus.joint_quality(f.joint_id) < 0.8,
			"set too high: in, but poor (%.2f)" % ship_bus.joint_quality(f.joint_id))

	# Held on past the clutch: the thread strips.
	_undo(rig, station)
	wrench.set_nm = target
	got.clear()
	_fasten(station)
	_run(station, TradesShipJoints.STRIP_S + 0.05)
	check(wrench.state == TradesPowerWrench.State.STRIPPED and not station.is_busy(), "held on too long: the thread strips")
	check(ship_bus.joint_quality(f.joint_id) < 0.2 and got.size() == 1 and bool(got[0].measurements.stripped_thread[0]),
			"a stripped thread is poor and Quality is told")

	# Let go before the clutch: not tight.
	_undo(rig, station)
	station.press(&"torque_wrench")
	station._stall_at = -1.0
	_run(station, TradesShipJoints.RUN_S * 0.3)
	station.release()
	check(not ship_bus.is_joint_tight(f.joint_id), "let go before the clutch: not tight")

	# A stall: it stops; let go and pull again.
	station.press(&"torque_wrench")
	station._stall_at = 0.1
	_run(station, 0.3)
	check(wrench.state == TradesPowerWrench.State.STALLED, "now and then it stalls")
	var stuck := wrench.applied_nm
	_run(station, 2.0)
	check(wrench.applied_nm == stuck and not ship_bus.is_joint_tight(f.joint_id), "stalled, holding on does nothing")
	station.release()
	_fasten(station)
	station.release()
	check(ship_bus.is_joint_tight(f.joint_id), "let go and pull again: it runs")

	# The tips and the wrist's Specs channel.
	var tips := "\n".join(rig.context_tips())
	check(tips.contains("switch to undo"), "on a tight bolt the tips offer undo: %s" % tips.replace("\n", " | "))
	check(not HudSlots.holo_channel(TradesBus.SPECS_CHANNEL).is_empty(), "the wrist screen has a Specs channel")
	var screen := TradesSpecsScreen.new(true)
	yard.add_child(screen)
	var text := _texts(screen)
	check(text.contains(f.spec) and text.contains("%d-%d N m" % [roundi(spec.x), roundi(spec.y)]),
			"it lists the bolt's torque window")
	screen.queue_free()

	bus.joint_completed.disconnect(on_done)
	yard.queue_free()
	await frames(1)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func _run(station: TradesShipJoints, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		station.update(minf(0.05, left))
		left -= 0.05


## Run it in to the clutch with no stall.
func _fasten(station: TradesShipJoints) -> void:
	station.press(&"torque_wrench")
	station._stall_at = -1.0
	_run(station, TradesShipJoints.RUN_S + 0.05)


func _undo(rig: TradesBay, station: TradesShipJoints) -> void:
	var w := rig.tool_node(&"torque_wrench") as TradesPowerWrench
	w.undo = true
	station.press(&"torque_wrench")
	station._stall_at = -1.0
	_run(station, TradesShipJoints.BREAK_S + 0.05)
	w.undo = false


func _texts(node: Node) -> String:
	var out := PackedStringArray()
	for l in node.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return "\n".join(out)


func _first(station: TradesShipJoints, kind: String) -> int:
	for i in station.points.size():
		if station.points[i].kind == kind:
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
