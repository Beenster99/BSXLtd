extends ModuleTest
## The vsship 2.0 importer on the frame Kestrel and frame Manta as Void Salvage exported them
## (fixtures/*.vsship.json, F7a): the files check out (schema, hashes, paths), every part and
## joint builds onto a body with its path, kind, head and phase, the fittings dress their
## parts, and a part is found by its path.
##   tools/run_tests.sh shared_components

const FIXTURES := "res://modules/shared_components/tests/fixtures/"


func run_tests() -> void:
	_check_ship("kestrel_frame", 529, 1748, 33)
	_check_ship("manta_frame", 1410, 6677, 77)
	_check_encodings()


func _check_ship(id: String, parts: int, joints: int, fittings: int) -> void:
	var f := VsShipImport.read(FIXTURES + id + ".vsship.json")
	check(not f.is_empty(), "%s: the file reads" % id)
	if f.is_empty():
		return
	var problems := VsShipImport.check(f)
	check(problems.is_empty(), "%s: the file checks out: %s" % [id, "; ".join(problems)])
	var body := RigidBody3D.new()
	var im := VsShipImport.new()
	var ok := im.build(f, body)   # built off the tree, then added: one compound shape, not one per part
	add_child(body)
	check(ok and im.errors.is_empty(), "%s: builds without errors: %s" % [id, "; ".join(im.errors)])
	check(im.warnings.is_empty(), "%s: builds without warnings: %s" % [id, "; ".join(im.warnings.slice(0, 5))])
	check(im.parts_by_path.size() == parts, "%s: every part built (%d of %d)" % [id, im.parts_by_path.size(), parts])
	check(im.joints_by_path.size() == joints, "%s: every joint built (%d of %d)" % [id, im.joints_by_path.size(), joints])
	check(im.kit.model.parts.size() == parts and im.kit.model.connections.size() == joints,
			"%s: the body's PartModel holds them" % id)
	check(im.fittings_built.size() == fittings, "%s: every fitting record rebuilt (%d of %d)" % [id, im.fittings_built.size(), fittings])
	# A part by its path, with the file's kind, mass and material.
	var first: Dictionary = f["parts"][0]
	var p := im.part_at(first["path"])
	check(p != null and p.path == first["path"], "%s: a part is found by its path" % id)
	check(p != null and is_equal_approx(p.mass, float(first["mass"])), "%s: the part keeps the file's mass" % id)
	check(p != null and p.material == first["material"], "%s: the part keeps the file's material" % id)
	# A joint by its path, with its kind, head, phase and ends.
	var jrec: Dictionary = f["joints"][0]
	var j := im.joint_at(jrec["path"])
	check(j != null and ConnectionData.Kind.keys()[j.kind].to_lower() == jrec["kind"], "%s: a joint keeps its kind" % id)
	check(j != null and j.head == int(jrec["head"]) and j.phase == jrec["phase"], "%s: a joint keeps its head and phase" % id)
	check(j != null and j.part_a == im.part_at(jrec["a"]).id and j.part_b == im.part_at(jrec["b"]).id,
			"%s: a joint joins the two parts its paths name" % id)
	check(j != null and j.local_position.is_equal_approx(VsShipImport.vec3(jrec["at"])), "%s: a joint sits where the file says" % id)
	# Phases: every joint has one, and the file's per-phase counts come through.
	var by_phase: Dictionary = f["derived"]["joints_by_phase"]
	var phases_ok := true
	for phase: String in by_phase:
		if im.joints_in_phase(phase).size() != int(by_phase[phase]):
			phases_ok = false
	check(phases_ok, "%s: joints_in_phase matches derived.joints_by_phase" % id)
	# A plate's rivets are found from the plate.
	var plate_path := ""
	for rec: Dictionary in f["parts"]:
		if rec["name"] == "HullPlate":
			plate_path = rec["path"]
			break
	check(plate_path != "" and im.joints_of(plate_path).size() >= 4, "%s: a hull plate has its row of rivets" % id)
	# Slots still carry the module ids BSX names.
	var slot_ids: Array = []
	for s: Dictionary in f.get("slots", []):
		slot_ids.append(s["slot_id"])
	check(slot_ids.has("hold_nets") and slot_ids.has("bowser_tank"), "%s: slots carry hold_nets and bowser_tank" % id)
	body.queue_free()


func _check_encodings() -> void:
	check(VsShipImport.vec3([1, 2, 3]) == Vector3(1, 2, 3), "vec3 from a list")
	check(VsShipImport.vec3("(4.254135, 0.14, 0.1)").is_equal_approx(Vector3(4.254135, 0.14, 0.1)), "vec3 from the text form")
	var t := VsShipImport.xform({"o": [1, 2, 3], "b": [0, 0, -1, 0, 1, 0, 1, 0, 0]})
	check(t.origin == Vector3(1, 2, 3) and t.basis.x.is_equal_approx(Vector3(0, 0, 1)) and t.basis.z.is_equal_approx(Vector3(-1, 0, 0)),
			"a transform's basis rows decode to its axes")
	check(VsShipImport.make_shape({"shape": "box", "args": [[1, 2, 3]]}) != null, "a box recipe makes a shape")
	check(VsShipImport.make_shape({"shape": "plate", "args": [[[0, 0], [1, 0], [1, 1]], 0.08]}) != null, "a FrameParts plate recipe makes a shape")
	check(VsShipImport.make_shape({"shape": "pipe", "args": [0.02, 0.5, [], []]}) != null, "a pipe recipe makes a shape")
	check(VsShipImport.make_shape({"shape": "no_such", "args": []}) == null, "an unknown recipe is null")
	var bad := VsShipImport.check({"format": "vsship", "version": [1, 0]})
	check(not bad.is_empty(), "a 1.0 file is refused plainly")
