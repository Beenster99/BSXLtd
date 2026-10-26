class_name ProgressionUpgrade
extends Resource
## A tool or yard upgrade the company buys (internal/data/upgrades/<id>.tres). Its price lives
## in Business under `price_ref`, so balance changes stay in one place.

enum Kind { TOOL, YARD }

@export var version := 1
@export var id: StringName = &""
@export var display_name := ""
@export var kind := Kind.TOOL
## The tool or yard feature it improves ("torque_wrench", "bay_crane").
@export var target_id: StringName = &""
## Upgrade ids that must be owned first.
@export var requires: PackedStringArray = PackedStringArray()
@export var price_ref: StringName = &""
@export var effect_key: StringName = &""
@export var value := 0.0
