extends ModuleTest
## Quality: large jobs signed off stage by stage (plan stage S6). The decommissioning rules
## (reactor out before anything is cut, every weapon destroyed), how a failed rule holds a
## report, and the stage survey from the Surveys channel to Contracts' sign_off_stage.
##   tools/run_tests.sh quality


class FakeOrder extends RefCounted:
	var stages: Array = []
	var wants: Array = []
	var hazards := PackedStringArray()


class FakeJob extends RefCounted:
	var job_id := "big1"
	var state := ContractJob.IN_PROGRESS
	var order := FakeOrder.new()
	var recoveries: Array[Dictionary] = []
	var stages_signed: Array = []


## Stands in for Contracts with S6's stage hooks.
class FakeContracts extends Node:
	signal job_state_changed(job_id: String, from_state: String, to_state: String)
	signal active_job_changed(job_id: String)
	signal stage_changed(job_id: String, stage_id: String, state: String)
	var job := FakeJob.new()
	var tests: Array = []
	var stage_signs: Array = []
	var missing := PackedStringArray()

	func stage_missing(_job_id: String) -> PackedStringArray:
		return missing

	func get_active_job() -> Object:
		return job

	func get_job(_job_id: String) -> Object:
		return job

	func current_stage(_job_id: String) -> Dictionary:
		return StageChecks.open_stage(job, PackedStringArray(job.stages_signed))

	func sign_off_stage(job_id: String, stage_id: String, report_id: String) -> bool:
		stage_signs.append([job_id, stage_id, report_id])
		job.stages_signed.append(stage_id)
		stage_changed.emit(job_id, stage_id, "signed")
		return true

	func advance(job_id: String, to_state: String, _by_client := false) -> bool:
		var from := job.state
		job.state = to_state
		job_state_changed.emit(job_id, from, to_state)
		return true

	func record_test(_job_id: String, test_name: String, passed: bool, _value := 0.0, _unit := "") -> void:
		tests.append([test_name, passed])

	func sign_off(_job_id: String, _player_id: String, _role: String, _open_snags := 0) -> void:
		pass


func run_tests() -> void:
	_rules()
	_reports()
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "trades": true,
			"multiplayer": true, "quality": true, "quality.scores": true, "quality.surveys": true,
			"contracts.stages": true, "quality.stage_surveys": true})
	Modules.load_all()
	var bus := Modules.bus("quality") as QualityBus
	check(bus != null, "quality loads with stage surveys on")
	if bus:
		await _visits(bus)
	Flags.use(saved)
	Modules.load_all()
	await frames(1)


static func _part(id: String, disposition: String) -> Dictionary:
	return {"component": {"id": id}, "kg": 100.0, "condition": 0.5, "disposition": disposition}


static func _cut(material: String) -> Dictionary:
	return {"material": material, "kg": 500.0, "condition": 0.0, "disposition": "scrapped"}


func _rules() -> void:
	var rules: SurveyRules = load("res://modules/quality/internal/data/survey_rules.tres")
	check(rules.reactor_words.size() == 1 and rules.weapon_words.has("turret"), "the rules file names reactors and weapons")
	var job := FakeJob.new()
	job.order.stages = [{"id": "weapons", "name": "Weapons out"}, {"id": "reactor", "name": "Reactor out"},
			{"id": "hull", "name": "Hull cut", "checks": ["reactor_out", "bogus"]}]
	check(StageChecks.checks_for(job, job.order.stages[0]).is_empty(), "no rules on a job with no weapons aboard")
	job.order.hazards = PackedStringArray(["fuel", "weapons"])
	check(StageChecks.decommissioning(job), "a subject with weapons is a decommissioning job")
	check(StageChecks.checks_for(job, job.order.stages[0]) == StageChecks.ALL, "decommissioning: every stage checks both rules")
	check(StageChecks.checks_for(job, job.order.stages[2]) == PackedStringArray(["reactor_out"]),
			"a stage's own checks win, unknown ones dropped")
	check(StageChecks.open_stage(job, PackedStringArray(["weapons"]))["id"] == "reactor", "the first unsigned stage is open")
	check(StageChecks.open_stage(job, PackedStringArray(["weapons", "reactor", "hull"])).is_empty(), "no stage open when all are signed")

	var c := StageChecks.run(job, StageChecks.ALL, rules)
	check(c.size() == 2 and not c[0]["passed"] and not c[1]["passed"], "nothing out yet: both rules unmet")
	check(c[0]["detail"] == "The reactor hasn't come out yet" and c[1]["detail"] == "No weapons recorded destroyed yet",
			"each says why: %s / %s" % [c[0]["detail"], c[1]["detail"]])
	job.recoveries.append(_part("dome_turret", "destroyed"))
	job.recoveries.append(_part("main_reactor", "kept"))
	c = StageChecks.run(job, StageChecks.ALL, rules)
	check(c[0]["passed"] and c[1]["passed"] and c[1]["detail"] == "1 weapon destroyed", "reactor out and turret destroyed: both met")
	job.recoveries.append(_part("rail_gun", "kept"))
	c = StageChecks.run(job, PackedStringArray([StageChecks.WEAPONS_DESTROYED]), rules)
	check(not c[0]["passed"] and c[0]["detail"].contains("rail gun kept"), "a weapon kept fails the rule: " + c[0]["detail"])

	var sentinel := FakeJob.new()
	var ref := ComponentRef.new()
	ref.id = "SlugLoader"
	sentinel.order.stages = [{"id": "weapons", "name": "Weapons out", "wants": [
			{"what": "part", "component": ref, "disposition": "destroyed"},
			{"what": "part", "component": {"id": "CapacitorBank"}, "disposition": "destroyed"}]}]
	check(StageChecks.weapon_ids(sentinel) == PackedStringArray(["slugloader", "capacitorbank"]),
			"the parts the client wants destroyed are the job's weapons: %s" % [StageChecks.weapon_ids(sentinel)])
	sentinel.recoveries.append(_part("PDC", "destroyed"))
	sentinel.recoveries.append(_part("CapacitorBank", "destroyed"))
	c = StageChecks.run(sentinel, PackedStringArray([StageChecks.WEAPONS_DESTROYED]), rules)
	check(c[0]["passed"] and c[0]["detail"] == "2 weapons destroyed", "a PDC and a wanted capacitor bank count: " + c[0]["detail"])
	sentinel.recoveries.append(_part("SlugLoader", "kept"))
	c = StageChecks.run(sentinel, PackedStringArray([StageChecks.WEAPONS_DESTROYED]), rules)
	check(not c[0]["passed"], "a wanted-destroyed part kept fails the rule")
	check(StageChecks.work_done(PackedStringArray()).passed and not StageChecks.work_done(PackedStringArray(["Reactor"])).passed,
			"the stage's own work is a check")

	var cut_first := FakeJob.new()
	cut_first.recoveries.append(_cut("steel"))
	cut_first.recoveries.append(_part("reactor_core", "scrapped"))
	c = StageChecks.run(cut_first, PackedStringArray([StageChecks.REACTOR_OUT]), rules)
	check(not c[0]["passed"] and c[0]["detail"].contains("before the reactor"), "cutting before the reactor is out fails")
	var still_in := FakeJob.new()
	still_in.recoveries.append(_cut("steel"))
	c = StageChecks.run(still_in, PackedStringArray([StageChecks.REACTOR_OUT]), rules)
	check(c[0]["detail"] == "Hull cut with the reactor still aboard", "cutting with the reactor aboard is called out")


func _reports() -> void:
	var rep := SurveyReport.new()
	rep.kind = SurveyReport.STAGE
	rep.grade = "A"
	rep.accepted = true
	SurveyDesk.add_checks(rep, [{"id": "reactor_out", "label": "Reactor out first", "passed": false, "detail": "x"}])
	check(not rep.accepted and rep.grade == "D", "a failed rule withholds sign-off and holds the grade at D")
	var empty := SurveyReport.new()
	empty.kind = SurveyReport.STAGE
	empty.grade = "–"
	empty.accepted = true
	SurveyDesk.add_checks(empty, [{"id": "weapons_destroyed", "passed": false}])
	check(empty.grade == "F" and empty.failed_checks().size() == 1, "with no joints graded a failed rule is an F")
	empty.stage_id = "weapons"
	empty.stage_name = "Weapons out"
	check(empty.summary().contains("Stage survey") and empty.summary().contains("Weapons out") and empty.summary().contains("held"),
			"summary: " + empty.summary())
	var back := SurveyReport.from_dict(JSON.parse_string(JSON.stringify(empty.to_dict())))
	check(back.kind == SurveyReport.STAGE and back.stage_id == "weapons" and back.checks.size() == 1, "stage reports survive JSON")
	var old := SurveyReport.from_dict({"id": "S-001", "kind": "FINAL", "grade": "B"})
	check(old.checks.is_empty() and old.stage_id == "", "version 1 reports load with no checks")
	var w := SurveyDesk.write("S-9", SurveyReport.STAGE, "j", [], 0, 0)
	check(w.accepted and w.grade == "–", "a stage with no joints to scan passes on its joints")
	check(SurveyDesk.duration(4, SurveyReport.STAGE, SurveyRules.new()) == SurveyDesk.duration(4, SurveyReport.FINAL, SurveyRules.new()),
			"a stage survey sends the full crew")


func _visits(bus: QualityBus) -> void:
	bus.clear()
	var fake := FakeContracts.new()
	add_child(fake)
	bus.attach(fake, Modules.bus("multiplayer"))
	var rules := bus.survey_rules.duplicate() as SurveyRules
	rules.random_min_s = 9999.0
	rules.random_max_s = 9999.0
	rules.arrive_s = 0.05
	rules.per_joint_s = 0.0
	bus.survey_rules = rules

	check(bus.stage_surveys_on(), "stage surveys run with both flags and Contracts' sign-off")
	check(bus.why_not(SurveyReport.STAGE) == "This job has no stage open for sign-off", "a job with no stages has nothing to sign")
	fake.job.order.hazards = PackedStringArray(["weapons"])
	fake.job.order.stages = [{"id": "weapons", "name": "Weapons out"}, {"id": "reactor", "name": "Reactor out"}]
	check(bus.current_stage()["id"] == "weapons" and bus.why_not(SurveyReport.STAGE) == "", "the first stage is open for sign-off")

	var started: Array = []
	var finished: Array[SurveyReport] = []
	bus.survey_started.connect(func(k: StringName, _j: String, _ids: Array) -> void: started.append(k))
	bus.survey_finished.connect(func(r: SurveyReport) -> void: finished.append(r))
	var screen := HudSlots.holo_channel(QualityBus.SURVEYS_CHANNEL).factory.call(true) as Control
	add_child(screen)
	var sign := screen.find_child("SignStage", true, false) as Button
	check(sign != null and not sign.disabled and sign.tooltip_text.contains("Weapons out"), "SIGN OFF STAGE names the open stage")
	sign.pressed.emit()
	check(started == [SurveyReport.STAGE] and bus.current_survey().get("stage_id") == "weapons", "the surveyors come for the stage")
	bus.finish_survey_now()
	var rep: SurveyReport = finished.back() if not finished.is_empty() else SurveyReport.new()
	check(rep.kind == SurveyReport.STAGE and rep.stage_name == "Weapons out" and rep.checks.size() == 3,
			"the report checks the stage's work and rules")
	check(not rep.accepted and fake.stage_signs.is_empty(), "nothing out yet: the stage is held")
	check(fake.tests.back() == ["Stage survey: Weapons out", false], "the held stage is on record")
	await frames(1)
	var checks := screen.find_child("Checks", true, false)
	check(checks != null and checks.get_child_count() == 3, "the detailed report lists the work and the rules")
	var verdict := screen.find_child("Verdict", true, false) as Label
	check(verdict != null and verdict.text.contains("not signed off") and verdict.text.contains("reactor"),
			"the report says what is missing: " + (verdict.text if verdict else ""))

	fake.job.recoveries.append(_part("twin_turret", "destroyed"))
	fake.job.recoveries.append(_part("reactor_cabinet", "kept"))
	fake.missing = PackedStringArray(["AssaultCannon destroyed"])
	bus.request_survey(SurveyReport.STAGE)
	bus.finish_survey_now()
	rep = finished.back()
	check(not rep.accepted and rep.failed_checks().size() == 1 and rep.failed_checks()[0]["detail"].contains("AssaultCannon"),
			"the stage's own work still to do holds it")
	fake.missing = PackedStringArray()
	bus.request_survey(SurveyReport.STAGE)
	bus.finish_survey_now()
	rep = finished.back()
	check(rep.accepted and rep.failed_checks().is_empty() and rep.grade == "A", "reactor out and weapons destroyed: the stage passes, A")
	check(fake.stage_signs == [["big1", "weapons", rep.id]], "Contracts gets the sign-off with the report: %s" % [fake.stage_signs])
	check(bus.current_stage()["id"] == "reactor", "the next stage opens")

	fake.job.recoveries.append(_part("missile_rack", "returned"))
	bus.request_survey(SurveyReport.FINAL)
	bus.finish_survey_now()
	rep = finished.back()
	check(rep.kind == SurveyReport.FINAL and not rep.accepted and rep.checks.size() == 2,
			"the final survey of a decommissioning job checks the rules too")
	check(fake.job.state == ContractJob.IN_PROGRESS, "a weapon handed back fails the final survey")

	Flags.set_flag("quality.stage_surveys", false)
	check(bus.why_not(SurveyReport.STAGE) == "Large jobs aren't signed off in stages yet", "flag off: no stage surveys")
	Flags.set_flag("quality.stage_surveys", true)
	screen.queue_free()
	fake.queue_free()
