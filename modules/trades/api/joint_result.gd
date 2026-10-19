class_name JointResult
extends Resource
## What was actually built. Raw measurements only: Quality does the grading, so pass marks
## never live in Trades. Bolting keys: torque_nm, torque_target_nm, sequence, sequence_ok,
## cross_threaded, washer, fastener_ids, misalign_mm.

const VERSION := 1

@export var version := VERSION
@export var joint_id: StringName
@export var trade: StringName
@export var component_id: StringName
@export var mount_id: StringName
@export var measurements: Dictionary = {}
## The peer who finished the joint (1 when playing alone).
@export var peer_id := 1
## Unix seconds.
@export var time := 0
