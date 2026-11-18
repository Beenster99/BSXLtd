extends ModuleTest
## Friends in the yard (Wave 1, stage 1.6): two players over ENet on localhost. Each streams
## their suit (body and eye) and what they hold; the other draws them in the Void Salvage suit
## where they are, walking or floating, with their lamp and tool, and hides the Multiplayer
## module's plain stand-in. A friend who leaves goes. Also the stand-ins the captures use.
##   tools/run_tests.sh yard

const PORT := 24611


func run_tests() -> void:
	for f: String in [YardBus.FLAG, YardBus.STATION, YardBus.DOCK, YardBus.RACKING]:
		Flags.set_flag(f, true)
	var shown := YardCrew.new()
	add_child(shown)
	var c := shown.show_stand_in("Dan", Color("6fc8e8"), Vector3(0, 0, 0), Vector3(0, 1.6, -5),
			{"deck": true, "tool": "grinder", "lamp": true})
	await frames(2)
	check(c.avatar != null and c.avatar.on_deck, "a stand-in wears the Void Salvage suit, standing")
	check(c.avatar.tool_override == c.tools["grinder"] and c.tools["grinder"].visible, "the grinder in its hand")
	check(c.lamp.visible, "its lamp on")
	check(is_equal_approx(c.global_position.y, YardRig.FEET), "its soles on the deck")
	c.wear({"deck": false, "tool": "", "lamp": false})
	check(not c.avatar.on_deck and c.avatar.tool_override == null and not c.tools["grinder"].visible and not c.lamp.visible,
			"floating, hand free, lamp off")
	shown.queue_free()

	if not ClassDB.class_exists("ENetMultiplayerPeer"):
		return
	var saved := Flags.all()
	Flags.set_flag("multiplayer", true)
	Flags.set_flag("multiplayer.online", true)
	var a := _bus("BusA", "Ana")
	var b := _bus("BusB", "Ben")
	var crew_a := YardCrew.new()
	crew_a.use_net(a)
	add_child(crew_a)
	var crew_b := YardCrew.new()
	crew_b.use_net(b)
	add_child(crew_b)
	check(a.call("host", PORT) == OK, "host starts")
	b.call("join", "127.0.0.1", PORT)
	check(await _until(func(): return (b.call("peers") as Dictionary).size() == 2 and (a.call("peers") as Dictionary).size() == 2), "friend joins")
	var b_id: int = b.call("local_peer_id")
	check(await _until(func(): return crew_a.crewmates.has(b_id)), "the host has a crewmate for the friend")
	var mate: YardCrew.Crewmate = crew_a.crewmates.get(b_id)
	check(mate != null and not mate.visible, "hidden until they say they are in the yard")
	check(crew_b.crewmates.has(1), "and the friend has one for the host")

	# Ben walks the corridor with the cutter out, looking a little down.
	var body := Transform3D(Basis(Vector3.UP, 0.8), Vector3(-6, 1.25, -2))
	crew_b._body.global_transform = body
	crew_b._head.global_transform = Transform3D(body.basis * Basis(Vector3.RIGHT, -0.3), body * Vector3(0, YardRig.EYE, 0))
	var held: Dictionary = b.call("held", b_id)
	held.merge({"yard": true, "deck": true, "tool": "cutter", "using": false, "lamp": true})
	b.call("set_held", held)
	check(await _until(func(): return mate.visible), "shown once in the yard")
	check(await _until(func(): return mate.global_position.distance_to(body.origin) < 0.01), "the suit stands where Ben is")
	check(mate.global_basis.z.distance_to(body.basis.z) < 0.01, "turned his way")
	await frames(2)
	check(absf(float(mate.avatar.get("_look_pitch")) + 0.3) < 0.02, "looking down as he looks: %.3f" % float(mate.avatar.get("_look_pitch")))
	check(mate.avatar.on_deck and mate.lamp.visible, "walking, lamp on")
	check(mate.shown_tool == "cutter" and mate.avatar.tool_override == mate.tools["cutter"], "the cutter in his hand")
	var stand_in: Node3D = a.call("avatar", b_id)
	var drawn := stand_in.find_children("*", "GeometryInstance3D", true, false).filter(func(g: Node) -> bool: return (g as GeometryInstance3D).layers != 0) if stand_in else []
	check(stand_in != null and drawn.is_empty(), "the plain stand-in is hidden")

	held = b.call("held", b_id)
	held.merge({"deck": false, "tool": "", "lamp": false}, true)
	b.call("set_held", held)
	check(await _until(func(): return not mate.avatar.on_deck), "floating out in the dock")
	check(mate.avatar.tool_override == null and not mate.lamp.visible, "hand free, lamp off")

	b.call("leave")
	check(await _until(func(): return not crew_a.crewmates.has(b_id)), "a friend who leaves goes")
	a.call("leave")
	crew_a.queue_free()
	crew_b.queue_free()
	await frames(2)
	a.call("unregister_module")
	b.call("unregister_module")
	a.queue_free()
	b.queue_free()
	Flags.use(saved)


func _bus(node_name: String, player: String) -> Node:
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
