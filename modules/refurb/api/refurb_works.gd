class_name RefurbWorks
extends RefCounted
## The refurb works' state and rules (beenster, 19 Nov: "refurbishing bots, as some of our goods
## suppliers will provide second hand parts"; 0.4.4 playtest: "move refurbishing unit to an annex
## of the main hall", "bare in mind they may have very large items to refurb", "drones should
## home on charger racks"). Pure data, stepped by the yard's shared clock in fixed ticks
## (step(delta) only, one seeded RNG: no Time, frame deltas or player positions), so every PC in
## a co-op yard runs the same works and a late joiner replays to the same one.
##
## A second-hand part comes in at goods in (the stores hall) at Reclaimed grade
## ("reactor_small:3R") and a condition (0..1). The goods-in cart brings it through the big door
## into the annex. A small part (up to light_max) goes onto the intake rollers; a light-line
## RF-2 fetches it to its own cradle. A big one (up to heavy_max) is lifted off the cart by the
## overhead crane onto the heavy stand, where the two RF-2H heavy bots and any idle light-line
## bots work it together. Each part goes through five stages: INSPECT (it may find a cracked
## casing: scrapped; a big part is cut up first), STRIP, CLEAN (the grime comes off), REBUILD
## (the condition comes up) and TEST (it may fail once and go back for another rebuild). A part
## that passes is certified at Standard grade, same size ("reactor_small:3"), and goes on the
## refurbished rack (or the heavy out bay, by crane) and into stock. Cost: the new price times
## (cost_base + cost_wear x wear). Idle bots go back to their slot on the charger rack and charge.
##
## Positions are annex space: metres, the floor y = 0, the annex's middle at x = z = 0, -Z
## towards the stores hall (the door) and the dock beyond it, axes as the station's.

enum Stage { INSPECT, STRIP, CLEAN, REBUILD, TEST, CUT }
const STAGE_NAMES: PackedStringArray = ["INSPECT", "STRIP", "CLEAN", "REBUILD", "TEST", "CUT UP"]
## What each stage does, for the board and tips.
const STAGE_BLURBS: PackedStringArray = [
	"scanning for cracks and worn parts", "covers off, worn seals and bearings out",
	"pressure washing the grime and corrosion off", "new seals, bearings and wiring, repairs welded",
	"bench test under power", "cracked: cutting it up for the skip"]
const STAGE_TOOLS: PackedStringArray = ["scanner", "nut_runner", "blaster", "welder", "probe", "cutter"]

## Where a lot is.
const AT_BACKLOG := "backlog"   # at goods in (the stores hall), waiting for the cart
const AT_CART := "cart"
const AT_INTAKE := "intake"     # on the intake rollers
const AT_CARRIED := "carried"   # in a bot's claw
const AT_CRANE := "crane"       # on the crane's hook
const AT_CRADLE := "cradle"     # on a light cradle or the heavy stand
const AT_OUT := "out"           # certified, on the refurbished rack or the heavy out bay
const AT_STORES := "stores"     # certified, moved on to the stores to make room
const AT_SCRAP := "scrap"

## What a bot is doing.
const BOT_DOCK := "dock"        # on (or going back to) its charger slot
const BOT_FETCH := "fetch"
const BOT_CARRY := "carry"
const BOT_WORK := "work"
const BOT_STOW := "stow"
const BOT_RETURN := "return"

## The annex (annex space, m): its inside, and the door from the stores hall (x from, to; height).
const SIZE := Vector3(36.0, 16.0, 30.0)
const DOOR_X := Vector2(2.0, 16.0)
const DOOR_H := 12.0
## The light line: its cradles in a row along x, their tops.
const LIGHT_XS: PackedFloat32Array = [-15.6, -11.4, -7.2, -3.0]
const LIGHT_Z := 3.0
const CRADLE_TOP := 1.2
## The heavy stand's top middle, and the heavy out bay's floor middle (both under the crane).
const HEAVY_AT := Vector3(9.0, 0.9, 0.5)
const HEAVY_OUT_AT := Vector3(9.0, 0.25, 11.0)
## The intake rollers along the hall wall (x of each place), the refurbished rack on the west
## wall (z of each place, its levels).
const ROLLER_XS: PackedFloat32Array = [-16.2, -13.9, -11.6, -9.3, -7.0, -4.7]
const ROLLER_Z := -13.9
const ROLLER_Y := 0.95
const OUT_X := -16.7
const OUT_ZS: PackedFloat32Array = [-9.5, -6.8, -4.1]
const OUT_LEVELS: PackedFloat32Array = [0.3, 2.8]
## The charger rack on the back wall: each slot's x and y (a bot hangs in front of it).
const CHARGER_XS: PackedFloat32Array = [-14.5, -10.5, -6.5]
const CHARGER_YS: PackedFloat32Array = [2.6, 5.6]
const CHARGER_Z := 13.75
## The scrap skip's floor middle and its inside (half sizes).
const SCRAP_AT := Vector3(-2.2, 0.3, 11.2)
const SCRAP_HALF := Vector2(2.1, 1.6)
## Parts drawn on the rollers, the rack and the cart at most this long (m), and in the skip.
const RACK_FIT := 2.1
const SCRAP_FIT := 1.6
## The goods-in cart's route (annex space; z < -15 is the stores hall): where it waits, where it
## loads at goods in, the door's two sides, where it stops for the rollers and for the crane.
const CART_PARK := Vector3(12.5, 0.0, -18.6)
const CART_PICK := Vector3(9.0, 0.0, -26.0)
const CART_LIGHT_ROUTE: Array[Vector3] = [Vector3(3.8, 0.0, -18.6), Vector3(3.8, 0.0, -11.3), Vector3(-9.8, 0.0, -11.3)]
const CART_HEAVY_ROUTE: Array[Vector3] = [Vector3(9.0, 0.0, -18.6), Vector3(9.0, 0.0, -9.6)]
## The cart's bed top (m) and where light parts ride on it (along its length).
const CART_BED := 0.85
const CART_SLOTS: PackedFloat32Array = [-2.3, 0.0, 2.3]
## The crane: the hook's travelling height, its parking spot, the sling's length above a load.
const CRANE_TRAVEL_Y := 12.8
const CRANE_PARK := Vector3(14.0, 12.8, 11.0)
const SLING := 1.0
## Categories the stand-in dealer brings second-hand (machinery, not furniture).
const DEALER_CATEGORIES: PackedStringArray = ["power", "propulsion", "jump", "sensors", "life",
		"fluids", "machinery", "defence", "weapons", "flight"]
const DEALER_NAME := "Kettlemoor Salvage Exchange"
const SEED := 19112026

var tuning: RefurbTuning
var catalog: DesignCatalog
## Seconds of yard time run.
var time := 0.0
## Every lot ever delivered, by id: {id, type, base, size, name, condition (now), start (as it
## came), grime, wear (as it came), heavy, dims (drawn box after yaw: long along x), yaw (turns its
## long side along x), rot (its turn now, on top of yaw), where, slot, pos (its bottom middle),
## stage, progress, retest, bot, result, cost, paid, source, h (height), rack_fit, at, done_at}.
var lots: Dictionary = {}
## Lot ids at goods in, in the order they arrived.
var backlog: Array[int] = []
## Intake roller places and refurbished rack places: lot id or -1.
var intake: Array[int] = []
var out_rack: Array[int] = []
## Per light cradle, then the heavy stand last: the lot on it or on its way (-1).
var cradles: Array[int] = []
## The heavy out bay's lot (-1 empty).
var heavy_out := -1
## Bots, light line first then the heavy crew: {id, serial, role ("light", "heavy"), pace, pos,
## target, state, lot, charge, charging, wait, spot, spot_t, tool}.
var bots: Array[Dictionary] = []
## The goods-in cart: {phase (park, out, load, in, unload, wait, back), pos, yaw, path, load
## (lot ids), t, heavy}.
var cart: Dictionary = {}
## The overhead crane: {hook (its hook's point), phase (idle, over, lower, sling, lift, carry, set,
## unsling, up, park), lot, to (the load's bottom middle where it goes), rot (its turn there),
## then (AT_CRADLE, AT_OUT, AT_SCRAP), t, queue (jobs waiting: {lot, to, rot, then})}.
var crane: Dictionary = {}
## Certified parts: type id -> how many are ready (on the racks or at the stores).
var stock: Dictionary = {}
## Credits spent refurbishing, and the counts.
var spent := 0.0
## Credits back from scrapped parts (their metal).
var recovered := 0.0
var certified := 0
var scrapped := 0
## The stand-in dealer (on until the parts market takes over): {next_at}.
var standin_dealer := true
var dealer: Dictionary = {}
## Something happened this tick (presentation hooks: "arrived", "stage", "scrapped",
## "certified", "retest", "docked", "unloaded", "slung", "set"): [{kind, lot, bot}], cleared at
## each step's start.
var events: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _next_id := 1
var _light_types: Array[String] = []
var _heavy_types: Array[String] = []


func _init(t: RefurbTuning = null, cat: DesignCatalog = null) -> void:
	tuning = t if t else load("res://modules/refurb/internal/data/refurb_tuning.tres") as RefurbTuning
	catalog = cat if cat else DesignCatalog.load_default()
	reset()


## Back to an empty works at time 0 (the yard's clock started again).
func reset() -> void:
	_rng.seed = SEED
	time = 0.0
	lots.clear()
	backlog.clear()
	intake.assign(_filled(mini(tuning.intake_slots, ROLLER_XS.size())))
	out_rack.assign(_filled(mini(tuning.out_slots, OUT_ZS.size() * OUT_LEVELS.size())))
	cradles.assign(_filled(light_count() + 1))
	heavy_out = -1
	stock.clear()
	spent = 0.0
	recovered = 0.0
	certified = 0
	scrapped = 0
	events.clear()
	_next_id = 1
	bots.clear()
	var n := mini(light_count() + tuning.heavy_crew, CHARGER_XS.size() * CHARGER_YS.size())
	for i in n:
		var dock := dock_point(i)
		var heavy := i >= light_count()
		bots.append({"id": i, "serial": ("RF-2H/%03d" if heavy else "RF-2/%03d") % (101 + i * 7), "role": "heavy" if heavy else "light",
				"pace": _rng.randf_range(tuning.pace_min, tuning.pace_max), "pos": dock, "target": dock, "state": BOT_DOCK,
				"lot": -1, "charge": _rng.randf_range(0.7, 1.0), "charging": false, "wait": _rng.randf_range(0.0, 4.0),
				"spot": 0, "spot_t": 0.0, "tool": ""})
	cart = {"phase": "park", "pos": CART_PARK, "yaw": PI * 0.5, "path": [], "load": [], "t": 0.0, "heavy": false}
	crane = {"hook": CRANE_PARK, "phase": "idle", "lot": -1, "to": Vector3.ZERO, "rot": 0.0, "then": "", "t": 0.0, "queue": []}
	dealer = {"next_at": tuning.dealer_first}
	if _light_types.is_empty() and _heavy_types.is_empty():
		for t: String in dealer_types(catalog, tuning.dealer_max_size):
			if longest(catalog.part(t)) <= tuning.light_max:
				_light_types.append(t)
			else:
				_heavy_types.append(t)


static func _filled(n: int) -> Array[int]:
	var a: Array[int] = []
	a.resize(n)
	a.fill(-1)
	return a


static func longest(p: DesignPartType) -> float:
	return maxf(p.size.x, maxf(p.size.y, p.size.z)) if p else 0.0


# --- Layout -------------------------------------------------------------------------------

func light_count() -> int:
	return mini(tuning.cradles, LIGHT_XS.size())


## The heavy stand's index in `cradles`.
func heavy_index() -> int:
	return light_count()


## The middle of cradle `i`'s top (the heavy stand for heavy_index()).
func cradle_point(i: int) -> Vector3:
	if i >= light_count():
		return HEAVY_AT
	return Vector3(LIGHT_XS[i], CRADLE_TOP, LIGHT_Z)


## Bot `i`'s slot on the charger rack (where it hangs to charge).
func dock_point(i: int) -> Vector3:
	var col := i % CHARGER_XS.size()
	var row := (i / CHARGER_XS.size()) % CHARGER_YS.size()
	return Vector3(CHARGER_XS[col], CHARGER_YS[row], CHARGER_Z)


## Where a part sits in a place: the intake rollers or the refurbished rack.
static func rack_point(slot: int, out: bool) -> Vector3:
	if not out:
		return Vector3(ROLLER_XS[clampi(slot, 0, ROLLER_XS.size() - 1)], ROLLER_Y, ROLLER_Z)
	var level := slot / OUT_ZS.size()
	return Vector3(OUT_X, OUT_LEVELS[mini(level, OUT_LEVELS.size() - 1)], OUT_ZS[slot % OUT_ZS.size()])


## A point on the cart (its bed top), `along` its length.
func cart_point(along: float) -> Vector3:
	var yaw := float(cart.yaw)
	return (cart.pos as Vector3) + Vector3(cos(yaw) * along, CART_BED, -sin(yaw) * along)


# --- Deliveries ---------------------------------------------------------------------------

## A second-hand part arrives at goods in (the parts market's used lots, or the stand-in
## dealer's): its type (any size and grade: it is refurbished to the same size at the certified
## grade), its condition (0..1) and who sold it. Returns the lot's id, or -1 for a type the
## catalogue doesn't have or too big for the annex.
func receive(type_id: String, condition: float, source := "") -> int:
	var p := catalog.part(type_id)
	if p == null or longest(p) > tuning.heavy_max:
		return -1
	var id := _next_id
	_next_id += 1
	var c := clampf(condition, 0.0, 1.0)
	var base := catalog.base_of(type_id)
	var yaw := 0.0 if p.size.x >= p.size.z else PI * 0.5
	var dims := Vector3(maxf(p.size.x, p.size.z), p.size.y, minf(p.size.x, p.size.z))
	lots[id] = {"id": id, "type": type_id, "base": p.base_id if p.base_id != "" else p.id, "size": p.size_class,
			"name": base.display_name if base else p.display_name, "condition": c, "start": c, "wear": 1.0 - c, "grime": 1.0 - c,
			"heavy": longest(p) > tuning.light_max, "dims": dims, "yaw": yaw, "rot": 0.0, "where": AT_BACKLOG,
			"slot": -1, "pos": CART_PICK, "stage": -1, "progress": 0.0, "retest": false, "bot": -1, "result": "",
			"cost": 0.0, "paid": float(p.cost), "source": source, "fit": 1.0,
			"rack_fit": minf(1.0, RACK_FIT / maxf(longest(p), 0.01)), "scrap_fit": minf(1.0, SCRAP_FIT / maxf(longest(p), 0.01)),
			"h": dims.y, "at": time, "done_at": -1.0}
	backlog.append(id)
	events.append({"kind": "arrived", "lot": id, "bot": -1})
	return id


# --- Estimates ----------------------------------------------------------------------------

## What refurbishing a part would take, for the market and the board: {result (the certified
## type id), seconds (at a normal pace, one bot, not counting the flying), cost (credits), scrap
## (chance 0..1), new_price (the certified part bought new), heavy (true: the heavy stand)}. Empty
## for an unknown type or one too big for the annex.
func estimate(type_id: String, condition: float) -> Dictionary:
	var p := catalog.part(type_id)
	if p == null or longest(p) > tuning.heavy_max:
		return {}
	var wear := 1.0 - clampf(condition, 0.0, 1.0)
	var result := certified_type(type_id)
	var rp := catalog.part(result)
	var secs := 0.0
	for s in Stage.CUT:
		secs += stage_seconds(s, p.size_class, wear)
	secs += stage_seconds(Stage.REBUILD, p.size_class, wear) * 0.5 * tuning.retest_chance * wear
	var new_price := float(rp.cost) if rp else float(p.cost)
	return {"result": result, "seconds": secs, "cost": refurb_cost(new_price, wear),
			"scrap": scrap_odds(wear), "new_price": new_price, "heavy": longest(p) > tuning.light_max}


## The type a part is certified as: the same type and size at the certified grade.
func certified_type(type_id: String) -> String:
	var p := catalog.part(type_id)
	if p == null:
		return type_id
	var base := catalog.base_of(type_id)
	if base == null or not base.graded:
		return p.id
	return DesignGrades.variant_id(base, p.size_class, tuning.certified_grade)


## One bot's seconds for a stage (a team shares it).
func stage_seconds(stage: int, size_class: int, wear: float) -> float:
	var t := tuning.cut_seconds if stage == Stage.CUT else (tuning.stage_seconds[stage] if stage < tuning.stage_seconds.size() else 10.0)
	return t * pow(tuning.per_class, maxi(size_class, 1) - 1) * (tuning.wear_base + tuning.wear_extra * wear)


func refurb_cost(new_price: float, wear: float) -> float:
	return roundf(new_price * (tuning.cost_base + tuning.cost_wear * wear) / 10.0) * 10.0


func scrap_odds(wear: float) -> float:
	return clampf(tuning.scrap_chance * wear * wear, 0.0, 1.0)


## Graded catalogue parts the stand-in dealer brings (machinery with a Void Salvage model, no
## longer than max_size), as Reclaimed variants, sorted so every machine picks the same.
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
			if p and longest(p) <= max_size:
				out.append(v)
	return out


# --- The clock ----------------------------------------------------------------------------

## One step of yard time (the shared clock calls it in fixed ticks).
func step(delta: float) -> void:
	events.clear()
	time += delta
	_step_dealer()
	_step_cart(delta)
	_step_crane(delta)
	for b in bots:
		_step_bot(b, delta)
	_step_heavy(delta)


func _step_dealer() -> void:
	if not standin_dealer:
		dealer.next_at = maxf(float(dealer.next_at), time)
		return
	if time < float(dealer.next_at):
		return
	if backlog.size() >= 2:
		dealer.next_at = time + 5.0
		return
	var heavy := not _heavy_types.is_empty() and (_light_types.is_empty() or _rng.randf() < tuning.dealer_heavy_chance)
	var pool := _heavy_types if heavy else _light_types
	if not pool.is_empty():
		var n := 1 if heavy else 1 + int(_rng.randf() < 0.45)
		for i in n:
			var t: String = pool[_rng.randi_range(0, pool.size() - 1)]
			receive(t, snappedf(_rng.randf_range(tuning.dealer_condition.x, tuning.dealer_condition.y), 0.01), DEALER_NAME)
	dealer.next_at = time + _rng.randf_range(tuning.dealer_gap.x, tuning.dealer_gap.y)


## Moves `who` (a dict with `key`) towards `to` at up to `speed` m/s, easing in; true on arrival.
static func _fly(who: Dictionary, to: Vector3, speed: float, delta: float, key := "pos") -> bool:
	var pos: Vector3 = who[key]
	var gap := to - pos
	var dist := gap.length()
	if dist < 0.03:
		who[key] = to
		return true
	var v := minf(speed, maxf(dist * 1.6, 0.4))
	who[key] = pos + gap / dist * minf(v * delta, dist)
	return false


## Moves at a steady `speed` towards `to` (no easing: the cart and the crane); true on arrival.
static func _drive(who: Dictionary, to: Vector3, speed: float, delta: float, key := "pos") -> bool:
	var pos: Vector3 = who[key]
	var gap := to - pos
	var dist := gap.length()
	var v := speed * clampf(dist / 0.8, 0.25, 1.0)
	if dist <= v * delta + 0.001:
		who[key] = to
		return true
	who[key] = pos + gap / dist * v * delta
	return false


# --- The goods-in cart --------------------------------------------------------------------

func _step_cart(delta: float) -> void:
	var c := cart
	match String(c.phase):
		"park":
			_plan_trip()
		"out", "in", "back":
			var path: Array = c.path
			if path.is_empty():
				_cart_arrived()
			else:
				var to: Vector3 = path[0]
				var gap := to - (c.pos as Vector3)
				if Vector2(gap.x, gap.z).length() > 0.05:
					c.yaw = atan2(-gap.z, gap.x)
				if _drive(c, to, tuning.cart_speed, delta):
					path.pop_front()
			_ride()
		"load":
			c.t = float(c.t) + delta
			if float(c.t) >= tuning.cart_load:
				c.phase = "in"
				c.path = (CART_HEAVY_ROUTE if bool(c.heavy) else CART_LIGHT_ROUTE).duplicate()
		"unload":
			var load: Array = c.load
			if load.is_empty():
				_cart_home()
				return
			var lot: Dictionary = lots[int(load[0])]
			if _fly(lot, rack_point(int(lot.slot), false), tuning.cart_unload_speed, delta):
				lot.where = AT_INTAKE
				lot.rot = PI * 0.5
				load.pop_front()
				events.append({"kind": "unloaded", "lot": int(lot.id), "bot": -1})
		"wait":
			var lot: Dictionary = lots.get(int(c.load[0]) if not (c.load as Array).is_empty() else -1, {})
			if lot.is_empty() or String(lot.where) != AT_CART:
				c.load = []
				_cart_home()


## At park: the oldest lot at goods in that can go now (a light one with room on the rollers, a
## heavy one with the heavy stand free), with more light ones to fill the trip.
func _plan_trip() -> void:
	var first := -1
	for id: int in backlog:
		var lot: Dictionary = lots[id]
		if bool(lot.heavy):
			if cradles[heavy_index()] < 0 and not crane_busy():
				first = id
				break
		elif intake.has(-1):
			first = id
			break
	if first < 0:
		return
	var c := cart
	var load: Array = [first]
	c.heavy = bool(lots[first].heavy)
	if bool(c.heavy):
		cradles[heavy_index()] = first
	else:
		for id: int in backlog:
			if load.size() >= mini(tuning.cart_carry, intake.count(-1)):
				break
			if id != first and not bool(lots[id].heavy):
				load.append(id)
		for id: int in load:
			var slot := intake.find(-1)
			intake[slot] = id
			lots[id].slot = slot
	for id: int in load:
		backlog.erase(id)
	c.load = load
	c.phase = "out"
	c.path = [CART_PICK]


func _cart_arrived() -> void:
	var c := cart
	match String(c.phase):
		"out":
			c.phase = "load"
			c.t = 0.0
			for id: int in c.load:
				lots[id].where = AT_CART
			_ride()
		"in":
			if bool(c.heavy):
				c.phase = "wait"
				var lot: Dictionary = lots[int(c.load[0])]
				_crane_job(int(lot.id), HEAVY_AT, 0.0, AT_CRADLE)
			else:
				c.phase = "unload"
		"back":
			c.phase = "park"


func _cart_home() -> void:
	var c := cart
	var route: Array = (CART_HEAVY_ROUTE if bool(c.heavy) else CART_LIGHT_ROUTE).duplicate()
	route.reverse()
	route.pop_front()
	route.append(CART_PARK)
	c.path = route
	c.phase = "back"


## The cart's load rides with it.
func _ride() -> void:
	var load: Array = cart.load
	for k in load.size():
		var lot: Dictionary = lots[int(load[k])]
		if String(lot.where) != AT_CART:
			continue
		var along := 0.0 if bool(lot.heavy) else CART_SLOTS[mini(k, CART_SLOTS.size() - 1)]
		lot.pos = cart_point(along)
		lot.rot = float(cart.yaw)


# --- The crane ----------------------------------------------------------------------------

## Queues the crane to lift lot `id` to `to` (its bottom middle there), turned `rot`, then mark
## it `then` (AT_CRADLE: on the heavy stand; AT_OUT: the heavy out bay; AT_SCRAP: the skip).
func _crane_job(id: int, to: Vector3, rot: float, then: String) -> void:
	var k := crane
	if crane_busy():
		(k.queue as Array).append({"lot": id, "to": to, "rot": rot, "then": then})
		return
	k.lot = id
	k.to = to
	k.rot = rot
	k.then = then
	k.phase = "over"
	k.t = 0.0


func crane_busy() -> bool:
	return String(crane.phase) not in ["idle", "park"]


func _step_crane(delta: float) -> void:
	var k := crane
	var hook: Vector3 = k.hook
	var lot: Dictionary = lots.get(int(k.lot), {})
	match String(k.phase):
		"idle":
			pass
		"park":
			if _drive(k, CRANE_PARK, tuning.crane_speed, delta, "hook"):
				k.phase = "idle"
		"over":
			# Up to travelling height first, then across.
			if hook.y < CRANE_TRAVEL_Y - 0.01:
				_drive(k, Vector3(hook.x, CRANE_TRAVEL_Y, hook.z), tuning.hoist_speed, delta, "hook")
			else:
				var at: Vector3 = lot.pos
				if _drive(k, Vector3(at.x, CRANE_TRAVEL_Y, at.z), tuning.crane_speed, delta, "hook"):
					k.phase = "lower"
		"lower":
			var top := (lot.pos as Vector3) + Vector3(0, float(lot.h) + SLING, 0)
			if _drive(k, top, tuning.hoist_speed, delta, "hook"):
				k.phase = "sling"
				k.t = 0.0
		"sling":
			k.t = float(k.t) + delta
			if float(k.t) >= tuning.crane_hold:
				if String(lot.where) == AT_CRADLE:
					cradles[heavy_index()] = -1
				lot.where = AT_CRANE
				k.phase = "lift"
				events.append({"kind": "slung", "lot": int(lot.id), "bot": -1})
		"lift":
			_hang(lot)
			if _drive(k, Vector3(hook.x, CRANE_TRAVEL_Y, hook.z), tuning.hoist_speed, delta, "hook"):
				k.phase = "carry"
		"carry":
			var to: Vector3 = k.to
			lot.rot = rotate_toward(float(lot.rot), float(k.rot), 0.5 * delta)
			_hang(lot)
			if _drive(k, Vector3(to.x, CRANE_TRAVEL_Y, to.z), tuning.crane_speed, delta, "hook"):
				lot.rot = float(k.rot)
				k.phase = "set"
		"set":
			var to: Vector3 = k.to
			_hang(lot)
			if _drive(k, to + Vector3(0, float(lot.h) + SLING, 0), tuning.hoist_speed, delta, "hook"):
				lot.pos = to
				k.phase = "unsling"
				k.t = 0.0
		"unsling":
			k.t = float(k.t) + delta
			if float(k.t) >= tuning.crane_hold:
				_landed(lot, String(k.then))
				k.phase = "up"
		"up":
			if _drive(k, Vector3(hook.x, CRANE_TRAVEL_Y, hook.z), tuning.hoist_speed, delta, "hook"):
				k.lot = -1
				k.phase = "park"
				var queue: Array = k.queue
				if not queue.is_empty():
					var j: Dictionary = queue.pop_front()
					_crane_job(int(j.lot), j.to, float(j.rot), String(j.then))


func _hang(lot: Dictionary) -> void:
	lot.pos = (crane.hook as Vector3) - Vector3(0, float(lot.h) + SLING, 0)


func _landed(lot: Dictionary, then: String) -> void:
	events.append({"kind": "set", "lot": int(lot.id), "bot": -1})
	match then:
		AT_CRADLE:
			lot.where = AT_CRADLE
			lot.stage = Stage.INSPECT
			lot.progress = 0.0
			events.append({"kind": "stage", "lot": int(lot.id), "bot": -1})
		AT_OUT:
			lot.where = AT_OUT
			heavy_out = int(lot.id)
		AT_SCRAP:
			lot.where = AT_SCRAP


# --- The bots -----------------------------------------------------------------------------

func _step_bot(b: Dictionary, delta: float) -> void:
	var pace := float(b.pace)
	var i := int(b.id)
	var speed := tuning.fly_speed * pace
	match String(b.state):
		BOT_DOCK:
			b.tool = ""
			var docked := _fly(b, dock_point(i), speed, delta)
			if b.wait > 0.0:
				b.wait = float(b.wait) - delta
			if docked:
				b.charge = minf(1.0, float(b.charge) + tuning.recharge * delta)
				if bool(b.charging) and float(b.charge) >= 0.98:
					b.charging = false
				if float(b.charge) < tuning.recharge_at and not bool(b.charging):
					b.charging = true
					events.append({"kind": "docked", "lot": -1, "bot": i})
			if bool(b.charging) or float(b.wait) > 0.0:
				return
			if String(b.role) == "light":
				var lot_id := _oldest_waiting()
				if lot_id >= 0 and cradles[i] < 0:
					var lot: Dictionary = lots[lot_id]
					lot.bot = i
					cradles[i] = lot_id
					b.lot = lot_id
					b.state = BOT_FETCH
					b.target = (lot.pos as Vector3) + Vector3(0, _rack_h(lot) + 0.75, 0)
					return
			if _heavy_wants_hands():
				var h: Dictionary = lots[cradles[heavy_index()]]
				b.lot = int(h.id)
				b.state = BOT_WORK
				b.spot_t = 0.0
				_next_spot(b, h)
		BOT_FETCH:
			var lot: Dictionary = lots[int(b.lot)]
			if _fly(b, b.target, speed, delta):
				intake[int(lot.slot)] = -1
				lot.slot = -1
				lot.where = AT_CARRIED
				lot.rot = PI * 0.5
				b.state = BOT_CARRY
				b.target = cradle_point(i) + Vector3(0, float(lot.h) + 0.75, 0)
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
			var lot: Dictionary = lots[int(b.lot)]
			if bool(lot.heavy):
				_help(b, lot, delta)
			else:
				_work(b, lot, delta)
		BOT_STOW:
			var lot: Dictionary = lots[int(b.lot)]
			var arrived := _fly(b, b.target, speed, delta)
			lot.pos = (b.pos as Vector3) - Vector3(0, float(lot.h) * _place_fit(lot) + 0.75, 0)
			if arrived:
				_put_down(b, lot)
		BOT_RETURN:
			if _fly(b, dock_point(i), speed, delta):
				b.state = BOT_DOCK
				b.wait = _rng.randf_range(0.5, 2.5)


## The oldest lot on the intake rollers, not yet claimed (-1 for none).
func _oldest_waiting() -> int:
	var best := -1
	for id: int in intake:
		if id >= 0 and String(lots[id].where) == AT_INTAKE and int(lots[id].bot) < 0 and (best < 0 or id < best):
			best = id
	return best


## True while a part on the heavy stand is being worked and has room for another bot.
func _heavy_wants_hands() -> bool:
	var id := cradles[heavy_index()]
	if id < 0:
		return false
	var lot: Dictionary = lots[id]
	if String(lot.where) != AT_CRADLE or int(lot.stage) < 0:
		return false
	return heavy_team(id).size() < tuning.team_max


## The bots working lot `id` (the heavy stand's team).
func heavy_team(id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in bots:
		if String(b.state) == BOT_WORK and int(b.lot) == id:
			out.append(b)
	return out


func _rack_h(lot: Dictionary) -> float:
	return float(lot.h) * float(lot.rack_fit)


## How big a lot is drawn where it is (1: its own size).
func _place_fit(lot: Dictionary) -> float:
	match String(lot.where):
		AT_INTAKE, AT_OUT:
			return 1.0 if bool(lot.heavy) else float(lot.rack_fit)
		AT_SCRAP:
			return float(lot.scrap_fit)
		AT_CART:
			return 1.0 if bool(lot.heavy) else float(lot.rack_fit)
		AT_CARRIED:
			return float(lot.rack_fit) if String(lot.result) != "" else 1.0
	return 1.0


## How big lot `id` is drawn now (presentation reads it).
func draw_fit(lot: Dictionary) -> float:
	if int(lot.stage) == Stage.CUT:
		return lerpf(1.0, float(lot.scrap_fit), float(lot.progress))
	if String(lot.where) == AT_CRANE and String(lot.result) == "scrap":
		return float(lot.scrap_fit)
	return _place_fit(lot)


## A light-line bot on its own cradle.
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
	_advance(lot, delta / maxf(secs, 0.01))
	if float(lot.progress) >= 1.0:
		_stage_done(lot, int(b.id))


## A bot on the heavy stand's team: it works its spot (the stand counts the team's work), and a
## light-line bot leaves when its own line has a part waiting.
func _help(b: Dictionary, lot: Dictionary, delta: float) -> void:
	var pace := float(b.pace)
	_fly(b, b.target, tuning.fly_speed * pace * 0.6, delta)
	b.charge = maxf(0.0, float(b.charge) - tuning.drain * delta)
	b.spot_t = float(b.spot_t) + delta
	if float(b.spot_t) >= tuning.spot_seconds / pace:
		b.spot_t = 0.0
		_next_spot(b, lot)
	var leave := float(b.charge) < tuning.recharge_at
	if String(b.role) == "light" and cradles[int(b.id)] < 0 and _oldest_waiting() >= 0:
		leave = true
	if leave:
		_release(b)


func _release(b: Dictionary) -> void:
	b.lot = -1
	b.tool = ""
	b.state = BOT_RETURN if float(b.charge) < tuning.recharge_at else BOT_DOCK
	b.wait = 0.0


## The heavy stand: its team's work moves its stage on (each bot on its spot adds its pace).
func _step_heavy(delta: float) -> void:
	var id := cradles[heavy_index()]
	if id < 0:
		return
	var lot: Dictionary = lots[id]
	if String(lot.where) != AT_CRADLE or int(lot.stage) < 0:
		return
	var rate := 0.0
	var first := -1
	for b in heavy_team(id):
		if (b.pos as Vector3).distance_to(b.target) < 0.6:
			rate += float(b.pace)
			if first < 0:
				first = int(b.id)
	if rate <= 0.0:
		return
	var stage := int(lot.stage)
	var secs := stage_seconds(stage, int(lot.size), float(lot.wear))
	if stage == Stage.REBUILD and bool(lot.retest):
		secs *= 0.5
	_advance(lot, delta * rate / maxf(secs, 0.01))
	if float(lot.progress) >= 1.0:
		_stage_done(lot, first)


func _advance(lot: Dictionary, step: float) -> void:
	lot.progress = minf(1.0, float(lot.progress) + step)
	var f := float(lot.progress)
	match int(lot.stage):
		Stage.CLEAN:
			lot.grime = lerpf(float(lot.wear), 0.04, f)
		Stage.REBUILD:
			var from := float(lot.start) if not bool(lot.retest) else tuning.pass_at - 0.08
			lot.condition = lerpf(from, tuning.rebuilt_condition, f)


func _stage_done(lot: Dictionary, bot_id: int) -> void:
	var stage := int(lot.stage)
	var heavy := bool(lot.heavy)
	match stage:
		Stage.INSPECT:
			if _rng.randf() < scrap_odds(float(lot.wear)):
				lot.result = "scrap"
				scrapped += 1
				recovered += float(lot.paid) * tuning.scrap_return
				events.append({"kind": "scrapped", "lot": int(lot.id), "bot": bot_id})
				if heavy:
					lot.stage = Stage.CUT
					lot.progress = 0.0
					events.append({"kind": "stage", "lot": int(lot.id), "bot": bot_id})
				else:
					_stow(bots[bot_id], lot, _scrap_spot())
				return
		Stage.CUT:
			_heavy_off(lot, _scrap_spot(), AT_SCRAP)
			return
		Stage.TEST:
			if not bool(lot.retest) and _rng.randf() < tuning.retest_chance * float(lot.wear):
				lot.retest = true
				lot.condition = tuning.pass_at - 0.08
				lot.stage = Stage.REBUILD
				lot.progress = 0.0
				events.append({"kind": "retest", "lot": int(lot.id), "bot": bot_id})
				return
			_certify(lot, bot_id)
			return
	lot.stage = stage + 1
	lot.progress = 0.0
	events.append({"kind": "stage", "lot": int(lot.id), "bot": bot_id})


func _scrap_spot() -> Vector3:
	return SCRAP_AT + Vector3(_rng.randf_range(-SCRAP_HALF.x, SCRAP_HALF.x) * 0.6, 0.0, _rng.randf_range(-SCRAP_HALF.y, SCRAP_HALF.y) * 0.6)


func _certify(lot: Dictionary, bot_id: int) -> void:
	lot.result = certified_type(String(lot.type))
	var rp := catalog.part(String(lot.result))
	lot.cost = refurb_cost(float(rp.cost) if rp else float(lot.paid), float(lot.wear))
	lot.condition = maxf(float(lot.condition), tuning.rebuilt_condition)
	spent += float(lot.cost)
	certified += 1
	stock[lot.result] = int(stock.get(lot.result, 0)) + 1
	events.append({"kind": "certified", "lot": int(lot.id), "bot": bot_id})
	if bool(lot.heavy):
		# The heavy out bay holds one: the last one there moves on to the stores.
		if heavy_out >= 0:
			lots[heavy_out].where = AT_STORES
			heavy_out = -1
		_heavy_off(lot, HEAVY_OUT_AT, AT_OUT)
		return
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
	_stow(bots[bot_id], lot, rack_point(slot, true))


## A heavy part done (certified or cut up): the team stands down and the crane takes it.
func _heavy_off(lot: Dictionary, to: Vector3, then: String) -> void:
	lot.stage = -1
	lot.done_at = time
	for b in heavy_team(int(lot.id)):
		_release(b)
	_crane_job(int(lot.id), to, 0.0, then)


func _stow(b: Dictionary, lot: Dictionary, rest: Vector3) -> void:
	lot.where = AT_CARRIED
	lot.stage = -1
	lot.done_at = time
	cradles[int(b.id)] = -1
	b.state = BOT_STOW
	b.tool = ""
	b.rest = rest
	b.target = rest + Vector3(0, float(lot.h) * float(lot.rack_fit) + 0.75, 0)


func _put_down(b: Dictionary, lot: Dictionary) -> void:
	lot.pos = b.rest
	lot.where = AT_SCRAP if String(lot.result) == "scrap" else AT_OUT
	lot.rot = 0.0
	lot.bot = -1
	b.lot = -1
	b.erase("rest")
	if float(b.charge) < tuning.recharge_at or (_oldest_waiting() < 0 and not _heavy_wants_hands()):
		b.state = BOT_RETURN
	else:
		b.state = BOT_DOCK
		b.wait = 0.0


## Picks the next place round the part to work from, and the tool for the stage. Round a big
## part a bot picks a side or the top and a spot along it, so a team spreads over it.
func _next_spot(b: Dictionary, lot: Dictionary) -> void:
	b.spot = int(b.spot) + 1
	b.tool = STAGE_TOOLS[clampi(int(lot.stage), 0, STAGE_TOOLS.size() - 1)]
	if not bool(lot.heavy):
		var c := cradle_point(int(b.id)) + Vector3(0, float(lot.h) * 0.5, 0)
		var r := maxf(maxf(float(lot.h), (lot.dims as Vector3).x) * 0.5, 0.9) + 0.9
		var a := _rng.randf_range(-PI * 0.85, PI * 0.85)
		var up := _rng.randf_range(-0.2, 0.75)
		b.target = c + Vector3(sin(a) * r, up * r * 0.7, cos(a) * r * 0.8)
		return
	var d: Vector3 = lot.dims
	var base: Vector3 = lot.pos
	var off := 1.15
	var face := _rng.randi_range(0, 4)
	var u := _rng.randf_range(-0.42, 0.42)
	var v := _rng.randf_range(0.15, 0.9)
	var p := Vector3.ZERO
	match face:
		0, 1:   # the long sides (-Z, +Z)
			p = base + Vector3(u * d.x, v * d.y, (d.z * 0.5 + off) * (-1.0 if face == 0 else 1.0))
		2, 3:   # the ends (-X, +X)
			p = base + Vector3((d.x * 0.5 + off) * (-1.0 if face == 2 else 1.0), v * d.y, u * d.z)
		_:      # the top
			p = base + Vector3(u * d.x, d.y + off, _rng.randf_range(-0.4, 0.4) * d.z)
	p.y = maxf(p.y, 1.0)
	b.target = p


# --- Reading it ---------------------------------------------------------------------------

## The lot on cradle `i` (the heavy stand for heavy_index()), or on its way to it, or {}.
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
	# One off the rack or the heavy bay, if any are still drawn there.
	if heavy_out >= 0 and String(lots[heavy_out].result) == type_id:
		lots[heavy_out].where = AT_STORES
		heavy_out = -1
		return true
	for s in out_rack.size():
		var id := out_rack[s]
		if id >= 0 and String(lots[id].result) == type_id:
			lots[id].where = AT_STORES
			out_rack[s] = -1
			break
	return true


## The whole state as plain numbers, for comparing two machines' works (tests).
func fingerprint() -> String:
	var parts: PackedStringArray = ["t%.3f" % time]
	for b in bots:
		var p: Vector3 = b.pos
		parts.append("%s %s %d %.3f %.3f %.3f %.3f" % [b.serial, b.state, int(b.lot), p.x, p.y, p.z, float(b.charge)])
	var cp: Vector3 = cart.pos
	var hk: Vector3 = crane.hook
	parts.append("cart %s %.3f %.3f crane %s %d %.3f %.3f %.3f" % [cart.phase, cp.x, cp.z, crane.phase, int(crane.lot), hk.x, hk.y, hk.z])
	var ids: Array = lots.keys()
	ids.sort()
	for id: int in ids:
		var l: Dictionary = lots[id]
		parts.append("%d %s %s %d %.3f %.3f %s" % [id, l.type, l.where, int(l.stage), float(l.progress), float(l.condition), l.result])
	parts.append("spent %.1f" % spent)
	return " | ".join(parts)
