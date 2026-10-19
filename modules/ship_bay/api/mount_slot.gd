class_name MountSlot
extends Resource
## One place on a ship where a part comes off and goes on: a Void Salvage module slot or a
## replaceable fitting. Positions are in ship space (-Z forward, +Y up, deck floor y = 0),
## metres.

## "<system>_<location>_<n>", for example "eng_aft_port_1".
@export var slot_id := ""
## Shown to players.
@export var display_name := ""
## Component or module ids this slot takes ("KestrelEngine", "hold_nets").
@export var accepts: PackedStringArray = []
## What the ship arrives with, "" if the slot is empty.
@export var fitted := ""
## Where the part's mounting face sits, ship space; basis Z points out of the mounting face.
@export var mount := Transform3D.IDENTITY
## Everything the fitted part occupies, ship space. Model pieces inside it hide when the
## slot is stripped.
@export var box := AABB()
## Which side a crew works from: "outboard", "inboard", "below" or "above".
@export var access := "inboard"
@export var fasteners: Array[FastenerPoint] = []


func takes(component: String) -> bool:
	return component in accepts


func fastener(joint_id: String) -> FastenerPoint:
	for f in fasteners:
		if f.joint_id == joint_id:
			return f
	return null
