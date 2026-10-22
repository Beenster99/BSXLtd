extends ModuleTest
## Progression with players: crew names as lasting ids, effects to Trades by peer id, the
## host's state reaching a client, and the Character page's Skills section.
##   tools/run_tests.sh progression


## Two peers' Multiplayer: "host" forwards host_emit to "client" as the session would.
class NetStub:
	extends MultiplayerBus
	var hosting := true
	var me := 1
	var crew := {}
	var events := {}
	var other: NetStub

	func peers() -> Dictionary:
		return crew.duplicate(true)

	func local_peer_id() -> int:
		return me

	func is_host() -> bool:
		return hosting

	func register_event(event_name: String, apply: Callable, _validate := Callable()) -> void:
		events[event_name] = apply

	func unregister_event(event_name: String) -> void:
		events.erase(event_name)

	func host_emit(event_name: String, payload: Dictionary = {}) -> void:
		for net: NetStub in [self, other]:
			if net and net.events.has(event_name):
				net.events[event_name].call(payload.duplicate(true))

	func register_snapshot_provider(_section: String, _provider: Object) -> void:
		pass

	func unregister_snapshot_provider(_section: String) -> void:
		pass


class TradesStub:
	extends Node
	var modifiers := {}

	func set_player_modifiers(player_id: Variant, effects: Dictionary) -> void:
		modifiers[str(player_id)] = effects


class QualityStub:
	extends Node
	signal joint_graded(record)

	func grade(joint_id: String, peer_id: int, score: int) -> void:
		var r := Record.new()
		r.joint_id = StringName(joint_id)
		r.trade = &"BOLT"
		r.peer_id = peer_id
		r.score = score
		joint_graded.emit(r)


class Record:
	extends RefCounted
	var joint_id: StringName
	var trade: StringName
	var peer_id := 1
	var score := -1


func run_tests() -> void:
	var start_flags := Flags.all()
	var on := start_flags.duplicate()
	for f in [ProgressionBus.PERKS, ProgressionBus.CERTS]:
		on[f] = true
	on["progression"] = true
	Flags.use(on)
	var crew := {1: {"name": "Sam"}, 7: {"name": "Fitter"}, 9: {"name": "Fitter"}}
	var host_net := NetStub.new()
	var client_net := NetStub.new()
	host_net.crew = crew
	client_net.crew = crew
	client_net.hosting = false
	client_net.me = 7
	host_net.other = client_net
	for n in [host_net, client_net]:
		add_child(n)

	var trades := TradesStub.new()
	var quality := QualityStub.new()
	add_child(trades)
	add_child(quality)
	var host := ProgressionBus.new()
	var client := ProgressionBus.new()
	add_child(host)
	add_child(client)
	host.attach(trades, null, quality, null)
	host.attach_net(host_net)
	client.attach_net(client_net)

	check(host.player_for_peer(1) == &"Sam", "a peer is known by crew name")
	check(host.player_for_peer(7) == &"Fitter", "lowest peer keeps a shared name")
	check(host.player_for_peer(9) == &"Fitter#9", "a later peer with the same name is told apart")
	check(client.my_player_id() == &"Fitter", "the client knows who it is")

	for i in 10:
		quality.grade("b%d" % i, 7, 100)
	check(host.skill_xp(&"Fitter", &"bolting") == 100, "XP kept under the crew name")
	check(host.skill_level(&"7", &"bolting") == 1, "queries take a peer id too (Business asks that way)")
	check(host.skill_xp(&"Fitter#9", &"bolting") == 0, "the other Fitter has their own XP")
	check(trades.modifiers.get("7", {}).has(&"torque_tolerance"), "Trades gets effects by peer id")
	check(not trades.modifiers.get("9", {}).has(&"torque_tolerance"), "and only that peer's")
	check(client.skill_level(&"Fitter", &"bolting") == 1, "the host's state reaches the client")
	check(client.total_level(client.my_player_id()) == 1, "total level adds every skill")

	# The Skills section on Settings > Character.
	var panel: Control = client.ProfilePanel.new(client)
	add_child(panel)
	var texts := PackedStringArray()
	_collect(panel, texts)
	var all := " ".join(texts)
	check("Torque wrench" in all and "200 XP to go" in all, "panel shows the trade, level and XP to go: %s" % all)
	check("No certifications yet" in all, "panel says when there are no certs")
	for i in 20:
		quality.grade("c%d" % i, 7, 100)
	await frames(2)
	texts = PackedStringArray()
	_collect(panel, texts)
	check("TOTAL LEVEL" in " ".join(texts) and "2" in texts, "panel refreshes when the state changes")
	panel.queue_free()

	# Levels only (the release set): no perk lines and no certifications.
	Flags.use(start_flags)
	Flags.set_flag("progression", true)
	var lite: Control = client.ProfilePanel.new(client)
	add_child(lite)
	texts = PackedStringArray()
	_collect(lite, texts)
	all = " ".join(texts)
	check("LEVEL 2 OF 5" in all and not "CERTIFICATIONS" in all and not "certification" in all,
			"levels-only panel: %s" % all)
	lite.queue_free()
	Flags.use(on)

	# Settings > Debug's Max XP: a client asks, the host applies it to that client's player.
	var payload: Variant = host._validate_max_xp(7, {})
	host._apply_max_xp(payload)
	var top := 0
	for s: ProgressionSkill in host.skills():
		top += s.xp_per_level.size()
	check(host.total_level(&"Fitter") == top, "Max XP puts every tool at its top level")
	check(host.total_level(&"Sam") == 0, "only for the player who asked")
	check(client.total_level(&"Fitter") == top, "and the client sees it")
	client.max_xp(&"Sam")
	check(host.total_level(&"Sam") == 0, "a client can't apply it itself")

	# Loaded for real: the section is on the Character page.
	var saved := start_flags
	var flags := saved.duplicate()
	flags["progression"] = true
	Flags.use(flags)
	Modules.load_all()
	var ids := Menu.settings_sections(Menu.CHARACTER).map(func(c): return c.id)
	check(Modules.is_loaded("progression") and ProgressionBus.PROFILE_SECTION in ids,
			"Skills section registered on the Character page")
	var real := Modules.bus("progression") as ProgressionBus
	check(real.my_player_id() != &"", "solo player has an id: %s" % real.my_player_id())
	flags["progression"] = false
	Flags.use(flags)
	Modules.load_all()
	ids = Menu.settings_sections(Menu.CHARACTER).map(func(c): return c.id)
	check(not ProgressionBus.PROFILE_SECTION in ids, "section gone with the module off")
	Flags.use(saved)
	Modules.load_all()


static func _collect(node: Node, out: PackedStringArray) -> void:
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_collect(c, out)
