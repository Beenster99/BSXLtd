class_name DesignBus
extends Node
## The Design Room module's bus (Modules.bus("design")): the ship designs the crew draws up
## in the design room, and the views onto them (plans, the holotable, the TV channels).
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


func register_module() -> void:
	Saves.register_section(SAVE_SECTION, library)


func unregister_module() -> void:
	Saves.unregister_section(SAVE_SECTION)


## The open design's numbers, or null with nothing open.
func totals() -> DesignTotals:
	return DesignTotals.compute(library.current, catalog) if library.current else null


## The open design's problems ([] with nothing open).
func problems() -> Array[Dictionary]:
	if library.current == null:
		return []
	return DesignRules.check(library.current, catalog)
