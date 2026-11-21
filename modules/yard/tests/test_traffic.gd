extends ModuleTest
## Goods in and the stores' bots (0.4.0 playtest): buying parts sends haulers to the berths
## outside goods in; bots draw the loads out with the tractor's grip field, set them down in
## the haulers' bays, put each away in a rack place of its kind; parts asked for at the yard
## side come off the racks and out to the build berth.
##   tools/run_tests.sh yard

const Traffic := preload("res://modules/yard/internal/stores_traffic.gd")
const BotLook := preload("res://modules/yard/internal/yard_bot_look.gd")


func run_tests() -> void:
	var store := YardRackStore.new()
	store.fill_demo(0.3)
	var traffic := Traffic.new()
	traffic.set_process(false)
	add_child(traffic)
	traffic.build(store)
	check(traffic.bots.size() == traffic.store_bots + traffic.yard_bots, "%d bots" % traffic.bots.size())
	check(not traffic.busy(), "quiet before a contract")
	_routes(traffic, store)
	await _freighter()
	await _kits()
	await _lines_ships()

	var order := [{"part": "HullPlate", "qty": 60}, {"part": "BoxBeam", "qty": 10}, {"part": "JunctionBox", "qty": 12},
			{"part": "HydrogenEngine", "qty": 2}, {"part": "Reactor", "qty": 1}, {"part": "Pipe", "qty": 25},
			{"part": "Radiator", "qty": 6}, {"part": "Generator", "qty": 2}, {"part": "DeckPlate", "qty": 15},
			{"part": "FuelTank", "qty": 2}, {"part": "Girder", "qty": 9}]
	var before := {}
	var bought := 0
	for it: Dictionary in order:
		before[it.part] = store.count(it.part)
		bought += int(it.qty)
	var got := {"n": 0}
	traffic.delivered.connect(func(_p: String, q: int) -> void: got.n += q)
	traffic.order(order)
	check(traffic.haulers.size() == 4, "four haulers come in at once")
	check(not traffic.backlog.is_empty(), "the rest wait for a berth")
	var brands := {}
	for h in traffic.haulers:
		brands[h.brand.id] = true
	check(brands.size() == 4, "each hauler is a different freight line (%s)" % str(brands.keys()))
	var seen := {"berthed": false, "bay": false, "grip": false, "rack_slide": false, "hauler_max": 0, "crew": false, "upstairs": false}
	var t := 0.0
	while traffic.busy() and t < 900.0:
		traffic.step(0.1)
		t += 0.1
		for h in traffic.haulers:
			if h.state == "open":
				seen.berthed = true
		for l in traffic.loads:
			if l.where == "bay":
				seen.bay = true
		for b in traffic.bots:
			if (b.grip as YardFieldGrip).holding():
				seen.grip = true
				if b.has("hauler"):
					seen.crew = true
				if (b.node as Node3D).global_position.y > YardRackStore.UPPER_FLOOR_Y + 1.0 and (b.node as Node3D).global_position.x < YardRackStore.UPPER_EDGE_X:
					seen.upstairs = true
	check(not traffic.busy(), "every delivery is put away (%.0f s)" % t)
	check(seen.berthed and seen.bay, "haulers berthed and loads were set down at goods in")
	check(seen.grip, "the bots carry with the tractor's grip field")
	var all_in := true
	for it: Dictionary in order:
		all_in = all_in and store.count(it.part) == int(before[it.part]) + int(it.qty)
	check(all_in, "the stores hold every part bought")
	check(got.n == bought, "%d of %d parts reported delivered" % [got.n, bought])
	check(store.pending.is_empty(), "no rack place still waiting")
	var kinds_right := true
	for s in store.slots:
		if s.part != "":
			kinds_right = kinds_right and YardRackStore.kind_of(s.part) == int(YardRackStore.RACKS[int(s.rack)].kind)
	check(kinds_right, "every part went to a rack of its kind")
	check(traffic.haulers.is_empty(), "the haulers have left")
	check(bool(seen.crew), "the haulers' own bots helped unload them")
	check(traffic.bots.size() == traffic.store_bots + traffic.yard_bots, "and went home aboard them (%d bots)" % traffic.bots.size())
	check(bool(seen.upstairs), "bots carried loads to the upper storey")

	# The yard asks for parts: off the racks, to the yard side, out to the build berth.
	var plates := store.count("HullPlate")
	var beams := store.count("BoxBeam")
	var sent := {"n": 0}
	traffic.sent.connect(func(_p: String, q: int) -> void: sent.n += q)
	traffic.send_to_yard([{"part": "HullPlate", "qty": 20}, {"part": "BoxBeam", "qty": 6}])
	t = 0.0
	while traffic.busy() and t < 600.0:
		traffic.step(0.1)
		t += 0.1
	check(not traffic.busy(), "the yard's parts are out (%.0f s)" % t)
	check(store.count("HullPlate") == plates - 20 and store.count("BoxBeam") == beams - 6, "taken off the racks")
	check(sent.n == 26, "26 parts set down at the build berth (%d)" % sent.n)
	var berth: AABB = YardLayout.BERTHS[0].box
	var at_berth := traffic.loads.filter(func(l: Dictionary) -> bool: return l.where == "berth")
	check(not at_berth.is_empty(), "loads wait at the berth")
	var inside := true
	for l in at_berth:
		inside = inside and berth.has_point((l.node as Node3D).global_position)
	check(inside, "inside the build berth")
	traffic.queue_free()


## Between storeys a bot goes by the well, never through the upper deck; out to a hauler by
## goods in's opening, never through the wall over it (0.4.1).
func _routes(traffic: Node, store: YardRackStore) -> void:
	var low := -1
	var high := -1
	for i in store.slots.size():
		var y := store.slot_position(i).y
		if low < 0 and YardRackStore.storey_of(y) == 0:
			low = i
		if high < 0 and YardRackStore.storey_of(y) == 1:
			high = i
	var bay := (YardRackStore.GOODS_IN_BAYS[0] as AABB).get_center()
	var mouth := YardRackStore.HAULER_BERTHS[0] + Vector3(-11.0, 1.0, 0.0)
	var trips := [[bay, store.pick_point(high)], [store.pick_point(high), store.pick_point(low)],
			[store.pick_point(low), store.pick_point(high)], [store.pick_point(high), (YardRackStore.DISPATCH_BAYS[0] as AABB).get_center()],
			[mouth, store.pick_point(high)], [store.pick_point(high), mouth], [mouth, bay]]
	var deck_y := YardRackStore.UPPER_FLOOR_Y - 0.2
	for trip: Array in trips:
		for index in [0, 3]:
			var path: Array = [trip[0]] + (traffic.call("_route", trip[0], trip[1], index) as Array)
			var through_deck := false
			var through_wall := false
			for j in path.size() - 1:
				var a: Vector3 = path[j]
				var b: Vector3 = path[j + 1]
				if (a.y - deck_y) * (b.y - deck_y) < 0.0:
					var t := (deck_y - a.y) / (b.y - a.y)
					through_deck = through_deck or a.lerp(b, t).x < YardRackStore.UPPER_EDGE_X
				if (a.x - 84.0) * (b.x - 84.0) < 0.0:
					var t := (84.0 - a.x) / (b.x - a.x)
					through_wall = through_wall or a.lerp(b, t).y > 11.5
			check(not through_deck and not through_wall and (path.back() as Vector3).is_equal_approx(trip[1]),
					"bot %d from %s to %s: by the well and the opening (%s)" % [index, trip[0], trip[1], str(path)])


## A big order brings the bulk freighter (0.4.1): she berths alongside goods in, her door's
## leaves part, her own bots and the stores' empty her hold, and she leaves; what she could
## not carry follows by hauler.
func _freighter() -> void:
	var store := YardRackStore.new()
	store.fill_demo(0.2)
	var traffic := Traffic.new()
	traffic.set_process(false)
	add_child(traffic)
	traffic.build(store)
	var order := [{"part": "HullPlate", "qty": 240}, {"part": "BoxBeam", "qty": 60}, {"part": "JunctionBox", "qty": 40},
			{"part": "FuelTank", "qty": 4}, {"part": "Pipe", "qty": 60}]
	var loads := 20 + 10 + 5 + 4 + 6
	traffic.order(order)
	check(traffic.haulers.size() == 1 and traffic.haulers[0].kind == "ship", "a big order (%d loads) brings the freighter" % loads)
	var ship: Dictionary = traffic.haulers[0]
	check((ship.loads as Array).size() == traffic.ship_loads and traffic.backlog.size() == loads - traffic.ship_loads,
			"she carries %d loads, the rest wait" % traffic.ship_loads)
	check((ship.crew as Array).size() == traffic.ship_crew, "with her own crew of bots")
	var seen := {"open": false, "crew": false, "inside": true, "after": false}
	var t := 0.0
	var start := {}
	for it: Dictionary in order:
		start[it.part] = store.count(it.part)
	while traffic.busy() and t < 1500.0:
		traffic.step(0.1)
		t += 0.1
		if traffic.haulers.has(ship) and ship.state == "open":
			var top: Node3D = (ship.node as Node3D).get_node("DoorTop")
			seen.open = seen.open or top.position.y > 7.0
			for b: Dictionary in ship.crew:
				seen.crew = seen.crew or not bool(b.aboard)
		for h in traffic.haulers:
			if h.kind == "hauler" and not traffic.haulers.has(ship):
				seen.after = true
	check(not traffic.busy(), "everything she and the haulers brought is put away (%.0f s)" % t)
	check(bool(seen.open) and bool(seen.crew), "her door opened and her bots came out to help")
	check(bool(seen.after), "the rest came by hauler after she left")
	var all_in := true
	for it: Dictionary in order:
		all_in = all_in and store.count(it.part) == int(start[it.part]) + int(it.qty)
	check(all_in, "the stores hold all of it")
	check(traffic.bots.size() == traffic.store_bots + traffic.yard_bots, "and every visiting bot went home aboard")
	traffic.queue_free()
	await frames(1)


## Mover bots (0.4.1): a kit goes off the racks to wherever its target is, by the corridor into
## a room, out of the open face to the dock, and follows it; the worker bots in the build berth
## ask for frame kits and weld each on as a ring.
func _kits() -> void:
	var store := YardRackStore.new()
	store.fill_demo(0.6)
	var traffic := Traffic.new()
	traffic.set_process(false)
	add_child(traffic)
	traffic.build(store)
	var you := Node3D.new()
	add_child(you)
	you.global_position = Vector3(32.0, 1.2, 8.0)   # in the sleeping quarters
	var got := {"id": -1}
	traffic.kit_delivered.connect(func(id: int, _k: String) -> void: got.id = id)
	var beams := store.count("BoxBeam")
	var id: int = traffic.deliver_kit("frame", you)
	check(id > 0, "a frame kit is on its way")
	var corridor := false
	var through_wall := false
	var t := 0.0
	while got.id != id and t < 400.0:
		traffic.step(0.1)
		t += 0.1
		for b: Dictionary in traffic.bots:
			if b.yard:
				var p := (b.node as Node3D).global_position
				if absf(p.z - -2.0) < 0.6 and p.y < 3.0 and p.x > 28.0 and p.x < 34.0:
					corridor = true
				if p.z > -3.8 and p.z < 0.0 and p.y > 3.2:
					through_wall = true
		if t > 20.0 and t < 21.0:
			you.global_position = Vector3(26.0, 1.2, 6.0)   # you walk off down the aisle
	check(got.id == id, "the kit arrived (%.0f s)" % t)
	check(store.count("BoxBeam") == beams - 2, "its parts came off the racks")
	var o: Dictionary = traffic.kit_order(id)
	var near := (o.loads as Array).all(func(l: Dictionary) -> bool: return (l.node as Node3D).global_position.distance_to(Vector3(26.0, 0.0, 6.0)) < 3.5)
	check((o.loads as Array).size() >= 2 and near, "set down by you where you went, not where you were")
	check(corridor and not through_wall, "the mover came along the corridor, under its ceiling")
	var on_floor := (o.loads as Array).all(func(l: Dictionary) -> bool: return absf((l.node as Node3D).global_position.y) < 0.05)
	check(on_floor, "on the quarters' floor")
	# Home again, and the loads go back after a while.
	for i in 900:
		traffic.step(0.25)
	check((o.loads as Array).all(func(l: Dictionary) -> bool: return not traffic.loads.has(l)), "uncollected kits go back after a while")
	var homes := traffic.bots.filter(func(b: Dictionary) -> bool: return b.yard and (b.node as Node3D).position.distance_to(b.home) < 0.5)
	check(homes.size() == traffic.yard_bots, "the movers are home")
	# Out to the dock.
	you.global_position = Vector3(-5.0, -2.0, -80.0)
	got.id = -1
	id = traffic.deliver_kit("power", you)
	t = 0.0
	while got.id != id and t < 400.0:
		traffic.step(0.1)
		t += 0.1
	o = traffic.kit_order(id)
	check(got.id == id and (o.loads as Array).all(func(l: Dictionary) -> bool: return (l.node as Node3D).global_position.distance_to(you.global_position) < 4.0),
			"a power kit brought out to you in zero g")
	# The worker bots build.
	var Workers := load("res://modules/yard/internal/yard_workers.gd")
	var crew: Node3D = Workers.new()
	crew.set_process(false)
	add_child(crew)
	crew.build(traffic)
	var rings: int = crew.rings_built()
	t = 0.0
	while crew.rings_built() == rings and t < 600.0:
		traffic.step(0.2)
		crew.step(0.2)
		t += 0.2
	check(crew.rings_built() == rings + 1, "the worker bots asked for a keel ring kit, carried, welded and riveted it on as a ring (%.0f s)" % t)
	var roles: Array = crew.workers.map(func(w: Dictionary) -> String: return w.role)
	check(roles.has("F") and roles.has("W") and roles.has("R"), "fitters, welders and riveters in the crew")
	var arms: Node3D = crew.workers[0].node
	check(arms.has_node("UpperR") and arms.has_node("ForeL") and arms.has_node("HandR"), "the workers have jointed arms")
	var movers_waited: bool = traffic.kit_orders.any(func(o: Dictionary) -> bool: return bool(o.get("wait", false)) and (o.loads as Array).size() > 0)
	check(movers_waited, "the movers brought the ring's stock and waited by the keel with it")
	# Wear, a fault and TartanCo. She never comes out while every bot is in fair shape.
	for w: Dictionary in crew.workers:
		w.wear = minf(float(w.wear), 0.5)
		w.fault = ""
	check(not crew.call_service() and crew.service.state == "away", "TartanCo stays away while no bot is in poor condition")
	var worn: Dictionary = crew.workers[2]
	worn.wear = 0.95
	worn.fault = "E-17 ACTUATOR"
	t = 0.0
	while crew.service.state == "away" and t < 30.0:
		traffic.step(0.2)
		crew.step(0.2)
		t += 0.2
	check(crew.service.state != "away", "a faulted bot sends for TartanCo")
	check(crew.pace(worn) < 0.7, "a worn bot works slower")
	t = 0.0
	while (worn.fault != "" or float(worn.wear) > 0.0) and t < 400.0:
		traffic.step(0.2)
		crew.step(0.2)
		t += 0.2
	check(worn.fault == "" and is_zero_approx(float(worn.wear)), "TartanCo's engineers put it right (%.0f s)" % t)
	check(crew.service.bay_services >= 1, "the faulted bot was taken aboard and serviced in a bay")
	check(not bool(worn.get("external", false)), "and handed back to the crew")
	check(crew.service.team.all(func(e: Dictionary) -> bool: return (e.node as Node3D).has_node("ShoulderR/Wand")), "TartanCo's engineers are suited people with wands")
	t = 0.0
	while crew.service.state != "away" and t < 400.0:
		traffic.step(0.2)
		crew.step(0.2)
		t += 0.2
	check(crew.service.state == "away" and crew.service.visits >= 1, "and their ship leaves again (%.0f s)" % t)
	worn.fault = "E-17 ACTUATOR"
	check(not crew.call_service(), "she won't come straight back: visits are at least %.0f s apart" % crew.service.min_gap)
	crew.service.since_visit = crew.service.min_gap
	check(crew.call_service(), "and comes again once the gap is up")
	worn.fault = ""
	crew.queue_free()
	traffic.queue_free()
	you.queue_free()
	await frames(1)


## The freight lines' own ships (19 Nov, flag yard.delivery_ships): a small order comes by
## courier, a bigger one by hauler, each in its line's design with its name aboard; the lids
## over the frames stand up and the loads are drawn straight up out of them, over the command
## module, to goods in.
func _lines_ships() -> void:
	const Ships := preload("res://modules/yard/internal/yard_delivery_ships.gd")
	Flags.set_flag(YardBus.DELIVERY_SHIPS, true)
	var store := YardRackStore.new()
	store.fill_demo(0.2)
	var traffic := Traffic.new()
	traffic.set_process(false)
	add_child(traffic)
	traffic.build(store)
	traffic.order([{"part": "Generator", "qty": 2}])
	check(traffic.haulers.size() == 1 and traffic.haulers[0].size == Ships.SMALL, "two loads come by courier")
	var courier: Dictionary = traffic.haulers[0]
	check((courier.crew as Array).size() == 1, "with one bot of her own")
	traffic.order([{"part": "HullPlate", "qty": 60}])
	var hauler: Dictionary = traffic.haulers[1]
	check(hauler.size == Ships.MEDIUM, "five loads come by hauler")
	check(courier.brand.id != hauler.brand.id, "from different lines")
	var named := false
	for c in (hauler.node as Node3D).get_children():
		named = named or (c is Label3D and (c as Label3D).text == String(hauler.brand.name))
	check(named, "her line's name is on her side")
	var seen := {"open": false, "high": false}
	var t := 0.0
	while traffic.busy() and t < 600.0:
		traffic.step(0.1)
		t += 0.1
		for h in traffic.haulers:
			seen.open = seen.open or Ships.open_of(h.node) > 0.95
		for b in traffic.bots:
			var l: Dictionary = b.carrying
			if not l.is_empty() and l.where == "carried" and (b.node as Node3D).global_position.x > 90.0:
				seen.high = seen.high or (b.node as Node3D).global_position.y > YardRackStore.HAULER_BERTHS[0].y + Ships.clear_y(Ships.MEDIUM)
	check(not traffic.busy(), "both put away (%.0f s)" % t)
	check(bool(seen.open), "the frames' lids stood open")
	check(bool(seen.high), "loads were drawn up clear of the command module")
	check(store.count("Generator") >= 2, "the stores hold the courier's load")
	# They leave by warp (21 Nov, flag yard.warp_out): a spool, a jump that stretches the ship
	# out along her heading, a flash and its sound, and she is gone.
	if Flags.is_on(YardBus.WARP_OUT):
		check(traffic.warps == 2, "both left by warp (%d)" % traffic.warps)
		var w: Node3D = null
		for c in traffic.get_children():
			if String(c.name).begins_with("Warp_"):
				w = c
		check(w != null and w.get("ship") != null, "the warp has her")
		if w != null:
			w.set_process(false)
			var her: Node3D = w.get("ship")
			var sound := w.get_node_or_null("Sound") as AudioStreamPlayer3D
			check(sound == null or sound.stream == YardSoundBank.stream("warp_jump"), "with the warp's own sound")
			check(YardSoundBank.stream("warp_jump") != null and YardSoundBank.stream("warp_jump").get_length() > 2.5, "a warp sound made in code")
			w.call("advance", float(w.get("spool")) + 0.2)
			check(w.get("phase") == "jump", "spooled up, she jumps")
			var stretched := (her.get_parent() as Node3D).basis * Vector3.RIGHT
			check(stretched.length() > 5.0, "stretched out along her heading (x%.0f)" % stretched.length())
			w.call("advance", 0.2)
			w.call("advance", 0.1)
			check(not is_instance_valid(her) or her.is_queued_for_deletion(), "and she is gone")
			w.call("advance", 3.0)
			check(w.get("phase") == "done", "the flash fades")
	for size: String in Ships.SIZES:
		for brand: Dictionary in BotLook.BRANDS:
			var ship := Ships.make(brand, size)
			check(ship.get_node_or_null("Hull") != null and (ship.get_node("Hull") as MeshInstance3D).mesh.get_surface_count() > 0, "%s's %s is built" % [brand.id, size])
			ship.free()
	traffic.queue_free()
	await frames(1)
