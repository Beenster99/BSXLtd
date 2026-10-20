extends ModuleTest
## Parts off the ship and the hover trolleys: a freed part stays (it never disappears) and a
## trolley is sent for it, with a yard beam to its deck; on the deck it is a crate and the
## copy goes. Taking it with your own beam calls the trolley off; dropping it sends for one
## again; with none free it asks again. Ship and Bay's trolley calls are played by a
## stand-in here (TradesTractor.trolley_api), so this checks the Tools side only.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
## The yard's trolleys: "m" is free unless `busy`; it records what it is asked.
const FAKE_TROLLEYS := """extends RefCounted
var busy := false
var asked: Array = []
var cancelled: Array = []
var deck := Vector3(6, 1.0, 4)
func beam_to_trolley(slot_id: String, component: String, condition: float, from: Vector3) -> String:
	asked.append([slot_id, component, from])
	return "" if busy else "m"
func cancel_beam(slot_id: String) -> void:
	cancelled.append(slot_id)
func trolley_deck_position(id: String) -> Variant:
	return deck if id == "m" else null
"""
const SLOT := "net_hold_dor_1"


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var had_flag := Flags.is_on("trades.tractor")
	Flags.set_flag("trades.tractor", true)
	ship_bus.load_ship("vs_kestrel")
	var yard := _make(FAKE_YARD, Node3D.new()) as Node3D
	var walker := CharacterBody3D.new()
	walker.position = Vector3(3, 0, 12)
	yard.set("walker", walker)
	yard.add_child(walker)
	add_child(yard)
	(Modules.bus("trades") as TradesBus)._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var station := rig.ship_station()
	var beam := station.tractor
	var trolleys: Object = _make(FAKE_TROLLEYS, RefCounted.new())
	beam.trolley_api = trolleys
	rig.set_tool(&"tractor")

	# Every joint off: the part stays where it was and a trolley is sent for it.
	for f in ship_bus.get_fasteners(SLOT):
		ship_bus.note_joint_removed(f.joint_id)
	var part: TradesLoosePart = beam.loose.get(SLOT)
	check(part != null and part.visible and part.is_inside_tree(), "a part that comes off stays in the yard")
	var asked: Array = trolleys.get("asked")
	check(asked.size() == 1 and asked[0][0] == SLOT and (asked[0][2] as Vector3).distance_to(part.centre()) < 0.01,
			"a trolley is sent for it, from where it came off")
	check(beam.to_trolley.get(SLOT) == "m", "the medium trolley is coming")
	_run(station, 1)
	var yard_beam: MeshInstance3D = beam._yard_beams.get(SLOT)
	check(yard_beam != null and yard_beam.visible, "a yard beam reaches from the part to the trolley")

	# The player takes it first: the trolley is called off; dropped, one is sent for again.
	_stand_off(rig, part.centre())
	station.press(&"tractor")
	check(beam.held == part and beam.to_trolley.is_empty() and trolleys.get("cancelled") == [SLOT],
			"taking it with your own beam calls the trolley off")
	_run(station, 1)
	await frames(1)
	check(not beam._yard_beams.has(SLOT), "and the yard beam goes")
	rig.worker.global_position += Vector3(0, 0, 1.5)
	_run(station, 30)
	trolleys.set("busy", true)
	station.release()
	check(asked.size() == 2 and beam.to_trolley.is_empty(), "dropped: it asks for a trolley again (none free)")
	trolleys.set("busy", false)
	_run(station, 100)
	check(asked.size() == 3 and beam.to_trolley.get(SLOT) == "m", "a few seconds on it asks again and one comes")

	# On the deck it's a crate: the copy goes.
	beam._on_part_beamed("crate_1", "m", part.component, SLOT)
	await frames(1)
	check(not beam.loose.has(SLOT) and not is_instance_valid(part), "on the trolley it's a crate: the loose copy goes")
	check(beam.to_trolley.is_empty() and beam._yard_beams.is_empty(), "nothing left waiting on the trolley")
	check((trolleys.get("cancelled") as Array).size() == 1, "and it isn't called off afterwards")

	yard.queue_free()
	await frames(1)
	ship_bus.load_ship("vs_kestrel")
	Flags.set_flag("trades.tractor", had_flag)


func _run(station: TradesShipJoints, n: int) -> void:
	for i in n:
		station.update(0.05)


## The worker standing 2.4 m off a point, looking at it.
func _stand_off(rig: TradesBay, at: Vector3) -> void:
	var feet := at + Vector3(0, 0, 2.4)
	feet.y = 0.0
	rig.worker.global_position = feet
	rig.worker.face(at)


func _make(source: String, obj: Object) -> Object:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	obj.set_script(script)
	return obj
