class_name ContractsBus
extends Node
## Contracts module bus (Modules.bus("contracts")). Work order import, as-built export, and the active job's blueprint, spec sheet and parts manifest.
## Other modules use this module only through this folder: signals here, and resource
## classes placed next to it. Everything else lives in internal/.
##
## Only the host imports files and changes jobs; Multiplayer replays these signals to the
## other players. File formats and job states: the Contracts module spec.

signal contract_imported(job_id: String)
## errors: lines the foreman can read on the planning table.
signal import_failed(path: String, errors: PackedStringArray)
signal active_job_changed(job_id: String)
signal job_state_changed(job_id: String, from_state: String, to_state: String)
signal change_status_changed(job_id: String, change_id: String, status: String)
signal variation_raised(job_id: String, variation: Dictionary)
signal as_built_exported(job_id: String, path: String)
## Convenience signals for Business and Progression, fired alongside job_state_changed.
## value is the contract price; due_day is the game day it is due (commercial.due_day in
## the work order), or NO_DUE_DAY when it has none.
signal contract_accepted(contract_id: String, value: int, due_day: int)
## quality is the mean install quality, 0 to 1.
signal contract_handed_over(contract_id: String, quality: float, open_snags: int)
signal contract_cancelled(contract_id: String, by_client: bool)
signal job_closed(job_id: String)

const SAVE_VERSION := 1
const NO_DUE_DAY := 1_000_000

const Reader := preload("res://modules/contracts/internal/work_order_reader.gd")
const Writer := preload("res://modules/contracts/internal/as_built_writer.gd")
const Store := preload("res://modules/contracts/internal/job_store.gd")

var _jobs: Dictionary = {}
var _active := ""
## Callable(id: String) -> bool, and Callable(id: String) -> Dictionary of library build
## data per joint kind ({bolt: {...}, ...}). Unset, every id is accepted and the spec is the
## work order's overrides alone. Wired to Shared Components once that module is a dependency.
var _component_exists: Callable
var _library_spec: Callable


func register_module() -> void:
	Saves.register_section("contracts", self)


func unregister_module() -> void:
	Saves.unregister_section("contracts")


func set_component_library(exists: Callable, library_spec: Callable = Callable()) -> void:
	_component_exists = exists
	_library_spec = library_spec


# Import

func import_work_order(path: String) -> ImportResult:
	var result := ImportResult.new()
	if not FileAccess.file_exists(path):
		result.errors.append("No file at %s." % path)
	else:
		result = import_text(FileAccess.get_file_as_string(path))
	if not result.ok():
		import_failed.emit(path, result.errors)
	return result


## Reads a work order from JSON text (the file picker and tests use this through
## import_work_order; Multiplayer may pass text received from the host).
func import_text(text: String) -> ImportResult:
	var result := ImportResult.new()
	var reader := Reader.new()
	reader.component_exists = _component_exists
	var order := reader.read_text(text)
	if order == null:
		result.errors = reader.errors
		return result
	if _jobs.has(order.contract_id):
		result.errors.append("Contract %s is already in the bay." % order.contract_id)
		return result
	var job := ContractJob.new()
	job.job_id = order.contract_id
	job.order = order
	for c in order.changes:
		job.change_status[c.change_id] = ChangeItem.PENDING
	_jobs[job.job_id] = job
	result.job_id = job.job_id
	contract_imported.emit(job.job_id)
	if _active == "":
		set_active_job(job.job_id)
	return result


# Reading jobs

func get_job(job_id: String) -> ContractJob:
	return _jobs.get(job_id)


func get_active_job() -> ContractJob:
	return _jobs.get(_active)


func job_ids() -> PackedStringArray:
	return PackedStringArray(_jobs.keys())


func set_active_job(job_id: String) -> void:
	if job_id != "" and not _jobs.has(job_id):
		return
	if job_id == _active:
		return
	_active = job_id
	active_job_changed.emit(job_id)


## What a change must meet: its part's library build data with the work order's overrides
## on top. Null for an unknown job or change.
func get_spec(job_id: String, change_id: String) -> SpecEntry:
	var job := get_job(job_id)
	var c := job.order.change(change_id) if job else null
	if c == null:
		return null
	var spec := SpecEntry.new()
	spec.change_id = change_id
	spec.component = c.install if c.install else c.remove
	if job.order.use_library and _library_spec.is_valid() and spec.component:
		spec.apply(_library_spec.call(spec.component.id))
	spec.apply(job.order.overrides.get(change_id, {}))
	return spec


# Changing jobs

## Moves a job to another state; false if the move is not allowed (see ContractJob.NEXT).
## Until Business is switched on, an offered job may go straight to parts_ready.
func advance(job_id: String, to_state: String, by_client := false) -> bool:
	var job := get_job(job_id)
	if job == null:
		return false
	var from_state := job.state
	var skip_business := from_state == ContractJob.OFFERED and to_state == ContractJob.PARTS_READY \
			and not Modules.is_loaded("business")
	if not skip_business and not ContractJob.can_move(from_state, to_state):
		return false
	job.state = to_state
	if to_state == ContractJob.IN_PROGRESS and from_state == ContractJob.INSPECTION:
		# Rework: whatever failed inspection is back to installed for another go.
		for id: String in job.change_status:
			if job.change_status[id] == ChangeItem.FAILED:
				set_change_status(job_id, id, ChangeItem.INSTALLED)
	job_state_changed.emit(job_id, from_state, to_state)
	_emit_milestone(job, to_state, by_client)
	return true


## Cancels a job before handover; by_client tells Business who pays for it.
func cancel(job_id: String, by_client: bool) -> bool:
	return advance(job_id, ContractJob.CANCELLED, by_client)


func _emit_milestone(job: ContractJob, to_state: String, by_client: bool) -> void:
	match to_state:
		ContractJob.ACCEPTED:
			var c := job.order.commercial
			contract_accepted.emit(job.job_id, int(c.get("price", 0)), int(c.get("due_day", NO_DUE_DAY)))
		ContractJob.HANDED_OVER:
			contract_handed_over.emit(job.job_id, job.mean_quality(), job.open_snags)
		ContractJob.CANCELLED:
			contract_cancelled.emit(job.job_id, by_client)
		ContractJob.CLOSED:
			job_closed.emit(job.job_id)


func set_change_status(job_id: String, change_id: String, status: String) -> void:
	var job := get_job(job_id)
	if job == null or job.order.change(change_id) == null or not status in ChangeItem.STATUSES:
		return
	if job.change_status.get(change_id) == status:
		return
	job.change_status[change_id] = status
	change_status_changed.emit(job_id, change_id, status)


## Quality: the as-built line for a fitted change. A later record replaces an earlier one.
func record_install(job_id: String, change_id: String, record: InstallRecord) -> void:
	var job := get_job(job_id)
	var c := job.order.change(change_id) if job else null
	if c == null or not c.needs_install():
		return
	job.installs[change_id] = record


## Ship and Bay: how the part that came out of a slot left it.
func record_removal(job_id: String, change_id: String, condition: float, disposition := "returned") -> void:
	var job := get_job(job_id)
	var c := job.order.change(change_id) if job else null
	if c == null or not c.needs_removal():
		return
	job.removals[change_id] = {"condition": clampf(condition, 0.0, 1.0), "disposition": disposition}


## Quality: a commissioning test result.
func record_test(job_id: String, test_name: String, passed: bool, value := 0.0, unit := "") -> void:
	var job := get_job(job_id)
	if job:
		job.tests.append({"name": test_name, "passed": passed, "value": value, "unit": unit})


## Quality: who signed the job off, and how many snags were still open.
func sign_off(job_id: String, player_id: String, role: String, open_snags := 0) -> void:
	var job := get_job(job_id)
	if job:
		job.signed_by.append({"player_id": player_id, "role": role})
		job.open_snags = open_snags


## Logs a change order (hidden damage, a client change). Returns its id, or "" if no job.
func raise_variation(job_id: String, description: String, price_delta := 0.0) -> String:
	var job := get_job(job_id)
	if job == null:
		return ""
	var v := {"variation_id": "v%d" % (job.variations.size() + 1), "description": description,
			"price_delta": price_delta}
	job.variations.append(v)
	variation_raised.emit(job_id, v)
	return v["variation_id"]


# Handover

## The as-built record as data, or {} if the job is not handed over or a change has no
## install record yet.
func as_built(job_id: String) -> Dictionary:
	var job := get_job(job_id)
	if job == null or job.state != ContractJob.HANDED_OVER or not job.missing_installs().is_empty():
		return {}
	if job.completed_at == "":
		job.completed_at = Time.get_datetime_string_from_system(true) + "Z"
	return Writer.build(job, Modules.is_loaded("business"))


## Writes `<contract_id>.asbuilt.json` into dir (or to a full path ending in .json) and
## closes the job.
func export_as_built(job_id: String, path: String) -> Error:
	var record := as_built(job_id)
	if record.is_empty():
		return ERR_UNCONFIGURED
	if not path.ends_with(".json"):
		path = path.path_join("%s.asbuilt.json" % job_id)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(record, "  "))
	f.close()
	advance(job_id, ContractJob.CLOSED)
	as_built_exported.emit(job_id, path)
	return OK


# Save section (Saves calls these)

func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	var jobs := {}
	for id: String in _jobs:
		jobs[id] = Store.to_save(_jobs[id])
	return {"jobs": jobs, "active": _active}


func load_data(data: Dictionary, _from_version: int) -> void:
	_jobs = {}
	for id: String in data.get("jobs", {}):
		var errors := PackedStringArray()
		var job := Store.from_save(data["jobs"][id], errors)
		if job:
			_jobs[job.job_id] = job
		else:
			push_warning("Contracts: dropped saved job %s: %s" % [id, "; ".join(errors)])
	_active = ""
	set_active_job(String(data.get("active", "")))
