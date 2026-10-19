extends ModuleTest
## Router, Hud, Menu, Shots and Settings registries.
##   tools/run_tests.sh core


func run_tests() -> void:
	Router.register_scene("_t", "res://modules/core/internal/boot.tscn")
	check(Router.has_scene("_t"), "router registers")
	check(Router.scene_path("_t").ends_with("boot.tscn"), "router path")
	check(not Router.has_scene("_nope"), "router unknown id")

	Hud.register_panel("_b", "res://x.tscn", Hud.TOOL_BELT, 5)
	Hud.register_panel("_a", "res://y.tscn", Hud.TOOL_BELT, 1)
	Hud.register_panel("_a", "res://y.tscn", Hud.TOOL_BELT, 1)
	var belt: Array = Hud.panels_in(Hud.TOOL_BELT).filter(func(p): return p.id.begins_with("_"))
	check(belt.size() == 2, "re-registering a panel replaces it")
	check(belt[0].id == "_a", "panels sorted by order")
	Hud.unregister_panel("_a")
	Hud.unregister_panel("_b")

	Menu.register_entry("_late", "Late", "_t", 50)
	Menu.register_entry("_early", "Early", "_t", -50)
	var ids: Array = Menu.entries().map(func(e): return e.id)
	check(ids.find("_early") < ids.find("_late"), "menu entries sorted by order")

	Settings.register("_test", {"speed": 3})
	check(Settings.get_value("_test", "speed") == 3, "settings default")
	Settings.set_value("_test", "speed", 5)
	check(Settings.get_value("_test", "speed") == 5, "settings set")

	Shots.register("_shot", "_t")
	check(Shots.all().any(func(s): return s.id == "_shot"), "shot registered")

	check(BuildInfo.version() != "", "build version readable")
