extends ModuleTest
## Design Room: non-rectangular rooms (beenster, 19 Nov). A selected room's side step handle puts
## a step in that side (a box becomes an L), its corners drag with square sides; the notch is
## not the room's floor for picks, overlaps, components or walls; undo puts the box back.
##   tools/run_tests.sh design

const PlanView := preload("res://modules/design/internal/views/plan_view.gd")
const RoomShape := preload("res://modules/design/internal/views/room_shape.gd")
const WalkBuild := preload("res://modules/design/internal/walk/walk_build.gd")


func run_tests() -> void:
	var bus := Modules.bus("design") as DesignBus
	_shapes()
	await _plan(bus)


## The shape maths on its own.
func _shapes() -> void:
	var box := PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)])
	var l := RoomShape.reshape(box, "room_step", 1, Vector2(-2, 0))
	var f := RoomShape.fields(l)
	check(f.get("outline") is Array and (f.outline as Array).size() == 6, "a step in a side makes an L: %s" % [f])
	check(RoomShape.fields(RoomShape.reshape(box, "room_vertex", 2, Vector2(1, 1))).get("outline") == null,
			"a box's corner dragged stays a box (stretched)")
	var slant := RoomShape.fields(RoomShape.reshape(box, "room_vertex", 2, Vector2(-1, 0), false))
	check(slant.get("outline") is Array and (slant.outline as Array).size() == 4, "a corner moved freely slants its sides: %s" % [slant])
	var bend := RoomShape.reshape(box, "room_step", 0, Vector2(0, -1), false)
	check(bend.size() == 5 and bend[1].is_equal_approx(Vector2(2, -1)), "a side's handle dragged freely puts a corner in it: %s" % [bend])
	check(RoomShape.fields(RoomShape.reshape(box, "room_vertex", 2, Vector2(-4, 0), false)).get("outline") is Array,
			"a corner dragged onto its neighbour is taken out: a three-cornered room")
	check(RoomShape.fields(PackedVector2Array([Vector2(0, 0), Vector2(4, 4), Vector2(4, 0), Vector2(0, 4)])).is_empty(),
			"a crossed outline isn't a room")


func _plan(bus: DesignBus) -> void:
	bus.library.reset_data()
	var rec := bus.library.create("Shapes")
	bus.editor.do({"op": "add_room", "room": {"type": "bridge", "deck": 0, "x": 0, "z": 0, "w": 4, "d": 4}})
	var rid := str(rec.rooms.keys()[0])
	var layer := CanvasLayer.new()
	add_child(layer)
	var plan := PlanView.new()
	plan.setup(bus, PlanView.PLAN, true)
	plan.size = Vector2(1200, 800)
	layer.add_child(plan)
	await frames(2)
	plan.frame_all()
	plan.set_tool("select")
	plan.select("room", rid)
	plan.keep_square = true  # Shift held

	# The right side's step handle, dragged in by 2 m: an L with its notch at x 2..4, z 2..4.
	var hit := plan.pick(plan.to_screen(Vector2(4, 2)))
	check(str(hit.get("kind", "")) == "room_step", "the selected room's side has a step handle: %s" % [hit])
	plan._press(plan.to_screen(Vector2(4, 2)))
	plan._drag_move(plan.to_screen(Vector2(2, 2)))
	plan._release(plan.to_screen(Vector2(2, 2)))
	var r: Dictionary = rec.rooms[rid]
	check(DesignRecord.is_shaped(r) and is_equal_approx(DesignRecord.room_area(r), 12.0),
			"the room is an L of 12 m2: %s" % [r.get("outline")])
	check(rec.room_at(0, Vector2(3, 3)) == "" and rec.room_at(0, Vector2(3, 1)) == rid,
			"the notch is not the room's floor")
	check(plan.pick(plan.to_screen(Vector2(3.5, 3.5))).get("kind", "") != "room", "a click in the notch goes through")

	# Its walls go round the L, none across its own inside corner.
	var s := DesignStructure.measure(rec)
	check(is_equal_approx(s.outer_len, 16.0) and is_equal_approx(s.inner_len, 0.0),
			"its walls follow the outline: %.1f outer, %.1f inner" % [s.outer_len, s.inner_len])
	check(is_equal_approx(s.floor_area, 12.0), "its floor is the L's: %.1f m2" % s.floor_area)

	# A room fits in the notch; a component in the notch sticks out.
	bus.editor.do({"op": "add_room", "room": {"type": "cargo", "deck": 0, "x": 2, "z": 2, "w": 2, "d": 2}})
	var cat := bus.catalog
	check(DesignRules.check(rec, cat).filter(func(p): return p.code == "overlap").is_empty(), "a room fits in the notch")
	var cargo := rec.room_at(0, Vector2(3, 3))
	check(cargo != "" and cargo != rid, "the notch is the new room's")
	check(not rec.shared_wall(rid, cargo).is_empty(), "the L and the room in its notch share a wall")
	var walk := WalkBuild.new(bus.catalog)
	var holder := Node3D.new()
	add_child(holder)
	walk.build(rec, holder)
	check(holder.get_child_count() > 0, "walk-inside builds the L")
	holder.queue_free()
	bus.editor.undo()
	bus.editor.do({"op": "add_component", "component": {"type": "pilot_console", "room": rid, "x": 3.3, "z": 3.3, "rot": 0}})
	var out := DesignRules.check(rec, cat).filter(func(p): return p.code == "outside_room")
	check(out.size() == 1, "a component in the notch sticks out of the room: %s" % [out])
	bus.editor.undo()

	# The inside corner dragged: its two sides move with it and stay square.
	plan.select("room", rid)
	var poly := DesignRecord.room_poly(rec.rooms[rid])
	var inner := -1
	for i in poly.size():
		if poly[i].is_equal_approx(Vector2(2, 2)):
			inner = i
	check(inner >= 0, "the L has its inside corner at (2, 2)")
	plan._press(plan.to_screen(Vector2(2, 2)))
	plan._drag_move(plan.to_screen(Vector2(3, 3)))
	plan._release(plan.to_screen(Vector2(3, 3)))
	r = rec.rooms[rid]
	check(is_equal_approx(DesignRecord.room_area(r), 15.0) and rec.room_at(0, Vector2(2.5, 2.5)) == rid,
			"the inside corner moved, the notch smaller: %.1f m2" % DesignRecord.room_area(r))
	var square := true
	poly = DesignRecord.room_poly(r)
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		square = square and (absf(a.x - b.x) < 0.01 or absf(a.y - b.y) < 0.01)
	check(square, "every side still runs along x or z")

	# Saves, mirrors, and undo puts the box back.
	var back := DesignRecord.from_dict(JSON.parse_string(JSON.stringify(rec.to_dict())))
	check(DesignRecord.is_shaped(back.rooms[rid]), "the outline saves with the design")
	var tw := DesignMirror.twin(rec, {"op": "add_room", "room": rec.rooms[rid]}, DesignMirror.ACROSS)
	check(not tw.is_empty() and is_equal_approx(DesignRecord.room_area(tw.room), 15.0), "the mirror's twin is the same shape")
	bus.editor.undo()
	bus.editor.undo()
	check(not DesignRecord.is_shaped(rec.rooms[rid]) and is_equal_approx(DesignRecord.room_area(rec.rooms[rid]), 16.0),
			"undo puts the box back")

	# Any angle (no Shift): the box's far corner dragged in makes a slanted side.
	plan.keep_square = false
	plan.select("room", rid)
	plan._press(plan.to_screen(Vector2(4, 4)))
	plan._drag_move(plan.to_screen(Vector2(2, 4)))
	plan._release(plan.to_screen(Vector2(2, 4)))
	r = rec.rooms[rid]
	check(DesignRecord.is_shaped(r) and not DesignRecord.is_square(r) and is_equal_approx(DesignRecord.room_area(r), 12.0),
			"a corner dragged freely: a slanted side, 12 m2: %s" % [r.get("outline")])
	check(rec.room_at(0, Vector2(3.8, 3.5)) == "" and rec.room_at(0, Vector2(3.5, 1)) == rid, "the cut-off corner is off its floor")
	s = DesignStructure.measure(rec)
	check(is_equal_approx(s.outer_len, 4 + 4 + 2 + sqrt(4.0 + 16.0)), "its walls follow the slant: %.2f m" % s.outer_len)
	# A room against the slant shares that wall.
	bus.editor.do({"op": "add_room", "room": {"type": "cargo", "deck": 0, "x": 2, "z": 0, "w": 4, "d": 4,
			"outline": [[2, 0], [4, 0], [4, 4], [0, 4]]}})
	var wedge := rec.room_at(0, Vector2(3.8, 3.5))
	check(wedge != "" and wedge != rid, "a wedge room fills the cut-off corner")
	check(DesignRules.check(rec, cat).filter(func(p): return p.code == "overlap").is_empty(), "the wedge doesn't overlap")
	var wall := rec.shared_wall(rid, wedge)
	check(wall.size() == 2 and is_equal_approx(wall[0].distance_to(wall[1]), sqrt(20.0)), "they share the slanted wall: %s" % [wall])
	var s3 := DesignStructure.measure(rec)
	check(is_equal_approx(s3.inner_len, sqrt(20.0)), "the shared slant is one inner wall: %.2f" % s3.inner_len)
	var holder2 := Node3D.new()
	add_child(holder2)
	walk.build(rec, holder2)
	check(holder2.find_child("Floor_" + rid, true, false) != null, "walk-inside builds the slanted room's floor to its outline")
	holder2.queue_free()
	layer.queue_free()
