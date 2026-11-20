extends PanelContainer
## The HELP tab (HelpBus): the pages down the left, a search box over them, the chosen page on
## the right in readable type (headings, bullets, tips, and the keys as key caps).

const T := preload("res://modules/ui/api/terminal_kit.gd")

const BG := Color(0.02, 0.05, 0.09)
const CARD := Color(0.05, 0.1, 0.16)
const ROW_ON := Color(0.1, 0.2, 0.3)
const LINE := Color(0.2, 0.45, 0.65, 0.6)
const TIP_BG := Color(0.12, 0.08, 0.03)

var bus: HelpBus
var px_per_m := 150.0
var fs := 15
## The page shown.
var current := ""
var query := ""

var _list: VBoxContainer
var _page: VBoxContainer
var _scroll: ScrollContainer
var _search: LineEdit
## A page that is a control of its own, kept while it is the page shown (so a search typed
## meanwhile doesn't reset it).
var _custom: Control
var _custom_id := ""


func setup(help_bus: HelpBus, density: float) -> void:
	bus = help_bus
	px_per_m = density
	fs = maxi(12, int(px_per_m * 0.1))
	name = "Help"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", T.box(BG, Color.TRANSPARENT, 0, fs * 0.6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(fs * 1.0))
	add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = fs * 17
	left.add_theme_constant_override("separation", int(fs * 0.3))
	row.add_child(left)
	left.add_child(_label("HELP", "display_bold", fs + 8, T.ORANGE))
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "Search help"
	_search.clear_button_enabled = true
	_search.add_theme_font_size_override("font_size", fs)
	_search.text_changed.connect(set_query)
	left.add_child(_search)
	_list = VBoxContainer.new()
	_list.name = "Topics"
	_list.add_theme_constant_override("separation", 2)
	left.add_child(_list)
	var page_box := PanelContainer.new()
	page_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_box.add_theme_stylebox_override("panel", T.box(CARD, LINE, 1, fs * 1.0))
	row.add_child(page_box)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_box.add_child(_scroll)
	_page = VBoxContainer.new()
	_page.name = "Page"
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", int(fs * 0.45))
	_scroll.add_child(_page)
	bus.topics_changed.connect(refresh)
	var all := bus.topics()
	current = str(all[0].id) if not all.is_empty() else ""
	refresh()


func refresh() -> void:
	var shown := bus.search(query) if query.strip_edges() != "" else bus.topics()
	if not shown.any(func(t: Dictionary) -> bool: return str(t.id) == current) and not shown.is_empty():
		current = str(shown[0].id)
	_fill_list(shown)
	_fill_page()


func show_topic(id: String) -> void:
	current = id
	refresh()
	_scroll.scroll_vertical = 0


func set_query(q: String) -> void:
	query = q
	if _search and _search.text != q:
		_search.text = q
	refresh()


func _fill_list(shown: Array[Dictionary]) -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if shown.is_empty():
		_list.add_child(_label("Nothing matches \"%s\"." % query, "body", fs, T.DIM, true))
		return
	for t in shown:
		var id := str(t.id)
		var on := id == current
		var b := Button.new()
		b.name = "Topic_" + id
		b.text = str(t.title)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", T.font("body_medium"))
		b.add_theme_font_size_override("font_size", fs + 1)
		b.add_theme_color_override("font_color", T.TEXT if on else T.DIM)
		b.add_theme_color_override("font_hover_color", T.TEXT)
		var normal := T.box(ROW_ON if on else Color(0, 0, 0, 0), T.ORANGE if on else Color.TRANSPARENT, 0, fs * 0.4)
		if on:
			normal.border_width_left = 3
			normal.border_color = T.ORANGE
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", T.box(Color(1, 1, 1, 0.06), Color.TRANSPARENT, 0, fs * 0.4))
		b.add_theme_stylebox_override("pressed", normal)
		b.pressed.connect(show_topic.bind(id))
		_list.add_child(b)


func _fill_page() -> void:
	for c in _page.get_children():
		_page.remove_child(c)
		if c != _custom:
			c.queue_free()
	var t := bus.topic(current)
	if _custom and (_custom_id != current or t.is_empty()):
		_custom.queue_free()
		_custom = null
		_custom_id = ""
	if t.is_empty():
		return
	_page.add_child(_label(str(t.title).to_upper(), "display_bold", fs + 12, T.TEXT, true))
	if t.has("make"):
		if _custom == null:
			_custom = (t.make as Callable).call(px_per_m) as Control
			_custom_id = current
		if _custom:
			_page.add_child(_custom)
			if _custom.has_method("set_query"):
				_custom.call("set_query", query)
		return
	for line in bus.page_text(current).split("\n"):
		var s := line.strip_edges()
		if s == "":
			continue
		if s.begins_with("# "):
			var h := _label(s.substr(2).to_upper(), "display_bold", fs + 3, T.ORANGE, true)
			h.custom_minimum_size.y = fs * 2.0
			h.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			_page.add_child(h)
		elif s.begins_with("- "):
			_page.add_child(_bullet(s.substr(2)))
		elif s.begins_with("> "):
			var tip := PanelContainer.new()
			tip.add_theme_stylebox_override("panel", T.box(TIP_BG, T.ORANGE, 1, fs * 0.6))
			tip.add_child(_label(s.substr(2), "body_medium", fs + 1, Color(1.0, 0.85, 0.65), true))
			_page.add_child(tip)
		elif s.begins_with("= "):
			_page.add_child(_key_row(s.substr(2)))
		else:
			_page.add_child(_label(s, "body", fs + 2, T.TEXT, true))


func _bullet(text: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(fs * 0.6))
	var dot := _label("▸", "body_medium", fs + 1, T.ORANGE)
	dot.custom_minimum_size.x = fs * 0.8
	dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(dot)
	h.add_child(_label(text, "body", fs + 1, T.TEXT, true))
	return h


## "Key|what it does": a key cap and its label.
func _key_row(spec: String) -> Control:
	var parts := spec.split("|")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(fs * 0.8))
	var cap := PanelContainer.new()
	cap.custom_minimum_size.x = fs * 7.5
	cap.add_theme_stylebox_override("panel", T.box(Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.25), 1, fs * 0.25))
	var k := _label(parts[0], "mono_bold", fs, T.TEXT)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(k)
	h.add_child(cap)
	h.add_child(_label(parts[1] if parts.size() > 1 else "", "body", fs + 1, T.TEXT, true))
	return h


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
