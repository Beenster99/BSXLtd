extends Node
## Pictures of the parts orders screen (no station: quick), for the thread's screenshots page.
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \
##       res://modules/orders/tools/orders_capture.tscn -- --out=/abs/dir


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://orders_shots"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var size := Vector2i(1600, 1000)
	DisplayServer.window_set_size(size)
	get_tree().root.size = size
	if not Modules.ready_done:
		await Modules.modules_ready
	for f: String in [BuildBus.FLAG, BuildBus.BOT_FLAG, BuildBus.HOLDING_FLAG, OrdersBus.FLAG, OrdersBus.GATE_FLAG, OrdersBus.USED_FLAG]:
		Flags.set_flag(f, true)
	Flags.set_flag("company.growth", false)  # the yard's rank does not hold the test back
	var build := Modules.bus("build") as BuildBus
	var orders := Modules.bus("orders") as OrdersBus
	var biz := Modules.bus("business")
	if biz:
		biz.call("credit", 80000000, "capture", "capture cash")
	var rec := DesignRecord.new()
	rec.name = "Hesper freighter"
	DesignBus.Samples.freighter(rec, orders.catalog())
	build.start("shot_ship", rec.to_dict(), rec.name, BuildBus.CREW_BOTS)
	await get_tree().process_frame
	var back := ColorRect.new()
	back.color = Color(0.03, 0.04, 0.06)
	back.size = Vector2(size)
	add_child(back)
	var screen: Control = orders.make_screen(150.0)
	screen.size = Vector2(size) - Vector2(80, 80)
	screen.position = Vector2(40, 40)
	back.add_child(screen)
	await _save(out, "orders_list")
	# The frame and skin bought now, split between two vendors; the rest still to choose.
	for l: Dictionary in orders.lines("shot_ship"):
		if str(l.stage) in ["frame", "plates"]:
			var qs := orders.quotes("shot_ship", l)
			if qs.size() >= 2 and str(l.key) == "hull:hull":
				orders.set_split("shot_ship", str(l.key), str(qs[0].vendor), ceilf(float(l.need) * 0.6))
				orders.set_split("shot_ship", str(l.key), str(qs[1].vendor), float(l.need))
			elif not qs.is_empty():
				orders.set_split("shot_ship", str(l.key), str(qs[0].vendor), float(l.need))
	orders.place("shot_ship")
	for o: Dictionary in orders.orders:
		if o.id == 1:
			o.due = orders.now_minute()
			o.late = 0
	orders.deliver_due()
	for l: Dictionary in orders.lines("shot_ship"):
		if str(l.kind) == "component":
			var qs := orders.quotes("shot_ship", l)
			orders.set_split("shot_ship", str(l.key), str(qs.back().vendor), float(l.need))
			break
	screen.call("refresh")
	await _save(out, "orders_placed")
	get_tree().quit()


func _save(out: String, id: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out, id]
	get_viewport().get_texture().get_image().save_png(path)
	print("captured ", path)
