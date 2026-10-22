extends HBoxContainer
## Business's channels on the wrist holo screen, drawn on glass with UI's TerminalKit so they
## match the yard terminal. The wrist draws the header and tabs; this is only the body.
##   "orders":   the market by category (search, category chips, +), the purchase order, and
##               the deliveries: what's on order and what has come, filtered the same way
##   "goods":    what's on order and when it lands, and the store by category (search, chips)
##   "accounts": cash and reputation, money in and out by kind over a day, week or month,
##               a day-by-day graph and the ledger
## Rows use a compact size (COMPACT) so more fits on a screen.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const MAX_ROWS := 120
## Text in list rows is drawn at this share of TerminalKit's size.
const COMPACT := 0.82
## How many past deliveries the Orders page lists.
const DELIVERED_SHOWN := 25
## Accounts periods: label -> game days.
const PERIODS := {"today": 1, "week": 7, "month": 30}
const GROUP_NAMES := {"contracts": "Contracts", "sales": "Items sold", "parts": "Items bought",
		"wages": "Wages and bonuses", "rent": "Bay rent", "loans": "Loans", "other": "Other"}

var bus: BusinessBus
var page := "orders"
var glass := true
var category := ""
var query := ""
## Orders page: "on order" or "delivered".
var deliveries := "on order"
## Goods in: the store's category and search.
var store_category := ""
var store_query := ""
## Accounts: a key of PERIODS.
var period := "week"

var _search: LineEdit
var _chips: Control
var _list: VBoxContainer
var _side: VBoxContainer
var _store: VBoxContainer
var _store_chips: Control
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
			"order_delayed": 1, "reputation_changed": 3, "day_closed": 1, "stock_added": 4}
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
	elif page == "goods":
		main.add_child(T.columns([["ON ORDER", 0], ["LANDS", 112]]))
		var find := T.search("Search the store", func(t: String) -> void:
			store_query = t.strip_edges().to_lower()
			_refresh_goods(), glass)
		find.name = "StoreSearch"
		_side.add_child(find)
		_store_chips = VBoxContainer.new()
		_side.add_child(_store_chips)
		_side.add_child(T.columns([["IN STORE", 0], ["COND.", 92], ["QTY", 90]]))
		_store = T.list()
		_side.add_child(_store.get_parent())
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
	elif page == "goods":
		_refresh_goods()
	else:
		_refresh_accounts()


# --- ORDERS ---------------------------------------------------------------------------------

func _refresh_chips() -> void:
	var holder := _chips
	_clear(holder)
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
	_clear(_list)
	var shown := shown_listings()
	if category == "":
		# Every category: grouped under headings, in the catalogue's category order.
		shown.sort_custom(func(a: MarketListing, b: MarketListing) -> bool:
			var ca := bus.listing_category(a)
			var cb := bus.listing_category(b)
			if ca != cb:
				return ca < cb
			var na := bus.part_name(a.part)
			var nb := bus.part_name(b.part)
			return na < nb if na != nb else a.unit_price < b.unit_price)
	var last := ""
	for i in mini(shown.size(), MAX_ROWS):
		var cat := bus.listing_category(shown[i])
		if category == "" and cat != last:
			_list.add_child(_heading(cat, shown.filter(func(l: MarketListing) -> bool: return bus.listing_category(l) == cat).size()))
			last = cat
		_list.add_child(_listing_row(shown[i], i % 2 == 1))
	if shown.is_empty():
		_list.add_child(T.label("Nothing matches." if query != "" else "Nothing on the market here today.", "body", 18, T.DIM))
	scroll.set_deferred("scroll_vertical", keep)


func _listing_row(l: MarketListing, alt: bool) -> Control:
	var s := bus.supplier(l.supplier_id)
	var add := T.button("+", true, 16, false, glass)
	add.name = "Add_" + l.id
	add.custom_minimum_size = Vector2(30, 24)
	add.disabled = int(basket.get(l.id, 0)) >= l.available
	add.pressed.connect(add_to_basket.bind(l.id, 1))
	var cond := PartCondition.label(l.condition)
	return compact(T.row([
		T.cell_text(bus.part_name(l.part), "%s  ·  %s" % [s.display_name if s else l.supplier_id, bus.listing_category(l)]),
		_width(T.tag(cond, _condition_colour(l.condition)), 92),
		T.cell("%dH" % l.lead_hours, 58),
		T.cell(str(l.available) if l.available < 999 else "∞", 52),
		T.cell(T.money(l.unit_price), 96, T.TEXT, "mono_bold"),
		_width(_centred(add), 46),
	], alt, glass))


## A category heading in a list, with how many lines are under it.
func _heading(cat: String, count: int) -> Control:
	var h := HBoxContainer.new()
	var l := T.label(cat.to_upper() if cat != "" else "OTHER", "display_bold", 16, T.ORANGE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(T.label(str(count), "mono_medium", 14, T.DIM))
	var pad := MarginContainer.new()
	pad.name = "Heading_" + (cat if cat != "" else "other").validate_node_name()
	pad.add_theme_constant_override("margin_left", 4)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_child(h)
	return pad


## Shrinks a row's text to COMPACT and its padding, so a screen holds more lines.
static func compact(c: Control) -> Control:
	if c is PanelContainer:
		var st := c.get_theme_stylebox("panel") as StyleBoxFlat
		if st:
			st.content_margin_top = 2
			st.content_margin_bottom = 2
	var labels: Array = c.find_children("*", "Label", true, false)
	if c is Label:
		labels.append(c)
	for l: Label in labels:
		if l.has_theme_font_size_override("font_size"):
			l.add_theme_font_size_override("font_size", maxi(10, roundi(l.get_theme_font_size("font_size") * COMPACT)))
	return c


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


## Frees what's in a box, renaming it first so new children keep their names (it may hold
## the button being pressed, so it stays in the tree until freed).
func _clear(box: Node) -> void:
	for c in box.get_children():
		c.name = "Old_" + str(c.get_instance_id())
		c.queue_free()


func _width(c: Control, w: float) -> Control:
	c.custom_minimum_size.x = w
	return c


func _centred(c: Control) -> CenterContainer:
	var box := CenterContainer.new()
	box.add_child(c)
	return box


## Text on a docket: light on glass, ink on the paper an opaque screen (a TV) draws.
func _ink() -> Color:
	return T.TEXT if glass else T.INK


func _ink_dim() -> Color:
	return T.DIM if glass else T.INK_DIM


func _refresh_side() -> void:
	_clear(_side)
	var po := T.docket("Purchase order", "BSX/PO", glass)
	var body := po.body as VBoxContainer
	var lines := basket_as_lines()
	if lines.is_empty():
		body.add_child(T.label("Empty. Press + on a part to add it.", "body", 16, _ink_dim()))
	for line: Dictionary in lines:
		body.add_child(_po_line(bus.get_listing(line.listing_id), int(line.qty)))
	var q := bus.quote_market(lines) if not lines.is_empty() else null
	var cost := q.cost if q and q.ok else 0
	body.add_child(_sum("DUE AT DELIVERIES", _due_text(q)))
	body.add_child(_sum("CASH AFTER", "%s CR" % T.money(bus.get_cash() - cost)))
	var total := HBoxContainer.new()
	var tl := T.label("TOTAL", "display_bold", 24, _ink())
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

	# Deliveries: what is on its way, or what has come, in the category picked on the left.
	var dl := T.docket("Deliveries", category.to_upper(), glass)
	dl.panel.name = "Deliveries"
	dl.panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pick := T.chips(PackedStringArray(["on order", "delivered"]), deliveries, func(n: String) -> void:
		deliveries = n
		refresh(), glass, false)
	pick.name = "DeliveryChips"
	(dl.body as VBoxContainer).add_child(pick)
	var list := T.list()
	(dl.body as VBoxContainer).add_child(list.get_parent())
	var shown := shown_deliveries()
	if shown.is_empty():
		var none := "Nothing on order" if deliveries == "on order" else "Nothing delivered yet"
		list.add_child(T.label(none + (" in %s." % category if category != "" else "."), "body", 16, _ink_dim()))
	for o in shown:
		list.add_child(_order_row(o, true))
	_side.add_child(dl.panel)


## The orders the Deliveries docket lists: on order (soonest first) or delivered (newest
## first, the last DELIVERED_SHOWN), holding a part in the picked category.
func shown_deliveries() -> Array[PartsOrder]:
	var on_order := deliveries == "on order"
	var out: Array[PartsOrder] = bus.get_orders(PartsOrder.State.PLACED if on_order else PartsOrder.State.DELIVERED)
	if category != "":
		out = out.filter(func(o: PartsOrder) -> bool:
			return o.lines.any(func(line: OrderLine) -> bool: return _category_of(line.part) == category))
	out.sort_custom(func(a: PartsOrder, b: PartsOrder) -> bool:
		return a.eta_minute < b.eta_minute if on_order else a.eta_minute > b.eta_minute)
	return out if on_order else out.slice(0, DELIVERED_SHOWN)


## A part's category on the market, for the store and deliveries: the catalogue's, raw
## materials, or a supplier's staples.
func _category_of(part: String) -> String:
	if part.begins_with(BusinessBus.RAW_PREFIX):
		return "materials"
	var cat := bus.get_catalogue().category_of(part)
	return cat if cat != "" else "staples"


func _po_line(l: MarketListing, qty: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var s := bus.supplier(l.supplier_id)
	var names := T.cell_text(bus.part_name(l.part), "%s  ·  %s" % [s.display_name if s else l.supplier_id, PartCondition.label(l.condition)])
	for i in names.get_child_count():
		(names.get_child(i) as Label).add_theme_color_override("font_color", _ink() if i == 0 else _ink_dim())
	h.add_child(names)
	var minus := T.button("−", false, 15, false, glass)
	minus.custom_minimum_size = Vector2(26, 24)
	minus.pressed.connect(add_to_basket.bind(l.id, -1))
	h.add_child(minus)
	var ql := T.label(str(qty), "mono_bold", 17, _ink())
	ql.custom_minimum_size.x = 26
	ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(ql)
	var plus := T.button("+", false, 15, false, glass)
	plus.custom_minimum_size = Vector2(26, 24)
	plus.disabled = qty >= l.available
	plus.pressed.connect(add_to_basket.bind(l.id, 1))
	h.add_child(plus)
	h.add_child(T.cell(T.money(l.unit_price * qty), 76, _ink()))
	return h


func _order_row(o: PartsOrder, on_paper := false) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	var top := HBoxContainer.new()
	var idl := T.label(o.id, "mono_bold", 15, _ink() if on_paper else T.TEXT)
	idl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(idl)
	if o.state == PartsOrder.State.DELIVERED:
		top.add_child(T.tag("came late" if o.delayed else "delivered", T.AMBER if o.delayed else T.GOOD, 13))
	else:
		top.add_child(T.tag("delayed" if o.delayed else "on its way", T.BAD if o.delayed else T.AMBER, 13))
	var m := o.eta_minute % 1440
	top.add_child(T.cell("DAY %d %02d:%02d" % [o.eta_day + 1, m / 60, m % 60], 112, T.ORANGE))
	col.add_child(top)
	var names := PackedStringArray()
	for line in o.lines:
		names.append("%d× %s" % [line.qty, bus.part_name(line.part)])
	var w := T.label(", ".join(names), "body", 14, _ink_dim() if on_paper else T.DIM)
	w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(w)
	return compact(col)


func _sum(what: String, value: String) -> Control:
	var h := HBoxContainer.new()
	var l := T.label(what, "display_medium", 15, _ink_dim())
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(T.label(value, "mono_medium", 15, _ink()))
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

# --- GOODS IN -------------------------------------------------------------------------------

func _refresh_goods() -> void:
	_clear(_list)
	var open := bus.get_orders(PartsOrder.State.PLACED)
	if open.is_empty():
		_list.add_child(T.label("Nothing on order.", "body", 18, T.DIM))
	for o in open:
		_list.add_child(_order_row(o))
	_clear(_store)
	var stock := bus.get_stock_detail()
	var by_cat := {}
	for part: String in stock:
		var cat := _category_of(part)
		by_cat[cat] = int(by_cat.get(cat, 0)) + 1
	var cats := PackedStringArray(by_cat.keys())
	cats.sort()
	if store_category != "" and not store_category in cats:
		store_category = ""
	_clear(_store_chips)
	if cats.size() > 1:
		_store_chips.add_child(T.chips(cats, store_category, func(n: String) -> void:
			store_category = n
			_refresh_goods(), glass))
	var parts := stock.keys().filter(func(p: String) -> bool:
		return (store_category == "" or _category_of(p) == store_category) \
				and (store_query == "" or ("%s %s" % [bus.part_name(p), _category_of(p)]).to_lower().contains(store_query)))
	parts.sort_custom(func(a: String, b: String) -> bool:
		var ca := _category_of(a)
		var cb := _category_of(b)
		return ca < cb if ca != cb else bus.part_name(a) < bus.part_name(b))
	if parts.is_empty():
		_store.add_child(T.label("The store is empty." if stock.is_empty() else "Nothing matches.", "body", 18, T.DIM))
	var n := 0
	var last := ""
	for part: String in parts:
		var cat := _category_of(part)
		if cat != last:
			_store.add_child(_heading(cat, parts.filter(func(p: String) -> bool: return _category_of(p) == cat).size()))
			last = cat
		for c: String in PartCondition.ALL:
			if stock[part].has(c):
				var name_l := T.label(bus.part_name(part), "body_medium", 16, T.TEXT)
				name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				name_l.clip_text = true
				var qty := int(stock[part][c])
				var count := ("%s KG" % T.money(qty)) if part.begins_with(BusinessBus.RAW_PREFIX) else "×%d" % qty
				_store.add_child(compact(T.row([name_l, _width(T.tag(c, _condition_colour(c), 12), 92),
						T.cell(count, 90, T.TEXT, "mono_bold")], n % 2 == 1, glass)))
				n += 1


func _refresh_accounts() -> void:
	var figures := get_child(0) as VBoxContainer
	_clear(figures)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	for f: Control in [T.figure("Cash", "%s CR" % T.money(bus.get_cash()), T.BAD if bus.get_cash() < 0 else T.ORANGE, glass),
			T.figure("Reputation", "%d / 100" % roundi(bus.get_reputation()), T.TEXT, glass)]:
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(f)
	figures.add_child(top)
	if bus.is_insolvent():
		figures.add_child(T.label("INSOLVENT: ordering is stopped.", "display_bold", 20, T.BAD))
	var chips := T.chips(PackedStringArray(PERIODS.keys()), period, func(n: String) -> void:
		period = n
		refresh(), glass, false)
	chips.name = "PeriodChips"
	figures.add_child(chips)
	var sum := bus.accounts_summary(int(PERIODS[period]))
	var totals := HBoxContainer.new()
	totals.add_theme_constant_override("separation", 8)
	for f: Control in [T.figure("In", "+" + T.money(sum.income), T.GOOD, glass),
			T.figure("Out", "−" + T.money(sum.outgoings), T.BAD, glass),
			T.figure("Net", ("+" if sum.net >= 0 else "−") + T.money(absi(int(sum.net))), T.GOOD if sum.net >= 0 else T.BAD, glass)]:
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		compact(f)
		totals.add_child(f)
	figures.add_child(totals)
	figures.add_child(T.columns([["BY KIND", 0], ["IN", 96], ["OUT", 96]]))
	var kinds := T.list()
	kinds.name = "Kinds"
	figures.add_child(kinds.get_parent())
	var n := 0
	for g: String in sum.groups:
		var got: Dictionary = sum.groups[g]
		var what := T.label(str(GROUP_NAMES.get(g, g.capitalize())), "body_medium", 16, T.TEXT)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := compact(T.row([what,
				T.cell("+" + T.money(got["in"]) if got["in"] > 0 else "—", 96, T.GOOD if got["in"] > 0 else T.DIM, "mono_bold"),
				T.cell("−" + T.money(got["out"]) if got["out"] > 0 else "—", 96, T.BAD if got["out"] > 0 else T.DIM, "mono_bold")], n % 2 == 1, glass))
		row.name = "Group_" + g
		kinds.add_child(row)
		n += 1
	kinds.add_child(T.label("BAY RENT %s CR / DAY" % T.money(bus.get_rules().bay_rent_per_day), "display_medium", 14, T.DIM))

	# The graph: money in and out each day of the period (at least a week), over the ledger.
	var graph := _side.get_node_or_null("DayBars") as DayBars
	if graph == null:
		graph = DayBars.new()
		graph.name = "DayBars"
		_side.add_child(graph)
		_side.move_child(graph, 0)
	graph.days = bus.accounts_summary(maxi(7, int(PERIODS[period])))["days"]
	graph.glass = glass
	graph.queue_redraw()

	_clear(_list)
	var since := maxi(0, bus.get_day() - int(PERIODS[period]) + 1)
	var entries := bus.get_ledger(since)
	if entries.is_empty():
		_list.add_child(T.label("No entries in this period.", "body", 18, T.DIM))
	n = 0
	for i in range(entries.size() - 1, maxi(-1, entries.size() - 1 - MAX_ROWS), -1):
		var e := entries[i]
		var what := "%s  ·  %s" % [str(GROUP_NAMES.get(BusinessBus.account_group(e.category), "")).to_upper(),
				e.category.to_upper() + ("  " + e.ref if e.ref != "" else "") + ("  ·  " + e.note if e.note != "" else "")]
		var text := T.label(what, "body", 16, T.TEXT)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.clip_text = true
		_list.add_child(compact(T.row([T.cell("D%d" % (e.day + 1), 64), text,
				T.cell(("+" if e.amount > 0 else "") + T.money(e.amount), 110, T.GOOD if e.amount > 0 else T.BAD, "mono_bold")], n % 2 == 1, glass)))
		n += 1


## Money in (up, green) and out (down, red) for each day, with the day's net as a dot.
class DayBars extends Control:
	var days: Array = []
	var glass := true

	func _init() -> void:
		custom_minimum_size = Vector2(0, 150)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(T.PLATE, T.GLASS_PLATE if glass else 1.0))
		if days.is_empty():
			return
		var top := 1
		for d: Dictionary in days:
			top = maxi(top, maxi(int(d["in"]), int(d["out"])))
		var font := T.font("mono_medium")
		var pad_l := 8.0
		var pad_b := 18.0
		var mid := (size.y - pad_b) * 0.5
		var w := (size.x - pad_l * 2.0) / days.size()
		draw_line(Vector2(pad_l, mid), Vector2(size.x - pad_l, mid), Color(T.DIM, 0.6), 1.0)
		for i in days.size():
			var d: Dictionary = days[i]
			var x := pad_l + i * w
			var bw := maxf(2.0, w * 0.6)
			var hi := (mid - 6.0) * float(d["in"]) / top
			var lo := (mid - 6.0) * float(d["out"]) / top
			if hi > 0.0:
				draw_rect(Rect2(x + (w - bw) * 0.5, mid - hi, bw, hi), Color(T.GOOD, 0.85))
			if lo > 0.0:
				draw_rect(Rect2(x + (w - bw) * 0.5, mid, bw, lo), Color(T.BAD, 0.85))
			var net := (mid - 6.0) * float(int(d["in"]) - int(d["out"])) / top
			draw_circle(Vector2(x + w * 0.5, mid - net), 2.5, T.TEXT)
			if days.size() <= 10 or i % 5 == 0 or i == days.size() - 1:
				draw_string(font, Vector2(x, size.y - 4.0), "D%d" % (int(d["day"]) + 1), HORIZONTAL_ALIGNMENT_CENTER, w, 11, T.DIM)
		draw_string(font, Vector2(size.x - 120.0, 14.0), "TOP %s" % T.money(top), HORIZONTAL_ALIGNMENT_RIGHT, 112.0, 11, T.DIM)
