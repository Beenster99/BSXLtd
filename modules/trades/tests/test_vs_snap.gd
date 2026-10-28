extends ModuleTest
## trades.vs_snap (beenster, 0.3.27): "I like the way tools in void salvage jump to the nearby
## bolt/rivet rather than me having to refocus all the time"; "in Void Salvage bolts and rivets
## which are behind plates or obscured can still be detected by the tool in hand".

const FLAGS := ["trades.vs_snap", "trades.aim_visible"]


func run_tests() -> void:
	var saved := {}
	for flag: String in FLAGS:
		saved[flag] = Flags.is_on(flag)
	Flags.set_flag("trades.aim_visible", true)
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(10)
	var rig: TradesBay = yard.get_node_or_null(TradesBus.YARD_RIG)
	check(rig != null, "the yard has the tools rig")
	if rig == null:
		return
	var station := rig.ship_station()
	rig.set_process(false)
	rig.set_physics_process(false)
	var space := rig.get_world_3d().direct_space_state
	# A rivet on a side plate of the Kestrel, the plate solid round it.
	var r := -1
	var tangent := Vector3.ZERO
	for i in station.points.size():
		var f := station.points[i]
		if f.kind != "rivet" or not station.is_tight(f) or TradesShipJoints.is_practice(f) or station.is_rig(f):
			continue
		var n := (station.ship_xform.basis * f.normal).normalized()
		if absf(n.y) > 0.3:
			continue
		var t := n.cross(Vector3.UP).normalized()
		var off := station.points_world[i] + t * 0.15
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(off + n * 0.5, off - n * 0.05))
		if hit.is_empty() or (hit.normal as Vector3).dot(n) < 0.9:
			continue
		# No other joint nearer the off-aim spot than this rivet.
		var nearest := true
		for k in station.points.size():
			if k != i and station.points_world[k].distance_to(off) < station.points_world[i].distance_to(off):
				nearest = false
				break
		if nearest:
			r = i
			tangent = t
			break
	check(r >= 0, "the Kestrel has a side rivet on solid plate")
	if r < 0:
		return
	var at := station.points_world[r]
	var n := (station.ship_xform.basis * station.points[r].normal).normalized()
	var spot := at + tangent * 0.15
	rig.set_tool(&"cutter")
	Flags.set_flag("trades.vs_snap", false)
	_aim(rig, station, at, n, spot)
	check(station.aimed != r, "without the snap, the cutter aimed 15 cm off the rivet doesn't take it")
	Flags.set_flag("trades.vs_snap", true)
	_aim(rig, station, at, n, spot)
	check(station.aimed == r, "with it, the cutter aimed 15 cm off the rivet jumps to it")
	check(station.hinted.size() > 0 and station._hint_mat.no_depth_test, "the joints round it show, through what hides them (%d)" % station.hinted.size())
	# Aimed at the plate, a hidden joint behind it still counts: every hinted one is in hint reach.
	var all_near := true
	for i in station.hinted:
		all_near = all_near and station.points_world[i].distance_to(spot) < TradesShipJoints.HINT_M + 0.05
	check(all_near, "the hints are the joints near the aim")
	# The wrench doesn't snap to a rivet it can't work.
	rig.set_tool(&"torque_wrench")
	_aim(rig, station, at, n, spot)
	check(station.aimed < 0 or station.points[station.aimed].kind == "bolt", "the wrench doesn't jump to a rivet")
	for i in station.hinted:
		check(station.points[i].kind == "bolt", "the wrench hints only bolts")
		break
	for flag: String in FLAGS:
		Flags.set_flag(flag, saved[flag])


func _aim(rig: TradesBay, station: TradesShipJoints, at: Vector3, n: Vector3, look_at: Vector3) -> void:
	var out := Vector3(n.x, 0.0, n.z).normalized()
	var eye := at + out * 0.9
	rig.worker.global_position = eye - Vector3.UP * (rig.worker.aim_origin().y - rig.worker.global_position.y)
	rig.worker.face(look_at)
	station.aimed = -1
	station.update(0.0)
