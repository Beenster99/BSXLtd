class_name PartModels
extends RefCounted
## BSX's own detailed models of ship components, for the ones Void Salvage has no part for (a
## component with a Void Salvage part is drawn with `VsParts`, always). Modelled in Blender by
## script (modules/part_models/blender/: `python3 build_models.py`), one .glb a component, named by
## its design catalogue id ("fridge", "jump_drive"), committed with the script that makes it.
##
## Every model is its catalogue size exactly (x across, y up, z deep, m), its origin in the middle
## of its footprint on the floor and its working face to -Z. A hull-mounted part's mounting face is
## at +Z and it stands out from the hull towards -Z. Presentation only: nothing here touches the
## network or the game state, and the scenes are shared (instance them, never edit them).

const DIR := "res://modules/part_models/internal/models/"

static var _scenes: Dictionary = {}
static var _motions: Dictionary = {}


## Whether there is a model for this catalogue id (a base id: "fridge", not "fridge:3S").
static func has(id: String) -> bool:
	return _scene(id) != null


## Every id with a model, sorted.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for f in ResourceLoader.list_directory(DIR):
		if f.ends_with(".glb"):
			out.append(f.get_basename())
	out.sort()
	return out


## The model as nodes to drop into a scene (origin on the floor, front to -Z); null if none.
static func instance(id: String) -> Node3D:
	var s := _scene(id)
	if s == null:
		return null
	var n := s.instantiate() as Node3D
	n.name = id
	n.set_meta("part_model", id)
	return n


## The model's box (m), from its meshes; Vector3.ZERO if none.
static func size(id: String) -> Vector3:
	return box(id).size


## The model's box as built (part space, m), every piece in place; an empty AABB if none.
static func box(id: String) -> AABB:
	var n := instance(id)
	if n == null:
		return AABB()
	var out := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := _transform_to(n, mi) * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	n.free()
	return out


## How a moving part moves (its motion note, <id>.motion.json beside the model): {"power_kw",
## "load_kg", "opening": [w, h] for a way through, "pieces": [{"name", "parent", "kind" (hinge,
## slide, spin, belt), "axis" (part space), "pivot" (part space, as built), "unit" (deg, m, m/s),
## "stowed", "deployed", "min", "max", "rest" (0 = as built), "seconds", "order" (lower deploys
## first, equal together), "contact": {"at" (the piece's own space), "radius"} on a foot}]}.
## Each piece is a node of that name in the model whose origin is its pivot. Empty if it doesn't move.
static func motion(id: String) -> Dictionary:
	if id == "" or id.contains("/") or id.contains("."):
		return {}
	if not _motions.has(id):
		var path := DIR + id + ".motion.json"
		var note: Dictionary = {}
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				note = parsed
		_motions[id] = note
	return _motions[id]


## A moving piece of an instanced model by name ("strut"), or null.
static func piece(model: Node3D, name: String) -> Node3D:
	return model.find_child(name, true, false) as Node3D if model else null


## Poses a moving model between stowed (t = 0) and deployed (t = 1): the pieces move in their
## "order", each over its own share of t. Belts and spins are left alone (they run, not pose).
static func pose(model: Node3D, id: String, t: float) -> void:
	var pieces: Array = motion(id).get("pieces", [])
	var steps := 1
	for pc: Dictionary in pieces:
		steps = maxi(steps, int(pc.get("order", 1)))
	for pc: Dictionary in pieces:
		var kind := String(pc.get("kind", "hinge"))
		if kind != "hinge" and kind != "slide":
			continue
		var node := piece(model, String(pc.get("name", "")))
		if node == null:
			continue
		if not node.has_meta("rest_transform"):
			node.set_meta("rest_transform", node.transform)
		var rest: Transform3D = node.get_meta("rest_transform")
		var f := clampf(t * steps - float(int(pc.get("order", 1)) - 1), 0.0, 1.0)
		var value := lerpf(float(pc.get("stowed", 0.0)), float(pc.get("deployed", 0.0)), f)
		var a: Array = pc.get("axis", [1, 0, 0])
		var axis := Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()
		if kind == "hinge":
			node.transform = Transform3D(rest.basis * Basis(axis, deg_to_rad(value)), rest.origin)
		else:
			node.transform = Transform3D(rest.basis, rest.origin + rest.basis * (axis * value))


static func _transform_to(root: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != root:
		t = (at as Node3D).transform * t
		at = at.get_parent()
	return t


static func _scene(id: String) -> PackedScene:
	if id == "" or id.contains("/") or id.contains("."):
		return null
	if not _scenes.has(id):
		var path := DIR + id + ".glb"
		_scenes[id] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	return _scenes[id]
