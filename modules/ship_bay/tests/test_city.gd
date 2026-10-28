extends ModuleTest
## Ship and Bay: the city round the yard: works close in, towers out to the edge, avenues
## with lamps, traffic in the sky and on the avenues, all clear of the yard, its apron and
## the road west; windows light up at night and the traffic moves.
##   tools/run_tests.sh ship_bay

const City := preload("res://modules/ship_bay/internal/yard/yard_city.gd")


func run_tests() -> void:
	# The city is off by default (beenster, 0.3.27): without the flag the yard stands alone.
	var was := Flags.is_on("ship_bay.city")
	Flags.set_flag("ship_bay.city", false)
	var bare := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(bare)
	await frames(3)
	check(bare.get("city") == null, "with ship_bay.city off there is no city round the yard")
	bare.queue_free()
	await frames(2)
	Flags.set_flag("ship_bay.city", true)
	await _with_city()
	Flags.set_flag("ship_bay.city", was)


func _with_city() -> void:
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	var city: Node3D = yard.get("city")
	check(city != null, "the yard has a city round it")
	if city == null:
		yard.queue_free()
		return
	var n: Dictionary = city.call("counts")
	check(int(n.get("tower", 0)) > 1000 and int(n.get("shed", 0)) > 20 and int(n.get("crane", 0)) > 20 and int(n.get("stack", 0)) > 10,
			"towers, sheds, rival yards' cranes and stacks: %s" % n)
	check(int(n.get("cars", 0)) > 300 and int(n.get("trucks", 0)) > 10 and int(n.get("ships", 0)) >= 3, "and busy with traffic: %s" % n)

	# Nothing stands in the yard, on its apron or on the road west.
	# (Read from the city's own lists: a headless run's multimeshes keep no transforms.)
	var bad := 0
	var batches: Dictionary = city.get("_batches")
	for key: String in ["tower", "shed", "crane", "tank", "stack"]:
		for xf: Transform3D in batches.get(key, {}).get("xforms", []):
			var p := xf.origin
			if City.KEEP_OUT.has_point(Vector2(p.x, p.z)) or (p.x < City.KEEP_OUT.position.x and absf(p.z - City.ROAD_Z) < City.ROAD_HALF):
				bad += 1
	check(bad == 0, "the yard, its apron and the road west are clear: %d in the way" % bad)
	var space := yard.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-205, 1.0, City.ROAD_Z), Vector3(-1000, 1.0, City.ROAD_Z)))
	check(hit.is_empty() or hit.position.x < -1000.0, "nothing solid across the road west: %s" % hit.get("position", "clear"))

	# Night lights the windows; the traffic moves.
	city.call("set_night", 0.0)
	var mat := (city.get_node("tower") as MultiMeshInstance3D).material_override as StandardMaterial3D
	var day := mat.emission_energy_multiplier
	city.call("set_night", 1.0)
	check(mat.emission_energy_multiplier > day + 0.2, "windows light up at night: %.2f -> %.2f" % [day, mat.emission_energy_multiplier])
	var car: Dictionary = (city.get("cars") as Array)[0]
	var truck: Dictionary = (city.get("trucks") as Array)[0]
	var before := [float(car["a"]), float(truck["s"])]
	for i in 30:
		await get_tree().process_frame
	check(absf(float(car["a"]) - before[0]) > 0.001 and absf(float(truck["s"]) - before[1]) > 0.1, "the hover cars fly their lanes and the trucks drive")
	yard.queue_free()
	await frames(1)
	(Modules.bus("ship_bay") as ShipBayBus).unload_ship()
