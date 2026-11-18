extends ModuleTest
## Design Room: the whiteboard. Pens, highlighter, lines, boxes and the eraser draw on the
## design's whiteboard layers through the editor (undo works), layers are added, hidden,
## reordered and deleted with their strokes, the plan can show underneath, it saves with the
## design, and a design wall can show it.
##   tools/run_tests.sh design

const Whiteboard := preload("res://modules/design/internal/views/whiteboard.gd")
const WallBoard := preload("res://modules/design/internal/room/wall_board.gd")


func run_tests() -> void:
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	var rec := bus.library.create("Sketches")
	_record_ops(rec)

	var layer := CanvasLayer.new()
	add_child(layer)
	var wb := Whiteboard.new()
	wb.setup(bus, 18)
	wb.size = Vector2(1600, 1000)
	layer.add_child(wb)
	await frames(3)
	var r := wb.board_rect()
	check(r.size.x > 100 and is_equal_approx(r.size.x / r.size.y, Whiteboard.BOARD.x / Whiteboard.BOARD.y),
			"the board fits the panel at its own shape: %s" % r)
	check(wb.to_board(wb.to_canvas(Vector2(400, 300))).distance_to(Vector2(400, 300)) < 0.01, "canvas and board points map both ways")

	# A wiggly pen stroke with the mouse: the first one makes Layer 1.
	rec.sketch_layers.clear()
	rec.strokes.clear()
	_drag(wb, [Vector2(100, 100), Vector2(150, 160), Vector2(220, 120), Vector2(300, 200)])
	check(rec.sketch_layers.size() == 1 and rec.strokes.size() == 1, "drawing makes Layer 1 and a stroke: %d %d"
			% [rec.sketch_layers.size(), rec.strokes.size()])
	var first: Dictionary = rec.strokes.values()[0]
	check(str(first.tool) == "pen" and (first.points as Array).size() == 4 and str(first.layer) == wb.active_layer,
			"the stroke keeps its shape, on the active layer: %s" % [first.points])
	# A nearly straight pen stroke snaps straight.
	var id := _drag(wb, [Vector2(100, 400), Vector2(250, 403), Vector2(400, 398), Vector2(600, 401)])
	check((rec.strokes[id].points as Array).size() == 2, "a nearly straight stroke snaps to a line")
	# A box in orange, thick.
	wb.set_tool("box")
	wb.set_colour("ff9a4d")
	wb.width = Whiteboard.WIDTHS[1]
	var box := _drag(wb, [Vector2(700, 100), Vector2(800, 200), Vector2(900, 300)])
	check(str(rec.strokes[box].tool) == "box" and (rec.strokes[box].points as Array).size() == 2
			and str(rec.strokes[box].colour) == "ff9a4d", "a box from its two corners, in the chosen colour")
	check(Whiteboard.stroke_points(rec.strokes[box]).size() == 5, "drawn as its outline")
	# The highlighter is wide.
	wb.set_tool("marker")
	var hi := _drag(wb, [Vector2(100, 600), Vector2(300, 650), Vector2(500, 600)])
	check(float(rec.strokes[hi].width) > float(rec.strokes[box].width), "the highlighter is wide")
	# A second layer: new strokes go there; hide it, then the eraser leaves it alone.
	var l2 := wb.add_layer()
	check(wb.active_layer == l2 and rec.sketch_layers.size() == 2, "+ LAYER adds a layer on top and draws on it")
	wb.set_tool("pen")
	var on_l2 := _drag(wb, [Vector2(1000, 500), Vector2(1100, 560), Vector2(1200, 520)])
	check(str(rec.strokes[on_l2].layer) == l2, "the stroke is on the new layer")
	bus.editor.do({"op": "set_layer", "id": l2, "fields": {"visible": false}})
	wb.set_tool("erase")
	_drag(wb, [Vector2(1000, 500), Vector2(1100, 560), Vector2(150, 160)])
	check(rec.strokes.has(on_l2) and not rec.strokes.has(str(first.id)), "the eraser takes what it touches, not on hidden layers")
	bus.editor.undo()
	check(rec.strokes.has(str(first.id)), "undo puts an erased stroke back")
	# The layer list: top first, with its buttons.
	await frames(1)
	var rows := wb._layer_list.get_children().filter(func(c): return str(c.name).begins_with("Layer_"))
	check(rows.size() == 2 and str(rows[0].name) == "Layer_" + l2, "the layer list shows the top layer first")
	var l1 := str(first.layer)
	wb.raise_layer(l1)
	check(int(rec.sketch_layers[l1].order) > int(rec.sketch_layers[l2].order), "^ raises a layer")
	# Clear the active layer, then delete one with its strokes and undo it.
	wb.active_layer = l2
	wb.clear_layer()
	check(not rec.strokes.has(on_l2), "CLEAR LAYER empties it")
	var n := rec.strokes.size()
	bus.editor.do({"op": "remove_layer", "id": l1})
	check(not rec.sketch_layers.has(l1) and rec.strokes.size() == 0, "deleting a layer takes its strokes")
	bus.editor.undo()
	check(rec.sketch_layers.has(l1) and rec.strokes.size() == n, "and undo brings both back")
	# The plan underneath.
	wb.toggle_plan()
	check(wb.show_plan and wb.plan.visible, "PLAN UNDER shows the deck plan under the sketch")
	# It saves with the design.
	var back := DesignRecord.from_dict(JSON.parse_string(JSON.stringify(rec.to_dict())))
	check(back.sketch_layers.size() == rec.sketch_layers.size() and back.strokes.size() == rec.strokes.size()
			and JSON.stringify(back.to_dict()) == JSON.stringify(rec.to_dict()), "the whiteboard saves with the design")
	layer.queue_free()

	# A design wall can show it.
	var board := WallBoard.new()
	add_child(board)
	board.setup(bus, "test", [["plan:0", 0.5], ["data", 0.5]], 150.0)
	check("whiteboard" in board.views(), "the walls' views include the whiteboard")
	board.set_view(0, "whiteboard")
	check(board.content(0) is Whiteboard, "a wall panel shows it")
	board.queue_free()
	await frames(2)


func _record_ops(rec: DesignRecord) -> void:
	check(rec.apply({"op": "add_stroke", "stroke": {"layer": "nope", "points": [[0, 0]]}}).is_empty(),
			"a stroke needs a layer")
	var u := rec.apply({"op": "add_layer", "layer": {"name": "Ideas"}})
	var lid := str(u.id)
	check(rec.sketch_layers[lid].visible and int(rec.sketch_layers[lid].order) == 0, "a layer is added, visible, at the bottom")
	var k := rec.apply({"op": "add_stroke", "stroke": {"layer": lid, "points": [[1, 2], [3, 4]], "colour": "ff0000"}})
	check(rec.strokes.has(str(k.id)) and str(rec.strokes[str(k.id)].tool) == "pen", "a stroke is added, a pen by default")
	var undo := rec.apply({"op": "remove_layer", "id": lid})
	check(rec.sketch_layers.is_empty() and rec.strokes.is_empty(), "removing the layer takes its stroke")
	rec.apply(undo)
	check(rec.sketch_layers.has(lid) and rec.strokes.has(str(k.id)), "and its undo restores both")
	rec.sketch_layers.clear()
	rec.strokes.clear()


## Drags the mouse across the canvas through board points; returns the new stroke's id.
func _drag(wb: Whiteboard, pts: Array) -> String:
	var rec := wb.record()
	var before := rec.strokes.keys()
	for i in pts.size():
		var at: Vector2 = wb.to_canvas(pts[i])
		if i == 0:
			var down := InputEventMouseButton.new()
			down.button_index = MOUSE_BUTTON_LEFT
			down.pressed = true
			down.position = at
			wb._canvas_input(down)
		else:
			var m := InputEventMouseMotion.new()
			m.position = at
			wb._canvas_input(m)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = wb.to_canvas(pts[pts.size() - 1])
	wb._canvas_input(up)
	for k in rec.strokes:
		if not k in before:
			return str(k)
	return ""
