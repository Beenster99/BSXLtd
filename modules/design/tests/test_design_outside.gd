extends ModuleTest
## The outside designer, stage 3 (plan 3.10; beenster, 21 Nov: "is it possible for us to design
## the external ship hull? Can we add frames, plates and other external positioned items?"):
## hull parts fitted anywhere on the skin (roof, belly, sides, nose, stern) picked in 3D, riding
## the hull when it changes, mirrored, with clearance checks, and placed by a click in the
## console's 3D view.
##   tools/run_tests.sh design

const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")


func run_tests() -> void:
	Flags.set_flag("design.outside", true)
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	var rec: DesignRecord = bus.library.create("Outside")
	bus.editor.do({"op": "add_room", "room": {"type": "cargo", "deck": 0, "x": -3, "z": -4, "w": 6, "d": 8}})
	bus.editor.do({"op": "add_room", "room": {"type": "quarters", "deck": 1, "x": -2, "z": -3, "w": 4, "d": 6}})
	var plan := bus.frame_plan()
	check(not plan.is_empty(), "the design has a proposed frame")

	# Picks from every side land on the matching face, the normal pointing out.
	var roof := DesignOutside.pick(plan, Vector3(0.3, 40, 0.5), Vector3.DOWN)
	check(int(roof.get("edge", -9)) == DesignFrame.ROOF_EDGE and (roof.normal as Vector3).y > 0.9, "from above: the roof %s" % [roof])
	var belly := DesignOutside.pick(plan, Vector3(0.3, -40, 0.5), Vector3.UP)
	check(int(belly.get("edge", -9)) == DesignFrame.BELLY_EDGE and (belly.normal as Vector3).y < -0.9, "from below: the belly")
	var stbd := DesignOutside.pick(plan, Vector3(40, 1.2, 0.5), Vector3.LEFT)
	check(int(stbd.get("edge", -9)) == DesignFrame.STARBOARD and (stbd.normal as Vector3).x > 0.9, "from starboard: its side")
	var nose := DesignOutside.pick(plan, Vector3(0.2, 1.2, -40), Vector3.BACK)
	check(int(nose.get("edge", -9)) == DesignOutside.NOSE and (nose.normal as Vector3).z < -0.9, "from ahead: the nose")
	check(DesignOutside.pick(plan, Vector3(40, 40, 0), Vector3.UP).is_empty(), "a ray that misses: nothing")

	# A part on the roof sits on the skin, facing out.
	var pt := bus.catalog.part("thruster_pack")
	var m := DesignOutside.anchor(roof, rec)
	m["type"] = "thruster_pack"
	bus.editor.do({"op": "add_mount", "mount": m})
	var mid: String = rec.mounts.keys()[0]
	var xf := DesignRules.mount_transform(rec, rec.mounts[mid], pt)
	var front := -(xf.basis.z.normalized())
	var centre := (DesignOutside.box_of(xf, pt)[0] as Transform3D).origin
	var roof_y := (roof.point as Vector3).y
	check(front.y > 0.9 and is_equal_approx(snappedf(centre.y - roof_y, 0.01), snappedf(pt.size.z * 0.5 + DesignOutside.GAP, 0.01)),
			"on the roof, its front up, its back on the plating: %.2f over %.2f" % [centre.y, roof_y])
	check(DesignRules.mount_transform(rec, rec.mounts[mid], pt, plan) == xf, "the same with the frame passed in")
	# An antenna stands on the roof, on its foot; told to, it lies by its back like a thruster.
	var ant := bus.catalog.part("antenna")
	var am := DesignOutside.anchor(roof, rec)
	am.type = "antenna"
	var axf := DesignRules.mount_transform(rec, am, ant, plan)
	check(axf.basis.y.y > 0.9 and absf(axf.origin.y - roof_y - DesignOutside.GAP) < 0.02, "an antenna stands up on the roof: %s" % [axf])
	am.stand = false
	check(DesignRules.mount_transform(rec, am, ant, plan).basis.z.y < -0.9, "laid flat, its face up")
	check(bus.problems().filter(func(p): return str(p.code).begins_with("mount") or str(p.code) == "off_hull").is_empty(),
			"one part on the roof: no problems: %s" % [bus.problems().map(func(p): return p.text)])

	# It rides the hull: the deck above grows taller and the part goes up with the roof.
	bus.editor.do({"op": "set_meta", "fields": {"deck_height": 3.5}})
	var lifted := (DesignOutside.box_of(DesignRules.mount_transform(rec, rec.mounts[mid], pt, bus.frame_plan()), pt)[0] as Transform3D).origin
	check(lifted.y > centre.y + 0.9, "taller decks: it rides up with the roof (%.2f to %.2f)" % [centre.y, lifted.y])
	bus.editor.undo()

	# Clearance: a second part on top of it clashes, one in its plume is warned about.
	var m2 := m.duplicate()
	m2.erase("id")
	bus.editor.do({"op": "add_mount", "mount": m2})
	var codes := bus.problems().map(func(p): return str(p.code))
	check("mount_clash" in codes, "two parts in one spot run into each other: %s" % [codes])
	bus.editor.undo()
	# Off the end of the hull: the anchor past the last frame.
	var m3 := m.duplicate()
	m3.erase("id")
	m3.z = 30.0
	bus.editor.do({"op": "add_mount", "mount": m3})
	codes = bus.problems().map(func(p): return str(p.code))
	check("off_hull" in codes, "past the stern frame: not on the hull")
	bus.editor.undo()
	# Hanging past the edge of the roof.
	var edge := DesignOutside.anchor(roof, rec)
	edge.type = "thruster_pack"
	edge.t = 0.0
	edge.z = float(roof.z) + 2.0
	bus.editor.do({"op": "add_mount", "mount": edge})
	codes = bus.problems().map(func(p): return str(p.code))
	check("mount_overhang" in codes, "at the very edge of the roof: it hangs over: %s" % [codes])
	bus.editor.undo()
	# A part over an outer door.
	bus.editor.do({"op": "add_door", "door": {"a": rec.rooms.keys()[0], "b": "", "deck": 0, "x": 3.0, "z": 0.0}})
	var door_hit := DesignOutside.pick(bus.frame_plan(), Vector3(40, 1.1, 0.0), Vector3.LEFT)
	var over := DesignOutside.anchor(door_hit, rec)
	over.type = "thruster_pack"
	bus.editor.do({"op": "add_mount", "mount": over})
	codes = bus.problems().map(func(p): return str(p.code))
	check("mount_over_door" in codes, "over the outer door: %s" % [codes])
	bus.editor.undo()
	bus.editor.undo()

	# Mirrored across: a part on the starboard side gets a twin on the port side.
	var side := DesignOutside.anchor(stbd, rec)
	side.type = "thruster_pack"
	side.z = 2.0
	var tw := DesignMirror.twin(rec, {"op": "add_mount", "mount": side}, DesignMirror.ACROSS)
	check(not tw.is_empty() and int(tw.mount.edge) == DesignFrame.PORT, "mirrored: onto the port side: %s" % [tw])
	if not tw.is_empty():
		var a := (DesignRules.mount_transform(rec, side, pt)).origin
		var b := (DesignRules.mount_transform(rec, tw.mount, pt)).origin
		check(is_equal_approx(snappedf(a.x, 0.02), snappedf(-b.x, 0.02)) and is_equal_approx(snappedf(a.y, 0.02), snappedf(b.y, 0.02)),
				"at the same height the other side: %s %s" % [a, b])

	# Saved and loaded with the design.
	var back := DesignRecord.from_dict(rec.to_dict())
	check(DesignOutside.on_skin(back.mounts[mid]) and int(back.mounts[mid].edge) == DesignFrame.ROOF_EDGE, "a part on the skin saves")

	# The console's 3D view: a hull part in hand, a click on the hologram fits it there.
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
	con.plan.set_tool("mount:thruster_pack")
	await frames(2)
	var ship: Node3D = con.holo.ship_node()
	check(ship != null, "the hologram has the ship")
	var target := ship.global_transform * Vector3(0.5, roof_y, 1.5)
	var at: Vector2 = con._holo_cam.unproject_position(target)
	var n := rec.mounts.size()
	var added: String = con.holo_click(at)
	check(rec.mounts.size() == n + 1 and added != "" and DesignOutside.on_skin(rec.mounts.get(added, {})),
			"a click in the 3D view fits it on the skin: %s" % [rec.mounts.get(added, {})])
	check(con.plan.selected_kind == "mount" and con.plan.selected_id == added, "and selects it")
	await frames(2)
	var turn := con.find_child("SkinTurn", true, false) as Button
	check(turn != null, "a part on the skin has TURN")
	if turn:
		turn.pressed.emit()
		check(is_equal_approx(float(rec.mounts[added].spin), PI * 0.5), "TURN gives it a quarter turn")
	con.plan.set_tool("select")
	await frames(3)
	ship = con.holo.ship_node()
	at = con._holo_cam.unproject_position(ship.global_transform * DesignOutside.box_of(
			DesignRules.mount_transform(rec, rec.mounts[added], pt), pt)[0].origin)
	check(con.holo_pick_mount(at) != "", "with nothing in hand a click picks a part on the hull")
	room.queue_free()
	await frames(2)
