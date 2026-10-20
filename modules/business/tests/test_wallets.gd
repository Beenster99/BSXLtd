extends ModuleTest
## Crew money: every player has a wallet, sends money to the crew through a host-checked
## request, the company account pays crew as wages, wallets save and reach joining players,
## and the transfer docket on the wrist's crew tab sends it.
##   tools/run_tests.sh business

const TransferPanel := preload("res://modules/business/internal/ui/transfer_panel.gd")


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "multiplayer": true,
			"business": true, "business.market": true, "business.wallets": true})
	Modules.load_all()
	var bus := Modules.bus("business") as BusinessBus
	check(bus != null, "business loads")
	if bus == null:
		Flags.use(saved)
		Modules.load_all()
		return
	bus.reset()
	bus.test_crew = {1: "Ana", 2: "Ben"}
	var refused: Array[String] = []
	bus.transfer_refused.connect(func(why: String) -> void: refused.append(why))

	var section := HudSlots.holo_sections(BusinessBus.CREW_CHANNEL)
	check(section.any(func(x): return x.id == BusinessBus.TRANSFER_SECTION), "the transfer docket is on the crew tab")
	check(bus.get_wallet("Ana") == 1000 and bus.get_wallet("Ben") == 1000, "everyone starts with a wallet")
	bus.request_transfer(2, 300)
	check(bus.get_wallet("Ana") == 700 and bus.get_wallet("Ben") == 1300, "Ana sends Ben 300")
	bus.request_transfer(2, 5000)
	check(refused.size() == 1 and refused[0].contains("700") and bus.get_wallet("Ana") == 700, "not more than you have: %s" % str(refused))
	bus.request_transfer(1, 10)
	check(refused.size() == 2, "not to yourself")
	bus.request_transfer(2, 0)
	check(refused.size() == 3, "not nothing")
	bus.request_transfer(9, 10)
	check(refused.size() == 4, "not to someone who isn't here")

	var cash := bus.get_cash()
	bus.request_transfer(2, 250, true)
	check(bus.get_cash() == cash - 250 and bus.get_wallet("Ben") == 1550 and bus.get_wallet("Ana") == 700, "the company pays Ben")
	var last: LedgerEntry = bus.get_ledger().back()
	check(last.category == "wages" and last.ref == "Ben" and last.amount == -250, "wages go in the ledger")
	bus.request_transfer(2, cash * 2, true)
	check(refused.size() == 5, "the company can't pay more than it has")

	# Saved with the business, and sent to a player joining.
	var data := bus.save_data()
	bus.reset()
	bus.load_data(JSON.parse_string(JSON.stringify(data)), bus.save_version())
	check(bus.get_wallet("Ana") == 700 and bus.get_wallet("Ben") == 1550, "wallets are saved")
	var snap := bus.get_net_snapshot()
	bus.reset()
	bus.apply_net_snapshot(snap)
	check(bus.get_wallet("Ben") == 1550, "a joining player gets the wallets")

	# The docket on the wrist's crew tab.
	var panel: Control = TransferPanel.new(bus, true)
	add_child(panel)
	await frames(1)
	check(panel.get("to_peer") == 2, "the docket picks the only other crew member")
	var amount := panel.get("_amount") as LineEdit
	amount.text = "12a0"
	amount.text_changed.emit(amount.text)
	check(amount.text == "120", "the amount takes digits only")
	var send := panel.find_child("SendMoney", true, false) as Button
	check(send != null and not send.disabled and send.text == "SEND 120 CR", "SEND shows the sum")
	send.pressed.emit()
	await frames(1)
	check(bus.get_wallet("Ana") == 580 and bus.get_wallet("Ben") == 1670, "SEND moves the money")
	var msg := panel.get("_message") as Label
	check(msg.text.begins_with("Sent 120 CR to Ben"), "the docket says it went: %s" % msg.text)
	panel.free()

	bus.test_crew = {}
	bus.reset()
	Flags.use(saved)
	Modules.load_all()
