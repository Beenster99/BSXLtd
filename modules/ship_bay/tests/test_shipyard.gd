extends ModuleTest
## Ship and Bay: the shipyard builds round the bay, its rooms are where the flow says, you
## can walk from the apron into the courtyard and through the rooms, and the Kestrel sits
## in the bay.
##   tools/run_tests.sh ship_bay

const Yard := preload("res://modules/ship_bay/internal/yard/shipyard.gd")


func run_tests() -> void:
	var bay := Modules.bus("ship_bay") as ShipBayBus
	var rooms := bay.shipyard_rooms()
	check(rooms.keys() == ["deliveries", "stock", "prep", "preassembly", "bay"], "rooms in work order: %s" % [rooms.keys()])
	var ids: Array = rooms.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: AABB = rooms[ids[i]].box
			var b: AABB = rooms[ids[j]].box
			check(not a.intersection(b).has_volume(), "%s and %s don't overlap" % [ids[i], ids[j]])
	var court: AABB = rooms["bay"].box
	check(court.has_point(Vector3(0, 1, 0)), "the bay is the courtyard round the origin")
	check(Yard.room_at(Vector3(-40, 1, 0)) == "deliveries", "west wing is deliveries")
	check(Yard.room_at(Vector3(40, 1, 0)) == "preassembly", "east wing is pre-assembly")
	check(Yard.room_at(Vector3(0, 1, 60)) == "", "the apron is outside")

	for spot: String in ["bench_preassembly", "bench_prep"]:
		var at := bay.shipyard_spot(spot).origin
		check(Yard.room_at(at + Vector3(0, 1, 0)) == ("preassembly" if spot == "bench_preassembly" else "prep"),
				"%s is in its room" % spot)
	var readied: Array = []
	bay.shipyard_ready.connect(func(y: Node3D) -> void: readied.append(y))
	var scene := load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene
	var yard := scene.instantiate() as Node3D
	add_child(yard)
	await frames(3)
	check(readied == [yard], "shipyard_ready hands other modules the yard")
	check(bay.ship != null and bay.ship.ship_id == "vs_kestrel", "the Kestrel is in the bay")
	for spot: String in ["bench_preassembly", "bench_prep"]:
		var at := bay.shipyard_spot(spot).origin
		var box := PhysicsShapeQueryParameters3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(5.0, 1.6, 2.6)
		box.shape = shape
		box.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 1.0, 0.8))
		var hits := yard.get_world_3d().direct_space_state.intersect_shape(box)
		check(hits.is_empty(), "%s is clear for a bench and a worker: %d" % [spot, hits.size()])
	var ship_bay: Node3D = yard.get("bay")
	check(ship_bay != null and ship_bay.get_node_or_null("Ship") != null, "the bay scene sits in the courtyard")
	check(ship_bay.find_child("Floor", false, false) == null, "inside the yard the bay brings no floor of its own")

	# Every doorway the flow uses is open at walking height; walls stand between the rooms.
	var space := yard.get_world_3d().direct_space_state
	for path: Array in [["apron to bay", Vector3(0, 1, 40), Vector3(0, 1, 12)],
			["bay to deliveries", Vector3(-20, 1, 0), Vector3(-36, 1, 0)],
			["deliveries to stock", Vector3(-39, 1, -18), Vector3(-39, 1, -30)],
			["stock to prep", Vector3(-6, 1, -35), Vector3(6, 1, -35)],
			["prep to pre-assembly", Vector3(39, 1, -28), Vector3(39, 1, -18)],
			["pre-assembly to bay", Vector3(36, 1, 0), Vector3(20, 1, 0)],
			["truck door", Vector3(-56, 1, -8), Vector3(-44, 1, -8)]]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(path[1], path[2]))
		check(hit.is_empty(), "%s is open: %s" % [path[0], hit.get("position", "")])
	for wall: Array in [["bay to stock away from its door", Vector3(-24, 1, -20), Vector3(-24, 1, -30)],
			["stock to prep away from its door", Vector3(-6, 1, -44), Vector3(6, 1, -44)]]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(wall[1], wall[2]))
		check(not hit.is_empty(), "%s is a wall" % wall[0])

	# The walker stands on the courtyard.
	var walker: CharacterBody3D = yard.get("walker")
	walker.call("place", Vector3(0, 0.5, 20), Vector3(0, 1, 0))
	for i in 30:
		await get_tree().physics_frame
	check(walker.is_on_floor(), "the walker stands on the ground")
	check(absf(walker.position.y) < 0.1, "at ground level: %.2f" % walker.position.y)
	check(bay.walker_position(yard).distance_to(walker.position) < 0.001, "walker_position reports the walker")
	var walker_cam := walker.get("camera") as Camera3D
	bay.set_walker_active(yard, false)
	check(not walker.is_physics_processing() and not walker_cam.current, "handed over: the walker stops and its camera stands down")
	var other := Camera3D.new()
	yard.add_child(other)
	other.current = true
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(200, 0)
	var turn := walker.rotation.y
	yard.call("_unhandled_input", motion)
	check(walker.rotation.y == turn and other.current, "handed over: the yard leaves the mouse alone")
	bay.set_walker_active(yard, true)
	check(walker.is_physics_processing() and walker_cam.current, "taken back: the walker walks and looks again")
	other.queue_free()
	yard.call("show_view", "deliveries")
	check(yard.get("view_camera").current, "a view takes the camera")
	yard.queue_free()
	await frames(1)
	bay.unload_ship()
