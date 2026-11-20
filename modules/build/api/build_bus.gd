class_name BuildBus
extends Node
## Building by hand module bus (Modules.bus("build")): master plan Wave 5. A small ship's
## signed-off design is built in the dock's build berth by the crew, with the hand tools:
##   5.1 the build plan: the design as ordered jobs, frame, plates, fittings, wiring, pipes
##       (BuildPlan);
##   5.2 the ghost ship: the berth shows the whole ship as a faint holo; the next job's pieces
##       glow, and turn solid as they are fixed;
##   5.3 fixing in zero g: press F at the glowing pieces and they float into place, chalked
##       where they are to be welded, riveted or bolted; the welder, riveter and socket do it;
##   5.4 workmanship: how well each fastening was made (a weld's bead, a rivet or bolt set
##       square) goes into the joints' strength and into the trial (a Workmanship row);
##   5.5 contract to trial: the keel and fit-out payments are paid when the frame stands and
##       when the hull is closed with the fittings in, not on the day the stand-in paid them.
##
## The build in the berth is a small ship contract ("building", size small) or, from the Debug
## tab, the sample skiff. Its state is data, the same on every machine: which jobs floated in
## and each hand fastening's quality. Every change goes through the multiplayer module's host.
##   var b := Modules.bus("build") as BuildBus
##   b.active()                     # {contract, design_name, jobs, done...} or {}
##   b.progress()                   # {stage, job, jobs_done, jobs, by_stage, workmanship...}
##   b.build_changed.connect(...)
##
## Flags: "build" (the module), "build.hand" (the hand build in the berth).

signal build_changed
## A job's last hand fastening went in (its pieces are fixed).
signal job_done(contract_id: String, job: int)
## Every job of a stage is done.
signal stage_done(contract_id: String, stage: String)

const FLAG := "build"
const HAND_FLAG := "build.hand"
const SAVE_SECTION := "build"
const SAVE_VERSION := 1
const EV_START := "build.start"
const EV_LAND := "build.land"
const EV_FASTEN := "build.fasten"
const EV_STOP := "build.stop"
## The sample build's contract id (no contract: the Debug tab's skiff).
const SAMPLE := "sample"
## Who claims the berth from the TartanCo stand-in keel (YardBus.claim_build_berth).
const CLAIM := "build"
const HOLO_CHANNEL := "build.plan"
const HOLO_LABEL := "Build plan"
## A ship the crew builds by hand: the order's size.
const HAND_SIZES: PackedStringArray = ["small"]
## The trial's workmanship row: met when the hand fastenings average this or better.
const WORKMANSHIP_NEED := 0.6

const Blueprint := preload("res://modules/build/internal/blueprint.gd")
const BerthBuild := preload("res://modules/build/internal/berth_build.gd")
const PlanScreen := preload("res://modules/build/internal/plan_screen.gd")

## contract id -> {contract, design (DesignRecord.to_dict), design_name, landed: [job ids],
## done: {"<job>:<k>": quality}, paid: [payment stage ids]}.
var builds: Dictionary = {}
## The build in the berth (its contract id), "" for none.
var current := ""
## The berth's build (internal BerthBuild) while a station is open.
var berth: Node3D
var _plans: Dictionary = {}   # contract id -> {plan: BuildPlan, blueprint}
var _net: Object
var _yard: Object
var _contracts: Object


func register_module() -> void:
	if not Flags.is_on(HAND_FLAG):
		return
	Saves.register_section(SAVE_SECTION, self)
	HudSlots.register_holo_channel(HOLO_CHANNEL, HOLO_LABEL,
			func(glass: bool = false) -> Control: return PlanScreen.new().setup(self, glass), 35)
	Menu.register_settings_section(Menu.DEBUG, "build.debug", "Building by hand", _debug_panel, 35)
	if Flags.is_on(YardBus.DOCK):
		for view: String in ["ghost", "frame", "weld", "hull"]:
			Shots.register("build_" + view, YardBus.SCENE, _shot.bind(view), 40)
	if Modules.ready_done:
		_hook_up()
	else:
		Modules.modules_ready.connect(_hook_up, CONNECT_ONE_SHOT)


func unregister_module() -> void:
	Saves.unregister_section(SAVE_SECTION)
	HudSlots.unregister_holo_channel(HOLO_CHANNEL)


func _hook_up() -> void:
	hook_net(Modules.bus("multiplayer"))
	_yard = Modules.bus("yard")
	if _yard:
		if not _yard.is_connected("station_ready", _on_station):
			_yard.connect("station_ready", _on_station)
		if not _yard.is_connected("hand_fastened", _on_hand_fastened):
			_yard.connect("hand_fastened", _on_hand_fastened)
	_contracts = Modules.bus("contracts")
	if _contracts:
		if _contracts.has_signal("ship_contract_changed") and not _contracts.is_connected("ship_contract_changed", _on_contract):
			_contracts.connect("ship_contract_changed", _on_contract)
		if _contracts.has_method("register_trial_rows"):
			_contracts.call("register_trial_rows", "build", trial_rows)


## Plays through this Multiplayer bus (tests run it alone).
func hook_net(net: Object) -> void:
	_net = net
	if _net == null:
		return
	_net.call("register_event", EV_START, _apply_start, _validate_start)
	_net.call("register_event", EV_LAND, _apply_land, _validate_land)
	_net.call("register_event", EV_FASTEN, _apply_fasten, _validate_fasten)
	_net.call("register_event", EV_STOP, _apply_stop, _validate_stop)
	_net.call("register_snapshot_provider", SAVE_SECTION, self)


func _request(ev: String, p: Dictionary) -> void:
	if _net:
		_net.call("request", ev, p)
		return
	var ok: Variant = (_validators()[ev] as Callable).call(1, p)
	if ok is Dictionary:
		(_appliers()[ev] as Callable).call(ok)


func _validators() -> Dictionary:
	return {EV_START: _validate_start, EV_LAND: _validate_land, EV_FASTEN: _validate_fasten, EV_STOP: _validate_stop}


func _appliers() -> Dictionary:
	return {EV_START: _apply_start, EV_LAND: _apply_land, EV_FASTEN: _apply_fasten, EV_STOP: _apply_stop}


func _is_host() -> bool:
	return _net == null or bool(_net.call("is_host"))


# --- What is being built ------------------------------------------------------------------------

## The build in the berth: its state (see builds), or {}.
func active() -> Dictionary:
	return builds.get(current, {})


## The plan of build `contract_id` (the one in the berth by default), or null.
func plan(contract_id := "") -> BuildPlan:
	var e := _plan_entry(contract_id if contract_id != "" else current)
	return e.get("plan") as BuildPlan


func blueprint(contract_id := "") -> Object:
	return _plan_entry(contract_id if contract_id != "" else current).get("blueprint")


func _plan_entry(cid: String) -> Dictionary:
	if cid == "" or not builds.has(cid):
		return {}
	if not _plans.has(cid):
		var b: Dictionary = builds[cid]
		var rec := DesignRecord.from_dict(b.design)
		var design := Modules.bus("design")
		var cat: DesignCatalog = design.get("catalog") if design else DesignCatalog.load_default()
		var bp := Blueprint.new()
		bp.build(rec, cat)
		var groups: Dictionary = bp.groups
		_plans[cid] = {"plan": BuildPlan.make(bp.model, func(p: PartData) -> Dictionary: return groups[p.id]),
				"blueprint": bp}
	return _plans[cid]


## Whether `contract` (a ship contract, ContractsBus.ship_contract) is one the crew builds by hand.
static func is_hand_build(contract: Dictionary) -> bool:
	return str(contract.get("state", "")) == "building" and \
			HAND_SIZES.has(str((contract.get("order", {}) as Dictionary).get("size", "")))


## Starts building `contract_id` in the berth from design `design` (DesignRecord.to_dict). The
## berth takes one build at a time: another one waits. Through the host.
func start(contract_id: String, design: Dictionary, design_name: String) -> void:
	_request(EV_START, {"contract": contract_id, "design": design, "design_name": design_name})


## Starts the sample skiff (the Debug tab; tests and screenshots).
func start_sample() -> void:
	var design := Modules.bus("design")
	var cat: DesignCatalog = design.get("catalog") if design else DesignCatalog.load_default()
	var rec := DesignRecord.new()
	rec.name = "Sample skiff"
	DesignBus.Samples.skiff(rec, cat)
	start(SAMPLE, rec.to_dict(), rec.name)


## Takes build `contract_id` out of the berth (the Debug tab; a delivered ship goes by itself).
func stop(contract_id := "") -> void:
	_request(EV_STOP, {"contract": contract_id if contract_id != "" else current})


func _validate_start(_sender: int, p: Dictionary) -> Variant:
	var cid := str(p.get("contract", ""))
	if cid == "" or (p.get("design", {}) as Dictionary).is_empty():
		return "nothing to build"
	if builds.has(cid):
		return "already building %s" % cid
	return p


func _apply_start(p: Dictionary) -> void:
	var cid := str(p.contract)
	builds[cid] = {"contract": cid, "design": p.design, "design_name": str(p.get("design_name", "")),
			"landed": [], "done": {}, "paid": []}
	if current == "" or not builds.has(current):
		current = cid
	if _is_host() and _contracts and cid != SAMPLE and _contracts.has_method("track_build"):
		_contracts.call("track_build", cid)
	_refresh_berth()
	build_changed.emit()


func _validate_stop(_sender: int, p: Dictionary) -> Variant:
	return p if builds.has(str(p.get("contract", ""))) else "no such build"


func _apply_stop(p: Dictionary) -> void:
	var cid := str(p.contract)
	builds.erase(cid)
	_plans.erase(cid)
	if current == cid:
		current = ""
		for k: String in builds:
			current = k
			break
	_refresh_berth()
	build_changed.emit()


# --- Floating a job in, fastening it -----------------------------------------------------------

## The next job to float in for build `cid`: its index, or -1 (every job in; one still has
## fastenings to make first).
func next_job(cid := "") -> int:
	cid = cid if cid != "" else current
	var b: Dictionary = builds.get(cid, {})
	var pl := plan(cid)
	if b.is_empty() or pl == null:
		return -1
	var landed: Array = b.landed
	if not landed.is_empty() and not job_finished(int(landed.back()), cid):
		return -1
	return landed.size() if landed.size() < pl.jobs.size() else -1


## The job floated in and still being fixed, or -1.
func job_in_hand(cid := "") -> int:
	cid = cid if cid != "" else current
	var b: Dictionary = builds.get(cid, {})
	if b.is_empty() or (b.landed as Array).is_empty():
		return -1
	var j := int((b.landed as Array).back())
	return -1 if job_finished(j, cid) else j


func job_finished(job: int, cid := "") -> bool:
	cid = cid if cid != "" else current
	var b: Dictionary = builds.get(cid, {})
	var pl := plan(cid)
	if b.is_empty() or pl == null or job < 0 or job >= pl.jobs.size() or not (b.landed as Array).has(job):
		return false
	for k in (pl.jobs[job].key as Array).size():
		if not (b.done as Dictionary).has("%d:%d" % [job, k]):
			return false
	return true


## Floats the next job in (F at its glowing pieces). Through the host.
func land_next() -> void:
	var j := next_job()
	if j >= 0:
		_request(EV_LAND, {"contract": current, "job": j})


func _validate_land(_sender: int, p: Dictionary) -> Variant:
	var cid := str(p.get("contract", ""))
	if not builds.has(cid) or int(p.get("job", -1)) != next_job(cid):
		return "not the next job"
	return p


func _apply_land(p: Dictionary) -> void:
	var cid := str(p.contract)
	var b: Dictionary = builds.get(cid, {})
	if b.is_empty() or (b.landed as Array).has(int(p.job)):
		return
	(b.landed as Array).append(int(p.job))
	if berth and is_instance_valid(berth) and cid == current:
		berth.call("land", int(p.job), true)
	_after_change(cid, int(p.job))


## A hand fastening went in (the riveter, welder or socket finished a planned one): if it is
## one of the build's, its quality goes to the host and every machine marks it in.
func _on_hand_fastened(body: RigidBody3D, c: ConnectionData, quality: float) -> void:
	if berth == null or not is_instance_valid(berth):
		return
	var key: Array = berth.call("key_for", body, c)
	if key.is_empty():
		return
	_request(EV_FASTEN, {"contract": current, "job": int(key[0]), "k": int(key[1]), "q": snappedf(quality, 0.001)})


## Marks hand fastening `k` of `job` in at `quality` (tests, and a crewmate's work).
func fasten(job: int, k: int, quality: float) -> void:
	_request(EV_FASTEN, {"contract": current, "job": job, "k": k, "q": snappedf(quality, 0.001)})


func _validate_fasten(_sender: int, p: Dictionary) -> Variant:
	var cid := str(p.get("contract", ""))
	var b: Dictionary = builds.get(cid, {})
	var pl := plan(cid)
	var j := int(p.get("job", -1))
	var k := int(p.get("k", -1))
	if b.is_empty() or pl == null or not (b.landed as Array).has(j) or k < 0 or k >= (pl.jobs[j].key as Array).size():
		return "not a fastening of the build"
	if (b.done as Dictionary).has("%d:%d" % [j, k]):
		return "already in"
	p.q = clampf(float(p.get("q", 1.0)), 0.0, 1.0)
	return p


func _apply_fasten(p: Dictionary) -> void:
	var cid := str(p.contract)
	var b: Dictionary = builds.get(cid, {})
	if b.is_empty():
		return
	var key := "%d:%d" % [int(p.job), int(p.k)]
	if (b.done as Dictionary).has(key):
		return
	b.done[key] = float(p.q)
	if berth and is_instance_valid(berth) and cid == current:
		berth.call("fastened", int(p.job), int(p.k), float(p.q))
	_after_change(cid, int(p.job))


func _after_change(cid: String, job: int) -> void:
	if job_finished(job, cid):
		if berth and is_instance_valid(berth) and cid == current:
			berth.call("finish", job)
		job_done.emit(cid, job)
		var st := str(plan(cid).jobs[job].stage)
		if stage_finished(st, cid):
			stage_done.emit(cid, st)
		_pay(cid)
	build_changed.emit()


# --- Progress, workmanship, payments ----------------------------------------------------------

func stage_finished(stage: String, cid := "") -> bool:
	cid = cid if cid != "" else current
	var pl := plan(cid)
	if pl == null:
		return false
	for j in pl.stage_jobs(stage):
		if not job_finished(int(j.id), cid):
			return false
	return true


## Every job done.
func complete(cid := "") -> bool:
	cid = cid if cid != "" else current
	var pl := plan(cid)
	if pl == null:
		return false
	for s in pl.stages():
		if not stage_finished(s, cid):
			return false
	return true


## How the build stands: {contract, design_name, stage (now; "" when complete), job (index of
## the job in hand or next, -1), job_name, floating (true while it is in hand), jobs, jobs_done,
## key, key_done, by_stage: {stage: [done, jobs]}, workmanship (0..1, -1 before any), grade,
## paid: [ids]}; {} with nothing in the berth.
func progress(cid := "") -> Dictionary:
	cid = cid if cid != "" else current
	var b: Dictionary = builds.get(cid, {})
	var pl := plan(cid)
	if b.is_empty() or pl == null:
		return {}
	var by_stage := {}
	var jobs_done := 0
	for s in pl.stages():
		var n := 0
		var of := pl.stage_jobs(s)
		for j in of:
			if job_finished(int(j.id), cid):
				n += 1
		by_stage[s] = [n, of.size()]
		jobs_done += n
	var in_hand := job_in_hand(cid)
	var nxt := in_hand if in_hand >= 0 else next_job(cid)
	var stage := str(pl.jobs[nxt].stage) if nxt >= 0 else ""
	var w := workmanship(cid)
	return {"contract": cid, "design_name": str(b.design_name), "stage": stage, "job": nxt,
			"job_name": str(pl.jobs[nxt].name) if nxt >= 0 else "", "floating": in_hand >= 0,
			"jobs": pl.jobs.size(), "jobs_done": jobs_done, "key": pl.key_count(), "key_done": (b.done as Dictionary).size(),
			"by_stage": by_stage, "workmanship": w, "grade": BuildPlan.grade(w) if w >= 0.0 else "",
			"paid": (b.paid as Array).duplicate()}


## The mean quality of the build's hand fastenings (0..1), -1 before any are in.
func workmanship(cid := "") -> float:
	cid = cid if cid != "" else current
	var done: Dictionary = (builds.get(cid, {}) as Dictionary).get("done", {})
	if done.is_empty():
		return -1.0
	var sum := 0.0
	for q: float in done.values():
		sum += q
	return sum / done.size()


## A job's quality (its hand fastenings' mean), 1 before any.
func job_quality(job: int, cid := "") -> float:
	cid = cid if cid != "" else current
	var done: Dictionary = (builds.get(cid, {}) as Dictionary).get("done", {})
	var sum := 0.0
	var n := 0
	for key: String in done:
		if int(key.get_slice(":", 0)) == job:
			sum += float(done[key])
			n += 1
	return sum / n if n > 0 else 1.0


## Host: pays each staged payment whose stages are all done (ContractsBus.request_ship_stage),
## once each, in order.
func _pay(cid: String) -> void:
	var b: Dictionary = builds.get(cid, {})
	if b.is_empty() or cid == SAMPLE or not _is_host() or _contracts == null:
		return
	for pay: String in BuildPlan.PAYMENTS:
		if (b.paid as Array).has(pay):
			continue
		var ok := true
		for s: String in BuildPlan.PAYMENTS[pay]:
			if not stage_finished(s, cid):
				ok = false
		if not ok:
			break
		(b.paid as Array).append(pay)
		_contracts.call("request_ship_stage", cid, pay)


## Rows the trial adds for a hand-built ship (ContractsBus.register_trial_rows): how well its
## joints were made, and whether it was built in full.
func trial_rows(contract_id: String) -> Array:
	if not builds.has(contract_id):
		return []
	var p := progress(contract_id)
	var w := workmanship(contract_id)
	var have := maxf(w, 0.0)
	return [
		{"key": "workmanship", "label": "Workmanship (%s)" % (BuildPlan.grade(w) if w >= 0.0 else "none"), "need": WORKMANSHIP_NEED,
				"have": snappedf(have, 0.01), "ok": w >= WORKMANSHIP_NEED, "share": clampf(have / WORKMANSHIP_NEED, 0.0, 1.0), "clause": true},
		{"key": "built", "label": "Built in full", "need": float(p.jobs), "have": float(p.jobs_done),
				"ok": int(p.jobs_done) >= int(p.jobs), "share": float(p.jobs_done) / maxf(1.0, float(p.jobs)), "clause": true},
	]


# --- The berth -------------------------------------------------------------------------------

func _on_station(_station: Node3D) -> void:
	_pick_up_contracts()
	_refresh_berth()


## A small ship contract signed (or delivered): the host starts (or ends) its hand build.
func _on_contract(contract_id: String) -> void:
	if not _is_host() or _contracts == null:
		return
	var c: Dictionary = _contracts.call("ship_contract", contract_id)
	if builds.has(contract_id) and str(c.get("state", "")) != "building":
		stop(contract_id)
		return
	_pick_up_contracts()


func _pick_up_contracts() -> void:
	if not _is_host() or _contracts == null or not _contracts.has_method("ship_contracts"):
		return
	var design := Modules.bus("design")
	var lib: Object = design.get("library") if design else null
	for c: Dictionary in _contracts.call("ship_contracts"):
		if builds.has(str(c.id)) or not is_hand_build(c) or lib == null:
			continue
		var d: Dictionary = lib.call("stored_design", str(c.design_id))
		if d.is_empty() and lib.get("current") and str(lib.get("current").get("id")) == str(c.design_id):
			d = lib.get("current").call("to_dict")
		if not d.is_empty():
			start(str(c.id), d, str(c.get("design_name", "")))


## Puts the build in the berth (or takes it out) in the open station.
func _refresh_berth() -> void:
	if _yard == null:
		return
	var root: Node3D = _yard.call("build_berth_root") if _yard.has_method("build_berth_root") else null
	if root == null:
		return
	if berth and is_instance_valid(berth) and str(berth.get("contract")) != current:
		berth.queue_free()
		berth = null
	if current == "":
		if _yard.has_method("release_build_berth"):
			_yard.call("release_build_berth")
		return
	if berth == null or not is_instance_valid(berth):
		berth = BerthBuild.new()
		berth.name = "HandBuild"
		root.add_child(berth)
		berth.call("setup", self, current)


## The yard's stand-in keel stays away while the berth has a build (on the shared clock: the
## berth node asks whenever the yard's claim is not its own).
func claim_berth() -> void:
	if _yard and _yard.has_method("claim_build_berth") and str(_yard.get("berth_claimed_by")) != CLAIM \
			and float(_yard.get("sim_epoch")) >= 0.0:
		_yard.call("claim_build_berth", CLAIM)


# --- Saving and joining ------------------------------------------------------------------------

func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	return {"builds": builds.duplicate(true), "current": current}


func load_data(data: Dictionary, _from_version: int) -> void:
	builds = (data.get("builds", {}) as Dictionary).duplicate(true)
	current = str(data.get("current", ""))
	if not builds.has(current):
		current = ""
	_plans.clear()
	_refresh_berth()
	build_changed.emit()


func reset_data() -> void:
	load_data({}, SAVE_VERSION)


func get_net_snapshot() -> Dictionary:
	return save_data()


func apply_net_snapshot(data: Dictionary) -> void:
	load_data(data, SAVE_VERSION)


func _debug_panel() -> Control:
	var box := VBoxContainer.new()
	for row: Array in [["Build the sample skiff in the berth", start_sample],
			["Float in and fix the next job", debug_next_job],
			["Finish the stage in hand", debug_finish_stage],
			["Take the build out of the berth", func() -> void: stop()]]:
		var b := Button.new()
		b.text = row[0]
		b.pressed.connect(row[1])
		box.add_child(b)
	return box


## Debug: floats the next job in and makes its fastenings (fair work).
func debug_next_job() -> void:
	var j := job_in_hand()
	if j < 0:
		j = next_job()
		if j < 0:
			return
		_request(EV_LAND, {"contract": current, "job": j})
	var pl := plan()
	for k in (pl.jobs[j].key as Array).size():
		if not (active().done as Dictionary).has("%d:%d" % [j, k]):
			fasten(j, k, 0.75)


## Debug: every job of the stage in hand (or next) done.
func debug_finish_stage() -> void:
	var p := progress()
	if p.is_empty() or str(p.stage) == "":
		return
	var stage := str(p.stage)
	while str(progress().get("stage", "")) == stage:
		var before := int(progress().jobs_done)
		debug_next_job()
		if int(progress().jobs_done) == before:
			break


## A screenshot of the build berth: the ghost skiff with her first job glowing, her frame up
## with the next glowing, a weld being made by hand, her hull closed.
func _shot(scene: Node, view: String) -> void:
	for i in 3:
		await scene.get_tree().process_frame
	start_sample()
	for i in 3:
		await scene.get_tree().process_frame
	match view:
		"frame":
			debug_finish_stage()
		"hull":
			debug_finish_stage()
			debug_finish_stage()
		"weld":
			land_next()
	for i in 6:
		await scene.get_tree().physics_frame
	if berth and berth.has_method("settle"):
		berth.call("settle")
	for i in 4:
		await scene.get_tree().physics_frame
	var work: Node3D = berth.get("work") if berth else null
	if work == null:
		return
	var cam := Camera3D.new()
	cam.name = "BuildShot"
	cam.fov = 60.0
	scene.add_child(cam)
	var mid: Vector3 = (berth as Node3D).global_position
	var side := (berth as Node3D).global_basis.x
	if view == "weld":
		var planned: Array = work.get("planned")
		var mover: Node3D = scene.get("mover")
		if not planned.is_empty() and mover:
			var p: Dictionary = planned[0]
			var at: Vector3 = (work as Node3D).global_transform * (p.at as Vector3)
			var n: Vector3 = work.call("planned_normal", p)
			var k: Dictionary = (mover.get_script() as Script).get_script_constant_map()
			mover.call("place", at + n * 0.8 - Vector3(0, float(k.FEET) + float(k.EYE), 0), at)
			var tools: Node = mover.get("tools")
			tools.call("select_tool", 7)
			for i in 3:
				await scene.get_tree().physics_frame
			tools.set("trigger_override", 1)
			var right := n.cross(Vector3.UP).normalized()
			cam.position = at + n * 1.9 + right * 1.3 + Vector3(0, 0.5, 0)
			cam.look_at(at - n * 0.1)
			cam.current = true
			for i in 30:
				await scene.get_tree().physics_frame
			return
	var b: AABB = (blueprint().get("bounds") as AABB) if blueprint() else AABB(Vector3(-6, -3, -12), Vector3(12, 6, 24))
	var reach := maxf(b.size.length(), 12.0)
	cam.position = mid + side.rotated(Vector3.UP, 0.7) * reach * 0.75 + Vector3(0, reach * 0.3, 0)
	cam.look_at(mid)
	cam.current = true
