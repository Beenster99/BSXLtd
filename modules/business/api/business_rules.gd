class_name BusinessRules
extends Resource
## Business balance numbers (internal/data/business_rules.tres). Money is in whole credits.

@export var version := 1
@export var starting_cash := 20000
@export var bay_rent_per_day := 400
## Share of a contract's value paid when BSX accepts it; the rest is paid at handover.
@export_range(0, 100) var deposit_percent := 30
@export var late_penalty_per_day := 250
## Late penalties on one contract stop growing at this share of its value.
@export_range(0, 100) var late_penalty_cap_percent := 25
## Reputation starts here and stays within 0-100.
@export var starting_reputation := 50.0
## Reputation gained at handover per point of quality above `quality_par` (quality is 0-1).
@export var rep_per_quality := 20.0
@export_range(0.0, 1.0) var quality_par := 0.6
@export var rep_per_late_day := 2.0
@export var rep_per_open_snag := 1.0
@export var rep_for_cancelling := 5.0
## Days the company may stay below zero cash before it goes insolvent.
@export var insolvency_grace_days := 5
## Game minutes that pass per real second while the yard is open (2 = a 12 minute day).
@export var game_minutes_per_second := 2.0
## The most a part's trade price swings from one day to the next, either way.
@export_range(0.0, 0.5) var daily_price_swing := 0.06
