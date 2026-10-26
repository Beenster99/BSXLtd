class_name ShipDefinition
extends Resource
## A ship BSX can take into a bay: its model and its mount slots. Built from a layout file
## (Void Salvage's ship space, see ShipBayBus.definition) plus BSX's fastener data.

## Schema version of the layout this came from.
@export var version := 1
## The ship's id in both games ("vs_kestrel").
@export var ship_id := ""
@export var display_name := ""
## The ship's look: a scene that builds it from its Void Salvage file.
@export var model: PackedScene
## Where the ship came from (the Void Salvage file's generator and design).
@export var source := ""
## The whole ship, ship space, metres.
@export var bounds := AABB()
## Room name -> its span along Z, metres (Vector2(from, to)).
@export var rooms: Dictionary = {}
@export var slots: Array[MountSlot] = []
## Joint ids that start undone: a wreck's broken joints, there to be made again.
@export var loose: PackedStringArray = PackedStringArray()
## The ship's Void Salvage file, for a ship with no model scene of its own (a generated
## wreck): the bay builds it from this. {} otherwise.
var file: Dictionary = {}


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
