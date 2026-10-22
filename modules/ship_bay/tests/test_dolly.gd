extends ModuleTest
## Ship and Bay: the transporter dolly drives on remote and from its cab in its three steering
## modes, stops dead for a person under it or anything within 0.5 m ahead, and moves the pad's
## hulk: in under its cradle, deck up to the beams, pins in, lift, drive, set it down on the
## pedestals again, pins out.
##   tools/run_tests.sh ship_bay

const Dolly := preload("res://modules/ship_bay/internal/yard/dolly.gd")
const Cradle := preload("res://modules/ship_bay/internal/yard/transport_cradle.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var was := [Flags.is_on("ship_bay.apron"), Flags.is_on("ship_bay.dolly")]
	Flags.set_flag("ship_bay.apron", true)
	Flags.set_flag("ship_bay.dolly", true)
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	var tr: Node3D = yard.get("transporters")
	check(tr != null, "the yard has its transporters")
	if tr == null:
		yard.queue_free()
		return
	var walker := yard.get("walker") as Node3D
	yard.call("set_walker_active", false)
	walker.global_position = Vector3(0, 0, 10)
	var all: Dictionary = tr.get("transporters")
	check(all.keys() == ["dolly", "crawler"], "a dolly and a crawler: %s" % [all.keys()])
	var d: Dolly = all["dolly"]
	var crawler: Dolly = all["crawler"]
	check(d.size() == Vector2(6, 12) and crawler.size() == Vector2(14, 30), "12 by 6 m and 30 by 14 m")
	check(d.get("_bogies").size() == 8 and crawler.get("_bogies").size() == 40, "eight bogies and forty")
	d.accel = 4.0
	d.lift_speed = 1.0

	# Remote: ahead in normal mode goes north (its front, -Z).
	tr.call("toggle_remote", "dolly")
	check(tr.get("driving") == "dolly" and tr.get("how") == "remote", "F on it takes it on remote")
	var start := d.global_position
	await _hold("ship_bay.dolly_ahead", 60)
	check(d.global_position.z < start.z - 0.8 and absf(d.global_position.x - start.x) < 0.05, "ahead drives it forward: %s" % (d.global_position - start))
	check(d.speed() <= d.speed_empty + 0.001, "at walking pace: %.2f m/s" % d.speed())
	await _stop(d)
	# Normal steering turns it.
	var yaw := d.global_rotation.y
	Input.action_press("ship_bay.dolly_right")
	await _hold("ship_bay.dolly_ahead", 90)
	Input.action_release("ship_bay.dolly_right")
	check(d.global_rotation.y < yaw - 0.02, "steering right turns it right: %.3f" % (d.global_rotation.y - yaw))
	await _stop(d)
	# Crab: square across, it slides sideways without turning.
	d.global_transform = Transform3D(Basis(), Vector3(-42, 0, 92))
	tr.call("change_mode", "dolly")
	check(d.mode == "crab", "M: crab mode")
	Input.action_press("ship_bay.dolly_right")
	for i in 200:
		await get_tree().physics_frame
	start = d.global_position
	await _hold("ship_bay.dolly_ahead", 60)
	Input.action_release("ship_bay.dolly_right")
	check(d.global_position.x > start.x + 0.5 and absf(d.global_position.z - start.z) < 0.1 and absf(d.global_rotation.y) < 0.01,
			"crab slides it sideways: %s" % (d.global_position - start))
	var swivel: Node3D = d.get("_bogies")[0].swivel
	check(absf(absf(swivel.rotation.y) - PI * 0.5) < 0.05, "every bogie square across: %.2f" % swivel.rotation.y)
	await _stop(d)
	# Carousel: turns on the spot.
	tr.call("change_mode", "dolly")
	check(d.mode == "carousel", "M: carousel mode")
	start = d.global_position
	await _hold("ship_bay.dolly_right", 60)
	check(absf(d.global_rotation.y) > 0.05 and d.global_position.distance_to(start) < 0.05, "carousel turns it on the spot")
	tr.call("change_mode", "dolly")
	check(d.mode == "normal", "back to normal")
	await _stop(d)

	# Stops: a person under the deck, a wall within 0.5 m.
	d.global_transform = Transform3D(Basis(), Vector3(-42, 0, 92))
	walker.global_position = Vector3(-42, 0, 92)
	start = d.global_position
	await _hold("ship_bay.dolly_ahead", 20)
	check(d.global_position.distance_to(start) < 0.01 and d.stopped == "STOP: PERSON UNDER", "it won't move with a person under it: %s" % d.stopped)
	walker.global_position = Vector3(0, 0, 10)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(10, 3, 0.4)
	wall.add_child(shape)
	yard.add_child(wall)
	wall.global_position = Vector3(-42, 1.5, 92 - 6 - Dolly.CAB.z - 2.0)
	await _hold("ship_bay.dolly_ahead", 400)
	var gap := (92 - 6 - Dolly.CAB.z - 2.0 + 0.2) - (d.global_position.z - 6 - Dolly.CAB.z)
	check(d.stopped == "STOP: CLEARANCE" and gap > -0.6 and gap < -0.3, "it stops short of a wall, within 0.5 m: %.2f m, %s" % [-gap, d.stopped])
	start = d.global_position
	await _hold("ship_bay.dolly_back", 30)
	check(d.global_position.z > start.z + 0.1, "and backs away from it")
	wall.queue_free()
	await _stop(d)

	# The pad's hulk: in under its cradle, lined up.
	var apron: Node3D = yard.get("apron")
	var pad: Cradle = apron.get("pad_cradle")
	var hulk: Node3D = apron.get("hulk")
	var home := pad.global_transform
	d.global_transform = Transform3D(Basis(), Vector3(home.origin.x, 0, home.origin.z - 0.8))
	await frames(2)
	check(bool(tr.call("aligned", d, pad)), "the sockets line up under the pins")
	await _hold("ship_bay.dolly_up", 60)
	check(absf(d.deck_height - (pad.global_position.y - 0.005)) < 0.01 and d.load_cradle == null, "the deck stops at the cross beams: %.3f" % d.deck_height)
	check(d.stopped == "PINS 0/4", "waiting for the pins: %s" % d.stopped)
	for i in 3:
		tr.call("throw_pin", str(pad.name), i)
	await _hold("ship_bay.dolly_up", 30)
	check(d.load_cradle == null and pad.engaged_count() == 3, "three pins aren't enough")
	tr.call("throw_pin", str(pad.name), 3)
	check(pad.all_pins_engaged(), "all four pins in")
	await _hold("ship_bay.dolly_up", 60)
	check(d.load_cradle == pad, "now it lifts the cradle")
	check(pad.global_position.y > home.origin.y + 0.5, "off its pedestals: %.2f" % pad.global_position.y)
	tr.call("throw_pin", str(pad.name), 0)
	check(pad.pins[0], "pins are locked under load")
	var lifted_hull := hulk.global_position
	await _hold("ship_bay.dolly_ahead", 60)
	check(hulk.global_position.z < lifted_hull.z - 0.5, "the hulk rides along: %s" % (hulk.global_position - lifted_hull))
	check(d.speed() <= d.speed_loaded + 0.001, "loaded, it goes at walking pace")
	await _hold("ship_bay.dolly_back", 120)
	await _stop(d)
	d.global_transform = Transform3D(Basis(), Vector3(home.origin.x, 0, home.origin.z - 0.8))
	await frames(2)
	await _hold("ship_bay.dolly_down", 120)
	check(d.load_cradle == null, "lowered onto the pedestals, it sets the cradle down")
	check(absf(pad.global_position.y - home.origin.y) < 0.01, "on its pedestals again: %.3f" % pad.global_position.y)
	start = d.global_position
	await _hold("ship_bay.dolly_back", 20)
	check(d.global_position.distance_to(start) < 0.01 and d.stopped == "STOP: DRAW PINS", "pinned to the cradle, it won't drive off: %s" % d.stopped)
	for i in 4:
		tr.call("throw_pin", str(pad.name), i)
	check(pad.engaged_count() == 0, "pins drawn")
	await _hold("ship_bay.dolly_down", 30)
	await _hold("ship_bay.dolly_back", 30)
	check(d.global_position.z > start.z + 0.1, "then it drives out")
	var saved: Dictionary = bus.snapshot().get("transport", {})
	check((saved.get("cradles", {}) as Dictionary).has(str(pad.name)), "where the cradles are goes in the save")

	# The cab: F sits you in it and its camera takes over; F gets you out.
	tr.call("enter_cab", "dolly")
	check(tr.get("how") == "cab" and d.cab_camera.current, "F on the cab: in the driver's seat")
	tr.call("enter_cab", "dolly")
	check(tr.get("driving") == "" and not d.cab_camera.current, "F again: out")

	# Scrapyard S1: a contract's subject part lands in Deliveries as a crate.
	bus.call("_on_subject_due", "J-TEST", {"type": "part", "component": {"id": "IonThruster", "material": "steel"}, "condition": 0.4, "mass_kg": 310.0})
	var landed := bus.delivered_crates().values().filter(func(c: Dictionary) -> bool: return str(c.get("order_id", "")) == ShipBayBus.SUBJECT_ORDER + "J-TEST")
	check(landed.size() == 1 and str(landed[0].get("item", "")) == "IonThruster", "a contract's subject part lands in Deliveries: %s" % [landed])

	yard.queue_free()
	await frames(2)
	Flags.set_flag("ship_bay.apron", was[0])
	Flags.set_flag("ship_bay.dolly", was[1])
	bus.reset_data()


func _hold(action: String, n: int) -> void:
	Input.action_press(action)
	for i in n:
		await get_tree().physics_frame
	Input.action_release(action)


func _stop(d: Dolly) -> void:
	d.halt()
	for i in 3:
		await get_tree().physics_frame
