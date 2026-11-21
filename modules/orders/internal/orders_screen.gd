extends PanelContainer
## PARTS ORDERS (master plan 7.1 to 7.3): on any wall of the design room and on the wrist. A
## build's parts list, line by line, with every vendor's quote for it (and a second-hand one
## for components): click a quote to take the rest of the line from that vendor, or HALF to take
## half of it there and split the rest elsewhere. The calculator above sums the three plans the
## market works out (cheapest, most reliable, median) against your own mix; USE takes a plan.
## PLACE ORDER buys what is split (EXPRESS: today, dearer). Below, the orders on their way and
## what came in.

const T := preload("res://modules/ui/api/terminal_kit.gd")

const BG := Color(0.02, 0.05, 0.09)
const CARD := Color(0.05, 0.1, 0.16)
const STAGE_COLOURS := {"frame": Color("8fa3b3"), "plates": Color("6fc8e8"), "fittings": Color("e8c25a"),
		"wiring": Color("ff9a4d"), "pipes": Color("7fd47a")}

var bus: Object
var fs := 15
var cid := ""
var express := false
var _body: VBoxContainer
var _status: Label
var _queued := false
var _clock := 0.0


func setup(orders_bus: Object, density: float) -> void:
	bus = orders_bus
	fs = maxi(12, int(density * 0.1))
	name = "OrdersScreen"
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
	var build := Modules.bus("build")
	if build:
		build.connect("build_changed", _queue)
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


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= 5.0 and is_visible_in_tree():
		_clock = 0.0
		refresh()


func _builds() -> Array:
	var build := Modules.bus("build")
	return (build.get("builds") as Dictionary).keys() if build else []


func refresh() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var ids := _builds()
	var build := Modules.bus("build")
	if not ids.has(cid):
		cid = str(build.get("current")) if build and ids.has(str(build.get("current"))) else (str(ids[0]) if not ids.is_empty() else "")
	if cid == "":
		_status.text = "PARTS ORDERS"
		_body.add_child(_label("No ship on the go. Sign a ship contract: her parts list comes here to order.", "body_medium", fs, T.DIM))
		return
	var lines: Array = bus.call("lines", cid)
	var b: Dictionary = (build.get("builds") as Dictionary).get(cid, {})
	var ordered := 0
	var arrived := 0
	for l: Dictionary in lines:
		if float(l.ordered) >= float(l.need) - 0.001:
			ordered += 1
		if float(l.arrived) >= float(l.need) - 0.001:
			arrived += 1
	_status.text = "PARTS ORDERS · %s · %d LINES · %d ORDERED · %d ARRIVED%s" % [str(b.get("design_name", cid)).to_upper(),
			lines.size(), ordered, arrived, " · WAITS FOR ITS PARTS" if bool(bus.call("gated", cid)) else ""]
	_head(ids)
	_calculator()
	_section("PARTS LIST")
	for l: Dictionary in lines:
		_line_row(l)
	_orders()


func _head(ids: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(fs * 0.5))
	var b := Modules.bus("build")
	var title := _label("%s  ·  berth %s" % [str((b.get("builds")[cid] as Dictionary).get("design_name", cid)),
			str(b.call("berth_of", cid)) if str(b.call("berth_of", cid)) != "" else "waiting"], "display_bold", fs + 4, T.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	if ids.size() > 1:
		for d: int in [-1, 1]:
			var btn := T.button("◀" if d < 0 else "▶", false, fs)
			btn.pressed.connect(func() -> void:
				cid = str(ids[(ids.find(cid) + d + ids.size()) % ids.size()])
				refresh())
			row.add_child(btn)
	_body.add_child(row)


func _calculator() -> void:
	_section("BILL OF MATERIALS CALCULATOR")
	var sums: Dictionary = bus.call("plan_sums", cid)
	if sums.is_empty():
		_body.add_child(_label("Every line is ordered: each line below says the day it is due.", "body_medium", fs - 1, T.GOOD))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(fs * 0.5))
	for p: String in ["cheapest", "reliable", "median", "mine"]:
		var s: Dictionary = sums.get(p, {})
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", T.box(CARD, Color.TRANSPARENT, 0, fs * 0.4))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		card.add_child(v)
		v.add_child(_label("YOUR MIX" if p == "mine" else str(SupplyOptimiser.PLAN_NAMES.get(p, p)), "mono_medium", fs - 3, T.DIM))
		var total := float(s.get("total", 0.0)) * (OrderBook.EXPRESS_FACTOR if express and p == "mine" else 1.0)
		v.add_child(_label("CR %s" % T.money(roundi(total)), "mono_bold", fs + 2, T.ORANGE if p == "mine" else T.TEXT))
		v.add_child(_label("%s · %d%% on time" % ["today" if express and p == "mine" else "%d days" % int(s.get("lead", 0)),
				roundi(float(s.get("on_time", 0.0)) * 100.0)], "mono_medium", fs - 3, T.DIM))
		if p != "mine":
			var use := T.button("USE", false, fs - 3)
			use.pressed.connect(func() -> void: bus.call("use_plan", cid, p))
			v.add_child(use)
		else:
			v.add_child(_label("%d lines split" % int(s.get("lines", 0)), "mono_medium", fs - 3, T.DIM))
		row.add_child(card)
	_body.add_child(row)
	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", int(fs * 0.5))
	var ex := T.button("EXPRESS: TODAY, +%d%%" % roundi((OrderBook.EXPRESS_FACTOR - 1.0) * 100.0), false, fs - 2, express)
	ex.pressed.connect(func() -> void:
		express = not express
		refresh())
	act.add_child(ex)
	var clear := T.button("CLEAR MIX", false, fs - 2)
	clear.pressed.connect(func() -> void: bus.call("clear_splits", cid))
	act.add_child(clear)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act.add_child(spacer)
	var problem := str(bus.call("place_problem", cid, express))
	var place := T.button("PLACE ORDER", true, fs)
	place.disabled = problem != ""
	place.tooltip_text = problem if problem != "" else "Order your mix: each supplier gets its own order, paid now."
	place.pressed.connect(func() -> void: bus.call("place", cid, express))
	act.add_child(place)
	var cheap_problem := str(bus.call("cheapest_problem", cid, express))
	var quick := T.button("ORDER CHEAPEST", false, fs - 2)
	quick.disabled = cheap_problem != ""
	quick.tooltip_text = cheap_problem if cheap_problem != "" else "Order every line still to order from the cheapest suppliers, now."
	quick.pressed.connect(func() -> void: bus.call("order_cheapest", cid, express))
	act.add_child(quick)
	var stage := str(bus.call("next_stage", cid))
	if stage != "":
		var stage_cost := int(bus.call("stage_cheapest", cid, stage)) * (OrderBook.EXPRESS_FACTOR if express else 1.0)
		var sb := T.button("ORDER NEXT STAGE: %s, CR %s" % [stage.to_upper(), T.money(roundi(stage_cost))], true, fs - 2)
		sb.tooltip_text = "Order just the %s stage's parts from the cheapest suppliers, now. The berth can start that stage when they are in." % stage
		sb.disabled = int(bus.call("cash")) < roundi(stage_cost)
		sb.pressed.connect(func() -> void: bus.call("order_stage_cheapest", cid, stage, express))
		act.add_child(sb)
	_body.add_child(act)
	# What PLACE ORDER needs, or what the last order came to.
	var note := problem if problem != "" else cheap_problem
	if note != "":
		var nl := _label(note, "body_medium", fs - 2, T.AMBER)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(nl)
	var lp: Dictionary = (bus.get("last_placed") as Dictionary).get(cid, {})
	if not lp.is_empty():
		var due := "arriving today" if int(lp.days) == 0 else "arriving in about %d days" % int(lp.days)
		_body.add_child(_label("Last order placed: %d supplier order%s, CR %s, %s. See ORDERS below." % [int(lp.orders),
				"" if int(lp.orders) == 1 else "s", T.money(int(lp.total)), due], "body_medium", fs - 2, T.GOOD))


func _line_row(l: Dictionary) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", T.box(CARD, Color.TRANSPARENT, 0, fs * 0.35))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(fs * 0.2))
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(fs * 0.5))
	var chip := ColorRect.new()
	chip.color = STAGE_COLOURS.get(str(l.stage), T.DIM)
	chip.custom_minimum_size = Vector2(fs * 0.4, fs * 1.2)
	top.add_child(chip)
	var name := _label(str(l.name), "body_medium", fs, T.TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	top.add_child(name)
	var unit := str(l.unit)
	var need := float(l.need)
	var st := "%s %s" % [_qty(need), unit if unit != "x" else ""]
	var colour := T.GOOD if float(l.arrived) >= need - 0.001 else (T.AMBER if float(l.ordered) >= need - 0.001 else T.DIM)
	var status := "%s · ordered %s · arrived %s" % [st.strip_edges(), _qty(float(l.ordered)), _qty(float(l.arrived))]
	if float(l.arrived) >= need - 0.001:
		status += " · all in"
	else:
		var due := int(bus.call("line_due", cid, str(l.key)))
		if due >= 0:
			status += " · due day %d (%s)" % [due / 1440, str(bus.call("when", due))]
		elif float(l.ordered) >= need - 0.001:
			status += " · in the refurb works"
		else:
			status += " · not ordered"
	top.add_child(_label(status, "mono_medium", fs - 2, colour))
	v.add_child(top)
	var left := need - float(l.ordered)
	if left <= 0.001:
		_body.add_child(card)
		return
	# Parts the yard holds from trading cover the line at no new cost.
	var can := int(bus.call("stock_can_cover", cid, str(l.key)))
	if can > 0:
		var use := T.button("USE %d FROM STOCK (no new cost)" % can, true, fs - 3)
		use.tooltip_text = "Take %d of the parts the yard holds (bought on PARTS TRADING) for this build: in at once, nothing more to pay." % can
		var key := str(l.key)
		use.pressed.connect(func() -> void: bus.call("use_held", cid, key, can))
		use.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(use)
	# The split so far.
	var sp: Array = (bus.get("splits") as Dictionary).get(cid, {}).get(str(l.key), [])
	if not sp.is_empty():
		var bits: Array[String] = []
		for e: Dictionary in sp:
			bits.append("%s %s" % [str(e.vendor).capitalize(), _qty(float(e.qty))])
		v.add_child(_label("Split: " + "  ·  ".join(bits), "mono_medium", fs - 3, T.ORANGE))
	var quotes := HFlowContainer.new()
	quotes.add_theme_constant_override("h_separation", int(fs * 0.3))
	quotes.add_theme_constant_override("v_separation", int(fs * 0.3))
	var qs: Array = bus.call("quotes", cid, l)
	for i in mini(qs.size(), 5):
		var q: Dictionary = qs[i]
		var btn := T.button("%s  CR %s  %dd  %d%%" % [str(q.name), T.money(roundi(float(q.unit))), int(q.lead),
				roundi(float(q.on_time) * 100.0)], i == 0 and sp.is_empty(), fs - 4)
		var vendor := str(q.vendor)
		btn.tooltip_text = "Take the rest of the line from %s" % str(q.name)
		btn.pressed.connect(func() -> void: bus.call("set_split", cid, str(l.key), vendor, left))
		quotes.add_child(btn)
		var half := T.button("½", false, fs - 4)
		half.tooltip_text = "Take half the line from %s" % str(q.name)
		half.pressed.connect(func() -> void: bus.call("set_split", cid, str(l.key), vendor, ceilf(need * 0.5)))
		quotes.add_child(half)
	v.add_child(quotes)
	_body.add_child(card)


func _orders() -> void:
	var mine: Array = (bus.get("orders") as Array).filter(func(o: Dictionary) -> bool: return str(o.cid) == cid)
	if mine.is_empty():
		return
	_section("ORDERS")
	for i in range(mine.size() - 1, -1, -1):
		var o: Dictionary = mine[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(fs * 0.6))
		row.add_child(_label("#%d" % int(o.id), "mono_bold", fs - 1, T.DIM))
		var who := _label(str(o.get("name", o.vendor)), "body_medium", fs - 1, T.TEXT)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(who)
		row.add_child(_label("%d lines · CR %s" % [(o.lines as Array).size(), T.money(int(o.total))], "mono_medium", fs - 2, T.DIM))
		var state := ""
		var colour := T.DIM
		if bool(o.arrived):
			var refurbing := 0
			for l: Dictionary in o.lines:
				refurbing += int(l.get("refurbing", 0))
			state = "in the refurb works (%d)" % refurbing if refurbing > 0 else "in the stores"
			colour = T.AMBER if refurbing > 0 else T.GOOD
		else:
			var due := int(o.due) + int(o.late) * 1440
			state = ("express, " if bool(o.get("express", false)) else "") + "due " + str(bus.call("when", due))
			if int(o.late) > 0 and int(o.due) <= int(bus.call("now_minute")):
				state += " (late)"
				colour = T.BAD
		row.add_child(_label(state, "mono_medium", fs - 2, colour))
		_body.add_child(row)


func _section(text: String) -> void:
	_body.add_child(_label(text, "mono_bold", fs - 2, T.ORANGE))


func _qty(q: float) -> String:
	return str(roundi(q)) if absf(q - roundf(q)) < 0.05 or q >= 10.0 else "%.1f" % q


func _label(text: String, face: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", T.font(face))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l
