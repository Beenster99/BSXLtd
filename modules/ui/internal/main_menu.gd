extends Control
## Main menu, laid out like Void Salvage's: the name and version centred over one column of
## buttons. Continue (the latest saved game), New Game and Load Game come first, like Void
## Salvage's Play Solo; all three go to Menu.start() (the yard). New Game and Load Game open
## the games panel over the menu. Then any other entries modules registered with Menu (a group's entries under its heading,
## like Void Salvage's field labels), then Graphics (Void Salvage's graphics screen),
## Settings and Exit Game.

var entry_box: VBoxContainer
var _center: CenterContainer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = BsxTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BsxTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
	box.add_theme_constant_override("separation", 14)
	_center.add_child(box)

	var title := BsxTheme.title("BSX LTD")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := BsxTheme.muted("ship fitting and maintenance  -  version %s" % BuildInfo.label().trim_prefix("v"))
	sub.name = "Version"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(_spacer(18))

	entry_box = VBoxContainer.new()
	entry_box.add_theme_constant_override("separation", 14)
	box.add_child(entry_box)
	box.add_child(_spacer(8))
	var graphics := BsxTheme.button("Graphics", _open_graphics)
	graphics.name = "Graphics"
	box.add_child(graphics)
	box.add_child(BsxTheme.button("Settings", func(): Router.goto(UiBus.SETTINGS)))
	var exit := BsxTheme.button("Exit Game", func(): get_tree().quit())
	exit.name = "ExitGame"
	box.add_child(exit)

	Menu.entries_changed.connect(_fill_entries)
	_fill_entries()


func _fill_entries() -> void:
	for child in entry_box.get_children():
		entry_box.remove_child(child)  # now, so the new buttons can take the same names
		child.queue_free()
	var entries := Menu.entries()
	var start := Menu.start()
	if not start.is_empty():
		var playable := Router.has_scene(start.scene)
		var games := Saves.games()
		if not games.is_empty():
			var latest: Dictionary = games[0]
			var cont := BsxTheme.button("Continue  -  %s" % latest.name, func() -> void: _continue(latest.slot))
			cont.name = "Continue"
			cont.custom_minimum_size.y = 52
			cont.disabled = not playable
			entry_box.add_child(cont)
		var go := BsxTheme.button("New Game", func() -> void: _open_games(true))
		go.name = "Start"
		go.custom_minimum_size.y = 52 if games.is_empty() else 0.0
		go.disabled = not playable
		entry_box.add_child(go)
		if not games.is_empty():
			var load_button := BsxTheme.button("Load Game", func() -> void: _open_games(false))
			load_button.name = "LoadGame"
			entry_box.add_child(load_button)
	elif entries.is_empty():
		var none := BsxTheme.muted("Nothing to play yet in this build.")
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry_box.add_child(none)
	var headed := {}
	for e in entries:
		if not start.is_empty() and e.scene == start.scene:
			continue  # Start already goes there
		var group: String = e.get("group", "")
		if group != "" and not headed.has(group):
			headed[group] = true
			var head := BsxTheme.muted(group)
			head.name = "Group_" + group.validate_node_name()
			head.add_theme_color_override("font_color", Color(BsxTheme.ACCENT, 0.85))
			entry_box.add_child(head)
		var args: Dictionary = e.get("args", {})
		var b := BsxTheme.button(e.label, func(): Router.goto(e.scene, args))
		b.name = e.id
		b.disabled = not Router.has_scene(e.scene)
		entry_box.add_child(b)


func _continue(slot: String) -> void:
	var start := Menu.start()
	if Saves.continue_game(slot) == OK:
		Router.goto(start.scene, start.args)


## The games panel over the menu: New Game puts the cursor in the name, Load Game is the same
## panel (its list of saved games is under the name).
func _open_games(_new: bool) -> void:
	_center.visible = false
	var panel := GamesPanel.new()
	panel.name = "GamesPanel"
	panel.closed.connect(func() -> void:
		_center.visible = true
		_fill_entries())
	add_child(panel)


## The graphics settings over the menu (the menu hides until it's closed), as in Void Salvage.
func _open_graphics() -> void:
	_center.visible = false
	var panel := GraphicsPanel.new()
	panel.name = "GraphicsPanel"
	panel.closed.connect(func() -> void: _center.visible = true)
	add_child(panel)


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c
