extends ModuleTest
## Game time (beenster, 19 Nov: speed time up and down, or pick a future date): the host's pace
## runs Business's calendar and the yard's work together, skipping ahead closes every day in
## between (rent, the market, payments due), and only the host's asks go through.
##   tools/run_tests.sh time

func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "shared_components": true,
			"business": true, "business.market": true, "business.economy": true, "time": true, "time.hud": true,
			"multiplayer": true})
	Modules.load_all()
	var time := Modules.bus("time") as TimeBus
	var business := Modules.bus("business") as BusinessBus
	check(time != null and business != null, "game time and business load")
	if time == null or business == null:
		Flags.use(saved)
		Modules.load_all()
		return
	business.reset()
	time.reset_data()
	check(is_equal_approx(time.rate, 1.0) and is_equal_approx(business.time_rate(), 1.0), "a new game runs at x1")
	check(is_equal_approx(time.day_seconds(), 720.0), "at x1 a day is 12 real minutes (%s s)" % time.day_seconds())

	# The pace.
	time.set_rate(2.0)
	check(is_equal_approx(time.rate, 2.0) and is_equal_approx(business.time_rate(), 2.0), "x2 is taken and Business's clock follows it")
	check(is_equal_approx(time.day_seconds(), 360.0), "at x2 a day is 6 minutes")
	var ahead := business.get_minute() + 120
	check(business.seconds_until(ahead) == 30, "parts due in 2 game hours arrive in 30 real seconds at x2 (%d)" % business.seconds_until(ahead))
	check(HudSlots.infos().any(func(c: Dictionary) -> bool: return c.id == TimeBus.INFO_ID and str(c.title) == "Time x2"),
			"a card says time runs at x2")
	time.set_rate(3.0)
	check(is_equal_approx(time.rate, 2.0), "a pace not on offer is refused")
	time.set_rate(0.0)
	check(business.arrival_text(ahead) == "PAUSED", "paused, an order on its way says so")
	time.set_rate(1.0)
	check(not HudSlots.infos().any(func(c: Dictionary) -> bool: return c.id == TimeBus.INFO_ID), "back at x1 the card goes")

	# The clock really runs at the pace while a yard is open (Business's _process).
	var fake_yard := Node3D.new()
	add_child(fake_yard)
	business.set("_yard", fake_yard)
	var m0 := business.get_minute()
	time.set_rate(4.0)
	business.call("_process", 1.0)
	check(business.get_minute() - m0 == 8, "a real second at x4 is 8 game minutes (%d)" % (business.get_minute() - m0))
	time.set_rate(0.0)
	business.call("_process", 5.0)
	check(business.get_minute() - m0 == 8, "paused, the calendar stands still")
	business.set("_yard", null)
	fake_yard.queue_free()
	time.set_rate(1.0)

	# Skipping ahead: every day in between closes.
	var closed: Array[int] = []
	var on_close := func(d: int) -> void: closed.append(d)
	business.day_closed.connect(on_close)
	var cash0 := business.get_cash()
	var day0 := business.get_day()
	time.skip_to(TimeBus.minute_of(day0 + 5, TimeBus.MORNING))
	check(business.get_day() == day0 + 5 and business.get_minute() % TimeBus.MINUTES_PER_DAY == TimeBus.MORNING,
			"skipped to day %d, 08:00 (%s)" % [day0 + 6, business.get_clock_text()])
	check(closed.size() == 5, "five days closed on the way (%d)" % closed.size())
	check(business.get_cash() <= cash0 - 5 * business.get_rules().bay_rent_per_day, "rent was paid for each (%d)" % (cash0 - business.get_cash()))
	check(int(time.last_skip.get("to", -1)) == business.get_minute(), "the skip is remembered for the screen")
	var here := business.get_minute()
	time.skip_to(here - 10)
	check(business.get_minute() == here, "a skip into the past is refused")
	time.skip_to(here + (TimeBus.MAX_SKIP_DAYS + 1) * TimeBus.MINUTES_PER_DAY)
	check(business.get_minute() == here, "a skip past %d days is refused" % TimeBus.MAX_SKIP_DAYS)
	var morning := time.next_morning()
	check(morning > here and morning % TimeBus.MINUTES_PER_DAY == TimeBus.MORNING and morning - here <= TimeBus.MINUTES_PER_DAY,
			"the next morning is the next 08:00")
	business.day_closed.disconnect(on_close)

	# What's coming up: a staged contract's payments and its due day.
	business.on_contract_accepted_staged("SO-T", BusinessBus.payment_plan(400000, business.get_day(), business.get_day() + 20), business.get_day() + 20)
	var coming := time.coming_up(20)
	check(coming.any(func(e: Dictionary) -> bool: return str(e.what).contains("payment expected")), "payments to come are listed: %s" % [coming])
	check(coming.any(func(e: Dictionary) -> bool: return str(e.what).ends_with("due")), "and the contract's due day")

	# Only the host's asks go through.
	check(time._validate_rate(1, {"rate": 2.0}) is Dictionary, "solo, the player is the host")
	time._net = _FakeNet.new(true, 1)
	check(time._validate_rate(3, {"rate": 2.0}) is String, "the host refuses a guest's ask for a pace")
	check(time._validate_skip(3, {"to": here + 600}) is String, "and a guest's skip")
	check(time._validate_rate(1, {"rate": 2.0}) is Dictionary, "and takes its own")
	time._net = _FakeNet.new(false, 3)
	check(not time.can_control(), "a guest's controls are read-only")
	time._apply_beat({"minute": here + 100, "at": 0.0, "rate": 2.0})
	check(is_equal_approx(time.rate, 2.0) and time.now_minute() >= here + 100, "a guest takes the host's time and pace")
	time._net = null
	time.reset_data()

	# Saves.
	time.load_data({"rate": 4.0}, 1)
	check(is_equal_approx(time.rate, 4.0) and is_equal_approx(time.save_data().rate, 4.0), "the pace is saved with the game")
	time.load_data({"rate": 7.0}, 1)
	check(is_equal_approx(time.rate, 1.0), "a pace not on offer loads as x1")

	# The settings section.
	var panel := time.make_panel()
	add_child(panel)
	await frames(2)
	var x4 := panel.find_child("Rate_x4", true, false) as Button
	check(x4 != null and panel.find_child("Rate_Paused", true, false) != null, "the section has a button for each pace")
	if x4:
		x4.pressed.emit()
		check(is_equal_approx(time.rate, 4.0), "pressing X4 sets the pace")
	var day_box := panel.find_child("Day", true, false) as SpinBox
	var skip := panel.find_child("Skip", true, false) as Button
	if day_box and skip:
		var want := business.get_day() + 3
		day_box.value = want + 1   # the box counts days from 1
		skip.pressed.emit()
		check(business.get_day() == want, "the section skips to the day picked (%d)" % business.get_day())
	panel.queue_free()
	time.reset_data()

	Flags.use(saved)
	Modules.load_all()


class _FakeNet:
	extends RefCounted
	var host := false
	var me := 1
	func _init(p_host: bool, p_me: int) -> void:
		host = p_host
		me = p_me
	func is_online() -> bool:
		return true
	func is_host() -> bool:
		return host
	func local_peer_id() -> int:
		return me
	func server_time() -> float:
		return 0.0
