extends ModuleTest
## Real fire extinguishers (beenster, 0.3.23): F takes one off its bracket, holding the left
## mouse button sprays (it empties), F stands it on the floor or hangs it on an empty bracket
## (where it's serviced back to full), a tool off the hotbar stands it down, and the host
## keeps two players from taking the same one.


func run_tests() -> void:
	var saved := {}
	for flag: String in ["trades.shipyard", "trades.extinguishers"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	ship_bus.reset_data()
	var yard := (load(Router.scene_path(ShipBayBus.SHIPYARD_SCENE)) as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	await physics(3)
	var bay: TradesBay = yard.get_node_or_null(TradesBus.YARD_RIG)
	check(bay != null, "the yard has you")
	if bay == null:
		yard.queue_free()
		return
	var worker := bay.worker
	await physics(30)
	if bay.extinguishers:
		check(bay.extinguishers.units.size() == TradesExtinguishers.fire_points().size() and bay.extinguishers.units.size() > 0,
				"one on every fire point Ship and Bay gives (%d)" % bay.extinguishers.units.size())
		bay.extinguishers.queue_free()
		bay.extinguishers = null
		await frames(1)

	# Two brackets in front of you, facing you, at the wall height the yard uses.
	var ahead := -worker.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var side := ahead.cross(Vector3.UP)
	var feet := worker.global_position
	var face := Basis.looking_at(-ahead, Vector3.UP)  # -Z toward you
	var ext := TradesExtinguishers.new()
	ext.bay = bay
	ext.refill_s = 1.0
	ext.spray_s = 2.0
	ext.spots.append(Transform3D(face, feet + ahead * 1.3 + Vector3.UP * 0.75))
	ext.spots.append(Transform3D(face, feet + ahead * 1.3 + side * 0.6 + Vector3.UP * 0.75))
	bay.add_child(ext)
	ext.build(null)
	bay.extinguishers = ext
	await frames(2)
	check(ext.units.size() == 2 and ext._on_bracket(0) == 0 and ext._on_bracket(1) == 1, "each bracket has its extinguisher")
	check(ext.units[0].node.find_child("Gauge", true, false) != null and ext.units[0].node.find_child("Horn", true, false) != null,
			"it has a gauge and a horn")

	worker.face(ext._centre(0))
	await frames(1)
	check(ext.aimed_unit() == 0, "you can aim at it on the wall")
	var hint := ext.look_hint({})
	check(str(hint.get("title", "")) == "Fire extinguisher" and str(hint.get("keys", [])).contains("take it"), "its card says F takes it")
	bay.set_tool(bay.hotbar[1])
	bay._on_action(Keys.INTERACT)
	check(ext.holding() and ext.held == 0 and ext.units[0].where == TradesExtinguishers.IN_HAND, "F takes it off the wall")
	check(bay.tool == &"hands", "the tool in hand goes away")
	check(ext._validate(2, {"id": 0, "act": "take"}) is String, "nobody else can take the one you hold")
	check(ext._validate(1, {"id": 1, "act": "take"}) is String, "one at a time")
	check(ext.aimed_bracket() == 0, "its empty bracket is there to hang it back on")

	# Spray it empty.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	bay._on_mouse_button(press)
	await frames(30)
	check(ext.spraying and ext._cloud.emitting and ext.charge_of(0) < 1.0, "holding the mouse sprays (%.2f left)" % ext.charge_of(0))
	check(bool(ext.held_state().get("spray")), "the crew are told you're spraying")
	await get_tree().create_timer(2.2).timeout
	check(ext.charge_of(0) == 0.0 and not ext._cloud.emitting, "it runs out")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	bay._on_mouse_button(release)
	check(not ext.spraying, "let go and it stops")

	# Stand it on the floor (look away from the bracket), pick it up again.
	worker.face(feet - ahead * 3.0 + Vector3.UP * 0.5)
	await frames(1)
	bay._on_action(Keys.INTERACT)
	var u: Dictionary = ext.units[0]
	check(u.where == TradesExtinguishers.ON_FLOOR and not ext.holding(), "F stands it on the floor")
	check(absf((u.node as Node3D).global_position.y - feet.y) < 0.15, "on the floor, not in the air (%.2f)" % ((u.node as Node3D).global_position.y - feet.y))
	worker.face(ext._centre(0))
	await frames(1)
	bay._on_action(Keys.INTERACT)
	check(ext.held == 0, "and F picks it up off the floor")

	# A tool off the hotbar stands it down.
	bay._on_action(TradesBus.KEY_TOOL + "2")
	check(not ext.holding() and ext.units[0].where == TradesExtinguishers.ON_FLOOR, "picking a tool stands it down first")

	# Hang it back: it fills up again.
	worker.face(ext._centre(0))
	await frames(1)
	bay._on_action(Keys.INTERACT)
	worker.face(ext.spots[0] * Vector3(0, TradesExtinguishers.BODY_H * 0.5, -0.1))
	await frames(1)
	bay._on_action(Keys.INTERACT)
	check(ext.units[0].where == TradesExtinguishers.ON_WALL and ext._on_bracket(0) == 0, "F at its bracket hangs it back")
	await get_tree().create_timer(1.3).timeout
	check(ext.charge_of(0) == 1.0, "on its bracket it's serviced back to full")

	# Late joiners see where they all are.
	var snap := ext.get_net_snapshot()
	ext.units[1].where = TradesExtinguishers.ON_FLOOR
	ext.apply_net_snapshot(snap)
	check(ext.units[1].where == TradesExtinguishers.ON_WALL, "a snapshot puts them back where they are")

	yard.queue_free()
	await frames(1)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
