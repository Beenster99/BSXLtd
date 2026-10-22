class_name SurveyReport
extends Resource
## What the independent surveyors hand BSX after a visit: a summary with an overall grade,
## and a line for every joint they scanned. The customer mandates the surveyors, so players
## never grade their own work; Quality runs the visits (QualityBus.request_survey) and keeps
## the reports. Other modules only read these.

const VERSION := 1

## A spot check the surveyors turn up for on their own: some of the work done since the last
## visit, so problems are caught early.
const RANDOM := &"RANDOM"
## Called in from the wrist screen or a TV: everything done since the last visit.
const CALLED := &"CALLED"
## The job was marked complete: every joint on it. Decides handover or rework.
const FINAL := &"FINAL"
const KINDS: Array[StringName] = [RANDOM, CALLED, FINAL]

## The consultancy BSX's customers insist on.
const FIRM := "Kessler & Vane Surveyors"

@export var version := VERSION
## "S-001", counting up per save.
@export var id := ""
@export var kind: StringName = RANDOM
@export var job_id := ""
## Seconds on the host's clock (unix time solo) when the report came in.
@export var time := 0
## One per joint scanned: {joint_id, trade, component_id, mount_id, score, grade, faults}.
@export var lines: Array[Dictionary] = []
## Joints on the job when the surveyors left, scanned or not.
@export var joints_on_job := 0
@export var passed := 0
@export var marginal := 0
@export var failed := 0
## Mean score of the graded joints scanned, 0..100.
@export var average := 0.0
## "A" to "F" (see letter()).
@export var grade := ""
## FINAL only: true when the job can be handed over.
@export var accepted := false


## The overall grade: A from 90, B from 80, C from 70, D from 50, F below; any failed joint
## holds it at D at best, since something has to be put right.
static func letter(avg: float, fails: int) -> String:
	var g := "F"
	if avg >= 90.0:
		g = "A"
	elif avg >= 80.0:
		g = "B"
	elif avg >= 70.0:
		g = "C"
	elif avg >= 50.0:
		g = "D"
	if fails > 0 and g < "D":
		g = "D"
	return g


func scanned() -> int:
	return lines.size()


func kind_name() -> String:
	match kind:
		CALLED:
			return "Called survey"
		FINAL:
			return "Final survey"
	return "Spot survey"


## One line for the report list and the notice: "Spot survey · 6 joints · B · 1 to fix".
func summary() -> String:
	var bits := PackedStringArray([kind_name(), "%d joint%s" % [scanned(), "" if scanned() == 1 else "s"], grade])
	if kind == FINAL:
		bits.append("accepted for handover" if accepted else "rework needed")
	elif failed > 0:
		bits.append("%d to fix" % failed)
	elif marginal > 0:
		bits.append("%d marginal" % marginal)
	else:
		bits.append("no issues")
	return "  ·  ".join(bits)


func to_dict() -> Dictionary:
	return {
		"version": version, "id": id, "kind": String(kind), "job_id": job_id, "time": time,
		"lines": lines, "joints_on_job": joints_on_job, "passed": passed, "marginal": marginal,
		"failed": failed, "average": average, "grade": grade, "accepted": accepted,
	}


static func from_dict(d: Dictionary) -> SurveyReport:
	var r := SurveyReport.new()
	r.id = str(d.get("id", ""))
	r.kind = StringName(d.get("kind", RANDOM))
	r.job_id = str(d.get("job_id", ""))
	r.time = int(d.get("time", 0))
	r.lines.assign(d.get("lines", []))
	r.joints_on_job = int(d.get("joints_on_job", 0))
	r.passed = int(d.get("passed", 0))
	r.marginal = int(d.get("marginal", 0))
	r.failed = int(d.get("failed", 0))
	r.average = float(d.get("average", 0.0))
	r.grade = str(d.get("grade", ""))
	r.accepted = bool(d.get("accepted", false))
	return r
