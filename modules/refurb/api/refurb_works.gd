class_name RefurbWorks
extends RefCounted
## The refurb shop's state and rules (beenster, 19 Nov: "refurbishing bots, as some of our goods
## suppliers will provide second hand parts"). Pure data, stepped by the yard's shared clock in
## fixed ticks (step(delta) only, one seeded RNG: no Time, frame deltas or player positions), so
## every PC in a co-op yard runs the same shop and a late joiner replays to the same one.
##
## A second-hand part comes in at Reclaimed grade ("reactor_small:3R") and a condition (0..1).
## One refurbishing bot per cradle fetches it off the intake rack and takes it through five
## stages: INSPECT (it may find a cracked casing: scrapped), STRIP, CLEAN (the grime comes off),
## REBUILD (the condition comes up) and TEST (it may fail once and go back for another rebuild).
## A part that passes is certified at Standard grade, same size ("reactor_small:3"), and goes on
## the refurbished rack and into stock. What it costs: the new price times (cost_base + cost_wear
## x wear). Positions are shop space: metres, the deck's top y = 0, +Z towards the station.

enum Stage { INSPECT, STRIP, CLEAN, REBUILD, TEST }
const STAGE_NAMES: PackedStringArray = ["INSPECT", "STRIP", "CLEAN", "REBUILD", "TEST"]
## What each stage does, for the board and tips.
const STAGE_BLURBS: PackedStringArray = [
	"scanning for cracks and worn parts", "covers off, worn seals and bearings out",
	"grit blasting the grime and corrosion off", "new seals, bearings and wiring, repairs welded",
	"bench test under power"]

## Where a lot is.
const AT_BACKLOG := "backlog"   # delivered, waiting for room on the intake rack
const AT_INTAKE := "intake"
const AT_CARRIED := "carried"
const AT_CRADLE := "cradle"
const AT_OUT := "out"           # certified, on the refurbished rack
const AT_STORES := "stores"     # certified, moved on to the stores to make room
const AT_SCRAP := "scrap"

## What a bot is doing.
const BOT_DOCK := "dock"
const BOT_FETCH := "fetch"
const BOT_CARRY := "carry"
const BOT_WORK := "work"
const BOT_STOW := "stow"
const BOT_RETURN := "return"

## The shop's layout (shop space, m).
const CRADLE_SPACING := 7.0
const CRADLE_TOP := 1.5
const RACK_X := 19.0
const RACK_LEVELS: PackedFloat32Array = [0.25, 3.45]
const RACK_ZS: PackedFloat32Array = [-4.0, 0.0, 4.0]
const DOCK_Z := -4.6
const DOCK_Y := 3.2
const SCRAP_AT := Vector3(14.5, 0.3, 6.2)
## A part longer than this is drawn (and carried) at this size on a rack, and this on a cradle.
const RACK_FIT := 2.4
const CRADLE_FIT := 4.4
## The dealer's tug: where it comes from and where it hovers to drop lots (over the intake).
const DEALER_FROM := Vector3(150.0, 10.0, 0.0)
const DEALER_DROP := Vector3(-RACK_X, 8.6, 0.0)
const DEALER_SPEED := 14.0
const DEALER_DROP_SECONDS := 2.0
## Categories the stand-in dealer brings second-hand (machinery, not furniture).
const DEALER_CATEGORIES: PackedStringArray = ["power", "propulsion", "jump", "sensors", "life",
		"fluids", "machinery", "defence", "weapons", "flight"]
const SEED := 19112026

var tuning: RefurbTuning
var catalog: DesignCatalog
## Seconds of yard time run.
var time := 0.0
## Every lot ever delivered, by id: {id, type, base, size, condition (now), start (as it came),
## grime, wear (as it came), where, slot, pos, stage, progress, retest, bot, result, cost, paid,
## source, h (drawn height on a cradle), fit, rack_fit, at (time delivered), done_at}.
var lots: Dictionary = {}
## Lot ids in the order they arrived but have no room on the intake yet.
var backlog: Array[int] = []
## Intake and refurbished rack slots: lot id or -1.
var intake: Array[int] = []
var out_rack: Array[int] = []
## Per cradle: the lot on it or being brought to it (-1).
var cradles: Array[int] = []
## One per cradle: {id, serial, pace, pos, target, state, lot, charge, charging, wait, spot, spot_t, tool}.
var bots: Array[Dictionary] = []
## Certified parts: type id -> how many are ready (on the rack or at the stores).
var stock: Dictionary = {}
## Credits spent refurbishing, and the counts.
var spent := 0.0
## Credits back from scrapped parts (their metal).
var recovered := 0.0
var certified := 0
var scrapped := 0
## The stand-in dealer (on until the parts market takes over): {phase, pos, t, next_at, cargo}.
var standin_dealer := true
var dealer: Dictionary = {}
## Something happened this tick (presentation hooks: "arrived", "stage", "scrapped",
## "certified", "retest", "docked"): [{kind, lot, bot}], cleared at each step's start.
var events: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _next_id := 1
var _dealer_types: Array[String] = []


func _init(t: RefurbTuning = null, cat: DesignCatalog = null) -> void:
	tuning = t if t else load("res://modules/refurb/internal/data/refurb_tuning.tres") as RefurbTuning
	catalog = cat if cat else DesignCatalog.load_default()
	reset()


## Back to an empty shop at time 0 (the yard's clock started again).
func reset() -> void:
	_rng.seed = SEED
	time = 0.0
	lots.clear()
	backlog.clear()
	intake.assign(_filled(RACK_LEVELS.size() * RACK_ZS.size() if tuning.intake_slots <= 0 else tuning.intake_slots))
	out_rack.assign(_filled(tuning.out_slots))
	cradles.assign(_filled(tuning.cradles))
	stock.clear()
	spent = 0.0
	recovered = 0.0
	certified = 0
	scrapped = 0
	events.clear()
	_next_id = 1
	bots.clear()
	for i in tuning.cradles:
		var dock := dock_point(i)
		bots.append({"id": i, "serial": "RF-2/%03d" % (101 + i * 7), "pace": _rng.randf_range(tuning.pace_min, tuning.pace_max),
				"pos": dock, "target": dock, "state": BOT_DOCK, "lot": -1, "charge": _rng.randf_range(0.7, 1.0),
				"charging": false, "wait": _rng.randf_range(0.0, 4.0), "spot": 0, "spot_t": 0.0, "tool": ""})
	dealer = {"phase": "away", "pos": DEALER_FROM, "t": 0.0, "next_at": tuning.dealer_first, "cargo": []}
	if _dealer_types.is_empty():
		_dealer_types = dealer_types(catalog, tuning.dealer_max_size)


static func _filled(n: int) -> Array[int]:
	var a: Array[int] = []
	a.resize(n)
	a.fill(-1)
	return a


# --- Layout -------------------------------------------------------------------------------

## The middle of cradle `i`'s top (shop space).
func cradle_point(i: int) -> Vector3:
	return Vector3((i - (tuning.cradles - 1) * 0.5) * CRADLE_SPACING, CRADLE_TOP, 0.0)


func dock_point(i: int) -> Vector3:
	return cradle_point(i) + Vector3(0.0, DOCK_Y - CRADLE_TOP, DOCK_Z)


## Where a part sits in rack slot `slot`: the intake (x < 0) or the refurbished rack.
static func rack_point(slot: int, out: bool) -> Vector3:
	var level := slot / RACK_ZS.size()
	var z := RACK_ZS[slot % RACK_ZS.size()]
	return Vector3(RACK_X if out else -RACK_X, RACK_LEVELS[mini(level, RACK_LEVELS.size() - 1)], z)


# --- Deliveries ---------------------------------------------------------------------------

## A second-hand part arrives (the parts market's used lots, or the stand-in dealer's): its type
## (any size and grade: it is refurbished to the same size at the certified grade), its condition
## (0..1) and who sold it. Returns the lot's id, or -1 for a type the catalogue doesn't have.
func receive(type_id: String, condition: float, source := "") -> int:
	var p := catalog.part(type_id)
	if p == null:
		return -1
	var id := _next_id
	_next_id += 1
	var longest := maxf(p.size.x, maxf(p.size.y, p.size.z))
	var fit := minf(1.0, CRADLE_FIT / maxf(longest, 0.01))
	var c := clampf(condition, 0.0, 1.0)
	var base := catalog.base_of(type_id)
	lots[id] = {"id": id, "type": type_id, "base": p.base_id if p.base_id != "" else p.id, "size": p.size_class,
			"name": base.display_name if base else p.display_name, "condition": c, "start": c, "wear": 1.0 - c, "grime": 1.0 - c, "where": AT_BACKLOG,
			"slot": -1, "pos": DEALER_DROP, "stage": -1, "progress": 0.0, "retest": false, "bot": -1, "result": "",
			"cost": 0.0, "paid": float(p.cost), "source": source, "fit": fit,
			"rack_fit": minf(1.0, RACK_FIT / maxf(longest, 0.01)), "h": p.size.y * fit, "at": time, "done_at": -1.0}
	backlog.append(id)
	_shelve()
	events.append({"kind": "arrived", "lot": id, "bot": -1})
	return id


## Moves backlog lots onto free intake slots, oldest first.
func _shelve() -> void:
	while not backlog.is_empty():
		var slot := intake.find(-1)
		if slot < 0:
			return
		var id: int = backlog.pop_front()
		intake[slot] = id
		var lot: Dictionary = lots[id]
		lot.where = AT_INTAKE
		lot.slot = slot
		lot.pos = rack_point(slot, false)


# --- Estimates ----------------------------------------------------------------------------

## What refurbishing a part would take, for the market and the board: {result (the certified
## type id), seconds (at a normal pace, not counting the flying), cost (credits), scrap (chance
## 0..1), new_price (the certified part bought new)}. Empty for an unknown type.
func estimate(type_id: String, condition: float) -> Dictionary:
	var p := catalog.part(type_id)
	if p == null:
		return {}
	var wear := 1.0 - clampf(condition, 0.0, 1.0)
	var result := certified_type(type_id)
	var rp := catalog.part(result)
	var secs := 0.0
	for s in STAGE_NAMES.size():
		secs += stage_seconds(s, p.size_class, wear)
	secs += stage_seconds(Stage.REBUILD, p.size_class, wear) * 0.5 * tuning.retest_chance * wear
	var new_price := float(rp.cost) if rp else float(p.cost)
	return {"result": result, "seconds": secs, "cost": refurb_cost(new_price, wear),
			"scrap": scrap_odds(wear), "new_price": new_price}


## The type a part is certified as: the same type and size at the certified grade.
func certified_type(type_id: String) -> String:
	var p := catalog.part(type_id)
	if p == null:
		return type_id
	var base := catalog.base_of(type_id)
	if base == null or not base.graded:
		return p.id
	return DesignGrades.variant_id(base, p.size_class, tuning.certified_grade)


func stage_seconds(stage: int, size_class: int, wear: float) -> float:
	var t := tuning.stage_seconds[stage] if stage < tuning.stage_seconds.size() else 10.0
	return t * pow(tuning.per_class, maxi(size_class, 1) - 1) * (tuning.wear_base + tuning.wear_extra * wear)


func refurb_cost(new_price: float, wear: float) -> float:
	return roundf(new_price * (tuning.cost_base + tuning.cost_wear * wear) / 10.0) * 10.0


func scrap_odds(wear: float) -> float:
	return clampf(tuning.scrap_chance * wear * wear, 0.0, 1.0)


## Graded catalogue parts the stand-in dealer brings (machinery with a Void Salvage model, small
## enough for the cradles), as Reclaimed variants, sorted so every machine picks the same.
static func dealer_types(cat: DesignCatalog, max_size: float) -> Array[String]:
	var out: Array[String] = []
	var ids: Array = cat.parts.keys()
	ids.sort()
	for id: String in ids:
		var base: DesignPartType = cat.parts[id]
		if not base.graded or base.shared_part == "" or not VsParts.has(base.shared_part):
			continue
		if not DEALER_CATEGORIES.has(base.category):
			continue
		var span := DesignGrades.sizes(base)
		for s in range(maxi(span[0], 1), maxi(span[1], 1) + 1):
			var v := DesignGrades.variant_id(base, s if base.size_class > 0 else 0, "R")
			var p := cat.part(v)
			if p and maxf(p.size.x, maxf(p.size.y, p.size.z)) <= max_size:
				out.append(v)
	return out


# --- The clock ----------------------------------------------------------------------------

## One step of yard time (the shared clock calls it in fixed ticks).
func step(delta: float) -> void:
	events.clear()
	time += delta
	_step_dealer(delta)
	for b in bots:
		_step_bot(b, delta)


func _step_dealer(delta: float) -> void:
	var d := dealer
	match String(d.phase):
		"away":
			if standin_dealer and time >= float(d.next_at) and intake.has(-1) and backlog.is_empty() and not _dealer_types.is_empty():
				var room := intake.count(-1)
				var n := mini(room, 1 + int(_rng.randf() < 0.45))
				var cargo: Array = []
				for i in n:
					var t: String = _dealer_types[_rng.randi_range(0, _dealer_types.size() - 1)]
					cargo.append({"type": t, "condition": snappedf(_rng.randf_range(tuning.dealer_condition.x, tuning.dealer_condition.y), 0.01)})
				d.cargo = cargo
				d.phase = "in"
				d.pos = DEALER_FROM
			elif not standin_dealer or not intake.has(-1):
				d.next_at = maxf(float(d.next_at), time)
		"in":
			if _fly(d, DEALER_DROP, DEALER_SPEED, delta):
				d.phase = "drop"
				d.t = 0.0
		"drop":
			d.t = float(d.t) + delta
			if float(d.t) >= DEALER_DROP_SECONDS:
				for c: Dictionary in d.cargo:
					receive(String(c.type), float(c.condition), "Kettlemoor Salvage Exchange")
				d.cargo = []
				d.phase = "out"
		"out":
			if _fly(d, DEALER_FROM, DEALER_SPEED, delta):
				d.phase = "away"
				d.next_at = time + _rng.randf_range(tuning.dealer_gap.x, tuning.dealer_gap.y)


## Moves `who` (a dict with pos) towards `to` at up to `speed` m/s, easing in; true on arrival.
static func _fly(who: Dictionary, to: Vector3, speed: float, delta: float) -> bool:
	var pos: Vector3 = who.pos
	var gap := to - pos
	var dist := gap.length()
	if dist < 0.03:
		who.pos = to
		return true
	var v := minf(speed, maxf(dist * 1.6, 0.4))
	who.pos = pos + gap / dist * minf(v * delta, dist)
	return false


func _step_bot(b: Dictionary, delta: float) -> void:
	var pace := float(b.pace)
	var i := int(b.id)
	var speed := tuning.fly_speed * pace
	match String(b.state):
		BOT_DOCK:
			_fly(b, dock_point(i), speed, delta)
			b.tool = ""
			if b.wait > 0.0:
				b.wait = float(b.wait) - delta
			var docked := (b.pos as Vector3).distance_to(dock_point(i)) < 0.05
			if docked and bool(b.charging):
				b.charge = minf(1.0, float(b.charge) + tuning.recharge * delta)
				if float(b.charge) >= 0.98:
					b.charging = false
			if docked and float(b.charge) < tuning.recharge_at and not bool(b.charging):
				b.charging = true
				events.append({"kind": "docked", "lot": -1, "bot": i})
			if bool(b.charging) or float(b.wait) > 0.0:
				return
			var lot_id := _oldest_waiting()
			if lot_id < 0:
				return
			var lot: Dictionary = lots[lot_id]
			intake[int(lot.slot)] = -1
			lot.slot = -1
			lot.bot = i
			cradles[i] = lot_id
			b.lot = lot_id
			b.state = BOT_FETCH
			b.target = (lot.pos as Vector3) + Vector3(0, _rack_h(lot) + 0.75, 0)
		BOT_FETCH:
			var lot: Dictionary = lots[int(b.lot)]
			if _fly(b, b.target, speed, delta):
				lot.where = AT_CARRIED
				b.state = BOT_CARRY
				b.target = cradle_point(i) + Vector3(0, float(lot.h) + 0.75, 0)
				_shelve()
		BOT_CARRY:
			var lot: Dictionary = lots[int(b.lot)]
			var arrived := _fly(b, b.target, speed, delta)
			lot.pos = (b.pos as Vector3) - Vector3(0, float(lot.h) + 0.75, 0)
			if arrived:
				lot.where = AT_CRADLE
				lot.pos = cradle_point(i)
				lot.stage = Stage.INSPECT
				lot.progress = 0.0
				b.state = BOT_WORK
				b.spot_t = 0.0
				_next_spot(b, lot)
				events.append({"kind": "stage", "lot": int(lot.id), "bot": i})
		BOT_WORK:
			_work(b, lots[int(b.lot)], delta)
		BOT_STOW:
			var lot: Dictionary = lots[int(b.lot)]
			var arrived := _fly(b, b.target, speed, delta)
			lot.pos = (b.pos as Vector3) - Vector3(0, float(lot.h) + 0.75, 0)
			if arrived:
				_put_down(b, lot)
		BOT_RETURN:
			if _fly(b, dock_point(i), speed, delta):
				b.state = BOT_DOCK
				b.wait = _rng.randf_range(0.5, 2.5)


## The oldest lot waiting on the intake rack, not yet claimed (-1 for none).
func _oldest_waiting() -> int:
	var best := -1
	for id: int in intake:
		if id >= 0 and int(lots[id].bot) < 0 and (best < 0 or id < best):
			best = id
	return best


func _rack_h(lot: Dictionary) -> float:
	return float(lot.h) / float(lot.fit) * float(lot.rack_fit)


func _work(b: Dictionary, lot: Dictionary, delta: float) -> void:
	var pace := float(b.pace)
	_fly(b, b.target, tuning.fly_speed * pace * 0.6, delta)
	b.charge = maxf(0.0, float(b.charge) - tuning.drain * delta)
	b.spot_t = float(b.spot_t) + delta
	if float(b.spot_t) >= tuning.spot_seconds / pace:
		b.spot_t = 0.0
		_next_spot(b, lot)
	var stage := int(lot.stage)
	var secs := stage_seconds(stage, int(lot.size), float(lot.wear)) / pace
	if stage == Stage.REBUILD and bool(lot.retest):
		secs *= 0.5
	lot.progress = minf(1.0, float(lot.progress) + delta / maxf(secs, 0.01))
	var f := float(lot.progress)
	match stage:
		Stage.CLEAN:
			lot.grime = lerpf(float(lot.wear), 0.04, f)
		Stage.REBUILD:
			var from := float(lot.start) if not bool(lot.retest) else tuning.pass_at - 0.08
			lot.condition = lerpf(from, tuning.rebuilt_condition, f)
	if f < 1.0:
		return
	# The stage is done.
	match stage:
		Stage.INSPECT:
			if _rng.randf() < scrap_odds(float(lot.wear)):
				lot.result = "scrap"
				scrapped += 1
				recovered += float(lot.paid) * tuning.scrap_return
				events.append({"kind": "scrapped", "lot": int(lot.id), "bot": int(b.id)})
				_stow(b, lot, SCRAP_AT + Vector3(_rng.randf_range(-0.6, 0.6), 0.0, _rng.randf_range(-0.4, 0.4)))
				return
		Stage.TEST:
			if not bool(lot.retest) and _rng.randf() < tuning.retest_chance * float(lot.wear):
				lot.retest = true
				lot.condition = tuning.pass_at - 0.08
				lot.stage = Stage.REBUILD
				lot.progress = 0.0
				events.append({"kind": "retest", "lot": int(lot.id), "bot": int(b.id)})
				return
			_certify(b, lot)
			return
	lot.stage = stage + 1
	lot.progress = 0.0
	events.append({"kind": "stage", "lot": int(lot.id), "bot": int(b.id)})


func _certify(b: Dictionary, lot: Dictionary) -> void:
	lot.result = certified_type(String(lot.type))
	var rp := catalog.part(String(lot.result))
	lot.cost = refurb_cost(float(rp.cost) if rp else float(lot.paid), float(lot.wear))
	lot.condition = maxf(float(lot.condition), tuning.rebuilt_condition)
	spent += float(lot.cost)
	certified += 1
	stock[lot.result] = int(stock.get(lot.result, 0)) + 1
	events.append({"kind": "certified", "lot": int(lot.id), "bot": int(b.id)})
	# Room on the refurbished rack: the oldest moves on to the stores if it is full.
	var slot := out_rack.find(-1)
	if slot < 0:
		var oldest := 0
		for s in out_rack.size():
			if int(out_rack[s]) < int(out_rack[oldest]):
				oldest = s
		var gone: Dictionary = lots[out_rack[oldest]]
		gone.where = AT_STORES
		gone.slot = -1
		out_rack[oldest] = -1
		slot = oldest
	out_rack[slot] = int(lot.id)
	lot.slot = slot
	_stow(b, lot, rack_point(slot, true))


func _stow(b: Dictionary, lot: Dictionary, rest: Vector3) -> void:
	lot.where = AT_CARRIED
	lot.stage = -1
	lot.done_at = time
	cradles[int(b.id)] = -1
	b.state = BOT_STOW
	b.tool = ""
	b.rest = rest
	b.target = rest + Vector3(0, _rack_h(lot) + 0.75, 0)


func _put_down(b: Dictionary, lot: Dictionary) -> void:
	lot.pos = b.rest
	lot.where = AT_SCRAP if String(lot.result) == "scrap" else AT_OUT
	lot.bot = -1
	b.lot = -1
	b.erase("rest")
	if float(b.charge) < tuning.recharge_at or _oldest_waiting() < 0:
		b.state = BOT_RETURN
	else:
		b.state = BOT_DOCK
		b.wait = 0.0


## Picks the next place round the part to work from, and the tool for the stage.
func _next_spot(b: Dictionary, lot: Dictionary) -> void:
	var c := cradle_point(int(b.id)) + Vector3(0, float(lot.h) * 0.5, 0)
	var r := maxf(float(lot.h) * 0.5, 0.9) + 0.9
	var a := _rng.randf_range(-PI * 0.85, PI * 0.85)   # round the front and sides, not behind
	var up := _rng.randf_range(-0.2, 0.75)
	b.spot = int(b.spot) + 1
	b.target = c + Vector3(sin(a) * r, up * r, cos(a) * r * 0.8)
	b.tool = ["scanner", "nut_runner", "blaster", "welder", "probe"][clampi(int(lot.stage), 0, 4)]


# --- Reading it ---------------------------------------------------------------------------

## The lot on cradle `i` (or being brought to it), or {}.
func lot_on(i: int) -> Dictionary:
	var id := cradles[i] if i < cradles.size() else -1
	return lots.get(id, {})


## Lots at a place (AT_*), oldest first.
func lots_at(where: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids: Array = lots.keys()
	ids.sort()
	for id: int in ids:
		if String(lots[id].where) == where:
			out.append(lots[id])
	return out


## Takes one certified part of `type_id` out of stock (fitted to a ship): true if there was one.
func take(type_id: String) -> bool:
	var n := int(stock.get(type_id, 0))
	if n <= 0:
		return false
	if n == 1:
		stock.erase(type_id)
	else:
		stock[type_id] = n - 1
	# One off the rack, if any are still drawn there.
	for s in out_rack.size():
		var id := out_rack[s]
		if id >= 0 and String(lots[id].result) == type_id:
			lots[id].where = AT_STORES
			out_rack[s] = -1
			break
	return true


## The whole state as plain numbers, for comparing two machines' shops (tests).
func fingerprint() -> String:
	var parts: PackedStringArray = ["t%.3f" % time]
	for b in bots:
		var p: Vector3 = b.pos
		parts.append("%s %s %d %.3f %.3f %.3f %.3f" % [b.serial, b.state, int(b.lot), p.x, p.y, p.z, float(b.charge)])
	var ids: Array = lots.keys()
	ids.sort()
	for id: int in ids:
		var l: Dictionary = lots[id]
		parts.append("%d %s %s %d %.3f %.3f %s" % [id, l.type, l.where, int(l.stage), float(l.progress), float(l.condition), l.result])
	parts.append("spent %.1f" % spent)
	return " | ".join(parts)
