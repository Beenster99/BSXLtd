extends PanelContainer
## The ACCOUNTS wall panel (beenster, 19 Nov: "a new and detailed screen of the current
## business accounts"): BSX Ltd's books on a design room wall, read from across the room.
##
##   the headline figures: cash, the period's net against the one before, money in and out,
##     what the company is worth, how many days the cash lasts, reputation, loans owed
##   a warning band while the company is overdrawn, insolvent or short of runway
##   profit and loss: every kind of money in and out, by group with subtotals
##   the cash chart: closing cash each day over the period, with the day's money in and out
##   the balance sheet, what a day costs now, contracts on the books (value, received,
##   parts, margin), loans, crew pay and wallets, stock at market value, and the ledger
##
## TODAY / 7 D / 30 D / ALL pick the period. Everything follows the books as they change.
## Made by BusinessBus.make_accounts_wall for DesignBus.register_wall_view, and the same panel
## is the F1 wrist screen's Accounts channel.

const T := preload("res://modules/ui/api/terminal_kit.gd")

const PERIODS := {"TODAY": 1, "7 D": 7, "30 D": 30, "ALL": 0}
const GROUP_NAMES := {"contracts": "CONTRACTS", "sales": "SALES", "parts": "PARTS AND STOCK", "wages": "CREW PAY",
		"rent": "PREMISES", "loans": "FINANCE", "other": "OTHER"}
## Below this many days of cash the runway figure and the band turn amber.
const RUNWAY_WARN := 7
const RECENT_ROWS := 14

const BG := Color(0.02, 0.05, 0.09)
const CARD := Color(0.05, 0.1, 0.16)
const ROW := Color(0.04, 0.08, 0.13)
const ROW_ALT := Color(0.055, 0.1, 0.155)
const HEAD := Color(0.08, 0.15, 0.22)
const LINE := Color(0.2, 0.45, 0.65, 0.6)

var bus: BusinessBus
var px_per_m := 150.0
## The base text size, px.
var fs := 15
var period := "7 D"
## The last report drawn (tests read it).
var report: Dictionary = {}

var _status: Label
var _chips: HBoxContainer
var _figures: GridContainer
var _band: PanelContainer
var _band_text: Label
var _pnl: VBoxContainer
var _chart: CashChart
var _cards: GridContainer
var _queued := false


func setup(business_bus: BusinessBus, density: float) -> void:
	bus = business_bus
	px_per_m = density
	fs = maxi(12, int(px_per_m * 0.1))
	name = "AccountsWall"
	add_theme_stylebox_override("panel", T.box(BG, Color.TRANSPARENT, 0, fs * 0.5))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", int(fs * 0.5))
	scroll.add_child(col)
	# The status line and the period chips.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(fs * 0.5))
	col.add_child(top)
	_status = _label("", "mono_medium", fs - 2, T.DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	top.add_child(_status)
	_chips = HBoxContainer.new()
	_chips.name = "PeriodChips"
	_chips.add_theme_constant_override("separation", 4)
	top.add_child(_chips)
	_figures = GridContainer.new()
	_figures.name = "Figures"
	_figures.add_theme_constant_override("h_separation", int(fs * 0.4))
	_figures.add_theme_constant_override("v_separation", int(fs * 0.4))
	col.add_child(_figures)
	_band = PanelContainer.new()
	_band.name = "Warning"
	_band_text = _label("", "body_medium", fs, Color(1.0, 0.85, 0.65))
	_band_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_band.add_child(_band_text)
	col.add_child(_band)
	# Profit and loss beside the cash chart.
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", int(fs * 0.5))
	col.add_child(mid)
	var pnl_card := _card("PROFIT AND LOSS")
	pnl_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(pnl_card)
	_pnl = pnl_card.get_child(0) as VBoxContainer
	var chart_card := _card("CASH")
	chart_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_card.size_flags_stretch_ratio = 1.2
	mid.add_child(chart_card)
	_chart = CashChart.new()
	_chart.name = "CashChart"
	_chart.font_size = fs - 2
	_chart.custom_minimum_size.y = fs * 14
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(chart_card.get_child(0) as VBoxContainer).add_child(_chart)
	# The detail cards.
	_cards = GridContainer.new()
	_cards.name = "Cards"
	_cards.add_theme_constant_override("h_separation", int(fs * 0.5))
	_cards.add_theme_constant_override("v_separation", int(fs * 0.5))
	col.add_child(_cards)
	for s in ["ledger_entry_added", "day_closed", "loan_taken", "loan_repaid", "owner_changed", "wallet_changed",
			"payslip_issued", "reputation_changed", "order_placed", "delivery_arrived", "stock_added", "went_insolvent"]:
		if bus.has_signal(s):
			var n := _arg_count(s)
			bus.connect(s, _queue.unbind(n) if n > 0 else _queue)
	resized.connect(_fit_columns)
	refresh()


func _ready() -> void:
	_fit_columns.call_deferred()


func _arg_count(sig: String) -> int:
	for s: Dictionary in bus.get_signal_list():
		if s.name == sig:
			return (s.args as Array).size()
	return 0


func _process(_delta: float) -> void:
	if _status and bus:
		_status.text = "BSX LTD  ·  ACCOUNTS  ·  %s  ·  OWNER %s" % [bus.get_clock_text(), str(report.get("owner", "")).to_upper()]


func _queue() -> void:
	if not _queued:
		_queued = true
		refresh.call_deferred()


## Builds the panel again from the books.
func refresh() -> void:
	_queued = false
	if bus == null:
		return
	report = bus.accounts_report(int(PERIODS[period]))
	_fill_chips()
	_fill_figures()
	_fill_band()
	_fill_pnl()
	_chart.days = report.balance
	_chart.queue_redraw()
	_fill_cards()
	_fit_columns()


func set_period(p: String) -> void:
	if PERIODS.has(p):
		period = p
		refresh()


# --- The parts -----------------------------------------------------------------------------

func _fill_chips() -> void:
	_clear(_chips)
	for p: String in PERIODS:
		var b := _button(p, p == period)
		b.name = "Period_" + p.replace(" ", "")
		b.pressed.connect(set_period.bind(p))
		_chips.add_child(b)


func _fill_figures() -> void:
	_clear(_figures)
	var r := report
	var cash := int(r.cash)
	var now: Dictionary = r.now
	var prev: Dictionary = r.prev
	var net := int(now.net)
	var vs := ""
	if r.has_prev:
		var diff := net - int(prev.net)
		vs = "%s %s ON THE %s BEFORE" % ["▲" if diff >= 0 else "▼", _signed(diff), _period_word()]
	var runway := int(r.runway)
	var run_text := "—" if runway < 0 else ("%d DAYS" % runway if runway < 1000 else "999+ DAYS")
	var run_col := T.GOOD if runway < 0 or runway >= RUNWAY_WARN else (T.AMBER if runway > 0 else T.BAD)
	var burn: Dictionary = r.burn
	_figures.add_child(_figure("CASH", "CR " + T.money(cash), T.BAD if cash < 0 else T.ORANGE, "IN THE COMPANY ACCOUNT"))
	_figures.add_child(_figure("NET " + _period_word(), _signed(net), T.GOOD if net >= 0 else T.BAD, vs))
	_figures.add_child(_figure("MONEY IN", "+" + T.money(int(now.income)), T.GOOD, _prev_line(int(prev.income))))
	_figures.add_child(_figure("MONEY OUT", "−" + T.money(int(now.outgoings)), T.BAD, _prev_line(int(prev.outgoings))))
	_figures.add_child(_figure("NET WORTH", "CR " + T.money(int(r.sheet.worth)), T.CYAN, "CASH + STOCK + ON ORDER − DEBT"))
	_figures.add_child(_figure("RUNWAY", run_text, run_col, "AT %s CR A DAY" % T.money(int(burn.per_day))))
	_figures.add_child(_figure("REPUTATION", "%d / 100" % roundi(float(r.reputation)), T.TEXT, "SETS LOAN LIMIT AND SUPPLIERS"))
	_figures.add_child(_figure("LOANS OWED", T.money(int(r.owed)), T.AMBER if int(r.owed) > 0 else T.DIM,
			"%s MORE AVAILABLE" % T.money(int(r.loan_room))))


func _fill_band() -> void:
	var r := report
	var text := ""
	var colour := T.AMBER
	if r.insolvent:
		text = "INSOLVENT: the company stayed overdrawn past %d days. Ordering is stopped." % int(r.grace_days)
		colour = T.BAD
	elif int(r.cash) < 0:
		text = "OVERDRAWN for %d day(s): %d left to get back over zero before the company is insolvent." % [
				int(r.days_in_debt), maxi(0, int(r.grace_days) - int(r.days_in_debt))]
		colour = T.BAD
	elif int(r.runway) >= 0 and int(r.runway) < RUNWAY_WARN:
		text = "LOW CASH: at today's costs the account runs dry in %d day(s). Close a contract or take a loan." % int(r.runway)
	_band.visible = text != ""
	_band_text.text = text
	_band.add_theme_stylebox_override("panel", T.box(Color(colour, 0.14), colour, 1, fs * 0.35))


func _fill_pnl() -> void:
	_clear(_pnl, 1)
	_pnl.add_child(_row([_cell("", 0, T.DIM), _cell("IN", 7, T.DIM), _cell("OUT", 7, T.DIM), _cell("NET", 7, T.DIM)], HEAD))
	var lines: Array = report.lines
	if lines.is_empty():
		_pnl.add_child(_label("No money moved in this period.", "body", fs, T.DIM))
	var group := ""
	var g_in := 0
	var g_out := 0
	var n := 0
	for i in lines.size() + 1:
		var l: Dictionary = lines[i] if i < lines.size() else {}
		if group != "" and (l.is_empty() or str(l.group) != group):
			_pnl.add_child(_subtotal(group, g_in, g_out))
		if l.is_empty():
			break
		if str(l.group) != group:
			group = str(l.group)
			g_in = 0
			g_out = 0
		g_in += int(l["in"])
		g_out += int(l.out)
		var what := _label("   %s  ×%d" % [str(l.name), int(l.count)], "body", fs, T.TEXT)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.clip_text = true
		var row := _row([what, _money_cell(int(l["in"]), 1), _money_cell(int(l.out), -1),
				_money_cell(int(l["in"]) - int(l.out), 0)], ROW_ALT if n % 2 else ROW)
		row.name = "Line_" + str(l.category)
		_pnl.add_child(row)
		n += 1
	var now: Dictionary = report.now
	var total := _row([_label("NET RESULT", "display_bold", fs, T.TEXT), _money_cell(int(now.income), 1),
			_money_cell(int(now.outgoings), -1), _money_cell(int(now.net), 0, "mono_bold")], HEAD)
	(total.get_child(0).get_child(0) as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.name = "NetResult"
	_pnl.add_child(total)


func _subtotal(group: String, got_in: int, got_out: int) -> PanelContainer:
	var what := _label(str(GROUP_NAMES.get(group, group.to_upper())), "display_bold", fs - 1, T.ORANGE)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := _row([what, _money_cell(got_in, 1, "mono_bold"), _money_cell(got_out, -1, "mono_bold"),
			_money_cell(got_in - got_out, 0, "mono_bold")], CARD)
	row.name = "Group_" + group
	return row


func _fill_cards() -> void:
	_clear(_cards)
	_cards.add_child(_sheet_card())
	_cards.add_child(_costs_card())
	_cards.add_child(_contracts_card())
	_cards.add_child(_loans_card())
	_cards.add_child(_crew_card())
	_cards.add_child(_stock_card())
	var ledger := _ledger_card()
	_cards.add_child(ledger)


func _sheet_card() -> PanelContainer:
	var c := _card("BALANCE SHEET")
	c.name = "Card_sheet"
	var body := c.get_child(0) as VBoxContainer
	var s: Dictionary = report.sheet
	var stock: Dictionary = report.stock
	var on_order: Dictionary = report.on_order
	body.add_child(_section("ASSETS"))
	body.add_child(_pair("Cash at bank", int(s.assets.cash)))
	body.add_child(_pair("Stock on hand (%d lines, market value)" % int(stock.lines), int(s.assets.stock)))
	body.add_child(_pair("Parts paid for, on their way (%d)" % int(on_order.count), int(s.assets.on_order)))
	body.add_child(_section("LIABILITIES"))
	body.add_child(_pair("Loans outstanding", -int(s.liabilities.loans)))
	body.add_child(_pair("Overdraft", -int(s.liabilities.overdraft)))
	body.add_child(_pair("NET WORTH", int(s.worth), true))
	return c


func _costs_card() -> PanelContainer:
	var c := _card("WHAT A DAY COSTS NOW")
	c.name = "Card_costs"
	var body := c.get_child(0) as VBoxContainer
	var b: Dictionary = report.burn
	body.add_child(_pair("Bay rent", -int(b.rent)))
	body.add_child(_pair("Crew wages (%d on shift)" % (report.crew as Array).filter(func(p: Dictionary) -> bool: return int(p.wage) > 0).size(), -int(b.wages)))
	body.add_child(_pair("Loan repayments (a day's share)", -int(b.loans)))
	body.add_child(_pair("EVERY DAY", -int(b.per_day), true))
	body.add_child(_pair("Every %d-day month" % bus.get_rules().days_per_month, -int(b.per_day) * bus.get_rules().days_per_month))
	var now: Dictionary = report.now
	var days := maxi(1, (report.balance as Array).size())
	body.add_child(_pair("Average day this period", roundi(float(now.net) / days)))
	return c


func _contracts_card() -> PanelContainer:
	var c := _card("CONTRACTS ON THE BOOKS")
	c.name = "Card_contracts"
	var body := c.get_child(0) as VBoxContainer
	var list: Array = report.contracts
	if list.is_empty():
		body.add_child(_label("No contracts yet. Their deposits and payments show here.", "body", fs - 1, T.DIM))
		return c
	body.add_child(_row([_cell("CONTRACT", 0, T.DIM), _cell("VALUE", 6, T.DIM), _cell("PAID", 6, T.DIM),
			_cell("PARTS", 6, T.DIM), _cell("MARGIN", 6, T.DIM)], HEAD))
	var n := 0
	for k: Dictionary in list:
		var state := str(k.state).to_upper()
		var sub := "DUE DAY %d" % (int(k.due_day) + 1) if k.state == "open" else state
		if int(k.stages) > 0:
			sub += "  ·  STAGES %d / %d" % [int(k.stages_paid), int(k.stages)]
		if int(k.penalties) > 0:
			sub += "  ·  PENALTIES %s" % T.money(int(k.penalties))
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", -2)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := _label(str(k.id), "body_medium", fs, T.TEXT)
		title.clip_text = true
		names.add_child(title)
		names.add_child(_label(sub, "display_medium", fs - 4, T.GOOD if k.state == "done" else T.DIM))
		var row := _row([names, _cell(T.money(int(k.value)), 6, T.TEXT), _cell(T.money(int(k.received)), 6, T.GOOD),
				_cell(T.money(int(k.parts)), 6, T.BAD), _money_cell(int(k.margin), 0, "mono_bold", 6)], ROW_ALT if n % 2 else ROW)
		row.name = "Contract_" + str(k.id).validate_node_name()
		body.add_child(row)
		n += 1
	return c


func _loans_card() -> PanelContainer:
	var c := _card("LOANS")
	c.name = "Card_loans"
	var body := c.get_child(0) as VBoxContainer
	var loans: Array = report.loans
	if loans.is_empty():
		body.add_child(_label("No loans. Up to %s CR can be borrowed at %s%% a year." % [T.money(int(report.loan_room)),
				str(bus.get_rules().loan_apr_percent)], "body", fs - 1, T.DIM))
		return c
	body.add_child(_row([_cell("LOAN", 0, T.DIM), _cell("MONTHLY", 6, T.DIM), _cell("LEFT", 6, T.DIM), _cell("SETTLE", 6, T.DIM)], HEAD))
	var n := 0
	for l: Dictionary in loans:
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", -2)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_child(_label("%s  ·  %s CR" % [str(l.id), T.money(int(l.principal))], "body_medium", fs, T.TEXT))
		names.add_child(_label("PAID %d OF %d MONTHS AT %s%%" % [int(l.paid_months), int(l.months), str(l.apr)], "display_medium", fs - 4, T.DIM))
		var row := _row([names, _cell(T.money(int(l.monthly)), 6, T.TEXT), _cell(T.money(int(l.balance)), 6, T.AMBER),
				_cell(T.money(int(l.settle)), 6, T.DIM)], ROW_ALT if n % 2 else ROW)
		row.name = "Loan_" + str(l.id)
		body.add_child(row)
		n += 1
	body.add_child(_pair("Still to borrow", int(report.loan_room)))
	return c


func _crew_card() -> PanelContainer:
	var c := _card("CREW PAY")
	c.name = "Card_crew"
	var body := c.get_child(0) as VBoxContainer
	var crew: Array = report.crew
	if crew.is_empty():
		body.add_child(_label("Nobody on shift.", "body", fs - 1, T.DIM))
		return c
	body.add_child(_row([_cell("CREW", 0, T.DIM), _cell("LEVEL", 4, T.DIM), _cell("WAGE", 5, T.DIM),
			_cell("PAYSLIP", 6, T.DIM), _cell("WALLET", 6, T.DIM)], HEAD))
	var n := 0
	for p: Dictionary in crew:
		var who := _label(str(p.name) + ("  (OWNER)" if p.owner else ""), "body_medium", fs, T.TEXT)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.clip_text = true
		var slip: Dictionary = p.last_slip
		var row := _row([who, _cell(str(int(p.level)), 4, T.TEXT), _cell(T.money(int(p.wage)), 5, T.TEXT),
				_cell(T.money(int(slip.get("total", 0))) if not slip.is_empty() else "—", 6, T.DIM),
				_cell(T.money(int(p.wallet)), 6, T.CYAN)], ROW_ALT if n % 2 else ROW)
		row.name = "Crew_" + str(p.name).validate_node_name()
		body.add_child(row)
		n += 1
	return c


func _stock_card() -> PanelContainer:
	var c := _card("STOCK ON HAND")
	c.name = "Card_stock"
	var body := c.get_child(0) as VBoxContainer
	var stock: Dictionary = report.stock
	var top: Array = stock.top
	if top.is_empty():
		body.add_child(_label("The stores are empty.", "body", fs - 1, T.DIM))
		return c
	body.add_child(_row([_cell("MOST VALUABLE LINES", 0, T.DIM), _cell("QTY", 4, T.DIM), _cell("VALUE", 6, T.DIM)], HEAD))
	var n := 0
	for s: Dictionary in top:
		var what := _label(str(s.name), "body", fs, T.TEXT)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.clip_text = true
		body.add_child(_row([what, _cell(str(int(s.qty)), 4, T.TEXT), _cell(T.money(int(s.value)), 6, T.TEXT)], ROW_ALT if n % 2 else ROW))
		n += 1
	body.add_child(_pair("All %d lines" % int(stock.lines), int(stock.value)))
	return c


func _ledger_card() -> PanelContainer:
	var c := _card("LEDGER, NEWEST FIRST")
	c.name = "Card_ledger"
	var body := c.get_child(0) as VBoxContainer
	var recent: Array = report.recent
	if recent.is_empty():
		body.add_child(_label("No entries in this period.", "body", fs - 1, T.DIM))
		return c
	var n := 0
	for e: LedgerEntry in recent.slice(0, RECENT_ROWS):
		var what := "%s%s%s" % [str(BusinessBus.CATEGORY_NAMES.get(e.category, e.category.capitalize())),
				("  " + e.ref) if e.ref != "" else "", ("  ·  " + e.note) if e.note != "" else ""]
		var text := _label(what, "body", fs - 1, T.TEXT)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.clip_text = true
		body.add_child(_row([_cell("D%d" % (e.day + 1), 3, T.DIM), text, _money_cell(e.amount, 0, "mono_bold", 6)], ROW_ALT if n % 2 else ROW))
		n += 1
	if recent.size() > RECENT_ROWS:
		body.add_child(_label("… and %d more in this period" % (recent.size() - RECENT_ROWS), "body", fs - 2, T.DIM))
	return c


## Two columns of cards on a wide wall, one on a narrow one; the figures four or two across.
func _fit_columns() -> void:
	if _cards == null:
		return
	var wide := size.x >= fs * 52
	_cards.columns = 2 if wide else 1
	_figures.columns = 4 if size.x >= fs * 44 else 2
	for c in _cards.get_children():
		(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for c in _figures.get_children():
		(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL


# --- Pieces ---------------------------------------------------------------------------------

func _period_word() -> String:
	match period:
		"TODAY":
			return "DAY"
		"7 D":
			return "WEEK"
		"30 D":
			return "MONTH"
	return "TO DATE"


func _prev_line(prev: int) -> String:
	return "%s THE %s BEFORE" % [T.money(prev), _period_word()] if report.has_prev else ""


func _signed(n: int) -> String:
	return ("+" if n >= 0 else "−") + T.money(absi(n))


func _label(text: String, face: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", T.font(face))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


func _button(text: String, on: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", T.font("display_bold"))
	b.add_theme_font_size_override("font_size", fs - 2)
	b.add_theme_stylebox_override("normal", T.box(Color(0.1, 0.2, 0.3) if on else CARD, T.ORANGE if on else LINE, 1, fs * 0.3))
	b.add_theme_stylebox_override("hover", T.box(Color(0.12, 0.24, 0.34), T.ORANGE, 1, fs * 0.3))
	b.add_theme_stylebox_override("pressed", T.box(Color(0.12, 0.24, 0.34), T.ORANGE, 1, fs * 0.3))
	b.add_theme_color_override("font_color", T.TEXT if on else T.DIM)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _figure(what: String, value: String, colour: Color, sub: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Figure_" + what.validate_node_name().replace(" ", "_")
	p.add_theme_stylebox_override("panel", T.box(CARD, LINE, 1, fs * 0.4))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(_label(what, "display_medium", fs - 3, T.DIM))
	var big := _label(value, "mono_bold", int(fs * 1.6), colour)
	big.name = "Value"
	v.add_child(big)
	var s := _label(sub, "display_medium", fs - 5, Color(T.DIM, 0.8))
	s.clip_text = true
	v.add_child(s)
	p.add_child(v)
	return p


## A titled card; add to its VBoxContainer (child 0). The title is the box's first child.
func _card(title: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(CARD, LINE, 1, fs * 0.4))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	p.add_child(v)
	v.add_child(_label(title, "display_bold", fs, T.ORANGE))
	return p


func _section(text: String) -> Label:
	return _label(text, "display_medium", fs - 3, T.DIM)


## A name and an amount on one line; `strong` for a total.
func _pair(what: String, amount: int, strong := false) -> PanelContainer:
	var l := _label(what, "display_bold" if strong else "body", fs, T.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	return _row([l, _money_cell(amount, 0, "mono_bold" if strong else "mono_medium", 8)], HEAD if strong else ROW)


func _row(cells: Array, bg: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var st := T.box(bg, Color.TRANSPARENT, 0, 0)
	st.content_margin_left = fs * 0.4
	st.content_margin_right = fs * 0.4
	st.content_margin_top = fs * 0.15
	st.content_margin_bottom = fs * 0.15
	panel.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(fs * 0.3))
	panel.add_child(h)
	for c: Control in cells:
		h.add_child(c)
	return panel


## A right-aligned cell `ems` text sizes wide (0 = takes the spare width).
func _cell(text: String, ems: float, colour: Color, face := "mono_medium") -> Label:
	var l := _label(text, face, fs, colour)
	if ems <= 0.0:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
	else:
		l.custom_minimum_size.x = fs * ems * 0.75
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


## An amount: `side` 1 = money in (green, +), -1 = money out (red, −), 0 = signed by value.
func _money_cell(n: int, side: int, face := "mono_medium", ems := 7.0) -> Label:
	if n == 0:
		return _cell("—", ems, T.DIM, face)
	match side:
		1:
			return _cell("+" + T.money(n), ems, T.GOOD, face)
		-1:
			return _cell("−" + T.money(n), ems, T.BAD, face)
	return _cell(_signed(n), ems, T.GOOD if n > 0 else T.BAD, face)


## Frees `box`'s children after the first `keep`.
func _clear(box: Node, keep := 0) -> void:
	for i in range(box.get_child_count() - 1, keep - 1, -1):
		var c := box.get_child(i)
		box.remove_child(c)
		c.queue_free()


## Closing cash each day as a line over the day's money in (up, green) and out (down, red).
class CashChart extends Control:
	var days: Array = []
	var font_size := 13

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := T.font("mono_medium")
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.03, 0.07, 0.11))
		if days.is_empty():
			return
		var pad_l := font_size * 4.5
		var pad_r := font_size * 0.6
		var pad_t := font_size * 1.4
		var pad_b := font_size * 1.6
		var plot := Rect2(pad_l, pad_t, size.x - pad_l - pad_r, size.y - pad_t - pad_b)
		if plot.size.x <= 4.0 or plot.size.y <= 4.0:
			return
		# The balance's range, zero always in it.
		var lo := 0.0
		var hi := 1.0
		var flow := 1.0
		for d: Dictionary in days:
			lo = minf(lo, float(d.close))
			hi = maxf(hi, float(d.close))
			flow = maxf(flow, maxf(float(d["in"]), float(d.out)))
		var y_of := func(v: float) -> float: return plot.end.y - (v - lo) / maxf(1.0, hi - lo) * plot.size.y
		# Gridlines at the top, zero and the bottom.
		for v in [hi, 0.0, lo] if lo < 0.0 else [hi, (hi + lo) * 0.5, 0.0]:
			var y: float = y_of.call(v)
			draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.3, 0.5, 0.7, 0.5 if v == 0.0 else 0.2), 1.0)
			draw_string(font, Vector2(0, y + font_size * 0.35), _short(v), HORIZONTAL_ALIGNMENT_RIGHT, pad_l - 6.0, font_size, T.DIM)
		var w := plot.size.x / days.size()
		var zero: float = y_of.call(0.0)
		var band := minf(plot.size.y * 0.3, maxf(zero - plot.position.y, plot.end.y - zero))
		var pts := PackedVector2Array()
		for i in days.size():
			var d: Dictionary = days[i]
			var x := plot.position.x + (i + 0.5) * w
			var bw := maxf(2.0, w * 0.5)
			var up := band * float(d["in"]) / flow
			var dn := band * float(d.out) / flow
			if up > 0.0:
				draw_rect(Rect2(x - bw * 0.5, zero - up, bw, up), Color(T.GOOD, 0.45))
			if dn > 0.0:
				draw_rect(Rect2(x - bw * 0.5, zero, bw, dn), Color(T.BAD, 0.45))
			pts.append(Vector2(x, y_of.call(float(d.close))))
			if days.size() <= 10 or i % maxi(1, days.size() / 8) == 0 or i == days.size() - 1:
				draw_string(font, Vector2(x - w * 0.5 - font_size, size.y - 4.0), "D%d" % (int(d.day) + 1),
						HORIZONTAL_ALIGNMENT_CENTER, w + font_size * 2.0, font_size, T.DIM)
		if pts.size() == 1:
			pts.insert(0, Vector2(plot.position.x, pts[0].y))
		draw_polyline(pts, T.CYAN, 2.5, true)
		for p in pts:
			draw_circle(p, 3.0, T.CYAN)
		var last: Dictionary = days.back()
		draw_string(font, Vector2(plot.position.x, font_size * 1.0), "CLOSING CASH  %s CR" % T.money(int(last.close)),
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, T.CYAN)
		draw_string(font, Vector2(plot.position.x, font_size * 1.0), "▮ IN  ▮ OUT", HORIZONTAL_ALIGNMENT_RIGHT, plot.size.x, font_size, T.DIM)

	static func _short(v: float) -> String:
		var a := absf(v)
		var s := ""
		if a >= 1000000.0:
			s = "%.1fM" % (a / 1000000.0)
		elif a >= 10000.0:
			s = "%dk" % roundi(a / 1000.0)
		elif a >= 1000.0:
			s = "%.1fk" % (a / 1000.0)
		else:
			s = str(roundi(a))
		return ("−" if v < 0.0 else "") + s
