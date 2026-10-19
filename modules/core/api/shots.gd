extends Node
## Screenshot points for the release tour (autoload `Shots`). A module registers the views
## worth showing; tools/screenshot_tour visits each one and saves a PNG, so the tour grows
## with the game.
##   Shots.register("bolting", "workbench", func(scene): scene.focus_tool("torque_wrench"))

var _shots: Array[Dictionary] = []


## setup (optional) is called with the loaded scene's root before the picture is taken.
func register(id: String, scene_id: String, setup: Callable = Callable(), settle_frames: int = 30) -> void:
	_shots = _shots.filter(func(s): return s.id != id)
	_shots.append({"id": id, "scene": scene_id, "setup": setup, "frames": settle_frames})


func all() -> Array[Dictionary]:
	return _shots.duplicate()
