extends ModuleTest
## Wave 8 as data: the yard's ranks (bots it can keep, specialists, holding berths, ship sizes it
## can sign), the rival yards' bids and the price BSX signs at, repeat orders from pleased clients,
## crew roles and their perks, naming a ship, the handover written in the company's record (with
## her miniature) and the send-off; it all saves and loads.
##   tools/run_tests.sh company


func run_tests() -> void:
	for f: String in [CompanyBus.FLAG, CompanyBus.GROWTH_FLAG, CompanyBus.RIVALS_FLAG, CompanyBus.LAUNCH_FLAG,
			BuildBus.FLAG, BuildBus.HOLDING_FLAG]:
		Flags.set_flag(f, true)
	var co := Modules.bus("company") as CompanyBus
	var contracts := Modules.bus("contracts") as ContractsBus
	check(co != null and contracts != null, "the company and contracts modules are loaded")
	if co == null or contracts == null:
		return
	co.reset_data()
	_ranks(co)
	_rivals(co, contracts)
	_roles(co)
	await _launch(co, contracts)
	_save(co)
	co.reset_data()


func _ranks(co: CompanyBus) -> void:
	var r := co.rank()
	check(int(r.index) == 0 and str(r.name) == "Workshop", "a new yard is a workshop (%s)" % str(r.name))
	check(co.bot_cap() == 12 and co.holding_berths() == 1, "a workshop keeps 12 bots and one holding berth")
	check(co.bot_unlock("frame_tech") != "" and co.bot_unlock("welder") == "", "specialists come with a rank (%s)" % co.bot_unlock("frame_tech"))
	check(co.sign_check({"size": "large"}) != "" and co.sign_check({"size": "small"}) == "",
			"a workshop signs only small and medium ships (%s)" % co.sign_check({"size": "large"}))
	check(not co.next_rank().is_empty() and str(co.next_rank().name) == "Yard", "and the next rank is a yard")
	# Three ships handed over and a good name: up the ranks (reputation from the business module).
	for i in 3:
		co.record.append({"cid": "fake_%d" % i, "name": "Fake %d" % i, "quality": 0.5})
	if co.reputation() >= 50.0:
		check(int(co.rank().index) >= 2, "three ships and a name: a shipworks")
	elif co.reputation() >= 25.0:
		check(int(co.rank().index) >= 1, "three ships and a name: a yard at least")
	Flags.set_flag(CompanyBus.GROWTH_FLAG, false)
	check(co.bot_cap() >= 999 and co.holding_berths() == 2 and co.sign_check({"size": "mega"}) == "",
			"with growth off nothing is held back")
	Flags.set_flag(CompanyBus.GROWTH_FLAG, true)
	co.record.clear()
	var build := Modules.bus("build") as BuildBus
	if build:
		check(not build.berth_open("H2") and build.berth_open("H1"), "a workshop's second holding berth is shut")


func _rivals(co: CompanyBus, contracts: ContractsBus) -> void:
	var order := {"id": "rival_test", "client": "nobody", "budget": 2_000_000, "size": "small"}
	var bids := co.rival_bids(order)
	check(bids.size() == CompanyBus.RIVALS_PER_ORDER, "rival yards bid for an order (%d)" % bids.size())
	check(bids == co.rival_bids(order), "the same bids on every machine")
	if bids.size() >= 2:
		check(int(bids[0].price) <= int(bids[1].price) and int(bids[0].price) < 2_000_000, "cheapest first, under the budget (%s)" % str(bids))
		check(co.price_rule(order, 1_990_000) == mini(1_990_000, int(bids[0].price)), "BSX signs at no more than the lowest bid")
		check(co.price_rule(order, 100_000) == 100_000, "a cheaper quote stands")
	var rep := order.duplicate()
	rep["repeat"] = true
	check(co.price_rule(rep, 1_990_000) == 1_990_000, "a repeat order is not bid against")
	check(contracts.sign_price(order, 0) is int, "the contracts module asks the company for the price")
	# Repeat orders: a pleased client of a real contract comes back.
	var real := {}
	for c: Dictionary in contracts.ship_contracts():
		if not (c.get("order", {}) as Dictionary).is_empty():
			real = c
			break
	if not real.is_empty():
		co.record.append({"cid": str(real.id), "name": "Good ship", "design": "x", "quality": 0.9})
		co.record.append({"cid": str(real.id), "name": "Poor ship", "design": "x", "quality": 0.3})
		var reps := co.repeat_orders()
		check(reps.size() == 1 and bool(reps[0].repeat) and str(reps[0].id).begins_with("rep_"), "a pleased client comes back, a poor one does not")
		var listed := contracts.ship_orders().any(func(o: Dictionary) -> bool: return bool(o.get("repeat", false)))
		check(listed, "the repeat order is on the board")
		co.record.clear()


func _roles(co: CompanyBus) -> void:
	var me := co.me()
	check(co.crew().has(me), "I am on shift (%s)" % str(co.crew()))
	check(is_equal_approx(co.perk("parts"), 1.0), "no buyer: parts at their price")
	co.set_role(me, "buyer")
	check(str(co.roles.get(me, "")) == "buyer" and co.perk("parts") < 1.0, "a buyer gets the parts cheaper (%.2f)" % co.perk("parts"))
	co.set_role(me, "foreman")
	check(co.perk("bots") > 1.0 and is_equal_approx(co.perk("parts"), 1.0), "one role at a time: the foreman speeds the bots")
	co.set_role(me, "nonsense")
	check(str(co.roles.get(me, "")) == "foreman", "an unknown role is refused")
	co.set_role(me, "")
	check(not co.roles.has(me), "and a role can be given up")


func _launch(co: CompanyBus, contracts: ContractsBus) -> void:
	co.name_ship("some_cid", "  Lady of the Dock  ")
	check(co.name_of("some_cid") == "Lady of the Dock", "the crew names a ship (%s)" % co.name_of("some_cid"))
	var order := {}
	Flags.set_flag(CompanyBus.GROWTH_FLAG, false)
	for o: Dictionary in contracts.ship_orders():
		if contracts.ship_sign_problem(o) == "" and not bool(o.get("repeat", false)):
			order = o
			break
	if order.is_empty():
		check(false, "an order on the board can be signed")
		Flags.set_flag(CompanyBus.GROWTH_FLAG, true)
		return
	var cost := int(float(order.budget) * 0.6)
	contracts.request_sign_ship(order, "d1", "Test design", cost)
	var c := contracts.ship_contract_for(str(order.id))
	check(not c.is_empty(), "a ship signed")
	var lowest := co.rival_bids(order)
	if not lowest.is_empty():
		check(int(c.price) <= int(lowest[0].price) or bool(order.get("repeat", false)) or co._client_level(str(order.client)) >= CompanyBus.LOYAL_LEVEL,
				"signed at no more than the rivals bid (%d against %d)" % [int(c.price), int(lowest[0].price)])
	# Contract papers: the design signed with the quote, a stage gate signed before it is paid.
	Flags.set_flag(ContractsBus.SIGNATURES_FLAG, true)
	var papers := contracts.papers(str(c.id))
	check(papers.size() == 1 and str(papers[0].kind) == "design" and str(papers[0].by) != "", "the design sign-off is on the contract (%s)" % str(papers))
	contracts.request_ship_stage(str(c.id), "keel")
	var keel: Dictionary = contracts.ship_contract(str(c.id)).stages[1]
	check(not bool(keel.paid) and contracts.gates_to_sign(str(c.id)) == ["keel"], "the build reaching the keel makes its gate ready, unpaid")
	contracts.request_sign_gate(str(c.id), "fit_out", "Tester")
	check(not bool(contracts.ship_contract(str(c.id)).stages[1].paid), "a gate not ready cannot be signed")
	contracts.request_sign_gate(str(c.id), "keel", "Tester")
	keel = contracts.ship_contract(str(c.id)).stages[1]
	check(bool(keel.paid) and contracts.gates_to_sign(str(c.id)).is_empty(), "signed, the keel is paid")
	papers = contracts.papers(str(c.id))
	check(papers.size() == 2 and str(papers[1].kind) == "gate" and str(papers[1].by) == "Tester", "and the signed gate is kept with the contract")
	var shot := co.make_screen(150.0, "PAPERS")
	add_child(shot)
	await frames(1)
	shot.queue_free()
	co.name_ship(str(c.id), "Brave Tern")
	var seen: Array = []
	var on_launch := func(e: Dictionary) -> void: seen.append(e)
	co.launched.connect(on_launch)
	contracts.request_deliver_ship(str(c.id), [{"key": "speed", "label": "Speed", "need": 10.0, "have": 20.0, "ok": true, "share": 1.0}])
	co.launched.disconnect(on_launch)
	check(co.record.size() == 1 and str(co.record[0].name) == "Brave Tern", "the handover goes in the record under her name")
	papers = contracts.papers(str(c.id))
	check(papers.size() >= 4 and str(papers.back().kind) == "delivery", "the fit-out signed at delivery and the delivery note kept (%d papers)" % papers.size())
	check(contracts.all_papers().any(func(pp: Dictionary) -> bool: return str(pp.contract) == str(c.id)), "every contract's papers in one list")
	check(seen.size() == 1 and float(seen[0].quality) > 0.0 and seen[0].has("side") and seen[0].has("crew"), "with her quality, crew and miniature")
	Flags.set_flag(CompanyBus.GROWTH_FLAG, true)
	# The send-off itself, on its own (no station in a headless test): the launch node's timeline.
	var root := Node3D.new()
	add_child(root)
	var ship := Node3D.new()
	var hull := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6, 4, 30)
	hull.mesh = box
	ship.add_child(hull)
	var l: Node3D = CompanyBus.Launch.new()
	root.add_child(l)
	l.call("setup", ship, "Brave Tern")
	await frames(1)
	l.call("jump_to", 5.0)
	check(bool(l.get("_broke")), "the bottle breaks on her bow")
	l.call("jump_to", 20.0)
	check(ship.position.z < -10.0, "she leaves the berth bow first (%.1f m)" % ship.position.z)
	l.call("jump_to", CompanyBus.Launch.SECONDS + 1.0)
	await frames(2)
	check(not is_instance_valid(l), "the send-off frees itself when she is gone")
	root.queue_free()
	var screen: Control = co.make_screen(150.0, "SHELF")
	add_child(screen)
	await frames(1)
	check(screen != null, "the trophy shelf draws")
	for p: String in ["RANK", "CLIENTS", "CREW", "LAUNCH", "SHELF"]:
		screen.set("page", p)
		screen.call("refresh")
	screen.queue_free()


func _save(co: CompanyBus) -> void:
	var saved := co.save_data()
	co.reset_data()
	check(co.record.is_empty() and co.names.is_empty(), "reset clears the company")
	co.load_data(saved, CompanyBus.SAVE_VERSION)
	check(co.record.size() == (saved.record as Array).size() and co.name_of("some_cid") == "Lady of the Dock", "the record and names come back")
