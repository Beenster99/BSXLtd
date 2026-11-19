class_name YardLayout
extends RefCounted
## Where everything in the orbital yard is (station space: metres, floor y = 0, -Z towards
## the dock). Data only, so tests, bots and other modules can reason about the place
## without loading it.

## id -> {name, box}. Boxes are the rooms' insides.
const ROOMS := {
	"design": {"name": "Design room", "box": AABB(Vector3(-12, 0, -22), Vector3(24, 11, 18))},
	"corridor": {"name": "Corridor", "box": AABB(Vector3(-34, 0, -4), Vector3(80, 3.2, 4))},
	"racking": {"name": "Stores hall", "box": AABB(Vector3(14, 0, -64), Vector3(70, 32.4, 60))},
	"contracts": {"name": "Contracts desk", "box": AABB(Vector3(-12, 0, 0), Vector3(12, 3.2, 10))},
	"crew": {"name": "Crew room", "box": AABB(Vector3(0, 0, 0), Vector3(20, 3.2, 12))},
	"quarters": {"name": "Sleeping quarters", "box": AABB(Vector3(20, 0, 0), Vector3(24, 3.2, 12))},
	"airlock": {"name": "Airlock", "box": AABB(Vector3(-40, 0, -5), Vector3(6, 3.2, 6))},
	"design_lock": {"name": "Design room airlock", "box": AABB(Vector3(-11.9, 0, -25), Vector3(1.7, 5, 2.9))},
	"refurb": {"name": "Refurb annex", "box": AABB(Vector3(48, 0, -4), Vector3(36, 16, 30))},
}
## The whole station's outside, hull included (m).
const HULL_BOX := AABB(Vector3(-40.3, -0.7, -64.3), Vector3(124.6, 33.8, 90.6))
## The airlock's doors: x of the inner (corridor) and outer (space) door, and the door
## opening along z (from, to) and its height.
const AIRLOCK_INNER_X := -34.0
const AIRLOCK_OUTER_X := -40.0
const AIRLOCK_DOOR_Z := Vector2(-2.9, -1.1)
const AIRLOCK_DOOR_H := 2.4
## The design room's own way out to the dock (0.4.0 playtest): a small lock in the window
## wall's left corner. Its doors' z (inner, in the window wall; outer, facing B1), their
## opening along x (from, to) and height. They slide up into the wall.
const DESIGN_LOCK_INNER_Z := -22.0
const DESIGN_LOCK_OUTER_Z := -25.0
const DESIGN_LOCK_DOOR_X := Vector2(-11.6, -10.3)
const DESIGN_LOCK_DOOR_H := 2.4

## The dock (stage 1.2): one build berth in front of the design room's window, and a
## holding berth either side. The berths grow with the company's reputation (beenster, 19 Nov:
## "maybe that comes with an automatic upgrade to the berths"; bought as a company upgrade from
## Wave 8). Each tier: the reputation (0-100) it comes at, and the build berth's frame inside
## (m: length along x, the keel's way; height; beam along z). The holding berths are the same
## size, so a hull parked from the build berth still fits.
const BERTH_TIERS := [
	{"tier": 1, "name": "Starter berth", "reputation": 0.0, "size": Vector3(60, 30, 30)},
	{"tier": 2, "name": "Long berth", "reputation": 40.0, "size": Vector3(110, 40, 40)},
	{"tier": 3, "name": "Capital berth", "reputation": 70.0, "size": Vector3(200, 60, 60)},
	{"tier": 4, "name": "Giga berth", "reputation": 90.0, "size": Vector3(320, 80, 80)},
]
## How far out (z) the berths reach at the largest tier (its face less its beam): anything else
## in the dock (TartanCo's ship) stays beyond.
const DOCK_FAR_Z := -150.0
## Every berth's station-side face (z) and middle height (y); the gap between the build berth
## and each holding berth (m).
const BERTH_FACE_Z := -70.0
const BERTH_MIDDLE_Y := -3.0
const HOLDING_GAP := 30.0
## Room the worker bots need round a hull in a berth, each side (m): a design fits a berth when
## its bounding box is no bigger than the berth less twice this (berth_clear_size). The design
## room's own fit check leaves the same 2 m.
const WORK_CLEARANCE := 2.0
## The first tier's berths (what the dock had before tiers).
const BERTHS := [
	{"id": "build_1", "name": "B1", "kind": "build", "box": AABB(Vector3(-30, -18, -100), Vector3(60, 30, 30))},
	{"id": "hold_1", "name": "H1", "kind": "holding", "box": AABB(Vector3(-120, -18, -100), Vector3(60, 30, 30))},
	{"id": "hold_2", "name": "H2", "kind": "holding", "box": AABB(Vector3(60, -18, -100), Vector3(60, 30, 30))},
]


static func room_at(point: Vector3) -> String:
	for id: String in ROOMS:
		if (ROOMS[id].box as AABB).grow(0.01).has_point(point):
			return id
	return ""


## True inside a room (the station's gravity), false outside (the weightless dock). A room
## counts from just under its floor, so standing on it is inside.
static func has_gravity(point: Vector3) -> bool:
	for id: String in ROOMS:
		var b: AABB = ROOMS[id].box
		if AABB(b.position - Vector3(0.05, 0.6, 0.05), b.size + Vector3(0.1, 0.6, 0.1)).has_point(point):
			return true
	return false


## The berths at `tier` (1 to 3): {id, name, kind ("build" or "holding"), box (station space)}.
static func berths(tier := 1) -> Array[Dictionary]:
	var size := berth_size(tier)
	var lo := Vector3(-size.x * 0.5, BERTH_MIDDLE_Y - size.y * 0.5, BERTH_FACE_Z - size.z)
	var step := size.x + HOLDING_GAP
	var out: Array[Dictionary] = []
	out.append({"id": "build_1", "name": "B1", "kind": "build", "box": AABB(lo, size)})
	out.append({"id": "hold_1", "name": "H1", "kind": "holding", "box": AABB(lo - Vector3(step, 0, 0), size)})
	out.append({"id": "hold_2", "name": "H2", "kind": "holding", "box": AABB(lo + Vector3(step, 0, 0), size)})
	return out


## The tier a company with `reputation` (0-100) has.
static func berth_tier_for(reputation: float) -> int:
	var tier := 1
	for t: Dictionary in BERTH_TIERS:
		if reputation >= float(t.reputation):
			tier = int(t.tier)
	return tier


static func berth_tier_info(tier: int) -> Dictionary:
	for t: Dictionary in BERTH_TIERS:
		if int(t.tier) == tier:
			return t.duplicate()
	return BERTH_TIERS[0].duplicate()


## A berth's frame inside at `tier` (m: length x, height y, beam z).
static func berth_size(tier: int) -> Vector3:
	return berth_tier_info(tier).size


## The biggest hull (bounding box, m: length, height, beam) the build berth takes at `tier`,
## leaving the bots room to work round it.
static func berth_clear_size(tier: int) -> Vector3:
	return berth_size(tier) - Vector3.ONE * WORK_CLEARANCE * 2.0



## The smallest tier whose build berth takes a hull `length_m` long (0 when none does). Only
## the length counts: hulls are longer than they are tall or wide.
static func berth_for_length(length_m: float) -> int:
	for t: Dictionary in BERTH_TIERS:
		if length_m <= berth_clear_size(int(t.tier)).x:
			return int(t.tier)
	return 0
