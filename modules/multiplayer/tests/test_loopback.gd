extends ModuleTest
## Two sessions in one process over ENet on localhost: handshake, join snapshot, request
## from a client applied everywhere in host order, claim conflicts, the shared clock,
## version refusal, a peer leaving and the host leaving.
##   tools/run_tests.sh multiplayer

const PORT := 24599


class Board:
	## A stand-in module: a list of fastened joints, synced by events and snapshots.
	var joints: Array = []

	func get_net_snapshot() -> Dictionary:
		return {"joints": joints.duplicate()}

	func apply_net_snapshot(data: Dictionary) -> void:
		joints = data.get("joints", []).duplicate()


func run_tests() -> void:
	var a := _make("Host", "Ana")
	var a_board := _board(a)
	check(a.host(PORT, 3) == OK, "host starts")
	check(a.is_host() and a.is_online(), "host is online host")

	# Work done before anyone joins reaches a late joiner through the snapshot.
	a.request("test.fasten", {"joint_id": "j1"})
	a.claim("bucking_bar")

	var b := _make("Client", "Ben")
	var b_board := _board(b)
	var b_ended: Array[String] = []
	b.session_ended.connect(func(why): b_ended.append(why))
	check(b.join("127.0.0.1", PORT) == OK, "client connects")
	check(await _until(func(): return b.state == NetSession.State.JOINED), "client joins")
	check(b_board.joints == ["j1"], "snapshot brings earlier work: %s" % str(b_board.joints))
	check(b.claim_owner("bucking_bar") == 1, "snapshot brings claims")
	check(b.peers().size() == 2 and a.peers().size() == 2, "both see a crew of two")
	check(str(b.peers()[1].name) == "Ana", "client sees host's name")
	check(b.local_peer_id() != 1, "client has its own peer id")

	# Client request: validated on the host, applied on both in the same order.
	b.request("test.fasten", {"joint_id": "j2"})
	a.request("test.fasten", {"joint_id": "j3"})
	check(await _until(func(): return b_board.joints.size() == 3), "events reach the client")
	check(a_board.joints == b_board.joints, "same order everywhere: %s / %s" % [a_board.joints, b_board.joints])

	var b_rejected: Array[String] = []
	b.request_rejected.connect(func(_n, why): b_rejected.append(why))
	b.request("test.fasten", {"joint_id": ""})
	check(await _until(func(): return b_rejected.size() == 1), "client hears refusals")
	b.claim("bucking_bar")
	check(await _until(func(): return b_rejected.size() == 2), "claim conflict refused")
	check(b_rejected[1] == "held by Ana", "refusal names the holder: %s" % b_rejected[1])
	b.claim("rivet_gun")
	check(await _until(func(): return a.claim_owner("rivet_gun") == b.local_peer_id()), "client claim granted on host")

	check(await _until(func(): return b.round_trip() > 0.0), "client measures round trip")
	check(absf(b.server_time() - a.server_time()) < 0.05, "clocks agree")

	# A client with a different module version is refused with a reason.
	var c := _make("Stale", "Cal")
	c.compat = {"game_version": "test", "modules": {"trades": "0.0.1"}}
	var c_ended: Array[String] = []
	c.session_ended.connect(func(why): c_ended.append(why))
	c.join("127.0.0.1", PORT)
	check(await _until(func(): return c_ended.size() == 1), "stale client sent away")
	check(c_ended[0].contains("trades"), "reason names the module: %s" % str(c_ended))
	check(a.peers().size() == 2, "refused client never joined")

	# Client leaves: host frees what it held.
	var a_left: Array[int] = []
	a.peer_left.connect(func(id, _why): a_left.append(id))
	var b_id := b.local_peer_id()
	b.leave()
	check(await _until(func(): return a_left == [b_id]), "host sees the client leave")
	check(a.claim_owner("rivet_gun") == 0, "leaver's claims released")
	check(b_ended == ["left"], "client session ended: %s" % str(b_ended))

	# Host leaving ends the session for clients.
	var d := _make("Late", "Dee")
	var d_ended: Array[String] = []
	d.session_ended.connect(func(why): d_ended.append(why))
	d.join("127.0.0.1", PORT)
	check(await _until(func(): return d.state == NetSession.State.JOINED), "second client joins")
	a.leave()
	check(await _until(func(): return d_ended.size() == 1), "host leaving ends the client's session")
	check(d_ended == ["The host left"], "reason given: %s" % str(d_ended))
	check(not d.is_online() and d.is_host(), "client back to solo")


func _make(node_name: String, player: String) -> NetSession:
	var s := NetSession.new()
	s.name = node_name
	s.profile = {"name": player}
	s.compat = {"game_version": "test", "modules": {"trades": "0.1.0"}}
	add_child(s)
	return s


func _board(s: NetSession) -> Board:
	var board := Board.new()
	s.register_event("test.fasten", func(p): board.joints.append(p.joint_id),
			func(_sender, p): return p if str(p.get("joint_id", "")) != "" else "no joint")
	s.register_snapshot_provider("test", board)
	return board


func _until(cond: Callable, timeout := 5.0) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()
