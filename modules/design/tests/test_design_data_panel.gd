extends ModuleTest
## The console's DESIGN DATA panel (beenster, 20 Nov: "much larger text than the others and
## could be more efficiently organised ... the will it fit section should definitely be at the
## top"): small type, figures as label-value pairs that wrap to the width, so the panel goes
## narrow; WILL IT WORK, the contract fit and the berth first.
##   tools/run_tests.sh design

const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")
const DesignConsole := preload("res://modules/design/internal/console/design_console.gd")
const DataChannel := preload("res://modules/design/internal/views/data_channel.gd")
const ConsoleLayout := preload("res://modules/design/internal/console/console_layout.gd")


func run_tests() -> void:
	ConsoleLayout.path = "user://test_design_data_panel.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ConsoleLayout.path))
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	bus.open_sample()
	var holo := HoloTable.new()
	add_child(holo)
	holo.setup(bus)
	var layer := CanvasLayer.new()
	add_child(layer)
	var console := DesignConsole.new()
	layer.add_child(console)
	console.setup(bus, holo)
	console.size = Vector2(1920, 1080)
	console.data.refresh()
	await frames(3)
	var data: DataChannel = console.data
	check(data.dense, "the console's data panel is the dense kind")
	var biggest := 0
	for l: Label in data.find_children("*", "Label", true, false):
		var fs := l.get_theme_font_size("font_size")
		biggest = maxi(biggest, fs)
	var tools_label := 0
	for l: Label in console.panels.tools.find_children("*", "Label", true, false):
		tools_label = maxi(tools_label, l.get_theme_font_size("font_size"))
	check(biggest <= maxi(tools_label, 18), "no text bigger than the other panels': %d (tools %d)" % [biggest, tools_label])
	check(data.get_combined_minimum_size().x < 260.0, "it can go narrow: %.0f px" % data.get_combined_minimum_size().x)
	check(data.find_child("Fig_Cost", true, false) != null and data.find_child("Fig_Dry_mass", true, false) != null,
			"figures are label-value pairs")
	# The checks come first.
	var order: Array = []
	for l: Label in data.find_children("*", "Label", true, false):
		order.append(l.text)
	var work := order.find("WILL IT WORK")
	var summary := -1
	for i in order.size():
		if str(order[i]) == "Cost":
			summary = i
			break
	check(work >= 0 and summary > work, "WILL IT WORK is above the figures: %d < %d" % [work, summary])
	var berth := order.find("BERTH")
	check(berth < 0 or berth < summary, "and the berth check too")
	check("SIZE AND LAYOUT" in order and "POWER AND DRIVE" in order, "the attributes are all still there")
	# A wall screen keeps its big tiles.
	var wall := DataChannel.new()
	add_child(wall)
	wall.setup(bus)
	await frames(1)
	check(not wall.dense and wall.find_child("Fig_Cost", true, false) == null, "wall screens keep the big tiles")
	wall.queue_free()
	layer.queue_free()
	holo.queue_free()
	await frames(2)
