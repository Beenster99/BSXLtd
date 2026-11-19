extends PanelContainer
## The PARTS MARKET wall panel (beenster, 19 Nov): the open design's parts list priced by
## every vendor, with this week's deals, waits from the company's standing and the volume
## bought, the running optimiser's three ways to buy it (cheapest, most reliable, median
## cost) and its notes, a chart of the past months' prices for a line or the whole design,
## and where the company stands with each vendor.
##
## Click a line for its price history (WHOLE DESIGN for the basket), a plan to mark its picks
## in the table, 30 D / 90 D / 180 D for the span. Everything refreshes with each edit, each
## market day and each change of standing.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const PriceChart := preload("res://modules/supply/internal/price_chart.gd")

const DESIGN_ROW := "__design"
const SPANS: Array[int] = [30, 90, 180]
## Seconds each optimiser note stays up.
const NOTE_SECONDS := 6.0

const BG := Color(0.02, 0.05, 0.09)
const CARD := Color(0.05, 0.1, 0.16)
const CARD_ON := Color(0.09, 0.17, 0.25)
const ROW := Color(0.04, 0.08, 0.13)
const ROW_ALT := Color(0.055, 0.1, 0.155)
const ROW_ON := Color(0.1, 0.2, 0.3)
const PICK := Color(0.91, 0.47, 0.17)
const LINE := Color(0.2, 0.45, 0.65, 0.6)
const PLAN_COLOURS := {SupplyOptimiser.CHEAPEST: Color("7fd47a"), SupplyOptimiser.RELIABLE: Color("6fc8e8"),
		SupplyOptimiser.MEDIAN: Color("e8c25a")}

var bus: SupplyBus
var px_per_m := 150.0
## The base text size, px.
var fs := 15
## The plan whose picks the table marks.
var plan := SupplyOptimiser.CHEAPEST
## The line the chart shows (its key), or DESIGN_ROW.
var selected := DESIGN_ROW
var span := 90
## The optimiser's notes, and the one up now.
var notes: PackedStringArray = []
var note_at := 0

var _status: Label
var _cards: HBoxContainer
var _note: Label
var _table: VBoxContainer
var _chart: PriceChart
var _vendors: VBoxContainer
var _spans: HBoxContainer
var _queued := false
var _note_clock := 0.0


func setup(supply_bus: SupplyBus, density: float) -> void:
	bus = supply_bus
	px_per_m = density
	fs = maxi(12, int(px_per_m * 0.1))
	name = "PartsMarket"
	add_theme_stylebox_override("panel", T.box(BG, Color.TRANSPARENT, 0, fs * 0.5))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(fs * 0.5))
	add_child(col)
	_status = _label("", "mono_medium", fs - 2, T.DIM)
	_status.clip_text = true
	col.add_child(_status)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", int(fs * 0.5))
	col.add_child(_cards)
	var note_box := PanelContainer.new()
	note_box.add_theme_stylebox_override("panel", T.box(Color(0.12, 0.08, 0.03), PICK, 1, fs * 0.35))
	_note = _label("", "body_medium", fs, Color(1.0, 0.85, 0.65))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.y = fs * 2.6
	note_box.add_child(_note)
	note_box.mouse_filter = Control.MOUSE_FILTER_STOP
	note_box.gui_input.connect(func(e: InputEvent) -> void:
		if _clicked(e):
			_next_note())
	col.add_child(note_box)
	# The parts table.
	var table_box := VBoxContainer.new()
	table_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_box.size_flags_stretch_ratio = 1.15
	table_box.add_theme_constant_override("separation", 0)
	col.add_child(table_box)
	table_box.add_child(_head_row())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_box.add_child(scroll)
	_table = VBoxContainer.new()
	_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table.add_theme_constant_override("separation", 1)
	scroll.add_child(_table)
	# The chart and the vendors side by side.
	var bottom := HBoxContainer.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.add_theme_constant_override("separation", int(fs * 0.5))
	col.add_child(bottom)
	var chart_col := VBoxContainer.new()
	chart_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_col.size_flags_stretch_ratio = 1.3
	chart_col.add_theme_constant_override("separation", 2)
	bottom.add_child(chart_col)
	_spans = HBoxContainer.new()
	_spans.add_theme_constant_override("separation", 4)
	chart_col.add_child(_spans)
	_chart = PriceChart.new()
	_chart.name = "PriceChart"
	_chart.font_size = fs - 1
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.custom_minimum_size.y = fs * 10
	chart_col.add_child(_chart)
	var vend_scroll := ScrollContainer.new()
	vend_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vend_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(vend_scroll)
	_vendors = VBoxContainer.new()
	_vendors.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vendors.add_theme_constant_override("separation", 3)
	vend_scroll.add_child(_vendors)
	var design := Modules.bus("design") as DesignBus
	if design:
		design.design_changed.connect(_queue)
	bus.day_changed.connect(func(_d: int) -> void: _queue())
	bus.standing_changed.connect(func(_v: String, _s: float) -> void: _queue())
	refresh()


func _process(delta: float) -> void:
	_note_clock += delta
	if _note_clock >= NOTE_SECONDS:
		_next_note()
	if _status and bus:
		_status.text = _status_text()


func _queue() -> void:
	if not _queued:
		_queued = true
		refresh.call_deferred()


## Builds every part of the screen again from the optimiser.
func refresh() -> void:
	_queued = false
	if bus == null:
		return
	var opt := bus.optimiser()
	var design := Modules.bus("design") as DesignBus
	var rec: DesignRecord = design.library.current if design else null
	if selected != DESIGN_ROW and not _keys(opt).has(selected):
		selected = DESIGN_ROW
	_fill_cards(opt, rec)
	notes = _notes(opt)
	note_at = clampi(note_at, 0, maxi(notes.size() - 1, 0))
	_show_note()
	_fill_table(opt, rec)
	_fill_spans()
	_fill_chart(opt)
	_fill_vendors(opt)


func set_plan(p: String) -> void:
	plan = p
	refresh()


func select(key: String) -> void:
	selected = key
	refresh()


func set_span(days: int) -> void:
	span = days
	refresh()


# The status line and the optimiser's three plans.

func _status_text() -> String:
	var opt := bus._opt
	var ago := (Time.get_ticks_msec() - bus.last_run_msec) / 1000.0
	return "MARKET DAY %d   %d VENDORS   OPTIMISER %s  weighed %d quotes in %.0f ms, %s ago%s" % [
			bus.day, bus.vendors.size(), "RUNNING" if int(Time.get_ticks_msec() / 600.0) % 2 == 0 else "running",
			opt.quotes_weighed if opt else 0, bus.last_run_cost_msec, _ago(ago),
			("  after " + bus.last_reason) if bus.last_reason != "" else ""]


func _fill_cards(opt: SupplyOptimiser, rec: DesignRecord) -> void:
	_clear(_cards)
	if rec == null or opt.rows.is_empty():
		_cards.add_child(_label("No design open, or nothing to buy yet. Open a design at the holotable.", "body", fs + 2, T.DIM))
		return
	for p: String in SupplyOptimiser.PLANS:
		var s: Dictionary = opt.plans[p]
		var on := p == plan
		var card := PanelContainer.new()
		card.name = "Plan_" + p
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", T.box(CARD_ON if on else CARD, PLAN_COLOURS[p] if on else LINE, 3 if on else 1, fs * 0.45))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(e: InputEvent) -> void:
			if _clicked(e):
				set_plan(p))
		_cards.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		card.add_child(v)
		v.add_child(_label(SupplyOptimiser.PLAN_NAMES[p], "display_bold", fs, PLAN_COLOURS[p]))
		v.add_child(_label("CR " + T.money(int(s.total)), "mono_bold", int(fs * 1.75), T.TEXT))
		var save := opt.saving(p)
		var vs := "market median" if p == SupplyOptimiser.MEDIAN else (
				("CR %s under median" % T.money(int(save))) if save >= 0.5 else ("CR %s over median" % T.money(int(-save))))
		v.add_child(_label(vs, "body", fs - 2, T.GOOD if p != SupplyOptimiser.MEDIAN and save >= 0.5 else T.DIM))
		v.add_child(_label("Wait %d d   On time %d%%   %d vendor%s" % [int(s.lead), roundi(float(s.on_time) * 100.0),
				(s.vendors as Array).size(), "" if (s.vendors as Array).size() == 1 else "s"], "mono_medium", fs - 2, T.TEXT))
	# The fourth card: the deals the design can take this week.
	var hits := opt.on_deal()
	var best := 0.0
	for h: Dictionary in hits:
		var q: Dictionary = h.quote
		best += float(q.list_unit) * float((h.row.line as Dictionary).qty) * int(q.deal_off) / 100.0
	var deal_card := PanelContainer.new()
	deal_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deal_card.add_theme_stylebox_override("panel", T.box(CARD, LINE, 1, fs * 0.45))
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 0)
	deal_card.add_child(dv)
	dv.add_child(_label("DEALS THIS WEEK", "display_bold", fs, T.GOOD))
	dv.add_child(_label("%d line%s" % [hits.size(), "" if hits.size() == 1 else "s"], "mono_bold", int(fs * 1.75), T.TEXT))
	dv.add_child(_label("up to CR %s off" % T.money(int(best)) if hits.size() > 0 else "none on this design", "body", fs - 2, T.DIM))
	dv.add_child(_label("Week ends day %d" % ((floori(bus.day / 7.0) + 1) * 7), "mono_medium", fs - 2, T.TEXT))
	_cards.add_child(deal_card)


# The table: one row per line, a column per vendor.

func _col_w() -> float:
	return fs * 5.6


func _head_row() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(Color(0.06, 0.13, 0.2), Color.TRANSPARENT, 0, fs * 0.25))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	p.add_child(h)
	var part := _label("PART", "display_bold", fs - 1, T.DIM)
	part.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(part)
	for v in bus.vendors:
		var l := _label(_short_name(v).to_upper(), "display_bold", fs - 2, v.colour)
		l.custom_minimum_size.x = _col_w()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		h.add_child(l)
	var tr := _label("30 D", "display_bold", fs - 2, T.DIM)
	tr.custom_minimum_size.x = fs * 4.0
	tr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(tr)
	return p


func _fill_table(opt: SupplyOptimiser, rec: DesignRecord) -> void:
	_clear(_table)
	if rec == null:
		return
	# The whole design: what each vendor could supply of it.
	var cells: Array[Control] = []
	for v in bus.vendors:
		var n := 0
		var sum := 0.0
		for r in opt.rows:
			for q: Dictionary in r.quotes:
				if q.vendor == v.id:
					n += 1
					sum += float(q.total)
		cells.append(_cell("%s" % _short(sum) if n > 0 else "-", "%d/%d lines" % [n, opt.rows.size() + opt.unsupplied.size()],
				T.TEXT if n > 0 else T.DIM, false, false))
	var trend := _design_trend(opt)
	_table.add_child(_row(DESIGN_ROW, "WHOLE DESIGN", "%d lines   %s" % [opt.rows.size(), rec.name], cells, trend, false))
	var ids := placed_ids(rec)
	var alt := false
	for r in opt.rows:
		var line: Dictionary = r.line
		var pick: Dictionary = r.picks[plan]
		cells = []
		for v in bus.vendors:
			var q := {}
			for x: Dictionary in r.quotes:
				if x.vendor == v.id:
					q = x
			if q.is_empty():
				cells.append(_cell("-", "", T.DIM, false, false))
				continue
			var sub := "%d d" % int(q.lead)
			if int(q.deal_off) > 0:
				sub += "  -%d%%" % int(q.deal_off)
			var col := T.TEXT if float(q.on_time) >= 0.85 else T.AMBER
			cells.append(_cell(_short(float(q.unit)), sub, col, q.vendor == pick.vendor, int(q.deal_off) > 0))
		var grade := str(line.grade)
		var sub_text := "%s %s" % [_qty(line), str(line.pack) if str(line.pack) != "" else ""]
		if grade != "":
			sub_text += "   grade %s %s" % [grade, str(DesignGrades.GRADES.get(grade, {}).get("name", ""))]
		sub_text += "   " + SupplyMarket.category_name(str(line.category))
		var tags: PackedStringArray = line.tags if not (line.tags as PackedStringArray).is_empty() \
				else ids.get(str(line.key), PackedStringArray())
		if not tags.is_empty():
			sub_text = "ID " + " ".join(tags) + "   " + sub_text
		_table.add_child(_row(str(line.key), str(line.name), sub_text, cells, _line_trend(r), alt))
		alt = not alt
	for line in opt.unsupplied:
		var none: Array[Control] = []
		for v in bus.vendors:
			none.append(_cell("-", "", T.DIM, false, false))
		_table.add_child(_row(str(line.key), str(line.name), "NO VENDOR STOCKS GRADE %s" % str(line.grade), none, NAN, alt))
		alt = not alt


func _row(key: String, title: String, sub: String, cells: Array[Control], trend: float, alt: bool) -> Control:
	var on := key == selected
	var p := PanelContainer.new()
	p.name = "Row_" + key.replace(":", "_")
	var st := T.box(ROW_ON if on else (ROW_ALT if alt else ROW), PICK if on else Color.TRANSPARENT, 2 if on else 0, 0)
	st.content_margin_left = fs * 0.4
	st.content_margin_right = fs * 0.3
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(e: InputEvent) -> void:
		if _clicked(e):
			select(key))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	p.add_child(h)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", -2)
	var t := _label(title, "body_medium", fs, T.TEXT if key != DESIGN_ROW else PICK)
	t.clip_text = true
	names.add_child(t)
	var s := _label(sub.to_upper(), "display_medium", fs - 4, T.DIM)
	s.clip_text = true
	names.add_child(s)
	h.add_child(names)
	for c in cells:
		h.add_child(c)
	var tr := _label("-" if is_nan(trend) else ("%+.1f%%" % (trend * 100.0)), "mono_medium", fs - 1,
			T.DIM if is_nan(trend) else (T.BAD if trend > 0.005 else (T.GOOD if trend < -0.005 else T.DIM)))
	tr.custom_minimum_size.x = fs * 4.0
	tr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(tr)
	return p


func _cell(top: String, sub: String, col: Color, picked: bool, deal: bool) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = _col_w()
	var st := T.box(Color(PICK, 0.22) if picked else Color.TRANSPARENT, PICK if picked else Color.TRANSPARENT, 1 if picked else 0, 1)
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var a := _label(top, "mono_bold" if picked else "mono_medium", fs, col)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(a)
	if sub != "":
		var b := _label(sub, "mono_medium", fs - 4, T.GOOD if deal else T.DIM)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(b)
	return p


## The line's cheapest price now against 30 days ago (0.04 = up 4%).
func _line_trend(r: Dictionary) -> float:
	var q: Dictionary = r.picks[SupplyOptimiser.CHEAPEST]
	var v := bus.vendor(str(q.vendor))
	var then_price := SupplyMarket.list_price(v, r.line, bus.day - 30)
	var now_price := SupplyMarket.list_price(v, r.line, bus.day)
	return now_price / then_price - 1.0 if then_price > 0.0 else NAN


func _design_trend(opt: SupplyOptimiser) -> float:
	var then_sum := 0.0
	var now_sum := 0.0
	for r in opt.rows:
		var q: Dictionary = r.picks[SupplyOptimiser.CHEAPEST]
		var v := bus.vendor(str(q.vendor))
		then_sum += SupplyMarket.list_price(v, r.line, bus.day - 30) * float(r.line.qty)
		now_sum += SupplyMarket.list_price(v, r.line, bus.day) * float(r.line.qty)
	return now_sum / then_sum - 1.0 if then_sum > 0.0 else NAN


# The chart.

func _fill_spans() -> void:
	_clear(_spans)
	var title := _label("PRICE HISTORY", "display_bold", fs - 1, T.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spans.add_child(title)
	for d in SPANS:
		var b := T.button("%d D" % d, false, fs - 3, d == span)
		b.name = "Span_%d" % d
		b.pressed.connect(set_span.bind(d))
		_spans.add_child(b)


func _fill_chart(opt: SupplyOptimiser) -> void:
	var step := maxi(1, span / 60)
	var series: Array[Dictionary] = []
	if selected == DESIGN_ROW:
		# The whole design bought each way, day by day (deals as they ran then).
		var cheap := PackedFloat32Array()
		var med := PackedFloat32Array()
		var n := ceili(float(span) / step)
		cheap.resize(n)
		med.resize(n)
		for r in opt.rows:
			var per: Array[PackedFloat32Array] = []
			for q: Dictionary in r.quotes:
				per.append(SupplyMarket.history(bus.vendor(str(q.vendor)), r.line, bus.day, span, bus.catalog(), step))
			var qty := float(r.line.qty)
			for i in n:
				var vals: Array[float] = []
				for h in per:
					if i < h.size():
						vals.append(h[i])
				if vals.is_empty():
					continue
				vals.sort()
				cheap[i] += vals[0] * qty
				med[i] += vals[floori((vals.size() - 1) / 2.0)] * qty
		series.append({"name": "median", "colour": PLAN_COLOURS[SupplyOptimiser.MEDIAN], "values": med, "bold": false})
		series.append({"name": "cheapest", "colour": PLAN_COLOURS[SupplyOptimiser.CHEAPEST], "values": cheap, "bold": true})
		_chart.set_data(series, 0.0, span, "WHOLE DESIGN at each day's prices (before volume and standing discounts), past %d days" % span, "CR, whole design")
		return
	for r in opt.rows:
		if str(r.line.key) != selected:
			continue
		var pick: Dictionary = r.picks[plan]
		for q: Dictionary in r.quotes:
			var v := bus.vendor(str(q.vendor))
			var vals := SupplyMarket.history(v, r.line, bus.day, span, bus.catalog(), step)
			var marks := PackedByteArray()
			var d := bus.day - span + 1
			for i in vals.size():
				marks.append(1 if not SupplyMarket.deal_on(v, r.line, d + i * step, bus.catalog(), int(r.line.units)).is_empty() else 0)
			series.append({"name": _short_name(v), "colour": v.colour, "values": vals, "deals": marks, "bold": q.vendor == pick.vendor})
		_chart.set_data(series, float(r.line.list_unit), span, "%s   %s, past %d days (shaded: on deal)" % [
				str(r.line.name).to_upper(), _qty(r.line), span], "CR each")


# The vendors: standing, what the next tier gives, reliability, this week's deals.

func _fill_vendors(opt: SupplyOptimiser) -> void:
	_clear(_vendors)
	_vendors.add_child(_label("VENDORS AND STANDING", "display_bold", fs - 1, T.TEXT))
	var used: Dictionary = {}
	for r in opt.rows:
		var q: Dictionary = r.picks[plan]
		used[q.vendor] = int(used.get(q.vendor, 0)) + 1
	for v in bus.vendors:
		var st := bus.standing_of(v.id)
		var t := SupplyMarket.tier(st)
		var p := PanelContainer.new()
		p.name = "Vendor_" + v.id
		var sb := T.box(CARD, Color(v.colour, 0.8), 0, fs * 0.3)
		sb.border_width_left = 4
		p.add_theme_stylebox_override("panel", sb)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -1)
		p.add_child(col)
		var top := HBoxContainer.new()
		var nm := _label(v.display_name, "body_medium", fs - 1, v.colour)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		top.add_child(nm)
		if used.has(v.id):
			top.add_child(_label("%d LINE%s IN PLAN" % [used[v.id], "" if used[v.id] == 1 else "S"], "mono_medium", fs - 4, PICK))
		col.add_child(top)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.value = st
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, fs * 0.45)
		var fill := StyleBoxFlat.new()
		fill.bg_color = v.colour
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", T.box(Color(0.1, 0.14, 0.2)))
		col.add_child(bar)
		var next := ""
		if int(t.next) >= 0:
			var nt := SupplyMarket.tier(float(t.next))
			next = "   next %s at %d: %+d d, %d%% off" % [str(nt.name), int(t.next), int(nt.lead), int(nt.off)]
		col.add_child(_label("%s %d/100: %+d d, %d%% off%s" % [str(t.name).to_upper(), int(st), int(t.lead), int(t.off), next],
				"mono_medium", fs - 4, T.TEXT))
		var vol := PackedStringArray()
		var ks := v.volume_percent.keys()
		ks.sort()
		for k in ks:
			vol.append("%d+ %d%%" % [int(k), int(v.volume_percent[k])])
		col.add_child(_label("On time %d%%   holds %d, then +%d d a batch   volume %s" % [roundi(v.reliability * 100.0),
				v.stock, v.restock_days, "  ".join(vol)], "mono_medium", fs - 4, T.DIM))
		var ds := PackedStringArray()
		for d: Dictionary in SupplyMarket.deals(v, bus.day, bus.catalog()):
			ds.append("%s -%d%%%s" % [str(d.name), int(d.percent), " (%d+)" % int(d.min_units) if int(d.min_units) > 1 else ""])
		if not ds.is_empty():
			var dl := _label("DEALS: " + ";  ".join(ds), "body", fs - 4, T.GOOD)
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(dl)
		_vendors.add_child(p)


# The optimiser's notes, one up at a time.

func _notes(opt: SupplyOptimiser) -> PackedStringArray:
	var out := PackedStringArray()
	if opt.rows.is_empty():
		return out
	var cheap: Dictionary = opt.plans[SupplyOptimiser.CHEAPEST]
	var rel: Dictionary = opt.plans[SupplyOptimiser.RELIABLE]
	var med: Dictionary = opt.plans[SupplyOptimiser.MEDIAN]
	var save := opt.saving(SupplyOptimiser.CHEAPEST)
	out.append("Cheapest buys the whole ship for CR %s, CR %s (%d%%) under the market median, from %d vendors; the last part lands in %d days." % [
			T.money(int(cheap.total)), T.money(int(save)), roundi(100.0 * save / maxf(float(med.total), 1.0)),
			(cheap.vendors as Array).size(), int(cheap.lead)])
	var extra := float(rel.total) - float(cheap.total)
	if float(rel.on_time) > float(cheap.on_time) + 0.01:
		out.append("Most reliable costs CR %s more than cheapest and raises the chance the whole order comes on time from %d%% to %d%%." % [
				T.money(int(extra)), roundi(float(cheap.on_time) * 100.0), roundi(float(rel.on_time) * 100.0)])
	# The best deal the design can take.
	var best := {}
	var best_save := 0.0
	for h: Dictionary in opt.on_deal():
		var q: Dictionary = h.quote
		var s := float(q.list_unit) * float(h.row.line.qty) * int(q.deal_off) / 100.0
		if s > best_save:
			best_save = s
			best = h
	if not best.is_empty():
		var q: Dictionary = best.quote
		out.append("Deal: %s from %s is %d%% off until day %d, worth CR %s on this design." % [str(best.row.line.name),
				bus.vendor(str(q.vendor)).display_name, int(q.deal_off), int((q.deal as Dictionary).ends), T.money(int(best_save))])
	# The line that sets the wait, and whether someone has it sooner.
	var slow := {}
	for r in opt.rows:
		if slow.is_empty() or int(r.picks[SupplyOptimiser.CHEAPEST].lead) > int(slow.picks[SupplyOptimiser.CHEAPEST].lead):
			slow = r
	if not slow.is_empty():
		var q: Dictionary = slow.picks[SupplyOptimiser.CHEAPEST]
		var faster := {}
		for x: Dictionary in slow.quotes:
			if int(x.lead) < int(q.lead) and (faster.is_empty() or int(x.lead) < int(faster.lead)):
				faster = x
		var text := "%s sets the wait: %d days from %s." % [str(slow.line.name), int(q.lead), bus.vendor(str(q.vendor)).display_name]
		if not faster.is_empty():
			text += " %s has it in %d days for CR %s more." % [bus.vendor(str(faster.vendor)).display_name, int(faster.lead),
					T.money(int(float(faster.total) - float(q.total)))]
		out.append(text)
	# Standing worth raising: the vendor with the most cheapest-plan spend short of its next tier.
	var spend := {}
	for r in opt.rows:
		var q: Dictionary = r.picks[SupplyOptimiser.CHEAPEST]
		spend[q.vendor] = float(spend.get(q.vendor, 0.0)) + float(q.total)
	var top := ""
	for v: String in spend:
		if int(SupplyMarket.tier(bus.standing_of(v)).next) >= 0 and (top == "" or float(spend[v]) > float(spend[top])):
			top = v
	if top != "":
		var t := SupplyMarket.tier(bus.standing_of(top))
		var nt := SupplyMarket.tier(float(t.next))
		var gain := float(spend[top]) * (int(nt.off) - int(t.off)) / 100.0
		out.append("Raise standing with %s to %s (%d more) and its lines here get %d%% off and %d day%s quicker: about CR %s." % [
				bus.vendor(top).display_name, str(nt.name), int(float(t.next) - bus.standing_of(top)), int(nt.off),
				int(t.lead) - int(nt.lead), "" if int(t.lead) - int(nt.lead) == 1 else "s", T.money(int(gain))])
	for line in opt.unsupplied:
		out.append("No vendor stocks %s in grade %s: pick another grade at the table." % [str(line.name), str(line.grade)])
	return out


func _show_note() -> void:
	_note_clock = 0.0
	if notes.is_empty():
		_note.text = "OPTIMISER: nothing to buy yet."
		return
	_note.text = "OPTIMISER %d/%d:  %s" % [note_at + 1, notes.size(), notes[note_at]]


func _next_note() -> void:
	if notes.size() > 0:
		note_at = (note_at + 1) % notes.size()
	_show_note()


## The unique ID of every object placed in the design, by the parts list line it is on
## ("component:reactor_small:5H" -> ["C3", "C7"]): what the crew calls each one at the table.
static func placed_ids(rec: DesignRecord) -> Dictionary:
	var out := {}
	if rec == null:
		return out
	for c: Dictionary in rec.components.values() + rec.mounts.values():
		var key := "component:" + str(c.get("type", ""))
		var list: PackedStringArray = out.get(key, PackedStringArray())
		list.append(str(c.get("id", "")).to_upper())
		out[key] = list
	return out


# Helpers.

func _label(text: String, face: String, size: int, col: Color) -> Label:
	var l := T.label(text, face, size, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _keys(opt: SupplyOptimiser) -> PackedStringArray:
	var out := PackedStringArray()
	for r in opt.rows:
		out.append(str(r.line.key))
	for l in opt.unsupplied:
		out.append(str(l.key))
	return out


static func _clicked(e: InputEvent) -> bool:
	return e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT


static func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


static func _short_name(v: SupplyVendor) -> String:
	return v.display_name.get_slice(" ", 0)


static func _short(v: float) -> String:
	if v >= 1000000.0:
		return "%.2fM" % (v / 1000000.0)
	if v >= 10000.0:
		return "%.1fk" % (v / 1000.0)
	if v >= 100.0:
		return T.money(roundi(v))
	return "%.2f" % v


static func _qty(line: Dictionary) -> String:
	var q := float(line.qty)
	var unit := str(line.unit)
	if unit == "x":
		return "%d x" % roundi(q)
	return "%s %s" % [("%d" % roundi(q)) if q >= 10.0 else ("%.1f" % q), unit]


static func _ago(s: float) -> String:
	return "%d s" % int(s) if s < 120.0 else "%d min" % int(s / 60.0)
