extends ModuleTest
## Game time's pace in the yard (19 Nov): a "rate" entry in the shared log changes how far each
## tick moves the yard's work on from its tick, the same on every machine; paused holds the
## work but not the airlocks; the host stamps a change into the log, and a late joiner gets the
## pace the clock started at.
##   tools/run_tests.sh yard

const YardSimRef := preload("res://modules/yard/internal/yard_sim.gd")


class Stepper:
	extends Node
	var total := 0.0
	func step(delta: float) -> void:
		total += delta
	func advance(delta: float) -> void:
		total += delta


func run_tests() -> void:
	_yard_pace()


## The yard's clock: a "rate" entry changes how far each tick moves things on, from its tick;
## paused holds the work but not the locks; the host stamps it into the shared log.
func _yard_pace() -> void:
	var sim: Node = YardSimRef.new()
	var worker := Stepper.new()
	var lock := Stepper.new()
	sim.steppers.append(worker)
	sim.advancers.append(lock)
	add_child(sim)
	sim.call("_enqueue", {"kind": "rate", "rate": 2.0, "tick": 10, "n": 1})
	sim.call("_enqueue", {"kind": "rate", "rate": 0.0, "tick": 20, "n": 2})
	sim.call("run_ticks", 30)
	var tick := 1.0 / 60.0
	check(is_equal_approx(worker.total, 10 * tick + 20 * tick), "ten ticks at x1, ten at x2, ten paused (%.4f s)" % worker.total)
	check(is_equal_approx(lock.total, 30 * tick), "the locks run at their own pace throughout")
	sim.queue_free()
	var yard := YardBus.new()
	add_child(yard)
	yard.set_sim_rate(2.0)
	check(yard.sim_log.is_empty() and is_equal_approx(yard.sim_rate, 2.0), "before the yard opens the pace waits for its clock")
	yard.sim_start()
	check(is_equal_approx(yard.sim_epoch_rate, 2.0), "the clock starts at that pace")
	yard.set_sim_rate(4.0)
	check(yard.sim_log.size() == 1 and str(yard.sim_log[0].kind) == "rate" and is_equal_approx(float(yard.sim_log[0].rate), 4.0),
			"a change once it runs goes into the shared log")
	check(is_equal_approx(float(yard.get_net_snapshot().rate), 2.0), "a late joiner gets the starting pace with the log")
	yard.queue_free()
