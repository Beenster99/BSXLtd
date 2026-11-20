extends Node
## Pictures of the bots for the thread's screenshots page: the board's pages and the time-lapse
## (quick, no station), then the yard: the bot bay, the crew at the freighter, a close-up of a
## welder and the bot camera.
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \
##       res://modules/bots/tools/bots_capture.tscn -- --out=/abs/dir [--only=board,lapse,bay,work,close,cam]
##       [--no-yard] [--size=1600x900]

const Types := preload("res://modules/bots/api/bot_types.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://bots_shots"
	var size := Vector2i(1600, 900)
	var only: PackedStringArray = []
	var yard := not OS.get_cmdline_user_args().has("--no-yard")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		elif arg.begins_with("--size="):
			var p := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(size)
	get_tree().root.size = size
	if not Modules.ready_done:
		await Modules.modules_ready
	for f: String in [YardBus.FLAG, YardBus.STATION, YardBus.DOCK, YardBus.RACKING, BuildBus.FLAG, BuildBus.HAND_FLAG,
			BuildBus.BOT_FLAG, BotsBus.FLAG, BotsBus.BOARD_FLAG, BotsBus.CAMS_FLAG]:
		Flags.set_flag(f, true)
	Flags.set_flag("company.growth", false)  # the yard's rank does not hold the test back
	var build := Modules.bus("build") as BuildBus
	var bots := Modules.bus("bots") as BotsBus
	var biz := Modules.bus("business")
	if biz:
		biz.call("credit", 50000000, "capture", "capture cash")
	bots.reset_data()
	var station: Node3D = null
	if yard and (only.is_empty() or only.has("bay") or only.has("work") or only.has("close") or only.has("cam")):
		station = (load(YardBus.SCENE_PATH) as PackedScene).instantiate() as Node3D
		add_child(station)
		for i in 10:
			await get_tree().process_frame
	build.start_sample_bots()
	for t: String in ["welder", "welder", "frame_tech", "plater", "riveter", "hauler", "inspector", "wirer", "fitout_tech"]:
		bots.buy(t)
	bots.crew.bots[2].name = "Sparky"
	bots.repaint(int(bots.crew.bots[3].id), "Dock blue")
	bots.fast_forward(900.0)
	await get_tree().process_frame

	# The board's pages and the time-lapse, each on a dark backdrop.
	var back := ColorRect.new()
	back.color = Color(0.03, 0.04, 0.06)
	back.size = Vector2(size)
	add_child(back)
	if only.is_empty() or only.has("board"):
		var board: Control = bots.make_board(150.0)
		board.size = Vector2(size) - Vector2(80, 80)
		board.position = Vector2(40, 40)
		back.add_child(board)
		for p: String in ["CREW", "RULES", "WORK", "SHOP", "LOG"]:
			board.set("page", p)
			board.call("refresh")
			await _save(out, "board_" + p.to_lower(), 4)
		board.queue_free()
	if only.is_empty() or only.has("lapse"):
		var lapse: Control = bots.make_lapse(150.0)
		lapse.size = Vector2(size) - Vector2(80, 80)
		lapse.position = Vector2(40, 40)
		back.add_child(lapse)
		lapse.set("_t", 13.0)
		await _save(out, "timelapse", 3)
		lapse.queue_free()
	back.queue_free()
	if station == null:
		get_tree().quit()
		return

	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 1200.0
	add_child(cam)
	if bots.view:
		bots.view.call("snap")
	var berth: Node = build.get("berth")
	if berth and berth.has_method("settle"):
		berth.call("settle")
	if only.is_empty() or only.has("bay"):
		var o := bots.bay_origin()
		cam.global_position = o + Vector3(9, 3, -16)
		cam.look_at(o + Vector3(0, -2, 0))
		cam.current = true
		await _save(out, "yard_bay", 30)
	if only.is_empty() or only.has("work"):
		var c := bots.ship_to_station() * Vector3.ZERO
		cam.global_position = c + Vector3(26, 14, -34)
		cam.look_at(c)
		cam.current = true
		await _save(out, "yard_work", 30)
	if only.is_empty() or only.has("close"):
		var target: Dictionary = {}
		for i in 200:
			for b: Dictionary in bots.crew.bots:
				if str(b.task.get("phase", "")) == "fasten" and Types.kind_skill(int(b.task.get("kind_of", -1))) == "weld":
					target = b
					break
			if not target.is_empty():
				break
			bots.fast_forward(1.0)
			await get_tree().process_frame
		if target.is_empty():
			target = bots.crew.bots[0]
		bots.view.call("snap")
		var look: Node3D = bots.view.call("look_of", int(target.id))
		var at: Vector3 = look.global_position if look else target.pos
		var spot: Vector3 = target.task.get("spot", at)
		cam.global_position = at + (at - spot).normalized().rotated(Vector3.UP, 0.9) * 2.8 + Vector3(0, 1.0, 0)
		cam.look_at(spot.lerp(at, 0.5))
		cam.current = true
		await _save(out, "yard_close", 12)
	if only.has("tow"):
		# Wave 7.4: the freighter towed out to a holding berth, half way, a skiff waiting in H1.
		var rec := DesignRecord.new()
		rec.name = "Skiff"
		DesignBus.Samples.skiff(rec, DesignCatalog.load_default())
		build.start("shot_skiff", rec.to_dict(), rec.name)
		await get_tree().process_frame
		build.move(BuildBus.SAMPLE_BOTS, "H2")
		for t: Dictionary in build.get("_tows"):
			t.t = BuildBus.TUG_SECONDS * 0.45
		var h1 := build.berth_xf("H1").origin
		var h2 := build.berth_xf("H2").origin
		var mid := (h1 + h2) * 0.5
		cam.global_position = mid + Vector3(0, 55, -150)
		cam.look_at(mid + Vector3(0, -4, 0))
		cam.current = true
		await _save(out, "yard_tow", 2)
		build.settle_tows()
		cam.global_position = h2 + Vector3(-30, 22, -60)
		cam.look_at(h2)
		await _save(out, "yard_held", 20)
	if only.is_empty() or only.has("cam"):
		var bc: Control = bots.make_cam(150.0)
		bc.size = Vector2(size) - Vector2(80, 80)
		bc.position = Vector2(40, 40)
		add_child(bc)
		await _save(out, "botcam", 40)
	get_tree().quit()


func _save(out: String, id: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out, id]
	get_viewport().get_texture().get_image().save_png(path)
	print("captured ", path)
