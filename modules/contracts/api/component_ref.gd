class_name ComponentRef
extends Resource
## A part or ship module named the way Void Salvage names it: a PartCatalog part_name
## ("IonThruster") or a shared ship module id ("attractor_coil_1"), with an optional
## Materials id. Written in contract files as {"id": ..., "material": ..., "version": ...}.

@export var id := ""
## A Void Salvage Materials id ("steel", "alloy", "copper"), or "" when the file gives none.
@export var material := ""
## 0 when the file gives none: Void Salvage has no per-component versions today.
@export var version := 0


static func from_dict(d: Dictionary) -> ComponentRef:
	var r := ComponentRef.new()
	r.id = String(d.get("id", ""))
	r.material = String(d.get("material", ""))
	r.version = int(d.get("version", 0))
	return r


func to_dict() -> Dictionary:
	var d := {"id": id}
	if material != "":
		d["material"] = material
	if version > 0:
		d["version"] = version
	return d


func _to_string() -> String:
	return id if material == "" else "%s (%s)" % [id, material]
