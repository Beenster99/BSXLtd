extends Node
## HUD panel registry (autoload `Hud`). Modules register panels into named slots; the UI
## module's HUD draws whatever is registered, so Core and UI never know which modules exist.
##   Hud.register_panel("torque_readout", "res://modules/trades/internal/torque.tscn", Hud.TOOL_BELT)

signal panels_changed

const TOP_BAR := "top_bar"
const TOOL_BELT := "tool_belt"
const JOB_CARD := "job_card"
const NOTICES := "notices"
const SLOTS: PackedStringArray = [TOP_BAR, TOOL_BELT, JOB_CARD, NOTICES]

var _panels: Array[Dictionary] = []


func register_panel(id: String, scene_path: String, slot: String, order: int = 0) -> void:
	assert(slot in SLOTS, "Hud: unknown slot '%s'" % slot)
	unregister_panel(id)
	_panels.append({"id": id, "scene": scene_path, "slot": slot, "order": order})
	_panels.sort_custom(func(a, b): return a.order < b.order)
	panels_changed.emit()


func unregister_panel(id: String) -> void:
	_panels = _panels.filter(func(p): return p.id != id)


func panels_in(slot: String) -> Array[Dictionary]:
	return _panels.filter(func(p): return p.slot == slot)
