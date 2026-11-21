extends ModuleTest
## Wave 7 as data: a build's parts list from its design, each line with its build stage; the
## vendors' quotes; a line split across two vendors; the calculator's plans; placing the order
## (the company pays, the vendors think better of the yard); the build waiting for its parts
## till they come; deliveries into the company's stock; a second-hand part through the refurb
## works; two ships on the go, one towed to a holding berth and back; it all saves and loads.
##   tools/run_tests.sh orders


func run_tests() -> void:
	for f: String in [BuildBus.FLAG, BuildBus.HAND_FLAG, BuildBus.BOT_FLAG, BuildBus.HOLDING_FLAG, OrdersBus.FLAG,
			OrdersBus.GATE_FLAG, OrdersBus.USED_FLAG]:
		Flags.set_flag(f, true)
	Flags.set_flag("company.growth", false)  # the yard's rank does not hold the test back
	var build := Modules.bus("build") as BuildBus
	var orders := Modules.bus("orders") as OrdersBus
	var supply := Modules.bus("supply") as SupplyBus
	check(build != null and orders != null and supply != null, "the build, orders and supply modules are loaded")
	if build == null or orders == null or supply == null:
		return
	for id: String in build.builds.keys():
		build.stop(id)
	orders.reset_data()
	var biz := Modules.bus("business")
	if biz:
		biz.call("credit", 80000000, "test", "test cash")
	var cat := orders.catalog()
	var rec := DesignRecord.new()
	rec.name = "Order test skiff"
	DesignBus.Samples.skiff(rec, cat)
	build.start("order_test", rec.to_dict(), rec.name)
	await frames(1)
	check(build.current == "order_test" and build.berth_of("order_test") == "B1", "the first ship goes to the build berth")
	check(orders.gated("order_test"), "a ship started with the gate on waits for her parts")

	# 7.1: the parts list and its quotes.
	var lines := orders.lines("order_test")
	check(lines.size() >= 6, "her parts list has lines (%d)" % lines.size())
	# Parts held from trading cover a line at no new cost.
	Flags.set_flag(OrdersBus.SELL_FLAG, true)
	var held_line := {}
	for l: Dictionary in lines:
		if str(l.kind) == "component" and not orders.trade_line(str(l.key)).is_empty() and int(l.units) >= 2:
			held_line = l
			break
	if held_line.is_empty():
		for l: Dictionary in lines:
			if str(l.kind) == "component" and not orders.trade_line(str(l.key)).is_empty():
				held_line = l
				break
	check(not held_line.is_empty(), "a line the yard can hold from trading")
	if not held_line.is_empty():
		var hk := str(held_line.key)
		orders.holdings[hk] = 1
		check(orders.stock_can_cover("order_test", hk) == 1, "one held part can go into the build")
		var cash := int(biz.call("get_cash")) if biz else 0
		orders.use_held("order_test", hk, 5)
		var after := orders.line("order_test", hk)
		var per := float(held_line.need) / maxf(1.0, float(held_line.units))
		check(int(orders.holdings.get(hk, 0)) == 0 and is_equal_approx(float(after.ordered), per) and is_equal_approx(float(after.arrived), per),
				"used from stock: no longer held, counted in and ordered (%.1f of %.1f)" % [float(after.arrived), float(held_line.need)])
		if biz:
			check(int(biz.call("get_cash")) == cash, "at no new cost")
		orders.use_held("order_test", hk, 1)
		check(is_equal_approx(float(orders.line("order_test", hk).ordered), per), "nothing more held, nothing more used")
		var saved := orders.save_data()
		orders.load_data(saved, OrdersBus.SAVE_VERSION)
		check(is_equal_approx(float(orders.line("order_test", hk).arrived), per), "and it keeps across a save")
	Flags.set_flag(OrdersBus.SELL_FLAG, false)
	lines = orders.lines("order_test")
	var stages := {}
	for l: Dictionary in lines:
		stages[str(l.stage)] = true
	check(stages.has("frame") and stages.has("plates") and stages.has("fittings"), "each line is for a build stage (%s)" % str(stages.keys()))
	check(not orders.stage_ready("order_test", "frame") and build.next_job("order_test") == -1,
			"nothing floats in before the frame's parts are in")
	check(str(build.progress("order_test").parts_wait).contains("not ordered"), "the berth says why (%s)" % str(build.progress("order_test").parts_wait))
	var frame_line: Dictionary = {}
	for l: Dictionary in lines:
		if str(l.key) == "hull:frame":
			frame_line = l
	check(not frame_line.is_empty(), "the frame has its line")
	var qs := orders.quotes("order_test", frame_line)
	check(qs.size() >= 2, "several vendors quote for it (%d)" % qs.size())
	if qs.size() >= 2:
		var need := float(frame_line.need)
		orders.set_split("order_test", "hull:frame", str(qs[0].vendor), ceilf(need * 0.6))
		orders.set_split("order_test", "hull:frame", str(qs[1].vendor), need)
		var sp: Array = orders.splits["order_test"]["hull:frame"]
		var total := 0.0
		for e: Dictionary in sp:
			total += float(e.qty)
		check(sp.size() == 2 and absf(total - need) < 0.01, "a line split across two vendors (%s)" % str(sp))
	var sums := orders.plan_sums("order_test")
	check(sums.has("cheapest") and sums.has("reliable") and sums.has("median") and sums.has("mine"), "the calculator sums every plan")
	check(float(sums.cheapest.total) <= float(sums.median.total) + 0.5, "the cheapest plan is no dearer than the median")

	# PLACE ORDER says why it can't go: nothing chosen, or not enough cash.
	var kept: Dictionary = (orders.splits.get("order_test", {}) as Dictionary).duplicate(true)
	orders.clear_splits("order_test")
	check(orders.place_problem("order_test").begins_with("Nothing chosen"), "with nothing chosen, PLACE ORDER says what to do")
	orders.splits["order_test"] = kept
	check(orders.place_problem("order_test") == "", "with a mix chosen and the cash, it can go")
	if biz:
		var all := int(biz.call("get_cash"))
		biz.call("charge", all, "test", "test: empty the bank")
		check(orders.place_problem("order_test").begins_with("Not enough cash") and orders.cheapest_problem("order_test").begins_with("Not enough cash"),
				"with no cash, both buttons say so (%s)" % orders.place_problem("order_test"))
		orders.place("order_test")
		check(orders.orders.is_empty(), "and nothing is ordered")
		# One stage at a time fits a smaller purse.
		var st := orders.next_stage("order_test")
		var st_cost := orders.stage_cheapest("order_test", st)
		check(st == "frame" and st_cost > 0 and st_cost < int(orders.plan_sums("order_test").cheapest.total),
				"the next stage to order is the frame, for less than the whole ship (CR %d)" % st_cost)
		biz.call("credit", st_cost + 10, "test", "test: enough for the frame")
		orders.order_stage_cheapest("order_test", st)
		check(not orders.orders.is_empty() and orders.lines("order_test").all(func(l: Dictionary) -> bool:
				return str(l.stage) != st or float(l.ordered) >= float(l.need) - 0.001), "the frame's parts ordered on their own")
		check(orders.next_stage("order_test") != st, "and the next stage moves on (%s)" % orders.next_stage("order_test"))
		orders.orders.clear()
		biz.call("credit", all, "test", "test: cash back")
	# Place it: the plan fills the lines not split yet.
	var standing_before := supply.standing_of(str(qs[0].vendor))
	var cash_before := int(biz.call("get_cash")) if biz else 0
	orders.use_plan("order_test", SupplyOptimiser.CHEAPEST)
	orders.set_split("order_test", "hull:frame", str(qs[0].vendor), ceilf(float(frame_line.need) * 0.6))
	orders.set_split("order_test", "hull:frame", str(qs[1].vendor), float(frame_line.need))
	orders.place("order_test")
	check(orders.orders.size() >= 2, "one order a vendor (%d)" % orders.orders.size())
	var lp: Dictionary = orders.last_placed.get("order_test", {})
	check(int(lp.get("orders", 0)) == orders.orders.size() and int(lp.get("total", 0)) > 0, "the screen can say what the order came to (%s)" % str(lp))
	if biz:
		check(int(biz.call("get_cash")) < cash_before, "the company paid for the parts")
	check(supply.standing_of(str(qs[0].vendor)) > standing_before, "the vendor thinks better of the yard")
	check(orders.lines("order_test").all(func(l: Dictionary) -> bool: return float(l.ordered) >= float(l.need) - 0.001),
			"every line is ordered")
	check(str(build.progress("order_test").parts_wait).contains("due"), "the berth says when they come (%s)" % str(build.progress("order_test").parts_wait))

	# 7.2: deliveries.
	var stock_before := int((biz.call("get_stock") as Dictionary).get("BoxBeam", 0)) if biz else 0
	for o: Dictionary in orders.orders:
		o.due = orders.now_minute()
		o.late = 0
	orders.deliver_due()
	check(orders.orders.all(func(o: Dictionary) -> bool: return bool(o.arrived)), "the orders come in")
	check(orders.stage_ready("order_test", "frame") and build.next_job("order_test") == 0, "the frame's parts are in: the first job can float in")
	if biz:
		check(int((biz.call("get_stock") as Dictionary).get("BoxBeam", 0)) > stock_before, "the beams go into the company's stock")
	orders._send_ready()
	check((orders.sent.get("order_test", []) as Array).has("frame"), "and out to the berth for the frame")

	# 7.3: a second-hand part through the refurb works.
	var comp: Dictionary = {}
	for l: Dictionary in orders.lines("order_test"):
		if str(l.kind) == "component":
			comp = l
			break
	check(not comp.is_empty(), "she has a component line")
	var used_q: Dictionary = {}
	for q: Dictionary in orders.quotes("order_test", comp):
		if str(q.vendor) == OrdersBus.USED:
			used_q = q
	var refurb := Modules.bus("refurb")
	if refurb:
		check(not used_q.is_empty(), "a second-hand quote for it")
	if not used_q.is_empty():
		var new_q: Dictionary = orders.quotes("order_test", comp)[0]
		check(float(used_q.unit) < float(new_q.unit) * 1.2, "second-hand comes cheaper or near it (%.0f against %.0f)" % [float(used_q.unit), float(new_q.unit)])
		# A second ship's worth, bought used: a fresh build to buy it for.
		var rec2 := DesignRecord.new()
		rec2.name = "Second skiff"
		DesignBus.Samples.skiff(rec2, cat)
		build.start("order_test_2", rec2.to_dict(), rec2.name)
		await frames(1)
		check(build.berth_of("order_test_2") == "H1", "the second ship waits in a holding berth (%s)" % build.berth_of("order_test_2"))
		orders.set_split("order_test_2", str(comp.key), OrdersBus.USED, float(comp.need))
		orders.place("order_test_2")
		var o2: Dictionary = orders.orders.back()
		check(str(o2.vendor) == OrdersBus.USED and bool(o2.lines[0].used), "a second-hand order")
		o2.due = orders.now_minute()
		o2.late = 0
		orders.deliver_due()
		var line2: Dictionary = orders.line("order_test_2", str(comp.key))
		check(float(line2.arrived) < float(line2.need), "it is in the refurb works, not in yet")
		for i in ceili(float(comp.need)):
			orders._on_certified(str(o2.lines[0].type), {})
		line2 = orders.line("order_test_2", str(comp.key))
		check(float(line2.arrived) >= float(line2.need) - 0.001, "certified, it counts as in (%.1f of %.1f, %s)" % [float(line2.arrived), float(line2.need), str(o2.lines)])

	# 7.4: two ships on the go: the first towed out to a holding berth, the second in.
	if build.builds.has("order_test_2"):
		build.move("order_test", "H2")
		check(build.berth_of("order_test") == "H2" and build.current == "", "the first ship is towed to H2: the build berth is free")
		build.move("order_test_2", "B1")
		check(build.current == "order_test_2" and build.berth_of("order_test_2") == "B1", "the second comes into the build berth")
		build.move("order_test", "B1")
		check(build.berth_of("order_test") == "H2", "the build berth takes one ship at a time")
		build.settle_tows()

	# 7.5: it all keeps across a save.
	var saved_build := build.save_data()
	var saved_orders := orders.save_data()
	build.reset_data()
	orders.reset_data()
	build.load_data(saved_build, BuildBus.SAVE_VERSION)
	orders.load_data(saved_orders, OrdersBus.SAVE_VERSION)
	check(build.builds.size() == saved_build.builds.size() and build.berth_of("order_test") == str(saved_build.builds.order_test.berth),
			"the ships come back in their berths")
	check(orders.orders.size() == (saved_orders.orders as Array).size() and orders.gated("order_test"), "and their orders")
	for id: String in build.builds.keys():
		build.stop(id)
	orders.reset_data()
