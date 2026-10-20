class_name GamesPanel
extends Control
## New game and saved games, over the main menu: a name for a new yard and Begin, then the
## saved games newest first, each with Load and Delete (Delete asks once more). Begin and
## Load go to the game's start scene (Menu.start()). Laid out like Void Salvage's menu.

signal closed

var name_field: LineEdit
var list_box: VBoxContainer


func _ready() -> void:
	theme = BsxTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := BsxTheme.title("GAMES", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_spacer(8))
	box.add_child(_field_label("New game"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	name_field = LineEdit.new()
	name_field.name = "GameName"
	name_field.placeholder_text = "Name your yard"
	name_field.text = "Yard %d" % (Saves.games().size() + 1)
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_field.custom_minimum_size.y = 42
	name_field.text_submitted.connect(func(_t: String) -> void: begin())
	row.add_child(name_field)
	var go := BsxTheme.button("Begin", begin)
	go.name = "Begin"
	go.disabled = not _can_start()
	row.add_child(go)

	box.add_child(_spacer(8))
	box.add_child(_field_label("Saved games"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.name = "SavedGames"
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(list_box)
	fill()

	box.add_child(_spacer(8))
	var back := BsxTheme.button("Back", close)
	back.name = "Back"
	box.add_child(back)
	name_field.grab_focus.call_deferred()
	name_field.select_all.call_deferred()


## Rebuilds the saved games list.
func fill() -> void:
	for child in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()
	var games := Saves.games()
	if games.is_empty():
		list_box.add_child(BsxTheme.muted("No saved games yet."))
	for g: Dictionary in games:
		var row := HBoxContainer.new()
		row.name = "Game_" + str(g.slot).validate_node_name()
		row.add_theme_constant_override("separation", 10)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		var label := Label.new()
		label.text = g.name
		text.add_child(label)
		var when := BsxTheme.muted("saved %s" % Time.get_datetime_string_from_unix_time(g.saved_at, true).left(16))
		when.add_theme_font_size_override("font_size", 13)
		text.add_child(when)
		row.add_child(text)
		var load_button := BsxTheme.button("Load", func() -> void: load_game(g.slot))
		load_button.name = "Load"
		load_button.custom_minimum_size.x = 96
		load_button.disabled = not _can_start()
		row.add_child(load_button)
		var del := BsxTheme.button("Delete", func() -> void: pass)
		del.name = "Delete"
		del.custom_minimum_size.x = 96
		del.pressed.connect(func() -> void: _ask_delete(del, g.slot))
		row.add_child(del)
		list_box.add_child(row)


func begin() -> void:
	if not _can_start():
		return
	Saves.new_game(name_field.text)
	_go()


func load_game(slot: String) -> void:
	if _can_start() and Saves.continue_game(slot) == OK:
		_go()


func close() -> void:
	closed.emit()
	queue_free()


## First press arms the button, the second deletes.
func _ask_delete(button: Button, slot: String) -> void:
	if not button.has_meta("armed"):
		button.set_meta("armed", true)
		button.text = "Sure?"
		button.add_theme_color_override("font_color", BsxTheme.WARN)
		return
	Saves.delete(slot)
	fill()


func _go() -> void:
	var start := Menu.start()
	Router.goto(start.scene, start.args)


func _can_start() -> bool:
	var start := Menu.start()
	return not start.is_empty() and Router.has_scene(start.scene)


func _field_label(text: String) -> Label:
	var l := BsxTheme.muted(text)
	l.add_theme_color_override("font_color", Color(BsxTheme.ACCENT, 0.85))
	return l


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c
