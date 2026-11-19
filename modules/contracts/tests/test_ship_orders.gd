extends ModuleTest
## Contracts: orders for new ships (ShipOrders, ShipClients, Wave 4): clients with back
## stories in every sector post kinds of ship from small to mega, each with several criteria
## (demands on the finished ship's ratings and special clauses), and a budget judged against
## the cheapest build (achievability).
##   tools/run_tests.sh contracts


func run_tests() -> void:
	_board()
	_variety()
	_achievability()
	_masses()
	_legacy_and_locks()
	_berths()


func _board() -> void:
	var a := ShipOrders.for_cycle(3)
	var b := ShipOrders.for_cycle(3)
	check(a.size() == ShipOrders.PER_CYCLE, "a cycle posts %d orders: %d" % [ShipOrders.PER_CYCLE, a.size()])
	check(JSON.stringify(a) == JSON.stringify(b), "the same cycle posts the same orders on every machine")
	check(JSON.stringify(a) != JSON.stringify(ShipOrders.for_cycle(4)), "another cycle posts others")
	var clients := {}
	for o in a:
		clients[o.client] = true
		check(ShipClients.has(str(o.client)) and ShipOrders.ROLES.has(str(o.role)), "order %s names a client and a kind of ship" % o.id)
		check(str(ShipClients.TABLE[o.client].sector) == str(o.sector), "the client orders ships of its own sector")
		check(o.demands.has("budget") and int(o.pay) > 0 and int(o.days) >= 15 and int(o.estimate) > 0, "it has a budget, a fee, a due time and an estimate")
		check(ShipOrders.demand_lines(o).size() == o.demands.size(), "every demand reads as a line")
		check(str(o.story).length() > 40, "the client has a back story")
	check(clients.size() == a.size(), "one order per client")
	for id: String in ShipClients.TABLE:
		check(ShipOrders.ROLES.values().any(func(r): return r.sector == ShipClients.TABLE[id].sector), "%s's sector has ships to order" % id)
	var bus := Modules.bus("contracts") as ContractsBus
	if bus and Flags.is_on(ContractsBus.SHIP_ORDERS_FLAG):
		var want := ShipOrders.PER_CYCLE if Flags.is_on(ContractsBus.SHIP_VARIETY_FLAG) else ShipOrders.LEGACY_PER_CYCLE
		check(bus.ship_orders().size() == want, "the board posts this cycle's ship orders")


## Over a few months every sector, size, kind of ship and clause turns up, and every order
## has several criteria to meet.
func _variety() -> void:
	var seen := {}
	var few := 99
	var sizes_cost := {}
	for c in range(80):
		for o in ShipOrders.for_cycle(c):
			for k in o.demands:
				seen["demand:" + k] = true
			for cl in o.clauses:
				seen["clause:" + str(cl.id)] = true
				check(ShipOrders.CLAUSES.has(str(cl.id)), "clause %s is one the catalogue knows" % cl.id)
			seen["sector:" + str(o.sector)] = true
			seen["size:" + str(o.size)] = true
			seen["role:" + str(o.role)] = true
			few = mini(few, ShipOrders.criteria_count(o) - 1)
			var s: Array = sizes_cost.get(o.size, [])
			s.append(int(o.estimate))
			sizes_cost[o.size] = s
	for sector in ShipClients.SECTORS:
		check(seen.has("sector:" + sector), "%s ships are ordered" % sector)
	for size in ShipOrders.SIZE_ORDER:
		check(seen.has("size:" + size), "%s ships are ordered" % size)
	var roles := 0
	for r in ShipOrders.ROLES:
		roles += 1 if seen.has("role:" + r) else 0
	check(roles >= ShipOrders.ROLES.size() - 2, "nearly every kind of ship turns up in 80 cycles: %d of %d" % [roles, ShipOrders.ROLES.size()])
	for k in ["jump_ly", "speed", "defence", "attack", "stealth", "sensor_km", "cargo_m3", "crew", "power",
			"fuel_mass", "wet_mass", "occupancy_mass", "cargo_max"]:
		check(seen.has("demand:" + k), "some orders demand %s" % k)
	var clauses := 0
	for id in ShipOrders.CLAUSES:
		clauses += 1 if seen.has("clause:" + id) else 0
	check(clauses >= ShipOrders.CLAUSES.size() - 3, "most special clauses turn up: %d of %d" % [clauses, ShipOrders.CLAUSES.size()])
	check(few >= 3, "every order sets at least three criteria besides its budget: %d" % few)
	var med := func(a: Array) -> int:
		a.sort()
		return int(a[a.size() / 2])
	var last := 0
	for size in ShipOrders.SIZE_ORDER:
		var m: int = med.call(sizes_cost[size])
		print("ship orders: %s median estimate CR %s" % [size, m])
		check(m > last, "a %s ship costs more than the size below: CR %d" % [size, m])
		last = m
	check(med.call(sizes_cost.mega) > 20 * med.call(sizes_cost.small), "a mega project is many times a small ship")


## Budgets against the cheapest build: the labels cover the range, and a stealth bomber on
## half a million is not worth bidding for.
func _achievability() -> void:
	var labels := {}
	for c in range(80):
		for o in ShipOrders.for_cycle(c):
			labels[o.achievability.label] = int(labels.get(o.achievability.label, 0)) + 1
			var a: Dictionary = ShipOrders.achievability(float(o.budget), float(o.estimate))
			check(a.label == o.achievability.label, "the label follows the budget and estimate")
	print("ship orders: achievability over 80 cycles %s" % [labels])
	for row in ShipOrders.ACHIEVABILITY:
		check(labels.has(row[1]), "some orders are %s" % row[1])
	check(int(labels.get("Fair", 0)) + int(labels.get("Generous", 0)) + int(labels.get("Tight", 0)) > int(labels.get("Unrealistic", 0)) * 3,
			"most orders can be built for the money")
	var bomber := {"attack": 120.0, "stealth": 60.0, "speed": 200.0, "crew": 2.0}
	var est := ShipOrders.estimate(bomber, [ShipOrders.clause("quiet_drives")])
	check(est > 700000.0, "a stealth bomber costs well over CR 700,000 to build: CR %d" % int(est))
	check(ShipOrders.achievability(500000.0, est).label == "Unrealistic", "and CR 500,000 for one is Unrealistic")
	check(ShipOrders.estimate({"crew": 2.0, "attack": 120.0, "speed": 200.0}) < est, "being quiet costs extra")
	check(ShipOrders.estimate({"cargo_m3": 400.0, "crew": 3.0, "jump_ly": 8.0}) < ShipOrders.estimate({"cargo_m3": 400.0, "crew": 3.0, "jump_ly": 16.0}),
			"longer range costs more")


func _masses() -> void:
	var rng := RandomNumberGenerator.new()
	var haul := ShipOrders.make("brine_freight", "hauler", "small", rng, "t")
	check(float(haul.demands.fuel_mass) >= 8000.0 and int(haul.demands.fuel_mass) % 1000 == 0, "a hauler asks for whole tonnes of fuel")
	var lines := " ".join(ShipOrders.demand_lines(haul))
	check(lines.contains("Fuel load at least") and lines.contains(" t"), "masses read in tonnes: %s" % lines)
	var e := ShipOrders.equivalent({"fuel_mass": 16000.0, "occupancy_mass": 1000.0, "cargo_max": 40000.0})
	check(is_equal_approx(float(e.fuel_m3), 20.0) and int(e.crew) == 10 and is_equal_approx(float(e.cargo_m3), 100.0),
			"mass demands read as fuel, people and hold space for the estimate")
	check(ShipOrders.estimate({"cargo_max": 80000.0, "crew": 3.0}) > ShipOrders.estimate({"cargo_max": 20000.0, "crew": 3.0}), "a bigger load costs more")


func _legacy_and_locks() -> void:
	var old := ShipOrders.for_cycle(5, ShipOrders.PER_CYCLE, false)
	check(old.size() == ShipOrders.LEGACY_PER_CYCLE, "with the variety off, the four old orders a cycle")
	for o in old:
		check(ShipOrders.ROLES[o.role].get("legacy", false) and (o.clauses as Array).is_empty(), "of the old kinds, with no clauses: %s" % o.role)
	var none := func(_id: String) -> int: return 0
	var any_locked := false
	var any_open := false
	for c in range(20):
		for o in ShipOrders.for_cycle(c, ShipOrders.PER_CYCLE, true, none):
			if o.locked:
				any_locked = true
				check(int(o.needs_level) > 0 and o.size in ["large", "capital", "mega", "giga"], "only big ships need standing: %s" % o.size)
			else:
				any_open = true
	check(any_locked and any_open, "a new yard can bid for small and medium ships; bigger ones need standing first")
	var all_in := func(_id: String) -> int: return 3
	for o in ShipOrders.for_cycle(7, ShipOrders.PER_CYCLE, true, all_in):
		check(not o.locked, "a preferred yard can bid for anything")


## Each order says how long the ship comes out and the build berth it needs: small ships fit
## the starter berth, a giga project the giga berth; top standing reaches every size.
func _berths() -> void:
	var by_size := {}
	var levels := func(_id: String) -> int: return 3
	for cycle in range(1, 120):
		for o: Dictionary in ShipOrders.for_cycle(cycle, ShipOrders.PER_CYCLE, true, levels):
			check(not o.locked, "top standing with every client opens every order")
			var tiers: Array = by_size.get(o.size, [])
			tiers.append(int(o.berth))
			by_size[o.size] = tiers
			check(int(o.length_m) > 0 and int(o.berth) == ShipOrders.berth_for(float(o.length_m)) or int(o.berth) == ShipOrders.berth_for(float(o.length_m) + 1.0),
					"an order's berth fits its length")
	check(by_size.has("giga"), "giga projects turn up")
	check((by_size.small as Array).max() == 1 and (by_size.medium as Array).max() == 1, "small and medium ships fit the starter berth")
	check((by_size.get("giga", [0]) as Array).max() >= 3 and (by_size.get("mega", [0]) as Array).max() >= 3, "the biggest projects need the biggest berths")
	print("ship orders: berths by size ", by_size.keys().map(func(k): return "%s %s-%s" % [k, (by_size[k] as Array).min(), (by_size[k] as Array).max()]))
