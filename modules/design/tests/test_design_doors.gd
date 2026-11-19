extends ModuleTest
## Design Room, 0.4.3 feedback (beenster, 19 Nov): doors and doorways of different widths and
## types; grid snapping down to 5 cm; the console's data pane shows the design's attributes, not
## its parts list (that has its own wall screen).
##   tools/run_tests.sh design

const DesignConsole := preload("res://modules/design/internal/console/design_console.gd")
const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")
const WalkBuild := preload("res://modules/design/internal/walk/walk_build.gd")


func run_tests() -> void:
	var bus := Modules.bus("design") as DesignBus
	_kinds(bus)
	await _console(bus)


func _kinds(bus: DesignBus) -> void:
	var styles := {}
	for k: String in DesignCatalog.DOOR_ORDER:
		var dk: Dictionary = DesignCatalog.DOOR_KINDS[k]
		check(float(dk.min_w) <= float(dk.w) and float(dk.w) <= float(dk.max_w), "%s's default width is in its range" % k)
		styles[str(dk.style)] = true
	check(DesignCatalog.DOOR_ORDER.size() >= 7 and styles.size() >= 5,
			"doors come in kinds that open differently: %s" % [styles.keys()])

	var d := DesignRecord.new("dr", "Doors")
	d.apply({"op": "add_room", "room": {"id": "a", "type": "corridor", "x": 0, "z": 0, "w": 2, "d": 8}})
	d.apply({"op": "add_room", "room": {"id": "b", "type": "cargo", "x": 2, "z": 0, "w": 6, "d": 8}})
	d.apply({"op": "add_door", "door": {"id": "d1", "deck": 0, "x": 2, "z": 4, "a": "a", "b": "b", "kind": "doorway"}})
	check(is_equal_approx(DesignCatalog.door_w(d.doors.d1), 1.2), "a doorway is 1.2 m by default")
	var u := d.apply({"op": "set_door", "id": "d1", "fields": {"w": 2.6}})
	check(is_equal_approx(DesignCatalog.door_w(d.doors.d1), 2.6), "a doorway made 2.6 m wide")
	var t := DesignTotals.compute(d, bus.catalog)
	var line: Dictionary = t.lines.filter(func(l): return l.kind == "door")[0]
	check(float(line.cost) > float(DesignCatalog.DOOR_KINDS.doorway.cost) * 2.0, "a wider door costs more: %d" % int(line.cost))
	d.apply(u)
	check(is_equal_approx(DesignCatalog.door_w(d.doors.d1), 1.2), "undo puts its width back")
	d.apply({"op": "set_door", "id": "d1", "fields": {"kind": "hinged", "w": 3.0}})
	check(is_equal_approx(DesignCatalog.door_w(d.doors.d1), 1.0), "a hinged door is kept to its widest, 1 m")
	check(DesignRules.check(d, bus.catalog).filter(func(p): return p.code == "door_off_wall").is_empty(),
			"the hinged door fits its wall")

	# Walk-inside hangs a hinged leaf from a jamb, and it swings open.
	var walk := WalkBuild.new(bus.catalog)
	var holder := Node3D.new()
	add_child(holder)
	walk.build(d, holder)
	var hinge := holder.find_child("Hinge", true, false) as Node3D
	check(hinge != null, "a hinged door has a hinge")
	if hinge:
		for i in 30:
			walk.update_doors([hinge.global_position], 0.1)
		check(absf(hinge.rotation.y) > deg_to_rad(80.0), "it swings open as you come near: %.0f deg" % rad_to_deg(hinge.rotation.y))
	holder.queue_free()


func _console(bus: DesignBus) -> void:
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
	var rec := bus.library.current
	# The grid goes down to 5 cm.
	check(is_equal_approx(DesignRecord.GRIDS[0], 0.05), "the finest grid is 5 cm")
	var pick := console.find_child("GridPick", true, false) as OptionButton
	check(pick != null and pick.item_count == DesignRecord.GRIDS.size(), "the console has a grid picker")
	if pick:
		pick.item_selected.emit(0)
	check(is_equal_approx(rec.grid, 0.05), "picking it sets a 5 cm grid")
	var at: Vector2 = console.plan._snap(Vector2(0.07, 0.12), rec.grid)
	check(at.is_equal_approx(Vector2(0.05, 0.1)), "the plan snaps to 5 cm: %s" % at)
	check(PlanView._m(0.05) == "0.05", "5 cm reads 0.05")

	# The data pane: attributes, no parts list.
	console.data.refresh()
	var texts: Array = []
	for n in console.data.find_children("*", "Label", true, false):
		texts.append((n as Label).text)
	check("DESIGN DATA" in texts and "SIZE AND LAYOUT" in texts and "STRUCTURE" in texts and "POWER AND DRIVE" in texts,
			"the console's data pane shows the design's attributes")
	check(not "PARTS LIST" in texts, "and no parts list")
	layer.queue_free()
	holo.queue_free()


const PlanView := preload("res://modules/design/internal/views/plan_view.gd")
