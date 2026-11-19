extends Node
## Screenshots of OPERATE and SET HER DOWN for the screenshots page (run under a display):
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . \
##       res://modules/motion/internal/tools/motion_capture.tscn -- --out=/abs/dir
## Builds a small lander (a hold with a crane, a cargo ramp, four legs, a hinged door that
## hits a locker) and saves holo_operate.png, console_operate.png, holo_ground.png,
## wall_moving_parts.png, walk_operate.png and walk_ramp.png.

const SIZE := Vector2i(1920, 1080)

const LANDER := [
	{"op": "add_room", "room": {"id": "r1", "type": "cargo", "deck": 0, "x": -4, "z": -6, "w": 8, "d": 8, "name": "Hold"}},
	{"op": "add_room", "room": {"id": "r2", "type": "bridge", "deck": 0, "x": -2, "z": 2, "w": 4, "d": 4}},
	{"op": "add_room", "room": {"id": "r3", "type": "quarters", "deck": 0, "x": 2, "z": 2, "w": 3, "d": 4}},
	{"op": "add_door", "door": {"id": "d1", "a": "r1", "b": "r2", "deck": 0, "x": 0, "z": 2, "kind": "cargo"}},
	{"op": "add_door", "door": {"id": "d2", "a": "r3", "b": "r2", "deck": 0, "x": 2, "z": 4, "kind": "hinged"}},
	{"op": "add_component", "component": {"id": "c1", "type": "crane_hoist", "room": "r1", "x": 0, "z": -2}},
	{"op": "add_component", "component": {"id": "c2", "type": "locker", "room": "r3", "x": 2.45, "z": 4.0}},
	{"op": "add_component", "component": {"id": "c3", "type": "pilot_console", "room": "r2", "x": 0, "z": 5.4}},
	{"op": "add_mount", "mount": {"id": "m1", "type": "landing_gear", "deck": 0, "x": -4, "z": -5, "angle": PI}},
	{"op": "add_mount", "mount": {"id": "m2", "type": "landing_gear", "deck": 0, "x": 4, "z": -5, "angle": 0.0}},
	{"op": "add_mount", "mount": {"id": "m3", "type": "landing_gear", "deck": 0, "x": -2, "z": 5, "angle": PI}},
	{"op": "add_mount", "mount": {"id": "m4", "type": "landing_gear", "deck": 0, "x": 5, "z": 5, "angle": 0.0}},
	{"op": "add_mount", "mount": {"id": "m5", "type": "cargo_ramp", "deck": 0, "x": -4, "z": -1.5, "angle": PI}},
]


func _ready() -> void:
	var runner := Runner.new()
	runner.name = "MotionCapture"
	get_tree().root.add_child.call_deferred(runner)


class Runner:
	extends Node

	func _ready() -> void:
		_run.call_deferred()

	func _run() -> void:
		var out := "user://motion_shots"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--out="):
				out = arg.trim_prefix("--out=")
		DirAccess.make_dir_recursive_absolute(out)
		DisplayServer.window_set_size(SIZE)
		get_tree().root.size = SIZE
		if not Modules.ready_done:
			await Modules.modules_ready
		var design := Modules.bus("design") as DesignBus
		var motion := Modules.bus("motion") as MotionBus
		design.library.reset_data()
		design.library.create("Lander")
		for op: Dictionary in LANDER:
			design.editor.do(op)
		for p in design.problems():
			print("MotionCapture problem: ", p.text)
		Router.goto("design.room")
		await _frames(30)
		var room: Node = get_tree().current_scene
		# On the holotable, mid-cycle, from the room.
		motion.set_operating(true)
		motion.started_msec = Time.get_ticks_msec() - 5000
		room.call("set_room_view", true)
		await _frames(30)
		await _save(out, "holo_room")
		# Close on the table.
		var table: Node3D = null
		for n in room.find_children("*", "Node3D", true, false):
			if n.has_method("holo_mat"):
				table = n
				break
		var cam := Camera3D.new()
		room.add_child(cam)
		if table:
			cam.global_position = table.global_position + Vector3(0.5, 3.0, 4.2)
			cam.look_at(table.global_position + Vector3(0, 1.3, 0))
		cam.fov = 50.0
		cam.current = true
		await _frames(20)
		await _save(out, "holo_operate")
		motion.started_msec = Time.get_ticks_msec() - 9000
		await _frames(10)
		await _save(out, "holo_operate_2")
		motion.set_operating(false)
		motion.set_grounded(true)
		await _frames(30)
		await _save(out, "holo_ground")
		motion.set_grounded(false)
		motion.set_operating(true)
		cam.current = false
		room.call("set_room_view", false)
		var console: Node = room.get("console")
		if console and console.has_method("_set_view"):
			console.call("_set_view", "side")
		await _frames(30)
		await _save(out, "console_operate")

		# The wall panel on its own.
		var vp := SubViewport.new()
		vp.size = Vector2i(1600, 1100)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var wall := motion.make_wall(150.0)
		wall.size = Vector2(1600, 1100)
		vp.add_child(wall)
		await _frames(10)
		vp.get_texture().get_image().save_png(out.path_join("wall_moving_parts.png"))
		print("MotionCapture: ", out.path_join("wall_moving_parts.png"))
		vp.queue_free()
		motion.set_grounded(false)
		# Walk-inside, outside her, the ramp coming down and her legs out.
		var furnishing: Node = room.get("furnishing")
		furnishing.call("open_walk")
		var walk: Node3D = furnishing.get("walk")
		await _frames(10)
		walk.set_physics_process(false)
		motion.set_operating(true)
		for shot in [["walk_operate", Vector3(-10, 0.3, 8), -0.75, 0.05, 6500],
				["walk_ramp", Vector3(-10, 0.2, 2.5), -PI * 0.5 + 0.35, 0.0, 8500]]:
			motion.started_msec = Time.get_ticks_msec() - int(shot[4])
			var body: Node3D = walk.get("body")
			body.position = shot[1]
			body.rotation.y = shot[2]
			(walk.get("camera") as Camera3D).rotation.x = shot[3]
			await _frames(20)
			await _save(out, shot[0])
		get_tree().quit()

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame

	func _save(out: String, name: String) -> void:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(out.path_join(name + ".png"))
		print("MotionCapture: ", out.path_join(name + ".png"))
