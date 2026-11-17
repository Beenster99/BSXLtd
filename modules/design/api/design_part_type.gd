class_name DesignPartType
extends Resource
## A component the designer can place in a room (modules/design/internal/data/components/*.tres).
## The design stage's stand-in for the shared part library: `shared_part` names the Void
## Salvage part it will be built from once the latest shared code is in (Wave 0.4).

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
## Thrust, kN (engines).
@export var thrust := 0.0
## Crew bunks it adds.
@export var crew := 0
## Room types it may go in ([] = any).
@export var rooms: PackedStringArray = PackedStringArray()
## Needs this much clear floor in front of it to be fitted and serviced, m.
@export var access := 0.6
## Days to get one from suppliers (availability on the data channel).
@export var lead_days := 1
## The Void Salvage part name it maps to ("" until the shared code is updated).
@export var shared_part := ""
