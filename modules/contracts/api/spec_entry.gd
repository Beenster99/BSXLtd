class_name SpecEntry
extends Resource
## What one change must meet, per Void Salvage joint kind (ConnectionData.Kind): the part's
## library build data with the work order's overrides laid over it. Trades and Quality read
## it through ContractsBus.get_spec().
##   bolt:      torque_nm, pattern
##   rivet:     type, pitch_mm
##   weld:      type, inspection_class
##   connector: gauge_awg, colour, circuit

const JOINT_KINDS: PackedStringArray = ["bolt", "rivet", "weld", "connector"]

@export var change_id := ""
@export var component: ComponentRef
@export var bolt: Dictionary = {}
@export var rivet: Dictionary = {}
@export var weld: Dictionary = {}
@export var connector: Dictionary = {}


## The values for one joint kind ("bolt"...), empty if the spec sets none.
func for_kind(kind: String) -> Dictionary:
	match kind:
		"bolt":
			return bolt
		"rivet":
			return rivet
		"weld":
			return weld
		"connector":
			return connector
	return {}


## Lays a {kind: {key: value}} dictionary over this entry; later values win.
func apply(over: Dictionary) -> void:
	for kind in JOINT_KINDS:
		var d: Variant = over.get(kind)
		if d is Dictionary:
			var merged := for_kind(kind).duplicate()
			merged.merge(d, true)
			set(kind, merged)
