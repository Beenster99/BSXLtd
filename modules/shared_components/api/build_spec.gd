class_name BuildSpec
extends Resource
## How BSX fits one Void Salvage part: the shape it is, the joints that hold it on, the order
## they go in, where a crane lifts it. Keyed by the part's Void Salvage part_name.
## One file per part in internal/specs/; read them through Modules.bus("shared_components").

## Schema version of this file.
@export var version := 1
## Void Salvage part_name ("IonThruster"): the part's id in both games.
@export var part_name := ""
## Shown to players.
@export var display_name := ""
## A Void Salvage PartCatalog category ("hull", "frame", "engines", ...).
@export var category := ""
## A Materials id ("steel", "alloy", ...).
@export var material := "steel"
## Kilograms.
@export var mass := 0.0
## Which shared builder makes its shape, and the builder's size arguments (metres).
## See SharedComponentsBus.make_shape for the builders it knows.
@export var shape := ""
@export var shape_args: Array = []
## The joints that hold it on, and the order they are made in (indexes into joints).
@export var joints: Array[PartJointSpec] = []
@export var order: PackedInt32Array = PackedInt32Array()
## Crane attach points, part space, metres.
@export var lift_points: PackedVector3Array = PackedVector3Array()
## For quoting: a crew's hours to fit it.
@export var hours := 0.0
