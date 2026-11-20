extends PanelContainer
## The live data channel (plan 2.5, 2.6): the open design's numbers, its parts list with
## quantities, and what will not work, updating with every edit. The same control is shown on
## a wall TV and beside the plan at the design console.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const PlanView := preload("res://modules/design/internal/views/plan_view.gd")

## The full contract fit assessment was asked for (the console opens it full screen).
signal assessment_requested
## A WILL IT WORK row was clicked (beenster, 20 Nov: "take me to the part of the design in
## error"): the problem, {code, text, rooms, components, doors}.
signal problem_picked(problem: Dictionary)

var bus: DesignBus
## Contract demands to score against (Wave 4 fills these from the contract).
var demands: Dictionary = {}
var compact := false
## Small type and figures as label-value pairs that wrap to the width (the design console's
## panel; beenster, 20 Nov: "much larger text than the others and could be more efficiently
## organised"). The wall screens keep the big tiles.
var dense := false
## With the parts and build lists (a wall screen), or without them and the design's attributes
## in their place (the design console; beenster, 19 Nov: "lots of attribute data, remove parts
## list": the parts list has its own wall screen).
var lists := true
var _body: VBoxContainer
## How wide one dense label-value pair is, px.
const PAIR_W := 168
var _queued := false


func setup(design_bus: DesignBus, is_compact := false, is_dense := false) -> void:
	bus = design_bus
	compact = is_compact
	dense = is_dense
	add_theme_stylebox_override("panel", T.box(T.KIOSK, T.EDGE, 1 if dense else 2, 6.0 if dense else 14.0))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4 if dense else 8)
	scroll.add_child(_body)
	bus.design_changed.connect(_queue)
	refresh()


func _queue() -> void:
	if not _queued:
		_queued = true
		refresh.call_deferred()


func refresh() -> void:
	_queued = false
	if _body == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var rec := bus.library.current
	_body.add_child(T.label("PARTS AND COST" if lists else "DESIGN DATA", "display_bold", _sz(26), T.TEXT))
	if not dense:
		_body.add_child(T.HazardRule.new(6.0))
	if rec == null:
		_body.add_child(T.label("No design open", "body", _sz(18), T.DIM))
		return
	var t := bus.totals()
	var problems := bus.problems()
	_body.add_child(T.label(rec.name + ("  (unsaved)" if bus.library.dirty else ""), "body_medium", _sz(19), T.TEXT))
	_problems(problems)
	if not lists:
		_berth()
	# The ship order the design answers sets the demands, unless a view set its own.
	var want: Dictionary = demands if not demands.is_empty() else rec.order.get("demands", {})
	if not want.is_empty():
		_body.add_child(_heading("CONTRACT FIT"))
		if not rec.order.is_empty():
			var ot := T.label(str(rec.order.get("title", "")), "body_medium", _sz(16), T.ORANGE)
			ot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_body.add_child(ot)
		for row in t.fit(want):
			_body.add_child(_fit_row(row))
		# The order's special clauses (rooms, parts, grades), scored like the demands.
		if demands.is_empty():
			for row in DesignContractCheck.clauses(rec.order, rec, bus.catalog):
				_body.add_child(_fit_row(row))
		var a := bus.assessment()
		if a and not rec.order.is_empty() and demands.is_empty():
			var col := T.GOOD if a.status == DesignAssessment.READY else (T.BAD if a.status == DesignAssessment.NOT_VIABLE else T.AMBER)
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 8)
			line.add_child(T.tag(a.status, col, _sz(14)))
			var what := T.label("%d%% overall  ·  %d pitfalls  ·  %d cheap wins" % [int(roundf(a.score * 100.0)),
					a.findings_of(DesignAssessment.PITFALL).size(), a.findings_of(DesignAssessment.WIN).size()], "body_medium", _sz(16), T.TEXT)
			what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(what)
			if compact:
				var open := T.button("FULL ASSESSMENT", true, _sz(14))
				open.name = "BtnAssessment"
				open.pressed.connect(func() -> void: assessment_requested.emit())
				line.add_child(open)
			_body.add_child(line)
	var balance := t.power_balance()
	_body.add_child(_figures("Summary", 4, [
		["Cost", "CR " + T.money(int(t.cost)), T.TEXT],
		["Dry mass", "%.1f t" % (t.mass / 1000.0), T.TEXT],
		["Power", "%+.0f kW" % balance, T.GOOD if balance >= 0.0 else T.BAD],
		["Build", "%d h" % int(ceil(t.build_hours)), T.TEXT],
		["Crew", "%d" % t.crew, T.TEXT],
		["Cargo", "%d m3" % int(t.cargo_m3), T.TEXT],
		["Thrust", "%.2f m/s2" % t.acceleration(), T.TEXT if t.thrust > 0.0 else T.AMBER],
		["Parts in", "%d days" % t.lead_days, T.TEXT],
	]))
	# What the finished ship can do, from its graded components (DesignTotals).
	_body.add_child(_heading("SHIP RATINGS"))
	_body.add_child(_figures("Ratings", 3, [
		["Jump range", "%.1f ly" % t.jump_range(), T.TEXT if t.jump_range() > 0.0 else T.AMBER],
		["Top speed", "%d m/s" % int(t.speed()), T.TEXT],
		["Defence", "%d" % int(t.defence_rating()), T.TEXT],
		["Attack", "%d dmg/s" % int(t.attack), T.TEXT],
		["Stealth", "%d / 100" % int(t.stealth()), T.TEXT],
		["Sensors", "%d km" % int(t.sensor_km), T.TEXT],
	]))
	# Her masses: as built, tanks full, people aboard; and what her holds may carry.
	_body.add_child(_heading("MASSES"))
	_body.add_child(_figures("Masses", 3, [
		["Dry mass", "%.1f t" % (t.dry_mass() / 1000.0), T.TEXT],
		["Fuel load", "%.1f t" % (t.fuel_mass / 1000.0), T.TEXT if t.fuel_mass > 0.0 else T.AMBER],
		["Wet mass", "%.1f t" % (t.wet_mass() / 1000.0), T.TEXT],
		["Occupancy mass", "%.1f t" % (t.occupancy_mass / 1000.0), T.TEXT],
		["Flying mass", "%.1f t" % (t.flying_mass() / 1000.0), T.TEXT],
		["Cargo max", "%.1f t" % (t.cargo_max / 1000.0), T.TEXT],
	]))
	if not lists:
		_attributes(rec, t)
		return
	_body.add_child(T.label("PARTS LIST", "display_bold", 20, T.TEXT))
	_body.add_child(T.columns([["Item", 0], ["Qty", 80], ["Mass", 90], ["Cost", 120]]))
	var alt := false
	for line in t.lines:
		var qty := "%d %s" % [int(roundf(line.qty)), str(line.unit)]
		# Each line names its objects by their IDs (DesignRecord.tag).
		var tags: Array = line.get("tags", [])
		var sub := str(line.kind) if tags.is_empty() else "%s   %s" % [str(line.kind), " ".join(tags)]
		_body.add_child(T.row([T.cell_text(str(line.name), sub), T.cell(qty, 80),
				T.cell("%.1f t" % (float(line.mass) / 1000.0), 90),
				T.cell(T.money(int(line.cost)), 120, T.TEXT)], alt))
		alt = not alt
	# The structure as the yard will build it: every member, plate and joint.
	var build := DesignFrame.build_list(bus.frame_plan())
	if not build.is_empty():
		_body.add_child(T.label("BUILD LIST", "display_bold", 20, T.TEXT))
		_body.add_child(T.columns([["Item", 0], ["Qty", 90], ["Fastened", 260]]))
		alt = false
		for b: Dictionary in build:
			_body.add_child(T.row([T.cell_text(str(b.name)), T.cell("%s %s" % [T.money(int(b.qty)), str(b.unit)], 90),
					T.cell(str(b.how), 260)], alt))
			alt = not alt


## WILL IT WORK, at the top (beenster, 20 Nov: "should definitely be at the top"): each problem a
## row, clickable when it names a room, part or door.
func _problems(problems: Array) -> void:
	_body.add_child(_heading("WILL IT WORK"))
	if problems.is_empty():
		_body.add_child(T.label("Nothing flagged", "body", _sz(17), T.GOOD))
	var alt := false
	for p in problems:
		var col := T.BAD if p.severity == DesignRules.ERROR else T.AMBER
		var text := T.label(p.text, "body", _sz(17), T.TEXT)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var row := T.row([T.tag("ERROR" if p.severity == DesignRules.ERROR else "CHECK", col, _sz(13)), _gap(4 if dense else 8), text], alt)
		if has_place(p):
			# Clickable: the console goes to the room, part or door it is about.
			row.name = "Problem_%d" % _body.get_child_count()
			row.mouse_filter = Control.MOUSE_FILTER_STOP
			row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			row.tooltip_text = "Click to show it on the plan"
			text.text += "  >"
			row.gui_input.connect(func(e: InputEvent) -> void:
				if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
					problem_picked.emit(p))
		_body.add_child(row)
		alt = not alt


## Whether she fits her berth, near the top with WILL IT WORK.
func _berth() -> void:
	var bf := bus.berth_fit()
	if not bf.is_empty():
		var b: Dictionary = bf.berth
		_section("BERTH", [
			["Berth", "%s, %s x %s x %s m" % [str(b.name), PlanView._m(snappedf(float(b.length), 0.1)),
					PlanView._m(snappedf(float(b.beam), 0.1)), PlanView._m(snappedf(float(b.height), 0.1))], T.TEXT],
			["She needs", "%s x %s x %s m" % [PlanView._m(snappedf(bf.length + 2.0 * DesignBerth.CLEARANCE, 0.1)),
					PlanView._m(snappedf(bf.beam + 2.0 * DesignBerth.CLEARANCE, 0.1)),
					PlanView._m(snappedf(bf.height + 2.0 * DesignBerth.CLEARANCE, 0.1))], T.GOOD if bf.ok else T.BAD],
			["Fits", "yes, with %s m for the bots" % PlanView._m(DesignBerth.CLEARANCE) if bf.ok
					else "NO: too " + ", ".join(bf.over.map(func(k: String) -> String: return {"length": "long", "beam": "wide", "height": "tall"}[k])),
					T.GOOD if bf.ok else T.BAD],
		])


## The design's attributes, a section at a time: its size and layout, structure, power and
## drive, and what it costs and weighs to build.
func _attributes(rec: DesignRecord, t: DesignTotals) -> void:
	var st := bus.structure()
	var box := rec.bounds()
	var decks := rec.decks().size()
	var airtight := 0
	var by_kind := {}
	for g: Dictionary in rec.doors.values():
		var dk := DesignCatalog.door_kind(g)
		if bool(dk.get("airtight", false)):
			airtight += 1
		by_kind[str(dk.short)] = int(by_kind.get(str(dk.short), 0)) + 1
	var shaped := rec.rooms.values().filter(func(r): return DesignRecord.is_shaped(r)).size()
	var made := t.power_made
	_section("SIZE AND LAYOUT", [
		["Length", "%s m" % PlanView._m(box.size.y), T.TEXT],
		["Beam", "%s m" % PlanView._m(box.size.x), T.TEXT],
		["Height", "%s m" % PlanView._m(decks * rec.deck_height), T.TEXT],
		["Decks", "%d at %s m" % [decks, PlanView._m(rec.deck_height)], T.TEXT],
		["Rooms", "%d (%d shaped)" % [rec.rooms.size(), shaped], T.TEXT],
		["Floor", "%d m2" % int(t.floor_area), T.TEXT],
		["Volume", "%d m3" % int(t.volume), T.TEXT],
		["Fuel", "%d m3" % int(t.fuel_m3), T.TEXT],
		["Components", "%d inside, %d on hull" % [rec.components.size(), rec.mounts.size()], T.TEXT],
		["Doors", "%d (%d airtight)" % [rec.doors.size(), airtight], T.TEXT],
		["Services", "%d runs" % rec.runs.size(), T.TEXT],
		["Grid", "%s m" % PlanView._m(rec.grid), T.TEXT],
	])
	if not by_kind.is_empty():
		var kinds: Array = []
		for k: String in by_kind:
			kinds.append("%d %s" % [by_kind[k], k.to_lower()])
		var l := T.label("Doors: " + ", ".join(kinds), "body", _sz(15), T.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(l)
	_section("STRUCTURE", [
		["Hull plate", "%d m2" % int(st.outer_area), T.TEXT],
		["Outer walls", "%s m" % PlanView._m(snappedf(st.outer_len, 0.1)), T.TEXT],
		["Inner walls", "%s m" % PlanView._m(snappedf(st.inner_len, 0.1)), T.TEXT],
		["Frame", "%d m" % int(st.frame_m), T.TEXT],
		["Hull mass", "%.1f t" % (t.hull_mass / 1000.0), T.TEXT],
		["Integrity", "%d" % int(t.integrity), T.TEXT],
		["Frame type", str(DesignStructure.option("frame", str(rec.structure.get("frame", "standard"))).get("name", "")), T.TEXT],
		["Spacing", "%s m" % PlanView._m(float(rec.structure.get("spacing", 2.0))), T.TEXT],
	])
	_section("POWER AND DRIVE", [
		["Made", "%d kW" % int(made), T.TEXT],
		["Used", "%d kW" % int(t.power_used), T.TEXT],
		["Spare", "%d%%" % int(100.0 * (made - t.power_used) / made) if made > 0.0 else "none",
				T.GOOD if made >= t.power_used and made > 0.0 else T.BAD],
		["Region", str(DesignPower.REGION_NAMES.get(t.region, t.region)), T.TEXT],
		["Solar", "%d kW rated, %d delivered" % [int(t.solar_rated), int(t.solar_kw)] if t.solar_rated > 0.0
				else "none", T.TEXT if t.solar_kw >= t.solar_rated * 0.5 else T.AMBER],
		["Fuelled", "%d kW%s" % [int(t.fuelled_kw), "  (%d reactor%s)" % [t.reactors, "" if t.reactors == 1 else "s"]
				if t.reactors > 0 else ""], T.TEXT],
		["Batteries", "%d kWh" % int(t.store_kwh), T.TEXT if t.solar_rides_shadow() else T.AMBER],
		["Endurance", ("%d days" % int(t.endurance_days())) + ("+" if t.endurance_days() >= DesignPower.ENDURANCE_CAP else ""),
				T.TEXT if t.endurance_days() > 0.0 else T.BAD],
		["Thrust", "%d kN" % int(t.thrust), T.TEXT if t.thrust > 0.0 else T.AMBER],
		["Thrust/mass", "%.2f m/s2" % t.acceleration(), T.TEXT],
		["Jump rating", "%d" % int(t.jump_rating), T.TEXT],
		["Signature", "%d" % int(t.signature()), T.TEXT],
		["Shielding", "%d" % int(t.defence), T.TEXT],
	])
	var tonnes := maxf(t.mass / 1000.0, 0.001)
	_section("BUILD", [
		["Parts and fit", "CR " + T.money(int(t.cost)), T.TEXT],
		["Per tonne", "CR " + T.money(int(t.cost / tonnes)), T.TEXT],
		["Per m2 floor", "CR " + T.money(int(t.cost / maxf(t.floor_area, 1.0))), T.TEXT],
		["Yard hours", "%d h" % int(ceil(t.build_hours)), T.TEXT],
		["Build days", "%d at 8 h" % int(ceil(t.build_hours / 8.0)), T.TEXT],
		["Longest wait", "%d days" % t.lead_days, T.TEXT],
		["Line items", "%d" % t.lines.size(), T.TEXT],
		["Problems", "%d" % bus.problems().size(), T.GOOD if bus.problems().is_empty() else T.AMBER],
	])


## True when a problem names a room, component or door to go to.
static func has_place(p: Dictionary) -> bool:
	for k: String in ["rooms", "components", "doors"]:
		if not (p.get(k, []) as Array).is_empty():
			return true
	return false


func _section(title: String, figs: Array) -> void:
	_body.add_child(_heading(title))
	_body.add_child(_figures(title.capitalize().replace(" ", ""), 4, figs))


## A text size, smaller when dense (the console's panels are 11 to 14).
func _sz(full: int) -> int:
	return maxi(11, int(roundf(full * 0.68))) if dense else full


func _heading(title: String) -> Label:
	return T.label(title, "display_bold", 14 if dense else 20, T.CYAN if dense else T.TEXT)


## Figures ([label, value, colour]...): big tiles in a grid (`columns`, 2 when compact), or when
## dense, label-value pairs that flow into as many columns as the panel is wide.
func _figures(node_name: String, columns: int, figs: Array) -> Control:
	if dense:
		var flow := HFlowContainer.new()
		flow.name = node_name
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 1)
		for fig in figs:
			flow.add_child(_pair(str(fig[0]), str(fig[1]), fig[2]))
		return flow
	var grid := GridContainer.new()
	grid.name = node_name
	grid.columns = 2 if compact else columns
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for fig in figs:
		var f := T.figure(fig[0], fig[1], fig[2])
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(f)
	return grid


## One dense figure: its name dim on the left, its value on the right, a fixed width so the
## pairs line up in columns.
func _pair(what: String, value: String, colour: Color) -> Control:
	var h := HBoxContainer.new()
	h.name = "Fig_" + what.replace(" ", "_").replace("/", "_")
	h.custom_minimum_size.x = PAIR_W
	h.add_theme_constant_override("separation", 4)
	# A long value (the berth's) makes its pair wider, onto a line of its own if need be.
	var k := T.label(what, "body", 12, T.DIM)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	var v := T.label(value, "mono_medium", 12, colour)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	return h


func _fit_row(row: Dictionary) -> Control:
	var col := T.GOOD if row.ok else T.BAD
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = row.share
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(50 if dense else 120, 6 if dense else 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	bar.add_theme_stylebox_override("fill", fill)
	var name_cell := T.cell_text(str(row.label))
	if dense:
		var n := T.label(str(row.label), "body", 12, T.TEXT)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.add_child(n)
		h.add_child(bar)
		var v := T.label("%s / %s" % [_num(row.have), _num(row.need)], "mono_medium", 12, col)
		v.custom_minimum_size.x = 84
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(v)
		return h
	return T.row([name_cell, bar, T.cell("%s / %s" % [_num(row.have), _num(row.need)], 160, col)])


func _gap(w: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = w
	return c


static func _num(v: float) -> String:
	if absf(v) >= 1000.0:
		return T.money(int(v))
	return ("%d" % int(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v)
