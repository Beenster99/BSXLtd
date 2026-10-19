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

signal saved(slot: String)
signal loaded(slot: String)

const DIR := "user://saves"
const FORMAT := 1

var _providers: Dictionary = {}
var _kept: Dictionary = {}


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
		"sections": sections,
	}
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
