class_name ContractClients
extends RefCounted
## Who posts work on the contracts board (the scrapyard loop, plan stage S4): Void Salvage's
## organisations and BSX's own. Static data, like Void Salvage's Clients.TABLE. Each client
## has the kinds of job it posts, the parts it sends (with the material, mass and condition
## they tend to arrive in, and what a break job yields from them), and a voice. Standing
## with a client (ContractsBus.standing_of) unlocks its higher tiers.

## Standing points at which a client's level (0 to 3) is reached: new, known, trusted,
## preferred. A level unlocks that tier of offers (tier = level, at least 1).
const LEVEL_POINTS: PackedInt32Array = [0, 10, 30, 70]
const LEVEL_NAMES: PackedStringArray = ["New", "Known", "Trusted", "Preferred"]
## Standing earned at handover: HANDOVER_POINTS times the job's quality (at least
## HANDOVER_MIN), and lost when BSX cancels a job it took on.
const HANDOVER_POINTS := 10.0
const HANDOVER_MIN := 3
const CANCEL_POINTS := 5

## Part stock a client draws its subjects from: Void Salvage PartCatalog names, the
## material they come in, the mass range (kg), and what a break job can ask back.
const PARTS: Dictionary = {
	"NavalTurret": {"material": "steel", "mass": [5000, 8000], "yields": ["TurretMotor", "Gunsight", "AmmoFeed"], "hazards": ["weapons", "power"]},
	"MissileLauncher": {"material": "steel", "mass": [3000, 5000], "yields": ["LaunchRail", "TargetingUnit"], "hazards": ["weapons"]},
	"FuelTank": {"material": "steel", "mass": [2500, 6000], "yields": ["FuelPump", "LevelGauge"], "hazards": ["fuel", "pressure"]},
	"CoolantTank": {"material": "alloy", "mass": [1500, 4000], "yields": ["CoolantPump", "LevelGauge"], "hazards": ["coolant", "pressure"]},
	"MainThruster": {"material": "alloy", "mass": [6000, 12000], "yields": ["ThrusterNozzle", "Gimbal", "InjectorBlock"], "hazards": ["power"]},
	"IonThruster": {"material": "alloy", "mass": [1500, 3500], "yields": ["IonGrid", "Gimbal"], "hazards": ["power"]},
	"Reactor": {"material": "titanium", "mass": [8000, 15000], "yields": ["ControlRods", "CoolantPump", "ShieldPlate"], "hazards": ["power", "coolant"]},
	"Generator": {"material": "steel", "mass": [1200, 3000], "yields": ["Alternator", "Regulator"], "hazards": ["power"]},
	"HullPlating": {"material": "alloy", "mass": [4000, 15000], "yields": [], "hazards": []},
	"ArmourSlab": {"material": "ceramic", "mass": [6000, 14000], "yields": [], "hazards": []},
	"SolarPanel": {"material": "alloy", "mass": [800, 2500], "yields": ["SolarCell", "PanelHinge"], "hazards": ["power"]},
	"CargoContainer": {"material": "steel", "mass": [2000, 4500], "yields": ["ContainerDoor", "LashingRing"], "hazards": []},
	"Gyro": {"material": "titanium", "mass": [3000, 7000], "yields": ["GyroRotor", "GyroBearing"], "hazards": ["power"]},
	"LifeSupport": {"material": "steel", "mass": [1500, 3500], "yields": ["Scrubber", "AirPump"], "hazards": ["pressure"]},
	"RailBarrel": {"material": "tungsten", "mass": [9000, 16000], "yields": ["RailSegment", "CapacitorBank"], "hazards": ["weapons", "power"]},
	"CockpitCanopy": {"material": "glass", "mass": [600, 1500], "yields": ["CanopyPane", "CanopyHinge"], "hazards": []},
}

## Clients by id. game: where the client lives ("void_salvage" organisations post on the
## Void Salvage tab; "bsx_generated" on local work). kinds: what it posts. parts: PARTS keys
## it sends. trade: the client's line of work, which picks the family of ship it sends (S3b,
## `ShipGenerator.family_for`). keeps: who keeps what the wants leave over. voice: a title and a line per kind,
## with %s for the part. post_chance: how often it posts a new offer each cycle.
const TABLE: Dictionary = {
	"tpa": {"display_name": "Tressler Port Authority", "game": "void_salvage", "post_chance": 0.6,
		"blurb": "Port security at Port Tressler. Strips weapons and reactors off impounded hulls.",
		"kinds": ["break", "dispose"], "parts": ["NavalTurret", "MissileLauncher", "Reactor", "RailBarrel"], "keeps": "bsx",
		"voice": {"break": ["Impound strip: %s", "Off an impounded hull. Port security wants the working parts back; the rest is yours."],
			"dispose": ["Make safe: %s", "Decommission it. Nothing comes back to us; we want it gone and a line in the record saying so."]}},
	"kettle_rock": {"display_name": "Kettle Rock Co-op", "game": "void_salvage", "post_chance": 0.7,
		"blurb": "The miners' co-op at Kettle Rock. Buys clean metal by the tonne.",
		"kinds": ["scrap", "break"], "parts": ["HullPlating", "CargoContainer", "ArmourSlab", "Generator"], "keeps": "bsx",
		"voice": {"scrap": ["Press for the co-op: %s", "Bent metal off the heap. Press us clean material by the tonne; the rest is yours for the trouble."],
			"break": ["Spares for the pit: %s", "The co-op's own kit is older than most of its miners. We need the working parts out of this one."]}},
	"brine_fuels": {"display_name": "Brine Fuels", "game": "void_salvage", "post_chance": 0.5,
		"blurb": "The fuel depot. Tanks and lines come to BSX when they are too far gone to clean.",
		"kinds": ["dispose", "refurbish"], "parts": ["FuelTank", "CoolantTank"], "keeps": "bsx",
		"voice": {"dispose": ["Condemned: %s", "Still has a load in it. Drain it, cut it up and keep the steel. We want it gone."],
			"refurbish": ["Recertify: %s", "Pressure test failed by a hair. Reline it, new fittings, and bring it back to spec."]}},
	"veil_relay": {"display_name": "Veil Relay", "game": "void_salvage", "post_chance": 0.4,
		"blurb": "The relay station in the Veil. Precious, delicate electrics.",
		"kinds": ["break", "refurbish"], "parts": ["SolarPanel", "Gyro", "Generator"], "keeps": "client",
		"voice": {"break": ["Salvage the cells: %s", "Out past the Veil nothing comes cheap. Get the working parts out and send everything back, even the scrap."],
			"refurbish": ["Bring it back: %s", "We would rather fix than replace this far out. Return it to spec and we will keep posting work your way."]}},
	"carrow_underwriters": {"trade": "freight", "display_name": "Carrow Orbital Underwriters", "game": "bsx_generated", "post_chance": 0.5,
		"blurb": "Insurers. Written-off kit goes to the breakers; they want the salvage value back.",
		"kinds": ["break", "scrap"], "parts": ["MainThruster", "Reactor", "Gyro", "HullPlating", "CargoContainer"], "keeps": "client",
		"voice": {"break": ["Write-off recovery: %s", "Total loss on the policy. Recover what still works and return it to the assessor."],
			"scrap": ["Realise the salvage: %s", "Nothing on this is worth fitting again. Press the metal and return it; the policy holder is paid from what it fetches."]}},
	"tallow_reserve": {"trade": "recovery", "display_name": "Tallow Defence Reserve", "game": "bsx_generated", "post_chance": 0.4,
		"blurb": "The reserve fleet's depot. Demilitarises old hardware, under paperwork.",
		"kinds": ["dispose", "break"], "parts": ["NavalTurret", "MissileLauncher", "RailBarrel", "ArmourSlab"], "keeps": "bsx",
		"voice": {"dispose": ["Demilitarise: %s", "Render it inert and destroy it. The certificate matters more to us than the metal."],
			"break": ["Reserve spares: %s", "The fleet keeps old hulls flying on parts like these. Recover them with care; the rest is scrap."]}},
	"hesper_line": {"trade": "passenger", "display_name": "Hesper Line", "game": "bsx_generated", "post_chance": 0.5,
		"blurb": "A passenger line. Keeps its liners in service with refurbished machinery.",
		"kinds": ["refurbish"], "parts": ["MainThruster", "IonThruster", "LifeSupport", "Generator"], "keeps": "client",
		"voice": {"refurbish": ["Back in service: %s", "Off a liner with a schedule to keep. Bring it back to spec and we have a ship back on the run."]}},
	"oread_racing": {"trade": "courier", "display_name": "Oread Racing League", "game": "bsx_generated", "post_chance": 0.4,
		"blurb": "Racers. Crash a lot, pay well, want it yesterday.",
		"kinds": ["refurbish", "break"], "parts": ["IonThruster", "CockpitCanopy", "Gyro"], "keeps": "client",
		"voice": {"refurbish": ["Race weekend: %s", "Bent it in qualifying. Needs to be perfect by the weekend, and we mean perfect."],
			"break": ["Parts bin: %s", "Written off in the wall. Pull anything that still works for the spares bin."]}},
	"scatter_metals": {"trade": "ore", "display_name": "Scatter Metals", "game": "bsx_generated", "post_chance": 0.7,
		"blurb": "A scrap broker. Pays by the tonne, asks no questions.",
		"kinds": ["scrap"], "parts": ["HullPlating", "ArmourSlab", "CargoContainer", "FuelTank"], "keeps": "bsx",
		"voice": {"scrap": ["Tonnage: %s", "Baled and clean, by the tonne. Keep whatever doesn't make weight."]}},
	"carrow_museum": {"trade": "liner", "display_name": "Carrow Museum of Flight", "game": "bsx_generated", "post_chance": 0.25,
		"blurb": "The museum. Wants old machinery brought back to how it looked, not how it ran.",
		"kinds": ["refurbish"], "parts": ["IonThruster", "CockpitCanopy", "Generator", "NavalTurret"], "keeps": "client",
		"voice": {"refurbish": ["For the gallery: %s", "A piece for the floor. It has to look right under the lights; it never has to run."]}},
}


static func has(id: String) -> bool:
	return TABLE.has(id)


static func display_name(id: String) -> String:
	return String(TABLE.get(id, {}).get("display_name", id.capitalize()))


## Level 0 to 3 for a number of standing points.
static func level_for(points: int) -> int:
	var level := 0
	for i in LEVEL_POINTS.size():
		if points >= LEVEL_POINTS[i]:
			level = i
	return level


static func level_name(level: int) -> String:
	return LEVEL_NAMES[clampi(level, 0, LEVEL_NAMES.size() - 1)]
