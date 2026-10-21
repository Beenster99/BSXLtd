extends VBoxContainer
## Settings pages for the company, built with UI's TerminalKit:
##   "company":  who owns it (the owner or host hands it over), bonuses with a note and
##               loans; the owner's controls are greyed for everyone else
##   "payslips": your own payslips, newest first: wage by level, bonuses and their notes

const T := preload("res://modules/ui/api/terminal_kit.gd")
const MAX_SLIPS := 30

var bus: BusinessBus
var page := "company"
var glass := false
## Peer picked for a bonus or the hand-over.
var to_peer := 0
var months := 12

var _message: Label
var _body: VBoxContainer
var _bonus_amount: LineEdit
var _bonus_note: LineEdit
var _loan_amount: LineEdit
var _dirty := false


func _init(p_bus: BusinessBus, p_page := "company", p_glass := false) -> void:
	bus = p_bus
	page = p_page
	glass = p_glass
	add_theme_constant_override("separation", 10)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	add_child(_body)
	_message = T.label("", "body_medium", 15, T.DIM)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)
	if page == "company":
		_build_company_inputs()
	var watch := {"cash_changed": 3, "owner_changed": 1, "loan_taken": 1, "loan_repaid": 3, "payslip_issued": 2, "bonus_awarded": 4}
	for sig: String in watch:
		bus.connect(sig, _mark_dirty.unbind(watch[sig]))
	bus.company_refused.connect(_on_refused)
	refresh()


func _mark_dirty() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		refresh()


## The inputs live across refreshes so typing isn't lost.
func _build_company_inputs() -> void:
	_bonus_amount = _digits("Amount")
	_bonus_note = T.search("A note for the payslip", func(_t: String) -> void: pass, glass)
	_bonus_note.max_length = BusinessBus.NOTE_MAX
	_bonus_note.clear_button_enabled = false
	_bonus_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loan_amount = _digits("Amount")
	_loan_amount.text_changed.connect(func(_t: String) -> void: _refresh_quote())


func _digits(placeholder: String) -> LineEdit:
	var e: LineEdit
	e = T.search(placeholder, func(t: String) -> void:
		var d := ""
		for ch in t:
			if ch >= "0" and ch <= "9":
				d += ch
		if d != t:
			e.text = d
			e.caret_column = d.length(), glass)
	e.clear_button_enabled = false
	e.custom_minimum_size.x = 140
	return e


func refresh() -> void:
	# The kept inputs come out first so they outlive the rows being freed.
	for e in [_bonus_amount, _bonus_note, _loan_amount]:
		if e and e.get_parent():
			e.get_parent().remove_child(e)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	if page == "payslips":
		_payslips()
	else:
		_company()


# --- Company --------------------------------------------------------------------------

func _company() -> void:
	var me := bus.my_name()
	var owner := bus.company_owner()
	var mine := bus.is_owner(me)
	var people := bus.crew_names()
	if not people.has(to_peer):
		to_peer = _first_other(people)

	var figs := HBoxContainer.new()
	figs.add_theme_constant_override("separation", 10)
	figs.add_child(T.figure("Owner", owner if owner != "" else "—", T.ORANGE, glass))
	figs.add_child(T.figure("Company funds", "%s CR" % T.money(bus.get_cash()), T.TEXT, glass))
	figs.add_child(T.figure("Wages today", "%s CR" % T.money(_wage_bill()), T.TEXT, glass))
	_body.add_child(figs)

	# Crew to pick for a bonus or the hand-over.
	var names := PackedStringArray()
	for id: int in people:
		names.append(people[id])
	_body.add_child(_heading("Crew"))
	_body.add_child(T.chips(names, str(people.get(to_peer, "")), func(n: String) -> void:
		for id: int in people:
			if people[id] == n:
				to_peer = id
		refresh(), glass, false))
	var hand := T.button("MAKE OWNER", false, 16, false, glass)
	hand.name = "MakeOwner"
	hand.disabled = not (mine or bus.my_peer() == 1) or str(people.get(to_peer, "")) == owner
	hand.pressed.connect(func() -> void: bus.request_owner(to_peer))
	var crew_row := HBoxContainer.new()
	crew_row.add_child(T.label("Wage %s CR a day at level %d" % [T.money(bus.wage_for(bus.player_level(str(people.get(to_peer, ""))))), bus.player_level(str(people.get(to_peer, "")))], "body", 16, T.DIM))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crew_row.add_child(gap)
	crew_row.add_child(hand)
	_body.add_child(crew_row)

	# A bonus from company funds, with a note.
	_body.add_child(_heading("Bonus"))
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", 6)
	b.add_child(_bonus_amount)
	b.add_child(_bonus_note)
	var pay := T.button("PAY BONUS", true, 16, false, glass)
	pay.name = "PayBonus"
	pay.disabled = not mine or to_peer == 0
	pay.pressed.connect(func() -> void:
		_say("")
		bus.request_bonus(to_peer, int(_bonus_amount.text), _bonus_note.text)
		if _message.text == "":
			_say("Paid %s CR to %s." % [T.money(int(_bonus_amount.text)), people.get(to_peer, "")], true)
			_bonus_amount.text = ""
			_bonus_note.text = "")
	b.add_child(pay)
	_body.add_child(b)

	# Loans.
	_body.add_child(_heading("Loans"))
	var l := HBoxContainer.new()
	l.add_theme_constant_override("separation", 6)
	l.add_child(_loan_amount)
	var minus := T.button("−", false, 16, false, glass)
	minus.pressed.connect(func() -> void: _set_months(months - (12 if months > 12 else 1)))
	l.add_child(minus)
	var ml := T.label("%d MONTHS" % months, "mono_bold", 16, T.TEXT)
	ml.name = "Months"
	ml.custom_minimum_size.x = 104
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_child(ml)
	var plus := T.button("+", false, 16, false, glass)
	plus.pressed.connect(func() -> void: _set_months(months + (12 if months >= 12 else 1)))
	l.add_child(plus)
	var quote := T.label("", "mono_medium", 15, T.DIM)
	quote.name = "Quote"
	quote.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_child(quote)
	var take := T.button("TAKE LOAN", true, 16, false, glass)
	take.name = "TakeLoan"
	take.disabled = not mine
	take.pressed.connect(func() -> void:
		_say("")
		var amount := int(_loan_amount.text)
		bus.request_loan(amount, months)
		if _message.text == "":
			_say("Borrowed %s CR over %d months." % [T.money(amount), months], true)
			_loan_amount.text = "")
	l.add_child(take)
	_body.add_child(l)
	_body.add_child(T.label("The bank will lend up to %s CR more at %s%% a year. Repayments come out every %d days." % [T.money(bus.loan_room()), str(bus.get_rules().loan_apr_percent), bus.get_rules().days_per_month], "body", 15, T.DIM))
	var loans := bus.get_loans()
	if not loans.is_empty():
		_body.add_child(T.columns([["LOAN", 0], ["MONTHS", 90], ["MONTHLY CR", 120], ["OWED CR", 120], ["", 110]]))
		for i in loans.size():
			var loan: Dictionary = loans[i]
			var off := T.button("PAY OFF", false, 15, false, glass)
			off.name = "PayOff_" + str(loan.id)
			off.custom_minimum_size.x = 104
			off.disabled = not mine
			off.tooltip_text = "Pays %s CR now" % T.money(bus.settle_amount(loan.id))
			off.pressed.connect(func() -> void: bus.request_settle(loan.id))
			_body.add_child(T.row([T.cell_text(str(loan.id), "%s CR from day %d" % [T.money(int(loan.principal)), int(loan.taken_day) + 1]),
					T.cell("%d / %d" % [int(loan.paid_months), int(loan.months)], 90),
					T.cell(T.money(int(loan.monthly)), 120, T.TEXT),
					T.cell(T.money(int(loan.balance)), 120, T.ORANGE, "mono_bold"), _centred(off, 110)], i % 2 == 1, glass))
	if not mine:
		_body.add_child(T.label("Only the owner pays bonuses and borrows.", "body", 15, T.DIM))
	_refresh_quote()


func _set_months(n: int) -> void:
	months = clampi(n, 1, bus.get_rules().loan_months_max)
	refresh()


func _refresh_quote() -> void:
	var q := _body.find_child("Quote", true, false) as Label
	if q == null or _loan_amount == null:
		return
	var amount := int(_loan_amount.text)
	if amount <= 0:
		q.text = ""
		return
	var quote := bus.loan_quote(amount, months)
	q.text = "  %s CR A MONTH · %s CR IN ALL" % [T.money(quote.monthly), T.money(quote.total)]


func _wage_bill() -> int:
	var n := 0
	var crew := bus.crew_levels()
	for player: String in crew:
		n += bus.wage_for(int(crew[player]))
	return n


func _first_other(people: Dictionary) -> int:
	for id: int in people:
		if id != bus.my_peer():
			return id
	return people.keys()[0] if not people.is_empty() else 0


# --- Payslips --------------------------------------------------------------------------

func _payslips() -> void:
	var me := bus.my_name()
	var level := bus.player_level(me)
	var figs := HBoxContainer.new()
	figs.add_theme_constant_override("separation", 10)
	figs.add_child(T.figure("Level", str(level), T.TEXT, glass))
	figs.add_child(T.figure("Day rate", "%s CR" % T.money(bus.wage_for(level)), T.ORANGE, glass))
	figs.add_child(T.figure("Wallet", "%s CR" % T.money(bus.get_wallet(me)), T.TEXT, glass))
	_body.add_child(figs)
	var slips := bus.get_payslips(me)
	if slips.is_empty():
		_body.add_child(T.label("No payslips yet: wages are paid at the end of each day.", "body", 16, T.DIM))
		return
	_body.add_child(T.columns([["PAYSLIP", 0], ["LEVEL", 70], ["WAGE CR", 100], ["BONUS CR", 100], ["TOTAL CR", 110]]))
	var list := T.list()
	list.get_parent().custom_minimum_size.y = 260
	_body.add_child(list.get_parent())
	var n := 0
	for i in range(slips.size() - 1, maxi(-1, slips.size() - 1 - MAX_SLIPS), -1):
		var s: Dictionary = slips[i]
		var notes := PackedStringArray()
		var bonus := 0
		for b: Dictionary in s.bonuses:
			bonus += int(b.amount)
			notes.append("%s from %s" % [("“%s”" % b.note) if str(b.note) != "" else "Bonus", b.by])
		var slip := VBoxContainer.new()
		slip.add_child(T.row([T.cell_text("Day %d" % (int(s.day) + 1), "BSX LTD · %s" % me),
				T.cell(str(int(s.level)), 70), T.cell(T.money(int(s.wage)), 100),
				T.cell(T.money(bonus) if bonus > 0 else "—", 100, T.GOOD if bonus > 0 else T.DIM),
				T.cell(T.money(int(s.total)), 110, T.ORANGE, "mono_bold")], n % 2 == 1, glass))
		for note in notes:
			var l := T.label("      " + note, "body", 15, T.TEXT)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			slip.add_child(l)
		list.add_child(slip)
		n += 1


# --- Bits ------------------------------------------------------------------------------

func _heading(text: String) -> Label:
	return T.label(text.to_upper(), "display_medium", 15, T.DIM)


func _centred(c: Control, w: float) -> CenterContainer:
	var box := CenterContainer.new()
	box.custom_minimum_size.x = w
	box.add_child(c)
	return box


func _say(text: String, good := false) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", T.GOOD if good else T.BAD)


func _on_refused(reason: String) -> void:
	_say(reason.left(1).to_upper() + reason.substr(1) + ".")
	Sfx.play("error")


func _notification(what: int) -> void:
	# Inputs held out of the tree between refreshes are freed with the panel.
	if what == NOTIFICATION_PREDELETE:
		for e in [_bonus_amount, _bonus_note, _loan_amount]:
			if is_instance_valid(e) and e.get_parent() == null:
				e.free()
