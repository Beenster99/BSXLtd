extends ModuleTest
## The detailed ACCOUNTS wall panel (beenster, 19 Nov): BusinessBus.accounts_report adds up the
## books (profit and loss by kind, closing cash each day, contracts, loans, stock, crew, what a
## day costs, the balance sheet) and the panel draws it, offered to the design room's walls.
##   tools/run_tests.sh business

func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "shared_components": true,
			"multiplayer": true, "design": true, "business": true, "business.market": true, "business.economy": true,
			"business.accounts_wall": true})
	Modules.load_all()
	var bus := Modules.bus("business") as BusinessBus
	check(bus != null, "business loads")
	if bus == null:
		Flags.use(saved)
		Modules.load_all()
		return
	bus.reset()
	bus.test_crew = {1: "Ann", 2: "Bob"}
	bus.test_levels = {"Ann": 4, "Bob": 0}
	var books: RefCounted = bus.get("_books")
	var start := bus.get_cash()

	# A day of business: a contract's deposit, rent, wages, a loan.
	books.call("accept_contract", "SO-1", 40000, 6)
	books.get("company").take_loan(10000, 12, bus.get_day())
	books.call("advance_day")
	var r := bus.accounts_report(7)
	check(int(r.cash) == bus.get_cash(), "the report's cash is the books' cash")
	check(int(r.period.first) == 0 and int(r.period.last) == 1, "a week from day one covers days 0 and 1: %s" % r.period)
	var balance: Array = r.balance
	check(balance.size() == 2, "a closing balance per day: %d" % balance.size())
	check(int(balance.back().close) == bus.get_cash(), "today closes at today's cash")
	var day0: Dictionary = balance[0]
	check(int(day0.close) == start + int(day0["in"]) - int(day0.out), "day one's close is the start plus its movements")
	var now: Dictionary = r.now
	var lines_in := 0
	var lines_out := 0
	for l: Dictionary in r.lines:
		lines_in += int(l["in"])
		lines_out += int(l.out)
	check(lines_in == int(now.income) and lines_out == int(now.outgoings), "the lines add up to the totals")
	var cats: Array = (r.lines as Array).map(func(l: Dictionary) -> String: return str(l.category))
	check("deposit" in cats and "rent" in cats and "wages" in cats and "loan" in cats, "deposit, rent, wages and the loan each have a line: %s" % [cats])
	check(cats.find("deposit") < cats.find("wages") and cats.find("wages") < cats.find("rent"), "lines in the accounts' group order")
	var contract: Dictionary = (r.contracts as Array)[0]
	check(contract.id == "SO-1" and int(contract.received) == int(contract.deposit) and int(contract.received) > 0, "the contract shows its deposit received: %s" % contract)
	check((r.loans as Array).size() == 1 and int(r.owed) > 10000, "the loan, owed with interest")
	var burn: Dictionary = r.burn
	check(int(burn.wages) == bus.wage_for(4) + bus.wage_for(0), "a day's wages for the crew on shift")
	check(int(burn.per_day) == int(burn.rent) + int(burn.wages) + int(burn.loans), "a day's cost adds up")
	check(int(r.runway) == bus.get_cash() / int(burn.per_day), "runway is cash over a day's cost: %d" % int(r.runway))
	var sheet: Dictionary = r.sheet
	check(int(sheet.worth) == bus.get_cash() + int(sheet.assets.stock) + int(sheet.assets.on_order) - int(r.owed), "net worth")
	check((r.crew as Array).size() == 2, "both crew listed")
	check((r.recent as Array).size() == bus.get_ledger(0).size(), "every entry in the period is in the ledger list")

	# Stock at market value.
	var part := ""
	for l in bus.get_listings():
		if bus.get_catalogue().value_of(l.part) > 0:
			part = l.part
			break
	bus.add_stock(part, 3, "used")
	r = bus.accounts_report(7)
	check(int(r.stock.value) == roundi(bus.get_catalogue().value_of(part) * PartCondition.price_factor("used") * 3), "used stock valued at its share of the new price")

	# Earlier days fall out of a short period; the day before is the comparison.
	books.call("advance_day")
	r = bus.accounts_report(1)
	check((r.balance as Array).size() == 1 and r.has_prev, "today alone, with yesterday to compare")
	check(int(r.prev.outgoings) > 0, "yesterday's outgoings carried as the comparison")
	r = bus.accounts_report(0)
	check(int(r.period.first) == 0 and (r.balance as Array).size() == bus.get_day() + 1 and not r.has_prev, "ALL runs from day one")

	# The panel.
	var wall := bus.make_accounts_wall(150.0)
	add_child(wall)
	wall.size = Vector2(1400, 900)
	await frames(3)
	check(wall.find_child("CashChart", true, false) != null and wall.find_child("NetResult", true, false) != null, "the cash chart and the profit and loss")
	for card in ["sheet", "costs", "contracts", "loans", "crew", "stock", "ledger"]:
		check(wall.find_child("Card_" + card, true, false) != null, "the %s card" % card)
	check(wall.find_child("Line_rent", true, false) != null and wall.find_child("Group_contracts", true, false) != null, "lines and group subtotals")
	check(wall.find_child("Contract_SO-1", true, false) != null and wall.find_child("Crew_Ann", true, false) != null, "the contract and the crew rows")
	check(int((wall.find_child("Cards", true, false) as GridContainer).columns) == 2, "two columns of cards on a wide wall")
	(wall.find_child("Period_30D", true, false) as Button).pressed.emit()
	await frames(1)
	check(str(wall.get("period")) == "30 D" and int(wall.get("report").period.days) == 30, "the period chips change the report")
	var cash_before := bus.get_cash()
	books.call("post", -500, LedgerEntry.PARTS, "PO-T", "test")
	await frames(2)
	check(int(wall.get("report").cash) == cash_before - 500, "the panel follows the books")
	wall.size = Vector2(700, 900)
	wall.call("_fit_columns")
	check(int((wall.find_child("Cards", true, false) as GridContainer).columns) == 1, "one column on a narrow wall")
	# Overdrawn: the warning band says how long is left.
	books.set("cash", -1000)
	wall.call("refresh")
	var band := wall.find_child("Warning", true, false) as Control
	check(band.visible and (band.get_child(0) as Label).text.begins_with("OVERDRAWN"), "the band warns when overdrawn")
	wall.queue_free()

	# The same panel is the wrist's Accounts, in place of the old Buy/Sell and Accounts pages.
	var ch := HudSlots.holo_channel(BusinessBus.WRIST_ACCOUNTS)
	check(int(ch.get("order", 0)) == 40 and str(ch.get("label", "")) == "Accounts", "Accounts on the wrist at 40")
	check(HudSlots.holo_channel("business.orders").is_empty(), "no old Buy/Sell page on the wrist")
	var on_wrist: Variant = (ch.factory as Callable).call(true)
	check(on_wrist is Control and (on_wrist as Node).name == "AccountsWall", "the wrist shows the accounts panel")
	(on_wrist as Node).free()

	# Offered to the design room's walls when the design room takes panels.
	var design := Modules.bus("design")
	if design and design.has_method("register_wall_view"):
		check((design.get("wall_views") as Dictionary).has(BusinessBus.ACCOUNTS_WALL_VIEW), "ACCOUNTS offered to the walls")
		var made: Variant = (design.get("wall_views")[BusinessBus.ACCOUNTS_WALL_VIEW].make as Callable).call(120.0)
		check(made is Control, "the wall makes the panel")
		(made as Node).free()

	bus.test_crew = {}
	bus.test_levels = {}
	bus.reset()
	Flags.use(saved)
	Modules.load_all()
