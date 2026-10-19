extends Control
## Main menu, laid out like Void Salvage's: the name and version centred over one column of
## buttons. The entries modules registered with Menu come first (a group's entries under
## its heading, like Void Salvage's field labels), then Graphics (Void Salvage's graphics
## screen), Settings and Exit Game.

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
	if entries.is_empty():
		var none := BsxTheme.muted("Nothing to play yet in this build.")
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry_box.add_child(none)
	var headed := {}
	for e in entries:
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
