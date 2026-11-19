class_name ShipClients
extends RefCounted
## The clients who order new ships from BSX (Wave 4: contracts and the trial). Each has a back
## story, a line of work (its sector, which picks the kinds of ship it orders), and a way with
## money: how far its budget runs ahead of, or falls short of, what the ship it asks for really
## costs. Standing with a client (ContractsBus.standing_of) grows as BSX delivers its ships to
## spec, and opens its bigger orders (ShipOrders.SIZES' level).
##
## purse: [low, high] budget as a multiple of the cheapest honest build (ShipOrders.estimate).
##   Under 1.0 the ship cannot be built for the money; a dreamer's purse reaches well under.
## fee: multiplies the yard's fee for its work (ShipOrders.SIZES' fee).
## temper: how the client is to deal with, shown on the order.

const SECTORS: Dictionary = {
	"military": {"name": "Military", "blurb": "Navies, militias and the companies that hire out to them."},
	"mining": {"name": "Mining", "blurb": "Prospectors, co-ops and the big rigs that strip a belt."},
	"trade": {"name": "Trade", "blurb": "Freight lines and owner-drivers moving goods between ports."},
	"salvage": {"name": "Salvage", "blurb": "Tugs, wreckers and breakers who make a living from the dead."},
	"courier": {"name": "Courier", "blurb": "Fast, small and discreet. Some of it legal."},
	"yacht": {"name": "Luxury yachts", "blurb": "Private ships for people who never ask what it costs. Usually."},
	"transport": {"name": "Transport", "blurb": "People in numbers: crews, passengers, troops and colonists."},
	"research": {"name": "Research", "blurb": "Survey ships, science vessels and stations that stay put."},
}

const TABLE: Dictionary = {
	# Military
	"tallow_reserve": {"name": "Tallow Defence Reserve", "sector": "military", "purse": [1.05, 1.6], "fee": 1.1, "temper": "Exacting",
		"story": "The reserve fleet has guarded the Tallow lanes for sixty years on hulls older than most of its officers. A new procurement minister wants the fleet renewed in her term, and the paperwork for every bolt is already written."},
	"marrow_militia": {"name": "Marrow Free Militia", "sector": "military", "purse": [0.5, 1.15], "fee": 0.9, "temper": "Ambitious",
		"story": "Volunteers from the Marrow settlements, tired of waiting for a navy that never comes. They know exactly what they want, and they want far more of it than their collection tins can pay for."},
	"halberd_security": {"name": "Halberd Security Group", "sector": "military", "purse": [1.2, 2.0], "fee": 1.3, "temper": "Impatient",
		"story": "A private security firm escorting convoys through the Scatter. Halberd pays well and pays on time, and expects the same of everyone it hires. Its founder still flies the lead ship."},
	# Mining
	"kettle_rock": {"name": "Kettle Rock Co-op", "sector": "mining", "purse": [0.8, 1.3], "fee": 0.85, "temper": "Careful",
		"story": "The miners' co-op at Kettle Rock votes on every credit it spends. Its members have patched the same three haulers for twenty years, and they will want to know why each part costs what it does."},
	"deepcut_minerals": {"name": "Deepcut Minerals", "sector": "mining", "purse": [1.1, 1.7], "fee": 1.15, "temper": "Businesslike",
		"story": "A mining house that grew from one claim to forty belts. Deepcut buys ships the way it buys drill heads: by the dozen, on spec, from yards that deliver."},
	"ferrow_prospecting": {"name": "Ferrow and Daughters", "sector": "mining", "purse": [0.6, 1.25], "fee": 0.9, "temper": "Hopeful",
		"story": "Old Ferrow found the Ashline seam with a borrowed scanner and lost it to a claim-jumper. Her daughters mean to find the next one first, on a ship with better eyes than anyone's."},
	# Trade
	"brine_freight": {"name": "Brine Freight Lines", "sector": "trade", "purse": [0.95, 1.45], "fee": 1.0, "temper": "Steady",
		"story": "Brine has run the fuel and freight route between Port Tressler and the Veil since before the war. Dull, reliable work, and they want dull, reliable ships for it."},
	"cassia_mercantile": {"name": "Cassia Mercantile", "sector": "trade", "purse": [1.15, 1.8], "fee": 1.2, "temper": "Demanding",
		"story": "A trading house with offices on six worlds and a reputation for buying the best. Cassia's captains are paid by the tonne delivered, so every cubic metre of hold matters."},
	"odd_job_haulage": {"name": "Pell Odd-Job Haulage", "sector": "trade", "purse": [0.55, 1.1], "fee": 0.8, "temper": "Haggler",
		"story": "Tam Pell will move anything anywhere for a price, usually a low one. Pell has had a ship built cheap before and regretted it, and has not quite learned the lesson."},
	# Salvage
	"rook_salvage": {"name": "Rook Salvage", "sector": "salvage", "purse": [0.85, 1.35], "fee": 0.95, "temper": "Practical",
		"story": "The Rooks have pulled wrecks out of the Ashfall field for three generations. Their tugs are famous for never quite dying; the newest is thirty-one years old."},
	"carrow_underwriters": {"name": "Carrow Orbital Underwriters", "sector": "salvage", "purse": [1.2, 1.9], "fee": 1.25, "temper": "Precise",
		"story": "Insurers who recover what their policies paid for. Carrow keep their own recovery fleet so they never have to trust anyone else's numbers, and they audit the ones they buy."},
	"ashfall_crew": {"name": "Ashfall Breakers", "sector": "salvage", "purse": [0.6, 1.2], "fee": 0.85, "temper": "Rough",
		"story": "A breakers' crew from the Ashfall yards, more scar than ship. They have a contract to clear a whole graveyard and nowhere near the hull to do it with."},
	# Courier
	"oread_express": {"name": "Oread Express", "sector": "courier", "purse": [1.1, 1.7], "fee": 1.15, "temper": "Impatient",
		"story": "The fastest parcel service in the Tressler cluster, and it says so on every hull. Oread's founder raced before she ran couriers and still thinks in lap times."},
	"quiet_hand": {"name": "The Quiet Hand", "sector": "courier", "purse": [0.9, 2.2], "fee": 1.4, "temper": "Secretive",
		"story": "Nobody at BSX has met anyone from the Quiet Hand. The orders arrive by courier, the deposits clear early, and the ships are never seen again on any register."},
	"post_office": {"name": "Tressler Postal Service", "sector": "courier", "purse": [0.7, 1.15], "fee": 0.85, "temper": "Bureaucratic",
		"story": "The public post, underfunded since anyone can remember. It still has to reach every rock in the cluster, so it asks a lot of a small ship on a small budget."},
	# Luxury yachts
	"vane_family": {"name": "The Vane Family Office", "sector": "yacht", "purse": [1.4, 2.4], "fee": 1.5, "temper": "Particular",
		"story": "Old money from the Vane shipping fortune. The family has never owned anything second-hand and does not intend to start; they notice every seam."},
	"lumen_resorts": {"name": "Lumen Resorts", "sector": "yacht", "purse": [1.05, 1.6], "fee": 1.2, "temper": "Image-conscious",
		"story": "A resort chain that flies its guests between pleasure moons. Lumen sells the trip as much as the stay, so the ship has to be the first thing guests post about."},
	"rex_dallow": {"name": "Rex Dallow", "sector": "yacht", "purse": [0.45, 1.3], "fee": 1.0, "temper": "Flamboyant",
		"story": "A media star with a famous face and a less famous accountant. Dallow wants a yacht to match the image, and the image is bigger than the bank balance."},
	# Transport
	"hesper_line": {"name": "Hesper Line", "sector": "transport", "purse": [1.0, 1.5], "fee": 1.05, "temper": "Steady",
		"story": "A passenger line that has kept its timetable through two wars and a plague. Hesper judges a ship by whether its passengers book again."},
	"new_dawn_colonial": {"name": "New Dawn Colonial Society", "sector": "transport", "purse": [0.65, 1.2], "fee": 0.9, "temper": "Idealistic",
		"story": "Settlers bound for the far side of the Veil, pooling everything they own. They have chosen their world; now they need a ship that can carry a town there."},
	"tallow_logistics": {"name": "Tallow Fleet Logistics", "sector": "transport", "purse": [1.1, 1.6], "fee": 1.1, "temper": "Exacting",
		"story": "The reserve fleet's transport arm. Troops, stores and crews to wherever the reserve is needed, on ships that have to land where there is no port."},
	# Research
	"veil_relay": {"name": "Veil Relay Institute", "sector": "research", "purse": [0.9, 1.45], "fee": 1.0, "temper": "Curious",
		"story": "The relay station in the Veil grew into a university. Its scientists want to go where the strange readings are, and their grant officers want to know why it costs so much."},
	"halcyon_labs": {"name": "Halcyon Labs", "sector": "research", "purse": [1.3, 2.1], "fee": 1.35, "temper": "Secretive",
		"story": "A corporate laboratory with deep pockets and closed doors. Halcyon's stations are built far from anywhere, and it pays extra for crews who do not ask what the work is."},
	"star_atlas": {"name": "Star Atlas Survey", "sector": "research", "purse": [0.55, 1.15], "fee": 0.85, "temper": "Dreamer",
		"story": "A charity mapping the uncharted systems, run on donations and stubbornness. Its ships go further than anyone's and its budgets never go far enough."},
}


static func has(id: String) -> bool:
	return TABLE.has(id)


static func display_name(id: String) -> String:
	return str(TABLE.get(id, {}).get("name", id.capitalize()))


static func sector_of(id: String) -> String:
	return str(TABLE.get(id, {}).get("sector", ""))


static func sector_name(sector: String) -> String:
	return str(SECTORS.get(sector, {}).get("name", sector.capitalize()))


## Client ids in a sector, sorted.
static func in_sector(sector: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in TABLE:
		if TABLE[id].sector == sector:
			out.append(id)
	out.sort()
	return out
