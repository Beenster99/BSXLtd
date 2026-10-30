class_name SurveyDesk
extends RefCounted
## The surveyors' office: which joints a visit scans, and the report it writes up. Pure
## logic (no nodes), so the bus and the tests share it.


## The joint ids a visit scans, oldest work first. `records` are the job's records.
## RANDOM: random_sample of the work since the last visit. CALLED: all of it, newest
## called_sample at most. FINAL: every joint on the job. STAGE: all the work since the last
## visit.
static func pick(records: Array[JointRecord], kind: StringName, rules: SurveyRules,
		rng: RandomNumberGenerator) -> PackedStringArray:
	var pool: Array[JointRecord] = []
	for r in records:
		if kind == SurveyReport.FINAL or r.survey_id == "":
			pool.append(r)
	match kind:
		SurveyReport.RANDOM:
			# Fisher-Yates with the bus's generator, so a seeded test is repeatable.
			for i in range(pool.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var t := pool[i]
				pool[i] = pool[j]
				pool[j] = t
			pool = pool.slice(0, rules.random_sample)
		SurveyReport.CALLED:
			pool.sort_custom(func(a: JointRecord, b: JointRecord) -> bool: return a.time > b.time)
			pool = pool.slice(0, rules.called_sample)
	pool.sort_custom(func(a: JointRecord, b: JointRecord) -> bool:
		return a.time < b.time if a.time != b.time else String(a.joint_id) < String(b.joint_id))
	var out := PackedStringArray()
	for r in pool:
		out.append(String(r.joint_id))
	return out


## Writes the report for the joints the surveyors scanned (records still standing when they
## left; a joint taken apart meanwhile is simply not in it).
static func write(id: String, kind: StringName, job_id: String, scanned: Array[JointRecord],
		joints_on_job: int, time: int) -> SurveyReport:
	var rep := SurveyReport.new()
	rep.id = id
	rep.kind = kind
	rep.job_id = job_id
	rep.time = time
	rep.joints_on_job = joints_on_job
	var total := 0
	var graded := 0
	for r in scanned:
		rep.lines.append({"joint_id": String(r.joint_id), "trade": String(r.trade),
				"component_id": String(r.component_id), "mount_id": String(r.mount_id),
				"score": r.score, "grade": String(r.grade), "faults": r.faults.duplicate(true)})
		match r.grade:
			JointRecord.PASS: rep.passed += 1
			JointRecord.MARGINAL: rep.marginal += 1
			JointRecord.FAIL: rep.failed += 1
		if r.score >= 0:
			graded += 1
			total += r.score
	rep.average = float(total) / graded if graded > 0 else 0.0
	rep.grade = SurveyReport.letter(rep.average, rep.failed) if graded > 0 else "–"
	rep.accepted = kind in [SurveyReport.FINAL, SurveyReport.STAGE] and rep.failed == 0
	return rep


## Adds the rule checks (StageChecks.run) to a report: any failed check withholds acceptance
## and, like a failed joint, holds the grade at D at best. With no joints graded the rules
## alone grade it: A when all are met, F when any is not.
static func add_checks(rep: SurveyReport, checks: Array[Dictionary]) -> void:
	rep.checks = checks
	if rep.failed_checks().is_empty():
		if rep.grade == "–" and not checks.is_empty():
			rep.grade = "A"
		return
	rep.accepted = false
	if rep.grade == "–":
		rep.grade = "F"
	elif rep.grade < "D":
		rep.grade = "D"


## How long a visit takes, seconds: getting there plus each surveyor's share of the joints.
static func duration(joints: int, kind: StringName, rules: SurveyRules) -> float:
	var crew := maxi(1, rules.final_crew if kind in [SurveyReport.FINAL, SurveyReport.STAGE] else rules.crew)
	return rules.arrive_s + rules.per_joint_s * ceili(float(joints) / crew)


## Words for a joint in the report: "Attractor coil · bolted at mount_a".
static func joint_words(line: Dictionary) -> String:
	var comp := str(line.get("component_id", "")).replace("_", " ").strip_edges()
	var what := comp.substr(0, 1).to_upper() + comp.substr(1) if comp != "" else str(line.get("joint_id", ""))
	var verb: String = {"BOLT": "bolted", "RIVET": "riveted", "WELD": "welded", "WIRE": "wired"}.get(
			str(line.get("trade", "")), str(line.get("trade", "")).to_lower())
	var mount := str(line.get("mount_id", ""))
	return "%s  ·  %s%s" % [what, verb, (" at " + mount.replace("_", " ")) if mount != "" else ""]
