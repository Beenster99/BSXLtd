extends Node
## Plays the game for a while and prints how long its frames took, for a performance pass.
## Runs through the test runner, so the autoloads and modules load as in the game:
##   godot --headless --path . res://modules/core/api/testing/test_runner.tscn -- \
##       --test=res://tools/perf/play_profile.gd --role=solo|host|guest [--secs=40] [--port=24611]
## A host starts the yard and hosts; a guest joins 127.0.0.1 from the lobby's path and then
## goes to the yard, as the Play Together screen does. Headless runs measure scripts and
## physics, not drawing. Not a test.

var role := "solo"
var secs := 40.0
var port := 24611
## --wreck=vsw:patience puts that wreck in the bay and stands the worker in its middle;
## --wreck=none stands the worker there with the bay empty.
var wreck := ""
var _frames: Array[float] = []   # msec of each frame, wall clock
var _proc: Array[float] = []
var _phys: Array[float] = []
var _draws: Array[float] = []
var _shadow_draws: Array[float] = []
var _objs: Array[float] = []
var _prims: Array[float] = []
var _last_us := 0
var _t := 0.0
var _phase := "boot"
var _phase_at := 0
var _events := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.get_slice("=", 1)
		elif arg.begins_with("--secs="): secs = float(arg.get_slice("=", 1))
		elif arg.begins_with("--port="): port = int(arg.get_slice("=", 1))
		elif arg.begins_with("--wreck="): wreck = arg.get_slice("=", 1)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred()


func _run() -> void:
	if not Modules.ready_done:
		await Modules.modules_ready
	var net: Node = Modules.bus("multiplayer")
	Settings.set_value("multiplayer", "player_name", role)
	var t0 := Time.get_ticks_msec()
	if role == "guest":
		Saves.close_game()
		net.join("127.0.0.1", port)
		while not (net.is_online() and not net.is_host()):
			await get_tree().process_frame
			if Time.get_ticks_msec() - t0 > 30000:
				print("PERF guest could not join"); get_tree().quit(1); return
		print("PERF joined after %d ms" % (Time.get_ticks_msec() - t0))
	else:
		Saves.new_game("Perf yard")
	var start: Dictionary = Menu.start()
	var ts := Time.get_ticks_usec()
	Router.goto(start.scene, start.args)
	await get_tree().process_frame
	await get_tree().process_frame
	print("PERF scene change took %d ms" % ((Time.get_ticks_usec() - ts) / 1000))
	if role == "host":
		net.host(port)
	if wreck != "":
		await _into_wreck()
	net.event_applied.connect(func(n: String, _p: Dictionary) -> void: _events[n] = int(_events.get(n, 0)) + 1)
	_last_us = Time.get_ticks_usec()
	_phase = "play"
	var stamp := Time.get_ticks_msec()
	while Time.get_ticks_msec() - stamp < secs * 1000.0:
		await get_tree().process_frame
	_report()
	get_tree().quit()


func _into_wreck() -> void:
	var bus: Node = Modules.bus("ship_bay")
	var tw := Time.get_ticks_usec()
	if wreck != "none":
		bus.call("debug_ship", "named_wreck", wreck)
	for i in 3:
		await get_tree().process_frame
	print("PERF wreck %s built in %d ms, nodes %d" % [wreck, (Time.get_ticks_usec() - tw) / 1000, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	var rig: Node = get_tree().current_scene.get_node_or_null("ToolsRig")
	var ship: Node3D = get_tree().current_scene.find_child("Wreck", true, false)
	if rig and wreck == "none":
		(rig.get("worker") as Node3D).global_position = Vector3(0, 3, 0)
		ship = Node3D.new()
		add_child(ship)
	if rig and (ship or wreck == "none"):
		var worker: Node3D = rig.get("worker")
		var box := AABB()
		var first := true
		for m: Node in ship.find_children("*", "MeshInstance3D", true, false):
			var b := (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
			box = b if first else box.merge(b)
			first = false
		if not first:
			worker.global_position = box.get_center() - Vector3(0, 1.0, 0)
		var counts := {}
		for n: Node in ship.find_children("*", "", true, false):
			counts[n.get_class()] = int(counts.get(n.get_class(), 0)) + 1
		var mm := 0
		for n: Node in ship.find_children("*", "MultiMeshInstance3D", true, false):
			mm += (n as MultiMeshInstance3D).multimesh.instance_count if (n as MultiMeshInstance3D).multimesh else 0
		var lights := get_tree().current_scene.find_children("*", "Light3D", true, false)
		var shadowed := lights.filter(func(l: Light3D) -> bool: return l.shadow_enabled and l.visible)
		for l: Light3D in shadowed:
			var extra := ""
			if l is OmniLight3D:
				extra = "omni range %.0f mode %d" % [(l as OmniLight3D).omni_range, (l as OmniLight3D).omni_shadow_mode]
			elif l is SpotLight3D:
				extra = "spot range %.0f" % (l as SpotLight3D).spot_range
			elif l is DirectionalLight3D:
				extra = "sun splits %d max %.0f" % [(l as DirectionalLight3D).directional_shadow_mode, (l as DirectionalLight3D).directional_shadow_max_distance]
			print("PERF shadowed light %s %s" % [l.get_path(), extra])
		print("PERF wreck nodes %s, multimesh instances %d, scene lights %d (%d shadowed)" % [counts, mm, lights.size(), shadowed.size()])
		print("PERF worker inside at %s (wreck box %s)" % [worker.global_position, box.size])
	for i in 60:
		await get_tree().process_frame


func _process(_delta: float) -> void:
	if _phase != "play":
		return
	var now := Time.get_ticks_usec()
	_frames.append((now - _last_us) / 1000.0)
	_last_us = now
	_proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	var vp := get_viewport().get_viewport_rid()
	_shadow_draws.append(RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_objs.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	_prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))


func _report() -> void:
	var n := _frames.size()
	print("PERF events ", _events)
	print("PERF %s frames %d nodes %d" % [role, n, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	# Per 2 s window: mean and worst frame.
	var w := 0
	var acc := 0.0
	var worst := 0.0
	var cnt := 0
	var line := ""
	var elapsed := 0.0
	for i in n:
		acc += _frames[i]; cnt += 1; worst = maxf(worst, _frames[i]); elapsed += _frames[i]
		if elapsed >= 2000.0 or i == n - 1:
			line += "[%d: %.1f/%.0f] " % [w, acc / cnt, worst]
			w += 1; acc = 0.0; cnt = 0; worst = 0.0; elapsed = 0.0
	print("PERF windows mean/worst ms: ", line)
	var s := _frames.duplicate(); s.sort()
	if n > 0:
		print("PERF frame ms p50 %.1f p95 %.1f p99 %.1f max %.1f" % [s[n / 2], s[int(n * 0.95)], s[int(n * 0.99)], s[n - 1]])
	var p := _proc.duplicate(); p.sort()
	var q := _phys.duplicate(); q.sort()
	if n > 0:
		var dc := _draws.duplicate(); dc.sort()
		var ob := _objs.duplicate(); ob.sort()
		var pr := _prims.duplicate(); pr.sort()
		var sd := _shadow_draws.duplicate(); sd.sort()
		print("PERF render p50: draw calls %d (shadows %d), objects %d, primitives %d" % [dc[n / 2], sd[n / 2], ob[n / 2], pr[n / 2]])
		print("PERF process ms p50 %.1f p95 %.1f max %.1f; physics ms p50 %.1f p95 %.1f max %.1f" % [p[n / 2], p[int(n * 0.95)], p[n - 1], q[n / 2], q[int(n * 0.95)], q[n - 1]])
