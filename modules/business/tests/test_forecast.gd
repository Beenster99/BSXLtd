extends ModuleTest
## Staged ship contracts and the cash forecast (beenster, 19 Nov): a price split 20/20/20/40
## (deposit, keel, fit-out, delivery after the trial), the deposit paid on acceptance, and the
## ACCOUNTS screen's forecast of money in by contract and stage, money out, and cash day by day
## with the trial's best and worst case.
##   tools/run_tests.sh business

func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "shared_components": true,
			"business": true, "business.market": true, "business.economy": true, "business.accounts_wall": true})
	Modules.load_all()
	var bus := Modules.bus("business") as BusinessBus
	check(bus != null, "business loads")
	if bus == null:
		Flags.use(saved)
		Modules.load_all()
		return
	bus.reset()
	bus.test_crew = {1: "Ann"}
	bus.test_levels = {"Ann": 2}
	var books: RefCounted = bus.get("_books")

	# The payment profile.
	var plan := BusinessBus.payment_plan(1000001, 10, 40)
	check(plan.size() == 4 and BusinessBus.staged_price(plan) == 1000001, "four stages adding up to the price")
	check(plan.map(func(p: Dictionary) -> String: return str(p.id)) == ["deposit", "keel", "fit_out", "delivery"], "deposit, keel, fit-out, delivery")
	check(int(plan[0].value) == 200000 and int(plan[1].value) == 200000 and int(plan[3].value) == 400001, "20, 20, 20 and 40 percent")
	check(int(plan[0].expected_day) == 10 and int(plan[1].expected_day) == 19 and int(plan[2].expected_day) == 31 and int(plan[3].expected_day) == 40,
			"due through the build: %s" % [plan.map(func(p: Dictionary) -> int: return int(p.expected_day))])

	# Accepting pays the deposit and nothing else.
	var start := bus.get_cash()
	var r := bus.on_contract_accepted_staged("SO-7", BusinessBus.payment_plan(500000, 0, 20), 20)
	check(r.is_ok() and bus.get_cash() == start + 100000, "the deposit is paid on acceptance: %d" % (bus.get_cash() - start))
	var prof: Dictionary = bus.payment_profiles()[0]
	var stages: Array = prof.stages
	check(bool(stages[0].paid) and not bool(stages[1].paid) and int(stages[1].amount) == 100000 and int(stages[3].amount) == 200000,
			"the profile: deposit paid, keel and delivery to come: %s" % [stages])
	check(int(prof.trial.bonus) == 20000 and int(prof.trial.holdback) == 50000, "the trial's bonus and hold-back on the delivery")

	# The forecast.
	bus.register_running_cost("bots", "TartanCo bots", func() -> int: return 150)
	var f := bus.cash_forecast(30)
	var rows: Array = f.days
	check(rows.size() == 30 and int(rows[0].day) == bus.get_day(), "30 days from today")
	var names: Array = (f.coming_in as Array).map(func(c: Dictionary) -> String: return str(c.stage))
	check(names == ["keel", "fit_out", "delivery"], "keel, fit-out and delivery coming in, in order: %s" % [names])
	var delivery: Dictionary = (f.coming_in as Array).back()
	check(int(delivery.day) == 20 and int(delivery.best) == 220000 and int(delivery.worst) == 150000, "delivery on day 21, 150,000 to 220,000 after the trial")
	var per_day := bus.get_rules().bay_rent_per_day + bus.wage_for(2) + 150
	check(int(rows[0].out) == per_day, "a day's costs: rent, wages and the bots: %d" % int(rows[0].out))
	check((f.going_out as Array).any(func(g: Dictionary) -> bool: return g.label == "TartanCo bots" and int(g.amount) == 150 * 30), "the bots listed as going out")
	var t: Dictionary = f.totals
	check(int((rows.back() as Dictionary).cash) == bus.get_cash() + int(t["in"]) - int(t.out), "the last day's cash is today's plus in less out")
	check(int((rows.back() as Dictionary).best) - int((rows.back() as Dictionary).worst) == 70000, "best and worst differ by the trial's range")
	check(int(f.short_day) == -1, "no shortfall with the deposit in")

	# A loan's repayment falls on its month's end.
	books.get("company").take_loan(30000, 12, bus.get_day())
	f = bus.cash_forecast(31)
	var monthly := int(bus.get_loans()[0].monthly)
	var month_end: Dictionary = (f.days as Array)[bus.get_rules().days_per_month - 1]
	var before: Dictionary = (f.days as Array)[bus.get_rules().days_per_month - 2]
	check(int(month_end.out) - int(before.out) == monthly, "the repayment on the month's last day: %d" % monthly)

	# Short of cash: the first day below zero, and the screen says so.
	books.set("cash", 2000)
	f = bus.cash_forecast(30)
	check(int(f.short_day) >= bus.get_day() and int(f.short_day) < 9, "short before the keel payment: day %d" % int(f.short_day))

	# Signing a stage off takes it off the forecast and pays it.
	books.set("cash", 100000)
	var cash := bus.get_cash()
	bus.on_stage_signed_off("SO-7", "keel")
	check(bus.get_cash() == cash + 100000, "the keel pays its 20 percent")
	check(not (bus.cash_forecast(30).coming_in as Array).any(func(c: Dictionary) -> bool: return c.stage == "keel"), "and leaves the forecast")
	bus.on_stage_signed_off("SO-7", "fit_out")
	# The trial: a bonus for beating one demand, some held back for missing another.
	bus.on_contract_adjusted("SO-7", 15000, "beat the range")
	bus.on_contract_adjusted("SO-7", -5000, "short on cargo")
	check(int(((bus.payment_profiles()[0] as Dictionary).stages as Array).back().amount) == 210000, "the forecast's delivery takes the trial in")
	cash = bus.get_cash()
	bus.on_contract_handed_over("SO-7", 0.8, 0)
	check(bus.get_cash() == cash + 210000, "the handover pays the delivery, 40 percent, plus the trial's 10,000: %d" % (bus.get_cash() - cash))
	var trial_line: LedgerEntry = bus.get_ledger().back()
	check(trial_line.category == LedgerEntry.TRIAL and trial_line.amount == 10000 and trial_line.note.contains("short on cargo"), "the trial on its own ledger line")
	check(bus.payment_profiles().is_empty(), "nothing left to come")

	# On the screen.
	bus.on_contract_accepted_staged("SO-8", BusinessBus.payment_plan(300000, bus.get_day(), bus.get_day() + 12), bus.get_day() + 12)
	var wall := bus.make_accounts_wall(150.0)
	add_child(wall)
	wall.size = Vector2(1400, 900)
	await frames(3)
	check(wall.find_child("ForecastChart", true, false) != null and wall.find_child("ForecastSummary", true, false) != null, "the forecast chart and its summary")
	check(wall.find_child("In_SO-8_keel", true, false) != null and wall.find_child("In_SO-8_delivery", true, false) != null, "each payment coming in, by contract and stage")
	wall.call("refresh")
	await frames(1)
	check(wall.find_child("ForecastChart", true, false) != null and wall.find_child("ForecastLists", true, false) != null, "the chart survives a refresh")
	books.set("cash", -50000)
	wall.call("refresh")
	var band := wall.find_child("Warning", true, false) as Control
	check(band.visible, "the warning band is up when cash is short")
	wall.queue_free()

	# The clock runs only while a yard is open.
	check(not bool(bus.call("_clock_running")), "no yard open: the business clock stands still")

	bus.unregister_running_cost("bots")
	bus.test_crew = {}
	bus.test_levels = {}
	bus.reset()
	Flags.use(saved)
	Modules.load_all()
