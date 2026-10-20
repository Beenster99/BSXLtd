extends HBoxContainer
## Business's channels on the wrist holo screen, drawn on glass with UI's TerminalKit so they
## match the yard terminal. The wrist draws the header and tabs; this is only the body.
##   "orders":   the market (search, categories, +), the purchase order, what's on order
##   "accounts": cash, reputation, rent and the ledger

const T := preload("res://modules/ui/api/terminal_kit.gd")
const MAX_ROWS := 60

var bus: BusinessBus
var page := "orders"
var glass := true
var category := ""
var query := ""

var _search: LineEdit
var _chips: Control
var _list: VBoxContainer
var _side: VBoxContainer
var _message := ""
var _message_good := true
var _dirty := false


func _init(p_bus: BusinessBus, p_page := "orders", p_glass := true) -> void:
	bus = p_bus
	page = p_page
	glass = p_glass
	add_theme_constant_override("separation", 14)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	var watch := {"market_changed": 0, "cash_changed": 3, "order_placed": 1, "delivery_arrived": 2,
			"order_delayed": 1, "reputation_changed": 3, "day_closed": 1}
	for sig: String in watch:
		bus.connect(sig, _mark_dirty.unbind(watch[sig]) if watch[sig] > 0 else _mark_dirty)


## The purchase order being built, kept on the bus so it survives closing the wrist.
var basket: Dictionary:
	get:
		return bus.wrist_basket


func _mark_dirty() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		refresh()


func _build() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_stretch_ratio = 1.7
	main.add_theme_constant_override("separation", 8)
	add_child(main)
	_side = VBoxContainer.new()
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.add_theme_constant_override("separation", 10)
	add_child(_side)
	if page == "orders":
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		_search = T.search("Search parts", func(t: String) -> void:
			query = t.strip_edges().to_lower()
			_refresh_list(), glass)
		top.add_child(_search)
		_chips = HBoxContainer.new()
		_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(_chips)
		main.add_child(top)
		main.add_child(T.columns([["PART  /  SUPPLIER", 0], ["COND.", 92], ["DUE", 58], ["LEFT", 52], ["UNIT CR", 96], ["", 46]]))
	else:
		_side.size_flags_stretch_ratio = 1.6
		main.size_flags_stretch_ratio = 1.0
		main.add_theme_constant_override("separation", 10)
		main.name = "Figures"
		var ledger_head := T.columns([["DAY", 52], ["LEDGER", 0], ["CR", 110]])
		_side.add_child(ledger_head)
	_list = T.list()
	(_side if page == "accounts" else main).add_child(_list.get_parent())
	refresh()


func refresh() -> void:
	_prune_basket()
	if page == "orders":
		_refresh_chips()
		_refresh_list()
		_refresh_side()
	else:
		_refresh_accounts()


# --- ORDERS ---------------------------------------------------------------------------------

func _refresh_chips() -> void:
	var holder := _chips
	for c in holder.get_children():
		c.queue_free()
	var flow := T.chips(_categories(), category, func(n: String) -> void:
		category = n
		refresh(), glass)
	holder.add_child(flow)


func _categories() -> PackedStringArray:
	var seen := {}
	for l in bus.get_listings():
		seen[bus.listing_category(l)] = true
	var out := PackedStringArray(seen.keys())
	out.sort()
	return out


## The listings shown: in the category, in stock, matching the search (part, supplier or
## category).
func shown_listings() -> Array[MarketListing]:
	var out: Array[MarketListing] = []
	for l in bus.get_listings(category):
		if l.available <= 0:
			continue
		if query != "":
			var s := bus.supplier(l.supplier_id)
			var hay := "%s %s %s" % [bus.part_name(l.part), s.display_name if s else l.supplier_id, bus.listing_category(l)]
			if not hay.to_lower().contains(query):
				continue
		out.append(l)
	return out


func _refresh_list() -> void:
	var scroll := _list.get_parent() as ScrollContainer
	var keep := scroll.scroll_vertical
	for c in _list.get_children():
		c.queue_free()
	var shown := shown_listings()
	for i in mini(shown.size(), MAX_ROWS):
		_list.add_child(_listing_row(shown[i], i % 2 == 1))
	if shown.is_empty():
		_list.add_child(T.label("Nothing matches." if query != "" else "Nothing on the market here today.", "body", 18, T.DIM))
	scroll.set_deferred("scroll_vertical", keep)


func _listing_row(l: MarketListing, alt: bool) -> Control:
	var s := bus.supplier(l.supplier_id)
	var add := T.button("+", true, 18, false, glass)
	add.name = "Add_" + l.id
	add.custom_minimum_size = Vector2(34, 30)
	add.disabled = int(basket.get(l.id, 0)) >= l.available
	add.pressed.connect(add_to_basket.bind(l.id, 1))
	var cond := PartCondition.label(l.condition)
	return T.row([
		T.cell_text(bus.part_name(l.part), "%s  ·  %s" % [s.display_name if s else l.supplier_id, bus.listing_category(l)]),
		_width(T.tag(cond, _condition_colour(l.condition)), 92),
		T.cell("%dH" % l.lead_hours, 58),
		T.cell(str(l.available) if l.available < 999 else "∞", 52),
		T.cell(T.money(l.unit_price), 96, T.TEXT, "mono_bold"),
		_width(_centred(add), 46),
	], alt, glass)


func _condition_colour(c: String) -> Color:
	match c:
		"new":
			return T.GOOD
		"refurbished":
			return T.CYAN
		"used":
			return T.AMBER
		"damaged":
			return T.BAD
	return T.STEEL


func _width(c: Control, w: float) -> Control:
	c.custom_minimum_size.x = w
	return c


func _centred(c: Control) -> CenterContainer:
	var box := CenterContainer.new()
	box.add_child(c)
	return box


func _refresh_side() -> void:
	for c in _side.get_children():
		c.queue_free()
	var po := T.docket("Purchase order", "BSX/PO", glass)
	var body := po.body as VBoxContainer
	var lines := basket_as_lines()
	if lines.is_empty():
		body.add_child(T.label("Empty. Press + on a part to add it.", "body", 16, T.DIM))
	for line: Dictionary in lines:
		body.add_child(_po_line(bus.get_listing(line.listing_id), int(line.qty)))
	var q := bus.quote_market(lines) if not lines.is_empty() else null
	var cost := q.cost if q and q.ok else 0
	body.add_child(_sum("DUE AT DELIVERIES", _due_text(q)))
	body.add_child(_sum("CASH AFTER", "%s CR" % T.money(bus.get_cash() - cost)))
	var total := HBoxContainer.new()
	var tl := T.label("TOTAL", "display_bold", 24, T.TEXT)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.add_child(tl)
	total.add_child(T.label("%s CR" % T.money(cost), "mono_bold", 24, T.ORANGE))
	body.add_child(total)
	if _message != "":
		var m := T.label(_message, "body_medium", 15, T.GOOD if _message_good else T.BAD)
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(m)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	var clear := T.button("CLEAR", false, 18, false, glass)
	clear.disabled = basket.is_empty()
	clear.pressed.connect(clear_basket)
	var place := T.button("PLACE ORDER", true, 20, false, glass)
	place.name = "PlaceOrder"
	place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place.disabled = q == null or not q.ok or q.cost > bus.get_cash()
	place.pressed.connect(place_order)
	buttons.add_child(clear)
	buttons.add_child(place)
	body.add_child(buttons)
	_side.add_child(po.panel)

	# What is already on its way, with when it lands.
	var on := T.docket("On order", "", glass)
	on.panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := T.list()
	(on.body as VBoxContainer).add_child(list.get_parent())
	var open := bus.get_orders(PartsOrder.State.PLACED)
	if open.is_empty():
		list.add_child(T.label("Nothing on order.", "body", 16, T.DIM))
	for o in open:
		list.add_child(_order_row(o))
	_side.add_child(on.panel)


func _po_line(l: MarketListing, qty: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var s := bus.supplier(l.supplier_id)
	h.add_child(T.cell_text(bus.part_name(l.part), "%s  ·  %s" % [s.display_name if s else l.supplier_id, PartCondition.label(l.condition)]))
	var minus := T.button("−", false, 15, false, glass)
	minus.custom_minimum_size = Vector2(26, 24)
	minus.pressed.connect(add_to_basket.bind(l.id, -1))
	h.add_child(minus)
	var ql := T.label(str(qty), "mono_bold", 17, T.TEXT)
	ql.custom_minimum_size.x = 26
	ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(ql)
	var plus := T.button("+", false, 15, false, glass)
	plus.custom_minimum_size = Vector2(26, 24)
	plus.disabled = qty >= l.available
	plus.pressed.connect(add_to_basket.bind(l.id, 1))
	h.add_child(plus)
	h.add_child(T.cell(T.money(l.unit_price * qty), 76, T.TEXT))
	return h


func _order_row(o: PartsOrder) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	var top := HBoxContainer.new()
	var idl := T.label(o.id, "mono_bold", 15, T.TEXT)
	idl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(idl)
	top.add_child(T.tag("delayed" if o.delayed else "on its way", T.BAD if o.delayed else T.AMBER, 13))
	var m := o.eta_minute % 1440
	top.add_child(T.cell("DAY %d %02d:%02d" % [o.eta_day + 1, m / 60, m % 60], 112, T.ORANGE))
	col.add_child(top)
	var names := PackedStringArray()
	for line in o.lines:
		names.append("%d× %s" % [line.qty, bus.part_name(line.part)])
	var w := T.label(", ".join(names), "body", 14, T.DIM)
	w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(w)
	return col


func _sum(what: String, value: String) -> Control:
	var h := HBoxContainer.new()
	var l := T.label(what, "display_medium", 15, T.DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(T.label(value, "mono_medium", 15, T.TEXT))
	return h


func _due_text(q: PartsQuote) -> String:
	if q == null or not q.ok:
		return "—"
	var m := q.eta_minute % 1440
	return "DAY %d  %02d:%02d" % [q.eta_day + 1, m / 60, m % 60]


## The purchase order as {listing_id, qty} lines, in the order they were added.
func basket_as_lines() -> Array:
	var out := []
	for id in basket:
		out.append({"listing_id": id, "qty": basket[id]})
	return out


func add_to_basket(listing_id: String, delta: int) -> void:
	var l := bus.get_listing(listing_id)
	if l == null:
		return
	var qty := clampi(int(basket.get(listing_id, 0)) + delta, 0, l.available)
	if qty == 0:
		basket.erase(listing_id)
	else:
		basket[listing_id] = qty
	_message = ""
	refresh()


func clear_basket() -> void:
	basket.clear()
	_message = ""
	refresh()


func place_order() -> BusinessResult:
	var r := bus.place_market_order(basket_as_lines())
	if r.is_ok():
		basket.clear()
		_message = "Placed %s for %s CR." % [", ".join(r.order_ids), T.money(r.cost)]
		_message_good = true
		Sfx.play("chime")
	else:
		Sfx.play("error")
		_message = r.message.left(1).to_upper() + r.message.substr(1) + "."
		_message_good = false
	refresh()
	_dirty = false
	return r


func _prune_basket() -> void:
	for id in basket.keys():
		var l := bus.get_listing(id)
		if l == null or l.available <= 0:
			basket.erase(id)
		elif basket[id] > l.available:
			basket[id] = l.available


# --- ACCOUNTS -------------------------------------------------------------------------------

func _refresh_accounts() -> void:
	var figures := get_child(0) as VBoxContainer
	for c in figures.get_children():
		c.queue_free()
	figures.add_child(T.figure("Cash", "%s CR" % T.money(bus.get_cash()), T.BAD if bus.get_cash() < 0 else T.ORANGE, glass))
	figures.add_child(T.figure("Reputation", "%d / 100" % roundi(bus.get_reputation()), T.TEXT, glass))
	figures.add_child(T.figure("Bay rent", "%s CR / DAY" % T.money(bus.get_rules().bay_rent_per_day), T.TEXT, glass))
	if bus.is_insolvent():
		figures.add_child(T.label("INSOLVENT: ordering is stopped.", "display_bold", 20, T.BAD))
	for c in _list.get_children():
		c.queue_free()
	var entries := bus.get_ledger()
	if entries.is_empty():
		_list.add_child(T.label("No entries yet.", "body", 18, T.DIM))
	var n := 0
	for i in range(entries.size() - 1, maxi(-1, entries.size() - 1 - MAX_ROWS), -1):
		var e := entries[i]
		var what := "    %s  %s" % [e.category.to_upper(), e.ref if e.note == "" else "%s · %s" % [e.ref, e.note]]
		var text := T.label(what, "body", 16, T.TEXT)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.clip_text = true
		_list.add_child(T.row([T.cell("D%d" % (e.day + 1), 52), text,
				T.cell(("+" if e.amount > 0 else "") + T.money(e.amount), 110, T.GOOD if e.amount > 0 else T.BAD, "mono_bold")], n % 2 == 1, glass))
		n += 1
