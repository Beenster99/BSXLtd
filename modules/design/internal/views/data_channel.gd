extends PanelContainer
## The live data channel (plan 2.5, 2.6): the open design's numbers, its parts list with
## quantities, and what will not work, updating with every edit. The same control is shown on
## a wall TV and beside the plan at the design console.

const T := preload("res://modules/ui/api/terminal_kit.gd")

var bus: DesignBus
## Contract demands to score against (Wave 4 fills these from the contract).
var demands: Dictionary = {}
var compact := false
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
	_body.add_child(T.label("PARTS AND COST", "display_bold", 26, T.TEXT))
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
	if not demands.is_empty():
		_body.add_child(T.label("CONTRACT FIT", "display_bold", 20, T.TEXT))
		for row in t.fit(demands):
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
	_body.add_child(T.label("PARTS LIST", "display_bold", 20, T.TEXT))
	_body.add_child(T.columns([["Item", 0], ["Qty", 80], ["Mass", 90], ["Cost", 120]]))
	alt = false
	for line in t.lines:
		var qty := "%d %s" % [int(roundf(line.qty)), str(line.unit)]
		_body.add_child(T.row([T.cell_text(str(line.name), str(line.kind)), T.cell(qty, 80),
				T.cell("%.1f t" % (float(line.mass) / 1000.0), 90),
				T.cell(T.money(int(line.cost)), 120, T.TEXT)], alt))
		alt = not alt


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
