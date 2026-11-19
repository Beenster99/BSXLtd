extends Node
## Screenshots of Esc > Settings > Gameplay > Game time, the host's and a guest's view.
##   xvfb-run godot --path . res://modules/time/internal/tools/time_capture.tscn -- --out=DIR

const SIZE := Vector2i(1280, 860)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The yard replaces the scene, so the work runs from a node of the root.
	if not has_meta("runner"):
		var runner: Node = (get_script() as Script).new()
		runner.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	_run.call_deferred()


func _run() -> void:
	var out := "user://time_shots"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	if not Modules.ready_done:
		await Modules.modules_ready
	var time := Modules.bus("time") as TimeBus
	var business := Modules.bus("business")
	business.call("reset")
	business.call("skip_to_minute", TimeBus.minute_of(3, 14 * 60 + 20))
	var today := int(business.call("get_day"))
	var plan: Variant = business.call("payment_plan", 1800000, today, today + 24)
	business.call("on_contract_accepted_staged", "SO-118 Kestrel Mk II", plan, today + 24)
	time.set_rate(2.0)
	DisplayServer.window_set_size(SIZE)
	get_tree().root.size = SIZE
	var back := ColorRect.new()
	back.color = Color("16191c")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	if "--yard" in OS.get_cmdline_user_args():
		back.queue_free()
		Router.goto("yard.station")
		await _frames(240)
	Menu.open_pause()
	await _frames(5)
	if get_tree().root.find_child("Settings", true, false) == null:
		push_error("TimeCapture: no pause menu")
		get_tree().quit(1)
		return
	(get_tree().root.find_child("Settings", true, false) as Button).pressed.emit()
	await _frames(5)
	var tabs := get_tree().root.find_child("SettingsTabs", true, false)
	tabs.call("open_tab", Menu.GAMEPLAY)
	await _frames(10)
	var section := tabs.find_child("Section_time_controls", true, false) as Control
	var scroll := tabs.find_child("Page", true, false).get_parent() as ScrollContainer
	if section and scroll:
		scroll.scroll_vertical = int(section.position.y) - 8
	await _frames(10)
	await _save(out, "time_host")
	time.set_rate(0.0)
	await _frames(10)
	await _save(out, "time_paused")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(out: String, shot: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(shot + ".png"))
	print("TimeCapture: ", out.path_join(shot + ".png"))
