extends Node
## First scene. Waits for Modules to load, then hands over to the main menu (registered by
## the UI module) by id, so Core never references UI.

const FIRST_SCENE := "main_menu"


func _ready() -> void:
	if not Modules.ready_done:
		await Modules.modules_ready
	if Router.has_scene(FIRST_SCENE):
		Router.goto(FIRST_SCENE)
	else:
		push_error("Boot: nothing registered '%s'; is the ui flag on?" % FIRST_SCENE)
