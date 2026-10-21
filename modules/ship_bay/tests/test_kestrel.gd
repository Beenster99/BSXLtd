extends ModuleTest
## Ship and Bay: the Kestrel's layout reads, its slots sit on the ship, and the model's pieces
## for each slot are found.
##   tools/run_tests.sh ship_bay

const Bay := preload("res://modules/ship_bay/internal/bay/bay.gd")


func run_tests() -> void:
	var bay := Modules.bus("ship_bay") as ShipBayBus
	var def := bay.definition("vs_kestrel")
	check(def != null, "Kestrel definition reads")
	if def == null:
		return
	check(def.model != null, "Kestrel model loads")
	check(def.slot_ids() == PackedStringArray(["eng_aft_port_1", "eng_aft_stbd_1", "net_hold_dor_1",
			"att_hold_aft_1", "pnl_roof_hold_1", "brk_hold_port_1", "plt_hull_stbd_1"]),
			"the 0.3 slots, the riveted roof panel and the welded bracket and doubler plate: %s" % def.slot_ids())
	for welded: String in ["brk_hold_port_1", "plt_hull_stbd_1"]:
		var welds := def.slot(welded).fasteners
		check(welds.size() >= 3 and welds.all(func(f: FastenerPoint) -> bool:
				return f.kind == "weld" and f.seam_size.x > 0.0 and f.seam_up.is_normalized() and absf(f.seam_up.dot(f.normal)) < 0.01),
				"%s is welded on: %d seams, each along its surface" % [welded, welds.size()])
	var panel := def.slot("pnl_roof_hold_1").fasteners
	check(panel.size() >= 30 and panel.all(func(f: FastenerPoint) -> bool: return f.kind == "rivet" and f.spec == "RIVET_4"),
			"roof panel is riveted on: %d rivets" % panel.size())
	check(def.rooms.get("hold", Vector2.ZERO) == Vector2(1.65, 6.42), "hold span from Void Salvage")
	for s in def.slots:
		check(def.bounds.grow(0.01).encloses(s.box), "%s inside the ship" % s.slot_id)
		check(s.box.grow(0.15).has_point(s.mount.origin), "%s mount on its box" % s.slot_id)
		check(s.mount.basis.z.is_normalized(), "%s mount faces somewhere" % s.slot_id)
		check(not s.fasteners.is_empty(), "%s has fasteners" % s.slot_id)
		for f in s.fasteners:
			check(FastenerPoint.slot_of(f.joint_id) == s.slot_id, "%s names its slot" % f.joint_id)
			check(s.box.grow(0.1).has_point(f.position), "%s sits on its part" % f.joint_id)
			check(f.kind in ["bolt", "rivet", "weld", "connector"], "%s kind %s" % [f.joint_id, f.kind])
	check(def.slot("eng_aft_port_1").mount.origin.x == -def.slot("eng_aft_stbd_1").mount.origin.x,
			"engines mirror each other")

	var model := def.model.instantiate() as Node3D
	var heads := {}
	for mmi: MultiMeshInstance3D in model.find_children("*", "MultiMeshInstance3D", false, false):
		heads[mmi.name.rstrip("0123456789")] = int(heads.get(mmi.name.rstrip("0123456789"), 0)) + mmi.multimesh.instance_count
	check(int(heads.get("Rivets", 0)) > 1500, "skin is riveted: %s" % heads)
	check(int(heads.get("BoltHeads", 0)) > 200, "linings, deck and fittings are bolted: %s" % heads)
	check(model.find_children("*", "CollisionShape3D", false, false).size() > 100, "the hull is solid to walk in")
	var root := Node3D.new()
	root.add_child(model)
	var found: Dictionary = Bay.pieces_by_slot(root, def)
	for s in def.slots:
		check((found[s.slot_id] as Array).size() > 0, "%s finds model pieces: %d" % [s.slot_id,
				(found[s.slot_id] as Array).size()])
	check((found["eng_aft_port_1"] as Array).size() == 5, "port engine is cowl, trim, ring, nozzle, glow")
	root.free()

	var scene := load("res://modules/ship_bay/internal/bay/bay.tscn") as PackedScene
	var view := scene.instantiate()
	add_child(view)
	await frames(2)
	check(bay.ship != null and bay.ship.ship_id == "vs_kestrel", "bay scene loads the Kestrel")
	for f in bay.get_fasteners("att_hold_aft_1"):
		bay.note_joint_removed(f.joint_id)
	var hidden := (view.pieces["att_hold_aft_1"] as Array).all(
			func(mi: MeshInstance3D) -> bool: return not mi.visible)
	check(hidden, "stripped emitters disappear from the model")
	view.queue_free()
	await frames(1)
	bay.unload_ship()
