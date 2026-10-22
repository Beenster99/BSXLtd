extends ModuleTest
## Jumping onto the yard's hover trolleys (beenster, 22 Oct: "my character should be able to
## jump onto any of the trolleys - we could use them to access areas of the ship at height"):
## a run-up and Space puts you on one, and you ride its deck up when it rises.


func run_tests() -> void:
	var saved := {}
	for flag: String in ["trades.shipyard", "trades.jump"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	ship_bus.reset_data()
	var yard := (load(Router.scene_path(ShipBayBus.SHIPYARD_SCENE)) as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	await physics(3)
	var rig: TradesBay = yard.get_node_or_null(TradesBus.YARD_RIG)
	var fleet: Node3D = yard.get("trolleys")
	check(rig != null and fleet != null, "the yard has you and its trolleys")
	if rig == null or fleet == null:
		yard.queue_free()
		return
	var worker := rig.worker
	var trolleys: Dictionary = fleet.get("trolleys")
	for kind: String in ["s", "m", "l"]:
		var t: Node3D = trolleys[kind]
		# Stand a step behind its open back on the floor, facing it.
		var back := t.global_basis.z.normalized()
		var at := Vector3(t.global_position.x, 0.0, t.global_position.z)
		var depth := float(t.call("radius"))
		var feet := at + back * (depth + 0.7) + Vector3(0, 0.05, 0)
		worker.global_position = feet
		worker.velocity = Vector3.ZERO
		worker.face(at + Vector3(0, 1.0, 0))
		await physics(20)
		Input.action_press(Keys.FORWARD)
		Input.action_press(Keys.JUMP)
		await physics(8)
		Input.action_release(Keys.JUMP)
		await physics(30)
		Input.action_release(Keys.FORWARD)
		await physics(30)
		var on := worker.is_on_floor() and worker.global_position.y > 0.65 \
				and Vector2(worker.global_position.x - at.x, worker.global_position.z - at.z).length() < depth + 1.0
		check(on, "trolley %s: a run-up and a jump puts you on it (%.2f m up)" % [kind.to_upper(), worker.global_position.y])
		if kind == "m" and on:
			# Its deck goes up and you ride it.
			var from := worker.global_position.y
			t.call("set_deck_target", 3.0)
			await physics(300)
			check(worker.global_position.y > from + 1.5, "riding the deck up to work at height (%.2f m)" % worker.global_position.y)
			t.call("set_deck_target", 0.7)
			await physics(300)
	yard.queue_free()
	await frames(1)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
