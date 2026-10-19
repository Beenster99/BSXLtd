class_name BoltingRules
extends Resource
## Pass marks for bolted joints. Tuning lives in internal/data/bolting_rules.tres so a
## "too strict" fix is a data change in this module, never a change to Trades.

@export var version := 1
## Torque within this many percent of target earns full marks for that hole...
@export var torque_full_pct := 5.0
## ...falling linearly to nothing at this many percent off.
@export var torque_zero_pct := 25.0
## Any hole this far over target fails the joint: the bolt has yielded.
@export var over_torque_fail_pct := 40.0

@export var weight_torque := 60.0
@export var weight_sequence := 15.0
@export var weight_fastener := 15.0
@export var weight_threads := 10.0

@export var pass_score := 70
@export var marginal_score := 50
