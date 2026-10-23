extends ModuleTest
## WreckMaker on the frame Kestrel: each event rolls damage from a seed the same way every
## time, the wreck file still checks out (the ship's own blocks and hashes untouched), the
## importer builds what is left with its wear, scorch, dents and broken joints, a stripped
## wreck is lighter, and the file goes out and comes back as JSON.
##   tools/run_tests.sh shared_components

const FIXTURE := "res://modules/shared_components/data/ships/kestrel.vsship.json"


func run_tests() -> void:
	var f := VsShipImport.read(FIXTURE)
	check(not f.is_empty(), "the Kestrel file reads")
	if f.is_empty():
		return
	_check_events(f)
	_check_build(f)
	_check_roundtrip(f)
	_check_parsing()
	_check_api()


func _check_events(f: Dictionary) -> void:
	for name: String in WreckMaker.EVENTS:
		var w := WreckMaker.make(f, 84, [[name, 3]])
		var d := WreckMaker.damage_of(w)
		var s := WreckMaker.summary(w)
		check(not d.get("parts", {}).is_empty() or not d.get("joints", {}).is_empty(), "%s: does something (%s)" % [name, str(s)])
		check(VsShipImport.check(w).is_empty(), "%s: the wreck file still checks out: %s" % [name, "; ".join(VsShipImport.check(w).slice(0, 3))])
		check(w.get("derived_only", false) == true and w["ship"].get("wreck", false) == true, "%s: marked derived_only, a wreck" % name)
		check(w["parts"].size() == f["parts"].size() and w["joints"].size() == f["joints"].size(), "%s: the ship's parts and joints are untouched" % name)
		var again := WreckMaker.make(f, 84, [[name, 3]])
		check(JSON.stringify(again["damage"]) == JSON.stringify(w["damage"]), "%s: the same seed rolls the same wreck" % name)
		var other := WreckMaker.make(f, 85, [[name, 3]])
		check(JSON.stringify(other["damage"]) != JSON.stringify(w["damage"]), "%s: another seed rolls another wreck" % name)
	var weathered := WreckMaker.summary(WreckMaker.make(f, 1, "weathered:2"))
	check(weathered["worn"] == f["parts"].size(), "weathered: every part worn")
	var fire := WreckMaker.summary(WreckMaker.make(f, 1, "fire:3"))
	check(fire["scorched"] > 20 and fire["broken"] > 0, "fire: scorches a good few parts and breaks joints (%s)" % str(fire))
	var hit := WreckMaker.make(f, 7, "collision:4")
	var dented := 0
	var bent := 0
	for path: String in hit["damage"]["parts"]:
		var c: Dictionary = hit["damage"]["parts"][path]["condition"]
		if c.has("dents"):
			dented += 1
		if c.has("bend"):
			bent += 1
	check(dented > 0 and bent > 0, "collision: dents plates and bends frame members (%d, %d)" % [dented, bent])
	check(hit["damage"]["events"][0].size() >= 4 and hit["damage"]["events"][0][3].has("plate"), "collision: notes the plate it struck")
	var breach := WreckMaker.summary(WreckMaker.make(f, 3, "breach:3"))
	check(breach["gone"] >= 3, "breach: blows plates out (%d gone)" % breach["gone"])
	var stripped := WreckMaker.summary(WreckMaker.make(f, 5, "stripped:3"))
	check(stripped["gone"] > 40, "stripped: takes plates and components (%d gone)" % stripped["gone"])
	# Strength scales it.
	var light := WreckMaker.summary(WreckMaker.make(f, 9, "stripped:1"))
	var heavy := WreckMaker.summary(WreckMaker.make(f, 9, "stripped:5"))
	check(heavy["gone"] > light["gone"], "stripped: strength 5 takes more than 1 (%d > %d)" % [heavy["gone"], light["gone"]])
	# Several events in one wreck, each with its own seed noted.
	var both := WreckMaker.make(f, 11, "fire:2,stripped:2")
	check(both["damage"]["events"].size() == 2 and both["damage"]["events"][1][0] == "stripped", "two events in order")


func _check_build(f: Dictionary) -> void:
	var w := WreckMaker.make(f, 84, "collision:3,fire:2")
	var body := RigidBody3D.new()
	var im := VsShipImport.new()
	var ok := im.build(w, body)
	add_child(body)
	check(ok and im.errors.is_empty() and im.warnings.is_empty(), "the wreck builds clean: %s" % "; ".join(im.warnings.slice(0, 3)))
	var s := WreckMaker.summary(w)
	check(im.parts_by_path.size() == f["parts"].size() - s["gone"] - s["detached"],
			"what is gone is not built (%d of %d, %d gone, %d detached)" % [im.parts_by_path.size(), f["parts"].size(), s["gone"], s["detached"]])
	check(im.gone_parts.size() == s["gone"] and im.detached_parts.size() == s["detached"], "gone and detached parts listed by path")
	check(im.broken_joints.size() == s["broken"] and im.joints_by_path.size() == f["joints"].size() - _dropped(w, im),
			"broken joints are not built (%d)" % im.broken_joints.size())
	for path: String in im.broken_joints:
		check(not im.joints_by_path.has(path), "a broken joint is absent")
		break
	# Wear, scorch, dents and removal reach the PartData, and the scorch its surface.
	var scorched := 0
	var dented := 0
	var own := 0
	for path: String in im.parts_by_path:
		var p: PartData = im.parts_by_path[path]
		var v := im.kit.model.part_visual(p.id)
		if p.scorch > 0.05 and v and v.material_override is ShaderMaterial:   # glass keeps its glazing
			scorched += 1
			if v.has_meta("own_surface"):
				var c: Vector4 = (v.material_override as ShaderMaterial).get_shader_parameter("condition")
				if c.y > 0.05:
					own += 1
		if not p.dents.is_empty():
			dented += 1
	check(scorched > 10 and own == scorched, "scorched parts carry it on their own surface (%d of %d)" % [own, scorched])
	check(dented > 0, "dented parts carry their dents (%d)" % dented)
	var hit: String = w["damage"]["events"][0][3]["plate"]
	check(im.gone_parts.has(hit), "the plate the collision struck is gone")
	# A weakened joint keeps its lower health.
	var weakened := 0
	for path: String in im.joints_by_path:
		var c: ConnectionData = im.joints_by_path[path]
		if c.max_health < float(ConnectionData.MAX_HEALTH.get(c.kind, 100.0)) - 0.01:
			weakened += 1
	check(weakened > 0, "weakened joints keep their lower health (%d)" % weakened)
	# A stripped wreck is lighter than the ship.
	var ship_kg := 0.0
	for p: PartData in im.kit.model.parts.values():
		ship_kg += p.mass
	var st := WreckMaker.make(f, 5, "stripped:3")
	var body2 := RigidBody3D.new()
	var im2 := VsShipImport.new()
	im2.build(st, body2)
	add_child(body2)
	var wreck_kg := 0.0
	for p: PartData in im2.kit.model.parts.values():
		wreck_kg += p.mass
	check(wreck_kg < ship_kg * 0.9, "a stripped wreck is lighter (%.0f of %.0f kg)" % [wreck_kg, ship_kg])
	check(im2.warnings.is_empty(), "stripped builds without warnings: %s" % "; ".join(im2.warnings.slice(0, 3)))
	# A clean ship has no damage.
	var im3 := VsShipImport.new()
	var body3 := RigidBody3D.new()
	im3.build(f, body3)
	add_child(body3)
	check(im3.damage.is_empty() and im3.gone_parts.is_empty() and im3.broken_joints.is_empty(), "a clean ship builds whole")


## Joints the importer leaves out: broken ones, and those on a part that is gone or detached.
func _dropped(w: Dictionary, im: VsShipImport) -> int:
	var n := 0
	for j: Dictionary in w["joints"]:
		if im.broken_joints.has(j["path"]) or not im.parts_by_path.has(j["a"]) or not im.parts_by_path.has(j["b"]):
			n += 1
	return n


func _check_roundtrip(f: Dictionary) -> void:
	var w := WreckMaker.make(f, 42, "fire:3")
	var path := "user://test_wreck_maker.vsship.json"
	var text := ShipRecorder.to_json(w)
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "the wreck file writes")
	if file == null:
		return
	file.store_string(text)
	file.close()
	var back := VsShipImport.read(path)
	check(VsShipImport.check(back).is_empty(), "the written wreck reads and checks out")
	check(WreckMaker.summary(back) == WreckMaker.summary(w), "the damage comes back as it went")
	var body := RigidBody3D.new()
	var im := VsShipImport.new()
	check(im.build(back, body) and im.warnings.is_empty(), "the read wreck builds")
	add_child(body)
	DirAccess.remove_absolute(path)


func _check_parsing() -> void:
	check(WreckMaker.parse_events("fire:3,stripped:1:84") == [["fire", 3], ["stripped", 1, 84]], "events parse from text")
	check(WreckMaker.parse_events([["impact", 9], ["no_such", 1]]) == [["collision", 5]], "aliases map, unknown events drop, strength clamps")
	check(WreckMaker.parse_events("fire") == [["fire", 2]], "a bare name is strength 2")


## What Contracts and Ship and Bay call: a wreck by design name and seed, and its manifest.
func _check_api() -> void:
	check(VsShipImport.design_file("kestrel_frame") == VsShipImport.SHIPS["kestrel"] and VsShipImport.design_file("manta_frame") != "",
			"a design file by short name or id")
	check(VsShipImport.design_file("no_such") == "" and WreckMaker.for_design("no_such", 1).is_empty(), "an unknown design gives nothing")
	var w := WreckMaker.for_design("kestrel", 84, "fire:3,stripped:2")
	check(not w.is_empty() and WreckMaker.damage_of(w).has("parts"), "a wreck by design name and seed")
	var m := WreckMaker.manifest(w)
	check(m["design"] == "kestrel" and m["class"] == "S" and m["wreck"] == true, "the manifest names the design and class")
	check(m["parts"].size() == w["parts"].size() and m["gone"] > 0 and m["mass_kg"] < m["ship_mass_kg"],
			"the manifest lists every part with its state and weighs what is left (%.0f of %.0f kg)" % [m["mass_kg"], m["ship_mass_kg"]])
	var first: Dictionary = m["parts"][0]
	check(first.has("material") and first.has("removal") and first.has("scorch"), "a manifest part carries material, removal and condition")
	var clean := WreckMaker.manifest(VsShipImport.read(VsShipImport.design_file("kestrel")))
	check(clean["wreck"] == false and clean["gone"] == 0 and is_equal_approx(clean["mass_kg"], clean["ship_mass_kg"]), "a clean ship's manifest is whole")
