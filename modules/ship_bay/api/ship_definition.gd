class_name ShipDefinition
extends Resource
## A ship BSX can take into a bay: its model and its mount slots. Built from a layout file
## (Void Salvage's ship space, see ShipBayBus.definition) plus BSX's fastener data.

## Schema version of the layout this came from.
@export var version := 1
## The ship's id in both games ("vs_kestrel").
@export var ship_id := ""
@export var display_name := ""
## The ship's look. Void Salvage builds its ships in code; this is an export of one.
@export var model: PackedScene
## Where the layout came from (a Void Salvage commit, or "hand-written").
@export var source := ""
## The whole ship, ship space, metres.
@export var bounds := AABB()
## Room name -> its span along Z, metres (Vector2(from, to)).
@export var rooms: Dictionary = {}
@export var slots: Array[MountSlot] = []


func slot(slot_id: String) -> MountSlot:
	for s in slots:
		if s.slot_id == slot_id:
			return s
	return null


func slot_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for s in slots:
		out.append(s.slot_id)
	return out
