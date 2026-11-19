extends PanelContainer
## The live data channel (plan 2.5, 2.6): the open design's numbers, its parts list with
## quantities, and what will not work, updating with every edit. The same control is shown on
## a wall TV and beside the plan at the design console.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const PlanView := preload("res://modules/design/internal/views/plan_view.gd")

var bus: DesignBus
## Contract demands to score against (Wave 4 fills these from the contract).
var demands: Dictionary = {}
var compact := false
## With the parts and build lists (a wall screen), or without them and the design's attributes
## in their place (the design console; beenster, 19 Nov: "lots of attribute data, remove parts
## list": the parts list has its own wall screen).
var lists := true
var _body: VBoxContainer
var _queued := false


func setup(design_bus: DesignBus, is_compact := false) -> void:
	bus = design_bus
	compact = is_compact
	add_theme_stylebox_override("panel", T.box(T.KIOSK, T.EDGE, 2, 14.0))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
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
	_body.add_child(T.label("PARTS AND COST" if lists else "DESIGN DATA", "display_bold", 26, T.TEXT))
	_body.add_child(T.HazardRule.new(6.0))
	if rec == null:
		_body.add_child(T.label("No design open", "body", 18, T.DIM))
		return
	var t := bus.totals()
	var problems := bus.problems()
	_body.add_child(T.label(rec.name + ("  (unsaved)" if bus.library.dirty else ""), "body_medium", 19, T.TEXT))
	var grid := GridContainer.new()
	grid.columns = 2 if compact else 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var balance := t.power_balance()
	for fig in [
		["Cost", "CR " + T.money(int(t.cost)), T.TEXT],
		["Mass", "%.1f t" % (t.mass / 1000.0), T.TEXT],
		["Power", "%+.0f kW" % balance, T.GOOD if balance >= 0.0 else T.BAD],
		["Build", "%d h" % int(ceil(t.build_hours)), T.TEXT],
		["Crew", "%d" % t.crew, T.TEXT],
		["Cargo", "%d m3" % int(t.cargo_m3), T.TEXT],
		["Thrust", "%.2f m/s2" % t.acceleration(), T.TEXT if t.thrust > 0.0 else T.AMBER],
		["Parts in", "%d days" % t.lead_days, T.TEXT],
	]:
		var f := T.figure(fig[0], fig[1], fig[2])
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(f)
	_body.add_child(grid)
	# What the finished ship can do, from its graded components (DesignTotals).
	_body.add_child(T.label("SHIP RATINGS", "display_bold", 20, T.TEXT))
	var ratings := GridContainer.new()
	ratings.columns = 2 if compact else 3
	ratings.add_theme_constant_override("h_separation", 6)
	ratings.add_theme_constant_override("v_separation", 6)
	for fig in [
		["Jump range", "%.1f ly" % t.jump_range(), T.TEXT if t.jump_range() > 0.0 else T.AMBER],
		["Top speed", "%d m/s" % int(t.speed()), T.TEXT],
		["Defence", "%d" % int(t.defence_rating()), T.TEXT],
		["Attack", "%d dmg/s" % int(t.attack), T.TEXT],
		["Stealth", "%d / 100" % int(t.stealth()), T.TEXT],
		["Sensors", "%d km" % int(t.sensor_km), T.TEXT],
	]:
		var f := T.figure(fig[0], fig[1], fig[2])
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ratings.add_child(f)
	_body.add_child(ratings)
	# The ship order the design answers sets the demands, unless a view set its own.
	var want: Dictionary = demands if not demands.is_empty() else rec.order.get("demands", {})
	if not want.is_empty():
		_body.add_child(T.label("CONTRACT FIT", "display_bold", 20, T.TEXT))
		if not rec.order.is_empty():
			_body.add_child(T.label(str(rec.order.get("title", "")), "body_medium", 16, T.ORANGE))
		for row in t.fit(want):
			_body.add_child(_fit_row(row))
	_body.add_child(T.label("WILL IT WORK", "display_bold", 20, T.TEXT))
	if problems.is_empty():
		_body.add_child(T.label("Nothing flagged", "body", 17, T.GOOD))
	var alt := false
	for p in problems:
		var col := T.BAD if p.severity == DesignRules.ERROR else T.AMBER
		var text := T.label(p.text, "body", 17, T.TEXT)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(T.row([T.tag("ERROR" if p.severity == DesignRules.ERROR else "CHECK", col, 13), _gap(8), text], alt))
		alt = not alt
	if not lists:
		_attributes(rec, t)
		return
	_body.add_child(T.label("PARTS LIST", "display_bold", 20, T.TEXT))
	_body.add_child(T.columns([["Item", 0], ["Qty", 80], ["Mass", 90], ["Cost", 120]]))
	alt = false
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
		var l := T.label("Doors: " + ", ".join(kinds), "body", 15, T.DIM)
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


func _section(title: String, figs: Array) -> void:
	_body.add_child(T.label(title, "display_bold", 20, T.TEXT))
	var grid := GridContainer.new()
	grid.columns = 2 if compact else 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for fig in figs:
		var f := T.figure(fig[0], fig[1], fig[2])
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(f)
	_body.add_child(grid)


func _fit_row(row: Dictionary) -> Control:
	var col := T.GOOD if row.ok else T.BAD
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = row.share
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	bar.add_theme_stylebox_override("fill", fill)
	var name_cell := T.cell_text(str(row.label))
	return T.row([name_cell, bar, T.cell("%s / %s" % [_num(row.have), _num(row.need)], 160, col)])


func _gap(w: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = w
	return c


static func _num(v: float) -> String:
	if absf(v) >= 1000.0:
		return T.money(int(v))
	return ("%d" % int(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v)
