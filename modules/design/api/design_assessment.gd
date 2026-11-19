class_name DesignAssessment
extends RefCounted
## How well the open design answers its ship order (ShipOrders), area by area (beenster,
## 19 Nov: "a very detailed screen which assesses the ship's match to the contract brief ...
## multi-faceted to cover all the potential pitfalls of the contract and potential bonuses or
## cheap wins ... a validation % for each area ... an overall status ... a narrative from our
## company optimiser").
##
## assess() reads the design's totals and rule problems and returns:
##   areas     one entry per area of the contract, each with a validation % (score 0..1), a
##             status (OK, WATCH, FAIL) and the checks behind it
##   findings  pitfalls, risks, bonuses and cheap wins, each with the area it belongs to
##   moves     the company optimiser's changes: grade and size swaps and parts to add, each
##             costed and tried against the brief on a copy of the totals
##   plan      the optimiser's cheapest set of moves that closes the gaps it can
##   status    the design's overall standing, score its overall %
##   narrative the optimiser's write-up, a paragraph a line
## Pure data: the views only draw it. It takes a few milliseconds (the moves are tried on
## copied numbers, never by rebuilding the design).

const OK := "ok"
const WATCH := "watch"
const FAIL := "fail"

## Kinds of finding.
const PITFALL := "pitfall"
const RISK := "risk"
const BONUS := "bonus"
const WIN := "win"

## Overall status, best first.
const READY := "READY TO BID"
const CARE := "BID WITH CARE"
const CLOSE := "CLOSE"
const WORK := "NEEDS WORK"
const NOT_VIABLE := "NOT VIABLE"
const NO_BRIEF := "NO BRIEF"

## The areas, in the order the screen shows them: id -> [name, weight in the overall %, what it covers].
const AREAS: Array = [
	["brief", "Performance against the brief", 0.32, "Every rating the client asked for."],
	["budget", "Cost and margin", 0.16, "The ship's cost against the client's ceiling, and room for price swings."],
	["schedule", "Delivery schedule", 0.16, "Supplier waits and yard hours against the days the client gave."],
	["rules", "Buildability and safety", 0.14, "What the design office's rules flag: things that cannot be built or will not work."],
	["systems", "Power and running", 0.10, "Spare power, fuel for the drives, thrust."],
	["crew", "Crew and habitability", 0.06, "What a crew living aboard needs: air, food, care."],
	["role", "What the client will look for", 0.06, "The checks a client in this line of work makes that the brief does not spell out."],
]

## Yard hours a working day (a crew of six on eight-hour shifts).
const YARD_HOURS_PER_DAY := 48.0
## Beat a rating by this share and the client pays BEAT_SHARE of the fee on top, each.
const BEAT_BY := 0.25
const BEAT_SHARE := 0.04
const BEAT_MAX := 4
## Deliver this much early (share of the days given) for EARLY_SHARE of the fee.
const EARLY_BY := 0.25
const EARLY_SHARE := 0.08
## Each day late costs this share of the fee.
const LATE_SHARE_PER_DAY := 0.02
## Market prices move about this much while parts are on order: cost above this share of the
## budget is watched.
const PRICE_SWING := 0.08
## Under this share of the budget the client notices the saving (standing).
const UNDER_BUDGET := 0.85
## A rating within this share above its need is watched (a heavier fit-out tips it over).
const HEADROOM := 0.1
## Spare power under this share of what is made is watched.
const POWER_MARGIN := 0.1
## A grade swap or an addition costing at most this share of the budget is a cheap win.
const CHEAP := 0.03

## Parts the optimiser may add to close a gap in a rating, best first.
const ADD_FOR: Dictionary = {
	"cargo_m3": ["cargo_rack", "cargo_container"], "crew": ["bunk_stack", "bunk"],
	"attack": ["turret", "twin_turret"], "defence": ["armour_slab", "shield_generator"],
	"sensor_km": ["radar_array", "survey_array"], "power": ["reactor_small", "generator"],
	"jump_ly": ["jump_drive"], "stealth": ["radiator", "signature_damper"], "speed": ["main_engine"],
	"fuel_m3": ["fuel_tank"],
}
## Most of one part the optimiser adds in one move.
const ADD_MAX := 12
## What the optimiser adds to power what it adds.
const POWER_PART := "generator"
## Never swapped to Reclaimed: the crew's lives hang on them.
const NO_RECLAIMED: PackedStringArray = ["life", "medical"]

## What a client in each line of work checks that its brief leaves out:
## [label, check id, why it matters].
const ROLE_CHECKS: Dictionary = {
	"hauler": [["A cargo door into the hold", "cargo_door", "Freight goes in by the pallet; a person-sized door will not do."],
		["Fuel for two jumps", "two_jumps", "Freight runs end where the cargo is, not where the fuel is."],
		["No reclaimed drive parts", "no_reclaimed_drive", "A hauler that breaks down loses the cargo's insurance."]],
	"liner": [["A mess or recreation room", "lounge", "Passengers judge her by somewhere to sit."],
		["Medical bay or pod", "medical", "A liner carries strangers: someone will fall ill."],
		["Quiet running (stealth 30+)", "quiet", "Loud ships are uncomfortable ships."]],
	"patrol": [["Fire control fitted", "fire_control", "Guns without fire control miss what runs."],
		["Hardened weapons or armour", "hardened", "Convoy work means taking hits."],
		["Power to spare under fire (20%)", "power_reserve", "Shields and guns draw more in a fight."]],
	"explorer": [["Fuel for two jumps", "two_jumps", "There are no ports where she goes."],
		["Medical bay or pod", "medical", "Weeks from help."],
		["A workshop or spares aboard", "workshop", "She repairs herself or she doesn't come home."]],
	"courier": [["No reclaimed parts", "no_reclaimed", "Reclaimed kit is loud and gives her away."],
		["Light (under 150 t)", "light", "Mass costs speed and range on every run."],
		["Signature dampers or radiators", "dampers", "Quiet is designed in, not hoped for."]],
	"tug": [["A tow winch or tractor beam", "tow", "A tug that cannot tow is a slow hauler."],
		["Power to spare (20%)", "power_reserve", "The winch and tractor draw hard."],
		["Hardened frame parts", "hardened", "Salvage work bangs the hull about."]],
}

var order: Dictionary = {}
var areas: Array[Dictionary] = []
var findings: Array[Dictionary] = []
var moves: Array[Dictionary] = []
var plan: Array[Dictionary] = []
## After the plan: {met, total, cost} ({} with no plan).
var plan_result: Dictionary = {}
var score := 0.0
var status := NO_BRIEF
var narrative: PackedStringArray = []
## The demand rows (DesignTotals.fit plus delivery), as the brief area shows them.
var rows: Array[Dictionary] = []
## Days to deliver: {days, given, parts, hours}.
var schedule: Dictionary = {}
## The yard's fee and what bonuses and penalties do to it.
var fee := 0
var bonus_total := 0
var penalty_total := 0

var _cat: DesignCatalog
var _rec: DesignRecord
## Placed type id -> count, and the base totals' per-type maxima inputs.
var _placed: Dictionary = {}


## Assesses `d` (its totals `t` and rule problems) against `ship_order` ({} for none: the
## areas that need no brief are still assessed).
static func assess(d: DesignRecord, cat: DesignCatalog, t: DesignTotals, problems: Array,
		ship_order: Dictionary) -> DesignAssessment:
	var a := DesignAssessment.new()
	a._cat = cat
	a._rec = d
	a.order = ship_order
	a.fee = int(ship_order.get("pay", 0))
	if d == null or t == null:
		return a
	for c: Dictionary in d.components.values() + d.mounts.values():
		var id := str(c.type)
		a._placed[id] = int(a._placed.get(id, 0)) + 1
	var demands: Dictionary = ship_order.get("demands", {})
	var base := Sim.of(t, a._comp_hours(t))
	a.rows = a._rows(base, demands)
	a.schedule = a._schedule(base)
	a._brief_area(base)
	a._budget_area(base)
	a._schedule_area(base)
	a._rules_area(problems)
	a._systems_area(base)
	a._crew_area(base)
	a._role_area(base)
	if not demands.is_empty():
		a._optimise(base, demands)
	a._overall()
	a._write()
	return a


## The area entry for `id` ({} if not assessed).
func area(id: String) -> Dictionary:
	for ar in areas:
		if ar.id == id:
			return ar
	return {}


func findings_of(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in findings:
		if f.kind == kind:
			out.append(f)
	return out


## Demands met (rows ok) and how many there are.
func met() -> Vector2i:
	var n := 0
	for r in rows:
		n += 1 if r.ok else 0
	return Vector2i(n, rows.size())


# --- The numbers a move changes, copied so moves can be tried without rebuilding --------

class Sim:
	extends RefCounted
	var t := DesignTotals.new()
	var comp_hours := 0.0
	## Placed type id -> count (after moves), for the per-type maxima (lead days, sensors).
	var placed: Dictionary = {}

	static func of(src: DesignTotals, comp_h: float) -> Sim:
		var s := Sim.new()
		for k in ["cost", "mass", "build_hours", "power_made", "power_used", "thrust", "crew", "cargo_m3",
				"fuel_m3", "lead_days", "jump_rating", "attack", "defence", "parts_signature", "sensor_km",
				"hull_mass", "integrity"]:
			s.t.set(k, src.get(k))
		s.comp_hours = comp_h
		return s

	func copy() -> Sim:
		var s := Sim.of(t, comp_hours)
		s.placed = placed.duplicate()
		return s

	## Adds (sign 1) or takes away (sign -1) `n` of part `pt`.
	func apply(pt: DesignPartType, n: int, sign: int) -> void:
		var k := float(n * sign)
		t.cost += pt.cost * k
		t.mass += pt.mass * k
		t.build_hours += pt.build_hours * k
		comp_hours += pt.build_hours * k
		if pt.power >= 0.0:
			t.power_made += pt.power * k
		else:
			t.power_used -= pt.power * k
		t.thrust += pt.thrust * k
		t.crew += pt.crew * n * sign
		t.cargo_m3 += pt.cargo * k
		t.fuel_m3 += pt.tank * k
		t.jump_rating += pt.jump * k
		t.attack += pt.attack * k
		t.defence += pt.defence * k
		t.parts_signature += pt.signature * k
		t.integrity += pt.integrity * k
		placed[pt.id] = int(placed.get(pt.id, 0)) + n * sign
		if int(placed[pt.id]) <= 0:
			placed.erase(pt.id)

	## Lead days and sensor range are the largest of the parts': worked out again after moves.
	func settle(cat: DesignCatalog) -> void:
		var lead := 0
		var sensor := 0.0
		for id: String in placed:
			var pt := cat.part(id)
			if pt:
				lead = maxi(lead, pt.lead_days)
				sensor = maxf(sensor, pt.sensor)
		t.lead_days = lead
		t.sensor_km = sensor


func _comp_hours(t: DesignTotals) -> float:
	var h := 0.0
	for line in t.lines:
		if line.kind == "component":
			h += float(line.hours)
	return h


## The brief's rows (DesignTotals.fit) and, when the order gives days, a delivery row.
func _rows(s: Sim, demands: Dictionary) -> Array[Dictionary]:
	var out := s.t.fit(demands)
	if order.has("days") and not demands.is_empty():
		var sch := _schedule(s)
		var need := float(order.days)
		out.append({"key": "days", "label": "Delivery, days", "need": need, "have": float(sch.days),
				"ok": float(sch.days) <= need, "share": clampf(need / maxf(float(sch.days), 0.01), 0.0, 1.0)})
	return out


## Days to deliver: the hull, rooms and services start at once; the components go in once the
## slowest supplier has delivered.
func _schedule(s: Sim) -> Dictionary:
	var all := s.t.build_hours / YARD_HOURS_PER_DAY
	var parts := float(s.t.lead_days) + s.comp_hours / YARD_HOURS_PER_DAY
	return {"days": ceili(maxf(all, parts)), "given": int(order.get("days", 0)), "parts": s.t.lead_days,
			"hours": s.t.build_hours}


func _area(id: String) -> Dictionary:
	for spec: Array in AREAS:
		if spec[0] == id:
			return {"id": id, "name": spec[1], "weight": spec[2], "about": spec[3], "score": 1.0,
					"status": OK, "checks": [], "assessed": true}
	return {}


## One line in an area: {label, have (text), ok, watch, share}.
func _check(ar: Dictionary, label: String, have: String, ok: bool, share: float, watch := false) -> void:
	(ar.checks as Array).append({"label": label, "have": have, "ok": ok, "watch": watch and ok,
			"share": clampf(share, 0.0, 1.0)})


func _finish(ar: Dictionary) -> void:
	var checks: Array = ar.checks
	if checks.is_empty():
		ar.score = 1.0
	else:
		var sum := 0.0
		var fail := false
		var watch := false
		for c: Dictionary in checks:
			sum += float(c.share)
			fail = fail or not c.ok
			watch = watch or c.watch
		ar.score = sum / checks.size()
		ar.status = FAIL if fail else (WATCH if watch else OK)
	areas.append(ar)


func _find(kind: String, area_id: String, text: String, value := 0.0) -> void:
	findings.append({"kind": kind, "area": area_id, "text": text, "value": value})


func _no_brief(ar: Dictionary) -> void:
	ar.assessed = false
	ar.score = 0.0
	ar.status = WATCH
	areas.append(ar)


# --- The areas ------------------------------------------------------------------------

func _brief_area(s: Sim) -> void:
	var ar := _area("brief")
	var demands: Dictionary = order.get("demands", {})
	if demands.is_empty():
		_no_brief(ar)
		return
	var beats := 0
	for r in rows:
		if r.key == "budget" or r.key == "days":
			continue
		var more: bool = not (r.key in ["max_mass", "build_days"])
		var need: float = r.need
		var have: float = r.have
		var watch: bool = more and r.ok and have < need * (1.0 + HEADROOM)
		_check(ar, str(r.label), "%s of %s" % [_n(have), _n(need)], r.ok, r.share, watch)
		if not r.ok:
			if absf(have) < 0.01:
				_find(PITFALL, "brief", "%s: nothing fitted gives any, and the client asks for %s." % [_name(r), _n(need)])
			else:
				_find(PITFALL, "brief", "%s is %s short of the %s asked (%d%%)." % [_name(r), _n(absf(need - have)),
						_n(need), int(r.share * 100.0)])
		elif watch:
			_find(RISK, "brief", "%s only just meets the brief (%s of %s): anything heavier added tips it under." % [
					_name(r), _n(have), _n(need)])
		elif more and need > 0.0 and have >= need * (1.0 + BEAT_BY) and beats < BEAT_MAX:
			beats += 1
			var b := int(roundf(fee * BEAT_SHARE / 1000.0) * 1000.0)
			bonus_total += b
			_find(BONUS, "brief", "%s beats the brief by %d%%: the client's performance bonus." % [
					_name(r), int((have / need - 1.0) * 100.0)], b)
		elif more and need > 0.0 and r.ok and beats < BEAT_MAX:
			var short := need * (1.0 + BEAT_BY) - have
			_find(BONUS, "brief", "%s is %s short of the performance bonus (%s)." % [_name(r), _n(short),
					_n(need * (1.0 + BEAT_BY))], 0.0)
	# The order's special clauses (ShipOrders.CLAUSES: rooms, parts, grades) are part of the brief.
	for r in DesignContractCheck.clauses(order, _rec, _cat):
		_check(ar, str(r.label), "%s of %s" % [_n(r.have), _n(r.need)], r.ok, r.share)
		if not r.ok:
			_find(PITFALL, "brief", "Clause not met: %s." % str(r.label))
	_finish(ar)


func _budget_area(s: Sim) -> void:
	var ar := _area("budget")
	var budget := float((order.get("demands", {}) as Dictionary).get("budget", 0.0))
	if budget <= 0.0:
		_no_brief(ar)
		return
	var cost := s.t.cost
	var ok := cost <= budget
	var watch := ok and cost > budget * (1.0 - PRICE_SWING)
	_check(ar, "Cost within the ceiling", "CR %s of %s" % [_money(cost), _money(budget)], ok,
			budget / cost if cost > budget else 1.0, watch)
	var swing := cost * (1.0 + PRICE_SWING)
	_check(ar, "Survives a %d%% price rise" % int(PRICE_SWING * 100.0), "CR %s" % _money(swing), swing <= budget,
			clampf(budget / swing, 0.0, 1.0))
	_check(ar, "Yard fee", "CR %s" % _money(fee), true, 1.0)
	if not ok:
		_find(PITFALL, "budget", "The ship costs CR %s over the client's ceiling of CR %s." % [_money(cost - budget), _money(budget)],
				-(cost - budget))
	elif watch:
		_find(RISK, "budget", "Only CR %s under the ceiling: a %d%% swing in part prices would put her over." % [
				_money(budget - cost), int(PRICE_SWING * 100.0)])
	elif cost <= budget * UNDER_BUDGET:
		_find(BONUS, "budget", "CR %s under the ceiling: the client remembers a saving (standing), or spend it on the ratings." % _money(budget - cost))
	_finish(ar)


func _schedule_area(s: Sim) -> void:
	var ar := _area("schedule")
	var given := int(schedule.get("given", 0))
	if given <= 0 or (order.get("demands", {}) as Dictionary).is_empty():
		_no_brief(ar)
		return
	var days := int(schedule.days)
	var ok := days <= given
	_check(ar, "Delivered in time", "%d of %d days" % [days, given], ok, float(given) / days if days > given else 1.0,
			ok and days > int(given * 0.85))
	_check(ar, "Slowest supplier", "%d days" % int(schedule.parts), float(schedule.parts) < given / 2.0,
			clampf(float(given) / 2.0 / maxf(1.0, float(schedule.parts)), 0.0, 1.0))
	_check(ar, "Yard hours", "%d h (%.0f days of the yard)" % [int(s.t.build_hours), s.t.build_hours / YARD_HOURS_PER_DAY], true, 1.0)
	if not ok:
		var late := days - given
		var p := int(roundf(fee * LATE_SHARE_PER_DAY * late / 1000.0) * 1000.0)
		penalty_total += p
		_find(PITFALL, "schedule", "She would be %d days late: CR %s off the fee in late penalties." % [late, _money(p)], -p)
	elif days <= int(given * (1.0 - EARLY_BY)):
		var b := int(roundf(fee * EARLY_SHARE / 1000.0) * 1000.0)
		bonus_total += b
		_find(BONUS, "schedule", "Delivered %d days early: the early delivery bonus." % (given - days), b)
	elif days > int(given * 0.85):
		_find(RISK, "schedule", "Only %d days in hand: one late delivery from a supplier makes her late." % (given - days))
	else:
		var need := days - int(given * (1.0 - EARLY_BY))
		_find(BONUS, "schedule", "%d days faster would earn the early delivery bonus." % need, 0.0)
	var slow := _slowest_parts(s)
	if not slow.is_empty() and float(schedule.parts) >= given / 2.0:
		_find(PITFALL if not ok else RISK, "schedule", "Waiting on suppliers for %d days: %s." % [int(schedule.parts), ", ".join(slow)])
	_finish(ar)


func _slowest_parts(s: Sim) -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in _placed:
		var pt := _cat.part(id)
		if pt and pt.lead_days == s.t.lead_days and out.size() < 3:
			out.append(pt.display_name)
	return out


func _rules_area(problems: Array) -> void:
	var ar := _area("rules")
	var errors := 0
	var warnings := 0
	for p: Dictionary in problems:
		if p.severity == DesignRules.ERROR:
			errors += 1
			if errors <= 4:
				_find(PITFALL, "rules", str(p.text) + ".")
		else:
			warnings += 1
			if warnings <= 3:
				_find(RISK, "rules", str(p.text) + ".")
	_check(ar, "Nothing that cannot be built", "%d errors" % errors, errors == 0, 1.0 - 0.25 * errors)
	_check(ar, "Nothing to check again", "%d to check" % warnings, true, 1.0 - 0.06 * warnings, warnings > 0)
	_finish(ar)


func _systems_area(s: Sim) -> void:
	var ar := _area("systems")
	var t := s.t
	var spare := t.power_balance()
	var margin := spare / t.power_made if t.power_made > 0.0 else -1.0
	_check(ar, "Power made covers power used", "%+.0f kW" % spare, spare >= 0.0,
			t.power_made / t.power_used if spare < 0.0 and t.power_used > 0.0 else 1.0,
			spare >= 0.0 and margin < POWER_MARGIN)
	if spare < 0.0:
		_find(PITFALL, "systems", "%.0f kW short of power: something will not run." % -spare)
	elif margin < POWER_MARGIN and t.power_made > 0.0:
		_find(RISK, "systems", "Only %.0f kW spare (%d%% of what she makes): no room for the client's own fit-out." % [spare, int(margin * 100.0)])
	_check(ar, "Thrust to move her", "%.2f m/s2" % t.acceleration(), t.thrust > 0.0, 1.0 if t.thrust > 0.0 else 0.0)
	if t.thrust <= 0.0:
		_find(PITFALL, "systems", "No engine or thrusters: she cannot leave the dock.")
	if t.jump_rating > 0.0:
		_check(ar, "Fuel aboard for the jump drive", "%.0f m3" % t.fuel_m3, t.fuel_m3 > 0.0, 1.0 if t.fuel_m3 > 0.0 else 0.0)
		if t.fuel_m3 <= 0.0:
			_find(PITFALL, "systems", "A jump drive with no fuel tank: her jump range is nothing.")
	_finish(ar)


func _has_category(cat_id: String) -> bool:
	for id: String in _placed:
		var pt := _cat.part(id)
		if pt and pt.category == cat_id:
			return true
	return false


func _has_room(types: Array) -> bool:
	for r: Dictionary in _rec.rooms.values():
		if str(r.type) in types:
			return true
	return false


func _crew_area(s: Sim) -> void:
	var ar := _area("crew")
	var crew := s.t.crew
	_check(ar, "Bunks", "%d" % crew, crew > 0, 1.0 if crew > 0 else 0.0)
	if crew > 0:
		var life := _has_category("life")
		_check(ar, "Life support and air", "fitted" if life else "none", life, 1.0 if life else 0.0)
		if not life:
			_find(PITFALL, "crew", "%d bunks and no life support: the crew has no air to breathe." % crew)
		var food := _has_category("galley") or _has_room(["mess"])
		_check(ar, "Somewhere to eat", "yes" if food else "no", food or crew < 4, 1.0 if food else 0.5, not food)
		if not food and crew >= 4:
			_find(RISK, "crew", "%d crew and no galley or mess: nobody signs on for long trips without one." % crew)
		var med := _has_category("medical") or _has_room(["medbay"])
		_check(ar, "Medical care", "yes" if med else "no", med or crew < 6, 1.0 if med else 0.6, not med)
		if not med and crew >= 6:
			_find(RISK, "crew", "%d crew and no medical pod or bay." % crew)
	_finish(ar)


func _role_area(s: Sim) -> void:
	var ar := _area("role")
	var role := str(order.get("role", ""))
	if not ROLE_CHECKS.has(role):
		_no_brief(ar)
		return
	for spec: Array in ROLE_CHECKS[role]:
		var ok := _role_check(str(spec[1]), s)
		_check(ar, str(spec[0]), "yes" if ok else "no", ok, 1.0 if ok else 0.0)
		if not ok:
			_find(RISK, "role", "%s: %s" % [spec[0], spec[2]])
	_finish(ar)


func _role_check(id: String, s: Sim) -> bool:
	var t := s.t
	match id:
		"cargo_door":
			for g: Dictionary in _rec.doors.values():
				if str(g.get("kind", "")) == "cargo":
					return true
			return false
		"two_jumps":
			var need := float((order.get("demands", {}) as Dictionary).get("jump_ly", 0.0))
			return t.jump_range() > 0.0 and t.fuel_m3 >= 20.0 and (need <= 0.0 or t.jump_range() >= need)
		"no_reclaimed_drive":
			return not _graded_in("R", ["propulsion", "jump", "power"])
		"no_reclaimed":
			return not _graded_in("R", [])
		"lounge":
			return _has_room(["mess", "recreation"])
		"medical":
			return _has_category("medical") or _has_room(["medbay"])
		"quiet":
			return t.stealth() >= 30.0
		"fire_control":
			return _placed_base("fire_control")
		"hardened":
			return _graded_in("H", ["weapons", "defence", "structure", "machinery"])
		"power_reserve":
			return t.power_made > 0.0 and t.power_balance() >= t.power_made * 0.2
		"workshop":
			return _has_room(["workshop"]) or _placed_base("spares_cage") or _placed_base("workbench")
		"light":
			return t.mass < 150000.0
		"dampers":
			return _placed_base("signature_damper") or _placed_base("radiator") or _placed_base("heat_sink")
		"tow":
			return _placed_base("tow_winch") or _placed_base("tractor_beam")
	return false


func _placed_base(base_id: String) -> bool:
	for id: String in _placed:
		if DesignGrades.parse(id).id == base_id:
			return true
	return false


## True if a placed part of grade `g` sits in one of `cats` (any category for []).
func _graded_in(g: String, cats: Array) -> bool:
	for id: String in _placed:
		var pt := _cat.part(id)
		if pt and pt.graded and pt.grade == g and (cats.is_empty() or pt.category in cats):
			return true
	return false


# --- The company optimiser --------------------------------------------------------------

## Tries every grade and size swap of each placed graded type (all of that type at once) and
## each addition of ADD_FOR's parts against the brief; keeps the swaps that fix a gap or save
## money without opening one, then builds the cheapest plan that closes what it can.
func _optimise(base: Sim, demands: Dictionary) -> void:
	base.placed = _placed.duplicate()
	var budget := float(demands.get("budget", 0.0))
	var before := _score_rows(base, demands)
	var fixes: Array[Dictionary] = []
	var saves: Array[Dictionary] = []
	for m in _candidates(base, demands):
		var after: Dictionary = m.after
		if after.broke:
			continue
		if int(after.fails) < int(before.fails):
			fixes.append(m)
		elif m.cost <= -1000.0 and int(after.fails) <= int(before.fails) and float(after.sum) >= float(before.sum) - 0.02 * maxf(1.0, float(before.fails)) and not after.worse:
			saves.append(m)
	fixes.sort_custom(func(a, b): return float(a.cost) < float(b.cost))
	saves.sort_custom(func(a, b): return float(a.cost) < float(b.cost))
	var seen := {}
	for m in fixes:
		if seen.has(m.base) or moves.size() >= 6:
			continue
		seen[m.base] = true
		m["kind"] = "fix"
		moves.append(m)
		if budget > 0.0 and float(m.cost) <= budget * CHEAP:
			_find(WIN, "optimiser", "%s: %s, fixes %s." % [m.text, _signed_money(float(m.cost)),
					", ".join(m.fixes)], -float(m.cost))
	var nsave := 0
	for m in saves:
		if seen.has(m.base) or nsave >= 4:
			continue
		seen[m.base] = true
		nsave += 1
		m["kind"] = "save"
		moves.append(m)
		_find(WIN, "optimiser", "%s saves CR %s and the brief is still met." % [m.text, _money(-float(m.cost))], -float(m.cost))
	_plan(base, demands, int(before.fails))


## Every move to try from `s`: {base, text, cost, fixes, after, apply (Callable on a Sim)}.
func _candidates(s: Sim, demands: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var before := _score_rows(s, demands)
	for id: String in s.placed:
		var pt := _cat.part(id)
		if pt == null or not pt.graded:
			continue
		var base_pt := _cat.base_of(id)
		if base_pt == null:
			continue
		var n := int(s.placed[id])
		var span := DesignGrades.sizes(base_pt)
		var tries: Array = []
		for g: String in DesignGrades.GRADE_ORDER:
			if g != pt.grade and _grade_allowed(g, pt):
				tries.append([pt.size_class, g])
		if pt.size_class > 0:
			for ds in [-1, 1]:
				var sz: int = pt.size_class + ds
				if sz >= span[0] and sz <= span[1]:
					tries.append([sz, pt.grade])
		for tr: Array in tries:
			var to := _cat.part(DesignGrades.variant_id(base_pt, int(tr[0]), str(tr[1])))
			if to == null or to.id == pt.id:
				continue
			var sim := s.copy()
			sim.apply(pt, n, -1)
			sim.apply(to, n, 1)
			sim.settle(_cat)
			var what := "grade %s (%s)" % [DesignGrades.GRADES[to.grade].name, DesignGrades.label(to)] if int(tr[0]) == pt.size_class \
					else "size %d (%s)" % [to.size_class, DesignGrades.label(to)]
			out.append(_move(base_pt.id, "Change %s%s to %s" % [_count(n), pt.display_name, what], sim, s, demands, before,
					{"from": pt.id, "to": to.id, "n": n}))
	for key: String in demands:
		if not ADD_FOR.has(key):
			continue
		var row := _row_of(before.rows, key)
		if row.is_empty() or row.ok:
			continue
		for add_id: String in ADD_FOR[key]:
			var base_pt := _cat.part(add_id)
			if base_pt == null:
				continue
			# The part at its own size and up to two sizes up.
			for up in 3:
				var pt := _cat.part(DesignGrades.variant_id(base_pt, base_pt.size_class + up, DesignGrades.DEFAULT_GRADE)) \
						if base_pt.size_class > 0 else (base_pt if up == 0 else null)
				if pt == null or (up > 0 and pt.size_class != base_pt.size_class + up):
					continue
				var m := _add_move(s, pt, key, demands, before)
				if not m.is_empty():
					out.append(m)
					break
	return out


## Adds `pt` one at a time (ADD_MAX at most) till the `key` row is met, with generators to
## power them when they would leave the ship short; {} if that never meets it.
func _add_move(s: Sim, pt: DesignPartType, key: String, demands: Dictionary, before: Dictionary) -> Dictionary:
	var gen := _cat.part(POWER_PART)
	var sim := s.copy()
	var gens := 0
	for k in range(1, ADD_MAX + 1):
		sim.apply(pt, 1, 1)
		while gen and pt.power < 0.0 and s.t.power_balance() >= 0.0 and sim.t.power_balance() < 0.0 and gens < ADD_MAX:
			sim.apply(gen, 1, 1)
			gens += 1
		sim.settle(_cat)
		var r := _row_of(_score_rows(sim, demands).rows, key)
		if not r.is_empty() and r.ok:
			var text := "Add %s%s" % [_count(k), pt.display_name]
			if gens > 0:
				text += " and %s%s to power %s" % [_count(gens), gen.display_name, "it" if k == 1 else "them"]
			return _move(pt.base_id if pt.base_id != "" else pt.id, text, sim, s, demands, before,
					{"add": pt.id, "n": k, "power": gens})
	return {}


## Reclaimed parts never go where lives depend on them, nor where this client checks for them.
func _grade_allowed(g: String, pt: DesignPartType) -> bool:
	if g != "R":
		return true
	if pt.category in NO_RECLAIMED:
		return false
	match str(order.get("role", "")):
		"courier":
			return false
		"hauler":
			return not (pt.category in ["propulsion", "jump", "power"])
	return true


func _move(base_id: String, text: String, sim: Sim, from: Sim, demands: Dictionary, before: Dictionary, how: Dictionary) -> Dictionary:
	var after := _score_rows(sim, demands)
	var fixed: PackedStringArray = []
	for r: Dictionary in before.rows:
		var r2 := _row_of(after.rows, str(r.key))
		if not r.ok and not r2.is_empty() and r2.ok:
			fixed.append(_name(r))
		if r.ok and not r2.is_empty() and not r2.ok:
			after.broke = true
		if not r2.is_empty() and float(r2.share) < float(r.share) - 0.001:
			after.worse = true
	if from.t.power_balance() >= 0.0 and sim.t.power_balance() < 0.0:
		after.broke = true
	return {"base": base_id, "text": text, "cost": sim.t.cost - from.t.cost, "fixes": fixed, "after": after,
			"sim": sim, "how": how}


## {rows, fails, sum, broke, worse} for `s` against `demands` (budget and delivery included).
func _score_rows(s: Sim, demands: Dictionary) -> Dictionary:
	var rs := _rows(s, demands)
	var fails := 0
	var sum := 0.0
	for r in rs:
		fails += 0 if r.ok else 1
		sum += float(r.share)
	if s.t.power_balance() < 0.0:
		fails += 1
	return {"rows": rs, "fails": fails, "sum": sum, "broke": false, "worse": false}


static func _row_of(rs: Array, key: String) -> Dictionary:
	for r: Dictionary in rs:
		if r.key == key:
			return r
	return {}


## Greedy: while gaps remain, take the cheapest move that closes at least one without opening
## another (each part type changed once), up to five steps.
func _plan(base: Sim, demands: Dictionary, fails: int) -> void:
	if fails == 0:
		return
	var s := base
	var used := {}
	for _step in 5:
		var best: Dictionary = {}
		var now := _score_rows(s, demands)
		if int(now.fails) == 0:
			break
		for m in _candidates(s, demands):
			if used.has(m.base) or m.after.broke or int(m.after.fails) >= int(now.fails):
				continue
			if best.is_empty() or float(m.cost) < float(best.cost):
				best = m
		if best.is_empty():
			break
		used[best.base] = true
		plan.append(best)
		s = best.sim
	if plan.is_empty():
		return
	var end := _score_rows(s, demands)
	var met_n := 0
	for r: Dictionary in end.rows:
		met_n += 1 if r.ok else 0
	plan_result = {"met": met_n, "total": (end.rows as Array).size(), "cost": s.t.cost,
			"extra": s.t.cost - base.t.cost, "power_ok": s.t.power_balance() >= 0.0}


# --- Overall and the write-up -----------------------------------------------------------

func _overall() -> void:
	var sum := 0.0
	var weight := 0.0
	var hard := 0
	var watch := 0
	for ar in areas:
		if not ar.assessed:
			continue
		sum += float(ar.score) * float(ar.weight)
		weight += float(ar.weight)
		if ar.status == FAIL and ar.id != "role" and ar.id != "crew":
			hard += 1
		elif ar.status != OK:
			watch += 1
	score = sum / weight if weight > 0.0 else 0.0
	# Demands missed weigh on the whole: a ship that misses half the brief is not 80% fit,
	# however well she runs.
	var m := met()
	if m.y > 0:
		score *= sqrt(float(m.x) / m.y)
	if (order.get("demands", {}) as Dictionary).is_empty():
		status = NO_BRIEF
	elif hard == 0:
		status = READY if watch == 0 else CARE
	elif _misses() <= 1 and score >= 0.75:
		status = CLOSE
	elif score >= 0.5:
		status = WORK
	else:
		status = NOT_VIABLE


## Demands (and delivery) not met.
func _misses() -> int:
	return met().y - met().x


## The fee once bonuses and penalties are counted.
func expected_fee() -> int:
	return fee + bonus_total - penalty_total


func _write() -> void:
	narrative = []
	if (order.get("demands", {}) as Dictionary).is_empty():
		narrative.append("No ship order is picked for this design, so I can only check that she will work. Pick one under SHIP ORDER at the console and I will hold her up against the client's brief.")
		var pits := findings_of(PITFALL)
		if not pits.is_empty():
			narrative.append("Before anything else: " + _join_texts(pits, 3))
		return
	var m := met()
	var client := str(order.get("client_name", "the client"))
	var open := "%s for %s: %d%% overall, %d of %d demands met." % [_status_words(), client, int(score * 100.0), m.x, m.y]
	narrative.append(open)
	var pits := findings_of(PITFALL)
	if not pits.is_empty():
		narrative.append("What would lose us the contract: " + _join_texts(pits, 4))
	if not plan.is_empty():
		var steps: PackedStringArray = []
		for p in plan:
			steps.append("%s (%s)" % [str(p.text).to_lower().left(1) + str(p.text).substr(1), _signed_money(float(p.cost))])
		var line := "What I would change, cheapest first: %s. " % "; then ".join(steps)
		line += "That meets %d of %d demands for CR %s more, CR %s in all." % [int(plan_result.met), int(plan_result.total),
				_money(float(plan_result.extra)), _money(float(plan_result.cost))]
		narrative.append(line)
	elif not pits.is_empty():
		narrative.append("I cannot close these gaps by swapping grades or adding parts alone: she needs a bigger rethink (more rooms, a larger hull or a different drive).")
	var wins := findings_of(WIN)
	if not wins.is_empty():
		narrative.append("Cheap wins: " + _join_texts(wins, 3))
	var bonuses: Array[Dictionary] = []
	for b in findings_of(BONUS):
		if float(b.value) > 0.0:
			bonuses.append(b)
	if not bonuses.is_empty():
		narrative.append("Bonuses in hand, worth CR %s: %s" % [_money(bonus_total), _join_texts(bonuses, 3)])
	var near: Array[Dictionary] = []
	for b in findings_of(BONUS):
		if float(b.value) <= 0.0:
			near.append(b)
	if not near.is_empty():
		narrative.append("Within reach: " + _join_texts(near, 2))
	var risks := findings_of(RISK)
	if not risks.is_empty():
		narrative.append("Keep an eye on: " + _join_texts(risks, 3))
	narrative.append("Our fee is CR %s; with the bonuses and penalties as she stands, expect CR %s." % [_money(fee), _money(expected_fee())])


func _status_words() -> String:
	match status:
		READY:
			return "Ready to bid"
		CARE:
			return "Ready to bid, with care"
		CLOSE:
			return "Close"
		WORK:
			return "Needs work"
		NOT_VIABLE:
			return "Not viable as she stands"
	return status.capitalize()


static func _join_texts(list: Array[Dictionary], most: int) -> String:
	var out: PackedStringArray = []
	for i in mini(most, list.size()):
		out.append(str(list[i].text).trim_suffix("."))
	var s := "; ".join(out) + "."
	if list.size() > most:
		s += " (and %d more on the screen)" % (list.size() - most)
	return s


static func _name(r: Dictionary) -> String:
	return str(r.label).get_slice(",", 0)


static func _count(n: int) -> String:
	return "" if n == 1 else "%d x " % n


static func _n(v: float) -> String:
	if absf(v) >= 1000.0:
		return _money(v)
	return ("%d" % int(roundf(v))) if absf(v - roundf(v)) < 0.05 else ("%.1f" % v)


static func _money(v: float) -> String:
	var n := int(roundf(absf(v)))
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < -0.5 else "") + s + out


static func _signed_money(v: float) -> String:
	return ("+CR " if v >= 0.0 else "saves CR ") + _money(absf(v))
