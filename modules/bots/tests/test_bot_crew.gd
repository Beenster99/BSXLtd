extends ModuleTest
## The bots build a bigger ship from its build plan (master plan 6.1 to 6.3, 6.5, 6.7), as data:
## the sample freighter goes to the berth for the bots; the two yardhands take jobs in the rule
## cards' order, claim them, float them in and make their fastenings; several jobs are in hand at
## once; specialists are faster at their trade; a hauler fetches; a pair works one job; an
## inspector makes poor work again; a bot low on charge docks; the crew can take a job over and
## hand it back; the roster and the deck save and load.
##   tools/run_tests.sh bots

const Types := preload("res://modules/bots/api/bot_types.gd")
const Rules := preload("res://modules/bots/api/bot_rules.gd")


func run_tests() -> void:
	for f: String in [BuildBus.FLAG, BuildBus.HAND_FLAG, BuildBus.BOT_FLAG, BotsBus.FLAG]:
		Flags.set_flag(f, true)
	Flags.set_flag("company.growth", false)  # the yard's rank does not hold the test back
	var build := Modules.bus("build") as BuildBus
	var bots := Modules.bus("bots") as BotsBus
	check(build != null and bots != null, "the build and bots modules are loaded")
	if build == null or bots == null:
		return
	bots.reset_data()
	check(bots.crew.bots.size() == 2 and bots.crew.bots.all(func(b: Dictionary) -> bool: return str(b.type) == "yardhand"),
			"a new company has two general bots (%d)" % bots.crew.bots.size())

	# The rule cards' order.
	var info := func(j: int) -> Dictionary: return {"stage": ["frame", "plates", "frame", "pipes"][j], "at": Vector3(0, j, [5.0, -3.0, -8.0, 0.0][j]), "order": j}
	check(Rules.rank([0, 1, 2, 3], info, [{"kind": "order", "arg": "bow", "on": true}]) == [2, 0, 1, 3],
			"bow first: the frame jobs nearest the bow, then the next stage")
	check(Rules.rank([0, 1, 2, 3], info, [{"kind": "order", "arg": "stern", "on": true}]) == [0, 2, 1, 3], "stern first")
	check(Rules.rank([0, 1, 2, 3], info, [{"kind": "rush", "arg": "pipes", "on": true}])[0] == 3, "a rush card puts its stage first")
	check(not Rules.rank([0, 1, 2, 3], info, [{"kind": "hold", "arg": "frame", "on": true}]).has(0), "a hold card keeps its stage back")
	check(Rules.rank([0, 1, 2, 3], info, [{"kind": "hold", "arg": "frame", "on": false}]).has(0), "a card switched off counts for nothing")

	# The freighter comes to the berth for the bots.
	build.start_sample_bots()
	check(build.current == BuildBus.SAMPLE_BOTS and build.crew_of() == BuildBus.CREW_BOTS, "the sample freighter is the bots' build")
	var pl := build.plan()
	check(pl != null and pl.jobs.size() >= 60, "a bigger ship: %d jobs" % (pl.jobs.size() if pl else 0))
	check(build.free_jobs() == [0], "only the first ring can float in at first")
	check(bots.active(), "the bots see a build of theirs in the berth")

	bots.fast_forward(1.0)
	var claims: Dictionary = build.active().claims
	check(claims.has("0") and str(claims["0"]).begins_with("bot:"), "a yardhand claims the first ring (%s)" % str(claims))
	bots.fast_forward(240.0)
	var p := build.progress()
	check(int(p.jobs_done) >= 1, "the yardhands float jobs in and fix them (%d done)" % int(p.jobs_done))
	check((build.active().done as Dictionary).values().all(func(q: float) -> bool: return q > 0.3 and q <= 1.0),
			"their fastenings are fair work")
	var t0 := float(bots.crew.totals.worked)
	check(t0 > 0.0, "the bots log the time they work")
	var by_two := int(p.jobs_done)

	# Specialists: a welder runs a frame's welds far faster than a yardhand.
	var yard_b := {"type": "yardhand", "mark": 1, "wear": 0.0}
	var welder_b := {"type": "welder", "mark": 1, "wear": 0.0}
	check(Types.level(welder_b, "weld") >= 4.0 * Types.level(yard_b, "weld"), "a welder welds four times as fast")
	check(Types.level(welder_b, "fit:fittings") == 0.0, "a welder cannot fit fittings")
	check(Types.fit_stages({"type": "fitout_tech"}) == PackedStringArray(["fittings", "wiring", "pipes"]), "the fit-out tech covers the inside")
	check(Types.pace({"type": "welder", "mark": 3, "wear": 0.0}) > Types.pace(welder_b), "a higher mark is faster")
	check(Types.quality({"type": "welder", "mark": 1, "wear": 0.9}) < Types.quality(welder_b), "wear spoils a bot's work")

	# Buy a crew of specialists (the company pays) and watch it go faster.
	var biz := Modules.bus("business")
	var cash_before := 0
	if biz:
		biz.call("credit", 50000000, "test", "test cash")
		cash_before = int(biz.call("get_cash"))
	for t: String in ["welder", "welder", "frame_tech", "plater", "hauler", "inspector"]:
		bots.buy(t)
	check(bots.crew.bots.size() == 8, "bought six more bots (%d)" % bots.crew.bots.size())
	if biz:
		check(int(biz.call("get_cash")) < cash_before, "the company paid for them")
	bots.fast_forward(600.0)
	p = build.progress()
	check(int(p.jobs_done) >= by_two + 4, "a bigger crew gets on faster (%d jobs, %d before)" % [int(p.jobs_done), by_two])
	var max_in_hand := 0
	for i in 60:
		bots.fast_forward(2.0)
		max_in_hand = maxi(max_in_hand, build.jobs_in_hand().size())
	check(max_in_hand >= 2, "several jobs are in hand at once (%d at most)" % max_in_hand)
	check(bots.crew.bots.any(func(b: Dictionary) -> bool: return str(b.type) == "hauler" and int(b.get("jobs", 0)) == 0),
			"the hauler fetches rather than fits")
	var any_haul := false
	for l in bots.log_lines:
		if l.contains("brought the parts"):
			any_haul = true
	check(any_haul or bots.crew.bots.any(func(b: Dictionary) -> bool: return str(b.task.kind) == "haul"), "a hauler brings parts to the berth")

	# Inspectors make poor fastenings again.
	var done: Dictionary = build.active().done
	var poor_key := ""
	for key: String in done:
		if build.job_finished(int(key.get_slice(":", 0))):
			poor_key = key
			break
	if poor_key != "":
		done[poor_key] = 0.2
		bots.crew.checked.erase(poor_key)
		bots.fast_forward(180.0)
		check(float(build.active().done[poor_key]) > 0.2, "an inspector makes a poor fastening again (%.2f)" % float(build.active().done[poor_key]))
		check(int(bots.crew.totals.reworks) >= 1, "and counts it")

	# Charge: a bot that is low docks at the bay and charges.
	var gus: Dictionary = bots.crew.bots[0]
	gus.charge = 0.05
	bots.crew.call("_drop", gus)
	bots.crew.call("_set_task", gus, {"kind": "idle"})
	bots.fast_forward(1.0)
	check(str(gus.task.kind) == "charge", "a bot low on charge goes to charge (%s)" % str(gus.task.kind))
	bots.fast_forward(200.0)
	check(float(gus.charge) > 0.9, "and charges at the bay (%.2f)" % float(gus.charge))

	# Working alongside: take a job off a bot, hand it back.
	var held_job := -1
	for key: String in build.active().claims:
		if str(build.active().claims[key]).begins_with("bot:"):
			held_job = int(key)
			break
	check(held_job >= 0, "a bot holds a job to take")
	if held_job >= 0:
		bots.take_over(held_job)
		check(build.claimed_by(held_job) == BuildBus.CREW_CLAIM, "the crew takes it over")
		bots.fast_forward(2.0)
		check(not bots.crew.bots.any(func(b: Dictionary) -> bool: return int(b.task.get("job", -1)) == held_job and str(b.task.kind) == "job"),
				"and the bot lets it go")
		bots.fast_forward(20.0)
		check(build.claimed_by(held_job) == BuildBus.CREW_CLAIM, "the bots leave the crew's job alone")
		bots.hand_back(held_job)
		check(build.claimed_by(held_job) == "", "handed back, it is free for the bots")

	# Leave a stage for the crew: the bots don't take it.
	var cards: Array = Rules.defaults()
	cards.append({"id": "x", "kind": "leave", "arg": "frame", "on": true})
	bots.set_cards(cards)
	check(not bots.free_jobs().any(func(j: int) -> bool: return str(pl.jobs[j].stage) == "frame"), "a stage left for the crew is not the bots'")
	bots.set_cards(Rules.defaults())

	# A pair: the helper works on its lead's job.
	var lead: Dictionary = bots.crew.bots[2]
	var helper: Dictionary = bots.crew.bots[3]
	cards = Rules.defaults()
	cards.append({"id": "p", "kind": "pair", "arg": "%d>%d" % [int(helper.id), int(lead.id)], "on": true})
	bots.set_cards(cards)
	var helped := false
	for i in 200:
		bots.fast_forward(1.0)
		if str(helper.task.kind) == "help" and str(helper.task.get("phase", "")) == "fasten" and int(helper.task.get("job", -1)) == int(lead.task.get("job", -2)):
			helped = true
			break
	check(helped, "the helper makes fastenings on its lead's job")
	bots.set_cards(Rules.defaults())

	# Upgrades and modules.
	var b0: Dictionary = bots.crew.bots[1]
	bots.upgrade(int(b0.id))
	check(int(b0.mark) == 2, "a bot raised a mark")
	bots.teach(int(b0.id), "scan_head")
	check(Types.level(b0, "inspect") > 0.0, "a yardhand taught a scan head can inspect")
	bots.teach(int(b0.id), "weld_pack")
	check((b0.modules as Array).size() == 2, "a Mk2 has two module slots")
	bots.teach(int(b0.id), "bolt_pack")
	check((b0.modules as Array).size() == 2, "but not three")
	bots.rename(int(b0.id), "Sparky")
	bots.repaint(int(b0.id), "Teal")
	check(str(b0.name) == "Sparky" and str(b0.paint) == "Teal", "named and painted")

	# The whole freighter, given time.
	bots.fast_forward(7200.0)
	p = build.progress()
	if int(p.jobs_done) < int(p.jobs):
		print("free %s claims %s in hand %s" % [str(build.free_jobs()), str(build.active().claims), str(build.jobs_in_hand())])
		for b: Dictionary in bots.crew.bots:
			print("  %s %s %s %s ch %.2f wear %.2f" % [b.name, b.type, str(b.task), b.line, float(b.charge), float(b.wear)])
		print("stuck %s" % str(bots.crew.stuck))
		for j in build.jobs_in_hand():
			print(" job %d %s key %d done %s" % [j, pl.jobs[j].name, (pl.jobs[j].key as Array).size(), str(range((pl.jobs[j].key as Array).size()).map(func(k: int) -> float: return build.fastening_quality(j, k)))])
	check(int(p.jobs_done) == int(p.jobs), "the bots finish her (%d of %d jobs)" % [int(p.jobs_done), int(p.jobs)])
	check(float(p.workmanship) >= 0.6, "to a fair standard (%.2f)" % float(p.workmanship))
	var lapse: Dictionary = bots.lapse.get(BuildBus.SAMPLE_BOTS, {})
	check(lapse.size() == int(p.jobs), "the time-lapse has when each job was done (%d)" % lapse.size())

	# Save and load.
	var saved := bots.save_data()
	bots.reset_data()
	check(bots.crew.bots.size() == 2, "a new game's crew")
	bots.load_data(saved, BotsBus.SAVE_VERSION)
	check(bots.crew.bots.size() == 8 and str(bots.crew.call("bot", int(b0.id)).name) == "Sparky", "the crew comes back as saved")
	check(int(bots.crew.call("bot", int(b0.id)).mark) == 2, "with its marks")
	build.stop()
	bots.reset_data()
	print("crew totals: %s" % str(bots.crew.totals))
