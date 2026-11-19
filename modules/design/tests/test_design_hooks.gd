extends ModuleTest
## Design Room: the hooks other modules use. A registered check's problems reach WILL IT WORK
## (once per edit), a console tool is a button on the console's top bar, the holotable says
## when it has built its hologram, and walk-inside when it has built the design.
##   tools/run_tests.sh design

const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")

var _runs := 0


func run_tests() -> void:
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	bus.open_sample()
	bus.register_check("test.hooks", func(_rec, _cat, _t) -> Array:
		_runs += 1
		return [{"code": "test.hooks", "severity": DesignRules.WARNING, "text": "Hook check", "rooms": [], "components": [], "doors": []}])
	var got := bus.problems().filter(func(p): return str(p.code) == "test.hooks")
	check(got.size() == 1, "a registered check's problem is on WILL IT WORK")
	bus.problems()
	check(_runs == 1, "it runs once per edit, not per read: %d" % _runs)
	bus.editor.do({"op": "set_meta", "fields": {"notes": "x"}})
	bus.problems()
	check(_runs == 2, "and again after an edit: %d" % _runs)
	bus.unregister_check("test.hooks")
	check(bus.problems().filter(func(p): return str(p.code) == "test.hooks").is_empty(), "unregistered, it goes")

	var pressed := [0]
	bus.register_console_tool("test.tool", "TEST TOOL", func() -> void: pressed[0] += 1, "a test", 99)
	var built: Array = []
	bus.holo_built.connect(func(table: Node3D, ship: Node3D) -> void: built.append([table, ship]))
	var room := Node3D.new()
	add_child(room)
	var cam := Camera3D.new()
	room.add_child(cam)
	var f := Furnishing.new()
	room.add_child(f)
	f.setup(bus, Furnishing.stand_in_walls())
	f.open_console()
	await frames(3)
	var b := f.console.find_child("Tool_test_tool", true, false) as Button
	check(b != null and b.text == "TEST TOOL", "the tool is a button on the console")
	if b:
		b.pressed.emit()
	check(pressed[0] == 1, "pressing it calls the tool")
	check(not built.is_empty() and (built[0][1] as Node3D).name == "Ship", "the holotable says when it has built, with its ship node")
	bus.unregister_console_tool("test.tool")
	await frames(1)
	check(f.console.find_child("Tool_test_tool", true, false) == null, "unregistered, the button goes")
	room.queue_free()
