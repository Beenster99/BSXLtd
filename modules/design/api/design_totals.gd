class_name DesignTotals
extends RefCounted
## The live numbers for a design (plan 2.5): the parts list with quantities, cost, mass,
## power balance, build hours, crew, cargo, availability, and how close the design comes to a
## contract's demands. Recomputed from the record in a few milliseconds, so every view calls
## compute() after each change rather than keeping running sums.

## The hull round the rooms (frame, outer plating, inner walls, decks) is priced from
## DesignStructure; wires and pipes from DesignServices.KINDS, per m.

var floor_area := 0.0
var volume := 0.0
var cost := 0.0
## Dry mass, kg: everything built into her (hull, rooms, parts, doors, wires and pipes), her
## tanks, hold and berths empty. Shelving and racking are always empty: she is a new ship.
var mass := 0.0
## What she carries when she flies, kg: the fuel in her tanks when full (FUEL_KG_PER_M3), and
## her people (PERSON_KG for each bunk: a crew member with suit, kit and effects).
var fuel_mass := 0.0
var occupancy_mass := 0.0
## The most her holds and racking are rated to carry, kg (CARGO_KG_PER_M3 of cargo space).
var cargo_max := 0.0
var build_hours := 0.0
## kW made and used; balance = made - used.
## made counts what solar delivers where she works (DesignPower), not batteries.
var power_made := 0.0
var power_used := 0.0
## Power by source (DesignPower): solar's rating in full sun and what it delivers in her working
## region; what fuel-burning sources make; stores' capacity, kWh, and their rating, kW.
var region := DesignPower.DEFAULT_REGION
var solar_rated := 0.0
var solar_kw := 0.0
var fuelled_kw := 0.0
var store_kwh := 0.0
var store_kw := 0.0
## Fuel burned a kWh across the fuelled sources, weighted by their output, m3.
var burn_per_kwh := 0.0
## Reactors aboard (DesignPower.REACTORS).
var reactors := 0
var thrust := 0.0
var crew := 0
var cargo_m3 := 0.0
var fuel_m3 := 0.0
## Longest supplier wait among the parts, days.
var lead_days := 0
## The finished ship's fighting and travelling numbers, summed from its graded components
## (DesignGrades): see jump_range(), speed(), defence_rating(), stealth().
var jump_rating := 0.0
var attack := 0.0
var defence := 0.0
## Heat and emissions from the parts (dampers and radiators take some away), before the
## reactors' and engines' own share (signature()).
var parts_signature := 0.0
var sensor_km := 0.0
var integrity := 0.0
## Mass of the hull lines (frame, skin, inner walls, decks), kg: counts toward defence.
var hull_mass := 0.0
## Parts list: [{kind: "hull"|"room"|"component"|"service", id, name, qty, unit, cost, mass, hours}]
## Hull lines come first.
var lines: Array[Dictionary] = []


## `structure` and `plan` (DesignStructure.measure, DesignFrame.propose of `d`) can be passed
## in when already worked out: they are the slow part (the bus keeps both per edit).
static func compute(d: DesignRecord, cat: DesignCatalog, structure: DesignStructure = null,
		plan: Variant = null) -> DesignTotals:
	var t := DesignTotals.new()
	t.region = DesignPower.region_of(d)
	var sun := DesignPower.sun(t.region)
	var burn_sum := 0.0
	var room_lines := {}
	for r: Dictionary in d.rooms.values():
		var rt := cat.room(str(r.type))
		var area := DesignRecord.room_area(r)
		t.floor_area += area
		t.volume += area * d.deck_height
		if rt == null:
			continue
		var line: Dictionary = room_lines.get(rt.id, {"kind": "room", "id": rt.id,
				"name": rt.display_name, "qty": 0.0, "unit": "m2", "cost": 0.0, "mass": 0.0, "hours": 0.0, "tags": []})
		line.tags.append(DesignRecord.tag(str(r.id)))
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
		var st := structure if structure else DesignStructure.measure(d)
		var spec := d.structure
		# The structure proposed round the rooms (DesignFrame): its members, its skin and the
		# joints that hold them; the rooms' outer walls stand inside it as linings.
		var fc := DesignFrame.counts(plan as Dictionary if plan is Dictionary else DesignFrame.propose(d))
		var framed := int(fc.stations) > 0
		for row: Array in [["frame", DesignStructure.option("frame", str(spec.frame)), fc.member_m if framed else st.frame_m, "m"],
				["hull", DesignStructure.option("hull", str(spec.hull)), fc.skin_m2 if framed else st.outer_area, "m2"],
				["armour", DesignFrame.ARMOUR, float(fc.get("armour_m2", 0.0)), "m2"],
				["welds", DesignFrame.WELD, float(fc.welds), "x"],
				["rivets", DesignFrame.RIVET, float(fc.rivets), "x"],
				["bolts", DesignFrame.BOLT, float(fc.bolts), "x"],
				["inner", DesignStructure.option("inner", str(spec.inner)), st.inner_area + (st.outer_area if framed else 0.0), "m2"],
				["deck", DesignStructure.DECK, st.floor_area, "m2"]]:
			var o: Dictionary = row[1]
			var qty: float = row[2]
			if qty <= 0.0:
				continue
			t.lines.append({"kind": "hull", "id": row[0], "name": o.name, "qty": qty, "unit": row[3],
					"cost": qty * float(o.cost), "mass": qty * float(o.mass), "hours": qty * float(o.hours)})
	var keys := room_lines.keys()
	keys.sort()
	for k in keys:
		t.lines.append(room_lines[k])
	var part_lines := {}
	for c: Dictionary in d.components.values() + d.mounts.values():
		var pt := cat.part(str(c.type))
		if pt == null:
			continue
		var line: Dictionary = part_lines.get(pt.id, {"kind": "component", "id": pt.id,
				"name": pt.display_name, "qty": 0.0, "unit": "x", "cost": 0.0, "mass": 0.0, "hours": 0.0, "tags": []})
		line.tags.append(DesignRecord.tag(str(c.id)))
		line.qty += 1.0
		line.cost += pt.cost
		line.mass += pt.mass
		line.hours += pt.build_hours
		part_lines[pt.id] = line
		if pt.power >= 0.0:
			match DesignPower.kind_of(pt.id, pt.power):
				"solar":
					t.solar_rated += pt.power
					t.solar_kw += pt.power * sun
				"store":
					t.store_kw += pt.power
					t.store_kwh += pt.power * float(DesignPower.STORE_HOURS.get(DesignPower.base_id(pt.id), 1.0))
				"fuelled":
					t.fuelled_kw += pt.power
					burn_sum += pt.power * DesignPower.burn_of(pt.id)
		else:
			t.power_used -= pt.power
		if DesignPower.base_id(pt.id) in DesignPower.REACTORS:
			t.reactors += 1
		t.thrust += pt.thrust
		t.crew += pt.crew
		t.lead_days = maxi(t.lead_days, pt.lead_days)
		t.cargo_m3 += pt.cargo
		t.fuel_m3 += pt.tank
		t.jump_rating += pt.jump
		t.attack += pt.attack
		t.defence += pt.defence
		t.parts_signature += pt.signature
		t.sensor_km = maxf(t.sensor_km, pt.sensor)
		t.integrity += pt.integrity
	keys = part_lines.keys()
	keys.sort()
	for k in keys:
		t.lines.append(part_lines[k])
	var door_n := {}
	for g: Dictionary in d.doors.values():
		var k := str(g.get("kind", "door"))
		if not DesignCatalog.DOOR_KINDS.has(k):
			k = "door"
		var sum: Dictionary = door_n.get(k, {"qty": 0.0, "cost": 0.0, "mass": 0.0, "hours": 0.0, "tags": []})
		sum.tags.append(DesignRecord.tag(str(g.id)))
		var c := DesignCatalog.door_cost(g)
		sum.qty += 1.0
		sum.cost += c.cost
		sum.mass += c.mass
		sum.hours += c.hours
		door_n[k] = sum
	for k: String in DesignCatalog.DOOR_ORDER:
		if door_n.has(k):
			var dk: Dictionary = DesignCatalog.DOOR_KINDS[k]
			var sum: Dictionary = door_n[k]
			t.lines.append({"kind": "door", "id": k, "name": dk.name, "qty": sum.qty, "unit": "x",
					"cost": sum.cost, "mass": sum.mass, "hours": sum.hours, "tags": sum.tags})
	var run_m := {}
	for w: Dictionary in d.runs.values():
		if DesignServices.KINDS.has(str(w.kind)):
			run_m[str(w.kind)] = float(run_m.get(str(w.kind), 0.0)) + DesignServices.length(w)
	for kind: String in DesignServices.KINDS:
		if run_m.has(kind):
			var k2: Dictionary = DesignServices.KINDS[kind]
			var m: float = run_m[kind]
			t.lines.append({"kind": "service", "id": kind, "name": k2.name, "qty": m, "unit": "m",
					"cost": m * float(k2.cost), "mass": m * float(k2.mass), "hours": m * float(k2.hours)})
	for line in t.lines:
		if line.kind == "hull":
			t.hull_mass += float(line.mass)
		t.cost += line.cost
		t.mass += line.mass
		t.build_hours += line.hours
	t.power_made = t.solar_kw + t.fuelled_kw
	t.burn_per_kwh = burn_sum / t.fuelled_kw if t.fuelled_kw > 0.0 else 0.0
	t.fuel_mass = t.fuel_m3 * FUEL_KG_PER_M3
	t.occupancy_mass = float(t.crew) * PERSON_KG
	t.cargo_max = t.cargo_m3 * CARGO_KG_PER_M3
	return t


## Full tanks, kg a m3 (a refined drive fuel).
const FUEL_KG_PER_M3 := 800.0
## One person aboard with suit, kit, effects and their share of stores, kg.
const PERSON_KG := 100.0
## The rated load of a m3 of hold or racking, kg (mixed freight).
const CARGO_KG_PER_M3 := 400.0


## Dry mass, kg: as built, nothing aboard.
func dry_mass() -> float:
	return mass


## Wet mass, kg: dry, with her tanks full.
func wet_mass() -> float:
	return mass + fuel_mass


## What she weighs as she flies, kg: wet, with her people aboard and her hold empty. The
## ratings (acceleration, top speed, jump range) are for this.
func flying_mass() -> float:
	return wet_mass() + occupancy_mass


func power_balance() -> float:
	return power_made - power_used


## kW the fuel-burning sources must make to carry the load once solar has given what it can.
func fuelled_load() -> float:
	return clampf(power_used - solar_kw, 0.0, fuelled_kw)


## Days she runs without refuelling at her full working load: the tanks over what her
## generators and reactors burn; DesignPower.ENDURANCE_CAP when solar carries it all (with the
## stores to ride out shadow) or nothing burns. 0 when she cannot carry her load at all.
func endurance_days() -> float:
	if power_balance() < 0.0:
		return 0.0
	var load := fuelled_load()
	if load <= 0.0:
		return DesignPower.ENDURANCE_CAP if solar_rides_shadow() else 0.0
	var per_day := load * 24.0 * burn_per_kwh
	if per_day <= 0.0:
		return DesignPower.ENDURANCE_CAP
	return minf(DesignPower.ENDURANCE_CAP, fuel_m3 / per_day)


## True when the ship needs no stores for shadow (fuelled power covers the load) or has the
## stores to carry the load through her region's shadow hours.
func solar_rides_shadow() -> bool:
	var gap := maxf(0.0, power_used - fuelled_kw)
	if gap <= 0.0 or solar_kw <= 0.0:
		return true
	return store_kw >= gap and store_kwh >= gap * DesignPower.shadow_hours(region)


## Acceleration at full thrust, m/s2 (0 with no mass).
func acceleration() -> float:
	var m := flying_mass()
	return thrust * 1000.0 / m if m > 0.0 else 0.0


## Light years the ship goes on one jump: the drives' ratings (ly for a 100 t ship) over its
## flying mass in hundreds of tonnes; nothing without a drive or with no fuel aboard.
func jump_range() -> float:
	var m := flying_mass()
	if jump_rating <= 0.0 or m <= 0.0 or fuel_m3 <= 0.0:
		return 0.0
	return jump_rating * 100000.0 / m


## Top speed, m/s: grows with the square root of the acceleration (drag-free flight capped by
## the drive's safe limit), SPEED_CAP at most.
const SPEED_PER_ROOT_ACCEL := 90.0
const SPEED_CAP := 600.0
func speed() -> float:
	return minf(SPEED_CAP, SPEED_PER_ROOT_ACCEL * sqrt(acceleration()))


## Defence points: armour and shields fitted, plus the hull's own plating (DEFENCE_PER_HULL_T
## a tonne).
const DEFENCE_PER_HULL_T := 0.5
func defence_rating() -> float:
	return defence + hull_mass / 1000.0 * DEFENCE_PER_HULL_T


## The ship's signature: the parts' heat and emissions plus a share of the power it makes and
## the thrust it has, never below zero.
const SIGNATURE_PER_KW := 0.15
const SIGNATURE_PER_KN := 0.05
func signature() -> float:
	var kw := fuelled_kw + solar_kw * DesignPower.SOLAR_SIGNATURE_SHARE
	return maxf(0.0, parts_signature + kw * SIGNATURE_PER_KW + thrust * SIGNATURE_PER_KN)


## Stealth, 0 (lit up like a beacon) to 100 (invisible): falls off with the signature.
const STEALTH_SCALE := 120.0
func stealth() -> float:
	return 100.0 * exp(-signature() / STEALTH_SCALE)


## How the design meets a contract's demands. `demands` takes any of:
##   cargo_m3, crew, budget (most it may cost), max_mass or dry_mass (most, kg), wet_mass (most,
##   kg), fuel_mass (least, kg: a long haul wants a lot), occupancy_mass (least, kg), cargo_max
##   (least, kg), accel (m/s2), build_days (most), jump_ly, speed (m/s), defence, attack
##   (damage a second), stealth (0..100), fuel_m3, power (spare kW), sensor_km,
##   endurance_days (least: days without refuelling), reactors (most aboard: 0 = no reactor)
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
			"max_mass", "dry_mass":
				have = mass
				more_is_better = false
				label = "Dry mass, kg"
			"wet_mass":
				have = wet_mass()
				more_is_better = false
				label = "Wet mass, kg"
			"fuel_mass":
				have = fuel_mass
				label = "Fuel load, kg"
			"occupancy_mass":
				have = occupancy_mass
				label = "Occupancy mass, kg"
			"cargo_max":
				have = cargo_max
				label = "Cargo max, kg"
			"accel":
				have = acceleration()
				label = "Acceleration, m/s2"
			"build_days":
				have = build_hours / maxf(crew_hours_per_day, 1.0)
				more_is_better = false
				label = "Build time, days"
			"jump_ly":
				have = jump_range()
				label = "Jump range, ly"
			"speed":
				have = speed()
				label = "Top speed, m/s"
			"defence":
				have = defence_rating()
				label = "Defence"
			"attack":
				have = attack
				label = "Attack, damage/s"
			"stealth":
				have = stealth()
				label = "Stealth"
			"fuel_m3":
				have = fuel_m3
				label = "Fuel, m3"
			"power":
				have = power_balance()
				label = "Spare power, kW"
			"sensor_km":
				have = sensor_km
				label = "Sensor range, km"
			"endurance_days":
				have = endurance_days()
				label = "Days without refuelling"
			"reactors":
				have = reactors
				more_is_better = false
				label = "Reactors aboard" if need > 0.0 else "No reactor aboard"
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
