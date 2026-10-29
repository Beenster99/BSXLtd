extends HBoxContainer
## The Stock channel on the wrist screen, drawn on glass with UI's TerminalKit: what the
## stores hold (figures, a search, category chips, then the lines under a heading per
## catalogue category, each folding shut with a click; a line per part and grade with its
## places, condition, quantity and value, in a smaller font so the screen holds many) and a
## docket for the picked line, whose BRING 3 TO ME sends the picking lift for as many as you
## pick with its - and + (beenster 0.3.24). Crates
## still waiting in Deliveries are listed first, under Goods in.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const Layout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")
## Rows drawn at most (a category heading counts as one).
const MAX_ROWS := 160
## How much smaller the list's text is than TerminalKit's, so the screen holds more lines.
const COMPACT := 0.82
const RAW_PREFIX := "raw_"
## The category of crates waiting in Deliveries.
const GOODS_IN := "goods_in"

signal close_requested

var bus: ShipBayBus
var fleet: Node
var glass := true
var category := ""
var query := ""
## The picked row's key: "part:<item>/<grade>" or "crate:<id>".
var selected := ""
## Category -> true for the headings folded shut (a search opens them all).
var folded := {}

var _figures: HBoxContainer
var _chips: Control
var _list: VBoxContainer
var _side: VBoxContainer
var _message := ""
## How many of the picked line BRING fetches (1 up to the most one place holds).
var bring_qty := 1
var _dirty := false


func _init(p_bus: ShipBayBus, p_fleet: Node, p_glass := true) -> void:
	bus = p_bus
	fleet = p_fleet
	glass = p_glass
	name = "StockScreen"
	add_theme_constant_override("separation", 14)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_stretch_ratio = 1.8
	main.add_theme_constant_override("separation", 8)
	add_child(main)
	_figures = HBoxContainer.new()
	_figures.add_theme_constant_override("separation", 10)
	main.add_child(_figures)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(T.search("Search stock", func(t: String) -> void:
		query = t.strip_edges().to_lower()
		_refresh_list(), glass))
	_chips = HBoxContainer.new()
	_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_chips)
	main.add_child(top)
	main.add_child(T.columns([["PART  /  WHERE", 0], ["COND.", 92], ["QTY", 72], ["VALUE CR", 104]]))
	_list = T.list()
	main.add_child(_list.get_parent())
	_side = VBoxContainer.new()
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.add_theme_constant_override("separation", 10)
	add_child(_side)
	bus.stock_changed.connect(_mark_dirty)
	refresh()


func _exit_tree() -> void:
	if bus.stock_changed.is_connected(_mark_dirty):
		bus.stock_changed.disconnect(_mark_dirty)


func _mark_dirty() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		refresh()


func refresh() -> void:
	_refresh_figures()
	_refresh_chips()
	_refresh_list()
	_refresh_side()


## Every line held: {key, item, name, category, grade, where, qty, condition, value, places}:
## the crates still waiting in Deliveries first, one line each, then one per part and grade
## with its places ({loc, where, qty, condition}) on the shelves, by category, then name.
func lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var locations: Dictionary = Layout.get_layout()["locations"]
	var ids: Array = bus.stocked_locations()
	ids.sort()
	var by_key := {}
	for loc: String in ids:
		var s := bus.stock_at(loc)
		var item := str(s.get("item", ""))
		var qty := int(s.get("qty", 0))
		var cond := float(s.get("condition", 1.0))
		var key := "part:%s/%s" % [item, grade_of(cond)]
		if not by_key.has(key):
			by_key[key] = {"key": key, "item": item, "name": part_name(item), "category": category_of(item),
					"grade": grade_of(cond), "qty": 0, "condition": 0.0, "places": []}
		var l: Dictionary = by_key[key]
		l.condition = (float(l.condition) * int(l.qty) + cond * qty) / maxf(int(l.qty) + qty, 1)
		l.qty = int(l.qty) + qty
		(l.places as Array).append({"loc": loc, "where": where_text(locations.get(loc, {})), "qty": qty, "condition": cond})
	var parts: Array = by_key.values()
	parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra := category_rank(str(a.category))
		var rb := category_rank(str(b.category))
		if ra != rb:
			return ra < rb
		return str(a.name) < str(b.name) if a.name != b.name else str(a.grade) < str(b.grade))
	var crates := bus.delivered_crates()
	var keys: Array = crates.keys()
	keys.sort()
	for id: String in keys:
		var c: Dictionary = crates[id]
		var item := str(c.get("item", ""))
		var cond := float(c.get("condition", 1.0))
		out.append(_priced({"key": "crate:" + id, "item": item, "name": str(c.get("name", part_name(item))),
				"category": GOODS_IN, "grade": grade_of(cond), "where": "Deliveries · goods in",
				"qty": int(c.get("qty", 0)), "condition": cond, "places": []}))
	for l: Dictionary in parts:
		var places: Array = l.places
		l.where = str(places[0].where) if places.size() == 1 else "%d places · %s" % [places.size(), str(places[0].where)]
		out.append(_priced(l))
	return out


func _priced(l: Dictionary) -> Dictionary:
	var unit := bus.part_value(str(l.item))
	l.value = -1 if unit < 0 else roundi(unit * int(l.qty) * price_factor(float(l.condition)))
	return l


## A part's name: the catalogue's, or for a raw material ("raw_steel") "Steel (raw, kg)", as
## Business names it.
static func part_name(item: String) -> String:
	if item.begins_with(RAW_PREFIX):
		return "%s (raw, kg)" % item.trim_prefix(RAW_PREFIX).capitalize()
	return str(Layout.items().get(item, {}).get("name", item))


## A part's catalogue category ("engines"), "materials" for raw materials, "" if unknown.
static func category_of(item: String) -> String:
	if item.begins_with(RAW_PREFIX):
		return "materials"
	return str(Layout.items().get(item, {}).get("category", ""))


## Where a category sorts: goods in first, then the catalogue's order, then the rest.
static func category_rank(cat: String) -> int:
	if cat == GOODS_IN:
		return -1
	var i: int = Layout.CATEGORIES.keys().find(cat)
	return i if i >= 0 else Layout.CATEGORIES.size() + (0 if cat == "materials" else 1)


static func category_name(cat: String) -> String:
	if cat == GOODS_IN:
		return "Goods in"
	if cat == "materials":
		return "Materials"
	return str(Layout.CATEGORIES.get(cat, "Other" if cat == "" else cat.capitalize()))


## "Rack B1 · bay 2 · level 3", "Bins C2 · bay 1 · level 2", "Large rack W1 · bay 1 · level 2",
## "Heavy rack H2 · bay 2 · level 1".
static func where_text(loc: Dictionary) -> String:
	if loc.is_empty():
		return "Stores"
	var what := "Rack"
	if loc.get("kind") == "bin":
		what = "Bins"
	elif str(loc.get("store", "")) == "large":
		what = "Large rack"
	elif str(loc.get("store", "")) == "heavy":
		what = "Heavy rack"
	elif str(loc.get("store", "")) == "plate":
		what = "Plate rack"
	elif str(loc.get("store", "")) == "beam":
		what = "Beam rack"
	return "%s %s · bay %d · level %d" % [what, loc.get("rack", ""), int(loc.get("bay", 0)), int(loc.get("level", 0))]


## A condition (1 as new .. 0 scrap) as the grades Business sells: new, refurb, used, damaged.
static func grade_of(condition: float) -> String:
	if condition >= 0.95:
		return "new"
	if condition >= 0.8:
		return "refurb"
	return "used" if condition >= 0.5 else "damaged"


static func grade_colour(grade: String) -> Color:
	return {"new": T.GOOD, "refurb": T.CYAN, "used": T.AMBER}.get(grade, T.BAD)


## Share of the new value a part in this condition is worth.
static func price_factor(condition: float) -> float:
	return {"new": 1.0, "refurb": 0.78, "used": 0.58}.get(grade_of(condition), 0.3)


func _refresh_figures() -> void:
	for c in _figures.get_children():
		c.queue_free()
	var all := lines()
	var items := 0
	var value := 0
	var priced := false
	for l in all:
		items += int(l.qty)
		if int(l.value) >= 0:
			value += int(l.value)
			priced = true
	_figures.add_child(T.figure("Lines held", str(all.size()), T.TEXT, glass))
	_figures.add_child(T.figure("Items", T.money(items), T.TEXT, glass))
	_figures.add_child(T.figure("Stock value", "CR " + T.money(value) if priced else "—", T.ORANGE, glass))
	var coming := bus.picked_crates().size()
	_figures.add_child(T.figure("On the way", str(coming), T.CYAN if coming > 0 else T.DIM, glass))


func _refresh_chips() -> void:
	for c in _chips.get_children():
		c.queue_free()
	var seen := {}
	for l in lines():
		seen[l.category] = true
	var cats: Array = seen.keys()
	cats.sort_custom(func(a: String, b: String) -> bool: return category_rank(a) < category_rank(b))
	if category != "" and not seen.has(category):
		category = ""
	if cats.size() < 2:
		return
	var names := PackedStringArray()
	for cat: String in cats:
		names.append(category_name(cat))
	_chips.add_child(T.chips(names, category_name(category) if category != "" else "", func(n: String) -> void:
		category = ""
		for cat: String in cats:
			if category_name(cat) == n:
				category = cat
		refresh(), glass))


func shown() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l in lines():
		if category != "" and l.category != category:
			continue
		if query != "" and not _matches(l):
			continue
		out.append(l)
	return out


func _matches(l: Dictionary) -> bool:
	var text := "%s %s %s %s %s" % [l.name, l.where, l.item, category_name(str(l.category)), l.grade]
	for p: Dictionary in l.places:
		text += " " + str(p.where)
	return text.to_lower().contains(query)


func _refresh_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)   # out now, so the new rows and headings keep their names
		c.queue_free()
	var rows := shown()
	if rows.is_empty():
		var empty := T.label("Nothing in the stores yet. Order parts at a yard terminal; deliveries land in the Deliveries hall."
				if lines().is_empty() else "No stock matches.", "body", 17, T.DIM)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(empty)
	var drawn := 0
	var n := 0
	var last := "\n"
	for l: Dictionary in rows:
		if drawn >= MAX_ROWS:
			break
		var cat := str(l.category)
		if cat != last:
			last = cat
			var in_cat := rows.filter(func(r: Dictionary) -> bool: return r.category == cat)
			_list.add_child(_heading(cat, in_cat))
			drawn += 1
			n = 0
		if is_folded(cat):
			continue
		var r := compact(T.row([_name_cell(str(l.name), str(l.where)), _w(T.tag(str(l.grade), grade_colour(str(l.grade)), 12), 92),
				T.cell(_qty_text(l), 72, T.TEXT), T.cell("—" if int(l.value) < 0 else T.money(int(l.value)), 104, T.TEXT, "mono_bold")],
				n % 2 == 1, glass))
		r.name = "Row_" + str(l.key).validate_node_name()
		if l.key == selected:
			var st := (r.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
			st.border_color = T.ORANGE
			st.border_width_left = 4
			r.add_theme_stylebox_override("panel", st)
		r.mouse_filter = Control.MOUSE_FILTER_STOP
		r.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				select(str(l.key)))
		_list.add_child(r)
		drawn += 1
		n += 1


## A category is shut when its heading was clicked shut, unless a search is on (it shows
## every match) or it is the only category picked.
func is_folded(cat: String) -> bool:
	return bool(folded.get(cat, false)) and query == "" and category == ""


## A category's heading: its name, how many lines and items, their value; click to fold it.
func _heading(cat: String, rows: Array) -> Control:
	var items := 0
	var value := 0
	for r: Dictionary in rows:
		items += int(r.qty)
		value += maxi(int(r.value), 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var arrow := T.label("▸" if is_folded(cat) else "▾", "mono_medium", 14, T.ORANGE)
	h.add_child(arrow)
	var l := T.label(category_name(cat).to_upper(), "display_bold", 15, T.ORANGE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(T.label("%d LINE%s · %s ITEM%s" % [rows.size(), "" if rows.size() == 1 else "S", T.money(items),
			"" if items == 1 else "S"], "mono_medium", 13, T.DIM))
	var v := T.label("CR " + T.money(value) if value > 0 else "", "mono_medium", 13, T.DIM)
	v.custom_minimum_size.x = T.px(104)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	var pad := MarginContainer.new()
	pad.name = "Heading_" + (cat if cat != "" else "other").validate_node_name()
	pad.add_theme_constant_override("margin_left", 4)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_child(h)
	pad.mouse_filter = Control.MOUSE_FILTER_STOP
	pad.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			fold(cat))
	return pad


## Folds a category's heading shut, or opens it again.
func fold(cat: String) -> void:
	folded[cat] = not bool(folded.get(cat, false))
	_refresh_list()


## A name over its place, smaller than TerminalKit's list cell.
func _name_cell(title: String, sub: String) -> VBoxContainer:
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -3)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := T.label(title, "body_medium", 19, T.TEXT)
	t.clip_text = true
	names.add_child(t)
	var w := T.label(sub.to_upper(), "display_medium", 14, T.DIM)
	w.clip_text = true
	names.add_child(w)
	return names


static func _qty_text(l: Dictionary) -> String:
	return ("%s KG" % T.money(int(l.qty))) if str(l.item).begins_with(RAW_PREFIX) else "×%d" % int(l.qty)


## Shrinks a row's text by COMPACT and its padding, as Business's lists do.
static func compact(c: Control) -> Control:
	if c is PanelContainer:
		var st := c.get_theme_stylebox("panel") as StyleBoxFlat
		if st:
			st.content_margin_top = 2
			st.content_margin_bottom = 2
	for l: Label in c.find_children("*", "Label", true, false):
		if l.has_theme_font_size_override("font_size"):
			l.add_theme_font_size_override("font_size", maxi(10, roundi(l.get_theme_font_size("font_size") * COMPACT)))
	return c


## Picks a line by its key, or the line that holds a location ("B1-2-3").
func select(key: String) -> void:
	if key != selected:
		bring_qty = 1
	selected = key
	for l in lines():
		for p: Dictionary in l.places:
			if p.loc == key:
				selected = str(l.key)
	_message = ""
	_refresh_list()
	_refresh_side()


func _refresh_side() -> void:
	for c in _side.get_children():
		c.queue_free()
	var line := {}
	for l in lines():
		if l.key == selected:
			line = l
	if line.is_empty():
		var d := T.docket("Stores", "BSX/STK", glass)
		var hint := T.label("Pick a line to see it and have the picking lift bring it to you.", "body", 17, T.TEXT)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.body.add_child(hint)
		var next := str(fleet.call("next_part_for_ship")) if fleet else ""
		if next != "":
			d.body.add_child(T.label("The ship in the bay takes:", "display_medium", 15, T.DIM))
			d.body.add_child(T.label(str(Layout.items().get(next, {}).get("name", next)), "body_medium", 19, T.TEXT))
			var b := T.button("BRING IT TO ME", true, 20, false, glass)
			b.name = "Bring"
			b.pressed.connect(press.bind("bring_next"))
			d.body.add_child(b)
		_side.add_child(d.panel)
		return
	var d := T.docket(str(line.name), str(line.item), glass)
	var grade := str(line.grade)
	var places: Array = line.places
	var where := str(line.where)
	if places.size() > 1:
		var at := PackedStringArray()
		for p: Dictionary in places.slice(0, 5):
			at.append("%s  ×%d" % [p.where, int(p.qty)])
		if places.size() > 5:
			at.append("and %d more" % (places.size() - 5))
		where = "\n".join(at)
	for pair: Array in [["WHERE", where], ["QTY", _qty_text(line)], ["CONDITION", "%s  %d%%" % [grade.to_upper(), roundi(float(line.condition) * 100)]],
			["MASS", "%s kg each" % _mass_text(float(Layout.items().get(line.item, {}).get("mass", 0.0)))],
			["VALUE", "—" if int(line.value) < 0 else "CR " + T.money(int(line.value))]]:
		var h := HBoxContainer.new()
		var k := T.label(pair[0], "display_medium", 14, T.DIM)
		k.custom_minimum_size.x = 96
		h.add_child(k)
		var v := T.label(str(pair[1]), "body_medium", 17, T.TEXT)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		d.body.add_child(h)
	if str(line.key).begins_with("crate:"):
		var b := T.button("PUT AWAY DELIVERIES", true, 20, false, glass)
		b.name = "PutAway"
		b.pressed.connect(press.bind("put_away"))
		d.body.add_child(b)
	else:
		bring_qty = clampi(bring_qty, 1, maxi(_most_in_one(line), 1))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		for pair: Array in [["-", "less"], ["+", "more"]]:
			var step := T.button(pair[0], false, 20, false, glass)
			step.name = "Bring_" + pair[1]
			step.custom_minimum_size.x = 44
			step.pressed.connect(press.bind(pair[1]))
			row.add_child(step)
			if pair[1] == "less":
				var n := T.label(str(bring_qty), "body_medium", 20, T.TEXT)
				n.name = "BringQty"
				n.custom_minimum_size.x = 44
				n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				row.add_child(n)
		var b := T.button("BRING %d TO ME" % bring_qty, true, 20, false, glass)
		b.name = "Bring"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(press.bind("bring"))
		row.add_child(b)
		d.body.add_child(row)
	if _message != "":
		var m := T.label(_message, "body", 16, T.GOOD)
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.body.add_child(m)
	_side.add_child(d.panel)


## The most of a line one place holds: the picking lift brings from one place a trip.
static func _most_in_one(line: Dictionary) -> int:
	var most := 0
	for p: Dictionary in line.get("places", []):
		most = maxi(most, int(p.get("qty", 0)))
	return most


## The docket's buttons, by name (tests call it): "less", "more", "bring", "bring_next",
## "put_away".
func press(action: String) -> void:
	var line := {}
	for l in lines():
		if l.key == selected:
			line = l
	match action:
		"bring":
			if line.is_empty() or fleet == null:
				return
			var n := clampi(bring_qty, 1, maxi(_most_in_one(line), 1))
			bus.fetch_stock(str(line.item), n, fleet.call("player_position"))
			_message = "The picking lift is bringing %d %s to you." % [n, str(line.name).to_lower()]
			Sfx.play("click")
		"less", "more":
			bring_qty = clampi(bring_qty + (1 if action == "more" else -1), 1, maxi(_most_in_one(line), 1))
			Sfx.play("click")
		"bring_next":
			if fleet and bool(fleet.call("fetch_for_ship")):
				_message = "On its way."
				Sfx.play("click")
		"put_away":
			for id: String in ["p2", "p3", "p4", "p5", "p6", "h"]:
				bus.command_trolley(id, "put_away")
			_message = "The goods-in lifts are putting the deliveries away."
			Sfx.play("click")
	_refresh_side()


## Every label's text, for tests.
func text() -> String:
	var parts := PackedStringArray()
	_gather(self, parts)
	return " | ".join(parts)


func _gather(n: Node, out: PackedStringArray) -> void:
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_gather(c, out)


static func _mass_text(kg: float) -> String:
	return ("%.2f" % kg) if kg < 10.0 else T.money(roundi(kg))


func _w(c: Control, width: float) -> Control:
	var box := CenterContainer.new()
	box.custom_minimum_size.x = width
	box.add_child(c)
	return box
