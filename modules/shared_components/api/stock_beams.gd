class_name StockBeams
extends RefCounted
## BSX-only stock beams (data/stock/beams.json): straight bars of box tube, I-beam, channel
## and angle in steel, alloy and titanium, 6 m and 12 m long, that BSX buys from suppliers,
## cuts to length on the plasma bed and builds into beam assemblies. Void Salvage has none of
## these; they never go into a ship file. Static and read once: every peer carries the same
## file, nothing is synced. The beams' twin of StockPlates.
##
## Item ids: "<Material><Kind>_<w>x<h>x<t>_<length>" in millimetres: "SteelBox_100x100x5_6000".
## `items()` lists every one with {name, category, material, family (box, i, channel, angle),
## section {w, h, t} (metres), length (m), mass (kg), value (CR), blurb} in the shape of
## Business's MarketCatalogue entries, so a supplier can list them as parts.
##   StockBeams.item_id("steel", "box", 100, 100, 5, 6000)   # "SteelBox_100x100x5_6000"
##   StockBeams.outline(id)    # the section's outer edge, metres, centred
##   StockBeams.holes(id)      # its inner edges (a box tube's bore), metres
##   StockBeams.make_shape(id) # the bar, length along x

const PATH := "res://modules/shared_components/data/stock/beams.json"
const FAMILIES: PackedStringArray = ["box", "i", "channel", "angle"]

static var _table: Dictionary = {}
static var _items: Dictionary = {}


static func table() -> Dictionary:
	if _table.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_table = parsed if parsed is Dictionary else {"materials": {}, "families": {}, "lengths": []}
	return _table


## Reads the file again (tests and tools).
static func reread() -> void:
	_table = {}
	_items = {}


## The stocked materials ("alloy", "steel", "titanium"), sorted.
static func materials() -> PackedStringArray:
	var out := PackedStringArray(table().get("materials", {}).keys())
	out.sort()
	return out


## A family ("box", "i", "channel", "angle"): {display_name, kind, sections [[w, h, t] mm]}.
static func family(id: String) -> Dictionary:
	return table().get("families", {}).get(id, {})


## Stocked bar lengths in millimetres (6000, 12000).
static func lengths() -> PackedInt32Array:
	return PackedInt32Array(table().get("lengths", []))


## The id of a bar: "SteelBox_100x100x5_6000". "" when that material, family, section or
## length isn't stocked.
static func item_id(material: String, family_id: String, w_mm: int, h_mm: int, t_mm: int, length_mm: int) -> String:
	var m: Dictionary = table().get("materials", {}).get(material, {})
	var id := "%s%s_%dx%dx%d_%d" % [str(m.get("prefix", "")), str(family(family_id).get("kind", "")), w_mm, h_mm, t_mm, length_mm]
	return id if items().has(id) else ""


## Every stocked bar: id -> {name, category, material, family, kind, w_mm, h_mm, t_mm,
## length_mm, section {w, h, t} (m), length (m), area (m2), size (Vector3 m: x length, y
## height, z width), mass (kg), value (CR), blurb}.
static func items() -> Dictionary:
	if not _items.is_empty():
		return _items
	var category := str(table().get("category", "stock_beams"))
	var per_kg := float(table().get("credits_per_kg", 1.0))
	for mat: String in materials():
		var md: Dictionary = table()["materials"][mat]
		var density := float(Materials.info(mat)["density"])
		var price := float(Materials.info(mat)["price"])
		for fam_id: String in FAMILIES:
			var fam := family(fam_id)
			for s: Variant in fam.get("sections", []):
				var w := int(s[0])
				var h := int(s[1])
				var t := int(s[2])
				var area := section_area(fam_id, w / 1000.0, h / 1000.0, t / 1000.0)
				for l: int in lengths():
					var kg := snappedf(area * l / 1000.0 * density, 0.1)
					var id := "%s%s_%dx%dx%d_%d" % [md.get("prefix", mat), fam.get("kind", fam_id), w, h, t, l]
					_items[id] = {"name": "%s %s %d x %d x %d, %d m" % [md.get("display_name", mat), fam.get("display_name", fam_id), w, h, t, l / 1000],
							"category": category, "material": mat, "family": fam_id, "kind": str(fam.get("kind", "")),
							"w_mm": w, "h_mm": h, "t_mm": t, "length_mm": l,
							"section": {"w": w / 1000.0, "h": h / 1000.0, "t": t / 1000.0}, "length": l / 1000.0, "area": area,
							"size": Vector3(l / 1000.0, h / 1000.0, w / 1000.0), "mass": kg,
							"value": maxi(1, roundi(kg * per_kg * price)),
							"blurb": "%s %s stock, %d m long, for cutting to length on the plasma bed." % [Materials.display_name(mat), fam.get("display_name", fam_id), l / 1000]}
	return _items


static func is_beam(id: String) -> bool:
	return items().has(id)


static func item(id: String) -> Dictionary:
	return items().get(id, {})


## Bar ids, optionally one family's or one material's, sorted by material, family (box, i,
## channel, angle), section area, then length.
static func item_ids(family_id := "", material := "") -> PackedStringArray:
	var rows: Array = []
	for id: String in items():
		var it: Dictionary = items()[id]
		if (family_id == "" or it["family"] == family_id) and (material == "" or it["material"] == material):
			rows.append(it.merged({"id": id}))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.material != b.material:
			return a.material < b.material
		if a.family != b.family:
			return FAMILIES.find(a.family) < FAMILIES.find(b.family)
		if a.area != b.area:
			return a.area < b.area
		return a.length_mm < b.length_mm)
	var out := PackedStringArray()
	for r: Dictionary in rows:
		out.append(r.id)
	return out


## A section's outer edge in metres, counter-clockwise, centred on its bounding box: u across
## the width, v up the height. A channel opens toward +u; an angle's legs run along the
## bottom and up the -u side. Empty for an unknown id.
static func outline(id: String) -> PackedVector2Array:
	var it := item(id)
	if it.is_empty():
		return PackedVector2Array()
	return section_outline(str(it["family"]), it["section"]["w"], it["section"]["h"], it["section"]["t"])


## A section's inner edges (a box tube's bore; none for the open sections), metres, clockwise.
static func holes(id: String) -> Array[PackedVector2Array]:
	var it := item(id)
	if it.is_empty():
		return []
	return section_holes(str(it["family"]), it["section"]["w"], it["section"]["h"], it["section"]["t"])


static func section_outline(family_id: String, w: float, h: float, t: float) -> PackedVector2Array:
	var u := w * 0.5
	var v := h * 0.5
	match family_id:
		"box":
			return PackedVector2Array([Vector2(-u, -v), Vector2(u, -v), Vector2(u, v), Vector2(-u, v)])
		"i":
			var c := t * 0.5
			return PackedVector2Array([Vector2(-u, -v), Vector2(u, -v), Vector2(u, -v + t), Vector2(c, -v + t),
					Vector2(c, v - t), Vector2(u, v - t), Vector2(u, v), Vector2(-u, v), Vector2(-u, v - t),
					Vector2(-c, v - t), Vector2(-c, -v + t), Vector2(-u, -v + t)])
		"channel":
			return PackedVector2Array([Vector2(-u, -v), Vector2(u, -v), Vector2(u, -v + t), Vector2(-u + t, -v + t),
					Vector2(-u + t, v - t), Vector2(u, v - t), Vector2(u, v), Vector2(-u, v)])
		"angle":
			return PackedVector2Array([Vector2(-u, -v), Vector2(u, -v), Vector2(u, -v + t), Vector2(-u + t, -v + t),
					Vector2(-u + t, v), Vector2(-u, v)])
	return PackedVector2Array()


static func section_holes(family_id: String, w: float, h: float, t: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if family_id == "box":
		var u := w * 0.5 - t
		var v := h * 0.5 - t
		out.append(PackedVector2Array([Vector2(-u, -v), Vector2(-u, v), Vector2(u, v), Vector2(u, -v)]))
	return out


## The section's area in square metres (the outline less its holes).
static func section_area(family_id: String, w: float, h: float, t: float) -> float:
	var a := absf(_signed_area(section_outline(family_id, w, h, t)))
	for hole in section_holes(family_id, w, h, t):
		a -= absf(_signed_area(hole))
	return a


## A bar's shape for the racks, a trolley, the plasma bed or the beam designer: the section
## extruded along x (its length), centred on the origin; collision its bounding box. null
## for an unknown id.
static func make_shape(id: String) -> PartShapes.PartShape:
	var it := item(id)
	if it.is_empty():
		return null
	return extrude(outline(id), holes(id), float(it["length"]), it["size"])


## Extrudes a counter-clockwise outline (and clockwise holes) along x, `length` long.
## `box` sizes the collision (defaults to the outline's bounds).
static func extrude(edge: PackedVector2Array, bores: Array[PackedVector2Array], length: float, box := Vector3.ZERO) -> PartShapes.PartShape:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var x0 := -length * 0.5
	var x1 := length * 0.5
	var loops: Array[PackedVector2Array] = [edge]
	loops.append_array(bores)
	# The walls: every edge of every loop, facing out of the metal.
	for loop in loops:
		for i in loop.size():
			var p := loop[i]
			var q := loop[(i + 1) % loop.size()]
			var d := q - p
			var out := Vector3(0.0, -d.x, d.y).normalized()   # (dv, -du) in (y, z)
			var a := Vector3(x0, p.y, p.x)
			var b := Vector3(x1, p.y, p.x)
			var c := Vector3(x1, q.y, q.x)
			var e := Vector3(x0, q.y, q.x)
			_tri(verts, normals, a, b, c, out)
			_tri(verts, normals, a, c, e, out)
	# The ends.
	for side: float in [x0, x1]:
		var out := Vector3(signf(side), 0.0, 0.0)
		if bores.is_empty():
			var idx := Geometry2D.triangulate_polygon(edge)
			for k in range(0, idx.size(), 3):
				_tri(verts, normals, _at(side, edge[idx[k]]), _at(side, edge[idx[k + 1]]), _at(side, edge[idx[k + 2]]), out)
		else:
			# A tube: the ring between its outline and its bore, corner by corner.
			var bore := bores[0].duplicate()
			bore.reverse()   # counter-clockwise, corners matching the outline's
			bore = PackedVector2Array([bore[bore.size() - 1]]) + bore.slice(0, bore.size() - 1)
			for i in edge.size():
				var j := (i + 1) % edge.size()
				_tri(verts, normals, _at(side, edge[i]), _at(side, edge[j]), _at(side, bore[j]), out)
				_tri(verts, normals, _at(side, edge[i]), _at(side, bore[j]), _at(side, bore[i]), out)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shape := PartShapes.PartShape.new()
	shape.mesh = mesh
	var col := BoxShape3D.new()
	if box == Vector3.ZERO:
		var r := Rect2(edge[0], Vector2.ZERO)
		for p in edge:
			r = r.expand(p)
		box = Vector3(length, r.size.y, r.size.x)
	col.size = box
	shape.collision = col
	var area := absf(_signed_area(edge))
	for bore in bores:
		area -= absf(_signed_area(bore))
	shape.volume = area * length
	return shape


static func _at(x: float, p: Vector2) -> Vector3:
	return Vector3(x, p.y, p.x)


## One triangle facing `out` (Godot draws front faces clockwise: the left-hand normal).
static func _tri(verts: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	if -(b - a).cross(c - a).dot(out) < 0.0:
		var s := b
		b = c
		c = s
	verts.append_array([a, b, c])
	normals.append_array([out, out, out])


static func _signed_area(loop: PackedVector2Array) -> float:
	var a := 0.0
	for i in loop.size():
		var p := loop[i]
		var q := loop[(i + 1) % loop.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## A bar's paint: steel grey, alloy pale, titanium blue-grey (as StockPlates').
static func paint(id: String) -> Material:
	match str(item(id).get("material", "")):
		"alloy":
			return ShipKit.paint(Color(0.72, 0.74, 0.77), 0.7, 0.35)
		"titanium":
			return ShipKit.paint(Color(0.55, 0.58, 0.66), 0.75, 0.4)
	return ShipKit.paint(Color(0.45, 0.47, 0.5), 0.6, 0.5)
