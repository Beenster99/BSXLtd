class_name ModuleManifest
extends Resource
## modules/<id>/module.tres: what a module is and what it may touch. Read by Modules at boot
## and by tools/check_boundaries.py in CI, so it is the single source for dependencies.

@export var id := ""
@export var display_name := ""
@export var version := "0.0.0"
## Module ids this module may use (through their api/ folders only). Every module may use
## core/api and ui/api without listing them.
@export var depends_on: PackedStringArray = PackedStringArray()
## Flag that switches the module on; usually the id.
@export var flag := ""
## Script under api/ that Modules instances as the module's bus node (signals plus a
## register_module() hook). Reach it with Modules.bus("<id>").
@export var bus: Script
## The module's stand-alone test scene or script (see modules/core/api/testing).
@export_file var test_scene := ""
