class_name ProgressionPerk
extends Resource
## A bonus a skill grants from a level up: `effect_key` is a number the owning module reads
## (Trades reads "torque_tolerance", say), and `value` is added to it.

@export var level := 1
@export var effect_key: StringName = &""
@export var value := 0.0
