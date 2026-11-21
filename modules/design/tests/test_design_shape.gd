extends ModuleTest
## The outside designer, stage 2 (plan 3.10; beenster, 21 Nov: "is it possible for us to design
## the external ship hull?"): free shapes. A nose and a tapered stern drawn out of the hull,
## wings, fins, pods on struts and fairings, each built as frames and plates bolted to her
## rings; on the parts list, the build list and the berth's measure; WILL IT WORK on clashes
## and doors; and all of it from the console.
##   tools/run_tests.sh design

const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")


## What the plan builds: part names counted, and the joints that fasten a shape to the hull.
func _built(plan: Dictionary) -> Dictionary:
	var body := RigidBody3D.new()
	var kit := ShipKit.new(body)
	kit.model = PartModel.new(body, true)
	DesignFrame.build(plan, kit)
	var names := {}
	var shape_parts := 0
	for p: PartData in kit.model.parts.values():
		names[p.part_name] = int(names.get(p.part_name, 0)) + 1
		if p.path.begins_with("shape_"):
			shape_parts += 1
	var bolted := 0
	for c: ConnectionData in kit.model.connections:
		var a := kit.model.parts.get(c.part_a) as PartData
		var b := kit.model.parts.get(c.part_b) as PartData
		if a and b and (a.path.begins_with("shape_") != b.path.begins_with("shape_")):
			bolted += 1
	body.free()
	return {"names": names, "shape_parts": shape_parts, "bolted": bolted}


func run_tests() -> void:
	Flags.set_flag("design.outside", true)
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	var rec: DesignRecord = bus.library.create("Shapes")
	bus.editor.do({"op": "add_room", "room": {"type": "cargo", "deck": 0, "x": -3, "z": -4, "w": 6, "d": 8}})
	bus.editor.do({"op": "add_room", "room": {"type": "quarters", "deck": 1, "x": -2, "z": -3, "w": 4, "d": 6}})
	var codes := func() -> Array: return bus.problems().map(func(p): return str(p.code))
	var plan := bus.frame_plan()
	var n0 := (plan.stations as Array).size()
	var front0 := float(plan.stations[0].z)
	var len0 := float(DesignBerth.size_of(rec).length)
	var skin0 := float(DesignFrame.counts(plan).skin_m2)

	# A nose: frames ahead of the bow, rounded down to a small tip.
	bus.editor.do({"op": "add_shape", "shape": DesignShape.make("nose")})
	plan = bus.frame_plan()
	var st: Array = plan.stations
	check(st.size() > n0 and float(st[0].z) < front0 - 3.0, "a nose: frames drawn out ahead (%d to %d, bow %.1f to %.1f)" % [n0, st.size(), front0, float(st[0].z)])
	var tip: Rect2 = st[0].rect
	var body: Rect2 = st[int(plan.body[0])].rect
	check(tip.size.x < body.size.x * 0.6 and tip.size.y < body.size.y * 0.6, "narrowing to a tip: %s from %s" % [tip.size, body.size])
	check(float(DesignBerth.size_of(rec).length) > len0 + 3.0, "she is longer in the berth: %.1f to %.1f m" % [len0, float(DesignBerth.size_of(rec).length)])
	check(float(DesignFrame.counts(plan).skin_m2) > skin0, "more skin on the parts list")
	var labels := st.map(func(s): return str(s.label))
	check(labels[0] == "f0" and labels[labels.size() - 1] == "f%d" % (st.size() - 1), "the frames numbered from the new bow: %s" % [labels])
	var nose_id: String = rec.shapes.keys()[0]
	bus.editor.do({"op": "add_shape", "shape": DesignShape.make("nose")})
	check(rec.shapes.size() == 1, "one nose: a second is not added")
	bus.editor.do({"op": "set_shape", "id": nose_id, "fields": {"drop": 1.0}})
	plan = bus.frame_plan()
	check((plan.stations[0].rect as Rect2).get_center().y > body.get_center().y + 0.5, "TIP HEIGHT raises the tip toward the roof")
	# A tapered stern too.
	bus.editor.do({"op": "add_shape", "shape": DesignShape.make("stern")})
	plan = bus.frame_plan()
	var last: Rect2 = plan.stations[(plan.stations as Array).size() - 1].rect
	check(int(plan.body[1]) < (plan.stations as Array).size() - 1 and last.size.x < body.size.x, "a tapered stern")
	var b0 := _built(plan)
	check(int(b0.names.get("HullPlate", 0)) > 0 and int(b0.names.get("CapPlate", 0)) > 0, "built as hull plates and end plates: %s" % [b0.names])
	# A door through the bow: no nose there.
	bus.editor.do({"op": "add_door", "door": {"a": rec.rooms.keys()[0], "b": "", "deck": 0, "x": 0.0, "z": -4.0}})
	check(codes.call().has("shape_blocked") and float(bus.frame_plan().stations[0].z) > float(plan.stations[0].z) + 2.0,
			"a door through the bow end: the nose is not built: %s" % [codes.call()])
	bus.editor.undo()

	# Wings: a pair off the sides, framed in ribs and spars, bolted to her rings.
	var wing_op := {"op": "add_shape", "shape": DesignShape.make("wing", 0.0)}
	bus.editor.do(wing_op)
	var wing_id := ""
	for sid: String in rec.shapes:
		if str(rec.shapes[sid].type) == "wing":
			wing_id = sid
	plan = bus.frame_plan()
	var limbs: Array = plan.limbs
	check(limbs.size() == 2 and float(limbs[0].side) * float(limbs[1].side) < 0.0, "a pair of wings: %d" % limbs.size())
	var box_s := DesignShape.limb_box(limbs[0])
	var side_x := float(DesignShape.hull_at(plan, -1, 1).x)
	check(box_s.position.x >= side_x and box_s.end.x > side_x + 3.0, "out from the side: x %.1f to %.1f (side at %.1f)" % [box_s.position.x, box_s.end.x, side_x])
	var b1 := _built(plan)
	check(int(b1.names.get("Rib", 0)) > 0 and int(b1.shape_parts) > 10, "built as ribs, spars and plates: %s" % [b1.names])
	check(int(b1.bolted) >= 4, "bolted to her rings: %d bolts" % int(b1.bolted))
	check(DesignFrame.build_list(plan).any(func(r): return str(r.name).begins_with("Wings")), "on the build list")
	check(float(DesignBerth.size_of(rec).beam) > box_s.end.x * 2.0 - 0.1, "her beam in the berth takes the wings: %.1f m" % float(DesignBerth.size_of(rec).beam))
	bus.editor.do({"op": "set_shape", "id": wing_id, "fields": {"span": 6.0, "sweep": 3.0}})
	plan = bus.frame_plan()
	var box2 := DesignShape.limb_box(plan.limbs[0])
	check(box2.end.x > box_s.end.x + 1.5 and box2.end.z > box_s.end.z + 0.5, "SPAN and SWEEP: longer and swept back: %s to %s" % [box_s, box2])
	bus.editor.do({"op": "set_shape", "id": wing_id, "fields": {"mirror": false}})
	check((bus.frame_plan().limbs as Array).size() == 1, "one side only")
	bus.editor.undo()
	# Two wings in one place run into each other.
	bus.editor.do(wing_op)
	check(codes.call().has("shape_clash"), "two wings in one place: they clash: %s" % [codes.call()])
	bus.editor.undo()

	# A fin on the roof, pods on struts, a fairing on the side.
	var roof := float(DesignShape.hull_at(bus.frame_plan(), -4, 4).roof)
	bus.editor.do({"op": "add_shape", "shape": DesignShape.make("fin", 3.0)})
	var fin: Dictionary = (bus.frame_plan().limbs as Array).filter(func(l): return str(l.type) == "fin")[0]
	check(DesignShape.limb_box(fin).position.y >= roof and DesignShape.limb_box(fin).end.y > roof + 2.0, "a fin stands up off the roof")
	bus.editor.do({"op": "add_shape", "shape": DesignShape.make("pod", 2.0)})
	var pods: Array = (bus.frame_plan().limbs as Array).filter(func(l): return str(l.type) == "pod")
	check(pods.size() == 2, "a pair of pods")
	var b2 := _built(bus.frame_plan())
	check(int(b2.names.get("Pylon", 0)) == 4, "each on two struts: %s" % [b2.names])
	var sh := DesignShape.make("fairing", -1.0)
	sh.face = "side"
	bus.editor.do({"op": "add_shape", "shape": sh})
	var fair: Array = (bus.frame_plan().limbs as Array).filter(func(l): return str(l.type) == "fairing")
	check(fair.size() == 2 and DesignShape.limb_box(fair[0]).position.x < side_x + 0.2, "a fairing laid on both sides")
	check(int(DesignFrame.counts(bus.frame_plan()).limbs) == 7, "seven limbs counted: %d" % int(DesignFrame.counts(bus.frame_plan()).limbs))

	# Saved and loaded; undone.
	var back := DesignRecord.from_dict(rec.to_dict())
	check(back.shapes == rec.shapes and (DesignFrame.propose(back).limbs as Array).size() == 7, "the shapes save with the design")
	var before := rec.shapes.size()
	bus.editor.undo()
	check(rec.shapes.size() == before - 1, "undo takes the last one off")

	# The console: HULL SHAPE, ADD WINGS, a size stepped up, REMOVE.
	bus.library.reset_data()
	rec = bus.library.create("Shapes 2")
	bus.editor.do({"op": "add_room", "room": {"type": "cargo", "deck": 0, "x": -3, "z": -4, "w": 6, "d": 8}})
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
	con.plan.select("", "")
	await frames(2)
	check(con.find_child("ShapeRows", true, false) != null, "nothing picked: HULL SHAPE")
	var add := con.find_child("AddShape_wing", true, false) as Button
	if add:
		add.pressed.emit()
	await frames(2)
	check(rec.shapes.size() == 1 and con.plan.selected_kind == "shape", "ADD WINGS adds a pair and picks them")
	var sid: String = rec.shapes.keys()[0] if not rec.shapes.is_empty() else ""
	var plus := con.find_child("Shape_span_plus", true, false) as Button
	if plus:
		plus.pressed.emit()
	check(sid != "" and DesignShape.field(rec.shapes[sid], "span") > float(DesignShape.make("wing").span), "SPAN + makes them longer")
	await frames(2)
	var rm := con.find_child("ShapeRemove", true, false) as Button
	if rm:
		rm.pressed.emit()
	check(rec.shapes.is_empty(), "REMOVE takes them off")
	bus.editor.undo()
	await frames(2)
	check(con.holo.ship_node() != null, "the hologram still builds with a shape")
	room.queue_free()
	await frames(2)
