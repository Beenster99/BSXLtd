extends ModuleTest
## Ship and Bay: the emitter frame rig (Component Upgrades U1). A coil goes on its deck and
## comes off, its four hold-down bolts follow its housing in spot space and are tracked like the ship's joints, TEST asks the host for a
## field sweep and Quality's result plays on every rig; all of it is saved.
##   tools/run_tests.sh ship_bay

const Rig := preload("res://modules/ship_bay/internal/yard/emitter_rig.gd")
const Yard := preload("res://modules/ship_bay/internal/yard/shipyard.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var spot := bus.shipyard_spot("rig_emitter")
	check(spot != Transform3D.IDENTITY and absf(spot.origin.y - Rig.DECK_H) < 0.001, "the rig has a spot at deck height: %s" % spot.origin)
	# It stands in the upgrade hall (beenster, 0.3.26), in its own bay there.
	check(Yard.room_at(spot.origin) == "upgrades", "in the upgrade hall")
	var bay: Array = Yard.UPGRADE_BAYS[0]
	var bay_box := Rect2((bay[4] as Vector2) - Yard.UPGRADE_BAY * 0.5, Yard.UPGRADE_BAY).grow(-0.2)
	# The rig's floor outline, mass rail and worker's place included, stays inside its bay.
	for corner: Vector3 in [Vector3(-2.4, 0, -1.0), Vector3(Rig.DECK.x * 0.5 + Rig.MASS_RAIL + 0.6, 0, 1.6),
			Vector3(-2.4, 0, 1.6), Vector3(Rig.DECK.x * 0.5 + Rig.MASS_RAIL + 0.6, 0, -1.0)]:
		var p := spot * (corner - Vector3(0, Rig.DECK_H, 0))
		check(bay_box.has_point(Vector2(p.x, p.z)), "the rig's corner %s is inside its bay %s" % [p, bay_box])
	# The other rigs the plan names have a bay each, apart, all in the hall.
	var hall := Yard.upgrade_box()
	for i in Yard.UPGRADE_BAYS.size():
		var b: Array = Yard.UPGRADE_BAYS[i]
		var r := Rect2((b[4] as Vector2) - Yard.UPGRADE_BAY * 0.5, Yard.UPGRADE_BAY)
		check(Rect2(hall.position.x, hall.position.z, hall.size.x, hall.size.z).grow(-0.4).encloses(r), "bay %s is in the hall" % b[0])
		check(bus.shipyard_spot(str(b[0])) != Transform3D.IDENTITY, "bay %s has a spot" % b[0])
		for j in range(i + 1, Yard.UPGRADE_BAYS.size()):
			var o: Array = Yard.UPGRADE_BAYS[j]
			check(not r.intersects(Rect2((o[4] as Vector2) - Yard.UPGRADE_BAY * 0.5, Yard.UPGRADE_BAY)), "bays %s and %s are apart" % [b[0], o[0]])
	# The door's aisle up the east side stays clear of the bays.
	var aisle := Rect2(Yard.UPGRADE_DOOR.x - Yard.UPGRADE_DOOR.y * 0.5, -28.0, Yard.UPGRADE_DOOR.y, hall.end.z + 28.0)
	check(Yard.UPGRADE_BAYS.all(func(b: Array) -> bool: return not aisle.intersects(Rect2((b[4] as Vector2) - Yard.UPGRADE_BAY * 0.5, Yard.UPGRADE_BAY))),
			"the way in from the door is clear")

	var rig := Rig.new()
	rig.sweep_time = 0.2
	add_child(rig)
	await frames(1)
	check(rig.unit_look == null, "the deck starts empty")
	bus.rig_mount("rig_emitter", "turbopump_1")
	check(bus.rig_state("rig_emitter")["unit"] == "", "it takes attractor coils only")
	bus.rig_mount("rig_emitter", "attractor_coil_1")
	await frames(1)
	check(bus.rig_state("rig_emitter")["unit"] == "attractor_coil_1" and rig.unit_look != null, "a coil goes on the deck")
	bus.rig_mount("rig_emitter", "attractor_coil_2")
	check(bus.rig_state("rig_emitter")["unit"] == "attractor_coil_1", "one unit at a time")
	check(bus.rig_state("rig_emitter")["tier"] == 1, "its tier is in the rig's state")
	var points := bus.rig_points("rig_emitter")
	var bolts_ok := points.size() == 4
	for f: FastenerPoint in points:
		bolts_ok = bolts_ok and f.kind == "bolt" and f.spec == "M12" and f.joint_id.begins_with("rig_emitter/b") \
				and absf(f.position.y) < 0.001 and is_equal_approx(absf(f.position.x), 0.4) and is_equal_approx(absf(f.position.z), 0.07) \
				and f.normal == Vector3.UP
	check(bolts_ok, "four M12 hold-down bolts at the Mk I housing's base corners, in spot space")
	check(bus.get_fasteners("rig_emitter").size() == 4, "get_fasteners gives the rig's bolts too")
	var size: Vector3 = Rig.unit_size("attractor_coil_1")
	var box := AABB(Vector3(-size.x * 0.5, Rig.DECK_H, -size.z * 0.5), size)
	# Shared Components' coil carries its place in its record; the stand-in in its node.
	var at: Transform3D = rig.unit_parts.get("xform", (rig.unit_look as Node3D).transform)
	check(rig.unit_look.get_child_count() > 0 and at.origin.distance_to(box.get_center()) < 0.001, "the unit sits on the deck, its centre over the deck's middle")
	if not rig.unit_parts.is_empty():
		check(bus.rig_unit("rig_emitter").get("unit", "") == "attractor_coil_1" and bus.rig_unit("rig_emitter").has("kit"),
				"rig_unit gives Shared Components' coil and its kit")
	check(not bus.is_joint_tight("rig_emitter/b1") and bus.note_joint_made("rig_emitter/b1", 0.9), "Tools torques a hold-down")
	check(bus.is_joint_tight("rig_emitter/b1") and is_equal_approx(bus.joint_quality("rig_emitter/b1"), 0.9)
			and (bus.rig_state("rig_emitter")["joints"] as Dictionary).size() == 1, "the rig keeps it")
	check(not bus.note_joint_made("rig_emitter/b9", 1.0), "and refuses a bolt it doesn't have")
	bus.rig_unmount("rig_emitter")
	check(bus.rig_state("rig_emitter")["unit"] == "attractor_coil_1", "a bolted-down unit can't come off")
	check(bus.note_joint_removed("rig_emitter/b1") and not bus.is_joint_tight("rig_emitter/b1"), "the bolt comes out")
	bus.note_joint_made("rig_emitter/b2", 1.0)

	var asked := []
	var heard := func(id: String, unit: String) -> void: asked.append([id, unit])
	bus.rig_test_requested.connect(heard)
	rig.screen.call("press", "test")
	# Quality may answer at once (its rig test is in), so the rig is testing or has a result.
	var st := bus.rig_state("rig_emitter")
	check(asked == [["rig_emitter", "attractor_coil_1"]] and (bool(st["testing"]) or not (st["result"] as Dictionary).is_empty()),
			"TEST asks the host for a field sweep")
	check(rig.sweep >= 0.0, "and the rig starts sweeping")
	bus.rig_test_requested.disconnect(heard)
	var result := {"lines": [["Reach", "18 m", "24 m"], ["Max mass", "6 t", "9 t"]], "passed": true, "note": "Within rating."}
	bus.rig_show_test("rig_emitter", result)
	check(not bool(bus.rig_state("rig_emitter")["testing"]) and bus.rig_state("rig_emitter")["result"] == result, "the result is kept")
	var far := rig.mass.position.x
	for i in 60:
		await get_tree().process_frame
		if rig.sweep < 0.0:
			break
	check(rig.sweep < 0.0 and absf(rig.mass.position.x - far) < 0.01, "the sweep runs and the mass goes back")
	check(str(rig.screen.get("_status").text) == "PASS" and str(rig.screen.get("_body").text).contains("24 m"), "the screen shows PASS and the new numbers")

	var saved := bus.snapshot()
	bus.note_joint_removed("rig_emitter/b2")
	bus.rig_unmount("rig_emitter")
	await frames(1)
	check(bus.rig_state("rig_emitter")["unit"] == "" and rig.unit_look == null, "the coil comes off")
	bus.restore(saved)
	await frames(1)
	check(bus.rig_state("rig_emitter")["unit"] == "attractor_coil_1" and rig.unit_look != null
			and bus.is_joint_tight("rig_emitter/b2"), "a load puts it back, bolted as it was")
	bus.note_joint_removed("rig_emitter/b2")
	bus.rig_unmount("rig_emitter")
	bus.rig_mount("rig_emitter", "attractor_coil_3")
	var wide := bus.rig_points("rig_emitter")
	check(wide.size() == 4 and is_equal_approx(absf(wide[0].position.x), 0.65) and bus.rig_state("rig_emitter")["tier"] == 3,
			"a Mk III's bolts follow its bigger housing")
	bus.rig_unmount("rig_emitter")
	rig.queue_free()
	await frames(1)
