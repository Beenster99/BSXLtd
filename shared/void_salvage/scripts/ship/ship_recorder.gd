class_name ShipRecorder
extends RefCounted
## Records a ship's build as it happens, for the ship file (docs/SHIP_FORMAT_PLAN.md, the
## `vsship` format). Set one on a ShipKit (`kit.recorder`) before the design builds: every
## piece, wall, hull section, fitting, system and light the kit is given lands here as a
## record, in the order it was built, with the kit's current `group`. While a record is
## open (a fitting, a system, a wall, a hull section) the pieces it adds fold into it
## instead of being recorded one by one; nested ones fold into the outermost.
##
## Records hold the engine's own values (Vector3, Transform3D, Material...); `encode` turns
## them into the file's JSON types and `to_json`/`canonical`/`body_hash` write them.
## Shared with BSX: names only ShipKit, PartShapes and the engine.

## The file's blocks, in build order within each: raw records (see SHIP_FORMAT_PLAN 4.6).
var hulls: Array[Dictionary] = []
var walls: Array[Dictionary] = []
var fittings: Array[Dictionary] = []
var systems: Array[Dictionary] = []
var pieces: Array[Dictionary] = []
var lights: Array[Dictionary] = []
## Everything the kit built, open records or not: mesh pieces, collision shapes, lights,
## solid volume (m^3) and the bounds of every piece (ship space).
var mesh_count: int = 0
var shape_count: int = 0
var light_count: int = 0
var volume: float = 0.0
var bounds := AABB()
## Top-level pieces whose shape has no recipe (a shape built by hand): the file cannot hold
## them. Their records keep an empty shape so the count shows where they are.
var recipe_less: int = 0

## Open records, outermost first: [record, block]. A nested or quiet one has block "".
var _open: Array = []
var _has_bounds := false


## Opens a record in `block` ("hulls", "walls", "fittings", "systems"; "" records nothing:
## the pieces it adds are counted but left out, e.g. what the layout rebuilds). Returns the
## record (an empty one when it is nested inside another).
func open(block: String, record: Dictionary, group: String) -> Dictionary:
	if not _open.is_empty() or block == "":
		_open.append([{}, ""])
		return {}
	record["group"] = group
	(get(block) as Array).append(record)
	_open.append([record, block])
	return record


## Closes the innermost record, merging `extra` into it if it was a top-level one.
func close(extra: Dictionary = {}) -> void:
	if _open.is_empty():
		push_error("ShipRecorder: close() with nothing open")
		return
	var top: Array = _open.pop_back()
	var record: Dictionary = top[0]
	if top[1] == "":
		return
	record.merge(extra, true)
	# A fitting says its own box; a system or wall gets the bounds of what it added.
	if record.has("_box"):
		if not record.has("box"):
			record["box"] = record["_box"]
		record.erase("_box")


## True while a record is open (pieces fold into it).
func is_open() -> bool:
	return not _open.is_empty()


## The kit added a piece.
func on_piece(shape: PartShapes.PartShape, xform: Transform3D, mat: Material, tag: String, glass_mat: Material,
		solid: bool, group: String, visual: bool = true) -> void:
	if visual:
		mesh_count += 1
	if solid:
		shape_count += 1
	volume += shape.volume
	var box := xform * (shape.mesh.get_aabb() if shape.mesh else AABB())
	bounds = box if not _has_bounds else bounds.merge(box)
	_has_bounds = true
	if not _open.is_empty():
		var outer: Dictionary = _open[0][0]
		if _open[0][1] != "":
			outer["_box"] = box if not outer.has("_box") else (outer["_box"] as AABB).merge(box)
			if tag != "":
				var tags: Array = outer.get_or_add("tags", [])
				if not tags.has(tag):
					tags.append(tag)
		return
	if shape.recipe.is_empty():
		recipe_less += 1
	var record := {"group": group, "shape": shape.recipe, "xform": xform, "mat": mat}
	if tag != "":
		record["tag"] = tag
	if not solid:
		record["solid"] = false
	if not visual:
		record["visual"] = false
	if glass_mat and shape.glass:
		record["glass_mat"] = glass_mat
	pieces.append(record)


## The kit added a light.
func on_light(at: Vector3, color: Color, energy: float, reach: float, shadows: bool, group: String) -> void:
	light_count += 1
	if not _open.is_empty():
		return
	lights.append({"group": group, "at": at, "color": color, "energy": energy, "range": reach, "shadows": shadows})


# --- Encoding ----------------------------------------------------------------------------

## Decimal places every float is written to (0.1 mm).
const PLACES: int = 4


## A value in the file's JSON types (SHIP_FORMAT_PLAN 4.1). `mat_name(Material) -> String`
## names materials; keys starting with "_" are left out.
static func encode(v: Variant, mat_name: Callable = Callable()) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return snappedf(v, 0.0001)
		TYPE_VECTOR2:
			return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001)]
		TYPE_VECTOR3:
			return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]
		TYPE_RECT2:
			var r: Rect2 = v
			return [snappedf(r.position.x, 0.0001), snappedf(r.position.y, 0.0001), snappedf(r.size.x, 0.0001),
					snappedf(r.size.y, 0.0001)]
		TYPE_AABB:
			var b: AABB = v
			return {"pos": encode(b.position), "size": encode(b.size)}
		TYPE_COLOR:
			var c: Color = v
			var out: Array = [snappedf(c.r, 0.0001), snappedf(c.g, 0.0001), snappedf(c.b, 0.0001)]
			if c.a < 0.99995:
				out.append(snappedf(c.a, 0.0001))
			return out
		TYPE_BASIS:
			var m: Basis = v
			# Rows of the matrix (the axes are its columns).
			return encode([m.x.x, m.y.x, m.z.x, m.x.y, m.y.y, m.z.y, m.x.z, m.y.z, m.z.z])
		TYPE_TRANSFORM3D:
			var t: Transform3D = v
			var out := {"o": encode(t.origin)}
			if not t.basis.is_equal_approx(Basis()):
				out["b"] = encode(t.basis)
			return out
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, \
				TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_ARRAY:
			var out: Array = []
			for e: Variant in v:
				out.append(encode(e, mat_name))
			return out
		TYPE_DICTIONARY:
			var out := {}
			for k: Variant in v:
				if String(k).begins_with("_"):
					continue
				out[String(k)] = encode(v[k], mat_name)
			return out
		TYPE_OBJECT:
			if v is Material and mat_name.is_valid():
				return mat_name.call(v)
			return null
		TYPE_STRING_NAME:
			return String(v)
	return v


## A number as the file writes it: at most PLACES decimals, no trailing zeros, no "-0".
static func number_text(f: float) -> String:
	var s := String.num(f, PLACES) if absf(f) < 1e15 else "%.0f" % f
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	if s == "-0" or s == "":
		s = "0"
	return s


## `v` (already encoded) as JSON text: one line with keys sorted when `indent` is "" (the
## canonical form), else pretty: keys in their own order, the top two levels indented and
## each record below them on one line.
static func to_json(v: Variant, indent: String = "", _depth: int = 0) -> String:
	var one_line := indent == "" or _depth >= 2
	var sep := "," if indent == "" else ", "
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return number_text(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return JSON.stringify(String(v))
		TYPE_ARRAY:
			var items: Array[String] = []
			var nested := false
			for e: Variant in v:
				items.append(to_json(e, indent, _depth + 1))
				nested = nested or typeof(e) == TYPE_ARRAY or typeof(e) == TYPE_DICTIONARY
			if one_line or not nested or items.is_empty():
				return "[" + sep.join(items) + "]"
			var pad := indent.repeat(_depth + 1)
			return "[
" + pad + (",
" + pad).join(items) + "
" + indent.repeat(_depth) + "]"
		TYPE_DICTIONARY:
			var keys: Array = (v as Dictionary).keys()
			if indent == "":
				keys.sort()
			var items: Array[String] = []
			for k: Variant in keys:
				items.append(JSON.stringify(String(k)) + (":" if indent == "" else ": ") + to_json(v[k], indent, _depth + 1))
			if one_line or items.is_empty():
				return "{" + sep.join(items) + "}"
			var pad := indent.repeat(_depth + 1)
			return "{
" + pad + (",
" + pad).join(items) + "
" + indent.repeat(_depth) + "}"
	return JSON.stringify(v)


## The canonical form (SHIP_FORMAT_PLAN 4.8): keys sorted, no whitespace, floats at 4
## decimals. Two programs agree on its bytes.
static func canonical(v: Variant) -> String:
	return to_json(v, "")


## "sha256:<hex>" of the canonical JSON of [hulls, walls, fittings, systems, pieces, slots]
## of an encoded file.
static func body_hash(file: Dictionary) -> String:
	var body: Array = []
	for block in ["hulls", "walls", "fittings", "systems", "pieces", "slots"]:
		body.append(file.get(block, []))
	return "sha256:" + canonical(body).sha256_text()
