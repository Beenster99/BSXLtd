extends ModuleTest
## The designer's panels (beenster, 20 Nov: "stretch and move sections ... look at Photoshop"):
## each section a docked panel that moves, folds, hides and stretches, a WINDOW menu, text
## sizes, the layout kept per player; and F at a wall screen showing a panel full screen.
##   tools/run_tests.sh design

const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")
const DesignConsole := preload("res://modules/design/internal/console/design_console.gd")
const ConsoleLayout := preload("res://modules/design/internal/console/console_layout.gd")
const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")


func run_tests() -> void:
	ConsoleLayout.path = "user://test_design_console.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ConsoleLayout.path))
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
	for id: String in ["contract", "rooms", "components", "modules", "hull", "views", "holo", "data", "selection", "tools"]:
		check(console.panels.has(id), "a %s panel" % id)
	check(console.find_child("RoomPick", true, false) != null and console.panels.rooms.is_ancestor_of(console.find_child("RoomPick", true, false)),
			"the room drop-down sits in the ROOMS panel")
	check(console.panels.components.is_ancestor_of(console.find_child("CompList", true, false)), "the component list in COMPONENTS")
	check(console.side_view != null and console.side_view.mode == "side", "a side view beside the plan and the 3D view")

	# Move, swap, fold, hide.
	var left: Control = console._docks.left
	var right: Control = console._docks.right
	var first: Node = left.get_child(0)
	console.move_panel("tools", -1)
	check(left.get_child(0) == console.panels.tools and first != console.panels.tools, "^ moves a panel up its dock")
	console.swap_panel("components")
	check(console.panels.components.get_parent() == right, "<> moves a panel to the other side")
	console.panels.data.set_collapsed(true)
	check(not console.panels.data.body.visible and bool(console.layout.panels.data.collapsed), "folding shows only its title")
	console.show_panel("holo", false)
	check(not console.panels.holo.visible, "X hides a panel")
	var win := console.find_child("WindowMenu", true, false) as MenuButton
	check(win != null, "a WINDOW menu")
	win.get_popup().id_pressed.emit(ConsoleLayout.PANELS.keys().find("holo"))
	await frames(1)
	check(console.panels.holo.visible, "WINDOW shows a hidden panel again")
	var before: float = console.panels.selection.ratio
	console._resize_panel("selection", 60.0)
	check(console.panels.selection.ratio > before, "dragging a panel's foot makes it taller")

	# Text size.
	win.get_popup().id_pressed.emit(100 + ConsoleLayout.TEXT_SIZES.size() - 1)
	await frames(2)
	var tiny := float(ConsoleLayout.TEXT_SIZES[ConsoleLayout.TEXT_SIZES.size() - 1][1])
	check(is_equal_approx(console._dock_boxes.left.factor, tiny) and is_equal_approx(console._top_box.factor, tiny),
			"the smallest text size shrinks the panels and the top bar: %.2f" % tiny)

	# Kept for next time, per player.
	var saved := ConsoleLayout.load_layout()
	check(str(saved.panels.components.dock) == "right" and bool(saved.panels.data.collapsed)
			and is_equal_approx(float(saved.text), tiny), "the layout is saved: %s" % [saved.panels.components])
	console.queue_free()
	await frames(1)
	var again := DesignConsole.new()
	layer.add_child(again)
	again.setup(bus, holo)
	await frames(2)
	check(again.panels.components.get_parent() == again._docks.right and is_equal_approx(again._dock_boxes.left.factor, tiny),
			"a new console opens as it was left")
	again.reset_layout()
	await frames(1)
	check(again.panels.components.get_parent() == again._docks.left and is_equal_approx(again._top_box.factor, 1.0),
			"RESET LAYOUT puts it back")
	again.queue_free()
	holo.queue_free()
	await frames(2)

	# F at a wall: full screen.
	var room := Node3D.new()
	add_child(room)
	var f := Furnishing.new()
	room.add_child(f)
	f.setup(bus, Furnishing.stand_in_walls())
	await frames(2)
	var wall: String = f.boards.keys()[0]
	check(f.open_fullscreen(wall, 0), "F at a wall opens a panel full screen")
	check(f.is_fullscreen() and f.fullscreen.find_child("Prev", true, false) != null, "with its < and >")
	var full: Node = f.full_from.board
	(full as Node).call("step", 0, 1)
	var shown := str((full as Node).get("panels")[0].view)
	f.close_fullscreen()
	await frames(1)
	check(not f.is_fullscreen() and str(f.boards[wall].panels[0].view) == shown,
			"back to the room, the wall shows what was put up: %s" % shown)
	room.queue_free()
	await frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ConsoleLayout.path))
	ConsoleLayout.path = ConsoleLayout.PATH
