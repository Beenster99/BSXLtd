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
	screen.call("set_query", "")
	await _test_matrix(bus, screen)
	screen.queue_free()


## The size x class matrix: a page of its own; every graded type in every size; a reactor
## clicked becomes the supply and lights what it can run (and only that).
func _test_matrix(bus: HelpBus, screen: Control) -> void:
	check(not bus.topic(HelpBus.MATRIX_TOPIC).is_empty(), "the size and class matrix is a help page")
	check(bus.search("reactor generator").any(func(t: Dictionary) -> bool: return t.id == HelpBus.MATRIX_TOPIC), "search finds the matrix")
	screen.call("show_topic", HelpBus.MATRIX_TOPIC)
	await frames(2)
	var m := screen.find_child("Matrix", true, false) as Control
	check(m != null, "the matrix page shows its matrix")
	if m == null:
		return
	var cat := (Modules.bus("design") as DesignBus).catalog
	var reactor := cat.part("reactor_small")
	check(reactor != null and reactor.power > 0.0, "the small reactor makes power")
	if reactor == null:
		return
	var span := DesignGrades.sizes(reactor)
	var cells := 0
	for s in range(span[0], span[1] + 1):
		if m.call("cell", DesignGrades.variant_id(reactor, s, "S")) != null:
			cells += 1
	check(cells == span[1] - span[0] + 1, "the reactor has a cell for every size it comes in: %d" % cells)
	var small_id := DesignGrades.variant_id(reactor, span[0], "S")
	(m.call("cell", small_id) as Button).pressed.emit()
	await frames(1)
	check(str(m.get("supply_id")) == small_id, "clicking a reactor makes it the supply")
	check((m.find_child("Supply", true, false) as Label).text.contains("runs"), "the supply bar says what it runs")
	# Every consumer in another group is green when the reactor makes its draw, red when not.
	m.call("set_category", "life")
	await frames(1)
	var supply := cat.part(small_id)
	var right := 0
	var wrong := 0
	var green := 0
	for base: DesignPartType in m.get("data").call("types_in", "life"):
		for s in range(1, 9):
			var v: DesignPartType = m.get("data").call("variant", base, s, "S")
			if v == null or v.power >= 0.0:
				continue
			var want := "run" if -v.power <= supply.power else "no"
			if want == "run":
				green += 1
			if str(m.call("cell_state", v)) == want and m.call("cell", v.id) != null:
				right += 1
			else:
				wrong += 1
	check(wrong == 0 and right > 0, "every power user is lit green or red by the supply: %d right, %d wrong" % [right, wrong])
	check(green > 0, "the small reactor runs some life support")
	var group := m.find_child("Group_life", true, false) as Button
	check(group != null and group.text.contains("/"), "each group counts what the supply runs")
	m.call("set_category", "power")
	m.call("set_grade", "P")
	await frames(1)
	check(m.call("cell", DesignGrades.variant_id(reactor, span[0], "P")) != null, "another grade shows that grade's cells")
	var data: RefCounted = m.get("data")
	var base_p := cat.part(DesignGrades.variant_id(reactor, span[0], "S"))
	var prec := cat.part(DesignGrades.variant_id(reactor, span[0], "P"))
	check(prec.power > base_p.power, "a Precision reactor makes more than a Standard one of its size")
	var cov_s: Dictionary = data.call("coverage", base_p)
	var cov_p: Dictionary = data.call("coverage", prec)
	check(int(cov_p.ok) >= int(cov_s.ok) and int(cov_s.total) > 0, "a stronger supply runs at least as much: %d vs %d of %d" % [cov_p.ok, cov_s.ok, cov_s.total])
	(m.find_child("ClearSupply", true, false) as Button).pressed.emit()
	await frames(1)
	check(str(m.get("supply_id")) == "", "the supply can be cleared")
