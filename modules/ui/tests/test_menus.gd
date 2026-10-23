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
	await _test_sounds()
	await _test_holo()
	_test_terminal_kit()
	await _test_key_binds()
	await _test_settings_pages()
	await _test_info_panel()
	await _test_pause()
	await _test_look_hints()
	await _test_touch_screen()

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


func _test_sounds() -> void:
	for sound in Sfx.names():
		var wav := Sfx.stream(sound)
		check(wav != null and wav.data.size() > 200, "sound %s is made" % sound)
	check(Sfx.stream("beam").loop_mode == AudioStreamWAV.LOOP_FORWARD, "the beam hum loops")
	check(Sfx.stream("click") == Sfx.stream("click"), "sounds are cached")
	var p := Sfx.play("click")
	check(p is AudioStreamPlayer, "a flat sound plays")
	var anchor := Node3D.new()
	add_child(anchor)
	check(Sfx.play("clunk", anchor) is AudioStreamPlayer3D, "a 3D sound follows its node")

	# A walker crossing a floor takes steps, and lands with a thud.
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.set_meta("surface", "metal")
	add_child(floor_body)
	var walker := Walker.new()
	var cap := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	cap.shape = capsule
	cap.position.y = 0.9
	walker.add_child(cap)
	walker.position = Vector3(0, 0.6, 0)
	add_child(walker)
	var feet := Footsteps.new()
	walker.add_child(feet)
	for i in 120:
		await get_tree().physics_frame
	check(feet.surface == "metal", "steps hear the metal floor")
	check(feet.steps >= 3, "walking 6 m takes steps (%d)" % feet.steps)
	walker.queue_free()
	floor_body.queue_free()
	anchor.queue_free()


func _test_holo() -> void:
	var ui := Modules.bus("ui") as UiBus
	var holo: WristHolo = ui.holo if ui else null
	check(holo != null and holo.is_inside_tree(), "the UI bus owns the wrist screen")
	if holo == null:
		return
	var made := [0]
	var glass_seen := [false]
	HudSlots.register_holo_channel("_orders", "Orders", func(glass: bool) -> Control:
		made[0] += 1
		glass_seen[0] = glass
		var l := Label.new()
		l.text = "orders here"
		return l, 1)
	HudSlots.register_holo_channel("_stock", "Stock", func() -> Control: return Label.new(), 2)
	HudSlots.register_holo_readout("_cash", func() -> String: return "CR 1,234")
	HudSlots.open_holo()
	await frames(2)
	check(holo.is_open and holo.channel == "_orders", "the wrist screen opens on the first channel")
	check(made[0] == 1 and glass_seen[0], "a one-argument factory is told it's on glass")
	check(holo.root.find_child("Header", true, false) != null and holo.root.find_child("Hint", true, false) != null,
			"the wrist screen has the terminal's header and footer")
	var first := holo.tabs.get_child(0) as Button
	check(first != null and first.text == "01  ORDERS", "tabs are numbered like the terminal's")
	check(holo.tabs.get_children().all(func(b: Node) -> bool: return b.name != "Ch_ui_settings"),
			"the wrist screen has no Settings tab")
	check((holo.root.find_child("Readouts", true, false) as Label).text.contains("CR 1,234"), "readouts show in the header")
	var os := holo.root.find_child("OsInfo", true, false) as Label
	check(os != null and os.text.begins_with("BSX-OS") and BuildInfo.version() in os.text,
			"the footer's small print names the OS and the build")
	var status := holo.root.find_child("Status", true, false) as Label
	check(status != null and str(Time.get_datetime_dict_from_system().year) in status.text and "UP " in status.text,
			"the footer shows the date, time and uptime")
	check(holo.root.has_meta("holo") and Sfx.press(first).get_meta("sound") == "tick",
			"buttons on the wrist screen tick")
	var plain := Button.new()
	holo.content.add_child(plain)
	check(Sfx.press(Button.new()).get_meta("sound") == "click", "buttons elsewhere still click")
	check(plain.has_meta("sfx") and plain.pressed.get_connections().size() > 0,
			"a plain button another module puts on the screen ticks too")
	await get_tree().create_timer(0.6).timeout
	check(is_equal_approx(holo.pane.scale.y, 1.0) and is_equal_approx((holo.pane.get_child(0) as Control).modulate.a, 1.0),
			"the screen has finished coming up")
	check(HudSlots.pointer_claimed() and HudSlots.pointer_claimed("_other"), "the wrist screen claims the pointer")
	var stock_tab := holo.tabs.find_child("Ch__stock", false, false) as Button
	stock_tab.pressed.emit()
	check(is_instance_valid(stock_tab) and not stock_tab.is_queued_for_deletion(),
			"the tab pressed outlives its own click, so the release can't fall through to the game")
	await frames(1)
	check(holo.channel == "_stock", "a tab brings up its channel")
	check(holo.content.find_child("Channel", false, false) is Label, "the channel's screen shows")
	holo.close()
	check(holo.root == null and holo.get_node_or_null("HoloVanishing") != null, "closing leaves the old screen folding away")
	check(not HudSlots.pointer_claimed(), "and gives the pointer back")
	await get_tree().create_timer(0.4).timeout
	check(holo.get_node_or_null("HoloVanishing") == null, "and then it's gone")
	HudSlots.open_holo()
	check(holo.channel == "_stock", "the wrist screen comes back on the last channel")
	HudSlots.register_holo_channel("_closing", "Closing", func() -> Control: return Closing.new(), 3)
	HudSlots.open_holo("_closing")
	(holo.content.find_child("Channel", false, false) as Closing).close_requested.emit()
	check(not holo.is_open, "a channel's close_requested puts the screen away")
	HudSlots.unregister_holo_channel("_closing")
	HudSlots.open_holo("_orders")
	HudSlots.unregister_holo_channel("_orders")
	await frames(1)
	check(holo.tabs.find_child("Ch__orders", false, false) == null and holo.channel != "_orders",
			"an unregistered channel leaves the tabs")
	(holo.tabs.find_child("Close", false, false) as Button).pressed.emit()
	check(not holo.is_open, "CLOSE puts the screen away")
	HudSlots.unregister_holo_channel("_stock")
	HudSlots.unregister_holo_readout("_cash")
	var key := InputEventKey.new()
	key.physical_keycode = Keys.key_of(Keys.HOLO)
	key.pressed = true
	holo._input(key)
	check(holo.is_open, "the holo key brings it up in a game")
	var esc := InputEventKey.new()
	esc.physical_keycode = Keys.key_of(Keys.CANCEL)
	esc.pressed = true
	holo._input(esc)
	check(not holo.is_open and holo.root == null, "Esc puts the wrist screen away")
	holo._input(key)
	var was := Router.current_id
	Router.current_id = UiBus.SETTINGS
	Router.scene_changed.emit(UiBus.SETTINGS)
	check(not holo.is_open, "going to a menu puts the wrist screen away")
	Router.current_id = was


func _test_terminal_kit() -> void:
	var T := TerminalKit
	var text_was: Variant = Settings.get_value(T.TEXT_SECTION, T.TEXT_KEY)
	check(text_was == null or str(text_was) in T.TEXT_SIZES, "terminal text is a known size")
	Settings.set_value(T.TEXT_SECTION, T.TEXT_KEY, "Standard")
	check(T.label("x", "body", 20, T.TEXT).get_theme_font_size("font_size") == 20, "Standard text is the size asked for")
	Settings.set_value(T.TEXT_SECTION, T.TEXT_KEY, "Compact")
	check(T.label("x", "body", 20, T.TEXT).get_theme_font_size("font_size") < 20 and T.cell("1", 100).custom_minimum_size.x < 100,
			"Compact text and columns are smaller, so a tab holds more")
	Settings.set_value(T.TEXT_SECTION, T.TEXT_KEY, text_was if text_was != null else T.TEXT_DEFAULT)
	check("tick" in Sfx.names() and Sfx.stream("tick").data.size() > 0, "the holo tick is a sound")
	HudSlots.register_holo_section("_crew", "_cash", "Transfer money", func(glass: bool) -> Control:
		var l := Label.new()
		l.text = "glass" if glass else "plain"
		return l)
	var secs := T.sections("_crew", true)
	add_child(secs)
	check(secs.get_child_count() == 1 and secs.find_child("Section__cash", false, false) != null,
			"a module's section shows in another's channel")
	HudSlots.register_holo_section("_crew", "_other", "Other", func() -> Control: return Label.new(), 5)
	check(secs.get_child_count() == 2, "sections added later show up")
	HudSlots.unregister_holo_section("_crew", "_cash")
	HudSlots.unregister_holo_section("_crew", "_other")
	await frames(1)
	check(secs.get_child_count() == 0 and HudSlots.holo_sections("_crew").is_empty(), "and leave when unregistered")
	secs.queue_free()
	var rows := T.list()
	for i in 3:
		rows.add_child(T.row([T.cell_text("Stringer", "Orbital surplus"), T.tag("new", T.GOOD),
				T.cell("24", 60), T.cell("CR " + T.money(12400), 110, T.TEXT, "mono_bold")], i % 2 == 1, true))
	check(rows.get_child_count() == 3 and rows.get_parent() is ScrollContainer, "kit lists hold rows")
	var plate := (rows.get_child(0) as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	check(plate.bg_color.a < 0.8, "rows on glass are see-through")
	check(T.money(12400) == "12,400" and T.money(-5) == "-5", "money text")
	var picked := [""]
	var flow := T.chips(PackedStringArray(["hull", "wiring"]), "", func(n: String) -> void: picked[0] = n, true)
	(flow.get_child(2) as Button).pressed.emit()
	check(flow.get_child_count() == 3 and picked[0] == "wiring", "chips: ALL then each, and they pick")
	var typed := [""]
	var s := T.search("Search parts", func(t: String) -> void: typed[0] = t, true)
	s.text_changed.emit("bolt")
	check(typed[0] == "bolt", "the search box reports what's typed")
	var d := T.docket("Purchase order", "BSX/PO", true)
	check(d.panel is PanelContainer and d.body is VBoxContainer, "a docket has a panel and a body")
	for n: Node in [rows.get_parent(), flow, s, d.panel]:
		n.free()


func _test_key_binds() -> void:
	var settings: Control = (load(Router.scene_path(UiBus.SETTINGS)) as PackedScene).instantiate()
	add_child(settings)
	await frames(2)
	(settings.find_child("KeyBinds", true, false) as Button).pressed.emit()
	await frames(2)
	var panel := settings.find_child("KeyBindsPanel", true, false) as KeyBindsPanel
	check(panel != null, "Settings has a key binds screen")
	if panel != null:
		check(panel.rows.has(Keys.INTERACT) and panel.rows[Keys.INTERACT].text == Keys.key_name(Keys.INTERACT),
				"key binds list the doing key")
		var was := Keys.key_of(Keys.JUMP)
		panel.rows[Keys.JUMP].pressed.emit()
		check(panel.listening == Keys.JUMP, "clicking a key waits for the new one")
		panel.press(KEY_K)
		check(Keys.key_of(Keys.JUMP) == KEY_K and panel.rows[Keys.JUMP].text == "K", "pressing a key rebinds")
		panel.rows[Keys.JUMP].pressed.emit()
		panel.press(KEY_ESCAPE)
		check(Keys.key_of(Keys.JUMP) == KEY_K, "Esc cancels a rebind")
		Keys.rebind(Keys.JUMP, was)
	settings.queue_free()


func _test_settings_pages() -> void:
	check(not Menu.settings_page(Menu.CHARACTER).is_empty(), "UI gives Settings a Character page")
	Menu.register_settings_section(Menu.CHARACTER, "_payslips", "Payslips", func() -> Control:
		var l := Label.new()
		l.name = "Slip"
		l.text = "CR 1,200"
		return l, 30)
	Menu.register_settings_page("_company", "Company", func() -> Control: return Label.new(), 20)
	var settings: Control = (load(Router.scene_path(UiBus.SETTINGS)) as PackedScene).instantiate()
	add_child(settings)
	await frames(2)
	var pages := settings.find_child("Pages", true, false)
	check(pages.find_child("Page_character", false, false) != null and pages.find_child("Page__company", false, false) != null,
			"each page has a button on the Settings menu")
	(pages.find_child("Page_character", false, false) as Button).pressed.emit()
	await frames(1)
	var over := settings.find_child("Page_character_Overlay", true, false)
	check(over != null and over.find_child("PageControls", true, false) != null
			and over.find_child("Section__payslips", true, false) != null, "Character shows its controls and module sections")
	Menu.register_settings_section(Menu.CHARACTER, "_level", "Level", func() -> Control: return Label.new(), 10)
	await frames(1)
	var body := over.find_child("PageBody", true, false)
	var lv := body.find_child("Section__level", false, false)
	var ps := body.find_child("Section__payslips", false, false)
	check(lv != null and ps != null and lv.get_index() < ps.get_index(), "sections added later slot in by order")
	(over.find_child("Done", true, false) as Button).pressed.emit()
	Menu.unregister_settings_page("_company")
	await frames(1)
	check(pages.find_child("Page__company", false, false) == null, "an unregistered page leaves the menu")
	Menu.unregister_settings_section(Menu.CHARACTER, "_payslips")
	Menu.unregister_settings_section(Menu.CHARACTER, "_level")
	check(Menu.settings_sections(Menu.CHARACTER).all(func(c): return not str(c.id).begins_with("_")), "sections unregister")
	settings.queue_free()


func _test_info_panel() -> void:
	var ui := Modules.bus("ui") as UiBus
	check(ui.info != null and ui.info.is_inside_tree(), "the UI bus owns the info panel")
	HudSlots.set_info("_b", "Second", "", 20)
	HudSlots.set_info("_a", "Driving the lift", "W A S D drive", 10)
	await frames(1)
	var a := ui.info.box.find_child("Info__a", false, false)
	var b := ui.info.box.find_child("Info__b", false, false)
	check(a != null and b != null and a.get_index() < b.get_index(), "info cards stack in order")
	check((a.find_child("Text", true, false) as Label).text == "W A S D drive", "a card shows its text")
	HudSlots.set_info("_a", "Driving the lift", "F lets go", 10)
	await frames(1)
	check(ui.info.box.find_child("Info__a", false, false) == a and (a.find_child("Text", true, false) as Label).text == "F lets go",
			"setting a card again updates it in place")
	check(is_equal_approx(ui.info.box.anchor_left, 1.0) and ui.info.box.offset_right < 0.0,
			"the cards sit on the right")
	HudSlots.clear_info("_a")
	HudSlots.clear_info("_b")
	await frames(1)
	check(ui.info.box.find_child("Info__a", false, false) == null and HudSlots.infos().is_empty(), "cleared cards go")


func _test_pause() -> void:
	var ui := Modules.bus("ui") as UiBus
	var pause := ui.pause
	check(pause != null, "the UI bus owns the pause menu")
	Menu.open_pause()
	check(pause.is_open and pause.root.find_child("Resume", true, false) != null
			and pause.root.find_child("Mainmenu", true, false) != null, "Menu.open_pause() brings up the pause menu")
	check(HudSlots.pointer_claimed() and get_tree().paused, "it takes the pointer and holds the game still offline")
	var esc := InputEventKey.new()
	esc.physical_keycode = Keys.key_of(Keys.CANCEL)
	esc.pressed = true
	pause._unhandled_input(esc)
	check(pause.is_open, "the Esc a scene opened it with doesn't close it again when it falls through")
	await frames(1)
	Menu.register_settings_section(Menu.GAMEPLAY, "_mouse", "Mouse", func() -> Control:
		var l := Label.new()
		l.text = "speed"
		return l, 10)
	(pause.root.find_child("Settings", true, false) as Button).pressed.emit()
	await frames(1)
	var st := pause.root.find_child("SettingsTabs", true, false) as SettingsTabs
	check(st != null and not (pause.root.find_child("Body", true, false) as Control).visible,
			"Settings replaces the menu's buttons")
	var names := st.tabs.get_children().map(func(b: Node) -> String: return str(b.name))
	check(names.slice(0, 4) == ["Tab_graphics", "Tab_keys", "Tab_sound", "Tab_gameplay"] and "Tab_character" in names,
			"Settings has Graphics, Key binds, Sound and Gameplay tabs, then the pages")
	check(st.body.find_child("Tab_graphics", false, false) is GraphicsPanel, "it opens on Graphics")
	(st.tabs.find_child("Tab_keys", false, false) as Button).pressed.emit()
	await frames(1)
	check(st.current == "keys" and st.body.get_child(0) is KeyBindsPanel, "Key binds lists the keys")
	st.open_tab(Menu.SOUND)
	var master := st.body.find_child("MasterVolume", true, false) as HSlider
	var effects := st.body.find_child("EffectsVolume", true, false) as HSlider
	check(master != null and effects != null, "Sound has master and effects volume")
	var was: Variant = Settings.get_value("audio", "effects")
	effects.value = 0.5
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Sfx.BUS)), linear_to_db(0.5))
			and Sfx.bus() == Sfx.BUS, "the effects slider sets the Effects bus the game's sounds play on")
	effects.value = float(was) if was != null else 1.0
	st.open_tab(Menu.GAMEPLAY)
	check(st.body.find_child("TimeOfDay", true, false) != null and st.body.find_child("Section__mouse", true, false) != null,
			"Gameplay has the time of day and the sections modules add")
	check(st.body.find_child("TerminalText", true, false) != null, "Gameplay chooses the terminal text size")
	Menu.unregister_settings_section(Menu.GAMEPLAY, "_mouse")
	var debug_was := Flags.is_on("ui.debug_tab")
	Flags.set_flag("ui.debug_tab", true)
	Menu.register_settings_section(Menu.DEBUG, "_max", "Max out", func() -> Control: return Button.new(), 10)
	check(st.tab_list().back() == [Menu.DEBUG, "Debug"], "Debug is the last tab while ui.debug_tab is on")
	st.open_tab(Menu.DEBUG)
	check(st.body.find_child("Section__max", true, false) != null, "Debug shows the buttons modules add")
	Menu.unregister_settings_section(Menu.DEBUG, "_max")
	Flags.set_flag("ui.debug_tab", false)
	check(not st.tab_list().any(func(t: Array) -> bool: return t[0] == Menu.DEBUG), "and hides with the flag off")
	Flags.set_flag("ui.debug_tab", debug_was)
	pause._input(esc)
	check(pause.is_open and (pause.root.find_child("Body", true, false) as Control).visible, "Esc goes back out of Settings")
	pause._input(esc)
	check(not pause.is_open and not get_tree().paused and not HudSlots.pointer_claimed(), "Esc resumes where you were")
	check(PauseMenu.resume_mouse_mode(Input.MOUSE_MODE_VISIBLE, false) == Input.MOUSE_MODE_CAPTURED,
			"Resume takes the mouse back for looking, even if it was free when Esc came in")
	check(PauseMenu.resume_mouse_mode(Input.MOUSE_MODE_CAPTURED, true) == Input.MOUSE_MODE_VISIBLE,
			"but leaves it free while another screen has the pointer")
	await frames(1)
	pause._unhandled_input(esc)
	check(pause.is_open, "an Esc nothing else used opens it")
	(pause.root.find_child("Resume", true, false) as Button).pressed.emit()
	check(not pause.is_open, "Resume closes it")
	await frames(1)


func _test_look_hints() -> void:
	var ui := Modules.bus("ui") as UiBus
	var before := Router.current_id
	Router.current_id = "_game"
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	var box := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	box.add_child(shape)
	box.position = Vector3(0, 0, -2.0)
	var part := Node3D.new()
	part.set_script(Hinted)
	part.add_child(box)
	add_child(part)
	await frames(3)
	ui.look.refresh()
	var card := HudSlots.infos().filter(func(c): return c.id == LookHints.CARD)
	check(card.size() == 1 and card[0].title == "Shore power" and "Push it" in str(card[0].text)
			and Keys.prompt(Keys.INTERACT) in str(card[0].text) and "[LMB]  Switch on" in str(card[0].text),
			"looking at something shows what it is and its keys")
	check(HudSlots.infos()[0].id == LookHints.CARD, "the look card sits above the others")
	HudSlots.register_look_hint("_override", func(hit: Dictionary) -> Dictionary:
		return {"title": "Override"} if hit.collider == box else {})
	ui.look.refresh()
	check(ui.look.current.get("title") == "Override", "a registered provider is asked first")
	HudSlots.unregister_look_hint("_override")
	box.set_meta("look_hint", {"title": "Meta"})
	ui.look.refresh()
	check(ui.look.current.get("title") == "Meta", "meta look_hint works too, nearest node first")
	cam.rotation.y = deg_to_rad(90)
	await frames(2)
	ui.look.refresh()
	check(HudSlots.infos().all(func(c): return c.id != LookHints.CARD), "looking at nothing shows no card")
	part.queue_free()
	cam.queue_free()
	Router.current_id = before
	ui.look.refresh()
	await frames(1)


func _test_touch_screen() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	var term := HoloTerminal.new(false, "HALL TERMINAL")
	var tv := TouchScreen.new(term, Vector2i(1280, 720), Vector2(2.4, 1.35))
	tv.position = Vector3(0, 0, -2.0)
	add_child(tv)
	HudSlots.register_holo_channel("_tv", "TV", func(glass: bool) -> Control:
		var l := Label.new()
		l.text = "glass" if glass else "plain"
		return l, 1)
	term.show_channel("_tv")
	await frames(3)
	check(term.content.find_child("Channel", false, false) is Label
			and (term.content.find_child("Channel", false, false) as Label).text == "plain",
			"a TV shows the wrist screen's channels, opaque")
	check(term.tabs.find_child("Close", false, false) == null and term.tabs.find_child("Ch__tv", false, false) != null,
			"a TV's terminal has the tabs but no CLOSE")
	check(tv.is_aimed() and TouchScreen.current() == tv, "looking at a screen within reach aims at it")
	check(tv.pointer.visible and tv.pointer_px.distance_to(Vector2(640, 360)) < 2.0, "the pointer sits where the view meets it")
	check(HudSlots.pointer_claimed() and not HudSlots.pointer_claimed(tv._claim_id()), "an aimed screen claims the pointer")
	cam.rotation.y = deg_to_rad(90)
	await frames(3)
	check(not tv.is_aimed() and not tv.pointer.visible and not HudSlots.pointer_claimed(), "looking away lets it go")
	cam.rotation.y = 0.0
	tv.position.z = -6.0
	await frames(3)
	check(not tv.is_aimed(), "out of reach, it isn't aimed")
	tv.queue_free()
	HudSlots.unregister_holo_channel("_tv")

	var presses: Array = []
	var holds: Array = []
	var panel := TouchScreen.buttons([{id = "power", label = "SHORE POWER", toggle = true},
			{id = "up", label = "RAISE", hold = true}], Vector2(0.3, 0.2))
	panel.position = Vector3(0, 0, -1.0)
	panel.button_pressed.connect(func(id: String, on: bool) -> void: presses.append([id, on]))
	panel.button_held.connect(func(id: String, down: bool) -> void: holds.append([id, down]))
	add_child(panel)
	await frames(3)
	check(panel.is_aimed(), "an LED button panel is aimed at like a TV")
	var power := panel.button("power")
	var at := power.get_global_rect().get_center()
	panel.click_at(at)
	await frames(1)
	check(presses == [["power", true]] and power.button_pressed, "left click turns a toggle on")
	panel.click_at(at)
	await frames(1)
	check(presses.back() == ["power", false] and not power.button_pressed, "and off again")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	panel.pointer_px = panel.button("up").get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = panel.pointer_px
	panel.viewport.push_input(motion, true)
	panel._input(click)
	check(holds == [["up", true]], "a hold button says when it's pressed down")
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	panel._input(release)
	check(holds.back() == ["up", false], "and when it's let go")
	var before := presses.size()
	panel.set_on("power", true)
	check(power.button_pressed and presses.size() == before, "set_on lights a toggle without a press")
	check(power.get_theme_stylebox("pressed") != power.get_theme_stylebox("normal"), "LED buttons light up when on")
	panel.queue_free()
	cam.queue_free()
	await frames(2)
	check(not HudSlots.pointer_claimed(), "a freed screen gives the pointer back")


class Hinted extends Node3D:
	func look_hint() -> Dictionary:
		return {"title": "Shore power", "text": "Off", "keys": [[Keys.INTERACT, "Push it"], ["LMB", "Switch on"]]}


class Walker extends CharacterBody3D:
	func _physics_process(delta: float) -> void:
		velocity.x = 3.0
		velocity.y -= 9.0 * delta
		move_and_slide()


class Closing extends Control:
	signal close_requested
