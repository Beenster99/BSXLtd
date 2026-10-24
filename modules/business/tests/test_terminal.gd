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

	# The channels on the wrist holo screen, on glass: Orders at the front, Accounts after
	# Ship and Bay's and Contracts', cash in the header.
	check(HudSlots.holo_channel("business.orders").get("order") == 10 and HudSlots.holo_channel("business.accounts").get("order", 0) >= 50,
			"Orders first, Accounts after the other modules' screens")
	check(Array(HudSlots.holo_readouts()).has("CR %s" % TerminalKit.money(bus.get_cash())), "cash shows in the wrist header")
	for id: String in BusinessBus.SCREEN_CHANNELS:
		var entry := HudSlots.holo_channel(id)
		check(not entry.is_empty(), "%s is on the wrist screen" % id)
		if entry.is_empty():
			continue
		var made: Control = entry.factory.call(true)
		check(made.get("page") == BusinessBus.SCREEN_CHANNELS[id][1] and made.get("glass") == true, "%s draws on glass" % id)
		check(made.find_children("*", "Label", true, false).all(func(l): return l.text != "BSX" and not l.text.begins_with("01")), "%s draws no header or tabs of its own" % id)
		add_child(made)
		made.size = Vector2(860, 420)
		await frames(2)
		check(made.size.x <= 861 and made.size.y <= 421, "%s fits the wrist pane: %s" % [id, made.size])
		made.free()

	# Ordering from the wrist: search, add, place; the order shows as on order.
	var wrist: Control = HudSlots.holo_channel("business.orders").factory.call(true)
	add_child(wrist)
	wrist.size = Vector2(1200, 600)
	await frames(1)
	var first: MarketListing = bus.get_listings().filter(func(l): return l.available >= 2 and l.unit_price < 3000)[0]
	var word := bus.part_name(first.part).split(" ")[0].to_lower()
	wrist.set("query", word)
	wrist.call("refresh")
	var found: Array = wrist.call("shown_listings")
	check(not found.is_empty() and found.all(func(l): return (bus.part_name(l.part) + " " + bus.supplier(l.supplier_id).display_name + " " + bus.listing_category(l)).to_lower().contains(word)),
			"search keeps only matching parts: %d for '%s'" % [found.size(), word])
	await frames(1)
	var add_btn := wrist.find_child("Add_" + first.id, true, false) as Button
	check(add_btn != null, "the searched part has a + button")
	if add_btn:
		add_btn.pressed.emit()
		add_btn = wrist.find_child("Add_" + first.id, true, false) as Button
		add_btn.pressed.emit()
	check(int(bus.wrist_basket.get(first.id, 0)) == 2, "+ twice puts two on the purchase order")
	wrist.free()
	wrist = HudSlots.holo_channel("business.orders").factory.call(true)
	add_child(wrist)
	check(int(wrist.get("basket").get(first.id, 0)) == 2, "the purchase order survives closing the wrist")
	var wcash := bus.get_cash()
	var placed: BusinessResult = wrist.call("place_order")
	check(placed.is_ok() and bus.get_cash() == wcash - first.unit_price * 2 and bus.wrist_basket.is_empty(), "PLACE ORDER on the wrist buys it")
	var on_order := false
	for l: Label in wrist.find_children("*", "Label", true, false):
		if l.text == placed.order_ids[0]:
			on_order = true
	check(on_order, "the order shows under ON ORDER")
	wrist.free()
	bus.reset()

	var yard: Node3D = load(Router.scene_path(ShipBayBus.SHIPYARD_SCENE)).instantiate()
	add_child(yard)
	await frames(3)
	var front := yard.get_node_or_null(BusinessBus.YARD_NODE)
	check(front != null, "Business furnishes the shipyard")
	if front == null:
		_done(saved, yard)
		return
	var monitors: Array = front.get("monitors")
	# The four halls, the bay (the courtyard round the ship) and the crusher house (beenster, 0.3.17).
	check(monitors.size() == 6, "a TV in every hall: %d" % monitors.size())
	var halls := {}
	var space := yard.get_world_3d().direct_space_state
	await get_tree().physics_frame
	for m: Node3D in monitors:
		var room: String = yard.call("room_at", m.global_position + m.global_basis.z * 0.5)
		halls[room] = true
		# Flat on a wall: a ray from in front of the screen to its back hits the wall there.
		var from := m.global_position + m.global_basis.z * 1.5
		var ray := PhysicsRayQueryParameters3D.create(from, m.global_position - m.global_basis.z * 0.2)
		ray.exclude = [(m.get_node("Body") as StaticBody3D).get_rid()]
		var hit := space.intersect_ray(ray)
		check(m.is_in_group("gfx_interactable") and str(m.get_meta("gfx_id", "")).begins_with("business.tv."), "%s lights up when looked at" % m.name)
		var tip := HudSlots.look_hint_for({"collider": m.get_node("Body")})
		check(tip.get("title") == "Hall TV" and (tip.keys as Array).size() == 2, "%s says what it does when looked at" % m.name)
		check(not hit.is_empty() and hit.position.distance_to(m.global_position) < 0.1, "%s is flat on the wall" % m.name)
		# Nothing stands in front of it within reach.
		var box := BoxShape3D.new()
		box.size = Vector3(3.2, 2.2, 3.0)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = box
		q.transform = Transform3D(m.global_basis, m.global_position + m.global_basis.z * 1.8 + Vector3(0, -0.6, 0))
		q.exclude = [(m.get_node("Body") as StaticBody3D).get_rid()]
		var hits := space.intersect_shape(q, 8)
		check(hits.is_empty(), "%s has clear floor in front: %s" % [m.name, str(hits.map(func(x): return x.collider.name))])
	check(halls.keys().size() == 6 and halls.has("deliveries") and halls.has("stock") and halls.has("prep") and halls.has("preassembly") and halls.has("bay"),
			"one in each hall: %s" % str(halls.keys()))

	# Every TV shows the wrist terminal without being aimed at, big enough to read across a hall.
	check(monitors.all(func(m: Node3D) -> bool: return m.get_node("Viewport").get_node_or_null("Terminal") is HoloTerminal),
			"every TV shows the wrist terminal")
	var big: Vector2 = front.get("SCREEN_M")
	check(big.x >= 5.0 and monitors.all(func(m: Node3D) -> bool: return m.global_position.y - big.y * 0.5 > 2.2), "the TVs are big and hung over people's heads: %s" % str(big))

	# Stand a camera in front of the first terminal: the prompt shows.
	var cam: Camera3D = front.call("stage_monitor_view", 0)
	await frames(2)
	check(front.call("nearest_monitor") == 0, "a player at the terminal can use it")
	cam.global_position += cam.global_basis.z * 8
	await frames(2)
	check(front.call("nearest_monitor") == -1, "out of reach, no prompt")

	# In place: aim the view at a TV and its floating pointer clicks on the working terminal.
	var tv0: Node3D = monitors[0]
	var px := Vector2(front.get("SCREEN_PX"))
	var m_size: Vector2 = front.get("SCREEN_M")
	var depth: float = front.get("DEPTH")
	var aim_at := func(pixel: Vector2) -> void:
		var spot := tv0.to_global(Vector3((pixel.x / px.x - 0.5) * m_size.x, (0.5 - pixel.y / px.y) * m_size.y, depth))
		cam.global_position = tv0.global_position + tv0.global_basis.z * 2.4 + Vector3(0, -0.9, 0)
		cam.look_at(spot)
	aim_at.call(px * 0.5)
	await frames(2)
	check(front.get("aimed") == 0 and front.call("is_awake", 0), "aiming at a TV wakes its terminal")
	var live: Control = tv0.get_node("Viewport/Terminal")
	check(live is HoloTerminal and str(live.get("channel")).begins_with("business."), "the TV shows the wrist terminal: %s" % str(live.get("channel")))
	live.call("show_channel", "business.orders")
	await frames(2)
	var plus: Button = null
	for b: Button in live.find_children("*", "Button", true, false):
		if b.text == "+" and not b.disabled:
			plus = b
			break
	check(plus != null, "a + button to aim at")
	if plus:
		aim_at.call(plus.get_global_rect().get_center())
		await frames(2)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		front.call("_input", click)
		await frames(1)
		click = click.duplicate()
		click.pressed = false
		front.call("_input", click)
		await frames(2)
		check(bus.wrist_basket.size() == 1, "clicking + with the pointer adds to the order: %s" % str(bus.wrist_basket))
		check(HudSlots.pointer_claimed(), "tools leave the click alone while a TV is aimed at")
		var full: Control = front.call("open_full", 0)
		check(full is HoloTerminal and full.get("channel") == "business.orders" and bus.wrist_basket.size() == 1 and not front.call("is_awake", 0),
				"F takes it full screen with the order")
		bus.wrist_basket.clear()
		front.call("close_terminal")
	cam.global_position += cam.global_basis.z * 20
	await frames(2)
	check(front.get("aimed") == -1 and not HudSlots.pointer_claimed(), "looking away drops the pointer and gives the click back")

	# The full terminal: add two listings, set quantities, place the order.
	var term: Control = front.call("open_terminal")
	check(front.get("overlay") != null and term != null, "the terminal opens full size")
	await frames(2)
	var tabs := term.find_children("*", "Button", true, false).map(func(b): return b.text)
	check(tabs.any(func(x): return "GOODS IN" in str(x).to_upper()) and tabs.any(func(x): return "ACCOUNTS" in str(x).to_upper()),
			"every wrist channel is a tab, goods in too: %s" % str(tabs))
	var screen: Control = term.find_child("Channel", true, false)
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
	check(bus.wrist_basket.is_empty(), "the purchase order clears")
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
