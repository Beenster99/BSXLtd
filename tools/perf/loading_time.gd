extends Node
## Goes into the yard the player's way, behind the loading screen, and prints each step it
## shows and how long until you could move. Not a test. A host then waits for a guest:
##   godot --headless --path . res://modules/core/api/testing/test_runner.tscn -- \
##       --test=res://tools/perf/loading_time.gd --role=solo|host|guest
## With a window (xvfb) it also saves a picture of the screen every 1.5 s to --out=<dir>.
var out := "/tmp/loadshots"
var role := "solo"
var port := 24633
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.get_slice("=", 1)
		elif arg.begins_with("--role="): role = arg.get_slice("=", 1)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	if not Modules.ready_done:
		await Modules.modules_ready
	var net: Node = Modules.bus("multiplayer")
	Settings.set_value("multiplayer", "player_name", role)
	if role == "guest":
		Saves.close_game()
		net.join("127.0.0.1", port)
		while not (net.is_online() and not net.is_host()):
			await get_tree().process_frame
	else:
		Saves.new_game("Probe")
	var start: Dictionary = Menu.start()
	var t0 := Time.get_ticks_msec()
	Router.force_loading_screen = true
	Router.goto_loading(start.scene, start.args)
	var shots := 0
	var next := 0
	var last_stage := ""
	await get_tree().process_frame
	while Router.is_loading() and Time.get_ticks_msec() - t0 < 300000:
		await (RenderingServer.frame_post_draw if DisplayServer.get_name() != "headless" else get_tree().process_frame)
		var t := Time.get_ticks_msec() - t0
		var scr: Node = Router.get_node("LoadingScreen")
		var st := "%s" % scr.get("_stage")
		if st != last_stage:
			print("PROBE %d ms: %s (bar %.2f)" % [t, st, float(scr.get("target"))])
			last_stage = st
		if DisplayServer.get_name() != "headless" and t >= next:
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/%s_%02d_%05d.png" % [out, role, shots, t])
			print("PROBE shot %d at %d ms" % [shots, t])
			shots += 1
			next = t + 1500
	print("PROBE %s ready after %d ms" % [role, Time.get_ticks_msec() - t0])
	if role == "host":
		net.host(port)
		await get_tree().create_timer(150).timeout
	for i in 30:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("%s/%s_after.png" % [out, role])
	get_tree().quit()
