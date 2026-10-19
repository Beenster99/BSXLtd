class_name JointSite
extends Node3D
## A place where a joint goes. Whoever owns the geometry places these (the bench now, Ship and
## Bay on real ships later); Trades only ever works on JointSites. Each child Marker3D is a
## hole, in child order.

@export var joint_id: StringName
@export var component_id: StringName
@export var mount_id: StringName
@export var spec: JointSpec


func _enter_tree() -> void:
	var bus := Modules.bus("trades") as TradesBus
	if bus:
		bus.register_site(self)


func _exit_tree() -> void:
	var bus := Modules.bus("trades") as TradesBus
	if bus:
		bus.unregister_site(self)


func holes() -> Array[Marker3D]:
	var out: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D:
			out.append(child)
	return out
