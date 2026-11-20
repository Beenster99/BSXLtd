extends Node
## The yard's shared clock (0.4.2 co-op playtest: "the maintenance ship came in 30 seconds
## late on my friend's PC", "mover bots aren't synchronised", "the airlock doesn't sync").
## Everything that runs on its own in the yard (the stores' haulers and mover bots, the worker
## crew and TartanCo's visits, the two airlocks) moves on here in fixed ticks counted from one
## moment every player agrees on: YardBus.sim_epoch, on the host's clock. What players do to
## it (calling a kit, starting a contract, pressing an airlock button) goes to the host, which
## stamps it with a tick a little ahead, and every machine applies it at that tick. So a player
## who joins (or comes into the yard) later replays from tick 0 and catches up to the same yard.
##
## Things that follow a player (a mover bringing you a kit) follow where that player is drawn on
## each machine, a moment behind on the others; that much can differ.

const TICK := 1.0 / 60.0
## Time spent stepping in one frame (ms), and while catching up (a late joiner replaying).
const FRAME_BUDGET_MS := 8.0
const CATCH_UP_BUDGET_MS := 40.0
## Behind by more than this many ticks counts as catching up.
const BEHIND := 30

## Calls `apply(entry)` for each logged event at its tick (the station's _apply_sim).
var apply: Callable
## What to step: nodes with step(delta) (traffic, workers) and with advance(delta) (locks).
var steppers: Array[Node] = []
var advancers: Array[Node] = []
## Ticks run since the epoch.
var tick := 0
## The pace (Game time): each tick moves things on by TICK * rate (0 holds them; the locks
## always run at their own pace, so nobody is shut in an airlock while time is paused).
var rate := 1.0
## True while well behind the shared clock (replaying after joining).
var catching_up := false

var _bus: Object
var _queue: Array[Dictionary] = []


## `bus`: the YardBus (it holds the epoch and the log); null runs on a local clock (tests).
func setup(bus: Object) -> void:
	_bus = bus
	for n in steppers:
		n.set_process(false)
	for n in advancers:
		n.set_physics_process(false)
	if _bus:
		_take_log()
		_bus.connect("sim_logged", _enqueue)


func _exit_tree() -> void:
	if _bus and is_instance_valid(_bus) and _bus.is_connected("sim_logged", _enqueue):
		_bus.disconnect("sim_logged", _enqueue)


## Takes the log afresh (the clock started again before anything ran here).
func restart() -> void:
	_queue.clear()
	tick = 0
	rate = 1.0
	if _bus:
		_take_log()


## The tick everything should be at now, or -1 while the shared clock is not known yet.
func target_tick() -> int:
	if _bus == null:
		return tick + 1
	return int(_bus.call("sim_target_tick"))


func _process(_delta: float) -> void:
	var target := target_tick()
	if target < 0:
		return
	var start := Time.get_ticks_usec()
	var limit := (CATCH_UP_BUDGET_MS if target - tick > BEHIND else FRAME_BUDGET_MS) * 1000.0
	while tick < target:
		run_tick()
		if Time.get_ticks_usec() - start > limit:
			break
	catching_up = target - tick > BEHIND


## One tick: the events due, then everything moved on by TICK at the pace (the locks by TICK).
func run_tick() -> void:
	while not _queue.is_empty() and int(_queue[0].tick) <= tick:
		var e: Dictionary = _queue.pop_front()
		if String(e.get("kind", "")) == "rate":
			rate = maxf(0.0, float(e.get("rate", 1.0)))
		elif apply.is_valid():
			apply.call(e)
	if rate > 0.0:
		for n in steppers:
			if is_instance_valid(n):
				n.call("step", TICK * rate)
	for n in advancers:
		if is_instance_valid(n):
			n.call("advance", TICK)
	tick += 1


## Runs `count` ticks straight away (tests).
func run_ticks(count: int) -> void:
	for i in count:
		run_tick()


## The racks' stock and the crew as they stood at tick 0 first, then everything logged since.
func _take_log() -> void:
	rate = float(_bus.get("sim_epoch_rate"))
	_enqueue({"kind": "stock", "tick": 0, "n": -2, "stock": (_bus.get("sim_stock") as Dictionary).duplicate(true)})
	_enqueue({"kind": "fleet", "tick": 0, "n": -1, "state": (_bus.get("sim_fleet") as Array).duplicate(true)})
	for e: Dictionary in _bus.get("sim_log"):
		_enqueue(e)


## Files a logged event by tick, then the host's order (an event logged late, for a tick
## already run, goes at the front and is applied on the next tick).
func _enqueue(e: Dictionary) -> void:
	var at := _queue.size()
	while at > 0 and _after(_queue[at - 1], e):
		at -= 1
	_queue.insert(at, e)


static func _after(a: Dictionary, b: Dictionary) -> bool:
	if int(a.tick) != int(b.tick):
		return int(a.tick) > int(b.tick)
	return int(a.get("n", 0)) > int(b.get("n", 0))
