extends Node
## Release screenshot tour. Visits every view registered with Shots (the main menu, then
## whatever enabled modules add) and saves a PNG of each. Needs a real renderer, so on a
## server run it under a virtual display with the Compatibility renderer:
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##       res://tools/screenshot_tour/screenshot_tour.tscn -- --out=/abs/path/screenshots
## tools/build/release.sh does this for every build.

const SIZE := Vector2i(1920, 1080)


func _ready() -> void:
	# Router.goto replaces the current scene (this one), so the tour runs from a node that
	# lives beside the autoloads instead.
	var runner := Runner.new()
	runner.name = "ScreenshotTour"
	get_tree().root.add_child.call_deferred(runner)


class Runner:
	extends Node

	func _ready() -> void:
		_run.call_deferred()

	func _run() -> void:
		var out := "user://screenshots"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--out="):
				out = arg.trim_prefix("--out=")
		DirAccess.make_dir_recursive_absolute(out)
		DisplayServer.window_set_size(SIZE)
		get_tree().root.size = SIZE
		if not Modules.ready_done:
			await Modules.modules_ready

		var failed := 0
		var index := 0
		for shot in Shots.all():
			index += 1
			if Router.goto(shot.scene) != OK:
				failed += 1
				continue
			await get_tree().process_frame
			await get_tree().process_frame
			if shot.setup.is_valid():
				await shot.setup.call(get_tree().current_scene)
			for i in shot.frames:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var path := "%s/%02d_%s.png" % [out, index, shot.id]
			var image := get_viewport().get_texture().get_image()
			if image == null or image.save_png(path) != OK:
				printerr("ScreenshotTour: could not save ", path)
				failed += 1
			else:
				print("ScreenshotTour: ", path)
		get_tree().quit(1 if failed > 0 else 0)
