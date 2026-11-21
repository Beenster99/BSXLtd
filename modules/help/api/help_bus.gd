class_name HelpBus
extends Node
## Help module bus (Modules.bus("help")): the HELP tab on the F1 wrist screen (beenster,
## 20 Nov: "maybe we could do with a help section in the F1 wrist HUD"). Short pages on how
## the game works (the yard, designing a ship, contracts from order to payment, parts and
## stock, the bots, money, game time, playing together, the wrist's own tabs) and every key
## as it is bound now, with a search over all of them.
##
## Any module can add its own page, so help stays next to the feature it explains:
##   var help := Modules.bus("help")
##   if help: help.call("add_topic", "contracts.starter", "Your first contract", text, 35)
## `text` is plain lines: "# A heading", "- a bullet", "> a tip", anything else a paragraph;
## {key:<action>} is replaced by the key it is on now ("[F]"). Orders: the built-in pages are
## 10, 20 ... 100; pick one between to sit beside the page it belongs with.
## A page can be a control of its own instead (add_page: make(px_per_m) -> Control), as the
## size x class matrix of every component is ("matrix", read from the design catalogue).
##
## Chapters: a page can name the wrist screen it explains (`screen`, a HudSlots channel id) and
## a group for the list ("Start here", "Step by step", "Screens", "More"). Context help: open the
## HELP tab from any screen and it opens on that screen's chapter (the screen shown just before;
## help_for_screen). A page's text can also hold "! <shot>" (a picture from shots/), "@ 3|..."
## (the picture's callout 3), "1. ..." (a numbered step), "=> <channel>|Open it" (a button that
## puts that screen up) and "-> <page>|See ..." (a link to another page).
##
## Features (Flags): "help" (the module), "help.wrist" (the wrist tab).

signal topics_changed

const FLAG := "help"
const WRIST_FLAG := "help.wrist"
const HOLO_CHANNEL := "help.guide"
const HOLO_LABEL := "Help"
## Last on the wrist, after every screen.
const HOLO_ORDER := 90
## The wrist builds the page at this many px per metre (base text 15 px), as the other screens.
const WRIST_PX := 150.0
## The page that lists the keys; built from Keys when shown.
const KEYS_TOPIC := "keys"
const HelpScreen := preload("res://modules/help/internal/help_screen.gd")
const Guide := preload("res://modules/help/internal/guide.gd")
const CapabilityMatrix := preload("res://modules/help/internal/capability_matrix.gd")
const PartsPage := preload("res://modules/help/internal/parts_page.gd")
const PartsData := preload("res://modules/help/internal/parts_data.gd")
## The chapters' pictures (made by internal/tools/help_shots.tscn).
const Shots := preload("res://modules/help/internal/help_shots_data.gd")
## The list of every building part.
const PARTS_TOPIC := "parts_list"
const PARTS_TEXT := """Every part you can build with, from the design catalogue: components, rooms, doors, the hull's frame, plates and glass, wires and pipes. Each with all its numbers, where it goes, and every size and grade."""
## The size x class matrix page.
const MATRIX_TOPIC := "matrix"
const MATRIX_TEXT := """Every component that comes in sizes, at sizes 1 to 8 and grades R S L H Q P: power made, thrust, jump, damage, defence, range, cargo and the power each one uses. Click a reactor, generator or battery to see everything it can power."""

## The list's groups, in order.
const GROUPS: PackedStringArray = [Guide.START, Guide.STEPS, Guide.SCREENS, Guide.MORE]
## id -> {id, title, text, order, group[, make]}
var _topics: Dictionary = {}
## Wrist channel id -> the page that explains it.
var _screens: Dictionary = {}
## The screen shown on a terminal just before Help (its chapter opens), "" once used.
var _last_screen := ""
## The page shown last, so Help opens where it was left.
var last_topic := ""


func register_module() -> void:
	for t: Dictionary in Guide.TOPICS:
		add_topic(str(t.id), str(t.title), str(t.text), int(t.order), str(t.get("group", "")))
		for sc: String in t.get("screens", []):
			_screens[sc] = str(t.id)
	var design := Modules.bus("design") as DesignBus
	if design:
		var cat := design.catalog
		add_page(MATRIX_TOPIC, "Sizes and classes", MATRIX_TEXT,
				func(px: float) -> Control: return make_matrix(cat, px), 410,
				func() -> String: return _matrix_words(cat))
		add_page(PARTS_TOPIC, "Every part", PARTS_TEXT,
				func(px: float) -> Control: return make_parts(cat, px), 411,
				func() -> String: return PartsData.new(cat).search_text())
		_topics[MATRIX_TOPIC]["group"] = Guide.MORE
		_topics[PARTS_TOPIC]["group"] = Guide.MORE
	if Flags.is_on(WRIST_FLAG):
		HudSlots.register_holo_channel(HOLO_CHANNEL, HOLO_LABEL,
				func(_glass: bool) -> Control: return make_screen(WRIST_PX), HOLO_ORDER)
		# Which screen was up before Help: a terminal names each screen it shows "Channel" with
		# its channel id as meta (HoloTerminal.show_channel).
		if not get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node.name == "Channel" and node.has_meta("channel") and node is Control:
		var ch := str(node.get_meta("channel"))
		if ch != HOLO_CHANNEL:
			_last_screen = ch


## The page that explains wrist screen `channel` ("" when none does).
func help_for_screen(channel: String) -> String:
	var id := str(_screens.get(channel, ""))
	return id if not topic(id).is_empty() else ""


## Says page `id` explains wrist screen `channel` (for a module adding its own page).
func add_screen_help(channel: String, id: String) -> void:
	_screens[channel] = id


## The page Help should open on now: the chapter of the screen shown just before it, else the
## page shown last. Used once: the screen before is forgotten.
func take_pending() -> String:
	var id := help_for_screen(_last_screen)
	_last_screen = ""
	return id if id != "" else last_topic


func unregister_module() -> void:
	HudSlots.unregister_holo_channel(HOLO_CHANNEL)
	if get_tree() and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


## Adds or replaces a page (see the header for the text's form). `group`: the heading it is
## listed under (Guide's groups; "" goes with More).
func add_topic(id: String, title: String, text: String, order: int = 50, group: String = "") -> void:
	if id in Guide.REPLACES:
		return
	_topics[id] = {"id": id, "title": title, "text": text, "order": order, "group": group if group != "" else Guide.MORE}
	topics_changed.emit()


## Adds a page that is a control of its own: `make(px_per_m) -> Control` builds it each time
## it is shown. Search reads `text`, and what `words() -> String` returns when given (read once
## and kept). A control with set_query(q) is told the words typed in Help's search box.
func add_page(id: String, title: String, text: String, make: Callable, order: int = 50,
		words: Callable = Callable()) -> void:
	_topics[id] = {"id": id, "title": title, "text": text, "order": order, "make": make, "words": words, "group": Guide.MORE}
	topics_changed.emit()


## Everything search reads on a page, lower case.
func search_text(id: String) -> String:
	var t := topic(id)
	if t.is_empty():
		return ""
	var w: Callable = t.get("words", Callable())
	if not w.is_valid():
		return (str(t.title) + " " + page_text(id)).to_lower()
	if not t.has("_hay"):
		t["_hay"] = (str(t.title) + " " + page_text(id) + " " + str(w.call())).to_lower()
	return str(t._hay)


func make_parts(catalog: DesignCatalog, px_per_m: float) -> Control:
	var p := PartsPage.new()
	p.setup(catalog, px_per_m)
	return p


static func _matrix_words(catalog: DesignCatalog) -> String:
	var words: PackedStringArray = []
	for p: DesignPartType in catalog.parts.values():
		if p.size_class > 0:
			words.append(p.display_name)
	return " ".join(words)


func make_matrix(catalog: DesignCatalog, px_per_m: float) -> Control:
	var m := CapabilityMatrix.new()
	m.setup(catalog, px_per_m)
	return m


func remove_topic(id: String) -> void:
	if _topics.erase(id):
		topics_changed.emit()


## Every page, in order.
func topics() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in _topics.values():
		out.append(t)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ga := GROUPS.find(str(a.get("group", Guide.MORE)))
		var gb := GROUPS.find(str(b.get("group", Guide.MORE)))
		if ga != gb:
			return ga < gb
		return int(a.order) < int(b.order) if int(a.order) != int(b.order) else str(a.title) < str(b.title))
	return out


func topic(id: String) -> Dictionary:
	return _topics.get(id, {})


## A page's text ready to show: {key:<action>} filled in; the keys page built from Keys.
func page_text(id: String) -> String:
	if id == KEYS_TOPIC:
		return keys_text()
	var t := topic(id)
	return fill_keys(str(t.get("text", "")))


## "{key:interact}" -> "[F]", for the key the player has it on now.
static func fill_keys(text: String) -> String:
	var re := RegEx.create_from_string("\\{key:([a-zA-Z0-9_.]+)\\}")
	var out := text
	for m in re.search_all(text):
		var action := m.get_string(1)
		out = out.replace(m.get_string(0), Keys.prompt(action) if Keys.has(action) else "[-]")
	return out


## Every key as bound now, grouped as the Keys settings page groups them.
func keys_text() -> String:
	var groups: Array[String] = []
	var by_group := {}
	for a: Dictionary in Keys.actions():
		var g := str(a.group)
		if not by_group.has(g):
			by_group[g] = []
			groups.append(g)
		(by_group[g] as Array).append(a)
	var first := [Keys.MOVEMENT, Keys.ACTIONS, "Deep space yard", "Orbital yard"]
	groups.sort_custom(func(x: String, y: String) -> bool:
		var ix := first.find(x)
		var iy := first.find(y)
		ix = ix if ix >= 0 else 99
		iy = iy if iy >= 0 else 99
		return ix < iy if ix != iy else groups.find(x) < groups.find(y))
	var lines: PackedStringArray = ["Every key as it is set now. Change any of them in Esc > Settings > Keys.",
			"- The mouse looks round; left click uses what you hold or presses what you point at."]
	for g in groups:
		lines.append("# " + g)
		for a: Dictionary in by_group[g]:
			lines.append("= %s|%s" % [Keys.key_name(str(a.action)), str(a.label)])
	return "\n".join(lines)


## Finds pages whose title or text has every word of `query`.
func search(query: String) -> Array[Dictionary]:
	var words := query.to_lower().split(" ", false)
	var out: Array[Dictionary] = []
	for t in topics():
		var hay := search_text(str(t.id))
		if Array(words).all(func(w: String) -> bool: return hay.contains(w)):
			out.append(t)
	return out


func make_screen(px_per_m: float) -> Control:
	var s := HelpScreen.new()
	s.setup(self, px_per_m)
	return s
