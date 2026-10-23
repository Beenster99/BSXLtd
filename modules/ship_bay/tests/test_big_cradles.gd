extends ModuleTest
## Ship and Bay: the crawler drives in under every big cradle on the apron from open ground
## (the holding lane's two medium ones, lying east-west, and Dock 3's large one), lines up,
## takes all four pins, lifts it off its pedestals and sets it down again (beenster, 0.3.15).
##   tools/run_tests.sh ship_bay

const Dolly := preload("res://modules/ship_bay/internal/yard/dolly.gd")
const Cradle := preload("res://modules/ship_bay/internal/yard/transport_cradle.gd")


func run_tests() -> void:
	(Modules.bus("ship_bay") as ShipBayBus).reset_data()
	var was := [Flags.is_on("ship_bay.apron"), Flags.is_on("ship_bay.dolly")]
	Flags.set_flag("ship_bay.apron", true)
	Flags.set_flag("ship_bay.dolly", true)
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	yard.call("set_walker_active", false)
	(yard.get("walker") as Node3D).global_position = Vector3(0, 0, 10)
	var tr: Node3D = yard.get("transporters")
	var apron: Node3D = yard.get("apron")
	var crawler: Dolly = tr.get("transporters")["crawler"]
	crawler.accel = 4.0
	crawler.lift_speed = 2.0
	crawler.speed_empty = 6.0
	var big: Array = (apron.get("holding_cradles") as Array).filter(func(c: Cradle) -> bool: return c.size != "s")
	big.append_array(apron.get("dock_cradles"))
	check(big.size() == 3, "two medium cradles and a large one")
	for c: Cradle in big:
		var home := c.global_transform
		# Start 2 m clear of the cradle's open end, facing in.
		var start := Vector3(home.origin.x, 0, home.origin.z) + home.basis.z * (c.length * 0.5 + crawler.size().y * 0.5 + 2.0)
		crawler.global_transform = Transform3D(home.basis, start)
		await frames(2)
		tr.call("toggle_remote", "crawler")
		Input.action_press("ship_bay.dolly_ahead")
		for i in 1200:
			await get_tree().physics_frame
			if (home.affine_inverse() * crawler.global_position).z < -0.6:
				break
		Input.action_release("ship_bay.dolly_ahead")
		crawler.halt()
		await frames(3)
		check(bool(tr.call("aligned", crawler, c)), "%s: the crawler drives in under it and lines up: %s (%s)" % [c.name, home.affine_inverse() * crawler.global_position, crawler.stopped])
		await _hold("ship_bay.dolly_up", 90)
		for i in 4:
			tr.call("throw_pin", str(c.name), i)
		check(c.all_pins_engaged(), "%s: all four pins go in" % c.name)
		await _hold("ship_bay.dolly_up", 90)
		check(crawler.load_cradle == c and c.global_position.y > home.origin.y + 0.5, "%s: lifted off its pedestals" % c.name)
		await _hold("ship_bay.dolly_down", 150)
		check(crawler.load_cradle == null and absf(c.global_position.y - home.origin.y) < 0.02, "%s: and set down on them again" % c.name)
		for i in 4:
			tr.call("throw_pin", str(c.name), i)
		await _hold("ship_bay.dolly_down", 120)
		tr.call("toggle_remote", "crawler")
	Flags.set_flag("ship_bay.apron", was[0])
	Flags.set_flag("ship_bay.dolly", was[1])
	yard.queue_free()
	await frames(2)


func _hold(action: String, n: int) -> void:
	Input.action_press(action)
	for i in n:
		await get_tree().physics_frame
	Input.action_release(action)
