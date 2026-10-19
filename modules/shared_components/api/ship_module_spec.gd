class_name ShipModuleSpec
extends Resource
## A ship upgrade ("module") a crew can order from BSX: what it is called, which ship
## classes take it, what it changes and where it goes. BSX names these ids; Void Salvage
## will store them in a ship's modules list (its BaseShip.state["modules"]) when it adds
## modules (its ECONOMY_PLAN phases E11 and E13). Contracts name a module by `id`.

## Schema version of this file.
@export var version := 1
## "attractor_coil_1": what contracts, saves and both games call it. Never renamed.
@export var id := ""
## "Attractor coil Mk I": what players read.
@export var display_name := ""
## One line on what it does, for terminals and contract sheets.
@export_multiline var blurb := ""
## "handling", "sensors", "towing", "fuel" or "processing".
@export var category := ""
## Ship classes that take it: "S" Kestrel, "M" Manta, "L" Hauler, "XL" Yard ship.
@export var fits: PackedStringArray = []
## Where it is fitted: "hold", "roof", "hull" or "engineering".
@export var mount := ""
## The ship figure it changes ("attractor_cap", "hold_capacity", "contact_range",
## "survey_time", "tow_mass", "bowser_capacity"), or "" for a module that adds a verb.
@export var stat := ""
## What `stat` is multiplied by (1.5 = half as much again). 1.0 when `stat` is "".
@export var factor := 1.0
## A module that must already be fitted first ("attractor_coil_1" before Mk II), or "".
@export var requires := ""
## Void Salvage part names (PartCatalog) it is built from, once those parts exist; empty
## until then.
@export var parts: PackedStringArray = []
## Crew hours to fit it in the bay, before skills.
@export var hours := 1.0
