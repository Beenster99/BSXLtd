extends ModuleTest
## UI: registers its scenes, the main menu lists registered entries, the HUD fills slots.
##   tools/run_tests.sh ui


func run_tests() -> void:
	check(Modules.bus("ui") is UiBus, "ui bus loaded")
	check(Router.has_scene(UiBus.MAIN_MENU) and Router.has_scene(UiBus.SETTINGS),
			"ui registers its menus")

	Menu.register_entry("_job", "Start job", UiBus.SETTINGS, 1)
	var menu: Control = (load(Router.scene_path(UiBus.MAIN_MENU)) as PackedScene).instantiate()
	add_child(menu)
	await frames(2)
	var entry := menu.find_child("_job", true, false) as Button
	check(entry != null and entry.text == "Start job", "main menu shows a registered entry")
	check(entry != null and not entry.disabled, "entry enabled when its scene exists")
	menu.queue_free()

	var settings: Control = (load(Router.scene_path(UiBus.SETTINGS)) as PackedScene).instantiate()
	add_child(settings)
	await frames(2)
	check(settings.find_child("MasterVolume", true, false) != null, "settings shows volume")
	settings.queue_free()

	Hud.register_panel("_panel", "res://modules/ui/tests/fixture_panel.tscn", "top_bar")
	var hud := HudLayer.new()
	add_child(hud)
	await frames(2)
	var top: Node = hud.slots["top_bar"]
	check(top.get_children().any(func(c): return c.get_meta("hud_panel", "") == "_panel"),
			"HUD instantiates a registered panel")
	Hud.unregister_panel("_panel")
	hud.queue_free()
