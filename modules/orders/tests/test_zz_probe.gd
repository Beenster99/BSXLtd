extends ModuleTest
func run_tests() -> void:
	var build := Modules.bus("build") as BuildBus
	var orders := Modules.bus("orders") as OrdersBus
	for f: String in [BuildBus.FLAG, OrdersBus.FLAG, OrdersBus.GATE_FLAG]:
		Flags.set_flag(f, true)
	for maker in ["skiff", "freighter"]:
		var rec := DesignRecord.new()
		if maker == "skiff": DesignBus.Samples.skiff(rec, orders.catalog())
		else: DesignBus.Samples.freighter(rec, orders.catalog())
		var cid := "probe_" + maker
		build.start(cid, rec.to_dict(), maker)
		await frames(1)
		var t := "PROBE %s total %d:" % [maker, int(orders.plan_sums(cid).cheapest.total)]
		for st in OrderBook.STAGE_ORDER:
			t += " %s %d" % [st, orders.stage_cheapest(cid, st)]
		print(t)
		build.stop(cid)
	check(true, "p")
