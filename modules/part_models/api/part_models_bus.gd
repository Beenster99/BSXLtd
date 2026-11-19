class_name PartModelsBus
extends Node
## Part Models module bus (Modules.bus("part_models")): BSX's own detailed models of the ship
## components Void Salvage has no part for (`PartModels`). A library: nothing to register, nothing
## synced (every machine reads the same committed files).


func register_module() -> void:
	pass


## How a moving part moves (PartModels.motion): empty if it doesn't move.
func motion(id: String) -> Dictionary:
	return PartModels.motion(id)


## Poses a moving model between stowed (0) and deployed (1) (PartModels.pose). The model is any
## node under which an instanced PartModels model hangs (its root carries meta "part_model").
func pose(model: Node3D, id: String, t: float) -> void:
	PartModels.pose(model, id, t)


## The PartModels model drawn under `node` (itself or a descendant with meta "part_model"), or null.
func find_model(node: Node) -> Node3D:
	if node == null:
		return null
	if node.has_meta("part_model"):
		return node as Node3D
	for c in node.get_children():
		var m := find_model(c)
		if m:
			return m
	return null
