extends ModuleTest
## The powered rivet gun on the ship (beenster, 0.3.7): the wheel sets how far out the head
## stands, the trigger builds the air and punches the rivet in, the wrong setting is poor in
## the quality survey, the welder heats a rivet till it pops out, and the cutter grinds its
## head off, both throwing sparks.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
const FLAGS := ["trades.power_riveter", "trades.rivet_heat", "trades.cutter"]


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var saved := {}
	# The tools before trades.vs_tools (test_vs_tools has the reworked ones).
	for old: String in ["trades.vs_tools", "trades.weld_skill"]:
		saved[old] = Flags.is_on(old)
		Flags.set_flag(old, false)
	for flag: String in FLAGS:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	# The cutter is tested here, so the full hotbar.
	saved["trades.slim_hotbar"] = Flags.is_on("trades.slim_hotbar")
	Flags.set_flag("trades.slim_hotbar", false)
	ship_bus.load_ship("vs_kestrel")
	var yard := _fake_yard()
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var station := rig.ship_station()
	var gun := rig.tool_node(&"rivet_squeezer") as TradesRivetGun
	check(gun != null and TradesBay.label_of(&"rivet_squeezer") == "Rivet gun", "the squeezer is the powered rivet gun")
	check(rig.hotbar.has(&"cutter") and rig.tool_node(&"cutter") is TradesCutter, "the cutter is on the hotbar")

	var i := _first(station, "rivet")
	check(i >= 0, "the ship has rivets")
	if i < 0:
		return
	var f := station.points[i]
	var target := TradesShipJoints.head_target_mm(f.spec)
	_aim_at(rig, station, i)
	check(station.aimed == i and ship_bus.is_joint_tight(f.joint_id), "aimed at a set rivet")

	# The cutter grinds its head off, throwing sparks.
	rig.set_tool(&"cutter")
	station.press(&"cutter")
	_run(station, TradesShipJoints.grind_s() * 0.5)
	check(station.is_busy() and rig.sparks.count() > 0, "grinding: sparks fly (%d)" % rig.sparks.count())
	_run(station, TradesShipJoints.GRIND_S * 0.6)
	check(not ship_bus.is_joint_tight(f.joint_id), "the cutter grinds the rivet off")

	# The gun: the wheel sets the head height, the air builds, then it punches.
	rig.set_tool(&"rivet_squeezer")
	gun.set_mm = 1.0
	rig.wheel(-1)
	check(is_equal_approx(gun.set_mm, 1.1) and rig.tool == &"rivet_squeezer", "wheel up sets the head 0.1 mm higher")
	check(gun.readout_text().contains("1.1"), "the setting is on its display")
	gun.set_mm = target
	var got: Array = []
	var on_done := func(r: JointResult) -> void: got.append(r)
	bus.joint_completed.connect(on_done)
	station.press(&"rivet_squeezer")
	_run(station, TradesShipJoints.PRESS_S * 0.5)
	check(gun.pressure > 0.3 and gun.pressure < 1.0 and not ship_bus.is_joint_tight(f.joint_id), "the air builds")
	_run(station, TradesShipJoints.PRESS_S * 0.6)
	check(ship_bus.is_joint_tight(f.joint_id) and ship_bus.joint_quality(f.joint_id) > 0.95, "punched: set at the spec")
	check(got.size() == 1 and got[0].trade == &"RIVET" and is_equal_approx(float(got[0].measurements.head_height_mm[0]), target)
			and is_equal_approx(float(got[0].measurements.head_height_target_mm), target), "Quality gets the head height and the target")

	# The welder heats it till it pops out.
	rig.set_tool(&"welder")
	station.press(&"welder")
	_run(station, TradesShipJoints.HEAT_S + 0.1)
	check(not ship_bus.is_joint_tight(f.joint_id), "the welder heats the rivet out")
	check(rig.sparks._pops.size() > 0, "and it pops off")

	# The wrong setting: in, but poor.
	rig.set_tool(&"rivet_squeezer")
	gun.set_mm = target * 2.0
	station.press(&"rivet_squeezer")
	_run(station, TradesShipJoints.PRESS_S + 0.1)
	check(ship_bus.is_joint_tight(f.joint_id) and ship_bus.joint_quality(f.joint_id) < 0.7,
			"set too far out: in, but poor (%.2f)" % ship_bus.joint_quality(f.joint_id))

	# Let go before the punch: nothing set.
	rig.set_tool(&"drill")
	station.back_out(&"drill")
	_run(station, 3.0)
	rig.set_tool(&"rivet_squeezer")
	station.press(&"rivet_squeezer")
	_run(station, TradesShipJoints.PRESS_S * 0.4)
	station.release()
	check(not ship_bus.is_joint_tight(f.joint_id) and gun.pressure == 0.0, "let go before the punch: no rivet")

	var tips := "\n".join(rig.context_tips())
	check(tips.to_lower().contains("head"), "the tips say the wheel sets the head: %s" % tips.replace("\n", " | "))

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
