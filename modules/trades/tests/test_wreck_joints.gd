extends ModuleTest
## Playtest 0.3.24 (beenster): "none of the bolts or rivets work with the tools on a wreck -
## they highlight but tools don't do anything". The wreck sits up on its cradle, so the ship's
## transform changed after the yard was entered; the tools kept the old one and aimed up to
## 0.7 m off every joint. Now the joints follow the ship: loaded, set down or driven away.


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var was := Flags.is_on("ship_bay.bay_cradle")
	Flags.set_flag("ship_bay.bay_cradle", true)
	var yard := (load(Router.scene_path(ShipBayBus.SHIPYARD_SCENE)) as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	var rig: TradesBay = yard.get_node_or_null(TradesBus.YARD_RIG)
	check(rig != null, "the tools are in the yard")
	if rig == null:
		return
	var station := rig.ship_station()
	ship_bus.wreck_seed = 9
	ship_bus.debug_ship("random_wreck", "S")
	await frames(3)
	var bay: Node3D = yard.get("bay")
	check(station.ship_xform.is_equal_approx(rig.ship_transform()), "the tools read where the wreck sits: %s" % rig.ship_transform().origin)
	var off := _worst(station, bay)
	check(off.y > 100 and off.x < 0.05, "every bolt, rivet and weld is where Ship and Bay marks it (%d, %.3f m out at worst)" % [off.y, off.x])
	var kinds := {}
	for f in station.points:
		kinds[f.kind] = true
	check(kinds.has("bolt") and kinds.has("rivet"), "the wreck has bolts and rivets to work: %s" % [kinds.keys()])
	# The ship moved under the tools (a cradle driven): they follow it.
	var ship_root: Node3D = bay.get("ship_root")
	ship_root.global_position += Vector3(2, 0, 1)
	station.update(0.3)
	off = _worst(station, bay)
	check(off.x < 0.05, "after it moves too (%.3f m)" % off.x)
	ship_root.global_position -= Vector3(2, 0, 1)
	station.update(0.3)
	# Playtest 0.3.26: "rivet, bolt and weld highlighting seems to have gone". The frame's welds
	# behind the skin kept winning the aim; now a joint behind the surface you look at isn't
	# picked (trades.aim_visible), and the one in front of you is.
	var was_vis := Flags.is_on("trades.aim_visible")
	var was_snap := Flags.is_on("trades.vs_snap")
	Flags.set_flag("trades.aim_visible", true)
	Flags.set_flag("trades.vs_snap", false)
	rig.set_tool(&"hands")
	var seen := [0, 0]
	var hidden := [0, 0]
	var hidden_ids: Array[int] = []
	# Every joint in turn until six of each are found: sampling every fifth missed them all
	# once Ship and Bay added inner bolts (a hidden one counts only where the hand reaches it,
	# for the snap's check below).
	for i in station.points.size():
		if seen[1] >= 6 and hidden[1] >= 6:
			break
		var depth := await _look_at(rig, station, i)
		# Only where the look lands on it (a joint high overhead is past the neck's reach).
		# Nor a joint already out (trades.gone_rings: a loose rivet the hands can't work is out of the
		# aim). Which are out follows the wreck's state, so it differs run to run.
		if is_nan(depth) or rig.aim_distance(station.points_world[i]) > 0.02 or station.is_gone(i):
			continue
		# In the hand's reach too, as the aim only picks what the hand reaches.
		if depth < 0.03 and seen[1] < 6 and rig.worker.right_hand.can_reach(station.points_world[i]):
			seen[1] += 1
			# The aim picks the nearest to its line: this one, or one as near (two a few mm apart).
			var a := station.aimed
			var ok := _same_spot(station, a, i) or (a >= 0 and rig.aim_distance(station.points_world[a]) <= rig.aim_distance(station.points_world[i]) + 0.002)
			seen[0] += 1 if ok else 0
			if not ok:
				print("joint %d not picked: aimed %d, %.3f m off the line, depth %.3f" % [i, a, rig.aim_distance(station.points_world[i]), depth])
		elif depth > 0.3 and hidden[1] < 6 and rig.worker.right_hand.can_reach(station.points_world[i]):
			hidden[1] += 1
			hidden[0] += 1 if station.aimed != i else 0
			hidden_ids.append(i)
	check(seen[1] > 0 and seen[0] == seen[1], "looking at a joint in front of you picks it (%d of %d)" % seen)
	check(hidden[1] > 0 and hidden[0] == hidden[1], "one behind the skin you're looking at isn't picked (%d of %d)" % hidden)
	# trades.vs_snap (beenster, 0.3.27: "in Void Salvage bolts and rivets which are behind plates
	# or obscured can still be detected by the tool in hand"): the same hidden ones are picked.
	Flags.set_flag("trades.vs_snap", true)
	var found := 0
	var reached := 0
	for i in hidden_ids:
		await _look_at(rig, station, i)
		if not rig.worker.right_hand.can_reach(station.points_world[i]) or rig.aim_distance(station.points_world[i]) > 0.02:
			continue
		reached += 1
		# The snap takes the nearest joint to the look: this one, or one no further from it (a
		# rivet where the look lands on the skin can be as near as one on the line behind it).
		var a := station.aimed
		found += 1 if a == i or (a >= 0 and _snap_d(rig, station, a) <= _snap_d(rig, station, i) + TradesShipJoints.STICK_M) else 0
	check(reached > 0 and found == reached, "with the snap, the ones behind the skin on the aim line, in reach, are picked or one as near (%d of %d)" % [found, reached])
	Flags.set_flag("trades.vs_snap", was_snap)
	Flags.set_flag("trades.aim_visible", was_vis)
	ship_bus.debug_ship("restore_bay")
	Flags.set_flag("ship_bay.bay_cradle", was)


## Stand in front of joint i and look at it; how far it lies behind the first surface on the
## way (metres; NAN when it faces up or down, or nothing is in the way).
func _look_at(rig: TradesBay, station: TradesShipJoints, i: int) -> float:
	var at := station.points_world[i]
	var n := (station.ship_xform.basis * station.points[i].normal).normalized()
	if absf(n.y) > 0.5:
		return NAN
	rig.worker.global_position = at + n * 0.9 - Vector3(0, 1.55, 0)
	rig.worker.face(at)
	# Physics steps too, not just a frame: the aim's surface ray reads the physics space, which
	# lags the moved worker on a busy machine (CI) until a step has run.
	await frames(1)
	for k in 2:
		await get_tree().physics_frame
	station.update(0.0)
	var o := rig.worker.aim_origin()
	var q := PhysicsRayQueryParameters3D.create(o, o + (at - o).normalized() * 20.0)
	q.exclude = [rig.worker.get_rid()]
	var hit := rig.worker.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return NAN
	return o.distance_to(at) - o.distance_to(hit.position)


## How near joint i is to the look by the snap's own measure: to where the look lands, or to the
## aim line when it's on it (TradesShipJoints._snap_aim).
func _snap_d(rig: TradesBay, station: TradesShipJoints, i: int) -> float:
	var p: Vector3 = station.call("_aim_point", i)
	var o := rig.worker.aim_origin()
	var q := PhysicsRayQueryParameters3D.create(o, o + rig.worker.aim_dir() * TradesShipJoints.POINTER_RAY_M)
	q.exclude = [rig.worker.get_rid()]
	var hit := rig.worker.get_world_3d().direct_space_state.intersect_ray(q)
	var on_line := rig.aim_distance(p)
	var d := on_line if on_line < TradesShipJoints.PICK_M else INF
	return minf(d, p.distance_to(hit.position)) if not hit.is_empty() else d


## The aimed joint is joint i, or one at the same spot (a bolt pair or a weld through one hole).
func _same_spot(station: TradesShipJoints, aimed: int, i: int) -> bool:
	return aimed == i or (aimed >= 0 and station.points_world[aimed].distance_to(station.points_world[i]) < 0.01)


## [worst distance between a joint's point and Ship and Bay's marker on it, joints compared].
func _worst(station: TradesShipJoints, bay: Node3D) -> Vector2:
	var markers: Dictionary = bay.get("markers")
	var worst := 0.0
	var n := 0
	for i in station.points.size():
		var f := station.points[i]
		if markers.has(f.joint_id):
			worst = maxf(worst, (markers[f.joint_id] as Node3D).global_position.distance_to(station.points_world[i]))
			n += 1
	return Vector2(worst, n)
