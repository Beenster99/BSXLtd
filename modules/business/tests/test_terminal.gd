extends ModuleTest
## Business in the shipyard: the wall terminals go up, a player in reach gets the prompt,
## the full terminal builds a purchase order and places it, and goods in store show as
## crates in the deliveries hall.
##   tools/run_tests.sh business

const Screen := preload("res://modules/business/internal/ui/terminal_screen.gd")
const Tv := preload("res://modules/business/internal/ui/yard_tv.gd")


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

	# A hall TV on its own: every channel draws, best buys are under Void Salvage's value.
	var wall: Control = Tv.new()
	wall.size = Vector2(1280, 720)
	add_child(wall)
	wall.call("setup", bus)
	for ch in Tv.CHANNELS:
		wall.call("show_channel", ch)
		var body: Control = wall.get("_body")
		check(body.get_child_count() > 0, "the TV's %s channel draws" % ch)
	var buys: Array = wall.call("best_buys")
	var cat := bus.get_catalogue()
	check(not buys.is_empty() and buys.all(func(l): return l.unit_price < cat.value_of(l.part)), "best buys are under value")
	check(buys.size() < 2 or buys[0].unit_price / cat.value_of(buys[0].part) <= buys[1].unit_price / cat.value_of(buys[1].part), "best first")
	wall.queue_free()

	# The channels other screens (the wrist holo screen) put up.
	for id: String in BusinessBus.SCREEN_CHANNELS:
		var ch: String = BusinessBus.SCREEN_CHANNELS[id][1]
		var made := bus.make_screen(true, ch)
		check(made.get("channel") == ch and made.get("interactive") == true and made.has_signal("close_requested"), "%s opens on %s" % [id, ch])
		made.free()

	var yard: Node3D = load(Router.scene_path(ShipBayBus.SHIPYARD_SCENE)).instantiate()
	add_child(yard)
	await frames(3)
	var front := yard.get_node_or_null(BusinessBus.YARD_NODE)
	check(front != null, "Business furnishes the shipyard")
	if front == null:
		_done(saved, yard)
		return
	var monitors: Array = front.get("monitors")
	check(monitors.size() == 4, "a TV in every hall: %d" % monitors.size())
	var halls := {}
	var space := yard.get_world_3d().direct_space_state
	await get_tree().physics_frame
	for m: Node3D in monitors:
		var room: String = yard.call("room_at", m.global_position + m.global_basis.z * 0.5)
		halls[room] = true
		# Flat on a wall: a ray from in front of the screen to its back hits the wall there.
		var from := m.global_position + m.global_basis.z * 1.5
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, m.global_position - m.global_basis.z * 0.2))
		check(not hit.is_empty() and hit.position.distance_to(m.global_position) < 0.1, "%s is flat on the wall" % m.name)
		# Nothing stands in front of it within reach.
		var box := BoxShape3D.new()
		box.size = Vector3(3.2, 2.2, 3.0)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = box
		q.transform = Transform3D(m.global_basis, m.global_position + m.global_basis.z * 1.8 + Vector3(0, -0.6, 0))
		var hits := space.intersect_shape(q, 8)
		check(hits.is_empty(), "%s has clear floor in front: %s" % [m.name, str(hits.map(func(x): return x.collider.name))])
	check(halls.keys().size() == 4 and halls.has("deliveries") and halls.has("stock") and halls.has("prep") and halls.has("preassembly"),
			"one in each hall: %s" % str(halls.keys()))

	# Stand a camera in front of the first terminal: the prompt shows.
	var cam: Camera3D = front.call("stage_monitor_view", 0)
	await frames(2)
	check(front.call("nearest_monitor") == 0, "a player at the terminal can use it")
	cam.global_position += cam.global_basis.z * 8
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
