class_name ConnectionData
extends RefCounted
## Game state for one joint holding two parts together: a weld, rivet, bolt, or a plug
## connector joining two spans of a wiring loom.
##
## Tools (Weekend 4) reduce health. At zero the connection breaks, and if nothing else holds
## a part on, the part floats free.

enum Kind { WELD, RIVET, BOLT, CONNECTOR }

## Starting health per kind, in damage points. A grinder or cutter will remove a set
## number of points per second, so these decide how long each joint takes to undo.
const MAX_HEALTH: Dictionary = {
	Kind.WELD: 120.0,
	Kind.RIVET: 40.0,
	Kind.BOLT: 80.0,
	Kind.CONNECTOR: 30.0,
}

const KIND_NAMES: Dictionary = {
	Kind.WELD: "WELD",
	Kind.RIVET: "RIVET",
	Kind.BOLT: "BOLT",
	Kind.CONNECTOR: "CONNECTOR",
}

var id: int
var kind: Kind
## Ids of the two parts this joint holds together.
var part_a: int
var part_b: int
## Where the joint sits, relative to the structure that owns it. For rivets and bolts this
## is the exposed head on the surface, which is what a tool has to reach.
var local_position: Vector3
## Which way the joint faces, relative to the structure: out of the surface for rivets and
## bolts, across the seam for welds.
var local_normal: Vector3
var max_health: float
var health: float
## Welds only: the seam the bead runs along, relative to the structure. The seam lies in
## the plane across `local_normal`; `seam_up` is one direction in that plane and
## `seam_size` its extent along seam_up (x) and across it (y), in metres. y > 0: a bead
## all the way round a joint face (a mitred corner, a member's end). y = 0: a straight
## bead x long. Zero size: a short bead at the point.
var seam_up: Vector3 = Vector3.ZERO
var seam_size: Vector2 = Vector2.ZERO
## How it broke (PartData.Removal: INTACT by a tool, FORCED by load, CUT by a slice); the
## host sends it with the break so everyone splits pieces off the same way.
var broken_by: int = 1
## How hot a torch has made this joint, 0..1, as of `heat_at` (engine seconds). It cools
## by HEAT_COOL per second. Game state: a seized bolt only turns once it's hot (see
## `is_seized`). Each machine tracks it from every player's tool; the host's decides.
var heat: float = 0.0
var heat_at: float = 0.0
## What the head looks like (JointView): 0 the classic proud head, 1 a flush bump, barely
## raised off the skin (v4 hulls, whose plates meet in one smooth surface). Set from the
## structure's `head_style` when the joint is made; built the same on every machine.
var head: int = 0

## How fast a heated joint cools, per second (1.0 = from red hot to cold).
const HEAT_COOL: float = 0.12


func _init(p_id: int, p_kind: Kind, p_part_a: int, p_part_b: int, p_position: Vector3,
		p_normal: Vector3) -> void:
	id = p_id
	kind = p_kind
	part_a = p_part_a
	part_b = p_part_b
	local_position = p_position
	local_normal = p_normal.normalized()
	max_health = MAX_HEALTH[kind]
	health = max_health


## How far `p` (structure space) is from this joint, metres. For a weld that's the
## distance to the nearest point of its seam face, so anywhere along a long seam counts.
func distance_to(p: Vector3) -> float:
	if seam_size == Vector2.ZERO or seam_up == Vector3.ZERO:
		return local_position.distance_to(p)
	var up := seam_up.normalized()
	var across := up.cross(local_normal).normalized()
	var d := p - local_position
	var u := clampf(d.dot(up), -seam_size.x * 0.5, seam_size.x * 0.5)
	var v := clampf(d.dot(across), -seam_size.y * 0.5, seam_size.y * 0.5)
	return p.distance_to(local_position + up * u + across * v)


## Heat right now, 0..1 (see `heat`).
func heat_now() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	return maxf(heat - (now - heat_at) * HEAT_COOL, 0.0)


func add_heat(amount: float) -> void:
	heat = minf(heat_now() + amount, 1.0)
	heat_at = Time.get_ticks_msec() / 1000.0


## Bolts only: rusted solid, so a socket can't turn it until it's been heated. Which bolts
## are seized follows from the joint id (the same on every machine); `chance` is the share
## of bolts that are. Once a bolt has started to turn (lost any health) it's free.
func is_seized(chance: float) -> bool:
	if kind != Kind.BOLT or health < max_health:
		return false
	return float(hash(id * 2654435761 + 977) % 10007) / 10007.0 < chance


func is_broken() -> bool:
	return health <= 0.0


## 0 = about to break, 1 = untouched.
func health_fraction() -> float:
	return clampf(health / max_health, 0.0, 1.0)


func kind_name() -> String:
	return KIND_NAMES[kind]


func other_part(part_id: int) -> int:
	return part_b if part_id == part_a else part_a
