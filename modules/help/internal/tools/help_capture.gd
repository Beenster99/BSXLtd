extends Node
## Screenshots of the Help tab for the thread's page (run under a display):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##       res://modules/help/internal/tools/help_capture.tscn -- --out=/abs/dir
## Saves help_<page>.png for a few pages, as the wrist pane shows them.


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://help_shots"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var size := Vector2i(1600, 900)
	DisplayServer.window_set_size(size)
	get_tree().root.size = size
	if not Modules.ready_done:
		await Modules.modules_ready
	var bus := Modules.bus("help") as HelpBus
	var layer := CanvasLayer.new()
	add_child(layer)
	var screen := bus.make_screen(150.0)
	screen.size = Vector2(size)
	layer.add_child(screen)
	for id in ["start", "contracts", "keys"]:
		screen.call("show_topic", id)
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("help_%s.png" % id))
	get_tree().quit()
