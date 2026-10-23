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
	check(def.slot_ids().slice(0, 9) == PackedStringArray(["eng_port", "eng_stbd", "attractor_coil", "hold_nets", "radar",
			"survey_array", "tow_winch", "bowser_tank", "plate_hold_port"]), "the file's slots: %s" % ", ".join(def.slot_ids().slice(0, 9)))
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
	var bolts := port.filter(func(f: FastenerPoint) -> bool: return f.path != "")
	check(port.size() == 6 and bolts.size() == 4 and bolts.all(func(f: FastenerPoint) -> bool:
			return f.kind == "bolt" and f.spec == "M12" and f.path.begins_with("slot:eng_port/engine/spot:")),
			"each engine is bolted (M12) to the stern cap where the file spots it, keyed by the file's paths")
	var plugs := port.filter(func(f: FastenerPoint) -> bool: return f.kind == "connector").map(
			func(f: FastenerPoint) -> String: return f.spec)
	check(plugs == ["fuel", "power"], "and takes a fuel and a power plug: %s" % [plugs])
	var plate := def.slot("plate_hold_port")
	check(plate.fitted == "HullPlate" and plate.fasteners.size() == 8 and plate.fasteners.all(
			func(f: FastenerPoint) -> bool: return f.kind == "rivet" and f.path != ""),
			"the hold's port side plate is a fitting riveted on with the file's 8 rivets")
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
	for f in bolts + plate.fasteners:
		check(importer.joint_at(f.path) != null, "%s is a joint on the model" % f.joint_id)
	check(model.find_children("*", "CollisionShape3D", true, false).size() > 100, "the hull is solid to walk in")
	var lamps := model.find_children("*", "Light3D", true, false).size()
	check(lamps >= 10, "the file's lamps are in: %d" % lamps)
	var found: Dictionary = model.call("slot_pieces", def)
	for id: String in ["eng_port", "eng_stbd", "hold_nets", "bowser_tank", "plate_hold_port"]:
		check((found[id] as Array).size() > 0, "%s finds model pieces: %d" % [id, (found[id] as Array).size()])
	var hull := importer.kit.model.part_visual(importer.part_at("hull/cap/back/0").id)
	check(not (found["eng_port"] as Array).has(hull), "the stern cap the engine sits on is not the engine")
	# The sliding doors start shut and slide open (and shut) on their panels.
	var leaf := importer.part_at("system:door_lock_out/leaf")
	var shut := leaf.local_transform.origin
	check(not bool(model.call("is_door_open", "door_lock_out")) and not bool(model.call("is_door_open", "door_bulkhead")),
			"both sliding doors start shut")
	var panel := importer.kit.model.part_collider(importer.part_at("system:door_lock_out/door_panel/1").id)
	check(panel != null and panel.has_meta("ship_bay_use"), "the side door's outside panel is a button")
	model.call("set_door", "door_lock_out", true, true)
	check(leaf.local_transform.origin.distance_to(shut + Vector3(0, 0, 0.85)) < 0.001, "open, the leaf is in its pocket")
	check(importer.kit.model.part_collider(leaf.id).position.distance_to(shut) > 0.8, "and so is its collision")
	model.call("set_door", "door_lock_out", false, true)
	check(leaf.local_transform.origin.distance_to(shut) < 0.001, "shut again")
	# The bulkhead's pocket door fills its doorway (the file draws it a third of its width).
	var inner := importer.part_at("system:door_bulkhead/leaf")
	var inner_look := importer.kit.model.part_visual(inner.id) as MeshInstance3D
	check(absf(inner_look.mesh.get_aabb().size.x - 1.12) < 0.01 and absf(inner.local_transform.origin.x) < 0.01,
			"the inside door is as wide as its doorway: %s" % inner_look.mesh.get_aabb().size)
	# The systems the file carries only as boxes are dressed: bowsers, hose, port, panels,
	# screens, floodlights, wires.
	var texts := {}
	for l: Label3D in model.find_children("*", "Label3D", true, false):
		texts[l.text.get_slice("\n", 0)] = true
	for want: String in ["FUEL", "COOLANT", "FUEL HOSE", "CARGO CONTROL", "STERN DOOR", "OPEN", "CLOSE", "HOLD MONITOR                 KESTREL", "SYSTEM MAP", "PUMP"]:
		check(texts.has(want), "the Kestrel has a %s label" % want.get_slice(" ", 0))
	check(model.get_node_or_null("Bowser_fuel") is CollisionShape3D and model.get_node_or_null("Bowser_coolant") is CollisionShape3D,
			"the bowsers' drums are solid")
	var dressing: RefCounted = model.get("dressing")
	check((dressing.get("spots") as Array).size() == 4, "four floodlights")
	var wires := model.get_node_or_null("Wires") as MeshInstance3D
	check(wires != null and wires.mesh.get_aabb().size.z > 5.0, "the leads' wires run along the ship")
	model.call("set_door", "door_bulkhead", true, true)
	var lamps: Array = (dressing.get("door_lamps") as Dictionary).get("door_bulkhead", [])
	check(lamps.size() == 2 and (lamps[0] as StandardMaterial3D).emission.g > 0.8, "an open door's panel lamps show green")
	model.call("set_door", "door_bulkhead", false, true)
	var plates := def.slots.filter(func(s: MountSlot) -> bool: return s.slot_id.begins_with("plate_"))
	var rivets := 0
	for s: MountSlot in plates:
		rivets += s.fasteners.filter(func(f: FastenerPoint) -> bool: return f.kind == "rivet").size()
	check(plates.size() == 69 and rivets == 369, "every riveted outer plate is a fitting: %d plates, %d rivets" % [plates.size(), rivets])
	check(def.slot("plate_cabin_e0") != null and def.slot("plate_cabin_e0").access == "outboard", "plates are named by body and edge, worked from outside")
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
