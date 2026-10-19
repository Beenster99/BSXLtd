class_name ProgressionCert
extends Resource
## A certification (internal/data/certs/<id>.tres): earned by passing the test job
## `test_job_id` with at least `min_level` in `skill`.

@export var version := 1
@export var id: StringName = &""
@export var display_name := ""
@export var skill: StringName = &""
@export var min_level := 1
@export var test_job_id: StringName = &""
## Closed jobs before it lapses and must be re-taken; 0 means it never lapses.
@export var valid_for_jobs := 0
