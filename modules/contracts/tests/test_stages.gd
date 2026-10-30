extends ModuleTest
## Large jobs in stages (plan stage S6, flag contracts.stages): the Reserve and the insurer
## post the Sentinel at Preferred standing with a stage plan; a stage is signed off in
## order and paid on its own; the rules (weapons destroyed first, reactor out before the
## rest) count breaches as snags; the plan saves and shows in the job pack.
##   tools/run_tests.sh contracts

const Generator := preload("res://modules/contracts/internal/offer_generator.gd")
const Board := preload("res://modules/contracts/internal/board_panel.gd")
const FLAGS := {"core": true, "ui": true, "contracts": true, "contracts.board": true, "contracts.kinds": true,
		"contracts.clients": true, "contracts.wrecks": true, "contracts.debug": true}


func run_tests() -> void:
	var saved := Flags.all()
	var off := FLAGS.duplicate()
	off["contracts.stages"] = false
	Flags.use(off)
	Modules.load_all()
	var bus := Modules.bus("contracts") as ContractsBus
	if bus == null:
		check(false, "contracts loads")
		Flags.use(saved)
		Modules.load_all()
		return
	check(_large(bus, "tallow_reserve") == null, "no large offers with contracts.stages off")

	var on := FLAGS.duplicate()
	on["contracts.stages"] = true
	Flags.use(on)
	Modules.load_all()
	bus = Modules.bus("contracts") as ContractsBus
	_test_offer(bus)
	_test_flow(bus)
	_test_pack_and_save(bus)
	_test_online_action(bus)
	_test_docket_words()
	Flags.use(saved)
	Modules.load_all()


## Calls offers in from a client at tier three until a staged one lands (the roll is seeded
## by slot, so a few tries cover it), or null.
func _large(bus: ContractsBus, client: String) -> ContractJob:
	for i in 12:
		var id := bus.call_in(client, 3)
		if id != "" and bus.get_job(id).is_staged():
			return bus.get_job(id)
	return null


func _test_offer(bus: ContractsBus) -> void:
	var job := _large(bus, "tallow_reserve")
	check(job != null, "the Reserve posts a large job in stages at tier three")
	if job == null:
		return
	var o := job.order
	check(String(o.subject.get("design", "")) == "vsw:sentinel", "the hulk is the Sentinel: %s" % str(o.subject.get("design", "")))
	check(float(o.subject.get("mass_kg", 0.0)) > Generator.MEDIUM_MAX_KG, "a large hulk: %.0f kg" % float(o.subject.get("mass_kg", 0.0)))
	check(String((o.raw.get("offer", {}) as Dictionary).get("size", "")) == "large", "the offer is sized large")
	check(o.stages.size() >= 4, "a plan of several stages: %d" % o.stages.size())
	var titles := PackedStringArray()
	var paid := 0
	for st: Dictionary in o.stages:
		titles.append(String(st.get("name", "")))
		paid += int(st.get("pay", 0))
		check(not (st.get("wants", []) as Array).is_empty(), "every stage takes something: %s" % String(st.get("name", "")))
	check(titles[0] == "Weapons made safe" and titles[1] == "Reactor out", "weapons first, then the reactor: %s" % str(titles))
	check(paid == int(o.commercial.get("price", 0)), "the stages' pay adds up to the price: %d of %d" % [paid, int(o.commercial.get("price", 0))])
	check(bool(o.commercial.get("stage_payments", false)), "the terms say it pays by the stage")
	var weapons: Array = o.stages[0].get("wants", [])
	var destroyed := true
	for w: Dictionary in weapons:
		destroyed = destroyed and String(w.get("disposition", "")) == "destroyed"
	check(destroyed and not weapons.is_empty(), "the weapons stage wants every weapon destroyed: %d lines" % weapons.size())
	check(o.wants.size() == _count_wants(o), "the order's wants are every stage's together")
	check("weapons" in o.hazards and "power" in o.hazards, "a warship's hazards: %s" % str(o.hazards))
	check(o.title.begins_with("Decommission:"), "the Reserve's voice: %s" % o.title)
	var insurer := _large(bus, "carrow_underwriters")
	check(insurer != null and insurer.order.title.begins_with("Total loss"), "the insurer posts large jobs too: %s" % (insurer.order.title if insurer else "none"))


func _count_wants(o: WorkOrder) -> int:
	var n := 0
	for st: Dictionary in o.stages:
		n += (st.get("wants", []) as Array).size()
	return n


func _test_flow(bus: ContractsBus) -> void:
	var job := _large(bus, "tallow_reserve")
	if job == null:
		return
	var id := job.job_id
	var paid: Array = []
	bus.stage_signed_off.connect(func(j: String, stage_id: String) -> void:
		var done: Dictionary = bus.get_job(j).stages_done[-1]
		paid.append([j, stage_id, int(done.get("pay", 0)), float(done.get("quality", 0.0))]))
	var staged: Array = []
	bus.contract_staged.connect(func(j: String, stages: Array) -> void: staged.append([j, stages]))
	var changes: Array = []
	bus.stage_changed.connect(func(_j: String, stage_id: String, state: String) -> void: changes.append(stage_id + ":" + state))
	var due: Array = []
	bus.subject_due.connect(func(j: String, _s: Dictionary) -> void: due.append(j))
	check(bus.accept(id) and job.state == ContractJob.ARRIVING and due.has(id), "accepted: the hulk is arriving and the yard is told")
	check(staged.size() == 1 and staged[0][0] == id and (staged[0][1] as Array).size() == job.order.stages.size()
			and int((staged[0][1] as Array)[0].get("value", 0)) == int(job.order.stages[0].get("pay", 0)),
			"Business is told the stages and their values: %s" % str(staged))
	check(bus.stage_text(id) == "stage 1 of %d: weapons made safe" % job.order.stages.size(), "the stage reads on the board: %s" % bus.stage_text(id))
	check(bus.subject_landed(id) and job.state == ContractJob.IN_PROGRESS, "landed: a staged job goes through its berth into progress: %s" % job.state)
	check(changes == ["weapons:open"], "the first stage opens with the work: %s" % str(changes))
	check(not bus.sign_off_stage(id, "reactor", "surveyor", true), "a stage that is not the one being worked cannot be signed")
	check(bus.subject_berthed(id), "berthed is true once it is in and under way")
	check(not bus.sign_off_stage(id), "the weapons stage cannot be signed off with the weapons still aboard")
	check(not bus.stage_missing(id).is_empty(), "it says what is still to do: %s" % str(bus.stage_missing(id)))
	# The reactor out before the weapons are made safe breaks the rule: a snag.
	var snags_before := job.open_snags
	bus.record_recovery(id, ComponentRef.from_dict({"id": "Reactor"}), 0.6, "returned")
	check(job.open_snags == snags_before + 1, "the reactor out before the weapons stage is a snag: %d" % job.open_snags)
	for w: Dictionary in job.order.stages[0].get("wants", []):
		var ref: ComponentRef = w.get("component")
		for i in int(w.get("qty", 1)):
			bus.record_recovery(id, ComponentRef.from_dict({"id": ref.id}), 0.0, "destroyed")
	check(bus.stage_missing(id).is_empty(), "every weapon destroyed: the stage is complete")
	check(bus.sign_off_stage(id, "weapons", "report-1"), "the surveyor signs the weapons stage off by its id")
	check(paid.size() == 1 and paid[0][0] == id and paid[0][1] == "weapons" and paid[0][2] == int(job.order.stages[0].get("pay", 0)),
			"the stage is paid on its own: %s" % str(paid))
	check(changes == ["weapons:open", "weapons:signed", "reactor:open"], "the stage closes and the next opens: %s" % str(changes))
	check(String(job.stages_done[0].get("by", "")) == "report-1" and String(job.stages_done[0].get("id", "")) == "weapons", "the sign-off records who and which")
	check(job.stage == 1 and bus.stage_text(id).begins_with("stage 2 of"), "on to the reactor stage: %s" % bus.stage_text(id))
	check(bus.stage_missing(id).is_empty(), "the reactor already out counts for its stage")
	check(bus.sign_off_stage(id), "the reactor stage signs off")
	check(paid.size() == 2 and float(paid[1][3]) > 0.5, "paid at the reactor's condition: %s" % str(paid[1]))
	# Forcing a stage through with work left is allowed, each unmet line a snag.
	snags_before = job.open_snags
	check(not bus.sign_off_stage(id), "the engines stage waits for the engines")
	check(bus.sign_off_stage(id, "", "surveyor", true), "forced through")
	check(job.open_snags > snags_before and paid.size() == 3, "with its unmet lines as snags: %d" % job.open_snags)
	while not bus.current_stage(id).is_empty():
		bus.sign_off_stage(id, "", "surveyor", true)
	check(bus.stage_text(id) == "stages done" and paid.size() == job.order.stages.size(), "every stage signed and paid: %d" % paid.size())
	var total := 0
	for p: Array in paid:
		total += int(p[2])
	check(total == int(job.order.commercial.get("price", 0)), "the stage payments add up to the price")
	check(not bus.sign_off_stage(id), "nothing left to sign")
	check(bus.advance(id, ContractJob.INSPECTION) and bus.advance(id, ContractJob.HANDED_OVER), "the final survey still hands the job over")


func _test_pack_and_save(bus: ContractsBus) -> void:
	var job := _large(bus, "carrow_underwriters")
	if job == null:
		return
	var id := job.job_id
	var pack := bus.job_pack(id)
	var ids := PackedStringArray()
	for d: Dictionary in pack:
		ids.append(String(d.get("id", "")))
	check(ids.has(ContractJobPack.STAGES), "the job pack carries the stage plan: %s" % str(ids))
	var text := ContractDocumentView.text_of(bus.document(id, ContractJobPack.STAGES))
	check("STAGE 1 OF" in text and "WEAPONS MADE SAFE" in text and "destroyed" in text, "the plan reads stage by stage: %s" % text.substr(0, 200))
	bus.accept(id)
	bus.subject_landed(id)
	text = ContractDocumentView.text_of(bus.document(id, ContractJobPack.STAGES))
	check("NEXT" in text and "Still to do" in text, "the stage being worked is marked next with what is left")
	bus.sign_off_stage(id, "", "surveyor", true)
	var data := bus.save_data()
	var copy := ContractsBus.new()
	add_child(copy)
	copy.load_data(data, bus.save_version())
	var back := copy.get_job(id)
	check(back != null and back.stage == 1 and back.stages_done.size() == 1 and back.order.stages.size() == job.order.stages.size(),
			"a save keeps the stage, the sign-offs and the plan")
	remove_child(copy)
	copy.free()


func _test_online_action(bus: ContractsBus) -> void:
	var job := _large(bus, "tallow_reserve")
	if job == null:
		return
	var id := job.job_id
	check(bus._validate_action(2, {"op": "sign_stage", "job": id}) is String, "a client cannot sign a stage on an offer")
	bus.accept(id)
	bus.subject_landed(id)
	check(bus._validate_action(2, {"op": "sign_stage", "job": id}) is String, "nor an unfinished stage")
	var forced: Variant = bus._validate_action(2, {"op": "sign_stage", "job": id, "force": true})
	check(forced is Dictionary, "a forced sign-off is a valid request")
	check(bus._validate_action(2, {"op": "sign_stage", "job": id, "stage": "reactor", "force": true}) is String, "nor a stage that is not the one being worked")
	bus._apply_action({"op": "sign_stage", "job": id, "stage": "weapons", "by": "surveyor", "force": true})
	check(job.stage == 1, "the host applies it")
	check((job.order.stages[1].get("checks", []) as Array) == ["weapons_destroyed"] and (job.order.stages[2].get("checks", []) as Array).has("reactor_out"),
			"stages carry the checks Quality confirms first")


func _test_docket_words() -> void:
	var ref := ComponentRef.from_dict({"id": "AssaultCannon"})
	check(Board.want_text({"what": "part", "component": ref, "qty": 4, "disposition": "destroyed"}).ends_with("destroyed"),
			"a destroyed want reads destroyed on the docket")
	check(Board.want_text({"what": "part", "component": ref, "qty": 1}).ends_with("back"),
			"a returned want reads back on the docket")
