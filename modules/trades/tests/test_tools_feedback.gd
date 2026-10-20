extends ModuleTest
## beenster's tool feedback in the yard: ball hands, the tool panel's labelled readings,
## holding Tab for a part's key data, holding the rotate key to turn a part in the beam,
## and the welder cutting a weld out (unweld) when the ship has one.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
const SLOT := "eng_aft_port_1"


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var saved := {}
	for flag: String in ["trades.tractor", "trades.sphere_hands", "trades.tool_panel", "trades.inspect", "trades.unweld"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	ship_bus.load_ship("vs_kestrel")
	var yard := _fake_yard()
	add_child(yard)
	(Modules.bus("trades") as TradesBus)._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var station := rig.ship_station()

	# Ball hands.
	var glove := rig.worker.right_hand.get_node("Glove")
	check(glove.has_node("Ball") and glove.get_child_count() == 2, "the hands are balls for now")

	# The tool panel: the tool's name, its readings by name, what it's doing.
	rig.set_tool(&"torque_wrench")
	await frames(1)
	var panel := rig.tool_panel_text()
	check(panel.contains("TORQUE WRENCH") and panel.contains("SET") and panel.contains("N m") and panel.contains("READY"),
			"the tool panel names the tool and labels its readings")
	rig.set_tool(&"welder")
	await frames(1)
	check(rig.tool_panel_text().contains("CURRENT") and rig.tool_panel_text().contains("WELD"), "the welder's panel shows its current and mode")

	# Hold Tab on a part on the ship: its key data.
	var slot := ship_bus.get_slot(SLOT)
	var home := station.ship_xform * slot.mount
	var f := slot.fasteners[0]
	_stand_off(rig, station.ship_xform * f.position, home.basis.z)
	_run(station, 1)
	check(station.aimed >= 0, "aiming at one of the engine's joints")
	check(rig.inspect_text() == "", "the details stay hidden until Tab is held")
	Input.action_press(TradesBus.KEY_INSPECT)
	await frames(1)
	var info := rig.inspect_text()
	Input.action_release(TradesBus.KEY_INSPECT)
	check(info.contains(SLOT) and info.contains("JOINTS") and info.contains("MASS") and info.contains("FITTED"),
			"holding Tab shows the part's slot, state, mass and joints")
	check(info.contains("JOINT ") and info.contains(f.spec), "and the joint you're looking at")
	await frames(1)
	check(rig.inspect_text() == "", "let go of Tab: it hides again")

	# Hold the rotate key in the beam: the mouse turns the part instead of the view.
	for g in ship_bus.get_fasteners(SLOT):
		ship_bus.note_joint_removed(g.joint_id)
	var part: TradesLoosePart = station.tractor.loose.get(SLOT)
	_stand_off(rig, part.centre(), home.basis.z)
	rig.set_tool(&"tractor")
	station.press(&"tractor")
	check(station.tractor.held == part, "the beam takes the engine")
	rig.worker.global_position += home.basis.z * 1.5
	_run(station, 30)
	var yaw := part.global_rotation.y
	var view := rig.worker.global_rotation.y
	check(not station.motion(Vector2(60, 0)), "without the rotate key the mouse looks about")
	Input.action_press(TradesBus.KEY_ROTATE)
	check(station.motion(Vector2(120, 0)), "holding the rotate key, the mouse turns the part")
	_run(station, 40)
	check(absf(angle_difference(part.global_rotation.y, yaw)) > deg_to_rad(20.0), "sideways turns it round")
	var up := part.global_basis.y
	station.motion(Vector2(0, 100))
	_run(station, 40)
	Input.action_release(TradesBus.KEY_ROTATE)
	check(up.angle_to(part.global_basis.y) > deg_to_rad(15.0), "up and down tips it")
	check(is_equal_approx(rig.worker.global_rotation.y, view), "and the view stays put")
	station.release()

	# Unweld: right click with the welder cuts a tight weld out.
	var weld := -1
	for i in station.points.size():
		if station.points[i].kind == "weld" and ship_bus.is_joint_tight(station.points[i].joint_id):
			weld = i
			break
	if weld >= 0:
		var w := station.points[weld]
		_stand_off(rig, station.points_world[weld], station.ship_xform.basis * w.normal)
		_run(station, 1)
		rig.set_tool(&"welder")
		station.back_out(&"welder")
		_run(station, 10)
		await frames(1)
		var torch := rig.tool_node(&"welder") as TradesWeldTorch
		check(torch.lit and torch.cutting and rig.tool_panel_text().contains("CUT"), "right click on a weld: the welder cuts")
		_run(station, 60)
		check(not ship_bus.is_joint_tight(w.joint_id), "the weld is cut out")
	else:
		print("  (the Kestrel has no welds yet: unweld checked on the torch only)")
		rig.set_tool(&"welder")
		var torch := rig.tool_node(&"welder") as TradesWeldTorch
		torch.lit = true
		torch.cutting = true
		torch.cut = 0.5
		await frames(1)
		check(rig.tool_panel_text().contains("CUT") and rig.tool_panel_text().contains("50 %"), "cutting, the welder's panel shows the cut")
		torch.lit = false
		torch.cutting = false

	yard.queue_free()
	await frames(1)
	ship_bus.load_ship("vs_kestrel")
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func _run(station: TradesShipJoints, n: int) -> void:
	for i in n:
		station.update(0.05)


func _stand_off(rig: TradesBay, at: Vector3, out: Vector3) -> void:
	var flat := Vector3(out.x, 0, out.z)
	flat = flat.normalized() if flat.length() > 0.1 else Vector3(0, 0, 1)
	var feet := at + flat * 1.6
	feet.y = 0.0
	rig.worker.global_position = feet
	rig.worker.face(at)


func _fake_yard() -> Node3D:
	var script := GDScript.new()
	script.source_code = FAKE_YARD
	script.reload()
	var yard := Node3D.new()
	yard.set_script(script)
	var walker := CharacterBody3D.new()
	walker.position = Vector3(3, 0, 12)
	yard.set("walker", walker)
	yard.add_child(walker)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 0.2, 80)
	floor_shape.shape = box
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)
	yard.add_child(floor_body)
	return yard
