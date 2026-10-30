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
var _frames: Array[float] = []   # msec of each frame, wall clock
var _proc: Array[float] = []
var _phys: Array[float] = []
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
	net.event_applied.connect(func(n: String, _p: Dictionary) -> void: _events[n] = int(_events.get(n, 0)) + 1)
	_last_us = Time.get_ticks_usec()
	_phase = "play"
	var stamp := Time.get_ticks_msec()
	while Time.get_ticks_msec() - stamp < secs * 1000.0:
		await get_tree().process_frame
	_report()
	get_tree().quit()


func _process(_delta: float) -> void:
	if _phase != "play":
		return
	var now := Time.get_ticks_usec()
	_frames.append((now - _last_us) / 1000.0)
	_last_us = now
	_proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)


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
		print("PERF process ms p50 %.1f p95 %.1f max %.1f; physics ms p50 %.1f p95 %.1f max %.1f" % [p[n / 2], p[int(n * 0.95)], p[n - 1], q[n / 2], q[int(n * 0.95)], q[n - 1]])
