class_name RigRules
extends Resource
## How the rig tests score an upgraded unit. Tuning lives in internal/data/rig_rules.tres.
## `gains` is a stand-in for the shared upgrade rules file (Shared Components, U1): a
## request that carries its own `rated` figures uses those instead.

@export var version := 1
## part -> tier (1..3) -> {stat: multiplier on the base figure}. Multipliers stack.
@export var gains: Dictionary = {
	"quantum_core": {
		1: {"attract_max_mass": 1.5, "attract_reach": 1.1},
		2: {"attract_max_mass": 2.5, "attract_reach": 1.2},
		3: {"attract_max_mass": 4.0, "attract_reach": 1.35},
	},
	"field_emitter_array": {
		1: {"attract_reach": 1.15, "attract_speed": 1.1},
		2: {"attract_reach": 1.3, "attract_speed": 1.25},
		3: {"attract_reach": 1.5, "attract_speed": 1.4},
	},
}
## Parts that let a tier 3 add-on run without overheating.
@export var coolers: PackedStringArray = ["heat_exchanger"]
## How much of the rated gain the unit reaches: floor + slope * (mean joint score / 100).
## 100 -> 1.05 (beats the rating), 90 -> 1.0, 70 -> 0.92, 50 -> 0.83.
@export var efficiency_floor := 0.6
@export var efficiency_slope := 0.45
## The sweep passes when the unit reaches this share of the rated gain.
@export var pass_efficiency := 0.9
## A plate's serial prefix.
@export var serial_prefix := "BSX-U-"
