extends ModuleTest
## trades.gone_rings (beenster, 0.3.29: "when a rivet or bolt is removed so is its highlight"):
## a rivet cut out or a bolt run out loses its ring at once. A tool that can't put it back
## doesn't aim it again; the wrench and the rivet gun can, and ring it once the look has left
## and come back. And trades.tool_one_job (the same playtest): the cutter only takes rivets out,
## the welder only works welds.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
const FLAGS := ["trades.vs_tools", "trades.power_wrench", "trades.cutter", "trades.slim_hotbar", "trades.vs_snap",
		"trades.gone_rings", "trades.tool_one_job", "trades.rivet_heat", "trades.cutter_welds"]


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

	# One job each.
	check(not station.kind_tools("weld").has(&"cutter") and station.kind_tools("weld").has(&"welder"), "the cutter doesn't work welds")
	check(not station.kind_tools("rivet").has(&"welder") and station.kind_tools("rivet").has(&"cutter"), "the welder doesn't work rivets")

	# A bolt run out: its ring goes at once, though the wrench stays on it to run it back in.
	var b := _first(station, "bolt")
	var f := station.points[b]
	rig.set_tool(&"torque_wrench")
	_aim_at(rig, station, b)
	check(station.aimed == b and station._marker.visible, "a tight bolt under the aim is ringed")
	station.press(&"torque_wrench")
	_run(station, TradesShipJoints.UNDO_S + 0.1)
	station.release()
	station.update(0.0)
	check(not ship_bus.is_joint_tight(f.joint_id), "the bolt is out")
	check(not station._marker.visible, "and its ring went with it")
	check(station.aimed == b, "the wrench is still on it to run it back")
	check(not station.hinted.has(b), "nor is it hinted")
	# Look away and back: the wrench can put it back, so it rings again.
	rig.worker.face(station.points_world[b] + Vector3.UP * 3.0)
	station.update(0.0)
	check(station.aimed != b, "looking away leaves it")
	_aim_at(rig, station, b)
	check(station._marker.visible, "looked away and back, the wrench rings it to put back")
	# The cutter can't put a bolt back: it isn't aimed.
	rig.set_tool(&"cutter")
	station.update(0.0)
	check(station.aimed != b, "the cutter doesn't aim a bolt that's out")

	# A rivet cut out: no ring, and the cutter moves on.
	var r := _first(station, "rivet")
	var rf := station.points[r]
	_aim_at(rig, station, r)
	check(station.aimed == r, "the cutter is on a tight rivet")
	station.press(&"cutter")
	_run(station, 8.0)
	station.release()
	station.update(0.0)
	check(not ship_bus.is_joint_tight(rf.joint_id), "the rivet is cut out")
	check(station.aimed != r and not station.hinted.has(r), "its ring is gone and the cutter leaves it: aimed %d" % station.aimed)
	# Off: as before, the ring stays.
	Flags.set_flag("trades.gone_rings", false)
	station.update(0.0)
	check(not station.is_gone(r, true), "with the flag off it counts as before")

	yard.queue_free()
	await frames(2)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func _run(station: TradesShipJoints, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		station.update(minf(0.05, left))
		left -= 0.05


func _first(station: TradesShipJoints, kind: String) -> int:
	for i in station.points.size():
		var f := station.points[i]
		if f.kind == kind and not TradesShipJoints.is_practice(f) and not station.is_rig(f) and station.is_tight(f):
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
