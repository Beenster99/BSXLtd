extends ModuleTest
## The Crew channel: chat and activity solo, the wrist screen's crew list, chat log, helmet
## cam and other modules' sections, then two players over ENet on localhost seeing each
## other's chat, avatars and helmet cams.
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

	HudSlots.register_holo_section(MultiplayerBus.CREW_CHANNEL, "_test_transfer", "Transfer money",
			func(_glass: bool) -> Control: return Label.new())
	var factory: Callable = HudSlots.holo_channel(MultiplayerBus.CREW_CHANNEL).factory
	var screen: Control = factory.call(true)
	add_child(screen)
	await frames(2)
	var rows := screen.find_child("CrewList", true, false).get_children()
	check(rows.size() == 1 and rows[0].find_child("Cam_*", true, false) == null, "solo crew list: just you, no CAM")
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
	check(b.chat_log().is_empty() or b.chat_log().size() == a.chat_log().size(), "joiner gets the chat so far")

	b.say("bucking bar ready")
	check(await _until(func(): return a.chat_log().size() > 0 and a.chat_log().back().text == "bucking bar ready"), "host hears the client")
	check(a.chat_log().back().name == "Ben", "line carries the sender's name")
	a.say("go")
	check(await _until(func(): return b.chat_log().back().text == "go"), "client hears the host")
	b.set_activity("Bucking bar")
	check(await _until(func(): return a.activity(b_id) == "Bucking bar"), "activity reaches the host")

	# Ben's head moves; Ana's avatar of Ben and her helmet cam follow it.
	var b_head: Node3D = b._crew.head_of(b_id)
	b_head.global_transform = Transform3D(Basis(Vector3.UP, 0.5), Vector3(3, 1.7, -2))
	check(await _until(func(): var h: Node3D = a._crew.head_of(b_id); return h != null and h.global_position.distance_to(Vector3(3, 1.7, -2)) < 0.01), "avatar follows the player's head")
	var screen: Control = a._crew_screen(true)
	add_child(screen)
	check(await _until(func(): return screen.cam_peer == b_id), "helmet cam picks the other player")
	await frames(3)
	var cam := screen.find_child("HelmetCam", true, false).get_child(0).get_child(0) as Camera3D
	check(cam.global_position.distance_to(Vector3(3, 1.7, -2)) < 0.01, "helmet cam looks out of Ben's helmet")
	check(screen.find_child("Cam_%d" % b_id, true, false) != null, "CAM button by Ben's name")
	screen.queue_free()

	b.leave()
	check(await _until(func(): return a._crew.head_of(b_id) == null), "avatar goes when the player leaves")
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


func _until(cond: Callable, timeout := 5.0) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()
