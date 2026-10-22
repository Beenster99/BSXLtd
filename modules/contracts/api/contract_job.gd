class_name ContractJob
extends Resource
## One job in the bay: a work order plus everything that happened to it. Held by
## ContractsBus; other modules read it and change it only through the bus's methods.

const OFFERED := "offered"
const ACCEPTED := "accepted"
## The subject is on its way to the yard (a part on a truck, a hulk under the lifter).
const ARRIVING := "arriving"
const PARTS_READY := "parts_ready"
const IN_BAY := "in_bay"
const IN_PROGRESS := "in_progress"
const INSPECTION := "inspection"
const HANDED_OVER := "handed_over"
const CLOSED := "closed"
const DECLINED := "declined"
const CANCELLED := "cancelled"

## Allowed moves. Cancelled is reachable from any state before handed_over (see can_move).
const NEXT: Dictionary = {
	OFFERED: [ACCEPTED, DECLINED],
	ACCEPTED: [PARTS_READY, ARRIVING],
	ARRIVING: [PARTS_READY],
	PARTS_READY: [IN_BAY],
	IN_BAY: [IN_PROGRESS],
	IN_PROGRESS: [INSPECTION],
	INSPECTION: [HANDED_OVER, IN_PROGRESS],
	HANDED_OVER: [CLOSED],
}
const CANCELLABLE: PackedStringArray = [OFFERED, ACCEPTED, ARRIVING, PARTS_READY, IN_BAY, IN_PROGRESS, INSPECTION]

@export var job_id := ""
@export var order: WorkOrder
@export var state := OFFERED
## change_id -> ChangeItem status.
@export var change_status: Dictionary = {}
## change_id -> InstallRecord.
@export var installs: Dictionary = {}
## change_id -> {condition (0.1 to 1), disposition ("returned", "scrapped", "kept_as_salvage")}.
@export var removals: Dictionary = {}
## Each {variation_id, description, price_delta}.
@export var variations: Array[Dictionary] = []
## What came out of the subject (break, scrap, refurbish, dispose jobs), each
## {component (Dictionary, ComponentRef.to_dict) or material, kg, condition, disposition
## ("returned" to the client, "kept" by BSX, "scrapped", "destroyed")}.
@export var recoveries: Array[Dictionary] = []
## Each {player_id, role}.
@export var signed_by: Array[Dictionary] = []
## Each {name, passed, value, unit}.
@export var tests: Array[Dictionary] = []
@export var open_snags := 0
@export var completed_at := ""


static func can_move(from: String, to: String) -> bool:
	if to == CANCELLED:
		return from in CANCELLABLE
	return to in NEXT.get(from, [])


func status_of(change_id: String) -> String:
	return change_status.get(change_id, ChangeItem.PENDING)


## Changes that still need an install record before the as-built record can be written.
func missing_installs() -> PackedStringArray:
	var out := PackedStringArray()
	for c in order.changes:
		if c.needs_install() and not installs.has(c.change_id):
			out.append(c.change_id)
	return out


## The wants lines a non-fit job has not met yet, as readable text (empty = ready to hand over).
func missing_wants() -> PackedStringArray:
	var out := PackedStringArray()
	for w in order.wants:
		match String(w.get("what")):
			"part":
				var ref: ComponentRef = w.get("component")
				var have := 0
				for r in recoveries:
					var c: Dictionary = r.get("component", {})
					if ref and c.get("id") == ref.id and r.get("disposition") == "returned" \
							and float(r.get("condition", 0.0)) >= float(w.get("min_condition", 0.0)):
						have += 1
				if have < int(w.get("qty", 1)):
					out.append("%d of %d %s returned" % [have, int(w.get("qty", 1)), ref.id if ref else "part"])
			"material":
				var kg := 0.0
				for r in recoveries:
					if r.get("material") == w.get("material") and r.get("disposition") in ["returned", "kept"]:
						kg += float(r.get("kg", 0.0))
				if kg < float(w.get("kg", 0.0)):
					out.append("%.0f of %.0f kg %s" % [kg, float(w.get("kg", 0.0)), w.get("material")])
			"condition":
				var best := -1.0
				for r in recoveries:
					if r.get("disposition") == "returned":
						best = maxf(best, float(r.get("condition", 0.0)))
				if best < float(w.get("min_condition", 1.0)):
					out.append("subject returned at %.0f%% or better" % (float(w.get("min_condition", 1.0)) * 100.0))
			"gone":
				var gone := false
				for r in recoveries:
					gone = gone or r.get("disposition") in ["scrapped", "destroyed"]
				if not gone:
					out.append("subject scrapped or destroyed")
	return out


## Mean condition of what went back to the client, 0 to 1 (1 when nothing did): the
## quality Business reads for a non-fit job.
func returned_condition() -> float:
	var total := 0.0
	var n := 0
	for r in recoveries:
		if r.get("disposition") == "returned":
			total += float(r.get("condition", 1.0))
			n += 1
	return total / n if n > 0 else 1.0


## Mean quality of the installs recorded so far, 0 to 1 (1 when there are none).
func mean_quality() -> float:
	if installs.is_empty():
		return 1.0
	var total := 0.0
	for r: InstallRecord in installs.values():
		total += r.quality
	return total / installs.size()
