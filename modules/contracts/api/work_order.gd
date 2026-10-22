class_name WorkOrder
extends Resource
## A Void Salvage work order as BSX reads it (docs: the Contracts module spec). Built by
## ContractsBus.import_work_order() from a `<contract_id>.workorder.json` file; read-only
## for other modules.

const SCHEMA := "bsx.work_order"
## The newest schema_version this build reads. Older files are upgraded on import.
const SCHEMA_VERSION := 1

## What the client wants done (the scrapyard loop, plan stage S1). FIT is the original
## job: change what is fitted to a ship. The others take a subject in and give back what
## `wants` says.
const FIT := "fit"
const BREAK := "break"
const SCRAP := "scrap"
const REFURBISH := "refurbish"
const DISPOSE := "dispose"
const KINDS: PackedStringArray = [FIT, BREAK, SCRAP, REFURBISH, DISPOSE]
## What arrives: a ship (the crew's, by design), a wreck (a Void Salvage wreck file; stage
## S3), or a part on a trolley (S1).
const SUBJECT_TYPES: PackedStringArray = ["ship", "wreck", "part"]
## What a `wants` line asks for: a named part back (break), kilograms of a material
## (scrap), the subject back at a condition (refurbish), or the subject gone (dispose).
const WANT_TYPES: PackedStringArray = ["part", "material", "condition", "gone"]

@export var contract_id := ""
## A title for the board, when the file gives one; else the board makes one from the job.
@export var title := ""
@export var issued_at := ""
## One of KINDS; files without one are FIT.
@export var kind := FIT
## {type (SUBJECT_TYPES), component (ComponentRef, for a part), condition (0 to 1),
## mass_kg, design (for a ship or wreck), file (a wreck file path, S3)}. A FIT order's
## subject is its ship.
@export var subject: Dictionary = {}
## Each {what (WANT_TYPES), component (ComponentRef)?, qty?, min_condition?, material?, kg?}.
@export var wants: Array[Dictionary] = []
## Who keeps whatever `wants` does not name: "bsx" or "client".
@export var keeps := "bsx"
## Hazards the subject carries: "fuel", "coolant", "power", "weapons", "pressure".
@export var hazards: PackedStringArray = []
## {company, display_name, game ("void_salvage" or "bsx_generated")}.
@export var client: Dictionary = {}
## "<company>/<design>", for example "rook_salvage/kestrel".
@export var ship_id := ""
## A Void Salvage ShipCatalog id: "kestrel" or "manta".
@export var design := ""
## What is fitted now: {slot, component (ComponentRef), condition (0.1 to 1)}.
@export var current_fit: Array[Dictionary] = []
@export var changes: Array[ChangeItem] = []
@export var manifest: Array[ManifestLine] = []
## True when each part's own library build data applies under the overrides.
@export var use_library := true
## change_id -> {bolt: {...}, rivet: {...}, weld: {...}, connector: {...}}.
@export var overrides: Dictionary = {}
## Each {text, change_id?, attachment?}.
@export var notes: Array[Dictionary] = []
## {price, currency, deposit_pct, deadline, late_penalty_per_day}; empty if none.
@export var commercial: Dictionary = {}
## The file's data after upgrading, unknown fields included, so a re-save keeps them.
@export var raw: Dictionary = {}


func is_fit() -> bool:
	return kind == FIT


## The part that arrives, for a part subject; null for a ship or wreck.
func subject_part() -> ComponentRef:
	return subject.get("component") if subject.get("component") is ComponentRef else null


func change(change_id: String) -> ChangeItem:
	for c in changes:
		if c.change_id == change_id:
			return c
	return null


## Notes about one change, or about the whole job when change_id is "".
func notes_for(change_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for n in notes:
		if String(n.get("change_id", "")) == change_id:
			out.append(String(n.get("text", "")))
	return out


func to_json() -> String:
	return JSON.stringify(raw, "  ")
