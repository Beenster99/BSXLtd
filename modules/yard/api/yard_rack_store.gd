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
##   var slot := store.store("FuelTank", 1)   # where a delivery goes
##   store.take(slot, 1)                         # a bot takes one out to the yard

enum { LONG, PLATE, COMPONENT, HEAVY }

const KIND_NAMES: PackedStringArray = ["long", "plate", "component", "heavy"]

## The parts the stores keep, by Void Salvage part_name (VsParts: the same part in both games,
## drawn by Void Salvage's own code): id -> {name, kind (rack), size (m, as it lies: x across
## the rack, y up, z along it), stack (how many to one place)}. RackingHall draws each one.
const PARTS := {
	"BoxBeam": {"name": "Box beam 6 m", "kind": LONG, "size": Vector3(0.21, 0.24, 6.0), "stack": 6},
	"Girder": {"name": "Girder 4 m", "kind": LONG, "size": Vector3(0.16, 0.2, 4.0), "stack": 8},
	"Pipe": {"name": "Pipe 4 m", "kind": LONG, "size": Vector3(0.22, 0.22, 4.0), "stack": 10},
	"BigPipe": {"name": "Big pipe 5 m", "kind": LONG, "size": Vector3(0.43, 0.43, 5.0), "stack": 4},
	"HullPlate": {"name": "Hull plate 1.5x2.5", "kind": PLATE, "size": Vector3(1.5, 0.06, 2.5), "stack": 12},
	"DeckPlate": {"name": "Deck plate 1.2x2.4", "kind": PLATE, "size": Vector3(1.2, 0.04, 2.4), "stack": 10},
	"ArmourSlab": {"name": "Armour slab 2x2.8", "kind": PLATE, "size": Vector3(2.0, 0.2, 2.8), "stack": 4},
	"Radiator": {"name": "Radiator 2.8 m", "kind": PLATE, "size": Vector3(1.2, 0.18, 2.8), "stack": 4},
	"SolarPanel": {"name": "Solar panel 1.6x3", "kind": PLATE, "size": Vector3(1.61, 0.07, 3.0), "stack": 8},
	"JunctionBox": {"name": "Junction box", "kind": COMPONENT, "size": Vector3(0.22, 0.34, 0.4), "stack": 8},
	"FuelValve": {"name": "Valve", "kind": COMPONENT, "size": Vector3(0.06, 0.22, 0.17), "stack": 10},
	"SwitchCabinet": {"name": "Switch cabinet", "kind": COMPONENT, "size": Vector3(0.48, 1.4, 0.72), "stack": 2},
	"BatteryRack": {"name": "Battery rack", "kind": COMPONENT, "size": Vector3(0.51, 1.4, 1.2), "stack": 1},
	"HeatSink": {"name": "Heat sink", "kind": COMPONENT, "size": Vector3(0.32, 1.0, 0.91), "stack": 2},
	"Gyroscope": {"name": "Gyroscope", "kind": COMPONENT, "size": Vector3(1.04, 1.0, 1.04), "stack": 1},
	"CapacitorBank": {"name": "Capacitor bank", "kind": COMPONENT, "size": Vector3(0.71, 1.4, 1.4), "stack": 1},
	"Generator": {"name": "Generator", "kind": COMPONENT, "size": Vector3(0.9, 1.2, 1.4), "stack": 1},
	"PilotConsole": {"name": "Pilot console", "kind": COMPONENT, "size": Vector3(0.71, 1.01, 1.81), "stack": 1},
	"SideConsole": {"name": "Side console", "kind": COMPONENT, "size": Vector3(0.61, 1.01, 1.01), "stack": 2},
	"Antenna": {"name": "Antenna", "kind": COMPONENT, "size": Vector3(1.21, 1.59, 1.21), "stack": 1},
	"SideThruster": {"name": "Side thruster", "kind": COMPONENT, "size": Vector3(0.41, 0.84, 0.6), "stack": 2},
	"IonThruster": {"name": "Ion thruster", "kind": COMPONENT, "size": Vector3(0.8, 1.2, 0.8), "stack": 2},
	"LiftThruster": {"name": "Lift thruster", "kind": COMPONENT, "size": Vector3(1.21, 0.61, 1.21), "stack": 2},
	"Seat": {"name": "Seat", "kind": COMPONENT, "size": Vector3(0.53, 1.19, 0.6), "stack": 2},
	"MainThruster": {"name": "Main thruster", "kind": HEAVY, "size": Vector3(1.87, 1.8, 1.87), "stack": 1},
	"HydrogenEngine": {"name": "Hydrogen engine", "kind": HEAVY, "size": Vector3(2.4, 2.0, 2.4), "stack": 1},
	"TurbineEngine": {"name": "Turbine engine", "kind": HEAVY, "size": Vector3(2.0, 1.6, 2.0), "stack": 1},
	"FuelTank": {"name": "Fuel tank", "kind": HEAVY, "size": Vector3(1.23, 2.8, 1.25), "stack": 1},
	"SideTank": {"name": "Side tank", "kind": HEAVY, "size": Vector3(1.24, 2.4, 1.25), "stack": 1},
	"Reactor": {"name": "Reactor", "kind": HEAVY, "size": Vector3(1.77, 2.0, 1.77), "stack": 1},
	"ReactorCore": {"name": "Reactor core", "kind": HEAVY, "size": Vector3(1.46, 2.46, 2.03), "stack": 1},
	"Assembler": {"name": "Assembler", "kind": HEAVY, "size": Vector3(1.27, 1.81, 1.67), "stack": 1},
	"MedStation": {"name": "Med station", "kind": HEAVY, "size": Vector3(0.59, 2.2, 1.6), "stack": 1},
	"Bunk": {"name": "Bunk", "kind": HEAVY, "size": Vector3(0.91, 1.9, 2.03), "stack": 1},
	"Locker": {"name": "Locker", "kind": HEAVY, "size": Vector3(0.54, 1.9, 0.81), "stack": 2},
	"CrashSeat": {"name": "Crash seat", "kind": HEAVY, "size": Vector3(0.6, 1.9, 0.65), "stack": 2},
	"Workbench": {"name": "Workbench", "kind": HEAVY, "size": Vector3(0.82, 1.95, 2.0), "stack": 1},
	"GalleyCounter": {"name": "Galley counter", "kind": HEAVY, "size": Vector3(0.65, 1.95, 3.0), "stack": 1},
}

## The hall's two storeys (0.4.1 playtest: "add another layer to the storage hall, same size so
## we double capacity"): the upper deck's top (y, m) and its east edge (x): past it the hall is
## open floor to roof over goods in, the well the bots rise and drop through between storeys.
const UPPER_FLOOR_Y := 16.0
const UPPER_EDGE_X := 64.0
const WELL_X := 74.0

## The racks, west to east on each storey: id, kind, x of the rack's middle (m), the sides it
## opens to (-1 west, +1 east), its z from the yard side (z0) to the back (z1), each place's
## length along z (bay), its levels, the first level's height above its floor and the pitch
## between them (m), how deep a place is across (depth, m, from the rack's middle), and the
## floor it stands on (base, m: 0 the ground floor, UPPER_FLOOR_Y the upper deck).
const RACKS := [
	{"id": "L1", "kind": LONG, "x": 20.5, "sides": [-1, 1], "z0": -52.0, "z1": -10.0, "bay": 7.0, "levels": 5, "first": 0.9, "pitch": 1.5, "depth": 2.2, "base": 0.0},
	{"id": "L2", "kind": LONG, "x": 29.0, "sides": [-1, 1], "z0": -52.0, "z1": -10.0, "bay": 7.0, "levels": 5, "first": 0.9, "pitch": 1.5, "depth": 2.2, "base": 0.0},
	{"id": "P1", "kind": PLATE, "x": 38.0, "sides": [-1, 1], "z0": -52.0, "z1": -10.0, "bay": 3.5, "levels": 4, "first": 0.15, "pitch": 1.9, "depth": 2.3, "base": 0.0},
	{"id": "C1", "kind": COMPONENT, "x": 47.0, "sides": [-1, 1], "z0": -52.0, "z1": -10.0, "bay": 3.0, "levels": 5, "first": 0.15, "pitch": 1.9, "depth": 1.8, "base": 0.0},
	{"id": "H1", "kind": HEAVY, "x": 58.5, "sides": [-1, 1], "z0": -52.0, "z1": -10.0, "bay": 4.2, "levels": 1, "first": 0.35, "pitch": 0.0, "depth": 3.0, "base": 0.0},
	{"id": "L3", "kind": LONG, "x": 20.5, "sides": [-1, 1], "z0": -52.0, "z1": -10.0, "bay": 7.0, "levels": 5, "first": 0.9, "pitch": 1.5, "depth": 2.2, "base": UPPER_FLOOR_Y},
	{"id": "L4", "kind": LONG, "x": 29.0, "sides": [-1, 1], "z0": -52.0, "z1": -10.0, "bay": 7.0, "levels": 5, "first": 0.9, "pitch": 1.5, "depth": 2.2, "base": UPPER_FLOOR_Y},
	{"id": "P2", "kind": PLATE, "x": 38.0, "sides": [-1, 1], "z0": -52.0, "z1": -10.0, "bay": 3.5, "levels": 4, "first": 0.15, "pitch": 1.9, "depth": 2.3, "base": UPPER_FLOOR_Y},
	{"id": "C2", "kind": COMPONENT, "x": 47.0, "sides": [-1, 1], "z0": -52.0, "z1": -10.0, "bay": 3.0, "levels": 5, "first": 0.15, "pitch": 1.9, "depth": 1.8, "base": UPPER_FLOOR_Y},
	{"id": "H2", "kind": HEAVY, "x": 58.5, "sides": [-1, 1], "z0": -52.0, "z1": -10.0, "bay": 4.2, "levels": 1, "first": 0.35, "pitch": 0.0, "depth": 3.0, "base": UPPER_FLOOR_Y},
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

## A place changed (slot), or every place at once (-1: set_stock).
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


## Lays out `parts` ({part id: qty}, YardRackStore.PARTS ids; others are left out) on empty
## racks, the same way on every machine: each kind's stacks spread evenly over its racks'
## places, one part's stacks side by side. What does not fit is left out. Emits changed(-1).
func set_stock(parts: Dictionary) -> void:
	pending.clear()
	for s in slots:
		s.part = ""
		s.qty = 0
	var ids: Array = parts.keys()
	ids.sort()
	for kind in KIND_NAMES.size():
		var stacks: Array[Dictionary] = []
		for id: Variant in ids:
			var part := str(id)
			if kind_of(part) != kind:
				continue
			var left := int(parts[id])
			var full := int(PARTS[part].stack)
			while left > 0:
				stacks.append({"part": part, "qty": mini(left, full)})
				left -= full
		var places: Array[int] = []
		for i in slots.size():
			if slot_kind(i) == kind:
				places.append(i)
		var n := mini(stacks.size(), places.size())
		for k in n:
			# Evenly over the places (k * places / stacks), so a few parts don't all bunch at one end.
			var i: int = places[int(floor(float(k) * float(places.size()) / float(n)))]
			slots[i].part = stacks[k].part
			slots[i].qty = int(stacks[k].qty)
	changed.emit(-1)


## How many of each part the racks hold: {part id: qty} (parts held only).
func counts() -> Dictionary:
	var out := {}
	for s in slots:
		if s.part != "":
			out[s.part] = int(out.get(s.part, 0)) + int(s.qty)
	return out


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
	var y := float(rack.base) + float(rack.first) + float(rack.pitch) * float(s.level)
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
## Which storey a place, or any point in the hall, is on: 0 the ground floor, 1 the upper deck.
static func storey_of(y: float) -> int:
	return 1 if y >= UPPER_FLOOR_Y - 0.3 else 0


static func floor_y(storey: int) -> float:
	return UPPER_FLOOR_Y if storey == 1 else 0.0


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
		# Along the floor, the upper deck's place over it hardly further (bots rise through
		# the well quickly): the two storeys fill together.
		var at := slot_position(i)
		var d := Vector2(at.x - to.x, at.z - to.z).length() + absf(at.y - to.y) * 0.05
		if d < best_d:
			best_d = d
			best = i
	return best
