class_name ShipOrders
extends RefCounted
## Orders for new ships (the shipbuilder plan, Wave 4's first step): BSX's own clients post
## what they want built, as demands the design office scores a design against
## (DesignTotals.fit keys: crew, cargo_m3, budget, jump_ly, speed, defence, attack, stealth,
## sensor_km, power, and the masses in kg: dry_mass, wet_mass (caps), fuel_mass, occupancy_mass,
## cargo_max (minimums)). Each client's line of work picks the kind of ship it orders, and each
## kind asks for the ratings that matter to it: an explorer jumps far and sees far, a patrol
## cutter fights, a courier is fast and quiet. Static data; the board for a cycle is the same
## on every machine (seeded by the cycle).

## Kinds of ship ordered. demands: key -> [low, high] (the order's number is picked in that
## range); pay: credits on top of the budget's share for the yard's work.
const ROLES: Dictionary = {
	"hauler": {"name": "Freight hauler", "brief": "A working hull for the freight runs: room in the hold, a crew that can live aboard, and enough range to reach the next port.",
		"demands": {"cargo_max": [60000, 160000], "fuel_mass": [15000, 40000], "crew": [3, 6], "jump_ly": [6, 12], "budget": [1400000, 2600000]}},
	"liner": {"name": "Passenger liner", "brief": "Berths, a galley and somewhere to sit. The passengers judge her by the cabins; the line judges her by the range.",
		"demands": {"occupancy_mass": [1000, 2400], "jump_ly": [8, 16], "speed": [90, 140], "budget": [2200000, 4000000]}},
	"patrol": {"name": "Patrol cutter", "brief": "Armed and armoured for convoy work. She has to take a hit, hit back and run down what runs.",
		"demands": {"attack": [40, 120], "defence": [100, 220], "speed": [120, 180], "crew": [4, 8], "budget": [2000000, 3800000]}},
	"explorer": {"name": "Survey explorer", "brief": "Long legs and good eyes: she goes where there are no ports, so range and sensors come first.",
		"demands": {"jump_ly": [16, 30], "fuel_mass": [20000, 50000], "sensor_km": [60, 140], "crew": [3, 6], "budget": [1600000, 3000000]}},
	"courier": {"name": "Fast courier", "brief": "Small, fast and hard to see. What she carries is nobody's business.",
		"demands": {"speed": [160, 240], "stealth": [40, 65], "jump_ly": [10, 20], "wet_mass": [60000, 120000], "budget": [1200000, 2400000]}},
	"tug": {"name": "Salvage tug", "brief": "Power to spare for the winch and tractor, a strong frame, and a crew that lives aboard for weeks.",
		"demands": {"power": [20, 120], "defence": [80, 160], "crew": [3, 5], "cargo_m3": [60, 160], "budget": [1400000, 2600000]}},
}
## A client's trade -> the kinds of ship it orders.
const TRADE_ROLES: Dictionary = {
	"freight": ["hauler", "tug"], "recovery": ["patrol", "tug"], "passenger": ["liner"],
	"courier": ["courier", "explorer"], "ore": ["hauler", "tug"], "liner": ["liner", "explorer"],
}
## Demands given in kg, shown to players in tonnes.
const MASS_KEYS: PackedStringArray = ["dry_mass", "max_mass", "wet_mass", "fuel_mass", "occupancy_mass", "cargo_max"]
## Orders on the board each cycle.
const PER_CYCLE := 4
## Days the client gives for the build.
const DAYS := [20, 40]
## What the client pays the yard, as a share of the budget (the rest buys the parts).
const PAY_SHARE := 0.35


## The ship orders on the board in `cycle`, one per client at most, most valuable first.
static func for_cycle(cycle: int, count: int = PER_CYCLE) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("ship_orders_%d" % cycle)
	var clients: Array = []
	for id: String in ContractClients.TABLE:
		var trade := str(ContractClients.TABLE[id].get("trade", ""))
		if TRADE_ROLES.has(trade):
			clients.append(id)
	clients.sort()
	var out: Array[Dictionary] = []
	while out.size() < count and not clients.is_empty():
		var id: String = clients.pop_at(rng.randi_range(0, clients.size() - 1))
		var roles: Array = TRADE_ROLES[str(ContractClients.TABLE[id].trade)]
		out.append(make(id, str(roles[rng.randi_range(0, roles.size() - 1)]), rng, "so%d_%d" % [cycle, out.size() + 1]))
	out.sort_custom(func(a, b): return int(a.pay) > int(b.pay))
	return out


## One order from `client` for a ship of `role`, its numbers drawn with `rng`.
static func make(client: String, role: String, rng: RandomNumberGenerator, id: String) -> Dictionary:
	var r: Dictionary = ROLES[role]
	var demands := {}
	for key: String in r.demands:
		var span: Array = r.demands[key]
		var v := rng.randf_range(float(span[0]), float(span[1]))
		# Round to what a client would write down.
		var step := 100000.0 if key == "budget" else (1000.0 if MASS_KEYS.has(key) else (10.0 if v >= 50.0 else 1.0))
		demands[key] = roundf(v / step) * step
	var budget := float(demands.get("budget", 0.0))
	return {"id": id, "client": client, "client_name": ContractClients.display_name(client), "role": role,
		"title": "%s for %s" % [r.name, ContractClients.display_name(client)], "brief": r.brief,
		"demands": demands, "pay": int(roundf(budget * PAY_SHARE / 1000.0) * 1000.0),
		"days": rng.randi_range(int(DAYS[0]), int(DAYS[1]))}


## The demands as lines a player reads ("Jump range at least 12 ly").
static func demand_lines(order: Dictionary) -> PackedStringArray:
	var names := {"cargo_m3": ["Cargo space", "m3", true], "crew": ["Crew bunks", "", true],
		"jump_ly": ["Jump range", "ly", true], "speed": ["Top speed", "m/s", true],
		"defence": ["Defence", "", true], "attack": ["Attack", "dmg/s", true], "stealth": ["Stealth", "/ 100", true],
		"sensor_km": ["Sensor range", "km", true], "power": ["Spare power", "kW", true],
		"budget": ["Cost", "CR", false], "max_mass": ["Dry mass", "t", false], "dry_mass": ["Dry mass", "t", false],
		"wet_mass": ["Wet mass", "t", false], "fuel_mass": ["Fuel load", "t", true],
		"occupancy_mass": ["Occupancy mass", "t", true], "cargo_max": ["Cargo max", "t", true],
		"build_days": ["Build time", "days", false]}
	var out: PackedStringArray = []
	var demands: Dictionary = order.get("demands", {})
	for key: String in demands:
		var n: Array = names.get(key, [key, "", true])
		var v := float(demands[key])
		var shown := str(int(v / 1000.0)) if MASS_KEYS.has(key) else str(int(v))
		out.append("%s %s %s %s" % [n[0], "at least" if n[2] else "at most", shown, n[1]])
	return out
