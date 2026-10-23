class_name VsShipImport
extends RefCounted
## Reads a Void Salvage `vsship` 2.0 file (a frame-built ship: parts and joints with the
## recipes that made them; Void Salvage docs/SHIP_FORMAT_PLAN.md section 10) and builds the
## ship onto a `RigidBody3D` with the synced builders: every derived part from its library
## shape recipe through `ShipKit.part`, every joint through `ShipKit.join` (so the body holds
## a `PartModel` with the same paths, kinds, heads and phases the file has), the fittings'
## looks from their `ShipParts` records, the loose pieces as visuals, the lights.
##
## The parts and joints are the truth (what a work order points at); the fittings' records
## only dress them. Nothing here rebuilds the recipe (the frame, decks, walls and services):
## that is Void Salvage's loader (F7b) and, later, BSX's structural jobs.
##
## Use: `var im := VsShipImport.new(); im.build(VsShipImport.read(path), body)`; then
## `im.part_at("hull/bay:hold/plate/e3/1")`, `im.joint_at(...)`, `im.kit.model`. `check(file)`
## validates a file (version, schema, hashes, unique paths, joints' ends) without building.

const SCHEMA_PATH := "res://shared/void_salvage/data/ship_format/vsship-2.schema.json"
## Recipe names that are not a library constructor's own name.
const RECIPE_ALIASES := {"pipe": "pipe_shape", "pipe_elbow": "pipe_elbow_shape", "pipe_union": "pipe_union_shape"}
## A unit piece within this (m) of its part's box, in position and size, covers that part's visual.
const SAME_BOX_M := 0.003

var file: Dictionary = {}
var kit: ShipKit
var body: RigidBody3D
## Part path -> PartData; joint path -> ConnectionData.
var parts_by_path: Dictionary = {}
var joints_by_path: Dictionary = {}
## Material name (the file's `materials` key) -> Material.
var materials: Dictionary = {}
## Fitting path -> the `ShipParts` result {name, box} where its record was rebuilt.
var fittings_built: Dictionary = {}
## Paths of parts whose plain visual a unit's look pieces cover (hidden under them).
var hidden_visuals: PackedStringArray = []
var errors: PackedStringArray = []
var warnings: PackedStringArray = []

static var _method_cache: Dictionary = {}


## Parses a file; {} (and a pushed error) when it cannot be read or is not JSON.
static func read(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("VsShipImport: cannot read %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("VsShipImport: %s is not a JSON object" % path)
	return {}


## Every problem with a file as data, before anything is built: the format and version, the
## schema, the two hashes against a recount, duplicate paths, joints whose parts are missing.
static func check(f: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	if f.get("format", "") != "vsship":
		out.append("format is %s, not vsship" % str(f.get("format", "")))
	var version: Variant = f.get("version", [])
	if not (version is Array and version.size() >= 1 and int(version[0]) == 2):
		out.append("version %s is not 2.x" % str(version))
		return out
	var schema := JsonSchema.load_schema(SCHEMA_PATH)
	if schema.is_empty():
		out.append("schema %s missing" % SCHEMA_PATH)
	else:
		for e: String in JsonSchema.validate(f, schema):
			out.append("schema: " + e)
	var derived: Dictionary = f.get("derived", {})
	if derived.has("parts_hash") and ShipRecorder.parts_hash(f) != derived["parts_hash"]:
		out.append("parts_hash does not match the parts and joints")
	if derived.has("body_hash") and ShipRecorder.body_hash(f) != derived["body_hash"]:
		out.append("body_hash does not match the recipe blocks")
	var paths := {}
	for p: Dictionary in f.get("parts", []):
		var path: String = p.get("path", "")
		if path == "":
			out.append("part %d has no path" % int(p.get("id", -1)))
		elif paths.has(path):
			out.append("part path %s twice" % path)
		paths[path] = true
	var jpaths := {}
	for j: Dictionary in f.get("joints", []):
		var path: String = j.get("path", "")
		if path == "":
			out.append("joint %d has no path" % int(j.get("id", -1)))
		elif jpaths.has(path):
			out.append("joint path %s twice" % path)
		jpaths[path] = true
		for end in ["a", "b"]:
			if not paths.has(j.get(end, "")):
				out.append("joint %s: part %s missing" % [path, str(j.get(end, ""))])
	if derived.has("parts") and int(derived["parts"]) != f.get("parts", []).size():
		out.append("derived.parts says %d, file holds %d" % [int(derived["parts"]), f.get("parts", []).size()])
	if derived.has("joints") and int(derived["joints"]) != f.get("joints", []).size():
		out.append("derived.joints says %d, file holds %d" % [int(derived["joints"]), f.get("joints", []).size()])
	return out


## Builds the ship from `f` onto `target`. False when nothing could be built; `errors` and
## `warnings` say what went wrong part by part (a part whose recipe is unknown is skipped
## with a warning and its joints with it).
func build(f: Dictionary, target: RigidBody3D) -> bool:
	file = f
	body = target
	errors.clear()
	warnings.clear()
	if f.is_empty():
		errors.append("empty file")
		return false
	var version: Variant = f.get("version", [])
	if not (version is Array and version.size() >= 1 and int(version[0]) == 2):
		errors.append("not a vsship 2.x file")
		return false
	kit = ShipKit.new(target)
	kit.model = PartModel.new(target, true)   # ids numbered from 1 per ship, as a crew's ship
	_decode_materials()
	for p: Dictionary in f.get("parts", []):
		_build_part(p)
	for j: Dictionary in f.get("joints", []):
		_build_joint(j)
	for rec: Dictionary in f.get("fittings", []):
		_build_fitting(rec)
	for piece: Dictionary in f.get("pieces", []):
		_build_piece(piece)
	for l: Dictionary in f.get("lights", []):
		kit.group = l.get("group", "")
		kit.light(vec3(l.get("at", [0, 0, 0])), color(l.get("color", [1, 1, 1])), float(l.get("energy", 1.0)),
				float(l.get("range", 5.0)), bool(l.get("shadows", false)))
	kit.group = ""
	return parts_by_path.size() > 0


func part_at(path: String) -> PartData:
	return parts_by_path.get(path)


func joint_at(path: String) -> ConnectionData:
	return joints_by_path.get(path)


## The joints by their `phase` (frame, deck, skin, lining, wall, fitting, service), in file
## order: the closing-up sequence a job is staged by.
func joints_in_phase(phase: String) -> Array[ConnectionData]:
	var out: Array[ConnectionData] = []
	for j: Dictionary in file.get("joints", []):
		if j.get("phase", "") == phase and joints_by_path.has(j.get("path", "")):
			out.append(joints_by_path[j["path"]])
	return out


## The joints that hold a part: every joint whose `a` or `b` is `path`.
func joints_of(path: String) -> Array[ConnectionData]:
	var out: Array[ConnectionData] = []
	for j: Dictionary in file.get("joints", []):
		if (j.get("a", "") == path or j.get("b", "") == path) and joints_by_path.has(j.get("path", "")):
			out.append(joints_by_path[j["path"]])
	return out


# --- parts and joints ---------------------------------------------------------------------

func _build_part(p: Dictionary) -> void:
	var path: String = p.get("path", "")
	var shape := make_shape(p.get("shape", {}), p)
	if shape == null:
		warnings.append("part %s: no shape for recipe %s" % [path, str(p.get("shape", {}))])
		return
	kit.group = p.get("group", "")
	_fix_collision(shape)
	var kind: PartData.Kind = _part_kind(p.get("kind", "component"))
	var mat := material(p.get("mat", ""))
	var glass_mat: Material = material(p["glass_mat"]) if p.has("glass_mat") else null
	var made := kit.part(p.get("name", "Part"), kind, shape, xform(p.get("xform", {})), mat,
			p.get("tag", ""), 1.0, glass_mat, path)
	if p.has("mass"):
		made.mass = float(p["mass"])
	if p.has("material"):
		made.material = str(p["material"])
	if p.has("power"):
		var role: String = str(p["power"]).to_upper()
		if PartData.Power.has(role):
			made.power = PartData.Power[role]
	parts_by_path[path] = made


func _build_joint(j: Dictionary) -> void:
	var path: String = j.get("path", "")
	var a: PartData = parts_by_path.get(j.get("a", ""))
	var b: PartData = parts_by_path.get(j.get("b", ""))
	if a == null or b == null:
		warnings.append("joint %s: a part is missing (%s, %s)" % [path, str(j.get("a", "")), str(j.get("b", ""))])
		return
	var kind_name: String = str(j.get("kind", "weld")).to_upper()
	if not ConnectionData.Kind.has(kind_name):
		warnings.append("joint %s: unknown kind %s" % [path, kind_name])
		return
	kit.model.head_style = int(j.get("head", 0))
	kit.model.phase = str(j.get("phase", ""))
	var made := kit.join(a, b, ConnectionData.Kind[kind_name], vec3(j.get("at", [0, 0, 0])),
			vec3(j.get("normal", [0, 1, 0])), vec3(j.get("seam_up", [0, 0, 0])),
			vec2(j.get("seam_size", [0, 0])), path)
	if made:
		joints_by_path[path] = made


# --- fittings, pieces ------------------------------------------------------------------------

## A fitting record is one `ShipParts` call (its name, frame and arguments). Rebuilding it
## dresses the fitting's part with its real look (lit edges, cushions, labels); the part's own
## plain visual is hidden under it, its collision and joints stay the truth.
func _build_fitting(rec: Dictionary) -> void:
	var fitting_name: String = rec.get("fitting", "")
	var method := _static_method(ShipParts, fitting_name)
	if method.is_empty():
		warnings.append("fitting %s: ShipParts has no such builder" % fitting_name)
		return
	var raw: Array = rec.get("args", []).duplicate()
	if rec.has("frame"):
		raw.push_front(rec["frame"])
	var args := [kit]
	var params: Array = method.get("args", [])
	for i in raw.size():
		var ptype: int = int(params[i + 1].get("type", TYPE_NIL)) if i + 1 < params.size() else TYPE_NIL
		var hint: String = str(params[i + 1].get("hint_string", "")) if i + 1 < params.size() else ""
		args.append(convert_arg(raw[i], ptype, hint))
	kit.group = rec.get("group", "")
	var made: Variant = Callable(ShipParts, fitting_name).callv(args)
	if made == null:
		warnings.append("fitting %s: ShipParts.%s refused its arguments %s" % [rec.get("path", ""), fitting_name, str(raw)])
		return
	if true:
		var path: String = rec.get("path", "")
		fittings_built[path] = made if made is Dictionary else {}   # a lamp returns its light
		var part: PartData = parts_by_path.get(path)
		if part:
			var look := kit.model.part_visual(part.id)
			if look:
				look.visible = false


## A loose piece (trim, a unit's looks, a design's own part that is also in `parts`) drawn
## as a visual only: parts carry the collision.
func _build_piece(piece: Dictionary) -> void:
	if piece.has("part"):
		return   # already built from `parts` (by: "piece")
	var shape := make_shape(piece.get("shape", {}), piece)
	if shape == null:
		warnings.append("piece: no shape for recipe %s" % str(piece.get("shape", {})))
		return
	var at := xform(piece.get("xform", {}))
	var mat := material(str(piece.get("mat", "")) if piece.get("mat") != null else "")
	var glass_mat: Material = null
	if shape.glass:
		glass_mat = material(piece["glass_mat"]) if piece.has("glass_mat") else ShipKit.glass()
	kit.group = piece.get("group", "")
	# Through the kit's own `add`, so the look gets the same tiny inset Void Salvage's ShipKit
	# gives touching pieces (no z-fighting with its neighbours); `solid` false: no collision.
	var made := kit.add(shape, at, mat, "", glass_mat, false)
	(made["mesh"] as Node).set_meta("vs_piece", true)
	if shape.glow:
		var e := MeshInstance3D.new()
		e.mesh = shape.glow
		e.transform = at * made.get("vis", Transform3D.IDENTITY)
		e.material_override = ShipKit.glow(shape.glow_color, 2.0)
		body.add_child(e)
	if piece.has("unit"):
		_hide_under(str(piece["unit"]), at * shape.mesh.get_aabb())


## A unit's look piece (an engine's cowl, a door leaf's panel) sits exactly on the unit's part,
## whose plain visual from its recipe would z-fight with it: that visual goes off, as a fitting's
## does. The part keeps its collision and joints. `hidden_visuals` lists the parts by path.
func _hide_under(unit: String, box: AABB) -> void:
	for path: String in parts_by_path:
		if path != unit and not path.begins_with(unit + "/"):
			continue
		var part: PartData = parts_by_path[path]
		var look := kit.model.part_visual(part.id) as MeshInstance3D
		if look == null or not look.visible or look.mesh == null:
			continue
		var part_box := look.transform * look.mesh.get_aabb()
		if part_box.position.distance_to(box.position) < SAME_BOX_M and part_box.size.distance_to(box.size) < SAME_BOX_M:
			look.visible = false
			hidden_visuals.append(path)


# --- recipes --------------------------------------------------------------------------------

## A library shape from its recipe {shape, args}: the constructor's name in PartShapes,
## FrameParts, WreckParts or ShipParts (`RECIPE_ALIASES` for the pipe shapes), its arguments
## converted by the constructor's declared types. `rec` is the record it belongs to (a loom
## span needs its box). Null for an unknown recipe.
static func make_shape(recipe: Dictionary, rec: Dictionary = {}) -> PartShapes.PartShape:
	var shape_name: String = str(recipe.get("shape", ""))
	if shape_name == "":
		return null
	var raw: Array = recipe.get("args", [])
	if shape_name == "loom_span":
		return _loom_span(float(raw[0]) if raw.size() > 0 else 1.0, rec)
	var fn: String = RECIPE_ALIASES.get(shape_name, shape_name)
	for lib: Script in [PartShapes, FrameParts, WreckParts, ShipParts]:
		var method := _static_method(lib, fn)
		if method.is_empty():
			continue
		var args := []
		var params: Array = method.get("args", [])
		for i in raw.size():
			var ptype: int = int(params[i].get("type", TYPE_NIL)) if i < params.size() else TYPE_NIL
			var hint: String = str(params[i].get("hint_string", "")) if i < params.size() else ""
			args.append(convert_arg(raw[i], ptype, hint))
		var made: Variant = Callable(lib, fn).callv(args)
		if made is PartShapes.PartShape:
			return made
		return null
	return null


## A loom span's look is the loom's own (WiringLoom); its recipe names only its length, the
## loom record in `services` its wire spec. A plain main-power loom when the record is not
## at hand; the collision is the file's box.
static func _loom_span(length: float, rec: Dictionary) -> PartShapes.PartShape:
	var spec := WiringLoom.ship_main()
	var loom := WiringLoom.new(spec, length, hash(str(rec.get("path", ""))))
	var shape := PartShapes.PartShape.new()
	shape.mesh = loom.build_mesh()
	var box := BoxShape3D.new()
	var size: Vector3 = vec3(rec.get("box", {}).get("size", [0.08, 0.08, length])) if rec.has("box") else Vector3(0.08, length, 0.08)
	box.size = Vector3(minf(size.x, size.z), length, minf(size.x, size.z))
	shape.collision = box
	shape.volume = box.size.x * box.size.y * box.size.z
	return shape


static func _static_method(lib: Script, fn: String) -> Dictionary:
	var key := str(lib.resource_path) + "#" + fn
	if _method_cache.has(key):
		return _method_cache[key]
	var found := {}
	for m: Dictionary in lib.get_script_method_list():
		if m.get("name", "") == fn:
			found = m
			break
	_method_cache[key] = found
	return found


## One JSON argument as the engine type a constructor declares (SHIP_FORMAT_PLAN 4.1): a
## Vector3 from [x, y, z] or the "(x, y, z)" text some records carry, a PackedVector2Array
## from [[x, y], ...], a Rect2 from [x, y, w, h], a Transform3D from {o, b}, a Color from
## [r, g, b, a?]; untyped parameters take the JSON value as it is.
static func convert_arg(v: Variant, ptype: int, hint: String = "") -> Variant:
	if v is String and str(v).begins_with("["):
		v = _list_text(v)   # "[(x, y), (x, y)]": the text form of a packed array some recipes carry
	match ptype:
		TYPE_VECTOR3:
			return vec3(v)
		TYPE_VECTOR2:
			return vec2(v)
		TYPE_RECT2:
			if v is Array and v.size() == 4:
				return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
		TYPE_TRANSFORM3D:
			return xform(v) if v is Dictionary else Transform3D.IDENTITY
		TYPE_COLOR:
			return color(v)
		TYPE_INT:
			return int(v)
		TYPE_FLOAT:
			return float(v)
		TYPE_BOOL:
			return bool(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return str(v)
		TYPE_PACKED_VECTOR2_ARRAY:
			var out := PackedVector2Array()
			for e: Variant in v:
				out.append(vec2(e))
			return out
		TYPE_PACKED_VECTOR3_ARRAY:
			var out := PackedVector3Array()
			for e: Variant in v:
				out.append(vec3(e))
			return out
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var out := PackedFloat64Array()
			for e: Variant in v:
				out.append(float(e))
			return out
		TYPE_ARRAY:
			if v is Array:
				if hint == "float" or hint.ends_with(":float") or hint == str(TYPE_FLOAT):
					var floats: Array[float] = []
					for e: Variant in v:
						floats.append(float(e))
					return floats
				if hint == "Vector2" or hint.ends_with(":Vector2") or hint == str(TYPE_VECTOR2):
					var v2s: Array[Vector2] = []
					for e: Variant in v:
						v2s.append(vec2(e))
					return v2s
				return v
	return v


# --- materials ------------------------------------------------------------------------------

## The file's `materials` as Materials: a livery key through `ShipParts.mat` in the ship's
## livery, `paint` through `ShipKit.paint`, `glow` through `ShipKit.glow`, `glass` as the
## kit's glass with the record's colour.
func _decode_materials() -> void:
	materials.clear()
	ShipParts.livery = str(file.get("ship", {}).get("livery", "company"))
	for key: String in file.get("materials", {}):
		var rec: Dictionary = file["materials"][key]
		materials[key] = _material_of(rec)


static func _material_of(rec: Dictionary) -> Material:
	if rec.has("livery"):
		return ShipParts.mat(str(rec["livery"]))
	if rec.has("glow"):
		return ShipKit.glow(color(rec["glow"]), float(rec.get("energy", 1.0)))
	if rec.has("glass"):
		var g := ShipKit.glass()
		if rec.has("color"):
			g.albedo_color = color(rec["color"])
		g.metallic = float(rec.get("metallic", g.metallic))
		g.roughness = float(rec.get("roughness", g.roughness))
		return g
	if rec.has("paint"):
		return ShipKit.paint(color(rec["paint"]), float(rec.get("metallic", 0.4)), float(rec.get("roughness", 0.55)),
				str(rec.get("finish", "")))
	return ShipKit.paint(Color.MAGENTA)


## A named material; magenta (and a warning once) for a name the file does not define.
func material(key: String) -> Material:
	if materials.has(key):
		return materials[key]
	if key != "":
		warnings.append("material %s is not in the file" % key)
	materials[key] = ShipKit.paint(Color.MAGENTA)
	return materials[key]


## "[(x, y), (x, y), ...]" (a PackedVector2Array printed as text, which some part recipes
## carry; reported to Void Salvage) as a list of [x, y] lists.
static func _list_text(text: String) -> Array:
	var out := []
	var re := RegEx.new()
	re.compile("\\(([^()]*)\\)")
	for m: RegExMatch in re.search_all(text):
		var nums := []
		for n: String in m.get_string(1).split(","):
			nums.append(float(n.strip_edges()))
		out.append(nums)
	return out


## Jolt refuses a convex hull thinner than its tolerance (Void Salvage's pipe spans keep a
## 1 mm "speck" of collision where a span lies wholly inside what it passes): such a hull
## becomes a small box of its own extents, at least 4 mm a side, so the body builds clean.
static func _fix_collision(shape: PartShapes.PartShape) -> void:
	shape.collision = _sane_collision(shape.collision)
	var extras: Array[Shape3D] = []
	for c: Shape3D in shape.extra_collision:
		extras.append(_sane_collision(c))
	shape.extra_collision = extras


static func _sane_collision(c: Shape3D) -> Shape3D:
	if not c is ConvexPolygonShape3D:
		return c
	var pts: PackedVector3Array = (c as ConvexPolygonShape3D).points
	if pts.is_empty():
		return c
	var lo := pts[0]
	var hi := pts[0]
	for v in pts:
		lo = lo.min(v)
		hi = hi.max(v)
	var ext := hi - lo
	if ext.x >= 0.003 and ext.y >= 0.003 and ext.z >= 0.003:
		return c
	var box := BoxShape3D.new()
	box.size = ext.max(Vector3(0.004, 0.004, 0.004))
	return box


# --- encodings (SHIP_FORMAT_PLAN 4.1) ------------------------------------------------------

static func vec3(v: Variant) -> Vector3:
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	if v is String:
		# "(x, y, z)": the text form some part recipes carry (reported to Void Salvage).
		var parts: PackedStringArray = str(v).trim_prefix("(").trim_suffix(")").split(",")
		if parts.size() == 3:
			return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	if v is Vector3:
		return v
	return Vector3.ZERO


static func vec2(v: Variant) -> Vector2:
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is String:
		var parts: PackedStringArray = str(v).trim_prefix("(").trim_suffix(")").split(",")
		if parts.size() == 2:
			return Vector2(float(parts[0]), float(parts[1]))
	if v is Vector2:
		return v
	return Vector2.ZERO


static func color(v: Variant) -> Color:
	if v is Array and v.size() >= 3:
		return Color(float(v[0]), float(v[1]), float(v[2]), float(v[3]) if v.size() > 3 else 1.0)
	return Color.WHITE


## {"o": [x, y, z], "b": [xx, xy, xz, yx, yy, yz, zx, zy, zz]} (basis rows; no "b" = identity).
static func xform(v: Variant) -> Transform3D:
	if not v is Dictionary:
		return Transform3D.IDENTITY
	var t := Transform3D.IDENTITY
	t.origin = vec3(v.get("o", [0, 0, 0]))
	if v.has("b"):
		var b: Array = v["b"]
		if b.size() == 9:
			t.basis = Basis(Vector3(float(b[0]), float(b[3]), float(b[6])), Vector3(float(b[1]), float(b[4]), float(b[7])),
					Vector3(float(b[2]), float(b[5]), float(b[8])))
	return t


static func _part_kind(name: String) -> PartData.Kind:
	var key := name.to_upper()
	return PartData.Kind[key] if PartData.Kind.has(key) else PartData.Kind.COMPONENT
