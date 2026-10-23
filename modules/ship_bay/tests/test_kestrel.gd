extends ModuleTest
## Ship and Bay: the Kestrel is the one Void Salvage exported (kestrel.vsship.json). Its slots
## are the file's, their joints the file's joints on the slots' parts (BSX's own for slots the
## file carries no part for), the model builds every part with its path, and the bay finds
## each slot's pieces and hides a stripped one.
##   tools/run_tests.sh ship_bay


func run_tests() -> void:
	var bay := Modules.bus("ship_bay") as ShipBayBus
	var def := bay.definition("vs_kestrel")
	check(def != null, "Kestrel definition reads")
	if def == null:
		return
	check(def.model != null, "Kestrel model loads")
	check(def.slot_ids() == PackedStringArray(["eng_port", "eng_stbd", "attractor_coil", "hold_nets", "radar",
			"survey_array", "tow_winch", "bowser_tank"]), "the file's slots: %s" % ", ".join(def.slot_ids()))
	check(def.slot("eng_port").takes("kestrel_engine") and def.slot("eng_port").fitted == "kestrel_engine",
			"engines take and carry the Kestrel engine")
	check(def.slot("attractor_coil").fitted == "" and def.slot("attractor_coil").takes("attractor_coil_1"),
			"the attractor coil slot arrives empty and takes the shared module")
	check(def.rooms.size() == 4 and def.bounds.size.z > 13.0, "rooms and bounds from the file")
	for s in def.slots:
		check(def.bounds.grow(0.01).encloses(s.box), "%s inside the ship" % s.slot_id)
		check(s.box.grow(0.25).has_point(s.mount.origin), "%s mount on its box" % s.slot_id)
		check(s.mount.basis.z.is_normalized(), "%s mount faces somewhere" % s.slot_id)
		check(not s.fasteners.is_empty(), "%s has fasteners" % s.slot_id)
		var ids := {}
		for f in s.fasteners:
			check(FastenerPoint.slot_of(f.joint_id) == s.slot_id and not ids.has(f.joint_id), "%s names its slot once" % f.joint_id)
			ids[f.joint_id] = true
			if f.kind != "connector" or f.path == "":   # a lead's joint is at the loom's end
				check(s.box.grow(0.12).has_point(f.position), "%s sits on its part" % f.joint_id)
			check(f.kind in ["bolt", "rivet", "weld", "connector"], "%s kind %s" % [f.joint_id, f.kind])
			if f.kind == "weld":
				check(f.seam_up.is_normalized() and absf(f.seam_up.dot(f.normal)) < 0.01 and f.seam_size.x > 0.0,
						"%s has a seam across its face" % f.joint_id)
	var port := def.slot("eng_port").fasteners
	check(port.size() == 4 and port.all(func(f: FastenerPoint) -> bool:
			return f.kind == "weld" and f.path.begins_with("slot:eng_port/engine/spot:")),
			"each engine is spot welded to the stern cap, keyed by the file's paths")
	var bowser := def.slot("bowser_tank").fasteners
	var kinds := {}
	for f in bowser:
		kinds[f.kind] = int(kinds.get(f.kind, 0)) + 1
	check(kinds == {"weld": 16, "bolt": 4, "connector": 1}, "bowsers: spots to the deck, pipe bolts, a loom lead: %s" % kinds)
	check(def.slot("hold_nets").fasteners.all(func(f: FastenerPoint) -> bool: return f.path == "" and f.kind == "bolt"),
			"the nets (no part in the file) take BSX's own bolts")
	check(def.slot("eng_port").mount.origin.x == -def.slot("eng_stbd").mount.origin.x, "engines mirror each other")

	var model := def.model.instantiate() as Node3D
	var importer: VsShipImport = model.get("importer")
	check(importer != null and importer.errors.is_empty() and importer.warnings.is_empty(),
			"the file builds cleanly: %s" % ("; ".join(importer.errors + importer.warnings) if importer else "no importer"))
	check(importer.parts_by_path.size() == 529 and importer.joints_by_path.size() == 1748,
			"every part and joint built: %d, %d" % [importer.parts_by_path.size(), importer.joints_by_path.size()])
	for f in port:
		check(importer.joint_at(f.path) != null, "%s is a joint on the model" % f.joint_id)
	check(model.find_children("*", "CollisionShape3D", true, false).size() > 100, "the hull is solid to walk in")
	var lamps := model.find_children("*", "Light3D", true, false).size()
	check(lamps >= 10, "the file's lamps are in: %d" % lamps)
	var found: Dictionary = model.call("slot_pieces", def)
	for id: String in ["eng_port", "eng_stbd", "hold_nets", "bowser_tank"]:
		check((found[id] as Array).size() > 0, "%s finds model pieces: %d" % [id, (found[id] as Array).size()])
	var hull := importer.kit.model.part_visual(importer.part_at("hull/cap/back/0").id)
	check(not (found["eng_port"] as Array).has(hull), "the stern cap the engine sits on is not the engine")
	model.free()

	var scene := load("res://modules/ship_bay/internal/bay/bay.tscn") as PackedScene
	var view := scene.instantiate()
	add_child(view)
	await frames(2)
	check(bay.ship != null and bay.ship.ship_id == "vs_kestrel", "bay scene loads the Kestrel")
	for f in bay.get_fasteners("eng_port"):
		bay.note_joint_removed(f.joint_id)
	var hidden := (view.pieces["eng_port"] as Array).all(
			func(mi: MeshInstance3D) -> bool: return not mi.visible)
	check(hidden, "a stripped engine disappears from the model")
	view.queue_free()
	await frames(1)
	bay.unload_ship()
