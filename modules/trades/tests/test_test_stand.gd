extends ModuleTest
## The tool test stand in the yard (beenster, 22 Oct: "add a few parts somewhere in the yard
## so that I can try the tools out"): every kind of joint, worked like the ship's, kept by
## Tools as practice and never sent to Ship and Bay or Quality.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
const FLAGS := ["trades.test_stand", "trades.power_wrench", "trades.wire_diagram", "trades.power_riveter",
		"trades.rivet_heat", "trades.slim_hotbar"]


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
	var stand := station.test_stand
	check(stand != null and stand.is_inside_tree(), "the test stand is up in the yard")
	var spot := ship_bus.shipyard_spot(TradesBay.TEST_STAND_SPOT).origin
	check(stand.global_position.distance_to(spot) < 0.01, "at Ship and Bay's Pre-assembly spot")
	var kinds := {}
	for f in stand.joints:
		kinds[f.kind] = true
	check(kinds.size() == 4 and stand.joints.size() >= 20, "every kind of joint on it (%d joints)" % stand.joints.size())
	var first := station.points.size() - stand.joints.size()
	check(station.points.slice(first).all(func(f: FastenerPoint) -> bool: return TradesShipJoints.is_practice(f))
			and not station.points.slice(0, first).any(func(f: FastenerPoint) -> bool: return TradesShipJoints.is_practice(f)),
			"its joints come after the ship's")
	var world := station.points_world[first]
	check(world.distance_to(stand.global_transform * stand.joints[0].position) < 0.001, "and sit where the stand draws them")
	check(station.status_line().begins_with("Ship: %d joints" % first), "the ship's count leaves the stand out")
	var reported: Array = []
	bus.joint_completed.connect(func(r: JointResult) -> void: reported.append(r))

	# A loose M10 bolt: run it in with the power wrench.
	var b := _first(station, "bolt", false)
	_aim_at(rig, station, b)
	rig.set_tool(&"torque_wrench")
	check(station.aimed == b, "aim picks a stand bolt")
	station._stall_at = -1.0
	station.press(&"torque_wrench")
	station._stall_at = -1.0
	_run(station, TradesShipJoints.RUN_S * 1.2)
	station.release()
	check(station.is_tight(station.points[b]), "the bolt runs in")
	check(not ship_bus.is_joint_tight(station.points[b].joint_id), "Ship and Bay never hears of it")
	check(reported.is_empty(), "nor does Quality")
	check(rig._hint_label.text.contains("in at"), "the hint says how tight: %s" % rig._hint_label.text)

	# The slim hotbar (beenster, 22 Oct): no drill, crimper or cutter.
	check(not rig.hotbar.has(&"drill") and not rig.hotbar.has(&"wire_tool") and not rig.hotbar.has(&"cutter")
			and rig.hotbar.has(&"welder") and rig.hotbar.has(&"hands"), "no drill, crimper or cutter on the hotbar")

	# A set rivet: heat it out with the welder.
	var r := _first(station, "rivet", true)
	_aim_at(rig, station, r)
	check(station.kind_tools("rivet") == [&"rivet_squeezer", &"welder"], "rivets: the rivet gun sets them, the welder takes them out")
	check(station.kind_help("rivet").contains("welder (%s) to take out" % rig.tool_key(&"welder")), "the help names the welder and its key")
	rig.set_tool(&"welder")
	station.press(&"welder")
	_run(station, TradesShipJoints.HEAT_S + 0.2)
	check(not station.is_tight(station.points[r]), "a stand rivet heats out")

	# The open weld seam: lay a bead.
	var w := _first(station, "weld", false)
	_aim_at(rig, station, w)
	rig.set_tool(&"welder")
	(rig.tool_node(&"welder") as TradesWeldTorch).unweld = false
	station.press(&"welder")
	_run(station, TradesShipJoints.WELD_S + 0.1)
	check(station.is_tight(station.points[w]), "a bead welds the open seam")

	# The fuel plug pushes home; the power plug opens the wiring tool.
	var fuel := _find(station, "fuel")
	_aim_at(rig, station, fuel)
	rig.set_tool(&"hands")
	station.press(&"hands")
	_run(station, TradesShipJoints.PLUG_S + 0.1)
	check(station.is_tight(station.points[fuel]), "the fuel plug pushes home")
	var power := _find(station, "power")
	_aim_at(rig, station, power)
	station.press(&"hands")
	check(station.wiring != null and station.wiring.title.contains("TEST PANEL"), "the power plug opens its wiring diagram")
	station.close_wiring()
	await frames(2)

	# Tab and the spec sheet: the stand's own sheet.
	_aim_at(rig, station, b)
	var lines := station.inspect_lines()
	check(lines.size() > 3 and lines[0] == "TOOL TEST STAND", "Tab shows the stand's sheet")
	check(station.aim_spec(&"torque_wrench").contains("Holds Test panel"), "the look card names the panel")
	check(station.aim_spec(&"torque_wrench").contains("of %d joints in" % stand.joints.size()),
			"and the part's key details, with no Tab sheet: %s" % station.aim_spec(&"torque_wrench"))
	check(reported.is_empty(), "still nothing sent to Quality")
	var marker := stand._markers[station.points[b].joint_id] as MeshInstance3D
	check((marker.get_child(0) as Node3D).visible, "a made joint shows its head on the stand")

	yard.queue_free()
	await frames(1)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func _run(station: TradesShipJoints, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		station.update(minf(0.05, left))
		left -= 0.05


func _first(station: TradesShipJoints, kind: String, made: bool) -> int:
	for i in station.points.size():
		var f := station.points[i]
		if TradesShipJoints.is_practice(f) and f.kind == kind and station.is_tight(f) == made:
			return i
	return -1


func _find(station: TradesShipJoints, spec: String) -> int:
	for i in station.points.size():
		if TradesShipJoints.is_practice(station.points[i]) and station.points[i].spec == spec:
			return i
	return -1


func _aim_at(rig: TradesBay, station: TradesShipJoints, i: int) -> void:
	var at := station.points_world[i]
	var n := (station.ship_xform.basis * station.points[i].normal).normalized()
	var feet := at + Vector3(n.x, 0.0, n.z).normalized() * 0.8
	feet.y = station.test_stand.global_position.y
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
