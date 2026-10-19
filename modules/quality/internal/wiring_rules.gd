class_name WiringRules
extends Resource
## Pass marks for wiring runs (internal/data/wiring_rules.tres).

@export var version := 1
## Strip length: full marks within strip_full_mm of target, nothing at strip_zero_mm.
@export var strip_full_mm := 1.0
@export var strip_zero_mm := 3.0
## Crimp pull force as a fraction of the minimum: full at 1.0, nothing at crimp_zero.
@export var crimp_zero := 0.5
## Continuity: full at or under the maximum, nothing at continuity_zero times it.
@export var continuity_zero := 2.0
## Insulation resistance as a fraction of the minimum: full at 1.0, nothing at
## insulation_zero, and under insulation_fail fails (a short waiting to happen).
@export var insulation_zero := 0.5
@export var insulation_fail := 0.25

@export var weight_crimp := 35.0
@export var weight_strip := 15.0
@export var weight_continuity := 25.0
@export var weight_insulation := 15.0
@export var weight_polarity := 10.0

@export var pass_score := 70
@export var marginal_score := 50
