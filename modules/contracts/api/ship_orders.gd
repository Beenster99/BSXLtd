class_name ShipOrders
extends RefCounted
## Orders for new ships (Wave 4: contracts and the trial). BSX's clients (ShipClients: each
## with a back story, a sector and a way with money) post what they want built: a kind of ship
## (ROLES) at a size from a small cutter to a mega project (SIZES), with several demands the
## finished ship is scored against (DesignTotals.fit keys: crew, cargo_m3, budget, jump_ly,
## speed, defence, attack, stealth, sensor_km, power, fuel_m3, max_mass) and special clauses
## (CLAUSES: rooms, parts and grades it must have, checked by DesignContractCheck).
##
## Every order carries an estimate of the cheapest honest build (estimate(), calibrated
## against DesignReference's real builds) and how its budget compares (achievability()): a
## client who wants a stealth bomber for CR 500,000 is on the board marked Unrealistic, and
## bidding for it is the player's own lookout. Static data; the board for a cycle is the same
## on every machine (seeded by the cycle).

## Sizes. scale multiplies the demands that grow with a ship (SCALED); speed multiplies speed
## demands (big ships are slower); days the client gives; fee is the yard's fee as a share of
## the estimate; level is the standing with the client needed to bid (ShipClients, ContractClients
## levels: 0 New, 1 Known, 2 Trusted, 3 Preferred); weight how often it is posted.
const SIZES: Dictionary = {
	"small": {"name": "Small", "scale": 1.0, "speed": 1.0, "days": [15, 30], "fee": 0.3, "level": 0, "weight": 30},
	"medium": {"name": "Medium", "scale": 2.5, "speed": 0.85, "days": [25, 45], "fee": 0.25, "level": 0, "weight": 30},
	"large": {"name": "Large", "scale": 8.0, "speed": 0.7, "days": [40, 75], "fee": 0.2, "level": 1, "weight": 20},
	"capital": {"name": "Capital", "scale": 30.0, "speed": 0.55, "days": [60, 120], "fee": 0.16, "level": 2, "weight": 12},
	"mega": {"name": "Mega project", "scale": 120.0, "speed": 0.45, "days": [100, 200], "fee": 0.12, "level": 3, "weight": 8},
}
const SIZE_ORDER: PackedStringArray = ["small", "medium", "large", "capital", "mega"]
## Demands that grow with the size of the ship (the rest are ratings: a big ship is no
## faster or quieter for being big).
const SCALED: PackedStringArray = ["crew", "cargo_m3", "attack", "defence", "power", "fuel_m3"]

## Special clauses an order can carry. kind: "room" (a room of that type, min_m2 at least),
## "part" (count of the first of parts, or any of them), "no_grade" (no part in that grade),
## "grade" (every graded part in category in one of grades). count_scaled: the count grows
## with the ship. cost: rough CR the clause adds to a build (used by estimate()).
const CLAUSES: Dictionary = {
	"rough_landing": {"kind": "part", "parts": ["landing_gear"], "count": 4, "cost": 26000, "text": "Must land on rough ground: at least four landing legs"},
	"docking_port": {"kind": "part", "parts": ["docking_port"], "count": 1, "cost": 15000, "text": "A docking port for station work"},
	"no_reclaimed": {"kind": "no_grade", "grade": "R", "cost": 0, "text": "No part older than new: nothing Reclaimed"},
	"medbay": {"kind": "room", "room": "medbay", "min_m2": 12.0, "cost": 22000, "text": "A medbay of at least 12 m2"},
	"surgery": {"kind": "part", "parts": ["surgery_unit"], "count": 1, "cost": 75000, "text": "A surgery unit in the medbay"},
	"recreation": {"kind": "room", "room": "recreation", "min_m2": 20.0, "cost": 20000, "text": "A recreation room of at least 20 m2"},
	"mess": {"kind": "room", "room": "mess", "min_m2": 16.0, "cost": 18000, "text": "A mess where the whole crew can eat"},
	"workshop": {"kind": "room", "room": "workshop", "min_m2": 16.0, "cost": 16000, "text": "A workshop of at least 16 m2"},
	"planning": {"kind": "room", "room": "planning", "min_m2": 12.0, "cost": 16000, "text": "A planning room for the science team"},
	"airlock": {"kind": "room", "room": "airlock", "min_m2": 6.0, "cost": 12000, "text": "An airlock for work outside"},
	"gravity": {"kind": "part", "parts": ["gravity_generator"], "count": 1, "cost": 70000, "text": "Artificial gravity"},
	"tractor": {"kind": "part", "parts": ["tractor_beam"], "count": 1, "cost": 40000, "text": "A tractor beam"},
	"tow_winch": {"kind": "part", "parts": ["tow_winch"], "count": 1, "cost": 15000, "text": "A tow winch"},
	"drills": {"kind": "part", "parts": ["drill"], "count": 2, "count_scaled": true, "cost": 64000, "text": "Mining drills on the hull"},
	"refinery": {"kind": "part", "parts": ["refinery"], "count": 1, "cost": 60000, "text": "An ore refinery aboard"},
	"smelter": {"kind": "part", "parts": ["smelter"], "count": 1, "cost": 42000, "text": "A smelter to melt down what is cut"},
	"scrap_grinder": {"kind": "part", "parts": ["scrap_grinder"], "count": 1, "cost": 25000, "text": "A scrap grinder in the hold"},
	"cryo": {"kind": "part", "parts": ["cryo_pod"], "count": 6, "count_scaled": true, "cost": 160000, "text": "Cryo pods for the long haul"},
	"point_defence": {"kind": "part", "parts": ["point_defence"], "count": 2, "count_scaled": true, "cost": 30000, "text": "Point defence against missiles"},
	"decoys": {"kind": "part", "parts": ["decoy_launcher"], "count": 2, "cost": 19000, "text": "Decoy launchers"},
	"hardened_weapons": {"kind": "grade", "category": "weapons", "grades": ["H", "P"], "cost": 0, "text": "Weapons Hardened or Precision grade"},
	"quiet_drives": {"kind": "grade", "category": "propulsion", "grades": ["Q"], "cost": 0, "text": "Quiet grade engines only"},
	"precision_jump": {"kind": "grade", "category": "jump", "grades": ["P"], "cost": 0, "text": "Precision grade jump drive"},
	"double_beds": {"kind": "part", "parts": ["double_bed", "captains_cabin"], "count": 2, "count_scaled": true, "cost": 5000, "text": "Proper beds for the guests, not bunks"},
	"cargo_ramp": {"kind": "part", "parts": ["cargo_ramp"], "count": 1, "cost": 18000, "text": "A cargo ramp for loading"},
	"holo_table": {"kind": "part", "parts": ["holo_table"], "count": 1, "cost": 24000, "text": "A holo table for briefings"},
	"survey_array": {"kind": "part", "parts": ["survey_array"], "count": 1, "cost": 17000, "text": "A survey array"},
	"radar": {"kind": "part", "parts": ["radar_array"], "count": 1, "cost": 19000, "text": "A long-range radar on the hull"},
	"media_wall": {"kind": "part", "parts": ["media_wall"], "count": 1, "cost": 9000, "text": "A media wall for the guests"},
	"bar": {"kind": "part", "parts": ["bar_counter"], "count": 1, "cost": 4000, "text": "A bar. Obviously."},
}

## Kinds of ship. sector: ShipClients.SECTORS key; sizes it comes in; demands: key ->
## [low, high] for a SMALL one (SCALED keys grow with the size, speed shrinks); clauses: the
## pool an order draws from; picks: [least, most] clauses drawn. legacy: one of the six kinds
## before Wave 4 (all that is posted with contracts.ship_variety off).
const ROLES: Dictionary = {
	# Military
	"patrol": {"name": "Patrol cutter", "sector": "military", "sizes": ["small", "medium"], "legacy": true,
		"brief": "Armed and armoured for convoy work. She has to take a hit, hit back and run down what runs.",
		"demands": {"attack": [30, 60], "defence": [60, 120], "speed": [150, 200], "crew": [3, 5]},
		"clauses": ["point_defence", "hardened_weapons", "docking_port", "medbay"], "picks": [1, 2]},
	"gunship": {"name": "Gunship", "sector": "military", "sizes": ["small", "medium", "large"],
		"brief": "All teeth. A gun platform with engines, for when talking has stopped.",
		"demands": {"attack": [70, 140], "defence": [90, 170], "speed": [120, 170], "crew": [3, 6]},
		"clauses": ["hardened_weapons", "point_defence", "decoys", "no_reclaimed"], "picks": [1, 3]},
	"stealth_bomber": {"name": "Stealth bomber", "sector": "military", "sizes": ["small", "medium"],
		"brief": "In unseen, one strike, out before anyone knows where it came from. Every watt she makes is a watt someone can see.",
		"demands": {"attack": [80, 150], "stealth": [45, 70], "speed": [160, 220], "crew": [2, 3]},
		"clauses": ["quiet_drives", "decoys", "no_reclaimed"], "picks": [1, 2]},
	"frigate": {"name": "Frigate", "sector": "military", "sizes": ["large", "capital"],
		"brief": "The workhorse of a fleet: long patrols, fights when she must, a crew who live aboard for months.",
		"demands": {"attack": [25, 50], "defence": [60, 110], "jump_ly": [8, 14], "speed": [130, 170], "crew": [4, 7]},
		"clauses": ["medbay", "mess", "point_defence", "hardened_weapons", "docking_port"], "picks": [2, 3]},
	"dreadnought": {"name": "Dreadnought", "sector": "military", "sizes": ["mega"],
		"brief": "A flagship. Something to end an argument by arriving.",
		"demands": {"attack": [20, 35], "defence": [45, 70], "jump_ly": [6, 10], "crew": [4, 6], "speed": [120, 160]},
		"clauses": ["medbay", "mess", "point_defence", "hardened_weapons", "gravity", "holo_table"], "picks": [3, 4]},
	# Mining
	"prospector": {"name": "Prospector", "sector": "mining", "sizes": ["small"],
		"brief": "Good eyes and a modest hold: find the seam, sample it, bring the proof home.",
		"demands": {"sensor_km": [50, 110], "cargo_m3": [30, 80], "crew": [2, 3], "jump_ly": [6, 12]},
		"clauses": ["survey_array", "rough_landing", "drills"], "picks": [1, 2]},
	"ore_hauler": {"name": "Ore hauler", "sector": "mining", "sizes": ["medium", "large"],
		"brief": "A hold, a drive and a crew who don't mind the dust. She runs ore from the rigs to the smelters.",
		"demands": {"cargo_m3": [70, 140], "crew": [2, 4], "power": [10, 30], "jump_ly": [5, 9]},
		"clauses": ["cargo_ramp", "rough_landing", "workshop"], "picks": [1, 2]},
	"mining_barge": {"name": "Mining barge", "sector": "mining", "sizes": ["large", "capital"],
		"brief": "A floating mine: drills on the hull, a refinery inside, and power for both.",
		"demands": {"cargo_m3": [50, 100], "power": [20, 40], "crew": [3, 5], "defence": [30, 60]},
		"clauses": ["drills", "refinery", "workshop", "mess"], "picks": [2, 3]},
	"mother_rig": {"name": "Mining mother rig", "sector": "mining", "sizes": ["mega"],
		"brief": "A whole mining town that moves: it parks on a belt for a decade and eats it.",
		"demands": {"cargo_m3": [60, 100], "power": [25, 45], "crew": [3, 5], "defence": [30, 50], "jump_ly": [4, 7]},
		"clauses": ["drills", "refinery", "smelter", "medbay", "gravity", "mess"], "picks": [3, 5]},
	# Trade
	"hauler": {"name": "Freight hauler", "sector": "trade", "sizes": ["small", "medium"], "legacy": true,
		"brief": "A working hull for the freight runs: room in the hold, a crew that can live aboard, and enough range to reach the next port.",
		"demands": {"cargo_m3": [60, 160], "crew": [2, 4], "jump_ly": [6, 12]},
		"clauses": ["cargo_ramp", "docking_port", "no_reclaimed"], "picks": [0, 2]},
	"freighter": {"name": "Freighter", "sector": "trade", "sizes": ["medium", "large"],
		"brief": "A proper merchantman: big hold, long legs, a mess for the crew and a ramp for the dockers.",
		"demands": {"cargo_m3": [100, 200], "crew": [2, 4], "jump_ly": [8, 14], "speed": [90, 130]},
		"clauses": ["cargo_ramp", "mess", "docking_port", "point_defence"], "picks": [1, 2]},
	"bulk_carrier": {"name": "Bulk carrier", "sector": "trade", "sizes": ["capital"],
		"brief": "Cheap tonnes over long distances. Every credit spent on her has to come back in freight.",
		"demands": {"cargo_m3": [140, 220], "crew": [2, 3], "jump_ly": [6, 10]},
		"clauses": ["cargo_ramp", "docking_port", "workshop"], "picks": [1, 2]},
	"container_ship": {"name": "Container ship", "sector": "trade", "sizes": ["mega"],
		"brief": "The largest thing that moves freight: a spine of containers with a drive at one end.",
		"demands": {"cargo_m3": [160, 240], "crew": [1, 2], "jump_ly": [6, 9], "defence": [15, 30]},
		"clauses": ["cargo_ramp", "docking_port", "point_defence", "mess"], "picks": [2, 3]},
	# Salvage
	"tug": {"name": "Salvage tug", "sector": "salvage", "sizes": ["small", "medium"], "legacy": true,
		"brief": "Power to spare for the winch and tractor, a strong frame, and a crew that lives aboard for weeks.",
		"demands": {"power": [20, 60], "defence": [40, 90], "crew": [2, 4], "cargo_m3": [30, 80]},
		"clauses": ["tow_winch", "tractor", "airlock", "workshop"], "picks": [1, 2]},
	"wrecker": {"name": "Wrecker", "sector": "salvage", "sizes": ["medium", "large"],
		"brief": "She cuts a wreck open where it lies and carries the good parts home.",
		"demands": {"cargo_m3": [60, 120], "power": [20, 50], "crew": [3, 5], "defence": [40, 80]},
		"clauses": ["scrap_grinder", "tractor", "workshop", "airlock"], "picks": [2, 3]},
	"breaker": {"name": "Breaker ship", "sector": "salvage", "sizes": ["capital", "mega"],
		"brief": "A breaker's yard with a drive: swallows a hulk whole and melts it down in transit.",
		"demands": {"cargo_m3": [80, 140], "power": [25, 45], "crew": [3, 5], "defence": [30, 60]},
		"clauses": ["smelter", "scrap_grinder", "tractor", "workshop", "medbay"], "picks": [2, 4]},
	# Courier
	"courier": {"name": "Fast courier", "sector": "courier", "sizes": ["small"], "legacy": true,
		"brief": "Small, fast and hard to see. What she carries is nobody's business.",
		"demands": {"speed": [180, 260], "stealth": [30, 55], "jump_ly": [10, 20], "crew": [1, 2]},
		"clauses": ["quiet_drives", "no_reclaimed"], "picks": [0, 1]},
	"express_packet": {"name": "Express packet", "sector": "courier", "sizes": ["small", "medium"],
		"brief": "Mail and parcels across the cluster on a timetable. Range and speed sell her, the hold pays for her.",
		"demands": {"speed": [160, 220], "jump_ly": [14, 26], "cargo_m3": [10, 30], "crew": [1, 3]},
		"clauses": ["docking_port", "no_reclaimed", "precision_jump"], "picks": [1, 2]},
	"blockade_runner": {"name": "Blockade runner", "sector": "courier", "sizes": ["small", "medium"],
		"brief": "Through the cordon and out the far side with the cargo intact. Quiet, quick and able to shrug off a near miss.",
		"demands": {"stealth": [40, 65], "speed": [170, 230], "defence": [40, 90], "cargo_m3": [15, 40], "crew": [2, 3]},
		"clauses": ["quiet_drives", "decoys", "no_reclaimed"], "picks": [1, 2]},
	# Luxury yachts
	"day_yacht": {"name": "Day yacht", "sector": "yacht", "sizes": ["small"],
		"brief": "A little ship for a lot of money: fast, pretty, and a bar.",
		"demands": {"crew": [3, 6], "speed": [150, 210], "jump_ly": [6, 10]},
		"clauses": ["bar", "double_beds", "no_reclaimed", "media_wall"], "picks": [2, 3]},
	"luxury_yacht": {"name": "Luxury yacht", "sector": "yacht", "sizes": ["medium", "large"],
		"brief": "Cabins for the guests, quarters for the crew who look after them, and range to reach the quiet moons.",
		"demands": {"crew": [4, 8], "speed": [130, 180], "jump_ly": [10, 18]},
		"clauses": ["recreation", "double_beds", "no_reclaimed", "bar", "medbay", "media_wall", "gravity"], "picks": [3, 4]},
	"mega_yacht": {"name": "Mega yacht", "sector": "yacht", "sizes": ["capital", "mega"],
		"brief": "A palace with a drive. It is judged on the first glance and the last detail.",
		"demands": {"crew": [5, 9], "speed": [130, 170], "jump_ly": [10, 16], "defence": [20, 40]},
		"clauses": ["recreation", "double_beds", "no_reclaimed", "gravity", "medbay", "surgery", "bar", "holo_table"], "picks": [4, 6]},
	# Transport
	"liner": {"name": "Passenger liner", "sector": "transport", "sizes": ["medium", "large"], "legacy": true,
		"brief": "Berths, a galley and somewhere to sit. The passengers judge her by the cabins; the line judges her by the range.",
		"demands": {"crew": [6, 12], "jump_ly": [8, 16], "speed": [110, 150]},
		"clauses": ["mess", "medbay", "recreation", "no_reclaimed"], "picks": [1, 3]},
	"crew_shuttle": {"name": "Crew shuttle", "sector": "transport", "sizes": ["small"],
		"brief": "A seat for everyone and a door at each end. She ferries shifts out to the rigs and lands anywhere.",
		"demands": {"crew": [6, 12], "speed": [140, 190]},
		"clauses": ["rough_landing", "docking_port", "airlock"], "picks": [1, 2]},
	"troop_transport": {"name": "Troop transport", "sector": "transport", "sizes": ["medium", "large"],
		"brief": "A platoon in, under fire, onto rough ground, and out again.",
		"demands": {"crew": [8, 14], "defence": [60, 110], "attack": [10, 30], "speed": [130, 170]},
		"clauses": ["rough_landing", "medbay", "point_defence", "hardened_weapons"], "picks": [2, 3]},
	"colony_ship": {"name": "Colony ship", "sector": "transport", "sizes": ["capital", "mega"],
		"brief": "A town's worth of people and everything they need to start again, a long way from anywhere.",
		"demands": {"crew": [6, 10], "cargo_m3": [40, 80], "jump_ly": [10, 16]},
		"clauses": ["cryo", "medbay", "gravity", "workshop", "mess", "rough_landing"], "picks": [3, 5]},
	# Research
	"explorer": {"name": "Survey explorer", "sector": "research", "sizes": ["small", "medium"], "legacy": true,
		"brief": "Long legs and good eyes: she goes where there are no ports, so range and sensors come first.",
		"demands": {"jump_ly": [16, 30], "sensor_km": [60, 140], "crew": [2, 4]},
		"clauses": ["survey_array", "workshop", "medbay"], "picks": [0, 2]},
	"science_vessel": {"name": "Science vessel", "sector": "research", "sizes": ["medium", "large"],
		"brief": "A laboratory that travels: room for the scientists, power for their kit, and sensors to point at the strange.",
		"demands": {"sensor_km": [80, 150], "crew": [4, 8], "power": [20, 50], "jump_ly": [10, 18]},
		"clauses": ["planning", "workshop", "survey_array", "medbay", "holo_table"], "picks": [2, 3]},
	"research_station": {"name": "Research station", "sector": "research", "sizes": ["large", "capital", "mega"],
		"brief": "She will be towed out once and never move again: everything aboard has to keep a crew alive and working for years.",
		"demands": {"crew": [5, 9], "power": [30, 60], "sensor_km": [80, 160], "defence": [20, 50]},
		"clauses": ["planning", "workshop", "medbay", "gravity", "mess", "recreation", "docking_port", "airlock"], "picks": [3, 5]},
}

## Orders on the board each cycle.
const PER_CYCLE := 6
## Old orders (before Wave 4) for the six legacy kinds: medium-sized, no clauses.
const LEGACY_PER_CYCLE := 4

## How a budget compares with the estimate (budget / estimate at least): name and a line.
const ACHIEVABILITY: Array = [
	[1.6, "Generous", "Room to build her well and make a good margin."],
	[1.2, "Fair", "Buildable with care, and worth the work."],
	[1.0, "Tight", "Only the plainest build fits the money. Every choice will hurt."],
	[0.8, "Long shot", "Beyond the cheapest build we can see. It needs a cleverer design than ours."],
	[0.0, "Unrealistic", "The money is nowhere near what this ship costs. Not worth bidding for."],
]


## The ship orders on the board in `cycle`, most valuable first. `variety` posts every kind
## and size (contracts.ship_variety); off, the four legacy orders. `level_of` (Callable(client
## id) -> int, standing level) marks orders the yard's standing does not yet reach as locked.
static func for_cycle(cycle: int, count: int = PER_CYCLE, variety := true, level_of: Callable = Callable()) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("ship_orders_%d" % cycle)
	var out: Array[Dictionary] = []
	if not variety:
		count = mini(count, LEGACY_PER_CYCLE)
	var roles := roles_for(variety)
	var used_clients := {}
	var tries := 0
	while out.size() < count and tries < count * 8:
		tries += 1
		var role: String = roles[rng.randi_range(0, roles.size() - 1)]
		var r: Dictionary = ROLES[role]
		var clients := ShipClients.in_sector(str(r.sector))
		var free: Array = []
		for c in clients:
			if not used_clients.has(c):
				free.append(c)
		if free.is_empty():
			continue
		var client: String = free[rng.randi_range(0, free.size() - 1)]
		var size := _pick_size(r, rng) if variety else ("medium" if (r.sizes as Array).has("medium") else str(r.sizes[0]))
		var o := make(client, role, size, rng, "so%d_%d" % [cycle, out.size() + 1], variety)
		if level_of.is_valid():
			var lv := int(level_of.call(client))
			o["level"] = lv
			o["locked"] = lv < int(o.needs_level)
		used_clients[client] = true
		out.append(o)
	out.sort_custom(func(a, b): return int(a.budget) > int(b.budget))
	return out


## The kinds of ship posted (all, or the legacy six), sorted.
static func roles_for(variety: bool) -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in ROLES:
		if variety or ROLES[id].get("legacy", false):
			out.append(id)
	out.sort()
	return out


static func _pick_size(r: Dictionary, rng: RandomNumberGenerator) -> String:
	var sizes: Array = r.sizes
	var total := 0
	for s in sizes:
		total += int(SIZES[s].weight)
	var roll := rng.randi_range(1, total)
	for s in sizes:
		roll -= int(SIZES[s].weight)
		if roll <= 0:
			return str(s)
	return str(sizes[0])


## One order from `client` for a ship of `role` at `size`, its numbers drawn with `rng`.
static func make(client: String, role: String, size: String, rng: RandomNumberGenerator, id: String, with_clauses := true) -> Dictionary:
	var r: Dictionary = ROLES[role]
	var sz: Dictionary = SIZES[size]
	var c: Dictionary = ShipClients.TABLE.get(client, {})
	var demands := {}
	for key: String in r.demands:
		var span: Array = r.demands[key]
		var v := rng.randf_range(float(span[0]), float(span[1]))
		if SCALED.has(key):
			v *= float(sz.scale)
		elif key == "speed":
			v *= float(sz.speed)
		demands[key] = round_figure(key, v)
	var clauses: Array = []
	if with_clauses:
		var pool: Array = (r.clauses as Array).duplicate()
		var n := rng.randi_range(int(r.picks[0]), int(r.picks[1]))
		while clauses.size() < n and not pool.is_empty():
			var cid: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
			clauses.append(clause(cid, size))
	var est := estimate(demands, clauses)
	var purse: Array = c.get("purse", [0.9, 1.5])
	var budget := round_figure("budget", est * rng.randf_range(float(purse[0]), float(purse[1])))
	demands["budget"] = budget
	var fee := int(roundf(est * float(sz.fee) * float(c.get("fee", 1.0)) / 1000.0) * 1000.0)
	var days := rng.randi_range(int(sz.days[0]), int(sz.days[1]))
	var title := "%s %s for %s" % [str(sz.name), str(r.name).to_lower(), ShipClients.display_name(client)] \
			if size != "medium" else "%s for %s" % [str(r.name), ShipClients.display_name(client)]
	return {"id": id, "client": client, "client_name": ShipClients.display_name(client), "role": role,
		"sector": str(r.sector), "size": size, "title": title, "brief": str(r.brief),
		"story": str(c.get("story", "")), "temper": str(c.get("temper", "")),
		"demands": demands, "clauses": clauses, "budget": budget, "estimate": int(est),
		"achievability": achievability(budget, est), "pay": fee, "days": days,
		"needs_level": int(sz.level), "locked": false}


## A clause by id, ready to go on an order of `size` (its count grown with the ship).
static func clause(id: String, size: String = "small") -> Dictionary:
	var c: Dictionary = (CLAUSES[id] as Dictionary).duplicate(true)
	c["id"] = id
	if c.get("count_scaled", false):
		c.count = int(ceil(float(c.count) * sqrt(float(SIZES[size].scale))))
		c.text = "%s (%d)" % [c.text, c.count]
	return c


## A number as a client would write it down.
static func round_figure(key: String, v: float) -> float:
	if key == "budget":
		var step := 10000.0 if v < 1000000.0 else (100000.0 if v < 20000000.0 else 1000000.0)
		return roundf(v / step) * step
	if v >= 1000.0:
		return roundf(v / 100.0) * 100.0
	if v >= 50.0:
		return roundf(v / 10.0) * 10.0
	return maxf(1.0, roundf(v))


## The cheapest honest build for these demands and clauses, CR: a model fitted to what
## DesignReference.build really costs across every kind and size of order (median error about
## 8%, worst about 25%; the design module's test_contract_variety holds the two together, and
## the numbers want refitting when the catalogue's prices move). A ship is a hull round her
## rooms (AREA) and what each rating takes on top; speed and jump range cost more the heavier
## she is (MASS, tonnes); being quiet costs more on a ship that also fights or runs fast.
const MASS: Dictionary = {"base": 8.47, "per_area": 1.884, "per_attack": 0.044, "per_defence": 0.128,
	"per_jump_area": 0.0272, "per_thrust_area": 0.112, "per_clause_k": 0.091}
const COST: Dictionary = {
	"base": 130300.0, "per_m2": 1277.0, "per_attack": 1013.0, "per_defence": 326.7, "per_power": 542.8,
	"per_sensor": 111.5, "per_jump_t": 128.3, "per_thrust_t": 321.9,
	"per_stealth": 663.8, "stealth_attack": 1935.0, "stealth_speed": 643.0, "per_clause": 2.21,
}
## Floor area a ship of these demands needs, m2: bridge and engineering, quarters, hold.
static func area_for(demands: Dictionary) -> float:
	return 20.0 + maxf(float(demands.get("crew", 2.0)), 1.0) * 4.5 + float(demands.get("cargo_m3", 0.0)) / 2.4 \
			+ float(demands.get("fuel_m3", 0.0)) / 2.5


static func estimate(demands: Dictionary, clauses: Array = []) -> float:
	var g := func(k: String) -> float: return float(demands.get(k, 0.0))
	var area := area_for(demands)
	var a75 := pow(area, 0.75)
	var thrust := pow(g.call("speed") / 90.0, 2.0)
	var clause_cost := 0.0
	for c: Dictionary in clauses:
		clause_cost += float(c.get("cost", 0.0))
	var tonnes: float = MASS.base + MASS.per_area * a75 + MASS.per_attack * g.call("attack") + MASS.per_defence * g.call("defence") \
			+ MASS.per_jump_area * g.call("jump_ly") * a75 + MASS.per_thrust_area * thrust * a75 + MASS.per_clause_k * clause_cost / 1000.0
	var st: float = g.call("stealth")
	var cost: float = COST.base + COST.per_m2 * area + COST.per_attack * g.call("attack") + COST.per_defence * g.call("defence") \
			+ COST.per_power * g.call("power") + COST.per_sensor * g.call("sensor_km") \
			+ COST.per_jump_t * g.call("jump_ly") * tonnes + COST.per_thrust_t * thrust * tonnes \
			+ COST.per_stealth * st + COST.stealth_attack * st * g.call("attack") / 100.0 + COST.stealth_speed * st * thrust \
			+ COST.per_clause * clause_cost
	return maxf(cost, COST.base)


## How a budget of `budget` compares with an estimate of `est`: {label, line, ratio}.
static func achievability(budget: float, est: float) -> Dictionary:
	var ratio := budget / maxf(est, 1.0)
	for row: Array in ACHIEVABILITY:
		if ratio >= float(row[0]):
			return {"label": row[1], "line": row[2], "ratio": snappedf(ratio, 0.01)}
	return {"label": "Unrealistic", "line": ACHIEVABILITY[-1][2], "ratio": snappedf(ratio, 0.01)}


## The demands as lines a player reads ("Jump range at least 12 ly").
static func demand_lines(order: Dictionary) -> PackedStringArray:
	var names := {"cargo_m3": ["Cargo space", "m3", true], "crew": ["Crew bunks", "", true],
		"jump_ly": ["Jump range", "ly", true], "speed": ["Top speed", "m/s", true],
		"defence": ["Defence", "", true], "attack": ["Attack", "dmg/s", true], "stealth": ["Stealth", "/ 100", true],
		"sensor_km": ["Sensor range", "km", true], "power": ["Spare power", "kW", true], "fuel_m3": ["Fuel", "m3", true],
		"budget": ["Cost", "CR", false], "max_mass": ["Mass", "kg", false], "build_days": ["Build time", "days", false]}
	var out: PackedStringArray = []
	var demands: Dictionary = order.get("demands", {})
	for key: String in demands:
		var n: Array = names.get(key, [key, "", true])
		out.append("%s %s %s %s" % [n[0], "at least" if n[2] else "at most", str(int(demands[key])), n[1]])
	return out


## The special clauses as lines a player reads.
static func clause_lines(order: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for c: Dictionary in order.get("clauses", []):
		out.append(str(c.get("text", c.get("id", ""))))
	return out


## Every criterion the order sets (demands, then clauses), counted.
static func criteria_count(order: Dictionary) -> int:
	return (order.get("demands", {}) as Dictionary).size() + (order.get("clauses", []) as Array).size()
