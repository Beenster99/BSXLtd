extends ModuleTest
## Router, HudSlots, Menu, Shots and Settings registries.
##   tools/run_tests.sh core


func run_tests() -> void:
	Router.register_scene("_t", "res://modules/core/internal/boot.tscn")
	check(Router.has_scene("_t"), "router registers")
	check(Router.scene_path("_t").ends_with("boot.tscn"), "router path")
	check(not Router.has_scene("_nope"), "router unknown id")

	HudSlots.register_panel("_b", "res://x.tscn", HudSlots.TOOL_BELT, 5)
	HudSlots.register_panel("_a", "res://y.tscn", HudSlots.TOOL_BELT, 1)
	HudSlots.register_panel("_a", "res://y.tscn", HudSlots.TOOL_BELT, 1)
	var belt: Array = HudSlots.panels_in(HudSlots.TOOL_BELT).filter(func(p): return p.id.begins_with("_"))
	check(belt.size() == 2, "re-registering a panel replaces it")
	check(belt[0].id == "_a", "panels sorted by order")
	HudSlots.unregister_panel("_a")
	HudSlots.unregister_panel("_b")

	Menu.register_entry("_late", "Late", "_t", 50)
	Menu.register_entry("_early", "Early", "_t", -50)
	var ids: Array = Menu.entries().map(func(e): return e.id)
	check(ids.find("_early") < ids.find("_late"), "menu entries sorted by order")
	Menu.register_entry("_weld", "Welding", "_t", 60, {"trade": "welding"}, "Workbench")
	var weld: Dictionary = Menu.entries().filter(func(e): return e.id == "_weld")[0]
	check(weld.args.trade == "welding" and weld.group == "Workbench", "menu entry keeps args and group")
	check(Menu.entries().filter(func(e): return e.id == "_late")[0].group == "",
			"old-style entries have no group")
	for id in ["_late", "_early", "_weld"]:
		Menu.unregister_entry(id)
	check(not Menu.entries().any(func(e): return e.id.begins_with("_")), "menu entries unregister")

	var before := Menu.start()  # a module's own start (the yard); put back at the end
	if not before.is_empty():
		Menu.clear_start(before.scene)
	Menu.set_start("_yard", 5)
	Menu.set_start("_other", 1)
	check(Menu.start().scene == "_yard", "the highest priority start wins")
	Menu.set_start("_other", 9, {"x": 1})
	check(Menu.start().scene == "_other" and Menu.start().args.x == 1, "a higher priority takes over")
	Menu.clear_start("_other")
	check(Menu.start().is_empty(), "start clears")
	if not before.is_empty():
		Menu.set_start(before.scene, before.priority, before.args)

	Settings.register("_test", {"speed": 3})
	check(Settings.get_value("_test", "speed") == 3, "settings default")
	Settings.set_value("_test", "speed", 5)
	check(Settings.get_value("_test", "speed") == 5, "settings set")

	Shots.register("_shot", "_t")
	check(Shots.all().any(func(s): return s.id == "_shot"), "shot registered")

	check(BuildInfo.version() != "", "build version readable")
