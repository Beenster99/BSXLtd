class_name YardRackStore
extends RefCounted
## The racking hall's store as data: every slot of the automated racks, what is in it, and
## the three presentation ports where a load is handed to a player (or, later, a bot). Pure
## data, the same on every machine; RackingHall (internal) draws and animates it.
##
## Three aisles, one per load size, each worked by its own stacker crane with racks on both
## sides: SMALL totes (0.6 m), MEDIUM crates (1.2 m) and LARGE cages (2.4 m). Space is the
## station's (floor y = 0, -Z towards the dock); the ports stand at the hall's front.
##   var store := YardRackStore.new(); store.fill_demo()
##   var slot := store.take_out(YardRackStore.SMALL)   # the crane brings a tote to its port
##   store.put_away(YardRackStore.SMALL)               # and takes it back

enum { SMALL, MEDIUM, LARGE }

const SIZE_NAMES: PackedStringArray = ["small", "medium", "large"]
## What a load of each size is called.
const LOAD_NAMES: PackedStringArray = ["tote", "crate", "cage"]
## Per size: aisle centre x (m), aisle width (m), cell size (m: a slot is a cube of it),
## levels, bays along the aisle.
const AISLES := [
	{"x": 18.0, "aisle": 1.6, "cell": 0.8, "levels": 12, "bays": 22},
	{"x": 25.5, "aisle": 2.0, "cell": 1.5, "levels": 6, "bays": 12},
	{"x": 37.0, "aisle": 3.2, "cell": 3.0, "levels": 3, "bays": 6},
]
## Racks start at this z (m, the end nearest the ports) and run towards -Z.
const RACK_FRONT_Z := -11.0
## How much of a cell the load fills.
const LOAD_FILL := 0.75
## Where each port hands a load over (the load's centre, station space).
const PORTS := [Vector3(18.0, 1.25, -6.6), Vector3(25.5, 0.85, -6.6), Vector3(37.0, 1.25, -6.4)]

## What the demo stock holds: label, how many come in one load.
const DEMO_GOODS := [
	["M8 bolts", 400], ["Rivets 6 mm", 1000], ["Wire 4 mm2", 50], ["Cable ties", 500],
	["Pipe clips", 120], ["Weld rod", 200], ["Fuses", 80], ["Hull plate 1x1", 6],
	["Box beam 2 m", 4], ["Junction box", 6], ["Pipe 2 m", 10], ["Lamp unit", 8],
	["Seal kit", 20], ["Panel 1x2", 4], ["Valve", 6], ["Breaker", 12],
]

signal changed(slot: int)
signal port_changed(size: int)

## One per slot: {size, side (-1 left, +1 right of the aisle), level, bay, load ({} empty,
## else {label, qty})}.
var slots: Array[Dictionary] = []
## The load standing at each port ({} for none), by size.
var ports: Array[Dictionary] = [{}, {}, {}]
## Which slot each port's load came from (-1: none).
var port_from: PackedInt32Array = [-1, -1, -1]


func _init() -> void:
	for size in 3:
		var a: Dictionary = AISLES[size]
		for bay in int(a.bays):
			for level in int(a.levels):
				for side: int in [-1, 1]:
					slots.append({"size": size, "side": side, "level": level, "bay": bay, "load": {}})


func slot_count(size: int) -> int:
	return slots.filter(func(s: Dictionary) -> bool: return s.size == size).size()


func filled_count(size: int) -> int:
	return slots.filter(func(s: Dictionary) -> bool: return s.size == size and not s.load.is_empty()).size()


## Fills about `share` of every aisle with the demo goods, the same way on every machine.
func fill_demo(share := 0.6, seed_value := 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in slots.size():
		if rng.randf() < share:
			var g: Array = DEMO_GOODS[rng.randi() % DEMO_GOODS.size()]
			var mult: int = [1, 4, 16][int(slots[i].size)]
			slots[i].load = {"label": g[0], "qty": int(g[1]) * mult}
		else:
			slots[i].load = {}


## Puts a load in the nearest empty slot of that size; the slot, or -1 when full.
func store(size: int, label: String, qty: int) -> int:
	var i := _nearest(size, false)
	if i >= 0:
		slots[i].load = {"label": label, "qty": qty}
		changed.emit(i)
	return i


## The crane takes the nearest load of that size to its port: the slot it came from, or -1
## when the port is already busy or the aisle is empty.
func take_out(size: int) -> int:
	if not ports[size].is_empty():
		return -1
	var i := _nearest(size, true)
	if i < 0:
		return -1
	ports[size] = slots[i].load
	port_from[size] = i
	slots[i].load = {}
	changed.emit(i)
	port_changed.emit(size)
	return i


## The load at the port goes back into the nearest empty slot: that slot, or -1.
func put_away(size: int) -> int:
	if ports[size].is_empty():
		return -1
	var i := _nearest(size, false)
	if i < 0:
		return -1
	slots[i].load = ports[size]
	ports[size] = {}
	port_from[size] = -1
	changed.emit(i)
	port_changed.emit(size)
	return i


## The middle of a slot (station space).
func slot_position(i: int) -> Vector3:
	var s := slots[i]
	var a: Dictionary = AISLES[int(s.size)]
	var cell: float = a.cell
	var x: float = float(a.x) + float(s.side) * (float(a.aisle) * 0.5 + cell * 0.5)
	return Vector3(x, 0.35 + cell * (float(s.level) + 0.5), RACK_FRONT_Z - cell * (float(s.bay) + 0.5))


## The size of the load of that size (a cube, m).
static func load_size(size: int) -> float:
	return float(AISLES[size].cell) * LOAD_FILL


## Nearest the ports first: lowest bay, then lowest level.
func _nearest(size: int, filled: bool) -> int:
	var best := -1
	var best_key := 1 << 30
	for i in slots.size():
		var s := slots[i]
		if int(s.size) != size or (s.load.is_empty() == filled):
			continue
		var key := int(s.bay) * 100 + int(s.level) * 2 + (0 if int(s.side) < 0 else 1)
		if key < best_key:
			best_key = key
			best = i
	return best
