extends ModuleTest
## Design Room: the hull as its own shape. A deck's outline is drawn (and undone), rooms must
## sit inside it, its sides are the outer hull and the deck is plated out to them, inner walls
## and beams are placed anywhere, and all of it saves with the design.
##   tools/run_tests.sh design

const WalkBuild := preload("res://modules/design/internal/walk/walk_build.gd")
const PlanView := preload("res://modules/design/internal/views/plan_view.gd")


func run_tests() -> void:
	var bus := Modules.bus("design") as DesignBus
	var cat := bus.catalog
	var d := DesignRecord.new("h", "Hull")
	var bridge := str(d.apply({"op": "add_room", "room": {"type": "bridge", "deck": 0, "x": 0, "z": 0, "w": 4, "d": 4}}).id)
	d.apply({"op": "add_room", "room": {"type": "cargo", "deck": 0, "x": 4, "z": 0, "w": 4, "d": 4}})
	var plain := DesignStructure.measure(d)
	check(is_equal_approx(plain.outer_len, 24.0) and is_equal_approx(plain.inner_len, 4.0),
			"with no hull drawn the rooms are hulled round: %.1f outer, %.1f inner" % [plain.outer_len, plain.inner_len])

	# Ops: a hull needs three points, undo puts the old one back.
	check(d.apply({"op": "set_hull", "deck": 0, "points": [[0, 0], [1, 1]]}).is_empty(), "a hull needs three points")
	var start := d.hull_round_rooms(0, 1.0)
	check(start.size() >= 4, "a starting hull round the rooms: %s" % [start])
	var hex := [[-1, -1], [9, -1], [11, 2], [9, 5], [-1, 5], [-2, 2]]
	var u := d.apply({"op": "set_hull", "deck": 0, "points": hex})
	check(d.hull_outline(0).size() == 6 and (u.points as Array).is_empty(), "set_hull draws the outline")
	check(DesignRules.check(d, cat).filter(func(p): return p.code == "outside_hull").is_empty(), "both rooms sit inside")

	# The hull is the outer wall now; room sides inside it are inner walls.
	var s := DesignStructure.measure(d)
	var perim := 0.0
	var o := d.hull_outline(0)
	for i in o.size():
		perim += o[i].distance_to(o[(i + 1) % o.size()])
	check(is_equal_approx(s.outer_len, perim), "the outer hull is the outline: %.2f m" % s.outer_len)
	check(is_equal_approx(s.inner_len, 4.0 + 24.0), "every room side becomes an inner wall: %.1f m" % s.inner_len)
	check(s.floor_area > 40.0 + 1.0, "the deck is plated out to the hull: %.1f m2" % s.floor_area)
	check(DesignStructure.on_deck(d, 0, Vector2(10, 2)) and not DesignStructure.on_deck(d, 0, Vector2(12, 2)),
			"inside the hull is deck, outside is space")

	# A room pushed through the hull.
	d.apply({"op": "set_room", "id": bridge, "fields": {"x": -3.0}})
	var out := DesignRules.check(d, cat).filter(func(p): return p.code == "outside_hull")
	check(out.size() == 1 and bridge in out[0].rooms and out[0].severity == DesignRules.ERROR,
			"a room through the hull is an error: %s" % [out])
	d.apply({"op": "set_room", "id": bridge, "fields": {"x": 0.0}})

	# Inner walls and beams anywhere.
	check(d.apply({"op": "add_wall", "wall": {"deck": 0, "a": [1, 1], "b": [1, 1.05]}}).is_empty(), "a wall needs length")
	var wu := d.apply({"op": "add_wall", "wall": {"deck": 0, "a": [8, -1], "b": [8, 5]}})
	var wid := str(wu.id)
	check(d.walls.has(wid) and wid.begins_with("i") and str(wu.op) == "remove_wall", "a wall drawn across the deck")
	var bu := d.apply({"op": "add_beam", "beam": {"deck": 0, "a": [0, 2], "b": [8, 2]}})
	check(d.beams.has(str(bu.id)) and str(bu.id).begins_with("b"), "a beam placed under the deckhead")
	var s2 := DesignStructure.measure(d)
	check(is_equal_approx(s2.inner_len, s.inner_len + 6.0) and is_equal_approx(s2.frame_m, s.frame_m + 8.0),
			"walls and beams count in the structure: %.1f m walls, %.1f m frame" % [s2.inner_len, s2.frame_m])

	# Saves with the design, and undo clears it.
	var back := DesignRecord.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	check(JSON.stringify(back.to_dict()) == JSON.stringify(d.to_dict()) and back.hull_outline(0).size() == 6
			and back.walls.size() == 1 and back.beams.size() == 1, "hull, walls and beams save with the design")
	var next := back.apply({"op": "add_wall", "wall": {"deck": 0, "a": [2, 0], "b": [2, 4]}})
	check(str(next.id) != wid, "loaded ids carry on")
	d.apply(bu)
	d.apply(wu)
	d.apply(u)
	check(d.hull.is_empty() and d.walls.is_empty() and d.beams.is_empty(), "undo takes them all away again")
	await _plan_tools(bus)
	await _walk_inside(bus)


## The console's plan: draw a hull corner by corner, drag a corner, draw a wall and a beam.
func _plan_tools(bus: DesignBus) -> void:
	bus.library.reset_data()
	var rec := bus.library.create("Hull tools")
	bus.editor.do({"op": "add_room", "room": {"type": "bridge", "deck": 0, "x": 0, "z": 0, "w": 4, "d": 4}})
	var layer := CanvasLayer.new()
	add_child(layer)
	var plan := PlanView.new()
	plan.setup(bus, PlanView.PLAN, true)
	plan.size = Vector2(1200, 800)
	layer.add_child(plan)
	await frames(2)
	plan.frame_all()
	plan.set_tool("hull")
	for p: Vector2 in [Vector2(-2, -2), Vector2(6, -2), Vector2(8, 2), Vector2(6, 6), Vector2(-2, 6)]:
		plan._press(plan.to_screen(p))
	check(rec.hull.is_empty(), "the hull waits until it is closed")
	plan._press(plan.to_screen(Vector2(-2, -2)))
	check(rec.hull_outline(0).size() == 5 and plan.tool == "select", "clicking the first corner again closes the hull")
	bus.editor.undo()
	check(rec.hull.is_empty(), "and undo takes it away")
	bus.editor.redo()
	# Drag the point of the bow out.
	var hit := plan.pick(plan.to_screen(Vector2(8, 2)))
	check(str(hit.get("kind", "")) == "hull" and str(hit.id) == "2", "a hull corner can be picked: %s" % [hit])
	plan._press(plan.to_screen(Vector2(8, 2)))
	plan._drag_move(plan.to_screen(Vector2(10, 2)))
	plan._release(plan.to_screen(Vector2(10, 2)))
	check(rec.hull_outline(0)[2].distance_to(Vector2(10, 2)) < 0.01, "dragging a corner reshapes the hull")
	# A wall and a beam, each dragged from end to end.
	for t: String in ["wall", "beam"]:
		plan.set_tool(t)
		plan._press(plan.to_screen(Vector2(5, -2)))
		plan._drag_move(plan.to_screen(Vector2(5, 6)))
		plan._release(plan.to_screen(Vector2(5, 6)))
	check(rec.walls.size() == 1 and rec.beams.size() == 1 and plan.selected_kind == "beam", "a wall and a beam drawn")
	plan.delete_selected()
	check(rec.beams.is_empty(), "a selected beam deletes")
	plan.select("hull", "2")
	plan.delete_selected()
	check(rec.hull_outline(0).size() == 4, "deleting a selected corner takes it out of the hull")
	layer.queue_free()
	await frames(1)


## Walk-inside builds the hull drawn: open deck plated out to angled hull sides, walls, beams.
func _walk_inside(bus: DesignBus) -> void:
	var rec := bus.library.current
	rec.apply({"op": "set_hull", "deck": 0, "points": [[-2, -2], [6, -2], [10, 2], [6, 6], [-2, 6]]})
	rec.apply({"op": "add_beam", "beam": {"deck": 0, "a": [-1, 2], "b": [9, 2]}})
	var holder := Node3D.new()
	add_child(holder)
	var b := WalkBuild.new(bus.catalog)
	b.build(rec, holder)
	var deck := holder.get_node_or_null("OpenDeck_0") as StaticBody3D
	check(deck != null and deck.get_child_count() >= 2, "the open deck inside the hull is plated and walkable")
	var angled := b.wall_pieces.filter(_is_angled)
	check(angled.size() == 2, "the bow's angled sides are hull walls: %d" % angled.size())
	var inner := b.wall_pieces.filter(func(p): return not bool(p.outer))
	check(inner.size() >= 5, "the room's sides and the drawn wall are inner walls: %d" % inner.size())
	check(holder.find_children("Girder*", "", true, false).size() > b.ribs, "the placed beam is a girder")
	check(holder.get_node_or_null("OpenDeckRoof_0") != null and b.lamps > 1, "the open deck is roofed and lit")
	# Something stands on it: a ray down onto open deck hits the floor.
	await frames(2)
	var space := holder.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(8, 1, 2), Vector3(8, -1, 2), WalkBuild.LAYER)
	var hit := space.intersect_ray(q)
	check(not hit.is_empty() and absf(float(hit.position.y)) < 0.02, "you can stand at the bow, outside the rooms: %s" % [hit])
	holder.queue_free()
	await frames(1)


func _is_angled(p: Dictionary) -> bool:
	var dir := ((p.b as Vector2) - (p.a as Vector2)).normalized()
	return bool(p.outer) and absf(dir.x) > 0.1 and absf(dir.y) > 0.1
