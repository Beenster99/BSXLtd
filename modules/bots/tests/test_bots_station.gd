extends ModuleTest
## The bots in the open station (master plan 6.4 to 6.7): the bot bay beside the build berth
## with a cradle for each bot; every bot drawn in its own body with arms, jets and a lamp, in its
## paint; a welder at work throws sparks; the berth's card says the bots are building her; the
## board's five pages, its take-over button, the bot camera and the time-lapse all draw.
##   tools/run_tests.sh bots

const Types := preload("res://modules/bots/api/bot_types.gd")
const Look := preload("res://modules/bots/internal/bot_look.gd")


func run_tests() -> void:
	for f: String in [YardBus.FLAG, YardBus.STATION, YardBus.DOCK, YardBus.RACKING, BuildBus.FLAG, BuildBus.HAND_FLAG,
			BuildBus.BOT_FLAG, BotsBus.FLAG, BotsBus.BOARD_FLAG, BotsBus.CAMS_FLAG, BotsBus.TARTANCO_FLAG]:
		Flags.set_flag(f, true)
	Flags.set_flag("company.growth", false)  # the yard's rank does not hold the test back
	var build := Modules.bus("build") as BuildBus
	var bots := Modules.bus("bots") as BotsBus
	bots.reset_data()
	var biz := Modules.bus("business")
	if biz:
		biz.call("credit", 50000000, "test", "test cash")
	# Every look builds, each with its parts.
	for t: String in Types.ORDER:
		var fam := str(Types.info(t).family)
		var look := Look.make(fam, Color("e8792b"), 3, 0.5, 4)
		check(look.get_node_or_null("Body") != null and look.get_node_or_null("Body/Head") != null, "%s has a body and a head" % t)
		check(not (look.get_meta("jets", []) as Array).is_empty(), "%s has jets" % t)
		check(look.find_child("Lamp", true, false) is OmniLight3D, "%s has a work lamp" % t)
		if fam != "inspector":
			check(not Look.tips(look).is_empty(), "%s has arms with tools" % t)
		Look.animate(look, 1.0, 1.0, 2.0)
		look.free()

	var station := (load(YardBus.SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child(station)
	await frames(3)
	var view := bots.view
	check(view != null and is_instance_valid(view) and view.get_parent() == station, "the bots are in the station")
	# The crew is TartanCo's fleet (0.5.3 playtest): no bay of its own; the yard's own bodies stand
	# down and the fleet hangs on its charge docks on the berth's frame.
	var yard := Modules.bus("yard")
	check(bots.fleet_mode() and view.get("bay") == null, "TartanCo's fleet needs no bot bay")
	var own: Array = (station.get("workers") as Node).get("workers")
	check(not own.is_empty() and own.all(func(w: Dictionary) -> bool: return not (w.node as Node3D).visible),
			"the yard's own copies of the fleet are hidden")
	bots.fast_forward(60.0)
	check(bots.crew.bots.size() == 6 and (bots.crew.bots[3].pos as Vector3).distance_to(yard.call("worker_dock_spot", 3)) < 0.3,
			"the six hang on the fleet's charge docks")

	build.start_sample_bots()
	for r: String in ["W", "R"]:
		bots.buy(r)
	await frames(2)
	check(view.call("look_of", int(bots.crew.bots[0].id)) != null, "each bot has its look")
	check((view.get("_bots") as Dictionary).size() == bots.crew.bots.size(), "one look per bot (%d)" % (view.get("_bots") as Dictionary).size())
	var first: Node3D = view.call("look_of", int(bots.crew.bots[0].id))
	check(first != null and bool(first.get_meta("android", false)) and str(first.get_meta("tartanco_model", "")) != "",
			"the crew are TartanCo's androids (%s)" % (str(first.get_meta("tartanco_model", "")) if first else "none"))
	# Run the crew till a welder is welding, and look.
	var saw_sparks := false
	for i in 120:
		bots.fast_forward(2.0)
		await frames(1)
		for b: Dictionary in bots.crew.bots:
			if str(b.task.get("phase", "")) == "fasten" and Types.kind_skill(int(b.task.get("kind_of", -1))) == "weld":
				var e: Dictionary = (view.get("_bots") as Dictionary)[int(b.id)]
				if (e.sparks as CPUParticles3D).emitting:
					saw_sparks = true
		if saw_sparks:
			break
	check(saw_sparks, "a bot welding throws sparks")
	var berth := build.berth
	check(berth != null and str(berth.call("card_text", build.progress())).contains("The bots are building her")
			or str(berth.call("card_text", build.progress())).contains("by hand") or build.job_in_hand() >= 0,
			"the berth's card says the bots are building her (%s)" % str(berth.call("card_text", build.progress())) if berth else "")
	var fleet := Modules.bus("fleet")
	if fleet:
		var rows: Array = fleet.call("rows")
		check(rows.size() == bots.crew.bots.size() and str(rows[2].serial) == "TC-W3-01",
				"the TARTANCO FLEET screen lists the crew (%d)" % rows.size())
		check(rows.any(func(r: Dictionary) -> bool: return str(r.state) == "working"), "and shows them working")
	var work := berth.get("work") as RigidBody3D if berth else null
	check(work != null and (work.get("model") as PartModel).parts.size() > 0, "the jobs the bots floated in are on the ship")

	# A TartanCo mark shows (the chest's model and mark).
	var b0: Dictionary = bots.crew.bots[0]
	var old_look: Node3D = view.call("look_of", int(b0.id))
	bots.upgrade(int(b0.id))
	await frames(2)
	check(int(bots.crew.bots[0].mark) == 2 and view.call("look_of", int(bots.crew.bots[0].id)) != old_look, "an upgraded bot is drawn again")

	# The board.
	var board: Control = bots.make_board(150.0)
	board.size = Vector2(1200, 800)
	add_child(board)
	await frames(1)
	for p: String in ["CREW", "RULES", "WORK", "SHOP", "LOG"]:
		board.set("page", p)
		board.call("refresh")
		await frames(1)
		var body := board.get("_body") as VBoxContainer
		check(body.get_child_count() > 0, "the board's %s page draws" % p)
	check(str(board.call("status_line")).contains("BOTS"), "the board's top line counts the bots")
	board.set("page", "WORK")
	board.call("refresh")
	await frames(1)
	var take: Button = null
	for n in board.find_children("*", "Button", true, false):
		if (n as Button).text == "TAKE OVER":
			take = n
			break
	check(take != null, "a job in hand can be taken over from the board")
	if take:
		take.pressed.emit()
		await frames(1)
		var crew_jobs := (build.active().claims as Dictionary).values().filter(func(w: String) -> bool: return w == BuildBus.CREW_CLAIM)
		check(not crew_jobs.is_empty(), "taken over: it is the crew's job")
	board.set("page", "SHOP")
	board.call("refresh")
	await frames(1)
	var n_before: int = bots.crew.bots.size()
	for n in board.find_children("*", "Button", true, false):
		if (n as Button).text == "BUY":
			(n as Button).pressed.emit()
			break
	await frames(1)
	check(bots.crew.bots.size() == n_before + 1, "BUY in the shop buys a bot")
	board.queue_free()

	# The bot camera and the time-lapse.
	var cam: Control = bots.make_cam(150.0)
	cam.size = Vector2(800, 500)
	add_child(cam)
	await frames(3)
	check(str((cam.get("_caption") as Label).text) != "", "the bot camera says whose it is (%s)" % (cam.get("_caption") as Label).text)
	check((cam.get("_vp") as SubViewport).world_3d == get_tree().root.world_3d, "and looks at the yard")
	cam.queue_free()
	var lapse: Control = bots.make_lapse(150.0)
	lapse.size = Vector2(900, 500)
	add_child(lapse)
	await frames(3)
	check(not (lapse.get("_parts") as Array).is_empty(), "the time-lapse draws the ship's pieces")
	check(str((lapse.get("_caption") as Label).text).contains("jobs done"), "and counts the jobs done (%s)" % (lapse.get("_caption") as Label).text)
	lapse.queue_free()
	build.stop()
	bots.reset_data()
	station.queue_free()
	await frames(2)
