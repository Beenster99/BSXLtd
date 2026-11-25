extends ModuleTest
## The loading screen (flag "core.loading_screen"): it holds the controls while up, waits for
## every hold, settles, then goes; holds made while it is down are ignored; goto_loading in a
## headless run is a plain goto. Drives Router's screen directly (headless runs never show it).
##   tools/run_tests.sh core


func run_tests() -> void:
	var screen := Router.get_node("LoadingScreen") as CanvasLayer
	check(screen != null, "Router has a loading screen")
	check(not Router.is_loading(), "not loading at the start")

	# Holds while it is down do nothing.
	Router.hold_loading("test.idle", "Nothing")
	check(not Router.is_holding_loading("test.idle"), "a hold while not loading is ignored")

	screen.call("begin", "Test yard")
	check(Router.is_loading(), "loading once begun")
	check(screen.visible, "the screen shows")
	check(HudSlots.pointer_claimed(), "the controls are held while loading")

	Router.hold_loading("test.a", "Doing A...")
	Router.hold_loading("test.b", "Doing B...")
	screen.call("scene_built")
	var built := float(screen.get("target"))
	await _frames(3)
	check(Router.is_loading(), "still loading while work is held")
	Router.loading_progress("test.a", 0.5)
	await _frames(2)
	var mid := float(screen.get("target"))
	check(mid > built, "progress moves the bar on (%.2f > %.2f)" % [mid, built])
	Router.release_loading("test.a")
	await _frames(2)
	check(float(screen.get("target")) >= mid, "the bar never goes back")
	check(Router.is_loading(), "one hold left keeps it up")

	var finished := [false]
	var on_finish := func() -> void: finished[0] = true
	Router.loading_finished.connect(on_finish)
	Router.release_loading("test.b")
	var waited := 0
	while Router.is_loading() and waited < 600:
		await get_tree().process_frame
		waited += 1
	check(not Router.is_loading(), "it goes once the holds are done and the frames settle")
	check(finished[0], "loading_finished fires")
	check(not HudSlots.pointer_claimed(), "the controls are free again")
	await get_tree().create_timer(0.8).timeout
	check(not screen.visible, "the screen has faded out")
	Router.loading_finished.disconnect(on_finish)

	# A hold still moving on keeps the screen past the give-up (a long co-op yard catching up);
	# one stuck that long lets it go.
	screen.call("begin", "Long yard")
	Router.hold_loading("test.long", "Catching up...")
	screen.call("scene_built")
	var give_up_ms := int(screen.GIVE_UP_S * 1000.0) + 5000
	screen.set("_started_ms", Time.get_ticks_msec() - give_up_ms)
	Router.loading_progress("test.long", 0.4)
	await _frames(3)
	check(Router.is_loading() and Router.is_holding_loading("test.long"), "progress past the give-up keeps the screen up")
	screen.set("_started_ms", Time.get_ticks_msec() - give_up_ms)
	Router.loading_progress("test.long", 0.4)
	await _frames(3)
	check(not Router.is_holding_loading("test.long"), "a hold that stopped moving is given up")
	await get_tree().create_timer(0.8).timeout

	# release_all ends it at once.
	screen.call("begin", "Again")
	Router.hold_loading("test.c", "Stuck")
	screen.call("release_all")
	check(not Router.is_loading() and not HudSlots.pointer_claimed(), "release_all ends the load")
	await get_tree().create_timer(0.8).timeout

	# Headless: goto_loading is a plain goto (nothing to draw it on).
	Router.set_loading_title("test.missing", "Missing")
	check(Router.goto_loading("test.missing") == ERR_DOES_NOT_EXIST, "an unknown scene is refused")
	check(not Router.is_loading(), "and shows nothing")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
