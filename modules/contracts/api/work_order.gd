class_name WorkOrder
extends Resource
## A Void Salvage work order as BSX reads it (docs: the Contracts module spec). Built by
## ContractsBus.import_work_order() from a `<contract_id>.workorder.json` file; read-only
## for other modules.

const SCHEMA := "bsx.work_order"
## The newest schema_version this build reads. Older files are upgraded on import.
const SCHEMA_VERSION := 1

@export var contract_id := ""
@export var issued_at := ""
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
