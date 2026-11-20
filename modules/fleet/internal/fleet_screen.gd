extends PanelContainer
## The TARTANCO FLEET screen (beenster, 19 Nov): every TartanCo bot in the yard at a glance
## (its trade, what it's doing, its condition and charge, where it is, its upgrades and group),
## one bot in detail, and the fleet's orders: groups of bots with a priority and a task list
## taken from the open design's build plan. On the design room's walls and the F1 wrist screen.
##
## Click a bot's row for its detail; ORDERS shows the groups. The orders are saved and shared
## with the crew; the bots follow them once auto-building arrives (master plan Wave 6).

const T := preload("res://modules/ui/api/terminal_kit.gd")

## Seconds between refreshes of the live figures.
const REFRESH := 0.5
const STATE_COLOURS := {"working": T.GOOD, "active": T.GOOD, "idle": T.STEEL, "to_dock": T.CYAN,
		"charging": T.CYAN, "faulted": T.BAD, "servicing": T.AMBER}
const BAND_COLOURS := {"good": T.GOOD, "fair": T.AMBER, "poor": T.BAD}
const TABS: PackedStringArray = ["bot", "orders"]

var bus: FleetBus
var px_per_m := 150.0
var glass := false
## The base text size, px.
var fs := 15
## The bot shown in detail (its serial), the group shown under ORDERS, and the side tab.
var selected := ""
var group := ""
var tab := "bot"

var _figures: HBoxContainer
var _table: VBoxContainer
var _side: VBoxContainer
var _tabs: HBoxContainer
var _clock := 0.0
var _table_key := ""
var _side_key := ""
var _rows: Array[Dictionary] = []
## The group editor (beenster, 20 Nov: name a group, add specific bots, then save it): open
## while editing, with its draft {group ("" new), name, bots: {serial: true}}. While it's open
## the side isn't rebuilt under the player's typing.
var editing := false
var draft: Dictionary = {}
var _pick_newest := false
var _rebuild_editor := false


func setup(fleet_bus: FleetBus, density: float, on_glass := false) -> void:
	bus = fleet_bus
	px_per_m = density
	glass = on_glass
	fs = maxi(12, int(px_per_m * 0.1))
	name = "FleetScreen"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", T.box(T.tone(T.KIOSK, glass, T.GLASS_KIOSK), Color.TRANSPARENT, 0, fs * 0.5))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(fs * 0.45))
	add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(fs * 0.6))
	col.add_child(head)
	var title := VBoxContainer.new()
	title.add_theme_constant_override("separation", -2)
	title.add_child(_label("TARTANCO FLEET", "display_bold", int(fs * 1.6), T.ORANGE))
	title.add_child(_label("WORKER ANDROIDS ON CONTRACT TO BSX LTD", "display_medium", fs - 3, T.DIM))
	head.add_child(title)
	_figures = HBoxContainer.new()
	_figures.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_figures.alignment = BoxContainer.ALIGNMENT_END
	_figures.add_theme_constant_override("separation", int(fs * 0.4))
	head.add_child(_figures)
	var rule := T.HazardRule.new()
	rule.custom_minimum_size.y = maxi(4, int(fs * 0.35))
	col.add_child(rule)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(fs * 0.6))
	col.add_child(body)
	# The fleet table.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.55
	left.add_theme_constant_override("separation", 2)
	body.add_child(left)
	left.add_child(_head_row())
	_table = T.list()
	_table.name = "Bots"
	_table.add_theme_constant_override("separation", 2)
	left.add_child(_table.get_parent())
	# The side: one bot in detail, or the orders.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", int(fs * 0.3))
	body.add_child(right)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	right.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_side = VBoxContainer.new()
	_side.name = "Side"
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.add_theme_constant_override("separation", int(fs * 0.35))
	scroll.add_child(_side)
	bus.orders_changed.connect(_on_orders_changed)
	refresh()


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= REFRESH:
		_clock = 0.0
		refresh()


func _on_orders_changed() -> void:
	if _pick_newest and not bus.orders.groups.is_empty():
		_pick_newest = false
		group = str(bus.orders.groups[bus.orders.groups.size() - 1].id)
	if group != "" and bus.orders.group(group).is_empty():
		group = ""
	if editing and str(draft.get("group", "")) != "" and bus.orders.group(str(draft.group)).is_empty():
		editing = false   # someone disbanded the group being edited
	refresh(true)


## Reads the fleet again and rebuilds what changed (`force`: everything).
func refresh(force := false) -> void:
	if bus == null:
		return
	_rows = bus.rows()
	if selected == "" or not _rows.any(func(r: Dictionary) -> bool: return r.serial == selected):
		selected = str(_rows[0].serial) if not _rows.is_empty() else ""
	if group == "" and not bus.orders.groups.is_empty():
		group = str(bus.orders.groups[0].id)
	var tkey := _key(_rows) + "|" + selected
	if force or tkey != _table_key:
		_table_key = tkey
		_fill_figures()
		_fill_table()
	var skey := "%s|%s|%s|%s" % [tab, selected, group, JSON.stringify(bus.orders.to_dict())]
	if tab == "bot":
		skey += _key(_rows.filter(func(r: Dictionary) -> bool: return r.serial == selected))
	if editing and tab == "orders" and not _rebuild_editor:
		return
	_rebuild_editor = false
	if force or skey != _side_key:
		_side_key = skey
		_fill_tabs()
		if tab == "bot":
			_fill_bot()
		else:
			_fill_orders()


## What the screen shows of these rows, to rebuild only when it changes.
func _key(rows: Array) -> String:
	var parts := PackedStringArray()
	for r: Dictionary in rows:
		parts.append("%s %s %s %d %d %s %s %s" % [r.serial, r.state, r.job, roundi(float(r.condition) * 100),
				roundi(float(r.charge) * 100), r.location, r.group, ",".join(PackedStringArray(r.errors))])
	return ";".join(parts)


func select(serial: String) -> void:
	selected = serial
	tab = "bot"
	refresh(true)


func show_tab(which: String) -> void:
	tab = which
	_rebuild_editor = true
	refresh(true)


func show_group(id: String) -> void:
	group = id
	tab = "orders"
	editing = false
	refresh(true)


## Opens the group editor on a group ("" a new one): its name and its bots, saved together.
func edit_group(id: String) -> void:
	var g := bus.orders.group(id)
	var bots := {}
	for serial: String in (g.get("bots", []) as Array):
		bots[serial] = true
	draft = {"group": id, "name": str(g.name) if not g.is_empty() else _next_name(), "bots": bots}
	editing = true
	tab = "orders"
	_rebuild_editor = true
	refresh(true)


## SAVE GROUP: the draft's name and bots as one order.
func save_group() -> void:
	if not editing:
		return
	var bots: Array = []
	for r in _rows:
		if (draft.bots as Dictionary).has(str(r.serial)):
			bots.append(str(r.serial))
	# Bots listed but not on site now (the yard closed) stay listed.
	for serial: String in (draft.bots as Dictionary):
		if not bots.has(serial):
			bots.append(serial)
	editing = false
	_pick_newest = str(draft.group) == ""
	if not _pick_newest:
		group = str(draft.group)
	bus.command({"op": "group_save", "group": str(draft.group), "name": str(draft.name), "bots": bots})
	refresh(true)


func cancel_edit() -> void:
	editing = false
	refresh(true)


# --- The header figures ----------------------------------------------------------------------

func _fill_figures() -> void:
	_clear(_figures)
	var s := bus.summary(_rows)
	_figures.add_child(_figure("BOTS", str(s.bots), T.TEXT))
	_figures.add_child(_figure("WORKING", str(s.working), T.GOOD))
	_figures.add_child(_figure("CHARGING", str(s.charging), T.CYAN))
	_figures.add_child(_figure("FAULTS", str(s.faulted), T.BAD if int(s.faulted) > 0 else T.DIM))
	_figures.add_child(_figure("CONDITION", "%d%%" % roundi(float(s.condition) * 100),
			BAND_COLOURS[FleetBus.band(float(s.condition))] if int(s.bots) > 0 else T.DIM))
	_figures.add_child(_figure("CHARGE", "%d%%" % roundi(float(s.charge) * 100), T.CYAN if int(s.bots) > 0 else T.DIM))


func _figure(what: String, value: String, colour: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(T.tone(T.PLATE, glass), T.tone(T.EDGE, glass, 0.8), 1, fs * 0.35))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	v.add_child(_label(what, "display_medium", fs - 4, T.DIM))
	v.add_child(_label(value, "mono_bold", int(fs * 1.35), colour))
	p.add_child(v)
	return p


# --- The fleet table -------------------------------------------------------------------------

## Column widths, in base text sizes.
func _w(n: float) -> int:
	return int(fs * n)


func _head_row() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(T.tone(T.EDGE, glass), Color.TRANSPARENT, 0, fs * 0.25))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(fs * 0.4))
	p.add_child(h)
	for spec: Array in [["", 0.7], ["BOT", 6.6], ["STATUS", 7.2], ["CURRENT JOB", 0], ["CONDITION", 6.5],
			["CHARGE", 6.5], ["LOCATION", 8.5], ["GROUP", 5.0]]:
		var l := _label(spec[0], "display_bold", fs - 3, T.DIM)
		if float(spec[1]) == 0.0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.custom_minimum_size.x = _w(spec[1])
		h.add_child(l)
	return p


func _fill_table() -> void:
	_clear(_table)
	if _rows.is_empty():
		var l := _label("No TartanCo bots on site. They work in the orbital yard's build berth: open the yard to see them here.",
				"body", fs, T.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = fs * 20
		_table.add_child(l)
		return
	for i in _rows.size():
		_table.add_child(_bot_row(_rows[i], i % 2 == 1))


func _bot_row(r: Dictionary, alt: bool) -> Control:
	var on := str(r.serial) == selected
	var p := PanelContainer.new()
	p.name = "Bot_" + str(r.serial).validate_node_name()
	var bg := T.PLATE_HI if alt else T.PLATE
	var st := T.box(T.tone(bg.lightened(0.08) if on else bg, glass), T.ORANGE if on else Color.TRANSPARENT, 2 if on else 0, fs * 0.3)
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.gui_input.connect(func(e: InputEvent) -> void:
		if _clicked(e):
			select(str(r.serial)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(fs * 0.4))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var lamp := Lamp.new()
	lamp.colour = STATE_COLOURS.get(str(r.state), T.STEEL)
	lamp.blink = str(r.state) == "faulted"
	lamp.custom_minimum_size = Vector2(_w(0.7), _w(0.7))
	lamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(lamp)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", -3)
	who.custom_minimum_size.x = _w(6.6)
	who.add_child(_label(str(r.serial), "mono_bold", fs, T.TEXT))
	who.add_child(_label("%s %s %s" % [r.model, str(r.mark).to_upper(), str(r.trade).to_upper()], "display_medium", fs - 4, T.DIM))
	h.add_child(who)
	var state := _label(str(r.state_name), "mono_bold", fs - 2, STATE_COLOURS.get(str(r.state), T.STEEL))
	state.custom_minimum_size.x = _w(7.2)
	state.clip_text = true
	h.add_child(state)
	var job_text := str(r.job)
	if not (r.errors as Array).is_empty():
		job_text = "ERROR " + ", ".join(PackedStringArray(r.errors))
	elif job_text == "":
		job_text = _job_fallback(r)
	var job := _label(job_text, "body_medium", fs - 1, T.BAD if not (r.errors as Array).is_empty() else T.TEXT)
	job.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	job.clip_text = true
	job.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(job)
	h.add_child(_meter(float(r.condition), BAND_COLOURS[str(r.band)], _w(6.5)))
	h.add_child(_meter(float(r.charge), T.CYAN if float(r.charge) > 0.2 else T.AMBER, _w(6.5), bool(r.charging)))
	var loc := _label(str(r.location), "body", fs - 2, T.DIM)
	loc.custom_minimum_size.x = _w(8.5)
	loc.clip_text = true
	h.add_child(loc)
	var g := bus.orders.group(str(r.group))
	var gl := _label(str(g.name) if not g.is_empty() else "-", "display_bold", fs - 2,
			Color.html(str(g.colour)) if not g.is_empty() else T.DIM)
	gl.custom_minimum_size.x = _w(5.0)
	gl.clip_text = true
	h.add_child(gl)
	return p


func _job_fallback(r: Dictionary) -> String:
	match str(r.state):
		"charging":
			return "Topping up on its dock"
		"to_dock":
			return "Flying to its charge dock"
		"servicing":
			return "Being serviced by TartanCo's engineers"
		"idle":
			return "Waiting for work"
	return "%s work on the keel" % str(r.trade)


## A bar with its percentage: `value` 0..1.
func _meter(value: float, colour: Color, width: int, pulse := false) -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size.x = width
	h.add_theme_constant_override("separation", int(fs * 0.25))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := Bar.new()
	bar.value = value
	bar.colour = colour
	bar.pulse = pulse
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size.y = maxi(6, int(fs * 0.5))
	h.add_child(bar)
	var l := _label("%d%%" % roundi(value * 100), "mono_medium", fs - 2, colour)
	l.custom_minimum_size.x = fs * 2.4
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(l)
	return h


# --- The side: tabs, one bot, the orders ------------------------------------------------------

func _fill_tabs() -> void:
	_clear(_tabs)
	for t: String in TABS:
		var b := T.button("BOT DETAIL" if t == "bot" else "GROUPS AND ORDERS", false, fs - 1, t == tab, glass)
		b.name = "Tab_" + t
		b.pressed.connect(show_tab.bind(t))
		_tabs.add_child(b)


func _fill_bot() -> void:
	_clear(_side)
	var r: Dictionary = {}
	for x in _rows:
		if x.serial == selected:
			r = x
	if r.is_empty():
		_side.add_child(_label("No bot picked.", "body", fs, T.DIM))
		return
	var card := _card()
	var v: VBoxContainer = card.get_child(0)
	var top := HBoxContainer.new()
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", -3)
	name_box.add_child(_label(str(r.serial), "mono_bold", int(fs * 1.5), T.TEXT))
	name_box.add_child(_label("TARTANCO %s  %s" % [r.model, str(r.trade).to_upper()], "display_medium", fs - 2, T.DIM))
	top.add_child(name_box)
	top.add_child(T.tag(str(r.state_name), STATE_COLOURS.get(str(r.state), T.STEEL), fs - 3))
	v.add_child(top)
	v.add_child(_fact("Job", str(r.job) if str(r.job) != "" else _job_fallback(r)))
	v.add_child(_fact("Location", "%s   (%.0f, %.0f, %.0f m)" % [r.location, r.where.x, r.where.y, r.where.z]))
	_side.add_child(card)
	# Health.
	var health := _card("CONDITION")
	var hv: VBoxContainer = health.get_child(0)
	hv.add_child(_meter_line("Condition", float(r.condition), BAND_COLOURS[str(r.band)],
			{"good": "Good", "fair": "Fair: slowing down", "poor": "Poor: needs TartanCo"}[str(r.band)]))
	hv.add_child(_meter_line("Charge", float(r.charge), T.CYAN,
			"Charging on its dock" if bool(r.charging) else ("Low: heading to charge" if float(r.charge) <= 0.2 else "On battery")))
	hv.add_child(_meter_line("Output", float(r.productivity), T.GOOD if float(r.productivity) > 0.8 else T.AMBER,
			"Stopped by a fault" if float(r.productivity) <= 0.0 else "Of a new bot's pace"))
	if not (r.errors as Array).is_empty():
		for e: String in r.errors:
			hv.add_child(_label("ERROR  " + e, "mono_bold", fs - 1, T.BAD))
	else:
		hv.add_child(_label("No errors logged", "body", fs - 2, T.DIM))
	_side.add_child(health)
	# Upgrades.
	var up := _card("UPGRADES")
	var uv: VBoxContainer = up.get_child(0)
	var fitted: Array = r.upgrades
	if str(r.mark) != "":
		uv.add_child(_fact("Mark", "%s, %d module slot%s, %d free" % [r.mark, int(r.slots), "" if int(r.slots) == 1 else "s",
				maxi(0, int(r.slots) - fitted.size())]))
	if fitted.is_empty():
		uv.add_child(_label("No modules fitted.", "body", fs - 2, T.DIM))
	for u: Variant in fitted:
		var d: Dictionary = u if u is Dictionary else {"name": str(u)}
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", int(fs * 0.4))
		line.add_child(T.tag(str(d.get("name", d.get("id", "?"))), T.CYAN, fs - 3))
		var eff := _label(str(d.get("line", "")), "body", fs - 3, T.DIM)
		eff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(eff)
		uv.add_child(line)
	_side.add_child(up)
	# Its group: the first command.
	var gc := _card("GROUP")
	var gv: VBoxContainer = gc.get_child(0)
	if bus.orders.groups.is_empty():
		gv.add_child(_label("No groups yet. Make one under GROUPS AND ORDERS.", "body", fs - 2, T.DIM))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	for g: Dictionary in bus.orders.groups:
		var b := T.button(str(g.name).to_upper(), false, fs - 2, str(r.group) == str(g.id), glass)
		b.name = "Join_" + str(g.id)
		b.add_theme_color_override("font_color", Color.html(str(g.colour)))
		b.pressed.connect(func() -> void: bus.command({"op": "bot_assign", "serial": str(r.serial), "group": str(g.id)}))
		flow.add_child(b)
	if str(r.group) != "":
		var none := T.button("NO GROUP", false, fs - 2, false, glass)
		none.name = "Join_none"
		none.pressed.connect(func() -> void: bus.command({"op": "bot_assign", "serial": str(r.serial), "group": ""}))
		flow.add_child(none)
	gv.add_child(flow)
	_side.add_child(gc)


func _fill_orders() -> void:
	_clear(_side)
	var groups_card := _card("BOT GROUPS")
	var gv: VBoxContainer = groups_card.get_child(0)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	for g: Dictionary in bus.orders.by_priority():
		var b := T.button("%s  P%d  %d BOTS" % [str(g.name).to_upper(), int(g.priority), (g.bots as Array).size()],
				false, fs - 2, str(g.id) == group, glass)
		b.name = "Group_" + str(g.id)
		b.add_theme_color_override("font_color", Color.html(str(g.colour)))
		b.pressed.connect(show_group.bind(str(g.id)))
		flow.add_child(b)
	var add := T.button("+ NEW GROUP", true, fs - 2, editing and str(draft.group) == "", glass)
	add.name = "NewGroup"
	add.pressed.connect(edit_group.bind(""))
	flow.add_child(add)
	gv.add_child(flow)
	_side.add_child(groups_card)
	if editing:
		_side.add_child(_editor())
		return
	var g := bus.orders.group(group)
	if g.is_empty():
		var hint := _label("Press + NEW GROUP, name it, pick its bots and save it. Then give it work from the build plan.",
				"body", fs - 2, T.DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_side.add_child(hint)
		_side.add_child(_footnote())
		return
	# The group: its name, priority and bots.
	var gcard := _card()
	var v: VBoxContainer = gcard.get_child(0)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	var title := _label(str(g.name).to_upper(), "display_bold", int(fs * 1.3), Color.html(str(g.colour)))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(_label("PRIORITY", "display_medium", fs - 3, T.DIM))
	top.add_child(_stepper(int(g.priority), func(p: int) -> void:
		bus.command({"op": "group_priority", "group": str(g.id), "priority": p}), "GroupPriority"))
	var edit := T.button("RENAME / PICK BOTS", false, fs - 3, false, glass)
	edit.name = "EditGroup"
	edit.pressed.connect(edit_group.bind(str(g.id)))
	top.add_child(edit)
	var drop := T.button("DISBAND", false, fs - 3, false, glass)
	drop.name = "Disband"
	drop.pressed.connect(func() -> void: bus.command({"op": "group_remove", "group": str(g.id)}))
	top.add_child(drop)
	v.add_child(top)
	var names := PackedStringArray()
	for s: String in g.bots:
		names.append(s)
	v.add_child(_fact("Bots", ", ".join(names) if not names.is_empty() else "None yet: press RENAME / PICK BOTS"))
	var trades := {}
	for r in _rows:
		if (g.bots as Array).has(r.serial):
			trades[r.role] = true
	_side.add_child(gcard)
	# Its task list.
	var tcard := _card("WORK TASKS")
	var tv: VBoxContainer = tcard.get_child(0)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	var plan := bus.plan_tasks()
	var from := T.button("ADD FROM BUILD PLAN" + (" (%s)" % bus.plan_name().to_upper() if bus.plan_name() != "" else ""),
			true, fs - 2, false, glass)
	from.name = "AddFromPlan"
	from.disabled = plan.is_empty()
	from.pressed.connect(func() -> void: _add_from_plan(g, plan, trades))
	bar.add_child(from)
	if not (g.tasks as Array).is_empty():
		var clear := T.button("CLEAR", false, fs - 2, false, glass)
		clear.name = "ClearTasks"
		clear.pressed.connect(func() -> void: bus.command({"op": "tasks_clear", "group": str(g.id)}))
		bar.add_child(clear)
	tv.add_child(bar)
	if plan.is_empty():
		tv.add_child(_label("Open a design at the holotable to take its build plan.", "body", fs - 2, T.DIM))
	var tasks: Array = g.tasks
	if tasks.is_empty():
		tv.add_child(_label("No tasks. The group's bots carry on with the keel.", "body", fs - 2, T.DIM))
	for i in tasks.size():
		tv.add_child(_task_row(g, tasks[i], i, tasks.size()))
	_side.add_child(tcard)
	_side.add_child(_footnote())


## The group editor: the name, a button per bot to put it in or take it out, SAVE GROUP.
func _editor() -> Control:
	var card := _card("NEW GROUP" if str(draft.group) == "" else "EDIT GROUP")
	card.name = "GroupEditor"
	var v: VBoxContainer = card.get_child(0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(fs * 0.4))
	var nl := _label("NAME", "display_medium", fs - 3, T.DIM)
	nl.custom_minimum_size.x = fs * 5.5
	row.add_child(nl)
	var name_box := T.search("Name the group", func(t: String) -> void: draft.name = t, glass)
	name_box.name = "GroupName"
	name_box.clear_button_enabled = false
	name_box.max_length = 32
	name_box.text = str(draft.name)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_font_size_override("font_size", T.px(fs))
	name_box.text_submitted.connect(func(_t: String) -> void: save_group())
	row.add_child(name_box)
	v.add_child(row)
	v.add_child(_label("BOTS: press a bot to put it in this group or take it out", "display_medium", fs - 3, T.DIM))
	if _rows.is_empty():
		v.add_child(_label("No bots on site. Open the orbital yard to pick them.", "body", fs - 2, T.DIM))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	for r in _rows:
		var serial := str(r.serial)
		var other := bus.orders.group_of(serial)
		var away := not other.is_empty() and str(other.id) != str(draft.group)
		var b := T.button("%s  %s%s" % [serial, str(r.trade).to_upper(), ("  (IN %s)" % str(other.name).to_upper()) if away else ""],
				false, fs - 3, (draft.bots as Dictionary).has(serial), glass)
		b.name = "Pick_" + serial.validate_node_name()
		b.toggle_mode = true
		b.button_pressed = (draft.bots as Dictionary).has(serial)
		b.toggled.connect(func(on: bool) -> void:
			if on:
				draft.bots[serial] = true
			else:
				(draft.bots as Dictionary).erase(serial)
			# Its look follows (the kit lights a tab with `on`).
			var lit := T.button(b.text, false, fs - 3, on, glass)
			b.add_theme_stylebox_override("normal", lit.get_theme_stylebox("normal"))
			b.add_theme_color_override("font_color", lit.get_theme_color("font_color"))
			lit.free())
		flow.add_child(b)
	v.add_child(flow)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	var save := T.button("SAVE GROUP", true, fs - 1, false, glass)
	save.name = "SaveGroup"
	save.pressed.connect(save_group)
	bar.add_child(save)
	var cancel := T.button("CANCEL", false, fs - 1, false, glass)
	cancel.name = "CancelEdit"
	cancel.pressed.connect(cancel_edit)
	bar.add_child(cancel)
	v.add_child(bar)
	var note := _label("A bot is in one group at a time: saving moves it here from any other.", "body", fs - 4, T.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	return card


## Adds the plan's tasks this group doesn't have yet: the ones its bots' trades do, or every one
## while it has no bots.
func _add_from_plan(g: Dictionary, plan: Array[Dictionary], trades: Dictionary) -> void:
	var have := {}
	for t: Dictionary in g.tasks:
		have[str(t.line)] = true
	for t in plan:
		if have.has(str(t.line)) or (not trades.is_empty() and not trades.has(str(t.trade))):
			continue
		bus.command({"op": "task_add", "group": str(g.id), "task": t})


func _task_row(g: Dictionary, t: Dictionary, i: int, n: int) -> Control:
	var p := PanelContainer.new()
	p.name = "Task_" + str(t.id)
	p.add_theme_stylebox_override("panel", T.box(T.tone(T.PLATE_HI if i % 2 else T.PLATE, glass), Color.TRANSPARENT, 0, fs * 0.25))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(fs * 0.3))
	p.add_child(h)
	h.add_child(_label("%d" % (i + 1), "mono_bold", fs - 1, T.DIM))
	var what := VBoxContainer.new()
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	what.add_theme_constant_override("separation", -3)
	var nl := _label(str(t.name), "body_medium", fs - 1, T.TEXT)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	what.add_child(nl)
	what.add_child(_label("%s  %s  %s %s  %.1f H  %s" % [str(FleetOrders.STAGE_NAMES.get(str(t.stage), t.stage)).to_upper(),
			str(FleetOrders.TRADES.get(str(t.trade), t.trade)).to_upper(), _qty(float(t.qty)), str(t.unit).to_upper(),
			float(t.hours), str(t.get("joins", "")).to_upper()], "display_medium", fs - 4, T.DIM))
	h.add_child(what)
	h.add_child(_stepper(int(t.priority), func(pr: int) -> void:
		bus.command({"op": "task_priority", "group": str(g.id), "task": str(t.id), "priority": pr}), "Priority"))
	for mv: Array in [["UP", -1, i > 0], ["DN", 1, i < n - 1]]:
		var b := T.button(mv[0], false, fs - 4, false, glass)
		b.name = "Move" + str(mv[0])
		b.disabled = not bool(mv[2])
		b.pressed.connect(func() -> void: bus.command({"op": "task_move", "group": str(g.id), "task": str(t.id), "by": int(mv[1])}))
		h.add_child(b)
	var x := T.button("X", false, fs - 4, false, glass)
	x.name = "Remove"
	x.pressed.connect(func() -> void: bus.command({"op": "task_remove", "group": str(g.id), "task": str(t.id)}))
	h.add_child(x)
	return p


func _qty(q: float) -> String:
	return "%d" % roundi(q) if q >= 10.0 or is_equal_approx(q, roundf(q)) else "%.1f" % q


## "- Normal +" for a priority 1..5.
func _stepper(value: int, on_set: Callable, node_name: String) -> Control:
	var h := HBoxContainer.new()
	h.name = node_name
	h.add_theme_constant_override("separation", 2)
	var down := T.button("-", false, fs - 3, false, glass)
	down.name = "Down"
	down.disabled = value <= FleetOrders.PRIORITY_MIN
	down.pressed.connect(func() -> void: on_set.call(value - 1))
	h.add_child(down)
	var colour: Color = [T.STEEL, T.STEEL, T.TEXT, T.AMBER, T.BAD][clampi(value, 1, 5) - 1]
	var l := _label(str(FleetOrders.PRIORITY_NAMES.get(value, value)).to_upper(), "mono_bold", fs - 3, colour)
	l.custom_minimum_size.x = fs * 3.6
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	var up := T.button("+", false, fs - 3, false, glass)
	up.name = "Up"
	up.disabled = value >= FleetOrders.PRIORITY_MAX
	up.pressed.connect(func() -> void: on_set.call(value + 1))
	h.add_child(up)
	return h


func _next_name() -> String:
	var used := {}
	for g: Dictionary in bus.orders.groups:
		used[str(g.name)] = true
	for n: String in ["Frame crew", "Hull crew", "Fit-out crew", "Services crew", "Night shift", "Reserve"]:
		if not used.has(n):
			return n
	return ""


func _footnote() -> Control:
	var l := _label("Orders are saved and shared with the crew. The bots start working to them when auto-building arrives; till then they build the keel.",
			"body", fs - 3, T.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# --- Bits ------------------------------------------------------------------------------------

func _card(title := "") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(T.tone(T.PLATE, glass), T.tone(T.EDGE, glass, 0.8), 1, fs * 0.5))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(fs * 0.25))
	p.add_child(v)
	if title != "":
		v.add_child(_label(title, "display_bold", fs - 2, T.STEEL))
	return p


func _fact(what: String, text: String) -> Control:
	var h := HBoxContainer.new()
	var a := _label(what.to_upper(), "display_medium", fs - 3, T.DIM)
	a.custom_minimum_size.x = fs * 5.5
	h.add_child(a)
	var b := _label(text, "body_medium", fs - 1, T.TEXT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(b)
	return h


func _meter_line(what: String, value: float, colour: Color, note: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var h := HBoxContainer.new()
	var a := _label(what.to_upper(), "display_medium", fs - 3, T.DIM)
	a.custom_minimum_size.x = fs * 5.5
	h.add_child(a)
	var m := _meter(value, colour, fs * 10)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(m)
	v.add_child(h)
	var n := _label(note, "body", fs - 4, T.DIM)
	n.custom_minimum_size.x = 0
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", int(fs * 5.5))
	pad.add_child(n)
	v.add_child(pad)
	return v


func _label(text: String, face: String, size: int, colour: Color) -> Label:
	var l := T.label(text, face, maxi(9, size), colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _clicked(e: InputEvent) -> bool:
	return e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT


func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


## A meter's bar: dark track, coloured fill, tick marks every quarter.
class Bar:
	extends Control
	var value := 0.0
	var colour := Color.WHITE
	## Charging: the fill's leading edge breathes.
	var pulse := false

	func _process(_d: float) -> void:
		if pulse:
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.45))
		var fill := Rect2(Vector2.ZERO, Vector2(size.x * clampf(value, 0.0, 1.0), size.y))
		var c := colour
		if pulse:
			c = c.lerp(Color.WHITE, 0.25 + 0.25 * sin(Time.get_ticks_msec() / 250.0))
		draw_rect(fill, c)
		for q in [0.25, 0.5, 0.75]:
			draw_line(Vector2(size.x * q, 0), Vector2(size.x * q, size.y), Color(0, 0, 0, 0.5), 1.0)
		draw_rect(r, Color(colour, 0.5), false, 1.0)


## A status lamp, blinking on a fault.
class Lamp:
	extends Control
	var colour := Color.WHITE
	var blink := false

	func _process(_d: float) -> void:
		if blink:
			queue_redraw()

	func _draw() -> void:
		var on := not blink or int(Time.get_ticks_msec() / 400.0) % 2 == 0
		var rad := minf(size.x, size.y) * 0.4
		draw_circle(size * 0.5, rad * 1.35, Color(colour, 0.18 if on else 0.05))
		draw_circle(size * 0.5, rad, colour if on else colour.darkened(0.6))
