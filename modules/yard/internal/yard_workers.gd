extends Node3D
## The worker bots building in the build berth (0.4.1 playtest: "they also deliver to the
## worker bots who actually make the ship in the yard", then "the worker bots who fix the ship
## up should be more functional, android style ... Some carry the large components and put them
## in place, others weld and rivet etc. The movers bring supplies to them when they need them
## or bring quantities of stock and wait until they have depleted them").
##
## A crew of heavy android bots (YardWorkerLook) round a keel frame of Void Salvage's box beams
## and girders, a ring at a time. When a ring needs parts they ask the stores for a keel ring
## kit; mover bots bring it out and hover by the keel holding their loads till every part is
## used. F-3 fitters take a part off a mover, carry it in their grippers and hold it in place;
## W-3 welders tack a box beam at both ends, sparks at the torch, and R-3 riveters punch rivets
## along it, each with a kick and a flash; B-3 bolters run bolts home at each end of a girder.
## The trades who fasten clamp their feet to the work and lean into it. Every second ring the
## crew fits it out: they send for a power kit, and movers bring it to the lead fitter when it's
## wanted; fitters set the battery rack, cabinet and junction boxes on the ring and the bolters
## bolt them down; the next fit-out is a piping kit, the pipes clamped on with bolts. Presentation only: it
## stands in for Wave 5's real building.
##
## How things are joined is TartanCo's rule (beenster, 19 Nov): beams are welded together; inner
## walls are riveted at the plate corners; outer hull plates are riveted at the corners and
## welded along a short length of one side; components are bolted to walls, ceilings and floors
## (large ones with several bolts); pipes are bolted and wires riveted (JOINING). So each ring's
## box beams and girders are welded at both ends, and once its frame stands its bay is skinned:
## hull plates on both sides (riveted, then a short seam) and an inner wall lining each (riveted).
##
## The bots are TartanCo's, and they wear: every job wears a bot a little, a worn bot slows
## down, and past a point it starts throwing errors and stops till it's seen to. Then the crew
## calls TartanCo (YardService), whose engineers come out by ship and put it right.
##
## They run on batteries too (beenster, 19 Nov: "mounted on the wall somewhere near the yard for
## when they are recharging", then "they should attach to charging stations built into the frame
## of the berths"): between jobs each bot hangs on its own dock, built onto a rib of the berth's
## station-side frame, back to the frame, topping up. Every job drains a bot a little; one run low
## stays on its dock till it's full. Each bot has its own pace and is slow or quick to leave its
## dock for a new job, so the crew never moves in unison ("They should not move in unison").

const WorkerLook := preload("res://modules/yard/internal/yard_worker_look.gd")
const Look := preload("res://modules/yard/internal/yard_stock_look.gd")
const Service := preload("res://modules/yard/internal/yard_service.gd")
const Upgrades := preload("res://modules/yard/internal/tartanco_upgrades.gd")

## The keel's first ring, the way it grows (m), the rings' pitch and how many it has room for.
const KEEL_START := Vector3(-16.0, -3.0, -85.0)
const KEEL_STEP := 3.2
const RINGS := 11
## The ring's side (m): a BoxBeam's length.
const RING := 6.0
## The kit the crew asks for, enough for one ring.
const KIT := "keel_ring"
## The crew by trade, in order: fitters, welders, riveter, bolter.
const CREW := ["F", "F", "W", "W", "R", "B"]
## The kit a fit-out sends for (brought to the lead fitter when it's wanted, not held waiting),
## and how often: after every this many rings.
const FITOUT_KIT := "power"
## The fit-out kits, in turn (a ring with power, the next with pipes).
const FITOUT_KITS: Array[String] = ["power", "piping"]
## TartanCo's joining rule (see the header): the fastening steps a part takes, in order. Anything
## not named is a component: bolted.
const JOINING := {
	"BoxBeam": ["weld"], "Girder": ["weld"],
	"HullPlate": ["rivet", "weld"],
	"DeckPlate": ["rivet"],
	"Pipe": ["bolt"],
	"Wire": ["rivet"],
}
## The trade each step wants.
const TRADE := {"weld": "W", "rivet": "R", "bolt": "B"}
const FITOUT_EVERY := 2
## The charging wall (station space): its face's middle at the docks' hanging height, standing on
## the dock arm's truss (z -66, y -16) beside the build berth, and its docks' spacing (m).
## Each bot's dock: on a rib of the build berth's station-side frame face (ribs every 10 m at
## z -70, 0.6 m thick), low under the hull clamps and high over them (station space: the rib's
## face at the hanging height).
## The first six for the crew the yard starts with, then one for each bot bought from TartanCo,
## up to MAX_BOTS: every rib of the build berth's station-side frame, low and high.
const DOCKS: Array[Vector3] = [Vector3(-20, -13.5, -70.3), Vector3(20, -13.5, -70.3), Vector3(-10, -13.5, -70.3),
		Vector3(10, -13.5, -70.3), Vector3(-10, 7.5, -70.3), Vector3(10, 7.5, -70.3),
		Vector3(0, -13.5, -70.3), Vector3(0, 7.5, -70.3), Vector3(-20, 7.5, -70.3), Vector3(20, 7.5, -70.3)]
## The most bots the berth has docks for.
const MAX_BOTS := 10

## Seconds a fitter takes to ease a part into place, a weld per joint, a rivet (pressure, then
## the punch).
@export var fit_seconds := 2.4
@export var weld_seconds := 2.6
@export var rivet_seconds := 1.0
## Seconds a bolter runs one bolt home, and bolts at each joint.
@export var bolt_seconds := 1.4
@export var bolts_per_joint := 2
## The welder's sparks a second (the grinder's spray: YardSparkSpray), and what a rivet slamming
## home throws: swarf and flakes, sparks and puffs of steam.
@export var weld_spark_rate := 420.0
@export var rivet_chips := 26
@export var rivet_sparks := 14
@export var rivet_steam := 8
## The frame's box girders, Void Salvage's sizes (m): the ring's members (width across the
## ring, depth along the keel) and the stringers between rings.
@export var ring_member := Vector2(0.24, 0.2)
@export var stringer := Vector2(0.16, 0.16)
## The skin: how far its plates stand off the frame's centre lines (m), how far in from a plate's
## edges its corner rivets go (m), and the hull plates' short seam (m).
@export var skin_gap := 0.2
@export var corner_inset := 0.12
@export var seam_length := 0.5
## How far a trade leans into the work it's clamped to (rad), and its pelvis over the surface (m).
@export var brace_lean := 0.62
@export var brace_height := 0.8
## Fit the rings out (see the header), and how long to wait on a fit-out's kit before going on
## without it (s).
@export var fit_out := true
@export var fitout_wait := 150.0
## The crew's flying speed (m/s), and how long they'll wait on the stores for a part before a
## spare turns up from the berth's own stock (s).
@export var fly_speed := 4.0
@export var spare_after := 120.0
## Rings standing when the yard opens.
@export var start_rings := 3
## Once the keel has all its rings, the crew waits this long (s), then the finished keel makes
## way for a new one and they start again (0.4.2 playtest: after the last ring they stood idle
## for good).
@export var new_keel := true
@export var keel_pause := 30.0
## Wear (0 new, 1 worn out) a job puts on a bot, on average; past `slow_from` it slows (down to
## `worn_pace` of its speed when worn out), past `faults_from` it may fault at the end of a job.
@export var wear_per_job := 0.045
@export var slow_from := 0.4
@export var worn_pace := 0.55
@export var faults_from := 0.6
## TartanCo is sent for when a bot faults or one is this worn; on a visit every bot worn past
## `service_from` gets seen to.
@export var call_at := 0.75
@export var service_from := 0.3
@export var auto_service := true

@export_group("Charging")
## How much of a full battery a job uses (0..1), the charge a bot goes to its dock at, and how
## long a dock takes to charge one from empty (s).
@export var charge_per_job := 0.05
@export var recharge_at := 0.2
@export var charge_seconds := 45.0

## A bot needs servicing (faulted, or worn past `call_at`): the bots to see to (each a worker's
## node). Sent once until they're all seen to. While anything listens (the TartanCo
## maintenance ship's module, through YardBus.workers_need_service), the yard's own service visit
## stays away.
signal service_needed(bots: Array)

## The faults a worn bot throws.
const FAULTS: PackedStringArray = ["E-17 ACTUATOR", "E-42 SERVO HEAT", "E-08 SENSOR DRIFT", "E-31 FEED JAM", "E-23 JOINT LASH"]

var traffic: Node
## {node, role, index, task (Dictionary: {} when idle), vel, sparks, light}.
var workers: Array[Dictionary] = []
var rings: Array[Node3D] = []
## The ring going on now: {part, t (ring space), stage, piece, fitter, waited}. Stages: need,
## carry, held (waiting on its next fastening step, `steps`[`step`]), working, done. `fixed` once its
## first step is done (its fitter lets go).
var members: Array[Dictionary] = []
var ring_node: Node3D
## Where the movers wait with their loads (just off the keel's front).
var supply: Node3D
var _order := -1
var _time := 0.0
## This step's length (s): what waiting counts, the same on every machine (the yard's sim clock).
var _step_dt := 0.0
var _rivet_mesh: CylinderMesh
var _rivet_mat: StandardMaterial3D
var service: Node3D
var _rng := RandomNumberGenerator.new()
## The fit-out under way: {} or {order (kit order id), t, ring}; rings already fitted out.
var _fitout: Dictionary = {}
var fitted_out: Array[int] = []
var _asked := false
var _bolt_mesh: CylinderMesh
var _keel_done := 0.0
var charge_docks: Node3D
## The welders' and riveters' shower of sparks, globs, chips and steam: the same spray the
## player's grinder throws (YardSparkSpray). Presentation only: its own random numbers, never
## the crew's `_rng`, so the shared clock's crew stays the same on every PC.
var spray: YardSparkSpray
var _owed := {}


func build(stores_traffic: Node) -> void:
	name = "YardWorkers"
	traffic = stores_traffic
	for i in start_rings:
		_whole_ring()
	supply = Node3D.new()
	supply.name = "Supply"
	add_child(supply)
	for i in CREW.size():
		_make_worker(String(CREW[i]))
	spray = YardSparkSpray.new()
	spray.name = "BotSpray"
	add_child(spray)
	charge_docks = Node3D.new()
	charge_docks.name = "ChargeDocks"
	add_child(charge_docks)
	for i in CREW.size():
		_add_dock(i)
	_rng.seed = 4021
	# Each its own pace, so no two move alike.
	for w: Dictionary in workers:
		w.speed = _rng.randf_range(0.8, 1.2)
	service = Service.new()
	add_child(service)
	service.build(self)
	_start_ring()


## The fitter the movers' first loads come to (the crew's lead).
func foreman() -> Node3D:
	return workers[0].node if not workers.is_empty() else null


func rings_built() -> int:
	return rings.size()


## Sends for TartanCo's engineers now (false if they're already coming or here).
func call_service() -> bool:
	return bool(service.call("call_in"))


## A bot waiting to be seen to (faulted, or worn past `service_from`), idle, and not already
## someone's (`taken`: the jobs the engineers have now), or {}.
func needs_service(taken: Array) -> Dictionary:
	for w: Dictionary in workers:
		if (w.fault != "" or float(w.wear) >= service_from) and (w.task as Dictionary).is_empty() and not bool(w.servicing):
			if not taken.any(func(t: Dictionary) -> bool: return not t.is_empty() and t.node == w.node):
				return w
	return {}


## An engineer has put `w` right: as new, its error cleared.
func serviced(w: Dictionary) -> void:
	w.wear = 0.0
	w.fault = ""
	w.servicing = false
	(w.node.get_node("Fault") as Label3D).visible = false


## A new bot of trade `role` on the next dock (its node named Worker<n>, numbered within its trade).
func _make_worker(role: String) -> Dictionary:
	var i := workers.size()
	var number := 1 + workers.filter(func(x: Dictionary) -> bool: return x.role == role).size()
	var bot := WorkerLook.make(role, "%02d" % number)
	bot.name = "Worker%d" % (i + 1)
	add_child(bot)
	var w := {"node": bot, "role": role, "index": i, "task": {}, "vel": Vector3.ZERO, "wear": 0.05 * i,
			"fault": "", "servicing": false, "charge": 1.0 - 0.13 * i, "charging": true, "low": false, "route": [],
			"speed": 1.0, "began": 0.0, "mark": Upgrades.FIRST_MARK, "modules": [],
			"fx": Upgrades.effects(Upgrades.FIRST_MARK, [])}
	if role != "F":
		w.sparks = make_sparks(role)
		add_child(w.sparks)
		var light := OmniLight3D.new()
		light.name = "WorkLight%d" % (i + 1)
		light.light_color = Color(0.6, 0.8, 1.0) if role == "W" else Color(1.0, 0.85, 0.6)
		light.omni_range = 6.0
		light.light_energy = 0.0
		add_child(light)
		w.light = light
	bot.position = dock_spot(i)
	WorkerLook.rest(bot, "R")
	WorkerLook.rest(bot, "L")
	WorkerLook.tuck(bot, "R")
	WorkerLook.tuck(bot, "L")
	workers.append(w)
	_refit(w)   # its chest code shows its mark: W-1 as it comes
	return w


func _add_dock(i: int) -> void:
	var dock := WorkerLook.charge_dock(i + 1)
	dock.position = DOCKS[i]
	charge_docks.add_child(dock)


# --- The fleet ---------------------------------------------------------------------------------
# beenster, 19 Nov: "New bots can be added to our fleet by buying them at TartanCo. They should be
# expensive so that you can't immediately have lots of them" (prices: TartanCoUpgrades.BOT_PRICES).
# Whoever sells them takes the money, then calls add_bot, on the yard's shared clock.

## Adds a new bot of trade `role` (F, W, R or B), new and charged, on a dock of its own on the
## berth's frame. Its node, or null when the trade is unknown or every dock is taken.
func add_bot(role: String) -> Node3D:
	if not Upgrades.BOT_PRICES.has(role) or workers.size() >= MAX_BOTS:
		return null
	_add_dock(workers.size())
	var w := _make_worker(role)
	w.wear = 0.0
	w.charge = 1.0
	w.speed = _rng.randf_range(0.8, 1.2)
	return w.node


## The fleet as it stands, to save: one {role, mark, modules} a bot, in order.
func fleet_state() -> Array:
	return workers.map(func(w: Dictionary) -> Dictionary: return {"role": w.role, "mark": int(w.mark), "modules": (w.modules as Array).duplicate()})


## Puts a saved fleet back: the bots bought since added again, every bot's mark and modules.
func restore_fleet(state: Array) -> void:
	for i in state.size():
		var b: Dictionary = state[i]
		if i >= workers.size() and add_bot(String(b.get("role", ""))) == null:
			break
		var w: Dictionary = workers[i]
		w.mark = int(b.get("mark", Upgrades.FIRST_MARK)) if Upgrades.MARKS.has(int(b.get("mark", 0))) else Upgrades.FIRST_MARK
		w.modules = (b.get("modules", []) as Array).filter(func(id: Variant) -> bool: return Upgrades.MODULES.has(String(id))).slice(0, Upgrades.slots(int(w.mark)))
		_refit(w)


## How fast a bot works for its wear (1 new).
func pace(w: Dictionary) -> float:
	var over := clampf((float(w.wear) - slow_from) / (1.0 - slow_from), 0.0, 1.0)
	return lerpf(1.0, worn_pace, over) * float(_fx(w).pace)


## A bot's upgrade effects (its mark and modules, TartanCoUpgrades.effects).
func _fx(w: Dictionary) -> Dictionary:
	return w.get("fx", Upgrades.effects(Upgrades.FIRST_MARK, []))


# --- Upgrades ---------------------------------------------------------------------------------
# beenster's pick, 19 Nov: marks with module slots (tartanco_upgrades.gd). Whoever sells them
# (TartanCo's engineers on a visit) calls these, on the yard's shared clock like everything else.

## Makes a bot `mark` (3 to 5). Modules past the new mark's slots come out. False if it isn't one.
func set_mark(bot: Node3D, mark: int) -> bool:
	var w := worker_of(bot)
	if w.is_empty() or not Upgrades.MARKS.has(mark):
		return false
	w.mark = mark
	(w.modules as Array).resize(mini((w.modules as Array).size(), Upgrades.slots(mark)))
	_refit(w)
	return true


## Fits module `id` in a free slot. False if it isn't a module, the bot has it or has no slot free.
func fit_module(bot: Node3D, id: String) -> bool:
	var w := worker_of(bot)
	var mods: Array = w.get("modules", [])
	if w.is_empty() or not Upgrades.MODULES.has(id) or mods.has(id) or mods.size() >= Upgrades.slots(int(w.mark)):
		return false
	mods.append(id)
	_refit(w)
	return true


## Takes module `id` out. False if it wasn't fitted.
func remove_module(bot: Node3D, id: String) -> bool:
	var w := worker_of(bot)
	if w.is_empty() or not (w.modules as Array).has(id):
		return false
	(w.modules as Array).erase(id)
	_refit(w)
	return true


## Its effects worked out again, and its mark shown (beenster, 19 Nov: "it should be Mk1, Mk2,
## Mk3, Mk4 and Mk5"): "Mk1" big on its chest, its trade and number under it ("W 01"), and its
## model "W Mk1".
func _refit(w: Dictionary) -> void:
	w.fx = Upgrades.effects(int(w.mark), w.modules)
	var node: Node3D = w.node
	var mark := Upgrades.mark_name(int(w.mark))
	node.set_meta("tartanco_model", "%s %s" % [w.role, mark])
	var label := node.get_node_or_null("Code") as Label3D
	if label:
		label.text = mark
	var number := node.get_node_or_null("Number") as Label3D
	if number:
		if not node.has_meta("number"):
			node.set_meta("number", number.text)
		number.text = "%s %s" % [w.role, String(node.get_meta("number"))]


## The crew's bots (their nodes), for the maintenance ship.
func bots() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for w: Dictionary in workers:
		out.append(w.node)
	return out


func worker_of(bot: Node3D) -> Dictionary:
	for w: Dictionary in workers:
		if w.node == bot:
			return w
	return {}


## A bot's state for the maintenance ship and the fleet screen: productivity 0..1 (its pace, 0
## while faulted), its errors, wear, charge, model and serial; its role (F/W/R/B), own speed
## factor, state (working, idle, to_dock, charging, faulted, servicing), job ("Welding keel ring
## 7, joint 2/2", "" when idle) and job_kind (fit/weld/rivet/bolt, "" when idle).
func condition(bot: Node3D) -> Dictionary:
	var w := worker_of(bot)
	if w.is_empty():
		return {}
	var errors: Array[String] = []
	if w.fault != "":
		errors.append(String(w.fault))
	return {"productivity": 0.0 if w.fault != "" else pace(w), "errors": errors, "wear": float(w.wear),
			"charge": float(w.charge), "charging": _docked(w) and float(w.charge) < 1.0,
			"model": bot.get_meta("tartanco_model", ""), "serial": bot.get_meta("serial", ""),
			"role": String(w.role), "speed": float(w.speed), "state": _state(w), "job": job_line(w),
			"job_kind": String((w.task as Dictionary).get("kind", "")),
			"mark": int(w.mark), "mark_name": Upgrades.mark_name(int(w.mark)), "slots": Upgrades.slots(int(w.mark)),
			"upgrades": Upgrades.fitted(w.modules)}


func _state(w: Dictionary) -> String:
	if w.fault != "":
		return "faulted"
	if bool(w.servicing):
		return "servicing"
	if not (w.task as Dictionary).is_empty():
		return "working"
	if _docked(w):
		return "charging" if float(w.charge) < 1.0 else "idle"
	return "to_dock" if bool(w.low) or not (w.route as Array).is_empty() else "idle"


const _VERB := {"fit": "Fitting", "weld": "Welding", "rivet": "Riveting", "bolt": "Bolting"}
const _UNIT := {"weld": "joint", "rivet": "rivet", "bolt": "bolt"}
const _NAMES := {"BoxBeam": "box beam", "Girder": "girder", "HullPlate": "hull plate", "DeckPlate": "inner wall",
		"Pipe": "pipe"}


## What a bot is doing, in a line ("Welding keel ring 7 hull plate, joint 1/1"), or "".
func job_line(w: Dictionary) -> String:
	var task: Dictionary = w.task
	if task.is_empty():
		return ""
	var m: Dictionary = task.get("member", {})
	var part: String = _NAMES.get(String(m.get("part", "")), String(m.get("part", "")).to_snake_case().replace("_", " "))
	var where := "keel ring %d" % (int(_fitout.ring) if not _fitout.is_empty() else rings.size() + 1)
	var line := "%s %s %s" % [_VERB.get(task.kind, String(task.kind).capitalize()), where, part]
	if task.has("of"):
		var left: Array = task.get("joints", task.get("spots", []))
		line += ", %s %d/%d" % [_UNIT[task.kind], mini(int(task.of), int(task.of) - left.size() + 1), int(task.of)]
	return line


## The maintenance ship takes a bot: it puts its job down (a part it was holding stays put) and
## keeps still till end_service. True if it took it.
func begin_service(bot: Node3D) -> bool:
	var w := worker_of(bot)
	if w.is_empty():
		return false
	_drop_task(w)
	w.servicing = true
	w.external = true
	return true


## The maintenance ship is done with a bot: as new, its error cleared, back to work.
func end_service(bot: Node3D) -> void:
	var w := worker_of(bot)
	if not w.is_empty():
		w.external = false
		serviced(w)


## True while someone else (the maintenance ship) answers service_needed.
func external_service() -> bool:
	# Through the tree, not the autoload's name: the capture tools run this as a bare script.
	var tree := Engine.get_main_loop() as SceneTree
	var modules := tree.root.get_node_or_null("Modules") if tree else null
	var bus: Node = modules.call("bus", "yard") if modules else null
	return bus != null and bus.has_signal("workers_need_service") and not bus.get_signal_connection_list("workers_need_service").is_empty()


## Puts a bot's job down so another can pick it up: its member goes back a stage.
func _drop_task(w: Dictionary) -> void:
	var task: Dictionary = w.task
	if task.is_empty():
		return
	var m: Dictionary = task.get("member", {})
	match String(task.kind):
		"fit":
			if task.phase == "go" or task.phase == "carry":
				if m.get("piece") != null and is_instance_valid(m.piece):
					(m.piece as Node3D).queue_free()
				m.piece = null
				m.stage = "need"
				m.waited = spare_after   # its part was taken: a spare comes
			elif task.phase == "fit":
				(m.piece as Node3D).global_transform = ring_node.global_transform * (m.t as Transform3D)
				(m.piece as Node3D).reparent(ring_node, true)
				m.stage = "held"
		"weld", "bolt", "rivet":
			m.stage = "held"
	w.task = {}


## A job done: wear on the bot, and a worn bot may fault.
func _job_done(w: Dictionary) -> void:
	w.task = {}
	var fx := _fx(w)
	w.charge = maxf(0.0, float(w.charge) - charge_per_job * float(fx.drain) * _rng.randf_range(0.7, 1.3))
	w.wear = minf(1.0, float(w.wear) + wear_per_job * float(fx.wear) * _rng.randf_range(0.6, 1.4))
	if float(w.wear) > faults_from and _rng.randf() < (float(w.wear) - faults_from) * 1.6 * float(fx.faults):
		w.fault = FAULTS[_rng.randi() % FAULTS.size()]
		var label := w.node.get_node("Fault") as Label3D
		label.text = "%s\n%s" % ["ERROR", w.fault]


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	_time += delta
	_step_dt = delta
	if ring_node == null and _fitout.is_empty():
		if fit_out and rings.size() >= FITOUT_EVERY and rings.size() % FITOUT_EVERY == 0 \
				and not fitted_out.has(rings.size()) and rings.size() > start_rings:
			_start_fitout()
		elif rings.size() < RINGS:
			_start_ring()
		elif new_keel:
			_keel_done += delta
			if _keel_done >= keel_pause:
				_new_keel()
	if not _fitout.is_empty():
		_step_fitout(delta)
	else:
		_keep_supplied()
	_send_to_charge()
	_assign()
	for w: Dictionary in workers:
		_work(w, delta * pace(w))
		WorkerLook.show_charge(charge_docks.get_node("Dock%d" % (int(w.index) + 1)), float(w.charge) if _docked(w) else -1.0, float(w.charge) < 1.0)
	_check_service()
	service.call("step", delta)
	if ring_node and not members.is_empty() and members.all(func(m: Dictionary) -> bool: return m.stage == "done"):
		if _fitout.is_empty():
			rings.append(ring_node)
		else:
			fitted_out.append(int(_fitout.ring))
			_fitout = {}
		ring_node = null
		members.clear()


## Sends for TartanCo when a bot faults or wears past `call_at`: the maintenance ship's module
## if it's listening (service_needed, once till they're seen to), else the yard's own visit.
func _check_service() -> void:
	var due: Array = []
	var urgent := false
	for w: Dictionary in workers:
		if w.fault != "" or float(w.wear) >= call_at:
			urgent = true
		if w.fault != "" or float(w.wear) >= service_from:
			due.append(w.node)
	if not urgent:
		_asked = false
		return
	if external_service():
		if not _asked:
			_asked = true
			service_needed.emit(due)
	elif auto_service and service.state == "away":
		call_service()


# --- The ring -------------------------------------------------------------------------------

## The face the next ring goes on (station space).
func _front() -> Vector3:
	return KEEL_START + Vector3(KEEL_STEP * rings.size(), 0, 0)


## Its members (ring space), framed the way Void Salvage frames a hull (beenster, 19 Nov: "box
## girders like those in Void Salvage", "the same neat beam joining ... so that we don't have big
## knuckles at joins"): four box girders round a square, each the corner to corner length of its
## side on the centre line and mitred 45 degrees at both ends (PartShapes.girder, VS's own box
## girder with its lightening holes), so the ring closes up corner to corner with no ends
## sticking past; then stringers, box girders too, butted onto the ring's faces back to the last
## ring at each corner. Each member carries its own shape (`shape`).
func _member_list(with_girders: bool) -> Array[Dictionary]:
	var h := RING * 0.5
	var out: Array[Dictionary] = []
	var centre := Vector3(0, h, 0)
	var corners: Array[Vector3] = [Vector3(0, 0, -h), Vector3(0, 0, h), Vector3(0, RING, h), Vector3(0, RING, -h)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var x := (b - a).normalized()
		var mid := (a + b) * 0.5
		# Width across the ring, pointing in: the mitre makes the outer edge the longer one.
		var z := (centre - mid).normalized()
		var basis := Basis(x, z.cross(x), z)
		out.append({"part": "BoxBeam", "t": Transform3D(basis, mid),
				"shape": _girder(a.distance_to(b), ring_member, 45.0)})
	if with_girders:
		var length := KEEL_STEP - ring_member.y
		for c: Vector3 in corners:
			# Along the keel, from the last ring's face to this one's.
			var z := Vector3(0, centre.y - c.y, centre.z - c.z).normalized()
			out.append({"part": "Girder", "t": Transform3D(Basis(Vector3.RIGHT, z.cross(Vector3.RIGHT), z), c - Vector3(KEEL_STEP * 0.5, 0, 0)),
					"shape": _girder(length, stringer, 0.0)})
		out.append_array(_skin_list())
	return out


## The bay's skin (ring space), once its frame stands: on each side three hull plates outside the
## frame and two inner wall linings inside it (a plating kit's worth), long sides along the keel.
## Each turned so its face (the part's +y) points out of the side it covers: the hull away from
## the keel, the linings in towards it.
func _skin_list() -> Array[Dictionary]:
	var h := RING * 0.5
	var bay := -KEEL_STEP * 0.5
	var out: Array[Dictionary] = []
	for side: float in [-1.0, 1.0]:
		var face := Vector3(0, 0, side)
		for y: float in [h - 1.6, h, h + 1.6]:
			out.append({"part": "HullPlate", "skin": true, "out": face,
					"t": Transform3D(Basis(Vector3.UP, face, Vector3.UP.cross(face)), Vector3(bay, y, side * (h + skin_gap)))})
		for y: float in [h - 0.65, h + 0.65]:
			out.append({"part": "DeckPlate", "skin": true, "out": -face,
					"t": Transform3D(Basis(Vector3.UP, -face, Vector3.UP.cross(-face)), Vector3(bay, y, side * (h - skin_gap)))})
	return out


static var _girders: Dictionary = {}


## A Void Salvage box girder `length` long, `section` (width, depth), mitred `mitre` degrees at
## both ends; built once a size.
func _girder(length: float, section: Vector2, mitre: float) -> PartShapes.PartShape:
	var key := "%.3f_%.3f_%.3f_%.1f" % [length, section.x, section.y, mitre]
	if not _girders.has(key):
		_girders[key] = PartShapes.girder(length, section.x, section.y, mitre, mitre)
	return _girders[key]


## What a member draws with: its own shape (a frame member's mitred box girder) on its part's
## surface, else the part as the stores keep it.
func _layers_of(m: Dictionary) -> Array:
	if m.has("shape"):
		return [{"mesh": (m.shape as PartShapes.PartShape).mesh, "material": Look.material(m.part)}]
	return Look.layers(m.part)


## A piece taken from a mover dressed as the member it will be (a stock box beam becomes this
## ring's mitred one).
func _dress(piece: Node3D, m: Dictionary) -> void:
	if not m.has("shape"):
		return
	for c in piece.get_children():
		if c is MeshInstance3D:
			piece.remove_child(c)
			c.queue_free()
	for l: Dictionary in _layers_of(m):
		var mi := MeshInstance3D.new()
		mi.mesh = l.mesh
		mi.material_override = l.material
		piece.add_child(mi)


## A member's fastening steps (JOINING) and where it starts.
func _ready_member(m: Dictionary) -> void:
	m.stage = "need"
	m.piece = null
	m.waited = 0.0
	m.steps = (JOINING.get(m.part, ["bolt"]) as Array).duplicate()
	m.step = 0
	m.fixed = false


## A member's next fastening step is done: its fitter lets go; on to the next, or done.
func _fastened(m: Dictionary) -> void:
	m.fixed = true
	m.step = int(m.step) + 1
	m.stage = "done" if int(m.step) >= (m.steps as Array).size() else "held"


## Whether this ring's frame (its beams and girders) is all welded, so its skin can go on.
func _frame_done() -> bool:
	return members.all(func(m: Dictionary) -> bool: return m.has("skin") or m.stage == "done")


## A ring standing whole (the ones there when the yard opens).
func _whole_ring() -> void:
	var ring := Node3D.new()
	ring.name = "Ring%d" % rings.size()
	ring.position = _front()
	add_child(ring)
	for m: Dictionary in _member_list(rings.size() > 0):
		for l: Dictionary in _layers_of(m):
			var mi := MeshInstance3D.new()
			mi.mesh = l.mesh
			mi.material_override = l.material
			mi.transform = m.t
			ring.add_child(mi)
	rings.append(ring)


## The finished keel goes (off to Wave 5's real building, one day) and a new one stands at the
## start with its first rings.
func _new_keel() -> void:
	_keel_done = 0.0
	for r: Node3D in rings:
		remove_child(r)
		r.queue_free()
	rings.clear()
	fitted_out.clear()
	for i in start_rings:
		_whole_ring()


func _start_ring() -> void:
	ring_node = Node3D.new()
	ring_node.name = "Ring%d" % rings.size()
	ring_node.position = _front()
	add_child(ring_node)
	members.clear()
	for m: Dictionary in _member_list(rings.size() > 0):
		_ready_member(m)
		members.append(m)
	# The movers wait beside the new ring, on the side away from the station.
	supply.position = _front() + Vector3(KEEL_STEP * 0.5, -0.5, RING * 0.5 + 4.5)


## The ring's axis at its front (station space): where "out" is measured from.
func _axis() -> Vector3:
	return _front() + Vector3(0, RING * 0.5, 0)


## Away from the keel's axis through `p`, square to it (a worker stands off the work this way).
func _out(p: Vector3) -> Vector3:
	var a := _axis()
	var v := Vector3(0, p.y - a.y, p.z - a.z)
	return v.normalized() if v.length() > 0.05 else Vector3.BACK


## A member's ends and its middle (station space), and how far its surface stands out along
## `out` from its centre line.
func _span(m: Dictionary) -> Dictionary:
	var box := AABB()
	var first := true
	for l: Dictionary in _layers_of(m):
		var b: AABB = (l.mesh as Mesh).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var c := box.get_center()
	var g: Transform3D = ring_node.global_transform * (m.t as Transform3D)
	var a := g * Vector3(box.position.x, c.y, c.z)
	var b2 := g * Vector3(box.end.x, c.y, c.z)
	var mid := (a + b2) * 0.5
	var o := _out(mid) if not m.has("out") else ring_node.global_basis * (m.out as Vector3)
	var half := box.size * 0.5
	var reach := absf(g.basis.x.dot(o)) * half.x + absf(g.basis.y.dot(o)) * half.y + absf(g.basis.z.dot(o)) * half.z
	return {"a": a, "b": b2, "mid": mid, "out": o, "skin": reach}


# --- Fitting out ----------------------------------------------------------------------------

## The kit the fit-out after ring `ring` sends for: power, then piping, in turn.
static func fitout_kit(ring: int) -> String:
	return FITOUT_KITS[(ring / FITOUT_EVERY) % FITOUT_KITS.size()]


## Sends for the fit-out's kit, brought to the lead fitter when it's wanted.
func _start_fitout() -> void:
	_fitout = {"order": -1, "t": 0.0, "ring": rings.size(), "kit": fitout_kit(rings.size())}
	if traffic:
		_fitout.order = int(traffic.call("deliver_kit", String(_fitout.kit), foreman(), false))


## Waits for the kit; once it's here, each part it brought is a member to set on the last ring.
func _step_fitout(delta: float) -> void:
	if ring_node != null:
		return
	_fitout.t = float(_fitout.t) + delta
	var o: Dictionary = traffic.call("kit_order", int(_fitout.order)) if traffic and int(_fitout.order) >= 0 else {}
	if o.is_empty() or (not bool(o.done) and float(_fitout.t) < fitout_wait):
		if o.is_empty() or float(_fitout.t) >= fitout_wait:
			fitted_out.append(int(_fitout.ring))
			_fitout = {}
		return
	var spots := _mount_spots()
	members.clear()
	for l: Dictionary in o.loads:
		if not is_instance_valid(l.node):
			continue
		l.kept = true   # the fitters set these: they don't go back
		for k in int(l.qty):
			var spot := _next_spot(spots, String(l.part))
			if spot.is_empty():
				break
			var m := {"part": l.part, "t": spot.t, "out": spot.out, "joints": spot.joints, "load": l}
			_ready_member(m)
			members.append(m)
	if members.is_empty():
		fitted_out.append(int(_fitout.ring))
		_fitout = {}
		return
	ring_node = rings.back()


## Places on the last ring for a fit-out's parts (ring space): big parts stand on the bottom
## beam, either side of the middle; small ones go on the uprights' inner faces. Each spot: its
## transform, the way out from its face and the bolts that hold it ({p, out, toward}).
func _mount_spots() -> Dictionary:
	var beam := AABB(-Vector3.ONE * ring_member.x * 0.5, Vector3.ONE * ring_member.x)   # a ring member's faces
	var h := RING * 0.5
	var big: Array = []
	for z: float in [-1.5, 1.5]:
		big.append([Basis(), Vector3(0, beam.end.y, z), Vector3.UP])
	var small: Array = []
	for y: float in [h - 0.9, h + 0.9]:
		small.append([Basis(), Vector3(0, y, -h + beam.end.z), Vector3.BACK])
		small.append([Basis(Vector3.UP, PI), Vector3(0, y, h - beam.end.z), Vector3.FORWARD])
	# Pipes stand up the bay's sides just behind the ring's uprights, clear of the linings.
	var pipes: Array = []
	for side: float in [-1.0, 1.0]:
		pipes.append([Basis(), Vector3(-0.4, h, side * (h - skin_gap - 0.45)), Vector3(0, 0, -side)])
	return {"big": big, "small": small, "pipe": pipes}


func _next_spot(spots: Dictionary, part: String) -> Dictionary:
	var size := _box(part).size
	var big := maxf(size.x, maxf(size.y, size.z)) >= 0.6
	var list: Array = spots.pipe if part == "Pipe" else (spots.big if big else spots.small)
	if list.is_empty():
		return {}
	var s: Array = list.pop_front()
	var basis: Basis = s[0]
	var contact: Vector3 = s[1]
	var normal: Vector3 = s[2]
	if part == "Pipe":
		# A pipe: a clamp bolted on at three points up its length, on the face towards the keel.
		var r := _box(part).size.x * 0.5
		var clamps: Array = []
		for y: float in [-1.4, 0.0, 1.4]:
			clamps.append({"p": contact + Vector3(0, y, 0) + normal * r, "out": normal, "toward": Vector3.UP, "n": 1})
		return {"t": Transform3D(basis, contact), "out": normal, "joints": clamps}
	var ab := Transform3D(basis, Vector3.ZERO) * _box(part)
	var half := absf(ab.size.dot(normal.abs())) * 0.5
	var at := contact - ab.get_center() + normal * half
	# Bolts at its foot: a small part one each side along the beam (or up the upright), a large
	# one at its four corners (TartanCo's rule: large objects take several bolts).
	var spread := Vector3(0, 0, 1) if normal == Vector3.UP else Vector3(0, 1, 0)
	var reach := maxf(0.12, absf(ab.size.dot(spread)) * 0.5 + 0.06)
	var side := normal.cross(spread).normalized()
	var joints: Array = []
	for sgn: float in [-1.0, 1.0]:
		if big:
			for k: float in [-1.0, 1.0]:
				joints.append({"p": contact + spread * sgn * reach + side * k * 0.07, "out": normal, "toward": -spread * sgn, "n": 1})
		else:
			joints.append({"p": contact + spread * sgn * reach, "out": normal, "toward": -spread * sgn, "n": 1})
	return {"t": Transform3D(basis, at), "out": normal, "joints": joints}


## A part's box in its own space.
func _box(part: String) -> AABB:
	var box := AABB()
	var first := true
	for l: Dictionary in Look.layers(part):
		var b: AABB = (l.mesh as Mesh).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


# --- Supplies --------------------------------------------------------------------------------

## Asks for a keel ring kit when the ring needs parts that no mover is holding and none is on
## its way.
func _keep_supplied() -> void:
	if traffic == null or ring_node == null:
		return
	if _order >= 0:
		var o: Dictionary = traffic.call("kit_order", _order)
		if not o.is_empty() and not bool(o.done):
			return
	var need := {}
	for m: Dictionary in members:
		if m.stage == "need":
			need[m.part] = int(need.get(m.part, 0)) + 1
	if need.is_empty():
		return
	for l: Dictionary in traffic.call("waiting_loads", supply):
		if need.has(l.part):
			need[l.part] = int(need[l.part]) - (int(l.qty) - int(l.get("promised", 0)))
	for part: String in need:
		if int(need[part]) > 0:
			_order = int(traffic.call("deliver_kit", _kit_for(part), supply, true))
			return


## The kit that brings `part`: the keel ring kit for the frame, the plating kit for the skin.
func _kit_for(part: String) -> String:
	for p: Dictionary in YardKits.parts(KIT):
		if p.part == part:
			return KIT
	for id: String in YardKits.ids():
		for p: Dictionary in YardKits.parts(id):
			if p.part == part:
				return id
	return KIT


## A load a mover is holding with a part of `part` not yet promised to a fitter.
func _load_with(part: String) -> Dictionary:
	if traffic == null:
		return {}
	for l: Dictionary in traffic.call("waiting_loads", supply):
		if l.part == part and int(l.qty) - int(l.get("promised", 0)) > 0:
			return l
	return {}


# --- Who does what -----------------------------------------------------------------------------

func _assign() -> void:
	for m: Dictionary in members:
		match String(m.stage):
			"need":
				if m.has("skin") and not _frame_done():
					continue
				var f := _idle("F")
				if f.is_empty():
					continue
				var l: Dictionary = m.load if m.has("load") and int(m.load.qty) > 0 else _load_with(m.part)
				if l.is_empty():
					m.waited = float(m.waited) + _step_dt
					if float(m.waited) < spare_after:
						continue
				elif not m.has("load"):
					l.promised = int(l.get("promised", 0)) + 1
				m.stage = "carry"
				m.fitter = f
				f.task = {"kind": "fit", "member": m, "load": l, "phase": "go", "t": 0.0}
			"held":
				var kind: String = (m.steps as Array)[int(m.step)]
				var w := _idle(TRADE[kind])
				if w.is_empty():
					continue
				m.stage = "working"
				match kind:
					"weld":
						w.task = {"kind": "weld", "member": m, "joints": _weld_joints(m), "phase": "go", "t": 0.0}
					"rivet":
						w.task = {"kind": "rivet", "member": m, "spots": _rivet_spots(m), "phase": "go", "t": 0.0}
					_:
						w.task = {"kind": "bolt", "member": m, "joints": _bolt_joints(m), "phase": "go", "t": 0.0, "bolt": 0}
				w.task.of = (w.task.get("joints", w.task.get("spots", [])) as Array).size()


func _idle(role: String) -> Dictionary:
	for w: Dictionary in workers:
		if w.role == role and (w.task as Dictionary).is_empty() and w.fault == "" and not bool(w.servicing) \
				and not bool(w.low):
			return w
	return {}


## Where a worker hangs about between jobs: just off the front ring, out of the way.
func _idle_spot(i: int) -> Vector3:
	var side := 1.0 if i % 2 == 0 else -1.0
	return _front() + Vector3(KEEL_STEP * 0.8, RING * 0.5 + (float(i / 2) - 1.0) * 1.8, side * (RING * 0.5 + 2.4))


# --- Doing it -------------------------------------------------------------------------------

func _work(w: Dictionary, delta: float) -> void:
	var node: Node3D = w.node
	var task: Dictionary = w.task
	var busy := true
	if w.has("sparks") and not (w.sparks as CPUParticles3D).one_shot:
		(w.sparks as CPUParticles3D).emitting = false
	if w.has("light"):
		(w.light as OmniLight3D).light_energy = 0.0
	var label := node.get_node("Fault") as Label3D
	label.visible = w.fault != "" and fmod(_time, 1.0) < 0.7
	if bool(w.get("external", false)):
		# The maintenance ship has it: it's theirs to move; its arms hang.
		(node.get_node("Thrust") as Node3D).visible = false
		return
	delta *= float(w.speed)
	if not task.is_empty() and bool(w.charging):
		# A new job: each bot is slow or quick to come off its dock, so they never go together.
		if not task.has("began"):
			task.began = _time + _rng.randf_range(0.2, 2.5)
		if _time < float(task.began):
			task = {}
		else:
			w.charging = false
			w.route = []
	if task.is_empty() and bool(w.charging):
		busy = false
		_charge(w, delta)
	elif task.is_empty():
		busy = false
		_fly(w, _idle_spot(int(w.index)), delta)
		if w.fault != "" or bool(w.servicing):
			# Stopped: arms hanging, waiting on TartanCo, a slow tumble if it's faulted.
			_face(node, node.global_position + Vector3(0.3, -0.25 if w.fault != "" else 0.0, -1.0), delta * 0.3)
		else:
			_face(node, _axis(), delta)
		WorkerLook.rest(node, "R")
		WorkerLook.rest(node, "L")
		var sway := sin(_time * 0.7 + float(w.index))
		WorkerLook.tuck(node, "R", sway)
		WorkerLook.tuck(node, "L", -sway)
	else:
		match String(task.kind):
			"fit":
				_fit(w, task, delta)
			"weld":
				_weld(w, task, delta)
			"rivet":
				_rivet(w, task, delta)
			"bolt":
				_bolt(w, task, delta)
	if w.role == "F":
		WorkerLook.aim_laser(node, task.get("laser") if not task.is_empty() else null)
	(node.get_node("Thrust") as Node3D).visible = (w.vel as Vector3).length() > 0.6
	var head := node.get_node("Head") as Node3D
	var bow := -0.25 if busy else (-0.4 if _docked(w) else 0.0)
	head.rotation.x = lerpf(head.rotation.x, bow, minf(1.0, delta * 3.0))
	WorkerLook.lay_hose(node)


# --- Charging -------------------------------------------------------------------------------

## Where bot `i` hangs on its dock (station space).
func dock_spot(i: int) -> Vector3:
	return DOCKS[i] + Vector3(0, 0, -WorkerLook.DOCK_OUT)


## A bot with its job done and nothing else on it goes back to its dock to top up; one run low
## stays there till it's full.
func _send_to_charge() -> void:
	for w: Dictionary in workers:
		if float(w.charge) <= recharge_at:
			w.low = true
		if bool(w.charging) or not (w.task as Dictionary).is_empty() \
				or w.fault != "" or bool(w.servicing) or bool(w.get("external", false)):
			continue
		w.charging = true
		var spot := dock_spot(int(w.index))
		w.route = [spot + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.4, 0.4), -3.0), spot]


## True while the bot hangs on its dock.
func _docked(w: Dictionary) -> bool:
	return bool(w.charging) and (w.route as Array).is_empty()


## To its dock along its route, then hangs there charging; full, it leaves out in front of the
## wall.
func _charge(w: Dictionary, delta: float) -> void:
	var node: Node3D = w.node
	var route: Array = w.route
	if not route.is_empty():
		if _fly(w, route[0], delta):
			route.pop_front()
		if route.size() <= 1:
			_face(node, node.global_position + Vector3.FORWARD, delta)
		else:
			_face(node, route[0], delta)
		WorkerLook.rest(node, "R")
		WorkerLook.rest(node, "L")
		WorkerLook.tuck(node, "R")
		WorkerLook.tuck(node, "L")
		return
	node.position = dock_spot(int(w.index))
	w.vel = Vector3.ZERO
	_face(node, node.global_position + Vector3.FORWARD, delta)
	WorkerLook.hang(node)
	w.charge = minf(1.0, float(w.charge) + delta * float(_fx(w).charge) / maxf(charge_seconds, 0.1))
	if float(w.charge) >= 1.0:
		w.low = false


## Flies towards `to`, easing in; true once there.
func _fly(w: Dictionary, to: Vector3, delta: float) -> bool:
	var node: Node3D = w.node
	var gap := to - node.position
	var fly := float(_fx(w).fly) / float(_fx(w).pace)   # its pace already sped the step up
	var want := gap.limit_length(minf(fly_speed * float(w.get("speed", 1.0)) * fly, gap.length() * 1.6 + 0.1))
	w.vel = (w.vel as Vector3).lerp(want, minf(1.0, delta * 3.0))
	node.position += (w.vel as Vector3) * delta
	if gap.length() < 0.08:
		node.position = to
		w.vel = Vector3.ZERO
		return true
	return false


## Turns to face `at` (station space), slowly.
func _face(node: Node3D, at: Vector3, delta: float) -> void:
	var f := at - node.global_position
	if f.length() < 0.05:
		return
	f = f.normalized()
	var up := Vector3.UP if absf(f.y) < 0.75 else Vector3.RIGHT
	var want := Basis.looking_at(f, up).get_rotation_quaternion()
	var now := node.global_basis.get_rotation_quaternion()
	node.global_basis = Basis(now.slerp(want, minf(1.0, delta * 2.5)))


## A fitter: to the mover, takes a part, carries it to the ring, eases it into place and holds
## it till it's welded.
func _fit(w: Dictionary, task: Dictionary, delta: float) -> void:
	var node: Node3D = w.node
	var m: Dictionary = task.member
	var l: Dictionary = task.load
	var sway := sin(_time * 0.9 + float(w.index)) * 0.5
	WorkerLook.tuck(node, "R", sway)
	WorkerLook.tuck(node, "L", -sway)
	task.erase("laser")
	match String(task.phase):
		"go":
			var at := supply.global_position if l.is_empty() or not is_instance_valid(l.node) else (l.node as Node3D).global_position
			var stand := at + Vector3(-1.9, 0.6, 0)
			_face(node, at, delta)
			WorkerLook.reach(node, "R", at + Vector3(-0.2, 0.15, -0.5), (at - node.global_position).normalized())
			WorkerLook.reach(node, "L", at + Vector3(-0.2, 0.15, 0.5), (at - node.global_position).normalized())
			if _fly(w, stand, delta):
				task.t = float(task.t) + delta
				if float(task.t) > 0.6:
					var piece: Node3D = traffic.call("take_piece", l) if not l.is_empty() else null
					if not l.is_empty():
						l.promised = maxi(0, int(l.get("promised", 0)) - 1)
						if int(l.qty) <= 0 and l.get("where") == "delivered":
							traffic.call("consume", l)
					if piece == null:
						piece = _spare(m.part, at)
					piece.reparent(self, true)
					_dress(piece, m)
					m.piece = piece
					task.from = piece.global_transform
					task.phase = "carry"
					task.t = 0.0
		"carry":
			var piece: Node3D = m.piece
			var s := _span(m)
			# Off to the part's side, so the trades who fasten it have its face to themselves.
			var across := (s.out as Vector3).cross(((s.b as Vector3) - (s.a as Vector3)).normalized()).normalized()
			var stand: Vector3 = s.mid + (s.out as Vector3) * 1.5 + across * 1.6
			var arrived := _fly(w, stand, delta)
			_face(node, s.mid, delta)
			task.t = minf(1.0, float(task.t) + delta / 0.8)
			var held := node.global_transform * Transform3D(Basis(), Vector3(0, 0.7, -1.25))
			piece.global_transform = (task.from as Transform3D).interpolate_with(held, _ease(float(task.t)))
			_hold(node, piece, m)
			if arrived and float(task.t) >= 1.0:
				task.phase = "fit"
				task.from = piece.global_transform
				task.t = 0.0
		"fit":
			var piece: Node3D = m.piece
			task.t = minf(1.0, float(task.t) + delta / fit_seconds)
			var final := ring_node.global_transform * (m.t as Transform3D)
			piece.global_transform = (task.from as Transform3D).interpolate_with(final, _ease(float(task.t)))
			_face(node, _span(m).mid, delta)
			_hold(node, piece, m)
			# The alignment laser on the part's place while it eases in.
			task.laser = final * _centre(m)
			if float(task.t) >= 1.0:
				piece.reparent(ring_node, true)
				m.stage = "held"
				task.phase = "hold"
		"hold":
			if bool(m.fixed) or m.stage == "done" or ring_node == null:
				_job_done(w)
				return
			_face(node, _span(m).mid, delta)
			_hold(node, m.piece, m)


## Both grippers on the part, half a metre either side of its middle, from its near side.
func _hold(node: Node3D, piece: Node3D, m: Dictionary) -> void:
	var g := piece.global_transform
	var along := g.basis.x.normalized()
	if along.dot(node.global_basis.x) < 0.0:
		along = -along
	var mid := g * _centre(m)
	var into := (mid - node.global_position).normalized()
	var skin := 0.12
	WorkerLook.reach(node, "R", mid + along * 0.55 - into * skin, into)
	WorkerLook.reach(node, "L", mid - along * 0.55 - into * skin, into)


func _centre(m: Dictionary) -> Vector3:
	var layers: Array = _layers_of(m)
	return (layers[0].mesh as Mesh).get_aabb().get_center() if not layers.is_empty() else Vector3.ZERO


## A part from the berth's own stock, when the stores have none to send.
func _spare(part: String, at: Vector3) -> Node3D:
	var piece := Node3D.new()
	piece.name = "Spare_%s" % part
	add_child(piece)
	piece.global_position = at
	for l: Dictionary in Look.layers(part):
		var mi := MeshInstance3D.new()
		mi.mesh = l.mesh
		mi.material_override = l.material
		piece.add_child(mi)
	return piece


## A welder: to each end of the part, then the arc run across the joint, sparks flying, the
## other hand braced on the part.
func _weld(w: Dictionary, task: Dictionary, delta: float) -> void:
	var node: Node3D = w.node
	var m: Dictionary = task.member
	var joints: Array = task.joints
	if joints.is_empty():
		_fastened(m)
		_job_done(w)
		return
	var j: Dictionary = joints[0]
	var out: Vector3 = j.out
	var inward: Vector3 = j.inward
	var face: Vector3 = j.face
	var across: Vector3 = j.across
	var half := float(j.half)
	var there := _brace(w, face, out, -inward, delta)
	WorkerLook.reach(node, "L", face + inward * 0.45 - node.global_basis.x * 0.3 + out * 0.04, -out)
	match String(task.phase):
		"go":
			WorkerLook.reach(node, "R", face + out * 0.35 + across * 0.2, -out)
			if there:
				task.phase = "arc"
				task.t = 0.0
		"arc":
			task.t = float(task.t) + delta
			var k := clampf(float(task.t) / weld_seconds, 0.0, 1.0)
			var tip := face + across * lerpf(-half, half, k)
			WorkerLook.reach(node, "R", tip, (-out + inward * 0.3).normalized())
			var arc_at := WorkerLook.tip_of(node, "R")
			_weld_shower(w, arc_at, out, across * (1.0 if k < 1.0 else -1.0), delta)
			var flick := 0.5 + 0.5 * sin(_time * 47.0) * sin(_time * 31.0 + float(w.index))
			var light: OmniLight3D = w.light
			light.global_position = arc_at + out * 0.3
			light.light_energy = 1.4 + flick * 2.2
			if float(task.t) >= weld_seconds:
				_bead(face - across * half, face + across * half, out)
				joints.pop_front()
				task.phase = "go"
				task.t = 0.0


## A riveter: along the part, at each spot the gun builds pressure, then punches a rivet home
## with a kick and a flash.
func _rivet(w: Dictionary, task: Dictionary, delta: float) -> void:
	var node: Node3D = w.node
	var m: Dictionary = task.member
	var spots: Array = task.spots
	if spots.is_empty():
		_fastened(m)
		_job_done(w)
		return
	var spot: Dictionary = spots[0]
	var out: Vector3 = spot.out
	var face: Vector3 = spot.face
	var along: Vector3 = spot.along
	var there := _brace(w, face, out, along, delta)
	WorkerLook.reach(node, "L", face - along * 0.35 - node.global_basis.x * 0.25 + out * 0.03, -out)
	match String(task.phase):
		"go":
			WorkerLook.reach(node, "R", face + out * 0.3, -out)
			if there:
				task.phase = "press"
				task.t = 0.0
		"press":
			task.t = float(task.t) + delta
			var punch := rivet_seconds * 0.75
			var kick := 0.0
			var light: OmniLight3D = w.light
			if float(task.t) < punch:
				# Building pressure: the gun pressed on, trembling a little.
				kick = -0.01 + 0.006 * sin(_time * 90.0)
			else:
				var k := (float(task.t) - punch) / (rivet_seconds - punch)
				kick = 0.14 * (1.0 - k) * (1.0 - k)
				if not task.has("fired"):
					task.fired = true
					_rivet_head(face, out)
					_spray(w, face + out * 0.03, out)
					_rivet_burst(face, out, along)
				light.global_position = face + out * 0.3
				light.light_energy = 3.0 * (1.0 - k)
			WorkerLook.reach(node, "R", face, -out, kick)
			if float(task.t) >= rivet_seconds:
				spots.pop_front()
				task.erase("fired")
				task.phase = "go"
				task.t = 0.0


## Where a bolter runs bolts in: for a girder, its two ends on its outer face; for a fitted part,
## the spots its mount gave. Each {p (global), out, toward}.
func _bolt_joints(m: Dictionary) -> Array:
	var out: Array = []
	if m.has("joints"):
		for j: Dictionary in m.joints:
			out.append({"p": ring_node.global_transform * (j.p as Vector3), "out": ring_node.global_basis * (j.out as Vector3),
					"toward": ring_node.global_basis * (j.toward as Vector3), "n": int(j.get("n", bolts_per_joint))})
		return out
	var s := _span(m)
	for end: Vector3 in [s.a, s.b]:
		var inward := ((s.mid as Vector3) - end).normalized()
		out.append({"p": end + inward * 0.18 + (s.out as Vector3) * float(s.skin), "out": s.out, "toward": -inward})
	return out


## Where a welder runs a bead (each {face, out, inward (into the part), across (the bead's line),
## half (its half length)}, global): a beam or girder across each end where it meets the frame; a
## hull plate a short seam along one long edge.
func _weld_joints(m: Dictionary) -> Array:
	var out: Array = []
	if m.part == "HullPlate":
		var g: Transform3D = ring_node.global_transform * (m.t as Transform3D)
		var box := _box(m.part)
		var o := g.basis.y.normalized()
		var inward := -g.basis.x.normalized()
		var edge := g * Vector3(box.end.x, box.end.y, box.get_center().z)
		out.append({"face": edge + o * 0.02 + inward * 0.06, "out": o, "inward": inward,
				"across": g.basis.z.normalized(), "half": seam_length * 0.5})
		return out
	var s := _span(m)
	for end: Vector3 in [s.a, s.b]:
		var o: Vector3 = s.out
		var inward := ((s.mid as Vector3) - end).normalized()
		out.append({"face": end + o * (float(s.skin) + 0.02) + inward * 0.06, "out": o, "inward": inward,
				"across": o.cross(inward).normalized(), "half": 0.16})
	return out


## Where a riveter sets rivets (each {face, out, along}, global): a plate's four corners, set in
## from its edges.
func _rivet_spots(m: Dictionary) -> Array:
	var out: Array = []
	var g: Transform3D = ring_node.global_transform * (m.t as Transform3D)
	var box := _box(m.part)
	var o := g.basis.y.normalized()
	var c := box.get_center()
	var hx := box.size.x * 0.5 - corner_inset
	var hz := box.size.z * 0.5 - corner_inset
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p := g * Vector3(c.x + corner.x * hx, box.end.y, c.z + corner.y * hz)
		out.append({"face": p + o * 0.01, "out": o, "along": g.basis.z.normalized()})
	return out


## A bolter: clamped on beside each joint, the nut runner on each bolt in turn: it seats, spins
## it home (the socket turning) and leaves a bolt head and washer.
func _bolt(w: Dictionary, task: Dictionary, delta: float) -> void:
	var node: Node3D = w.node
	var m: Dictionary = task.member
	var joints: Array = task.joints
	if joints.is_empty():
		_fastened(m)
		_job_done(w)
		return
	var j: Dictionary = joints[0]
	var bolts := int(j.get("n", bolts_per_joint))
	var out: Vector3 = (j.out as Vector3).normalized()
	var toward: Vector3 = j.toward
	var across := out.cross(toward).normalized()
	var k := int(task.bolt)
	var offset := (float(k) - (bolts - 1) * 0.5) * 0.09
	var face: Vector3 = (j.p as Vector3) + across * offset + out * 0.01
	var there := _brace(w, j.p, out, toward, delta)
	WorkerLook.reach(node, "L", (j.p as Vector3) - toward * 0.3 - node.global_basis.x * 0.25 + out * 0.03, -out)
	match String(task.phase):
		"go":
			WorkerLook.reach(node, "R", face + out * 0.3, -out)
			if there:
				task.phase = "run"
				task.t = 0.0
		"run":
			task.t = float(task.t) + delta
			var f := clampf(float(task.t) / bolt_seconds, 0.0, 1.0)
			# Seat it, then spin it down; the hand turns with the socket.
			WorkerLook.reach(node, "R", face + out * (0.06 * (1.0 - f)), -out)
			WorkerLook.spin_socket(node, float(task.t) * 30.0)
			var light: OmniLight3D = w.light
			light.global_position = face + out * 0.4
			light.light_energy = 0.6 if f > 0.2 else 0.0
			if f > 0.2:
				_spray(w, face + out * 0.05, out)
				(w.sparks as CPUParticles3D).emitting = true
			if float(task.t) >= bolt_seconds:
				_bolt_head(face, out)
				task.bolt = k + 1
				task.t = 0.0
				if int(task.bolt) >= bolts:
					joints.pop_front()
					task.bolt = 0
					task.phase = "go"


## Clamps a trade to the work: its feet on the surface at `face` (whose way out is `out`), facing
## along `toward` and leaning into it, pelvis `brace_height` up. Flies there first (legs tucked);
## true once it's clamped on.
func _brace(w: Dictionary, face: Vector3, out: Vector3, toward: Vector3, delta: float) -> bool:
	var node: Node3D = w.node
	var up := out.normalized()
	var fwd := toward - up * up.dot(toward)
	fwd = fwd.normalized() if fwd.length() > 0.01 else up.cross(Vector3.RIGHT).normalized()
	var z := -fwd
	var basis := Basis(up.cross(z).normalized(), up, z)
	basis = Basis(basis.x, -brace_lean) * basis
	var at := face + up * brace_height - fwd * 0.92
	var there := _fly(w, at, delta)
	var now := node.global_basis.get_rotation_quaternion()
	node.global_basis = Basis(now.slerp(basis.get_rotation_quaternion(), minf(1.0, delta * 3.0)))
	if node.global_position.distance_to(at) < 0.35:
		var x := up.cross(z).normalized()
		# Feet staggered along the member's line, magnetic clamps on its face.
		WorkerLook.plant(node, "R", face - fwd * 0.42 + x * 0.1, -up, fwd)
		WorkerLook.plant(node, "L", face - fwd * 0.86 - x * 0.1, -up, fwd)
	else:
		WorkerLook.tuck(node, "R")
		WorkerLook.tuck(node, "L")
	return there and node.global_basis.get_rotation_quaternion().angle_to(basis.get_rotation_quaternion()) < 0.15


func _bolt_head(at: Vector3, out: Vector3) -> void:
	if _bolt_mesh == null:
		_bolt_mesh = CylinderMesh.new()
		_bolt_mesh.top_radius = 0.024
		_bolt_mesh.bottom_radius = 0.024
		_bolt_mesh.height = 0.035
		_bolt_mesh.radial_segments = 6
		_bolt_mesh.rings = 1
	var y := out.normalized()
	var x := y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).normalized()
	var washer := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.04
	wm.bottom_radius = 0.04
	wm.height = 0.006
	wm.radial_segments = 12
	wm.rings = 1
	washer.mesh = wm
	washer.material_override = _rivet_material()
	ring_node.add_child(washer)
	washer.global_transform = Transform3D(Basis(x, y, x.cross(y)), at + y * 0.003)
	var head := MeshInstance3D.new()
	head.mesh = _bolt_mesh
	head.material_override = _rivet_material()
	ring_node.add_child(head)
	head.global_transform = Transform3D(Basis(x, y, x.cross(y)), at + y * 0.024)


## A weld bead left across the joint: a dark, slightly glossy ridge.
func _bead(a: Vector3, b: Vector3, out: Vector3) -> void:
	var bead := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.035
	mesh.height = a.distance_to(b) + 0.07
	mesh.radial_segments = 10
	mesh.rings = 2
	bead.mesh = mesh
	bead.material_override = _rivet_material()
	ring_node.add_child(bead)
	var y := (b - a).normalized()
	var x := out.cross(y).normalized()
	bead.global_transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)


func _rivet_head(at: Vector3, out: Vector3) -> void:
	if _rivet_mesh == null:
		_rivet_mesh = CylinderMesh.new()
		_rivet_mesh.top_radius = 0.025
		_rivet_mesh.bottom_radius = 0.04
		_rivet_mesh.height = 0.03
		_rivet_mesh.radial_segments = 12
		_rivet_mesh.rings = 1
	var head := MeshInstance3D.new()
	head.mesh = _rivet_mesh
	head.material_override = _rivet_material()
	ring_node.add_child(head)
	var y := out.normalized()
	var x := y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).normalized()
	head.global_transform = Transform3D(Basis(x, y, x.cross(y)), at + y * 0.01)


func _rivet_material() -> StandardMaterial3D:
	if _rivet_mat == null:
		_rivet_mat = StandardMaterial3D.new()
		_rivet_mat.albedo_color = Color(0.32, 0.32, 0.34)
		_rivet_mat.metallic = 0.85
		_rivet_mat.roughness = 0.35
	return _rivet_mat


## Sparks for each trade, flung out and drifting on (zero g: no fall), white hot to orange to
## dark: the welder's torch a constant spray, the riveter's gun a burst at each rivet, the
## bolter's runner a fizz while the nut bites.
func make_sparks(role := "W") -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Sparks"
	p.emitting = false
	p.direction = Vector3.UP
	p.gravity = Vector3.ZERO
	p.local_coords = false
	p.damping_min = 0.5
	p.damping_max = 2.0
	match role:
		"W":
			p.amount = 260
			p.lifetime = 1.1
			p.spread = 75.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 8.0
			p.scale_amount_min = 0.012
			p.scale_amount_max = 0.035
		"R":
			p.amount = 110
			p.lifetime = 0.8
			p.one_shot = true
			p.explosiveness = 0.9
			p.spread = 85.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 10.0
			p.scale_amount_min = 0.012
			p.scale_amount_max = 0.03
		_:
			p.amount = 90
			p.lifetime = 0.6
			p.spread = 60.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 5.0
			p.scale_amount_min = 0.008
			p.scale_amount_max = 0.02
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.97, 0.85))
	ramp.set_color(1, Color(0.6, 0.12, 0.02, 0.0))
	ramp.add_point(0.35, Color(1.0, 0.7, 0.25))
	p.color_ramp = ramp
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2)
	mat.emission_energy_multiplier = 3.0
	m.material = mat
	p.mesh = m
	return p


## Points a bot's sparks out of the work at `at` along `out`; the riveter's burst fires once.
func _spray(w: Dictionary, at: Vector3, out: Vector3) -> void:
	if not w.has("sparks"):
		return
	var p: CPUParticles3D = w.sparks
	var y := out.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	p.global_transform = Transform3D(Basis(x, y, x.cross(y)), at)
	if p.one_shot:
		p.restart()
		p.emitting = true


## How many of a thing are due this step at `rate` a second (the remainder carried over), for
## worker `key`.
func _due(key: String, rate: float, delta: float) -> int:
	var owed := float(_owed.get(key, 0.0)) + rate * delta
	var n := int(owed)
	_owed[key] = owed - n
	return n


## The welder's arc, thrown like the grinder's spray (beenster, 19 Nov: "should be as good as
## the grinder"): a dense fan of streaking sparks off the pool, many forking into stars, molten
## globs that stick and glow where they land, and a little smoke.
func _weld_shower(w: Dictionary, at: Vector3, out: Vector3, run: Vector3, delta: float) -> void:
	if spray == null:
		return
	var n := out.normalized()
	var t := run.normalized() if run.length() > 0.01 else n.cross(Vector3.UP).normalized()
	var axis := t.cross(n).normalized()
	var from := at + n * 0.02
	var key := "weld%d" % int(w.index)
	var hot := Color(1.0, 0.85, 0.45)
	for k in _due(key, weld_spark_rate, delta):
		# Most fly out off the pool in a wide cone; some skid back along the seam.
		var lift := deg_to_rad(randf_range(-4.0, 6.0) if randf() < 0.25 else randf_range(15.0, 80.0))
		var swing := randf_range(-PI, PI)
		var side := t * cos(swing) + axis * sin(swing)
		var d := (side * cos(lift) + n * sin(lift)).normalized()
		var life := randf_range(0.35, 1.1)
		var fork := randf_range(0.2, 0.55) * life if randf() < 0.18 else -1.0
		spray.shower(from, d * randf_range(3.5, 10.0), life, hot if randf() < 0.7 else Color(1.0, 0.97, 0.85), fork)
	for k in _due(key + "glob", weld_spark_rate * 0.05, delta):
		var d := (n * randf_range(0.3, 1.0) + t * randf_range(-0.8, 0.8) + axis * randf_range(-0.8, 0.8)).normalized()
		spray.glob(from, d * randf_range(1.5, 4.5), randf_range(1.0, 2.2), Color(1.0, 0.55, 0.15), randf_range(0.004, 0.012))
	for k in _due(key + "smoke", 6.0, delta):
		spray.dust(from + n * 0.05, (n * 0.35 + axis * randf_range(-0.1, 0.1)) * randf_range(0.3, 0.7), Color(0.75, 0.75, 0.72))


## A rivet slammed through the plate (beenster, 19 Nov: "spray metal particles, steam and some
## sparks"): a ring of swarf and flakes flung off the plate, a few sparks, and a burst of steam
## from the hot rivet.
func _rivet_burst(at: Vector3, out: Vector3, along: Vector3) -> void:
	if spray == null:
		return
	var n := out.normalized()
	var t := along.normalized()
	var axis := t.cross(n).normalized()
	var from := at + n * 0.02
	for k in rivet_chips:
		var a := randf_range(0.0, TAU)
		var d := ((t * cos(a) + axis * sin(a)) * randf_range(0.6, 1.0) + n * randf_range(0.2, 0.9)).normalized()
		var grey := randf_range(0.45, 0.8)
		spray.chip(from, d * randf_range(1.0, 4.0), randf_range(1.5, 3.0), Color(grey, grey, grey * 1.04), randf_range(0.003, 0.009), 30.0)
	for k in rivet_sparks:
		var a := randf_range(0.0, TAU)
		var d := ((t * cos(a) + axis * sin(a)) + n * randf_range(0.1, 0.6)).normalized()
		spray.shower(from, d * randf_range(3.0, 8.0), randf_range(0.2, 0.55), Color(1.0, 0.8, 0.4))
	for k in rivet_steam:
		var a := randf_range(0.0, TAU)
		spray.dust(from + n * 0.04, (n * randf_range(0.4, 0.9) + (t * cos(a) + axis * sin(a)) * 0.35) * randf_range(0.5, 1.2),
				Color(0.95, 0.96, 1.0))


static func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
