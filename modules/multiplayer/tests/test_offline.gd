extends ModuleTest
## Solo play: the bus is loaded, the local player is host, requests apply at once, refusals
## come back as request_rejected, claims and holds work, and hosting waits for the online flag.
##   tools/run_tests.sh multiplayer

var applied: Array[Dictionary] = []
var rejected: Array[String] = []


func run_tests() -> void:
	var net := Modules.bus("multiplayer") as MultiplayerBus
	check(net != null, "multiplayer bus loaded")
	if net == null:
		return
	check(not net.is_online(), "starts offline")
	check(net.is_host(), "solo player is the host")
	check(net.local_peer_id() == 1, "solo player is peer 1")
	check(net.peers().size() == 1, "a crew of one")

	net.request_rejected.connect(func(n, why): rejected.append("%s: %s" % [n, why]))
	net.register_event("test.fasten", func(p): applied.append(p),
			func(_sender, p): return p if p.get("torque", 0.0) > 10.0 else "too loose")
	net.request("test.fasten", {"joint_id": "j1", "torque": 40.0})
	check(applied.size() == 1 and applied[0].joint_id == "j1", "request applies immediately offline")
	net.request("test.fasten", {"joint_id": "j2", "torque": 2.0})
	check(applied.size() == 1, "refused request not applied")
	check(rejected == ["test.fasten: too loose"], "refusal reported: %s" % str(rejected))
	net.request("test.nothing", {})
	check(rejected.size() == 2, "unknown event refused")

	net.register_event("test.delivery", func(p): applied.append(p))
	net.host_emit("test.delivery", {"crate": 7})
	check(applied.back().get("crate") == 7, "host_emit applies")

	net.claim("rivet_gun_1")
	check(net.claim_owner("rivet_gun_1") == 1 and net.is_mine("rivet_gun_1"), "claim granted")
	net.release("rivet_gun_1")
	check(net.claim_owner("rivet_gun_1") == 0, "claim released")

	# Solo tractor beam: hold, line it up, lock it, fasten, let go.
	net.set_hold("unit:pump", false)
	check(net.claim_owner("unit:pump") == 1 and not net.is_hold_ready("unit:pump"), "hold claims, not aligned yet")
	net.set_hold("unit:pump", true, true, "slot:a")
	var info := net.hold_info("unit:pump")
	check(net.is_hold_ready("unit:pump") and info.locked and info.target == "slot:a", "locked aligned hold: %s" % str(info))
	net.end_hold("unit:pump")
	check(net.hold_info("unit:pump").is_empty() and net.claim_owner("unit:pump") == 0, "end_hold lets go")

	var trolley := Node3D.new()
	add_child(trolley)
	net.register_mover("trolley:small_1", trolley)
	check(net.drives("trolley:small_1"), "solo player drives every mover")
	net.unregister_mover("trolley:small_1")
	trolley.queue_free()

	var saved := Flags.all()
	Flags.set_flag(MultiplayerBus.ONLINE_FLAG, false)
	check(net.host() == ERR_UNAVAILABLE, "hosting needs the online flag")
	Flags.use(saved)

	var compat := net.compat_info()
	check(compat.modules.has("multiplayer") and compat.game_version != "", "compat names modules and version")
	net.unregister_event("test.fasten")
	net.unregister_event("test.delivery")
