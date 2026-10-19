extends Node
## Main menu entry registry (autoload `Menu`). A module adds its own entry, pointing at a
## Router scene id; the UI module's main menu lists them in order.
##   Menu.register_entry("new_job", "New job", "workshop", 10)
## `args` are handed to the scene through Router.args, so several entries can open one scene
## set up differently. Entries with the same `group` are listed together under that heading
## (one bench, a button per trade):
##   Menu.register_entry("bench_welding", "Welding", "workbench", 12, {"trade": "welding"}, "Workbench")

signal entries_changed

var _entries: Array[Dictionary] = []


func register_entry(id: String, label: String, scene_id: String, order: int = 0,
		args: Dictionary = {}, group: String = "") -> void:
	_entries = _entries.filter(func(e): return e.id != id)
	_entries.append({"id": id, "label": label, "scene": scene_id, "order": order,
			"args": args.duplicate(), "group": group})
	_entries.sort_custom(func(a, b): return a.order < b.order)
	entries_changed.emit()


func entries() -> Array[Dictionary]:
	return _entries.duplicate()


func unregister_entry(id: String) -> void:
	_entries = _entries.filter(func(e): return e.id != id)
	entries_changed.emit()
