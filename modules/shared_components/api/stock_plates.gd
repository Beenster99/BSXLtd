class_name StockPlates
extends RefCounted
## BSX-only stock plates (data/stock/plates.json): flat metal and glass plates in standard
## sizes and thicknesses that BSX buys from suppliers, keeps on the plate hall's shelves and
## cuts to shape on the plasma bed. Void Salvage has none of these; they never go into a
## ship file. Static and read once: every peer carries the same file, nothing is synced.
##
## Item ids: "<Kind>_<length>x<width>_<thickness>" in millimetres, length first:
## "SteelPlate_2500x1250_5". `items()` lists every one with {name, category, material,
## family, size (metres: x length, y thickness, z width), mass (kg), value (CR)} in the
## shape of Business's MarketCatalogue entries, so a supplier can list them as parts.
## `crush_materials` says what a plate, or a sheet part off a wreck, gives the smelter.

const PATH := "res://modules/shared_components/data/stock/plates.json"
## Of a plate's mass, what comes back out of the crusher (Ship and Bay's RECOVERY).
const RECOVERY := 0.75

static var _table: Dictionary = {}
static var _items: Dictionary = {}


static func table() -> Dictionary:
	if _table.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_table = parsed if parsed is Dictionary else {"kinds": {}, "families": {}, "sheet_parts": {}}
	return _table


## Reads the file again (tests and tools).
static func reread() -> void:
	_table = {}
	_items = {}


## Plate kinds ("SteelPlate", "GlassPlate", ...), sorted.
static func kinds() -> PackedStringArray:
	var out := PackedStringArray(table().get("kinds", {}).keys())
	out.sort()
	return out


## A kind: {display_name, family ("metal" or "glass"), material}.
static func kind(id: String) -> Dictionary:
	return table().get("kinds", {}).get(id, {})


## A family: {category, sizes [[length, width] mm], thicknesses [mm], credits_per_kg}.
static func family(id: String) -> Dictionary:
	return table().get("families", {}).get(id, {})


## The id of a plate: "SteelPlate_2500x1250_5". "" when that kind, size or thickness isn't
## stocked.
static func item_id(kind_id: String, length_mm: int, width_mm: int, thickness_mm: int) -> String:
	var id := "%s_%dx%d_%d" % [kind_id, length_mm, width_mm, thickness_mm]
	return id if items().has(id) else ""


## Every stocked plate: id -> {name, category, material, family, kind, length_mm, width_mm,
## thickness_mm, size (Vector3 m: x length, y thickness, z width), mass (kg), value (CR),
## blurb}.
static func items() -> Dictionary:
	if not _items.is_empty():
		return _items
	for k: String in kinds():
		var kd := kind(k)
		var fam := family(str(kd.get("family", "")))
		var mat := str(kd.get("material", "steel"))
		var density := float(Materials.info(mat)["density"])
		var price := float(Materials.info(mat)["price"])
		for s: Variant in fam.get("sizes", []):
			var l := int(s[0])
			var w := int(s[1])
			for t: Variant in fam.get("thicknesses", []):
				var th := int(t)
				var size := Vector3(l / 1000.0, th / 1000.0, w / 1000.0)
				var kg := snappedf(size.x * size.y * size.z * density, 0.1)
				var id := "%s_%dx%d_%d" % [k, l, w, th]
				_items[id] = {"name": "%s %d x %d, %d mm" % [kd.get("display_name", k), l, w, th],
						"category": str(fam.get("category", "")), "material": mat, "family": str(kd.get("family", "")),
						"kind": k, "length_mm": l, "width_mm": w, "thickness_mm": th, "size": size, "mass": kg,
						"value": maxi(1, roundi(kg * float(fam.get("credits_per_kg", 1.0)) * price)),
						"blurb": "%s stock, %s mm thick, for cutting to shape on the plasma bed." % [Materials.display_name(mat), th]}
	return _items


static func is_plate(id: String) -> bool:
	return items().has(id)


static func item(id: String) -> Dictionary:
	return items().get(id, {})


## Plate ids, optionally one family's ("metal", "glass") or one kind's, sorted by kind,
## then size, then thickness.
static func item_ids(family_id := "", kind_id := "") -> PackedStringArray:
	var rows: Array = []
	for id: String in items():
		var it: Dictionary = items()[id]
		if (family_id == "" or it["family"] == family_id) and (kind_id == "" or it["kind"] == kind_id):
			rows.append(it.merged({"id": id}))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.kind != b.kind:
			return a.kind < b.kind
		if a.length_mm * a.width_mm != b.length_mm * b.width_mm:
			return a.length_mm * a.width_mm < b.length_mm * b.width_mm
		return a.thickness_mm < b.thickness_mm)
	var out := PackedStringArray()
	for r: Dictionary in rows:
		out.append(r.id)
	return out


## A plate's shape for the shelves, a trolley or the plasma bed: a flat box, length along
## x, thickness along y, width along z, centred on the origin. null for an unknown id.
static func make_shape(id: String) -> PartShapes.PartShape:
	var it := item(id)
	if it.is_empty():
		return null
	return PartShapes.box(it["size"])


## A plate's paint: steel grey, alloy pale, titanium blue-grey; glass a tinted pane.
static func paint(id: String) -> Material:
	match str(item(id).get("material", "")):
		"alloy":
			return ShipKit.paint(Color(0.72, 0.74, 0.77), 0.7, 0.35)
		"titanium":
			return ShipKit.paint(Color(0.55, 0.58, 0.66), 0.75, 0.4)
		"glass", "crystal":
			return ShipKit.glass()
	return ShipKit.paint(Color(0.45, 0.47, 0.5), 0.6, 0.5)


## Is this a Void Salvage sheet part (a hull plate, lining panel, deck plate, window
## pane) that crushes back into its own material?
static func is_sheet(part_name: String) -> bool:
	for fam: String in ["metal", "glass"]:
		if (table().get("sheet_parts", {}).get(fam, []) as Array).has(part_name):
			return true
	return false


## What `qty` of a plate or a sheet part crushes into: material id -> kg, at RECOVERY.
## `mass` (kg each) and `material` are needed for a sheet part (its own, as it came off
## the wreck: PartData.mass, PartData.material); a plate knows its own. {} for anything
## else, so the crusher falls back on its category mix.
static func crush_materials(id: String, qty: int, mass := 0.0, material := "") -> Dictionary:
	var it := item(id)
	if not it.is_empty():
		return {str(it["material"]): snappedf(float(it["mass"]) * qty * RECOVERY, 0.1)}
	# A piece cut from a plate ("<plate id>:cut:<template>"): its own mass, the plate's material.
	var cut := id.find(":cut:")
	if cut > 0 and is_plate(id.left(cut)):
		if mass <= 0.0:
			return {}
		return {str(item(id.left(cut))["material"]): snappedf(mass * qty * RECOVERY, 0.1)}
	if not is_sheet(id) or mass <= 0.0:
		return {}
	var glassy := (table().get("sheet_parts", {}).get("glass", []) as Array).has(id)
	var mat := material
	if glassy and not mat in ["glass", "crystal"]:
		mat = "glass"   # a pane built as "steel" (Void Salvage's default) is still glass
	elif mat == "" or not Materials.TABLE.has(mat):
		mat = "steel"
	return {mat: snappedf(mass * qty * RECOVERY, 0.1)}
