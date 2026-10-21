extends ModuleTest
## Ship and Bay's clean-up (ship_bay.clean_up, beenster 0.3.8): a part that comes off falls and
## lies where it lands, Ship and Bay hears of it (note_loose) with its condition, which hard
## landings knock down; letting go of the beam throws it; taking it, or seating it, forgets it;
## a clean-up trolley claiming it draws it on as before. Ship and Bay's calls are played by a
## stand-in (TradesTractor.trolley_api), so this checks the Tools side only.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
const FAKE_YARD_BUS := """extends RefCounted
var asked: Array = []
var noted := {}
var forgot: Array = []
func beam_to_trolley(slot_id: String, component: String, condition: float, from: Vector3) -> String:
	asked.append(slot_id)
	return "m"
func cancel_beam(slot_id: String) -> void:
	pass
func trolley_deck_position(id: String) -> Variant:
	return Vector3(6, 1.0, 4)
func fitted_condition(slot_id: String) -> float:
	return 0.8
func note_loose(slot_id: String, component: String, condition: float, body: Node3D) -> void:
	noted[slot_id] = [component, condition, body]
func forget_loose(slot_id: String) -> void:
	forgot.append(slot_id)
	noted.erase(slot_id)
"""
const SLOT := "net_hold_dor_1"


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var saved := {}
	for flag: String in ["trades.tractor", "ship_bay.clean_up"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	ship_bus.load_ship("vs_kestrel")
	var yard := _make(FAKE_YARD, Node3D.new()) as Node3D
	var walker := CharacterBody3D.new()
	walker.position = Vector3(3, 0, 12)
	yard.set("walker", walker)
	yard.add_child(walker)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(80, 0.2, 80)
	floor_shape.shape = slab
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)
	yard.add_child(floor_body)
	add_child(yard)
	(Modules.bus("trades") as TradesBus)._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var station := rig.ship_station()
	var beam := station.tractor
	var api: Object = _make(FAKE_YARD_BUS, RefCounted.new())
	beam.trolley_api = api
	rig.set_tool(&"tractor")
	check(beam.clean_up(), "the clean-up is on")

	# Every joint off: no trolley; it falls, and Ship and Bay hears of it.
	for f in ship_bus.get_fasteners(SLOT):
		ship_bus.note_joint_removed(f.joint_id)
	var part: TradesLoosePart = beam.loose.get(SLOT)
	var noted: Dictionary = api.get("noted")
	check(part != null and (api.get("asked") as Array).is_empty(), "no trolley comes for it on its own")
	check(noted.has(SLOT) and noted[SLOT][2] == part and is_equal_approx(float(noted[SLOT][1]), 0.8),
			"Ship and Bay hears it's loose, at its fitted condition")
	check(not part.freeze, "it falls")

	# Hard landings knock it down, and Ship and Bay hears the new figure.
	part.knock(2.0)
	check(is_equal_approx(part.condition, 0.8), "a gentle bump does nothing")
	part.knock(9.0)
	check(part.condition < 0.8 and is_equal_approx(float(noted[SLOT][1]), part.condition),
			"a hard landing knocks it down (%.2f) and Ship and Bay is told" % part.condition)

	# Taken by the beam: forgotten. Let go while swinging it: thrown, and loose again.
	var stand := part.centre() + Vector3(0, 0, 2.4)
	stand.y = 0.0
	rig.worker.global_position = stand
	rig.worker.face(part.centre())
	station.press(&"tractor")
	check(beam.held == part and not noted.has(SLOT) and (api.get("forgot") as Array).has(SLOT), "taken by your beam: forgotten")
	for i in 5:
		rig.worker.rotate_y(0.08)
		station.update(0.05)
	station.release()
	check(part.linear_velocity.length() > 0.5, "let go while swinging: it's thrown (%.1f m/s)" % part.linear_velocity.length())
	check(noted.has(SLOT), "and it's loose again")

	# A clean-up trolley claims it: the yard beam draws it on, and on the deck it goes.
	beam._on_clean_up_claimed(SLOT, "m")
	station.update(0.05)
	check(beam.to_trolley.get(SLOT) == "m" and beam._yard_beams.has(SLOT), "a clean-up trolley claims it and beams it on")
	beam._on_part_beamed("crate_1", "m", part.component, SLOT)
	await frames(1)
	check(not beam.loose.has(SLOT) and not noted.has(SLOT), "on the deck: the copy goes and it's forgotten")

	yard.queue_free()
	await frames(1)
	ship_bus.load_ship("vs_kestrel")
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func _make(source: String, obj: Object) -> Object:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	obj.set_script(script)
	return obj
