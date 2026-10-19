extends Node
## Scene router (autoload `Router`). Modules register scenes by id; anyone moves between
## them by id, so no module preloads another module's scene.
##   Router.register_scene("main_menu", "res://modules/ui/internal/main_menu.tscn")
##   Router.goto("main_menu")

signal scene_changed(id: String)

var current_id := ""
var _scenes: Dictionary = {}


func register_scene(id: String, path: String) -> void:
	_scenes[id] = path


func has_scene(id: String) -> bool:
	return _scenes.has(id)


func scene_path(id: String) -> String:
	return _scenes.get(id, "")


func goto(id: String) -> Error:
	if not _scenes.has(id):
		push_error("Router: no scene registered as '%s'" % id)
		return ERR_DOES_NOT_EXIST
	var err := get_tree().change_scene_to_file(_scenes[id])
	if err == OK:
		current_id = id
		scene_changed.emit(id)
	return err
