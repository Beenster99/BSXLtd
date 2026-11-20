extends ModuleTest
## Copy and paste in the designer, and smart guides (beenster, 20 Nov: "copy paste (Ctrl C and
## Ctrl V) would help for components ... smart alignment lines popped up when I am positioning
## something (like you get in powerpoint) - then the object can snap for alignment").
##   tools/run_tests.sh design

const PlanView := preload("res://modules/design/internal/views/plan_view.gd")


func run_tests() -> void:
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	var rec: DesignRecord = bus.library.create("Clip")
	var plan := PlanView.new()
	plan.size = Vector2(1000, 700)
	add_child(plan)
	plan.setup(bus, PlanView.PLAN, true)
	await frames(2)
	plan.set_deck(0)
	bus.editor.do({"op": "add_room", "room": {"type": "engineering", "deck": 0, "x": 0, "z": 0, "w": 8, "d": 6}})
	var room_id: String = rec.rooms.keys()[0]
	bus.editor.do({"op": "add_component", "component": {"type": "battery_bank", "room": room_id, "x": 2, "z": 2, "rot": 0}})
	var part_id: String = rec.components.keys()[0]

	# A part: Ctrl+C, then Ctrl+V at the pointer.
	plan.select("part", part_id)
	check(plan.copy_selected(), "Ctrl+C takes the selected part")
	var pasted := plan.paste(Vector2(5, 4))
	check(pasted != "" and rec.components.has(pasted) and pasted != part_id, "Ctrl+V adds a copy: %s" % pasted)
	if rec.components.has(pasted):
		var c: Dictionary = rec.components[pasted]
		check(str(c.type) == "battery_bank" and str(c.room) == room_id and is_equal_approx(float(c.x), 5.0),
				"the same part, in the room under the pointer: %s" % [c])
		check(plan.selected_kind == "part" and plan.selected_id == pasted, "and the copy is selected")
	check(plan.paste(Vector2(200, 200)) == "", "pasting a part where there is no room does nothing")
	var n := rec.components.size()
	bus.editor.undo()
	check(rec.components.size() == n - 1, "a paste is one undo step")

	# Ctrl+D duplicates without touching what was copied.
	var kept := PlanView.clipboard.duplicate(true)
	plan.select("part", part_id)
	var ctrl_d := InputEventKey.new()
	ctrl_d.keycode = KEY_D
	ctrl_d.ctrl_pressed = true
	ctrl_d.pressed = true
	var before := rec.components.size()
	plan._gui_input(ctrl_d)
	check(rec.components.size() == before + 1, "Ctrl+D duplicates the selected part beside it")
	check(PlanView.clipboard == kept, "and leaves the clipboard as it was")

	# A room comes with what is in it.
	plan.select("room", room_id)
	check(plan.copy_selected(), "Ctrl+C takes a room")
	var inside := rec.components.values().filter(func(c): return str(c.room) == room_id).size()
	var new_room := plan.paste(Vector2(20, 3))
	check(new_room != "" and rec.rooms.has(new_room), "Ctrl+V adds a copy of the room")
	if rec.rooms.has(new_room):
		var r: Dictionary = rec.rooms[new_room]
		check(str(r.type) == "engineering" and is_equal_approx(float(r.w), 8.0) and int(r.deck) == 0,
				"same type and size, on this deck: %s" % [r])
		var moved := rec.components.values().filter(func(c): return str(c.room) == new_room)
		check(moved.size() == inside, "with its %d parts: %d" % [inside, moved.size()])
		var rr := rec.room_rect(new_room)
		check(moved.all(func(c): return rr.has_point(Vector2(float(c.x), float(c.z)))), "inside it")

	# Smart guides: a box near another's edge or middle snaps to it and draws the line.
	var other := rec.room_rect(room_id)
	plan.zoom = 40.0  # 8 px = 0.2 m
	var near := Rect2(other.position + Vector2(0.15, 10.0), Vector2(4, 4))
	var al := plan.align(near, "room", "nothing")
	check(is_equal_approx(float(al.offset.x), -0.15), "a left edge 0.15 m off another's snaps to it: %s" % [al.offset])
	check(not (al.guides as Array).is_empty(), "and a guide line shows it")
	var g: Array = al.guides[0]
	check(is_equal_approx(g[0].x, other.position.x) and is_equal_approx(g[1].x, other.position.x), "the line runs down that edge")
	var mid := Rect2(Vector2(other.get_center().x - 2.0 + 0.1, 30.0), Vector2(4, 4))
	check(is_equal_approx(float(plan.align(mid, "room", "nothing").offset.x), -0.1), "middles line up too")
	var far := Rect2(Vector2(-30.0, 40.0), Vector2(1, 1))
	al = plan.align(far, "room", "nothing")
	check(al.offset == Vector2.ZERO and (al.guides as Array).is_empty(), "nothing near: no snap, no line")
	plan.queue_free()
	await frames(2)
