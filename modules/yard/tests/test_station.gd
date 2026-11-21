extends ModuleTest
## The orbital yard's station and dock (Wave 1, stages 1.1 and 1.2): the rooms are there and
## walkable, the design room's shell is what the Design Room module builds on (its root, size,
## clear circle and stable wall spots), gravity holds inside and the dock is weightless, the
## airlock never opens both doors, the stores hall holds real parts on solid racks, open to the yard,
## and the dock has one build berth and two holding berths.
##   tools/run_tests.sh yard


const DockScript := preload("res://modules/yard/internal/dock.gd")
const YardWorkersScript := preload("res://modules/yard/internal/yard_workers.gd")
const YardServiceScript := preload("res://modules/yard/internal/yard_service.gd")

func run_tests() -> void:
	for f: String in [YardBus.FLAG, YardBus.STATION, YardBus.DOCK, YardBus.RACKING, YardBus.AIRLOCK_DETAIL]:
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
	_design_lock(station)
	_room_detail(station)
	_furniture(station)
	_frame_rate(station)
	await _racking(station)
	await _dock(station)

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
	# Its walls as whole planes for screens: on a wall, facing in, nothing of the station's in
	# front of them (rays from 0.3 m out land on the plane).
	var wall_ids: PackedStringArray = []
	var space0 := station.get_world_3d().direct_space_state
	for w: Dictionary in YardBus.design_room_walls():
		wall_ids.append(w.id)
		var t: Transform3D = Transform3D(Basis.IDENTITY, root.position) * (w.transform as Transform3D)
		var size: Vector2 = w.size
		check(box.grow(0.01).has_point(t.origin) and box.has_point(t.origin - t.basis.z), "%s on a wall, facing in" % w.id)
		var bare := true
		for u: float in [-0.45, 0.0, 0.45]:
			for v: float in [-0.45, 0.0, 0.45]:
				var on := t * Vector3(u * size.x, v * size.y, 0.0)
				var from := on - t.basis.z * 0.3
				var hit := space0.intersect_ray(PhysicsRayQueryParameters3D.create(from, on + t.basis.z * 0.2))
				bare = bare and not hit.is_empty() and (hit.position as Vector3).distance_to(on) < 0.1
		check(bare, "%s is bare" % w.id)
	check(wall_ids == PackedStringArray(["wall_left", "wall_right", "wall_back_low_left", "wall_back_low_right", "wall_back_high"]),
			"stable wall ids")
	# Nothing solid of the yard's in the holotable's circle: a ray straight down lands on the
	# floor (the design room's own furniture, the holotable itself, stands there by right).
	var space := station.get_world_3d().direct_space_state
	var furnished: Array[RID] = []
	var furnishing := station.find_child("DesignFurnishing", true, false)
	if furnishing:
		for n: Node in furnishing.find_children("*", "CollisionObject3D", true, false):
			furnished.append((n as CollisionObject3D).get_rid())
	var clear := true
	for i in 12:
		var a := TAU * i / 12.0
		for r: float in [0.0, 1.5, YardBus.DESIGN_CLEAR_RADIUS - 0.1]:
			var p := root.position + Vector3(cos(a) * r, 5.5, sin(a) * r)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 6.0, 0xFFFFFFFF, furnished))
			clear = clear and not hit.is_empty() and absf((hit.position as Vector3).y) < 0.01
	check(clear, "the holotable circle is clear down to the floor")
	check(station.get_node_or_null("DesignRoomRoot/HoloCircle") != null, "the circle is marked")


func _gravity_and_walking(station: Node3D) -> void:
	for id: String in ["design", "corridor", "racking", "contracts", "crew", "quarters", "airlock", "design_lock"]:
		var c: Vector3 = (YardLayout.ROOMS[id].box as AABB).get_center()
		check(YardLayout.room_at(c) == id and YardLayout.has_gravity(c), "%s has gravity" % id)
	check(not YardLayout.has_gravity(Vector3(-45, 1, -2)), "past the airlock it is weightless")
	check(not YardLayout.has_gravity(Vector3(0, -3, -85)), "the build berth is weightless")
	check(YardLayout.room_at(Vector3(0, 0, -85)) == "", "the dock is in no room")

	var rig := station.get("mover") as YardRig
	check(rig != null and rig.in_gravity, "you start with your feet on the deck")
	await physics_steps(30)
	check(rig.on_deck() and rig.grounded() and absf(rig.feet().y) < 0.1, "standing on the corridor floor (feet at %.2f)" % rig.feet().y)
	var start := rig.feet()
	rig.place(start, start + Vector3(10, 0, 0))
	await physics_steps(2)
	Input.action_press(Keys.FORWARD)
	await physics_steps(40)
	Input.action_release(Keys.FORWARD)
	check(rig.feet().x - start.x > 0.5 and absf(rig.feet().y) < 0.1, "walked along the corridor (%.2f m)" % (rig.feet().x - start.x))
	await physics_steps(30)
	check(rig.linear_velocity.length() < 0.3, "the boots grip and you stop (%.2f m/s)" % rig.linear_velocity.length())
	# The mouse turns you round on a deck and tilts only the head.
	var pitch0 := rig.head.rotation.x
	rig.look(Vector2(-200, -100))
	await physics_steps(20)
	check(rig.head.rotation.x - pitch0 > 0.15 and absf(rig.global_basis.y.dot(Vector3.UP) - 1.0) < 0.01,
			"looking up tilts the head, the body stays upright")
	# Walking and turning together (0.4.3 playtest: "my character sways a bit when walking and
	# turning"): the body, and so the view, stays upright the whole way.
	rig.place(rig.feet(), rig.feet() + Vector3(10, 0, 0))
	await physics_steps(2)
	var sway := 0.0
	Input.action_press(Keys.FORWARD)
	Input.action_press(Keys.RUN)
	for i in 90:
		rig.look(Vector2(40.0 if (i / 30) % 2 == 0 else -60.0, 0.0))
		await physics_steps(1)
		sway = maxf(sway, rad_to_deg(acos(clampf(rig.global_basis.y.dot(Vector3.UP), -1.0, 1.0))))
	Input.action_release(Keys.FORWARD)
	Input.action_release(Keys.RUN)
	for i in 30:
		await physics_steps(1)
		sway = maxf(sway, rad_to_deg(acos(clampf(rig.global_basis.y.dot(Vector3.UP), -1.0, 1.0))))
	print("  sway walking and turning: %.3f deg" % sway)
	check(sway < 0.05, "walking and turning, no sway (%.3f deg)" % sway)
	rig.place(Vector3(4.0, 0.0, -1.5), Vector3(10.0, 1.5, -1.5))
	await physics_steps(5)
	# A screen holding the mouse (a console) keeps you still.
	HudSlots.claim_pointer("yard.test")
	var held_at := rig.feet()
	Input.action_press(Keys.FORWARD)
	await physics_steps(30)
	Input.action_release(Keys.FORWARD)
	HudSlots.release_pointer("yard.test")
	check(rig.feet().distance_to(held_at) < 0.05, "no walking while a screen has the mouse")
	var wall_test := rig.feet()
	rig.place(Vector3(4.0, 0.0, -1.5), Vector3(4.0, 1.5, 10.0))
	await physics_steps(2)
	Input.action_press(Keys.FORWARD)
	await physics_steps(90)
	Input.action_release(Keys.FORWARD)
	check(rig.feet().z < 0.0, "the corridor wall stops you (z %.2f)" % rig.feet().z)
	# The design room's stair takes you up to the mezzanine (0.4.0 playtest).
	rig.place(Vector3(-3.6, 0.0, -8.75), Vector3(-12.0, 1.5, -8.75))
	await physics_steps(10)
	Input.action_press(Keys.FORWARD)
	var climbed := 0.0
	for i in 12:
		await physics_steps(20)
		climbed = maxf(climbed, rig.feet().y)
		if rig.feet().x < -10.6:
			break
	Input.action_release(Keys.FORWARD)
	check(climbed > YardBus.DESIGN_MEZZANINE_Y - 0.15, "up the stair to the mezzanine (feet at %.2f)" % climbed)
	rig.place(Vector3(-11.2, YardBus.DESIGN_MEZZANINE_Y, -8.75), Vector3(-11.2, 4.5, 0.0))
	await physics_steps(10)
	Input.action_press(Keys.FORWARD)
	await physics_steps(60)
	Input.action_release(Keys.FORWARD)
	check(rig.feet().z > -8.0 and rig.feet().y > YardBus.DESIGN_MEZZANINE_Y - 0.1, "and on along it (z %.2f, feet at %.2f)" % [rig.feet().z, rig.feet().y])
	rig.place(Vector3(0.0, YardBus.DESIGN_MEZZANINE_Y, -6.0), Vector3(0.0, 4.5, -20.0))
	await physics_steps(10)
	Input.action_press(Keys.FORWARD)
	await physics_steps(90)
	Input.action_release(Keys.FORWARD)
	check(rig.feet().z > -8.0 and rig.feet().y > YardBus.DESIGN_MEZZANINE_Y - 0.1, "its rail keeps you on it (z %.2f)" % rig.feet().z)

	# Your own body: the Void Salvage suit, seen in first person only as forearms.
	var body := rig.get_node_or_null("Avatar") as YardAvatar
	check(body != null and body.joints.has("forearm_R") and body.joints.has("head"), "you wear the suit's jointed body")
	if body:
		var seen := 0
		for n in body.find_children("*", "GeometryInstance3D", true, false):
			if YardAvatar.drawn(n as GeometryInstance3D):
				seen += 1
		check(seen > 0, "your forearms are drawn in first person (%d pieces)" % seen)

	# Out in the dock: no gravity, the suit flies.
	rig.place(Vector3(-60, 0, -30), Vector3(-60, 0, -80))
	await physics_steps(5)
	check(not rig.in_gravity and not rig.on_deck(), "weightless outside")
	var y0 := rig.global_position.y
	Input.action_press(Keys.FORWARD)
	await physics_steps(40)
	Input.action_release(Keys.FORWARD)
	check(rig.linear_velocity.z < -0.3, "thrust carries you forward (%.2f m/s)" % rig.linear_velocity.z)
	check(absf(rig.global_position.y - y0) < 0.3, "and you do not fall")
	check(rig.glide > 0.3, "holding forward you lay out in the glide (%.2f)" % rig.glide)
	await physics_steps(80)
	check(rig.linear_velocity.length() < 0.3, "the dampeners stop your drift (%.2f m/s)" % rig.linear_velocity.length())
	check(rig.glide > 0.9, "the glide holds till you pull back")
	Input.action_press(Keys.BACK)
	await physics_steps(3)
	Input.action_release(Keys.BACK)
	await physics_steps(30)
	check(rig.glide < 0.1, "pulling back stands you up again")
	# The mouse turns the whole body after it, at the gyros' pace.
	var facing := -rig.global_basis.z
	rig.look(Vector2(-300, 0))
	await physics_steps(60)
	check((-rig.global_basis.z).angle_to(facing) > 0.4, "the gyros turn you to the look (%.2f rad)" % (-rig.global_basis.z).angle_to(facing))
	Input.action_press("yard.roll_left")
	await physics_steps(20)
	Input.action_release("yard.roll_left")
	check(absf(rig.global_basis.y.dot(Vector3.UP)) < 0.99, "Q rolls you")
	# Back through the airlock: the station's gravity takes you, upright, the head keeping the look.
	var lock := station.get("airlock") as Node3D
	lock.call("cycle", true)
	for i in 1000:
		if not lock.call("is_busy"):
			break
		lock.call("advance", 0.05)
	rig.place(Vector3(-36.5, 0.2, -2.0), Vector3(-30, 1.5, -2.0))
	await physics_steps(30)
	check(rig.on_deck() and rig.grounded(), "inside the airlock you stand on its floor")
	rig.place(Vector3(-46, 0.5, -2.0), Vector3(-30, 1.5, -2.0))
	await physics_steps(3)
	check(not rig.on_deck(), "past the outer door you float")
	Input.action_press(Keys.FORWARD)
	Input.action_press(Keys.RUN)
	var crossed := false
	for i in 240:
		await physics_steps(1)
		if rig.on_deck():
			crossed = true
			break
	Input.action_release(Keys.FORWARD)
	Input.action_release(Keys.RUN)
	check(crossed and absf(rig.global_basis.y.dot(Vector3.UP) - 1.0) < 0.05, "flying in through the airlock you land on your feet")
	lock.call("cycle", false)
	for i in 1000:
		if not lock.call("is_busy"):
			break
		lock.call("advance", 0.05)
	rig.place(wall_test, wall_test + Vector3.RIGHT)
	await physics_steps(5)


## `n` physics steps.
func physics_steps(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _airlock(station: Node3D) -> void:
	var lock := station.get("airlock") as Node3D
	check(lock.get("state") == 0, "the airlock starts open to the corridor")
	# Its panels (21 Nov): a housing on the wall, a lit button facing out, a screen with its state.
	var panels_ok := true
	for where: String in ["corridor", "inside", "outside"]:
		var p := lock.get_node_or_null("Panel_" + where) as Node3D
		var button := p.get_node_or_null("Button") as MeshInstance3D if p else null
		var status := p.get_node_or_null("Status") as Label3D if p else null
		panels_ok = panels_ok and button != null and status != null and status.text == "READY"
		if button != null:
			# The button stands out of the wall it is on, into the room the panel faces.
			var out := button.global_basis.y.normalized()
			panels_ok = panels_ok and absf(absf(out.dot(p.global_basis.x)) - 1.0) < 0.01
	check(panels_ok, "each airlock panel has a lit button and a status screen reading READY")
	check(lock.get_node_or_null("../AirlockGauges") != null or station.find_children("AirlockGauges", "", true, false).size() > 0,
			"the airlock has its pressure board")
	lock.call("cycle", true)
	var both_open := false
	var pumping_shown := false
	var steps := 0
	while lock.call("is_busy") and steps < 1000:
		lock.call("advance", 0.05)
		var o: Vector2 = lock.call("openness")
		both_open = both_open or (o.x > 0.0 and o.y > 0.0)
		var screen := lock.get_node("Panel_inside/Status") as Label3D
		pumping_shown = pumping_shown or (int(lock.get("state")) == 3 and screen.text == "PUMPING")
		steps += 1
	check(pumping_shown, "the panels' screens say PUMPING while it pumps")
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


## The design room's own lock to the dock (0.4.0 playtest): cycles like the main one, its doors
## lifting into the wall.
func _design_lock(station: Node3D) -> void:
	var lock := station.get("design_lock") as Node3D
	check(lock != null and lock.get("state") == 0, "the design room's lock starts open to the room")
	var inner := lock.get("inner_door") as Node3D
	var outer := lock.get("outer_door") as Node3D
	var h := YardLayout.DESIGN_LOCK_DOOR_H
	check(inner.position.y > h and absf(outer.position.y - h * 0.5) < 0.01, "inner door up, outer door down")
	check(absf(inner.position.z - YardLayout.DESIGN_LOCK_INNER_Z) < 0.01 and absf(outer.position.z - YardLayout.DESIGN_LOCK_OUTER_Z) < 0.01,
			"its doors sit in the window wall and the outer wall")
	lock.call("cycle", true)
	var both_open := false
	var steps := 0
	while lock.call("is_busy") and steps < 1000:
		lock.call("advance", 0.05)
		var o: Vector2 = lock.call("openness")
		both_open = both_open or (o.x > 0.0 and o.y > 0.0)
		steps += 1
	check(lock.get("state") == 1 and not both_open, "it cycles out, never both doors open")
	check(absf(inner.position.y - h * 0.5) < 0.01 and outer.position.y > h, "inner door down, outer door up")
	var mid := Vector3((YardLayout.DESIGN_LOCK_DOOR_X.x + YardLayout.DESIGN_LOCK_DOOR_X.y) * 0.5, 1.0, -23.5)
	check(YardLayout.room_at(mid) == "design_lock", "the lock is a room of its own")
	lock.call("toggle")
	while lock.call("is_busy") and steps < 2000:
		lock.call("advance", 0.05)
		steps += 1
	check(lock.get("state") == 0, "and back in")
	# Its call button is off the wall screens (0.4.6 playtest: "the button is on the screen").
	var call := lock.get_node_or_null("Panel_corridor") as Node3D
	var clear := call != null
	if call != null:
		var at := call.global_position - YardBus.DESIGN_ROOM_CENTRE
		for w: Dictionary in YardBus.design_room_walls():
			var local: Vector3 = (w.transform as Transform3D).affine_inverse() * at
			var size: Vector2 = w.size
			if absf(local.z) < 0.4 and absf(local.x) < size.x * 0.5 + 0.15 and absf(local.y) < size.y * 0.5 + 0.15:
				clear = false
		clear = clear and YardLayout.room_at(call.global_position + call.global_basis.x * 0.3) == "design"
	check(clear, "the lock's call button is in the design room, off its wall screens")


## The rooms dressed to Void Salvage's standard (beenster, 20 Nov): a few merged meshes with no
## collision, nothing in a doorway, nothing over a button.
func _room_detail(station: Node3D) -> void:
	var rd: RefCounted = station.get("room_detail")
	var node := station.get_node_or_null("RoomDetail")
	check(rd != null and node != null, "the rooms get their detail pass")
	if rd == null or node == null:
		return
	var dm: RefCounted = rd.get("dm")
	var boxes: Array[AABB] = dm.get("boxes")
	check(boxes.size() > 2000 and node.get_child_count() < 300 and node.find_children("*", "CollisionShape3D").is_empty(),
			"thousands of fittings in a few hundred meshes, none solid (%d in %d)" % [boxes.size(), node.get_child_count()])
	var blocked := []
	for w: Dictionary in (station.get("kit") as RefCounted).get("walls"):
		for g: Array in w.gaps:
			if g.size() > 3 and float(g[3]) > 0.0:
				continue   # a window
			var t := float(w.thick) * 0.5 + 0.4
			var a := float(g[0]) + 0.02
			var b := float(g[1]) - 0.02
			var y1 := float(w.y0) + float(g[2]) - 0.02
			var door := AABB(Vector3(a, float(w.y0) + 0.01, float(w.at) - t), Vector3(b - a, y1 - float(w.y0), t * 2.0)) if w.along_x \
					else AABB(Vector3(float(w.at) - t, float(w.y0) + 0.01, a), Vector3(t * 2.0, y1 - float(w.y0), b - a))
			for box: AABB in boxes:
				if box.intersects(door):
					blocked.append([door, box])
					break
	check(blocked.is_empty(), "no fitting stands in a doorway %s" % [blocked])
	var covered := []
	for area: Node in station.get_tree().get_nodes_in_group("gfx_interactable"):
		if not (area is Area3D) or not station.is_ancestor_of(area):
			continue
		var at := (area as Node3D).global_position
		for box: AABB in boxes:
			if box.grow(0.03).has_point(at):
				covered.append(area.name)
				break
	check(covered.is_empty(), "no fitting covers a button %s" % [covered])


## The crew room and the contracts desk in Void Salvage's own furniture: every piece inside its
## room, none in another's place, the mugs on the tables, the desk still taking contracts.
func _furniture(station: Node3D) -> void:
	var f: RefCounted = station.get("furniture")
	check(f != null, "the crew room and contracts desk are furnished")
	if f == null:
		return
	var placed: Array[Node3D] = f.get("placed")
	var boxes: Array[AABB] = []
	var outside := []
	for n: Node3D in placed:
		var b := _world_box(n)
		boxes.append(b)
		var room := YardLayout.room_at(b.get_center())
		var rb: AABB = YardLayout.ROOMS[room].box if room != "" else AABB()
		var inside := room != "" and b.position.x > rb.position.x + 0.09 and b.end.x < rb.end.x - 0.09 \
				and b.position.z > rb.position.z + 0.09 and b.end.z < rb.end.z - 0.09
		if not inside:
			outside.append("%s %s" % [n.name, b])
	check(placed.size() >= 25 and outside.is_empty(), "%d pieces, each inside its room %s" % [placed.size(), outside])
	var clash := []
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if boxes[i].grow(-0.02).intersects(boxes[j].grow(-0.02)):
				clash.append("%s/%s" % [placed[i].name, placed[j].name])
	check(clash.is_empty(), "no two pieces stand in one place %s" % [clash])
	check(station.get_node_or_null("Use_contract") != null, "the desk still takes contracts")
	# Each faces the way its room wants (0.5.1 playtest: "some of the furniture is the wrong way
	# around"; Void Salvage's parts face -Z): lockers into the room, the galley off its wall, the
	# desk's seats at the desk, the visitors' at it from the front.
	var wrong := []
	for n: Node3D in placed:
		var front := -n.global_basis.z
		var id := String(n.name).get_slice("_", 0)
		var p := n.global_position
		var ok := true
		match id:
			"Locker": ok = front.x < -0.9                       # on the east wall
			"GalleyCounter", "JunctionBox": ok = front.z > 0.9  # off the corridor wall
			"MediaWall": ok = front.x > 0.9                     # on the west wall
			"Seat": ok = front.z < -0.9 if p.z > 5.8 else front.z > 0.9
			"CornerSofa": ok = front.z > 0.9                    # facing the window
		if not ok:
			wrong.append("%s %s" % [n.name, front.snapped(Vector3.ONE * 0.01)])
	check(wrong.is_empty(), "each piece faces into its room %s" % [wrong])
	# The quarters' desk seats face their desks.
	var turned := []
	for n: Node in station.find_children("Seat_*", "Node3D", true, false):
		var s := n as Node3D
		if YardLayout.room_at(s.global_position + Vector3(0, 0.3, 0)) == "quarters" and (-s.global_basis.z).x > -0.9:
			turned.append(s.name)
	check(turned.is_empty(), "the cabins' seats face their desks %s" % [turned])


## What the 0.5.1 playtest's 40 fps in the quarters came from: every room's fill light cast
## shadows at High (87 of them), and everything in the station threw a sun shadow.
func _frame_rate(station: Node3D) -> void:
	var fills := station.find_children("Bounce_*", "OmniLight3D", true, false)
	check(fills.size() > 20 and fills.all(func(l: Node) -> bool: return l.has_meta("gfx_no_shadow")), "no fill light casts a shadow (%d)" % fills.size())
	var lit := 0
	var bunks := station.find_children("Bunk_*", "Node3D", true, false)
	for b: Node in bunks:
		for m: Node in b.find_children("*", "GeometryInstance3D", true, false) + ([b] if b is GeometryInstance3D else []):
			if (m as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				lit += 1
	check(bunks.size() == 8 and lit == 0, "what stands in a closed room throws no sun shadow (%d)" % lit)
	var walls_cast := 0
	for m: Node in station.find_children("*", "MeshInstance3D", false, false):
		var g := m as MeshInstance3D
		var b := g.global_transform * g.get_aabb()
		if b.size.y > 2.5 and b.size.x < 0.3 and YardLayout.room_at(b.get_center() + Vector3(0.4, 0, 0)) == "quarters" and g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			walls_cast += 1
	check(walls_cast > 0, "its walls still keep the sun out (%d)" % walls_cast)


func _world_box(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: Node in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b := m.global_transform * m.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## The berths grow with reputation (beenster, 19 Nov): three tiers, each clear of the station,
## of each other, of the keel the bots build and of TartanCo's berth; the dock rebuilt at each.
func _berth_tiers(station: Node3D) -> void:
	check(YardLayout.berth_tier_for(0.0) == 1 and YardLayout.berth_tier_for(40.0) == 2 and YardLayout.berth_tier_for(100.0) == 4,
			"the tier follows reputation, the largest at the max")
	var service_ship := AABB(YardServiceScript.BERTH - Vector3(40, 6, 7), Vector3(80, 12, 14))
	for t: Dictionary in YardBus.berth_tiers():
		var tier := int(t.tier)
		var berths := YardBus.berths(tier)
		var build: AABB = berths[0].box
		var ok := true
		for b: Dictionary in berths:
			var box: AABB = b.box
			ok = ok and not box.intersects(YardLayout.HULL_BOX) and not box.intersects(service_ship)
			for other: Dictionary in berths:
				ok = ok and (other.id == b.id or not box.intersects(other.box))
			for h: Vector3 in YardRackStore.HAULER_BERTHS:
				ok = ok and not box.grow(6.0).has_point(h)
		ok = ok and build.end.z <= YardLayout.BERTH_FACE_Z + 0.01 and build.position.z >= YardLayout.DOCK_FAR_Z - 0.01
		check(ok, "tier %d: berths clear of the station, each other, TartanCo's ship and the haulers" % tier)
		check(build.has_point(YardWorkersScript.KEEL_START) and is_equal_approx(build.size.x, (t.size as Vector3).x),
				"tier %d: the keel is in the %d m build berth" % [tier, int(build.size.x)])
		check(is_equal_approx((berths[1].box as AABB).size.x, build.size.x), "tier %d: a parked hull fits a holding berth" % tier)
		# The worker bots' charge docks sit on the build berth's ribs (20 Nov: "these recharge bays
		# should be mounted to the frame of the berth"), clear of each other and of the clamps.
		var docks := YardWorkersScript.docks_for(tier)
		var ribs := int(build.size.x / 10.0)
		var mounted := docks.size() == YardWorkersScript.MAX_BOTS
		var seen := {}
		for d: Vector3 in docks:
			var on_rib := false
			for i in range(1, ribs):
				on_rib = on_rib or absf(d.x - (build.position.x + build.size.x * float(i) / float(ribs))) < 0.01
			var clamps := [build.position.y + build.size.y * 0.3, build.position.y + build.size.y * 0.7]
			var clear := absf(d.y - float(clamps[0])) > 3.0 and absf(d.y - float(clamps[1])) > 3.0
			mounted = mounted and on_rib and clear and d.y > build.position.y + 2.5 and d.y < build.end.y - 2.5 \
					and absf(d.z - (build.end.z - 0.3)) < 0.01 and not seen.has(str(d))
			seen[str(d)] = true
		check(mounted, "tier %d: every charge dock on a rib of the build berth, clear of the clamps" % tier)
	check(YardBus.berth_tier_for_hull(Vector3(50, 20, 20)) == 1 and YardBus.berth_tier_for_hull(Vector3(90, 30, 30)) == 2
			and YardBus.berth_tier_for_hull(Vector3(190, 50, 50)) == 3 and YardBus.berth_tier_for_hull(Vector3(300, 50, 50)) == 4
			and YardBus.berth_tier_for_hull(Vector3(400, 50, 50)) == 0 and YardBus.berth_for(60.0) == 2,
			"which tier a hull needs, leaving the bots their room")
	var bus := Modules.bus("yard") as YardBus
	var b1: Dictionary = bus.build_berth()
	check(b1.has_all(["name", "tier", "length", "height", "beam"]) and float(b1.length) >= 60.0, "the build berth for the design room: %s" % str(b1))
	# The dock built again at the capital tier, and back.
	station.call("_on_berth_tier", 4)
	var dock := station.get("dock") as Node3D
	var spots := dock.find_children("*", "SpotLight3D", true, false).size()
	check(int(dock.get("tier")) == 4 and spots >= 24, "the dock rebuilt as giga berths, floodlit (%d)" % spots)
	var drawn := (dock.get("berth_nodes") as Dictionary)
	check(drawn.size() == 3, "all three berths drawn")
	var crew := station.get("workers") as Node
	check(crew.get("docks") == YardWorkersScript.docks_for(4) and (crew.get("charge_docks") as Node3D).get_child(0).position == YardWorkersScript.docks_for(4)[0],
			"the crew's docks moved to the giga berth's ribs")
	station.call("_on_berth_tier", 1)
	await frames(1)


func _racking(station: Node3D) -> void:
	var hall := station.get("racking") as Node3D
	check(hall != null, "the stores hall is built")
	var store := hall.get("store") as YardRackStore
	var bus := Modules.bus("yard") as YardBus
	check(bus.rack_store == store, "the bus holds the hall's store")
	# The roof's solar arrays stand clear of it (20 Nov: "some of the solar panels poke through
	# the roof of the warehouse").
	var roof_y := (YardLayout.ROOMS["racking"].box as AABB).end.y
	var arrays := 0
	var lowest := INF
	for n in station.get_children():
		if not str(n.name).begins_with("StoresSolar_"):
			continue
		arrays += 1
		for m in (n as Node3D).find_children("*", "MultiMeshInstance3D", true, false):
			var mmi := m as MultiMeshInstance3D
			var box := mmi.global_transform * mmi.multimesh.get_aabb()
			lowest = minf(lowest, box.position.y)
	# Nothing of the station's own stands in the upper deck's aisles (20 Nov: "some of the
	# corridors in the warehouse are blocked by these objects": old roof fins at 16 m).
	var in_aisle := 0
	for n in station.get_children():
		var mi := n as MeshInstance3D
		if mi == null or not mi.visible:
			continue
		var b := mi.global_transform * mi.get_aabb()
		if b.position.y < YardRackStore.UPPER_FLOOR_Y + 2.5 and b.end.y > YardRackStore.UPPER_FLOOR_Y + 0.3 \
				and b.position.x > 22.7 and b.end.x < 26.8 and b.position.z > -52.0 and b.end.z < -10.0:
			in_aisle += 1
	check(in_aisle == 0, "the upper deck's aisles are clear (%d in the way)" % in_aisle)
	check(arrays == 6 and lowest > roof_y + 0.3, "the roof's six solar arrays clear the roof (lowest %.2f m, roof %.2f m)" % [lowest, roof_y])
	# Real parts, not crates: every filled place drawn as its part, all of it inside its place.
	var expected := 0
	var fits := true
	var worst := ""
	for i in store.slots.size():
		if store.slots[i].part == "":
			continue
		var xforms: Array[Transform3D] = hall.call("item_transforms", i)
		expected += xforms.size()
		var room: AABB = (hall.call("slot_box", i) as AABB).grow(0.06)
		var look: Dictionary = (load("res://modules/yard/internal/yard_stock_look.gd")).look(store.slots[i].part)
		for t: Transform3D in xforms:
			var drawn: AABB = t * (look.mesh as Mesh).get_aabb()
			if not room.encloses(drawn):
				fits = false
				worst = "%s in place %d: %s outside %s" % [store.slots[i].part, i, drawn, room]
	check(expected > 400 and hall.call("drawn_count") == expected, "every part on the racks is drawn (%d)" % expected)
	check(fits, "every part lies inside its place %s" % worst)
	var kinds := {}
	for part: String in (hall.get("part_meshes") as Dictionary):
		kinds[YardRackStore.kind_of(part)] = true
	check(kinds.size() == 4, "long stock, plates, components and heavy parts are all on show")
	var vs_drawn := true
	for part: String in (hall.get("part_meshes") as Dictionary):
		var body: MultiMeshInstance3D = hall.get("part_meshes")[part].body
		vs_drawn = vs_drawn and body.material_override == VsParts.surface(part)
	check(vs_drawn, "the racks draw each part on Void Salvage's salvage surface")
	# No counters: nothing in the hall to press for a load.
	var uses := hall.find_children("Use_*", "Area3D", true, false)
	check(uses.is_empty(), "no ordering counters")
	# Five times the old hall (32 x 26 m), and open to the yard along its whole dock side.
	var box: AABB = YardLayout.ROOMS.racking.box
	check(box.size.x * box.size.z >= 5.0 * 32.0 * 26.0, "the hall is five times the old one (%.0f m2)" % (box.size.x * box.size.z))
	var space := station.get_world_3d().direct_space_state
	var open := true
	for x: float in [20.0, 40.0, 58.0, 76.0]:
		for y: float in [1.0, 6.0, 12.0]:
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, y, -58.0), Vector3(x, y, -69.0))
			if not space.intersect_ray(q).is_empty():
				open = false
	check(open, "the yard side is open from the floor to 12 m")
	check(YardLayout.has_gravity(Vector3(40, 1, -60)) and not YardLayout.has_gravity(Vector3(40, 1, -66)), "gravity stops at the open face")
	var q2 := PhysicsRayQueryParameters3D.create(Vector3(76, 3, -34), Vector3(110, 3, -34))
	check(space.intersect_ray(q2).is_empty(), "goods in opens to the haulers' berths")
	# Two storeys (0.4.1): a deck you stand on over the racks, open to the yard too, a well
	# over goods in from floor to roof, and a stair up beside it.
	var deck_y := YardRackStore.UPPER_FLOOR_Y
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(33.5, deck_y + 3.0, -30), Vector3(33.5, deck_y - 3.0, -30)))
	check(not down.is_empty() and absf((down.position as Vector3).y - deck_y) < 0.02, "the upper deck is a floor at %.0f m" % deck_y)
	check(YardLayout.has_gravity(Vector3(33.5, deck_y + 1.0, -30)), "with the station's gravity on it")
	var open_up := true
	for x: float in [20.0, 40.0, 58.0]:
		for y: float in [1.0, 6.0, 12.0]:
			open_up = open_up and space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, deck_y + y, -58.0), Vector3(x, deck_y + y, -69.0))).is_empty()
	check(open_up, "the upper storey is open to the yard as well")
	var well := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(74, 30.0, -34), Vector3(74, 0.5, -34)))
	check(well.is_empty(), "the well over goods in is open floor to roof")
	var stair_x := YardRackStore.UPPER_EDGE_X + 0.12 + 0.8
	var heights: Array[float] = []
	for z: float in [-8.0, -20.0, -32.0]:
		var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(stair_x, 20.0, z), Vector3(stair_x, -0.5, z)))
		heights.append((h.position as Vector3).y if not h.is_empty() else -1.0)
	check(heights[0] > 0.3 and heights[1] > heights[0] + 4.0 and heights[2] > heights[1] + 4.0 and heights[2] < deck_y,
			"a stair climbs to the deck beside the well %s" % str(heights))
	# A landing at its head (0.5.1 playtest: "missing landing at top of warehouse stairs"): floor
	# at the deck's height from the stair across to the deck's edge, past the top step.
	var landed := true
	for p: Vector2 in [Vector2(stair_x, -34.9), Vector2(YardRackStore.UPPER_EDGE_X + 0.05, -34.9), Vector2(stair_x, -35.6)]:
		var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, deck_y + 1.0, p.y), Vector3(p.x, deck_y - 1.0, p.y)))
		landed = landed and not h.is_empty() and absf((h.position as Vector3).y - deck_y) < 0.02
	check(landed, "a landing at the stair's head, level with the deck")
	# The racks are solid: walking into one stops at its face.
	var q3 := PhysicsRayQueryParameters3D.create(Vector3(33.5, 1.0, -30), Vector3(42.5, 1.0, -30))
	var hit := space.intersect_ray(q3)
	check(not hit.is_empty() and absf((hit.position as Vector3).x - 35.65) < 0.1, "a plate rack stops you at its face")
	# Putting away and taking out redraws the racks.
	var before := int(hall.call("drawn_count"))
	var slot := store.store("Reactor", 1)
	check(slot >= 0, "a delivered reactor goes on a heavy cradle")
	await frames(2)
	check(int(hall.call("drawn_count")) == before + 1, "and is drawn there")
	check(store.take(slot, 1) == 1, "a bot takes it out")
	await frames(2)
	check(int(hall.call("drawn_count")) == before, "and it is gone from the rack")


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
	# Void Salvage's standard (yard.room_detail): fittings on every frame, none in a hull's way.
	var detail = dock.get("detail")
	if Flags.is_on(YardBus.ROOM_DETAIL):
		check(detail != null and int(detail.dm.count) > 3000, "the berths and arm carry their fittings (%d)" % (int(detail.dm.count) if detail != null else 0))
		var meshes := dock.find_children("Detail*", "MeshInstance3D", false, false).size()
		check(meshes > 0 and meshes < 200, "gathered into a few meshes (%d)" % meshes)
		var in_way := 0
		for b: Dictionary in berths:
			var keep := Vector3(1.0, 1.0, 3.6)
			var inner := AABB((b.box as AABB).position + keep, (b.box as AABB).size - keep * 2.0)
			for d: AABB in detail.dm.boxes:
				if d.intersects(inner):
					in_way += 1
		check(in_way == 0, "nothing reaches further into a berth than its clamp pads (%d)" % in_way)
	# The dock's two arms land on mount plates flush under the station (20 Nov: "please join the
	# design office properly to the berth").
	var feet := 0
	for foot: Vector3 in DockScript.ARM_FEET:
		for m in dock.find_children("*", "MeshInstance3D", true, false):
			var b := (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
			if absf(b.end.y - YardLayout.UNDERSIDE) < 0.02 and b.size.x >= 4.0 and b.has_point(Vector3(foot.x, b.get_center().y, foot.z)):
				# ...and the plate stays under a room's floor all round (0.5.1: it stood 0.4 m
				# below the floor and ran out past the design room's front).
				var c := b.get_center()
				var under := true
				for corner: Vector3 in [b.position, Vector3(b.end.x, c.y, b.end.z), Vector3(b.position.x, c.y, b.end.z), Vector3(b.end.x, c.y, b.position.z)]:
					if YardLayout.room_at(Vector3(corner.x + signf(c.x - corner.x) * 0.01, 1.0, corner.z + signf(c.z - corner.z) * 0.01)) == "":
						under = false
				if under:
					feet += 1
				break
	check(feet == DockScript.ARM_FEET.size(), "both dock arms bolted flat under the station (%d)" % feet)
	# Lived in: steam off the coffee, dust in the stores, a fan turning, a lamp that stutters.
	var lived := station.get_node_or_null("LivedIn")
	check(lived != null and lived.get_node_or_null("Steam") is CPUParticles3D and lived.get_node_or_null("Dust") is CPUParticles3D, "steam off the coffee machine and dust in the stores")
	var fan := lived.get_node("VentFan") as Node3D
	var turned := fan.rotation
	lived.call("_process", 0.5)
	check(not fan.rotation.is_equal_approx(turned), "the corridor's vent fan turns")
	# Worker bots at the keel frame in the build berth; K calls a mover with the next kit.
	var crew := station.get("workers") as Node3D
	check(crew != null and crew.call("foreman") != null and int(crew.call("rings_built")) >= 3, "worker bots at a keel frame in the build berth")
	var kit: String = station.call("call_kit")
	var note := station.get_node("Hud/KitNote") as Label
	for i in 60:   # on the shared clock: a tick or so later
		if note.visible:
			break
		await frames(1)
	check(YardKits.KITS.has(kit) and (station.get("traffic").get("kit_orders") as Array).size() >= 1, "K sends a mover bot with a %s" % kit)
	check(note.visible, "and says so on the HUD (%s, %s)" % [note.text, str(station.get("_note_left"))])
	# Sleeping quarters: eight cabins, each with Void Salvage's bunk, off the corridor.
	var bunks := station.find_children("Bunk_*", "Node3D", true, false)
	check(bunks.size() == 8, "eight cabins with a bunk each in the quarters (%d)" % bunks.size())
	var in_quarters := bunks.all(func(b: Node3D) -> bool: return YardLayout.room_at(b.global_position + Vector3(0, 0.3, 0)) == "quarters")
	check(in_quarters, "the bunks are in the sleeping quarters")
	var door_q := PhysicsRayQueryParameters3D.create(Vector3(32, 1.2, -2), Vector3(32, 1.2, 5.5))
	check(station.get_world_3d().direct_space_state.intersect_ray(door_q).is_empty(), "the quarters open off the corridor")
	# Floodlights on all eight corners of every berth, on yokes that turn to a new aim.
	var floods: Array = dock.get("floods")
	check(floods.size() == berths.size() * 8, "a floodlight on every corner of every berth (%d)" % floods.size())
	var low := floods.filter(func(f: Dictionary) -> bool: return (f.pan as Node3D).global_position.y < (berths[0].box as AABB).position.y + 1.0 and f.berth == "build_1")
	check(low.size() == 4, "the bottom corners have floods too")
	var f0: Dictionary = floods[0]
	var lens := func(f: Dictionary) -> Vector3: return -(f.spot as SpotLight3D).global_basis.z
	var home_dir: Vector3 = (f0.home - (f0.spot as SpotLight3D).global_position).normalized()
	check(lens.call(f0).dot(home_dir) > 0.97, "each flood is aimed at its berth's middle")
	var spot_at: Vector3 = (berths[0].box as AABB).position + Vector3(5, 5, 5)
	dock.call("aim_floods", f0.berth, spot_at)
	for i in 120:
		dock.call("_process", 0.05)
	var new_dir: Vector3 = (spot_at - (f0.spot as SpotLight3D).global_position).normalized()
	check(lens.call(f0).dot(new_dir) > 0.97, "the floods turn to a new aim")
	dock.call("aim_floods", f0.berth)
	# Solar arrays of Void Salvage's own panels on the roofs and the dock arm.
	var panels := 0
	for a: Node in station.find_children("*Solar*", "Node3D", true, false):
		panels += int(a.get_meta("panels", 0))
	check(panels >= 400, "hundreds of real solar panels (%d)" % panels)
	# The build berth is seen from the design room's window.
	var space := station.get_world_3d().direct_space_state
	var eye := Vector3(0, 1.7, -20)
	var berth_mid: Vector3 = (berths[0].box as AABB).get_center()
	var q := PhysicsRayQueryParameters3D.create(eye, eye + (berth_mid - eye).normalized() * 30.0)
	var hit := space.intersect_ray(q)
	check(not hit.is_empty() and absf((hit.position as Vector3).z - -22.0) < 0.2, "the build berth is in view through the design room's window")

	await _berth_tiers(station)
