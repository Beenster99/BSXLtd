extends ModuleTest
## The designer's left panel and WILL IT WORK list (beenster, 20 Nov playtest): a click on a
## problem takes the plan to the room, part or door in error; the component sections are one
## drop-down with a tick each; the rooms are one drop-down.
##   tools/run_tests.sh design

const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")
const DesignConsole := preload("res://modules/design/internal/console/design_console.gd")
const DataChannel := preload("res://modules/design/internal/views/data_channel.gd")


func run_tests() -> void:
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	var holo := HoloTable.new()
	add_child(holo)
	holo.setup(bus)
	var layer := CanvasLayer.new()
	add_child(layer)
	var console := DesignConsole.new()
	layer.add_child(console)
	console.setup(bus, holo)
	await frames(3)
	var plan = console.plan
	plan.size = Vector2(1000, 700)

	# Rooms: one drop-down, picking arms that room.
	var rooms := console.find_child("RoomPick", true, false) as MenuButton
	check(rooms != null and rooms.get_popup().item_count == bus.catalog.room_list().size(),
			"the rooms are one drop-down with every room type")
	check(console.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text == "Bridge").is_empty(),
			"no long list of room buttons any more")
	if rooms:
		var i := -1
		for k in rooms.get_popup().item_count:
			if str(rooms.get_popup().get_item_metadata(k)) == "cargo":
				i = k
		rooms.get_popup().id_pressed.emit(rooms.get_popup().get_item_id(i))
		check(plan.tool == "room:cargo" and "CARGO" in rooms.text, "picking one arms it and the button says so: %s" % rooms.text)

	# Components: the sections are one drop-down with ticks, any number at once.
	var groups := console.find_child("CompGroups", true, false) as MenuButton
	check(groups != null, "the component sections are a drop-down")
	if groups:
		var pop := groups.get_popup()
		pop.id_pressed.emit(1001)  # NONE
		await frames(1)
		check(_rows(console) == 0, "none ticked: no rows")
		var power := -1
		var flight := -1
		for k in pop.item_count:
			if pop.is_item_checkable(k) and pop.get_item_text(k).begins_with("Power"):
				power = k
			if pop.is_item_checkable(k) and pop.get_item_text(k).to_lower().begins_with("flight"):
				flight = k
		check(power >= 0 and flight >= 0, "Power and Flight are in the list")
		pop.id_pressed.emit(pop.get_item_id(power))
		await frames(1)
		var just_power := _rows(console)
		check(just_power > 0 and pop.is_item_checked(power), "ticking Power lists its parts: %d" % just_power)
		pop.id_pressed.emit(pop.get_item_id(flight))
		await frames(1)
		check(_rows(console) > just_power and pop.is_item_checked(power) and pop.is_item_checked(flight),
				"ticking Flight too lists both: %d" % _rows(console))
		check("POWER" in groups.text and "," in groups.text, "the button names what is ticked: %s" % groups.text)
		pop.id_pressed.emit(1000)  # ALL
		await frames(1)
		check(groups.text.begins_with("SECTIONS: ALL"), "ALL ticks every section")

	# WILL IT WORK: a click goes to the problem.
	var rec := bus.library.current
	bus.editor.do({"op": "add_room", "room": {"type": "cargo", "deck": 2, "x": 10, "z": 20, "w": 1, "d": 1}})
	await frames(2)
	var probs := bus.problems().filter(func(p): return (p.rooms as Array).size() > 0)
	check(not probs.is_empty(), "a tiny cargo hold up on deck 3 has a problem naming it")
	if not probs.is_empty():
		var p: Dictionary = probs[0]
		var rid := str(p.rooms[0])
		plan.set_deck(0)
		plan.centre = Vector2(-50, -50)
		var data: DataChannel = console.data
		data.refresh()
		var row: Control = null
		for c in data.find_children("Problem_*", "", true, false):
			row = c
			break
		check(row != null, "a problem naming a room is a clickable row")
		var got := []
		data.problem_picked.connect(func(q): got.append(q))
		if row:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = true
			row.gui_input.emit(e)
		check(got.size() == 1, "clicking the row picks its problem")
		var to: Dictionary = got[0] if not got.is_empty() else p
		var target: Dictionary = rec.rooms[str(to.rooms[0])]
		check(plan.deck == int(target.deck) and plan.selected_kind == "room" and plan.selected_id == str(to.rooms[0]),
				"the plan goes to its deck and picks the room: deck %d, %s %s" % [plan.deck, plan.selected_kind, plan.selected_id])
		check(plan.centre.distance_to(rec.room_rect(str(to.rooms[0])).get_center()) < 0.01, "and centres on it")
		check(not DataChannel.has_place({"rooms": [], "components": [], "doors": []}), "a problem with nothing to show is not clickable")
	check(not console.go_to_problem({"code": "berth", "rooms": [], "components": [], "doors": []}),
			"nothing to go to: the plan stays")
	# The 3D window zooms on the wheel (the camera moves; the table's hologram does not).
	var table_zoom: float = holo.zoom
	var before: float = console.view_zoom
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	console._holo_input(wheel)
	check(console.view_zoom > before and is_equal_approx(holo.zoom, table_zoom), "wheel up zooms the 3D window in: %.2f" % console.view_zoom)
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for i in 40:
		console._holo_input(wheel)
	check(is_equal_approx(console.view_zoom, DesignConsole.VIEW_ZOOM_MIN), "and out, to a limit")
	console.queue_free()
	holo.queue_free()
	await frames(2)


static func _rows(console: Node) -> int:
	return console.find_child("CompList", true, false).find_children("Part_*", "Button", true, false).size() \
			+ console.find_child("CompList", true, false).find_children("Mount_*", "Button", true, false).size()
