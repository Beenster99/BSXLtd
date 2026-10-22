extends ModuleTest
## The scrapyard's money (S1): labour by job size and kind, scrap by the kilo at the
## broker's low steady rate, stripped parts worth far more whole than as metal, and a
## handed-over job's recoveries coming into stock (kept, bought from the client, scrapped).
##   tools/run_tests.sh business


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "contracts.kinds": true, "ship_bay": true,
			"multiplayer": true, "business": true, "business.market": true, "business.wallets": true,
			"business.economy": true})
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

	# Labour follows the plan's ranges, scaled by what the client wants back.
	check(bus.labour_price("break", "small", 0.0) == 2000 and bus.labour_price("break", "small", 1.0) == 12000,
			"a small job pays 2,000 to 12,000")
	check(bus.labour_price("fit", "medium", 0.0) == 10000 and bus.labour_price("fit", "large", 1.0) == 400000,
			"medium from 10,000, large to 400,000")
	check(bus.labour_price("scrap", "medium", 0.5) < bus.labour_price("break", "medium", 0.5)
			and bus.labour_price("refurbish", "medium", 0.5) > bus.labour_price("break", "medium", 0.5),
			"scrap pays least, refurbish most")
	check(bus.labour_price("break", "huge", 0.0) == 2000 and bus.labour_price("odd", "small", 0.0) == 2000,
			"an unknown size or kind falls back to small and 1x")

	# Scrap: low and steady, by material.
	check(bus.scrap_value("steel", 1000.0) == 500, "a tonne of steel bales: %d" % bus.scrap_value("steel", 1000.0))
	check(bus.scrap_value("alloy", 1000.0) == 800 and bus.scrap_value("veil", 1000.0) == 10000,
			"dearer materials pay their price factor")
	check(bus.scrap_value("steel", 1000.0, "ingot") == 650, "ingots pay more than bales")
	check(bus.scrap_value("unobtainium", 1000.0) == 0 and bus.scrap_value("steel", 0.0) == 0, "nobody buys nothing")
	# A Kestrel (25 t) cut to steel bales earns about what a modest medium job's labour does.
	var kestrel := bus.scrap_value("steel", 25000.0)
	check(kestrel >= bus.labour_price("scrap", "medium", 0.0) and kestrel <= bus.labour_price("fit", "medium", 0.2),
			"a starter ship's steel is worth %d, a modest medium job" % kestrel)

	# Intact components pay far more than their metal: strip carefully.
	var cat := bus.get_catalogue()
	var part := "Assembler"
	check(cat.has_part(part), "the catalogue has %s" % part)
	var whole := bus.recovery_value(part, 0.9)
	var metal := bus.scrap_value("steel", cat.mass_of(part))
	check(whole > 5 * metal, "%s whole %d, as steel %d" % [part, whole, metal])
	check(bus.recovery_condition(0.9) == PartCondition.USED and bus.recovery_condition(0.3) == PartCondition.DAMAGED,
			"stripped parts are used or damaged, never new")
	check(bus.recovery_value(part, 0.3) < whole and bus.recovery_value("NoSuchPart", 1.0) == 0,
			"damaged is worth less; an unknown part nothing")
	check(bus.job_kind("NO-SUCH-JOB") == "fit" and bus.job_recoveries("NO-SUCH-JOB").is_empty(),
			"an unknown job is a fit-out with nothing stripped")

	# Handover: labour as today, then the recoveries into stock.
	books.call("accept_contract", "BRK-1", 8000, 10)
	var cash := bus.get_cash()
	var deposit: int = bus.get_contract_balance("BRK-1").deposit
	var recs := [
		{"part": part, "qty": 1, "condition": 0.9, "disposition": "keep"},
		{"part": "BatteryRack", "qty": 2, "condition": 0.4, "disposition": "buy"},
		{"part": "Bulkhead", "qty": 4, "condition": 1.0, "disposition": "client"},
		{"part": "HullPlate", "disposition": "scrap", "material": "steel", "kg": 612.4},
		{"part": "Wire", "disposition": "scrap", "material": "nonsense", "kg": 20.0},
		"not a recovery",
	]
	check(bus.on_contract_handed_over("BRK-1", 0.8, 0, recs).is_ok(), "the break job hands over")
	var bought: int = bus.recovery_value("BatteryRack", 0.4) * 2 * r.recovery_buy_percent / 100
	check(bus.get_cash() == cash + 8000 - deposit - bought, "labour in, the bought parts paid out: %d" % (bus.get_cash() - cash))
	var detail := bus.get_stock_detail()
	check(detail.get(part, {}).get(PartCondition.USED) == 1, "the kept part is in stock, used")
	check(detail.get("BatteryRack", {}).get(PartCondition.DAMAGED) == 2, "the bought racks are in stock, damaged")
	check(not detail.has("Bulkhead"), "the client's parts go back to the client")
	check(bus.get_stock().get("raw_steel") == 612 and not bus.get_stock().has("raw_nonsense"), "the scrap is in as kilos of steel")
	check(bus.get_ledger().back().category == LedgerEntry.SALVAGE, "the ledger shows what the client was paid")
	check(not bus.on_contract_handed_over("BRK-1", 0.8, 0, recs).is_ok() and bus.get_stock_detail().get(part, {}).get(PartCondition.USED) == 1,
			"a second handover adds nothing")

	# Without contracts.kinds, a handover leaves stock alone.
	Flags.set_flag("contracts.kinds", false)
	books.call("accept_contract", "BRK-2", 5000, 10)
	bus.on_contract_handed_over("BRK-2", 0.8, 0, [{"part": "Antenna", "disposition": "keep"}])
	check(not bus.get_stock().has("Antenna"), "the flag off: no recoveries")
	Flags.set_flag("contracts.kinds", true)

	# Selling scrap to the broker.
	cash = bus.get_cash()
	check(bus.sell_scrap("steel", 500).is_ok() and bus.get_cash() == cash + 250 and bus.get_stock().get("raw_steel") == 112,
			"500 kg of steel bales sell for 250")
	check(bus.get_ledger().back().category == LedgerEntry.SCRAP, "the ledger shows the scrap sale")
	check(not bus.sell_scrap("steel", 1000).is_ok() and bus.get_stock().get("raw_steel") == 112, "can't sell what isn't there")
	check(not bus.sell_scrap("nonsense", 1).is_ok(), "nor a material nobody buys")

	bus.reset()
	Flags.use(saved)
	Modules.load_all()
