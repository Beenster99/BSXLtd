extends SceneTree
## Packs Void Salvage's wrecks for BSX. Void Salvage builds its derelicts with its own wreck
## pipeline (WreckDesign, SalvageHull, WreckInterior: far more of its game than the shared set),
## so BSX doesn't run it: Void Salvage writes each design as a `vswreck` file (as built, with
## `--meshes`), and this turns each into a pack BSX reads like a ship file: a vsship 2.0-shaped
## dictionary (parts and joints with paths, a material per look) whose parts without a library
## recipe carry Void Salvage's own triangles. `VsWreckLibrary` reads the packs; the importer,
## the wreck maker and the yard's rules take them as they take the Kestrel.
##
##   tools/vs_wrecks.sh <void-salvage checkout>     (exports at its HEAD, then runs this)
##   godot --headless --path . -s res://modules/shared_components/internal/tools/vs_wreck_pack.gd \
##       -- --in=/abs/dir/of/vswreck/files [--out=res://modules/shared_components/data/wrecks]
##
## A pack is `<design>.vswz`: the dictionary's `var_to_bytes` size (32 bits), then those bytes
## zstd-compressed in one piece; `index.json` beside them lists every design with its size class, name, length,
## mass and part count (what a picker needs without opening a pack).

const OUT := "res://modules/shared_components/data/wrecks"

func _init() -> void:
	var src := ""
	var out := OUT
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--in="):
			src = arg.trim_prefix("--in=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if src == "":
		push_error("vs_wreck_pack: pass --in=<folder of .vswreck.json files>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var index := {}
	var names := Array(DirAccess.get_files_at(src))
	names.sort()
	for name: String in names:
		if not name.ends_with(".vswreck.json"):
			continue
		var raw := FileAccess.get_file_as_string(src.path_join(name))
		var vsw: Variant = JSON.parse_string(raw)
		if not vsw is Dictionary:
			push_error("vs_wreck_pack: %s is not JSON" % name)
			continue
		var pack := pack_of(vsw)
		var design: String = str(vsw.get("wreck", {}).get("design", ""))
		var path := out.path_join(design + ".vswz")
		var f := FileAccess.open(path, FileAccess.WRITE)
		var raw_pack := var_to_bytes(pack)
		f.store_32(raw_pack.size())
		f.store_buffer(raw_pack.compress(FileAccess.COMPRESSION_ZSTD))
		f.close()
		index[design] = pack["vs_wreck"]
		print("vs_wreck_pack: %s  %s  %d parts, %d joints, %d meshes" % [design, pack["vs_wreck"]["class"],
				pack["parts"].size(), pack["joints"].size(), pack["meshes"].size()])
	var keys := index.keys()
	keys.sort()
	var sorted := {}
	for k in keys:
		sorted[k] = index[k]
	var idx := FileAccess.open(out.path_join("index.json"), FileAccess.WRITE)
	idx.store_string(JSON.stringify({"format": "bsx-vs-wrecks", "version": 1, "wrecks": sorted}, "\t", false) + "\n")
	idx.close()
	quit(0)

## One `vswreck` file as a vsship 2.0-shaped dictionary (VsWreckLibrary's pack).
static func pack_of(vsw: Dictionary) -> Dictionary:
	var w: Dictionary = vsw.get("wreck", {})
	var design := str(w.get("design", ""))
	var meshes: Array = []
	var mesh_of := {}   # triangles' hash -> mesh index
	var parts: Array = []
	var path_of := {}   # part id -> path
	var kind_of := {}
	for p: Dictionary in vsw.get("parts", []):
		var id := int(p["id"])
		var name := str(p.get("name", "Part"))
		var kind := str(p.get("kind", "component"))
		var path := "%s/%s/%d" % [kind, name, id]
		if kind == "hull" or kind == "glass":
			path = "%s/skin/%s/%d" % [kind, name, id]   # the yard's rules make each a plate fitting
		path_of[id] = path
		kind_of[id] = kind
		var g: Dictionary = p.get("geometry", {})
		var shape: Dictionary
		var corners: Array[Vector3] = []   # a mesh's own corners, for a box that hugs a turned part
		if g.has("recipe"):
			shape = g["recipe"]
		elif g.has("mesh"):
			# Welded to shared corners at a millimetre, x then y then z, each the step from the
			# last: a sixth of the size once packed. The reader unwelds them for flat faces.
			var m: Dictionary = g["mesh"]
			var flat: Array = m.get("vertices", [])
			var corner := {}
			var pts: Array[Vector3i] = []
			var idx := PackedInt32Array()
			for i in m.get("indices", range(flat.size() / 3)):
				var q := Vector3i(roundi(float(flat[i * 3]) * 1e3), roundi(float(flat[i * 3 + 1]) * 1e3),
						roundi(float(flat[i * 3 + 2]) * 1e3))
				if not corner.has(q):
					corner[q] = pts.size()
					pts.append(q)
					corners.append(Vector3(q) * 1e-3)
				idx.append(corner[q])
			var verts := PackedInt32Array()
			for axis in 3:
				var last := 0
				for q in pts:
					verts.append(q[axis] - last)
					last = q[axis]
			var key := hash([verts, idx])
			if not mesh_of.has(key):
				mesh_of[key] = meshes.size()
				meshes.append([verts, idx])
			shape = {"shape": "vs_mesh", "args": [mesh_of[key]]}
		else:
			continue
		var x := VsShipImport.xform(p.get("xform", {}))
		var b: Dictionary = g.get("bounds", {})
		var local := AABB(VsShipImport.vec3(b.get("pos", [-0.5, -0.5, -0.5])), VsShipImport.vec3(b.get("size", [1, 1, 1])))
		var box := x * local
		if not corners.is_empty():
			box = AABB(x * corners[0], Vector3.ZERO)
			for c in corners:
				box = box.expand(x * c)
		var rec := {"id": id, "path": path, "name": name, "kind": kind, "material": str(p.get("material", "steel")),
				"mass": float(p.get("mass_kg", 1.0)), "group": "", "by": "vswreck", "shape": shape,
				"mat": str(p.get("look", "")), "xform": p.get("xform", {}),
				"box": {"pos": [box.position.x, box.position.y, box.position.z], "size": [box.size.x, box.size.y, box.size.z]},
				"solid": g.get("collision", {}), "category": str(p.get("category", ""))}
		if p.has("power"):
			rec["power"] = str(p["power"].get("role", "")) if p["power"] is Dictionary else str(p["power"])
		if p.has("fluid"):
			rec["fluid"] = p["fluid"]
		if p.has("hazard"):
			rec["hazard"] = p["hazard"]
		parts.append(rec)
	var joints: Array = []
	for j: Dictionary in vsw.get("joints", []):
		var a := int(j["a"])
		var bb := int(j["b"])
		if not path_of.has(a) or not path_of.has(bb):
			continue
		var kind := str(j.get("kind", "weld"))
		var rec := {"id": int(j["id"]), "path": "joint/%s/%d" % [kind, int(j["id"])], "kind": kind, "head": int(j.get("head", 0)),
				"phase": _phase(kind, kind_of[a], kind_of[bb]), "a": path_of[a], "b": path_of[bb],
				"at": j.get("at", [0, 0, 0]), "normal": j.get("normal", [0, 1, 0])}
		var seam: Dictionary = j.get("seam", {})
		if not seam.is_empty():
			rec["seam_up"] = seam.get("up", [0, 1, 0])
			rec["seam_size"] = seam.get("size", [0, 0])
		if bool(j.get("seized", false)):
			rec["seized"] = true
		joints.append(rec)
	var materials := {}
	for key: String in vsw.get("looks", {}):
		materials[key] = _look(vsw["looks"][key])
	var derived: Dictionary = vsw.get("derived", {})
	var info := {"design": design, "name": str(w.get("name", design)), "class": str(w.get("size_class", "M")),
			"length_m": float(w.get("length_m", 0.0)), "mass_kg": snappedf(float(derived.get("mass_kg", 0.0)), 1.0),
			"parts": parts.size(), "joints": joints.size(), "cargo_role": str(w.get("cargo_role", "")),
			"rollable": bool(w.get("rollable", true)), "reference": w.get("reference", {}),
			"vs_version": str(vsw.get("generator", {}).get("version", ""))}
	return {"format": "vsship", "version": [2, 0],
			"generator": {"app": "void-salvage", "version": info["vs_version"], "date": str(vsw.get("generator", {}).get("date", "")),
					"via": "vswreck"},
			"ship": {"id": VsWreckLibrary.ID_PREFIX + design, "name": info["name"], "class": info["class"],
					"base": {"design": design, "app_version": info["vs_version"]}, "livery": "company"},
			"stats": {}, "materials": materials, "parts": parts, "joints": joints,
			"fittings": [], "systems": [], "pieces": [], "units": [], "lights": [], "slots": [],
			"layout": {"rooms": []},
			"derived": {"parts": parts.size(), "joints": joints.size(), "bounds": derived.get("bounds", {}),
					"mass_kg": derived.get("mass_kg", 0.0), "value_cr": derived.get("value_cr", 0.0)},
			"vs_wreck": info, "meshes": meshes}

## A joint's building phase as the yard's rules read it: welds between frame members are the
## frame; rivets hold the skin; the rest fit things on.
static func _phase(kind: String, a: String, b: String) -> String:
	if kind == "weld" and a == "frame" and b == "frame":
		return "frame"
	match kind:
		"rivet":
			return "skin"
		"spot":
			return "deck"
		"connector":
			return "service"
	return "fitting"

## A Void Salvage look ({paint: rgb, metallic, roughness, finish} or {glass: kind, colour}) as
## the importer's material record.
static func _look(l: Dictionary) -> Dictionary:
	if l.has("glass"):
		return {"glass": str(l["glass"]), "color": l.get("colour", [0.4, 0.55, 0.65, 0.3]),
				"metallic": float(l.get("metallic", 0.4)), "roughness": float(l.get("roughness", 0.06))}
	if l.has("glow"):
		return {"glow": l["glow"], "energy": float(l.get("energy", 1.0))}
	var out := {"paint": l.get("paint", [0.5, 0.5, 0.5]), "metallic": float(l.get("metallic", 0.4)),
			"roughness": float(l.get("roughness", 0.55))}
	if l.has("finish"):
		out["finish"] = str(l["finish"])
	return out
