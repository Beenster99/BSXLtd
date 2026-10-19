class_name SharedComponentsBus
extends Node
## Shared Components module bus (Modules.bus("shared_components")): the ship parts BSX and
## Void Salvage share, and how BSX fits each one. Read-only at runtime, so nothing here is
## synced over the network; peers compare `source_commit` and `specs_version` when joining.
## Shapes and joints come from Void Salvage's own code in res://shared/void_salvage/.

const SPECS_DIR := "res://modules/shared_components/internal/specs"
const FASTENERS_DIR := "res://modules/shared_components/internal/fasteners"
const SHIP_MODULES_DIR := "res://modules/shared_components/internal/ship_modules"
## Ship classes a module may fit, smallest first.
const SHIP_CLASSES: PackedStringArray = ["S", "M", "L", "XL"]
const SOURCE_COMMIT_FILE := "res://shared/void_salvage/SOURCE_COMMIT"

## The shape builders a BuildSpec may name. Each takes its spec's shape_args in order.
const SHAPES: PackedStringArray = [
	"PartShapes.box", "PartShapes.chamfer_box", "PartShapes.girder",
	"WreckParts.ion_thruster", "WreckParts.tank", "WreckParts.junction_box",
]

## The Void Salvage commit the shared code was copied from ("" if it never was).
var source_commit := ""
## The highest BuildSpec schema version in the library.
var specs_version := 0

var _specs: Dictionary = {}
var _fasteners: Dictionary = {}
var _ship_modules: Dictionary = {}


func register_module() -> void:
	reload()


## Reads every spec and fastener again (tests and tools; the game reads once at boot).
func reload() -> void:
	_specs = {}
	_fasteners = {}
	_ship_modules = {}
	specs_version = 0
	source_commit = ""
	if FileAccess.file_exists(SOURCE_COMMIT_FILE):
		source_commit = FileAccess.get_file_as_string(SOURCE_COMMIT_FILE).strip_edges()
	for res in _load_dir(FASTENERS_DIR):
		var f := res as FastenerSpec
		if f:
			_fasteners[f.id] = f
	for res in _load_dir(SHIP_MODULES_DIR):
		var m := res as ShipModuleSpec
		if m:
			_ship_modules[m.id] = m
	for res in _load_dir(SPECS_DIR):
		var s := res as BuildSpec
		if s:
			_specs[s.part_name] = s
			specs_version = maxi(specs_version, s.version)


## How BSX fits this part, or null if BSX can't fit it yet.
func build_spec(part_name: String) -> BuildSpec:
	return _specs.get(part_name)


func is_buildable(part_name: String) -> bool:
	return _specs.has(part_name)


## Every part BSX can fit, optionally only one category's, sorted by part name.
func part_names(category := "") -> PackedStringArray:
	var out := PackedStringArray()
	for n: String in _specs:
		if category == "" or (_specs[n] as BuildSpec).category == category:
			out.append(n)
	out.sort()
	return out


func fastener(id: String) -> FastenerSpec:
	return _fasteners.get(id)


func fastener_ids() -> PackedStringArray:
	var out := PackedStringArray(_fasteners.keys())
	out.sort()
	return out


## Every Void Salvage material id ("steel", "alloy", ...), lowest tier first.
func material_ids() -> PackedStringArray:
	var ids: Array = Materials.TABLE.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return Materials.tier(a) < Materials.tier(b) or (Materials.tier(a) == Materials.tier(b) and a < b))
	var out := PackedStringArray(ids)
	return out


func is_material(id: String) -> bool:
	return Materials.TABLE.has(id)


## A ship upgrade by id ("attractor_coil_1"), or null if there is no such module.
func ship_module(id: String) -> ShipModuleSpec:
	return _ship_modules.get(id)


func is_ship_module(id: String) -> bool:
	return _ship_modules.has(id)


## Every module id, optionally only those a ship class ("S", "M", "L", "XL") takes, sorted.
func ship_module_ids(ship_class := "") -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in _ship_modules:
		if ship_class == "" or (_ship_modules[id] as ShipModuleSpec).fits.has(ship_class):
			out.append(id)
	out.sort()
	return out


## The part's mesh and collision from Void Salvage's builders, or null for an unknown part
## or builder.
func make_shape(part_name: String) -> PartShapes.PartShape:
	var s := build_spec(part_name)
	return null if s == null else shape_for(s)


static func shape_for(s: BuildSpec) -> PartShapes.PartShape:
	var a := s.shape_args
	match s.shape:
		"PartShapes.box":
			return PartShapes.box(a[0])
		"PartShapes.chamfer_box":
			return PartShapes.chamfer_box(a[0], a[1])
		"PartShapes.girder":
			return PartShapes.girder(a[0], a[1], a[2])
		"WreckParts.ion_thruster":
			return WreckParts.ion_thruster(a[0], a[1])
		"WreckParts.tank":
			return WreckParts.tank(a[0], a[1])
		"WreckParts.junction_box":
			return WreckParts.junction_box(a[0])
	return null


func _load_dir(dir: String) -> Array[Resource]:
	var out: Array[Resource] = []
	for file in ResourceLoader.list_directory(dir):
		if file.ends_with(".tres"):
			out.append(load(dir.path_join(file)))
	return out
