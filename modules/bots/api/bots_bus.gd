class_name BotsBus
extends Node
## The bots module's bus (Modules.bus("bots")): master plan Wave 6. Bigger ships are built in
## the berth by the company's bots, and they are worth watching:
##   6.1 first bots: two yardhands fetch parts and fix jobs, working from the build plan;
##   6.2 priorities: rule cards on the bot board (section first, rush, hold, leave for the crew,
##       which bot helps which, when to inspect, when to charge);
##   6.3 specialists: welder, riveter, plater, wirer, pipe fitter, hauler, inspector, refurbisher,
##       and two multi-taskers (frame tech, fit-out tech), bought at the board's shop (BotTypes);
##   6.4 looks: every type its own body, tools, movement and sound; named and painted;
##   6.5 upkeep: bots use charge and wear, dock at the bot bay to charge, are serviced there, cost
##       a little a day, and can be raised a mark or taught a trade;
##   6.6 watching: bot cameras and a time-lapse of the build on the TVs, and the board showing who
##       is doing what and what is stuck;
##   6.7 working alongside: take any job off a bot (or float a free one in yourself) and do it by hand.
##
##   var bots := Modules.bus("bots") as BotsBus
##   bots.crew.bots              # [{id, type, name, paint, mark, charge, wear, pos, task, line...}]
##   bots.buy("welder")          # through the host; the company pays
##   bots.set_cards(cards)       # the rule deck (BotRules)
##   bots.take_over(job)         # the crew does this job by hand; hand_back(job) gives it back
##   bots.crew_changed.connect(...)
##
## The host decides everything; guests get the crew's state (STATE_EVENT) and fly the bots on
## between. Flags: "bots" (the module), "bots.board" (the board on the walls and wrist),
## "bots.cams" (bot cameras and the time-lapse on the walls).

signal crew_changed
signal said(line: String)

const FLAG := "bots"
const BOARD_FLAG := "bots.board"
const CAMS_FLAG := "bots.cams"
## The crew are TartanCo's androids (their look and trades, YardBus.worker_look), not BSX's own
## flying bots (beenster, 20 Nov). Off, the flying bots come back.
const TARTANCO_FLAG := "bots.tartanco"
const SAVE_SECTION := "bots"
const SAVE_VERSION := 1
const STATE_EVENT := "bots.state"
const ASK_EVENT := "bots.ask"
const WALL_BOARD := "bots"
const WALL_CAM := "botcam"
const WALL_LAPSE := "timelapse"
const HOLO_CHANNEL := "bots.board"
const RUNNING_COST := "bots.upkeep"
## How often the host sends the crew's state while it changes (s).
const SYNC_EVERY := 0.25
## How much of a skipped stretch of game time the bots work through (s at x1; four game days).
const SKIP_MAX := 2880.0
const SKIP_STEP := 0.5

const Types := preload("res://modules/bots/api/bot_types.gd")
const Rules := preload("res://modules/bots/api/bot_rules.gd")
const Crew := preload("res://modules/bots/internal/bot_crew.gd")
const View := preload("res://modules/bots/internal/bot_view.gd")
const Board := preload("res://modules/bots/internal/bot_board.gd")
const CamView := preload("res://modules/bots/internal/bot_cam_view.gd")
const Lapse := preload("res://modules/bots/internal/timelapse_view.gd")

var crew: Object
## The board's log, newest last (a few dozen lines).
var log_lines: PackedStringArray = []
## Build contract id -> {job id (as a string): seconds into the build it was done}: the time-lapse.
var lapse: Dictionary = {}
## Build contract id -> seconds the bots have worked it (the time-lapse's clock).
var build_clock: Dictionary = {}
var view: Node3D
var _net: Object
var _build: Object
var _yard: Object
var _business: Object
var _sync_in := 0.0
var _dirty := false
var _xf_key := ""
var _xf := Transform3D.IDENTITY
var _infos: Dictionary = {}


func _init() -> void:
	crew = Crew.new()
	crew.call("setup", self, 7)
	crew.cards = Rules.defaults()
	for t: String in Types.STARTERS:
		crew.call("add", t)
	crew.connect("changed", func() -> void: _dirty = true)
	crew.connect("said", _on_said)


func register_module() -> void:
	Saves.register_section(SAVE_SECTION, self)
	if Flags.is_on(BOARD_FLAG):
		HudSlots.register_holo_channel(HOLO_CHANNEL, "Bot board",
				func(_glass: bool = false) -> Control: return make_board(150.0), 50)
	Menu.register_settings_section(Menu.DEBUG, "bots.debug", "Bots", _debug_panel, 36)
	if Flags.is_on(YardBus.DOCK):
		for v: String in ["bots_work", "bots_bay", "bots_close"]:
			Shots.register(v, YardBus.SCENE, _shot.bind(v), 3)
	if Modules.ready_done:
		_hook_up()
	else:
		Modules.modules_ready.connect(_hook_up, CONNECT_ONE_SHOT)


func unregister_module() -> void:
	Saves.unregister_section(SAVE_SECTION)
	HudSlots.unregister_holo_channel(HOLO_CHANNEL)
	var design := Modules.bus("design")
	if design:
		for id: String in [WALL_BOARD, WALL_CAM, WALL_LAPSE]:
			design.call("unregister_wall_view", id)
	if _business and _business.has_method("unregister_running_cost"):
		_business.call("unregister_running_cost", RUNNING_COST)


func _hook_up() -> void:
	hook_net(Modules.bus("multiplayer"))
	_build = Modules.bus("build")
	_yard = Modules.bus("yard")
	_business = Modules.bus("business")
	if _build:
		_build.connect("job_done", _on_job_done)
		_build.connect("build_changed", _on_build_changed)
	if _yard and _yard.has_signal("station_ready"):
		_yard.connect("station_ready", _on_station)
	var design := Modules.bus("design")
	if design and Flags.is_on(BOARD_FLAG):
		design.call("register_wall_view", WALL_BOARD, "BOT BOARD", make_board)
	if design and Flags.is_on(CAMS_FLAG):
		design.call("register_wall_view", WALL_CAM, "BOT CAMERA", make_cam)
		design.call("register_wall_view", WALL_LAPSE, "TIME-LAPSE", make_lapse)
	if _business and _business.has_method("register_running_cost"):
		_business.call("register_running_cost", RUNNING_COST, "Bot upkeep", upkeep_per_day)
	if _business and _business.has_signal("day_closed"):
		_business.connect("day_closed", _on_day_closed)
	var time := Modules.bus("time")
	if time and time.has_signal("skipped"):
		time.connect("skipped", _on_skipped)


func hook_net(net: Object) -> void:
	_net = net
	if _net == null:
		return
	_net.call("register_event", STATE_EVENT, _apply_state, _validate_state)
	_net.call("register_event", ASK_EVENT, _apply_ask, _validate_ask)
	_net.call("register_snapshot_provider", SAVE_SECTION, self)


var _seen_cid := ""
var _seen_active := false


## The berth's build changed (or a new one came in, or she was towed out, or was given back to
## the crew to build by hand): the bots let go of what they had of the old one.
func _on_build_changed() -> void:
	_infos.clear()
	var cid := str(_build.get("current")) if _build else ""
	var on := active()
	if cid != _seen_cid or (_seen_active and not on):
		crew.call("release_all")
	_seen_cid = cid
	_seen_active = on


func is_host() -> bool:
	return _net == null or not bool(_net.call("is_online")) or bool(_net.call("is_host"))


# --- The day -----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var dt := delta * pace()
	if dt <= 0.0:
		return
	var host := is_host()
	crew.call("step", dt * perk(), host)
	if host and active():
		var cid := str(_build.get("current"))
		build_clock[cid] = float(build_clock.get(cid, 0.0)) + dt
	if host and _net and bool(_net.call("is_online")):
		_sync_in -= delta
		if _dirty and _sync_in <= 0.0:
			_sync_in = SYNC_EVERY
			_dirty = false
			_net.call("host_emit", STATE_EVENT, {"crew": crew.call("to_snapshot"), "cards": (crew.cards as Array).duplicate(true)})
	if _dirty and not (_net and bool(_net.call("is_online"))):
		_dirty = false
		crew_changed.emit()


## The company's word on how fast the bots work (a foreman on shift: the company module), 1 without it.
func perk() -> float:
	var company := Modules.bus("company")
	return float(company.call("perk", "bots")) if company and company.has_method("perk") else 1.0


## Launch day: the bots line up along the build berth's face to see her off for `seconds`.
func line_up(seconds := 40.0) -> void:
	if not is_host():
		return
	var box: AABB = YardLayout.berths(int(_yard.call("berth_tier")) if _yard and _yard.has_method("berth_tier") else 1)[0].box
	var points: Array = []
	var n: int = crew.bots.size()
	for i in n:
		var u := (float(i) + 0.5) / maxf(1.0, float(n))
		points.append(Vector3(lerpf(box.position.x + 4.0, box.end.x - 4.0, u), box.end.y + 3.0, box.end.z + 6.0))
	crew.call("line_up", points, seconds)
	_dirty = true


## The yard's pace (Game time's: 0 paused, 0.5 to 4), 1 without it.
func pace() -> float:
	if _business and _business.has_method("time_rate"):
		return float(_business.call("time_rate"))
	var time := Modules.bus("time")
	if time and time.get("rate") != null:
		return maxf(0.0, float(time.get("rate")))
	return 1.0


## Game time skipped ahead: the bots work through it (up to SKIP_MAX seconds of it).
func _on_skipped(from_minute: int, to_minute: int) -> void:
	if not is_host():
		return
	var mps := 2.0
	var time := Modules.bus("time")
	if time and time.has_method("minutes_per_second"):
		mps = float(time.call("minutes_per_second"))
	fast_forward(minf(SKIP_MAX, float(to_minute - from_minute) / maxf(0.1, mps)))


## Host: runs the crew on `seconds` at once (a skip, the Debug tab, tests).
func fast_forward(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var dt := minf(SKIP_STEP, left)
		crew.call("step", dt, true)
		if active():
			var cid := str(_build.get("current"))
			build_clock[cid] = float(build_clock.get(cid, 0.0)) + dt
		left -= dt
	_dirty = true


func _validate_state(sender: int, p: Dictionary) -> Variant:
	return p if sender == 1 or _net == null else "only the host"


func _apply_state(p: Dictionary) -> void:
	if is_host():
		return
	crew.call("from_snapshot", p.get("crew", {}))
	if p.has("cards"):
		crew.cards = (p.cards as Array).duplicate(true)
	crew_changed.emit()


# --- What the players ask ----------------------------------------------------------------------

## Buys a bot of `type_id` (the company pays its price).
func buy(type_id: String) -> void:
	_ask({"what": "buy", "type": type_id})


## Sells bot `id` back (half its price).
func sell(id: int) -> void:
	_ask({"what": "sell", "id": id})


func rename(id: int, bot_name: String) -> void:
	_ask({"what": "rename", "id": id, "name": bot_name.strip_edges().left(18)})


func repaint(id: int, paint: String) -> void:
	_ask({"what": "paint", "id": id, "paint": paint})


## Raises bot `id` a mark (the company pays).
func upgrade(id: int) -> void:
	_ask({"what": "mark", "id": id})


## Teaches bot `id` a trade module (BotTypes.MODULES; the company pays).
func teach(id: int, module_id: String) -> void:
	_ask({"what": "teach", "id": id, "module": module_id})


## Sends bot `id` for a service now (the company pays).
func service(id: int) -> void:
	_ask({"what": "service", "id": id})


## The rule deck, whole (BotRules cards).
func set_cards(cards: Array) -> void:
	_ask({"what": "cards", "cards": cards})


## Puts the bots on the build in the berth, whatever her size (0.5.3 playtest: a small ship's
## build was the crew's alone). The bots pick up where the crew left off.
func put_on_build() -> void:
	if _build and str(_build.get("current")) != "":
		_build.call("set_crew", BuildBus.CREW_BOTS)


## Gives the build in the berth back to the crew to build by hand (the bots stand down).
func stand_down() -> void:
	if _build and str(_build.get("current")) != "":
		_build.call("set_crew", BuildBus.CREW_HAND)


## The crew takes job `job` of the build in the berth off whichever bot has it (6.7): the
## bot lets it go and the job is the crew's to float in and fix by hand.
func take_over(job: int) -> void:
	_ask({"what": "take", "job": job})


## Gives job `job` back to the bots.
func hand_back(job: int) -> void:
	_ask({"what": "give", "job": job})


func _ask(p: Dictionary) -> void:
	if _net:
		_net.call("request", ASK_EVENT, p)
		return
	var ok: Variant = _validate_ask(1, p)
	if ok is Dictionary:
		_apply_ask(ok)
	elif ok is String:
		_on_said(str(ok))


func _validate_ask(_sender: int, p: Dictionary) -> Variant:
	var what := str(p.get("what", ""))
	var b: Dictionary = crew.call("bot", int(p.get("id", -1)))
	match what:
		"buy":
			if not Types.TYPES.has(str(p.get("type", ""))):
				return "no such bot"
			var company := Modules.bus("company")
			if company and company.has_method("bot_cap") and crew.bots.size() >= int(company.call("bot_cap")):
				return "the yard can keep %d bots at its rank: grow the company for more" % int(company.call("bot_cap"))
			if company and company.has_method("bot_unlock") and str(company.call("bot_unlock", str(p.type))) != "":
				return str(company.call("bot_unlock", str(p.type)))
			var price := int(Types.info(str(p.type)).price)
			if not _pay(price, "Bot bought: %s" % Types.info(str(p.type)).name):
				return "the company cannot afford a %s" % Types.info(str(p.type)).name
		"sell":
			if b.is_empty():
				return "no such bot"
			_earn(int(Types.info(str(b.type)).price) / 2, "Bot sold: %s" % b.name)
		"rename", "paint", "service":
			if b.is_empty():
				return "no such bot"
			if what == "paint" and not Types.PAINTS.has(str(p.get("paint", ""))):
				return "no such paint"
			if what == "service" and not _pay(service_cost(b), "Bot service: %s" % b.name):
				return "the company cannot afford the service"
		"mark":
			if b.is_empty() or int(b.mark) >= Types.MAX_MARK:
				return "already at the top mark"
			if not _pay(Types.mark_cost(b), "Bot upgrade: %s to Mk%d" % [b.name, int(b.mark) + 1]):
				return "the company cannot afford the upgrade"
		"teach":
			var m := str(p.get("module", ""))
			if b.is_empty() or not Types.MODULES.has(m) or (b.modules as Array).has(m):
				return "cannot teach that"
			if (b.modules as Array).size() >= Types.module_slots(b):
				return "%s has no free slot: raise it a mark first" % b.name
			if not _pay(int(Types.MODULES[m].price), "Bot module: %s for %s" % [Types.MODULES[m].name, b.name]):
				return "the company cannot afford it"
		"cards":
			if not (p.get("cards") is Array):
				return "no cards"
		"take", "give":
			if not active():
				return "no bot build in the berth"
		_:
			return "unknown ask"
	return p


func _apply_ask(p: Dictionary) -> void:
	var b: Dictionary = crew.call("bot", int(p.get("id", -1)))
	match str(p.what):
		"buy":
			var nb: Dictionary = crew.call("add", str(p.type))
			_on_said("%s the %s joins the crew" % [nb.name, Types.info(str(p.type)).name.to_lower()])
		"sell":
			_on_said("%s is sold" % b.name)
			crew.call("remove", int(p.id))
		"rename":
			if str(p.name) != "":
				b.name = str(p.name)
		"paint":
			b.paint = str(p.paint)
		"mark":
			b.mark = int(b.mark) + 1
			_on_said("%s is now a Mk%d" % [b.name, int(b.mark)])
		"teach":
			(b.modules as Array).append(str(p.module))
		"service":
			if is_host():
				crew.call("_set_task", b, {"kind": "service"})
		"cards":
			crew.cards = (p.cards as Array).duplicate(true)
		"take":
			if is_host():
				crew.call("release_job", int(p.job))
				_build.call("claim", int(p.job), BuildBus.CREW_CLAIM)
		"give":
			if is_host() and str(_build.call("claimed_by", int(p.job), "")) == BuildBus.CREW_CLAIM:
				_build.call("claim", int(p.job), "")
	_dirty = true
	crew_changed.emit()


func _pay(amount: int, what: String) -> bool:
	if amount <= 0 or _business == null or not _business.has_method("charge"):
		return true
	if _business.has_method("can_afford") and not bool(_business.call("can_afford", amount)):
		return false
	var r: Object = _business.call("charge", amount, "bots", what)
	return r == null or not r.has_method("is_ok") or bool(r.call("is_ok"))


func _earn(amount: int, what: String) -> void:
	if _business and _business.has_method("credit") and amount > 0:
		_business.call("credit", amount, "bots", what)


## What the crew costs a day to keep (the business's running costs).
func upkeep_per_day() -> int:
	var n := 0
	for b: Dictionary in crew.bots:
		n += int(Types.info(str(b.type)).upkeep)
	return n


## Host: each day's upkeep is paid at midnight (charge, parts, the bay).
func _on_day_closed(_day: int) -> void:
	if is_host() and upkeep_per_day() > 0 and _business and _business.has_method("charge"):
		_business.call("charge", mini(upkeep_per_day(), int(_business.call("get_cash"))), "bots", "Bot upkeep")


func service_cost(b: Dictionary) -> int:
	return roundi(float(Types.info(str(b.type)).price) * 0.04)


## The crew's service at the bay (charged by the business, as upkeep).
func serviced(b: Dictionary) -> void:
	_pay(service_cost(b), "Bot service: %s" % b.name)


func _on_said(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 40:
		log_lines = log_lines.slice(log_lines.size() - 40)
	said.emit(line)


func _on_job_done(cid: String, job: int) -> void:
	if not lapse.has(cid):
		lapse[cid] = {}
	(lapse[cid] as Dictionary)[str(job)] = snappedf(float(build_clock.get(cid, 0.0)), 0.1)


# --- The build in the berth, as the crew sees it (its `site`) ----------------------------------

## True while the berth holds a build for the bots.
func active() -> bool:
	return _build != null and str(_build.get("current")) != "" and str(_build.call("crew_of", "")) == BuildBus.CREW_BOTS


func _cid() -> String:
	return str(_build.get("current")) if _build else ""


func free_jobs() -> Array:
	if not active():
		return []
	var out: Array = []
	var left := Rules.left_for_crew(crew.cards)
	var pl: BuildPlan = _build.call("plan", "")
	for j: int in _build.call("free_jobs", ""):
		if not left.has(str(pl.jobs[j].stage)):
			out.append(j)
	return out


## Jobs floated in, not finished, that nobody holds (handed back, or a flat bot's): a bot picks
## them up where they are.
func orphans() -> Array:
	if not active():
		return []
	var out: Array = []
	var left := Rules.left_for_crew(crew.cards)
	var pl: BuildPlan = _build.call("plan", "")
	for j: int in _build.call("jobs_in_hand", ""):
		if str(_build.call("claimed_by", j, "")) == "" and not left.has(str(pl.jobs[j].stage)):
			out.append(j)
	return out


## Why the build in the berth waits for its parts ("" when it doesn't): the orders module's word.
func parts_wait() -> String:
	if not active():
		return ""
	return str((_build.call("progress", "") as Dictionary).get("parts_wait", ""))


## Jobs floated in and not finished, crew's ones left out: a bot with nothing to do lends a hand
## with their fastenings.
func in_hand() -> Array:
	if not active():
		return []
	var out: Array = []
	for j: int in _build.call("jobs_in_hand", ""):
		if str(_build.call("claimed_by", j, "")) != BuildBus.CREW_CLAIM:
			out.append(j)
	return out


## Ship space (the build's blueprint) to station space.
func ship_to_station() -> Transform3D:
	var tier := int(_yard.call("berth_tier")) if _yard and _yard.has_method("berth_tier") else 1
	var cid := _cid()
	var key := "%s/%d" % [cid, tier]
	if key == _xf_key:
		return _xf
	var bp: Object = _build.call("blueprint", "") if _build else null
	var centre := (bp.get("bounds") as AABB).get_center() if bp else Vector3.ZERO
	var box: AABB = YardLayout.berths(tier)[0].box
	_xf = Transform3D(Basis(Vector3.UP, PI * 0.5), box.get_center()) * Transform3D(Basis.IDENTITY, -centre)
	_xf_key = key
	return _xf


## Job `j` of the build in the berth: {stage, name, at (station space, where its bot works it
## from), centre, order, keys}.
func job_info(j: int) -> Dictionary:
	if _infos.has(j):
		return _infos[j]
	var pl: BuildPlan = _build.call("plan", "") if _build else null
	if pl == null or j < 0 or j >= pl.jobs.size():
		return {"stage": "frame", "name": "", "at": Vector3.ZERO, "order": j, "keys": 0}
	var bp: Object = _build.call("blueprint", "")
	var job: Dictionary = pl.jobs[j]
	var box := AABB()
	var first := true
	for id: int in job.parts:
		var b: AABB = bp.call("box_of", id)
		box = b if first else box.merge(b)
		first = false
	var xf := ship_to_station()
	var bounds: AABB = bp.get("bounds")
	# Work it from just outside the ship's side nearest it, level with its middle.
	var c := box.get_center()
	var out := Vector3(signf(c.x - bounds.get_center().x), 0.0, 0.0)
	if out == Vector3.ZERO:
		out = Vector3.RIGHT
	var stand := Vector3(c.x, c.y, c.z)
	if str(job.stage) in ["frame", "plates"]:
		stand = c + out * (box.size.x * 0.5 + 1.2)
	else:
		stand = c + Vector3(0, box.size.y * 0.5 + 0.8, 0)
	var info := {"stage": str(job.stage), "name": str(job.name), "at": xf * stand, "centre": xf * c,
			"order": j, "keys": (job.key as Array).size(), "box": box}
	_infos[j] = info
	return info


## The hand fastenings of job `j`: [{k, kind (BuildPlan.hand_kind), at, normal (station space)}].
func fastenings(j: int) -> Array:
	var pl: BuildPlan = _build.call("plan", "") if _build else null
	if pl == null or j < 0 or j >= pl.jobs.size():
		return []
	var model: PartModel = (_build.call("blueprint", "") as Object).get("model")
	var xf := ship_to_station()
	var out := []
	var keys: Array = pl.jobs[j].key
	for k in keys.size():
		var c: ConnectionData = model.connections[int(keys[k])]
		var n := (xf.basis * c.local_normal).normalized()
		if n.length() < 0.5:
			n = Vector3.UP
		out.append({"k": k, "kind": BuildPlan.hand_kind(c.kind), "at": xf * c.local_position, "normal": n})
	return out


func job_landed(j: int) -> bool:
	return active() and ((_build.call("active") as Dictionary).get("landed", []) as Array).has(j)


func job_done(j: int) -> bool:
	return active() and bool(_build.call("job_finished", j, ""))


func fastened(j: int, k: int) -> float:
	return float(_build.call("fastening_quality", j, k, "")) if active() else -1.0


func claimed_by(j: int) -> String:
	return str(_build.call("claimed_by", j, "")) if active() else ""


func can_land(j: int, who: String) -> bool:
	return active() and bool(_build.call("can_land", j, "")) and claimed_by(j) in ["", who]


func claim(j: int, who: String) -> void:
	if active():
		_build.call("claim", j, who, "")


func land(j: int, who: String) -> void:
	if active():
		_build.call("land", j, who, "")


func fasten(j: int, k: int, q: float) -> void:
	if active():
		_build.call("fasten", j, k, q, "")


func rework(j: int, k: int, q: float) -> void:
	if active():
		_build.call("rework", j, k, q, "")


## The poorest fastening of the build under `under` not in `skip` ("job:k"): {job, k, kind, at,
## normal}, or {}.
func poorest(under: float, skip: Dictionary) -> Dictionary:
	if not active():
		return {}
	var done: Dictionary = (_build.call("active") as Dictionary).get("done", {})
	var worst := ""
	var wq := under
	for key: String in done:
		if skip.has(key):
			continue
		var q := float(done[key])
		if q < wq and bool(_build.call("job_finished", int(key.get_slice(":", 0)), "")):
			wq = q
			worst = key
	if worst == "":
		return {}
	var j := int(worst.get_slice(":", 0))
	var k := int(worst.get_slice(":", 1))
	for s: Dictionary in fastenings(j):
		if int(s.k) == k:
			return {"job": j, "k": k, "kind": int(s.kind), "at": s.at, "normal": s.normal}
	return {}


## The bot bay: a slot for each bot (station space), in the gap between the build berth and the
## holding berth to its -X side, facing the berth.
func bay_slot(i: int) -> Vector3:
	return bay_origin() + Vector3(float(i % 4) * 3.0 - 4.5, -float(i / 4) * 3.2, 0.0)


func bay_origin() -> Vector3:
	var tier := int(_yard.call("berth_tier")) if _yard and _yard.has_method("berth_tier") else 1
	var box: AABB = YardLayout.berths(tier)[0].box
	return Vector3(box.position.x - YardLayout.HOLDING_GAP * 0.5, YardLayout.BERTH_MIDDLE_Y + 4.0, YardLayout.BERTH_FACE_Z - 4.0)


## Where an idle bot hovers: in front of its bay slot.
func idle_point(i: int) -> Vector3:
	return bay_slot(i) + Vector3(0, 0, -2.2)


## Where a bot loads parts: off the stores hall's open face, spread along it.
func stores_point(i: int) -> Vector3:
	return Vector3(22.0 + float(i % 8) * 7.0, YardLayout.BERTH_MIDDLE_Y + 1.0, YardLayout.HULL_BOX.position.z - 2.5)


## Where a refurbisher goes: the stores' goods-in end, the way into the refurb annex.
func refurb_point(_i: int) -> Vector3:
	return Vector3(80.0, 1.0, YardLayout.HULL_BOX.position.z - 1.5)


func has_refurb() -> bool:
	return Modules.bus("refurb") != null


# --- The station -----------------------------------------------------------------------------

func _on_station(station: Node3D) -> void:
	_xf_key = ""
	if view and is_instance_valid(view):
		view.queue_free()
	view = View.new()
	view.name = "Bots"
	station.add_child(view)
	view.call("setup", self)


## The bot board (wall view and wrist channel).
func make_board(px_per_m: float) -> Control:
	var b: Control = Board.new()
	b.call("setup", self, px_per_m)
	return b


func make_cam(px_per_m: float) -> Control:
	var c: Control = CamView.new()
	c.call("setup", self, px_per_m)
	return c


func make_lapse(px_per_m: float) -> Control:
	var c: Control = Lapse.new()
	c.call("setup", self, px_per_m)
	return c


# --- Saving and joining ------------------------------------------------------------------------

func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	return {"roster": crew.call("roster"), "cards": (crew.cards as Array).duplicate(true), "next_id": crew.next_id,
			"lapse": lapse.duplicate(true), "clock": build_clock.duplicate(), "totals": (crew.totals as Dictionary).duplicate()}


func load_data(data: Dictionary, _from_version: int) -> void:
	crew.call("load_roster", data.get("roster", []))
	crew.next_id = maxi(int(crew.next_id), int(data.get("next_id", 1)))
	crew.cards = (data.get("cards", Rules.defaults()) as Array).duplicate(true)
	lapse = (data.get("lapse", {}) as Dictionary).duplicate(true)
	build_clock = (data.get("clock", {}) as Dictionary).duplicate()
	crew.totals = (data.get("totals", crew.totals) as Dictionary).duplicate()
	crew_changed.emit()


func reset_data() -> void:
	var fresh := Crew.new()
	crew.bots.clear()
	crew.next_id = 1
	for t: String in Types.STARTERS:
		crew.call("add", t)
	crew.cards = Rules.defaults()
	crew.totals = fresh.totals.duplicate()
	lapse.clear()
	build_clock.clear()
	crew_changed.emit()


func get_net_snapshot() -> Dictionary:
	var s := save_data()
	s["crew"] = crew.call("to_snapshot")
	return s


func apply_net_snapshot(data: Dictionary) -> void:
	load_data(data, SAVE_VERSION)
	if data.has("crew"):
		crew.call("from_snapshot", data.crew)


# --- Debug and screenshots -----------------------------------------------------------------------

func _debug_panel() -> Control:
	var box := VBoxContainer.new()
	for row: Array in [["Bots: build the sample freighter", func() -> void: _build.call("start_sample_bots")],
			["Buy one of every bot", func() -> void:
				for t: String in Types.ORDER:
					if t != "yardhand":
						buy(t)],
			["Work through ten minutes", func() -> void: fast_forward(600.0)],
			["Work through an hour", func() -> void: fast_forward(3600.0)]]:
		var b := Button.new()
		b.text = row[0]
		b.pressed.connect(row[1])
		box.add_child(b)
	return box


func _shot(scene: Node, which: String) -> void:
	await scene.get_tree().process_frame
	if _build and str(_build.get("current")) == "":
		_build.call("start_sample_bots")
	for t: String in Types.ORDER:
		if t != "yardhand" and t != "refurbisher":
			_apply_ask({"what": "buy", "type": t})
	for i in 2:
		await scene.get_tree().process_frame
	fast_forward(240.0 if which != "bots_bay" else 30.0)
	for i in 6:
		await scene.get_tree().physics_frame
	var berth: Node = _build.get("berth") if _build else null
	if berth and berth.has_method("settle"):
		berth.call("settle")
	if view:
		view.call("snap")
	var cam := Camera3D.new()
	cam.name = "BotsShot"
	cam.fov = 55.0
	scene.add_child(cam)
	match which:
		"bots_bay":
			var o := bay_origin()
			cam.position = o + Vector3(9, 3, -16)
			cam.look_at(o + Vector3(0, -2, 0))
		"bots_close":
			var target := Vector3.ZERO
			for b: Dictionary in crew.bots:
				if str(b.task.kind) == "job" and str(b.task.get("phase", "")) == "fasten":
					target = b.pos
					break
			if target == Vector3.ZERO and not crew.bots.is_empty():
				target = crew.bots[0].pos
			cam.position = target + Vector3(3.5, 1.6, -3.5)
			cam.look_at(target)
		_:
			var c := ship_to_station() * Vector3.ZERO
			cam.position = c + Vector3(26, 14, -34)
			cam.look_at(c)
	cam.current = true
