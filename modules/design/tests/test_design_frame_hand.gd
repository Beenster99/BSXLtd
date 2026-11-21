extends ModuleTest
## The outside designer, stage 1 (plan 3.10; beenster, 21 Nov: "Can we add frames, plates and
## other external positioned items?"): frames added, moved and taken out by hand, single ring
## girders and stringers taken out, plates made metal, armour, glass or left off, the proposal
## still the starting point, WILL IT WORK warning of gaps, loose plates and long bays, the
## changes in the build (parts) and the price, and all of it from the console's 3D view.
##   tools/run_tests.sh design

const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")


func _plates(plan: Dictionary) -> Dictionary:
	var body := RigidBody3D.new()
	var kit := ShipKit.new(body)
	kit.model = PartModel.new(body, true)
	DesignFrame.build(plan, kit)
	var names := {}
	for p: PartData in kit.model.parts.values():
		names[p.part_name] = int(names.get(p.part_name, 0)) + 1
	body.free()
	return names


func run_tests() -> void:
	Flags.set_flag("design.outside", true)
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	var rec: DesignRecord = bus.library.create("Hand frame")
	bus.editor.do({"op": "add_room", "room": {"type": "cargo", "deck": 0, "x": -3, "z": -4, "w": 6, "d": 8}})
	var plan := bus.frame_plan()
	var st: Array = plan.stations
	var n := st.size()
	var codes := func() -> Array: return bus.problems().map(func(p): return str(p.code))
	check(n >= 4 and not codes.call().has("hull_gap"), "the proposal: %d frames, nothing flagged" % n)

	# A frame added in a bay, then taken out again; the end frames stay.
	var mid := (float(st[1].z) + float(st[2].z)) * 0.5
	bus.editor.do({"op": "set_frame", "key": DesignFrame.ring_key(mid), "value": {"add": true}})
	check((bus.frame_plan().stations as Array).size() == n + 1, "a frame added between frames 1 and 2")
	bus.editor.undo()
	bus.editor.do({"op": "set_frame", "key": DesignFrame.ring_key(float(st[0].z)), "value": {"remove": true}})
	check((bus.frame_plan().stations as Array).size() == n, "the end frame carries the end plate: it stays")
	bus.editor.undo()
	bus.editor.do({"op": "set_frame", "key": DesignFrame.ring_key(float(st[2].z)), "value": {"remove": true}})
	plan = bus.frame_plan()
	check((plan.stations as Array).size() == n - 1, "frame 2 taken out")
	check(codes.call().has("long_bay"), "and the bay it leaves is too long for a plate: %s" % [codes.call()])
	bus.editor.undo()

	# Plates: armour costs and weighs more, open is a gap, the build follows.
	var t0 := bus.totals()
	var mass0: float = t0.lines.filter(func(l): return str(l.kind) == "hull").reduce(func(a, l): return a + float(l.mass), 0.0)
	var built0 := _plates(bus.frame_plan())
	bus.editor.do({"op": "set_frame", "key": DesignFrame.panel_key(mid, DesignFrame.ROOF_EDGE), "value": {"kind": "armour"}})
	plan = bus.frame_plan()
	check(DesignFrame.panel_at(plan, 1, DesignFrame.ROOF_EDGE) == "armour", "a roof plate made armour")
	var t1 := bus.totals()
	var armour := t1.lines.filter(func(l): return str(l.id) == "armour")
	check(not armour.is_empty() and float(armour[0].mass) > 0.0, "an armour line on the parts list: %s" % [armour])
	var mass1: float = t1.lines.filter(func(l): return str(l.kind) == "hull").reduce(func(a, l): return a + float(l.mass), 0.0)
	check(mass1 > mass0, "she is heavier: %.0f kg to %.0f kg" % [mass0, mass1])
	var built1 := _plates(plan)
	check(int(built1.get("ArmourPlate", 0)) >= 1 and int(built1.get("HullPlate", 0)) < int(built0.get("HullPlate", 0)),
			"built as an armour plate: %s" % [built1])
	check(DesignFrame.build_list(plan).any(func(r): return str(r.name) == "Armour plates"), "the build list counts it")
	bus.editor.do({"op": "set_frame", "key": DesignFrame.panel_key(mid, DesignFrame.STARBOARD), "value": {"kind": "open"}})
	plan = bus.frame_plan()
	check(codes.call().has("hull_gap"), "a plate left off: a gap in the hull")
	var built2 := _plates(plan)
	var plates1 := int(built1.get("HullPlate", 0)) + int(built1.get("ArmourPlate", 0))
	var plates2 := int(built2.get("HullPlate", 0)) + int(built2.get("ArmourPlate", 0))
	check(plates2 < plates1, "and it is not built: %d plates to %d" % [plates1, plates2])
	bus.editor.undo()
	bus.editor.undo()

	# Members: both ring girders at a plate's ends out, and it has nothing to hold it.
	var e := DesignFrame.PORT
	var rings0 := int(DesignFrame.counts(bus.frame_plan()).rings)
	bus.editor.do({"op": "set_frame", "key": DesignFrame.member_key(float(st[1].z), e), "value": {"remove": true}})
	check(not codes.call().has("plate_unsupported"), "one ring girder out: the plate still holds")
	bus.editor.do({"op": "set_frame", "key": DesignFrame.member_key(float(st[2].z), e), "value": {"remove": true}})
	check(codes.call().has("plate_unsupported"), "both out: nothing holds it up")
	check(int(DesignFrame.counts(bus.frame_plan()).rings) == rings0 - 2, "two fewer ring girders counted")
	bus.editor.undo()
	bus.editor.undo()
	bus.editor.do({"op": "set_frame", "key": DesignFrame.stringer_key(mid, e), "value": {"remove": true}})
	bus.editor.do({"op": "set_frame", "key": DesignFrame.stringer_key(mid, e + 1), "value": {"remove": true}})
	check(codes.call().has("plate_unsupported"), "both stringers at its sides out: nothing holds it up either")
	bus.editor.undo()
	bus.editor.undo()
	check(bus.problems().filter(func(p): return str(p.code) in ["hull_gap", "plate_unsupported", "long_bay"]).is_empty(),
			"all undone: nothing flagged")

	# Saved and loaded.
	bus.editor.do({"op": "set_frame", "key": DesignFrame.panel_key(mid, DesignFrame.BELLY_EDGE), "value": {"kind": "armour"}})
	var back := DesignRecord.from_dict(rec.to_dict())
	check(DesignFrame.panel_at(DesignFrame.propose(back), 1, DesignFrame.BELLY_EDGE) == "armour", "the plates save with the design")
	bus.editor.undo()

	# From the console's 3D view: click a plate, make it armour, split it with a new frame.
	var room := Node3D.new()
	add_child(room)
	var cam := Camera3D.new()
	room.add_child(cam)
	cam.current = true
	var fu := Furnishing.new()
	room.add_child(fu)
	fu.setup(bus, Furnishing.stand_in_walls())
	fu.open_console()
	await frames(4)
	var con = fu.console
	var top := DesignOutside.pick(bus.frame_plan(), Vector3(0.3, 40, mid), Vector3.DOWN)
	var ship: Node3D = con.holo.ship_node()
	var at: Vector2 = con._holo_cam.unproject_position(ship.global_transform * (top.point as Vector3))
	var picked: String = con.holo_click(at)
	check(con.plan.selected_kind == "panel" and int(picked.get_slice(":", 1)) == DesignFrame.ROOF_EDGE,
			"a click on the hull picks the plate: %s" % picked)
	await frames(2)
	var arm := con.find_child("Panel_armour", true, false) as Button
	check(arm != null, "the plate's choices: metal, armour, glass, open")
	if arm:
		arm.pressed.emit()
		check(DesignFrame.panel_at(bus.frame_plan(), DesignFrame.bay_at(bus.frame_plan(), float(picked.get_slice(":", 0))), DesignFrame.ROOF_EDGE) == "armour",
				"ARMOUR makes it armour")
	await frames(2)
	var frames_before := (bus.frame_plan().stations as Array).size()
	var split := con.find_child("PanelSplit", true, false) as Button
	if split:
		split.pressed.emit()
	check((bus.frame_plan().stations as Array).size() == frames_before + 1, "SPLIT puts a frame across it")
	await frames(2)
	var mv := con.find_child("MoveFrameForeFwd", true, false) as Button
	if mv == null:
		mv = con.find_child("MoveFrameAftBack", true, false) as Button
	var zs_before: Array = (bus.frame_plan().stations as Array).map(func(s): return snappedf(float(s.z), 0.01))
	if mv:
		mv.pressed.emit()
	var zs_after: Array = (bus.frame_plan().stations as Array).map(func(s): return snappedf(float(s.z), 0.01))
	check(mv != null and zs_after.size() == zs_before.size() and zs_after != zs_before, "a frame moves: %s to %s" % [zs_before, zs_after])
	room.queue_free()
	await frames(2)
