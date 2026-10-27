class_name VsWreckLibrary
extends RefCounted
## Void Salvage's own wrecks, built by its wreck pipeline and packed for BSX (beenster, 27 Oct:
## "use the current Void Salvage wreck building pipeline for our own wrecks"). Each design is a
## pack (`data/wrecks/<design>.vswz`, made by internal/tools/vs_wreck_pack.gd from Void
## Salvage's `vswreck` exports; read with `file_of`): the derelict as Void Salvage builds it, every part and joint,
## shaped like a vsship 2.0 file, so `VsShipImport.build` builds it, `WreckMaker` damages it
## and the yard's wreck rules give every weld, bolt and rivet a fastener.
##
## A design id is "vsw:<design>" ("vsw:lander"); `VsShipImport.design_source` and so
## `WreckMaker.for_design` take it like "kestrel" or a generated "gen:..." id.
##   VsWreckLibrary.designs("M")              # the medium ones, sorted
##   VsWreckLibrary.pick(rng, "S")             # one at random, the same on every machine
##   WreckMaker.for_design("vsw:lander", 84, "collision:3")

const ID_PREFIX := "vsw:"
const DIR := "res://modules/shared_components/data/wrecks"
## The yard's sizes (S, M, L) by length in metres, as its cradles take them: small to the
## small cradle's 18 m, medium to the medium one's 30 m, large to the dock cradles' 78 m.
## (Void Salvage's own classes run a size larger: its M lander is 13.6 m.)
const LENGTHS := {"S": [0.0, 18.0], "M": [18.0, 30.0], "L": [30.0, 78.0]}

static var _index: Dictionary = {}
static var _files: Dictionary = {}


static func is_vs_wreck(design: String) -> bool:
	return design.begins_with(ID_PREFIX)


## Every packed design: design (no prefix) -> {design, name, class, length_m, mass_kg, parts,
## joints, cargo_role, rollable, reference, vs_version}.
static func index() -> Dictionary:
	if _index.is_empty():
		var res := load(DIR.path_join("index.json")) as JSON if ResourceLoader.exists(DIR.path_join("index.json")) else null
		if res and res.data is Dictionary:
			_index = res.data.get("wrecks", {})
	return _index


## The design ids ("vsw:<design>") a yard size takes ("S", "M", "L"; "" for all), sorted.
## Only designs Void Salvage rolls for its own contracts (`rollable`).
static func designs(size: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	for d: String in index():
		var info: Dictionary = index()[d]
		if not bool(info.get("rollable", true)):
			continue
		var s := size_of(d)
		if s != "" and (size == "" or s == size):
			out.append(ID_PREFIX + d)
	out.sort()
	return out


## One design of `size` from `rng`, "" when none.
static func pick(rng: RandomNumberGenerator, size: String = "") -> String:
	var list := designs(size)
	return list[rng.randi_range(0, list.size() - 1)] if not list.is_empty() else ""


## The yard size ("S", "M", "L") a design's length falls in, "" for none (too long for a cradle).
static func size_of(design: String) -> String:
	var length := float(info(design).get("length_m", 0.0))
	for size: String in LENGTHS:
		if length > float(LENGTHS[size][0]) and length <= float(LENGTHS[size][1]):
			return size
	return ""


static func info(design: String) -> Dictionary:
	return index().get(design.trim_prefix(ID_PREFIX), {})


## The design's pack as a vsship 2.0-shaped dictionary, read once and kept; {} for none.
## Callers that change it duplicate it first (WreckMaker.make does).
static func file_of(design: String) -> Dictionary:
	var id := design.trim_prefix(ID_PREFIX)
	if _files.has(id):
		return _files[id]
	var path := DIR.path_join(id + ".vswz")
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var size := f.get_32()
	var packed := f.get_buffer(f.get_length() - 4)
	f.close()
	var data: Variant = bytes_to_var(packed.decompress(size, FileAccess.COMPRESSION_ZSTD))
	if not data is Dictionary:
		return {}
	_files[id] = data
	return data


## A part of a pack with no library recipe: Void Salvage's own triangles (`meshes[i]`: [corners in
## millimetres as steps, all x then y then z; indices, three a face], part space) and its collision as Void Salvage made it (`solid`: box, convex, cylinder).
static func mesh_shape(file: Dictionary, p: Dictionary) -> PartShapes.PartShape:
	var args: Array = p.get("shape", {}).get("args", [])
	var meshes: Array = file.get("meshes", [])
	var i := int(args[0]) if not args.is_empty() else -1
	if i < 0 or i >= meshes.size():
		return null
	# Shared corners in millimetres (all the x steps, then y, then z), unwelded here so every
	# face is flat.
	var steps: PackedInt32Array = meshes[i][0]
	var idx: PackedInt32Array = meshes[i][1]
	var n_corners := steps.size() / 3
	var corners := PackedVector3Array()
	corners.resize(n_corners)
	for axis in 3:
		var at := 0
		for c in n_corners:
			at += steps[axis * n_corners + c]
			corners[c][axis] = at * 1e-3
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(idx.size())
	normals.resize(idx.size())
	for k in idx.size():
		verts[k] = corners[idx[k]]
	for t in range(0, verts.size() - 2, 3):
		# Clockwise from outside (MeshKit's winding): the outward normal is the left-hand one.
		var n := -(verts[t + 1] - verts[t]).cross(verts[t + 2] - verts[t]).normalized()
		normals[t] = n
		normals[t + 1] = n
		normals[t + 2] = n
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shape := PartShapes.PartShape.new()
	shape.mesh = mesh
	shape.collision = solid(p.get("solid", {}), verts)
	var box: Dictionary = p.get("box", {})
	var size := VsShipImport.vec3(box.get("size", [1, 1, 1]))
	shape.volume = maxf(size.x * size.y * size.z * 0.5, 0.0001)
	shape.recipe = p.get("shape", {})
	return shape


## Void Salvage's collision record as a shape; the triangles' hull when there is none.
static func solid(c: Dictionary, verts: PackedVector3Array) -> Shape3D:
	match str(c.get("type", "")):
		"box":
			var b := BoxShape3D.new()
			b.size = VsShipImport.vec3(c.get("size", [1, 1, 1]))
			return b
		"cylinder":
			var cy := CylinderShape3D.new()
			cy.radius = float(c.get("radius", 0.5))
			cy.height = float(c.get("height", 1.0))
			return cy
		"convex":
			var pts := PackedVector3Array()
			for q in c.get("points", []):
				pts.append(VsShipImport.vec3(q))
			if pts.size() >= 4:
				var cv := ConvexPolygonShape3D.new()
				cv.points = pts
				return cv
	var hull := ConvexPolygonShape3D.new()
	hull.points = verts
	return hull
