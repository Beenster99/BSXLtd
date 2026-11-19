extends ModuleTest
## Contracts: orders for new ships (ShipOrders): what BSX's clients post for the design
## office, with demands on the finished ship's ratings.
##   tools/run_tests.sh contracts


func run_tests() -> void:
	var a := ShipOrders.for_cycle(3)
	var b := ShipOrders.for_cycle(3)
	check(a.size() == ShipOrders.PER_CYCLE, "a cycle posts %d orders: %d" % [ShipOrders.PER_CYCLE, a.size()])
	check(JSON.stringify(a) == JSON.stringify(b), "the same cycle posts the same orders on every machine")
	check(JSON.stringify(a) != JSON.stringify(ShipOrders.for_cycle(4)), "another cycle posts others")
	var clients := {}
	for o in a:
		clients[o.client] = true
		check(ContractClients.has(str(o.client)) and ShipOrders.ROLES.has(str(o.role)), "order %s names a client and a kind of ship" % o.id)
		check(o.demands.has("budget") and int(o.pay) > 0 and int(o.days) >= 20, "it has a budget, pay and a due time")
		check(ShipOrders.demand_lines(o).size() == o.demands.size(), "every demand reads as a line")
	check(clients.size() == a.size(), "one order per client")
	var seen := {}
	for c in range(40):
		for o in ShipOrders.for_cycle(c):
			for k in o.demands:
				seen[k] = true
	for k in ["jump_ly", "speed", "defence", "attack", "stealth"]:
		check(seen.has(k), "some orders demand %s" % k)
	var bus := Modules.bus("contracts") as ContractsBus
	check(bus.ship_orders().size() == ShipOrders.PER_CYCLE, "the board posts this cycle's ship orders")
