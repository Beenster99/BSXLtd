extends ModuleTest
## Goods in and the stores' bots (0.4.0 playtest): buying parts sends haulers to the berths
## outside goods in; bots draw the loads out with the tractor's grip field, set them down in
## the haulers' bays, put each away in a rack place of its kind; parts asked for at the yard
## side come off the racks and out to the build berth.
##   tools/run_tests.sh yard

const Traffic := preload("res://modules/yard/internal/stores_traffic.gd")


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
