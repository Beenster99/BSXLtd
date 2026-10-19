extends RefCounted
## Brings an older work order up to WorkOrder.SCHEMA_VERSION before it is read, one step
## at a time, so the rest of the game only ever sees the newest shape. When a field is
## renamed or removed: bump WorkOrder.SCHEMA_VERSION, add `static func _v1_to_v2(d)` here
## and a case for it in step(). Adding an optional field needs no upgrade.


static func upgrade(d: Dictionary, from_version: int) -> Dictionary:
	var out := d.duplicate(true)
	for v in range(from_version, WorkOrder.SCHEMA_VERSION):
		out = step(out, v)
		out["schema_version"] = v + 1
	return out


static func step(d: Dictionary, from_version: int) -> Dictionary:
	match from_version:
		_:
			return d
