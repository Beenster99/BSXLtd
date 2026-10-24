extends ModuleTest
## Ship and Bay: the emitter frame rig (Component Upgrades U1). A coil goes on its deck and
## comes off, its four hold-down bolts sit on the deck in yard space, TEST asks the host for a
## field sweep and Quality's result plays on every rig; all of it is saved.
##   tools/run_tests.sh ship_bay

const Rig := preload("res://modules/ship_bay/internal/yard/emitter_rig.gd")
const Yard := preload("res://modules/ship_bay/internal/yard/shipyard.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var spot := bus.shipyard_spot("rig_emitter")
	check(spot != Transform3D.IDENTITY and absf(spot.origin.y - Rig.DECK_H) < 0.001, "the rig has a spot at deck height: %s" % spot.origin)
	check(Yard.room_at(spot.origin) == "preassembly", "in Pre-assembly")
	check(spot.origin.distance_to(bus.shipyard_spot("bench_preassembly").origin) > 6.0, "clear of Trades' test stand")
	# The rig's floor outline, mass rail included, stays in the room and off the lines' trolleys.
	var room: AABB = Yard.ROOMS["preassembly"]["box"]
	for corner: Vector3 in [Vector3(-2.4, 0, -1.0), Vector3(Rig.DECK.x * 0.5 + Rig.MASS_RAIL + 0.6, 0, 1.0),
			Vector3(-2.4, 0, 1.0), Vector3(Rig.DECK.x * 0.5 + Rig.MASS_RAIL + 0.6, 0, -1.0)]:
		var p := spot * (corner - Vector3(0, Rig.DECK_H, 0))
		check(room.grow(-0.3).has_point(p + Vector3(0, 1, 0)) and p.x < 33.0 and p.z > 7.0, "the rig's corner %s is in the room, west of line A's trolley and south of the doorway" % p)

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
	var points := bus.rig_points("rig_emitter")
	var bolts_ok := points.size() == 4
	for f: FastenerPoint in points:
		bolts_ok = bolts_ok and f.kind == "bolt" and f.spec == "M12" and f.joint_id.begins_with("rig_emitter/b") \
				and absf(f.position.y - (Rig.DECK_H + 0.03)) < 0.001 and f.position.distance_to(spot.origin) < 0.8
	check(bolts_ok, "four M12 hold-down bolts on the deck, in yard space")

	var asked := []
	var heard := func(id: String, unit: String) -> void: asked.append([id, unit])
	bus.rig_test_requested.connect(heard)
	rig.screen.call("press", "test")
	check(asked == [["rig_emitter", "attractor_coil_1"]] and bool(bus.rig_state("rig_emitter")["testing"]),
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
	bus.rig_unmount("rig_emitter")
	await frames(1)
	check(bus.rig_state("rig_emitter")["unit"] == "" and rig.unit_look == null, "the coil comes off")
	bus.restore(saved)
	await frames(1)
	check(bus.rig_state("rig_emitter")["unit"] == "attractor_coil_1" and rig.unit_look != null, "a load puts it back")
	bus.rig_unmount("rig_emitter")
	rig.queue_free()
	await frames(1)
