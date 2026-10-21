extends ModuleTest
## Ship and Bay: the mobile scaffold rigs: their posts add and take away bays and lifts and
## open their ends, a change that would grow into something is refused, they drive in to the
## hull sideways and stop at it, and the ladder takes you up onto the top deck.
##   tools/run_tests.sh ship_bay


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	var scene := load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene
	var yard := scene.instantiate() as Node3D
	add_child(yard)
	await frames(3)
	for i in 3:
		await get_tree().physics_frame
	var access: Node3D = (yard.get("bay") as Node3D).get("access")
	var rigs: Array = access.get("scaffolds")
	check(rigs.size() == 2, "two scaffold rigs stand by the bay: %d" % rigs.size())
	if rigs.size() < 2:
		yard.queue_free()
		return
	var rig: Node3D = rigs[0]
	check(int(rig.get("bays")) == 2 and int(rig.get("lifts")) == 2 and is_equal_approx(float(rig.call("top")), 4.35),
			"each starts 2 bays long and 2 lifts high (top deck at %.2f m)" % rig.call("top"))
	var hull_x := 2.6
	check(rig.to_global(Vector3(0.8, 0, 0)).x > hull_x + 15.0, "parked off to the side of the yard, well clear of the ship")
	# Pushed over beside the ship to work on it (where it once parked).
	rig.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(7.6, 0, -1.0))
	for i in 3:
		await get_tree().physics_frame

	# The post's touch screen: its buttons change the rig.
	var screen: Node3D = rig.get("post_screen")
	check(screen != null and str(screen.call("text")).contains("BAY +") and str(screen.call("text")).contains("SCAFFOLD 1"),
			"the post has a touch screen: %s" % (screen.call("text") if screen else "none"))
	var press := func(button: String) -> void:
		var s: Node3D = rig.get("post_screen")
		s.call("press", button)
	press.call("bay_up")
	await get_tree().physics_frame
	press.call("lift_up")
	await get_tree().physics_frame
	check(int(rig.get("bays")) == 3 and int(rig.get("lifts")) == 3, "BAY + and LIFT + make it 3 x 3: %d x %d" % [rig.get("bays"), rig.get("lifts")])
	var deck_hit := yard.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
			rig.to_global(Vector3(0.3, 8.0, 6.2)), rig.to_global(Vector3(0.3, 0.5, 6.2))))
	check(absf(float(deck_hit.get("position", Vector3.ZERO).y) - 6.35) < 0.1, "its new top deck is a floor at 6.35 m: %s" % deck_hit.get("position", ""))
	press.call("ends")
	await get_tree().physics_frame
	check(bool(rig.call("end_open", 0)) and not bool(rig.call("end_open", 1)), "ENDS opens the front end to join another rig")
	for b: String in ["bay_down", "lift_down"]:
		press.call(b)
		await get_tree().physics_frame
	await get_tree().physics_frame
	check(int(rig.get("bays")) == 2 and int(rig.get("lifts")) == 2, "BAY - and LIFT - take it back")

	# Driving: it crabs sideways to the hull and stops there.
	var start := rig.global_position
	var steps := 0
	for i in 200:
		if not bool(access.call("drive", "rig0", 0.0, 0.0, 0.05)):
			break
		steps += 1
	var face := rig.to_global(Vector3(0.8, 2.5, 1.0)).x
	check(steps > 40 and face > hull_x - 0.05 and face < hull_x + 0.2, "driven in sideways it stops at the hull: its face at x %.2f after %d steps" % [face, steps])
	for i in 2:
		await get_tree().physics_frame
	var moved_hit := yard.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
			rig.to_global(Vector3(0.2, 7.0, 3.0)), rig.to_global(Vector3(0.2, 0.5, 3.0))))
	check(absf(float(moved_hit.get("position", Vector3.ZERO).y) - 4.35) < 0.1, "its frame went with it (the deck is there): %s" % moved_hit.get("position", ""))
	var grow_ok: bool = rig.call("fits", 2, 3)
	check(not grow_ok, "against the hull it can't grow another lift into the ship's shoulder")
	press.call("lift_up")
	await get_tree().physics_frame
	check(int(rig.get("lifts")) == 2, "so LIFT + is refused there")
	var handle := rig.find_child("PushHandle", true, false) as Node
	check(handle != null and handle.has_meta("ship_bay_use"), "F on the post's handle takes it to push")

	# Climbing: the ladder on its outboard side takes you up and onto the top deck.
	var walker: CharacterBody3D = yard.get("walker")
	yard.call("set_walker_active", true)
	var foot := rig.to_global(Vector3(-0.8 - 0.4, 0.05, 0.9))
	walker.call("place", foot, rig.to_global(Vector3(0, 1.7, 0.9)))
	await get_tree().physics_frame
	Input.action_press(Keys.FORWARD)
	for i in 480:
		await get_tree().physics_frame
		if rig.to_local(walker.global_position).x > -0.8:
			break
	Input.action_release(Keys.FORWARD)
	for i in 10:
		await get_tree().physics_frame
	var on := rig.to_local(walker.global_position)
	check(absf(walker.global_position.y - float(rig.call("top"))) < 0.2 and absf(on.x) < 0.8,
			"climbed the ladder onto the top deck: y %.2f, x across %.2f" % [walker.global_position.y, on.x])

	# And back out of the way.
	yard.call("set_walker_active", false)
	for i in steps:
		access.call("drive", "rig0", 0.0, 0.0, -0.05)
	check(rig.global_position.distance_to(start) < 0.06, "it drives back out to where it was")
	yard.queue_free()
	await frames(1)
	bus.unload_ship()
