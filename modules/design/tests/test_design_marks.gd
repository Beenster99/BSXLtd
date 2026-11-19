extends ModuleTest
## Design Room, Wave 3 (plan 3.2 to 3.4): a pick on one drawing is the pick on every drawing and
## lights the room on the holotable; a section line thrown from a drawing cuts the hologram; the
## table's view goes up on the wall you face; the tape measure keeps a running total; notes pin
## to the ship and save with it; "look here" pulls the drawings to a spot; the title block and
## dimensions draw.
##   tools/run_tests.sh design

const PlanView := preload("res://modules/design/internal/views/plan_view.gd")
const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")
const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")


func run_tests() -> void:
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	var rec := bus.library.create("Marks")
	bus.editor.do({"op": "add_room", "room": {"type": "bridge", "deck": 0, "x": 0, "z": 0, "w": 4, "d": 4}})
	bus.editor.do({"op": "add_room", "room": {"type": "cargo", "deck": 0, "x": 0, "z": 4, "w": 6, "d": 8}})
	var layer := CanvasLayer.new()
	add_child(layer)
	var console := PlanView.new()
	console.setup(bus, PlanView.PLAN, true)
	console.size = Vector2(1200, 800)
	layer.add_child(console)
	var wall := PlanView.new()
	wall.setup(bus, PlanView.PLAN, false)
	wall.size = Vector2(1200, 800)
	layer.add_child(wall)
	var holo := HoloTable.new()
	add_child(holo)
	holo.setup(bus)
	await frames(3)
	console.frame_all()
	wall.frame_all()

	# 3.3: one pick everywhere.
	wall._press(wall.to_screen(Vector2(2, 2)))
	check(wall.selected_id == "r1" and console.selected_id == "r1", "a room touched on a wall is picked on the console too")
	check(holo.lit_rooms.has("r1"), "and lit on the holotable")
	console.select("room", "r2")
	check(wall.selected_id == "r2" and holo.lit_rooms.has("r2") and not holo.lit_rooms.has("r1"), "and the other way round")

	# 3.3: a section line from a drawing cuts the hologram.
	wall.marks.press_action("section")
	wall.marks.press(wall.to_screen(Vector2(3, 6)))
	check(str(bus.section.get("axis", "")) == "z" and is_equal_approx(float(bus.section.at), 6.0),
			"SECTION and a click throws a section line across the ship: %s" % [bus.section])
	await frames(2)
	check(not holo._section.is_equal_approx(HoloTable.NO_SECTION), "the hologram is cut there: %s" % holo._section)
	wall.marks.press_action("section")
	check(bus.section.is_empty(), "SECTION again takes it off")
	await frames(2)
	check(holo._section.is_equal_approx(HoloTable.NO_SECTION), "and the hologram is whole again")

	# 3.4: the tape.
	console.marks.press_action("measure")
	for p: Vector2 in [Vector2(0, 0), Vector2(3, 0), Vector2(3, 4)]:
		console.marks.press(console.to_screen(p))
	check(is_equal_approx(console.marks.tape_total(), 7.0), "the tape's running total: %.2f m" % console.marks.tape_total())
	check(console.cancel() and console.marks.tape.is_empty(), "Esc clears the tape")

	# 3.4: notes pinned to the ship.
	console.marks.press_action("note")
	console.marks.press(console.to_screen(Vector2(1, 1)))
	check(console.find_child("NoteEdit", true, false) != null, "NOTE and a click opens a note box")
	console.marks.add_note("Check the headroom here")
	check(rec.pins.size() == 1 and str(rec.pins.values()[0].text) == "Check the headroom here", "the note is pinned")
	var back := DesignRecord.from_dict(JSON.parse_string(JSON.stringify(rec.to_dict())))
	check(back.pins.size() == 1, "pinned notes save with the design")
	console.marks.press_action("note")
	console.marks.press(console.to_screen(Vector2(1, 1)))
	check(rec.pins.is_empty(), "NOTE and a click on a note takes it off")
	bus.editor.undo()
	check(rec.pins.size() == 1, "undo puts it back")

	# 3.4: look here.
	wall.centre = Vector2(50, 50)
	console.marks.press_action("look")
	console.marks.press(console.to_screen(Vector2(2, 9)))
	check(wall.centre.is_equal_approx(Vector2(2, 9)) and not wall.marks.look.is_empty(), "LOOK HERE pulls every drawing to the spot")

	# 3.4: the room readout, 3.2: dimensions and the title block draw.
	wall.marks.moved(wall.to_screen(Vector2(3, 8)))
	check(wall.marks.hover == "r2", "the pointer over a room reads it out")
	wall.queue_redraw()
	await frames(2)
	check(wall.marks.bar != null and wall.marks.bar.visible, "the marks bar shows on a plan")
	layer.queue_free()

	# 3.3: the table's view put up on the wall you face.
	var f := Furnishing.new()
	add_child(f)
	f.setup(bus, Furnishing.stand_in_walls())
	await frames(3)
	var cam := Camera3D.new()
	f.holo.add_child(cam)
	cam.position = Vector3(0, 1.7, 3.0)
	cam.look_at(cam.global_position + Vector3(-1, 0, 0))
	cam.make_current()
	await frames(1)
	f.holo.set_cut(0.5)
	var sent: Array = f.send_view_to_wall()
	check(sent.size() == 2 and str(sent[1]) == "plan:0", "J at the table puts the cut-down hologram up as a plan: %s" % [sent])
	if sent.size() == 2:
		var board = f.boards[sent[0]]
		check(board.panels.any(func(p): return str(p.view) == "plan:0"), "on the wall faced")
	f.queue_free()
	holo.queue_free()
