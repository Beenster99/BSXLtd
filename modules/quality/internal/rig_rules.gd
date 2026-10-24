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
	"field_emitter": {
		1: {"attract_reach": 1.15, "attract_speed": 1.1},
		2: {"attract_reach": 1.3, "attract_speed": 1.25},
		3: {"attract_reach": 1.5, "attract_speed": 1.4},
	},
}
## A stock unit's figures before any add-ons, by unit id (stand-in for the shared library's
## unit designs; a request's own `base` wins). Mass in kg, as Void Salvage's attract_max_mass.
@export var base_figures: Dictionary = {
	"attractor_coil_1": {"attract_reach": 18.0, "attract_max_mass": 8000.0, "attract_speed": 5.0},
}
## Tools' mount names for a fitted add-on that came without a part id.
@export var mount_parts: Dictionary = {"core": "quantum_core", "emitter": "field_emitter", "board": "control_board"}
## A unit joint's quality (0..1 from Tools) as a grade: PASS from pass_score, MARGINAL from
## marginal_score, FAIL below (the same marks as ship joints).
@export var pass_score := 70
@export var marginal_score := 50
## Parts that let a tier 3 add-on run without overheating. Empty: no overheat check (U1 has
## no heat exchanger; U2 adds it).
@export var coolers: PackedStringArray = []
## How much of the rated gain the unit reaches: floor + slope * (mean joint score / 100).
## 100 -> 1.05 (beats the rating), 90 -> 1.0, 70 -> 0.92, 50 -> 0.83.
@export var efficiency_floor := 0.6
@export var efficiency_slope := 0.45
## The sweep passes when the unit reaches this share of the rated gain.
@export var pass_efficiency := 0.9
## A plate's serial prefix.
@export var serial_prefix := "BSX-U-"
