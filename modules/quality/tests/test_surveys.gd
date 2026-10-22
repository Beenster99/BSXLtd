extends ModuleTest
## Quality: the independent surveyors. Overall grades, which joints each kind of visit scans,
## the visit flow on the host's clock (called, spot and final surveys), handover or rework
## after the final survey, the Surveys channel, the crew in the yard and the save round trip.
##   tools/run_tests.sh quality

const SurveyScreen := preload("res://modules/quality/internal/survey_screen.gd")
const SurveyCrew := preload("res://modules/quality/internal/survey_crew.gd")


class FakeResult extends Resource:
	var joint_id: StringName
	var trade: StringName = &"BOLT"
	var component_id: StringName = &"attractor_coil_1"
	var mount_id: StringName = &"mount_a"
	var measurements: Dictionary = {}
	var peer_id := 1
	var time := 1000


## Stands in for Contracts: one active job, and what Quality asked of it.
class FakeContracts extends Node:
	signal job_state_changed(job_id: String, from_state: String, to_state: String)
	signal active_job_changed(job_id: String)
	var job := ContractJob.new()
	var tests: Array = []
	var signed: Array = []

	func get_active_job() -> ContractJob:
		return job

	func advance(job_id: String, to_state: String, _by_client := false) -> bool:
		var from := job.state
		job.state = to_state
		job_state_changed.emit(job_id, from, to_state)
		return true

	func record_test(_job_id: String, test_name: String, passed: bool, _value := 0.0, _unit := "") -> void:
		tests.append([test_name, passed])

	func sign_off(_job_id: String, player_id: String, role: String, open_snags := 0) -> void:
		signed.append([player_id, role, open_snags])


func run_tests() -> void:
	_grades()
	_picking()
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "trades": true,
			"multiplayer": true, "quality": true, "quality.scores": true, "quality.surveys": true})
	Modules.load_all()
	var bus := Modules.bus("quality") as QualityBus
	check(bus != null, "quality loads with surveys on")
	if bus:
		await _visits(bus)
	Flags.use(saved)
	Modules.load_all()
	await frames(1)


func _grades() -> void:
	check(SurveyReport.letter(95.0, 0) == "A" and SurveyReport.letter(85.0, 0) == "B", "A from 90, B from 80")
	check(SurveyReport.letter(72.0, 0) == "C" and SurveyReport.letter(55.0, 0) == "D", "C from 70, D from 50")
	check(SurveyReport.letter(40.0, 0) == "F", "F below 50")
	check(SurveyReport.letter(96.0, 1) == "D", "a failed joint holds the grade at D")
	check(SurveyReport.letter(30.0, 2) == "F", "a poor average with fails stays F")
	var rep := SurveyReport.new()
	rep.kind = SurveyReport.FINAL
	rep.grade = "B"
	rep.accepted = true
	check(rep.summary().contains("Final survey") and rep.summary().contains("accepted"), "summary line: " + rep.summary())
	var back := SurveyReport.from_dict(JSON.parse_string(JSON.stringify(rep.to_dict())))
	check(back.kind == SurveyReport.FINAL and back.accepted and back.grade == "B", "report survives JSON")


func _picking() -> void:
	var rules := SurveyRules.new()
	rules.random_sample = 2
	rules.called_sample = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var recs: Array[JointRecord] = []
	for i in 5:
		var r := JointRecord.new()
		r.joint_id = StringName("j%d" % i)
		r.time = 100 + i
		r.survey_id = "S-001" if i < 1 else ""
		recs.append(r)
	var spot := SurveyDesk.pick(recs, SurveyReport.RANDOM, rules, rng)
	check(spot.size() == 2 and not "j0" in spot, "a spot survey samples the new work: %s" % [spot])
	var called := SurveyDesk.pick(recs, SurveyReport.CALLED, rules, rng)
	check(called == PackedStringArray(["j2", "j3", "j4"]), "a called survey takes the newest new work: %s" % [called])
	var final := SurveyDesk.pick(recs, SurveyReport.FINAL, rules, rng)
	check(final.size() == 5 and final[0] == "j0", "the final survey scans every joint, oldest first")
	check(SurveyDesk.duration(4, SurveyReport.FINAL, SurveyRules.new()) < SurveyDesk.duration(4, SurveyReport.CALLED, SurveyRules.new()),
			"two surveyors make the final survey quicker per joint")
	var words := SurveyDesk.joint_words({"component_id": "attractor_coil_1", "trade": "BOLT", "mount_id": "mount_a"})
	check(words == "Attractor coil 1  ·  bolted at mount a", "report names the joint: " + words)


func _visits(bus: QualityBus) -> void:
	check(not HudSlots.panels_in(HudSlots.NOTICES).any(func(p): return p.id == QualityBus.SCORE_CARD),
			"no per-joint score card while the surveyors grade the work")
	check(not HudSlots.holo_channel(QualityBus.SURVEYS_CHANNEL).is_empty(), "Surveys channel on the wrist and TVs")
	bus.clear()
	var fake := FakeContracts.new()
	add_child(fake)
	fake.job.job_id = "job1"
	fake.job.state = ContractJob.IN_BAY
	bus.attach(fake, Modules.bus("multiplayer"))
	var rules := bus.survey_rules.duplicate() as SurveyRules
	rules.random_min_s = 9999.0
	rules.random_max_s = 9999.0
	rules.arrive_s = 0.05
	rules.per_joint_s = 0.0
	bus.survey_rules = rules

	check(bus.why_not(SurveyReport.CALLED).begins_with("Nothing to survey"), "no survey before work starts")
	fake.job.state = ContractJob.IN_PROGRESS
	check(bus.why_not(SurveyReport.CALLED) == "Nothing new since the last survey", "nothing to call them for yet")
	_bolt(bus, "a", [25.0, 25.0, 25.0, 25.0])
	_bolt(bus, "b", [25.0, 25.0, 25.0, 25.0])
	_bolt(bus, "c", [25.0, 25.0, 25.0, 25.0], {"cross_threaded": [true, false, false, false]})
	check(bus.get_record(&"a").job_id == "job1", "records note the job they were done on")

	var started: Array = []
	var finished: Array[SurveyReport] = []
	bus.survey_started.connect(func(k: StringName, _j: String, ids: Array) -> void: started.append([k, ids.size()]))
	bus.survey_finished.connect(func(r: SurveyReport) -> void: finished.append(r))

	var screen := HudSlots.holo_channel(QualityBus.SURVEYS_CHANNEL).factory.call(true) as Control
	add_child(screen)
	var request := screen.find_child("Request", true, false) as Button
	check(request != null and not request.disabled, "REQUEST SURVEY is live with new work")
	request.pressed.emit()
	check(started.size() == 1 and started[0] == [SurveyReport.CALLED, 3], "calling them in scans the new work: %s" % [started])
	check(bus.survey_running() and bus.why_not(SurveyReport.CALLED) == "The surveyors are already on site", "one visit at a time")
	var status := screen.find_child("Status", true, false) as Label
	check(status != null and status.text.begins_with("Surveyors on site"), "the channel says they're on site")
	check(HudSlots.infos().any(func(c): return c.id == QualityBus.NOTICE), "a notice says the surveyors arrived")
	for i in 60:
		if not finished.is_empty():
			break
		await frames(1)
	check(finished.size() == 1, "the surveyors leave on the host's clock with a report")
	var rep: SurveyReport = finished[0] if finished.size() > 0 else SurveyReport.new()
	check(rep.scanned() == 3 and rep.failed == 1 and rep.passed == 2 and rep.grade == "D",
			"report: %d scanned, %d failed, grade %s" % [rep.scanned(), rep.failed, rep.grade])
	check(bus.get_record(&"c").survey_id == rep.id and bus.get_record(&"c").inspected, "scanned joints are marked")
	check(bus.reports()[0] == rep, "reports are kept newest first")
	await frames(1)
	check(screen.find_child("Row_" + rep.id.validate_node_name(), true, false) != null, "the report is listed")
	var verdict := screen.find_child("Verdict", true, false) as Label
	check(verdict != null and verdict.text.contains("1 joint failed"), "the report says what to put right")
	check(screen.find_child("Lines", true, false).get_child_count() == 3, "the detailed report lists every joint")

	check(bus.why_not(SurveyReport.CALLED) == "Nothing new since the last survey", "scanned work isn't scanned again")
	_bolt(bus, "d", [25.0, 25.0, 25.0, 25.0])
	bus.request_survey(SurveyReport.RANDOM)
	bus.finish_survey_now()
	check(finished.size() == 2 and finished[1].kind == SurveyReport.RANDOM and finished[1].scanned() == 1,
			"a spot survey looks at the work since the last visit")

	# The crew in the yard: two surveyors walk in for the final survey and out again.
	var yard := Node3D.new()
	add_child(yard)
	var crew := SurveyCrew.new(bus)
	yard.add_child(crew)
	var complete := screen.find_child("Complete", true, false) as Button
	check(complete != null and not complete.disabled, "MARK JOB COMPLETE is live while the job is in progress")
	complete.pressed.emit()
	check(fake.job.state == ContractJob.INSPECTION, "marking the job complete sends it for inspection")
	check(started.back() == [SurveyReport.FINAL, 4], "the final survey scans every joint on the job: %s" % [started.back()])
	check(crew.surveyors().size() == 2, "two surveyors come for the final survey")
	bus.finish_survey_now()
	var fin: SurveyReport = finished.back()
	check(fin.kind == SurveyReport.FINAL and not fin.accepted, "a failed joint fails the final survey")
	check(fake.job.state == ContractJob.IN_PROGRESS, "a failed final survey sends the job back for rework")
	check(fake.tests.back() == ["Independent final survey", false] and fake.signed.is_empty(), "the failed survey is on record, unsigned")
	check(crew.surveyors().all(func(s): return s.state == 3), "the surveyors walk off when the report is in")

	bus.drop(&"c")
	_bolt(bus, "c", [25.0, 25.0, 25.0, 25.0])
	bus.request_survey(SurveyReport.FINAL)
	bus.finish_survey_now()
	fin = finished.back()
	check(fin.accepted and fin.grade == "A", "reworked, the job passes: %s" % fin.grade)
	check(fake.job.state == ContractJob.HANDED_OVER, "an accepted final survey hands the job over")
	check(fake.signed.size() == 1 and fake.signed[0][1] == SurveyReport.FIRM, "the surveyors sign it off")

	var data := bus.save_data()
	var count := bus.reports().size()
	bus.clear()
	bus.load_data(JSON.parse_string(JSON.stringify(data)), QualityBus.SAVE_VERSION)
	check(bus.reports().size() == count and bus.reports()[0].accepted, "reports survive a save round trip")
	check(bus.get_record(&"a").survey_id != "" and bus.get_record(&"a").job_id == "job1", "records keep their job and survey")
	var v1 := {"records": [{"joint_id": "old", "trade": "BOLT", "score": 80, "grade": "PASS"}]}
	bus.load_data(v1, 1)
	check(bus.get_record(&"old").job_id == "" and bus.reports().is_empty(), "version 1 saves load with no surveys")

	screen.queue_free()
	yard.queue_free()
	fake.queue_free()


func _bolt(bus: QualityBus, id: String, torques: Array, extra: Dictionary = {}) -> JointRecord:
	var res := FakeResult.new()
	res.joint_id = StringName(id)
	var n := torques.size()
	var m := {"torque_nm": torques, "torque_target_nm": 25.0, "sequence": [], "sequence_ok": true,
			"cross_threaded": _fill(n, false), "washer": _fill(n, true), "fastener_ids": [], "misalign_mm": 0.5}
	m.merge(extra, true)
	res.measurements = m
	return bus.submit(res)


func _fill(n: int, v: bool) -> Array:
	var a := []
	a.resize(n)
	a.fill(v)
	return a
