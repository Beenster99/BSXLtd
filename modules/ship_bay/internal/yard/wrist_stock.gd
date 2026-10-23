extends HBoxContainer
## The Stock channel on the wrist screen, drawn on glass with UI's TerminalKit: what the
## stores hold (figures, a search, category chips, a row per location: part / where,
## condition, quantity, value) and a docket for the picked line, whose BRING ONE TO ME sends
## the picking lift for it. Crates still waiting in Deliveries are listed too.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const Layout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")
const MAX_ROWS := 80

signal close_requested

var bus: ShipBayBus
var fleet: Node
var glass := true
var category := ""
var query := ""
## The picked row's key: a location id, or "crate:<id>".
var selected := ""

var _figures: HBoxContainer
var _chips: Control
var _list: VBoxContainer
var _side: VBoxContainer
var _message := ""
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
	main.add_child(T.columns([["PART  /  WHERE", 0], ["COND.", 96], ["QTY", 56], ["VALUE CR", 104]]))
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


## Every line held: {key, item, name, category, where, qty, condition, value}, shelves first
## (in location order), then crates waiting in Deliveries.
func lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var items := Layout.items()
	var locations: Dictionary = Layout.get_layout()["locations"]
	var ids: Array = bus.stocked_locations()
	ids.sort()
	for loc: String in ids:
		var s := bus.stock_at(loc)
		var item := str(s.get("item", ""))
		out.append(_line(loc, item, str(items.get(item, {}).get("name", item)), where_text(locations.get(loc, {})),
				int(s.get("qty", 0)), float(s.get("condition", 1.0))))
	var crates := bus.delivered_crates()
	var keys: Array = crates.keys()
	keys.sort()
	for id: String in keys:
		var c: Dictionary = crates[id]
		var item := str(c.get("item", ""))
		out.append(_line("crate:" + id, item, str(c.get("name", item)), "Deliveries · goods in",
				int(c.get("qty", 0)), float(c.get("condition", 1.0))))
	return out


func _line(key: String, item: String, part_name: String, where: String, qty: int, condition: float) -> Dictionary:
	var unit := bus.part_value(item)
	return {"key": key, "item": item, "name": part_name, "where": where, "qty": qty, "condition": condition,
			"category": str(Layout.items().get(item, {}).get("category", "")),
			"value": -1 if unit < 0 else roundi(unit * qty * price_factor(condition))}


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
		if str(l.category) != "":
			seen[l.category] = true
	var names := PackedStringArray()
	for cat: String in Layout.CATEGORIES:
		if seen.has(cat):
			names.append(cat)
	if category != "" and not seen.has(category):
		category = ""
	_chips.add_child(T.chips(names, category, func(n: String) -> void:
		category = n
		refresh(), glass))


func shown() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l in lines():
		if category != "" and l.category != category:
			continue
		if query != "" and not (str(l.name).to_lower().contains(query) or str(l.where).to_lower().contains(query)
				or str(l.item).to_lower().contains(query) or str(l.category).contains(query)):
			continue
		out.append(l)
	return out


func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var rows := shown()
	if rows.is_empty():
		var empty := T.label("Nothing in the stores yet. Order parts at a yard terminal; deliveries land in the Deliveries hall."
				if lines().is_empty() else "No stock matches.", "body", 17, T.DIM)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(empty)
	for i in mini(rows.size(), MAX_ROWS):
		var l: Dictionary = rows[i]
		var grade := grade_of(float(l.condition))
		var r := T.row([T.cell_text(str(l.name), str(l.where)), _w(T.tag(grade, grade_colour(grade)), 96),
				T.cell(str(l.qty), 56, T.TEXT), T.cell("—" if int(l.value) < 0 else T.money(int(l.value)), 104, T.TEXT, "mono_bold")],
				i % 2 == 1, glass)
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


func select(key: String) -> void:
	selected = key
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
	var grade := grade_of(float(line.condition))
	for pair: Array in [["WHERE", line.where], ["QTY", str(line.qty)], ["CONDITION", "%s  %d%%" % [grade.to_upper(), roundi(float(line.condition) * 100)]],
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
		var b := T.button("BRING ONE TO ME", true, 20, false, glass)
		b.name = "Bring"
		b.pressed.connect(press.bind("bring"))
		d.body.add_child(b)
	if _message != "":
		var m := T.label(_message, "body", 16, T.GOOD)
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.body.add_child(m)
	_side.add_child(d.panel)


## The docket's buttons, by name (tests call it): "bring", "bring_next", "put_away".
func press(action: String) -> void:
	var line := {}
	for l in lines():
		if l.key == selected:
			line = l
	match action:
		"bring":
			if line.is_empty() or fleet == null:
				return
			bus.fetch_stock(str(line.item), 1, fleet.call("player_position"))
			_message = "The picking lift is bringing one %s to you." % str(line.name).to_lower()
			Sfx.play("click")
		"bring_next":
			if fleet and bool(fleet.call("fetch_for_ship")):
				_message = "On its way."
				Sfx.play("click")
		"put_away":
			for id: String in ["s", "m", "l"]:
				bus.command_trolley(id, "put_away")
			_message = "The trolleys are putting the deliveries away."
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
