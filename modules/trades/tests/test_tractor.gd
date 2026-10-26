extends ModuleTest
## The tractor beam in the yard: a part held on by its joints won't lift; one that has come
## off lifts, follows the beam, is pushed out by the wheel, turns with Q/E, parks in the air,
## drops when let go away from its mount, and seats in its mount (Ship and Bay hears) when
## let go in line with it.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
const SLOT := "eng_port"


func run_tests() -> void:
	var bus := Modules.bus("trades") as TradesBus
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var had_flag := Flags.is_on("trades.tractor")
	Flags.set_flag("trades.tractor", true)
	# Parts here hover where they came off; Ship and Bay's clean-up drops them
	# (test_tractor_clean_up.gd).
	var had_clean_up := Flags.is_on("ship_bay.clean_up")
	Flags.set_flag("ship_bay.clean_up", false)
	ship_bus.load_ship("vs_kestrel")
	var yard := _fake_yard()
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var station := rig.ship_station()
	var beam := station.tractor
	var at := rig.hotbar.find(&"tractor")
	check(at >= 0 and at == rig.hotbar.size() - (2 if rig.hotbar.has(&"cutter") else 1),
			"the tractor beam is on the hotbar after the hand tools (tool %d)" % (at + 1))
	rig.set_tool(&"tractor")
	var slot := ship_bus.get_slot(SLOT)
	var home := station.ship_xform * slot.mount

	# Still bolted on: it won't lift.
	_stand_off(rig, home * slot.mount.affine_inverse() * slot.box.get_center(), home.basis.z)
	check(beam.aimed_slot() == SLOT, "the beam finds the engine on the ship")
	station.press(&"tractor")
	check(not beam.is_holding(), "a part still held by its joints won't lift")

	# Every joint off: it sits loose on its mount, and the beam takes it.
	for f in ship_bus.get_fasteners(SLOT):
		ship_bus.note_joint_removed(f.joint_id)
	check(ship_bus.get_slot_state(SLOT) == ShipBayBus.SlotState.EMPTY, "all its joints off: the part is free")
	var part: TradesLoosePart = beam.loose.get(SLOT)
	check(part != null and part.global_transform.origin.distance_to(home.origin) < 0.001 and part.anchored,
			"it sits loose where it was, not falling")
	_stand_off(rig, part.centre(), home.basis.z)
	var stood := rig.worker.global_transform
	check(beam.aimed_part() == part, "aiming at it picks it")
	station.press(&"tractor")
	check(beam.is_holding() and station.is_busy(), "left click: the beam has it")
	check(station.tools() == [&"tractor"], "while it holds, the hotbar shows only the beam")

	# Walk back with it: it follows.
	rig.worker.global_position += home.basis.z * 1.5
	_run(station, 30)
	check(part.global_position.distance_to(home.origin) > 1.0, "it follows the beam away from the ship")
	check(not beam.aligned, "away from its mount it isn't in line")
	# The line (beenster, 0.3.14): fine and flowing, it bends behind a quick swing and settles.
	var line := beam._beam as TradesBeamLine
	check(line.visible and TradesBeamLine.CORE_W < 0.01, "a fine line joins the tool to the part")
	rig.worker.rotate_y(0.5)
	_run(station, 2)
	check(beam.beam_bend() > 0.01, "a quick swing bends it (%.3f m)" % beam.beam_bend())
	rig.worker.rotate_y(-0.5)
	_run(station, 90)
	check(beam.beam_bend() < 0.005, "and it settles straight (%.3f m)" % beam.beam_bend())
	var before := part.global_position.distance_to(rig.worker.aim_origin())
	# Wheel up (-1) pushes it away (trades.wheel_away, beenster 0.3.20).
	var away := -1 if Flags.is_on("trades.wheel_away") else 1
	station.turn_held(away, false)
	station.turn_held(away, false)
	_run(station, 30)
	check(part.global_position.distance_to(rig.worker.aim_origin()) > before + 0.15, "the wheel pushes it out")
	# The wheel itself, button up (beenster, 0.3.14): it pulls the part in, not a tool change.
	var out := part.global_position.distance_to(rig.worker.aim_origin())
	rig.wheel(-away)
	rig.wheel(-away)
	_run(station, 30)
	check(rig.tool == &"tractor" and part.global_position.distance_to(rig.worker.aim_origin()) < out - 0.15,
			"the mouse wheel pulls it back in while the beam holds it")
	var yaw := part.global_rotation.y
	station.adjust(1)
	_run(station, 30)
	check(absf(angle_difference(part.global_rotation.y, yaw)) > deg_to_rad(10.0), "E turns it")
	station.adjust(-1)

	# Park it in the air, take it again.
	station.back_out(&"tractor")
	check(not beam.is_holding() and part.anchored and part.freeze, "right click parks it hovering")
	_stand_off(rig, part.centre(), home.basis.z)
	station.press(&"tractor")
	check(beam.held == part, "left click takes it again")

	# Back to where it came off: the beam draws it into line, and it seats.
	station.release()
	part.global_transform = home
	part.anchor()
	_stand_off(rig, part.centre(), home.basis.z)
	station.press(&"tractor")
	rig.worker.global_position += Vector3(0.1, 0, 0.05)
	_run(station, 60)
	check(beam.aligned, "near its mount the beam draws it into line")
	check(ship_bus.get_slot_state(SLOT) == ShipBayBus.SlotState.POSITIONED and part.seated and not part.visible,
			"in line it seats in its mount while the beam holds it")
	var net: Node = Modules.bus("multiplayer")
	var unit := TradesTractor.unit_id(SLOT)
	if net:
		check(net.call("is_hold_ready", unit), "Multiplayer hears the hold is in line")
	station.release()
	check(ship_bus.get_slot_state(SLOT) == ShipBayBus.SlotState.POSITIONED and not beam.is_holding(),
			"let go in line: it stays locked in its mount")
	if net:
		check((net.call("hold_info", unit) as Dictionary).get("locked", false), "the hold is locked (the solo way)")

	# Locked with nothing fastened: the beam lifts it straight back off, and away it drops.
	_stand_off(rig, part.centre(), home.basis.z)
	station.press(&"tractor")
	check(beam.held == part, "the beam takes a locked part again")
	rig.worker.global_position += home.basis.z * 1.5
	_run(station, 30)
	check(ship_bus.get_slot_state(SLOT) == ShipBayBus.SlotState.EMPTY and part.visible,
			"out of line before any joint is in: it comes back off")
	station.release()
	check(not part.freeze and not part.held, "let go away from its mount: it drops")
	await frames(1)
	var dropped := part.global_position
	station.press(&"hands")
	check(ship_bus.get_slot_state(SLOT) == ShipBayBus.SlotState.EMPTY, "hands can't put back a part that isn't at its mount")
	check(dropped.distance_to(home.origin) > 0.5, "it stays where it fell")

	# Held in line, the first joint goes in: the ship holds it, the beam lets go.
	part.global_transform = home
	part.anchor()
	_stand_off(rig, part.centre(), home.basis.z)
	station.press(&"tractor")
	_run(station, 30)
	check(part.seated, "seated in the beam again")
	ship_bus.note_joint_made(ship_bus.get_fasteners(SLOT)[0].joint_id, 1.0)
	_run(station, 1)
	await frames(1)
	check(not beam.is_holding() and not beam.loose.has(SLOT), "the first joint in: the part is the ship's, the beam lets go")
	if net:
		check((net.call("hold_info", unit) as Dictionary).is_empty(), "and the hold ends")

	yard.queue_free()
	await frames(1)
	ship_bus.load_ship("vs_kestrel")
	Flags.set_flag("trades.tractor", had_flag)
	Flags.set_flag("ship_bay.clean_up", had_clean_up)


func _run(station: TradesShipJoints, n: int) -> void:
	for i in n:
		station.update(0.05)


## The worker standing `out` from a point (along the face's outward direction), looking at it.
func _stand_off(rig: TradesBay, at: Vector3, out: Vector3) -> void:
	var flat := Vector3(out.x, 0, out.z).normalized()
	var feet := at + flat * 2.4
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
