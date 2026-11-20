class_name BotTypes
extends RefCounted
## The company's build bots (master plan Wave 6): what each type can do, how fast and how well,
## what it costs to buy and keep, and how it looks. BSX's own bots, not TartanCo's: the TartanCo
## androids are the hired stand-in crew who lay a keel in an empty berth.
##
## Skills, each a level (1 is a yardhand's, 0 or missing cannot):
##   fit      {stage: level}: float a job of that build stage into place and line it up
##   weld, rivet, bolt: make a hand fastening of that kind (a frame's welds, a plate's rivets, a
##            fitting's or a pipe's bolts; wiring is clipped, which is a rivet)
##   haul     fetch a job's parts from the stores to the berth for the bot fitting it
##   inspect  check finished work and make a poor fastening again, better
##   refurb   bring a worn part up to standard (works with the refurb annex)
## A bot takes a job when it can fit its stage; a fastening it cannot make waits for a helper (a
## pair rule) or is made at a crawl. Higher levels are faster: time = base / level.
##
## Specialists do one thing very fast; multi-taskers (the frame tech, the fit-out tech) cover a
## logical group of trades at a middling pace, so the right bot is never far away (beenster, 17
## Nov: "some logical grouping of skills helps. These are great upgrade paths").

const STAGES: PackedStringArray = ["frame", "plates", "fittings", "wiring", "pipes"]
const KINDS: PackedStringArray = ["weld", "rivet", "bolt"]

## Seconds at level 1 (at the yard's normal pace): floating a job in, one fastening, loading
## parts at the stores, checking one fastening.
const FIT_SECONDS := 12.0
const FASTEN_SECONDS := 7.0
const LOAD_SECONDS := 4.0
const INSPECT_SECONDS := 2.5
## A fastening made without the skill takes this many times longer (a yardhand's level would be 1).
const UNSKILLED := 4.0

## The marks a bot can be raised to: each adds speed and quality (beenster's TartanCo bots go
## Mk1 to Mk5; ours go to Mk3), and what the next one costs as a share of the bot's price.
const MARKS := {
	1: {"name": "Mk1", "speed": 1.0, "quality": 0.0, "cost": 0.0},
	2: {"name": "Mk2", "speed": 1.35, "quality": 0.06, "cost": 0.45},
	3: {"name": "Mk3", "speed": 1.8, "quality": 0.12, "cost": 0.8},
}
const MAX_MARK := 3

## Skill modules a bot can be taught, as an upgrade (one per mark): each adds a trade at level 1.5.
const MODULES := {
	"weld_pack": {"name": "Welding pack", "skill": "weld", "price": 18000},
	"rivet_pack": {"name": "Rivet head", "skill": "rivet", "price": 14000},
	"bolt_pack": {"name": "Nut runner", "skill": "bolt", "price": 14000},
	"cargo_frame": {"name": "Cargo frame", "skill": "haul", "price": 12000},
	"scan_head": {"name": "Scan head", "skill": "inspect", "price": 20000},
}
const MODULE_LEVEL := 1.5

## The colours a bot can be painted (the board's chips): name -> colour.
const PAINTS := {
	"BSX orange": Color("e8792b"), "Yard yellow": Color("e8c25a"), "Signal red": Color("c8402e"),
	"Dock blue": Color("3f7fb8"), "Teal": Color("2f9e96"), "Slate": Color("59636c"),
	"Bone": Color("d8d2c2"), "Racing green": Color("2f6b45"),
}

## type id -> {name, code, family (the look), blurb, skills, speed (flying, m/s), quality (0..1:
## how well it makes a fastening, before marks and wear), price (credits), upkeep (credits a day),
## drain (charge used per second of work, 0..1), paint (its colour as delivered)}.
const TYPES := {
	"yardhand": {"name": "Yardhand", "code": "G-1", "family": "general",
		"blurb": "A general bot: fetches parts and fixes any job, slowly. Two come with the yard.",
		"skills": {"fit": {"frame": 1.0, "plates": 1.0, "fittings": 1.0, "wiring": 1.0, "pipes": 1.0},
				"weld": 1.0, "rivet": 1.0, "bolt": 1.0, "haul": 1.0},
		"speed": 4.0, "quality": 0.66, "price": 38000, "upkeep": 90, "drain": 0.0012, "paint": "BSX orange"},
	"welder": {"name": "Welder", "code": "W-2", "family": "welder",
		"blurb": "Runs a frame's welds very fast and neatly. Lifts frame members in at a yardhand's pace.",
		"skills": {"fit": {"frame": 1.2}, "weld": 4.0},
		"speed": 4.5, "quality": 0.84, "price": 62000, "upkeep": 140, "drain": 0.0016, "paint": "Yard yellow"},
	"riveter": {"name": "Riveter", "code": "R-2", "family": "riveter",
		"blurb": "Sets rivets very fast: hull plates, linings and the wiring's clips.",
		"skills": {"fit": {"plates": 1.0, "wiring": 1.0}, "rivet": 4.0},
		"speed": 4.5, "quality": 0.8, "price": 54000, "upkeep": 120, "drain": 0.0014, "paint": "Signal red"},
	"plater": {"name": "Plater", "code": "P-2", "family": "plater",
		"blurb": "Four suction arms: floats hull plates and walls into place very fast, rivets them slowly.",
		"skills": {"fit": {"plates": 4.0}, "rivet": 1.0},
		"speed": 3.5, "quality": 0.74, "price": 58000, "upkeep": 130, "drain": 0.0018, "paint": "Dock blue"},
	"wirer": {"name": "Wirer", "code": "E-2", "family": "wirer",
		"blurb": "Pays cable out of its reel and clips it to the frame, very fast.",
		"skills": {"fit": {"wiring": 4.0}, "rivet": 2.5},
		"speed": 5.0, "quality": 0.82, "price": 48000, "upkeep": 110, "drain": 0.0012, "paint": "Teal"},
	"pipe_fitter": {"name": "Pipe fitter", "code": "F-2", "family": "pipe_fitter",
		"blurb": "Clamp jaws and a nut runner: lifts pipe runs in and bolts them up, very fast.",
		"skills": {"fit": {"pipes": 4.0}, "bolt": 3.0},
		"speed": 4.0, "quality": 0.8, "price": 50000, "upkeep": 115, "drain": 0.0014, "paint": "Racing green"},
	"hauler": {"name": "Hauler", "code": "H-2", "family": "hauler",
		"blurb": "Fetches the next job's parts from the stores, so the fitters never leave the berth.",
		"skills": {"haul": 3.0},
		"speed": 8.0, "quality": 0.0, "price": 34000, "upkeep": 80, "drain": 0.0010, "paint": "Slate"},
	"inspector": {"name": "Inspector", "code": "I-2", "family": "inspector",
		"blurb": "Scans finished work and makes any poor fastening again, better. Raises the trial's workmanship.",
		"skills": {"inspect": 3.0, "weld": 1.5, "rivet": 1.5, "bolt": 1.5},
		"speed": 5.5, "quality": 0.9, "price": 70000, "upkeep": 150, "drain": 0.0010, "paint": "Bone"},
	"refurbisher": {"name": "Refurbisher", "code": "U-2", "family": "refurbisher",
		"blurb": "Works in the refurb annex: strips, cleans and rebuilds worn parts so they are fit to use.",
		"skills": {"refurb": 2.0},
		"speed": 3.5, "quality": 0.8, "price": 52000, "upkeep": 110, "drain": 0.0012, "paint": "Bone"},
	"frame_tech": {"name": "Frame tech", "code": "FT-3", "family": "frame_tech",
		"blurb": "A multi-tasker for the structure: frames and plates, welds and rivets, all at a good pace.",
		"skills": {"fit": {"frame": 2.0, "plates": 2.0}, "weld": 2.2, "rivet": 2.2},
		"speed": 4.5, "quality": 0.78, "price": 82000, "upkeep": 170, "drain": 0.0016, "paint": "BSX orange"},
	"fitout_tech": {"name": "Fit-out tech", "code": "FO-3", "family": "fitout_tech",
		"blurb": "A multi-tasker for the inside: fittings, wiring and pipes, bolts and clips, all at a good pace.",
		"skills": {"fit": {"fittings": 2.2, "wiring": 2.0, "pipes": 2.0}, "bolt": 2.2, "rivet": 2.0},
		"speed": 4.5, "quality": 0.78, "price": 80000, "upkeep": 165, "drain": 0.0016, "paint": "Teal"},
}
## The order the shop lists them in.
const ORDER: PackedStringArray = ["yardhand", "welder", "riveter", "plater", "wirer", "pipe_fitter",
		"hauler", "inspector", "refurbisher", "frame_tech", "fitout_tech"]
## What a new company's bot bay holds (master plan 6.1: "Two general bots").
const STARTERS: PackedStringArray = ["yardhand", "yardhand"]
## Names a new bot is given, in turn (the board renames it).
const NAMES: PackedStringArray = ["Gus", "Mabel", "Sprocket", "Dot", "Rivet", "Bramble", "Tock", "Juno",
		"Pip", "Clank", "Hettie", "Bolt", "Wren", "Ivo", "Nell", "Toby", "Fen", "Maud", "Ozzy", "Kit"]


static func info(type_id: String) -> Dictionary:
	return TYPES.get(type_id, TYPES.yardhand)


## A bot's level at `skill` ("weld", "fit:frame", ...): its type's, raised by a module it was
## taught, 0 when it cannot.
static func level(bot: Dictionary, skill: String) -> float:
	var t := info(str(bot.get("type", "yardhand")))
	var sk: Dictionary = t.skills
	var lv := 0.0
	if skill.begins_with("fit:"):
		lv = float((sk.get("fit", {}) as Dictionary).get(skill.substr(4), 0.0))
	else:
		lv = float(sk.get(skill, 0.0))
	for m: String in bot.get("modules", []):
		if str((MODULES.get(m, {}) as Dictionary).get("skill", "")) == skill:
			lv = maxf(lv, MODULE_LEVEL)
	return lv


## How fast bot `bot` works (its mark's speed, slowed by wear past half).
static func pace(bot: Dictionary) -> float:
	var mark: Dictionary = MARKS.get(int(bot.get("mark", 1)), MARKS[1])
	var wear := float(bot.get("wear", 0.0))
	return float(mark.speed) * (1.0 - maxf(0.0, wear - 0.5) * 0.6)


## How well bot `bot` makes a fastening it has the skill for, before the day's luck (0..1).
static func quality(bot: Dictionary) -> float:
	var t := info(str(bot.get("type", "yardhand")))
	var mark: Dictionary = MARKS.get(int(bot.get("mark", 1)), MARKS[1])
	var q := float(t.quality)
	if q <= 0.0:
		q = 0.6
	return clampf(q + float(mark.quality) - float(bot.get("wear", 0.0)) * 0.25, 0.2, 0.98)


## The stages bot `bot` can fit.
static func fit_stages(bot: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for s in STAGES:
		if level(bot, "fit:" + s) > 0.0:
			out.append(s)
	return out


## The trade name for a hand fastening kind (BuildPlan.hand_kind's ConnectionData.Kind).
static func kind_skill(kind: int) -> String:
	match kind:
		ConnectionData.Kind.WELD, ConnectionData.Kind.SPOT:
			return "weld"
		ConnectionData.Kind.BOLT:
			return "bolt"
	return "rivet"


## What the next mark costs for bot `bot`, 0 at the top.
static func mark_cost(bot: Dictionary) -> int:
	var next := int(bot.get("mark", 1)) + 1
	if next > MAX_MARK:
		return 0
	return roundi(float(info(str(bot.type)).price) * float(MARKS[next].cost))


## How many skill modules bot `bot` can carry (one per mark).
static func module_slots(bot: Dictionary) -> int:
	return int(bot.get("mark", 1))


## One line of what a type does best: "weld x4, fit frame x1.2".
static func skill_line(type_id: String) -> String:
	var sk: Dictionary = info(type_id).skills
	var bits: PackedStringArray = []
	for s in STAGES:
		var lv := float((sk.get("fit", {}) as Dictionary).get(s, 0.0))
		if lv > 0.0:
			bits.append("fit %s x%s" % [s, _n(lv)])
	for k in ["weld", "rivet", "bolt", "haul", "inspect", "refurb"]:
		if float(sk.get(k, 0.0)) > 0.0:
			bits.append("%s x%s" % [k, _n(float(sk[k]))])
	return ", ".join(bits)


static func _n(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else String.num(v, 1)
