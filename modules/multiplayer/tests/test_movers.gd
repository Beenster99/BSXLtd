extends ModuleTest
## Holds and movers between two sessions over ENet on localhost: the host drives an
## unclaimed trolley, a client takes over by claiming it, a client's tractor-beam hold is
## what the host's fastening check sees, and a leaver's hold ends. Plus the interpolation.
##   tools/run_tests.sh multiplayer

const PORT := 24598


func run_tests() -> void:
	_check_sampling()

	var a := _make("Host", "Ana")
	var b := _make("Client", "Ben")
	var a_trolley := _node(a, Vector3(1, 0, 0))
	var b_trolley := _node(b, Vector3.ZERO)
	var a_unit := _node(a, Vector3.ZERO)
	var b_unit := _node(b, Vector3.ZERO)
	a.register_mover("trolley:large_1", a_trolley)
	b.register_mover("trolley:large_1", b_trolley)
	check(a.host(PORT, 3) == OK, "host starts")
	b.join("127.0.0.1", PORT)
	check(await _until(func(): return b.state == NetSession.State.JOINED), "client joins")
	check(b_trolley.position.is_equal_approx(Vector3(1, 0, 0)), "join snapshot places movers")

	# Unclaimed: the host drives (automated routing runs there), the client follows.
	a_trolley.position = Vector3(5, 2, 0)
	check(await _until(func(): return b_trolley.position.distance_to(Vector3(5, 2, 0)) < 0.01), "client follows the host's trolley")
	b_trolley.position = Vector3(-9, 0, 0)  # A client can't drive what it doesn't hold.
	await frames(10)
	check(a_trolley.position.is_equal_approx(Vector3(5, 2, 0)), "host ignores an undriven client copy")

	# Remote control: the client claims the trolley and drives it.
	b.claim("trolley:large_1")
	check(await _until(func(): return a.mover_authority("trolley:large_1") == b.local_peer_id()), "claim hands over driving")
	b_trolley.position = Vector3(3, 4, 5)
	check(await _until(func(): return a_trolley.position.distance_to(Vector3(3, 4, 5)) < 0.01), "host follows the client's trolley")

	# Tractor beam: Ben lifts the unit and lines it up; Ana's fastening is checked on the host.
	a.register_mover("unit:pump", a_unit)
	b.register_mover("unit:pump", b_unit)
	var fastened: Array[String] = []
	var refused: Array[String] = []
	for s in [a, b]:
		s.register_event("test.rivet", func(p): fastened.append(p.unit),
				func(_sender, p): return p if a.is_hold_ready(p.unit) else "not held in line")
	a.request_rejected.connect(func(_n, why): refused.append(why))
	b.set_hold("unit:pump", false, false, "slot:engine_1")
	check(await _until(func(): return not a.hold_info("unit:pump").is_empty()), "host sees the hold")
	a.request("test.rivet", {"unit": "unit:pump"})
	check(refused == ["not held in line"] and fastened.is_empty(), "no rivet while out of line")
	b_unit.position = Vector3(0, 3, 0)
	b.set_hold("unit:pump", true, false, "slot:engine_1")
	check(await _until(func(): return a.is_hold_ready("unit:pump")), "aligned hold reaches the host")
	check(await _until(func(): return a_unit.position.distance_to(Vector3(0, 3, 0)) < 0.01), "held unit moves on the host")
	a.claim("unit:pump")
	await frames(10)
	check(refused.size() == 2 and refused[1] == "held by Ben", "can't take a unit out of someone's beam")
	a.request("test.rivet", {"unit": "unit:pump"})
	check(await _until(func(): return fastened.size() == 2), "first rivet counts once aligned, on both peers")

	var a_holds: Array[String] = []
	a.hold_changed.connect(func(id, info): if info.is_empty(): a_holds.append(id))
	b.leave()
	check(await _until(func(): return a_holds.has("unit:pump")), "leaver's hold ends")
	check(a.mover_authority("trolley:large_1") == 1, "host drives the trolley again")
	a.leave()


func _check_sampling() -> void:
	var list := [[1.0, Transform3D(Basis(), Vector3.ZERO)], [2.0, Transform3D(Basis(), Vector3(10, 0, 0))]]
	check(NetMovers.sample_at(list, 1.5).origin.is_equal_approx(Vector3(5, 0, 0)), "halfway between samples")
	check(NetMovers.sample_at(list, 0.0).origin.is_equal_approx(Vector3.ZERO), "held before the first sample")
	check(NetMovers.sample_at(list, 9.0).origin.is_equal_approx(Vector3(10, 0, 0)), "held after the last sample")


func _make(node_name: String, player: String) -> NetSession:
	var s := NetSession.new()
	s.name = node_name
	s.profile = {"name": player}
	s.compat = {"game_version": "test", "modules": {}}
	add_child(s)
	return s


func _node(parent: Node, at: Vector3) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = at
	return n


func _until(cond: Callable, timeout := 5.0) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()
