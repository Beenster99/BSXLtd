extends ModuleTest
## The orbital yard's station and dock (Wave 1, stages 1.1 and 1.2): the rooms are there and
## walkable, the design room's shell is what the Design Room module builds on (its root, size,
## clear circle and stable wall spots), gravity holds inside and the dock is weightless, the
## airlock never opens both doors, the racking cranes bring a load to a port and take it back,
## and the dock has one build berth and two holding berths.
##   tools/run_tests.sh yard


func run_tests() -> void:
	for f: String in [YardBus.FLAG, YardBus.STATION, YardBus.DOCK, YardBus.RACKING]:
		Flags.set_flag(f, true)
	var bus := Modules.bus("yard") as YardBus
	if bus == null:
		bus = YardBus.new()
		bus.name = "yard"
		Modules.add_child(bus)
		bus.register_module()
	check(Router.has_scene(YardBus.SCENE), "the station is a scene")
	check(Menu.start().get("scene", "") == YardBus.SCENE, "Start goes to the orbital yard")
	var opened: Array = []
	bus.station_ready.connect(func(s: Node3D) -> void: opened.append(s))

	var station := (load(YardBus.SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child(station)
	await frames(3)
	check(opened.size() == 1 and opened[0] == station and bus.station() == station, "station_ready came with the station")

	_design_room(bus, station)
	await _gravity_and_walking(station)
	_airlock(station)
	await _racking(station)
	_dock(station)

	for id: String in station.get("VIEWS"):
		station.call("show_view", id)
		check((station.get("view_camera") as Camera3D).current, "view %s" % id)

	station.queue_free()
	await frames(2)
	check(bus.station() == null, "closed")


func _design_room(bus: YardBus, station: Node3D) -> void:
	var root := bus.design_room_root()
	check(root != null and root.position.is_equal_approx(YardBus.DESIGN_ROOM_CENTRE), "the design room's root at its floor centre")
	check(bus.design_room_size() == Vector3(24, 6, 18), "24 x 6 x 18 m")
	var box: AABB = YardLayout.ROOMS.design.box
	check(box.get_center().x == root.position.x and box.position.z + box.size.z * 0.5 == root.position.z, "the room box agrees")
	var ids: PackedStringArray = []
	for m: Dictionary in bus.design_room_mounts():
		ids.append(m.id)
		var t: Transform3D = m.transform
		var at := root.position + t.origin
		check(box.grow(0.01).has_point(at), "%s is on the design room's wall" % m.id)
		# Its -Z points into the room.
		var into := at - t.basis.z * 1.0
		check(box.has_point(into), "%s faces into the room" % m.id)
	check(ids == PackedStringArray(["tv_left_1", "tv_right_1", "tv_left_2", "tv_right_2", "tv_left_3", "tv_right_3", "whiteboard"]),
			"stable mount ids")
	# Nothing solid in the holotable's circle: a ray straight down lands on the floor.
	var space := station.get_world_3d().direct_space_state
	var clear := true
	for i in 12:
		var a := TAU * i / 12.0
		for r: float in [0.0, 1.5, YardBus.DESIGN_CLEAR_RADIUS - 0.1]:
			var p := root.position + Vector3(cos(a) * r, 5.5, sin(a) * r)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 6.0))
			clear = clear and not hit.is_empty() and absf((hit.position as Vector3).y) < 0.01
	check(clear, "the holotable circle is clear down to the floor")
	check(station.get_node_or_null("DesignRoomRoot/HoloCircle") != null, "the circle is marked")


func _gravity_and_walking(station: Node3D) -> void:
	for id: String in ["design", "corridor", "racking", "contracts", "crew", "airlock"]:
		var c: Vector3 = (YardLayout.ROOMS[id].box as AABB).get_center()
		check(YardLayout.room_at(c) == id and YardLayout.has_gravity(c), "%s has gravity" % id)
	check(not YardLayout.has_gravity(Vector3(-45, 1, -2)), "past the airlock it is weightless")
	check(not YardLayout.has_gravity(Vector3(0, -3, -85)), "the build berth is weightless")
	check(YardLayout.room_at(Vector3(0, 0, -85)) == "", "the dock is in no room")

	var mover := station.get("mover") as CharacterBody3D
	check(mover.get("in_gravity") == true, "you start with your feet on the deck")
	await frames(20)
	check(mover.is_on_floor() and absf(mover.position.y) < 0.1, "standing on the corridor floor")
	var start := mover.position
	mover.call("place", start, start + Vector3(10, 0, 0))
	Input.action_press(Keys.FORWARD)
	await frames(40)
	Input.action_release(Keys.FORWARD)
	check(mover.position.x - start.x > 0.5 and absf(mover.position.y) < 0.1, "walked along the corridor (%.2f m)" % (mover.position.x - start.x))
	# A screen holding the mouse (a console) keeps you still.
	HudSlots.claim_pointer("yard.test")
	var held_at := mover.position
	Input.action_press(Keys.FORWARD)
	await frames(30)
	Input.action_release(Keys.FORWARD)
	HudSlots.release_pointer("yard.test")
	check(mover.position.distance_to(held_at) < 0.05, "no walking while a screen has the mouse")
	var wall_test := mover.position
	mover.call("place", Vector3(4.0, 0.0, -1.5), Vector3(4.0, 1.5, 10.0))
	Input.action_press(Keys.FORWARD)
	await frames(90)
	Input.action_release(Keys.FORWARD)
	check(mover.position.z < 0.0, "the corridor wall stops you (z %.2f)" % mover.position.z)

	# Out in the dock: no gravity, the suit flies.
	mover.call("place", Vector3(-60, 0, -30), Vector3(-60, 0, -80))
	await frames(5)
	check(mover.get("in_gravity") == false, "weightless outside")
	var y0 := mover.position.y
	Input.action_press(Keys.FORWARD)
	await frames(40)
	Input.action_release(Keys.FORWARD)
	check(mover.velocity.z < -0.3, "thrust carries you forward (%.2f m/s)" % mover.velocity.z)
	check(absf(mover.position.y - y0) < 0.2, "and you do not fall")
	mover.call("place", wall_test, wall_test + Vector3.RIGHT)


func _airlock(station: Node3D) -> void:
	var lock := station.get("airlock") as Node3D
	check(lock.get("state") == 0, "the airlock starts open to the corridor")
	lock.call("cycle", true)
	var both_open := false
	var steps := 0
	while lock.call("is_busy") and steps < 1000:
		lock.call("advance", 0.05)
		var o: Vector2 = lock.call("openness")
		both_open = both_open or (o.x > 0.0 and o.y > 0.0)
		steps += 1
	check(lock.get("state") == 1, "cycled out: the outer door is open")
	check(not both_open, "never both doors open")
	var o: Vector2 = lock.call("openness")
	check(o == Vector2(0, 1), "inner shut, outer open")
	var inner := lock.get("inner_door") as Node3D
	var outer := lock.get("outer_door") as Node3D
	check(absf(inner.position.z - -2.0) < 0.01 and outer.position.z > -0.5, "the doors moved to match")
	lock.call("cycle", true)
	check(not lock.call("is_busy"), "asking for the open door again does nothing")
	lock.call("toggle")
	while lock.call("is_busy") and steps < 2000:
		lock.call("advance", 0.05)
		steps += 1
	check(lock.get("state") == 0, "and back in")


func _racking(station: Node3D) -> void:
	var hall := station.get("racking") as Node3D
	check(hall != null, "the racking hall is built")
	var store := hall.get("store") as YardRackStore
	var bus := Modules.bus("yard") as YardBus
	check(bus.rack_store == store, "the bus holds the hall's store")
	for size in 3:
		check((hall.get("load_meshes")[size] as MultiMeshInstance3D).multimesh.instance_count == store.slot_count(size),
				"a drawn place for every %s slot" % YardRackStore.SIZE_NAMES[size])
	var size := YardRackStore.SMALL
	check(hall.call("use_port", size) == "fetching", "F at the small port calls the crane")
	check(hall.call("use_port", size) == "busy", "and it is busy until done")
	var waited := 0.0
	while hall.call("busy") and waited < 15.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	check(not hall.call("busy"), "the crane finished (%.1f s)" % waited)
	var box := hall.get("port_boxes")[size] as Node3D
	check(box != null and box.position.distance_to(YardRackStore.PORTS[size]) < 0.6, "a tote stands at the port")
	check(hall.call("use_port", size) == "storing", "F again puts it away")
	waited = 0.0
	while hall.call("busy") and waited < 15.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	check(store.ports[size].is_empty() and hall.get("port_boxes")[size] == null, "the port is clear again")


func _dock(station: Node3D) -> void:
	var berths := YardBus.berths()
	check(berths.size() == 3, "three berths")
	check(berths.filter(func(b: Dictionary) -> bool: return b.kind == "build").size() == 1, "one build berth")
	check(berths.filter(func(b: Dictionary) -> bool: return b.kind == "holding").size() == 2, "two holding berths")
	var dock := station.get("dock") as Node3D
	check(dock != null, "the dock is built")
	for b: Dictionary in berths:
		check((dock.get("berth_nodes") as Dictionary).has(b.id), "berth %s drawn" % b.name)
		var box: AABB = b.box
		check(not box.intersects(YardLayout.HULL_BOX), "berth %s is clear of the station" % b.name)
		for other: Dictionary in berths:
			if other.id != b.id:
				check(not box.intersects(other.box), "berths %s and %s do not overlap" % [b.name, other.name])
	var lights := dock.find_children("*", "SpotLight3D", true, false)
	check(lights.size() >= 12, "the berths are floodlit")
	# The build berth is seen from the design room's window.
	var space := station.get_world_3d().direct_space_state
	var eye := Vector3(0, 1.7, -20)
	var berth_mid: Vector3 = (berths[0].box as AABB).get_center()
	var q := PhysicsRayQueryParameters3D.create(eye, eye + (berth_mid - eye).normalized() * 30.0)
	var hit := space.intersect_ray(q)
	check(not hit.is_empty() and absf((hit.position as Vector3).z - -22.0) < 0.2, "the build berth is in view through the design room's window")
