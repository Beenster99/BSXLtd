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

	var order := [{"part": "hull_plate", "qty": 60}, {"part": "box_beam_6", "qty": 10}, {"part": "junction_box", "qty": 12},
			{"part": "hydrogen_engine", "qty": 2}, {"part": "reactor", "qty": 1}, {"part": "pipe_4", "qty": 25},
			{"part": "radiator", "qty": 6}, {"part": "generator", "qty": 2}, {"part": "deck_plate", "qty": 15},
			{"part": "tank_large", "qty": 2}, {"part": "girder_4", "qty": 9}]
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
	var seen := {"berthed": false, "bay": false, "grip": false, "rack_slide": false, "hauler_max": 0}
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

	# The yard asks for parts: off the racks, to the yard side, out to the build berth.
	var plates := store.count("hull_plate")
	var beams := store.count("box_beam_6")
	var sent := {"n": 0}
	traffic.sent.connect(func(_p: String, q: int) -> void: sent.n += q)
	traffic.send_to_yard([{"part": "hull_plate", "qty": 20}, {"part": "box_beam_6", "qty": 6}])
	t = 0.0
	while traffic.busy() and t < 600.0:
		traffic.step(0.1)
		t += 0.1
	check(not traffic.busy(), "the yard's parts are out (%.0f s)" % t)
	check(store.count("hull_plate") == plates - 20 and store.count("box_beam_6") == beams - 6, "taken off the racks")
	check(sent.n == 26, "26 parts set down at the build berth (%d)" % sent.n)
	var berth: AABB = YardLayout.BERTHS[0].box
	var at_berth := traffic.loads.filter(func(l: Dictionary) -> bool: return l.where == "berth")
	check(not at_berth.is_empty(), "loads wait at the berth")
	var inside := true
	for l in at_berth:
		inside = inside and berth.has_point((l.node as Node3D).global_position)
	check(inside, "inside the build berth")
	traffic.queue_free()
