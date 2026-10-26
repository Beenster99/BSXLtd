extends ModuleTest
## Ship and Bay: you board the Kestrel on the scissor lift (walk on, hold RAISE on its
## touch screen to the door sill, walk in), the lift steps, stops, is pushed and won't run
## into the hull, the touch screens take clicks from the view's pointer, the ground power unit
## powers the ship up once its plug is clicked onto the hull, and the yard's night lights
## follow the time of day.
##   tools/run_tests.sh ship_bay


const TransportCradle := preload("res://modules/ship_bay/internal/yard/transport_cradle.gd")


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
	var screens: Array = access.get("lift_screens")
	check(screens.size() == 2, "the lift has two touch screens: %d" % screens.size())
	var deck_screen: Node3D = screens[1]
	check(deck_screen.global_basis.z.dot(lift.global_basis.x) > 0.6 and deck_screen.global_basis.z.y > 0.2,
			"the platform's screen faces in at whoever stands on it, tilted up")
	# Hold RAISE until the sill comes level, then let go: it stops there.
	var sill: float = bay.get("cradle_height")
	deck_screen.call("hold", "raise", true)
	for i in 400:
		walker.velocity = Vector3(0, walker.velocity.y - 9.0 / 60.0 if not walker.is_on_floor() else 0.0, 0)
		walker.move_and_slide()
		await get_tree().physics_frame
		if platform.position.y >= sill - 0.005:
			break
	deck_screen.call("hold", "raise", false)
	for i in 20:
		walker.velocity = Vector3(0, walker.velocity.y - 9.0 / 60.0 if not walker.is_on_floor() else 0.0, 0)
		walker.move_and_slide()
		await get_tree().physics_frame
	check(absf(platform.position.y - sill) < 0.02, "held RAISE, let go at the door sill, it stopped there: %.3f" % platform.position.y)
	check(str(deck_screen.call("text")).contains("%.1f M" % sill), "its screen shows the height: %s" % deck_screen.call("text"))
	check(absf(walker.position.y - sill) < 0.15, "riding up on it: y %.2f" % walker.position.y)
	# The side door is shut: F on its outside panel slides it open.
	check(not bool(model.call("is_door_open", "door_lock_out")), "the side door starts shut")
	var panel := model.to_global(Vector3(-2.75, 1.3, 3.1))
	var eye := model.to_global(Vector3(-3.4, 1.4, 3.1))
	check(bool(bay.call("use_along", eye, panel - eye)), "F on the side door's outside panel does something")
	await get_tree().create_timer(1.3).timeout
	check(bool(model.call("is_door_open", "door_lock_out")), "and the side door slid open")
	for i in 240:
		walker.velocity = Vector3(2.5, walker.velocity.y - 9.0 / 60.0 if not walker.is_on_floor() else 0.0, 0.0)
		walker.move_and_slide()
		await get_tree().physics_frame
		if walker.position.x > -1.2:
			break
	check(walker.position.x > -1.6, "walked off it through the side door into the hold: x %.2f" % walker.position.x)
	check(absf(walker.position.y - sill) < 0.15, "standing on the hold's floor: y %.2f" % walker.position.y)
	walker.set_physics_process(true)
	yard.call("set_walker_active", false)

	# UP again to the flank stop, DOWN to stop it partway, DOWN back to the bottom.
	access.call("lift_up")
	for i in 400:
		await get_tree().physics_frame
	var next_up := 0.0
	for h: float in access.get("stops"):
		if h > sill + 0.01:
			next_up = h
			break
	check(absf(platform.position.y - next_up) < 0.01, "UP goes on to the next stop: %.2f" % platform.position.y)
	access.call("lift_down")
	for i in 400:
		await get_tree().physics_frame
	check(absf(platform.position.y - sill) < 0.01, "DOWN steps back to the sill: %.2f" % platform.position.y)
	access.call("lift_down")
	for i in 20:
		await get_tree().physics_frame
	access.call("lift_down")
	var held := platform.position.y
	for i in 30:
		await get_tree().physics_frame
	check(absf(platform.position.y - held) < 0.001 and held < sill and held > 0.4, "pressed while moving it stops: %.2f" % held)
	access.call("lift_down")
	for i in 300:
		await get_tree().physics_frame
	check(absf(platform.position.y - 0.35) < 0.01, "and goes down to the bottom")

	# Pushing: F on the push bar takes hold; walk and it rolls along in front of you.
	var cam := Camera3D.new()
	yard.add_child(cam)
	cam.current = true
	var bar := lift.to_global(Vector3(0, 1.05, -2.6 * 0.5 - 0.22))
	cam.global_transform = Transform3D(Basis.looking_at(lift.global_basis.z), bar - lift.global_basis.z * 1.0)
	check(bool(bay.call("use_along", cam.global_position, -cam.global_basis.z)) and access.get("driving") == "lift", "F on the lift's push bar takes hold of it")
	var before := lift.global_position
	for i in 60:
		cam.global_position += lift.global_basis.z * 0.025
		await get_tree().physics_frame
	check(lift.global_position.distance_to(before) > 1.2 and lift.global_position.distance_to(before) < 1.6,
			"walked 1.5 m and the lift rolled along ahead: %.2f m" % lift.global_position.distance_to(before))
	for i in 60:
		cam.global_position -= lift.global_basis.z * 0.025
		await get_tree().physics_frame
	check(lift.global_position.distance_to(before) < 0.05, "and pulled back again: %.2f m off" % lift.global_position.distance_to(before))
	bay.call("use_along", cam.global_position, -cam.global_basis.z)
	check(access.get("driving") == "", "F again lets it go")

	# The pointer: looking at a touch screen and clicking presses the button under it.
	var unit: Node3D = access.get("unit")
	var unit_screen: Node3D = access.get("unit_screen")
	var power_button: Button = (unit_screen.get("buttons") as Dictionary)["power"]
	await frames(2)
	var centre := power_button.get_global_rect().get_center()
	var vp_size := Vector2((unit_screen.get("viewport") as SubViewport).size)
	var size_m: Vector2 = unit_screen.get("size")
	var on_face := unit_screen.to_global(Vector3((centre.x / vp_size.x - 0.5) * size_m.x, (0.5 - centre.y / vp_size.y) * size_m.y, 0))
	cam.global_transform = Transform3D(Basis.looking_at(-unit_screen.global_basis.z), on_face + unit_screen.global_basis.z * 0.8)
	var pointer: Node = get_tree().root.get_node_or_null("ShipBayTouchPointer")
	check(pointer != null, "the touch pointer is in the tree")
	await frames(2)
	var aimed: Array = pointer.call("aim") if pointer else [null]
	check(aimed[0] == unit_screen and str(unit_screen.call("button_at", aimed[1])) == "power",
			"looking at the power unit's screen points at its POWER button")
	check(bool(access.get("switch_on")), "the unit starts switched on (the ship comes in on shore power)")
	for down: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		pointer.call("_input", click)
		await frames(1)
	check(not bool(access.get("switch_on")), "a left click there switches it off")
	access.call("toggle_power")
	cam.queue_free()

	# Driving: along the hull it goes; it won't drive or rise into the ship.
	var start := lift.global_position
	var moved := 0
	for i in 60:
		if bool(access.call("drive", "lift", 0.05, 0.0)):
			moved += 1
	check(moved == 60 and lift.global_position.distance_to(start) > 2.9, "the lift drives along the hull: %.2f m" % lift.global_position.distance_to(start))
	for i in 2:
		await get_tree().physics_frame
	var deck_hit := yard.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
			platform.global_position + Vector3(0, 3, 0), platform.global_position + Vector3(0, -0.5, 0)))
	check(not deck_hit.is_empty() and deck_hit.collider == platform, "its platform went with it: %s at %s (lift at %s)" % [deck_hit.get("collider"), deck_hit.get("position"), lift.global_position])
	for i in 60:
		access.call("drive", "lift", -0.05, 0.0)
	check(lift.global_position.distance_to(start) < 0.01, "and back to the door")
	var into := lift.global_transform
	var turned: bool = access.call("drive", "lift", 0.0, -PI * 0.5)
	if turned:
		for i in 100:
			if not bool(access.call("drive", "lift", 0.05, 0.0)):
				break
	if bay.get("cradle") != null:
		# On the transport cradle the hull stands high enough to roll the lowered lift in
		# under the frame; it just won't rise into it.
		access.call("lift_up")
		for i in 240:
			await get_tree().physics_frame
		check(lift.global_position.x < -2.0 or platform.position.y < TransportCradle.REST - 0.2,
				"it can't be driven or raised into the hull: x %.2f, platform %.2f" % [lift.global_position.x, platform.position.y])
		access.call("lift_down")
		for i in 240:
			await get_tree().physics_frame
	else:
		check(lift.global_position.x < -2.0, "it can't be driven into the hull: x %.2f" % lift.global_position.x)
	lift.global_transform = into

	# Shore power: on to start with. The switch alone does nothing; the plug clipped to the
	# hull (anywhere in reach) with the switch on powers the ship.
	check(bus.ship_powered and bool(model.get("powered")) and access.get("plug_state") == "hull",
			"the ship comes into the bay on shore power, plugged in")
	# Unplugged and switched off, to try the unit from cold.
	unit_screen.call("press", "power")
	access.set("plug_state", "hook")
	access.call("_place_plug_on_hook")
	access.call("_update_power")
	check(not bus.ship_powered and not bool(model.get("powered")), "switched off and unplugged, the ship is cold")
	unit_screen.call("press", "power")
	check(bool(access.get("switch_on")) and not bus.ship_powered, "switched on, the plug still on its hook: no power")
	check(str(unit_screen.call("text")).contains("NO PLUG") and str(unit_screen.call("text")).contains("POWER OFF"),
			"its screen says so: %s" % unit_screen.call("text"))
	var hook := unit.to_global(Vector3(-0.6, 0.85, 0.15))
	check(not bool(bay.call("use_along", hook + Vector3(-1.5, 0, 0), Vector3.RIGHT)) or not bool(access.call("holding_plug")), "F doesn't take the plug")
	bay.call("click_along", hook + Vector3(-1.5, 0, 0), Vector3.RIGHT)
	check(bool(access.call("holding_plug")), "a left click on the hook takes the plug in hand")
	check(not bool(access.call("place_plug", Vector3(6, 1.5, 9), Vector3.DOWN)), "the floor won't take it")
	var hull := Vector3(4.8, 2.6, 3.0)
	check(bool(bay.call("click_along", hull, Vector3.LEFT)) and access.get("plug_state") == "hull", "a left click on the hull clamps it there")
	check(bus.ship_powered and bool(model.get("powered")), "and the ship powers up")
	check(model.get_node_or_null("PowerHum") != null, "with a quiet hum")
	var lamps := model.find_children("*", "Light3D", false, false)
	check(lamps.size() > 0 and not lamps.all(func(l: Light3D) -> bool: return l.visible), "its lights come on bow to stern, not all at once")
	for i in 150:
		await get_tree().physics_frame
	check(lamps.all(func(l: Light3D) -> bool: return l.visible), "and soon every lamp aboard is lit")
	check(str(unit_screen.call("text")).contains("LIVE"), "the unit's screen shows LIVE")
	unit_screen.call("press", "power")
	check(not bus.ship_powered and not bool(model.get("powered")), "POWER turns it off")
	check(model.get_node_or_null("PowerHum") == null or (model.get_node("PowerHum") as Node).is_queued_for_deletion(), "and the hum stops")
	check(bus.snapshot().get("powered") == false, "power is saved with the bay")
	unit_screen.call("press", "power")
	check(bus.ship_powered, "and on again")

	# Pushing the unit away: out of the cable's reach the plug pops off and the power goes.
	var cam2 := Camera3D.new()
	yard.add_child(cam2)
	cam2.current = true
	var handle := unit.to_global(Vector3(0, 0.62, -1.5 * 0.5 - 0.75))
	cam2.global_transform = Transform3D(Basis.looking_at(unit.global_basis.z), handle + Vector3(0, 1.0, 0) - unit.global_basis.z * 0.8)
	access.call("toggle_drive", "unit")
	check(access.get("driving") == "unit", "F on its handle takes hold of the unit")
	check(HudSlots.infos().any(func(c: Dictionary) -> bool: return c.id == "ship_bay.pushing"), "pushing shows a card in the right-hand info panel")
	# A short cable, so a few metres is out of reach.
	access.set("cable_length", 4.0)
	for i in 600:
		cam2.global_position += Vector3(0.03, 0, 0.0)
		await get_tree().physics_frame
		if access.get("plug_state") != "hull" or access.get("driving") == "":
			break
	check(access.get("plug_state") == "hook" and not bus.ship_powered, "pushed out of reach, the plug reels in and the power goes (%s)" % access.get("plug_state"))
	if access.get("driving") == "unit":
		access.call("toggle_drive", "unit")
	access.set("cable_length", 14.0)
	check(access.get("driving") == "", "and lets go")
	check(not HudSlots.infos().any(func(c: Dictionary) -> bool: return c.id == "ship_bay.pushing"), "and the card goes")
	cam2.queue_free()
	access.call("toggle_power")

	# The wrist's Machines channel lists the lift, the power unit and the scaffold rigs too.
	var machines_ch := HudSlots.holo_channel("ship_bay.machines")
	if not machines_ch.is_empty():
		var wrist: Control = (machines_ch["factory"] as Callable).call(true)
		add_child(wrist)
		await frames(2)
		var shown: String = wrist.call("text")
		check(shown.contains("Scissor lift") and shown.contains("Ground power unit") and shown.contains("Scaffold rig 1") and shown.contains("RAISE") and shown.contains("PUSH"),
				"the Machines screen lists the bay's kit: %s" % shown.left(400))
		wrist.call("press", "rig0", "drive")
		check(access.get("driving") == "rig0", "PUSH there takes hold of a scaffold rig")
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
	var floods := lights.filter(func(l: Light3D) -> bool: return l is SpotLight3D and (l as SpotLight3D).spot_range >= 30.0)
	check(floods.size() >= 8 and floods.all(func(l: Light3D) -> bool: return not l.has_meta("gfx_no_shadow")),
			"floodlights on the masts and the crane light the yard and the apron, with shadows: %d" % floods.size())
	yard.call("set_time_of_day", 12.0)
	check(lights.all(func(l: Light3D) -> bool: return not l.visible), "at noon they are off")
	Settings.set_value("world", "time_of_day", 21.0)
	check(is_equal_approx(float(yard.get("time_of_day")), 21.0), "the yard follows the time-of-day setting")
	yard.queue_free()
	await frames(1)
	bus.unload_ship()
