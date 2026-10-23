extends Control
## What the hall TVs show when nobody is using them: the yard terminal's channels as a
## broadcast in big type, readable across a hall. ORDERS shows today's best buys, GOODS IN
## what is on its way, ACCOUNTS the money. Channels change on their own; a bar along the
## bottom shows when. The full terminal (terminal_screen.gd) opens when a player walks up.

const Look := preload("res://modules/business/internal/ui/terminal_look.gd")
const CHANNELS: PackedStringArray = ["orders", "goods", "accounts"]
const TITLES := {"orders": "BEST BUYS TODAY", "goods": "GOODS IN", "accounts": "ACCOUNTS"}
const TABS := {"orders": "BUY/SELL", "goods": "GOODS IN", "accounts": "ACCOUNTS"}
## How long each channel stays up (seconds).
const CYCLE_SECONDS := 9.0
const BUYS := 6
const ARRIVALS := 5
const LEDGER_LINES := 5

var bus: BusinessBus
var channel := "orders"

var _cycle := 0.0
var _dirty := true
var _clock: Label
var _cash: Label
var _title: Label
var _body: MarginContainer
var _tabs: HBoxContainer
var _progress: ColorRect


func setup(p_bus: BusinessBus, first := "orders") -> void:
	bus = p_bus
	channel = first
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	var watch := {"market_changed": 0, "cash_changed": 3, "order_placed": 1, "delivery_arrived": 2,
			"order_delayed": 1, "reputation_changed": 3, "day_closed": 1}
	for sig: String in watch:
		bus.connect(sig, _mark_dirty.unbind(watch[sig]) if watch[sig] > 0 else _mark_dirty)
	bus.clock_changed.connect(func(_m: int) -> void: _refresh_header())
	refresh()


func show_channel(id: String) -> void:
	channel = id
	_cycle = 0.0
	refresh()


func _mark_dirty() -> void:
	_dirty = true


func _process(delta: float) -> void:
	if bus == null:
		return
	_cycle += delta
	if _cycle >= CYCLE_SECONDS:
		_cycle = 0.0
		channel = CHANNELS[(CHANNELS.find(channel) + 1) % CHANNELS.size()]
		_dirty = true
	if _progress:
		_progress.anchor_right = _cycle / CYCLE_SECONDS
	if _dirty:
		_dirty = false
		refresh()


func refresh() -> void:
	_refresh_header()
	_title.text = TITLES[channel]
	for i in _tabs.get_child_count():
		var tab := _tabs.get_child(i) as Label
		var on := CHANNELS[i] == channel
		tab.add_theme_color_override("font_color", Look.ORANGE if on else Look.DIM)
		tab.text = ("■ " if on else "□ ") + TABS[CHANNELS[i]]
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


# --- Frame ---------------------------------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Look.KIOSK.darkened(0.25)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 96
	header.add_theme_constant_override("separation", 0)
	col.add_child(header)
	var badge := PanelContainer.new()
	var badge_st := Look.box(Look.ORANGE)
	badge_st.content_margin_left = 26
	badge_st.content_margin_right = 26
	badge.add_theme_stylebox_override("panel", badge_st)
	var bsx := Look.label("BSX", "display_bold", 58, Look.BLACK)
	bsx.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(bsx)
	header.add_child(badge)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 26)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = Look.label("", "display_bold", 54, Look.TEXT)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pad.add_child(_title)
	header.add_child(pad)
	var readouts := VBoxContainer.new()
	readouts.alignment = BoxContainer.ALIGNMENT_CENTER
	readouts.add_theme_constant_override("separation", -4)
	var rpad := MarginContainer.new()
	rpad.add_theme_constant_override("margin_right", 28)
	rpad.add_child(readouts)
	header.add_child(rpad)
	_clock = Look.label("", "mono_medium", 26, Look.DIM)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cash = Look.label("", "mono_bold", 40, Look.ORANGE)
	_cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readouts.add_child(_clock)
	readouts.add_child(_cash)
	col.add_child(Look.HazardRule.new(12.0))

	_body = MarginContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		_body.add_theme_constant_override("margin_" + side, 34)
	_body.add_theme_constant_override("margin_top", 22)
	_body.add_theme_constant_override("margin_bottom", 14)
	col.add_child(_body)

	# The strip along the bottom: the channels, when the next comes up, how to use it.
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", Look.box(Look.EDGE, Color.TRANSPARENT, 0, 0))
	var strip_col := VBoxContainer.new()
	strip_col.add_theme_constant_override("separation", 0)
	strip.add_child(strip_col)
	var bar := Control.new()
	bar.custom_minimum_size.y = 5
	_progress = ColorRect.new()
	_progress.color = Look.ORANGE
	_progress.anchor_bottom = 1.0
	bar.add_child(_progress)
	strip_col.add_child(bar)
	var row := HBoxContainer.new()
	var row_pad := MarginContainer.new()
	for side in ["left", "right"]:
		row_pad.add_theme_constant_override("margin_" + side, 30)
	for side in ["top", "bottom"]:
		row_pad.add_theme_constant_override("margin_" + side, 10)
	row_pad.add_child(row)
	strip_col.add_child(row_pad)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 34)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in CHANNELS:
		_tabs.add_child(Look.label(TABS[id], "display_bold", 26, Look.DIM))
	row.add_child(_tabs)
	row.add_child(Look.label("WALK UP AND PRESS  %s  TO ORDER" % Keys.prompt(Keys.INTERACT), "display_bold", 26, Look.TEXT))
	col.add_child(strip)


func _refresh_header() -> void:
	if bus == null or _clock == null:
		return
	_clock.text = bus.get_clock_text()
	_cash.text = "CR %s" % Look.money(bus.get_cash())
	_cash.add_theme_color_override("font_color", Look.BAD if bus.get_cash() < 0 else Look.ORANGE)


# --- Channels ------------------------------------------------------------------------------

## Today's best buys: catalogue parts furthest under their Void Salvage value.
func best_buys() -> Array[MarketListing]:
	var cat := bus.get_catalogue()
	var out: Array[MarketListing] = []
	for l in bus.get_listings():
		if l.available > 0 and cat.has_part(l.part) and cat.value_of(l.part) > 0:
			out.append(l)
	out.sort_custom(func(a: MarketListing, b: MarketListing) -> bool:
		return a.unit_price / cat.value_of(a.part) < b.unit_price / cat.value_of(b.part))
	return out.slice(0, BUYS)


func _orders() -> Control:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	var buys := best_buys()
	if buys.is_empty():
		list.add_child(_big_note("The market is closed.", "New listings come in at midnight."))
	var cat := bus.get_catalogue()
	for l in buys:
		var row := _plate_row()
		var name := Look.label(bus.part_name(l.part), "display_bold", 32, Look.TEXT)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		row.add_child(name)
		row.add_child(Look.condition_tag(l.condition, 22))
		var s := bus.supplier(l.supplier_id)
		row.add_child(_cell(s.display_name if s else l.supplier_id, 250, Look.DIM, "display_medium", 22))
		var off := roundi(100.0 - 100.0 * l.unit_price / cat.value_of(l.part))
		row.add_child(_cell("-%d%%" % off if off > 0 else "", 90, Look.GOOD, "mono_bold", 26))
		row.add_child(_cell("CR " + Look.money(l.unit_price), 190, Look.ORANGE, "mono_bold", 32))
		list.add_child(row.get_parent())
	return list


func _goods() -> Control:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	var open := bus.get_orders(PartsOrder.State.PLACED)
	if open.is_empty():
		list.add_child(_big_note("Nothing on order.", "New games start with an empty store: order parts at any screen."))
		return list
	list.add_child(Look.label("ARRIVING IN THE DELIVERIES HALL", "display_medium", 24, Look.DIM))
	for o: PartsOrder in open.slice(0, ARRIVALS):
		var row := _plate_row()
		var names := PackedStringArray()
		for line in o.lines:
			names.append("%d× %s" % [line.qty, bus.part_name(line.part)])
		var what := Look.label(", ".join(names), "display_bold", 30, Look.TEXT)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.clip_text = true
		row.add_child(what)
		var m := o.eta_minute % 1440
		row.add_child(_cell(("LATE  " if o.delayed else "") + "DAY %d  %02d:%02d" % [o.eta_day + 1, m / 60, m % 60], 300,
				Look.BAD if o.delayed else Look.ORANGE, "mono_bold", 30))
		list.add_child(row.get_parent())
	if open.size() > ARRIVALS:
		list.add_child(Look.label("+ %d more on order" % (open.size() - ARRIVALS), "display_medium", 24, Look.DIM))
	return list


func _accounts() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.custom_minimum_size.x = 470
	row.add_child(left)
	left.add_child(_figure("CASH", "CR " + Look.money(bus.get_cash()), Look.BAD if bus.get_cash() < 0 else Look.ORANGE, 56))
	left.add_child(_figure("REPUTATION", "%d / 100" % roundi(bus.get_reputation()), Look.TEXT, 40))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.value = bus.get_reputation()
	bar.custom_minimum_size.y = 18
	bar.add_theme_stylebox_override("background", Look.box(Look.EDGE))
	bar.add_theme_stylebox_override("fill", Look.box(Look.ORANGE))
	left.add_child(bar)
	left.add_child(_figure("BAY RENT", "CR %s / DAY" % Look.money(bus.get_rules().bay_rent_per_day), Look.TEXT, 34))

	var ledger := VBoxContainer.new()
	ledger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ledger.add_theme_constant_override("separation", 10)
	ledger.add_child(Look.label("LATEST", "display_medium", 24, Look.DIM))
	var entries := bus.get_ledger()
	if entries.is_empty():
		ledger.add_child(Look.label("No entries yet.", "display_medium", 30, Look.DIM))
	if bus.is_insolvent():
		ledger.add_child(Look.label("INSOLVENT: ORDERING STOPPED", "display_bold", 34, Look.BAD))
	for i in range(entries.size() - 1, maxi(-1, entries.size() - 1 - LEDGER_LINES), -1):
		var e := entries[i]
		var h := HBoxContainer.new()
		var what := Look.label("D%d  %s" % [e.day + 1, e.category.to_upper()], "display_bold", 28, Look.TEXT)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(what)
		h.add_child(_cell(("+" if e.amount > 0 else "") + Look.money(e.amount), 200, Look.GOOD if e.amount > 0 else Look.BAD, "mono_bold", 30))
		ledger.add_child(h)
	row.add_child(ledger)
	return row


# --- Pieces --------------------------------------------------------------------------------

## A steel plate holding one row; add to the returned row, then add its parent to a list.
func _plate_row() -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.plate(12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	return row


func _cell(text: String, width: float, color: Color, face: String, size: int) -> Label:
	var l := Look.label(text, face, size, color)
	l.custom_minimum_size.x = width
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	return l


func _figure(what: String, value: String, colour: Color, size: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.plate(16))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	panel.add_child(col)
	col.add_child(Look.label(what, "display_medium", 24, Look.DIM))
	col.add_child(Look.label(value, "mono_bold", size, colour))
	return panel


func _big_note(head: String, sub: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(Look.label(head, "display_bold", 52, Look.TEXT))
	var s := Look.label(sub, "display_medium", 30, Look.DIM)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(s)
	return col
