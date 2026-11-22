extends PanelContainer
## The wrist's Build plan channel: the build in the berth, stage by stage (master plan 5.1),
## the job in hand and what it asks, the workmanship so far and the payments the build has
## earned. Redraws as the build moves on.

const T := preload("res://modules/ui/api/terminal_kit.gd")

var bus: Object
var glass := false
var _body: VBoxContainer


func setup(build_bus: Object, on_glass := false) -> Control:
	bus = build_bus
	glass = on_glass
	name = "BuildPlanScreen"
	custom_minimum_size = Vector2(860, 520)
	add_theme_stylebox_override("panel", T.plate(18.0, glass, T.KIOSK))
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	add_child(_body)
	bus.connect("build_changed", _fill)
	var contracts := Modules.bus("contracts")
	var on_contract := func(_id: String) -> void: _fill()
	if contracts:
		contracts.connect("ship_contract_changed", on_contract)
	tree_exiting.connect(func() -> void:
		if bus.is_connected("build_changed", _fill):
			bus.disconnect("build_changed", _fill)
		if contracts and contracts.is_connected("ship_contract_changed", on_contract):
			contracts.disconnect("ship_contract_changed", on_contract))
	_fill()
	return self


func _fill() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var p: Dictionary = bus.call("progress")
	if p.is_empty():
		_body.add_child(T.label("BUILD PLAN", "display_bold", 30, T.TEXT))
		_body.add_child(T.label("Nothing in the build berth. Sign a ship contract and its design comes to the berth as a ghost ship, to build by hand or with the bots.",
				"body", 18, T.DIM))
		_berths()
		return
	var head := HBoxContainer.new()
	var title := T.label("BUILD PLAN  ·  %s" % str(p.design_name).to_upper(), "display_bold", 28, T.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(T.label("JOBS %d / %d" % [int(p.jobs_done), int(p.jobs)], "mono_bold", 20, T.AMBER))
	_body.add_child(head)
	_crew_row(p)
	var figures := HBoxContainer.new()
	figures.add_theme_constant_override("separation", 10)
	var w := float(p.workmanship)
	figures.add_child(T.figure("Workmanship", ("%s  %d%%" % [str(p.grade), roundi(w * 100.0)]) if w >= 0.0 else "-",
			T.GOOD if w >= 0.8 else (T.AMBER if w >= 0.5 else (T.BAD if w >= 0.0 else T.DIM)), glass))
	figures.add_child(T.figure("Hand fastenings", "%d / %d" % [int(p.key_done), int(p.key)], T.TEXT, glass))
	var paid: Array = p.paid
	figures.add_child(T.figure("Paid by the build", ", ".join(paid.map(func(s: String) -> String:
			return "Keel" if s == "keel" else "Fit-out")) if not paid.is_empty() else "-", T.CYAN, glass))
	_body.add_child(figures)
	var pl: BuildPlan = bus.call("plan")
	for s: String in pl.stages():
		var counts: Array = p.by_stage[s]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var now := s == str(p.stage)
		var name := T.label(("▶ " if now else "   ") + str(BuildPlan.STAGES[s].name), "display_medium", 20,
				T.ORANGE_HI if now else (T.GOOD if int(counts[0]) >= int(counts[1]) else T.TEXT))
		name.custom_minimum_size.x = 260
		row.add_child(name)
		var bar := ProgressBar.new()
		bar.max_value = maxf(1.0, float(counts[1]))
		bar.value = float(counts[0])
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(360, 18)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		row.add_child(T.label("%d / %d" % [int(counts[0]), int(counts[1])], "mono_medium", 18, T.DIM))
		var pays: Array[String] = []
		for pay: String in BuildPlan.PAYMENTS:
			if (BuildPlan.PAYMENTS[pay] as Array).back() == s:
				pays.append(("Keel laid" if pay == "keel" else "Fit-out") + (" paid" if paid.has(pay) else " pays here"))
		if not pays.is_empty():
			row.add_child(T.label("  ".join(pays), "mono_medium", 15, T.CYAN))
		_body.add_child(row)
	var job := T.label("", "body", 19, T.TEXT)
	job.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var berth: Node = bus.get("berth")
	if berth and is_instance_valid(berth):
		job.text = str(berth.call("card_text", p))
	else:
		job.text = "Next: %s. Go out to the build berth to work on her." % str(p.job_name)
	_body.add_child(job)
	if str(p.get("parts_wait", "")) != "":
		var wait := T.label("Waiting for parts: %s." % str(p.parts_wait), "body", 18, T.AMBER)
		wait.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(wait)
		var orders := Modules.bus("orders")
		if orders and str(p.parts_wait).contains("not ordered"):
			var go := T.button("ORDER THE CHEAPEST PLAN", true, 18, false, glass)
			var cid := str(p.contract)
			go.pressed.connect(func() -> void: orders.call("order_cheapest", cid))
			_body.add_child(go)
	_gates(str(p.contract))
	_berths()


## Contract papers: the stage gates this build has reached, waiting for a player's signature.
func _gates(cid: String) -> void:
	var contracts := Modules.bus("contracts") as ContractsBus
	if contracts == null or not Flags.is_on(ContractsBus.SIGNATURES_FLAG):
		return
	var gates := contracts.gates_to_sign(cid)
	if gates.is_empty():
		return
	var c := contracts.ship_contract(cid)
	var g := str(gates[0])
	var stage_name := g
	for st: Dictionary in c.get("stages", []):
		if str(st.id) == g:
			stage_name = "%s (CR %s)" % [str(st.name), T.money(int(st.value))]
	var go := T.button("SIGN STAGE GATE: %s  as %s" % [stage_name.to_upper(), contracts.signer()], true, 18, false, glass)
	go.pressed.connect(func() -> void: contracts.request_sign_gate(cid, g, contracts.signer()))
	_body.add_child(go)


## Who builds her, and the button that changes it (0.5.3 playtest: the bots could not be put on
## a small ship's build).
func _crew_row(p: Dictionary) -> void:
	var bots := str(p.get("crew", "")) == BuildBus.CREW_BOTS
	if not bots and not Flags.is_on(BuildBus.BOT_FLAG):
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var who := T.label("Built by the bots: they float the jobs in and fasten them. Take any job yourself as you like." if bots
			else "Built by hand: you and your crew float each job in and fasten it.", "body", 18, T.TEXT)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(who)
	var go := T.button("BUILD HER BY HAND" if bots else "BOTS BUILD HER", not bots, 18, false, glass)
	go.name = "CrewButton"
	go.pressed.connect(func() -> void: bus.call("set_crew", BuildBus.CREW_HAND if bots else BuildBus.CREW_BOTS))
	row.add_child(go)
	_body.add_child(row)


## Master plan 7.4: every ship on the go, the berth she is in, and the tug to move her.
func _berths() -> void:
	var builds: Dictionary = bus.get("builds")
	if builds.is_empty() or not Flags.is_on(BuildBus.HOLDING_FLAG):
		return
	_body.add_child(T.label("BERTHS", "display_bold", 22, T.ORANGE))
	for cid: String in builds:
		var b: Dictionary = builds[cid]
		var at := str(b.get("berth", ""))
		var p: Dictionary = bus.call("progress", cid)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var where := T.label(at if at != "" else "--", "mono_bold", 20, T.AMBER if at == "B1" else T.TEXT)
		where.custom_minimum_size.x = 50
		row.add_child(where)
		var what := T.label("%s  ·  %d / %d jobs  ·  %s" % [str(b.get("design_name", cid)), int(p.get("jobs_done", 0)),
				int(p.get("jobs", 0)), "the bots" if str(b.get("crew", "")) == BuildBus.CREW_BOTS else "by hand"], "body", 18, T.TEXT)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.clip_text = true
		row.add_child(what)
		for to in BuildBus.BERTH_IDS:
			if to == at or not bool(bus.call("berth_free", to)):
				continue
			var go := T.button("TUG TO %s" % to, false, 15, false, glass)
			go.pressed.connect(func() -> void: bus.call("move", cid, to))
			row.add_child(go)
		_body.add_child(row)
