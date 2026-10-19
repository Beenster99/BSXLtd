extends RefCounted
## Jobs to and from the Contracts save section. A job saves its work order's file data
## (re-read on load, so upgrades apply) and what has happened to it since.

const Reader := preload("res://modules/contracts/internal/work_order_reader.gd")


static func to_save(job: ContractJob) -> Dictionary:
	var installs := {}
	for id: String in job.installs:
		var r: InstallRecord = job.installs[id]
		installs[id] = {"component": r.component.to_dict() if r.component else {},
				"serial": r.serial, "source": r.source, "quality": r.quality,
				"joints": r.joints, "defects": r.defects}
	return {"order": job.order.raw, "state": job.state, "change_status": job.change_status,
			"installs": installs, "removals": job.removals, "variations": job.variations,
			"signed_by": job.signed_by, "tests": job.tests, "open_snags": job.open_snags,
			"completed_at": job.completed_at}


## Rebuilds a job, or null if its work order no longer reads (the reason goes to errors).
static func from_save(d: Dictionary, errors: PackedStringArray) -> ContractJob:
	var reader := Reader.new()
	var order := reader.read(d.get("order", {}))
	if order == null:
		errors.append_array(reader.errors)
		return null
	var job := ContractJob.new()
	job.job_id = order.contract_id
	job.order = order
	job.state = String(d.get("state", ContractJob.OFFERED))
	job.change_status = d.get("change_status", {})
	for id: String in d.get("installs", {}):
		var s: Dictionary = d["installs"][id]
		var r := InstallRecord.new()
		var comp: Dictionary = s.get("component", {})
		r.component = ComponentRef.from_dict(comp) if comp.has("id") else null
		r.serial = String(s.get("serial", ""))
		r.source = String(s.get("source", "new"))
		r.quality = float(s.get("quality", 1.0))
		r.joints = s.get("joints", {})
		r.defects.assign(s.get("defects", []))
		job.installs[id] = r
	job.removals = d.get("removals", {})
	job.variations.assign(d.get("variations", []))
	job.signed_by.assign(d.get("signed_by", []))
	job.tests.assign(d.get("tests", []))
	job.open_snags = int(d.get("open_snags", 0))
	job.completed_at = String(d.get("completed_at", ""))
	return job
