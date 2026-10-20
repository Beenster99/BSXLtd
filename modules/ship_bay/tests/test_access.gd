extends ModuleTest
## Ship and Bay: you can walk up the boarding stairs into the Kestrel's hold, the scissor lift
## rises and falls on its control, the ground power unit powers the ship up and down, and the
## yard's night lights follow the time of day.
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
	check(access != null, "the bay has its stairs, lift and power unit")
	if access == null:
		yard.queue_free()
		return
	for i in 3:
		await get_tree().physics_frame

	# Walk from the foot of the stairs, up and through the side door into the hold.
	var walker: CharacterBody3D = yard.get("walker")
	yard.call("set_walker_active", true)
	walker.set_physics_process(false)
	walker.call("place", Vector3(-7.4, 0.05, 2.25), Vector3(0, 1, 2.25))
	var top_y := 0.0
	for i in 240:
		walker.velocity = Vector3(2.5, walker.velocity.y - 9.0 / 60.0 if not walker.is_on_floor() else 0.0, 0.0)
		walker.move_and_slide()
		top_y = maxf(top_y, walker.position.y)
		await get_tree().physics_frame
		if walker.position.x > -1.2:
			break
	check(walker.position.x > -1.6, "walked through the side door into the hold: x %.2f" % walker.position.x)
	check(absf(walker.position.y - 1.6) < 0.15, "standing on the hold's floor: y %.2f" % walker.position.y)
	walker.set_physics_process(true)

	# Shore power: off to start with; the power unit's switch turns it on and off.
	check(not bus.ship_powered and not bool(model.get("powered")), "the ship is cold in the yard")
	var socket: Vector3 = model.call("access_points")["power_socket"]
	var unit := bay.to_global(Vector3(socket.x + 2.1, 0.7, socket.z + 1.6))
	var used: bool = bay.call("use_along", unit + Vector3(2.0, 0, 0), Vector3.LEFT)
	check(used and bus.ship_powered, "the power unit's switch powers the ship up")
	check(bool(model.get("powered")), "the ship's lamps and screens come on")
	var lamps_on := model.find_children("*", "Light3D", false, false).all(func(l: Light3D) -> bool: return l.visible)
	check(lamps_on, "every lamp aboard is lit")
	bay.call("use_along", unit + Vector3(2.0, 0, 0), Vector3.LEFT)
	check(not bus.ship_powered and not bool(model.get("powered")), "and down again")
	check(bus.snapshot().get("powered") == false, "power is saved with the bay")

	# The lift: its ground control sends the platform up to the flank level.
	var platform: Node3D = access.get("platform")
	var start_y := platform.position.y
	var control := bay.to_global(Vector3(4.2, 0.85, 3.9))
	check(bay.call("use_along", control + Vector3(1.5, 0, 0), Vector3.LEFT), "the lift's ground control takes Use")
	for i in 300:
		await get_tree().physics_frame
	check(absf(platform.position.y - 2.4) < 0.01, "the platform rose to 2.4 m: %.2f (from %.2f)" % [platform.position.y, start_y])

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
