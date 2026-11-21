extends PanelContainer
## The HELP tab (HelpBus): the chapters down the left in their groups, a search box over them,
## the chosen chapter on the right in readable type: headings, bullets, tips, the keys as key
## caps, numbered steps, the screen's picture with its numbered callouts, and buttons that open
## a screen or another chapter.

const T := preload("res://modules/ui/api/terminal_kit.gd")

const BG := Color(0.02, 0.05, 0.09)
const CARD := Color(0.05, 0.1, 0.16)
const ROW_ON := Color(0.1, 0.2, 0.3)
const LINE := Color(0.2, 0.45, 0.65, 0.6)
const TIP_BG := Color(0.12, 0.08, 0.03)
const STEP_BG := Color(0.07, 0.13, 0.2)
const SHOTS_DIR := "res://modules/help/shots"

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
	var list_scroll := ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.name = "Topics"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	list_scroll.add_child(_list)
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
	var asked := bus.take_pending()
	if asked != "" and not bus.topic(asked).is_empty():
		current = asked
	refresh()


func refresh() -> void:
	var shown := bus.search(query) if query.strip_edges() != "" else bus.topics()
	if not shown.any(func(t: Dictionary) -> bool: return str(t.id) == current) and not shown.is_empty():
		current = str(shown[0].id)
	_fill_list(shown)
	_fill_page()


func show_topic(id: String) -> void:
	current = id
	bus.last_topic = id
	refresh()
	_scroll.scroll_vertical = 0


func set_query(q: String) -> void:
	query = q
	if _search and _search.text != q:
		_search.text = q
	refresh()


## The buttons in the topic list (not the group headings).
func topic_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for c in _list.get_children():
		if c is Button:
			out.append(c)
	return out


func _fill_list(shown: Array[Dictionary]) -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if shown.is_empty():
		_list.add_child(_label("Nothing matches \"%s\"." % query, "body", fs, T.DIM, true))
		return
	var group := ""
	var searching := query.strip_edges() != ""
	for t in shown:
		var id := str(t.id)
		var on := id == current
		var g := str(t.get("group", ""))
		if not searching and g != group and g != "":
			group = g
			var gl := _label(g.to_upper(), "mono_bold", fs - 2, T.ORANGE)
			gl.custom_minimum_size.y = fs * 1.9
			gl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			_list.add_child(gl)
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
			tip.add_child(_label(s.substr(2).replace("**", ""), "body_medium", fs + 1, Color(1.0, 0.85, 0.65), true))
			_page.add_child(tip)
		elif s.begins_with("=> "):
			_page.add_child(_link(s.substr(3), true))
		elif s.begins_with("-> "):
			_page.add_child(_link(s.substr(3), false))
		elif s.begins_with("= "):
			_page.add_child(_key_row(s.substr(2)))
		elif s.begins_with("! "):
			var shot := _shot(s.substr(2).strip_edges())
			if shot:
				_page.add_child(shot)
		elif s.begins_with("@ "):
			_page.add_child(_callout(s.substr(2)))
		elif _step_re.search(s):
			var m := _step_re.search(s)
			_page.add_child(_step(m.get_string(1), s.substr(m.get_end())))
		else:
			_page.add_child(_rich(s, fs + 2))


var _step_re := RegEx.create_from_string("^(\\d{1,2})\\. ")


## A chapter's picture of its screen, as wide as the page.
func _shot(id: String) -> Control:
	var path := SHOTS_DIR.path_join(id + ".webp")
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var frame := PanelContainer.new()
	frame.name = "Shot_" + id
	frame.add_theme_stylebox_override("panel", T.box(Color(0, 0, 0, 0.3), LINE, 1, 2))
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(r)
	# EXPAND_FIT_WIDTH_PROPORTIONAL sizes by height; keep the height to the page's width.
	frame.resized.connect(func() -> void:
		var w := frame.size.x - 4.0
		var h := w * float(tex.get_height()) / maxf(1.0, float(tex.get_width()))
		if absf(r.custom_minimum_size.y - h) > 1.0:
			r.custom_minimum_size = Vector2(0, h))
	return frame


func _badge(n: String, colour: Color, text_colour: Color) -> Control:
	var b := PanelContainer.new()
	var st := T.box(colour, Color.TRANSPARENT, 0, 0)
	st.set_corner_radius_all(int(fs * 0.8))
	st.content_margin_left = fs * 0.45
	st.content_margin_right = fs * 0.45
	b.add_theme_stylebox_override("panel", st)
	b.custom_minimum_size = Vector2(fs * 1.6, fs * 1.6)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var l := _label(n, "mono_bold", fs, text_colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	return b


## "3|PLACE ORDER buys ...": the picture's callout 3 (an orange ring on the picture).
func _callout(spec: String) -> Control:
	var i := spec.find("|")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(fs * 0.6))
	h.add_child(_badge(spec.left(i) if i > 0 else "•", T.ORANGE, Color(0.05, 0.03, 0.0)))
	h.add_child(_rich(spec.substr(i + 1) if i > 0 else spec, fs + 1))
	return h


## A numbered step of a workflow.
func _step(n: String, text: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(STEP_BG, Color.TRANSPARENT, 0, fs * 0.5))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(fs * 0.7))
	p.add_child(h)
	h.add_child(_badge(n, T.CYAN, Color(0.02, 0.05, 0.09)))
	h.add_child(_rich(text, fs + 1))
	return p


## "orders.book|Open Parts orders": a button that puts a wrist screen up (`screen`), or with
## `screen` false "contracts|Your first contract" one that opens another chapter.
func _link(spec: String, screen: bool) -> Control:
	var parts := spec.split("|")
	var target := parts[0].strip_edges()
	var b := T.button(("▶  " if screen else "→  ") + (parts[1] if parts.size() > 1 else target), screen, fs + 2)
	b.name = ("Open_" if screen else "Goto_") + target.validate_node_name()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if screen:
		b.disabled = HudSlots.holo_channel(target).is_empty()
		b.pressed.connect(open_screen.bind(target))
	else:
		b.disabled = bus.topic(target).is_empty()
		b.pressed.connect(show_topic.bind(target))
	return b


## Puts a wrist screen up: in the terminal this page is on (the wrist, a TV), else the wrist.
func open_screen(channel: String) -> void:
	var n: Node = get_parent()
	while n and not n is HoloTerminal:
		n = n.get_parent()
	if n:
		(n as HoloTerminal).show_channel(channel)
	else:
		HudSlots.open_holo(channel)


## Text where **words** are bold (a button's or a figure's name).
func _rich(text: String, size: int) -> Control:
	if not text.contains("**"):
		return _label(text, "body", size, T.TEXT, true)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", T.font("body"))
	r.add_theme_font_override("bold_font", T.font("body_medium"))
	for k in ["normal_font_size", "bold_font_size"]:
		r.add_theme_font_size_override(k, size)
	r.add_theme_color_override("default_color", T.TEXT)
	var bits := text.split("**")
	var out := ""
	for i in bits.size():
		var b := bits[i].replace("[", "[lb]")
		out += ("[b][color=#%s]%s[/color][/b]" % [Color(1.0, 0.85, 0.65).to_html(false), b]) if i % 2 == 1 else b
	r.text = out
	return r


func _bullet(text: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(fs * 0.6))
	var dot := _label("▸", "body_medium", fs + 1, T.ORANGE)
	dot.custom_minimum_size.x = fs * 0.8
	dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(dot)
	h.add_child(_rich(text, fs + 1))
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
