class_name StoresReport
extends RefCounted
## What the stores hall holds, worked out from the racks (YardRackStore), for the warehouse
## stock screen: one line per part the stores keep (in stock or not), each rack kind's and
## storey's fill, every rack's bays, totals, and what the open design needs against it.
## Pure data: build one with StoresReport.build(store, catalog, totals) and read its fields.
##   var r := StoresReport.build(yard.rack_store, design.catalog, design.totals())
##   r.lines[0]   # {id, name, kind, qty, places, stack, room, inbound, need, short, unit_cost, value, mass, slots}

const KIND_TITLES: PackedStringArray = ["Long stock", "Plate", "Components", "Heavy"]
const KIND_RACKS: PackedStringArray = ["Cantilever racks", "Deep pallet racks", "Pallet racks", "Floor cradles"]
const STOREY_NAMES: PackedStringArray = ["Ground floor", "Upper deck"]

## One per part in YardRackStore.PARTS: id, name, kind (YardRackStore kind), qty (held),
## places (places holding it), stack (to a place), room (more that fit in its partly filled
## places), inbound (on their way in: promised places), need (the open design's count, 0
## with none open), short (need not covered by qty + inbound), unit_cost (CR, 0 unknown),
## value (CR), mass (kg, all held), racks (ids of the racks holding it), slots (slot indexes).
var lines: Array[Dictionary] = []
## Per kind (index = kind): {places, filled, qty, value, inbound}.
var kinds: Array[Dictionary] = []
## Per storey (0 ground, 1 upper): {places, filled}.
var storeys: Array[Dictionary] = []
## Per rack (index into YardRackStore.RACKS): {id, kind, storey, bays: [{places, filled, parts: {id: qty}}]}.
var racks: Array[Dictionary] = []
var total_qty := 0
var total_value := 0.0
var total_mass := 0.0
var total_places := 0
var filled_places := 0
var inbound_qty := 0
## Lines held (qty > 0), lines out (qty 0), lines short for the open design.
var lines_in := 0
var lines_out := 0
var lines_short := 0
## The open design's name ("" with none), and how many of its parts the stores keep at all.
var design_name := ""
var design_lines := 0


## `catalog` (DesignCatalog) gives unit costs and masses by their shared_part; `totals`
## (DesignTotals of the open design) gives what it needs. Either may be null.
static func build(store: YardRackStore, catalog: Object = null, totals: Object = null, design_name := "") -> StoresReport:
	var r := StoresReport.new()
	r.design_name = design_name
	if store == null:
		return r
	var cost := {}
	var mass := {}
	var by_type := {}   # design part type id -> shared part
	if catalog and catalog.get("parts") is Dictionary:
		for pt: Variant in (catalog.get("parts") as Dictionary).values():
			var sp := str(pt.get("shared_part"))
			if sp != "" and YardRackStore.PARTS.has(sp):
				by_type[str(pt.get("id"))] = sp
				if not cost.has(sp):
					cost[sp] = float(pt.get("cost"))
					mass[sp] = float(pt.get("mass"))
	var need := {}
	if totals and totals.get("lines") is Array:
		for line: Variant in totals.get("lines"):
			if not line is Dictionary or str(line.get("kind", "")) != "component":
				continue
			var id := str(line.id)
			var base := id.get_slice(":", 0)
			var sp: String = by_type.get(id, by_type.get(base, ""))
			if sp == "" and catalog and catalog.has_method("base_of"):
				var b: Variant = catalog.call("base_of", id)
				if b:
					sp = by_type.get(str(b.get("id")), "")
			if sp != "":
				need[sp] = int(need.get(sp, 0)) + int(round(float(line.qty)))
	for k in YardRackStore.KIND_NAMES.size():
		r.kinds.append({"places": 0, "filled": 0, "qty": 0, "value": 0.0, "inbound": 0})
	for s in 2:
		r.storeys.append({"places": 0, "filled": 0})
	for i in YardRackStore.RACKS.size():
		var rack: Dictionary = YardRackStore.RACKS[i]
		var bays: Array[Dictionary] = []
		for b in YardRackStore.bays_of(i):
			bays.append({"places": 0, "filled": 0, "parts": {}})
		r.racks.append({"id": str(rack.id), "kind": int(rack.kind), "storey": YardRackStore.storey_of(float(rack.base)), "bays": bays})
	var by_part := {}
	for id: String in YardRackStore.PARTS:
		var p: Dictionary = YardRackStore.PARTS[id]
		var line := {"id": id, "name": str(p.name), "kind": int(p.kind), "qty": 0, "places": 0,
				"stack": int(p.stack), "room": 0, "inbound": 0, "need": int(need.get(id, 0)), "short": 0,
				"unit_cost": float(cost.get(id, 0.0)), "value": 0.0, "mass": 0.0, "racks": [],
				"slots": [], "unit_mass": float(mass.get(id, 0.0))}
		by_part[id] = line
		r.lines.append(line)
	for i in store.slots.size():
		var s: Dictionary = store.slots[i]
		var rack: Dictionary = r.racks[int(s.rack)]
		var kind := int(rack.kind)
		var bay: Dictionary = rack.bays[int(s.bay)]
		bay.places += 1
		r.kinds[kind].places += 1
		r.storeys[int(rack.storey)].places += 1
		r.total_places += 1
		var part := str(s.part)
		if part == "" or not by_part.has(part):
			continue
		var qty := int(s.qty)
		var line: Dictionary = by_part[part]
		bay.filled += 1
		bay.parts[part] = int(bay.parts.get(part, 0)) + qty
		r.kinds[kind].filled += 1
		r.storeys[int(rack.storey)].filled += 1
		r.filled_places += 1
		line.qty += qty
		line.places += 1
		line.room += maxi(0, int(line.stack) - qty)
		(line.slots as Array).append(i)
		if not (line.racks as Array).has(str(rack.id)):
			(line.racks as Array).append(str(rack.id))
	for i: Variant in store.pending:
		var due: Dictionary = store.pending[i]
		if by_part.has(str(due.part)):
			by_part[str(due.part)].inbound += int(due.qty)
	for line in r.lines:
		line.value = float(line.qty) * float(line.unit_cost)
		line.mass = float(line.qty) * float(line.unit_mass)
		line.short = maxi(0, int(line.need) - int(line.qty) - int(line.inbound))
		var k := int(line.kind)
		r.kinds[k].qty += int(line.qty)
		r.kinds[k].value += float(line.value)
		r.kinds[k].inbound += int(line.inbound)
		r.total_qty += int(line.qty)
		r.total_value += float(line.value)
		r.total_mass += float(line.mass)
		r.inbound_qty += int(line.inbound)
		if int(line.qty) > 0:
			r.lines_in += 1
		else:
			r.lines_out += 1
		if int(line.short) > 0:
			r.lines_short += 1
		if int(line.need) > 0:
			r.design_lines += 1
	return r


func line(id: String) -> Dictionary:
	for l in lines:
		if l.id == id:
			return l
	return {}


## A place in words: "L1 west · bay 3 · level 2" (bays and levels from 1, levels from the floor).
static func place_name(store: YardRackStore, i: int) -> String:
	var s: Dictionary = store.slots[i]
	var rack: Dictionary = YardRackStore.RACKS[int(s.rack)]
	var side := "west" if int(s.side) < 0 else "east"
	if int(rack.kind) == YardRackStore.HEAVY:
		return "%s %s · cradle %d" % [rack.id, side, int(s.bay) + 1]
	return "%s %s · bay %d · level %d" % [rack.id, side, int(s.bay) + 1, int(s.level) + 1]


## Share of a count, 0..1.
static func share(part: int, whole: int) -> float:
	return float(part) / float(whole) if whole > 0 else 0.0
