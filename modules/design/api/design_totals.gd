class_name DesignTotals
extends RefCounted
## The live numbers for a design (plan 2.5): the parts list with quantities, cost, mass,
## power balance, build hours, crew, cargo, availability, and how close the design comes to a
## contract's demands. Recomputed from the record in a few milliseconds, so every view calls
## compute() after each change rather than keeping running sums.

## The hull and frame round each room, per m2 of floor: frame, outer plates, deck.
const HULL_COST_PER_M2 := 650.0
const HULL_MASS_PER_M2 := 180.0
const HULL_HOURS_PER_M2 := 2.0

var floor_area := 0.0
var volume := 0.0
var cost := 0.0
var mass := 0.0
var build_hours := 0.0
## kW made and used; balance = made - used.
var power_made := 0.0
var power_used := 0.0
var thrust := 0.0
var crew := 0
var cargo_m3 := 0.0
var fuel_m3 := 0.0
## Longest supplier wait among the parts, days.
var lead_days := 0
## Parts list: [{kind: "room"|"component"|"hull", id, name, qty, unit, cost, mass, hours}]
var lines: Array[Dictionary] = []


static func compute(d: DesignRecord, cat: DesignCatalog) -> DesignTotals:
	var t := DesignTotals.new()
	var room_lines := {}
	for r: Dictionary in d.rooms.values():
		var rt := cat.room(str(r.type))
		var area := float(r.w) * float(r.d)
		t.floor_area += area
		t.volume += area * d.deck_height
		if rt == null:
			continue
		var line: Dictionary = room_lines.get(rt.id, {"kind": "room", "id": rt.id,
				"name": rt.display_name, "qty": 0.0, "unit": "m2", "cost": 0.0, "mass": 0.0, "hours": 0.0})
		line.qty += area
		line.cost += area * rt.cost_per_m2
		line.mass += area * rt.mass_per_m2
		line.hours += area * rt.hours_per_m2
		room_lines[rt.id] = line
		t.power_used += area * rt.power_per_m2
		t.crew += int(floor(area * rt.crew_per_m2 + 0.001))
		t.cargo_m3 += area * d.deck_height * rt.cargo_share
		t.fuel_m3 += area * d.deck_height * rt.fuel_share
	if t.floor_area > 0.0:
		t.lines.append({"kind": "hull", "id": "hull", "name": "Hull, frame and decks",
				"qty": t.floor_area, "unit": "m2", "cost": t.floor_area * HULL_COST_PER_M2,
				"mass": t.floor_area * HULL_MASS_PER_M2, "hours": t.floor_area * HULL_HOURS_PER_M2})
	var keys := room_lines.keys()
	keys.sort()
	for k in keys:
		t.lines.append(room_lines[k])
	var part_lines := {}
	for c: Dictionary in d.components.values():
		var pt := cat.part(str(c.type))
		if pt == null:
			continue
		var line: Dictionary = part_lines.get(pt.id, {"kind": "component", "id": pt.id,
				"name": pt.display_name, "qty": 0.0, "unit": "x", "cost": 0.0, "mass": 0.0, "hours": 0.0})
		line.qty += 1.0
		line.cost += pt.cost
		line.mass += pt.mass
		line.hours += pt.build_hours
		part_lines[pt.id] = line
		if pt.power >= 0.0:
			t.power_made += pt.power
		else:
			t.power_used -= pt.power
		t.thrust += pt.thrust
		t.crew += pt.crew
		t.lead_days = maxi(t.lead_days, pt.lead_days)
	keys = part_lines.keys()
	keys.sort()
	for k in keys:
		t.lines.append(part_lines[k])
	for line in t.lines:
		t.cost += line.cost
		t.mass += line.mass
		t.build_hours += line.hours
	return t


func power_balance() -> float:
	return power_made - power_used


## Acceleration at full thrust, m/s2 (0 with no mass).
func acceleration() -> float:
	return thrust * 1000.0 / mass if mass > 0.0 else 0.0


## How the design meets a contract's demands. `demands` takes any of:
##   cargo_m3, crew, budget (most it may cost), max_mass (kg), accel (m/s2), build_days (most)
## Returns one row per demand: {key, label, need, have, ok, share (0..1, 1 = met)}.
func fit(demands: Dictionary, crew_hours_per_day: float = 8.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: String in demands:
		var need := float(demands[key])
		var have := 0.0
		var more_is_better := true
		var label := key
		match key:
			"cargo_m3":
				have = cargo_m3
				label = "Cargo space, m3"
			"crew":
				have = crew
				label = "Crew bunks"
			"budget":
				have = cost
				more_is_better = false
				label = "Cost, credits"
			"max_mass":
				have = mass
				more_is_better = false
				label = "Mass, kg"
			"accel":
				have = acceleration()
				label = "Acceleration, m/s2"
			"build_days":
				have = build_hours / maxf(crew_hours_per_day, 1.0)
				more_is_better = false
				label = "Build time, days"
			_:
				continue
		var ok := have >= need if more_is_better else have <= need
		var share := 1.0
		if more_is_better:
			share = clampf(have / need, 0.0, 1.0) if need > 0.0 else 1.0
		elif have > 0.0:
			share = clampf(need / have, 0.0, 1.0)
		out.append({"key": key, "label": label, "need": need, "have": have, "ok": ok, "share": share})
	return out
