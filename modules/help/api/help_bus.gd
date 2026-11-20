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
## The size x class matrix page.
const MATRIX_TOPIC := "matrix"
const MATRIX_TEXT := """Every component that comes in sizes, at sizes 1 to 8 and grades R S L H Q P: power made, thrust, jump, damage, defence, range, cargo and the power each one uses. Click a reactor, generator or battery to see everything it can power."""

## id -> {id, title, text, order[, make]}
var _topics: Dictionary = {}


func register_module() -> void:
	for t: Dictionary in Guide.TOPICS:
		add_topic(str(t.id), str(t.title), str(t.text), int(t.order))
	var design := Modules.bus("design") as DesignBus
	if design:
		add_page(MATRIX_TOPIC, "Sizes and classes", MATRIX_TEXT,
				func(px: float) -> Control: return make_matrix(design.catalog, px), 45)
	if Flags.is_on(WRIST_FLAG):
		HudSlots.register_holo_channel(HOLO_CHANNEL, HOLO_LABEL,
				func(_glass: bool) -> Control: return make_screen(WRIST_PX), HOLO_ORDER)


func unregister_module() -> void:
	HudSlots.unregister_holo_channel(HOLO_CHANNEL)


## Adds or replaces a page (see the header for the text's form).
func add_topic(id: String, title: String, text: String, order: int = 50) -> void:
	_topics[id] = {"id": id, "title": title, "text": text, "order": order}
	topics_changed.emit()


## Adds a page that is a control of its own: `make(px_per_m) -> Control` builds it each time
## it is shown; `text` is what search reads and what shows above it.
func add_page(id: String, title: String, text: String, make: Callable, order: int = 50) -> void:
	_topics[id] = {"id": id, "title": title, "text": text, "order": order, "make": make}
	topics_changed.emit()


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
		var hay := (str(t.title) + " " + page_text(str(t.id))).to_lower()
		if Array(words).all(func(w: String) -> bool: return hay.contains(w)):
			out.append(t)
	return out


func make_screen(px_per_m: float) -> Control:
	var s := HelpScreen.new()
	s.setup(self, px_per_m)
	return s
