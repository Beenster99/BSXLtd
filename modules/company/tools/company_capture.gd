extends Node
## Pictures of Wave 8 for the thread's screenshots page: THE COMPANY's pages (rank, clients,
## crew, launch, the trophy shelf) and the launch send-off (no station: quick).
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \
##       res://modules/company/tools/company_capture.tscn -- --out=/abs/dir


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://company_shots"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var size := Vector2i(1600, 1000)
	DisplayServer.window_set_size(size)
	get_tree().root.size = size
	if not Modules.ready_done:
		await Modules.modules_ready
	for f: String in [BuildBus.FLAG, BuildBus.HAND_FLAG, CompanyBus.FLAG, CompanyBus.GROWTH_FLAG, CompanyBus.RIVALS_FLAG,
			CompanyBus.LAUNCH_FLAG]:
		Flags.set_flag(f, true)
	Flags.set_flag("orders.gate", false)
	var build := Modules.bus("build") as BuildBus
	var co := Modules.bus("company") as CompanyBus
	co.reset_data()
	for id: String in build.builds.keys():
		build.stop(id)
	# A freighter built through to the end, by hand at a good quality.
	var rec := DesignRecord.new()
	rec.name = "Hesper freighter"
	DesignBus.Samples.freighter(rec, DesignCatalog.load_default())
	build.start("shot_ship", rec.to_dict(), rec.name)
	await get_tree().process_frame
	var pl := build.plan("shot_ship")
	for i in pl.jobs.size() * 2:
		var j := build.next_job("shot_ship")
		if j < 0:
			break
		build.land_next()
		for k in (pl.jobs[j].key as Array).size():
			build.fasten(j, k, 0.82 + 0.15 * float((j * 7 + k) % 5) / 4.0, "shot_ship")
	var side := co.side_of("shot_ship")
	print("landed ", (build.builds.shot_ship.landed as Array).size(), " of ", pl.jobs.size(), "; miniature ", side.size())
	var me := co.me()
	co.record.append({"cid": "a", "name": "Little Auk", "design": "Skiff", "client": "Halvard Survey", "day": 4, "quality": 0.78,
			"price": 1_450_000, "crew": [me], "jobs": 22, "workmanship": 0.81, "side": _skiff()})
	co.record.append({"cid": "b", "name": "Brave Tern", "design": "Hesper freighter", "client": "Corvane Freight", "day": 11,
			"quality": 0.91, "price": 7_800_000, "crew": [me, "Dan"], "jobs": pl.jobs.size(), "workmanship": 0.9, "side": side})
	co.names["shot_ship"] = "Lady of the Dock"
	# Contract papers: a design signed with its quote, the keel's gate signed, the fit-out's waiting.
	var contracts := Modules.bus("contracts") as ContractsBus
	Flags.set_flag(ContractsBus.SIGNATURES_FLAG, true)
	Flags.set_flag(CompanyBus.GROWTH_FLAG, false)
	for o: Dictionary in contracts.ship_orders():
		if contracts.ship_sign_problem(o) == "":
			contracts.request_sign_ship(o, "d1", "Hesper freighter", int(float(o.budget) * 0.6), me)
			var c := contracts.ship_contract_for(str(o.id))
			contracts.request_ship_stage(str(c.id), "keel")
			contracts.request_sign_gate(str(c.id), "keel", "Dan")
			contracts.request_ship_stage(str(c.id), "fit_out")
			break
	Flags.set_flag(CompanyBus.GROWTH_FLAG, true)
	co.set_role(me, "foreman")
	co.changed.emit()
	var back := ColorRect.new()
	back.color = Color(0.03, 0.04, 0.06)
	back.size = Vector2(size)
	add_child(back)
	for p: String in ["RANK", "CLIENTS", "CREW", "LAUNCH", "SHELF", "PAPERS"]:
		var screen: Control = co.make_screen(150.0, p)
		screen.size = Vector2(size) - Vector2(80, 80)
		screen.position = Vector2(40, 40)
		back.add_child(screen)
		await _save(out, "company_" + p.to_lower(), 4)
		screen.queue_free()
	back.queue_free()

	# The send-off, in open space.
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.01, 0.012, 0.02)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.4, 0.5)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_energy = 1.3
	add_child(sun)
	var stage := Node3D.new()
	add_child(stage)
	var launch: Node3D = CompanyBus.Launch.new()
	stage.add_child(launch)
	launch.call("setup", build.ship_view("shot_ship"), "Lady of the Dock")
	var half: float = launch.get("_half")
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 2000.0
	add_child(cam)
	cam.current = true
	launch.set_process(false)
	cam.global_position = Vector3(-14, 6, -half - 14)
	cam.look_at(Vector3(0, 1, -half))
	launch.call("jump_to", 3.2)
	await _save(out, "launch_bottle", 3)
	launch.call("jump_to", 4.15)
	await _save(out, "launch_smash", 2)
	cam.global_position = Vector3(half * 1.6, half * 0.5, half * 0.9)
	cam.look_at(Vector3(0, 0, 0))
	launch.call("jump_to", 11.5)
	await _save(out, "launch_engines", 3)
	cam.global_position = Vector3(half * 1.3, half * 0.45, half * 1.6)
	cam.look_at(Vector3(0, 0, -half * 1.2))
	launch.call("jump_to", 18.0)
	await _save(out, "launch_away", 3)
	get_tree().quit()


## A small ship's outline for the shelf (z, y, w, h: m).
func _skiff() -> Array:
	var out: Array = []
	for i in 14:
		var z := -7.0 + i
		var h := 2.4 - absf(z) * 0.18
		out.append([z, -h * 0.5, 0.95, h])
	out.append([-2.0, -2.0, 3.0, 0.6])
	return out


func _save(out: String, id: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out, id]
	get_viewport().get_texture().get_image().save_png(path)
	print("captured ", path)
