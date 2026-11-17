class_name PartAsset
extends RefCounted
## A component modelled in Blender (docs/BLENDER_PARTS.md): reads assets/parts/<name>.vspart,
## written by tools/blender/build_parts.py, into the meshes a PartShape carries. The game never
## runs Blender: the file is committed with the script that makes it.
##
## The file: "VSPT", the version, a JSON head (the palette of colour names, the surfaces, the
## stretch bands, named points, the box) and a zlib-packed body (per surface: positions as
## float32, normals as int16, a palette index a vertex, triangle indices as uint32). Colours are
## names (a WreckParts constant, "PAINT", "GLOW"), looked up in the palette the caller gives, so
## the finish codes and any later colour change reach these parts too.
##
## Sizing: `scale` grows the whole part evenly about its origin; `stretch` (metres per axis, after
## the scale) is shared out over that axis's bands, slabs the model keeps plain (a drum between
## its clamps), so bolts and rings keep their shape whatever size a ship calls for.
##
## The meshes come out as a MeshKit's do (no index, a normal and colour a corner), so everything
## that reads a part's mesh (cuts, dents, shadows, the hologram) takes them as it takes the others.

const MAGIC := "VSPT"
const VERSION := 1
const ROOT := "res://shared/void_salvage/assets/parts/"
const GLASS_KINDS := {"clear": Glazing.Kind.CLEAR, "tinted": Glazing.Kind.TINTED,
		"frosted": Glazing.Kind.FROSTED, "armoured": Glazing.Kind.ARMOURED, "amber": Glazing.Kind.AMBER,
		"red": Glazing.Kind.RED, "solar": Glazing.Kind.SOLAR}

## The least share of its length a band keeps when a part is shortened.
const SQUEEZE := 0.1
## Sizes of a part whose placed corners are kept (a ship's few sizes of it; cleared past this).
const PLACED_KEPT := 16

## Turns the Blender-drawn parts off (they fall back on their code-drawn looks): captures' before
## shots, and a check that a part still builds without its file.
static var enabled: bool = true
## path -> the file read ({head, surfaces: [{role, kind, pos, nrm, col, idx}]}); {} when missing.
static var _cache: Dictionary = {}
## `split`'s meshes by name, scale and stretch (one set shared by every fitting of a size).
static var _splits: Dictionary = {}


## Whether `name` has a file (and the Blender parts are on).
static func has(name: String) -> bool:
	return enabled and not data(name).is_empty()


## The file read, cached ({} when it is missing or unreadable).
static func data(name: String) -> Dictionary:
	return file(ROOT + name + ".vspart")


## Any .vspart by its path (the asteroids keep theirs in res://assets/rocks/), cached ({} when it is
## missing or unreadable). A surface written with a "Shade" carries it as three bytes a vertex.
static func file(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var out := _read(path)
	_cache[path] = out
	return out


## The part's head: palette, bands, points, aabb, tris.
static func head(name: String) -> Dictionary:
	var d := data(name)
	return d.get("head", {})


## A named point in the part's space at `scale` and `stretch`.
static func point(name: String, which: String, scale: float = 1.0, stretch := Vector3.ZERO) -> Vector3:
	var p: Array = head(name).get("points", {}).get(which, [0.0, 0.0, 0.0])
	return _place(Vector3(p[0], p[1], p[2]), scale, _stretchers(head(name), stretch / scale))


## The largest scale up to `scale` at which the part can still be squeezed to `length` along
## `axis` (0 x, 1 y, 2 z) by its bands: a squat call keeps its height and loses a little width.
static func scale_to_fit(name: String, axis: int, length: float, scale: float) -> float:
	var h := head(name)
	if h.is_empty():
		return scale
	var full: float = box_of(name)[axis]
	var bands := 0.0
	for b: Array in h.get("bands", {}).get(["x", "y", "z"][axis], []):
		bands += float(b[1]) - float(b[0])
	var shortest := full - bands * (1.0 - SQUEEZE)
	return minf(scale, length / shortest) if shortest > 0.0 else scale


## The box the part is called by: the model's "box" when it gives one (a breaker cabinet whose lever
## stands proud of the box it fills), else its bounds. Centred on the origin either way.
static func box_of(name: String) -> Vector3:
	var h := head(name)
	if h.is_empty():
		return Vector3.ONE
	if h.has("box"):
		var b: Array = h["box"]
		return Vector3(b[0], b[1], b[2])
	var full := Vector3()
	for a in 3:
		full[a] = float(h["aabb"][1][a]) - float(h["aabb"][0][a])
	return full


## [scale, stretch] fitting the part to the box `size`: grown evenly to the least of the axes in
## `even` (those whose round details must stay round), narrowed further where a squat axis can't be
## squeezed that far by its bands, the rest of each axis taken up by its bands.
static func fit_box(name: String, size: Vector3, even := [0, 1]) -> Array:
	var h := head(name)
	if h.is_empty():
		return [1.0, Vector3.ZERO]
	var full := box_of(name)
	var scale := INF
	for a: int in even:
		scale = minf(scale, size[a] / full[a])
	for a in 3:
		scale = scale_to_fit(name, a, size[a], scale)
	return [scale, size - full * scale]


## Fills `shape`'s mesh, emissives and glass from the file. `palette`: colour name -> Color
## (unknown names draw white, the part's paint). Returns false when there is no file. A stretch
## grows about the part's middle, except on an axis where `keep_low` is 1: there what lies below
## every band stays put and the rest moves up (a pipe clip's band on the pipe, its stem to the holder).
## `offset` moves the whole part once placed (a locker's leaf, modelled in the locker's space, drawn
## about its own middle).
## `extra` (a MeshKit) is added to the plain faces as it stands: what the game draws itself on a
## modelled part (a name board's letters, from its text).
static func fill(shape: PartShapes.PartShape, name: String, palette: Dictionary, scale: float = 1.0,
		stretch := Vector3.ZERO, keep_low := Vector3.ZERO, offset := Vector3.ZERO, extra: MeshKit = null) -> bool:
	var d := data(name)
	if not enabled or d.is_empty():
		return false
	var h: Dictionary = d["head"]
	var colours: Array[Color] = []
	for c: String in h["palette"]:
		colours.append(palette.get(c, Color.WHITE))
	var bands := _stretchers(h, stretch / scale)
	if keep_low != Vector3.ZERO:
		bands.append(keep_low)
	for s: Dictionary in d["surfaces"]:
		var role := String(s["role"])
		var mesh := _mesh(s, colours, scale, bands, offset, extra if role == "mesh" else null)
		match role:
			"mesh":
				shape.mesh = mesh
			"glass":
				shape.glass = mesh
				shape.glass_kind = GLASS_KINDS.get(String(s["kind"]), Glazing.Kind.CLEAR)
			"emit":
				var col: Color = colours[int(s["col"][0])] if not (s["col"] as PackedByteArray).is_empty() else Color.WHITE
				PartShapes.emissive(shape, String(s["kind"]), mesh, col)
	if shape.mesh == null:
		shape.mesh = ArrayMesh.new()
	return true


## The part's plain faces split by colour, placed at `scale` and `stretch` as `fill` places them:
## {palette name: ArrayMesh}, for a body that paints each colour with a material of its own (the crew
## ships' fittings take their livery's materials by name: "shell", "trim", "edge"...). {} with no file.
static func split(name: String, scale: float = 1.0, stretch := Vector3.ZERO) -> Dictionary:
	var d := data(name)
	if not enabled or d.is_empty():
		return {}
	var key := "%s|%s|%s" % [name, scale, stretch]
	if _splits.has(key):
		return _splits[key]
	var h: Dictionary = d["head"]
	var names: Array = h["palette"]
	var bands := _stretchers(h, stretch / scale)
	var verts := {}
	var normals := {}
	for s: Dictionary in d["surfaces"]:
		if String(s["role"]) != "mesh":
			continue
		var corners := _corners(s, scale, bands)
		var nrm: PackedVector3Array = s["corner_nrm"]
		var col: PackedByteArray = s["col"]
		var idx: PackedInt32Array = s["idx"]
		var by_colour := {}   # colour -> corner indices (packed arrays copy on read: gather, then append once)
		for t in idx.size():
			var c := col[idx[t]]
			if not by_colour.has(c):
				by_colour[c] = PackedInt32Array()
			var list: PackedInt32Array = by_colour[c]
			list.append(t)
			by_colour[c] = list
		for c: int in by_colour:
			var v: PackedVector3Array = verts.get(c, PackedVector3Array())
			var n: PackedVector3Array = normals.get(c, PackedVector3Array())
			for t: int in by_colour[c]:
				v.append(corners[t])
				n.append(nrm[t])
			verts[c] = v
			normals[c] = n
	var out := {}
	var kept := MeshKit.keep_arrays
	MeshKit.keep_arrays = true   # shared by every build: kept for the merged looks and shadows
	for c: int in verts:
		var k := MeshKit.new()
		k.verts = verts[c]
		k.normals = normals[c]
		var white := PackedColorArray()
		white.resize(k.verts.size())
		white.fill(Color.WHITE)
		k.colors = white
		out[String(names[c])] = k.finish()
	MeshKit.keep_arrays = kept
	if _splits.size() >= PLACED_KEPT * 4:
		_splits.clear()
	_splits[key] = out
	return out


## The palette from a script's colour constants (WreckParts, ShipParts), plus "PAINT" (white,
## the part's own paint) and "GLOW" (`glow`).
static func palette_of(script: Script, glow: Color) -> Dictionary:
	var out := {}
	var consts := script.get_script_constant_map()
	for k: String in consts:
		if consts[k] is Color:
			out[k] = consts[k]
	out["PAINT"] = Color.WHITE
	out["GLOW"] = glow
	return out


static func _mesh(s: Dictionary, colours: Array[Color], scale: float, bands: Array,
		offset := Vector3.ZERO, extra: MeshKit = null) -> ArrayMesh:
	var k := MeshKit.new()
	k.verts = _corners(s, scale, bands)
	if offset != Vector3.ZERO:
		var moved := k.verts.duplicate()
		for i in moved.size():
			moved[i] += offset
		k.verts = moved
	k.normals = s["corner_nrm"]
	var key := str(colours)
	var by_palette: Dictionary = s["corner_col"]
	if not by_palette.has(key):
		var col: PackedByteArray = s["col"]
		var idx: PackedInt32Array = s["idx"]
		var out := PackedColorArray()
		out.resize(idx.size())
		for t in idx.size():
			out[t] = colours[col[idx[t]]]
		by_palette[key] = out
	k.colors = by_palette[key]
	if extra != null and not extra.verts.is_empty():
		var v := k.verts.duplicate()
		var n := k.normals.duplicate()
		var c := k.colors.duplicate()
		v.append_array(extra.verts)
		n.append_array(extra.normals)
		c.append_array(extra.colors)
		k.verts = v
		k.normals = n
		k.colors = c
	return k.finish()


## The surface's corners (three a triangle) placed at `scale` and `bands`, kept per size: a ship
## calls the same size of a part many times, and placing is most of a part's build.
static func _corners(s: Dictionary, scale: float, bands: Array) -> PackedVector3Array:
	var key := str([scale, bands])
	var placed_at: Dictionary = s["placed"]
	if placed_at.has(key):
		return placed_at[key]
	var placed := _placed(s["pos"], scale, bands)
	var idx: PackedInt32Array = s["idx"]
	var out := PackedVector3Array()
	out.resize(idx.size())
	for t in idx.size():
		out[t] = placed[idx[t]]
	if placed_at.size() >= PLACED_KEPT:
		placed_at.clear()
	placed_at[key] = out
	return out


## Every point of `pos` pushed out by the bands, then scaled (as `_place`, an axis at a time).
static func _placed(pos: PackedVector3Array, scale: float, bands: Array) -> PackedVector3Array:
	var out := pos.duplicate()
	for a in 3:
		var list: Array = bands[a] if bands.size() > a else []
		if list.is_empty():
			continue
		var n := list.size()
		var los := PackedFloat64Array()
		var his := PackedFloat64Array()
		var slopes := PackedFloat64Array()
		var grows := PackedFloat64Array()
		var base := 0.0
		for b: Array in list:
			los.append(b[0])
			his.append(b[1])
			grows.append(b[2])
			slopes.append(float(b[2]) / (float(b[1]) - float(b[0])))
			base -= float(b[2]) * 0.5
		if bands.size() > 3 and (bands[3] as Vector3)[a] > 0.5:
			base = 0.0
		for i in out.size():
			var v := out[i]
			var c: float = v[a]
			var shift := base
			for j in n:
				if c >= his[j]:
					shift += grows[j]
				elif c > los[j]:
					shift += slopes[j] * (c - los[j])
			v[a] = c + shift
			out[i] = v
	return Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO) * out


## Per axis: [[lo, hi, grow], ...] in the file's space (`stretch` too), each band's share.
static func _stretchers(h: Dictionary, stretch: Vector3) -> Array:
	var out := [[], [], []]
	var all: Dictionary = h.get("bands", {})
	var names := ["x", "y", "z"]
	for a in 3:
		var list: Array = all.get(names[a], [])
		if list.is_empty() or is_zero_approx(stretch[a]):
			continue
		var total := 0.0
		for b: Array in list:
			total += float(b[1]) - float(b[0])
		# A shrink never squeezes the bands under SQUEEZE of their length.
		var grow := maxf(stretch[a], -total * (1.0 - SQUEEZE))
		for b: Array in list:
			var share := (float(b[1]) - float(b[0])) / total
			out[a].append([float(b[0]), float(b[1]), grow * share])
	return out


## A point of the model (file space) at `scale`, pushed out by the bands below it.
static func _place(p: Vector3, scale: float, bands: Array) -> Vector3:
	var q := p
	for a in 3:
		var list: Array = bands[a] if bands.size() > a else []
		if list.is_empty():
			continue
		var shift := 0.0
		var total := 0.0
		for b: Array in list:
			total += float(b[2])
		# Bands share the growth about the part's middle: what is below every band moves down
		# half the total, what is above moves up half.
		var lo_shift := -total * 0.5
		if bands.size() > 3 and (bands[3] as Vector3)[a] > 0.5:
			lo_shift = 0.0
		shift = lo_shift
		for b: Array in list:
			var lo: float = b[0]
			var hi: float = b[1]
			var grow: float = b[2]
			if p[a] >= hi:
				shift += grow
			elif p[a] > lo:
				shift += grow * (p[a] - lo) / (hi - lo)
		q[a] = p[a] + shift
	return q * scale


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_buffer(4).get_string_from_ascii() != MAGIC:
		return {}
	var version := f.get_32()
	if version != VERSION:
		push_error("PartAsset: %s is version %d, the game reads %d" % [path, version, VERSION])
		return {}
	var head_len := f.get_32()
	var raw_len := f.get_32()
	var h: Variant = JSON.parse_string(f.get_buffer(head_len).get_string_from_utf8())
	if not h is Dictionary:
		return {}
	var packed_len := f.get_32()
	var body := f.get_buffer(packed_len).decompress(raw_len, FileAccess.COMPRESSION_DEFLATE)
	if body.size() != raw_len:
		push_error("PartAsset: %s did not unpack" % path)
		return {}
	var surfaces := []
	for s: Dictionary in h["surfaces"]:
		var n := int(s["verts"])
		var t := int(s["tris"])
		var at := int(s["offset"])
		var pos := body.slice(at, at + n * 12).to_float32_array()
		at += n * 12
		var nrm_raw := body.slice(at, at + n * 6)
		at += n * 6
		var col := body.slice(at, at + n)
		at += n
		var idx := body.slice(at, at + t * 12).to_int32_array()
		at += t * 12
		# A rock's "Shade" (three bytes a vertex: light, band, dust), after the indices.
		var shade := PackedByteArray()
		if s.get("shade", false):
			shade = body.slice(at, at + n * 3)
			at += n * 3
		# A baked rock's UVs (two 16-bit numbers a vertex), after the Shade.
		var uv := PackedVector2Array()
		if s.get("uv", false):
			var raw := body.slice(at, at + n * 4)
			uv.resize(n)
			for i in n:
				uv[i] = Vector2(raw.decode_u16(i * 4), raw.decode_u16(i * 4 + 2)) / 65535.0
		var points := PackedVector3Array()
		var normals := PackedVector3Array()
		points.resize(n)
		normals.resize(n)
		for i in n:
			points[i] = Vector3(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2])
			normals[i] = Vector3(nrm_raw.decode_s16(i * 6), nrm_raw.decode_s16(i * 6 + 2),
					nrm_raw.decode_s16(i * 6 + 4)).normalized()
		var corner_nrm := PackedVector3Array()
		corner_nrm.resize(idx.size())
		for c in idx.size():
			corner_nrm[c] = normals[idx[c]]
		surfaces.append({"role": s["role"], "kind": s.get("kind", ""), "pos": points, "nrm": normals,
				"col": col, "idx": idx, "shade": shade, "uv": uv, "corner_nrm": corner_nrm, "corner_col": {}, "placed": {}})
	return {"head": h, "surfaces": surfaces}
