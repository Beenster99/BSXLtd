extends RefCounted
## Turns a finished ContractJob into the as-built record Void Salvage reads
## (`<contract_id>.asbuilt.json`, schema "bsx.as_built").

const SCHEMA := "bsx.as_built"
const SCHEMA_VERSION := 1


static func _subject(o: WorkOrder) -> Dictionary:
	var out := o.subject.duplicate()
	if out.get("component") is ComponentRef:
		out["component"] = (out["component"] as ComponentRef).to_dict()
	return out


static func build(job: ContractJob, business_on: bool) -> Dictionary:
	var installed: Array = []
	var removed: Array = []
	for c in job.order.changes:
		if c.needs_install():
			var rec: InstallRecord = job.installs[c.change_id]
			var ref := rec.component if rec.component else c.install
			installed.append({
				"change_id": c.change_id,
				"slot": c.slot,
				"component": ref.to_dict(),
				"serial": rec.serial,
				"source": rec.source,
				"quality": snappedf(rec.quality, 0.001),
				"joints": rec.joints,
				"defects": rec.defects,
			})
		if c.needs_removal():
			var r: Dictionary = job.removals.get(c.change_id, {})
			removed.append({
				"slot": c.slot,
				"component": c.remove.to_dict(),
				"condition": snappedf(float(r.get("condition", 1.0)), 0.001),
				"disposition": String(r.get("disposition", "returned")),
			})
	var d := {
		"schema": SCHEMA,
		"schema_version": SCHEMA_VERSION,
		"contract_id": job.order.contract_id,
		"kind": job.order.kind,
		"ship_id": job.order.ship_id,
		"subject": _subject(job.order),
		"recovered": job.recoveries,
		"completed_at": job.completed_at,
		"signed_by": job.signed_by,
		"installed": installed,
		"removed": removed,
		"tests": job.tests,
		"open_snags": job.open_snags,
		"variations": job.variations,
	}
	if business_on and not job.order.commercial.is_empty():
		var total := float(job.order.commercial.get("price", 0.0))
		for v in job.variations:
			total += float(v.get("price_delta", 0.0))
		var deposit := total * float(job.order.commercial.get("deposit_pct", 0.0)) / 100.0
		d["invoice"] = {"total": total, "deposit_paid": deposit, "balance": total - deposit,
				"currency": String(job.order.commercial.get("currency", "cr"))}
	return d
