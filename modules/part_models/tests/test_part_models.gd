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
		var pieces: Array = PartModels.motion(id).get("pieces", [])
		check(meshes.size() == 1 + pieces.size(), "%s: one joined mesh a piece (%d)" % [id, meshes.size()])
		var surfaces := 0
		for m in meshes:
			surfaces += (m as MeshInstance3D).mesh.get_surface_count()
			for i in (m as MeshInstance3D).mesh.get_surface_count():
				var mat := (m as MeshInstance3D).mesh.surface_get_material(i) as BaseMaterial3D
				if mat and mat.emission_enabled:
					lit += 1
		check(surfaces >= 2 and surfaces <= 16 + 4 * pieces.size(), "%s: a handful of materials (%d)" % [id, surfaces])
		var box := PartModels.box(id)
		var mid := box.get_center()
		check(absf(box.position.y) < 0.005 and absf(mid.x) < 0.005 and absf(mid.z) < 0.005,
				"%s: stands on the floor, centred (%s)" % [id, box])
		check(PartModels.size(id).is_equal_approx(box.size), "%s: size() reads its box" % id)
		n.free()
	check(lit >= 60, "screens and lamps glow (%d lit surfaces)" % lit)
	_test_moving()


## Moving parts: each piece is a node on its pivot, posing moves it, and the notes say how.
func _test_moving() -> void:
	check(PartModels.motion("fridge").is_empty(), "a part that doesn't move has no motion note")
	for id: String in ["landing_gear", "cargo_ramp", "blast_door"]:
		var note := PartModels.motion(id)
		var pieces: Array = note.get("pieces", [])
		check(not pieces.is_empty() and note.has("power_kw") and note.has("load_kg"), "%s: has a motion note" % id)
		var n := PartModels.instance(id)
		var before := {}
		for pc: Dictionary in pieces:
			var node := PartModels.piece(n, pc["name"])
			check(node != null, "%s: piece %s is a node" % [id, pc["name"]])
			check(PartModels.piece(n, pc["parent"]) != null, "%s: %s hangs off %s" % [id, pc["name"], pc["parent"]])
			if node:
				before[pc["name"]] = node.transform
		PartModels.pose(n, id, 0.0)
		var stowed := {}
		for pc: Dictionary in pieces:
			var node := PartModels.piece(n, pc["name"])
			if node:
				stowed[pc["name"]] = node.transform
		PartModels.pose(n, id, 1.0)
		var moved := 0
		for pc: Dictionary in pieces:
			var node := PartModels.piece(n, pc["name"])
			if node and not node.transform.is_equal_approx(stowed[pc["name"]]):
				moved += 1
		check(moved > 0, "%s: operating moves its pieces (%d)" % [id, moved])
		for pc: Dictionary in pieces:
			var node := PartModels.piece(n, pc["name"])
			if node and is_zero_approx(float(pc["deployed"])):
				check(node.transform.is_equal_approx(before[pc["name"]]), "%s: %s deploys back to as built" % [id, pc["name"]])
		n.free()
	check(PartModels.motion("cargo_ramp").get("opening", []).size() == 2, "a ramp says how big a way through it opens")
	var foot: Dictionary = PartModels.motion("landing_gear")["pieces"][2]
	check(foot["name"] == "foot" and foot.has("contact"), "the gear's foot has a contact for standing on a pad")
	var door := PartModels.instance("blast_door")
	var leaf := PartModels.piece(door, "leaf_r")
	var x0 := leaf.position.x
	PartModels.pose(door, "blast_door", 1.0)
	check(leaf.position.x > x0 + 0.5, "the blast door's right leaf slides open to the right (%.2f)" % (leaf.position.x - x0))
	door.free()
