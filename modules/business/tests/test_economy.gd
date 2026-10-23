extends ModuleTest
## The company's economy: a won contract pays its parts plus goodwill up front and the rest
## at sign-off, the crew is paid daily by skill level with payslips, the owner pays bonuses
## with a note and hands the company over, and loans are taken, repaid monthly and paid off.
##   tools/run_tests.sh business

const CompanyPanel := preload("res://modules/business/internal/ui/company_panel.gd")


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "multiplayer": true,
			"business": true, "business.market": true, "business.wallets": true, "business.economy": true})
	Modules.load_all()
	var bus := Modules.bus("business") as BusinessBus
	check(bus != null, "business loads")
	if bus == null:
		Flags.use(saved)
		Modules.load_all()
		return
	bus.reset()
	var books: RefCounted = bus.get("_books")
	var r := bus.get_rules()

	# A contract: parts and goodwill up front, the rest when the client signs off.
	var cash := bus.get_cash()
	books.call("accept_contract", "JOB-1", 100000, 10, 6000)
	var bal := bus.get_contract_balance("JOB-1")
	check(bal.deposit == 6000 + 100000 * r.goodwill_percent / 100 and bus.get_cash() == cash + bal.deposit,
			"parts plus goodwill come in up front: %d" % bal.deposit)
	var cats := bus.get_ledger().slice(-2).map(func(e): return e.category)
	check(cats == [LedgerEntry.DEPOSIT, LedgerEntry.GOODWILL], "the ledger shows parts and goodwill: %s" % str(cats))
	cash = bus.get_cash()
	bus.on_contract_handed_over("JOB-1", 0.8, 0)
	check(bus.get_cash() == cash + 100000 - bal.deposit, "the rest comes at sign-off")
	books.call("accept_contract", "JOB-2", 50000, 10, 80000)
	check(bus.get_contract_balance("JOB-2").deposit == 50000, "never more up front than the price")
	books.call("accept_contract", "JOB-3", 50000, 10)
	check(bus.get_contract_balance("JOB-3").deposit == 50000 * r.deposit_percent / 100, "unpriced parts fall back to the deposit share")
	check(bus.on_contract_accepted("JOB-4", 10000, 10).is_ok() and bus.get_contract_balance("JOB-4").deposit == 10000 * (r.deposit_percent + r.goodwill_percent) / 100,
			"a job of ship modules (no market price) gets the deposit share plus goodwill")
	check(bus.job_materials("NO-SUCH-JOB") == -1, "an unknown job has no parts price")

	# Wages: every day, by skill level, with a payslip each.
	bus.reset()
	bus.test_crew = {1: "Ana", 2: "Ben", 3: "Cal"}
	bus.test_levels = {"Ana": 0, "Ben": 5, "Cal": 12}
	check(bus.wage_for(0) == 200 and bus.wage_for(5) == 275 and bus.wage_for(100) == r.wage_max, "wage by level, capped")
	cash = bus.get_cash()
	bus.advance_day()
	var wages := 200 + 275 + 380
	check(bus.get_cash() == cash - wages - r.bay_rent_per_day, "a day's wages and rent: %d" % (cash - bus.get_cash()))
	check(bus.get_wallet("Ben") == 1000 + 275, "Ben is paid into his wallet")
	var slips := bus.get_payslips("Cal")
	check(slips.size() == 1 and slips[0].wage == 380 and slips[0].level == 12 and slips[0].day == 0, "Cal has a payslip: %s" % str(slips))
	# Progression levels run 0-20 (four tools, five levels each). A full crew of three at the
	# top costs less a day than the board's jobs bring in (about 1,300 CR per due day each).
	var three_avg := 3 * bus.wage_for(10) + r.bay_rent_per_day
	var three_top := 3 * bus.wage_for(20) + r.bay_rent_per_day
	check(three_avg <= 1500 and three_top <= 2000, "three players and rent cost %d a day at level 10, %d at 20" % [three_avg, three_top])

	# The owner: the host until handed over. Bonuses with a note, owner only.
	check(bus.company_owner() == "Ana" and bus.is_owner("Ana"), "the host owns the company")
	var refused: Array[String] = []
	bus.company_refused.connect(func(why: String) -> void: refused.append(why))
	cash = bus.get_cash()
	bus.request_bonus(2, 500, "Lovely welds on the Kestrel")
	check(bus.get_cash() == cash - 500 and bus.get_wallet("Ben") == 1775, "the owner pays Ben a bonus")
	var today: Dictionary = bus.get_payslips("Ben").back()
	check(today.day == 1 and today.bonuses.size() == 1 and today.bonuses[0].note == "Lovely welds on the Kestrel" and today.bonuses[0].by == "Ana",
			"the bonus and its note go on Ben's payslip: %s" % str(today))
	check(bus.get_ledger().back().category == LedgerEntry.BONUS, "bonuses go in the ledger")
	check(bus.call("_validate_bonus", 2, {"to": 3, "amount": 100, "note": ""}) is String, "only the owner pays bonuses")
	bus.request_bonus(2, bus.get_cash() + 1, "")
	check(refused.size() == 1, "not more than the company has")
	bus.request_owner(2)
	check(bus.company_owner() == "Ben", "the company is handed to Ben")
	bus.request_bonus(3, 100, "")
	check(refused.size() == 2 and refused[1].contains("Ben"), "Ana isn't the owner any more: %s" % str(refused))
	check(bus.call("_validate_owner", 1, {"to": 1}) is Dictionary, "the host can always take it back")
	check(bus.call("_validate_owner", 3, {"to": 3}) is String, "a crew member can't take it")
	bus.request_owner(1)

	# Loans: the owner borrows, repays monthly, pays off early.
	check(bus.loan_room() == r.loan_limit_base + int(r.loan_limit_per_rep * bus.get_reputation()), "room to borrow by reputation")
	var q := bus.loan_quote(24000, 12)
	check(q.monthly > 2000 and q.monthly < 2100 and q.total > 24000, "12 months on 24,000 at 8%%: %s" % str(q))
	cash = bus.get_cash()
	bus.request_loan(24000, 12)
	var loans := bus.get_loans()
	check(loans.size() == 1 and bus.get_cash() == cash + 24000 and loans[0].monthly == q.monthly, "the loan comes in")
	bus.request_loan(5000, 60)
	bus.request_loan(500, 12)
	bus.request_loan(bus.loan_room() + 1, 12)
	check(refused.size() == 5 and bus.get_loans().size() == 1, "48 months at most, a minimum, and a limit: %s" % str(refused.slice(2)))
	bus.test_crew = {1: "Ana"}
	bus.test_levels = {"Ana": 0}
	for i in r.days_per_month - 1:
		bus.advance_day()
	check(bus.get_loans()[0].paid_months == 0, "nothing due before a month is up")
	cash = bus.get_cash()
	bus.advance_day()
	var after: Dictionary = bus.get_loans()[0]
	check(after.paid_months == 1 and after.balance == q.total - q.monthly, "the first month comes out")
	check(cash - bus.get_cash() == q.monthly + bus.wage_for(0) + r.bay_rent_per_day, "a month's repayment with the day's costs")
	var settle := bus.settle_amount(after.id)
	books.call("post", -bus.get_cash(), LedgerEntry.PAYMENT, "JOB-8")
	check(settle < after.balance and settle > 20000, "paying off early skips the interest not yet due: %d of %d" % [settle, after.balance])
	bus.request_settle(after.id)
	check(refused.back() == "the company can't pay it off yet" and bus.get_loans().size() == 1, "not without the cash to do it")
	books.call("post", 50000, LedgerEntry.PAYMENT, "JOB-9")
	cash = bus.get_cash()
	bus.request_settle(after.id)
	check(bus.get_loans().is_empty() and bus.get_cash() == cash - settle, "the loan is paid off: %s %d %s" % [str(bus.get_loans()), cash - bus.get_cash(), str(refused)])

	# Saved and loaded with the business.
	bus.request_loan(10000, 6)
	bus.request_bonus(1, 50, "Tea money")
	var data := bus.save_data()
	bus.reset()
	bus.load_data(JSON.parse_string(JSON.stringify(data)), bus.save_version())
	check(bus.get_loans().size() == 1 and bus.get_loans()[0].months == 6 and bus.get_payslips("Ana").back().bonuses[0].note == "Tea money",
			"loans and payslips are saved")
	var snap := bus.get_net_snapshot()
	bus.request_owner(1)
	bus.reset()
	bus.apply_net_snapshot(snap)
	check(bus.get_loans().size() == 1 and bus.get_payslips("Ana").size() > 0, "joining players get the company")

	# The Settings pages: Company (owner, bonus, loans) and Payslips.
	check(not Menu.settings_page(BusinessBus.COMPANY_PAGE).is_empty(), "the Company page is in Settings")
	check(Menu.settings_sections(Menu.CHARACTER).any(func(c): return c.id == BusinessBus.PAYSLIPS_SECTION), "payslips are on the Character page")
	var made: Control = Menu.settings_page(BusinessBus.COMPANY_PAGE).factory.call()
	check(made != null, "the Company page builds")
	made.free()
	bus.reset()
	bus.test_crew = {1: "Ana", 2: "Ben"}
	bus.test_levels = {"Ana": 3, "Ben": 7}
	bus.advance_day()
	var company: Control = CompanyPanel.new(bus, "company", false)
	add_child(company)
	company.size = Vector2(900, 600)
	await frames(2)
	check(company.get("to_peer") == 2, "the company page picks Ben")
	(company.get("_bonus_amount") as LineEdit).text = "300"
	(company.get("_bonus_note") as LineEdit).text = "First shift done"
	(company.find_child("PayBonus", true, false) as Button).pressed.emit()
	check(bus.get_payslips("Ben").back().bonuses.size() == 1, "PAY BONUS pays it with the note")
	await frames(2)
	(company.get("_loan_amount") as LineEdit).text = "12000"
	(company.get("_loan_amount") as LineEdit).text_changed.emit("12000")
	var quote := company.find_child("Quote", true, false) as Label
	check(quote != null and quote.text.contains("A MONTH"), "the loan is quoted as you type: %s" % (quote.text if quote else "none"))
	(company.find_child("TakeLoan", true, false) as Button).pressed.emit()
	check(bus.get_loans().size() == 1 and bus.get_loans()[0].months == 12, "TAKE LOAN borrows it")
	await frames(2)
	check(company.find_child("PayOff_" + str(bus.get_loans()[0].id), true, false) != null, "the loan is listed with PAY OFF")
	(company.find_child("MakeOwner", true, false) as Button).pressed.emit()
	await frames(2)
	check(bus.company_owner() == "Ben" and (company.find_child("PayBonus", true, false) as Button).disabled, "MAKE OWNER hands it over; Ana's bonus button greys out")
	company.free()
	var slips_page: Control = CompanyPanel.new(bus, "payslips", false)
	add_child(slips_page)
	await frames(2)
	var texts := slips_page.find_children("*", "Label", true, false).map(func(l): return l.text)
	check(texts.has("Day 1") and texts.has("3") and texts.has(TerminalKit.money(bus.wage_for(3))), "Ana's payslip shows her day, level and wage: %s" % str(texts.slice(0, 12)))
	slips_page.free()

	# The recycler's raw materials go into stock; deliveries land within half a day.
	bus.reset()
	var added: Array = []
	bus.stock_added.connect(func(part: String, cond: String, qty: int, src: String) -> void: added.append([part, cond, qty, src]))
	check(bus.add_stock("frame_ring", 3) == 3 and bus.add_stock("frame_ring", 2, "used") == 5, "raw materials go into stock")
	check(added.size() == 2 and added[0] == ["frame_ring", "new", 3, "recycler"], "and say so: %s" % str(added))
	check(bus.add_stock("frame_ring", 1, "mint") == 5 and bus.add_stock("frame_ring", 0) == 5, "an unknown condition or nothing adds nothing")
	check(bus.get_suppliers().all(func(s): return s.lead_seconds.x >= 5 and s.lead_seconds.y + 15 <= 60),
			"every supplier delivers in 5 to 60 seconds, late (15 s more) or not")
	bus.call("_on_scrap_recycled", "hull_plate", 1, {"steel": 41.6, "copper": 0.2, "glass": 3.0})
	var st := bus.get_stock()
	check(st.get("raw_steel") == 42 and st.get("raw_glass") == 3 and not st.has("raw_copper"), "the recycler's kilos go into stock: %s" % str(st))
	check(bus.part_name("raw_steel") == "Steel (raw, kg)", "raw materials have a name: %s" % bus.part_name("raw_steel"))

	bus.test_crew = {}
	bus.test_levels = {}
	bus.reset()
	Flags.use(saved)
	Modules.load_all()
