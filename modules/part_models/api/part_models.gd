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
	var n := instance(id)
	if n == null:
		return Vector3.ZERO
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := _transform_to(n, mi) * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	n.free()
	return box.size


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
