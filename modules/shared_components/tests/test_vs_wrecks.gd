extends ModuleTest
## Void Salvage's own wrecks in BSX (beenster, 27 Oct): every packed design reads, builds with
## no errors (each part from its library recipe or Void Salvage's own triangles, each joint
## between its two parts), keeps Void Salvage's part and joint counts, takes the wreck maker's
## damage, and is picked the same way on every machine.
##   tools/run_tests.sh shared_components


func run_tests() -> void:
	var all := VsWreckLibrary.designs()
	check(not all.is_empty(), "there are packed wrecks: %d" % all.size())
	for design: String in all:
		var info := VsWreckLibrary.info(design)
		var f := VsShipImport.design_source(design)
		check(not f.is_empty() and VsWreckLibrary.is_vs_wreck(design), "%s reads" % design)
		if f.is_empty():
			continue
		check(f["parts"].size() == int(info["parts"]) and f["joints"].size() == int(info["joints"]),
				"%s: as many parts and joints as the index says (%d, %d)" % [design, f["parts"].size(), f["joints"].size()])
		var body := RigidBody3D.new()
		var im := VsShipImport.new()
		var ok := im.build(f, body)
		add_child(body)
		check(ok and im.errors.is_empty() and im.warnings.is_empty(), "%s builds cleanly: %s" % [design, "; ".join((im.errors + im.warnings).slice(0, 4))])
		check(im.parts_by_path.size() == f["parts"].size() and im.joints_by_path.size() == f["joints"].size(),
				"%s: every part and joint built (%d of %d, %d of %d)" % [design, im.parts_by_path.size(), f["parts"].size(),
				im.joints_by_path.size(), f["joints"].size()])
		var meshes := 0
		for p: Dictionary in f["parts"]:
			if str(p["shape"]["shape"]) == "vs_mesh":
				meshes += 1
				var part := im.part_at(p["path"])
				var vis: MeshInstance3D = im.kit.model.part_visual(part.id) if part else null
				if vis == null or vis.mesh == null or vis.mesh.get_faces().is_empty():
					check(false, "%s: %s has its triangles" % [design, p["path"]])
					break
		check(meshes > 0, "%s: parts drawn from Void Salvage's own triangles: %d" % [design, meshes])
		var wreck := WreckMaker.for_design(design, 84, "collision:3,fire:2")
		check(not WreckMaker.damage_of(wreck).is_empty(), "%s: the wreck maker damages her" % design)
		body.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var a := VsWreckLibrary.pick(rng, "M")
	rng.seed = 7
	check(a != "" and a == VsWreckLibrary.pick(rng, "M") and VsWreckLibrary.size_of(a) == "M", "the same roll picks the same medium wreck: %s" % a)
