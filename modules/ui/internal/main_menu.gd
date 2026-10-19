extends Control
## Main menu: the title, the entries modules registered with Menu, then Settings and Quit.

var entry_box: VBoxContainer


func _ready() -> void:
	theme = BsxTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BsxTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 120)
	add_child(column)
	column.add_child(BsxTheme.title("BSX Ltd"))
	column.add_child(BsxTheme.muted("Ship fitting and maintenance contractors"))
	column.add_child(_spacer(24))
	entry_box = VBoxContainer.new()
	entry_box.add_theme_constant_override("separation", 10)
	column.add_child(entry_box)
	column.add_child(_spacer(12))
	column.add_child(BsxTheme.button("Settings", func(): Router.goto(UiBus.SETTINGS)))
	column.add_child(BsxTheme.button("Quit", func(): get_tree().quit()))

	var version := BsxTheme.muted(BuildInfo.label())
	add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)

	Menu.entries_changed.connect(_fill_entries)
	_fill_entries()


func _fill_entries() -> void:
	for child in entry_box.get_children():
		child.queue_free()
	var entries := Menu.entries()
	if entries.is_empty():
		entry_box.add_child(BsxTheme.muted("Nothing to play yet in this build."))
	for e in entries:
		var b := BsxTheme.button(e.label, func(): Router.goto(e.scene))
		b.name = e.id
		b.disabled = not Router.has_scene(e.scene)
		entry_box.add_child(b)


func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	return c
