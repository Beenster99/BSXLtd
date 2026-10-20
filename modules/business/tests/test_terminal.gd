extends ModuleTest
## Business in the shipyard: the wall terminals go up, a player in reach gets the prompt,
## the full terminal builds a purchase order and places it, and goods in store show as
## crates in the deliveries hall.
##   tools/run_tests.sh business

const Screen := preload("res://modules/business/internal/ui/terminal_screen.gd")


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "ship_bay.shipyard": true,
			"business": true, "business.market": true})
	Modules.load_all()
	var bus := Modules.bus("business") as BusinessBus
	var yard_bus := Modules.bus("ship_bay") as ShipBayBus
	check(bus != null and yard_bus != null, "business and ship_bay load")
	if bus == null or yard_bus == null:
		Flags.use(saved)
		Modules.load_all()
		return
	bus.reset()

	# A wall screen on its own: display only, every channel draws.
	var wall: Control = Screen.new()
	wall.size = Vector2(1280, 800)
	add_child(wall)
	wall.call("setup", bus, false)
	for ch in ["orders", "goods", "accounts"]:
		wall.call("show_channel", ch)
		check(wall.get_child_count() > 0, "the %s channel draws" % ch)
	wall.queue_free()

	var yard: Node3D = load(Router.scene_path(ShipBayBus.SHIPYARD_SCENE)).instantiate()
	add_child(yard)
	await frames(3)
	var front := yard.get_node_or_null(BusinessBus.YARD_NODE)
	check(front != null, "Business furnishes the shipyard")
	if front == null:
		_done(saved, yard)
		return
	var monitors: Array = front.get("monitors")
	check(monitors.size() == 2, "two wall terminals")
	for m: Node3D in monitors:
		check(yard.call("room_at", m.global_position) == "deliveries", "%s hangs in the deliveries hall" % m.name)

	# Stand a camera in front of the first terminal: the prompt shows.
	var cam: Camera3D = front.call("stage_monitor_view", 0)
	await frames(2)
	check(front.call("nearest_monitor") == 0, "a player at the terminal can use it")
	cam.global_position += Vector3(0, 0, 8)
	await frames(2)
	check(front.call("nearest_monitor") == -1, "out of reach, no prompt")

	# The full terminal: add two listings, set quantities, place the order.
	var screen: Control = front.call("open_terminal")
	check(front.get("overlay") != null and screen != null, "the terminal opens full size")
	var picks := bus.get_listings().filter(func(l): return not l.id.begins_with("S-") and l.unit_price < 2000 and l.available >= 3)
	screen.call("add_to_basket", picks[0].id, 1)
	screen.call("add_to_basket", picks[0].id, 1)
	screen.call("add_to_basket", picks[1].id, 1)
	screen.call("add_to_basket", picks[1].id, -1)
	var lines: Array = screen.call("basket_as_lines")
	check(lines.size() == 1 and lines[0].qty == 2, "+ and - set quantities: %s" % str(lines))
	var expected: int = picks[0].unit_price * 2
	var cash := bus.get_cash()
	var r: BusinessResult = screen.call("place_order")
	check(r.is_ok() and bus.get_cash() == cash - expected, "the order is placed for the bill shown")
	check((screen.get("basket") as Dictionary).is_empty(), "the purchase order clears")
	front.call("close_terminal")
	check(front.get("overlay") == null and not get_tree().paused, "closing gives the game back")

	# It lands: crates in the deliveries hall (Ship and Bay doesn't take deliveries yet).
	for s: SupplierDef in bus.get_suppliers():
		s.reliability = 1.0
	for i in 4:
		bus.advance_day()
	var crates: Node3D = front.get_node("GoodsIn")
	if bus.ship_bay_takes_deliveries():
		check(crates.get_child_count() == 0, "Ship and Bay places deliveries, so no Business crates")
		var landed: Dictionary = yard_bus.call("delivered_crates")
		var ours := landed.keys().filter(func(id): return landed[id].item == picks[0].part)
		check(ours.size() == 1 and int(landed[ours[0]].qty) == 2, "the order lands as a Ship and Bay crate: %s" % str(landed))
		for id in ours:
			var at: Vector3 = yard_bus.call("crate_position", id)
			check(yard.call("room_at", at + Vector3(0, 0.5, 0)) == "deliveries", "%s stands in the deliveries hall" % id)
	else:
		check(crates.get_child_count() == 1, "a crate for what arrived: %d" % crates.get_child_count())
		for c: Node3D in crates.get_children():
			check(yard.call("room_at", c.global_position + Vector3(0, 0.5, 0)) == "deliveries", "%s is in the deliveries hall" % c.name)
		bus.use_stock(picks[0].part, 2)
		check(crates.get_child_count() == 0, "fitting the parts empties the crate")
	_done(saved, yard)


func _done(saved: Dictionary, yard: Node) -> void:
	yard.queue_free()
	await frames(2)
	(Modules.bus("business") as BusinessBus).reset()
	Flags.use(saved)
	Modules.load_all()
