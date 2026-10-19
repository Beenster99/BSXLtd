class_name InstallRecord
extends Resource
## What Quality hands Contracts when a change is fitted and inspected: the as-built line for
## it. Quality is 0 to 1 throughout, the same scale as Void Salvage's part condition.

@export var component: ComponentRef
@export var serial := ""
## One of ManifestLine.SOURCES.
@export var source := "new"
@export_range(0.0, 1.0) var quality := 1.0
## Per joint kind ("bolt", "rivet", "weld", "connector"): {count, min, mean}.
@export var joints: Dictionary = {}
## Each {type, severity (0 to 1), hidden (bool)}.
@export var defects: Array[Dictionary] = []
