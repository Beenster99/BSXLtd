extends ModuleTest
## The Crew channel: chat and activity solo, the wrist screen's crew list, chat log, helmet
## cam and other modules' sections, then two players over ENet on localhost seeing each
## other's chat, avatars, hands, what they hold, helmet cams and the host's time of day.
##   tools/run_tests.sh multiplayer

const PORT := 24597


func run_tests() -> void:
	var net := Modules.bus("multiplayer") as MultiplayerBus
	check(not HudSlots.holo_channel(MultiplayerBus.CREW_CHANNEL).is_empty(), "Crew channel on the wrist screen")
	net.say("  checking in  ")
	net.say("   ")
	var log := net.chat_log()
	check(log.size() == 1 and log[0].text == "checking in", "solo chat logs trimmed lines only: %s" % str(log))
	check(log[0].peer == 1 and str(log[0].time).length() == 5, "line stamped with player and time")
	net.set_activity("Riveting")
	check(net.activity(1) == "Riveting", "activity recorded")

	var got: Array[Dictionary] = []
	var on_ping := func(p: Dictionary) -> void: got.append(p)
	net.ping_received.connect(on_ping)
	net.ping(Vector3(1, 0, 2), "unit:reactor_2", Vector3(0, 2, 0))
	net.ping(Vector3(5, 0, 5))
	check(got.size() == 1 and got[0].at == Vector3(1, 0, 2) and got[0].object_id == "unit:reactor_2",
			"solo ping reaches this player at once: %s" % str(got))
	check(got[0].peer == 1 and got[0].normal == Vector3.UP and got[0].colour == net.player_colour(1),
			"ping stamped with player, colour and a unit normal")
	check(net.pings().size() == 1, "a second ping within 0.25 s is dropped")
	var removed: Array[int] = []
	var refused: Array[String] = []
	net.request_rejected.connect(func(n: String, why: String) -> void: refused.append("%s %s" % [n, why]))
	var on_removed := func(id: int) -> void: removed.append(id)
	net.ping_removed.connect(on_removed)
	for i in 5:
		await _wait_real(0.3)
		net.ping(Vector3(i, 0, 0), "", Vector3.UP, "Rivet gun" if i == 4 else "")
	check(net.pings().size() == 5, "at most 5 pings showing per player: %d" % net.pings().size())
	check(got.size() == 6 and removed == [got[0].id], "the sixth ping replaced the oldest: %d sent, removed %s, refused %s" % [got.size(), str(removed), str(refused)])
	check(got.back().label == "Rivet gun" and got[1].label == "", "ping carries the object's name")
	check(MultiplayerBus.PING_LIFE == 10.0, "pings last 10 seconds")
	net.ping_removed.disconnect(on_removed)
	var before := got.size()
	await _wait_real(0.3)
	net.ping(Vector3(INF, 0, 0))
	check(got.size() == before, "a ping with no real place is refused")
	net.ping_received.disconnect(on_ping)

	HudSlots.register_holo_section(MultiplayerBus.CREW_CHANNEL, "_test_transfer", "Transfer money",
			func(_glass: bool) -> Control: return Label.new())
	var factory: Callable = HudSlots.holo_channel(MultiplayerBus.CREW_CHANNEL).factory
	var screen: Control = factory.call(true)
	add_child(screen)
	await frames(2)
	var rows := screen.find_child("CrewList", true, false).get_children()
	check(rows.size() == 1 and rows[0].find_child("Cam_*", true, false) == null, "solo crew list: just you, no CAM")
	check(screen.find_child("PlayTogether", true, false) == null, "no host/join section on the Crew tab")
	check(screen.find_child("ChatLog", true, false).get_child_count() == 1, "chat log shows earlier lines")
	check(screen.find_child("Section__test_transfer", true, false) != null, "other modules' sections appear")
	var box := screen.find_child("CrewSayBox", true, false) as LineEdit
	box.text = "from the box"
	(screen.find_child("CrewSend", true, false) as Button).pressed.emit()
	await frames(2)
	check(net.chat_log().back().text == "from the box" and box.text == "", "SEND posts and clears the box")
	check(screen.find_child("ChatLog", true, false).get_child_count() == 2, "new line shows on the screen")
	screen.queue_free()
	HudSlots.unregister_holo_section(MultiplayerBus.CREW_CHANNEL, "_test_transfer")

	await _two_players()


func _two_players() -> void:
	var saved := Flags.all()
	Flags.set_flag(MultiplayerBus.ONLINE_FLAG, true)
	var a := _bus("BusA", "Ana")
	var b := _bus("BusB", "Ben")
	check(a.host(PORT) == OK, "host starts")
	b.join("127.0.0.1", PORT)
	check(await _until(func(): return b.peers().size() == 2 and a.peers().size() == 2), "client joins")
	var b_id := b.local_peer_id()
	var sky := AlienSky.new()
	add_child(sky)
	check(await _until(func(): return is_equal_approx(sky.hour_override, AlienSky.setting_hour())), "joiner's sky shows the host's hour from the start")
	var hour_was: Variant = Settings.get_value(AlienSky.SECTION, AlienSky.KEY)
	check(b.chat_log().is_empty() or b.chat_log().size() == a.chat_log().size(), "joiner gets the chat so far")

	b.say("bucking bar ready")
	check(await _until(func(): return a.chat_log().size() > 0 and a.chat_log().back().text == "bucking bar ready"), "host hears the client")
	check(a.chat_log().back().name == "Ben", "line carries the sender's name")
	a.say("go")
	check(await _until(func(): return b.chat_log().back().text == "go"), "client hears the host")
	var a_saw: Array[Dictionary] = []
	a.ping_received.connect(func(p: Dictionary) -> void: a_saw.append(p))
	b.ping(Vector3(2, 1, -3), "trolley:large_1", Vector3.FORWARD)
	check(await _until(func(): return a_saw.size() == 1), "host sees the client's ping")
	check(a_saw[0].peer == b_id and a_saw[0].object_id == "trolley:large_1" and a_saw[0].name == b.player_name(b_id),
			"ping carries who sent it and what it points at")
	check(await _until(func(): return b.pings().size() == 1), "the sender sees their own ping back")
	check(a.player_colour(1) != a.player_colour(b_id), "each player has their own ping colour")
	b.set_activity("Bucking bar")
	check(await _until(func(): return a.activity(b_id) == "Bucking bar"), "activity reaches the host")

	# Ben's head moves; Ana's avatar of Ben and her helmet cam follow it.
	var b_head: Node3D = b._crew.head_of(b_id)
	b_head.global_transform = Transform3D(Basis(Vector3.UP, 0.5), Vector3(3, 1.7, -2))
	check(await _until(func(): var h: Node3D = a._crew.head_of(b_id); return h != null and h.global_position.distance_to(Vector3(3, 1.7, -2)) < 0.01), "avatar follows the player's head")
	var tagged := get_tree().get_nodes_in_group("crew_head").filter(func(n: Node) -> bool:
		return n.get_meta("peer_id", 0) == b_id)
	check(tagged.size() == 1 and tagged[0] == a._crew.head_of(b_id), "Ben's avatar head is in crew_head with his peer id")
	check(a.avatar_head(b_id) == tagged[0] and a.avatar_head(1) == null and a.avatar_head(99) == null,
			"avatar_head gives Ben's head, not your own or a stranger's")
	var screen: Control = a._crew_screen(true)
	add_child(screen)
	check(await _until(func(): return screen.cam_peer == b_id), "helmet cam picks the other player")
	await frames(3)
	var cam := screen.find_child("HelmetCam", true, false).get_child(0).get_child(0) as Camera3D
	check(cam.global_position.distance_to(Vector3(3, 1.7, -2)) < 0.01, "helmet cam looks out of Ben's helmet")
	check(screen.find_child("Cam_%d" % b_id, true, false) != null, "CAM button by Ben's name")
	screen.queue_free()

	# Ben shares his hands and what he holds: his avatar reaches there, Tools can dress it.
	var b_hand := Node3D.new()
	add_child(b_hand)
	b_hand.global_position = Vector3(3.4, 1.2, -2.5)
	var a_held: Array = []
	a.held_changed.connect(func(peer: int, h: Dictionary) -> void: a_held.append([peer, h]))
	b.set_local_hands(b_hand, null)
	check(await _until(func(): var h := a.avatar_hand(b_id); return h != null and h.global_position.distance_to(Vector3(3.4, 1.2, -2.5)) < 0.01), "avatar's hand follows the player's real hand")
	check(a.avatar(b_id) != null and bool(a.avatar(b_id).get("hands_live")), "avatar knows the hands are live")
	var hands := get_tree().get_nodes_in_group("crew_hand").filter(func(n: Node) -> bool:
		return n.get_meta("peer_id", 0) == b_id)
	check(hands.size() == 2 and a.avatar_hand(b_id, false) in hands and a.avatar_hand(b_id, false).get_meta("side") == "left",
			"Ben's hands are in crew_hand with his peer id and side")
	check(a.avatar_hand(1) == null and a.avatar(1) == null, "no avatar or hand for yourself")
	b.set_held({"tool": "welder", "using": true, "junk": Node3D, "blob": [1, 2]})
	check(await _until(func(): return a.held(b_id).get("tool") == "welder"), "what Ben holds reaches the host")
	check(a.held(b_id) == {"tool": "welder", "using": true, "hands": true}, "held keeps small values and the hands flag: %s" % str(a.held(b_id)))
	check(not a_held.is_empty() and a_held.back()[0] == b_id, "held_changed tells Tools")
	var c := _bus("BusC", "Cas")
	c.join("127.0.0.1", PORT)
	check(await _until(func(): return c.held(b_id).get("tool") == "welder"), "a later joiner learns what Ben holds")
	c.leave()
	b_hand.free()
	check(await _until(func(): return a.avatar_hand(b_id) != null), "a hand that's gone doesn't break the avatar")
	b.set_local_hands(null, null)
	check(await _until(func(): return not bool(a.held(b_id).get("hands", true))), "hands go back to rest when unshared")

	# The host's time of day is everyone's.
	Settings.set_value(AlienSky.SECTION, AlienSky.KEY, 21.5)
	check(await _until(func(): return is_equal_approx(sky.hour_override, 21.5)), "the host's new hour reaches the joiner's sky")

	b.leave()
	check(await _until(func(): return a._crew.head_of(b_id) == null), "avatar goes when the player leaves")
	check(await _until(func(): return sky.hour_override < 0.0), "a leaver's sky goes back to their own setting")
	sky.queue_free()
	Settings.set_value(AlienSky.SECTION, AlienSky.KEY, hour_was)
	a.leave()
	Flags.use(saved)


func _bus(node_name: String, player: String) -> MultiplayerBus:
	var bus := MultiplayerBus.new()
	bus.name = node_name
	add_child(bus)
	bus.register_module()
	Settings.set_value("multiplayer", "player_name", player)
	bus._refresh_identity()
	return bus


## Real seconds: the host's ping limit runs on the wall clock, which tests can outpace.
func _wait_real(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _until(cond: Callable, timeout := 5.0) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()
