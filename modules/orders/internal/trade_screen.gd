extends PanelContainer
## PARTS TRADING (master plan 7.6, a sideline): on any wall of the design room and on the wrist.
## Trading is in refurbished lots only (new parts are for builds: buying new to sell never pays).
## A "how this works" box, then a table, one row a part: PART, YOU HOLD (and how many are coming),
## REFURB LOT TODAY (each, refurb included; a few parts a day), SELL PRICE TODAY (the best supplier),
## LAST 14 DAYS (the range of sell prices and whether today is HIGH, LOW or MIDDLING), then BUY LOT,
## SELL 1 and SELL ALL. Trading's money shows as its own line in the accounts (beenster, 20 Nov).

const T := preload("res://modules/ui/api/terminal_kit.gd")

const BG := Color(0.02, 0.05, 0.09)
const CARD := Color(0.05, 0.1, 0.16)
const LOT := TradeBook.LOT_SIZE

var bus: Object
var fs := 15
var show_all := false
var _body: VBoxContainer
var _status: Label
var _queued := false


func setup(orders_bus: Object, density: float) -> void:
	bus = orders_bus
	fs = maxi(12, int(density * 0.1))
	name = "TradeScreen"
	add_theme_stylebox_override("panel", T.box(BG, Color.TRANSPARENT, 0, fs * 0.5))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(fs * 0.4))
	add_child(col)
	_status = _label("", "mono_medium", fs - 2, T.DIM)
	_status.clip_text = true
	col.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", int(fs * 0.3))
	scroll.add_child(_body)
	bus.connect("changed", _queue)
	refresh()


func _queue() -> void:
	if _queued:
		return
	_queued = true
	_later.call_deferred()


func _later() -> void:
	_queued = false
	if is_inside_tree():
		refresh()


func refresh() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var t: Dictionary = bus.call("trade_totals")
	_status.text = "PARTS TRADING  ·  DAY %d  ·  SPENT ON STOCK CR %s  ·  PAID BY BUYERS CR %s  ·  NET SO FAR CR %s (unsold stock counts as spent)" % [
			int(bus.call("market_day")), T.money(int(t.spent)), T.money(int(t.earned)), T.money(int(t.net))]
	if not Flags.is_on(OrdersBus.SELL_FLAG):
		_body.add_child(_label("Parts trading is off.", "body_medium", fs, T.DIM))
		return
	# How it works, in three steps.
	var how := PanelContainer.new()
	how.add_theme_stylebox_override("panel", T.box(CARD, Color.TRANSPARENT, 0, fs * 0.3))
	var hv := VBoxContainer.new()
	how.add_child(hv)
	hv.add_child(_label("HOW THIS WORKS", "display_bold", fs, T.ORANGE))
	for line: String in [
			"1. Each day a few second-hand lots of %d parts come up. BUY LOT buys one; the refurb works fix them up." % LOT,
			"2. When they are done they show under YOU HOLD.",
			"3. Sell to the supplier paying most. Your profit is the sell price less what the lot cost each. Sell on a HIGH day for more, or hold on a LOW one."]:
		var l := _label(line, "body_medium", fs - 2, T.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hv.add_child(l)
	var all := T.button("SHOW EVERY PART" if not show_all else "SHOW ONLY TODAY'S LOTS AND WHAT I HOLD", show_all, fs - 3)
	all.pressed.connect(func() -> void:
		show_all = not show_all
		refresh())
	all.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hv.add_child(all)
	_body.add_child(how)
	_body.add_child(_columns(true, {}, 0, 0, false))
	var holdings: Dictionary = bus.get("holdings")
	var coming := _coming()
	var lots: Array = bus.call("trade_lines")
	var on_offer: Array = bus.call("trade_lots")
	var rows: Array = []
	for l: Dictionary in lots:
		var key := str(l.key)
		var have := int(holdings.get(key, 0))
		var lot := on_offer.has(key)
		if not show_all and not lot and have <= 0 and int(coming.get(key, 0)) <= 0:
			continue
		rows.append([0 if lot else (1 if have > 0 else 2), l, have, lot])
	rows.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) < int(y[0]))
	for r: Array in rows:
		_body.add_child(_columns(false, r[1], int(r[2]), int(coming.get(str(r[1].key), 0)), bool(r[3])))
	if rows.is_empty():
		_body.add_child(_label("No lots left today and nothing held. New lots come up tomorrow.", "body_medium", fs - 2, T.DIM))
	var sales: Array = bus.get("sales")
	if not sales.is_empty():
		_body.add_child(_label("RECENT SALES", "display_bold", fs + 2, T.ORANGE))
		for i in range(sales.size() - 1, maxi(-1, sales.size() - 9), -1):
			var e: Dictionary = sales[i]
			_body.add_child(_label("Sold %d %s to %s at CR %s each: CR %s" % [int(e.qty), str(e.name), str(e.vendor_name),
					T.money(int(e.each)), T.money(int(e.total))], "mono_medium", fs - 3, T.TEXT))


## Trade line key -> how many are on their way (bought, not in yet, or in the refurb works).
func _coming() -> Dictionary:
	var out := {}
	for o: Dictionary in bus.get("orders"):
		if str(o.cid) != OrdersBus.STOCK:
			continue
		for l: Dictionary in o.lines:
			var n := int(l.get("refurbing", 0)) if bool(o.arrived) else roundi(float(l.qty))
			if n > 0:
				out[str(l.key)] = int(out.get(str(l.key), 0)) + n
	return out


## Column widths (in font sizes): part, you hold, refurb lot today, sell price today, last 14 days.
const COLS := [10.0, 5.5, 10.0, 12.0, 13.0]
const HEADS := ["PART", "YOU HOLD", "REFURB LOT TODAY", "SELL PRICE TODAY", "LAST 14 DAYS"]


## One row of the table: the headings when `head`, else part `l` (`lot`: a lot of it is on offer).
func _columns(head: bool, l: Dictionary, have: int, coming: int, lot: bool) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", T.box(CARD if not head else Color.TRANSPARENT, Color.TRANSPARENT, 0, fs * 0.3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(fs * 0.6))
	card.add_child(row)
	if head:
		for i in HEADS.size():
			_cell(row, _label(HEADS[i], "mono_bold", fs - 4, T.DIM), i)
		var bs := _label("BUY  ·  SELL", "mono_bold", fs - 4, T.DIM)
		bs.custom_minimum_size.x = fs * 4.6 * 3.0 + int(fs * 0.6) * 2
		bs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(bs)
		return card
	var key := str(l.key)
	var used: Dictionary = bus.call("trade_used_quote", key, LOT) if lot else {}
	var offers: Array = bus.call("trade_offers", key, 1)
	var best := float(offers[0].each) if not offers.is_empty() else 0.0
	var trend: PackedFloat32Array = bus.call("trade_trend", key, 14)
	var lo := best
	var hi := best
	for v in trend:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var where := "MIDDLING"
	if hi > lo and best >= lo + (hi - lo) * 0.75:
		where = "HIGH: good day to sell"
	elif hi > lo and best <= lo + (hi - lo) * 0.25:
		where = "LOW: hold if you can"
	var name_l := _label(str(l.name), "body_medium", fs - 1, T.TEXT)
	_cell(row, name_l, 0)
	_cell(row, _label(("%d" % have) + (("\n+%d coming" % coming) if coming > 0 else ""), "mono_medium", fs - 2, T.TEXT if have > 0 else T.DIM), 1)
	if used.is_empty():
		_cell(row, _label("none today", "mono_medium", fs - 2, T.DIM), 2)
	else:
		var gain := int(best) - int(used.unit)
		var lc := VBoxContainer.new()
		lc.add_theme_constant_override("separation", 0)
		lc.add_child(_label("CR %s each" % T.money(int(used.unit)), "mono_medium", fs - 2, T.TEXT))
		lc.add_child(_label(("%s%s each sold today" % ["+" if gain >= 0 else "-", T.money(absi(gain))]), "mono_bold", fs - 4,
				T.GOOD if gain > 0 else T.AMBER))
		_cell(row, lc, 2)
	_cell(row, _label(("CR %s each\n%s" % [T.money(int(best)), str(offers[0].name)]) if not offers.is_empty() else "nobody buys it", "mono_medium", fs - 2, T.GOOD), 3)
	var days := VBoxContainer.new()
	var spark := Control.new()
	spark.custom_minimum_size = Vector2(fs * float(COLS[4]), fs * 1.2)
	spark.draw.connect(_draw_trend.bind(spark, trend))
	spark.tooltip_text = "What suppliers paid for one over the last 14 days; the orange dot is today."
	days.add_child(spark)
	days.add_theme_constant_override("separation", 0)
	var rl := _label("CR %s to %s" % [T.money(int(lo)), T.money(int(hi))], "mono_medium", fs - 4, T.DIM)
	days.add_child(rl)
	var wl := _label("today " + where, "mono_bold", fs - 4,
			T.GOOD if where.begins_with("HIGH") else (T.AMBER if where.begins_with("LOW") else T.DIM))
	days.add_child(wl)
	_cell(row, days, 4)
	var b := T.button("BUY LOT", false, fs - 3)
	b.disabled = used.is_empty()
	if not used.is_empty():
		b.tooltip_text = "Buy this lot of %d for CR %s (refurb included); they are ready to sell in about %d days." % [LOT, T.money(int(used.total)), int(used.lead)]
	b.pressed.connect(func() -> void: bus.call("trade_buy", key, LOT, true))
	_button(row, b)
	var s1 := T.button("SELL 1", true, fs - 3)
	s1.disabled = have < 1
	s1.pressed.connect(func() -> void: bus.call("trade_sell", key, 1, ""))
	_button(row, s1)
	var sa := T.button("SELL ALL", true, fs - 3)
	sa.disabled = have < 1
	sa.tooltip_text = "Sell every one you hold to the supplier paying most (selling many at once fetches a little less each)."
	sa.pressed.connect(func() -> void: bus.call("trade_sell", key, have, ""))
	_button(row, sa)
	return card


func _button(row: HBoxContainer, b: Button) -> void:
	b.custom_minimum_size.x = fs * 4.6
	b.clip_text = true
	row.add_child(b)


func _cell(row: HBoxContainer, c: Control, i: int) -> void:
	c.custom_minimum_size.x = fs * float(COLS[i])
	if c is Label:
		(c as Label).clip_text = true
		(c as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if i == 0:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(c)


func _draw_trend(c: Control, trend: PackedFloat32Array) -> void:
	var sz := c.size
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.06, 0.1))
	if trend.size() < 2:
		return
	var lo := trend[0]
	var hi := trend[0]
	for v in trend:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var span := maxf(hi - lo, 1.0)
	var pts := PackedVector2Array()
	for i in trend.size():
		pts.append(Vector2(float(i) / float(trend.size() - 1) * (sz.x - 4.0) + 2.0, sz.y - 3.0 - (trend[i] - lo) / span * (sz.y - 6.0)))
	c.draw_polyline(pts, T.CYAN, 2.0, true)
	c.draw_circle(pts[pts.size() - 1], 3.0, T.ORANGE)


func _label(text: String, face: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", T.font(face))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l
