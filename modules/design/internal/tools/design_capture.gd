extends Node
## Screenshots of the design room for the screenshots page (run under a display):
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . \
##       res://modules/design/internal/tools/design_capture.tscn -- --flags=design.room=on --out=/abs/dir
## Saves console.png (the design console), room.png (the room with its TVs and table),
## holo_cut.png (the holotable cut through deck 1) and tv_plan.png (a wall TV's plan).

const SIZE := Vector2i(1920, 1080)


func _ready() -> void:
	var runner := Runner.new()
	runner.name = "DesignCapture"
	get_tree().root.add_child.call_deferred(runner)


class Runner:
	extends Node

	func _ready() -> void:
		_run.call_deferred()

	func _run() -> void:
		var out := "user://design_shots"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--out="):
				out = arg.trim_prefix("--out=")
		DirAccess.make_dir_recursive_absolute(out)
		DisplayServer.window_set_size(SIZE)
		get_tree().root.size = SIZE
		if not Modules.ready_done:
			await Modules.modules_ready
		var bus := Modules.bus("design") as DesignBus
		bus.open_sample()
		Router.goto("design.room")
		await _frames(20)
		var room: Node = get_tree().current_scene
		room.console.plan.select("room", "r4")
		room.console.plan.set_tool("room:workshop")
		await _frames(30)
		await _save(out, "console")
		room.console.plan.set_tool("select")
		room.set_room_view(true)
		await _frames(30)
		await _save(out, "room")
		room.set_room_view(false)
		for layer in ["frame", "power"]:
			(room.console.find_child("Layer_" + layer, true, false) as Button).button_pressed = true
		(room.console.find_child("Cut", true, false) as HSlider).value = 0.45
		room.console._set_view("side")
		await _frames(30)
		await _save(out, "holo_cut")
		var tv: Node = room.tvs["tv_left_1"]
		await _frames(5)
		var img: Image = tv.viewport.get_texture().get_image()
		img.save_png(out.path_join("tv_plan.png"))
		print("DesignCapture: ", out.path_join("tv_plan.png"))
		get_tree().quit()

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw

	func _save(out: String, id: String) -> void:
		var path := out.path_join(id + ".png")
		get_viewport().get_texture().get_image().save_png(path)
		print("DesignCapture: ", path)
