extends PanelContainer
## One section of the design console as a docked panel, after Photoshop's (beenster, 20 Nov:
## "look at Photoshop interface to see how to move and hide sections"): a title bar with
## buttons to move it up or down its dock, across to the other dock, fold it to its title and
## hide it (the console's WINDOW menu shows it again), and a grip along its foot to drag it
## taller or shorter against the panel below.

const T := preload("res://modules/ui/api/terminal_kit.gd")
## How tall the foot grip is, px.
const GRIP := 7

signal move_requested(id: String, by: int)
signal swap_requested(id: String)
signal hide_requested(id: String)
signal collapse_changed(id: String, collapsed: bool)
## The grip was dragged `dy` px (positive: taller).
signal height_dragged(id: String, dy: float)

var id := ""
var title := ""
var body: Control
var collapsed := false
## Its share of its dock's height (the docks stretch their panels by it).
var ratio := 1.0:
	set(v):
		ratio = clampf(v, 0.15, 12.0)
		size_flags_stretch_ratio = ratio

var _box: VBoxContainer
var _fold: Button
var _grip: Control
var _drag_from := -1.0


func setup(p_id: String, p_title: String, p_body: Control) -> void:
	id = p_id
	title = p_title
	body = p_body
	name = "Dock_" + id
	add_theme_stylebox_override("panel", T.box(T.KIOSK, T.EDGE, 1, 6.0))
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 2)
	add_child(_box)
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", 2)
	_box.add_child(head)
	_fold = _small("v", "Fold to its title (click again to open)")
	_fold.name = "Fold"
	_fold.pressed.connect(func() -> void: set_collapsed(not collapsed))
	head.add_child(_fold)
	var t := T.label(title, "display_bold", 13, T.CYAN)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb and mb.pressed and mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
			set_collapsed(not collapsed))
	head.add_child(t)
	for spec: Array in [["Up", "^", "Move up the dock", func() -> void: move_requested.emit(id, -1)],
			["Down", "v", "Move down the dock", func() -> void: move_requested.emit(id, 1)],
			["Swap", "<>", "Move to the other side", func() -> void: swap_requested.emit(id)],
			["Hide", "X", "Hide (WINDOW menu shows it again)", func() -> void: hide_requested.emit(id)]]:
		var b := _small(str(spec[1]), str(spec[2]))
		b.name = str(spec[0])
		b.pressed.connect(spec[3])
		head.add_child(b)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_child(body)
	_grip = Control.new()
	_grip.name = "Grip"
	_grip.custom_minimum_size.y = GRIP
	_grip.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	_grip.tooltip_text = "Drag to make this panel taller or shorter"
	_grip.draw.connect(func() -> void:
		var w := _grip.size.x
		for i in 3:
			_grip.draw_line(Vector2(w * 0.5 - 14, 2 + i * 2), Vector2(w * 0.5 + 14, 2 + i * 2), Color(T.EDGE, 0.9), 1.0))
	_grip.gui_input.connect(_grip_input)
	_box.add_child(_grip)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ratio = ratio
	set_collapsed(collapsed)


func set_collapsed(on: bool) -> void:
	var was := collapsed
	collapsed = on
	body.visible = not on
	_grip.visible = not on
	_fold.text = ">" if on else "v"
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN if on else Control.SIZE_EXPAND_FILL
	if was != on:
		collapse_changed.emit(id, on)


func _grip_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		_drag_from = mb.global_position.y if mb.pressed else -1.0
		_grip.accept_event()
	var mm := e as InputEventMouseMotion
	if mm and _drag_from >= 0.0:
		var dy := mm.global_position.y - _drag_from
		_drag_from = mm.global_position.y
		height_dragged.emit(id, dy)
		_grip.accept_event()


func _small(text: String, tip: String) -> Button:
	var b := T.button(text, false, 11)
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(22, 0)
	for st: String in ["normal", "hover", "pressed"]:
		var sb := b.get_theme_stylebox(st)
		if sb is StyleBoxFlat:
			var s := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			s.content_margin_top = 1
			s.content_margin_bottom = 1
			s.content_margin_left = 4
			s.content_margin_right = 4
			b.add_theme_stylebox_override(st, s)
	return b
