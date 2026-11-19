extends RefCounted
## The TartanCo bots' upgrade path (beenster, 19 Nov: "We need an upgrade path for tartanco
## bots", then his pick: marks with module slots). Each bot is a mark: Mk1 as they come, up to
## Mk5. Each mark is quicker and wears slower than the one before; Mk1 and Mk2 have one slot, Mk3
## and Mk4 two, Mk5 three; modules go in the slots, each a part with one effect on the bot's work.
## TartanCo's engineers fit them on a service visit. Pure data: YardWorkers reads the effects.
## Higher marks open new trades too (a pipe fitter at Mk4, a wire tech at Mk5, say): later.

## mark -> {name, slots, pace (work and flying, x), wear (per job, x), price (credits)}. Every bot
## starts as a Mk1 (beenster, 19 Nov: "Why don't we have Mk1 to Mk5"), a new one too.
const MARKS := {
	1: {"name": "Mk1", "slots": 1, "pace": 1.0, "wear": 1.0, "price": 0},
	2: {"name": "Mk2", "slots": 1, "pace": 1.06, "wear": 0.9, "price": 8000},
	3: {"name": "Mk3", "slots": 2, "pace": 1.12, "wear": 0.8, "price": 18000},
	4: {"name": "Mk4", "slots": 2, "pace": 1.2, "wear": 0.7, "price": 30000},
	5: {"name": "Mk5", "slots": 3, "pace": 1.3, "wear": 0.6, "price": 48000},
}
const FIRST_MARK := 1
## A new Mk1 bot from TartanCo, by trade (credits): dear on purpose, so a company grows its
## fleet slowly (beenster, 19 Nov: "They should be expensive so that you can't immediately have
## lots of them"). A medium contract pays 10,000 to 60,000; a company starts with 20,000.
const BOT_PRICES := {"F": 55000, "W": 65000, "R": 60000, "B": 60000}
const BOT_NAMES := {"F": "F-1 component fitter", "W": "W-1 welder", "R": "R-1 riveter", "B": "B-1 bolter"}
const LAST_MARK := 5

## id -> {name, line (what it does, for the screens), price (credits), and its effect: a factor on
## one of pace (its work), fly (its flying speed), drain (charge a job uses), charge (how quick its
## dock fills it), wear (per job) or faults (the odds a worn bot throws an error)}.
const MODULES := {
	"battery_pack": {"name": "Extended battery", "line": "Uses 40% less charge a job", "price": 4500, "drain": 0.6},
	"fast_charge": {"name": "Fast-charge contacts", "line": "Charges twice as fast on its dock", "price": 3500, "charge": 2.0},
	"servo_set": {"name": "Uprated servos", "line": "Works 15% faster", "price": 6000, "pace": 1.15},
	"thrusters": {"name": "Uprated thrusters", "line": "Flies 30% faster between jobs", "price": 3000, "fly": 1.3},
	"hardened_joints": {"name": "Hardened joints", "line": "Wears 40% slower", "price": 5500, "wear": 0.6},
	"sensor_suite": {"name": "Sensor suite", "line": "Half the errors when worn", "price": 4000, "faults": 0.5},
}

const EFFECTS: Array[String] = ["pace", "fly", "drain", "charge", "wear", "faults"]


static func slots(mark: int) -> int:
	return int(MARKS.get(mark, MARKS[FIRST_MARK]).slots)


static func mark_name(mark: int) -> String:
	return String(MARKS.get(mark, MARKS[FIRST_MARK]).name)


static func module_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in MODULES:
		out.append(id)
	return out


## What a bot of `mark` with `modules` fitted does, as factors (1 = as a new Mk1): {pace, fly,
## drain, charge, wear, faults}. The mark's pace counts for flying too.
static func effects(mark: int, modules: Array) -> Dictionary:
	var m: Dictionary = MARKS.get(mark, MARKS[FIRST_MARK])
	var out := {}
	for e: String in EFFECTS:
		out[e] = 1.0
	out.pace = float(m.pace)
	out.fly = float(m.pace)
	out.wear = float(m.wear)
	for id: Variant in modules:
		var mod: Dictionary = MODULES.get(String(id), {})
		for e: String in EFFECTS:
			if mod.has(e):
				out[e] = float(out[e]) * float(mod[e])
	return out


## The modules fitted, as the screens show them: [{id, name, line}].
static func fitted(modules: Array) -> Array:
	var out: Array = []
	for id: Variant in modules:
		var mod: Dictionary = MODULES.get(String(id), {})
		if not mod.is_empty():
			out.append({"id": String(id), "name": mod.name, "line": mod.line})
	return out
