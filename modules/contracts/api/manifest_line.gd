class_name ManifestLine
extends Resource
## One line of a work order's parts manifest.

const SOURCES: PackedStringArray = ["new", "refurbished", "salvaged"]
const SUPPLIERS: PackedStringArray = ["client", "bsx"]

@export var line_id := ""
@export var component: ComponentRef
@export var qty := 1
## "client" (the client sends it) or "bsx" (BSX orders it).
@export var supplied_by := "bsx"
## Which of SOURCES the client accepts.
@export var allowed_sources: PackedStringArray = PackedStringArray(["new"])
