extends ModuleTest
## You in Ship and Bay's shipyard: no bench, the worker takes over from the yard's walker
## with every tool to hand, and the tools work on the ship's real joints, telling Ship and
## Bay about each one made or taken off.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""


func run_tests() -> void:
	var bus := Modules.bus("trades") as TradesBus
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var had_ship := ship_bus.ship != null
	ship_bus.load_ship("vs_kestrel")
	var script := GDScript.new()
	script.source_code = FAKE_YARD
	script.reload()
	var yard: Node3D = Node3D.new()
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
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)

	var rig: TradesBay = yard.get_node_or_null(TradesBus.YARD_RIG)
	check(rig != null and rig.in_yard, "the shipyard gets you, the worker with the tools")
	check(rig.find_children("*", "StaticBody3D", true, false).is_empty(), "no bench, no room: nothing built round you")
	check(not yard.get("walker_active") and rig.worker.camera.current, "the yard's walker stands down; your view is current")
	check(rig.worker.global_position.distance_to(Vector3(3, 0, 6)) < 0.3, "you start where the walker stood")
	var station := rig.ship_station()
	var expected := 0
	for slot in ship_bus.get_slots():
		expected += ship_bus.get_fasteners(slot.slot_id).size()
	check(station != null and station.points.size() == expected and expected > 0,
			"the ship is the station: all %d of its joints" % expected)
	rig.wheel(1)
	check(rig.tool == &"torque_wrench", "the mouse wheel moves along the tools")

	# A bolt: break it loose and torque it again.
	var bolt := _first(station, "bolt")
	_aim_at(rig, station, bolt)
	check(station.aimed == bolt, "aiming at a bolt picks it")
	# The tips say what the tool in hand does to it, with its keys (beenster, 0.3.7).
	rig.set_tool(&"hands")
	var tips := "\n".join(rig.context_tips())
	check(tips.contains("%s: take the torque wrench" % rig.tool_key(&"torque_wrench")),
			"the wrong tool in hand: the tips say which key takes up the right one (%s)" % tips.replace("\n", " | "))
	rig.set_tool(&"torque_wrench")
	tips = "\n".join(rig.context_tips())
	check(tips.contains(TradesBay.HOLD_RIGHT + ": break it loose") and tips.contains("part details"),
			"the wrench on a tight bolt: hold right click breaks it loose (%s)" % tips.replace("\n", " | "))
	var card := HudSlots.look_hint_for({"collider": null})
	check(str(card.get("title", "")).contains("bolt, tight"),
			"UI's look card gets Tools' hint for the aimed bolt: %s" % card.get("title", ""))
	check(not tips.contains(Keys.key_name(Keys.JUMP)) and not tips.contains("walk"), "no walking or jumping keys in the tips")
	check(station.status_line().contains("TIGHT"), "the HUD says it's tight")
	var id := station.points[bolt].joint_id
	rig.set_tool(&"hands")
	station.back_out(&"hands")
	check(not station.is_busy() and ship_bus.is_joint_tight(id), "hands can't break a bolt loose")
	rig.set_tool(&"torque_wrench")
	station.back_out(&"torque_wrench")
	station.update(TradesShipJoints.BREAK_S + 0.05)
	check(not ship_bus.is_joint_tight(id), "right click with the wrench breaks it loose (Ship and Bay hears)")
	check(ship_bus.get_slot_state(FastenerPoint.slot_of(id)) == ShipBayBus.SlotState.LOOSENED, "its part is now loosened")
	station.press(&"torque_wrench")
	var nm := TradesShipJoints.torque_range(station.points[bolt].spec)
	station.motion(Vector2(0, nm.x * 0.5 / TradesShipJoints.NM_PER_PX))
	station.update(0.016)
	check(not ship_bus.is_joint_tight(id), "half the torque: not yet")
	station.motion(Vector2(0, ((nm.x + nm.y) * 0.5 - nm.x * 0.5) / TradesShipJoints.NM_PER_PX + 1.0))
	station.update(0.016)
	check(ship_bus.is_joint_tight(id) and ship_bus.joint_quality(id) > 0.9, "pulled to the click: torqued, good quality")
	station.release()
	check(ship_bus.get_slot_state(FastenerPoint.slot_of(id)) == ShipBayBus.SlotState.FITTED, "every joint tight again: fitted")

	# A connector: unplug and plug by hand.
	var plug := _first(station, "connector")
	_aim_at(rig, station, plug)
	var plug_id := station.points[plug].joint_id
	rig.set_tool(&"welder")
	station.press(&"welder")
	check(not station.is_busy(), "the wrong tool does nothing to a plug")
	rig.set_tool(&"hands")
	station.back_out(&"hands")
	station.update(TradesShipJoints.PLUG_S + 0.05)
	check(not ship_bus.is_joint_tight(plug_id), "right click unplugs it")
	station.press(&"hands")
	station.update(TradesShipJoints.PLUG_S + 0.05)
	check(ship_bus.is_joint_tight(plug_id), "left click plugs it back in")

	# Every joint of a part off: the part is off; hands put it back.
	var slot_id := FastenerPoint.slot_of(plug_id)
	for f in ship_bus.get_fasteners(slot_id):
		if f.joint_id != plug_id:
			ship_bus.note_joint_removed(f.joint_id)
	_aim_at(rig, station, plug)
	station.back_out(&"hands")
	station.update(TradesShipJoints.PLUG_S + 0.05)
	check(ship_bus.get_slot_state(slot_id) == ShipBayBus.SlotState.EMPTY, "the last joint off frees the part")
	station.update(0.0)
	station.press(&"hands")
	check(ship_bus.get_slot_state(slot_id) == ShipBayBus.SlotState.POSITIONED, "hands on it put the part back in place")

	# Rivets on the roof are in reach of the stretchy arms from the floor beside the ship.
	var rivet := _first(station, "rivet")
	if rivet >= 0:
		var at := station.points_world[rivet]
		rig.worker.global_position = Vector3(at.x + signf(at.x) * 2.0 + 0.01, 0.0, at.z)
		await frames(1)
		check(rig.worker.right_hand.can_reach(at), "a roof rivet is in reach from the floor")

	yard.queue_free()
	await frames(1)
	if had_ship:
		ship_bus.load_ship("vs_kestrel")
	else:
		ship_bus.unload_ship()


func _first(station: TradesShipJoints, kind: String) -> int:
	for i in station.points.size():
		if station.points[i].kind == kind:
			return i
	return -1


## Stand the worker back from a joint, looking straight at it, and let the station pick.
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
