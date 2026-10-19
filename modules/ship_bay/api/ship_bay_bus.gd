class_name ShipBayBus
extends Node
## Ship and Bay module bus (Modules.bus("ship_bay")). Loads a ship into a bay, marks mount points and seams, and tracks strip-out and install state.
## Other modules use this module only through this folder: signals here, and resource
## classes placed next to it. Everything else lives in internal/.


func register_module() -> void:
	pass
