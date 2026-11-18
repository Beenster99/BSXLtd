class_name DesignBus
extends Node
## The Design Room module's bus (Modules.bus("design")): the ship designs the crew draws up
## in the design room, and the views onto them (plans, the holotable, the walls).
##
## Other modules read designs through here:
##   var bus := Modules.bus("design") as DesignBus
##   bus.library.list()                 # saved designs
##   bus.library.current                # the open DesignRecord (or null)
##   bus.totals()                       # DesignTotals of the open design (parts list, cost...)
##   bus.problems()                     # DesignRules.check of the open design
##   bus.design_changed.connect(...)    # any edit, open or save
##
## Features (Flags): "design" (the module: designs in the save), "design.room" (the design
## room scene and its menu entry, off until the room is ready to play at test point 2).

signal design_changed

const SAVE_SECTION := "design"
const ROOM_SCENE := "design.room"
const ROOM_FLAG := "design.room"

var catalog: DesignCatalog = DesignCatalog.load_default()
var library := DesignLibrary.new()
var editor := DesignEditor.new(library)


func _init() -> void:
	library.opened.connect(func(_r: DesignRecord) -> void: design_changed.emit())
	library.edited.connect(func(_op: Dictionary) -> void: design_changed.emit())
	library.list_changed.connect(func() -> void: design_changed.emit())


const ROOM_PATH := "res://modules/design/internal/room/design_room.tscn"
const Samples := preload("res://modules/design/internal/sample_designs.gd")
const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")


func register_module() -> void:
	Saves.register_section(SAVE_SECTION, library)
	if Flags.is_on(ROOM_FLAG):
		Router.register_scene(ROOM_SCENE, ROOM_PATH)
		Menu.register_entry(ROOM_SCENE, "Design room", ROOM_SCENE, 30)
		Shots.register("design_console", ROOM_SCENE, _shot_setup.bind(false), 40)
		Shots.register("design_room", ROOM_SCENE, _shot_setup.bind(true), 40)
		Menu.register_settings_section(Menu.DEBUG, "design.debug", "Design room",
				_debug_panel, 30)
		# The station is optional (its module may be off), so it is reached by name only,
		# once every module has registered.
		if Modules.ready_done:
			_hook_yard()
		else:
			Modules.modules_ready.connect(_hook_yard, CONNECT_ONE_SHOT)


func _hook_yard() -> void:
	var yard := Modules.bus("yard")
	if yard and yard.has_signal("station_ready") and not yard.is_connected("station_ready", furnish_station):
		yard.connect("station_ready", furnish_station)


## The design room's wall planes: the station's (the yard module's design_room_walls), or
## the stand-in planes (the same ids and convention) while it has none.
func room_walls() -> Array[Dictionary]:
	var yard := Modules.bus("yard")
	if yard and yard.has_method("design_room_walls"):
		var out: Array[Dictionary] = []
		out.assign(yard.call("design_room_walls"))
		if not out.is_empty():
			return out
	return Furnishing.stand_in_walls()


## Puts the holotable, the interactive walls and the console into the station's design room.
func furnish_station(_station: Node3D = null) -> void:
	var yard := Modules.bus("yard")
	var root: Node3D = yard.call("design_room_root") if yard and yard.has_method("design_room_root") else null
	if root == null or root.has_node("DesignFurnishing"):
		return
	var f: Node3D = Furnishing.new()
	root.add_child(f)
	f.call("setup", self, room_walls())


func unregister_module() -> void:
	Saves.unregister_section(SAVE_SECTION)
	Menu.unregister_entry(ROOM_SCENE)
	Menu.unregister_settings_section(Menu.DEBUG, "design.debug")


## Opens a new design holding the sample skiff (Debug tab, tests, screenshots).
func open_sample() -> DesignRecord:
	var rec := library.create("Sample skiff")
	Samples.skiff(rec)
	library.save_current()
	return rec


func _shot_setup(scene: Node, room_view: bool) -> void:
	open_sample()
	if scene.has_method("set_room_view"):
		scene.set_room_view(room_view)


func _debug_panel() -> Control:
	var b := Button.new()
	b.text = "Open the sample skiff"
	b.pressed.connect(func() -> void: open_sample())
	return b


## The open design's numbers, or null with nothing open.
func totals() -> DesignTotals:
	return DesignTotals.compute(library.current, catalog) if library.current else null


## The open design's problems ([] with nothing open).
func problems() -> Array[Dictionary]:
	if library.current == null:
		return []
	return DesignRules.check(library.current, catalog)
