extends PanelContainer
## PARTS TRADING (master plan 7.6, a sideline): on any wall of the design room and on the wrist.
## Every part the yard deals in, one row each: what the cheapest vendor sells it for today, what
## the best buyer pays for it (always less), the buy-back's trend over two weeks (time a sale:
## sell when it is high), how many the yard holds and how many are on their way. BUY 5 new or a
## second-hand LOT of 5 (cheaper, through the refurb works first), SELL 1 or SELL ALL to the best
## buyer. Trading's money shows as its own line in the accounts.

const T := preload("res://modules/ui/api/terminal_kit.gd")

const BG := Color(0.02, 0.05, 0.09)
const CARD := Color(0.05, 0.1, 0.16)
const LOT := 5

var bus: Object
var fs := 15
var only_held := false
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
	_status.text = "PARTS TRADING  ·  DAY %d  ·  BOUGHT CR %s  ·  SOLD CR %s  ·  NET CR %s" % [int(bus.call("market_day")),
			T.money(int(t.spent)), T.money(int(t.earned)), T.money(int(t.net))]
	if not Flags.is_on(OrdersBus.SELL_FLAG):
		_body.add_child(_label("Parts trading is off.", "body_medium", fs, T.DIM))
		return
	var head := HBoxContainer.new()
	var intro := _label("Vendors buy parts back, always for less than they sell them that day. Buy when the market is low and sell when it is high, or buy second-hand lots cheap, refurbish them and sell them on.",
			"body_medium", fs - 2, T.DIM)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(intro)
	var held := T.button("HELD ONLY" if not only_held else "ALL PARTS", only_held, fs - 3)
	held.pressed.connect(func() -> void:
		only_held = not only_held
		refresh())
	head.add_child(held)
	_body.add_child(head)
	var holdings: Dictionary = bus.get("holdings")
	var coming := _coming()
	for l: Dictionary in bus.call("trade_lines"):
		var key := str(l.key)
		var have := int(holdings.get(key, 0))
		if only_held and have <= 0 and int(coming.get(key, 0)) <= 0:
			continue
		_row(l, have, int(coming.get(key, 0)))
	var sales: Array = bus.get("sales")
	if not sales.is_empty():
		_body.add_child(_label("SALES", "display_bold", fs + 2, T.ORANGE))
		for i in range(sales.size() - 1, maxi(-1, sales.size() - 9), -1):
			var e: Dictionary = sales[i]
			_body.add_child(_label("%d x %s to %s at CR %s each: CR %s" % [int(e.qty), str(e.name), str(e.vendor_name),
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


func _row(l: Dictionary, have: int, coming: int) -> void:
	var key := str(l.key)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", T.box(CARD, Color.TRANSPARENT, 0, fs * 0.3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(fs * 0.6))
	card.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var name_l := _label(str(l.name), "body_medium", fs, T.TEXT)
	name_l.clip_text = true
	left.add_child(name_l)
	var buy: Dictionary = bus.call("trade_buy_quote", key, LOT)
	var used: Dictionary = bus.call("trade_used_quote", key, LOT)
	var offers: Array = bus.call("trade_offers", key, 1)
	var best := float(offers[0].each) if not offers.is_empty() else 0.0
	var trend: PackedFloat32Array = bus.call("trade_trend", key, 14)
	var lo := 0.0
	var hi := 0.0
	if not trend.is_empty():
		lo = trend[0]
		hi = trend[0]
		for v in trend:
			lo = minf(lo, v)
			hi = maxf(hi, v)
	var where := "high" if hi > lo and best >= lo + (hi - lo) * 0.75 else ("low" if hi > lo and best <= lo + (hi - lo) * 0.25 else "middling")
	var facts := "Buy new CR %s" % T.money(int(buy.get("unit", 0.0)))
	if not used.is_empty():
		facts += "  ·  used lot CR %s each (refurbished)" % T.money(int(used.unit))
	facts += "  ·  buyers pay CR %s (%s)" % [T.money(int(best)), str(offers[0].name) if not offers.is_empty() else "nobody"]
	left.add_child(_label(facts, "mono_medium", fs - 3, T.DIM))
	left.add_child(_label("Held %d%s  ·  buy-back this fortnight CR %s to %s, %s today" % [have, ("  ·  %d coming" % coming) if coming > 0 else "",
			T.money(int(lo)), T.money(int(hi)), where], "mono_medium", fs - 3, T.GOOD if where == "high" else (T.AMBER if where == "middling" else T.DIM)))
	var spark := Control.new()
	spark.custom_minimum_size = Vector2(fs * 7, fs * 2.2)
	spark.draw.connect(_draw_trend.bind(spark, trend))
	row.add_child(spark)
	var b := T.button("BUY %d" % LOT, false, fs - 3)
	b.disabled = buy.is_empty()
	b.tooltip_text = "%d new from %s for CR %s, in %d days." % [LOT, str(buy.get("name", "")), T.money(int(buy.get("total", 0.0))), int(buy.get("lead", 0))]
	b.pressed.connect(func() -> void: bus.call("trade_buy", key, LOT, false))
	row.add_child(b)
	var u := T.button("LOT %d" % LOT, false, fs - 3)
	u.disabled = used.is_empty()
	u.tooltip_text = "A second-hand lot of %d for CR %s, refurbished in the works before it can be sold." % [LOT, T.money(int(used.get("total", 0.0)))]
	u.pressed.connect(func() -> void: bus.call("trade_buy", key, LOT, true))
	row.add_child(u)
	var s1 := T.button("SELL 1", true, fs - 3)
	s1.disabled = have < 1
	s1.pressed.connect(func() -> void: bus.call("trade_sell", key, 1, ""))
	row.add_child(s1)
	var sa := T.button("SELL ALL", true, fs - 3)
	sa.disabled = have < 1
	if have > 1:
		var all_offers: Array = bus.call("trade_offers", key, have)
		if not all_offers.is_empty():
			sa.tooltip_text = "%d to %s at CR %s each (more at once fetches less each)." % [have, str(all_offers[0].name), T.money(int(all_offers[0].each))]
	sa.pressed.connect(func() -> void: bus.call("trade_sell", key, have, ""))
	row.add_child(sa)
	_body.add_child(card)


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
