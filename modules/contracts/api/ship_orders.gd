class_name ShipOrders
extends RefCounted
## Orders for new ships (Wave 4: contracts and the trial). BSX's clients (ShipClients: each
## with a back story, a sector and a way with money) post what they want built: a kind of ship
## (ROLES) at a size from a small cutter to a mega project (SIZES), with several demands the
## finished ship is scored against (DesignTotals.fit keys: crew, cargo_m3, budget, jump_ly,
## speed, defence, attack, stealth, sensor_km, power, fuel_m3, max_mass) and special clauses
## (CLAUSES: rooms, parts and grades it must have, checked by DesignContractCheck). The masses
## are in kg (MASS_KEYS, shown in tonnes): dry_mass and wet_mass are caps, fuel_mass (long
## hauls need a lot of fuel), occupancy_mass (the people aboard) and cargo_max (the holds'
## rated load) are minimums.
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
	"giga": {"name": "Giga project", "scale": 250.0, "speed": 0.4, "days": [150, 300], "fee": 0.1, "level": 3, "weight": 5},
}
const SIZE_ORDER: PackedStringArray = ["small", "medium", "large", "capital", "mega", "giga"]
## The yard's build berths (YardLayout.BERTH_TIERS, the orbital yard thread): tier and the
## longest hull each takes, m (its frame less the bots' 2 m each end). Berths grow with the
## company's reputation; an order needs the smallest that takes the ship it asks for.
const BERTHS: Array = [[1, "Starter berth", 56.0], [2, "Long berth", 106.0], [3, "Capital berth", 196.0], [4, "Giga berth", 316.0]]
## Hull length from floor area (m2): a few decks of rooms, longer than wide. Fitted to the
## reference builds (DesignReference) and kept a little generous.
const LENGTH_PER_ROOT_AREA := 2.2
const LENGTH_BASE := 4.0
## Where a sector's ships work (an order's "region": DesignPower.SUN, how much sunlight solar
## gets there), and how often its orders ask for endurance (days without refuelling at full
## working load) or no reactor aboard ("reactors": 0, for passengers and nervous owners).
const SECTOR_WORK: Dictionary = {
	"military": {"regions": ["inner", "mid", "outer"], "endurance": 0.25, "no_reactor": 0.03},
	"mining": {"regions": ["mid", "outer", "outer", "deep"], "endurance": 0.4, "no_reactor": 0.05},
	"trade": {"regions": ["inner", "inner", "mid"], "endurance": 0.2, "no_reactor": 0.08},
	"salvage": {"regions": ["inner", "mid", "outer"], "endurance": 0.3, "no_reactor": 0.05},
	"courier": {"regions": ["inner", "mid"], "endurance": 0.1, "no_reactor": 0.1},
	"yacht": {"regions": ["inner", "inner", "mid"], "endurance": 0.15, "no_reactor": 0.35},
	"transport": {"regions": ["inner", "mid", "outer", "deep"], "endurance": 0.3, "no_reactor": 0.3},
	"research": {"regions": ["mid", "outer", "deep", "deep"], "endurance": 0.5, "no_reactor": 0.15},
}
## Days without refuelling asked, by region: further out, longer between ports.
const ENDURANCE_DAYS: Dictionary = {"inner": [7, 20], "mid": [14, 40], "outer": [30, 90], "deep": [60, 180]}
## How long a ship can be asked to go without refuelling when she must also jump far or run
## fast. Her tanks weigh, the weight wants a bigger jump drive and engines, they burn more, and
## past a point the tanks never catch up (DesignReference: a small explorer asked 26 ly and 100
## days came to 8,700 t and CR 19 million and still fell short). Days x jump (ly) up to
## JUMP_DAYS, or days x (speed / 90)^2 up to THRUST_DAYS, together at most one; measured on the
## the reference build: at one the tanks run away. Orders ask at most ENDURANCE_LIMIT of it (an
## order asking more has its days cut to fit), and the estimate adds ENDURANCE_PREMIUM x that
## share cubed (the reference build at three quarters costs about a third over the plain fit).
const ENDURANCE_JUMP_DAYS := 1600.0
const ENDURANCE_THRUST_DAYS := 500.0
const ENDURANCE_LIMIT := 0.75
const ENDURANCE_PREMIUM := 0.9
## Shortest endurance demand worth writing down; below it the order asks none.
const ENDURANCE_MIN := 7
const REGION_NAMES: Dictionary = {"inner": "Inner system", "mid": "Mid system", "outer": "Outer system", "deep": "Deep space"}
## Fuel a working load burns, m3 a kWh (a generator's: DesignPower.DEFAULT_BURN), and the
## working load the estimate assumes, kW, fitted to the reference builds' power drawn: a base,
## per crew, per point of attack and defence, per m2, and the drives per tonne moved.
const BURN_PER_KWH := 0.0004
const LOAD: Dictionary = {"base": 34.66, "per_crew": 0.81, "per_attack": 0.2824, "per_defence": 0.0211,
	"per_jump_t": 0.0491, "per_thrust_t": 0.0903, "per_m2": 0.0438}
## Demands that grow with the size of the ship (the rest are ratings: a big ship is no
## faster or quieter for being big).
const SCALED: PackedStringArray = ["crew", "cargo_m3", "attack", "defence", "power", "fuel_m3",
	"fuel_mass", "occupancy_mass", "cargo_max", "dry_mass", "wet_mass"]
## Demands given in kg, shown to players in tonnes.
const MASS_KEYS: PackedStringArray = ["dry_mass", "max_mass", "wet_mass", "fuel_mass", "occupancy_mass", "cargo_max"]
## The DesignTotals rates the mass demands convert by (kg per m3 of fuel, a person, kg per m3
## of hold), so the estimate can read them as fuel, crew and cargo space.
const FUEL_KG_PER_M3 := 800.0
const PERSON_KG := 100.0
const CARGO_KG_PER_M3 := 400.0

## Special clauses an order can carry. kind: "room" (a room of that type, min_m2 at least),
## "part" (count of the first of parts, or any of them), "no_grade" (no part in that grade),
## "grade" (every graded part in category in one of grades). count_scaled: the count grows
## with the ship. cost: rough CR the clause adds to a build (used by estimate()).
const CLAUSES: Dictionary = {
	"rough_landing": {"kind": "part", "parts": ["landing_gear"], "count": 4, "cost": 26000, "text": "Must land on rough ground: at least four landing legs"},
	"docking_port": {"kind": "part", "parts": ["docking_port"], "count": 1, "cost": 15000, "text": "A docking port for station work"},
	"no_reclaimed": {"kind": "no_grade", "grade": "R", "cost": 0, "text": "Nothing Reclaimed: every part new"},
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
	"ore_detector": {"kind": "part", "parts": ["ore_detector"], "count": 1, "cost": 13000, "text": "An ore detector on the hull"},
	"ore_bins": {"kind": "part", "parts": ["ore_bin"], "count": 4, "count_scaled": true, "cost": 13000, "text": "Ore bins in the hold"},
	"mining_lasers": {"kind": "part", "parts": ["mining_laser"], "count": 2, "count_scaled": true, "cost": 34000, "text": "Mining lasers on the hull"},
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
	"dreadnought": {"name": "Dreadnought", "sector": "military", "sizes": ["mega", "giga"],
		"brief": "A flagship. Something to end an argument by arriving.",
		"demands": {"attack": [20, 35], "defence": [45, 70], "jump_ly": [6, 10], "crew": [4, 6], "speed": [120, 160]},
		"clauses": ["medbay", "mess", "point_defence", "hardened_weapons", "gravity", "holo_table"], "picks": [3, 4]},
	# Mining
	"prospector": {"name": "Prospector", "sector": "mining", "sizes": ["small"],
		"brief": "Good eyes and a modest hold: find the seam, sample it, bring the proof home.",
		"demands": {"sensor_km": [50, 110], "cargo_m3": [30, 80], "crew": [2, 3], "jump_ly": [6, 12]},
		"clauses": ["survey_array", "rough_landing", "drills", "ore_detector", "mining_lasers"], "picks": [1, 2]},
	"ice_harvester": {"name": "Ice harvester", "sector": "mining", "sizes": ["small", "medium"],
		"brief": "She cuts ice off comets and brings it home as water and fuel. Cold work, slow money, steady contracts.",
		"demands": {"cargo_max": [16000, 40000], "power": [15, 35], "crew": [2, 3], "jump_ly": [5, 9]},
		"clauses": ["mining_lasers", "ore_bins", "rough_landing", "workshop"], "picks": [1, 2]},
	"gas_skimmer": {"name": "Gas skimmer", "sector": "mining", "sizes": ["medium", "large"],
		"brief": "Dives into a gas giant's upper air, fills her tanks and climbs out before the storms take her. Fast, tough and thirsty.",
		"demands": {"fuel_mass": [8000, 20000], "defence": [40, 80], "speed": [140, 190], "power": [10, 30], "crew": [2, 3]},
		"clauses": ["hardened_weapons", "point_defence", "no_reclaimed", "workshop"], "picks": [1, 2]},
	"asteroid_tug": {"name": "Asteroid tug", "sector": "mining", "sizes": ["small", "medium"],
		"brief": "Nudges a whole rock into a safe orbit for the rigs to work. All muscle: power, a strong frame and the gear to grab hold.",
		"demands": {"power": [30, 70], "defence": [50, 100], "crew": [2, 3], "speed": [110, 150]},
		"clauses": ["tractor", "tow_winch", "ore_detector"], "picks": [1, 2]},
	"ore_hauler": {"name": "Ore hauler", "sector": "mining", "sizes": ["medium", "large"],
		"brief": "A hold, a drive and a crew who don't mind the dust. She runs ore from the rigs to the smelters.",
		"demands": {"cargo_m3": [70, 140], "crew": [2, 4], "power": [10, 30], "jump_ly": [5, 9]},
		"clauses": ["cargo_ramp", "rough_landing", "workshop", "ore_bins"], "picks": [1, 2]},
	"mining_barge": {"name": "Mining barge", "sector": "mining", "sizes": ["large", "capital"],
		"brief": "A floating mine: drills on the hull, a refinery inside, and power for both.",
		"demands": {"cargo_m3": [50, 100], "power": [20, 40], "crew": [3, 5], "defence": [30, 60]},
		"clauses": ["drills", "refinery", "workshop", "mess", "ore_detector", "ore_bins", "mining_lasers"], "picks": [2, 3]},
	"mother_rig": {"name": "Mining mother rig", "sector": "mining", "sizes": ["mega", "giga"],
		"brief": "A whole mining town that moves: it parks on a belt for a decade and eats it.",
		"demands": {"cargo_m3": [60, 100], "power": [25, 45], "crew": [3, 5], "defence": [30, 50], "jump_ly": [4, 7]},
		"clauses": ["drills", "refinery", "smelter", "medbay", "gravity", "mess"], "picks": [3, 5]},
	# Trade
	"hauler": {"name": "Freight hauler", "sector": "trade", "sizes": ["small", "medium"], "legacy": true,
		"brief": "A working hull for the freight runs: room in the hold, a crew that can live aboard, and enough range to reach the next port.",
		"demands": {"cargo_max": [24000, 64000], "fuel_mass": [8000, 20000], "crew": [2, 4], "jump_ly": [6, 12]},
		"clauses": ["cargo_ramp", "docking_port", "no_reclaimed"], "picks": [0, 2]},
	"freighter": {"name": "Freighter", "sector": "trade", "sizes": ["medium", "large"],
		"brief": "A proper merchantman: big hold, long legs, a mess for the crew and a ramp for the dockers.",
		"demands": {"cargo_max": [40000, 80000], "fuel_mass": [10000, 24000], "crew": [2, 4], "jump_ly": [8, 14], "speed": [90, 130]},
		"clauses": ["cargo_ramp", "mess", "docking_port", "point_defence"], "picks": [1, 2]},
	"bulk_carrier": {"name": "Bulk carrier", "sector": "trade", "sizes": ["capital"],
		"brief": "Cheap tonnes over long distances. Every credit spent on her has to come back in freight.",
		"demands": {"cargo_max": [56000, 88000], "fuel_mass": [8000, 16000], "crew": [2, 3], "jump_ly": [6, 10]},
		"clauses": ["cargo_ramp", "docking_port", "workshop"], "picks": [1, 2]},
	"container_ship": {"name": "Container ship", "sector": "trade", "sizes": ["mega", "giga"],
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
	"breaker": {"name": "Breaker ship", "sector": "salvage", "sizes": ["capital", "mega", "giga"],
		"brief": "A breaker's yard with a drive: swallows a hulk whole and melts it down in transit.",
		"demands": {"cargo_m3": [80, 140], "power": [25, 45], "crew": [3, 5], "defence": [30, 60]},
		"clauses": ["smelter", "scrap_grinder", "tractor", "workshop", "medbay"], "picks": [2, 4]},
	# Courier
	"courier": {"name": "Fast courier", "sector": "courier", "sizes": ["small"], "legacy": true,
		"brief": "Small, fast and hard to see. What she carries is nobody's business.",
		"demands": {"speed": [180, 260], "stealth": [30, 55], "jump_ly": [10, 20], "crew": [1, 2], "wet_mass": [70000, 120000]},
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
		"demands": {"occupancy_mass": [600, 1200], "jump_ly": [8, 16], "speed": [110, 150]},
		"clauses": ["mess", "medbay", "recreation", "no_reclaimed"], "picks": [1, 3]},
	"crew_shuttle": {"name": "Crew shuttle", "sector": "transport", "sizes": ["small"],
		"brief": "A seat for everyone and a door at each end. She ferries shifts out to the rigs and lands anywhere.",
		"demands": {"crew": [6, 12], "speed": [140, 190]},
		"clauses": ["rough_landing", "docking_port", "airlock"], "picks": [1, 2]},
	"troop_transport": {"name": "Troop transport", "sector": "transport", "sizes": ["medium", "large"],
		"brief": "A platoon in, under fire, onto rough ground, and out again.",
		"demands": {"crew": [8, 14], "defence": [60, 110], "attack": [10, 30], "speed": [130, 170]},
		"clauses": ["rough_landing", "medbay", "point_defence", "hardened_weapons"], "picks": [2, 3]},
	"colony_ship": {"name": "Colony ship", "sector": "transport", "sizes": ["capital", "mega", "giga"],
		"brief": "A town's worth of people and everything they need to start again, a long way from anywhere.",
		"demands": {"occupancy_mass": [600, 1000], "cargo_m3": [40, 80], "fuel_mass": [6000, 12000], "jump_ly": [10, 16]},
		"clauses": ["cryo", "medbay", "gravity", "workshop", "mess", "rough_landing"], "picks": [3, 5]},
	# Research
	"explorer": {"name": "Survey explorer", "sector": "research", "sizes": ["small", "medium"], "legacy": true,
		"brief": "Long legs and good eyes: she goes where there are no ports, so range and sensors come first.",
		"demands": {"jump_ly": [16, 30], "fuel_mass": [6000, 16000], "sensor_km": [60, 140], "crew": [2, 4]},
		"clauses": ["survey_array", "workshop", "medbay"], "picks": [0, 2]},
	"science_vessel": {"name": "Science vessel", "sector": "research", "sizes": ["medium", "large"],
		"brief": "A laboratory that travels: room for the scientists, power for their kit, and sensors to point at the strange.",
		"demands": {"sensor_km": [80, 150], "crew": [4, 8], "power": [20, 50], "jump_ly": [10, 18]},
		"clauses": ["planning", "workshop", "survey_array", "medbay", "holo_table"], "picks": [2, 3]},
	"research_station": {"name": "Research station", "sector": "research", "sizes": ["large", "capital", "mega", "giga"],
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


## Starter orders (beenster, 20 Nov: "a couple of really easy, almost tutorial level contracts
## so that we can learn how it works"): small, plainly met, a generous budget and plenty of
## time, open to a new yard. Always on the board until delivered. The sample skiff in the
## design library meets both as it stands, so the whole round (quote, deposit, stages, trial,
## delivery) can be tried in a few minutes.
const TUTORIAL: Array = [
	{"id": "tut_1", "client": "hesper_line", "role": "crew_shuttle", "title": "Starter job: a crew shuttle for Hesper Line",
		"brief": "Our first order with you, so we've kept it simple: a small shuttle for four with some room for luggage. Take your time.",
		"demands": {"crew": 4, "cargo_m3": 40}, "clauses": [], "region": "inner", "days": 40, "budget": 950000, "fee": 120000},
	{"id": "tut_2", "client": "veil_relay", "role": "science_vessel", "title": "Starter job: a survey skiff for the Veil Relay Institute",
		"brief": "A little runabout for our survey teams: reasonably quick, a decent radar, and an airlock for work outside.",
		"demands": {"speed": 80, "sensor_km": 15}, "clauses": ["airlock"], "region": "inner", "days": 40, "budget": 950000, "fee": 120000},
]


## The starter orders, priced like any other.
static func tutorial_orders() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in TUTORIAL:
		var clauses: Array = []
		for cid: String in t.clauses:
			clauses.append(clause(cid, "small"))
		var demands: Dictionary = (t.demands as Dictionary).duplicate()
		var est := estimate(demands, clauses)
		# A fixed, generous budget: enough for the sample skiff with room to spare.
		var budget := int(t.budget)
		demands["budget"] = budget
		var c: Dictionary = ShipClients.TABLE.get(str(t.client), {})
		var r: Dictionary = ROLES[t.role]
		out.append({"id": t.id, "client": t.client, "client_name": ShipClients.display_name(str(t.client)), "role": t.role,
			"sector": str(r.sector), "size": "small", "title": t.title, "brief": t.brief,
			"story": str(c.get("story", "")), "temper": str(c.get("temper", "")), "tutorial": true,
			"demands": demands, "clauses": clauses, "budget": budget, "estimate": int(est),
			"achievability": achievability(budget, est), "pay": int(t.fee),
			"days": int(t.days), "needs_level": 0, "locked": false, "region": t.region,
			"length_m": int(length_for(demands, clauses)), "berth": berth_for(length_for(demands, clauses))})
	return out


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
	var region := "inner"
	if with_clauses:
		var work: Dictionary = SECTOR_WORK.get(str(r.sector), {})
		var regions: Array = work.get("regions", ["inner"])
		region = str(regions[rng.randi_range(0, regions.size() - 1)])
		if rng.randf() < float(work.get("endurance", 0.0)):
			var span: Array = ENDURANCE_DAYS[region]
			var days := mini(rng.randi_range(int(span[0]), int(span[1])), endurance_cap(demands))
			if days >= ENDURANCE_MIN:
				demands["endurance_days"] = days
		if rng.randf() < float(work.get("no_reactor", 0.0)):
			demands["reactors"] = 0
	var clauses: Array = []
	if with_clauses:
		var pool: Array = (r.clauses as Array).duplicate()
		var n := rng.randi_range(int(r.picks[0]), int(r.picks[1]))
		while clauses.size() < n and not pool.is_empty():
			var cid: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
			# Graded weapons only on a ship asked to carry weapons.
			if str(CLAUSES[cid].get("category", "")) == "weapons" and not demands.has("attack"):
				continue
			clauses.append(clause(cid, size))
	_fit_berth(demands, clauses)
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
		"needs_level": int(sz.level), "locked": false, "region": region, "length_m": int(length_for(demands, clauses)),
		"berth": berth_for(length_for(demands, clauses))}


## The most days without refuelling a ship of these demands can be asked for (ENDURANCE_JUMP_DAYS).
static func endurance_cap(demands: Dictionary) -> int:
	var per_day := _endurance_per_day(demands)
	return 100000 if per_day <= 0.0 else int(floorf(ENDURANCE_LIMIT / per_day))


## How far an order's endurance goes towards the tanks running away (1 = they do).
static func endurance_share(demands: Dictionary) -> float:
	return float(demands.get("endurance_days", 0.0)) * _endurance_per_day(demands)


static func _endurance_per_day(demands: Dictionary) -> float:
	return float(demands.get("jump_ly", 0.0)) / ENDURANCE_JUMP_DAYS \
			+ pow(float(demands.get("speed", 0.0)) / 90.0, 2.0) / ENDURANCE_THRUST_DAYS


## Scales down what makes a ship big (crew, hold, tanks...) until she fits the largest berth:
## no client asks for a ship no yard can build.
static func _fit_berth(demands: Dictionary, clauses: Array) -> void:
	var longest := float(BERTHS[-1][2])
	for _i in 40:
		if length_for(demands, clauses) <= longest:
			return
		for key: String in SCALED:
			if demands.has(key):
				demands[key] = round_figure(key, float(demands[key]) * 0.93)


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
	if MASS_KEYS.has(key):
		return maxf(1000.0, roundf(v / 1000.0) * 1000.0)
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
const MASS: Dictionary = {"base": 13.64, "per_area": 2.159, "per_attack": 0.05724, "per_defence": 0.1257,
	"per_jump_area": 0.06976, "per_thrust_area": 0.3013, "per_clause_k": 0.07652}
const COST: Dictionary = {
	"base": 126600.0, "per_m2": 1285.0, "per_attack": 1044.0, "per_defence": 304.9, "per_power": 534.6,
	"per_sensor": 90.01, "per_jump_t": 116.6, "per_thrust_t": 328.2,
	"per_stealth": -1211.0, "stealth_attack": 1814.0, "stealth_speed": 1450.0, "per_clause": 2.274,
}
## The demands with the mass ones read as what they need aboard: fuel_mass as fuel_m3,
## occupancy_mass as crew, cargo_max as cargo_m3 (each the larger of the two when both are set).
static func equivalent(demands: Dictionary) -> Dictionary:
	var d := demands.duplicate()
	if d.has("fuel_mass"):
		d.fuel_m3 = maxf(float(d.get("fuel_m3", 0.0)), float(d.fuel_mass) / FUEL_KG_PER_M3)
	if d.has("occupancy_mass"):
		d.crew = maxf(float(d.get("crew", 0.0)), ceilf(float(d.occupancy_mass) / PERSON_KG))
	if d.has("cargo_max"):
		d.cargo_m3 = maxf(float(d.get("cargo_m3", 0.0)), float(d.cargo_max) / CARGO_KG_PER_M3)
	if d.has("endurance_days"):
		d.fuel_m3 = maxf(float(d.get("fuel_m3", 0.0)), float(d.endurance_days) * 24.0 * working_load(d) * BURN_PER_KWH)
	return d


## The working load the estimate assumes for these (equivalent) demands, kW.
static func working_load(d: Dictionary) -> float:
	var g := func(k: String) -> float: return float(d.get(k, 0.0))
	var t := tonnes_for(d)
	var thrust := pow(g.call("speed") / 90.0, 2.0)
	return LOAD.base + LOAD.per_crew * maxf(g.call("crew"), 1.0) + LOAD.per_attack * g.call("attack") \
			+ LOAD.per_defence * g.call("defence") + LOAD.per_jump_t * g.call("jump_ly") * t \
			+ LOAD.per_thrust_t * thrust * t + LOAD.per_m2 * area_for(d)


## About what the ship weighs, t (the estimate's mass model), for equivalent demands.
static func tonnes_for(demands: Dictionary, clause_cost := 0.0) -> float:
	var g := func(k: String) -> float: return float(demands.get(k, 0.0))
	var a75 := pow(area_for(demands), 0.75)
	var thrust := pow(g.call("speed") / 90.0, 2.0)
	return MASS.base + MASS.per_area * a75 + MASS.per_attack * g.call("attack") + MASS.per_defence * g.call("defence") \
			+ MASS.per_jump_area * g.call("jump_ly") * a75 + MASS.per_thrust_area * thrust * a75 + MASS.per_clause_k * clause_cost / 1000.0


## Floor area a ship of these demands needs, m2: bridge and engineering, quarters, hold.
static func area_for(demands: Dictionary) -> float:
	return 20.0 + maxf(float(demands.get("crew", 2.0)), 1.0) * 4.5 + float(demands.get("cargo_m3", 0.0)) / 2.4 \
			+ float(demands.get("fuel_m3", 0.0)) / 2.5


## About how long the ship an order asks for comes out, m.
static func length_for(raw: Dictionary, clauses: Array = []) -> float:
	var area := area_for(equivalent(raw))
	for c: Dictionary in clauses:
		if str(c.get("kind", "")) == "room":
			area += float(c.get("min_m2", 0.0))
	return LENGTH_BASE + LENGTH_PER_ROOT_AREA * sqrt(area)


## The smallest berth tier that takes a hull `length` m long (the largest if none does).
static func berth_for(length: float) -> int:
	for b: Array in BERTHS:
		if length <= float(b[2]):
			return int(b[0])
	return int(BERTHS[-1][0])


static func berth_name(tier: int) -> String:
	for b: Array in BERTHS:
		if int(b[0]) == tier:
			return str(b[1])
	return "Berth %d" % tier


static func estimate(raw: Dictionary, clauses: Array = []) -> float:
	var demands := equivalent(raw)
	var g := func(k: String) -> float: return float(demands.get(k, 0.0))
	var area := area_for(demands)
	var thrust := pow(g.call("speed") / 90.0, 2.0)
	var clause_cost := 0.0
	for c: Dictionary in clauses:
		clause_cost += float(c.get("cost", 0.0))
	var tonnes := tonnes_for(demands, clause_cost)
	var st: float = g.call("stealth")
	var cost: float = COST.base + COST.per_m2 * area + COST.per_attack * g.call("attack") + COST.per_defence * g.call("defence") \
			+ COST.per_power * g.call("power") + COST.per_sensor * g.call("sensor_km") \
			+ COST.per_jump_t * g.call("jump_ly") * tonnes + COST.per_thrust_t * thrust * tonnes \
			+ maxf(0.0, COST.per_stealth * st + COST.stealth_attack * st * g.call("attack") / 100.0 + COST.stealth_speed * st * thrust) \
			+ COST.per_clause * clause_cost
	cost *= 1.0 + ENDURANCE_PREMIUM * pow(endurance_share(raw), 3.0)
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
		"budget": ["Cost", "CR", false], "max_mass": ["Dry mass", "t", false], "dry_mass": ["Dry mass", "t", false],
		"wet_mass": ["Wet mass", "t", false], "fuel_mass": ["Fuel load", "t", true],
		"occupancy_mass": ["Occupancy mass", "t", true], "cargo_max": ["Cargo max", "t", true],
		"build_days": ["Build time", "days", false], "endurance_days": ["Days without refuelling", "", true]}
	var out: PackedStringArray = []
	var demands: Dictionary = order.get("demands", {})
	for key: String in demands:
		if key == "reactors":
			out.append("No reactor aboard" if int(demands[key]) == 0 else "Reactors at most %d" % int(demands[key]))
			continue
		var n: Array = names.get(key, [key, "", true])
		var v := float(demands[key])
		out.append("%s %s %s %s" % [n[0], "at least" if n[2] else "at most", _thousands(int(v / 1000.0) if MASS_KEYS.has(key) else int(v)), n[1]])
	return out


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## "Works in the outer system: solar gets a quarter of full sun." for an order with a region.
static func region_line(order: Dictionary) -> String:
	var region := str(order.get("region", ""))
	if region == "":
		return ""
	var sun := {"inner": "full sun", "mid": "60% sun", "outer": "a quarter of full sun", "deep": "almost no sun"}
	return "Works in the %s: solar gets %s." % [str(REGION_NAMES.get(region, region)).to_lower(), sun.get(region, "")]


## The special clauses as lines a player reads.
static func clause_lines(order: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for c: Dictionary in order.get("clauses", []):
		out.append(str(c.get("text", c.get("id", ""))))
	return out


## Every criterion the order sets (demands, then clauses), counted.
static func criteria_count(order: Dictionary) -> int:
	return (order.get("demands", {}) as Dictionary).size() + (order.get("clauses", []) as Array).size()


# --- Quotes, staged payments and the trial (plan 4.3 to 4.6) ---------------------------------

## The payments a signed ship contract is paid in, in order: share of the price, what sets
## it off, and when it is expected (share of the build time from signing). Starting values,
## to tune at test point 4.
const PAYMENT_STAGES: Array = [
	{"id": "deposit", "name": "Deposit", "share": 0.2, "at": 0.0, "trigger": "Paid when the client signs off the design."},
	{"id": "keel", "name": "Keel laid", "share": 0.2, "at": 0.35, "trigger": "Paid when the frame is complete in the dock."},
	{"id": "fit_out", "name": "Fit-out", "share": 0.2, "at": 0.7, "trigger": "Paid when the hull is closed and the main machinery is in."},
	{"id": "delivery", "name": "Delivery", "share": 0.4, "at": 1.0, "trigger": "Paid after the surveyors' trial, adjusted by its result."},
]
## The trial moves the delivery payment: each demand beaten by BEAT_BY earns BONUS_PER_BEAT
## of the price (BONUS_MAX beats at most); each criterion missed holds back HOLDBACK_PER_MISS
## of the price (lost if she is handed over anyway); each day late takes LATE_PER_DAY. The
## delivery payment never goes below nothing.
const BEAT_BY := 0.25
const BONUS_PER_BEAT := 0.03
const BONUS_MAX := 3
const HOLDBACK_PER_MISS := 0.05
const LATE_PER_DAY := 0.01
## Standing with the client after delivery: STANDING_DELIVERED for a ship to spec, plus
## STANDING_PER_BEAT a demand beaten; a miss costs STANDING_PER_MISS, a day late STANDING_PER_LATE.
const STANDING_DELIVERED := 12
const STANDING_PER_BEAT := 2
const STANDING_PER_MISS := 4
const STANDING_PER_LATE := 1


## BSX's quote for building `order` to a design that costs `cost` CR: the parts and hours at
## cost plus the yard's fee, never more than the client's budget (the yard eats the
## difference). {price, cost, fee, margin, over_budget (bool: the build alone costs more than
## the budget), line}.
static func quote(order: Dictionary, cost: float) -> Dictionary:
	var budget := float((order.get("demands", {}) as Dictionary).get("budget", 0.0))
	var fee := float(order.get("pay", 0))
	var price := cost + fee
	if budget > 0.0:
		price = minf(price, budget)
	price = roundf(price / 1000.0) * 1000.0
	var over := budget > 0.0 and cost > budget
	var line := "The client's budget does not cover the build: CR %s over." % _thousands(int(cost - budget)) if over \
			else ("Price CR %s: the build at cost and the yard's fee of CR %s." % [_thousands(int(price)), _thousands(int(price - cost))])
	return {"price": int(price), "cost": int(cost), "fee": int(fee), "margin": int(price - cost), "over_budget": over, "line": line}


## The payment schedule for a contract at `price` signed on `start_day` and due on `due_day`:
## one row a stage, {id, name, share, value (CR), expected_day, trigger}. Amounts add up to
## the price exactly (the last stage takes the rounding).
static func payment_plan(price: int, start_day: int, due_day: int) -> Array:
	var out: Array = []
	var left := price
	for i in PAYMENT_STAGES.size():
		var st: Dictionary = PAYMENT_STAGES[i]
		var value := left if i == PAYMENT_STAGES.size() - 1 else int(roundf(price * float(st.share) / 1000.0) * 1000.0)
		left -= value
		out.append({"id": st.id, "name": st.name, "share": st.share, "value": value, "trigger": st.trigger,
			"expected_day": start_day + int(roundf(float(due_day - start_day) * float(st.at)))})
	return out


## The trial's verdict on a delivered ship: `rows` are DesignTotals.fit and
## DesignContractCheck rows for the order, `price` the contract price, `days_late` past the
## due day. {met, misses: [labels], beats: [labels], bonus, holdback, late, adjustment (CR on
## the delivery payment), grade (A to E), quality (0..1), standing (points with the client)}.
static func trial(rows: Array, price: int, days_late: int = 0) -> Dictionary:
	var misses: Array = []
	var beats: Array = []
	var share_sum := 0.0
	for r: Dictionary in rows:
		share_sum += float(r.get("share", 0.0))
		# "Top speed, m/s" reads as "Top speed" in the verdict.
		var label := str(r.label) if r.get("clause", false) else str(r.label).get_slice(",", 0)
		if not r.get("ok", false):
			misses.append(label)
			continue
		var key := str(r.get("key", ""))
		if r.get("clause", false) or key in ["budget", "max_mass", "dry_mass", "wet_mass", "build_days"]:
			continue
		if float(r.need) > 0.0 and float(r.have) >= float(r.need) * (1.0 + BEAT_BY) and beats.size() < BONUS_MAX:
			beats.append(label)
	var bonus := int(roundf(price * BONUS_PER_BEAT * beats.size() / 1000.0) * 1000.0)
	var holdback := int(roundf(price * HOLDBACK_PER_MISS * misses.size() / 1000.0) * 1000.0)
	var late := int(roundf(price * LATE_PER_DAY * maxi(0, days_late) / 1000.0) * 1000.0)
	var quality := share_sum / maxf(1.0, rows.size())
	var grade := "A"
	if not misses.is_empty() or days_late > 0:
		grade = "B" if misses.size() <= 1 and days_late <= 2 else ("C" if misses.size() <= 2 else ("D" if quality >= 0.6 else "E"))
	var standing := STANDING_DELIVERED + STANDING_PER_BEAT * beats.size() - STANDING_PER_MISS * misses.size() \
			- STANDING_PER_LATE * maxi(0, days_late)
	return {"met": misses.is_empty(), "misses": misses, "beats": beats, "bonus": bonus, "holdback": holdback,
		"late": late, "adjustment": bonus - holdback - late, "grade": grade, "quality": quality, "standing": standing}


## Best and worst the trial can do to the delivery payment of `order` at `price`: {bonus
## (every demand beaten, up to BONUS_MAX), holdback (every criterion missed)}.
static func trial_range(order: Dictionary, price: int) -> Dictionary:
	var demands := (order.get("demands", {}) as Dictionary).size()
	var criteria := criteria_count(order)
	return {"bonus": int(roundf(price * BONUS_PER_BEAT * mini(BONUS_MAX, demands - 1) / 1000.0) * 1000.0),
		"holdback": int(roundf(price * HOLDBACK_PER_MISS * criteria / 1000.0) * 1000.0)}
