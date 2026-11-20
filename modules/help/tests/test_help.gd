extends ModuleTest
## Help: the wrist has a Help tab, every built-in page has text with no unfilled key marks,
## the keys page lists the keys as bound now, other modules can add a page, search finds
## pages, and the screen shows a page and answers a click and a search.
##   tools/run_tests.sh help


func run_tests() -> void:
	var bus := Modules.bus("help") as HelpBus
	check(bus != null, "the help module is loaded")
	if bus == null:
		return
	check(not HudSlots.holo_channel(HelpBus.HOLO_CHANNEL).is_empty(), "Help is a wrist tab")
	var topics := bus.topics()
	check(topics.size() >= 8, "the built-in pages are there: %d" % topics.size())
	check(str(topics[0].id) == "start", "Getting started comes first")
	for t in topics:
		var text := bus.page_text(str(t.id))
		check(text.length() > 80, "%s has text" % t.id)
		check(not text.contains("{key:"), "%s: every key mark is filled in" % t.id)
		check(not text.contains("[-]"), "%s: every key it names exists" % t.id)
	var keys := bus.page_text(HelpBus.KEYS_TOPIC)
	check(keys.contains("Wrist screen") and keys.contains(Keys.key_name(Keys.HOLO)), "the keys page lists the wrist key as bound")
	check(HelpBus.fill_keys("{key:interact}") == Keys.prompt(Keys.INTERACT), "a key mark becomes its key")
	bus.add_topic("_test.page", "Test page", "# Heading\n- a bullet {key:interact}", 15)
	check(str(bus.topics()[1].id) == "_test.page", "an added page sits by its order")
	check(bus.search("bullet").size() == 1, "search finds a word in a page")
	check(bus.search("deposit").any(func(t: Dictionary) -> bool: return t.id == "contracts"), "search finds the contracts page by 'deposit'")

	var screen := bus.make_screen(150.0)
	screen.size = Vector2(1400, 800)
	add_child(screen)
	await frames(2)
	var list := screen.find_child("Topics", true, false) as VBoxContainer
	check(list.get_child_count() == bus.topics().size(), "every page is listed")
	(screen.find_child("Topic_contracts", true, false) as Button).pressed.emit()
	await frames(1)
	check(str(screen.get("current")) == "contracts", "clicking a page shows it")
	var page := screen.find_child("Page", true, false) as VBoxContainer
	check(page.get_child_count() > 5, "the page has its headings and lines")
	screen.call("set_query", "airlock")
	await frames(1)
	check(list.get_child_count() == 1 and str(screen.get("current")) == "yard", "searching narrows the list and shows the match")
	bus.remove_topic("_test.page")
	screen.queue_free()
