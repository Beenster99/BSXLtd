class_name JointSpec
extends Resource
## What a joint should be: the trade and, for bolting, the fastener, torque and order.
## Comes from Shared Components build data once that exists; the bench uses its own copy.

const VERSION := 1

@export var version := VERSION
## BOLT, RIVET, WELD, WIRE or FIT.
@export var trade: StringName = &"BOLT"
@export var fastener_id: StringName = &"bolt_m8x25_8.8"
@export var torque_target_nm := 25.0
## Hole indices in the order final torque should be applied. Empty means any order.
@export var sequence: PackedInt32Array = PackedInt32Array()
@export var needs_washer := true
