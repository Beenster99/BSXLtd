extends ModuleTest
## Large jobs in stages (S6): the job is priced as the sum of its stages, each stage is paid
## once on sign-off less its share of the deposit, and the handover pays what is left, so
## the job pays its value exactly once; the plan survives a save.
##   tools/run_tests.sh business


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "business": true})
	Modules.load_all()
	var bus := Modules.bus("business") as BusinessBus
	check(bus != null, "business loads")
	if bus == null:
		Flags.use(saved)
		Modules.load_all()
		return
	bus.reset()
	var stages := [{"id": "strip", "name": "Strip the weapons", "value": 40000},
			{"id": "reactor", "name": "Reactor out", "value": 60000},
			{"id": "cut", "name": "Cut the hull", "value": 100000}]
	check(BusinessBus.staged_price(stages) == 200000, "a large job is priced as the sum of its stages")

	var start := bus.get_cash()
	check(bus.on_contract_accepted("BIG-1", 150000, bus.get_day() + 20).is_ok(), "the job is accepted")
	var deposit := bus.get_cash() - start
	check(deposit > 0, "a deposit is taken: %d" % deposit)
	check(not bus.on_stage_signed_off("BIG-1", "strip").is_ok(), "no stage pays before the stages are planned")
	check(bus.on_contract_staged("BIG-1", stages).is_ok(), "the stages are planned")
	check(int(bus.get_contract_balance("BIG-1").value) == 200000, "the contract's value is now the sum of its stages")
	check(not bus.on_contract_staged("BIG-1", [{"id": "x", "value": -5}]).is_ok(), "a stage needs a value")

	var paid: Array = []
	bus.stage_payment_received.connect(func(id: String, stage: String, amount: int) -> void: paid.append([id, stage, amount]))
	var before := bus.get_cash()
	var expect := bus.stage_payment("BIG-1", "strip")
	check(expect > 0 and expect < 40000, "a stage pays its value less its share of the deposit: %d" % expect)
	var r := bus.on_stage_signed_off("BIG-1", "strip")
	check(r.is_ok() and r.cost == expect and bus.get_cash() - before == expect, "signing off pays the stage: %d" % r.cost)
	check(paid.size() == 1 and paid[0] == ["BIG-1", "strip", expect], "and says so: %s" % str(paid))
	check(not bus.on_stage_signed_off("BIG-1", "strip").is_ok() and bus.get_cash() - before == expect, "a stage pays once")
	check(not bus.on_stage_signed_off("BIG-1", "nope").is_ok(), "an unknown stage pays nothing")
	check(not bus.on_contract_staged("BIG-1", stages).is_ok(), "the plan can't change once a stage is paid")

	# The plan and what's paid survive a save.
	var data := bus.save_data()
	bus.reset()
	bus.load_data(data, bus.save_version())
	check(bus.stage_payment("BIG-1", "strip") == 0 and bus.stage_payment("BIG-1", "reactor") > 0, "stages come back from a save")

	bus.on_stage_signed_off("BIG-1", "reactor")
	bus.on_stage_signed_off("BIG-1", "cut")
	var all_in := bus.get_cash()
	check(bus.on_contract_handed_over("BIG-1", 0.8, 0).is_ok(), "the job is handed over")
	var total := bus.get_cash() - all_in
	check(bus.get_cash() - start == 200000, "deposit, stages and handover pay the job's value once: %d" % (bus.get_cash() - start))
	check(total >= 0, "the handover pays what's left: %d" % total)

	bus.reset()
	Flags.use(saved)
	Modules.load_all()
