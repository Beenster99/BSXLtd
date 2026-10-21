extends Node
## HUD panel registry (autoload `HudSlots`). Modules register panels into named slots; the UI
## module's HUD draws whatever is registered, so Core and UI never know which modules exist.
##   HudSlots.register_panel("torque_readout", "res://modules/trades/internal/torque.tscn", HudSlots.TOOL_BELT)
##
## The wrist screen: channels are the screens a player can call up on the holo over their
## wrist (Keys.HOLO) from anywhere in a game, so they needn't walk to a wall terminal. A
## module registers a factory that builds the channel's Control (freed when the holo closes
## or switches channel); the holo shows it on a semi-transparent pane sized about 900 x 560.
##   HudSlots.register_holo_channel("business.orders", "Orders", func() -> Control: return OrdersScreen.new())
##   HudSlots.open_holo("business.orders")   # e.g. from a terminal's "show on wrist" button
## The pointer: a screen that needs the mouse (the wrist screen, a full-screen terminal, a
## menu) claims it while it's up; walkers, benches and tools leave the mouse alone and fire
## nothing while pointer_claimed() is true:
##   HudSlots.claim_pointer("business.terminal") ... HudSlots.release_pointer("business.terminal")
## Info cards: the one place for status, instructions and tips while playing (what you're
## driving and its keys, the tool's state, a hint). UI stacks them in a see-through panel
## on the right; a module sets its card when something starts and clears it when it ends:
##   HudSlots.set_info("ship_bay.drive", "Driving the scissor lift", "W A S D drive\nF lets it go")
##   HudSlots.clear_info("ship_bay.drive")
## Look hints: the info panel shows a card for whatever the player is looking at (within
## LOOK_REACH), saying what it is, what can be done with it and the keys, and nothing when
## they look at nothing. Give the object (its collider or any parent) a method
##   func look_hint() -> Dictionary: return {title = "Shore power", text = "Off",
##           keys = [[Keys.INTERACT, "Push it"], ["LMB", "Switch on"]]}
## (keys: an action, shown with its bound key, or a label as it is), or meta "look_hint"
## with the same Dictionary; or, for things that aren't colliders, register a provider
## that's asked first with the view's ray hit {collider, position, normal, from, direction}
## (collider null when the ray hits nothing) and returns {} when it has nothing:
##   HudSlots.register_look_hint("trades.tool", func(hit: Dictionary) -> Dictionary: ..., 10)
## A channel can take sections from other modules without naming them: the owner lays out
## TerminalKit.sections("<channel>", glass) and any module adds a docket to it, e.g.
##   HudSlots.register_holo_section("multiplayer.crew", "business.transfer", "Transfer money", factory)

signal panels_changed
signal holo_channels_changed
signal holo_sections_changed(channel: String)
signal info_changed
signal pointer_changed(claimed: bool)
## Asks the UI's wrist screen to open on a channel ("" = its home page).
signal holo_requested(channel: String)

const TOP_BAR := "top_bar"
const TOOL_BELT := "tool_belt"
const JOB_CARD := "job_card"
const NOTICES := "notices"
const SLOTS: PackedStringArray = [TOP_BAR, TOOL_BELT, JOB_CARD, NOTICES]

var _panels: Array[Dictionary] = []


func register_panel(id: String, scene_path: String, slot: String, order: int = 0) -> void:
	assert(slot in SLOTS, "HudSlots: unknown slot '%s'" % slot)
	unregister_panel(id)
	_panels.append({"id": id, "scene": scene_path, "slot": slot, "order": order})
	_panels.sort_custom(func(a, b): return a.order < b.order)
	panels_changed.emit()


func unregister_panel(id: String) -> void:
	_panels = _panels.filter(func(p): return p.id != id)


func panels_in(slot: String) -> Array[Dictionary]:
	return _panels.filter(func(p): return p.slot == slot)


var _holo: Array[Dictionary] = []


## Adds a wrist screen channel. `factory` takes no arguments and returns a Control.
func register_holo_channel(id: String, label: String, factory: Callable, order: int = 0) -> void:
	unregister_holo_channel(id)
	_holo.append({"id": id, "label": label, "factory": factory, "order": order})
	_holo.sort_custom(func(a, b): return a.order < b.order)
	holo_channels_changed.emit()


func unregister_holo_channel(id: String) -> void:
	var before := _holo.size()
	_holo = _holo.filter(func(c): return c.id != id)
	if _holo.size() != before:
		holo_channels_changed.emit()


func holo_channels() -> Array[Dictionary]:
	return _holo.duplicate()


func holo_channel(id: String) -> Dictionary:
	for c in _holo:
		if c.id == id:
			return c
	return {}


## Opens the wrist screen on a channel.
func open_holo(channel: String = "") -> void:
	holo_requested.emit(channel)


var _readouts: Array[Dictionary] = []


## A short text for the wrist screen's header, read each time the header refreshes.
func register_holo_readout(id: String, getter: Callable, order: int = 0) -> void:
	unregister_holo_readout(id)
	_readouts.append({"id": id, "getter": getter, "order": order})
	_readouts.sort_custom(func(a, b): return a.order < b.order)


func unregister_holo_readout(id: String) -> void:
	_readouts = _readouts.filter(func(r): return r.id != id)


## The readouts' texts now, in order.
func holo_readouts() -> PackedStringArray:
	var out := PackedStringArray()
	for r in _readouts:
		var v: Variant = r.getter.call() if r.getter.is_valid() else ""
		if str(v) != "":
			out.append(str(v))
	return out


var _sections: Array[Dictionary] = []


## Adds a section to another module's channel (see the header). `factory` builds a Control
## and, like a channel's, may take one argument: true on the wrist screen's glass.
func register_holo_section(channel: String, id: String, label: String, factory: Callable, order: int = 0) -> void:
	unregister_holo_section(channel, id)
	_sections.append({"channel": channel, "id": id, "label": label, "factory": factory, "order": order})
	_sections.sort_custom(func(a, b): return a.order < b.order)
	holo_sections_changed.emit(channel)


func unregister_holo_section(channel: String, id: String) -> void:
	var before := _sections.size()
	_sections = _sections.filter(func(c): return not (c.channel == channel and c.id == id))
	if _sections.size() != before:
		holo_sections_changed.emit(channel)


## The sections other modules added to `channel`, in order.
func holo_sections(channel: String) -> Array[Dictionary]:
	return _sections.filter(func(c): return c.channel == channel)


var _infos: Array[Dictionary] = []


## Puts up or updates an info card (see the header); `order` sorts the cards, low on top.
func set_info(id: String, title: String, text: String = "", order: int = 0) -> void:
	for c in _infos:
		if c.id == id:
			if c.title == title and c.text == text and c.order == order:
				return
			c.title = title
			c.text = text
			c.order = order
			_infos.sort_custom(func(a, b): return a.order < b.order)
			info_changed.emit()
			return
	_infos.append({"id": id, "title": title, "text": text, "order": order})
	_infos.sort_custom(func(a, b): return a.order < b.order)
	info_changed.emit()


func clear_info(id: String) -> void:
	var before := _infos.size()
	_infos = _infos.filter(func(c): return c.id != id)
	if _infos.size() != before:
		info_changed.emit()


## The cards up now, in order: {id, title, text, order}.
func infos() -> Array[Dictionary]:
	return _infos.duplicate(true)


## How far the view's ray looks for something to hint about, m.
const LOOK_REACH := 4.0
var _look: Array[Dictionary] = []


func register_look_hint(id: String, provider: Callable, order: int = 0) -> void:
	unregister_look_hint(id)
	_look.append({"id": id, "provider": provider, "order": order})
	_look.sort_custom(func(a, b): return a.order < b.order)


func unregister_look_hint(id: String) -> void:
	_look = _look.filter(func(c): return c.id != id)


## The registered providers in order: {id, provider, order}.
func look_hinters() -> Array[Dictionary]:
	return _look.duplicate()


## The hint for a ray hit: the first provider with one, else the collider's (or a parent's)
## look_hint() or meta "look_hint"; {} for none.
func look_hint_for(hit: Dictionary) -> Dictionary:
	for c in _look:
		var p: Callable = c.provider
		if not p.is_valid():
			continue
		var h: Variant = p.call(hit)
		if h is Dictionary and not (h as Dictionary).is_empty():
			return h
	var n := hit.get("collider") as Node
	while n != null:
		if n.has_method("look_hint"):
			var h: Variant = n.call("look_hint")
			if h is Dictionary and not (h as Dictionary).is_empty():
				return h
		if n.has_meta("look_hint"):
			return n.get_meta("look_hint")
		n = n.get_parent()
	return {}


var _pointer: Dictionary = {}


## Says a screen is using the mouse (see the header). Claims nest by id.
func claim_pointer(id: String) -> void:
	var was := pointer_claimed()
	_pointer[id] = true
	if not was:
		pointer_changed.emit(true)


func release_pointer(id: String) -> void:
	if not _pointer.erase(id):
		return
	if not pointer_claimed():
		pointer_changed.emit(false)


## True while any screen has the mouse: don't capture it, look around or use tools on clicks.
## `except`: a claim of your own that doesn't count.
func pointer_claimed(except := "") -> bool:
	return _pointer.size() > (1 if _pointer.has(except) else 0)
