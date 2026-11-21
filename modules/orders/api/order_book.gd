class_name OrderBook
extends RefCounted
## The numbers behind ordering a build's parts (master plan 7.1 to 7.3), worked out from the
## build's design, the market and the day alone: the build's parts list as lines to buy (the
## parts market's own lines, SupplyMarket.buy_lines), which build stage each line is for, which
## of the stores' rack parts stand for it when it comes in, and what a second-hand one costs.

## Line kind (and id) -> the build stage that waits for it.
const STAGE_OF := {"hull:frame": "frame", "hull:welds": "frame", "hull:hull": "plates", "hull:rivets": "plates",
		"hull:inner": "plates", "hull:deck": "plates", "hull:bolts": "fittings", "service:wire": "wiring",
		"service:fuel": "pipes"}
## The build stages in the order the berth works them (the order to buy their parts in).
const STAGE_ORDER := ["frame", "plates", "fittings", "wiring", "pipes"]
## Stages by line kind where the id doesn't say (rooms' fit-out, components, doors).
const STAGE_OF_KIND := {"room": "fittings", "component": "fittings", "door": "plates", "hull": "plates",
		"service": "pipes"}
## Rack parts (YardRackStore.PARTS) standing for a line on the racks, and how much of the line
## one of them is (m, m2 or each), for lines that aren't components.
const RACK_OF := {"hull:frame": ["BoxBeam", 6.0], "hull:hull": ["HullPlate", 3.75], "hull:inner": ["HullPlate", 3.75],
		"hull:deck": ["DeckPlate", 2.9], "service:wire": ["JunctionBox", 25.0], "service:fuel": ["Pipe", 4.0]}
## Loads one line puts on the racks at most (a big ship's skin would fill the hall).
const RACK_CAP := 16
## A component the racks have no drawing for comes in as one of these, by its catalogue category.
const RACK_BY_CATEGORY := {"flight": "PilotConsole", "power": "Generator", "propulsion": "MainThruster",
		"jump": "CapacitorBank", "sensors": "Antenna", "defence": "ArmourSlab", "weapons": "CapacitorBank",
		"life": "HeatSink", "fluids": "FuelTank", "machinery": "Assembler", "medical": "MedStation", "crew": "Bunk",
		"galley": "GalleyCounter", "furniture": "Seat", "storage": "Locker", "cargo": "Locker", "doors": "SwitchCabinet",
		"lighting": "JunctionBox", "structure": "Girder"}
## A second-hand component (master plan 7.3): this share of the median new price, then the
## refurb works' own bill; it comes in at this condition (0 worn out, 1 as new) and takes
## this many days longer (it goes through the works).
const USED_SHARE := 0.38
const USED_CONDITION := 0.55
const USED_EXTRA_DAYS := 1
## Express: this much dearer, and it comes the soonest (game minutes after ordering).
const EXPRESS_FACTOR := 1.35
const EXPRESS_MINUTES := 60
## Deliveries (beenster, 21 Nov: "nothing should take more than 10 real minutes to get to
## us"): each day of a supplier's quoted lead is this many game minutes on the way, each late
## step (1 to 3 when a supplier slips) this many more, and nothing takes longer than
## MAX_REAL_SECONDS at normal speed (1,200 game minutes at the default 2 a second).
const LEAD_MINUTES := 120
const LATE_MINUTES := 90
const MAX_REAL_SECONDS := 600.0
## The contract's payment stages and the build stages each waits on (BuildPlan.PAYMENTS: the
## keel is paid when the frame is done, the fit-out when the plates and fittings are, the
## delivery after the rest). Parts are ordered a payment stage at a time (beenster, 21 Nov:
## "for the keel part of the build I am only expecting beams").
const PAY_STAGES: Array = [
	{"id": "keel", "name": "Keel laid", "stages": ["frame"], "what": "the frame: beams and their welds"},
	{"id": "fit_out", "name": "Fit-out", "stages": ["plates", "fittings"],
		"what": "the hull plates, doors, rooms and machinery"},
	{"id": "delivery", "name": "Delivery", "stages": ["wiring", "pipes"], "what": "the wiring and pipes"},
]


## The payment stage (PAY_STAGES id) build stage `stage` is ordered with.
static func pay_stage_of(stage: String) -> String:
	for ps: Dictionary in PAY_STAGES:
		if stage in (ps.stages as Array):
			return str(ps.id)
	return "fit_out"


## PAY_STAGES entry `id` ({} when none).
static func pay_stage(id: String) -> Dictionary:
	for ps: Dictionary in PAY_STAGES:
		if str(ps.id) == id:
			return ps
	return {}


## Whether line `line` is in stage `stage`: a build stage ("frame") or a payment stage ("keel").
static func in_stage(line: Dictionary, stage: String) -> bool:
	return str(line.get("stage", "")) == stage or pay_stage_of(str(line.get("stage", ""))) == stage


## Game minutes on the way for a quoted lead of `lead` days and `late` late steps, at
## `minutes_per_second` game minutes a real second at normal speed.
static func delivery_minutes(lead: int, late: int, minutes_per_second: float) -> int:
	var cap := int(MAX_REAL_SECONDS * maxf(0.1, minutes_per_second))
	return clampi(maxi(1, lead) * LEAD_MINUTES + maxi(0, late) * LATE_MINUTES, 1, cap)


## Build design `design` (DesignRecord.to_dict) as lines to buy, each with its "stage".
static func lines_for(design: Dictionary, cat: DesignCatalog) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if design.is_empty() or cat == null:
		return out
	var rec := DesignRecord.from_dict(design)
	var totals := DesignTotals.compute(rec, cat, DesignStructure.measure(rec), DesignFrame.propose(rec))
	for l: Dictionary in SupplyMarket.buy_lines(totals, cat):
		l["stage"] = stage_of(l)
		out.append(l)
	return out


static func stage_of(line: Dictionary) -> String:
	var key := str(line.get("key", ""))
	if STAGE_OF.has(key):
		return STAGE_OF[key]
	return str(STAGE_OF_KIND.get(str(line.get("kind", "")), "fittings"))


## The rack parts `qty` of `line` puts in the stores when it comes in: {part id: count}.
static func rack_loads(line: Dictionary, qty: float, cat: DesignCatalog) -> Dictionary:
	var key := str(line.get("key", ""))
	var part := ""
	var per := 1.0
	if RACK_OF.has(key):
		part = RACK_OF[key][0]
		per = float(RACK_OF[key][1])
	elif str(line.get("kind", "")) == "component":
		var pt: DesignPartType = cat.part(key.trim_prefix("component:")) if cat else null
		if pt and YardRackStore.PARTS.has(pt.shared_part):
			part = pt.shared_part
		elif pt:
			part = str(RACK_BY_CATEGORY.get(pt.category, "SwitchCabinet"))
	if part == "" or not YardRackStore.PARTS.has(part):
		return {}
	return {part: clampi(ceili(qty / per - 0.001), 1, RACK_CAP)}


## Whether `line` can be bought second-hand: components the refurb works can take.
static func can_buy_used(line: Dictionary) -> bool:
	return str(line.get("kind", "")) == "component"


## The catalogue's reclaimed variant of a component line ("reactor_small:3R"), what the refurb
## works takes in.
static func used_type(line: Dictionary) -> String:
	var id := str(line.get("key", "")).trim_prefix("component:")
	var at := id.rfind(":")
	if at < 0:
		return id
	var size := id.substr(at + 1).left(1)
	return "%s:%sR" % [id.left(at), size]


## A second-hand quote for `qty` of `line`: {vendor "used", unit, total, lead, on_time, refurb}
## (each unit's refurb bill in its unit). `median_unit`: the market's middle new price.
static func used_quote(line: Dictionary, qty: float, median_unit: float, refurb_cost: float) -> Dictionary:
	var unit := median_unit * USED_SHARE + refurb_cost
	return {"vendor": "used", "unit": unit, "total": unit * qty, "lead": maxi(1, int(line.get("lead", 2))) + USED_EXTRA_DAYS,
			"on_time": 0.8, "refurb": refurb_cost}


## A whole number from the order's id and its vendor, the same on every machine: 0-999.
static func roll(order_id: int, vendor: String) -> int:
	return absi(hash("%d|%s" % [order_id, vendor])) % 1000
