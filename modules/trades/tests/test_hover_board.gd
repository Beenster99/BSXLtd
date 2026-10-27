extends ModuleTest
## The hover board (beenster, 0.3.23): B brings it out under you in the yard, it floats over
## the floor and carries you much faster than running, the up and down arrows raise and lower
## it, and B again puts it away (you drop back to the floor). Crewmates see it.


func run_tests() -> void:
	var saved := {}
	for flag: String in ["trades.shipyard", "trades.hover_board"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	check(InputMap.has_action(TradesBus.KEY_BOARD) and InputMap.has_action(TradesBus.KEY_BOARD_UP),
			"the board's keys are bound (B, the up and down arrows)")
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	ship_bus.reset_data()
	var yard := (load(Router.scene_path(ShipBayBus.SHIPYARD_SCENE)) as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	await physics(3)
	var rig: TradesBay = yard.get_node_or_null(TradesBus.YARD_RIG)
	check(rig != null and rig.worker.board != null, "in the yard you have a hover board")
	if rig == null or rig.worker.board == null:
		yard.queue_free()
		return
	var worker := rig.worker
	var board := worker.board
	await physics(30)
	var floor_y := worker.global_position.y
	check(not board.riding and not board.visible, "it starts put away")
	_face_open(worker)

	await _tap(TradesBus.KEY_BOARD)
	check(board.riding and board.visible, "B brings it out under your feet")
	await physics(90)
	var over := worker.global_position.y - floor_y
	check(absf(over - board.start_height) < 0.08, "it floats over the floor (%.2f m)" % over)

	# Riding: much faster than running, flat out faster still.
	var from := worker.global_position
	Input.action_press(Keys.FORWARD)
	await physics(80)
	var speed := Vector2(worker.velocity.x, worker.velocity.z).length()
	check(speed > worker.run_speed + 1.5, "riding goes faster than running (%.1f m/s, running %.1f)" % [speed, worker.run_speed])
	Input.action_press(Keys.RUN)
	await physics(50)
	var boost := Vector2(worker.velocity.x, worker.velocity.z).length()
	check(boost > speed + 2.0, "Shift goes flat out (%.1f m/s)" % boost)
	Input.action_release(Keys.RUN)
	Input.action_release(Keys.FORWARD)
	check(Vector2(worker.global_position.x - from.x, worker.global_position.z - from.z).length() > 6.0,
			"and it carries you across the yard (%.1f m)" % (worker.global_position - from).length())
	await physics(240)
	check(Vector2(worker.velocity.x, worker.velocity.z).length() < 0.5, "let go of the keys and it coasts to a stop")

	# Up and down.
	var low := worker.global_position.y
	Input.action_press(TradesBus.KEY_BOARD_UP)
	await physics(120)
	Input.action_release(TradesBus.KEY_BOARD_UP)
	await physics(60)
	var high := worker.global_position.y
	check(high > low + 2.5, "the up arrow raises it (%.2f m higher)" % (high - low))
	check(board.height <= board.max_height, "never past its top height")
	Input.action_press(TradesBus.KEY_BOARD_DOWN)
	await physics(180)
	Input.action_release(TradesBus.KEY_BOARD_DOWN)
	await physics(60)
	check(absf(board.height - board.min_height) < 0.01 and worker.global_position.y < high - 2.0,
			"the down arrow lowers it to its least height (%.2f m)" % board.height)

	# The crew see it.
	if rig.crew:
		check(bool(rig.crew.held_state().get("board", false)), "crewmates are told you're riding")
	var look := TradesHoverBoard.build_look()
	check(look.find_children("Glow*", "MeshInstance3D", true, false).size() >= 2, "their copy has its lit pads")
	look.free()

	# Up high, B puts it away and you drop to the floor.
	Input.action_press(TradesBus.KEY_BOARD_UP)
	await physics(60)
	Input.action_release(TradesBus.KEY_BOARD_UP)
	await physics(30)
	await _tap(TradesBus.KEY_BOARD)
	check(not board.riding and not board.visible, "B again puts it away")
	await physics(120)
	check(worker.is_on_floor() and absf(worker.global_position.y - floor_y) < 0.1, "and you're back on your feet on the floor")

	yard.queue_free()
	await frames(1)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func _tap(action: String) -> void:
	Input.action_press(action)
	await physics(2)
	Input.action_release(action)
	await physics(2)


## Turn to the way with the most open floor ahead (a long ray at knee height).
func _face_open(worker: BenchWorker) -> void:
	var space := worker.get_world_3d().direct_space_state
	var best := Vector3.FORWARD
	var best_d := -1.0
	for i in 16:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
		var from := worker.global_position + Vector3.UP * 0.5
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 60.0)
		q.exclude = [worker.get_rid()]
		var hit := space.intersect_ray(q)
		var d := 60.0 if hit.is_empty() else from.distance_to(hit.position)
		if d > best_d:
			best_d = d
			best = dir
	worker.face(worker.global_position + best * 10.0 + Vector3.UP * 1.62)


func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
