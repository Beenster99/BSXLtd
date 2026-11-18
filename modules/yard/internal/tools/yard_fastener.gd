class_name YardFastener
extends YardTool
## The tools that put joints in rather than take them out (0.4.0 playtest): the riveter sets
## rivets and the welder runs welds, where the work has them planned (YardWorkpiece.planned:
## a rivet's hole ringed in chalk, a weld's line chalked). Hold the trigger on one: its head rides
## out to it on the boom, the rivet's head swells or the bead runs along the line, and once it is
## in it is a joint like any other (the grinder or the cutter takes it out again).

## The kind of joint it puts in.
var fasten_kind: ConnectionData.Kind = ConnectionData.Kind.RIVET
## How much of one fastening it puts in a second (1 = one a second), Mk I.
@export var set_rate: float = 0.5
## How close to a planned spot (or a weld's line) the aim must land (m).
@export var plan_snap: float = 0.12
## Setting one now, and how far in it is (0..1): for its looks and sounds (the controller sets them).
var fastening := false
var progress: float = 0.0


func _init() -> void:
	rivet_rate = 0.0
	bolt_rate = 0.0
	weld_rate = 0.0
	connector_rate = 0.0
	spot_rate = 0.0


func _apply_mark(row: Dictionary) -> void:
	if not _base.has("set"):
		_base["set"] = set_rate
	set_rate = float(_base["set"]) * float(row["rate"])
