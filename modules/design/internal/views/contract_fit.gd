extends PanelContainer
## The contract fit assessment (beenster, 19 Nov): the open design held up against its ship
## order, area by area. The overall status and %, each area's validation % with the checks
## behind it, the pitfalls, risks, bonuses and cheap wins, and the company optimiser's
## write-up and plan. Reads DesignBus.assessment() (worked out once per edit for every view);
## shown on a wall panel ("fit") and full screen from the design console.
## Wide, it sets the areas beside the optimiser; narrow, one under the other.

const T := preload("res://modules/ui/api/terminal_kit.gd")

## Below this many font-heights wide it stacks into one column.
const STACK_BELOW := 52.0

var bus: DesignBus
## Base text size, px (a wall panel reads from across the room).
var font := 18
var _body: VBoxContainer
var _queued := false
var _wide := true


func setup(design_bus: DesignBus, base_font := 18) -> void:
	bus = design_bus
	font = base_font
	name = "ContractFit"
	add_theme_stylebox_override("panel", T.box(T.KIOSK, T.EDGE, 2, font * 0.7))
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", int(font * 0.6))
	scroll.add_child(_body)
	bus.design_changed.connect(_queue)
	resized.connect(_on_resized)
	refresh()


func _on_resized() -> void:
	var wide := size.x >= font * STACK_BELOW
	if wide != _wide:
		_wide = wide
		_queue()


func _queue() -> void:
	if not _queued:
		_queued = true
		refresh.call_deferred()


func _s(k: float) -> int:
	return int(roundf(font * k))


func refresh() -> void:
	_queued = false
	if _body == null or not is_instance_valid(bus):
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var a := bus.assessment()
	if a == null:
		_body.add_child(T.label("No design open", "body", _s(1.0), T.DIM))
		return
	_body.add_child(_header(a))
	_body.add_child(T.HazardRule.new(font * 0.35))
	var split: BoxContainer = HBoxContainer.new() if _wide else VBoxContainer.new()
	split.add_theme_constant_override("separation", _s(0.9))
	_body.add_child(split)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.35
	left.add_theme_constant_override("separation", _s(0.5))
	split.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", _s(0.5))
	split.add_child(right)
	left.add_child(_heading("AREAS OF THE CONTRACT"))
	var grid := GridContainer.new()
	grid.columns = 2 if _wide else 1
	grid.add_theme_constant_override("h_separation", _s(0.5))
	grid.add_theme_constant_override("v_separation", _s(0.5))
	for ar in a.areas:
		grid.add_child(_area_card(ar))
	left.add_child(grid)
	right.add_child(_optimiser(a))
	right.add_child(_findings(a))


# --- The header: the order and the overall verdict ---------------------------------------

func _header(a: DesignAssessment) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", _s(1.0))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", _s(0.15))
	h.add_child(info)
	info.add_child(T.label("CONTRACT FIT ASSESSMENT", "display_medium", _s(0.8), T.DIM))
	var rec := bus.library.current
	if a.order.is_empty():
		info.add_child(T.label(rec.name if rec else "", "display_bold", _s(1.6), T.TEXT))
		info.add_child(_wrap("No ship order picked. Pick one under SHIP ORDER at the design console to score her against a client's brief.",
				"body", _s(0.95), T.AMBER))
	else:
		info.add_child(T.label(str(a.order.get("title", "")), "display_bold", _s(1.6), T.TEXT))
		var role: Dictionary = ShipOrders.ROLES.get(str(a.order.get("role", "")), {})
		info.add_child(T.label("%s   ·   %s   ·   DESIGN: %s" % [str(a.order.get("client_name", "")).to_upper(),
				str(role.get("name", "")).to_upper(), (rec.name if rec else "").to_upper()], "display_medium", _s(0.85), T.ORANGE))
		info.add_child(_wrap("\"%s\"" % str(a.order.get("brief", "")), "body", _s(0.95), T.DIM))
		var demands := HFlowContainer.new()
		demands.add_theme_constant_override("h_separation", _s(0.4))
		demands.add_theme_constant_override("v_separation", _s(0.3))
		for line in ShipOrders.demand_lines(a.order):
			demands.add_child(T.tag(line, T.STEEL, _s(0.75)))
		demands.add_child(T.tag("Delivery in %d days" % int(a.order.get("days", 0)), T.STEEL, _s(0.75)))
		info.add_child(demands)
		var bf := bus.berth_fit()
		if not bf.is_empty() and not bf.ok:
			var bl := _wrap("NEEDS A LARGER BERTH: she is %s x %s x %s m and the %s is %s x %s x %s m, less %s m clearance each side." % [
					snappedf(bf.length, 0.1), snappedf(bf.beam, 0.1), snappedf(bf.height, 0.1),
					str(bf.berth.name).to_lower(), snappedf(float(bf.berth.length), 0.1), snappedf(float(bf.berth.beam), 0.1),
					snappedf(float(bf.berth.height), 0.1), DesignBerth.CLEARANCE], "display_medium", _s(0.85), T.BAD)
			bl.name = "BerthNeeded"
			info.add_child(bl)
	# The verdict block.
	var verdict := PanelContainer.new()
	var col := _status_colour(a.status)
	verdict.add_theme_stylebox_override("panel", T.box(Color(col, 0.1), col, 2, font * 0.6))
	verdict.custom_minimum_size.x = font * 15
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", _s(0.1))
	verdict.add_child(v)
	v.add_child(T.label("OVERALL STATUS", "display_medium", _s(0.75), T.DIM))
	var st := T.label(a.status, "display_bold", _s(1.5), col)
	st.name = "Status"
	v.add_child(st)
	var pct := T.label("%d%%" % int(roundf(a.score * 100.0)), "mono_bold", _s(2.6), col)
	pct.name = "Overall"
	v.add_child(pct)
	v.add_child(_bar(a.score, col, font * 0.45))
	if not a.order.is_empty():
		var m := a.met()
		v.add_child(T.label("%d of %d demands met" % [m.x, m.y], "body_medium", _s(0.9), T.TEXT))
		v.add_child(T.label("Fee CR %s   Expected CR %s" % [T.money(a.fee), T.money(a.expected_fee())], "mono_medium", _s(0.8),
				T.GOOD if a.expected_fee() >= a.fee else T.AMBER))
	h.add_child(verdict)
	return h


# --- One area: its % and the checks behind it --------------------------------------------

func _area_card(ar: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.name = "Area_" + str(ar.id)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := _area_colour(ar)
	var sb := T.box(T.PLATE, col, 0, font * 0.5)
	sb.border_width_left = maxi(3, _s(0.25))
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", _s(0.2))
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", _s(0.4))
	var name_l := _wrap(str(ar.name).to_upper(), "display_bold", _s(0.95), T.TEXT)
	top.add_child(name_l)
	var pct := T.label("%d%%" % int(roundf(float(ar.score) * 100.0)) if ar.assessed else "--", "mono_bold", _s(1.5), col)
	pct.name = "Pct"
	top.add_child(pct)
	v.add_child(top)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", _s(0.4))
	var bar := _bar(float(ar.score) if ar.assessed else 0.0, col, font * 0.35)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(bar)
	line.add_child(T.tag(_area_word(ar), col, _s(0.7)))
	v.add_child(line)
	v.add_child(_wrap(str(ar.about), "body", _s(0.75), T.DIM))
	if not ar.assessed:
		v.add_child(T.label("Needs a ship order", "body_medium", _s(0.85), T.AMBER))
	for c: Dictionary in ar.checks:
		var ccol := T.BAD if not c.ok else (T.AMBER if c.watch else T.GOOD)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", _s(0.35))
		var mark := T.label("OK" if c.ok and not c.watch else ("!!" if c.ok else "NO"), "mono_bold", _s(0.8), ccol)
		mark.custom_minimum_size.x = font * 1.6
		row.add_child(mark)
		var lab := _wrap(str(c.label), "body", _s(0.85), T.TEXT)
		row.add_child(lab)
		var have := T.label(str(c.have), "mono_medium", _s(0.8), ccol)
		have.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(have)
		v.add_child(row)
	return p


# --- The company optimiser --------------------------------------------------------------

func _optimiser(a: DesignAssessment) -> Control:
	var p := PanelContainer.new()
	p.name = "Optimiser"
	p.add_theme_stylebox_override("panel", T.box(Color(T.CYAN, 0.07), Color(T.CYAN, 0.6), 2, font * 0.7))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", _s(0.45))
	p.add_child(v)
	var head := HBoxContainer.new()
	var t := T.label("COMPANY OPTIMISER", "display_bold", _s(1.15), T.CYAN)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(T.label("BSX LTD DESIGN OFFICE", "display_medium", _s(0.7), T.DIM))
	v.add_child(head)
	for para in a.narrative:
		v.add_child(_wrap(para, "body", _s(0.95), T.TEXT))
	if not a.plan.is_empty():
		v.add_child(T.label("THE PLAN", "display_bold", _s(0.9), T.CYAN))
		var i := 1
		for m: Dictionary in a.plan:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", _s(0.4))
			row.add_child(T.label("%d" % i, "mono_bold", _s(0.9), T.CYAN))
			row.add_child(_wrap("%s, fixes %s" % [str(m.text), ", ".join(m.fixes)], "body_medium", _s(0.85), T.TEXT))
			row.add_child(T.label(_cost(float(m.cost)), "mono_medium", _s(0.8), T.TEXT))
			v.add_child(row)
			i += 1
		var r := a.plan_result
		v.add_child(T.label("After the plan: %d of %d demands met, CR %s" % [int(r.met), int(r.total), T.money(int(r.cost))],
				"mono_bold", _s(0.85), T.GOOD if int(r.met) == int(r.total) else T.AMBER))
	return p


func _findings(a: DesignAssessment) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", _s(0.35))
	for spec in [[DesignAssessment.PITFALL, "PITFALLS", T.BAD], [DesignAssessment.RISK, "RISKS TO WATCH", T.AMBER],
			[DesignAssessment.WIN, "CHEAP WINS", T.CYAN], [DesignAssessment.BONUS, "BONUSES AND NEAR MISSES", T.GOOD]]:
		var list := a.findings_of(str(spec[0]))
		var head := HBoxContainer.new()
		var t := T.label(str(spec[1]), "display_bold", _s(0.95), spec[2])
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		head.add_child(T.tag("%d" % list.size(), spec[2], _s(0.7)))
		v.add_child(head)
		if list.is_empty():
			v.add_child(T.label("None", "body", _s(0.85), T.DIM))
		var alt := false
		for f: Dictionary in list:
			var row := PanelContainer.new()
			row.name = "Finding_" + str(spec[0])
			var sb := T.box(T.PLATE_HI if alt else T.PLATE, spec[2], 0, font * 0.35)
			sb.border_width_left = 3
			row.add_theme_stylebox_override("panel", sb)
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", _s(0.4))
			row.add_child(h)
			h.add_child(T.label(_area_short(str(f.area)), "display_medium", _s(0.65), T.DIM))
			h.add_child(_wrap(str(f.text), "body", _s(0.85), T.TEXT))
			if absf(float(f.value)) >= 1.0:
				h.add_child(T.label(("+" if float(f.value) > 0.0 else "-") + "CR " + T.money(int(absf(float(f.value)))), "mono_medium",
						_s(0.8), T.GOOD if float(f.value) > 0.0 else T.BAD))
			v.add_child(row)
			alt = not alt
	return v


# --- Bits ------------------------------------------------------------------------------

func _heading(text: String) -> Label:
	return T.label(text, "display_bold", _s(1.05), T.TEXT)


func _wrap(text: String, face: String, sz: int, col: Color) -> Label:
	var l := T.label(text, face, sz, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = font * 6
	return l


func _bar(share: float, col: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(share, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(font * 4, height)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(T.EDGE, 0.9)
	bar.add_theme_stylebox_override("background", bg)
	return bar


static func _status_colour(status: String) -> Color:
	match status:
		DesignAssessment.READY:
			return T.GOOD
		DesignAssessment.CARE, DesignAssessment.CLOSE:
			return T.AMBER
		DesignAssessment.WORK:
			return T.ORANGE
		DesignAssessment.NOT_VIABLE:
			return T.BAD
	return T.STEEL


static func _area_colour(ar: Dictionary) -> Color:
	if not ar.assessed:
		return T.STEEL
	match str(ar.status):
		DesignAssessment.FAIL:
			return T.BAD
		DesignAssessment.WATCH:
			return T.AMBER
	return T.GOOD


static func _area_word(ar: Dictionary) -> String:
	if not ar.assessed:
		return "NO BRIEF"
	match str(ar.status):
		DesignAssessment.FAIL:
			return "FAILS"
		DesignAssessment.WATCH:
			return "WATCH"
	return "PASSES"


static func _area_short(id: String) -> String:
	return {"brief": "BRIEF", "budget": "COST", "schedule": "TIME", "rules": "BUILD", "systems": "SYSTEMS",
			"crew": "CREW", "role": "CLIENT", "optimiser": "OPTIMISER"}.get(id, id.to_upper())


static func _cost(v: float) -> String:
	return ("+CR " if v >= 0.0 else "-CR ") + T.money(int(absf(v)))
