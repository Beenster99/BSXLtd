extends ModuleTest
## Ship and Bay: the shipyard builds round the bay, its rooms are where the flow says, you
## can walk from the apron into the courtyard and through the rooms, and the Kestrel sits
## in the bay.
##   tools/run_tests.sh ship_bay

const Yard := preload("res://modules/ship_bay/internal/yard/shipyard.gd")
const CrusherPlant := preload("res://modules/ship_bay/internal/yard/crusher_plant.gd")
const Apron := preload("res://modules/ship_bay/internal/yard/apron.gd")


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
	# Direction signs: every hall's wall board shows the way to every other room, each arrow
	# toward the first doorway on the way.
	check(Yard.way_to("stock", "deliveries") == Vector2(-39, -24) and Yard.way_to("deliveries", "preassembly") == Vector2(-28, 0),
			"the way from room to room goes through their doorways")
	for d: Array in Yard.DIRECTION_SIGNS:
		var said := " ".join(Yard.wall_sign_lines(d))
		for id: String in rooms:
			if id != d[0]:
				check(said.contains((rooms[id].name as String).to_upper()), "%s's sign shows the way to %s: %s" % [d[0], id, said])
	check(Yard.direction_lines("deliveries", Vector3(-39, 10, 0), 0.0) == PackedStringArray(["↑  STOCK", "STORE 2  ·  PRE-ASSEMBLY  ·  THE BAY  →"]),
			"deliveries, facing the stock end: stock ahead, the rest through the bay on the right: %s" % [Yard.direction_lines("deliveries", Vector3(-39, 10, 0), 0.0)])
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
	# Tools hangs real extinguishers at the fire points: on a wall, facing into a room.
	var fires := bay.fire_points()
	var inside := fires.filter(func(f: Transform3D) -> bool:
			var into := f.origin - f.basis.z * 0.5 + Vector3(0, 1, 0)
			return Yard.room_at(into) != "" and f.origin.y > 0.0 and f.origin.y < 1.0)
	check(fires.size() > 20 and inside.size() == fires.size(), "the fire points face into the rooms: %d of %d" % [inside.size(), fires.size()])
	var bed := bay.cutting_bed_spot()
	check(is_zero_approx(bed.origin.y) and Yard.room_at(bed.origin + Vector3(0, 1, 0)) == "", "the cutting bed's spot is on the floor west of the halls: %s" % bed.origin)
	for spot: String in ["bench_preassembly", "bench_prep"]:
		var box := PhysicsShapeQueryParameters3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(5.0, 1.6, 2.6)
		box.shape = shape
		box.transform = bay.shipyard_spot(spot) * Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 0.8))
		# Only the yard's own building counts: other modules (Tools' bench) stand on the spots.
		var hits := yard.get_world_3d().direct_space_state.intersect_shape(box).filter(
				func(hit: Dictionary) -> bool: return yard.call("is_own_body", hit.collider))
		check(hits.is_empty(), "%s is clear for a bench and a worker: %d" % [spot, hits.size()])
	var arrows := yard.get_tree().get_nodes_in_group("direction_sign").size()
	if Flags.is_on("ship_bay.no_signs"):
		check(arrows == 0, "no direction boards or fingerposts (beenster, 0.3.19): %d lines" % arrows)
	else:
		check(arrows == 16, "the halls' boards and the courtyard's fingerpost are up: %d lines" % arrows)
	var ship_bay: Node3D = yard.get("bay")
	check(ship_bay != null and ship_bay.get("ship_root") != null, "the bay scene sits in the courtyard")
	check(ship_bay.find_child("Floor", false, false) == null, "inside the yard the bay brings no floor of its own")

	# Every doorway the flow uses is open at walking height; walls stand between the rooms.
	var space := yard.get_world_3d().direct_space_state
	for path: Array in [["apron to bay", Vector3(0, 1, 40), Vector3(0, 1, 12)],
			["bay to deliveries", Vector3(-20, 1, 0), Vector3(-36, 1, 0)],
			["deliveries to stock", Vector3(-39, 1, -18), Vector3(-39, 1, -28.5)],
			["stock to prep", Vector3(-2.0, 1, -35), Vector3(2.6, 1, -35)],
			["prep to pre-assembly", Vector3(39, 1, -28), Vector3(39, 1, -18)],
			["pre-assembly to bay", Vector3(36, 1, 0), Vector3(20, 1, 0)],
			["truck door", Vector3(-56, 1, -8), Vector3(-44, 1, -8)]]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(path[1], path[2]))
		check(hit.is_empty(), "%s is open: %s" % [path[0], hit.get("position", "")])
	# The halls' doorways are tall enough for a picking lift's mast (beenster, 0.3.15).
	var mast := float(preload("res://modules/ship_bay/internal/yard/hover_trolley.gd").SPECS["h"]["mast"]) + 0.3
	for path: Array in [["bay to deliveries", Vector3(-20, mast, 0), Vector3(-36, mast, 0)],
			["deliveries to stock", Vector3(-39, mast, -18), Vector3(-39, mast, -28.5)],
			["bay to stock", Vector3(-14, mast, -18), Vector3(-14, mast, -28.5)],
			["stock to prep", Vector3(-2.0, mast, -35), Vector3(2.6, mast, -35)],
			["prep to pre-assembly", Vector3(39, mast, -28), Vector3(39, mast, -18)],
			["pre-assembly to bay", Vector3(36, mast, 0), Vector3(20, mast, 0)]]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(path[1], path[2]))
		check(hit.is_empty(), "%s is open up to %.1f m for the picking lifts: %s" % [path[0], mast, hit.get("position", "")])
	for wall: Array in [["bay to stock away from its door", Vector3(-24, 1, -20), Vector3(-24, 1, -30)],
			["stock to prep away from its door", Vector3(-6, 1, -44), Vector3(6, 1, -44)]]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(wall[1], wall[2]))
		check(not hit.is_empty(), "%s is a wall" % wall[0])

	# Dock 1: no fixed gantries round the ship (bigger ships come in), and no balcony stair.
	for z: float in [-8.6, 11.2]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-7.0, 1, z + 1.5), Vector3(-7.0, 1, z - 1.5)))
		check(hit.is_empty(), "the dock is clear at z %.1f" % z)
	var gone := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 8, -22.9), Vector3(0, 0.5, -22.9)))
	check(gone.is_empty(), "the overlook balcony and its stair are gone: %s" % gone.get("position", ""))

	# The walker stands on the courtyard.
	var walker: CharacterBody3D = yard.get("walker")
	# Another module (Tools) may have taken the yard over on shipyard_ready.
	yard.call("set_walker_active", true)
	walker.call("place", Vector3(0, 0.5, 20), Vector3(0, 1, 0))
	for i in 30:
		await get_tree().physics_frame
	check(walker.is_on_floor(), "the walker stands on the ground")
	check(absf(walker.position.y) < 0.1, "at ground level: %.2f" % walker.position.y)
	check(bay.walker_position(yard).distance_to(walker.position) < 0.001, "walker_position reports the walker")
	var walker_cam := walker.get("camera") as Camera3D
	bay.set_walker_active(yard, false)
	check(not walker.is_physics_processing() and not walker_cam.current, "handed over: the walker stops and its camera stands down")
	check(walker.collision_layer == 0 and walker.collision_mask == 0, "handed over: the walker no longer collides")
	var ship_xf := bay.ship_transform(yard)
	check(ship_xf.origin.is_equal_approx(Vector3(0, float(yard.get("bay").get("cradle_height")), 0)), "ship space sits on the cradles: %s" % ship_xf.origin)
	if Flags.is_on("ship_bay.bay_cradle"):
		var bay_cradle: Node3D = yard.get("bay").get("cradle")
		check(bay_cradle != null and bay_cradle.get("load_node") == yard.get("bay").get("ship_root"),
				"the courtyard ship sits in a transport cradle that carries it (beenster, 0.3.19)")
		var tr: Node = yard.find_child("Transporters", true, false)
		check(tr == null or tr.call("cradle", "BayCradle") == bay_cradle, "the transporters can lift the courtyard's cradle")
	check(bay.ship_to_yard(yard) == ship_xf, "ship_to_yard is ship_transform")
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
	check(walker.collision_layer != 0, "taken back: the walker collides again")
	other.queue_free()
	yard.call("show_view", "deliveries")
	check(yard.get("view_camera").current, "a view takes the camera")
	var kinds := {}
	for m: MeshInstance3D in yard.find_children("*", "MeshInstance3D", true, false):
		var mats: Array = [m.material_override]
		if m.mesh:
			for i in m.mesh.get_surface_count():
				mats.append(m.get_active_material(i))
		for mat: Material in mats:
			if mat and mat.has_meta("gfx_surface"):
				kinds[mat] = str(mat.get_meta("gfx_surface"))
	var counts := {}
	for k: String in kinds.values():
		counts[k] = int(counts.get(k, 0)) + 1
	check(counts == {"concrete": 1, "ground": 1, "epoxy": 4, "asphalt": 2},
			"the ground paints are tagged for Graphics' surfaces: %s" % [counts])
	_check_apron(yard)
	yard.queue_free()
	await frames(1)
	bay.unload_ship()


## The apron (S2): flat docks and pad, cradles on their pedestals, the pad's cradle empty,
## the cutting bay open to the road and walled elsewhere.
func _check_apron(yard: Node3D) -> void:
	var apron: Node3D = yard.get("apron")
	if not Flags.is_on("ship_bay.apron"):
		check(apron == null, "with ship_bay.apron off there's no apron")
		return
	check(apron != null, "the apron is built")
	if apron == null:
		return
	var space := yard.get_world_3d().direct_space_state
	var docks: Dictionary = Apron.DOCKS
	for id: String in docks:
		var r: Rect2 = docks[id]
		# Flat: nothing stands round the dock's edge (no walls), and its floor is the apron's.
		var along := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(r.position.x - 3, 1, r.position.y - 3), Vector3(r.end.x + 3, 1, r.position.y - 3)))
		check(along.is_empty(), "Dock %s has no wall along its north edge: %s" % [id, along.get("position", "")])
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(r.get_center().x, 5, r.get_center().y), Vector3(r.get_center().x, -5, r.get_center().y)))
		check(not down.is_empty() and absf((down.position as Vector3).y) < 0.01, "Dock %s's floor is the apron, not sunken: %s" % [id, down.get("position", "")])
	var pad: Node3D = apron.get("pad_cradle")
	check(pad != null and pad.find_children("*", "RigidBody3D", true, false).is_empty() and float(pad.get("load_t")) == 0.0,
			"the pad's cradle stands empty (no test Kestrel)")
	var pad_at: Vector3 = Apron.PAD
	check(pad.global_position.is_equal_approx(pad_at + Vector3(0, 1.6, 0)), "the pad cradle stands on its pedestals at the pad: %s" % pad.global_position)
	var holding: Array = apron.get("holding_cradles")
	check(holding.size() == 3, "three cradles in the holding lane")
	var docked: Array = apron.get("dock_cradles")
	check(holding.map(func(c: Node3D) -> String: return str(c.get("size"))) == ["s", "m", "m"] and docked.size() == 1 and str(docked[0].get("size")) == "l",
			"a small and two medium cradles wait in the holding lane, a large one in Dock 3")
	check(float(docked[0].get("length")) > 70.0 and float(holding[1].get("length")) > 25.0, "the big ones are much longer than the Kestrel's")
	for c: Node3D in holding + docked + [pad]:
		for foot: Vector3 in c.call("pedestal_points"):
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(foot + Vector3(0, -0.8, -1.5), foot + Vector3(0, -0.8, 1.5)))
			check(not hit.is_empty(), "%s has a pedestal under it at %s" % [c.name, foot])
	# A 6 m wide dolly fits between a cradle's pedestals, under its cross beams.
	var under := space.intersect_ray(PhysicsRayQueryParameters3D.create(pad.global_position + Vector3(0, -0.4, -10), pad.global_position + Vector3(0, -0.4, 10)))
	check(under.is_empty(), "the way under the pad cradle is clear: %s" % under.get("position", ""))
	var house: Rect2 = CrusherPlant.HOUSE
	var hd: Vector3 = CrusherPlant.HOUSE_DOOR
	var door := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(hd.x, 1, house.end.y + 4), Vector3(hd.x, 1, house.end.y - 3)))
	check(door.is_empty(), "the crusher house's door is open to the front strip: %s" % door.get("position", ""))
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(house.end.x + 3, 1, house.get_center().y), Vector3(house.end.x - 3, 1, house.get_center().y)))
	check(not wall.is_empty(), "the crusher house has walls")
	var through := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(48.5, 1, 0), Vector3(52.5, 1, 0)))
	check(through.is_empty(), "Pre-assembly's east door leads into it: %s" % through.get("position", ""))
	check(house.encloses(Rect2(CrusherPlant.BAY.position.x, CrusherPlant.BAY.position.y, CrusherPlant.BAY.size.x, CrusherPlant.BAY.size.y)), "the crusher plant is inside it")
