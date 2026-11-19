extends Node
## Runs stock_capture.tscn's shots (see there).

const SIZE := Vector2i(1920, 1080)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://stock_shots"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(SIZE)
	get_tree().root.size = SIZE
	if not Modules.ready_done:
		await Modules.modules_ready
	var bus := Modules.bus("stores") as StoresBus
	var design := Modules.bus("design") as DesignBus
	if design:
		design.open_sample()
	if "--station" in OS.get_cmdline_user_args():
		Router.goto(YardBus.SCENE)
		await _frames(25)
		for ch in HudSlots.holo_channels():
			print("StockCapture: channel ", ch.id, " ", ch.label)
		for ch in HudSlots.holo_channels():
			HudSlots.open_holo(str(ch.id))
			await _frames(12)
			await _save(out, "wrist_" + str(ch.id).replace(".", "_"))
		get_tree().quit()
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	var screen := bus.make_screen(160.0)
	screen.position = Vector2.ZERO
	screen.size = Vector2(SIZE)
	layer.add_child(screen)
	await _frames(10)
	await _save(out, "stock_wall")
	screen.call("select", "FuelValve")
	await _frames(10)
	await _save(out, "stock_part")
	screen.call("set_filter", "SHORT")
	await _frames(10)
	await _save(out, "stock_short")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(out: String, id: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out.path_join(id + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("StockCapture: ", path)
