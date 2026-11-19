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
		var st := DesignStructure.measure(d)
		var spec := d.structure
		# The structure proposed round the rooms (DesignFrame): its members, its skin and the
		# joints that hold them; the rooms' outer walls stand inside it as linings.
		var fc := DesignFrame.counts(DesignFrame.propose(d))
		var framed := int(fc.stations) > 0
		for row: Array in [["frame", DesignStructure.option("frame", str(spec.frame)), fc.member_m if framed else st.frame_m, "m"],
				["hull", DesignStructure.option("hull", str(spec.hull)), fc.skin_m2 if framed else st.outer_area, "m2"],
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
		door_n[k] = int(door_n.get(k, 0)) + 1
	for k: String in DesignCatalog.DOOR_ORDER:
		if door_n.has(k):
			var dk: Dictionary = DesignCatalog.DOOR_KINDS[k]
			var n := float(door_n[k])
			t.lines.append({"kind": "door", "id": k, "name": dk.name, "qty": n, "unit": "x",
					"cost": n * float(dk.cost), "mass": n * float(dk.mass), "hours": n * float(dk.hours)})
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
	return t


func power_balance() -> float:
	return power_made - power_used


## Acceleration at full thrust, m/s2 (0 with no mass).
func acceleration() -> float:
	return thrust * 1000.0 / mass if mass > 0.0 else 0.0


## Light years the ship goes on one jump: the drives' ratings (ly for a 100 t ship) over its
## mass in hundreds of tonnes; nothing without a drive or with no fuel aboard.
func jump_range() -> float:
	if jump_rating <= 0.0 or mass <= 0.0 or fuel_m3 <= 0.0:
		return 0.0
	return jump_rating * 100000.0 / mass


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
	return maxf(0.0, parts_signature + power_made * SIGNATURE_PER_KW + thrust * SIGNATURE_PER_KN)


## Stealth, 0 (lit up like a beacon) to 100 (invisible): falls off with the signature.
const STEALTH_SCALE := 120.0
func stealth() -> float:
	return 100.0 * exp(-signature() / STEALTH_SCALE)


## How the design meets a contract's demands. `demands` takes any of:
##   cargo_m3, crew, budget (most it may cost), max_mass (kg), accel (m/s2), build_days (most),
##   jump_ly, speed (m/s), defence, attack (damage a second), stealth (0..100), fuel_m3,
##   power (spare kW), sensor_km
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
