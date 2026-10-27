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
	ship_bus.debug_ship("restore_bay")
	Flags.set_flag("ship_bay.bay_cradle", was)


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
