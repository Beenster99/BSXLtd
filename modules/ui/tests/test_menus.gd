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
	var before := Menu.start()
	Menu.set_start(UiBus.SETTINGS, 1000)
	Menu.register_entry("_dup", "Settings again", UiBus.SETTINGS, 4)
	await frames(2)
	var start := menu.find_child("Start", true, false) as Button
	var first: Node = menu.entry_box.get_child(0)
	check(start != null and start.text == "New Game" and not start.disabled
			and (first == start or first.name == "Continue"), "Continue or New Game leads the menu")
	check(menu.find_child("_dup", true, false) == null, "an entry for the start scene isn't listed twice")
	Menu.clear_start(UiBus.SETTINGS)
	if not before.is_empty():
		Menu.set_start(before.scene, before.priority, before.args)
	Menu.unregister_entry("_dup")
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
	var tod := settings.find_child("TimeOfDay", true, false) as HSlider
	check(tod != null and tod.max_value == 24.0, "settings has a time of day slider")
	if tod != null:
		var was := AlienSky.setting_hour()
		tod.value = 6.5
		check(is_equal_approx(AlienSky.setting_hour(), 6.5), "the slider sets the time of day")
		var label := settings.find_child("TimeOfDayLabel", true, false) as Label
		check(label != null and label.text.ends_with("06:30"), "the slider shows the clock")
		tod.value = was
	settings.queue_free()

	await _test_sky()
	await _test_games()

	HudSlots.register_panel("_panel", "res://modules/ui/tests/fixture_panel.tscn", "top_bar")
	var hud := HudLayer.new()
	add_child(hud)
	await frames(2)
	var top: Node = hud.slots["top_bar"]
	check(top.get_children().any(func(c): return c.get_meta("hud_panel", "") == "_panel"),
			"HUD instantiates a registered panel")
	HudSlots.unregister_panel("_panel")
	hud.queue_free()


func _test_sky() -> void:
	check(AlienSky.sun_direction(12.0).y > 0.7, "the sun is high at noon")
	check(AlienSky.sun_direction(0.0).y < -0.7, "the sun is down at midnight")
	check(AlienSky.sun_direction(7.0).x > 0.0 and AlienSky.sun_direction(17.0).x < 0.0,
			"the sun rises in the east and sets in the west")
	check(AlienSky.daylight_at(12.0) == 1.0 and AlienSky.daylight_at(0.0) == 0.0,
			"daylight runs from night to full day")
	var dawn := AlienSky.daylight_at(6.0)
	check(dawn > 0.05 and dawn < 0.4, "dawn is half lit")
	check(AlienSky.clock(15.5) == "15:30" and AlienSky.clock(24.0) == "00:00", "clock text")
	var sky := AlienSky.new()
	sky.hour_override = 23.0
	add_child(sky)
	await frames(1)
	check(sky.environment.sky != null and sky.sky_material.shader != null, "the sky has its shader")
	check(not sky.sun.visible and sky.planet_light.light_energy > 0.2, "at night the planet lights the yard")
	var hours: Array[float] = []
	sky.time_changed.connect(func(h: float, _d: float) -> void: hours.append(h))
	sky.set_hour(12.0)
	check(sky.sun.visible and sky.sun.light_energy > 1.5, "at noon the sun is up")
	check(hours == [12.0], "the sky reports the hour")
	var was := AlienSky.setting_hour()
	sky.set_hour(-1.0)
	Settings.set_value(AlienSky.SECTION, AlienSky.KEY, 9.0)
	check(is_equal_approx(sky.hour, 9.0), "the sky follows the setting")
	Settings.set_value(AlienSky.SECTION, AlienSky.KEY, was)
	sky.queue_free()


func _test_games() -> void:
	var before := Menu.start()
	Menu.set_start(UiBus.SETTINGS, 1000)
	var stamp := Time.get_ticks_usec()
	var slot := Saves.new_game("_Menu test %d" % stamp)
	var menu: Control = (load(Router.scene_path(UiBus.MAIN_MENU)) as PackedScene).instantiate()
	add_child(menu)
	await frames(2)
	var cont := menu.find_child("Continue", true, false) as Button
	check(cont != null and cont.get_index() == 0 and cont.text.ends_with(str(stamp)),
			"Continue leads the menu with the latest game")
	check(menu.find_child("LoadGame", true, false) != null, "the menu has Load Game")
	(menu.find_child("Start", true, false) as Button).pressed.emit()
	await frames(2)
	var panel := menu.find_child("GamesPanel", true, false) as GamesPanel
	check(panel != null and not menu._center.visible, "New Game opens the games panel")
	if panel != null:
		check(panel.name_field.text != "" and panel.find_child("Begin", true, false) != null,
				"the panel offers a name and Begin")
		var row := panel.list_box.find_child("Game_" + slot.validate_node_name(), false, false)
		check(row != null, "the panel lists the saved game")
		if row != null:
			var del := row.find_child("Delete", false, false) as Button
			del.pressed.emit()
			check(Saves.exists(slot) and del.text == "Sure?", "Delete asks once more")
			del.pressed.emit()
			await frames(1)
			check(not Saves.exists(slot), "the second press deletes the game")
			check(panel.list_box.find_child("Game_" + slot.validate_node_name(), false, false) == null,
					"the deleted game leaves the list")
		(panel.find_child("Back", true, false) as Button).pressed.emit()
		await frames(2)
		check(menu._center.visible, "Back shows the menu again")
	if Saves.exists(slot):
		Saves.delete(slot)
	Saves.close_game()
	menu.queue_free()
	Menu.clear_start(UiBus.SETTINGS)
	if not before.is_empty():
		Menu.set_start(before.scene, before.priority, before.args)
