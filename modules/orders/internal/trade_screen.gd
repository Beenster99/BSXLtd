extends PanelContainer
## PARTS TRADING (master plan 7.6, a sideline): on any wall of the design room and on the wrist.
## A market (beenster, 20 Nov): each part's price rises and falls over weeks and months; buy at a
## low, sell at a high. A "how this works" box, then a table, one row a part: PART, YOU HOLD (and
## how many are coming), BUY NEW (today), SECOND-HAND LOT (the parts' price, and the refurb works'
## bill shown apart; a few parts a day), SELL TODAY (the best supplier), the last 90 days' chart,
## then TRENDS (this week, this month, and where today sits in the 90 days: LOW, HIGH or
## MIDDLING), then NEW 5, BUY LOT, SELL 1 and SELL ALL. Trading's money shows as its own line in
## the accounts.

const T := preload("res://modules/ui/api/terminal_kit.gd")

const BG := Color(0.02, 0.05, 0.09)
const CARD := Color(0.05, 0.1, 0.16)
const LOT := TradeBook.LOT_SIZE

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
	_status.text = "PARTS TRADING  ·  DAY %d  ·  SPENT ON STOCK CR %s  ·  PAID BY BUYERS CR %s  ·  NET SO FAR CR %s (unsold stock counts as spent)" % [
			int(bus.call("market_day")), T.money(int(t.spent)), T.money(int(t.earned)), T.money(int(t.net))]
	if not Flags.is_on(OrdersBus.SELL_FLAG):
		_body.add_child(_label("Parts trading is off.", "body_medium", fs, T.DIM))
		return
	var how := PanelContainer.new()
	how.add_theme_stylebox_override("panel", T.box(CARD, Color.TRANSPARENT, 0, fs * 0.3))
	var hv := VBoxContainer.new()
	how.add_child(hv)
	hv.add_child(_label("HOW THIS WORKS", "display_bold", fs, T.ORANGE))
	for line: String in [
			"1. Each part's price rises and falls over weeks and months. Buy when it is LOW, sell when it is HIGH. The chart and TRENDS show where it has been.",
			"2. Buy NEW 5 at today's new price, or one of today's SECOND-HAND LOTS of %d: cheaper parts, but the refurb works charge to fix them up first." % LOT,
			"3. When they are in (YOU HOLD), sell to the supplier paying most. On any one day suppliers pay a bit under the new price, so the profit is in the timing."]:
		var l := _label(line, "body_medium", fs - 2, T.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hv.add_child(l)
	var held := T.button("SHOW ONLY WHAT I HOLD" if not only_held else "SHOW EVERY PART", only_held, fs - 3)
	held.pressed.connect(func() -> void:
		only_held = not only_held
		refresh())
	held.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hv.add_child(held)
	_body.add_child(how)
	_body.add_child(_row(true, {}, 0, 0, false))
	var holdings: Dictionary = bus.get("holdings")
	var coming := _coming()
	var lots: Array = bus.call("trade_lots")
	for l: Dictionary in bus.call("trade_lines"):
		var key := str(l.key)
		var have := int(holdings.get(key, 0))
		if only_held and have <= 0 and int(coming.get(key, 0)) <= 0:
			continue
		_body.add_child(_row(false, l, have, int(coming.get(key, 0)), lots.has(key)))
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


## Column widths (in font sizes): part, you hold, buy new, second-hand lot, sell today, 90 days, trends.
const COLS := [9.0, 5.0, 6.5, 11.5, 9.5, 12.0, 11.0]
const HEADS := ["PART", "YOU HOLD", "BUY NEW", "SECOND-HAND LOT", "SELL TODAY", "LAST 90 DAYS", "TRENDS"]
const DAYS := 90


## One row of the table: the headings when `head`, else part `l` (`lot`: a lot of it is on offer today).
func _row(head: bool, l: Dictionary, have: int, coming: int, lot: bool) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", T.box(CARD if not head else Color.TRANSPARENT, Color.TRANSPARENT, 0, fs * 0.3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(fs * 0.6))
	card.add_child(row)
	if head:
		for i in HEADS.size():
			_cell(row, _lines([[HEADS[i], "mono_bold", fs - 4, T.DIM]]), i)
		var bs := _label("BUY  ·  SELL", "mono_bold", fs - 4, T.DIM)
		bs.custom_minimum_size.x = fs * 4.4 * 4.0 + int(fs * 0.6) * 3
		bs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(bs)
		return card
	var key := str(l.key)
	var buy: Dictionary = bus.call("trade_buy_quote", key, LOT)
	var used: Dictionary = bus.call("trade_used_quote", key, LOT) if lot else {}
	var offers: Array = bus.call("trade_offers", key, 1)
	var best := float(offers[0].each) if not offers.is_empty() else 0.0
	var trend: PackedFloat32Array = bus.call("trade_trend", key, DAYS)
	var st := _stats(trend)
	_cell(row, _lines([[str(l.name), "body_medium", fs - 1, T.TEXT]]), 0)
	var hold := [["%d" % have, "mono_medium", fs - 2, T.TEXT if have > 0 else T.DIM]]
	if coming > 0:
		hold.append(["+%d coming" % coming, "mono_medium", fs - 4, T.DIM])
	_cell(row, _lines(hold), 1)
	_cell(row, _lines([["CR %s" % T.money(int(buy.unit)) if not buy.is_empty() else "-", "mono_medium", fs - 2, T.TEXT],
			["each", "mono_medium", fs - 4, T.DIM]]), 2)
	if used.is_empty():
		_cell(row, _lines([["none today", "mono_medium", fs - 2, T.DIM]]), 3)
	else:
		_cell(row, _lines([["CR %s each" % T.money(int(used.parts)), "mono_medium", fs - 2, T.TEXT],
				["+ CR %s each to refurb" % T.money(int(used.refurb)), "mono_medium", fs - 4, T.AMBER]]), 3)
	_cell(row, _lines([["CR %s" % T.money(int(best)) if not offers.is_empty() else "nobody", "mono_medium", fs - 2, T.GOOD],
			[str(offers[0].name) if not offers.is_empty() else "", "mono_medium", fs - 4, T.DIM]]), 4)
	var spark := Control.new()
	spark.custom_minimum_size = Vector2(fs * float(COLS[5]), fs * 2.2)
	spark.draw.connect(_draw_trend.bind(spark, trend))
	spark.tooltip_text = "What suppliers paid for one over the last %d days (CR %s to %s). The orange dot is today; the dashed line is the 90-day average." % [
			DAYS, T.money(int(st.lo)), T.money(int(st.hi))]
	_cell(row, spark, 5)
	var where := "MIDDLING"
	var wc := T.DIM
	if float(st.pos) <= 0.25:
		where = "LOW, buy"
		wc = T.AMBER
	elif float(st.pos) >= 0.75:
		where = "HIGH, sell"
		wc = T.GOOD
	_cell(row, _lines([[_change("week", float(st.week)), "mono_medium", fs - 4, T.TEXT],
			[_change("month", float(st.month)), "mono_medium", fs - 4, T.TEXT],
			["90-day range: " + where, "mono_bold", fs - 4, wc]]), 6)
	var b := T.button("NEW %d" % LOT, false, fs - 3)
	b.disabled = buy.is_empty()
	if not buy.is_empty():
		b.tooltip_text = "Buy %d new from %s for CR %s; they arrive in %d days." % [LOT, str(buy.get("name", "")), T.money(int(buy.total)), int(buy.get("lead", 0))]
	b.pressed.connect(func() -> void: bus.call("trade_buy", key, LOT, false))
	_button(row, b)
	var u := T.button("BUY LOT", false, fs - 3)
	u.disabled = used.is_empty()
	if not used.is_empty():
		u.tooltip_text = "Buy this second-hand lot of %d: CR %s for the parts and CR %s to refurb them, CR %s in all. Ready to sell in about %d days." % [
				LOT, T.money(int(float(used.parts) * LOT)), T.money(int(float(used.refurb) * LOT)), T.money(int(used.total)), int(used.lead)]
	u.pressed.connect(func() -> void: bus.call("trade_buy", key, LOT, true))
	_button(row, u)
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


## The trend's figures: lo, hi, avg, pos (today in the range, 0 low to 1 high), week and month
## (today against 7 and 30 days ago, a share).
static func _stats(trend: PackedFloat32Array) -> Dictionary:
	var out := {"lo": 0.0, "hi": 0.0, "avg": 0.0, "pos": 0.5, "week": 0.0, "month": 0.0}
	if trend.is_empty():
		return out
	var lo := trend[0]
	var hi := trend[0]
	var sum := 0.0
	for v in trend:
		lo = minf(lo, v)
		hi = maxf(hi, v)
		sum += v
	var today := trend[trend.size() - 1]
	out.lo = lo
	out.hi = hi
	out.avg = sum / float(trend.size())
	out.pos = (today - lo) / (hi - lo) if hi > lo else 0.5
	var n := trend.size()
	if n > 7 and trend[n - 8] > 0.0:
		out.week = today / trend[n - 8] - 1.0
	if n > 30 and trend[n - 31] > 0.0:
		out.month = today / trend[n - 31] - 1.0
	return out


func _change(span: String, share: float) -> String:
	if absf(share) < 0.01:
		return "this %s: flat" % span
	return "this %s: %s %d%%" % [span, "up" if share > 0.0 else "down", roundi(absf(share) * 100.0)]


## A column of labels: [[text, face, size, colour], ...].
func _lines(rows: Array) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	for r: Array in rows:
		var l := _label(str(r[0]), str(r[1]), int(r[2]), r[3])
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(l)
	return v


func _cell(row: HBoxContainer, c: Control, i: int) -> void:
	c.custom_minimum_size.x = fs * float(COLS[i])
	if i == 0:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(c)


func _button(row: HBoxContainer, b: Button) -> void:
	b.custom_minimum_size.x = fs * 4.4
	b.clip_text = true
	row.add_child(b)


func _draw_trend(c: Control, trend: PackedFloat32Array) -> void:
	var sz := c.size
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.06, 0.1))
	if trend.size() < 2:
		return
	var st := _stats(trend)
	var lo := float(st.lo)
	var span := maxf(float(st.hi) - lo, 1.0)
	var y := func(v: float) -> float: return sz.y - 3.0 - (v - lo) / span * (sz.y - 6.0)
	# The 90-day average, dashed, and month marks (30 and 7 days back).
	c.draw_dashed_line(Vector2(2.0, y.call(float(st.avg))), Vector2(sz.x - 2.0, y.call(float(st.avg))), Color(1, 1, 1, 0.25), 1.0, 4.0)
	for back: int in [30, 7]:
		if trend.size() > back:
			var x := float(trend.size() - 1 - back) / float(trend.size() - 1) * (sz.x - 4.0) + 2.0
			c.draw_line(Vector2(x, 0.0), Vector2(x, sz.y), Color(1, 1, 1, 0.08), 1.0)
	var pts := PackedVector2Array()
	for i in trend.size():
		pts.append(Vector2(float(i) / float(trend.size() - 1) * (sz.x - 4.0) + 2.0, y.call(trend[i])))
	c.draw_polyline(pts, T.CYAN, 1.5, true)
	c.draw_circle(pts[pts.size() - 1], 3.0, T.ORANGE)


func _label(text: String, face: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", T.font(face))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l
