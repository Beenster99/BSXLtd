extends Node
## Main menu entry registry (autoload `Menu`). A module adds its own entry, pointing at a
## Router scene id; the UI module's main menu lists them in order.
##   Menu.register_entry("new_job", "New job", "workshop", 10)
## `args` are handed to the scene through Router.args, so several entries can open one scene
## set up differently. Entries with the same `group` are listed together under that heading
## (one bench, a button per trade):
##   Menu.register_entry("bench_welding", "Welding", "workbench", 12, {"trade": "welding"}, "Workbench")
##
## Settings pages: each is a button on the Settings menu that opens the page. A module adds
## a page of its own, or a section to someone else's (UI owns "character", the player's
## profile: name, level, payslips...). Factories build a Control; they're called with no
## arguments, so the same one can serve the wrist screen if it takes `glass := false`.
##   Menu.register_settings_page("business.company", "Company", func() -> Control: ..., 20)
##   Menu.register_settings_section(Menu.CHARACTER, "business.payslips", "Payslips", factory, 30)

signal entries_changed
## Asks UI's pause menu to open (Esc in a game). Scenes call Menu.open_pause() on Esc when
## nothing of theirs is open, instead of leaving for the main menu.
signal pause_requested
signal settings_pages_changed
signal settings_sections_changed(page: String)

## The player's profile page in Settings (UI's); modules add sections to it.
const CHARACTER := "character"

var _entries: Array[Dictionary] = []
var _start: Dictionary = {}


## Where "Start" on the main menu goes: the game itself (the yard). The highest priority wins,
## so one module owns it without the menu naming any module.
##   Menu.set_start("ship_bay.shipyard", 10)
func set_start(scene_id: String, priority: int = 0, args: Dictionary = {}) -> void:
	if not _start.is_empty() and int(_start.priority) > priority and _start.scene != scene_id:
		return
	_start = {"scene": scene_id, "priority": priority, "args": args.duplicate()}
	entries_changed.emit()


func clear_start(scene_id: String) -> void:
	if _start.get("scene", "") == scene_id:
		_start = {}
		entries_changed.emit()


## {scene, priority, args}, or {} while nothing set a start.
func start() -> Dictionary:
	return _start.duplicate()


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


var _pages: Array[Dictionary] = []
var _sections: Array[Dictionary] = []


## A page on the Settings menu. `factory` may be an empty Callable for a page of sections only.
func register_settings_page(id: String, label: String, factory: Callable = Callable(), order: int = 0) -> void:
	_pages = _pages.filter(func(p): return p.id != id)
	_pages.append({"id": id, "label": label, "factory": factory, "order": order})
	_pages.sort_custom(func(a, b): return a.order < b.order)
	settings_pages_changed.emit()


func unregister_settings_page(id: String) -> void:
	var before := _pages.size()
	_pages = _pages.filter(func(p): return p.id != id)
	if _pages.size() != before:
		settings_pages_changed.emit()


func settings_pages() -> Array[Dictionary]:
	return _pages.duplicate()


## {id, label, factory, order}, or {} if there is no such page.
func settings_page(id: String) -> Dictionary:
	for p in _pages:
		if p.id == id:
			return p
	return {}


## A section on a Settings page, shown under the page's own controls in `order`. The page
## needn't exist yet; the section shows once it does.
func register_settings_section(page: String, id: String, label: String, factory: Callable, order: int = 0) -> void:
	_sections = _sections.filter(func(c): return not (c.page == page and c.id == id))
	_sections.append({"page": page, "id": id, "label": label, "factory": factory, "order": order})
	_sections.sort_custom(func(a, b): return a.order < b.order)
	settings_sections_changed.emit(page)


func unregister_settings_section(page: String, id: String) -> void:
	var before := _sections.size()
	_sections = _sections.filter(func(c): return not (c.page == page and c.id == id))
	if _sections.size() != before:
		settings_sections_changed.emit(page)


func settings_sections(page: String) -> Array[Dictionary]:
	return _sections.filter(func(c): return c.page == page)


## Opens the pause menu (Resume, Save, Main menu, Quit) over the game. See pause_requested.
func open_pause() -> void:
	pause_requested.emit()
