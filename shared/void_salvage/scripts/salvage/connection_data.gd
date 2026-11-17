class_name ConnectionData
extends RefCounted
## Game state for one joint holding two parts together: a weld, rivet, bolt, a plug
## connector joining two spans of a wiring loom, or a spot weld tacking a fitting down.
##
## Tools (Weekend 4) reduce health. At zero the connection breaks, and if nothing else holds
## a part on, the part floats free.

## Append only: the ints are saved and shared (BSX, the wreck and ship files).
enum Kind { WELD, RIVET, BOLT, CONNECTOR, SPOT }

## Starting health per kind, in damage points. A grinder or cutter will remove a set
## number of points per second, so these decide how long each joint takes to undo.
const MAX_HEALTH: Dictionary = {
	Kind.WELD: 120.0,
	Kind.RIVET: 40.0,
	Kind.BOLT: 80.0,
	Kind.CONNECTOR: 30.0,
	Kind.SPOT: 30.0,
}

const KIND_NAMES: Dictionary = {
	Kind.WELD: "WELD",
	Kind.RIVET: "RIVET",
	Kind.BOLT: "BOLT",
	Kind.CONNECTOR: "CONNECTOR",
	Kind.SPOT: "SPOT",
}

## The share of bolts rusted solid by default (`is_seized`; a socket may be tuned to
## another share).
const SEIZED_CHANCE: float = 0.075

## False for an opt-in flexible electrical lead: it conducts but never fuses bodies.
var structural: bool = true

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
## raised off the skin (v4 hulls, whose plates meet in one smooth surface), on welds 2 a
## machine bead and 3 one ground flush (FrameStyle), 4 the frame builds' subtle heads (a
## rivet seen up close and gone at ten metres, a low flush bolt), on a bolt 5 a fitting's foot bolt (a small hex
## head on its bracket, WD10a). Set from the
## structure's `head_style` when the joint is made; built the same on every machine.
var head: int = 0
## What the joint is, by the path of the part it fastens, its role, what it fastens to and
## its place in its row (docs/SHIP_FRAME_PLAN.md 4.7): "hull/bay:hold/skin/e3/rivet:st:hold:e3/1".
## The builders set it; "" where none did.
var path: String = ""
## The step of the build that made it (docs/SHIP_FRAME_PLAN.md 4.7, BSX's closing-up order):
## "frame", "deck", "skin", "lining", "wall", "fitting", "service"; "" where no builder said.
## Stamped from the model's `phase` when the joint is made.
var phase: String = ""
## Loom plugs on a lead (FrameTarget.power_lead): the wire's points, structure space, from the
## device to the plug. The whole wire is the joint's reach, so a tool anywhere along it bites
## the plug (`closest_point`, `lead_near_ray`); empty for every other joint. It hangs on the
## device (part_b) and moves with it (PartModel.move_part).
var lead: PackedVector3Array = PackedVector3Array()
## Where along the lead (metres from the device) a torch severed it, or -1: pulled at the plug.
## Set on the host as the torch works and sent with the break (World `_remote_lead_cuts`), so
## every machine draws the wire parted at the same spot (PartModel.cut_lead).
var lead_cut: float = -1.0
## Bolts only: rusted solid on purpose, whatever the id rule says (`is_seized`). A design sets it
## while it builds (the Patience's lessons: a bolt that must be heated first, wherever her ids
## fall), so it is the same on every machine and never sent.
var force_seized: bool = false
## Welds and spot welds only (LK3): the metal round it shows a weld's heat colours (straw,
## bronze, purple, blue), drawn as a halo by its view (PartModel.mark_heat). Look only: a
## design or the wreck marks a dozen at build time, seeded, the same on every machine, never sent.
var heat_marked: bool = false

## How fast a heated joint cools, per second (1.0 = from red hot to cold).
const HEAT_COOL: float = 0.12

## (FS2, docs/review/19_FASTENERS.md 4) A hull plate's seam weld (FS1's, its path has "/seam:") at least this
## long is ground off along its line, a stretch at a time (`follows`), metres. Shorter welds work as before.
const FOLLOW_MIN: float = 0.6
## The length of one cell of a followed seam, metres.
const SEAM_CELL: float = 0.1
## A cell ground to under this much bead is ground clean (no slivers left by a pass just under the follow speed).
const CELL_CLEAN: float = 0.03
## A followed seam's bead, cell by cell along `seam_up` from its -x end: how much of each is left (1 untouched,
## 0 ground off). Made on first use (`follows`) from what the build set, the same on every machine; the host's
## grinding changes it and sends it (World `_receive_seam_cells`). Its mean is the joint's share of health a
## grinder has not taken; the joint breaks when every cell is ground.
var cells: PackedFloat32Array = PackedFloat32Array()


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
	return p.distance_to(closest_point(p))


## The joint's point nearest `p` (structure space): its head, or on a weld the nearest point
## of its seam face (where a tool along the seam bites it).
func closest_point(p: Vector3) -> Vector3:
	if lead.size() > 1:
		var best := local_position
		var best_d := p.distance_squared_to(best)
		for i in range(1, lead.size()):
			var q := Geometry3D.get_closest_point_to_segment(p, lead[i - 1], lead[i])
			var d := p.distance_squared_to(q)
			if d < best_d:
				best_d = d
				best = q
		return best
	if seam_size == Vector2.ZERO or seam_up == Vector3.ZERO:
		return local_position
	var up := seam_up.normalized()
	var across := up.cross(local_normal).normalized()
	var d := p - local_position
	var u := clampf(d.dot(up), -seam_size.x * 0.5, seam_size.x * 0.5)
	var v := clampf(d.dot(across), -seam_size.y * 0.5, seam_size.y * 0.5)
	return local_position + up * u + across * v


## A lead's point nearest the ray from `origin` along `dir` (structure space, `dir` unit) no
## further than `length` along it: [point on the wire, its distance off the ray, how far along
## the ray], or [] for a joint with no lead.
func lead_near_ray(origin: Vector3, dir: Vector3, length: float) -> Array:
	if lead.size() < 2:
		return []
	var end := origin + dir * length
	var best: Array = []
	for i in range(1, lead.size()):
		var pair := Geometry3D.get_closest_points_between_segments(lead[i - 1], lead[i], origin, end)
		var off := pair[0].distance_to(pair[1])
		if best.is_empty() or off < float(best[1]):
			best = [pair[0], off, (pair[1] - origin).length()]
	return best


## How far along the lead (metres from the device) its point nearest `p` lies (structure space).
func lead_along(p: Vector3) -> float:
	var best := 0.0
	var best_d := INF
	var walked := 0.0
	for i in range(1, lead.size()):
		var q := Geometry3D.get_closest_point_to_segment(p, lead[i - 1], lead[i])
		var d := p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = walked + lead[i - 1].distance_to(q)
		walked += lead[i - 1].distance_to(lead[i])
	return best


## Heat right now, 0..1 (see `heat`).
func heat_now() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	return maxf(heat - (now - heat_at) * HEAT_COOL, 0.0)


func add_heat(amount: float) -> void:
	heat = minf(heat_now() + amount, 1.0)
	heat_at = Time.get_ticks_msec() / 1000.0


## Bolts only: rusted solid, so a socket can't turn it until it's been heated. Which bolts
## are seized follows from the joint id (the same on every machine); `chance` is the share
## of bolts that are, and `force_seized` makes one seized whatever the chance. Once a bolt has
## started to turn (lost any health) it's free.
func is_seized(chance: float) -> bool:
	if kind != Kind.BOLT or health < max_health:
		return false
	if force_seized:
		return true
	return float(hash(id * 2654435761 + 977) % 10007) / 10007.0 < chance


func is_broken() -> bool:
	return health <= 0.0


## (FS2) Is this a seam weld ground by following its line (a hull plate's, at least FOLLOW_MIN long)? Makes its
## cells the first time it is asked once it is one (builders name the joint after making it).
func follows() -> bool:
	if not cells.is_empty():
		return true
	if kind != Kind.WELD or seam_size.y != 0.0 or seam_size.x < FOLLOW_MIN or seam_up == Vector3.ZERO \
			or not path.contains("/seam:"):
		return false
	cells.resize(maxi(ceili(seam_size.x / SEAM_CELL - 0.001), 1))
	cells.fill(1.0)
	return true


## (FS2) Where `p` (structure space) lies along the seam, metres from its middle (-length/2 .. length/2).
func seam_along(p: Vector3) -> float:
	return clampf((p - local_position).dot(seam_up.normalized()), -seam_size.x * 0.5, seam_size.x * 0.5)


## (FS2) The seam's point `u` metres from its middle (structure space).
func seam_point(u: float) -> Vector3:
	return local_position + seam_up.normalized() * u


## (FS2) The seam's nearest point to the ray from `origin` along `dir` (structure space, `dir` unit, `length`
## long): [the point on the seam, the point on the ray, the distance between them].
func seam_near_ray(origin: Vector3, dir: Vector3, length: float) -> Array:
	var half := seam_up.normalized() * seam_size.x * 0.5
	var pair := Geometry3D.get_closest_points_between_segments(local_position - half, local_position + half,
			origin, origin + dir * length)
	return [pair[0], pair[1], pair[0].distance_to(pair[1])]


## (FS2) Grinds the cells within `reach` metres of `u` (metres from the middle) down by `amount` each (a share of a
## cell); returns the share of the whole seam taken off (0..1). Health follows (the mean of what is left), so a
## seam ground to its last cell breaks; damage from anything else (load, a blast) still comes off health alone.
func grind_cells(u: float, reach: float, amount: float) -> float:
	if not follows() or amount <= 0.0:
		return 0.0
	var n := cells.size()
	var start := -seam_size.x * 0.5
	var lo := clampi(floori((u - reach - start) / SEAM_CELL), 0, n - 1)
	var hi := clampi(floori((u + reach - start) / SEAM_CELL), 0, n - 1)
	var taken := 0.0
	for i in range(lo, hi + 1):
		var was := cells[i]
		cells[i] = maxf(was - amount, 0.0) if was - amount > CELL_CLEAN else 0.0
		taken += was - cells[i]
	taken /= float(n)
	health -= taken * max_health
	if cells_left() <= 0.0:
		health = minf(health, 0.0)
	return taken


## (FS2) The most bead left in the cells within `reach` of `u` (m from the middle), 0..1.
func left_near(u: float, reach: float) -> float:
	if not follows():
		return 1.0
	var n := cells.size()
	var start := -seam_size.x * 0.5
	var lo := clampi(floori((u - reach - start) / SEAM_CELL), 0, n - 1)
	var hi := clampi(floori((u + reach - start) / SEAM_CELL), 0, n - 1)
	var most := 0.0
	for i in range(lo, hi + 1):
		most = maxf(most, cells[i])
	return most


## (FS2) How much of the seam's bead is left, metres (its length on any other joint).
func seam_left() -> float:
	if not follows():
		return seam_size.x
	return cells_left() * seam_size.x


## (FS2) The share of a followed seam's cells left (0..1).
func cells_left() -> float:
	if cells.is_empty():
		return 1.0
	var sum := 0.0
	for v in cells:
		sum += v
	return sum / float(cells.size())


## (FS2) Sets the cells from the host's bytes (each 0..255 for 0..1) and health to match, never back up.
func take_cells(levels: PackedByteArray) -> void:
	if not follows() or levels.size() != cells.size():
		return
	for i in cells.size():
		cells[i] = minf(cells[i], float(levels[i]) / 255.0)


## (FS2) The cells as bytes, for the wire.
func cell_bytes() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(cells.size())
	for i in cells.size():
		out[i] = clampi(ceili(cells[i] * 255.0), 0, 255)
	return out


## 0 = about to break, 1 = untouched.
func health_fraction() -> float:
	return clampf(health / max_health, 0.0, 1.0)


func kind_name() -> String:
	return KIND_NAMES[kind]


func other_part(part_id: int) -> int:
	return part_b if part_id == part_a else part_a
