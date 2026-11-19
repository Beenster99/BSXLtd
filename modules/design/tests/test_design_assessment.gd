extends ModuleTest
## Design Room: the contract fit assessment (DesignAssessment and its screen): every area of
## a ship order scored with a validation %, the overall status, pitfalls, bonuses and cheap
## wins, the company optimiser's moves and plan (tried on copied numbers) and its write-up;
## the screen on a wall panel and full screen from the console.
##   tools/run_tests.sh design

const Samples := preload("res://modules/design/internal/sample_designs.gd")
const ContractFit := preload("res://modules/design/internal/views/contract_fit.gd")
const WallBoard := preload("res://modules/design/internal/room/wall_board.gd")
const DesignConsole := preload("res://modules/design/internal/console/design_console.gd")
const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")

var cat := DesignCatalog.load_default()


func skiff() -> DesignRecord:
	var d := DesignRecord.new("a", "Skiff")
	Samples.skiff(d, cat)
	return d


func order(demands: Dictionary, role := "tug", days := 30, pay := 700000) -> Dictionary:
	return {"id": "t1", "client": "scatter_metals", "client_name": "Scatter Metals", "role": role,
			"title": "Test order", "brief": "A test.", "demands": demands, "pay": pay, "days": days}


func assess(d: DesignRecord, o: Dictionary) -> DesignAssessment:
	var t := DesignTotals.compute(d, cat)
	return DesignAssessment.assess(d, cat, t, DesignRules.check(d, cat, t), o)


func run_tests() -> void:
	_areas()
	_no_brief()
	_pitfalls_and_plan()
	_bonuses_and_penalties()
	_cheap_wins()
	_status()
	_speed()
	await _screen()


func _areas() -> void:
	var a := assess(skiff(), order({"cargo_m3": 40.0, "crew": 4.0, "budget": 2000000.0}))
	var ids: PackedStringArray = []
	for ar in a.areas:
		ids.append(str(ar.id))
		check(float(ar.score) >= 0.0 and float(ar.score) <= 1.0, "%s's validation %% is 0 to 100" % ar.id)
	check(ids == PackedStringArray(["brief", "budget", "schedule", "rules", "systems", "crew", "role"]),
			"seven areas, in order: %s" % [ids])
	check(not (a.area("brief").checks as Array).is_empty(), "the brief area lists its demands")
	check(a.score > 0.0 and a.score <= 1.0, "an overall %% (%d)" % int(a.score * 100.0))
	check(a.met().y == 4, "three demands and the delivery are scored (%d)" % a.met().y)
	check(not a.narrative.is_empty() and a.narrative[a.narrative.size() - 1].contains("fee"), "the optimiser ends on the fee")


func _no_brief() -> void:
	var a := assess(skiff(), {})
	check(a.status == DesignAssessment.NO_BRIEF, "no order: no brief")
	check(not a.area("brief").assessed and a.area("rules").assessed, "the rules are still assessed without an order")
	check(a.narrative.size() >= 1 and a.narrative[0].contains("SHIP ORDER"), "the optimiser says to pick an order")


func _pitfalls_and_plan() -> void:
	# The skiff has about 89 m3 of cargo and 10 kW spare: ask for more of both.
	var a := assess(skiff(), order({"cargo_m3": 160.0, "power": 60.0, "budget": 3000000.0}))
	check(a.area("brief").status == DesignAssessment.FAIL, "short of the brief fails the brief area")
	var pits := a.findings_of(DesignAssessment.PITFALL)
	check(pits.any(func(f: Dictionary) -> bool: return str(f.text).begins_with("Cargo space")), "a cargo pitfall")
	check(pits.any(func(f: Dictionary) -> bool: return str(f.text).begins_with("Spare power")), "a power pitfall")
	check(a.moves.any(func(m: Dictionary) -> bool: return "Cargo space" in m.fixes), "a move fixes the cargo")
	check(not a.plan.is_empty() and int(a.plan_result.met) == int(a.plan_result.total),
			"the optimiser's plan meets every demand (%s)" % [a.plan_result])
	check(float(a.plan_result.extra) > 0.0, "the plan costs something (CR %d)" % int(a.plan_result.get("extra", 0)))
	# The plan's moves really work: add what it says and assess again.
	var d := skiff()
	for m: Dictionary in a.plan:
		var how: Dictionary = m.how
		if how.has("add"):
			for i in int(how.n):
				d.apply({"op": "add_component", "component": {"type": str(how.add), "room": "r4", "x": -6.0, "z": -5.0}})
			for i in int(how.get("power", 0)):
				d.apply({"op": "add_component", "component": {"type": DesignAssessment.POWER_PART, "room": "r5", "x": 2.0, "z": 0.0}})
	var b := assess(d, a.order)
	check(b.met().x == b.met().y, "after the plan's parts are added every demand is met (%d of %d)" % [b.met().x, b.met().y])
	check(Array(a.narrative).any(func(p: String) -> bool: return p.begins_with("What I would change")), "the write-up gives the plan")


func _bonuses_and_penalties() -> void:
	# Easy demands with lots of time: beats the brief and delivers early.
	var easy := assess(skiff(), order({"cargo_m3": 20.0, "crew": 2.0, "budget": 3000000.0}, "tug", 60))
	check(easy.bonus_total > 0, "beating the brief and delivering early earn bonuses (CR %d)" % easy.bonus_total)
	check(easy.expected_fee() > easy.fee, "the expected fee rises with them")
	check(easy.findings_of(DesignAssessment.BONUS).any(func(f: Dictionary) -> bool: return str(f.text).contains("early")),
			"an early delivery bonus")
	# Far too little time: late penalties.
	var late := assess(skiff(), order({"crew": 2.0, "budget": 3000000.0}, "tug", 5))
	check(late.penalty_total > 0 and late.expected_fee() < late.fee, "late delivery costs penalties (CR %d)" % late.penalty_total)
	check(late.area("schedule").status == DesignAssessment.FAIL, "late fails the schedule area")
	# Over budget.
	var dear := assess(skiff(), order({"crew": 2.0, "budget": 100000.0}))
	check(dear.area("budget").status == DesignAssessment.FAIL, "over budget fails the cost area")


func _cheap_wins() -> void:
	var a := assess(skiff(), order({"crew": 2.0, "budget": 3000000.0}, "patrol"))
	var saves := a.moves.filter(func(m: Dictionary) -> bool: return m.kind == "save")
	check(not saves.is_empty(), "the optimiser finds savings that keep the brief met (%d)" % saves.size())
	for m: Dictionary in saves:
		check(float(m.cost) < 0.0, "a saving saves: %s" % m.text)
		check(not str(m.how.get("to", "")).ends_with("R") or not (cat.part(str(m.how.get("to", ""))).category in DesignAssessment.NO_RECLAIMED),
				"never reclaimed life support or medical kit: %s" % m.text)
	check(not a.findings_of(DesignAssessment.WIN).is_empty(), "savings show as cheap wins")
	var courier := assess(skiff(), order({"crew": 2.0, "budget": 3000000.0}, "courier"))
	check(not courier.moves.any(func(m: Dictionary) -> bool: return str(m.how.get("to", "")).ends_with("R")),
			"a courier's optimiser never offers reclaimed parts")


func _status() -> void:
	var good := assess(skiff(), order({"crew": 2.0, "cargo_m3": 20.0, "budget": 3000000.0}, "tug", 60))
	check(good.status in [DesignAssessment.READY, DesignAssessment.CARE], "everything met: ready to bid (%s)" % good.status)
	var bad := assess(skiff(), order({"attack": 400.0, "defence": 900.0, "speed": 500.0, "jump_ly": 40.0, "budget": 300000.0}, "patrol", 5))
	check(bad.status in [DesignAssessment.WORK, DesignAssessment.NOT_VIABLE], "far off the brief: needs work or not viable (%s)" % bad.status)


func _speed() -> void:
	var d := skiff()
	var t := DesignTotals.compute(d, cat)
	var probs := DesignRules.check(d, cat, t)
	var t0 := Time.get_ticks_msec()
	for o: Dictionary in ShipOrders.for_cycle(3):
		DesignAssessment.assess(d, cat, t, probs, o)
	var ms := Time.get_ticks_msec() - t0
	check(ms < 1000, "four orders assessed in %d ms" % ms)


func _screen() -> void:
	var bus := Modules.bus("design") as DesignBus
	check(bus != null, "the design bus is up")
	if bus == null:
		return
	var rec := bus.open_sample()
	bus.editor.do({"op": "set_meta", "fields": {"order": order({"cargo_m3": 160.0, "power": 60.0, "budget": 3000000.0})}})
	check(bus.assessment() != null and bus.assessment() == bus.assessment(), "the bus keeps one assessment per edit")
	var view := ContractFit.new()
	view.custom_minimum_size = Vector2(1600, 900)
	add_child(view)
	view.setup(bus, 18)
	await get_tree().process_frame
	await get_tree().process_frame
	check(view.find_child("Optimiser", true, false) != null, "the screen has the company optimiser")
	check(view.find_children("Area_*", "", true, false).size() == 7, "the screen shows the seven areas")
	var status := view.find_child("Status", true, false) as Label
	check(status != null and status.text == bus.assessment().status, "the screen shows the overall status")
	check(view.find_children("Finding_pitfall", "", true, false).size() > 0, "the screen lists pitfalls")
	# An edit refreshes it.
	bus.editor.do({"op": "set_meta", "fields": {"order": {}}})
	await get_tree().process_frame
	await get_tree().process_frame
	status = view.find_child("Status", true, false) as Label
	check(status != null and status.text == DesignAssessment.NO_BRIEF, "clearing the order refreshes the screen")
	view.queue_free()
	# A wall panel can show it.
	var board := WallBoard.new()
	add_child(board)
	board.setup(bus, "test", [["fit", 1.0]], 150.0)
	check("fit" in board.views(), "the walls' views include the contract fit assessment")
	check(board.content(0) != null and board.content(0).name == "ContractFit", "a wall panel shows the assessment")
	board.queue_free()
	# The console opens it full screen from the data channel.
	bus.editor.do({"op": "set_meta", "fields": {"order": order({"crew": 2.0, "budget": 3000000.0})}})
	var holo := HoloTable.new()
	add_child(holo)
	holo.setup(bus)
	var layer := CanvasLayer.new()
	add_child(layer)
	var console := DesignConsole.new()
	layer.add_child(console)
	console.setup(bus, holo)
	await get_tree().process_frame
	await get_tree().process_frame
	var btn := console.find_child("BtnAssessment", true, false) as Button
	check(btn != null, "the console's data channel has FULL ASSESSMENT")
	if btn:
		btn.pressed.emit()
		await get_tree().process_frame
		check(console.find_child("Assessment", true, false) != null, "FULL ASSESSMENT opens it over the console")
		console.toggle_assessment()
		await get_tree().process_frame
		await get_tree().process_frame
		check(console.find_child("Assessment", true, false) == null, "and CLOSE shuts it")
	layer.queue_free()
	holo.queue_free()
	check(rec != null, "the sample design was open throughout")
