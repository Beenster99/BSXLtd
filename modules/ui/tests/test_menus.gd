extends ModuleTest
## UI: registers its scenes, the main menu lists registered entries, the HUD fills slots,
## and the Void Salvage look (fonts, space backdrop, graphics screen) is in place.
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
	Menu.register_entry("_rivet", "Riveting", UiBus.SETTINGS, 2, {"trade": "riveting"}, "_Bench")
	Menu.register_entry("_weld", "Welding", UiBus.SETTINGS, 3, {"trade": "welding"}, "_Bench")
	await frames(2)
	var heads := menu.find_children("Group__Bench", "Label", true, false)
	check(heads.size() == 1, "a group's entries share one heading")
	var rivet := menu.find_child("_rivet", true, false) as Button
	check(rivet != null and heads.size() == 1
			and rivet.get_index() == heads[0].get_index() + 1, "grouped entry sits under its heading")
	Menu.unregister_entry("_rivet")
	Menu.unregister_entry("_weld")
	Menu.unregister_entry("_job")
	var gfx := menu.find_child("Graphics", true, false) as Button
	check(gfx != null, "main menu has a Graphics button")
	if gfx != null:
		gfx.pressed.emit()
		await frames(2)
		check(menu.find_children("*", "GraphicsPanel", true, false).size() == 1,
				"Graphics opens the graphics screen")
	menu.queue_free()

	for face: String in BsxTheme.FACES:
		check(BsxTheme.font(face) != null, "font %s loads" % face)
	var env := SpaceLook.environment()
	check(env.background_mode == Environment.BG_SKY and env.sky != null,
			"space look uses the starfield sky")
	var sun := SpaceLook.sun()
	check(sun.shadow_enabled, "space look's sun casts shadows")
	sun.free()
	check(get_node_or_null("/root/Graphics") != null, "Graphics autoload is running")

	var settings: Control = (load(Router.scene_path(UiBus.SETTINGS)) as PackedScene).instantiate()
	add_child(settings)
	await frames(2)
	check(settings.find_child("MasterVolume", true, false) != null, "settings shows volume")
	settings.queue_free()

	HudSlots.register_panel("_panel", "res://modules/ui/tests/fixture_panel.tscn", "top_bar")
	var hud := HudLayer.new()
	add_child(hud)
	await frames(2)
	var top: Node = hud.slots["top_bar"]
	check(top.get_children().any(func(c): return c.get_meta("hud_panel", "") == "_panel"),
			"HUD instantiates a registered panel")
	HudSlots.unregister_panel("_panel")
	hud.queue_free()
