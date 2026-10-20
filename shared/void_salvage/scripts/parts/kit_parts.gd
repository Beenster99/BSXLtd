class_name KitParts
extends RefCounted
## Ready-made models from the Quaternius Modular SciFi MegaKit (assets/megakit, CC0 public
## domain: see assets/megakit/LICENSE.txt). Interior walls and floor plates, stairs, doors,
## rails, lights, vents, fans, computers, crates and barrels, textured. Use them on ships
## through ShipKit.model(name, xform). Sizes: walls and floors are 4 m modules.

const DIR := "res://assets/megakit/"

static var _scenes: Dictionary = {}
static var _bounds: Dictionary = {}


## Every model name in the kit (file names without .gltf).
static func names() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gltf"):
			out.append(f.get_basename())
		elif f.ends_with(".gltf.import"):
			# Exported builds keep only the .import files.
			var n := f.get_basename().get_basename()
			if not out.has(n):
				out.append(n)
	out.sort()
	return out


static func scene(model: String) -> PackedScene:
	if not _scenes.has(model):
		_scenes[model] = load(DIR + model + ".gltf") as PackedScene
	return _scenes[model]


## A new copy of a model.
static func make(model: String) -> Node3D:
	var s := scene(model)
	return s.instantiate() as Node3D if s else null


## The model's bounds in its own space.
static func bounds(model: String) -> AABB:
	if not _bounds.has(model):
		var node := make(model)
		var box := AABB()
		var first := true
		if node:
			for mi in node.find_children("*", "MeshInstance3D", true, false):
				var m := mi as MeshInstance3D
				var t := Transform3D()
				var c: Node = m
				while c != node:
					t = (c as Node3D).transform * t
					c = c.get_parent()
				var b := t * m.mesh.get_aabb()
				box = b if first else box.merge(b)
				first = false
			node.free()
		_bounds[model] = box
	return _bounds[model]
