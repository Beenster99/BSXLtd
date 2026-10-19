class_name WeldingRules
extends Resource
## Pass marks for welded seams (internal/data/welding_rules.tres).

@export var version := 1
## Travel speed, torch angle and arc length: the average distance of the samples from
## target earns full marks within full_pct percent, nothing at zero_pct.
@export var steady_full_pct := 10.0
@export var steady_zero_pct := 40.0
## Coverage (share of seam welded): full at coverage_full, nothing at coverage_zero, and
## a joint with less than coverage_fail welded fails (a gap in a pressure seam leaks).
@export var coverage_full := 0.98
@export var coverage_zero := 0.8
@export var coverage_fail := 0.9
## Penetration (1.0 = required depth): full at 1.0, nothing at penetration_zero, and under
## penetration_fail fails (lack of fusion).
@export var penetration_zero := 0.6
@export var penetration_fail := 0.7

@export var weight_speed := 20.0
@export var weight_angle := 15.0
@export var weight_arc := 15.0
@export var weight_coverage := 25.0
@export var weight_penetration := 25.0

@export var pass_score := 70
@export var marginal_score := 50
