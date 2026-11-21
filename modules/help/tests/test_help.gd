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
	check(topics.size() >= 25, "the built-in chapters are there: %d" % topics.size())
	check(str(topics[0].id) == "start", "Getting started comes first")
	for t in topics:
		var text := bus.page_text(str(t.id))
		check(text.length() > 80, "%s has text" % t.id)
		check(not text.contains("{key:"), "%s: every key mark is filled in" % t.id)
		check(not text.contains("[-]"), "%s: every key it names exists" % t.id)
	var keys := bus.page_text(HelpBus.KEYS_TOPIC)
	check(keys.contains("Wrist screen") and keys.contains(Keys.key_name(Keys.HOLO)), "the keys page lists the wrist key as bound")
	check(HelpBus.fill_keys("{key:interact}") == Keys.prompt(Keys.INTERACT), "a key mark becomes its key")
	_test_chapters(bus)
	bus.add_topic("_test.page", "Test page", "# Heading\n- a bullet {key:interact}", 15, HelpBus.Guide.START)
	check(str(bus.topics()[1].id) == "_test.page", "an added page sits by its order in its group")
	check(bus.search("bullet").size() == 1, "search finds a word in a page")
	check(bus.search("deposit").any(func(t: Dictionary) -> bool: return t.id == "first_contract"), "search finds the first contract by 'deposit'")
	bus.add_topic("orders", "Ordering parts", "An old page another module used to add.", 31)
	check(bus.topic("orders").is_empty(), "pages the chapters replace are left out")

	var screen := bus.make_screen(150.0)
	screen.size = Vector2(1400, 800)
	add_child(screen)
	await frames(2)
	var list := screen.find_child("Topics", true, false) as VBoxContainer
	check((screen.call("topic_buttons") as Array).size() == bus.topics().size(), "every page is listed")
	check(list.get_child_count() > bus.topics().size(), "under its group's heading")
	(screen.find_child("Topic_orders_screen", true, false) as Button).pressed.emit()
	await frames(1)
	check(str(screen.get("current")) == "orders_screen", "clicking a page shows it")
	var page := screen.find_child("Page", true, false) as VBoxContainer
	check(page.get_child_count() > 5, "the page has its headings and lines")
	check(screen.find_child("Shot_orders", true, false) != null, "a screen's chapter shows its picture")
	check(screen.find_child("Goto_buy_parts", true, false) != null, "and links to the step-by-step it belongs with")
	(screen.find_child("Goto_buy_parts", true, false) as Button).pressed.emit()
	await frames(1)
	check(str(screen.get("current")) == "buy_parts", "a link opens that chapter")
	check(screen.find_child("Open_orders_book", true, false) != null, "a step-by-step has a button that opens the screen")
	screen.call("set_query", "airlock")
	await frames(1)
	var hits := screen.call("topic_buttons") as Array
	check(hits.size() < bus.topics().size() and hits.any(func(b: Button) -> bool: return b.name == "Topic_yard"), "searching narrows the list: %d" % hits.size())
	bus.remove_topic("_test.page")
	screen.call("set_query", "")
	await _test_context(bus)
	await _test_matrix(bus, screen)
	await _test_parts(bus, screen)
	screen.queue_free()


## Every chapter's pictures, callouts and links hold together: a picture named is in shots/
## and was made with at least as many rings as the chapter has callouts under it, a link goes to
## a chapter or a wrist screen that is there, and every wrist screen has a chapter.
func _test_chapters(bus: HelpBus) -> void:
	var rings := {}
	for sh: Dictionary in HelpBus.Shots.SHOTS:
		rings[str(sh.id)] = (sh.get("ring", []) as Array).size()
	for t in bus.topics():
		var shot := ""
		var callouts := 0
		var lines := (str(t.text) + "\n! _end").split("\n")
		for line in lines:
			var l := line.strip_edges()
			if l.begins_with("! "):
				if shot != "" and shot != "_end":
					check(callouts <= int(rings.get(shot, 0)), "%s: %s has a ring for each of its %d callouts (%d)" % [t.id, shot, callouts, int(rings.get(shot, 0))])
				shot = l.substr(2)
				callouts = 0
				if shot != "_end":
					check(rings.has(shot), "%s: the picture %s is made by the shots tool" % [t.id, shot])
					check(ResourceLoader.exists(HelpBus.Shots.DIR.path_join(shot + ".webp")), "%s: the picture %s is in the game" % [t.id, shot])
			elif l.begins_with("@ "):
				callouts += 1
			elif l.begins_with("-> "):
				var to := l.substr(3).get_slice("|", 0)
				check(not bus.topic(to).is_empty(), "%s: its link to %s goes somewhere" % [t.id, to])
			elif l.begins_with("=> "):
				var ch := l.substr(3).get_slice("|", 0)
				check(not HudSlots.holo_channel(ch).is_empty(), "%s: its button opens the %s screen" % [t.id, ch])
	var groups := {}
	for t in bus.topics():
		groups[str(t.group)] = true
	check(groups.size() == 4, "the chapters are in their four groups: %s" % [groups.keys()])
	for ch: Dictionary in HudSlots.holo_channels():
		if str(ch.id) != HelpBus.HOLO_CHANNEL:
			check(bus.help_for_screen(str(ch.id)) != "", "the %s screen has a chapter" % ch.label)


## Help opens on the chapter of the screen shown just before it (a terminal's "Channel" node
## names its channel), once, then where it was left.
func _test_context(bus: HelpBus) -> void:
	var before := Control.new()
	before.name = "Channel"
	before.set_meta("channel", "orders.book")
	add_child(before)
	var s := bus.make_screen(150.0)
	s.size = Vector2(1400, 800)
	add_child(s)
	await frames(1)
	check(str(s.get("current")) == "orders_screen", "Help opened from Parts orders opens on its chapter: %s" % s.get("current"))
	s.call("show_topic", "deliver")
	s.queue_free()
	before.queue_free()
	await frames(1)
	var again := bus.make_screen(150.0)
	add_child(again)
	await frames(1)
	check(str(again.get("current")) == "deliver", "opened again, Help is where it was left")
	again.queue_free()


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



## Every part: each catalogue component, room, door kind and frame piece has an entry with its
## numbers, rooms say what goes in them, parts say where they go, every size and grade has a
## row, and Help's search finds a part and narrows the list to it.
func _test_parts(bus: HelpBus, screen: Control) -> void:
	var cat := (Modules.bus("design") as DesignBus).catalog
	var data := HelpBus.PartsData.new(cat)
	var all := data.entries()
	var comps := all.filter(func(e: Dictionary) -> bool: return cat.parts.has(str(e.id)))
	check(comps.size() == cat.parts.size(), "every component has an entry: %d of %d" % [comps.size(), cat.parts.size()])
	check(all.filter(func(e: Dictionary) -> bool: return str(e.id).begins_with("room.")).size() == cat.rooms.size(), "every room has an entry")
	check(all.filter(func(e: Dictionary) -> bool: return str(e.id).begins_with("door.")).size() == DesignCatalog.DOOR_KINDS.size(), "every door kind has an entry")
	for k in ["frame.HullPlate", "frame.WindowPane", "frame.FrameRing", "frame.Stringer", "frame.DeckPlate", "structure.hull.armoured", "joint.rivets"]:
		check(not data.entry(k).is_empty(), "the frame kit lists %s" % k)
	var reactor := data.entry("reactor_small")
	var span := DesignGrades.sizes(cat.part("reactor_small"))
	check((reactor.rows as Array).size() == (span[1] - span[0] + 1) * DesignGrades.GRADE_ORDER.size(), "a graded part has a row for every size and grade: %d" % (reactor.rows as Array).size())
	var attr := func(e: Dictionary, label: String) -> String:
		for a: Array in e.attrs:
			if str(a[0]) == label:
				return str(a[1])
		return ""
	# beenster: "life support does not belong in a medical bay but I could not find where it should go".
	var placed := cat.parts.values().filter(func(p: DesignPartType) -> bool: return not p.rooms.is_empty() and not p.hull_mount)
	check(not placed.is_empty(), "some parts only go in some rooms")
	var p: DesignPartType = placed[0]
	var goes: String = attr.call(data.entry(p.id), "Goes in")
	check(goes.contains(cat.room(p.rooms[0]).display_name), "a part says which rooms it goes in: %s -> %s" % [p.display_name, goes])
	var room_text: String = attr.call(data.entry("room." + p.rooms[0]), "Parts made for it")
	check(room_text.contains(p.display_name), "its room lists it among the parts made for it")
	check(data.find(p.display_name.to_lower()).size() >= 1, "search over parts finds it by name")

	check(bus.search("rivets").any(func(t: Dictionary) -> bool: return t.id == HelpBus.PARTS_TOPIC), "Help's search reaches into the parts list")
	screen.call("set_query", "")
	screen.call("show_topic", HelpBus.PARTS_TOPIC)
	await frames(2)
	var page := screen.find_child("Parts", true, false) as Control
	check(page != null, "the Every part page shows the parts list")
	if page == null:
		return
	check((page.call("shown") as Array).size() == all.size(), "with no search every part is listed")
	screen.call("set_query", "glass panel")
	await frames(1)
	page = screen.find_child("Parts", true, false) as Control
	check(page != null and str(screen.get("current")) != "", "searching keeps a page shown")
	if str(screen.get("current")) == HelpBus.PARTS_TOPIC and page:
		var hits: Array = page.call("shown")
		check(not hits.is_empty() and hits.all(func(e: Dictionary) -> bool: return str(e.search).contains("glass")), "the search narrows the parts list: %d" % hits.size())
		check(str(page.get("picked")) == str(hits[0].id), "and picks the first match")
	else:
		var titles := bus.search("glass panel").map(func(t: Dictionary) -> String: return str(t.id))
		check(HelpBus.PARTS_TOPIC in titles, "the parts list is among the search hits: %s" % [titles])
		screen.call("show_topic", HelpBus.PARTS_TOPIC)
		await frames(1)
		page = screen.find_child("Parts", true, false) as Control
		check(page != null and (page.call("shown") as Array).size() < all.size(), "opening it while searching narrows the list")
	screen.call("set_query", "")
