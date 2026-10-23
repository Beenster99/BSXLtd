extends ModuleTest
## The welder on the ship (beenster, 0.3.7): X switches it between weld and unweld, the shield
## flicks down while the arc is lit and you look out through its dark letterbox, the arc
## throws sparks that fall and fade, and other players' arcs are drawn too.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var was_unweld := Flags.is_on("trades.unweld")
	var was_helmet := Flags.is_on("trades.weld_helmet")
	Flags.set_flag("trades.unweld", true)
	Flags.set_flag("trades.weld_helmet", true)
	var was_trace := Flags.is_on("trades.trace_weld")
	Flags.set_flag("trades.trace_weld", true)
	# The shield on the arc alone (test_playtest_0316 has its key).
	var was_toggle := Flags.is_on("trades.helmet_toggle")
	Flags.set_flag("trades.helmet_toggle", false)
	ship_bus.load_ship("vs_kestrel")
	var yard := _fake_yard()
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var station := rig.ship_station()
	var torch := rig.tool_node(&"welder") as TradesWeldTorch
	check(rig.worker.welding_helmet != null and rig.helmet_down() == 0.0, "you wear a welding shield, tipped up (%s, %.2f)" % [rig.worker.welding_helmet, rig.helmet_down()])

	var i := _first(station, "weld")
	check(i >= 0, "the ship has welds")
	if i < 0:
		return
	var f := station.points[i]
	_aim_at(rig, station, i)
	rig.set_tool(&"welder")
	check(station.aimed == i and ship_bus.is_joint_tight(f.joint_id), "aimed at a weld")

	# Weld mode on a weld: nothing. X: unweld, and left click cuts it out.
	station.press(&"welder")
	check(not station.is_busy(), "weld mode on a finished weld does nothing")
	var tips := "\n".join(rig.context_tips())
	check(tips.contains("switch to unweld"), "the tips offer unweld: %s" % tips.replace("\n", " | "))
	rig._on_action(TradesBus.KEY_MODE)
	check(torch.unweld and torch.readout_text().contains("UNWELD"), "%s switches the welder to unweld" % Keys.key_name(TradesBus.KEY_MODE))
	_to_end(rig, station, i)
	station.press(&"welder")
	_run(rig, station, 0.3)
	check(torch.lit and torch.cutting, "unwelding: the arc is lit")
	check(rig.helmet_down() > 0.9 and rig.worker.welding_helmet.down > 0.9, "the shield flicks down (%.2f, %.2f)" % [rig.helmet_down(), rig.worker.welding_helmet.down])
	var view := rig.find_children("WeldingView", "TradesWeldingView", true, false)
	check(view.size() == 1 and (view[0] as TradesWeldingView).visible and (view[0] as TradesWeldingView).down > 0.9,
			"first person: you look out through its letterbox")
	check(rig.sparks.count() > 20, "a shower of sparks (%d)" % rig.sparks.count())
	_run(rig, station, 0.5)
	check(ship_bus.is_joint_tight(f.joint_id), "holding still on one spot doesn't cut it out")
	_sweep(rig, station, i)
	check(not ship_bus.is_joint_tight(f.joint_id), "tracing the arc along the seam cuts it out")
	check(station.hot_beads() > 0, "and the cut glows orange (%d)" % station.hot_beads())
	_run(rig, station, 1.0)
	check(rig.helmet_down() == 0.0 and not (view[0] as TradesWeldingView).visible, "arc out: the shield lifts")

	# Back to weld mode and lay it again.
	rig._on_action(TradesBus.KEY_MODE)
	check(not torch.unweld, "and back to weld")
	_to_end(rig, station, i)
	station.press(&"welder")
	_sweep(rig, station, i)
	check(ship_bus.is_joint_tight(f.joint_id), "weld mode lays it again, traced along the seam")
	_run(rig, station, TradesShipJoints.BEAD_COOL_S + 0.5)
	check(station.hot_beads() == 0, "and the bead cools")

	# Sparks fall under gravity, bounce off the floor and fade away.
	var test_sparks := TradesSparks.new()
	add_child(test_sparks)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(4, 0.2, 4)
	floor_shape.shape = slab
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	floor_body.global_position = Vector3(100, -0.1, 0)
	await frames(2)
	test_sparks.emit(Vector3(100, 0.5, 0), Vector3.RIGHT, 1, 1.0, 0.0)
	for k in 10:
		test_sparks._physics_process(1.0 / 60.0)
	check(test_sparks.positions()[0].y < 0.5, "a spark falls (%.2f m)" % test_sparks.positions()[0].y)
	for k in 20:
		test_sparks._physics_process(1.0 / 60.0)
	var low := test_sparks.positions()[0].y if test_sparks.count() > 0 else 0.0
	check(test_sparks.count() == 0 or low > -0.01, "it stops on the floor, not through it (%.3f m)" % low)
	for k in 90:
		test_sparks._physics_process(1.0 / 60.0)
	check(test_sparks.count() == 0, "and fades away")
	# Bolts and rivet heads that come out (beenster, 0.3.14): they fall, at most 100 at once,
	# gone in 15 s.
	var bolt := BoxMesh.new()
	for k in TradesSparks.POP_MAX + 5:
		test_sparks.pop(Vector3(100, 0.5, 0), Vector3.ZERO, bolt, null)
	check(test_sparks.pop_count() == TradesSparks.POP_MAX, "no more than %d bits down at once" % TradesSparks.POP_MAX)
	for k in 60:
		test_sparks._physics_process(1.0 / 60.0)
	check(test_sparks.pop_positions()[0].y < 0.2, "a dropped bolt falls to the floor")
	for k in int(TradesSparks.POP_LIFE_S * 60) + 10:
		test_sparks._physics_process(1.0 / 60.0)
	check(test_sparks.pop_count() == 0, "and is gone after %d s" % TradesSparks.POP_LIFE_S)
	test_sparks.queue_free()
	floor_body.queue_free()

	# Another player's arc.
	rig._apply_torch({"peer": 99, "on": true, "at": station.points_world[i], "cutting": true})
	rig._process(0.016)
	check(rig.remote_arcs() == 1 and rig.sparks.count() > 0, "another player's arc is drawn, with its sparks")
	rig._apply_torch({"peer": 99, "on": false, "at": station.points_world[i], "cutting": false})
	check(rig.remote_arcs() == 0, "and goes out with theirs")

	yard.queue_free()
	await frames(1)
	Flags.set_flag("trades.unweld", was_unweld)
	Flags.set_flag("trades.weld_helmet", was_helmet)
	Flags.set_flag("trades.trace_weld", was_trace)
	Flags.set_flag("trades.helmet_toggle", was_toggle)


## Runs the station and the bay's shield together, as frames would.
func _run(rig: TradesBay, station: TradesShipJoints, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		station.update(minf(0.05, left))
		rig.update_helmet(minf(0.05, left))
		left -= 0.05


## Looks at the start of a weld's seam, where an arc can be struck.
func _to_end(rig: TradesBay, station: TradesShipJoints, i: int) -> void:
	var f := station.points[i]
	rig.worker.face(station.points_world[i] - station.ship_xform.basis * f.seam_up * f.seam_size.x * 0.5)
	station.update(0.0)


## Runs the aim along a weld's seam from end to end, as a player tracing it would.
func _sweep(rig: TradesBay, station: TradesShipJoints, i: int) -> void:
	var f := station.points[i]
	var at := station.points_world[i]
	var along := station.ship_xform.basis * f.seam_up
	for k in 41:
		rig.worker.face(at + along * (f.seam_size.x * (k / 40.0 - 0.5)))
		station.update(0.05)
		rig.update_helmet(0.05)


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
