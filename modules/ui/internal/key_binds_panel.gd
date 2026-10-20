class_name KeyBindsPanel
extends VBoxContainer
## Every key the game uses, grouped under headings (Movement, Actions, then each module's
## own), each with its key on a button: press it, then press the new key (Esc cancels).
## A key used by two actions shows in orange with the other action named. Used by Settings >
## Key binds and the wrist screen's Key binds channel.

var rows: Dictionary = {}   # action -> Button
var listening := ""
var _notes: Dictionary = {}  # action -> Label


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 16)  # room for the scroll bar
	scroll.add_child(pad)
	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	pad.add_child(list)
	var group := ""
	for a: Dictionary in Keys.actions():
		if a.group != group:
			group = a.group
			var head := BsxTheme.muted(group)
			head.add_theme_color_override("font_color", Color(BsxTheme.ACCENT, 0.85))
			if list.get_child_count() > 0:
				list.add_child(_gap(6))
			list.add_child(head)
		var row := HBoxContainer.new()
		row.name = "Row_" + str(a.action).validate_node_name()
		row.add_theme_constant_override("separation", 10)
		var label := Label.new()
		label.text = a.label
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var note := BsxTheme.muted("")
		note.add_theme_font_size_override("font_size", 13)
		row.add_child(note)
		_notes[a.action] = note
		var key := BsxTheme.button("", func() -> void: listen(a.action))
		key.name = "Key"
		key.custom_minimum_size = Vector2(130, 34)
		row.add_child(key)
		rows[a.action] = key
		list.add_child(row)
	var reset := BsxTheme.button("Reset all keys", func() -> void:
		Keys.reset_all()
		refresh())
	reset.name = "ResetAll"
	add_child(reset)
	refresh()


## Waits for the next key press and puts `action` on it.
func listen(action: String) -> void:
	listening = action
	refresh()
	rows[action].text = "press a key..."


## Puts the action being listened for on `key` (what a key press does while listening).
func press(key: Key) -> void:
	if listening == "":
		return
	var action := listening
	listening = ""
	if key != KEY_ESCAPE or action == Keys.CANCEL:
		Keys.rebind(action, key)
	refresh()


func refresh() -> void:
	for action: String in rows:
		var b: Button = rows[action]
		b.text = Keys.key_name(action)
		var clash := Keys.clashes(action)
		var note: Label = _notes[action]
		note.text = "also " + ", ".join(Array(clash).map(func(c): return Keys.label_of(c))) if clash.size() > 0 else ""
		b.add_theme_color_override("font_color", BsxTheme.WARN if clash.size() > 0 else BsxTheme.TEXT)


func _input(event: InputEvent) -> void:
	if listening == "" or not is_visible_in_tree():
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		press(key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
		get_viewport().set_input_as_handled()


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
