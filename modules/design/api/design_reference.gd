class_name DesignReference
extends RefCounted
## The plainest ship that meets a client's demands (Wave 4: contracts and the trial): rooms
## sized for the crew, cargo and fuel asked for, and the cheapest catalogue components that
## reach each rating, priced by the same DesignTotals a player's design is. It is what "the
## cheapest honest build" costs, so a contract's budget can be judged against it: a client who
## asks for a stealth bomber with CR 500,000 to spend is shown up here.
##
## Not a design tool: the layout is a row of boxes on as many decks as it needs, nothing is
## placed with care, and a good designer beats it. Ratings depend on mass and mass on the parts
## picked, so it settles over a few rounds (ROUNDS).

const ROUNDS := 24
## Floor area per crew member in the quarters, m2 (quarters house 0.25 a m2).
const M2_PER_CREW := 4.0
## Room laid out around a part's footprint, as a multiple of the footprint.
const ROOM_PER_FOOTPRINT := 1.8
## Spare made over what is asked, so a rating just reached stays reached after the next round.
const MARGIN := 1.06
## Largest deck area before the build takes another deck, m2.
const DECK_M2 := 2400.0
## Radiators and dampers tried at most for a stealth demand before it is called out of reach.
const MAX_COOLING := 80

## What each rating is bought with: [part ids to choose from (cheapest wins), field on the part].
const BUY: Dictionary = {
	"thrust": [["main_thruster", "engine_pod", "stern_thruster", "main_engine", "turbine_engine"], "thrust"],
	"jump": [["jump_drive", "quantum_core"], "jump"],
	"attack": [["turret", "twin_turret", "railgun", "naval_turret", "missile_launcher", "gatling_gun"], "attack"],
	"defence": [["armour_cowl", "shield_generator", "shield_booster", "bulkhead_plating"], "defence"],
	"power": [["generator", "reactor_small", "reactor_core", "fission_pile", "hydrogen_generator"], "power"],
	"sensor": [["radar_array", "survey_array", "antenna"], "sensor"],
	"cooling": [["radiator", "heat_exchanger", "signature_damper", "heat_sink"], "signature"],
}


## The reference build for `demands` (DesignTotals.fit keys) and `clauses` (ShipOrders
## clauses). Returns {record: DesignRecord, totals: DesignTotals, cost, met: bool,
## misses: PackedStringArray (the demands it could not reach, by key)}.
static func build(demands: Dictionary, clauses: Array, cat: DesignCatalog) -> Dictionary:
	var grade := "S"
	if float(demands.get("stealth", 0.0)) > 0.0:
		grade = "Q"
	var forced := _forced_grades(clauses)
	var plan := {"thrust": 0.0, "jump": 0.0, "attack": 0.0, "defence": 0.0, "power": 0.0, "sensor": 0.0, "cooling": 0.0}
	var rec: DesignRecord = null
	var t: DesignTotals = null
	var picks := {}
	for round_i in ROUNDS:
		picks = {}
		for key: String in plan:
			if float(plan[key]) > 0.0:
				picks[key] = _cheapest(key, float(plan[key]), grade, forced, cat)
		rec = _layout(demands, clauses, picks, grade, forced, cat)
		t = DesignTotals.compute(rec, cat)
		var next := _needs(demands, t, plan)
		if next == plan:
			break
		plan = next
	var misses: PackedStringArray = []
	for row in t.fit(_rated(demands)):
		if not row.ok:
			misses.append(str(row.key))
	return {"record": rec, "totals": t, "cost": t.cost, "met": misses.is_empty(), "misses": misses}


## The demands the build is held to (cost, mass and time are what it is judged by, not aimed at).
static func _rated(demands: Dictionary) -> Dictionary:
	var out := demands.duplicate()
	for k in ["budget", "max_mass", "build_days"]:
		out.erase(k)
	return out


## How much of each rating to buy next round, from what the last round's ship came to.
static func _needs(demands: Dictionary, t: DesignTotals, plan: Dictionary) -> Dictionary:
	var next := plan.duplicate()
	var mass := maxf(t.mass, 1000.0)
	if demands.has("speed"):
		var accel := pow(float(demands.speed) / DesignTotals.SPEED_PER_ROOT_ACCEL, 2.0)
		next.thrust = accel * mass / 1000.0 * MARGIN
	if demands.has("jump_ly"):
		next.jump = float(demands.jump_ly) * mass / 100000.0 * MARGIN
	if demands.has("attack"):
		next.attack = float(demands.attack) * MARGIN
	if demands.has("defence"):
		next.defence = maxf(0.0, float(demands.defence) - t.hull_mass / 1000.0 * DesignTotals.DEFENCE_PER_HULL_T) * MARGIN
	if demands.has("sensor_km"):
		next.sensor = float(demands.sensor_km)
	next.power = (t.power_used + float(demands.get("power", 0.0))) * MARGIN
	if demands.has("stealth"):
		var target := -DesignTotals.STEALTH_SCALE * log(clampf(float(demands.stealth), 1.0, 99.0) / 100.0)
		var over := t.signature() - target
		if over > 0.0:
			next.cooling = float(plan.cooling) + over * MARGIN
	# Settle: stop when nothing moved more than a few per cent.
	var same := true
	for k: String in next:
		var a := float(plan[k])
		var b := float(next[k])
		if absf(a - b) > maxf(0.03 * maxf(a, b), 0.5):
			same = false
	return plan if same else next


## Grades a clause forces: category -> grade to use.
static func _forced_grades(clauses: Array) -> Dictionary:
	var out := {}
	for c: Dictionary in clauses:
		if str(c.get("kind", "")) == "grade":
			var gs: Array = c.get("grades", [])
			if not gs.is_empty():
				out[str(c.get("category", ""))] = str(gs[0])
	return out


static func _grade_for(pt: DesignPartType, grade: String, forced: Dictionary) -> String:
	return str(forced.get(pt.category, grade))


## The cheapest way to buy `amount` of a rating: [{type: variant id, n}].
static func _cheapest(key: String, amount: float, grade: String, forced: Dictionary, cat: DesignCatalog) -> Array:
	var best: Array = []
	var best_cost := INF
	var field: String = BUY[key][1]
	for base_id: String in BUY[key][0]:
		var base := cat.part(base_id)
		if base == null:
			continue
		var g := _grade_for(base, grade, forced)
		var span := DesignGrades.sizes(base)
		for size in range(span[0], span[1] + 1):
			var v := cat.part(DesignGrades.variant_id(base, size, g)) if base.graded else base
			if v == null:
				continue
			var each := float(v.get(field))
			if key == "cooling":
				each = -each
			if each <= 0.0:
				continue
			var n := int(ceil(amount / each))
			if (key == "cooling" and n > MAX_COOLING) or (key == "sensor" and n > 1):
				continue
			var cost := n * v.cost
			if cost < best_cost:
				best_cost = cost
				best = [{"type": DesignGrades.variant_id(base, size, g) if base.graded else base.id, "n": n}]
			if not base.graded:
				break
	return best


## The rooms and parts as a design record: one row of rooms a deck, the components in the
## rooms they belong in, the hull mounts spread along the hull.
static func _layout(demands: Dictionary, clauses: Array, picks: Dictionary, grade: String,
		forced: Dictionary, cat: DesignCatalog) -> DesignRecord:
	var rec := DesignRecord.new("reference", "Reference build")
	var crew := maxi(int(demands.get("crew", 2)), 1)
	var areas := {"bridge": 16.0 + crew * 0.5, "quarters": crew * M2_PER_CREW, "engineering": 12.0, "fuel": 0.0, "cargo": 0.0}
	if demands.has("cargo_m3"):
		areas.cargo = float(demands.cargo_m3) / (rec.deck_height * cat.room("cargo").cargo_share) * MARGIN
	var fuel := float(demands.get("fuel_m3", 0.0))
	if demands.has("jump_ly") or picks.has("thrust"):
		fuel = maxf(fuel, 4.0 + crew * 0.5)
	if fuel > 0.0:
		areas.fuel = fuel / (rec.deck_height * cat.room("fuel").fuel_share) * MARGIN
	# The parts inside, and the room each goes in; mounts go on the hull.
	var inside: Array = []
	var outside: Array = []
	for key: String in picks:
		for p: Dictionary in picks[key]:
			var pt := cat.part(str(p.type))
			for i in int(p.n):
				(outside if pt.hull_mount else inside).append(str(p.type))
	for c: Dictionary in clauses:
		match str(c.get("kind", "")):
			"room":
				var r := str(c.get("room", ""))
				areas[r] = maxf(float(areas.get(r, 0.0)), float(c.get("min_m2", 12.0)))
			"part":
				var parts: Array = c.get("parts", [])
				if parts.is_empty():
					continue
				var pt := cat.part(str(parts[0]))
				if pt == null:
					continue
				var id := pt.id
				if pt.graded:
					id = DesignGrades.variant_id(pt, pt.size_class, _grade_for(pt, grade, forced))
				for i in int(c.get("count", 1)):
					(outside if pt.hull_mount else inside).append(id)
	var room_of := {}
	for type_id: String in inside:
		var pt := cat.part(type_id)
		var r := "engineering"
		if not pt.rooms.is_empty() and not pt.rooms.has("engineering"):
			r = str(pt.rooms[0])
		room_of[type_id] = r
		areas[r] = float(areas.get(r, 0.0)) + pt.size.x * pt.size.z * ROOM_PER_FOOTPRINT
	# Lay the rooms out: decks of at most DECK_M2, each a row along z of one width.
	var total := 0.0
	for r: String in areas:
		total += float(areas[r])
	var decks := maxi(1, int(ceil(total / DECK_M2)))
	var width := clampf(snappedf(sqrt(total / decks / 3.0), 1.0), 4.0, 40.0)
	var at := []
	for i in decks:
		at.append(0.0)
	var deck_i := 0
	var room_id := {}
	var names := areas.keys()
	names.sort()
	for r: String in names:
		var a := float(areas[r])
		if a <= 0.0:
			continue
		var d := maxf(2.0, ceilf(a / width))
		deck_i = 0
		for i in decks:
			if float(at[i]) < float(at[deck_i]):
				deck_i = i
		var undo := rec.apply({"op": "add_room", "room": {"type": r, "deck": deck_i, "x": 0.0, "z": float(at[deck_i]), "w": width, "d": d}})
		if not undo.is_empty():
			room_id[r] = [str(rec.rooms.keys()[-1]), float(at[deck_i]), d, deck_i]
		at[deck_i] = float(at[deck_i]) + d
	for type_id: String in inside:
		var r := str(room_of[type_id])
		if not room_id.has(r):
			r = "engineering"
		var info: Array = room_id.get(r, room_id.values()[0])
		rec.apply({"op": "add_component", "component": {"type": type_id, "room": info[0], "x": width * 0.5, "z": float(info[1]) + float(info[2]) * 0.5}})
	var length := 0.0
	for v in at:
		length = maxf(length, float(v))
	for i in outside.size():
		rec.apply({"op": "add_mount", "mount": {"type": outside[i], "deck": 0, "x": 0.0 if i % 2 == 0 else width,
				"z": length * (float(i) + 0.5) / float(outside.size()), "angle": PI if i % 2 == 0 else 0.0}})
	return rec
