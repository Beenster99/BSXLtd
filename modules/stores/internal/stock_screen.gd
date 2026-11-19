extends PanelContainer
## The WAREHOUSE STOCK screen (beenster, 19 Nov): everything the stores hall holds, in
## detail. Along the top the totals (units, value, weight, places used, on the way in, short
## for the open design) and each kind of rack's fill; below, a table of every part the stores
## keep, in stock or not (sortable: click a heading), filtered by rack kind or by IN STOCK /
## SHORT / INBOUND; on the right a map of both storeys' racks, every bay shaded by how full
## it is, the chosen part's bays lit, and the chosen part's places one by one.
##
## The same screen on the wrist (F1) and on the design room's walls (StoresBus.make_screen).
## Click a line to pick a part, a bay on the map to see what is in it.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const RackMap := preload("res://modules/stores/internal/rack_map.gd")

const BG := Color(0.02, 0.05, 0.09)
const CARD := Color(0.05, 0.1, 0.16)
const ROW := Color(0.04, 0.08, 0.13)
const ROW_ALT := Color(0.055, 0.1, 0.155)
const ROW_ON := Color(0.1, 0.2, 0.3)
const PICK := Color(0.91, 0.47, 0.17)
const LINE := Color(0.2, 0.45, 0.65, 0.6)
## Each rack kind's colour (YardRackStore kind order: long, plate, component, heavy).
const KIND_COLOURS: Array[Color] = [Color("6fc8e8"), Color("b49cf0"), Color("7fd47a"), Color("e8c25a")]

const FILTERS: PackedStringArray = ["ALL", "LONG", "PLATE", "COMPONENTS", "HEAVY", "IN STOCK", "SHORT", "INBOUND"]
## Table columns: key, heading, width in characters of table text (0 = the part name, takes the rest).
const COLUMNS := [["name", "PART", 0.0], ["racks", "RACKS", 12.0], ["qty", "HELD", 6.0], ["places", "PLACES", 7.0],
		["room", "ROOM", 6.0], ["inbound", "INBOUND", 8.0], ["need", "DESIGN", 7.0], ["short", "SHORT", 7.0],
		["unit_cost", "UNIT CR", 8.5], ["value", "VALUE CR", 10.5], ["mass", "TONNES", 8.0]]
## Seconds between refreshes while the racks keep changing.
const REFRESH_GAP := 0.4

var bus: StoresBus
var px_per_m := 150.0
## Base text size, px.
var fs := 15
var filter := "ALL"
var sort_key := "value"
var sort_down := true
## The chosen part's id ("" none).
var selected := ""
## The chosen bay on the map: [rack index, bay] or [].
var bay: Array = []

var _status: Label
var _cards: HBoxContainer
var _kinds: HBoxContainer
var _chips: HBoxContainer
var _head: HBoxContainer
var _table: VBoxContainer
var _map: Control
var _detail: VBoxContainer
var _due := true
var _since := 0.0
var _pulse := 0.0


func setup(stores_bus: StoresBus, density: float) -> void:
	bus = stores_bus
	px_per_m = density
	fs = maxi(12, int(px_per_m * 0.1))
	name = "WarehouseStock"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", T.box(BG, Color.TRANSPARENT, 0, fs * 0.5))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(fs * 0.45))
	add_child(col)
	_status = _label("", "mono_medium", fs - 2, T.DIM)
	_status.clip_text = true
	col.add_child(_status)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", int(fs * 0.45))
	col.add_child(_cards)
	_kinds = HBoxContainer.new()
	_kinds.add_theme_constant_override("separation", int(fs * 0.45))
	col.add_child(_kinds)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(fs * 0.6))
	col.add_child(body)
	# The table.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	left.add_theme_constant_override("separation", 2)
	body.add_child(left)
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 4)
	left.add_child(_chips)
	var head_box := PanelContainer.new()
	head_box.add_theme_stylebox_override("panel", T.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, fs * 0.2))
	left.add_child(head_box)
	_head = HBoxContainer.new()
	_head.add_theme_constant_override("separation", 0)
	head_box.add_child(_head)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	_table = VBoxContainer.new()
	_table.name = "Lines"
	_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table.add_theme_constant_override("separation", 1)
	scroll.add_child(_table)
	# The map and the chosen part's places.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", int(fs * 0.35))
	body.add_child(right)
	right.add_child(_label("STORES HALL  ·  BAYS BY FILL", "display_bold", fs + 1, T.TEXT))
	_map = RackMap.new()
	_map.name = "RackMap"
	_map.set("font_size", fs - 3)
	_map.set("kind_colours", KIND_COLOURS)
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.size_flags_stretch_ratio = 1.25
	_map.custom_minimum_size = Vector2(fs * 20, fs * 13)
	_map.connect("bay_clicked", pick_bay)
	right.add_child(_map)
	var detail_box := PanelContainer.new()
	detail_box.add_theme_stylebox_override("panel", T.box(CARD, LINE, 1, fs * 0.45))
	detail_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail_box)
	var dscroll := ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_box.add_child(dscroll)
	_detail = VBoxContainer.new()
	_detail.name = "Detail"
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 2)
	dscroll.add_child(_detail)
	bus.report_changed.connect(func() -> void: _due = true)
	refresh()


func _process(delta: float) -> void:
	_since += delta
	_pulse += delta
	if _due and _since >= REFRESH_GAP:
		refresh()
	if _status and bus:
		_status.text = _status_text()


## Builds the screen again from the stores (at most every REFRESH_GAP while they change).
func refresh() -> void:
	_due = false
	_since = 0.0
	if bus == null:
		return
	var r := bus.report()
	if selected == "":
		selected = _default_pick(r)
	_fill_cards(r)
	_fill_kinds(r)
	_fill_chips()
	_fill_head()
	_fill_table(r)
	_map.call("show_report", r, bus.store(), selected, bay)
	_fill_detail(r)


func set_filter(f: String) -> void:
	filter = f
	refresh()


func sort_by(key: String) -> void:
	if sort_key == key:
		sort_down = not sort_down
	else:
		sort_key = key
		sort_down = key != "name" and key != "racks"
	refresh()


func select(id: String) -> void:
	selected = id
	bay = []
	refresh()


func pick_bay(rack: int, b: int) -> void:
	bay = [rack, b]
	selected = ""
	var r := bus.report()
	# The bay's biggest holding becomes the chosen part, so its other places light too.
	var parts: Dictionary = r.racks[rack].bays[b].parts
	var most := 0
	for id: String in parts:
		if int(parts[id]) > most:
			most = int(parts[id])
			selected = id
	refresh()


## The lines the filter lets through, sorted.
func shown_lines(r: StoresReport) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l in r.lines:
		if _passes(l):
			out.append(l)
	var key := sort_key
	var down := sort_down
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var va: Variant = a[key]
		var vb: Variant = b[key]
		if va is Array:
			va = ",".join(PackedStringArray(va))
			vb = ",".join(PackedStringArray(vb))
		if va == vb:
			return str(a.name) < str(b.name)
		return (va > vb) if down else (va < vb))
	return out


func _passes(l: Dictionary) -> bool:
	match filter:
		"LONG":
			return int(l.kind) == YardRackStore.LONG
		"PLATE":
			return int(l.kind) == YardRackStore.PLATE
		"COMPONENTS":
			return int(l.kind) == YardRackStore.COMPONENT
		"HEAVY":
			return int(l.kind) == YardRackStore.HEAVY
		"IN STOCK":
			return int(l.qty) > 0
		"SHORT":
			return int(l.short) > 0
		"INBOUND":
			return int(l.inbound) > 0
	return true


func _default_pick(r: StoresReport) -> String:
	var best := ""
	var most := -1.0
	for l in r.lines:
		var score := float(l.short) * 1e9 + float(l.value) + float(l.qty)
		if int(l.qty) > 0 or int(l.short) > 0:
			if score > most:
				most = score
				best = str(l.id)
	return best


# --- The top: status, totals, rack kinds ------------------------------------------------

func _status_text() -> String:
	var r := bus.report()
	var where := "PREVIEW · THE STOCK A NEW YARD STARTS WITH" if bus.is_preview() else "LIVE · STORES HALL"
	var design := ("  ·  OPEN DESIGN %s" % r.design_name.to_upper()) if r.design_name != "" else "  ·  NO DESIGN OPEN"
	var blink := "●" if int(_pulse * 2.0) % 2 == 0 else "○"
	return "%s %s  ·  %d RACKS ON 2 STOREYS  ·  %d PLACES%s" % [blink, where, YardRackStore.RACKS.size(), r.total_places, design]


func _fill_cards(r: StoresReport) -> void:
	_clear(_cards)
	var used := StoresReport.share(r.filled_places, r.total_places)
	_cards.add_child(_card("UNITS HELD", "%d" % r.total_qty, "%d of %d lines in stock" % [r.lines_in, r.lines.size()], T.TEXT))
	_cards.add_child(_card("STOCK VALUE", "CR " + T.money(int(r.total_value)), "at catalogue cost", T.GOOD))
	_cards.add_child(_card("WEIGHT", "%.1f t" % (r.total_mass / 1000.0), "on the racks", T.TEXT))
	_cards.add_child(_card("PLACES USED", "%d%%" % roundi(used * 100.0), "%d of %d" % [r.filled_places, r.total_places],
			T.BAD if used > 0.9 else (T.AMBER if used > 0.75 else T.CYAN)))
	_cards.add_child(_card("ON THE WAY IN", "%d" % r.inbound_qty, "units promised a place", T.CYAN))
	var short_text := "%d lines" % r.lines_short if r.design_name != "" else "no design open"
	_cards.add_child(_card("SHORT FOR DESIGN", "%d" % _short_units(r), short_text,
			T.BAD if r.lines_short > 0 else T.GOOD))


func _short_units(r: StoresReport) -> int:
	var n := 0
	for l in r.lines:
		n += int(l.short)
	return n


func _fill_kinds(r: StoresReport) -> void:
	_clear(_kinds)
	for k in YardRackStore.KIND_NAMES.size():
		var info: Dictionary = r.kinds[k]
		var on: bool = filter == ["LONG", "PLATE", "COMPONENTS", "HEAVY"][k]
		var card := PanelContainer.new()
		card.name = "Kind_" + YardRackStore.KIND_NAMES[k]
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", T.box(ROW_ON if on else CARD, KIND_COLOURS[k] if on else LINE, 2 if on else 1, fs * 0.35))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var f: String = ["LONG", "PLATE", "COMPONENTS", "HEAVY"][k]
		card.gui_input.connect(func(e: InputEvent) -> void:
			if _clicked(e):
				set_filter("ALL" if filter == f else f))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		card.add_child(v)
		var top := HBoxContainer.new()
		v.add_child(top)
		var title := _label(StoresReport.KIND_TITLES[k].to_upper(), "display_bold", fs, KIND_COLOURS[k])
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(title)
		top.add_child(_label("%d units" % int(info.qty), "mono_bold", fs - 1, T.TEXT))
		var bar := _Bar.new()
		bar.value = StoresReport.share(int(info.filled), int(info.places))
		bar.colour = KIND_COLOURS[k]
		bar.custom_minimum_size.y = fs * 0.55
		v.add_child(bar)
		v.add_child(_label("%s  ·  %d / %d places  ·  CR %s%s" % [StoresReport.KIND_RACKS[k], int(info.filled), int(info.places),
				T.money(int(info.value)), ("  ·  %d in" % int(info.inbound)) if int(info.inbound) > 0 else ""],
				"mono_medium", fs - 3, T.DIM))
		_kinds.add_child(card)


# --- The table ---------------------------------------------------------------------------

func _fill_chips() -> void:
	_clear(_chips)
	for f: String in FILTERS:
		var b := T.button(f, false, fs - 3, f == filter)
		b.name = "Filter_" + f.replace(" ", "_")
		b.pressed.connect(set_filter.bind(f))
		_chips.add_child(b)


func _fill_head() -> void:
	_clear(_head)
	for c: Array in COLUMNS:
		var key: String = c[0]
		var text: String = c[1]
		if key == sort_key:
			text += " ▼" if sort_down else " ▲"
		var l := _label(text, "mono_bold", fs - 3, T.ORANGE if key == sort_key else T.DIM)
		l.name = "Sort_" + key
		_size_cell(l, float(c[2]))
		if float(c[2]) > 0.0:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.gui_input.connect(func(e: InputEvent) -> void:
			if _clicked(e):
				sort_by(key))
		_head.add_child(l)


func _fill_table(r: StoresReport) -> void:
	_clear(_table)
	var rows := shown_lines(r)
	if rows.is_empty():
		_table.add_child(_label("Nothing here for %s." % filter, "body", fs, T.DIM))
		return
	var alt := false
	for l in rows:
		_table.add_child(_row(l, alt))
		alt = not alt


func _row(l: Dictionary, alt: bool) -> Control:
	var on: bool = str(l.id) == selected
	var p := PanelContainer.new()
	p.name = "Line_" + str(l.id)
	p.add_theme_stylebox_override("panel", T.box(ROW_ON if on else (ROW_ALT if alt else ROW), PICK if on else Color.TRANSPARENT, 1 if on else 0, fs * 0.2))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var id := str(l.id)
	p.gui_input.connect(func(e: InputEvent) -> void:
		if _clicked(e):
			select(id))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var held := int(l.qty)
	for c: Array in COLUMNS:
		var key: String = c[0]
		var text := ""
		var colour := T.TEXT
		var face := "mono_medium"
		match key:
			"name":
				var name_box := HBoxContainer.new()
				name_box.add_theme_constant_override("separation", int(fs * 0.4))
				name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var dot := ColorRect.new()
				dot.color = KIND_COLOURS[int(l.kind)]
				dot.custom_minimum_size = Vector2(fs * 0.3, fs * 1.1)
				dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
				name_box.add_child(dot)
				var nl := _label(str(l.name), "body_medium", fs - 1, T.TEXT if held > 0 else T.DIM)
				nl.clip_text = true
				nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				name_box.add_child(nl)
				h.add_child(name_box)
				continue
			"racks":
				text = " ".join(PackedStringArray(l.racks)) if held > 0 else "—"
				colour = T.DIM
			"qty":
				text = str(held) if held > 0 else "OUT"
				colour = T.TEXT if held > 0 else T.BAD
				face = "mono_bold"
			"places":
				text = str(int(l.places))
			"room":
				text = str(int(l.room)) if held > 0 else "—"
				colour = T.DIM
			"inbound":
				text = ("+%d" % int(l.inbound)) if int(l.inbound) > 0 else "—"
				colour = T.CYAN if int(l.inbound) > 0 else T.DIM
			"need":
				text = str(int(l.need)) if int(l.need) > 0 else "—"
				colour = T.AMBER if int(l.need) > 0 else T.DIM
			"short":
				text = str(int(l.short)) if int(l.short) > 0 else ("OK" if int(l.need) > 0 else "—")
				colour = T.BAD if int(l.short) > 0 else (T.GOOD if int(l.need) > 0 else T.DIM)
				face = "mono_bold"
			"unit_cost":
				text = T.money(int(l.unit_cost)) if float(l.unit_cost) > 0.0 else "—"
				colour = T.DIM
			"value":
				text = T.money(int(l.value)) if float(l.value) > 0.0 else "—"
			"mass":
				text = "%.2f" % (float(l.mass) / 1000.0) if float(l.mass) > 0.0 else "—"
				colour = T.DIM
		var cell := _label(text, face, fs - 2, colour)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_size_cell(cell, float(c[2]))
		h.add_child(cell)
	return p


func _size_cell(c: Control, width: float) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width <= 0.0:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.custom_minimum_size.x = width * (fs - 2) * 0.62


# --- The chosen part or bay --------------------------------------------------------------

func _fill_detail(r: StoresReport) -> void:
	_clear(_detail)
	var store := bus.store()
	if not bay.is_empty():
		var rack: Dictionary = r.racks[int(bay[0])]
		var b: Dictionary = rack.bays[int(bay[1])]
		_detail.add_child(_label("%s  BAY %d  ·  %s" % [rack.id, int(bay[1]) + 1, StoresReport.STOREY_NAMES[int(rack.storey)].to_upper()],
				"display_bold", fs + 1, KIND_COLOURS[int(rack.kind)]))
		_detail.add_child(_label("%d of %d places in use" % [int(b.filled), int(b.places)], "mono_medium", fs - 2, T.DIM))
		var parts: Dictionary = b.parts
		if parts.is_empty():
			_detail.add_child(_label("Empty.", "body", fs - 1, T.DIM))
		for id: String in parts:
			_detail.add_child(_label("%3d × %s" % [int(parts[id]), YardRackStore.PARTS[id].name], "mono_medium", fs - 2, T.TEXT))
		_detail.add_child(HSeparator.new())
	var l := r.line(selected)
	if l.is_empty():
		if bay.is_empty():
			_detail.add_child(_label("Pick a line or a bay to see where its parts are.", "body", fs - 1, T.DIM))
		return
	var head := HBoxContainer.new()
	_detail.add_child(head)
	var t := _label(str(l.name).to_upper(), "display_bold", fs + 2, T.TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_label(StoresReport.KIND_TITLES[int(l.kind)].to_upper(), "mono_bold", fs - 3, KIND_COLOURS[int(l.kind)]))
	var size: Vector3 = YardRackStore.PARTS[str(l.id)].size
	_detail.add_child(_label("%d held in %d places (%d to a place)  ·  room for %d more  ·  %.1f × %.1f × %.1f m" % [
			int(l.qty), int(l.places), int(l.stack), int(l.room), size.x, size.y, size.z], "mono_medium", fs - 3, T.DIM))
	var money := "CR %s each  ·  CR %s held  ·  %.2f t" % [T.money(int(l.unit_cost)), T.money(int(l.value)), float(l.mass) / 1000.0] \
			if float(l.unit_cost) > 0.0 else "No catalogue price"
	_detail.add_child(_label(money, "mono_medium", fs - 3, T.DIM))
	if int(l.need) > 0:
		var ok := int(l.short) == 0
		_detail.add_child(_label("Open design needs %d: %s" % [int(l.need), "covered" if ok else "%d short" % int(l.short)],
				"body_medium", fs - 1, T.GOOD if ok else T.BAD))
	if int(l.inbound) > 0:
		_detail.add_child(_label("+%d on the way in from goods in" % int(l.inbound), "body_medium", fs - 1, T.CYAN))
	if int(l.qty) <= 0:
		_detail.add_child(_label("None on the racks.", "body", fs - 1, T.BAD))
		return
	_detail.add_child(_label("PLACES", "mono_bold", fs - 3, T.ORANGE))
	for i: int in l.slots:
		var row := HBoxContainer.new()
		_detail.add_child(row)
		var where := _label(StoresReport.place_name(store, i), "mono_medium", fs - 3, T.TEXT)
		where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(where)
		var storey := YardRackStore.storey_of(store.slot_position(i).y)
		row.add_child(_label("%s  %d/%d" % ["UPPER" if storey == 1 else "GROUND", int(store.slots[i].qty), int(l.stack)],
				"mono_medium", fs - 3, T.DIM))


# --- Bits --------------------------------------------------------------------------------

func _card(title: String, value: String, sub: String, colour: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Card_" + title.replace(" ", "_")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", T.box(CARD, LINE, 1, fs * 0.4))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	v.add_child(_label(title, "mono_bold", fs - 4, T.DIM))
	v.add_child(_label(value, "display_bold", fs + 9, colour))
	v.add_child(_label(sub, "mono_medium", fs - 4, T.DIM))
	return card


func _label(text: String, face: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", T.font(face))
	l.add_theme_font_size_override("font_size", maxi(8, size))
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


static func _clicked(e: InputEvent) -> bool:
	return e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT


## A fill bar.
class _Bar extends Control:
	var value := 0.0
	var colour := Color.WHITE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.08))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(value, 0.0, 1.0), size.y)), Color(colour, 0.85))
