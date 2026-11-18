extends ModuleTest
## Design Room: the hull as its own shape. A deck's outline is drawn (and undone), rooms must
## sit inside it, its sides are the outer hull and the deck is plated out to them, inner walls
## and beams are placed anywhere, and all of it saves with the design.
##   tools/run_tests.sh design


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
