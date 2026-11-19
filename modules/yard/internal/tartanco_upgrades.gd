extends RefCounted
## The TartanCo bots' upgrade path (beenster, 19 Nov: "We need an upgrade path for tartanco
## bots", then his pick: marks with module slots). Each bot is a mark: Mk3 as they come, Mk4,
## Mk5. Each mark is quicker and wears slower than the one before and has one more slot (Mk3 one,
## Mk4 two, Mk5 three); modules go in the slots, each a part with one effect on the bot's work.
## TartanCo's engineers fit them on a service visit. Pure data: YardWorkers reads the effects.
## Higher marks open new trades too (a pipe fitter at Mk4, a wire tech at Mk5): later.

## mark -> {name, slots, pace (work and flying, x), wear (per job, x), price (credits)}.
const MARKS := {
	3: {"name": "Mk3", "slots": 1, "pace": 1.0, "wear": 1.0, "price": 0},
	4: {"name": "Mk4", "slots": 2, "pace": 1.12, "wear": 0.8, "price": 18000},
	5: {"name": "Mk5", "slots": 3, "pace": 1.25, "wear": 0.65, "price": 42000},
}
const FIRST_MARK := 3
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


## What a bot of `mark` with `modules` fitted does, as factors (1 = as a new Mk3): {pace, fly,
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
