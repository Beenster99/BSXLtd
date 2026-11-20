extends Node
## Close-up studio shots of TartanCo's worker androids (YardWorkerLook), one of each trade at
## work, for the worker androids' screenshots page. Not part of the game.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 \
##       res://modules/yard/tools/worker_capture.tscn -- --out=/abs/dir

const WorkerLook := preload("res://modules/yard/internal/yard_worker_look.gd")
const Traffic := preload("res://modules/yard/internal/stores_traffic.gd")
const Workers := preload("res://modules/yard/internal/yard_workers.gd")
const BerthDock := preload("res://modules/yard/internal/dock.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://worker_shots"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	get_tree().root.content_scale_size = Vector2i(1600, 900)
	get_tree().root.size = Vector2i(1600, 900)
	var root := Node3D.new()
	get_tree().root.add_child(root)
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.055, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.65)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -40, 0)
	sun.light_energy = 1.3
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 140, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.6, 0.75, 1.0)
	root.add_child(fill)
	if OS.get_cmdline_user_args().has("--berth"):
		await _berth(root, e, out)
		get_tree().quit()
		return
	var bots: Array[Node3D] = []
	var roles: Array = WorkerLook.ROLES.keys().filter(func(r: String) -> bool: return r != "E")
	for i in roles.size():
		var bot := WorkerLook.make(roles[i], "01")
		root.add_child(bot)
		bot.position = Vector3((i - (roles.size() - 1) * 0.5) * 2.3, 0, 0)
		bot.rotation.y = PI - 0.45
		bots.append(bot)
	var cam := Camera3D.new()
	cam.environment = e
	cam.fov = 40
	root.add_child(cam)
	await get_tree().process_frame
	for bot in bots:
		_pose(bot)
	for shot: Array in [["androids_line_up", Vector3(0, 0.8, 8.2), Vector3(0, 0.0, 0)],
			["androids_close", Vector3(-1.6, 1.5, 3.6), Vector3(-2.3, 0.4, 0)], ["androids_back", Vector3(2.5, 1.8, -3.6), Vector3(1.2, 0.5, 0)]]:
		cam.position = shot[1]
		cam.look_at(shot[2])
		for k in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(out.path_join(String(shot[0]) + ".png"))
	get_tree().quit()


## Each trade's working pose: arms out to an imagined beam in front of it.
func _pose(bot: Node3D) -> void:
	var role: String = bot.get_meta("role")
	var front := -bot.global_basis.z
	var work := bot.global_position + front * 1.35 + Vector3(0, 0.45, 0)
	var side := bot.global_basis.x
	match role:
		"F":
			WorkerLook.reach(bot, "R", work + side * 0.45, front)
			WorkerLook.reach(bot, "L", work - side * 0.45, front)
		_:
			WorkerLook.reach(bot, "R", work + side * 0.15, front)
			WorkerLook.reach(bot, "L", work - side * 0.5, front)
	WorkerLook.lay_hose(bot)
	WorkerLook.aim_laser(bot, work if role == "F" else null)
	if role == "W" or role == "B":
		WorkerLook.stand(bot)
	else:
		WorkerLook.tuck(bot, "R", 0.4)
		WorkerLook.tuck(bot, "L", -0.4)


## The crew at work on the keel (no station round them): a shot of each trade as it works, the
## camera over its shoulder.
func _berth(root: Node3D, env: Environment, out: String) -> void:
	var store := YardRackStore.new()
	store.fill_demo(0.6)
	var traffic := Traffic.new()
	traffic.set_process(false)
	root.add_child(traffic)
	traffic.build(store)
	# The berths' frames, so the docks are seen on their ribs.
	var berths: Node3D = BerthDock.new()
	root.add_child(berths)
	berths.call("build")
	var crew: Node3D = Workers.new()
	crew.set_process(false)
	root.add_child(crew)
	crew.build(traffic)
	crew.wear_per_job = 0.0
	var cam := Camera3D.new()
	cam.environment = env
	cam.fov = 50
	root.add_child(cam)
	var want := {"weld": "arc", "seam": "arc", "rivet": "press", "bolt": "run", "pipe": "run", "fit": "fit", "fitout": "fit"}
	var got := {}
	var t := 0.0
	while got.size() < want.size() and t < 3000.0:
		traffic.step(0.1)
		crew.step(0.1)
		t += 0.1
		for w: Dictionary in crew.workers:
			var task: Dictionary = w.task
			if task.is_empty():
				continue
			var key: String = task.kind
			if key == "fit" and (task.member as Dictionary).has("load"):
				key = "fitout"
			# TartanCo's joining rule at work: a hull plate's short seam, a pipe's clamp bolts.
			if key == "weld" and task.member.part == "HullPlate":
				key = "seam"
			if key == "bolt" and task.member.part == "Pipe":
				key = "pipe"
			if got.has(key) or task.phase != want[key]:
				continue
			if key in ["weld", "bolt"] and float(task.t) < 0.5:
				continue
			if key == "rivet" and not task.has("fired"):
				continue
			if key.begins_with("fit") and float(task.t) < 0.6:
				continue
			got[key] = true
			var node: Node3D = w.node
			var b := node.global_basis
			var far := 4.5 if key.begins_with("fit") else 3.2
			cam.global_position = node.global_position + b.x * far * 0.75 - b.z * far * 0.75 + b.y * 0.9
			cam.look_at(node.global_position - b.z * 0.7 - b.y * 0.3, b.y)
			if key in ["rivet", "weld", "seam"]:
				# Close on the tool's tip, from beside the bot, so the spray fills the frame.
				var tip := WorkerLook.tip_of(node, "R")
				cam.global_position = tip + b.x * 1.6 + b.y * 0.6 - b.z * 0.6
				cam.look_at(tip, b.y)
				if key == "rivet" and not (task.spots as Array).is_empty():
					# Off the plate's face, past the bot's shoulder, onto the rivet as it goes home.
					var spot: Dictionary = task.spots[0]
					var o: Vector3 = spot.out
					cam.global_position = (spot.face as Vector3) + o * 1.3 + (spot.along as Vector3) * 0.9 - b.x * 0.4
					cam.look_at(spot.face, o.cross(spot.along).normalized())
			# Let the frame catch up, the crew working on for a moment so the spray is flying.
			for k in 14:
				crew.step(1.0 / 60.0)
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_tree().root.get_texture().get_image().save_png(out.path_join("berth_%s.png" % key))
			print("shot ", key, " at ", t)
	# The whole keel from off its front.
	cam.global_position = crew.KEEL_START + Vector3(crew.KEEL_STEP * crew.rings.size() + 9.0, 7.0, 10.0)
	cam.look_at(crew.KEEL_START + Vector3(crew.KEEL_STEP * crew.rings.size() - 2.0, 2.5, 0))
	for k in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(out.path_join("berth_keel.png"))
	# A corner of a finished ring up close: the box girders mitred into each other, the stringers
	# butted onto them (no knuckles).
	var ring: Node3D = crew.rings[1]
	var corner := ring.global_position + Vector3(0, 0, -crew.RING * 0.5)
	cam.global_position = corner + Vector3(1.6, -1.2, -1.8)
	cam.look_at(corner + Vector3(-0.6, 0.3, 0.2))
	for k in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(out.path_join("berth_corner.png"))
	# A weld bead close up: the stacked ripples the player's welder lays.
	for r: Node3D in crew.rings:
		var beads := r.get_node_or_null("Beads") as MultiMeshInstance3D
		if beads == null or beads.multimesh.visible_instance_count < 60:
			continue
		var t0 := r.global_transform * beads.multimesh.get_instance_transform(0)
		var t1 := r.global_transform * beads.multimesh.get_instance_transform(40)
		var mid := (t0.origin + t1.origin) * 0.5
		var up := t0.basis.z.normalized()
		var run := (t1.origin - t0.origin).normalized()
		cam.global_position = mid + up * 0.22 + run.cross(up) * 0.12 - run * 0.08
		cam.look_at(mid, run)
		for k in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(out.path_join("berth_bead.png"))
		break
	# The charging docks in the berth's frame: four bots back on their docks, charging slowly so
	# they are all still there for the shot.
	crew.charge_seconds = 10000.0
	for i in [0, 2, 3, 5]:
		var w: Dictionary = crew.workers[i]
		crew._drop_task(w)
		w.charge = 0.05
	var settled := 0.0
	while settled < 60.0:
		traffic.step(0.1)
		crew.step(0.1)
		settled += 0.1
		if [0, 2, 3, 5].all(func(i: int) -> bool: return crew._docked(crew.workers[i])):
			break
	for k in [0, 2, 3, 5]:
		crew.workers[k].charge = 0.2 + 0.15 * k
	for k in 30:
		crew.step(0.1)
	for shot: Array in [["charging_frame", Vector3(2.0, -3.0, -90.0), Vector3(0, -6.0, -70.0)],
			["charging_close", Vector3(-6.8, -11.6, -75.2), Vector3(-10.0, -13.4, -70.5)]]:
		cam.global_position = shot[1]
		cam.look_at(shot[2])
		for k in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(out.path_join("berth_%s.png" % shot[0]))
