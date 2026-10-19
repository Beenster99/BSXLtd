extends ModuleTest
## Solo play: the bus is loaded, the local player is host, requests apply at once, refusals
## come back as request_rejected, claims work, and hosting waits for the online flag.
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

	var saved := Flags.all()
	Flags.set_flag(MultiplayerBus.ONLINE_FLAG, false)
	check(net.host() == ERR_UNAVAILABLE, "hosting needs the online flag")
	Flags.use(saved)

	var info := net.compat_info()
	check(info.modules.has("multiplayer") and info.game_version != "", "compat names modules and version")
	net.unregister_event("test.fasten")
	net.unregister_event("test.delivery")
