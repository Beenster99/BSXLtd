class_name JointRecord
extends Resource
## One finished joint as Quality sees it: what Trades measured, plus Quality's verdict.
## Quality creates these from Trades' joint_completed results; other modules only read them.

const VERSION := 1

const PASS := &"PASS"
const MARGINAL := &"MARGINAL"
const FAIL := &"FAIL"
## No rules for this trade yet (it shipped before its rules did).
const UNGRADED := &"UNGRADED"

@export var version := VERSION
@export var joint_id: StringName
@export var trade: StringName
@export var component_id: StringName
@export var mount_id: StringName
## Trades' raw measurements, keyed as in the Trades spec (e.g. torque_nm, sequence_ok).
@export var measurements: Dictionary = {}
@export var peer_id := 1
@export var time := 0
## 0..100, or -1 when UNGRADED.
@export var score := -1
@export var grade: StringName = UNGRADED
## Points earned per rule, e.g. {"torque": 54.0, "sequence": 15.0}.
@export var breakdown: Dictionary = {}
## What is wrong with it: [{"code": "cross_threaded", "hole": 2, "text": "Hole 3 cross-threaded"}].
## hole is -1 for faults on the whole joint.
@export var faults: Array[Dictionary] = []
## Checked by a player with an inspection tool (from 0.5).
@export var inspected := false


func passed() -> bool:
	return grade == PASS


func to_dict() -> Dictionary:
	return {
		"joint_id": String(joint_id), "trade": String(trade),
		"component_id": String(component_id), "mount_id": String(mount_id),
		"measurements": measurements, "peer_id": peer_id, "time": time,
		"score": score, "grade": String(grade), "breakdown": breakdown,
		"faults": faults, "inspected": inspected,
	}


static func from_dict(d: Dictionary) -> JointRecord:
	var r := JointRecord.new()
	r.joint_id = StringName(d.get("joint_id", ""))
	r.trade = StringName(d.get("trade", ""))
	r.component_id = StringName(d.get("component_id", ""))
	r.mount_id = StringName(d.get("mount_id", ""))
	r.measurements = d.get("measurements", {})
	r.peer_id = int(d.get("peer_id", 1))
	r.time = int(d.get("time", 0))
	r.score = int(d.get("score", -1))
	r.grade = StringName(d.get("grade", UNGRADED))
	r.breakdown = d.get("breakdown", {})
	r.faults.assign(d.get("faults", []))
	r.inspected = bool(d.get("inspected", false))
	return r
