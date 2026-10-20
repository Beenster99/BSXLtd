extends ModuleTest
## The bench in Ship and Bay's shipyard: it stands at the Pre-assembly spot, waits while you
## walk the yard, F at it hands you the bench, Esc hands you back.


func run_tests() -> void:
	var bus := Modules.bus("trades") as TradesBus
	var yard := Node3D.new()
	add_child(yard)
	var walker_cam := Camera3D.new()
	yard.add_child(walker_cam)
	walker_cam.current = true
	bus._on_shipyard_ready(yard)
	await frames(2)
	var bench: Node = yard.get_node_or_null("ToolsBench")
	check(bench != null and bench.in_yard, "the shipyard gets the bench")
	check(bench.is_in_group(TradesBus.YARD_GUEST_GROUP), "marked as a guest in the yard")
	var spot := (Modules.bus("ship_bay") as ShipBayBus).shipyard_spot(TradesBus.YARD_SPOT)
	check(bench.global_position.distance_to(spot.origin + Vector3(0, 0, TradesBus.YARD_BOARD_DEPTH)) < 0.001,
			"standing at the Pre-assembly spot")
	check(not bench.active and walker_cam.current and not bench.worker.visible, "it waits: the yard keeps the view")

	walker_cam.global_position = bench.to_global(Vector3(0.6, 1.62, 6.0))
	await frames(1)
	check(not bench.yard_walker_near() and not bench._prompt.visible, "no prompt from across the room")
	walker_cam.global_position = bench.to_global(Vector3(0.6, 1.62, 1.2))
	await frames(1)
	check(bench.yard_walker_near() and bench._prompt.visible, "standing at it asks you to press F")
	bench._input(_key(KEY_F))
	check(bench.active and bench.worker.camera.current and bench.worker.visible, "F hands you the bench and its view")
	check(absf(bench.to_local(bench.worker.global_position).x - 0.6) < 0.01, "your worker steps up where you stood")
	bench._input(_key(KEY_ESCAPE))
	check(not bench.active and walker_cam.current, "Esc hands the yard its view back")
	yard.queue_free()
	await frames(1)


func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.pressed = true
	return e
