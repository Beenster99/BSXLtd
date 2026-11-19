class_name DesignPartType
extends Resource
## A component the designer can place in a room (modules/design/internal/data/components/*.tres).
## `shared_part` names the Void Salvage part it is (a VsParts id): walk-inside draws that part
## and the catalog takes its size and mass from it. Cost and the rest stay BSX's own numbers.

@export var version := 1
@export var id := ""
@export var display_name := ""
@export var short := ""
@export var colour := Color(0.9, 0.8, 0.4)
## Size, m: x across (X), y height, z depth (Z).
@export var size := Vector3(1, 1, 1)
@export var cost := 1000.0
## kg
@export var mass := 100.0
@export var build_hours := 2.0
## kW: positive makes power, negative uses it.
@export var power := 0.0
## Fuel: +1 feeds fuel lines (a pump), -1 burns fuel and needs a line, 0 neither.
@export var fuel := 0
## Thrust, kN (engines).
@export var thrust := 0.0
## Crew bunks it adds.
@export var crew := 0
## Fitted on the outside of the hull (thrusters, engine bells) instead of in a room.
@export var hull_mount := false
## Its Void Salvage part is built nozzle down (-Y); fitted on the hull it is laid over so the
## nozzle points out from the hull (its size then reads across, height, out from the hull).
@export var nozzle_down := false
## Room types it may go in ([] = any).
@export var rooms: PackedStringArray = PackedStringArray()
## Needs this much clear floor in front of it to be fitted and serviced, m.
@export var access := 0.6
## Days to get one from suppliers (availability on the data channel).
@export var lead_days := 1
## The Void Salvage part it is, a VsParts id ("" for none yet: drawn as a fitted box).
@export var shared_part := ""

## --- Sizes and grades (DesignGrades) ---
## Palette group: "power", "propulsion", "jump", "flight", "sensors", "defence", "weapons",
## "life", "medical", "crew", "galley", "furniture", "storage", "cargo", "fluids", "machinery",
## "doors", "lighting", "structure".
@export var category := ""
## Size class of the numbers above, 1 (smallest) to 8; 0 = one size only (furniture).
@export var size_class := 0
## Smallest and largest size class it comes in (both 0 = only `size_class`).
@export var min_class := 0
@export var max_class := 0
## Comes in grades (DesignGrades.GRADES); furniture and plain fittings don't.
@export var graded := true
## Hit points before it fails.
@export var integrity := 100.0
## Jump drive rating: light years it carries a 100 t ship on one jump.
@export var jump := 0.0
## Weapons: damage per second at its rated range.
@export var attack := 0.0
## Armour and shields: defence points added to the ship.
@export var defence := 0.0
## Heat and emissions it gives off (the ship's signature); negative hides some (heat sinks,
## dampers, baffles).
@export var signature := 0.0
## Cargo it holds, m3 (racks, containers).
@export var cargo := 0.0
## Fuel it holds, m3 (tanks).
@export var tank := 0.0
## Sensor range, km.
@export var sensor := 0.0
## Set on a derived size/grade variant (DesignCatalog.part("reactor_small:5H")): its base type's
## id, its size class and grade code, and how much bigger its model is drawn than the base's.
var base_id := ""
var grade := ""
var model_scale := 1.0
