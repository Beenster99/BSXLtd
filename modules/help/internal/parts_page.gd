extends VBoxContainer
## Help's parts list: every building part (components, rooms, doors, the hull's frame, plates
## and glass, wires and pipes) down the left, filtered by group and by the words typed in
## Help's search; the part picked on the right with every number it has, where it goes and a
## row for every size and grade it comes in.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const Parts := preload("res://modules/help/internal/parts_data.gd")

var data: Parts
var fs := 15
var group := ""
var query := ""
var picked := ""

var _groups: HFlowContainer
var _count: Label
var _list: VBoxContainer
var _detail: VBoxContainer


func setup(catalog: DesignCatalog, px_per_m: float) -> void:
	data = Parts.new(catalog)
	fs = maxi(12, int(px_per_m * 0.1))
	name = "Parts"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", int(fs * 0.5))
	add_child(_label("Every part you can build with: components, rooms, doors, the hull's frame, plates and glass, wires and pipes. Type in Help's search box to find a part or a number (\"medbay\", \"airtight\", \"kN\"); pick one to see all it has and every size and grade it comes in.", "body", fs + 1, T.TEXT, true))
	_groups = HFlowContainer.new()
	_groups.name = "PartGroups"
	_groups.add_theme_constant_override("h_separation", int(fs * 0.3))
	_groups.add_theme_constant_override("v_separation", int(fs * 0.3))
	add_child(_groups)
	_count = _label("", "body", fs, T.DIM)
	add_child(_count)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(fs * 1.0))
	add_child(row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(fs * 19, fs * 36)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "PartList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 1)
	scroll.add_child(_list)
	_detail = VBoxContainer.new()
	_detail.name = "PartDetail"
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", int(fs * 0.3))
	row.add_child(_detail)
	refresh()


## The words typed in Help's search box narrow the list.
func set_query(q: String) -> void:
	query = q.strip_edges()
	refresh()


func set_group(g: String) -> void:
	group = g
	refresh()


func pick(id: String) -> void:
	picked = id
	refresh()


func shown() -> Array[Dictionary]:
	return data.find(query, group)


func refresh() -> void:
	var list := shown()
	if not list.any(func(e: Dictionary) -> bool: return str(e.id) == picked):
		picked = str(list[0].id) if not list.is_empty() else ""
	_fill_groups()
	_count.text = "%d of %d parts%s" % [list.size(), data.entries().size(),
			(" matching \"%s\"" % query) if query != "" else ""]
	_fill_list(list)
	_fill_detail()


func _fill_groups() -> void:
	_clear(_groups)
	var all := _chip("All", group == "")
	all.name = "PartGroup_all"
	all.pressed.connect(set_group.bind(""))
	_groups.add_child(all)
	for g in data.groups():
		var n := data.find(query, g).size()
		var b := _chip("%s  %d" % [g, n], g == group)
		b.name = "PartGroup_" + g.validate_node_name().replace(" ", "_")
		b.disabled = n == 0 and g != group
		b.pressed.connect(set_group.bind(g))
		_groups.add_child(b)


func _fill_list(list: Array[Dictionary]) -> void:
	_clear(_list)
	var last := ""
	for e in list:
		if str(e.group) != last and group == "":
			last = str(e.group)
			var h := _label(last.to_upper(), "display_bold", fs - 1, T.ORANGE)
			h.custom_minimum_size.y = fs * 1.8
			h.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			_list.add_child(h)
		var on := str(e.id) == picked
		var b := Button.new()
		b.name = "Part_" + str(e.id).validate_node_name().replace(".", "_")
		b.text = str(e.name)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", T.font("body"))
		b.add_theme_font_size_override("font_size", fs)
		b.add_theme_color_override("font_color", T.TEXT if on else T.DIM)
		b.add_theme_color_override("font_hover_color", T.TEXT)
		var box := T.box(Color(0.1, 0.2, 0.3) if on else Color(0, 0, 0, 0), Color.TRANSPARENT, 0, fs * 0.25)
		if on:
			box.border_width_left = 3
			box.border_color = T.ORANGE
		b.add_theme_stylebox_override("normal", box)
		b.add_theme_stylebox_override("pressed", box)
		b.add_theme_stylebox_override("hover", T.box(Color(1, 1, 1, 0.06), Color.TRANSPARENT, 0, fs * 0.25))
		b.pressed.connect(pick.bind(str(e.id)))
		_list.add_child(b)
	if list.is_empty():
		_list.add_child(_label("No part matches \"%s\"." % query, "body", fs, T.DIM, true))


func _fill_detail() -> void:
	_clear(_detail)
	var e := data.entry(picked)
	if e.is_empty():
		return
	_detail.add_child(_label(str(e.name).to_upper(), "display_bold", fs + 6, T.TEXT, true))
	_detail.add_child(_label(str(e.group), "body_medium", fs, T.ORANGE))
	if str(e.get("text", "")) != "" and not (e.attrs as Array).any(func(a: Array) -> bool: return str(a[1]) == str(e.text)):
		_detail.add_child(_label(str(e.text), "body", fs + 1, T.TEXT, true))
	var grid := GridContainer.new()
	grid.name = "Attributes"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(fs * 1.0))
	grid.add_theme_constant_override("v_separation", int(fs * 0.2))
	for a: Array in e.attrs:
		var k := _label(str(a[0]), "body_medium", fs, T.DIM)
		k.custom_minimum_size.x = fs * 11
		k.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(k)
		var v := _label(str(a[1]), "body", fs + 1, T.TEXT, true)
		v.custom_minimum_size.x = fs * 30
		grid.add_child(v)
	_detail.add_child(grid)
	var rows: Array = e.rows
	if rows.is_empty() or (e.cols as Array).is_empty():
		return
	_detail.add_child(_label("EVERY SIZE AND GRADE  (%d)" % rows.size() if str(e.id).find(".") < 0 else "IN EACH FRAME WEIGHT",
			"display_bold", fs + 1, T.ORANGE))
	var t := GridContainer.new()
	t.name = "Variants"
	t.columns = (e.cols as Array).size()
	t.add_theme_constant_override("h_separation", int(fs * 0.9))
	t.add_theme_constant_override("v_separation", 1)
	for c in e.cols:
		t.add_child(_label(str(c).to_upper(), "display_bold", fs - 2, T.DIM))
	for r: Array in rows:
		for i in r.size():
			t.add_child(_label(str(r[i]), "mono_medium" if i > 0 else "mono_bold", fs - 2, T.TEXT if i > 0 else T.ORANGE_HI))
	_detail.add_child(t)


func _chip(text: String, on: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", T.font("body_medium"))
	b.add_theme_font_size_override("font_size", fs - 1)
	b.add_theme_color_override("font_color", T.TEXT if on else T.DIM)
	b.add_theme_color_override("font_hover_color", T.TEXT)
	b.add_theme_color_override("font_disabled_color", Color(T.DIM, 0.4))
	var box := T.box(Color(0.1, 0.2, 0.3) if on else Color(1, 1, 1, 0.05), T.ORANGE if on else Color.TRANSPARENT, 1 if on else 0, fs * 0.35)
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("pressed", box)
	b.add_theme_stylebox_override("disabled", box)
	b.add_theme_stylebox_override("hover", T.box(Color(1, 1, 1, 0.1), Color.TRANSPARENT, 0, fs * 0.35))
	return b


func _label(text: String, face: String, size: int, colour: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", T.font(face))
	l.add_theme_font_size_override("font_size", maxi(8, size))
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
