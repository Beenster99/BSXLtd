class_name YardRackStore
extends RefCounted
## The stores hall's racks as data (0.4.0 playtest: "the storage racking needs to be 5x larger
## and accommodate significant part sizes ... their actual parts and not crates and boxes").
## Every place on every rack, the part lying in it and how many; pure data, the same on every
## machine. RackingHall (internal) draws the racks and the parts themselves.
##
## Four kinds of rack, by what a part is like (station space: floor y = 0, -Z towards the
## dock; the racks run along z, their aisles open onto the yard side at the hall's open face):
##   LONG       cantilever racks: beams, girders, pipes laid along the arms, up to 6 m
##   PLATE      deep pallet racking: hull plates and armour lying flat in stacks
##   COMPONENT  pallet racking: boxes, valves, cabinets, batteries, gyros on the decks
##   HEAVY      floor cradles under the gantry: engines, tanks, reactors, one to a cradle
##   var store := YardRackStore.new(); store.fill_demo()
##   var slot := store.store("tank_large", 1)   # where a delivery goes
##   store.take(slot, 1)                         # a bot takes one out to the yard

enum { LONG, PLATE, COMPONENT, HEAVY }

const KIND_NAMES: PackedStringArray = ["long", "plate", "component", "heavy"]

## The parts the stores keep: id -> {name, kind (rack), size (m, as it lies: x across the rack,
## y up, z along it), stack (how many to one place)}. RackingHall draws each one.
const PARTS := {
	"box_beam_6": {"name": "Box beam 6 m", "kind": LONG, "size": Vector3(0.2, 0.24, 6.0), "stack": 6},
	"girder_4": {"name": "Frame girder 4 m", "kind": LONG, "size": Vector3(0.16, 0.2, 4.0), "stack": 8},
	"pipe_4": {"name": "Pipe 4 m", "kind": LONG, "size": Vector3(0.18, 0.18, 4.0), "stack": 10},
	"pipe_big_5": {"name": "Main pipe 5 m", "kind": LONG, "size": Vector3(0.36, 0.36, 5.0), "stack": 4},
	"hull_plate": {"name": "Hull plate 1.5x2.5", "kind": PLATE, "size": Vector3(1.5, 0.03, 2.5), "stack": 12},
	"deck_plate": {"name": "Deck plate 1.2x2.4", "kind": PLATE, "size": Vector3(1.2, 0.04, 2.4), "stack": 10},
	"armour_slab": {"name": "Armour slab 2x2.8", "kind": PLATE, "size": Vector3(2.0, 0.18, 2.8), "stack": 4},
	"radiator": {"name": "Radiator 2.8 m", "kind": PLATE, "size": Vector3(1.2, 0.16, 2.8), "stack": 4},
	"junction_box": {"name": "Junction box", "kind": COMPONENT, "size": Vector3(0.4, 0.3, 0.2), "stack": 8},
	"valve": {"name": "Valve", "kind": COMPONENT, "size": Vector3(0.2, 0.2, 0.12), "stack": 10},
	"switch_cabinet": {"name": "Switch cabinet", "kind": COMPONENT, "size": Vector3(0.7, 1.4, 0.35), "stack": 2},
	"battery_rack": {"name": "Battery rack", "kind": COMPONENT, "size": Vector3(1.2, 1.4, 0.5), "stack": 1},
	"heat_sink": {"name": "Heat sink", "kind": COMPONENT, "size": Vector3(0.84, 1.0, 0.32), "stack": 2},
	"gyroscope": {"name": "Gyroscope", "kind": COMPONENT, "size": Vector3(1.0, 1.0, 1.0), "stack": 1},
	"capacitor_bank": {"name": "Capacitor bank", "kind": COMPONENT, "size": Vector3(1.6, 1.4, 0.7), "stack": 1},
	"generator": {"name": "Generator", "kind": COMPONENT, "size": Vector3(1.4, 1.2, 0.9), "stack": 1},
	"engine_bell": {"name": "Engine bell", "kind": HEAVY, "size": Vector3(1.9, 1.9, 1.9), "stack": 1},
	"hydrogen_engine": {"name": "Hydrogen engine", "kind": HEAVY, "size": Vector3(2.5, 2.5, 2.2), "stack": 1},
	"turbine_engine": {"name": "Turbine engine", "kind": HEAVY, "size": Vector3(2.2, 2.2, 1.7), "stack": 1},
	"thruster_pod": {"name": "Thruster pod", "kind": HEAVY, "size": Vector3(1.4, 1.2, 1.8), "stack": 2},
	"tank_large": {"name": "Tank 1.2x3", "kind": HEAVY, "size": Vector3(1.3, 1.3, 3.0), "stack": 1},
	"reactor": {"name": "Reactor", "kind": HEAVY, "size": Vector3(2.0, 2.2, 2.0), "stack": 1},
}

## The racks, west to east: id, kind, x of the rack's middle (m), the sides it opens to (-1
## west, +1 east), its z from the yard side (z0) to the back (z1), each place's length along z
## (bay), its levels, the first level's height and the pitch between them (m), and how deep
## a place is across (depth, m, from the rack's middle).
const RACKS := [
	{"id": "L1", "kind": LONG, "x": 20.5, "sides": [-1, 1], "z0": -52.0, "z1": -10.0, "bay": 7.0, "levels": 5, "first": 0.9, "pitch": 1.5, "depth": 2.2},
	{"id": "L2", "kind": LONG, "x": 29.0, "sides": [-1, 1], "z0": -52.0, "z1": -10.0, "bay": 7.0, "levels": 5, "first": 0.9, "pitch": 1.5, "depth": 2.2},
	{"id": "P1", "kind": PLATE, "x": 38.0, "sides": [-1, 1], "z0": -52.0, "z1": -10.0, "bay": 3.5, "levels": 4, "first": 0.15, "pitch": 1.9, "depth": 2.3},
	{"id": "C1", "kind": COMPONENT, "x": 47.0, "sides": [-1, 1], "z0": -52.0, "z1": -10.0, "bay": 3.0, "levels": 5, "first": 0.15, "pitch": 1.9, "depth": 1.8},
	{"id": "H1", "kind": HEAVY, "x": 58.5, "sides": [-1, 1], "z0": -52.0, "z1": -10.0, "bay": 4.2, "levels": 1, "first": 0.35, "pitch": 0.0, "depth": 3.0},
]

## Goods in (east end): where the haulers' loads are set down, one bay per hauler, and the
## hauler berths outside the east wall's opening (all station space).
const GOODS_IN_BAYS := [
	AABB(Vector3(68, 0, -56), Vector3(14, 0.1, 10)),
	AABB(Vector3(68, 0, -44), Vector3(14, 0.1, 10)),
	AABB(Vector3(68, 0, -32), Vector3(14, 0.1, 10)),
	AABB(Vector3(68, 0, -20), Vector3(14, 0.1, 10)),
]
const HAULER_BERTHS := [Vector3(104, 5, -51), Vector3(104, 5, -39), Vector3(104, 5, -27), Vector3(104, 5, -15)]
## The yard side: bays along the open face where bots set parts down for the build berth, and
## the face itself (z).
const YARD_SIDE_Z := -64.0
const DISPATCH_BAYS := [
	AABB(Vector3(16, 0, -62), Vector3(10, 0.1, 6)),
	AABB(Vector3(28, 0, -62), Vector3(10, 0.1, 6)),
	AABB(Vector3(40, 0, -62), Vector3(10, 0.1, 6)),
	AABB(Vector3(52, 0, -62), Vector3(10, 0.1, 6)),
]

signal changed(slot: int)

## One per place: {rack (index into RACKS), side, level, bay, part ("" empty), qty}.
var slots: Array[Dictionary] = []
## Places promised to parts on their way there (a bot carrying them): slot -> {part, qty}.
var pending: Dictionary = {}


func _init() -> void:
	for r in RACKS.size():
		var rack: Dictionary = RACKS[r]
		for bay in bays_of(r):
			for level in int(rack.levels):
				for side: int in rack.sides:
					slots.append({"rack": r, "side": side, "level": level, "bay": bay, "part": "", "qty": 0})


static func bays_of(r: int) -> int:
	var rack: Dictionary = RACKS[r]
	return int(floor(absf(float(rack.z1) - float(rack.z0)) / float(rack.bay) + 0.001))


static func kind_of(part: String) -> int:
	return int(PARTS[part].kind) if PARTS.has(part) else -1


static func parts_of_kind(kind: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in PARTS:
		if int(PARTS[id].kind) == kind:
			out.append(id)
	return out


func slot_kind(i: int) -> int:
	return int(RACKS[int(slots[i].rack)].kind)


func slot_count(kind: int) -> int:
	return slots.filter(func(s: Dictionary) -> bool: return int(RACKS[int(s.rack)].kind) == kind).size()


func filled_count(kind: int) -> int:
	return slots.filter(func(s: Dictionary) -> bool: return int(RACKS[int(s.rack)].kind) == kind and s.part != "").size()


## How many of `part` the stores hold.
func count(part: String) -> int:
	var n := 0
	for s in slots:
		if s.part == part:
			n += int(s.qty)
	return n


## Fills about `share` of every rack with parts of its kind, the same way on every machine.
func fill_demo(share := 0.6, seed_value := 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in slots.size():
		slots[i].part = ""
		slots[i].qty = 0
		if rng.randf() < share:
			var choice := parts_of_kind(slot_kind(i))
			var part: String = choice[rng.randi() % choice.size()]
			var full := int(PARTS[part].stack)
			slots[i].part = part
			slots[i].qty = maxi(1, full - rng.randi() % maxi(full, 1) / 2)


## Puts `qty` of `part` away: onto a place already holding it with room, else the empty place
## of its kind nearest goods in. The slot, or -1 when its racks are full. (One place holds up
## to the part's stack; what does not fit stays with the caller.)
func store(part: String, qty: int) -> int:
	var kind := kind_of(part)
	if kind < 0 or qty <= 0:
		return -1
	var full := int(PARTS[part].stack)
	var i := -1
	for j in slots.size():
		if slots[j].part == part and int(slots[j].qty) + qty <= full:
			i = j
			break
	if i < 0:
		i = _nearest_empty(kind, GOODS_IN_BAYS[0].get_center())
	if i < 0:
		return -1
	slots[i].part = part
	slots[i].qty = int(slots[i].qty) + mini(qty, full)
	changed.emit(i)
	return i


## Promises a place to `qty` of `part` on its way from goods in (as `store` picks one, never
## a place already promised to another part): the slot, or -1. `put` fills it on arrival.
func reserve(part: String, qty: int) -> int:
	var kind := kind_of(part)
	if kind < 0 or qty <= 0:
		return -1
	var full := int(PARTS[part].stack)
	var i := -1
	for j in slots.size():
		var due: Dictionary = pending.get(j, {})
		if slots[j].part == part and (due.is_empty() or due.part == part) \
				and int(slots[j].qty) + int(due.get("qty", 0)) + qty <= full:
			i = j
			break
	if i < 0:
		i = _nearest_empty(kind, GOODS_IN_BAYS[0].get_center())
	if i < 0:
		return -1
	var due: Dictionary = pending.get(i, {"part": part, "qty": 0})
	due.qty = int(due.qty) + qty
	pending[i] = due
	return i


## A promised load arrives: `qty` of `part` go into place `i`.
func put(i: int, part: String, qty: int) -> void:
	if pending.has(i):
		pending[i].qty = int(pending[i].qty) - qty
		if int(pending[i].qty) <= 0:
			pending.erase(i)
	slots[i].part = part
	slots[i].qty = mini(int(slots[i].qty) + qty, int(PARTS[part].stack))
	changed.emit(i)


## Takes `qty` from a place (all it has, at most): how many came out.
func take(i: int, qty := 1) -> int:
	if i < 0 or i >= slots.size() or slots[i].part == "":
		return 0
	var n := mini(qty, int(slots[i].qty))
	slots[i].qty = int(slots[i].qty) - n
	if int(slots[i].qty) <= 0:
		slots[i].part = ""
		slots[i].qty = 0
	changed.emit(i)
	return n


## The place holding `part` nearest the yard side, or -1.
func find(part: String) -> int:
	var best := -1
	var best_d := INF
	for i in slots.size():
		if slots[i].part != part:
			continue
		var d := slot_position(i).z - YARD_SIDE_Z
		if d < best_d:
			best_d = d
			best = i
	return best


## Where a place's parts lie: the middle of its floor (the arms, the deck or the cradle's
## top), station space.
func slot_position(i: int) -> Vector3:
	var s := slots[i]
	var rack: Dictionary = RACKS[int(s.rack)]
	var x := float(rack.x) + float(s.side) * float(rack.depth) * 0.5
	var y := float(rack.first) + float(rack.pitch) * float(s.level)
	var dz := float(rack.bay) * (float(s.bay) + 0.5)
	var z := float(rack.z0) + (dz if float(rack.z1) > float(rack.z0) else -dz)
	return Vector3(x, y, z)


## Where a bot works a place from: in the aisle beside it at the place's height (over a
## heavy cradle, the cradle itself).
func pick_point(i: int) -> Vector3:
	var s := slots[i]
	var rack: Dictionary = RACKS[int(s.rack)]
	var p := slot_position(i)
	if int(rack.kind) != HEAVY:   # a cradle has nothing over it: a bot comes down on top
		p.x = float(rack.x) + float(s.side) * (float(rack.depth) + 1.2)
	return p


## The size of a place (m): across, its clear height, along.
func slot_size(i: int) -> Vector3:
	var rack: Dictionary = RACKS[int(slots[i].rack)]
	var h := float(rack.pitch) - 0.25 if float(rack.pitch) > 0.0 else 3.4
	return Vector3(float(rack.depth), h, float(rack.bay))


func _nearest_empty(kind: int, to: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in slots.size():
		if slots[i].part != "" or slot_kind(i) != kind or pending.has(i):
			continue
		var d := slot_position(i).distance_squared_to(to)
		if d < best_d:
			best_d = d
			best = i
	return best
