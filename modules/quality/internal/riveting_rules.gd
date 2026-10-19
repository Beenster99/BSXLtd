class_name RivetingRules
extends Resource
## Pass marks for riveted joints (internal/data/riveting_rules.tres).

@export var version := 1
## Formed head height and diameter: full marks within this many percent of target...
@export var head_full_pct := 10.0
## ...nothing at this many percent off.
@export var head_zero_pct := 30.0
## Hole clearance (hole minus shank): full marks up to this, nothing from hole_fit_zero_mm.
@export var hole_fit_full_mm := 0.15
@export var hole_fit_zero_mm := 0.4

@export var weight_head := 50.0
@export var weight_hole := 20.0
@export var weight_deburr := 15.0
@export var weight_seated := 15.0

@export var pass_score := 70
@export var marginal_score := 50
