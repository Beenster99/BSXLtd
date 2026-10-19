extends Node
## Main menu entry registry (autoload `Menu`). A module adds its own entry, pointing at a
## Router scene id; the UI module's main menu lists them in order.
##   Menu.register_entry("new_job", "New job", "workshop", 10)

signal entries_changed

var _entries: Array[Dictionary] = []


func register_entry(id: String, label: String, scene_id: String, order: int = 0) -> void:
	_entries = _entries.filter(func(e): return e.id != id)
	_entries.append({"id": id, "label": label, "scene": scene_id, "order": order})
	_entries.sort_custom(func(a, b): return a.order < b.order)
	entries_changed.emit()


func entries() -> Array[Dictionary]:
	return _entries.duplicate()
