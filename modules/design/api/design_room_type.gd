class_name DesignRoomType
extends Resource
## A kind of room the designer can place (modules/design/internal/data/rooms/*.tres).
## Numbers are per square metre of floor, so a room's cost and mass grow with its size.

@export var version := 1
@export var id := ""
@export var display_name := ""
## Short label for small plans.
@export var short := ""
@export var colour := Color(0.4, 0.7, 1.0)
## Smallest sensible size, m (w, d).
@export var min_size := Vector2(2, 2)
## What a new one is placed at, m (w, d).
@export var default_size := Vector2(4, 4)
## Fit-out: floor, walls, lining, lighting, credits per m2.
@export var cost_per_m2 := 400.0
## Fit-out mass, kg per m2 (the hull and frame are counted apart).
@export var mass_per_m2 := 60.0
## Fit-out work, hours per m2.
@export var hours_per_m2 := 1.0
## Power the room itself draws (lights, air), kW per m2.
@export var power_per_m2 := 0.05
## Crew bunks per m2 of floor (quarters), 0 for none.
@export var crew_per_m2 := 0.0
## Cargo space as a share of the room's volume (holds), 0..1.
@export var cargo_share := 0.0
## Fuel space as a share of the room's volume (tanks), 0..1.
@export var fuel_share := 0.0
## Needs a door to the rest of the ship (tanks and voids don't).
@export var needs_access := true
## The ship needs at least one of these (bridge, airlock).
@export var required := false
## Counts as a way on and off the ship.
@export var is_airlock := false
## Joins the decks above and below where another one stands over it (stairs, lifts).
@export var links_decks := false
