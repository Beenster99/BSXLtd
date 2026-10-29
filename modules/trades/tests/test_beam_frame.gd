extends ModuleTest
## trades.beam_designer, built onto the frame (beenster, 29 Oct: "the beams and design that we
## add MUST be attached to the existing beam structure"): an end holds only on one of the
## ship's frame members or on another beam of the design. On a frame node with its plates
## still fitted the end is pink (strip them first); with those plates off it holds. The
## ground and the cradle don't hold a beam, beams that never reach the frame are "not on the
## ship", and TEST passes only a design joined to the bare frame. Ends snap to frame nodes.

func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var saved := {}
	for flag: String in ["trades.beam_designer", "trades.beam_versions"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	# Drawn end to end, the first way (trades.beam_grow, growing out of the ship, is test_beam_grow's).
	saved["trades.beam_grow"] = Flags.is_on("trades.beam_grow")
	Flags.set_flag("trades.beam_grow", false)
	bus.reset_data()
	# The real yard: the ship in the bay is built from her file, frame and plates as parts.
	var yard: Node3D = load(Router.scene_path(ShipBayBus.SHIPYARD_SCENE)).instantiate()
	add_child(yard)
	await frames(30)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	if rig.designer == null:
		rig.build_designer()
	var d := rig.designer
	rig.set_tool(&"tablet")
	await physics_frames(3)

	# A frame node on her starboard side, high up, and the plates over it.
	var nodes := d.frame_nodes()
	check(nodes.size() > 20, "her frame nodes are known: %d" % nodes.size())
	var bb := ship_bus.ship.bounds
	var top_x := -INF
	for n: Vector3 in nodes:
		top_x = maxf(top_x, n.x)
	var node := Vector3.INF
	for n: Vector3 in nodes:
		if n.x > top_x - 0.1 and absf(n.z - bb.get_center().z) < 3.0 and n.y > 0.5 \
				and (not node.is_finite() or absf(n.z - bb.get_center().z) < absf(node.z - bb.get_center().z)):
			node = n
	check(node.is_finite(), "a node on her starboard side: %s" % [node])
	var plates: Array[MountSlot] = []
	for s: MountSlot in ship_bus.get_slots():
		if s.slot_id.begins_with("plate_") and s.box.grow(0.3).has_point(node):
			plates.append(s)
	check(not plates.is_empty(), "plates cover it: %s" % [plates.map(func(s: MountSlot) -> String: return s.slot_id)])
	check(d.snap(node + Vector3(0.1, 0.1, 0.05))[1] == "node", "an end near it snaps to the node")

	# A wing stub out from the node: plated, so pink.
	var out := node + Vector3(2.5, 0, 0)
	var stub := d.add_beam(node, out)
	d.run_checks()
	check(d.plated_ends.any(func(e: Array) -> bool: return e[0] == stub and e[1] == 0), "on the plated frame its end is pink: %s" % [d.plated_ends])
	check(d.loose_ends.any(func(e: Array) -> bool: return e[0] == stub and e[1] == 1), "its far end is loose")
	var res := d.test()
	check(not bool(res.passed) and d.test_line().contains("under plating"), "TEST says strip the plating: %s" % d.test_line())

	# Strip the plates there: the end holds on the bare frame.
	for s in plates:
		for f in s.fasteners:
			ship_bus.note_joint_removed(f.joint_id)
	check(plates.all(func(s: MountSlot) -> bool: return ship_bus.get_slot_state(s.slot_id) == ShipBayBus.SlotState.EMPTY), "the plates are off")
	d.run_checks()
	check(not d.plated_ends.any(func(e: Array) -> bool: return e[0] == stub) and not d.loose_ends.any(func(e: Array) -> bool: return e[0] == stub and e[1] == 0),
			"on the bare frame it holds")
	check(not d.unattached.has(stub), "and it is on the ship")
	# A brace from the stub's end back to another bare node finishes it.
	var other := Vector3.INF
	for n: Vector3 in nodes:
		if n.distance_to(node) > 0.5 and absf(n.z - node.z) < 0.05 and absf(n.x - node.x) < 0.05 \
				and (not other.is_finite() or n.distance_to(node) < other.distance_to(node)):
			other = n
	if other.is_finite():
		for s in ship_bus.get_slots():
			if s.slot_id.begins_with("plate_") and s.box.grow(0.3).has_point(other):
				for f in s.fasteners:
					ship_bus.note_joint_removed(f.joint_id)
		d.add_beam(out, other)
		res = d.test()
		check(bool(res.passed), "a stub and a brace on the bare frame pass: %s" % d.test_line())
	else:
		check(false, "a second bare node near the first")

	# Off the ship: a frame standing on the ground isn't on her.
	var ground := (rig.ship_transform().affine_inverse() * Vector3.ZERO).y
	var x0 := bb.position.x - 2.5
	var leg := d.add_beam(Vector3(x0, ground, 0), Vector3(x0, bb.end.y + 1.0, 0))
	var top := d.add_beam(Vector3(x0, bb.end.y + 1.0, 0), Vector3(x0, bb.end.y + 1.0, 2))
	d.run_checks()
	check(d.loose_ends.any(func(e: Array) -> bool: return e[0] == leg and e[1] == 0), "the ground doesn't hold a leg")
	check(d.unattached.has(leg) and d.unattached.has(top), "beams that never reach her frame are not on the ship: %s" % [d.unattached])
	res = d.test()
	check(not bool(res.passed) and d.test_line().contains("not on the ship's frame"), "TEST fails them: %s" % d.test_line())
	check("\n".join(d.info_lines()).contains("Not on the ship"), "the panel says so")

	bus.reset_data()
	yard.queue_free()
	await frames(2)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
