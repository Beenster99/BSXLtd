extends Node
## Scene router (autoload `Router`). Modules register scenes by id; anyone moves between
## them by id, so no module preloads another module's scene.
##   Router.register_scene("main_menu", "res://modules/ui/internal/main_menu.tscn")
##   Router.goto("main_menu")
##   Router.goto("workbench", {"trade": "welding"})   # the scene reads Router.args
##
## The loading screen (flag "core.loading_screen"): a scene that takes a while to be ready
## gives itself a title, and the player's way into it uses goto_loading(), which covers the
## window from before the build until the scene is ready to play (LoadingScreen's header).
## Tools, tests and screenshots keep using goto(), which never shows it.
##   Router.set_loading_title("yard.station", "Orbital yard")
##   Router.goto_loading("yard.station")
## While it is up, the scene and any module can hold it with work of their own, keyed:
##   if Router.is_loading(): Router.hold_loading("graphics.gi", "Lighting the rooms...")
##   Router.loading_progress("graphics.gi", 0.5)
##   Router.release_loading("graphics.gi")
## Holds made while it is not up are ignored, so call them freely.

const LoadingScreen := preload("res://modules/core/api/loading_screen.gd")
const LOADING_FLAG := "core.loading_screen"

signal scene_changed(id: String)
## The loading screen went away: the scene is ready to play.
signal loading_finished

var current_id := ""
## What the last goto() was asked to open the scene with; read it in the scene's _ready().
var args: Dictionary = {}
var _scenes: Dictionary = {}
var _loading_titles: Dictionary = {}
var _screen: CanvasLayer
var _load_serial := 0
## Shows the loading screen even without a window (tests and timing runs).
var force_loading_screen := false


func _ready() -> void:
	_screen = LoadingScreen.new()
	_screen.name = "LoadingScreen"
	add_child(_screen)
	_screen.connect("finished", func() -> void: loading_finished.emit())


func register_scene(id: String, path: String) -> void:
	_scenes[id] = path


func has_scene(id: String) -> bool:
	return _scenes.has(id)


func scene_path(id: String) -> String:
	return _scenes.get(id, "")


func goto(id: String, scene_args: Dictionary = {}) -> Error:
	if not _scenes.has(id):
		push_error("Router: no scene registered as '%s'" % id)
		return ERR_DOES_NOT_EXIST
	args = scene_args.duplicate()
	var err := get_tree().change_scene_to_file(_scenes[id])
	if err == OK:
		current_id = id
		scene_changed.emit(id)
	return err


## Says scene `id` shows the loading screen, titled `title`, when the player goes in with
## goto_loading().
func set_loading_title(id: String, title: String) -> void:
	_loading_titles[id] = title


## The player's way into a scene: like goto(), behind the loading screen when the scene has
## a loading title (and the flag is on, and there is a window). The scene changes a couple of
## frames later, once the screen is drawn.
func goto_loading(id: String, scene_args: Dictionary = {}) -> Error:
	if not _scenes.has(id):
		push_error("Router: no scene registered as '%s'" % id)
		return ERR_DOES_NOT_EXIST
	if not _wants_screen(id):
		return goto(id, scene_args)
	_load_serial += 1
	var serial := _load_serial
	_screen.call("begin", str(_loading_titles[id]))
	_change_after_drawn.call_deferred(id, scene_args.duplicate(), serial)
	return OK


## True while the loading screen is waiting on the scene (the controls are held meanwhile).
func is_loading() -> bool:
	return bool(_screen.get("active"))


## Holds the loading screen up for work `key` still has to do ("Lighting the rooms...").
func hold_loading(key: String, label: String = "") -> void:
	_screen.call("hold", key, label)


## How far `key`'s work has got (0..1); `label` changes what the screen says, if given.
func loading_progress(key: String, fraction: float, label: String = "") -> void:
	_screen.call("progress", key, fraction, label)


## `key`'s work is done.
func release_loading(key: String) -> void:
	_screen.call("release", key)


func is_holding_loading(key: String) -> bool:
	return bool(_screen.call("holding", key))


func _wants_screen(id: String) -> bool:
	return _loading_titles.has(id) and Flags.is_on(LOADING_FLAG) \
			and (DisplayServer.get_name() != "headless" or force_loading_screen)


func _change_after_drawn(id: String, scene_args: Dictionary, serial: int) -> void:
	# Two drawn frames, so the screen is up before the build holds the window.
	for i in 2:
		await (RenderingServer.frame_post_draw if DisplayServer.get_name() != "headless" else get_tree().process_frame)
	if serial != _load_serial:
		return
	if goto(id, scene_args) != OK:
		_screen.call("release_all")
		return
	# change_scene_to_file builds the scene at the end of this frame.
	await get_tree().process_frame
	await get_tree().process_frame
	if serial == _load_serial:
		_screen.call("scene_built")
