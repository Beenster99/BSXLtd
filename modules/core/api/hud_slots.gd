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

signal panels_changed
signal holo_channels_changed
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
