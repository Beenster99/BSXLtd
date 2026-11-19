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
}
## The whole station's outside, hull included (m).
const HULL_BOX := AABB(Vector3(-40.3, -0.7, -64.3), Vector3(124.6, 33.8, 76.6))
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
## holding berth either side.
const BERTHS := [
	{"id": "build_1", "name": "B1", "kind": "build", "box": AABB(Vector3(-30, -18, -100), Vector3(60, 30, 30))},
	{"id": "hold_1", "name": "H1", "kind": "holding", "box": AABB(Vector3(-100, -15, -98), Vector3(40, 24, 24))},
	{"id": "hold_2", "name": "H2", "kind": "holding", "box": AABB(Vector3(60, -15, -98), Vector3(40, 24, 24))},
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


static func berths() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Dictionary in BERTHS:
		out.append(b.duplicate())
	return out
