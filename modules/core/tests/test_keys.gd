extends ModuleTest
## Keys: Core's actions on their default keys, module actions, rebinding saved through
## Settings, clashes, and holo channels in HudSlots.
##   tools/run_tests.sh core


func run_tests() -> void:
	for action in [Keys.FORWARD, Keys.BACK, Keys.LEFT, Keys.RIGHT, Keys.RUN, Keys.JUMP,
			Keys.INTERACT, Keys.HOLO, Keys.CANCEL]:
		check(InputMap.has_action(action), "Core registers %s" % action)
	var saved: Dictionary = {}
	for a: Dictionary in Keys.actions():
		saved[a.action] = Keys.key_of(a.action)
	Keys.reset(Keys.INTERACT)
	check(Keys.key_of(Keys.INTERACT) == KEY_F and Keys.prompt(Keys.INTERACT) == "[F]", "F is the doing key")
	check(_pressed(KEY_F, Keys.INTERACT), "pressing F fires interact")

	Keys.register("_t.call", "Call a trolley", KEY_T, "_Trolleys")
	var listed: Array = Keys.actions().map(func(a): return a.action)
	check(listed.find(Keys.FORWARD) < listed.find("_t.call"), "Core's actions list first")
	check(Keys.actions().filter(func(a): return a.action == "_t.call")[0].group == "_Trolleys", "group kept")
	Keys.rebind("_t.call", KEY_G)
	check(Keys.key_of("_t.call") == KEY_G and _pressed(KEY_G, "_t.call") and not _pressed(KEY_T, "_t.call"),
			"rebinding moves the action")
	check(int(Settings.get_value(Keys.SECTION, "_t.call")) == KEY_G, "the rebind is saved in Settings")
	Keys.register("_t.call", "Call a trolley", KEY_T, "_Trolleys")
	check(Keys.key_of("_t.call") == KEY_G, "a saved rebind survives registering again")
	Keys.rebind("_t.call", KEY_F)
	check(Keys.INTERACT in Keys.clashes("_t.call"), "two actions on one key clash")
	Keys.reset("_t.call")
	check(Keys.key_of("_t.call") == KEY_T and Settings.get_value(Keys.SECTION, "_t.call") == null,
			"reset goes back to the default")
	Keys.unregister("_t.call")
	check(not InputMap.has_action("_t.call") and not Keys.has("_t.call"), "unregister removes it")

	var heard: Array[String] = []
	var on_request := func(c: String) -> void: heard.append(c)
	HudSlots.holo_requested.connect(on_request)
	HudSlots.register_holo_channel("_b", "B", func() -> Control: return Control.new(), 5)
	HudSlots.register_holo_channel("_a", "A", func() -> Control: return Control.new(), 1)
	var ids: Array = HudSlots.holo_channels().map(func(c): return c.id)
	check(ids.find("_a") < ids.find("_b"), "holo channels sorted by order")
	check(HudSlots.holo_channel("_a").label == "A", "holo channel found by id")
	HudSlots.open_holo("_a")
	check(heard == ["_a"], "open_holo asks the wrist screen for a channel")
	HudSlots.holo_requested.disconnect(on_request)
	HudSlots.unregister_holo_channel("_a")
	HudSlots.unregister_holo_channel("_b")
	check(HudSlots.holo_channel("_a").is_empty(), "holo channel unregisters")
	for action: String in saved:
		if Keys.has(action):
			Keys.rebind(action, saved[action])


func _pressed(key: Key, action: String) -> bool:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.pressed = true
	return ev.is_action_pressed(action)
