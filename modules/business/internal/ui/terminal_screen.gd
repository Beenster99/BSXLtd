extends Control
## The yard terminal: three channels on one screen. ORDERS is today's parts market and a
## purchase order (pick listings, set quantities, see the bill, place it); GOODS IN shows
## what is on its way and what is in store; ACCOUNTS shows cash, reputation and the ledger.
## The same screen runs on the wall monitors (display only, cycling channels) and full
## size when a player uses one (interactive).

signal close_requested

const Look := preload("res://modules/business/internal/ui/terminal_look.gd")
const CHANNELS: PackedStringArray = ["orders", "goods", "accounts"]
const CHANNEL_NAMES := {"orders": "01  ORDERS", "goods": "02  GOODS IN", "accounts": "03  ACCOUNTS"}
## How long a wall monitor shows each channel.
const CYCLE_SECONDS := 7.0
const MAX_ROWS := 60

var bus: BusinessBus
var interactive := false
var channel := "orders"
var category := ""
## How many market lines the list shows; SHOW MORE adds another MAX_ROWS.
var limit := MAX_ROWS
## listing id -> quantity in the purchase order.
var basket: Dictionary = {}

var _clock: Label
var _cash: Label
var _tabs: HBoxContainer
var _body: MarginContainer
var _message := ""
var _message_good := true
var _dirty := true
var _cycle := 0.0
var _scroll_keep := 0.0


func setup(p_bus: BusinessBus, p_interactive: bool) -> void:
	bus = p_bus
	interactive = p_interactive
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	_build()
	# Signal -> how many arguments it carries.
	var watch := {"market_changed": 0, "cash_changed": 3, "order_placed": 1, "delivery_arrived": 2,
			"order_delayed": 1, "reputation_changed": 3, "day_closed": 1}
	for sig: String in watch:
		bus.connect(sig, _mark_dirty.unbind(watch[sig]) if watch[sig] > 0 else _mark_dirty)
	bus.order_refused.connect(_on_order_refused)
	bus.clock_changed.connect(func(_m: int) -> void: _refresh_header())


func _mark_dirty() -> void:
	_dirty = true


func _process(delta: float) -> void:
	if bus == null:
		return
	if not interactive:
		_cycle += delta
		if _cycle >= CYCLE_SECONDS:
			_cycle = 0.0
			channel = CHANNELS[(CHANNELS.find(channel) + 1) % CHANNELS.size()]
			_dirty = true
	if _dirty:
		_dirty = false
		refresh()


func show_channel(id: String) -> void:
	channel = id
	_cycle = 0.0
	refresh()


func refresh() -> void:
	_refresh_header()
	_refresh_tabs()
	_prune_basket()
	var scroll := _body.find_child("Scroll", true, false) as ScrollContainer
	_scroll_keep = scroll.scroll_vertical if scroll else 0.0
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match channel:
		"orders":
			_body.add_child(_orders())
		"goods":
			_body.add_child(_goods())
		_:
			_body.add_child(_accounts())
	scroll = _body.find_child("Scroll", true, false) as ScrollContainer
	if scroll:
		scroll.set_deferred("scroll_vertical", int(_scroll_keep))


# --- Frame ---------------------------------------------------------------------------------

func _build() -> void:
	for c in get_children():
		c.free()
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", Look.box(Look.KIOSK, Look.EDGE, 4))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 64
	header.add_theme_constant_override("separation", 0)
	col.add_child(header)
	var badge := PanelContainer.new()
	var badge_st := Look.box(Look.ORANGE, Color.TRANSPARENT, 0, 0)
	badge_st.content_margin_left = 18
	badge_st.content_margin_right = 18
	badge.add_theme_stylebox_override("panel", badge_st)
	var bsx := Look.label("BSX", "display_bold", 40, Look.BLACK)
	bsx.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(bsx)
	header.add_child(badge)
	var title := VBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", -4)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_child(title)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(pad)
	title.add_child(Look.label("YARD TERMINAL", "display_bold", 30, Look.TEXT))
	title.add_child(Look.label("GOODS  ·  SUPPLY  ·  ACCOUNTS", "display_medium", 16, Look.DIM))
	var readouts := VBoxContainer.new()
	readouts.alignment = BoxContainer.ALIGNMENT_CENTER
	readouts.add_theme_constant_override("separation", -2)
	var rpad := MarginContainer.new()
	rpad.add_theme_constant_override("margin_right", 18)
	rpad.add_child(readouts)
	header.add_child(rpad)
	_clock = Look.label("", "mono_medium", 18, Look.DIM)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cash = Look.label("", "mono_bold", 26, Look.ORANGE)
	_cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readouts.add_child(_clock)
	readouts.add_child(_cash)
	col.add_child(Look.HazardRule.new(10.0))

	var tab_pad := MarginContainer.new()
	for side in ["left", "right", "top"]:
		tab_pad.add_theme_constant_override("margin_" + side, 14)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	tab_pad.add_child(_tabs)
	col.add_child(tab_pad)

	_body = MarginContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		_body.add_theme_constant_override("margin_" + side, 14)
	col.add_child(_body)

	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel", Look.box(Look.EDGE, Color.TRANSPARENT, 0, 6))
	var hint := Look.label("%s CLOSE    ·    + / − SET QUANTITIES    ·    TRADE PRICES MOVE DAILY    ·    GOODS ARRIVE AT DELIVERIES" % Keys.prompt(Keys.CANCEL)
			if interactive else "WALK UP AND PRESS %s TO ORDER PARTS" % Keys.prompt(Keys.INTERACT), "display_medium", 16, Look.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(hint)
	col.add_child(footer)
	refresh()


func _refresh_header() -> void:
	if bus == null or _clock == null:
		return
	_clock.text = bus.get_clock_text()
	_cash.text = "CR %s" % Look.money(bus.get_cash())
	_cash.add_theme_color_override("font_color", Look.BAD if bus.get_cash() < 0 else Look.ORANGE)


func _refresh_tabs() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	for id in CHANNELS:
		var b := Look.button(CHANNEL_NAMES[id], false, 20, id == channel)
		b.custom_minimum_size.x = 170
		b.pressed.connect(show_channel.bind(id))
		b.disabled = not interactive and id != channel
		_tabs.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.add_child(spacer)
	if interactive:
		var close := Look.button("CLOSE  ✕", false, 18)
		close.pressed.connect(func() -> void: close_requested.emit())
		_tabs.add_child(close)


# --- ORDERS --------------------------------------------------------------------------------

func _orders() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var market := VBoxContainer.new()
	market.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market.size_flags_stretch_ratio = 1.7
	market.add_theme_constant_override("separation", 8)
	row.add_child(market)

	var cats := HFlowContainer.new()
	cats.add_theme_constant_override("h_separation", 4)
	cats.add_theme_constant_override("v_separation", 4)
	var names := PackedStringArray([""])
	names.append_array(_market_categories())
	for c in names:
		var b := Look.button(c.to_upper() if c != "" else "ALL", false, 15, c == category)
		b.pressed.connect(func() -> void:
			category = c
			limit = MAX_ROWS
			refresh())
		b.disabled = not interactive and c != category
		cats.add_child(b)
	market.add_child(cats)

	var head := HBoxContainer.new()
	for spec: Array in [["PART  /  SUPPLIER", true, 0], ["COND.", false, 92], ["DUE", false, 58], ["LEFT", false, 52], ["UNIT CR", false, 96], ["", false, 46]]:
		var l := Look.label(spec[0], "display_medium", 14, Look.DIM)
		if spec[1]:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.custom_minimum_size.x = spec[2]
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(l)
	var head_pad := MarginContainer.new()
	head_pad.add_theme_constant_override("margin_left", 10)
	head_pad.add_theme_constant_override("margin_right", 22)
	head_pad.add_child(head)
	market.add_child(head_pad)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	market.add_child(scroll)
	var shown := 0
	var hidden := 0
	for l in bus.get_listings(category):
		if l.available <= 0:
			continue
		if shown >= limit:
			hidden += 1
			continue
		list.add_child(_listing_row(l, shown % 2 == 1))
		shown += 1
	if hidden > 0:
		# Every Void Salvage part is on sale, so a long list shows a page at a time.
		var more := Look.button("SHOW MORE  (%d more)" % hidden, false, 16)
		more.name = "ShowMore"
		more.disabled = not interactive
		more.pressed.connect(func() -> void:
			limit += MAX_ROWS
			refresh())
		var box := CenterContainer.new()
		box.add_child(more)
		list.add_child(box)
	if shown == 0:
		list.add_child(Look.label("Nothing on the market here today.", "body", 18, Look.DIM))

	row.add_child(_docket())
	return row


func _market_categories() -> PackedStringArray:
	var seen := {}
	for l in bus.get_listings():
		seen[bus.listing_category(l)] = true
	var out := PackedStringArray(seen.keys())
	out.sort()
	return out


func _listing_row(l: MarketListing, alt: bool) -> Control:
	var panel := PanelContainer.new()
	var st := Look.box(Look.PLATE_HI if alt else Look.PLATE, Color.TRANSPARENT, 0, 0)
	st.content_margin_left = 10
	st.content_margin_right = 8
	st.content_margin_top = 5
	st.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	panel.add_child(h)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -3)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var part := Look.label(bus.part_name(l.part), "body_medium", 19, Look.TEXT)
	part.clip_text = true
	names.add_child(part)
	var s := bus.supplier(l.supplier_id)
	names.add_child(Look.label("%s  ·  %s" % [s.display_name.to_upper() if s else l.supplier_id, bus.listing_category(l).to_upper()], "display_medium", 13, Look.DIM))
	h.add_child(names)
	var tag_box := CenterContainer.new()
	tag_box.custom_minimum_size.x = 92
	tag_box.add_child(Look.condition_tag(l.condition))
	h.add_child(tag_box)
	h.add_child(_cell("%dH" % l.lead_hours, 58, Look.DIM))
	h.add_child(_cell(str(l.available) if l.available < 999 else "∞", 52, Look.DIM))
	h.add_child(_cell(Look.money(l.unit_price), 96, Look.TEXT, "mono_bold"))
	var add_box := CenterContainer.new()
	add_box.custom_minimum_size.x = 46
	var add := Look.button("+", true, 18)
	add.custom_minimum_size = Vector2(34, 30)
	add.disabled = not interactive or int(basket.get(l.id, 0)) >= l.available
	add.pressed.connect(add_to_basket.bind(l.id, 1))
	add_box.add_child(add)
	h.add_child(add_box)
	return panel


func _cell(text: String, width: float, color: Color, face := "mono_medium") -> Label:
	var l := Look.label(text, face, 17, color)
	l.custom_minimum_size.x = width
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _docket() -> Control:
	var paper := PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := Look.box(Look.DOCKET, Look.EDGE, 2, 14)
	st.border_width_top = 8
	st.border_color = Look.STEEL.darkened(0.3)
	paper.add_theme_stylebox_override("panel", st)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	paper.add_child(col)
	var top := HBoxContainer.new()
	var t := Look.label("PURCHASE ORDER", "display_bold", 26, Look.INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(Look.label("BSX/PO", "mono_medium", 14, Look.INK_DIM))
	col.add_child(top)
	var rule := ColorRect.new()
	rule.color = Look.INK
	rule.custom_minimum_size.y = 2
	col.add_child(rule)

	var lines := VBoxContainer.new()
	lines.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 4)
	col.add_child(lines)
	var basket_lines := basket_as_lines()
	if basket_lines.is_empty():
		lines.add_child(Look.label("Empty. Press + on a listing to add it.", "body", 17, Look.INK_DIM))
	for line: Dictionary in basket_lines:
		lines.add_child(_docket_line(bus.get_listing(line.listing_id), int(line.qty)))

	var q := bus.quote_market(basket_lines) if not basket_lines.is_empty() else null
	var count := 0
	for line: Dictionary in basket_lines:
		count += int(line.qty)
	var rule2 := ColorRect.new()
	rule2.color = Look.INK
	rule2.custom_minimum_size.y = 1
	col.add_child(rule2)
	col.add_child(_docket_sum("ITEMS", str(count)))
	col.add_child(_docket_sum("DUE AT DELIVERIES", _due_text(q)))
	col.add_child(_docket_sum("CASH AFTER", Look.money(bus.get_cash() - (q.cost if q and q.ok else 0)) + " CR"))
	var total := HBoxContainer.new()
	var tl := Look.label("TOTAL", "display_bold", 28, Look.INK)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.add_child(tl)
	total.add_child(Look.label("%s CR" % Look.money(q.cost if q and q.ok else 0), "mono_bold", 30, Look.INK))
	col.add_child(total)
	if _message != "":
		var m := Look.label(_message, "body_medium", 16, Color("2f7a2b") if _message_good else Color("b3261e"))
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(m)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	var clear := Look.button("CLEAR", false, 20)
	clear.disabled = not interactive or basket.is_empty()
	clear.pressed.connect(clear_basket)
	var place := Look.button("PLACE ORDER", true, 22)
	place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place.disabled = not interactive or q == null or not q.ok or q.cost > bus.get_cash()
	place.pressed.connect(place_order)
	buttons.add_child(clear)
	buttons.add_child(place)
	col.add_child(buttons)
	return paper


func _docket_line(l: MarketListing, qty: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := Look.label(bus.part_name(l.part), "body_medium", 17, Look.INK)
	n.clip_text = true
	names.add_child(n)
	names.add_child(Look.label("%s  @ %s" % [PartCondition.label(l.condition), Look.money(l.unit_price)], "mono", 13, Look.INK_DIM))
	h.add_child(names)
	var minus := Look.button("−", false, 16)
	minus.custom_minimum_size = Vector2(28, 26)
	minus.disabled = not interactive
	minus.pressed.connect(add_to_basket.bind(l.id, -1))
	h.add_child(minus)
	var q := Look.label(str(qty), "mono_bold", 18, Look.INK)
	q.custom_minimum_size.x = 30
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(q)
	var plus := Look.button("+", false, 16)
	plus.custom_minimum_size = Vector2(28, 26)
	plus.disabled = not interactive or qty >= l.available
	plus.pressed.connect(add_to_basket.bind(l.id, 1))
	h.add_child(plus)
	var sum := Look.label(Look.money(l.unit_price * qty), "mono_medium", 17, Look.INK)
	sum.custom_minimum_size.x = 92
	sum.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(sum)
	return h


func _docket_sum(what: String, value: String) -> Control:
	var h := HBoxContainer.new()
	var l := Look.label(what, "display_medium", 16, Look.INK_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(Look.label(value, "mono_medium", 16, Look.INK))
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
			_message = "Order placed: %s for %s CR. Watch GOODS IN." % [", ".join(r.order_ids), Look.money(r.cost)]
		_message_good = true
		Sfx.play("chime")
	else:
		Sfx.play("error")
		_message = r.message.left(1).to_upper() + r.message.substr(1) + "."
		_message_good = false
	refresh()
	return r


func _prune_basket() -> void:
	for id in basket.keys():
		var l := bus.get_listing(id)
		if l == null or l.available <= 0:
			basket.erase(id)
		elif basket[id] > l.available:
			basket[id] = l.available


# --- GOODS IN ------------------------------------------------------------------------------

func _goods() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var on_order := _column("ON ORDER")
	var open := bus.get_orders(PartsOrder.State.PLACED)
	if open.is_empty():
		on_order.list.add_child(Look.label("Nothing on order.", "body", 18, Look.DIM))
	for o in open:
		var s := bus.supplier(o.supplier_id)
		var names := PackedStringArray()
		for line in o.lines:
			names.append("%d× %s" % [line.qty, bus.part_name(line.part)])
		var m := o.eta_minute % 1440
		on_order.list.add_child(_goods_row(o.id, "%s  ·  %s" % [s.display_name.to_upper() if s else o.supplier_id, ", ".join(names)],
				("DELAYED  " if o.delayed else "") + "DAY %d %02d:%02d" % [o.eta_day + 1, m / 60, m % 60], Look.BAD if o.delayed else Look.ORANGE))
	row.add_child(on_order.root)

	var in_store := _column("IN STORE")
	var stock := bus.get_stock_detail()
	var parts := stock.keys()
	parts.sort()
	if parts.is_empty():
		in_store.list.add_child(Look.label("The store is empty.", "body", 18, Look.DIM))
	for part in parts:
		for c: String in PartCondition.ALL:
			if stock[part].has(c):
				var h := HBoxContainer.new()
				var n := Look.label(bus.part_name(part), "body_medium", 18, Look.TEXT)
				n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(n)
				h.add_child(Look.condition_tag(c, 13))
				h.add_child(_cell("×%d" % int(stock[part][c]), 70, Look.TEXT, "mono_bold"))
				in_store.list.add_child(h)
	row.add_child(in_store.root)
	return row


func _goods_row(id: String, what: String, when: String, when_colour: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.plate(8))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	panel.add_child(col)
	var top := HBoxContainer.new()
	var idl := Look.label(id, "mono_bold", 17, Look.TEXT)
	idl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(idl)
	top.add_child(Look.label(when, "mono_medium", 16, when_colour))
	col.add_child(top)
	var w := Look.label(what, "body", 16, Look.DIM)
	w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(w)
	return panel


func _column(title: String) -> Dictionary:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	root.add_child(Look.label(title, "display_bold", 22, Look.ORANGE))
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	root.add_child(scroll)
	return {"root": root, "list": list}


# --- ACCOUNTS ------------------------------------------------------------------------------

func _accounts() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	left.add_child(_figure("CASH", "%s CR" % Look.money(bus.get_cash()), Look.BAD if bus.get_cash() < 0 else Look.ORANGE))
	left.add_child(_figure("REPUTATION", "%d / 100" % roundi(bus.get_reputation()), Look.TEXT))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.value = bus.get_reputation()
	bar.custom_minimum_size.y = 14
	bar.add_theme_stylebox_override("background", Look.box(Look.EDGE))
	bar.add_theme_stylebox_override("fill", Look.box(Look.ORANGE))
	left.add_child(bar)
	left.add_child(_figure("BAY RENT", "%s CR / DAY" % Look.money(bus.get_rules().bay_rent_per_day), Look.TEXT))
	if bus.is_insolvent():
		left.add_child(Look.label("INSOLVENT: ordering is stopped.", "display_bold", 22, Look.BAD))

	var ledger := _column("LEDGER")
	ledger.root.size_flags_stretch_ratio = 1.6
	var entries := bus.get_ledger()
	if entries.is_empty():
		ledger.list.add_child(Look.label("No entries yet.", "body", 18, Look.DIM))
	for i in range(entries.size() - 1, maxi(-1, entries.size() - 1 - MAX_ROWS), -1):
		var e := entries[i]
		var h := HBoxContainer.new()
		h.add_child(_cell("D%d" % (e.day + 1), 52, Look.DIM, "mono"))
		var what := Look.label("  %s  %s" % [e.category.to_upper(), e.ref if e.note == "" else "%s · %s" % [e.ref, e.note]], "body", 16, Look.TEXT)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.clip_text = true
		h.add_child(what)
		h.add_child(_cell(("+" if e.amount > 0 else "") + Look.money(e.amount), 110, Look.GOOD if e.amount > 0 else Look.BAD, "mono_bold"))
		ledger.list.add_child(h)
	row.add_child(ledger.root)
	return row


func _figure(what: String, value: String, colour: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.plate(12))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	panel.add_child(col)
	col.add_child(Look.label(what, "display_medium", 16, Look.DIM))
	col.add_child(Look.label(value, "mono_bold", 30, colour))
	return panel
