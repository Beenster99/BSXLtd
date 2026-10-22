class_name SurveyRules
extends Resource
## How the independent surveyors work: when they turn up unannounced, how much they look at
## and how long a visit takes. Tuning lives in internal/data/survey_rules.tres.

@export var version := 1
## A spot survey turns up somewhere between these many seconds after the last visit, while
## a job is in progress and there's new work to look at.
@export var random_min_s := 240.0
@export var random_max_s := 480.0
## Joints a spot survey scans (picked at random from the work since the last visit).
@export var random_sample := 6
## Joints a called survey scans at most (the newest work first).
@export var called_sample := 12
## Surveyors on a spot or called visit, and on the final survey.
@export var crew := 1
@export var final_crew := 2
## A visit lasts arrive_s plus per_joint_s for each joint a surveyor has to scan.
@export var arrive_s := 20.0
@export var per_joint_s := 10.0
## How long a surveyor stands scanning a joint, and how fast they walk (m/s).
@export var scan_s := 4.0
@export var walk_speed := 1.4
## Reports kept in the save (oldest go first).
@export var keep_reports := 30
