class_name FastenerSpec
extends Resource
## One kind of fastener BSX crews fit: a bolt size or a rivet. Joint specs name it by id.

## Schema version of this file.
@export var version := 1
## "M12", "RIVET_4": what joint specs and contracts call it.
@export var id := ""
## ConnectionData.Kind.BOLT or ConnectionData.Kind.RIVET.
@export var kind := ConnectionData.Kind.BOLT
## Shank diameter, millimetres.
@export var diameter_mm := 12.0
## Shank length, millimetres.
@export var length_mm := 40.0
## Tightening window, newton-metres (min, max). Zero for rivets.
@export var torque_nm := Vector2.ZERO
