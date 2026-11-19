class_name YardKits
extends RefCounted
## Kits: set recipes of stock the mover bots bring to you wherever you are, and to the worker
## bots building in the yard (0.4.1 playtest: "mover bots who just bring certain recipes of
## materials/stock to you wherever you are - they also deliver to the worker bots who actually
## make the ship in the yard"). Parts are YardRackStore.PARTS ids (Void Salvage part_names).

## id -> {name, parts: [{part, qty}...]}, in the order K offers them.
const KITS := {
	"frame": {"name": "Frame kit", "parts": [{"part": "Girder", "qty": 4}, {"part": "BoxBeam", "qty": 2}]},
	"plating": {"name": "Plating kit", "parts": [{"part": "HullPlate", "qty": 6}, {"part": "DeckPlate", "qty": 4}]},
	"power": {"name": "Power kit", "parts": [{"part": "BatteryRack", "qty": 1}, {"part": "JunctionBox", "qty": 4},
			{"part": "SwitchCabinet", "qty": 1}]},
	"piping": {"name": "Piping kit", "parts": [{"part": "Pipe", "qty": 6}, {"part": "FuelValve", "qty": 4}]},
	"thrusters": {"name": "Thruster kit", "parts": [{"part": "SideThruster", "qty": 2}, {"part": "IonThruster", "qty": 1}]},
	"cabin": {"name": "Cabin kit", "parts": [{"part": "Bunk", "qty": 1}, {"part": "Locker", "qty": 1}, {"part": "Seat", "qty": 1}]},
}


static func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in KITS:
		out.append(id)
	return out


static func display_name(id: String) -> String:
	return String(KITS.get(id, {}).get("name", id))


## The kit's parts: [{part, qty}...] (a copy).
static func parts(id: String) -> Array:
	return (KITS.get(id, {}).get("parts", []) as Array).duplicate(true)
