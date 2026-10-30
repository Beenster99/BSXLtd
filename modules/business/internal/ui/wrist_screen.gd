extends HBoxContainer
## Business's channels on the wrist holo screen, drawn on glass with UI's TerminalKit so they
## match the yard terminal. The wrist draws the header and tabs; this is only the body.
##   "orders":   BUY/SELL. Buy: the market by category (search, category chips, deals, +),
##               frame packages from the Frame Builder (PACKAGES: ORDER buys one),
##               the purchase order with bulk prices, and the deliveries: what's on order
##               and what has come. Sell: everything in stock with what each company offers
##               for it today, sold to the best offer; and today's sales
##   "accounts": cash and reputation, money in and out by kind over a day, week or month,
##               a day-by-day graph and the ledger
## Rows use a compact size (COMPACT) so more fits on a screen.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const MAX_ROWS := 120
## The buy list holds every listing (well over a thousand under ALL), so only the lines in
## view and this many past each edge are built; spacers stand in for the rest.
const WINDOW_SPARE := 16
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
## How many order lines the list shows; SHOW MORE adds another MAX_ROWS.
var limit := MAX_ROWS
## Buy/Sell page: "buy" (the market) or "sell" (the stock, to other companies).
var mode := "buy"
## Buy side: the cost estimator is out in place of the purchase order (+ adds to it).
var estimating := false
## Buy side: the listing whose terms (deal, bulk prices, standing) show over the purchase
## order, picked by clicking its line; "" for none.
var picked := ""
## Sell side: the stock line ("<part>|<condition>") whose buyers show over the sales; "" for
## none.
var picked_stock := ""
## Orders page: "on order" or "delivered".
var deliveries := "on order"
## Accounts: a key of PERIODS.
var period := "week"

var _search: LineEdit
var _chips: Control
var _mode_chips: Control
var _columns: Control
var _list: VBoxContainer
var _side: VBoxContainer
var _message := ""
var _message_good := true
var _dirty := false
## The buy list as laid out: a category heading (String), a frame package (Dictionary) or a
## MarketListing per entry, each
## entry's top in the list (pixels, one more for the end), and the entries built now.
var _entries: Array = []
var _offsets := PackedFloat32Array()
var _counts := {}
var _built := Vector2i(-1, -1)
var _row_h := 0.0
var _head_h := 0.0
var _pkg_h := 0.0
var _measured_in_tree := false
## The category and search the list was last drawn for: a new one starts at the top.
var _list_key := ""


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
	bus.order_refused.connect(_on_order_refused)
	bus.package_changed.connect(_mark_dirty.unbind(1))
	bus.clock_changed.connect(func(_m: int) -> void: _tick_countdowns())


## The purchase order being built, kept on the bus so it survives closing the wrist.
var basket: Dictionary:
	get:
		return bus.wrist_basket


## The cost estimate being built, kept on the bus too.
var estimate: Dictionary:
	get:
		return bus.wrist_estimate


func _mark_dirty() -> void:
	_dirty = true


func _notification(what: int) -> void:
	# Lines measured before the screen had a theme are measured again in it.
	if what == NOTIFICATION_ENTER_TREE and page == "orders" and not _measured_in_tree:
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
		_mode_chips = HBoxContainer.new()
		top.add_child(_mode_chips)
		_search = T.search("Search parts", func(t: String) -> void:
			query = t.strip_edges().to_lower()
			limit = MAX_ROWS
			_refresh_list(), glass)
		top.add_child(_search)
		_chips = HBoxContainer.new()
		_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(_chips)
		main.add_child(top)
		_columns = VBoxContainer.new()
		main.add_child(_columns)
	else:
		_side.size_flags_stretch_ratio = 1.6
		main.size_flags_stretch_ratio = 1.0
		main.add_theme_constant_override("separation", 10)
		main.name = "Figures"
		var ledger_head := T.columns([["DAY", 52], ["LEDGER", 0], ["CR", 110]])
		_side.add_child(ledger_head)
	_list = T.list()
	(_side if page == "accounts" else main).add_child(_list.get_parent())
	if page == "orders":
		(_list.get_parent() as ScrollContainer).get_v_scroll_bar().value_changed.connect(_on_list_scrolled)
	refresh()


func refresh() -> void:
	_prune_basket()
	if page == "orders":
		_refresh_chips()
		if mode == "sell":
			_refresh_sell()
			_refresh_sales()
		else:
			_refresh_list()
			if estimating:
				_refresh_estimate()
			else:
				_refresh_side()
	else:
		_refresh_accounts()


# --- ORDERS ---------------------------------------------------------------------------------

func _refresh_chips() -> void:
	_clear(_mode_chips)
	var modes := HBoxContainer.new()
	modes.name = "ModeChips"
	modes.add_theme_constant_override("separation", 4)
	for n: String in ["buy", "sell"]:
		var b := T.button(n.to_upper(), false, 16, n == mode, glass)
		b.name = "Mode_" + n
		b.pressed.connect(func() -> void:
			mode = n
			category = ""
			limit = MAX_ROWS
			refresh())
		modes.add_child(b)
	if mode == "buy":
		var est := T.button("ESTIMATE", false, 16, estimating, glass)
		est.name = "Estimate"
		est.tooltip_text = "Price a list of parts without ordering them"
		est.pressed.connect(toggle_estimator)
		modes.add_child(est)
	_mode_chips.add_child(modes)
	_search.placeholder_text = "Search the stock" if mode == "sell" else "Search parts"
	_clear(_columns)
	if mode == "sell":
		_columns.add_child(T.columns([["IN STOCK  /  OTHER OFFERS", 0], ["COND.", 92], ["HELD", 52], ["BEST CR", 96], ["", 126]]))
	else:
		_columns.add_child(T.columns([["PART  /  SUPPLIER", 0], ["COND.", 92], ["LEFT", 52], ["UNIT CR", 96], ["", 46]]))
	var holder := _chips
	_clear(holder)
	var flow := T.chips(_categories(), category, func(n: String) -> void:
		category = n
		limit = MAX_ROWS
		refresh(), glass)
	holder.add_child(flow)


func _categories() -> PackedStringArray:
	var seen := {}
	var deals := false
	if mode == "sell":
		for line in stock_lines(""):
			seen[_category_of(line.part)] = true
	else:
		for l in bus.get_listings():
			seen[bus.listing_category(l)] = true
			deals = deals or l.list_price > l.unit_price
	var out := PackedStringArray(seen.keys())
	out.sort()
	if deals:
		out.insert(0, "deals")
	if mode == "buy" and not bus.get_packages().is_empty():
		out.insert(0, "packages")
	return out


## The listings shown: in the category, in stock, matching the search (part, supplier or
## category).
func shown_listings() -> Array[MarketListing]:
	var out: Array[MarketListing] = []
	if category == "packages":
		return out
	for l in bus.get_listings("" if category == "deals" else category):
		if l.available <= 0:
			continue
		if category == "deals" and l.list_price <= l.unit_price:
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
	if _list_key != category + "|" + query:
		_list_key = category + "|" + query
		keep = 0
	_drop_rows()
	_entries.clear()
	_counts.clear()
	_built = Vector2i(-1, -1)
	var shown := shown_listings()
	# Each listing's category, read once (the market holds over a thousand lines and the sort
	# below compared them by category and name thousands of times: a second's stall).
	var cats := {}
	for l in shown:
		cats[l] = bus.listing_category(l)
	if category == "":
		# Every category: grouped under headings, in the catalogue's category order.
		var names := {}
		for l in shown:
			names[l] = bus.part_name(l.part)
		shown.sort_custom(func(a: MarketListing, b: MarketListing) -> bool:
			var ca: String = cats[a]
			var cb: String = cats[b]
			if ca != cb:
				return ca < cb
			var na: String = names[a]
			var nb: String = names[b]
			return na < nb if na != nb else a.unit_price < b.unit_price)
	# Frame packages first: under their own heading in ALL, alone under PACKAGES.
	var packages := shown_packages()
	if not packages.is_empty():
		_counts["packages"] = packages.size()
		if category == "":
			_entries.append("packages")
		_entries.append_array(packages)
	var last: Variant = null
	for l in shown:
		var cat: String = cats[l]
		_counts[cat] = int(_counts.get(cat, 0)) + 1
		if category == "" and cat != last:
			_entries.append(cat)
			last = cat
		_entries.append(l)
	if _entries.is_empty():
		var none := "Nothing matches." if query != "" else "Nothing on the market here today."
		if category == "packages":
			none = "No packages. Commit a frame in the Frame Builder (O) to make one."
		_list.add_child(T.label(none, "body", 18, T.DIM))
		return
	_lay_out()
	_draw_window(keep)
	scroll.set_deferred("scroll_vertical", keep)


## Every line of the buy list is the same height, and every heading: measured once from a
## real one, then each entry's top follows.
func _lay_out() -> void:
	# Each kind of line is measured once (again once in the tree), when the list first has one.
	var all := not _measured_in_tree
	var measure: Array = []
	if all or _head_h == 0.0:
		measure.append(_entries[0] if _entries[0] is String else "")
	if all or _row_h == 0.0:
		measure.append(_first_listing())
	if all or _pkg_h == 0.0:
		measure.append(_first_package())
	if all:
		_measured_in_tree = _list.is_inside_tree()
	if not measure.is_empty():
		for e: Variant in measure:
			if e == null:
				continue
			var c := _entry(e, 0)
			_list.add_child(c)
			var h := c.get_combined_minimum_size().y
			if e is String:
				_head_h = h
			elif e is Dictionary:
				_pkg_h = h
			else:
				_row_h = h
			_list.remove_child(c)
			c.free()
	var sep := float(_list.get_theme_constant("separation"))
	_offsets.resize(_entries.size() + 1)
	var y := 0.0
	for i in _entries.size():
		_offsets[i] = y
		var e: Variant = _entries[i]
		y += (_head_h if e is String else _pkg_h if e is Dictionary else _row_h) + sep
	_offsets[_entries.size()] = y


func _first_package() -> Variant:
	for e: Variant in _entries:
		if e is Dictionary:
			return e
	return null


func _first_listing() -> MarketListing:
	for e: Variant in _entries:
		if e is MarketListing:
			return e
	return null


## Builds the entries in view at scroll position `at` (pixels), unless they're built already.
func _draw_window(at: float) -> void:
	if _entries.is_empty() or _offsets.size() != _entries.size() + 1:
		return
	var scroll := _list.get_parent() as ScrollContainer
	var view := maxf(scroll.size.y, 400.0)
	var first := maxi(0, _entry_at(at) - WINDOW_SPARE)
	var last := mini(_entries.size() - 1, _entry_at(at + view) + WINDOW_SPARE)
	if _built.x >= 0 and first >= _built.x and last <= _built.y:
		return
	# Build a little further than needed so a slow scroll doesn't rebuild every step.
	first = maxi(0, first - WINDOW_SPARE)
	last = mini(_entries.size() - 1, last + WINDOW_SPARE)
	_drop_rows()
	var sep := float(_list.get_theme_constant("separation"))
	if first > 0:
		_list.add_child(_spacer("Above", _offsets[first] - sep))
	var row := 0
	for i in first:
		if _entries[i] is MarketListing:
			row += 1
	for i in range(first, last + 1):
		_list.add_child(_entry(_entries[i], row))
		if _entries[i] is MarketListing:
			row += 1
	if last < _entries.size() - 1:
		_list.add_child(_spacer("Below", _offsets[_entries.size()] - _offsets[last + 1] - sep))
	_built = Vector2i(first, last)


func _entry(e: Variant, row: int) -> Control:
	if e is String:
		return _heading(e, int(_counts.get(e, 0)))
	if e is Dictionary:
		return _package_row(e, row % 2 == 1)
	return _listing_row(e, row % 2 == 1)


## The entry at height `y` in the list.
func _entry_at(y: float) -> int:
	return clampi(_offsets.bsearch(y, false) - 1, 0, _entries.size() - 1)


func _spacer(n: String, h: float) -> Control:
	var c := Control.new()
	c.name = n
	c.custom_minimum_size.y = maxf(0.0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _on_list_scrolled(at: float) -> void:
	if page == "orders" and mode == "buy" and not _entries.is_empty():
		_draw_window(at)


## Takes the list's lines out at once (a pressed + may be one of them, so they're freed
## after), so the windowed list never lays out stale lines.
func _drop_rows() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()


func _listing_row(l: MarketListing, alt: bool) -> Control:
	var s := bus.supplier(l.supplier_id)
	var add := T.button("+", true, 16, false, glass)
	add.name = "Add_" + l.id
	add.custom_minimum_size = Vector2(30, 24)
	if estimating:
		add.name = "Estimate_" + l.id
		add.tooltip_text = "Add to the estimate"
		add.pressed.connect(add_to_estimate.bind(l.id, 1))
	else:
		add.disabled = int(basket.get(l.id, 0)) >= l.available
		add.pressed.connect(add_to_basket.bind(l.id, 1))
	var cond := PartCondition.label(l.condition)
	var deal := l.deal_off()
	var row := compact(T.row([
		T.cell_text(bus.part_name(l.part), _terms_line(l)),
		_width(T.tag(cond, _condition_colour(l.condition)), 92),
		T.cell(str(l.available) if l.available < 999 else "∞", 52),
		T.cell(T.money(l.unit_price), 96, T.GOOD if deal > 0 else T.TEXT, "mono_bold"),
		_width(_centred(add), 46),
	], alt or l.id == picked, glass))
	row.name = "Listing_" + l.id.validate_node_name()
	_click_to(row, pick_listing.bind(l.id))
	return row


## A line's small print: its supplier and category, today's deal, the bulk prices its stock
## can reach and the company's own discount there.
func _terms_line(l: MarketListing) -> String:
	var s := bus.supplier(l.supplier_id)
	var out := PackedStringArray([s.display_name if s else l.supplier_id, bus.listing_category(l)])
	var deal := l.deal_off()
	if deal > 0:
		out.append("DEAL %d%% OFF TODAY, WAS %s" % [deal, T.money(l.list_price)])
	var tiers := PackedStringArray()
	for t: Vector2i in bulk_tiers(l):
		tiers.append("%d+ %d%%" % [t.x, t.y])
	if not tiers.is_empty():
		out.append("BULK " + "  ".join(tiers))
	var mine := int(bus.standing_with(l.supplier_id).off)
	if mine > 0:
		out.append("YOU GET %d%% OFF" % mine)
	return "  ·  ".join(out)


## The bulk prices a listing's stock can reach: (quantity, percent off) by quantity.
func bulk_tiers(l: MarketListing) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var s := bus.supplier(l.supplier_id)
	if s == null or l.id.begins_with("S-"):
		return out
	var keys := s.bulk_percent.keys()
	keys.sort()
	for n: Variant in keys:
		if int(n) <= l.available:
			out.append(Vector2i(int(n), int(s.bulk_percent[n])))
	return out


## Shows a listing's terms over the purchase order (again: hides them).
func pick_listing(listing_id: String) -> void:
	picked = "" if picked == listing_id else listing_id
	refresh()


## Calls `then` when a row is clicked (its buttons keep their own clicks).
func _click_to(row: Control, then: Callable) -> void:
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(func(e: InputEvent) -> void:
		var b := e as InputEventMouseButton
		if b and b.pressed and b.button_index == MOUSE_BUTTON_LEFT:
			then.call())


## The frame packages the Buy list shows (ALL and PACKAGES), newest first, matching the search.
func shown_packages() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if mode != "buy" or (category != "" and category != "packages"):
		return out
	for pkg in bus.get_packages():
		if query == "" or ("%s %s package" % [pkg.title, pkg.ref]).to_lower().contains(query):
			out.append(pkg)
	return out


## A package's line: its title, ref, size and who it would come from; PROPOSED ones show
## today's best price and ORDER, ordered ones what was paid.
func _package_row(pkg: Dictionary, alt: bool) -> Control:
	var items := 0
	for item: Dictionary in pkg.items:
		items += int(item.qty)
	var small := PackedStringArray([str(pkg.ref), "%d item%s" % [items, "" if items == 1 else "s"]])
	var cost := int(pkg.cost)
	var state: Control
	var drop: Control = Control.new()
	if pkg.state == "proposed":
		var plan := bus.quote_package(pkg.ref)
		cost = int(plan.cost)
		var missing: Array = plan.missing
		if missing.is_empty():
			var names := PackedStringArray()
			for sid: String in plan.suppliers:
				var s := bus.supplier(sid)
				names.append(s.display_name if s else sid)
			small.append(", ".join(names))
		else:
			small.append("NOBODY HAS %s TODAY" % ", ".join(missing).to_upper())
		var order := T.button("ORDER", true, 15, false, glass)
		order.name = "Order_" + str(pkg.ref)
		order.tooltip_text = "Buy every part in this package"
		order.custom_minimum_size = Vector2(84, 24)
		order.disabled = not missing.is_empty() or cost > bus.get_cash()
		order.pressed.connect(order_package.bind(str(pkg.ref)))
		state = _width(_centred(order), 92)
		var x := T.button("✕", false, 15, false, glass)
		x.name = "Drop_" + str(pkg.ref)
		x.tooltip_text = "Remove this package"
		x.custom_minimum_size = Vector2(30, 24)
		x.pressed.connect(drop_package.bind(str(pkg.ref)))
		drop = x
	else:
		small.append(", ".join(pkg.order_ids))
		state = _width(T.tag("ORDERED", T.GOOD), 92)
	if str(pkg.destination) == "courtyard":
		small.append("TO THE COURTYARD")
	var row := compact(T.row([
		T.cell_text(str(pkg.title), "  ·  ".join(small)),
		state,
		T.cell(str(items), 52),
		T.cell(T.money(cost), 96, T.ORANGE, "mono_bold"),
		_width(_centred(drop), 46),
	], alt, glass))
	row.name = "Package_" + str(pkg.ref).validate_node_name()
	return row


## Buys a package (ORDER on its line).
func order_package(ref: String) -> BusinessResult:
	var r := bus.order_package(ref)
	if r.is_ok():
		if r.order_ids.is_empty():
			_message = "Package %s sent to the host." % ref
		else:
			_message = "Ordered %s for %s CR. It comes straight to the courtyard." % [ref, T.money(r.cost)]
		_message_good = true
		Sfx.play("chime")
	else:
		Sfx.play("error")
		_message = r.message.left(1).to_upper() + r.message.substr(1) + "."
		_message_good = false
	refresh()
	_dirty = false
	return r


## Removes a package that hasn't been ordered (✕ on its line).
func drop_package(ref: String) -> void:
	bus.cancel_package(ref)
	if category == "packages" and bus.get_packages().is_empty():
		category = ""
	refresh()


## The terms of the picked listing: today's deal, what each bulk quantity costs, the
## company's standing with the supplier and when it arrives. In Deals with nothing picked,
## how deals work.
func _terms_docket() -> Control:
	var l := bus.get_listing(picked) if picked != "" else null
	var d := T.docket("The deal" if l and l.deal_off() > 0 else "Terms", "BSX/TERMS", glass)
	d.panel.name = "Terms"
	var body := d.body as VBoxContainer
	if l == null:
		var how := T.label("Deals are today's price cuts: each supplier marks a few lines down until the market changes tomorrow. Bulk prices come off the deal price as well. Click a part to see its terms.", "body", 15, _ink())
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(how)
		return d.panel
	var s := bus.supplier(l.supplier_id)
	var head := T.label("%s  ·  %s" % [bus.part_name(l.part), PartCondition.label(l.condition)], "body_medium", 17, _ink())
	head.clip_text = true
	body.add_child(head)
	body.add_child(T.label(s.display_name if s else l.supplier_id, "display_medium", 14, _ink_dim()))
	if l.deal_off() > 0:
		body.add_child(_sum("TODAY ONLY", "%d%% OFF" % l.deal_off()))
		body.add_child(_sum("WAS", "%s CR" % T.money(l.list_price)))
	var mine := bus.standing_with(l.supplier_id)
	var tiers := bulk_tiers(l)
	body.add_child(_sum("BUY 1%s" % ("" if tiers.is_empty() else " TO %d" % (tiers[0].x - 1)), "%s CR EACH" % T.money(bus.listing_cost(l, 1))))
	for t in tiers:
		body.add_child(_sum("BUY %d OR MORE" % t.x, "%s CR EACH  (−%d%%)" % [T.money(roundi(bus.listing_cost(l, t.x) / float(t.x))), t.y + int(mine.off)]))
	if s and not l.id.begins_with("S-") and tiers.size() < s.bulk_percent.size():
		var short := T.label("Only %d left, so the bigger bulk prices can't be reached." % l.available, "body", 14, _ink_dim())
		short.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(short)
	body.add_child(_sum("YOU ARE", "%s%s" % [str(mine.name).to_upper(), "  (−%d%%)" % mine.off if int(mine.off) > 0 else ""]))
	body.add_child(_sum("ARRIVES IN", "ABOUT %d S" % l.lead_seconds))
	return d.panel


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
	if picked != "" and bus.get_listing(picked) == null:
		picked = ""
	if picked != "" or category == "deals":
		_side.add_child(_terms_docket())
	var po := T.docket("Purchase order", "BSX/PO", glass)
	var body := po.body as VBoxContainer
	var lines := basket_as_lines()
	if lines.is_empty():
		body.add_child(T.label("Empty. Press + on a part to add it.", "body", 16, _ink_dim()))
	for line: Dictionary in lines:
		body.add_child(_po_line(bus.get_listing(line.listing_id), int(line.qty)))
	var q := bus.quote_market(lines) if not lines.is_empty() else null
	var cost := q.cost if q and q.ok else 0
	if q and q.ok and q.saving > 0:
		body.add_child(_sum("BULK SAVING", "%s CR" % T.money(q.saving)))
	body.add_child(_sum("ARRIVES", _due_text(q)))
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
	if category == "packages":
		out = out.filter(func(o: PartsOrder) -> bool: return o.package_ref != "")
	elif category != "" and category != "deals":
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
	return bus.part_category(part)


func _po_line(l: MarketListing, qty: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var s := bus.supplier(l.supplier_id)
	var cost := bus.listing_cost(l, qty)
	var sub := "%s  ·  %s" % [s.display_name if s else l.supplier_id, PartCondition.label(l.condition)]
	if cost < l.unit_price * qty:
		sub += "  ·  BULK %d%% OFF" % roundi(100.0 - 100.0 * cost / (l.unit_price * qty))
	var names := T.cell_text(bus.part_name(l.part), sub)
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
	h.add_child(T.cell(T.money(cost), 76, _ink()))
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
	if o.state == PartsOrder.State.PLACED:
		top.add_child(_count_down(T.cell(bus.arrival_text(o.eta_minute), 112, T.ORANGE), o.eta_minute))
	else:
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


# --- SELL -----------------------------------------------------------------------------------

## The stock the Sell list shows: {part, condition, qty, offers} for every part in stock that
## some company buys, in the category (or "" for all) and matching the search.
func stock_lines(cat: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var detail := bus.get_stock_detail()
	for part: String in detail:
		if cat != "" and _category_of(part) != cat:
			continue
		if query != "" and not ("%s %s" % [bus.part_name(part), _category_of(part)]).to_lower().contains(query):
			continue
		# Only what is on a shelf: parts still on their way in aren't stock yet.
		var shelved := bus.shelved_count(part)
		for c: String in PartCondition.ALL:
			var qty := mini(int(detail[part].get(c, 0)), shelved)
			if qty <= 0:
				continue
			shelved -= qty
			var offers := bus.get_offers(part, c)
			if not offers.is_empty():
				out.append({"part": part, "condition": c, "qty": qty, "offers": offers})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca := _category_of(a.part)
		var cb := _category_of(b.part)
		if ca != cb:
			return ca < cb
		var na := bus.part_name(a.part)
		var nb := bus.part_name(b.part)
		return na < nb if na != nb else PartCondition.ALL.find(a.condition) < PartCondition.ALL.find(b.condition))
	return out


func _refresh_sell() -> void:
	var scroll := _list.get_parent() as ScrollContainer
	var keep := scroll.scroll_vertical
	_clear(_list)
	var lines := stock_lines(category)
	var last := ""
	for i in mini(lines.size(), limit):
		var cat := _category_of(lines[i].part)
		if category == "" and cat != last:
			_list.add_child(_heading(cat, lines.filter(func(d: Dictionary) -> bool: return _category_of(d.part) == cat).size()))
			last = cat
		_list.add_child(_stock_row(lines[i], i % 2 == 1))
	if lines.size() > limit:
		var more := T.button("SHOW MORE  (%d more)" % (lines.size() - limit), false, 16, false, glass)
		more.name = "ShowMore"
		more.pressed.connect(func() -> void:
			limit += MAX_ROWS
			_refresh_sell())
		_list.add_child(_centred(more))
	if lines.is_empty():
		_list.add_child(T.label("Nothing matches." if query != "" else "Nothing on the shelves that anyone buys. Parts show here once they are put away on a shelf.", "body", 18, T.DIM))
	scroll.set_deferred("scroll_vertical", keep)


func _stock_row(line: Dictionary, alt: bool) -> Control:
	var offers: Array = line.offers
	var best: Dictionary = offers[0]
	var others := PackedStringArray()
	for o: Dictionary in offers:
		var s := bus.supplier(o.supplier_id)
		others.append("%s %s" % [s.display_name if s else o.supplier_id, T.money(o.unit_price)])
	var key := "%s_%s" % [line.part, line.condition]
	var one := T.button("SELL 1", true, 14, false, glass)
	one.name = "Sell_" + key.validate_node_name()
	one.custom_minimum_size = Vector2(58, 24)
	one.pressed.connect(sell.bind(best.supplier_id, line.part, line.condition, 1))
	var all := T.button("ALL", false, 14, false, glass)
	all.name = "SellAll_" + key.validate_node_name()
	all.custom_minimum_size = Vector2(44, 24)
	all.pressed.connect(sell.bind(best.supplier_id, line.part, line.condition, int(line.qty)))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	buttons.add_child(one)
	buttons.add_child(all)
	var names := T.cell_text(bus.part_name(line.part), "  ·  ".join(others))
	for l: Label in names.get_children():
		l.clip_text = true
	var picked_key := "%s|%s" % [line.part, line.condition]
	var row := compact(T.row([
		names,
		_width(T.tag(PartCondition.label(line.condition), _condition_colour(line.condition)), 92),
		T.cell(str(line.qty), 52),
		T.cell(T.money(best.unit_price), 96, T.GOOD, "mono_bold"),
		_width(_centred(buttons), 126),
	], alt or picked_key == picked_stock, glass))
	row.name = "Stock_" + key.validate_node_name()
	_click_to(row, pick_stock.bind(picked_key))
	return row


## Shows a stock line's buyers over the sales (again: hides them).
func pick_stock(stock_key: String) -> void:
	picked_stock = "" if picked_stock == stock_key else stock_key
	refresh()


## Every company's offer for the picked stock line, best first, with the company's standing
## there and what selling to it does for that: pick the buyer, not just the best price.
func _buyers_docket() -> Control:
	var bits := picked_stock.split("|")
	var line: Dictionary = {}
	for l in stock_lines(""):
		if l.part == bits[0] and l.condition == bits[1]:
			line = l
	if line.is_empty():
		picked_stock = ""
		return null
	var d := T.docket("Buyers", "BSX/OFFERS", glass)
	d.panel.name = "Buyers"
	var body := d.body as VBoxContainer
	var head := T.label("%s  ·  %s  ·  %d on the shelf" % [bus.part_name(line.part), PartCondition.label(line.condition), line.qty], "body_medium", 16, _ink())
	head.clip_text = true
	body.add_child(head)
	var best := int(line.offers[0].unit_price)
	for o: Dictionary in line.offers:
		body.add_child(_buyer_row(line, o, best))
	var note := T.label("Selling builds your standing with a company: Known, then Regular, then Partner, each taking a little more off what you buy from it.", "body", 13, _ink_dim())
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	return d.panel


func _buyer_row(line: Dictionary, o: Dictionary, best: int) -> Control:
	var s := bus.supplier(o.supplier_id)
	var st := bus.standing_with(o.supplier_id)
	var col := VBoxContainer.new()
	col.name = "Buyer_" + str(o.supplier_id).validate_node_name()
	col.add_theme_constant_override("separation", 0)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	var who := T.label(s.display_name if s else o.supplier_id, "body_medium", 16, _ink())
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.clip_text = true
	top.add_child(who)
	var less := best - int(o.unit_price)
	top.add_child(T.cell(T.money(o.unit_price), 70, T.GOOD if less == 0 else _ink(), "mono_bold"))
	var key := ("%s_%s_%s" % [o.supplier_id, line.part, line.condition]).validate_node_name()
	var one := T.button("SELL 1", true, 13, false, glass)
	one.name = "SellTo_" + key
	one.custom_minimum_size = Vector2(54, 22)
	one.pressed.connect(sell.bind(o.supplier_id, line.part, line.condition, 1))
	top.add_child(one)
	var all := T.button("ALL", false, 13, false, glass)
	all.name = "SellAllTo_" + key
	all.custom_minimum_size = Vector2(40, 22)
	all.pressed.connect(sell.bind(o.supplier_id, line.part, line.condition, int(line.qty)))
	top.add_child(all)
	col.add_child(top)
	var sub := PackedStringArray([str(st.name).to_upper() + (" (%d%% OFF BUYING)" % st.off if int(st.off) > 0 else "")])
	if less > 0:
		sub.append("%s LESS EACH THAN THE BEST" % T.money(less))
	if str(st.next_name) != "":
		sub.append("%s CR MORE SOLD TO BE %s" % [T.money(int(st.next_at) - int(st.sold)), str(st.next_name).to_upper()])
	var small := T.label("  ·  ".join(sub), "display_medium", 12, _ink_dim())
	small.clip_text = true
	col.add_child(small)
	return col


## Sells from stock to a company at today's offer; the result shows on the Sales docket.
func sell(supplier_id: String, part: String, condition: String, qty: int) -> BusinessResult:
	var r := bus.sell_stock(supplier_id, part, condition, qty)
	var s := bus.supplier(supplier_id)
	if r.is_ok():
		_message = "Sold %d %s to %s for %s CR." % [qty, bus.part_name(part), s.display_name if s else supplier_id, T.money(-r.cost)] \
				if r.cost != 0 else "Sale sent to the host."
	else:
		_message = r.message.capitalize() if r.message != "" else "That sale didn't go through."
	_message_good = r.is_ok()
	refresh()
	return r


## The side in Sell: today's sales (from the ledger) and the last message.
func _refresh_sales() -> void:
	_clear(_side)
	if picked_stock != "":
		var buyers := _buyers_docket()
		if buyers:
			_side.add_child(buyers)
	var d := T.docket("Sales today", "BSX/SALES", glass)
	d.panel.name = "Sales"
	d.panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body := d.body as VBoxContainer
	var total := 0
	var list := T.list()
	for e in bus.get_ledger(bus.get_day()):
		if e.category != LedgerEntry.RESALE:
			continue
		total += e.amount
		var s := bus.supplier(e.ref)
		var row := HBoxContainer.new()
		var w := T.label("%s  →  %s" % [e.note, s.display_name if s else e.ref], "body", 14, _ink())
		w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		w.clip_text = true
		row.add_child(w)
		row.add_child(T.cell(T.money(e.amount), 76, _ink()))
		list.add_child(row)
	if total == 0:
		list.add_child(T.label("Nothing sold today. SELL 1 or ALL sells to the best offer; click a line to pick the buyer.", "body", 16, _ink_dim()))
	var sum := HBoxContainer.new()
	var tl := T.label("TAKEN", "display_bold", 24, _ink())
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sum.add_child(tl)
	sum.add_child(T.label("%s CR" % T.money(total), "mono_bold", 24, T.ORANGE))
	body.add_child(sum)
	body.add_child(_sum("CASH", "%s CR" % T.money(bus.get_cash())))
	if _message != "":
		var m := T.label(_message, "body_medium", 15, T.GOOD if _message_good else T.BAD)
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(m)
	body.add_child(list.get_parent())
	_side.add_child(d.panel)


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
	return "IN %d S" % bus.seconds_until(q.eta_minute)


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


## The host turned a crew member's order down.
func _on_order_refused(reason: String) -> void:
	Sfx.play("error")
	_message = reason.left(1).to_upper() + reason.substr(1) + "."
	_message_good = false
	refresh()


func place_order() -> BusinessResult:
	var r := bus.place_market_order(basket_as_lines())
	if r.is_ok():
		basket.clear()
		# A crew member's order goes to the host, which places it (or says why not).
		if r.order_ids.is_empty():
			_message = "Order sent to the host."
		else:
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
	# An estimate keeps any quantity, but only parts still listed (prices change daily).
	for id in estimate.keys():
		if bus.get_listing(id) == null:
			estimate.erase(id)


# --- COST ESTIMATOR -------------------------------------------------------------------------
# A price list to work out what a job's parts would cost: + on any part adds it, at any
# quantity (stock doesn't limit an estimate), costed at today's prices less bulk discounts.

func toggle_estimator() -> void:
	estimating = not estimating
	_message = ""
	refresh()


func add_to_estimate(listing_id: String, delta: int) -> void:
	if bus.get_listing(listing_id) == null:
		return
	var qty := maxi(0, int(estimate.get(listing_id, 0)) + delta)
	if qty == 0:
		estimate.erase(listing_id)
	else:
		estimate[listing_id] = qty
	refresh()


func clear_estimate() -> void:
	estimate.clear()
	refresh()


## What the estimate comes to: {cost, list (before bulk), cheaper (CR saved buying each
## line from the cheapest supplier of that part and condition)}.
func estimate_total() -> Dictionary:
	var best := _cheapest_units()
	var cost := 0
	var list := 0
	var cheaper := 0
	for id: String in estimate:
		var l := bus.get_listing(id)
		var qty := int(estimate[id])
		var c := bus.listing_cost(l, qty)
		cost += c
		list += l.unit_price * qty
		var low := int(best.get("%s|%s" % [l.part, l.condition], l.unit_price))
		cheaper += maxi(0, c - low * qty)
	return {"cost": cost, "list": list, "cheaper": cheaper}


## Part|condition -> the lowest unit price any supplier lists it at today.
func _cheapest_units() -> Dictionary:
	var best := {}
	for l in bus.get_listings():
		var key := "%s|%s" % [l.part, l.condition]
		if not best.has(key) or l.unit_price < int(best[key]):
			best[key] = l.unit_price
	return best


## Puts the estimate's lines on the purchase order, as many of each as are in stock.
func order_estimate() -> void:
	var short := 0
	for id: String in estimate:
		var l := bus.get_listing(id)
		var qty := mini(int(estimate[id]), l.available - int(basket.get(id, 0)))
		short += int(estimate[id]) - maxi(qty, 0)
		if qty > 0:
			basket[id] = int(basket.get(id, 0)) + qty
	estimating = false
	_message = "Estimate copied to the purchase order." + (" %d not in stock today." % short if short > 0 else "")
	_message_good = short == 0
	refresh()


func _refresh_estimate() -> void:
	_clear(_side)
	var est := T.docket("Cost estimate", "BSX/EST", glass)
	est.panel.name = "Estimator"
	est.panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body := est.body as VBoxContainer
	var hint := T.label("Press + on any part to price it. Nothing is ordered.", "body", 15, _ink_dim())
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)
	var list := T.list()
	list.name = "EstimateLines"
	body.add_child(list.get_parent())
	(list.get_parent() as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	var best := _cheapest_units()
	for id: String in estimate:
		list.add_child(_estimate_line(bus.get_listing(id), int(estimate[id]), best))
	if estimate.is_empty():
		list.add_child(T.label("No parts yet.", "body", 16, _ink_dim()))
	var t := estimate_total()
	var count := 0
	for id: String in estimate:
		count += int(estimate[id])
	body.add_child(_sum("PARTS", str(count)))
	if t.list > t.cost:
		body.add_child(_sum("BULK SAVING", "%s CR" % T.money(t.list - t.cost)))
	if t.cheaper > 0:
		body.add_child(_sum("CHEAPER ELSEWHERE BY", "%s CR" % T.money(t.cheaper)))
	body.add_child(_sum("CASH NOW", "%s CR" % T.money(bus.get_cash())))
	var total := HBoxContainer.new()
	var tl := T.label("ESTIMATE", "display_bold", 24, _ink())
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.add_child(tl)
	var tv := T.label("%s CR" % T.money(t.cost), "mono_bold", 24, T.ORANGE)
	tv.name = "EstimateTotal"
	total.add_child(tv)
	body.add_child(total)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	var clear := T.button("CLEAR", false, 18, false, glass)
	clear.disabled = estimate.is_empty()
	clear.pressed.connect(clear_estimate)
	buttons.add_child(clear)
	var close := T.button("CLOSE", false, 18, false, glass)
	close.name = "CloseEstimate"
	close.pressed.connect(toggle_estimator)
	buttons.add_child(close)
	var order := T.button("ORDER THESE", true, 20, false, glass)
	order.name = "OrderEstimate"
	order.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order.disabled = estimate.is_empty()
	order.pressed.connect(order_estimate)
	buttons.add_child(order)
	body.add_child(buttons)
	_side.add_child(est.panel)


func _estimate_line(l: MarketListing, qty: int, best: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var s := bus.supplier(l.supplier_id)
	var cost := bus.listing_cost(l, qty)
	var sub := "%s  ·  %s  ·  %s EACH" % [s.display_name if s else l.supplier_id, PartCondition.label(l.condition), T.money(l.unit_price)]
	if cost < l.unit_price * qty:
		sub += "  ·  BULK %d%% OFF" % roundi(100.0 - 100.0 * cost / (l.unit_price * qty))
	var low := int(best.get("%s|%s" % [l.part, l.condition], l.unit_price))
	if low < l.unit_price:
		sub += "  ·  %s EACH ELSEWHERE" % T.money(low)
	var names := T.cell_text(bus.part_name(l.part), sub)
	for i in names.get_child_count():
		var nl := names.get_child(i) as Label
		nl.add_theme_color_override("font_color", _ink() if i == 0 else _ink_dim())
		nl.clip_text = true
	h.add_child(names)
	for step: int in [-1, 1]:
		var b := T.button("−" if step < 0 else "+", false, 15, false, glass)
		b.custom_minimum_size = Vector2(26, 24)
		b.pressed.connect(add_to_estimate.bind(l.id, step))
		h.add_child(b)
		if step < 0:
			var ql := T.label(str(qty), "mono_bold", 17, _ink())
			ql.custom_minimum_size.x = 34
			ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			h.add_child(ql)
	var ten := T.button("+10", false, 13, false, glass)
	ten.custom_minimum_size = Vector2(34, 24)
	ten.pressed.connect(add_to_estimate.bind(l.id, 10))
	h.add_child(ten)
	h.add_child(T.cell(T.money(cost), 84, _ink()))
	return h


# --- ACCOUNTS -------------------------------------------------------------------------------

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


## Labels counting down to an order's arrival: each carries meta "eta" (its order's
## eta_minute) and "prefix"; the clock ticks them without rebuilding the page.
var _countdowns: Array[Label] = []


func _count_down(l: Label, eta_minute: int, prefix := "") -> Label:
	l.set_meta("eta", eta_minute)
	l.set_meta("prefix", prefix)
	_countdowns.append(l)
	return l


func _tick_countdowns() -> void:
	# Untyped: a freed label can't be passed as a Label, and filter() returns a plain Array.
	_countdowns.assign(_countdowns.filter(func(l: Variant) -> bool: return is_instance_valid(l)))
	for l in _countdowns:
		l.text = str(l.get_meta("prefix")) + bus.arrival_text(int(l.get_meta("eta")))
