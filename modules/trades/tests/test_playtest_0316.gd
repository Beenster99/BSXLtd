extends ModuleTest
## beenster's 0.3.16 playtest: the power wrench keeps the torque the player set (the wheel, its
## tip saying so), the welding shield comes down slowly on its own key and stays till lifted,
## only the rings near where you point are lit, and a part that falls on you never pins you.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
const FLAGS := ["trades.test_stand", "trades.power_wrench", "trades.trace_weld", "trades.weld_helmet",
		"trades.torque_kept", "trades.helmet_toggle", "trades.near_rings", "trades.weld_from_end",
		"trades.no_pinning"]


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

	# The torque is yours: the wheel sets it in fives (ones with Ctrl), and it stays put from
	# bolt to bolt.
	var bolts: Array[int] = []
	for i in station.points.size():
		if TradesShipJoints.is_practice(station.points[i]) and station.points[i].kind == "bolt":
			bolts.append(i)
	check(bolts.size() >= 2, "two bolts on the stand")
	rig.set_tool(&"torque_wrench")
	var wrench := rig.tool_node(&"torque_wrench") as TradesPowerWrench
	_aim_at(rig, station, bolts[0])
	wrench.set_nm = 30.0
	rig.wheel(-1)
	rig.wheel(-1)
	check(is_equal_approx(wrench.set_nm, 40.0), "two notches up: 40 N m (%.0f)" % wrench.set_nm)
	check(is_equal_approx(TradesPowerWrench.kept_nm, 40.0), "and the wrench remembers it")
	var tips := " ".join(rig.context_tips())
	check(tips.contains("set the torque") and tips.contains("40"), "the tip says the wheel sets it: %s" % tips)
	_aim_at(rig, station, bolts[bolts.size() - 1])
	check(is_equal_approx(wrench.set_nm, 40.0), "aiming at another bolt leaves it alone (%.0f)" % wrench.set_nm)
	tips = " ".join(rig.context_tips())
	check(tips.contains("set the torque"), "a tight bolt still shows how to set it: %s" % tips)

	# The shield: its key drops it, slowly, and it stays down till the key lifts it.
	rig.set_tool(&"welder")
	check(not rig.helmet_lowered and rig.helmet_down() == 0.0, "the shield starts up")
	rig._on_action(TradesBus.KEY_HELMET)
	check(rig.helmet_lowered, "its key drops it")
	_helmet(rig, 0.2)
	var part := rig.helmet_down()
	check(part > 0.2 and part < 0.7, "slowly: part way after a fifth of a second (%.2f)" % part)
	_helmet(rig, 0.5)
	check(rig.helmet_down() == 1.0, "and down in half a second more")
	_helmet(rig, 2.0)
	check(rig.helmet_down() == 1.0, "it stays down with no arc")
	var w := -1
	for i in station.points.size():
		if TradesShipJoints.is_practice(station.points[i]) and station.points[i].kind == "weld":
			w = i
			break
	_aim_at(rig, station, w)
	tips = " ".join(rig.context_tips())
	check(tips.contains("lift the shield"), "the welder's tips name its key: %s" % tips)
	rig._on_action(TradesBus.KEY_HELMET)
	_helmet(rig, 1.0)
	check(not rig.helmet_lowered and rig.helmet_down() == 0.0, "the key lifts it again")
	# Strike with it up and it comes down anyway.
	var torch := rig.tool_node(&"welder") as TradesWeldTorch
	torch.lit = true
	_helmet(rig, 0.05)
	torch.lit = false
	check(rig.helmet_lowered, "striking with it up drops it")
	rig.helmet_lowered = false
	_helmet(rig, 1.0)

	# Rings: only those near where you point. Looking at the stand its rings show; looking
	# away at the far floor they don't, though the heads stay.
	var stand := station.test_stand
	_aim_at(rig, station, bolts[0])
	station.update(0.0)
	stand._show()
	var ring := stand._markers[station.points[bolts[0]].joint_id] as MeshInstance3D
	check(ring.transparency == 0.0, "the ring you look at is lit")
	var away := rig.worker.global_position - station.points_world[bolts[0]]
	away.y = 0.0
	rig.worker.face(rig.worker.global_position + away.normalized() * 6.0 + Vector3(0, -1.0, 0))
	station.update(0.0)
	stand._show()
	var far := station.pointer_point()
	check(far.distance_to(station.points_world[bolts[0]]) > TradesShipJoints.NEAR_RINGS_M, "pointing away (%.1f m off)" % far.distance_to(station.points_world[bolts[0]]))
	var lit := 0
	for id: String in stand._markers:
		lit += 1 if (stand._markers[id] as MeshInstance3D).transparency == 0.0 else 0
	check(lit == 0, "no stand rings are lit (%d)" % lit)
	Flags.set_flag("trades.near_rings", false)
	station.update(0.0)
	stand._show()
	check(ring.transparency == 0.0, "flag off: every ring shows")

	# A part that falls on you is pushed off, or drops through you: you're never pinned.
	var someone := CharacterBody3D.new()
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	body_shape.shape = capsule
	body_shape.position.y = 0.9
	someone.add_child(body_shape)
	yard.add_child(someone)
	someone.global_position = Vector3(-20, 0, -20)
	var slot := MountSlot.new()
	slot.slot_id = "test_roof_unit"
	slot.box = AABB(Vector3(-0.6, 0, -0.6), Vector3(1.2, 0.5, 1.2))
	var unit := TradesLoosePart.new()
	unit.setup(slot, "test_unit", null)
	yard.add_child(unit)
	unit.global_position = Vector3(-20, 2.2, -20)
	unit.drop()
	for k in 3 * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
	var on_top := absf(unit.centre().x - someone.global_position.x) < 0.5 and absf(unit.centre().z - someone.global_position.z) < 0.5 and unit.centre().y > 1.0
	check(not on_top, "a unit dropped on someone doesn't stay on them (at %s)" % unit.centre())
	check(unit.centre().y < 1.0 or unit.lets_through(someone), "it's on the floor or passing through them")
	unit.queue_free()
	someone.queue_free()

	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])
	TradesPowerWrench.kept_nm = -1.0
	yard.queue_free()
	await frames(1)


func _helmet(rig: TradesBay, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		rig.update_helmet(minf(0.05, left))
		left -= 0.05


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
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 0.2, 80)
	floor_shape.shape = box
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)
	yard.add_child(floor_body)
	return yard
