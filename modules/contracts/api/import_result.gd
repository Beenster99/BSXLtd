class_name ImportResult
extends RefCounted
## What ContractsBus.import_work_order() returns: the new job's id, or the reasons the file
## was refused, each a line the foreman can read.

var job_id := ""
var errors: PackedStringArray = []


func ok() -> bool:
	return errors.is_empty() and job_id != ""
