extends ModuleTest
## The yard's shared clock (co-op sync, 19 Nov): a yard replayed from the same log to the same
## tick is the same yard (where every mover bot, hauler and worker is, what each is doing, the
## airlock), so a friend who joins later sees what the host sees; what players do (a kit, the
## airlock, a contract) goes through the log; the host stamps it ahead for the trip out.
##   tools/run_tests.sh yard

const TICKS := 3600   # a minute of the yard
const PORT := 24617


func run_tests() -> void:
	for f: String in [YardBus.FLAG, YardBus.STATION, YardBus.DOCK, YardBus.RACKING]:
		Flags.set_flag(f, true)
	var bus := Modules.bus("yard") as YardBus
	if bus == null:
		bus = YardBus.new()
		bus.name = "yard"
		Modules.add_child(bus)
		bus.register_module()
	# The host's yard: a kit called, the airlock cycled out, a contract started, a minute run.
	var a := _open()
	check(bus.sim_epoch >= 0.0, "opening the yard starts its clock")
	a.call("call_kit")
	(a.get("airlock") as Node).call("use", "out")
	a.call("ask_demo_contract")
	check(bus.sim_log.size() == 3, "a kit, the airlock and a contract are logged (%d)" % bus.sim_log.size())
	check(int((a.get("airlock") as Node).get("state")) == 0, "the airlock waits for its tick")
	var sim: Node = a.get("sim")
	var t0 := Time.get_ticks_usec()
	sim.call("run_ticks", TICKS)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / TICKS
	print("  a yard tick: %.3f ms" % ms)
	check(ms < 2.0, "a tick is cheap enough to catch up a late joiner (%.3f ms)" % ms)
	check(int((a.get("airlock") as Node).get("state")) == 1, "the airlock cycled out at its tick")
	check((a.get("traffic").get("kit_orders") as Array).size() >= 1, "the kit's mover set off")
	var host := _state(a)
	var log := bus.sim_log.duplicate(true)
	a.queue_free()
	await frames(2)
	# A friend's yard, opened later: replays the host's log from tick 0 to the same tick.
	var b := _open()
	bus.sim_log.assign(log)
	(b.get("sim") as Node).call("restart")
	(b.get("sim") as Node).call("run_ticks", TICKS)
	var friend := _state(b)
	check(host == friend, "the friend's yard is the host's, tick for tick%s" % _diff(host, friend))
	b.queue_free()
	await frames(2)
	# The host stamps what a player does half a second ahead (when online) for the trip out.
	bus.sim_epoch = Time.get_ticks_usec() / 1_000_000.0 - 10.0
	var stamped: Variant = bus._sim_validate(2, {"kind": "kit", "kit": "keel_ring"})
	check(stamped is Dictionary and int(stamped.peer) == 2 and int(stamped.tick) >= 590, "the host stamps the sender and the tick")
	await _online()


## Two players over ENet: the friend gets the host's clock when joining and agrees on the tick;
## what the friend does is logged on both at the same tick, half a second ahead.
func _online() -> void:
	if not ClassDB.class_exists("ENetMultiplayerPeer"):
		return
	var saved := Flags.all()
	Flags.set_flag("multiplayer", true)
	Flags.set_flag("multiplayer.online", true)
	var a := _net_bus("SimNetA", "Ana")
	var b := _net_bus("SimNetB", "Ben")
	var ya := YardBus.new()
	var yb := YardBus.new()
	ya.use_net(a)
	yb.use_net(b)
	var host_yard := Node3D.new()   # the host's own station stands open
	ya.set("_station", host_yard)
	check(a.call("host", PORT) == OK, "host starts")
	ya.sim_start()
	check(ya.sim_epoch >= 0.0, "the host's yard clock starts")
	b.call("join", "127.0.0.1", PORT)
	check(await _until(func(): return yb.sim_target_tick() >= 0), "the friend gets the host's clock")
	check(is_equal_approx(ya.sim_epoch, yb.sim_epoch), "the same tick 0")
	check(absi(ya.sim_target_tick() - yb.sim_target_tick()) <= 6, "and the same tick now, near enough (%d, %d)" % [ya.sim_target_tick(), yb.sim_target_tick()])
	yb.sim_start()   # the friend opens the yard while the host is in it: the host's clock stands
	await _until(func(): return false, 0.3)
	check(is_equal_approx(ya.sim_epoch, yb.sim_epoch), "the friend opening the yard keeps the host's clock")
	var now := yb.sim_target_tick()
	yb.sim_request({"kind": "lock", "lock": "airlock", "mode": "out"})
	check(await _until(func(): return ya.sim_log.size() == 1 and yb.sim_log.size() == 1), "the friend's airlock press is logged on both")
	if ya.sim_log.size() == 1 and yb.sim_log.size() == 1:
		check(ya.sim_log[0] == yb.sim_log[0], "at the same tick, the same entry")
		check(int(yb.sim_log[0].tick) >= now + YardBus.SIM_LEAD - 6, "stamped ahead for the trip out")
		check(int(yb.sim_log[0].peer) == int(b.call("local_peer_id")), "as the friend's")
	b.call("leave")
	await _until(func(): return (a.call("peers") as Dictionary).size() == 1)
	a.call("leave")
	await frames(2)
	a.call("unregister_module")
	b.call("unregister_module")
	a.queue_free()
	b.queue_free()
	ya.free()
	yb.free()
	host_yard.free()
	Flags.use(saved)


func _net_bus(node_name: String, player: String) -> Node:
	var bus: Node = (load("res://modules/multiplayer/api/multiplayer_bus.gd") as GDScript).new()
	bus.name = node_name
	add_child(bus)
	bus.call("register_module")
	Settings.set_value("multiplayer", "player_name", player)
	bus.call("_refresh_identity")
	return bus


func _until(cond: Callable, timeout := 5.0) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _open() -> Node3D:
	var s := (load(YardBus.SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child(s)
	(s.get("sim") as Node).set_process(false)
	return s


## Where everything that moves is and what it is doing, rounded to the millimetre.
func _state(s: Node3D) -> Array[String]:
	var out: Array[String] = []
	var traffic: Node = s.get("traffic")
	for b: Dictionary in traffic.get("bots"):
		out.append("bot %s %s" % [_at(b.node), str((b.job as Array).size())])
	for h: Dictionary in traffic.get("haulers"):
		out.append("hauler %s %s" % [_at(h.get("node")), str(h.get("state", ""))])
	for l: Dictionary in traffic.get("loads"):
		out.append("load %s %s" % [str(l.get("where", "")), _at(l.get("node"))])
	var workers: Node = s.get("workers")
	if workers:
		for w: Dictionary in workers.get("workers"):
			out.append("worker %s %s" % [_at(w.get("node")), str(w.get("task", {}).get("kind", "")) if w.get("task") is Dictionary else ""])
		out.append("rings %d" % int(workers.call("rings_built")))
	out.append("airlock %d" % int((s.get("airlock") as Node).get("state")))
	return out


func _at(n: Variant) -> String:
	if not (n is Node3D) or not is_instance_valid(n):
		return "-"
	var p := (n as Node3D).global_position
	return "(%.3f %.3f %.3f)" % [p.x, p.y, p.z]


func _diff(x: Array[String], y: Array[String]) -> String:
	if x.size() != y.size():
		return " (%d against %d things)" % [x.size(), y.size()]
	for i in x.size():
		if x[i] != y[i]:
			return " (first difference: %s against %s)" % [x[i], y[i]]
	return ""
