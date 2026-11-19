extends ModuleTest
## BSX's own part models (PartModels): every committed model loads, is a few meshes (joined in
## Blender, so a part costs a handful of draw calls), stands on the floor centred on its
## footprint, and lights its screens and lamps.
##   tools/run_tests.sh part_models


func run_tests() -> void:
	var ids := PartModels.ids()
	check(ids.size() >= 80, "a full set of models (%d)" % ids.size())
	check(not PartModels.has("no_such_part") and PartModels.instance("no_such_part") == null, "an unknown id has no model")
	check(not PartModels.has("../part_models") and not PartModels.has(""), "ids are names, not paths")
	var lit := 0
	for id: String in ids:
		var n := PartModels.instance(id)
		check(n != null, "%s: loads" % id)
		if n == null:
			continue
		var meshes := n.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() == 1, "%s: one joined mesh (%d)" % [id, meshes.size()])
		var surfaces := 0
		for m in meshes:
			surfaces += (m as MeshInstance3D).mesh.get_surface_count()
			for i in (m as MeshInstance3D).mesh.get_surface_count():
				var mat := (m as MeshInstance3D).mesh.surface_get_material(i) as BaseMaterial3D
				if mat and mat.emission_enabled:
					lit += 1
		check(surfaces >= 2 and surfaces <= 16, "%s: a handful of materials (%d)" % [id, surfaces])
		var box := (meshes[0] as MeshInstance3D).mesh.get_aabb() if not meshes.is_empty() else AABB()
		var mid := box.get_center()
		check(absf(box.position.y) < 0.005 and absf(mid.x) < 0.005 and absf(mid.z) < 0.005,
				"%s: stands on the floor, centred (%s)" % [id, box])
		check(PartModels.size(id).is_equal_approx(box.size), "%s: size() reads its box" % id)
		n.free()
	check(lit >= 60, "screens and lamps glow (%d lit surfaces)" % lit)
