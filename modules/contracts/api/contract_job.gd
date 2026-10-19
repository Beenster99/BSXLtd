class_name ContractJob
extends Resource
## One job in the bay: a work order plus everything that happened to it. Held by
## ContractsBus; other modules read it and change it only through the bus's methods.

const OFFERED := "offered"
const ACCEPTED := "accepted"
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
	ACCEPTED: [PARTS_READY],
	PARTS_READY: [IN_BAY],
	IN_BAY: [IN_PROGRESS],
	IN_PROGRESS: [INSPECTION],
	INSPECTION: [HANDED_OVER, IN_PROGRESS],
	HANDED_OVER: [CLOSED],
}
const CANCELLABLE: PackedStringArray = [OFFERED, ACCEPTED, PARTS_READY, IN_BAY, IN_PROGRESS, INSPECTION]

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


## Mean quality of the installs recorded so far, 0 to 1 (1 when there are none).
func mean_quality() -> float:
	if installs.is_empty():
		return 1.0
	var total := 0.0
	for r: InstallRecord in installs.values():
		total += r.quality
	return total / installs.size()
