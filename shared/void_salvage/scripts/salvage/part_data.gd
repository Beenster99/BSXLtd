class_name PartData
extends RefCounted
## Game state for one salvageable part (a hull plate, a frame beam, a tank...).
##
## This is pure data: no nodes. The SalvageStructure that owns the part creates and moves
## the visual and collision nodes for it. Keeping state separate from presentation means
## it can later be saved, sent over the network, or shown in a scanner.

## What a part is, which decides how it is processed and sold later.
enum Kind { HULL, FRAME, HAZARD, CONDUIT, COMPONENT, GLASS }

## A part's role in the ship's electrics (see PowerGrid). Power only travels through loom
## CONNECTOR joints (plugs between loom spans, and device leads plugged into a loom).
##   SOURCE     makes power (reactor, emergency light cells)
##   CONDUCTOR  carries it on (loom spans)
##   SWITCH     carries it on only while closed (a breaker)
##   CONSUMER   uses it and passes nothing on (lights, door panels)
enum Power { NONE, SOURCE, CONDUCTOR, SWITCH, CONSUMER }

## Faults on a part, as bit flags in `faults` (docs/DAMAGE_PLAN.md 9.3.3; more to come):
##   DEAD_LAMP  a lamp whose bulb or cell has failed: dark whatever the grid says
enum Fault { DEAD_LAMP = 1 }

## How a part came off the wreck (docs/ECONOMY_PLAN.md 3.4), worst so far:
##   ATTACHED  still on it (or never off anything)
##   INTACT    every joint holding it was undone with a tool
##   FORCED    the last joint broke under load (a blast, wreck events)
##   CUT       a torch slice went through it, or through what it came off on
## Also the source a joint break passes (SalvageStructure.damage_connection).
enum Removal { ATTACHED, INTACT, FORCED, CUT }
## Value kept per removal (ATTACHED, INTACT, FORCED, CUT): torched parts are scrap stock.
const REMOVAL_VALUE: Array[float] = [1.0, 1.0, 0.7, 0.4]
const REMOVAL_NAMES: Array[String] = ["ON THE WRECK", "INTACT", "FORCED", "CUT"]

## Unique across the whole game session.
var id: int
var part_name: String
var kind: Kind
## Kilograms.
var mass: float
## Credits if sold intact (Milestone 2+).
var value: float
## Position and rotation relative to the structure that owns it. When a part splits off into
## a new structure, the new body starts with the old body's transform, so this stays valid.
var local_transform: Transform3D
## Part space: where the part's mass is centred. Zero as built; a piece cut or torn from a
## part keeps that part's transform, so its middle is off its origin (SalvageStructure.
## replace_part sets it, recompute_mass weighs the part there).
var centroid := Vector3.ZERO
## What it's made of: an id into Materials.TABLE (hardness tier, density, price, look).
## Steel as built (copper for looms); wrecks get theirs from their design (Materials).
var material: String = Materials.BUILT
## How it came off the wreck (Removal; ATTACHED while it's still on).
var removal: Removal = Removal.ATTACHED
## Electrical role; NONE for most parts.
var power: Power = Power.NONE
## For SWITCH parts: closed (conducting) or open. Shared between players by the World.
var switch_closed: bool = true
## For SOURCE parts: how much it puts out, 0 (dead) to 1 (live). A wreck's reactor and
## generators get the contract roll's power state (WreckEvents.residual); the grid passes
## `output * charge` on as the level every part it reaches runs at (PowerGrid).
var output: float = 1.0
## For SOURCE parts: how full its cell is, 0..1 (1 for a reactor or generator). Only a
## `cell` runs down (the host drains it and sends the number); the rest keep theirs.
var charge: float = 1.0
## A battery cell (an emergency lamp's own): its charge runs down while it feeds.
var cell: bool = false
## Fault flags (Fault): what is broken on it beyond wear and dents. Rolled from the seed
## with the damage on every machine, never sent.
var faults: int = 0

## --- Fluids (FluidSystem). What a tank holds or a line carries: "", "fuel", "coolant".
var fluid: String = ""
## Tanks: litres it holds when full (0 for lines), and how full it is, 0..1. Every machine
## rolls the same fill from the wreck's seed; draining comes from the host.
var fluid_capacity: float = 0.0
var fluid_level: float = 0.0

## --- Condition (wreck events now; explosions later). 0 = like new, 1 = as bad as it gets.
## Every machine works these out from the same seeded events, so they're never sent.
## Scuffs, pitting, grime: age.
var wear: float = 0.0
## Soot and heat tint.
var scorch: float = 0.0
## Where the scorch is worst (in the owning structure's space, which split pieces keep) and
## how far it spreads, metres; radius 0 = the whole part evenly.
var scorch_at := Vector3.ZERO
var scorch_radius: float = 0.0
## A streak (a scrape): the scorch runs along this structure-space direction; zero = a spot.
var scorch_line := Vector3.ZERO


## Dents: [point, push direction, depth m, radius m, crumple 0-1], point and direction in
## the owning structure's space. Plates bow in around each one (DeformMesh).
var dents: Array = []
## Bend for long parts (frame members): how far the middle is pushed, as a structure-space
## vector (metres); zero = straight.
var bend := Vector3.ZERO
## Torn, snapped or shattered (a piece of what it was): worth less.
var torn: bool = false


func is_deformed() -> bool:
	return not dents.is_empty() or bend.length_squared() > 0.0


## How badly bent out of shape it is, 0 (true) to 1 (wrecked).
func deformation() -> float:
	var d := bend.length() * 3.0
	for dent: Array in dents:
		d += float(dent[2]) * 3.0 + float(dent[4]) * 0.5
	return clampf(d, 0.0, 1.0)


## How much of its value the part keeps in this condition (0.1 to 1).
func condition() -> float:
	return clampf((1.0 - 0.35 * wear) * (1.0 - 0.6 * scorch) * (1.0 - 0.5 * deformation())
			* (0.75 if torn else 1.0), 0.1, 1.0)


## Credits if sold as it is now.
func salvage_value() -> float:
	return value * condition() * REMOVAL_VALUE[removal]


## Records that it came off this way (a worse way sticks: cut beats forced beats intact).
func mark_removed(how: Removal) -> void:
	removal = maxi(removal, how) as Removal


## Taken off cleanly (or never off): what an "intact" contract wants.
func is_intact() -> bool:
	return removal <= Removal.INTACT


## The level a SOURCE puts into the grid (0..1): its output times its cell's charge.
func source_level() -> float:
	return clampf(output * charge, 0.0, 1.0)


func has_fault(f: Fault) -> bool:
	return faults & f != 0


func _init(p_id: int, p_name: String, p_kind: Kind, p_mass: float, p_value: float,
		p_transform: Transform3D) -> void:
	id = p_id
	part_name = p_name
	kind = p_kind
	mass = p_mass
	value = p_value
	local_transform = p_transform
