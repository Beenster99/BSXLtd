extends ModuleTest
## A contract can always be finished, and every player sees the same board (0.3.19
## playtest): work starts by itself once the subject or the parts are in, so MARK JOB
## COMPLETE is open; a handover with client wants unmet still closes, each miss a snag and a
## cut to the quality the pay follows; the host's board round-trips as the snapshot and the
## sync event, and a player's board actions are validated like the host would.
##   tools/run_tests.sh contracts


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "contracts.board": true, "contracts.kinds": true,
			"contracts.clients": true, "shared_components": true})
	Modules.load_all()
	var bus := Modules.bus("contracts") as ContractsBus
	check(bus != null, "contracts loads")
	if bus:
		_test_part_job(bus)
		_test_fit_job(bus)
		_test_sync(bus)
	Flags.use(saved)
	Modules.load_all()


func _test_part_job(bus: ContractsBus) -> void:
	const BREAK := "tpa.sb301"
	var states: Array[String] = []
	bus.job_state_changed.connect(func(id: String, _f: String, to: String) -> void:
		if id == BREAK:
			states.append(to))
	check(bus.accept(BREAK), "accept the break job")
	check(bus.get_job(BREAK).state == ContractJob.ARRIVING, "the turret is on its way")
	check(bus.subject_landed(BREAK), "Ship and Bay lands it")
	check(bus.get_job(BREAK).state == ContractJob.IN_PROGRESS, "and work is under way at once: %s" % bus.get_job(BREAK).state)
	check(states == ["accepted", "arriving", "parts_ready", "in_bay", "in_progress"], "every step was announced: %s" % str(states))
	check(bus.advance(BREAK, ContractJob.INSPECTION), "the crew marks it complete")
	var handed: Array = []
	bus.contract_handed_over.connect(func(id: String, q: float, snags: int) -> void: handed.append([id, q, snags]))
	check(bus.get_job(BREAK).missing_wants().size() == 2, "nothing was returned yet: %s" % str(bus.get_job(BREAK).missing_wants()))
	check(bus.advance(BREAK, ContractJob.HANDED_OVER), "the handover still goes through")
	check(handed.size() == 1 and int(handed[0][2]) == 2 and is_zero_approx(float(handed[0][1])),
			"two snags and no quality for a break job that returned nothing: %s" % str(handed))


func _test_fit_job(bus: ContractsBus) -> void:
	const FIT := "rook_salvage.vs101"
	var job := bus.get_job(FIT)
	check(job != null and job.state == ContractJob.OFFERED, "the hold net fit is on offer")
	if job == null:
		return
	check(bus.needs_parts(job), "BSX supplies the net")
	check(bus.accept(FIT), "accept it")
	check(job.state == ContractJob.IN_PROGRESS, "without Business there is nothing to order: work starts: %s" % job.state)


func _test_sync(bus: ContractsBus) -> void:
	var snap := bus.get_net_snapshot()
	check(snap.get("data") is Dictionary and (snap.data as Dictionary).has("jobs"), "the snapshot is the board")
	var other := ContractsBus.new()
	add_child(other)
	var redrawn: Array[int] = []
	other.board_changed.connect(func() -> void: redrawn.append(1))
	other.apply_net_snapshot(snap)
	check(other.job_ids().size() == bus.job_ids().size() and other.job_ids().size() > 0, "a joiner gets every job")
	check(other.get_job("tpa.sb301") != null and other.get_job("tpa.sb301").state == ContractJob.HANDED_OVER, "in the host's state")
	check(other.get_active_job() != null and other.get_active_job().job_id == bus.get_active_job().job_id, "and the active job")
	check(redrawn.size() == 1, "the board redraws once")
	check(other._validate_action(2, {"op": "accept", "job": "kettle_rock.ss304"}) is Dictionary, "a player may accept an offer")
	check(other._validate_action(2, {"op": "accept", "job": "tpa.sb301"}) is String, "not a job already taken")
	check(other._validate_action(2, {"op": "activate", "job": "kettle_rock.ss304"}) is String, "nor make an offer active")
	check(other._validate_action(2, {"op": "activate", "job": "tpa.sb301"}) is Dictionary, "a taken job can be made active")
	check(other._validate_action(2, {"op": "accept", "job": "nope"}) is String, "unknown jobs are refused")
	other.queue_free()
