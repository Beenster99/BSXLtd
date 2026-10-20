extends Node
## Save and load (autoload `Saves`). One file per slot, one section per module, each with
## its own schema version:
##   {"game_version": "0.1.0", "sections": {"trades": {"version": 2, "data": {...}}}}
##
## A module registers a provider: any object with
##   save_version() -> int
##   save_data() -> Dictionary
##   load_data(data: Dictionary, from_version: int) -> void   # migrates older versions itself
## Sections with no provider (a module switched off) are kept as they were and written back,
## so switching a module off never loses its data.
##
## Games: the player's saved games are slots too. new_game(name) resets every module (a
## provider's optional reset_data(), else load_data({}, save_version())) and makes a fresh
## slot the current game; continue_game(slot) loads one; while a game is current it saves
## itself every AUTOSAVE_SECONDS, on going back to the main menu and when the window closes.
## games() lists them newest first for the menu; delete(slot) removes one.

signal saved(slot: String)
signal loaded(slot: String)
signal game_started(slot: String, is_new: bool)
signal deleted(slot: String)

const DIR := "user://saves"
const FORMAT := 1
const AUTOSAVE_SECONDS := 60.0
## Router scene ids where autosave holds off and which count as "back at the menu".
const MENU_SCENES := ["main_menu", "settings", "boot", ""]

var _providers: Dictionary = {}
var _kept: Dictionary = {}
## The slot of the game being played, "" at the menu before one is picked.
var current_slot := ""
var current_name := ""
var _created_at := 0
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = AUTOSAVE_SECONDS
	_timer.timeout.connect(_autosave)
	add_child(_timer)
	_timer.start()
	var router := get_node_or_null("/root/Router")
	if router:
		router.scene_changed.connect(_on_scene_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_autosave()


func register_section(module_id: String, provider: Object) -> void:
	for method in ["save_version", "save_data", "load_data"]:
		assert(provider.has_method(method), "Saves: %s provider lacks %s()" % [module_id, method])
	_providers[module_id] = provider


func unregister_section(module_id: String) -> void:
	_providers.erase(module_id)


func path_for(slot: String) -> String:
	return "%s/%s.json" % [DIR, slot]


func exists(slot: String) -> bool:
	return FileAccess.file_exists(path_for(slot))


func save(slot: String) -> Error:
	DirAccess.make_dir_recursive_absolute(DIR)
	var sections := _kept.duplicate(true)
	for id in _providers:
		var p: Object = _providers[id]
		sections[id] = {"version": p.save_version(), "data": p.save_data()}
	var doc := {
		"format": FORMAT,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"saved_at": int(Time.get_unix_time_from_system()),
		"sections": sections,
	}
	if slot == current_slot:  # a player's game: the menu lists it by these
		doc["name"] = current_name
		doc["created_at"] = _created_at
	elif exists(slot):  # saving over another game keeps its name
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(path_for(slot)))
		if old is Dictionary and old.has("name"):
			doc["name"] = old.name
			doc["created_at"] = old.get("created_at", 0)
	var f := FileAccess.open(path_for(slot), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	saved.emit(slot)
	return OK


func load_slot(slot: String) -> Error:
	if not exists(slot):
		return ERR_FILE_NOT_FOUND
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(path_for(slot)))
	if not doc is Dictionary or not doc.get("sections") is Dictionary:
		return ERR_PARSE_ERROR
	_kept = {}
	var sections: Dictionary = doc["sections"]
	for id in sections:
		var section: Dictionary = sections[id]
		if _providers.has(id):
			_providers[id].load_data(section.get("data", {}), int(section.get("version", 0)))
		else:
			_kept[id] = section
	loaded.emit(slot)
	return OK


## Starts a fresh game called `game_name`: every module back to its new-game state, a new
## slot written at once so it shows in the list. Returns the slot.
func new_game(game_name: String) -> String:
	var clean := game_name.strip_edges()
	if clean == "":
		clean = "Yard %d" % (games().size() + 1)
	_kept = {}
	for id in _providers:
		var p: Object = _providers[id]
		if p.has_method("reset_data"):
			p.reset_data()
		else:
			p.load_data({}, p.save_version())
	current_slot = _free_slot(clean)
	current_name = clean
	_created_at = int(Time.get_unix_time_from_system())
	save(current_slot)
	game_started.emit(current_slot, true)
	return current_slot


## Loads a saved game and makes it the current one.
func continue_game(slot: String) -> Error:
	var err := load_slot(slot)
	if err == OK:
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path_for(slot)))
		current_slot = slot
		current_name = str(doc.get("name", slot))
		_created_at = int(doc.get("created_at", doc.get("saved_at", 0)))
		game_started.emit(slot, false)
	return err


## Saved games, newest first: [{slot, name, saved_at, created_at, game_version}].
func games() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var slot := file.trim_suffix(".json")
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(path_for(slot)))
		if not doc is Dictionary or not doc.has("name"):
			continue  # not a player's game (tests, old files)
		out.append({"slot": slot, "name": str(doc.name), "saved_at": int(doc.get("saved_at", 0)),
				"created_at": int(doc.get("created_at", 0)), "game_version": str(doc.get("game_version", ""))})
	out.sort_custom(func(a, b): return a.saved_at > b.saved_at)
	return out


## Deletes a saved game. Deleting the current one leaves no game current.
func delete(slot: String) -> Error:
	if not exists(slot):
		return ERR_FILE_NOT_FOUND
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path_for(slot)))
	if err == OK:
		if slot == current_slot:
			current_slot = ""
			current_name = ""
		deleted.emit(slot)
	return err


## Leaves the current game (after saving it); the menu shows no game as current.
func close_game() -> void:
	_autosave()
	current_slot = ""
	current_name = ""


func _free_slot(game_name: String) -> String:
	var base := game_name.to_lower().validate_filename().replace(" ", "_")
	if base == "":
		base = "game"
	var slot := base
	var n := 2
	while exists(slot):
		slot = "%s_%d" % [base, n]
		n += 1
	return slot


func _autosave() -> void:
	if current_slot == "":
		return
	var router := get_node_or_null("/root/Router")
	if router and str(router.current_id) in MENU_SCENES and router.current_id != "":
		return  # nothing has changed since leaving the game
	save(current_slot)


func _on_scene_changed(id: String) -> void:
	# Back at the menu from a game: save what was played.
	if id in MENU_SCENES and current_slot != "":
		save(current_slot)
