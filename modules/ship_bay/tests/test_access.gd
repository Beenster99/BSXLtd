extends ModuleTest
## Ship and Bay: you board the Kestrel on the scissor lift (walk on, UP to the door sill,
## walk in), the lift steps, stops, drives and won't run into the hull, the ground power unit
## powers the ship once its plug is clipped to the hull, and the yard's night lights follow
## the time of day.
##   tools/run_tests.sh ship_bay


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	var scene := load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene
	var yard := scene.instantiate() as Node3D
	add_child(yard)
	await frames(3)
	var bay: Node3D = yard.get("bay")
	var access: Node3D = bay.get("access")
	var model: Node3D = bay.get("model")
	check(access != null, "the bay has its lift and power unit")
	if access == null:
		yard.queue_free()
		return
	for i in 3:
		await get_tree().physics_frame

	# No stairs: walk up the lift's ramp onto its platform, press UP, ride it to the door sill
	# and walk into the hold.
	var walker: CharacterBody3D = yard.get("walker")
	yard.call("set_walker_active", true)
	walker.set_physics_process(false)
	var platform: AnimatableBody3D = access.get("platform")
	var lift: Node3D = access.get("lift")
	check(access.get_node_or_null("Stairs") == null and lift != null, "a lift at the door and no stairs")
	var ramp_foot := lift.to_global(Vector3(0, 0.05, 2.6 * 0.5 + 1.3 + 0.6))
	walker.call("place", ramp_foot, ramp_foot + Vector3(0, 0, -2))
	for i in 180:
		walker.velocity = Vector3(0, walker.velocity.y - 9.0 / 60.0 if not walker.is_on_floor() else 0.0, -2.0)
		walker.move_and_slide()
		await get_tree().physics_frame
		if walker.position.z < lift.global_position.z:
			break
	check(absf(walker.position.y - (platform.global_position.y)) < 0.15 and walker.position.z < lift.global_position.z + 0.3,
			"walked up the ramp onto the platform: y %.2f z %.2f" % [walker.position.y, walker.position.z])
	var button := platform.to_global(Vector3(-0.7 - 0.06 - 0.085, 1.05 - 0.1 + 0.05, -2.6 * 0.25))
	check(bool(bay.call("use_along", button + lift.global_basis.x * -1.2, lift.global_basis.x)), "UP on the platform's controls takes Use")
	for i in 400:
		walker.velocity = Vector3(0, walker.velocity.y - 9.0 / 60.0 if not walker.is_on_floor() else 0.0, 0)
		walker.move_and_slide()
		await get_tree().physics_frame
	var sill := 1.6
	check(absf(platform.position.y - sill) < 0.01, "it stopped level with the door sill: %.2f" % platform.position.y)
	check(absf(walker.position.y - sill) < 0.15, "riding up on it: y %.2f" % walker.position.y)
	for i in 240:
		walker.velocity = Vector3(2.5, walker.velocity.y - 9.0 / 60.0 if not walker.is_on_floor() else 0.0, 0.0)
		walker.move_and_slide()
		await get_tree().physics_frame
		if walker.position.x > -1.2:
			break
	check(walker.position.x > -1.6, "walked off it through the side door into the hold: x %.2f" % walker.position.x)
	check(absf(walker.position.y - 1.6) < 0.15, "standing on the hold's floor: y %.2f" % walker.position.y)
	walker.set_physics_process(true)
	yard.call("set_walker_active", false)

	# UP again to the flank stop, DOWN to stop it partway, DOWN back to the bottom.
	access.call("lift_up")
	for i in 200:
		await get_tree().physics_frame
	check(absf(platform.position.y - 2.4) < 0.01, "UP goes on to the flank stop: %.2f" % platform.position.y)
	access.call("lift_down")
	for i in 200:
		await get_tree().physics_frame
	check(absf(platform.position.y - 1.6) < 0.01, "DOWN steps back to the sill: %.2f" % platform.position.y)
	access.call("lift_down")
	for i in 20:
		await get_tree().physics_frame
	access.call("lift_down")
	var held := platform.position.y
	for i in 30:
		await get_tree().physics_frame
	check(absf(platform.position.y - held) < 0.001 and held < 1.6 and held > 0.4, "pressed while moving it stops: %.2f" % held)
	access.call("lift_down")
	for i in 300:
		await get_tree().physics_frame
	check(absf(platform.position.y - 0.35) < 0.01, "and goes down to the bottom")

	# Driving: along the hull it goes; it won't drive or rise into the ship.
	var start := lift.global_position
	var moved := 0
	for i in 60:
		if bool(access.call("drive", "lift", 0.05, 0.0)):
			moved += 1
	check(moved == 60 and lift.global_position.distance_to(start) > 2.9, "the lift drives along the hull: %.2f m" % lift.global_position.distance_to(start))
	await get_tree().physics_frame
	var deck_hit := yard.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
			platform.global_position + Vector3(0, 3, 0), platform.global_position + Vector3(0, -0.5, 0)))
	check(not deck_hit.is_empty() and deck_hit.collider == platform, "its platform went with it")
	for i in 60:
		access.call("drive", "lift", -0.05, 0.0)
	check(lift.global_position.distance_to(start) < 0.01, "and back to the door")
	var into := lift.global_transform
	var turned: bool = access.call("drive", "lift", 0.0, -PI * 0.5)
	if turned:
		for i in 100:
			if not bool(access.call("drive", "lift", 0.05, 0.0)):
				break
	check(lift.global_position.x < -2.0, "it can't be driven into the hull: x %.2f" % lift.global_position.x)
	lift.global_transform = into

	# Shore power: off to start with. The switch alone does nothing; the plug clipped to the
	# hull (anywhere in reach) with the switch on powers the ship.
	check(not bus.ship_powered and not bool(model.get("powered")), "the ship is cold in the yard")
	var unit: Node3D = access.get("unit")
	var panel := unit.to_global(Vector3(0, 0.95, 0.77))
	check(bool(bay.call("use_along", panel + Vector3(0, 0, 1.5), Vector3.BACK * -1.0)), "the power unit's switch takes Use")
	check(bool(access.get("switch_on")) and not bus.ship_powered, "switched on, the plug still on its hook: no power")
	var hook := unit.to_global(Vector3(-0.6, 0.85, 0.15))
	bay.call("use_along", hook + Vector3(-1.5, 0, 0), Vector3.RIGHT)
	check(bool(access.call("holding_plug")), "F on the hook takes the plug in hand")
	check(not bool(access.call("place_plug", Vector3(6, 1.5, 9), Vector3.DOWN)), "the floor won't take it")
	var hull := Vector3(4.8, 2.6, 3.0)
	check(bool(access.call("place_plug", hull, Vector3.LEFT)), "it clips on to the hull")
	check(bus.ship_powered and bool(model.get("powered")), "and the ship powers up")
	var lamps_on := model.find_children("*", "Light3D", false, false).all(func(l: Light3D) -> bool: return l.visible)
	check(lamps_on, "every lamp aboard is lit")
	bay.call("use_along", panel + Vector3(0, 0, 1.5), Vector3.BACK * -1.0)
	check(not bus.ship_powered and not bool(model.get("powered")), "the switch turns it off")
	check(bus.snapshot().get("powered") == false, "power is saved with the bay")
	bay.call("use_along", panel + Vector3(0, 0, 1.5), Vector3.BACK * -1.0)
	check(bus.ship_powered, "and on again")

	# Towing the unit: out of the cable's reach the plug pops off and the power goes.
	access.call("toggle_drive", "unit")
	check(access.get("driving") == "unit", "F on its handle tows the unit")
	for i in 400:
		access.call("drive", "unit", -0.05, 0.0)
		await get_tree().physics_frame
		if access.get("plug_state") != "hull":
			break
	check(access.get("plug_state") == "hook" and not bus.ship_powered, "towed out of reach, the plug reels in and the power goes (%s)" % access.get("plug_state"))
	access.call("toggle_drive", "unit")
	check(access.get("driving") == "", "and lets go")
	access.call("toggle_power")

	# The wrist's Machines channel lists the lift, the power unit and the scaffold rigs too.
	var machines_ch := HudSlots.holo_channel("ship_bay.machines")
	if not machines_ch.is_empty():
		var wrist: Control = (machines_ch["factory"] as Callable).call(true)
		add_child(wrist)
		await frames(2)
		var shown: String = wrist.call("text")
		check(shown.contains("Scissor lift") and shown.contains("Ground power unit") and shown.contains("Scaffold rig 1") and shown.contains("RAISE"),
				"the Machines screen lists the bay's kit: %s" % shown.left(400))
		wrist.call("press", "rig0", "drive")
		check(access.get("driving") == "rig0", "DRIVE there takes a scaffold rig")
		wrist.call("press", "rig0", "drive")
		check(access.get("driving") == "", "and lets it go again")
		wrist.queue_free()
	else:
		check(false, "the Machines channel is registered")

	# Night: the lamp posts come on in the dark and go out by day.
	yard.call("set_time_of_day", 22.0)
	var lights: Array = yard.get("_night_lights")
	check(lights.size() >= 14, "the yard has night lights: %d" % lights.size())
	check(lights.all(func(l: Light3D) -> bool: return l.visible and l.light_energy > 1.0), "at 22:00 they are on")
	check(not (yard.get("_sun") as Light3D).visible, "and the sun is down")
	yard.call("set_time_of_day", 12.0)
	check(lights.all(func(l: Light3D) -> bool: return not l.visible), "at noon they are off")
	Settings.set_value("world", "time_of_day", 21.0)
	check(is_equal_approx(float(yard.get("time_of_day")), 21.0), "the yard follows the time-of-day setting")
	yard.queue_free()
	await frames(1)
	bus.unload_ship()
