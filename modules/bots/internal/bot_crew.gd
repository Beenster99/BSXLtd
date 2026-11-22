extends RefCounted
## The bot crew's working day as data (master plan 6.1 to 6.3, 6.5, 6.7): who is doing what,
## where each bot is, its charge and wear. The host steps it (step); every other machine gets the
## host's state now and then (to_snapshot) and steps it on between, for looks only (step with
## authority off: bots fly on to where they were going, nothing is decided).
##
## The crew works the build in the berth through `site` (the bus): it picks free jobs by the
## rule cards, claims them, flies to the stores for the parts (or has a hauler fetch them), floats
## the job in, flies to each fastening and makes it, and lets the job go when it is done. Pairs
## work together: the helper makes fastenings on its lead's job. Inspectors go over finished work
## and make poor fastenings again. A bot low on charge flies to the bot bay; a worn one is
## serviced there.
##
## Positions are station space (m). Times are seconds at the yard's normal pace.

signal changed
## A line for the board's log ("F-3 01 floated in Frame ring 3").
signal said(line: String)
## A bot finished a job / a fastening / a rework (for the stats and the sounds).
signal worked(bot_id: int, what: String, job: int)

const Types := preload("res://modules/bots/api/bot_types.gd")

## Charge used a second while idle or flying (working uses the type's drain).
const IDLE_DRAIN := 0.00012
## Charge gained a second docked at the bay.
const CHARGE_RATE := 1.0 / 90.0
## Wear gained a second of work, and the wear at which a bot goes for a service.
const WEAR_RATE := 0.00006
const SERVICE_AT := 0.6
## Bots lending a hand on one job at most, besides the one fitting it.
const LEND_MAX := 2
const SERVICE_SECONDS := 25.0
## How often idle bots look for work (s).
const ASSIGN_EVERY := 0.5
## How close counts as there (m).
const ARRIVE := 0.25
## How far from a fastening a bot works (m, along its face).
const WORK_STANDOFF := 0.9

var bots: Array[Dictionary] = []
var cards: Array = []
var site: Object
var rng := RandomNumberGenerator.new()
## Jobs whose parts are at the berth for their bot (hauled), and the hauls wanted: job -> bot id.
var delivered: Dictionary = {}
var hauls: Dictionary = {}
## "job:k" -> the bot making it (pairs share a job), "job:k" -> the inspector checking it.
var busy: Dictionary = {}
var checked: Dictionary = {}
## Why work is waiting: [{what, why}] (the board's STUCK list), worked out each assign.
var stuck: Array[Dictionary] = []
## Totals: jobs, fastenings, reworks, seconds worked.
var totals := {"jobs": 0, "fastenings": 0, "reworks": 0, "worked": 0.0}
var next_id := 1
var _assign_in := 0.0
var _dirty := false


func setup(on_site: Object, seed_value := 1) -> void:
	site = on_site
	rng.seed = seed_value


# --- The roster --------------------------------------------------------------------------------

## A new bot of `type_id` (named from the list in turn), docked at the bay.
func add(type_id: String, bot_name := "", paint := "") -> Dictionary:
	var t := Types.info(type_id)
	var id := next_id
	next_id += 1
	var b := {"id": id, "type": type_id if Types.TYPES.has(type_id) else "yardhand",
			"name": bot_name if bot_name != "" else Types.default_name(type_id, id),
			"paint": paint if paint != "" else str(t.paint), "mark": 1, "modules": [],
			"charge": 1.0, "wear": 0.0, "pos": _bay(bots.size()), "task": {"kind": "idle"},
			"jobs": 0, "fastenings": 0, "worked": 0.0, "line": "Docked"}
	bots.append(b)
	_dirty = true
	return b


func bot(id: int) -> Dictionary:
	for b in bots:
		if int(b.id) == id:
			return b
	return {}


func remove(id: int) -> void:
	var b := bot(id)
	if b.is_empty():
		return
	_drop(b)
	bots.erase(b)
	_dirty = true


func name_of(id: int) -> String:
	var b := bot(id)
	return str(b.get("name", "bot %d" % id))


# --- Stepping ----------------------------------------------------------------------------------

## Moves the day on `dt` seconds (already scaled by the yard's pace). `authority`: the host,
## which decides; elsewhere bots only fly on.
func step(dt: float, authority := true) -> void:
	if dt <= 0.0:
		return
	for b in bots:
		_step(b, dt, authority)
	if authority:
		_assign_in -= dt
		if _assign_in <= 0.0:
			_assign_in = ASSIGN_EVERY
			_assign()
	if _dirty:
		_dirty = false
		changed.emit()


func _step(b: Dictionary, dt: float, authority: bool) -> void:
	var task: Dictionary = b.task
	task.t = float(task.get("t", 0.0)) + dt
	var working := false
	match str(task.kind):
		"idle":
			_fly(b, site.call("idle_point", _index(b)), dt)
			b.line = "Standing by"
		"charge":
			if _fly(b, _bay(_index(b)), dt):
				b.charge = minf(1.0, float(b.charge) + CHARGE_RATE * dt)
				b.line = "Charging %d%%" % roundi(float(b.charge) * 100.0)
				if authority and float(b.charge) >= 0.999:
					_set_task(b, {"kind": "idle"})
			else:
				b.line = "Going to charge"
		"service":
			if _fly(b, _bay(_index(b)), dt):
				b.line = "Being serviced"
				b.charge = minf(1.0, float(b.charge) + CHARGE_RATE * dt)
				if authority and float(task.t) >= SERVICE_SECONDS:
					b.wear = 0.0
					site.call("serviced", b)
					_say("%s is serviced and back to work" % b.name)
					_set_task(b, {"kind": "idle"})
			else:
				b.line = "Going for a service"
		"job":
			working = _step_job(b, task, dt, authority)
		"haul":
			_step_haul(b, task, dt, authority)
		"help":
			working = _step_help(b, task, dt, authority)
		"inspect":
			working = _step_inspect(b, task, dt, authority)
		"refurb":
			_fly(b, site.call("refurb_point", _index(b)), dt)
			working = true
			b.line = "Refurbishing in the annex"
		"line":
			# Launch day: lined up along the berth to see her off.
			_fly(b, task.get("at", b.pos), dt)
			b.line = "Seeing her off"
			if authority and float(task.t) >= float(task.get("for", 30.0)):
				_set_task(b, {"kind": "idle"})
	var drain := float(Types.info(str(b.type)).drain) if working else IDLE_DRAIN
	if str(task.kind) != "charge" and str(task.kind) != "service":
		b.charge = maxf(0.0, float(b.charge) - drain * dt)
	if working:
		b.wear = minf(1.0, float(b.wear) + WEAR_RATE * dt)
		b.worked = float(b.worked) + dt
		totals.worked = float(totals.worked) + dt


## A job of its own: to the stores (or straight to the berth when a hauler fetches), float the
## job in, then each fastening. True while working (not flying).
func _step_job(b: Dictionary, task: Dictionary, dt: float, authority: bool) -> bool:
	var j := int(task.job)
	var info: Dictionary = site.call("job_info", j)
	if authority and _lost(b, j):
		_say("%s leaves %s to the crew" % [b.name, info.get("name", "a job")])
		_drop(b)
		_set_task(b, {"kind": "idle"})
		return false
	match str(task.phase):
		"to_stores":
			b.line = "Fetching parts for %s" % info.get("name", "")
			if _fly(b, site.call("stores_point", _index(b)), dt):
				_phase(b, "load")
		"load":
			b.line = "Loading parts for %s" % info.get("name", "")
			if float(task.t) >= Types.LOAD_SECONDS / maxf(0.5, Types.level(b, "haul")):
				_phase(b, "to_site")
				task.carrying = true
		"to_site":
			b.line = "Taking %s to the berth" % info.get("name", "") if bool(task.get("carrying", false)) else "Going to %s" % info.get("name", "")
			if _fly(b, info.get("at", b.pos), dt):
				_phase(b, "fit" if bool(task.get("carrying", false)) or delivered.has(j) else "wait_parts")
		"wait_parts":
			b.line = "Waiting for the parts for %s" % info.get("name", "")
			if delivered.has(j):
				task.carrying = true
				_phase(b, "fit")
			elif authority and not hauls.has(j):
				# Nobody is bringing them: fetch them itself.
				_phase(b, "to_stores")
		"fit":
			b.line = "Floating in %s" % info.get("name", "")
			var lv := maxf(0.25, Types.level(b, "fit:" + str(info.stage)))
			if float(task.t) >= Types.FIT_SECONDS / (lv * Types.pace(b)):
				if bool(site.call("job_landed", j)):
					task.carrying = false
					delivered.erase(j)
					_phase(b, "next_k")
				elif authority and not bool(task.get("asked", false)):
					task.asked = true
					site.call("land", j, "bot:%d" % int(b.id))
				elif authority and float(task.t) > Types.FIT_SECONDS * 8.0 and not bool(site.call("can_land", j, "bot:%d" % int(b.id))):
					_drop(b)
					_set_task(b, {"kind": "idle"})
			return true
		"next_k", "to_k", "fasten":
			return _step_fastening(b, task, j, dt, authority, true)
	return false


## Picks, flies to and makes the next fastening of job `j` (its own, or its lead's when helping).
## True while working.
func _step_fastening(b: Dictionary, task: Dictionary, j: int, dt: float, authority: bool, own: bool) -> bool:
	var info: Dictionary = site.call("job_info", j)
	match str(task.phase):
		"next_k":
			if not authority:
				return false
			var spots: Array = site.call("fastenings", j)
			var pick := {}
			for s: Dictionary in spots:
				var key := "%d:%d" % [j, int(s.k)]
				if float(site.call("fastened", j, int(s.k))) >= 0.0 or busy.has(key):
					continue
				# A helper takes only what it can make; the lead takes what is left.
				if not own and Types.level(b, Types.kind_skill(int(s.kind))) <= 0.0:
					continue
				if pick.is_empty() or (Types.level(b, Types.kind_skill(int(s.kind))) > Types.level(b, Types.kind_skill(int(pick.kind)))):
					pick = s
			if pick.is_empty():
				if bool(site.call("job_done", j)) and own:
					_say("%s finished %s" % [b.name, info.get("name", "")])
					b.jobs = int(b.jobs) + 1
					totals.jobs = int(totals.jobs) + 1
					worked.emit(int(b.id), "job", j)
					_drop(b)
					_set_task(b, {"kind": "idle"})
				else:
					b.line = "Waiting on %s" % info.get("name", "")
					if not own:
						_drop(b)
						_set_task(b, {"kind": "help"})
				return false
			busy["%d:%d" % [j, int(pick.k)]] = int(b.id)
			task.k = int(pick.k)
			task.kind_of = int(pick.kind)
			task.spot = pick.at
			task.normal = pick.normal
			_phase(b, "to_k")
			_dirty = true
		"to_k":
			b.line = "Going to a %s on %s" % [Types.kind_skill(int(task.get("kind_of", 0))), info.get("name", "")]
			var at: Vector3 = task.get("spot", b.pos)
			var n: Vector3 = task.get("normal", Vector3.UP)
			if _fly(b, at + n * WORK_STANDOFF, dt):
				_phase(b, "fasten")
		"fasten":
			var skill := Types.kind_skill(int(task.get("kind_of", 0)))
			var lv := Types.level(b, skill)
			var dur := Types.FASTEN_SECONDS * (Types.UNSKILLED if lv <= 0.0 else 1.0 / lv) / Types.pace(b)
			b.line = "%s %s (%d of %d)" % [_verb(skill), info.get("name", ""), _done_count(j) + 1, int(info.get("keys", 1))]
			if authority and float(task.t) >= dur:
				var k := int(task.k)
				var q := _quality(b, lv)
				if float(site.call("fastened", j, k)) < 0.0:
					site.call("fasten", j, k, q)
				busy.erase("%d:%d" % [j, k])
				b.fastenings = int(b.fastenings) + 1
				totals.fastenings = int(totals.fastenings) + 1
				worked.emit(int(b.id), skill, j)
				_phase(b, "next_k")
			return true
	return false


## A hauler fetching job `job`'s parts for the bot fitting it.
func _step_haul(b: Dictionary, task: Dictionary, dt: float, authority: bool) -> void:
	var j := int(task.job)
	var info: Dictionary = site.call("job_info", j)
	match str(task.get("phase", "to_stores")):
		"to_stores":
			b.line = "Fetching parts for %s" % info.get("name", "")
			if _fly(b, site.call("stores_point", _index(b)), dt):
				_phase(b, "load")
		"load":
			b.line = "Loading parts for %s" % info.get("name", "")
			if float(task.t) >= Types.LOAD_SECONDS / maxf(0.5, Types.level(b, "haul")):
				task.carrying = true
				_phase(b, "to_site")
		"to_site":
			b.line = "Bringing parts for %s" % info.get("name", "")
			if _fly(b, (info.get("at", b.pos) as Vector3) + Vector3(0, 1.6, 0), dt) and authority:
				delivered[j] = true
				hauls.erase(j)
				task.carrying = false
				_say("%s brought the parts for %s" % [b.name, info.get("name", "")])
				_set_task(b, {"kind": "idle"})


## A helper paired with a lead: makes fastenings on the lead's job, or fetches its parts.
func _step_help(b: Dictionary, task: Dictionary, dt: float, authority: bool) -> bool:
	if task.has("lend"):
		# Lending a hand (nobody paired): the job's fastenings till none is left for it.
		var lj := int(task.get("job", -1))
		if not bool(site.call("job_landed", lj)) or bool(site.call("job_done", lj)) or str(site.call("claimed_by", lj)) == BuildBus.CREW_CLAIM:
			if authority:
				_drop(b)
				_set_task(b, {"kind": "idle"})
			return false
		b.line = "Lending a hand on %s" % str((site.call("job_info", lj) as Dictionary).get("name", ""))
		return _step_fastening(b, task, lj, dt, authority, false)
	var lead := bot(int(BotRules.pairs(cards).get(int(b.id), -1)))
	if lead.is_empty():
		if authority:
			_set_task(b, {"kind": "idle"})
		return false
	var lt: Dictionary = lead.task
	if str(task.get("phase", "")) in ["to_k", "fasten", "next_k"] and int(task.get("job", -1)) >= 0:
		var j := int(task.job)
		if str(lt.get("kind", "")) != "job" or int(lt.get("job", -2)) != j:
			if authority:
				_drop(b)
				_set_task(b, {"kind": "help"})
			return false
		return _step_fastening(b, task, j, dt, authority, false)
	b.line = "Helping %s" % lead.name
	var near: Vector3 = (lead.pos as Vector3) + Vector3(1.2, 0.6, 0)
	_fly(b, near, dt)
	if authority and str(lt.get("kind", "")) == "job" and bool(site.call("job_landed", int(lt.job))):
		task.job = int(lt.job)
		_phase(b, "next_k")
	return false


## An inspector going over finished work: to each poor fastening, scan it, make it again.
func _step_inspect(b: Dictionary, task: Dictionary, dt: float, authority: bool) -> bool:
	var j := int(task.job)
	var k := int(task.k)
	var info: Dictionary = site.call("job_info", j)
	match str(task.get("phase", "to_k")):
		"to_k":
			b.line = "Inspecting %s" % info.get("name", "")
			if _fly(b, (task.spot as Vector3) + (task.normal as Vector3) * (WORK_STANDOFF + 0.4), dt):
				_phase(b, "scan")
		"scan":
			b.line = "Scanning %s" % info.get("name", "")
			var lv := maxf(0.5, Types.level(b, "inspect"))
			if authority and float(task.t) >= Types.INSPECT_SECONDS / lv + Types.FASTEN_SECONDS / maxf(1.0, Types.level(b, Types.kind_skill(int(task.kind_of)))):
				var was := float(site.call("fastened", j, k))
				var q := maxf(was, _quality(b, Types.level(b, Types.kind_skill(int(task.kind_of)))))
				if q > was + 0.001:
					site.call("rework", j, k, q)
					totals.reworks = int(totals.reworks) + 1
					worked.emit(int(b.id), "rework", j)
					_say("%s made a poor %s on %s again" % [b.name, Types.kind_skill(int(task.kind_of)), info.get("name", "")])
				checked["%d:%d" % [j, k]] = true
				_set_task(b, {"kind": "idle"})
			return true
	return false


# --- Handing out work --------------------------------------------------------------------------

func _assign() -> void:
	stuck.clear()
	var low := BotRules.threshold(cards, "charge", 0.25)
	var pairs := BotRules.pairs(cards)
	var active := bool(site.call("active"))
	var idle: Array[Dictionary] = []
	for b in bots:
		var kind := str(b.task.kind)
		if kind == "idle" or kind == "refurb":
			if float(b.charge) < low:
				_say("%s is low and goes to charge" % b.name)
				_set_task(b, {"kind": "charge"})
				continue
			if float(b.wear) >= SERVICE_AT:
				_say("%s goes in for a service" % b.name)
				_set_task(b, {"kind": "service"})
				continue
			if pairs.has(int(b.id)) and active:
				_set_task(b, {"kind": "help"})
				continue
			idle.append(b)
		elif kind == "charge":
			stuck.append({"what": str(b.name), "why": "charging"})
		elif float(b.charge) <= 0.03 and kind in ["job", "help", "haul", "inspect"]:
			# Flat: it lets its work go and docks.
			_say("%s ran flat and goes to charge" % b.name)
			_drop(b)
			_set_task(b, {"kind": "charge"})
	if not active:
		for b in idle:
			if Types.level(b, "refurb") > 0.0 and str(b.task.kind) != "refurb" and bool(site.call("has_refurb")):
				_set_task(b, {"kind": "refurb"})
		return
	# Refurbishers go to the annex.
	for b in idle.duplicate():
		if Types.level(b, "refurb") > 0.0 and Types.fit_stages(b).is_empty():
			if str(b.task.kind) != "refurb" and bool(site.call("has_refurb")):
				_set_task(b, {"kind": "refurb"})
			idle.erase(b)
	# Jobs, best first, to the idle bot best at each.
	# Jobs already in that nobody has (handed back, or a flat bot's) come first: no fetching.
	for j: int in site.call("orphans"):
		if fitters_left(idle).is_empty():
			break
		var info: Dictionary = site.call("job_info", j)
		var best := _best_fitter(idle, str(info.stage))
		if best.is_empty():
			continue
		idle.erase(best)
		site.call("claim", j, "bot:%d" % int(best.id))
		_set_task(best, {"kind": "job", "job": j, "phase": "to_site", "carrying": true})
		_say("%s picks up %s" % [best.name, info.get("name", "")])
	var free: Array = site.call("free_jobs")
	var crew_stages := BotRules.left_for_crew(cards)
	var held := BotRules.held(cards)
	var ranked := BotRules.rank(free, func(j: int) -> Dictionary: return site.call("job_info", j), cards)
	var fitters := idle.filter(func(b: Dictionary) -> bool: return not Types.fit_stages(b).is_empty())
	var haulers := idle.filter(func(b: Dictionary) -> bool: return Types.fit_stages(b).is_empty() and Types.level(b, "haul") > 0.0)
	var nobody: Dictionary = {}
	for j: int in ranked:
		var info: Dictionary = site.call("job_info", j)
		var stage := str(info.stage)
		var best: Dictionary = {}
		for b: Dictionary in fitters:
			var lv := Types.level(b, "fit:" + stage)
			if lv > 0.0 and (best.is_empty() or lv > Types.level(best, "fit:" + stage)):
				best = b
		if best.is_empty():
			if not _anyone_fits(stage):
				nobody[stage] = true
			continue
		fitters.erase(best)
		site.call("claim", j, "bot:%d" % int(best.id))
		var hauler: Dictionary = haulers.pop_front() if not haulers.is_empty() else {}
		if not hauler.is_empty():
			hauls[j] = int(hauler.id)
			_set_task(hauler, {"kind": "haul", "job": j, "phase": "to_stores"})
			_set_task(best, {"kind": "job", "job": j, "phase": "to_site"})
		else:
			_set_task(best, {"kind": "job", "job": j, "phase": "to_stores"})
		_say("%s takes %s" % [best.name, info.get("name", "")])
		if fitters.is_empty():
			break
	for stage: String in nobody:
		stuck.append({"what": "%s jobs" % str(BuildPlan.STAGES[stage].name), "why": "no bot can fit them: buy one that can"})
	for s in held:
		stuck.append({"what": "%s jobs" % str(BuildPlan.STAGES[s].name), "why": "left for the crew" if crew_stages.has(s) else "held by a rule card"})
	var pw := str(site.call("parts_wait")) if site.has_method("parts_wait") else ""
	if pw != "":
		stuck.append({"what": "Parts", "why": pw})
	for b in bots:
		if str(b.task.kind) == "job" and str(b.task.get("phase", "")) == "wait_parts":
			stuck.append({"what": str(b.name), "why": "waiting for parts"})
	# Inspectors: the poorest fastening nobody has checked.
	var under := BotRules.threshold(cards, "inspect", 0.6)
	for b: Dictionary in idle:
		if str(b.task.kind) != "idle" or Types.level(b, "inspect") <= 0.0:
			continue
		var poor: Dictionary = site.call("poorest", under, checked)
		if poor.is_empty():
			continue
		checked["%d:%d" % [int(poor.job), int(poor.k)]] = true
		_set_task(b, {"kind": "inspect", "job": int(poor.job), "k": int(poor.k), "kind_of": int(poor.kind),
				"spot": poor.at, "normal": poor.normal, "phase": "to_k"})
	# Anyone still idle lends a hand: a fastening it can make on a job in hand (a welder runs
	# the welds of the ring the frame tech just floated in), a couple of helpers to a job.
	var helping: Dictionary = {}
	for b in bots:
		if str(b.task.kind) == "help" and b.task.has("lend"):
			helping[int(b.task.get("job", -1))] = int(helping.get(int(b.task.get("job", -1)), 0)) + 1
	for b: Dictionary in idle:
		if str(b.task.kind) != "idle" or Types.level(b, "weld") + Types.level(b, "rivet") + Types.level(b, "bolt") <= 0.0:
			continue
		for j: int in site.call("in_hand"):
			if int(helping.get(j, 0)) >= LEND_MAX or not _can_help(b, j):
				continue
			helping[j] = int(helping.get(j, 0)) + 1
			_set_task(b, {"kind": "help", "lend": true, "job": j, "phase": "next_k"})
			break


## Whether `b` can make one of job `j`'s fastenings nobody is on yet.
func _can_help(b: Dictionary, j: int) -> bool:
	for s: Dictionary in site.call("fastenings", j):
		if float(site.call("fastened", j, int(s.k))) >= 0.0 or busy.has("%d:%d" % [j, int(s.k)]):
			continue
		if Types.level(b, Types.kind_skill(int(s.kind))) > 0.0:
			return true
	return false


static func fitters_left(idle: Array) -> Array:
	return idle.filter(func(b: Dictionary) -> bool: return not Types.fit_stages(b).is_empty())


static func _best_fitter(idle: Array, stage: String) -> Dictionary:
	var best: Dictionary = {}
	for b: Dictionary in idle:
		var lv := Types.level(b, "fit:" + stage)
		if lv > 0.0 and (best.is_empty() or lv > Types.level(best, "fit:" + stage)):
			best = b
	return best


func _anyone_fits(stage: String) -> bool:
	for b in bots:
		if Types.level(b, "fit:" + stage) > 0.0:
			return true
	return false


## The job was taken off the bot (the crew claimed it) or is done by someone else.
func _lost(b: Dictionary, j: int) -> bool:
	var who := str(site.call("claimed_by", j))
	return (who != "" and who != "bot:%d" % int(b.id)) or (bool(site.call("job_done", j)) and str(b.task.get("phase", "")) in ["to_stores", "load", "to_site", "wait_parts"])


## Lets go of whatever bot `b` holds: its claim, its fastening in hand, its haul.
func _drop(b: Dictionary) -> void:
	var task: Dictionary = b.task
	var j := int(task.get("job", -1))
	if str(task.kind) == "job" and j >= 0:
		if str(site.call("claimed_by", j)) == "bot:%d" % int(b.id) and not bool(site.call("job_done", j)):
			site.call("claim", j, "")
		if hauls.has(j):
			var h := bot(int(hauls[j]))
			hauls.erase(j)
			if not h.is_empty() and str(h.task.kind) == "haul":
				_set_task(h, {"kind": "idle"})
	if task.has("k") and j >= 0:
		var key := "%d:%d" % [j, int(task.k)]
		if int(busy.get(key, -1)) == int(b.id):
			busy.erase(key)
	if str(task.kind) == "haul" and j >= 0:
		hauls.erase(j)


## Launch day: every bot lines up at `points` (one each, in order) for `seconds`.
func line_up(points: Array, seconds: float) -> void:
	for i in bots.size():
		if i < points.size():
			_set_task(bots[i], {"kind": "line", "at": points[i], "for": seconds})


## The build in the berth changed: everyone lets go of their work on the old one.
func release_all() -> void:
	for b in bots:
		if str(b.task.kind) in ["job", "help", "haul", "inspect"]:
			# Not _drop: her claims went with her (BuildBus._apply_move), and the job numbers
			# would be read against the new build.
			_set_task(b, {"kind": "idle"})
	busy.clear()
	hauls.clear()
	delivered.clear()
	checked.clear()
	_dirty = true


## The crew took job `j` (or it went): whoever has it lets go.
func release_job(j: int) -> void:
	for b in bots:
		if int(b.task.get("job", -1)) == j and str(b.task.kind) in ["job", "haul", "help"]:
			_drop(b)
			_set_task(b, {"kind": "idle"})


func _set_task(b: Dictionary, task: Dictionary) -> void:
	# A fastening it had in hand is free again.
	var old: Dictionary = b.get("task", {})
	if old.has("k") and int(old.get("job", -1)) >= 0:
		var key := "%d:%d" % [int(old.job), int(old.k)]
		if int(busy.get(key, -1)) == int(b.id):
			busy.erase(key)
	task.t = 0.0
	b.task = task
	_dirty = true


func _phase(b: Dictionary, phase: String) -> void:
	b.task.phase = phase
	b.task.t = 0.0
	_dirty = true


func _say(line: String) -> void:
	said.emit(line)


# --- Helpers -----------------------------------------------------------------------------------

func _index(b: Dictionary) -> int:
	return bots.find(b)


func _bay(i: int) -> Vector3:
	return site.call("bay_slot", i) if site else Vector3.ZERO


## Flies `b` towards `to` at its speed (easing in the last metres); true on arrival.
func _fly(b: Dictionary, to: Vector3, dt: float) -> bool:
	var p: Vector3 = b.pos
	var d := to - p
	var dist := d.length()
	if dist <= ARRIVE:
		b.pos = to
		return true
	var speed := float(Types.info(str(b.type)).speed) * Types.pace(b)
	var v := minf(speed, maxf(dist * 1.5, 0.6))
	b.pos = p + d / dist * minf(dist, v * dt)
	b.heading = d / dist
	return false


func _quality(b: Dictionary, lv: float) -> float:
	var q := Types.quality(b)
	if lv <= 0.0:
		q *= 0.7
	return clampf(q + rng.randf_range(-0.08, 0.08), 0.15, 1.0)


func _done_count(j: int) -> int:
	var n := 0
	for s: Dictionary in site.call("fastenings", j):
		if float(site.call("fastened", j, int(s.k))) >= 0.0:
			n += 1
	return n


static func _verb(skill: String) -> String:
	match skill:
		"weld":
			return "Welding"
		"bolt":
			return "Bolting"
	return "Riveting"


# --- Saving and sharing ------------------------------------------------------------------------

## The roster as saved: each bot without its task (a loaded crew starts docked).
func roster() -> Array:
	var out := []
	for b in bots:
		out.append({"id": b.id, "type": b.type, "name": b.name, "paint": b.paint, "mark": b.mark,
				"modules": (b.modules as Array).duplicate(), "charge": snappedf(float(b.charge), 0.001),
				"wear": snappedf(float(b.wear), 0.0001), "jobs": b.jobs, "fastenings": b.fastenings,
				"worked": snappedf(float(b.worked), 0.1)})
	return out


func load_roster(list: Array) -> void:
	bots.clear()
	busy.clear()
	hauls.clear()
	delivered.clear()
	next_id = 1
	for e: Dictionary in list:
		var b := e.duplicate(true)
		b.pos = _bay(bots.size())
		b.task = {"kind": "idle", "t": 0.0}
		b.line = "Docked"
		for k: String in ["jobs", "fastenings"]:
			b[k] = int(b.get(k, 0))
		b.worked = float(b.get("worked", 0.0))
		b.modules = b.get("modules", [])
		# A save from before 0.5.4 named its bots from the pet names: with TartanCo's androids
		# they take their trade's code and number instead (a name the players gave them stays).
		if Types.NAMES.has(str(b.get("name", ""))) and str(b.name) == Types.NAMES[(int(b.id) - 1) % Types.NAMES.size()] \
				and Flags.is_on("bots.tartanco"):
			b.name = Types.tartanco_name(str(b.type), int(b.id))
		bots.append(b)
		next_id = maxi(next_id, int(b.id) + 1)
	_dirty = true


## Everything a guest needs to draw the crew now: the bots with their tasks.
func to_snapshot() -> Dictionary:
	var list := []
	for b in bots:
		var e := b.duplicate(true)
		list.append(e)
	return {"bots": list, "next_id": next_id, "stuck": stuck.duplicate(true), "totals": totals.duplicate()}


func from_snapshot(s: Dictionary) -> void:
	bots.clear()
	for e: Dictionary in s.get("bots", []):
		bots.append(e.duplicate(true))
	next_id = int(s.get("next_id", next_id))
	stuck.assign(s.get("stuck", []))
	totals = (s.get("totals", totals) as Dictionary).duplicate()
	changed.emit()
