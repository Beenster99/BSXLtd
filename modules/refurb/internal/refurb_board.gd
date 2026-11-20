extends PanelContainer
## The works' wall screen over the charger rack (beenster, 20 Nov: "The wall TV should be in the
## same format as the ones in the design room - nice common layout with details of the
## tasking"): the design room's wall board look (a dark blue wall, panels side by side, each
## under a header bar with its title, big tiles and rows in the terminal kit's style), here
## three panels: TASKING (each cradle and the heavy stand: the part, its grade now and when
## certified and the drones on it, the stage, a progress bar and its condition, then what is
## coming in), DRONES (each drone, what it is doing and its charge) and THE WORKS (the figures:
## goods in, on the rollers, certified, scrapped, spent, the crane and cart, and what is ready
## to take). Built once; `refresh()` only changes texts, colours and bars.

const T := preload("res://modules/ui/api/terminal_kit.gd")

## The panels: [title, share of the wall's width].
const PANELS := [["TASKING", 1.95], ["DRONES", 1.3], ["THE WORKS", 0.85]]
## Text is drawn this much bigger than the sizes below (read from the floor, ten metres off).
const TEXT_SCALE := 2.0
const STAGE_COLOURS: Array[Color] = [Color(0.3, 0.75, 1.0), Color(1.0, 0.6, 0.15), Color(0.85, 0.8, 0.6),
		Color(1.0, 0.45, 0.1), Color(0.3, 1.0, 0.45), Color(1.0, 0.25, 0.15)]

var works: RefurbWorks
## Pixels per metre the wall is drawn at (sizes the text to read from the floor).
var px_per_m := 150.0
var _rows: Array[Dictionary] = []
var _bots: Array[Dictionary] = []
var _figures: Dictionary = {}
var _coming: Label
var _ready: Label


func setup(w: RefurbWorks, density: float) -> void:
	works = w
	px_per_m = density
	name = "RefurbBoard"
	add_theme_stylebox_override("panel", T.box(Color(0.02, 0.05, 0.09), Color(0.2, 0.45, 0.65, 0.6), 2, 0.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(px_per_m * 0.12))
	add_child(row)
	var bodies: Array[VBoxContainer] = []
	for p: Array in PANELS:
		var slot := VBoxContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_stretch_ratio = float(p[1])
		slot.add_theme_constant_override("separation", 0)
		row.add_child(slot)
		slot.add_child(_header(str(p[0])))
		var body_box := PanelContainer.new()
		body_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_box.add_theme_stylebox_override("panel", T.box(T.KIOSK, T.EDGE, 2, _px(0.09)))
		slot.add_child(body_box)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", _px(0.07))
		body_box.add_child(body)
		bodies.append(body)
	_tasking(bodies[0])
	_drones(bodies[1])
	_works(bodies[2])
	refresh()


func _px(m: float) -> int:
	return int(px_per_m * m)


func _font(m: float) -> int:
	return maxi(10, int(px_per_m * m * TEXT_SCALE))


func _header(title: String) -> Control:
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", T.box(Color(0.06, 0.13, 0.2), Color.TRANSPARENT, 0, px_per_m * 0.07))
	var t := T.label(title, "display_bold", _font(0.2), T.TEXT)
	t.name = "Title"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(t)
	return head


func _heading(text: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", _px(0.02))
	col.add_child(T.label(text, "display_bold", _font(0.14), T.TEXT))
	var rule := T.HazardRule.new(float(_px(0.06)))
	col.add_child(rule)
	return col


## A bar `width` px wide: [the bar's back, its fill].
func _bar(width: float, height: float) -> Array:
	var back := ColorRect.new()
	back.color = Color(0.1, 0.12, 0.14)
	back.custom_minimum_size = Vector2(width, height)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := ColorRect.new()
	fill.color = T.GOOD
	fill.size = Vector2(0, height)
	back.add_child(fill)
	return [back, fill]


func _cell(text: String, width: float, colour := T.DIM, face := "mono_medium", size := 0.1) -> Label:
	var l := T.label(text, face, _font(size), colour)
	l.custom_minimum_size.x = width
	l.clip_text = true
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _tasking(body: VBoxContainer) -> void:
	body.add_child(_heading("ON THE STANDS"))
	var head := HBoxContainer.new()
	for c: Array in [["BAY", 0.95], ["PART", 0.0], ["STAGE", 1.55], ["PROGRESS", 1.75], ["COND", 0.8]]:
		var l := _cell(str(c[0]), _px(float(c[1])), T.DIM, "display_medium", 0.1)
		if float(c[1]) == 0.0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(l)
	body.add_child(head)
	for i in works.cradles.size():
		var heavy := i == works.heavy_index()
		var cells := HBoxContainer.new()
		cells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cells.add_theme_constant_override("separation", _px(0.04))
		var bay := _cell("HEAVY" if heavy else "R%d" % (i + 1), _px(0.95), T.ORANGE, "display_bold", 0.18)
		var part := VBoxContainer.new()
		part.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		part.add_theme_constant_override("separation", -_px(0.02))
		var name_l := _cell("", 0, T.TEXT, "body_medium", 0.15)
		var grade_l := _cell("", 0, T.DIM, "mono_medium", 0.095)
		part.add_child(name_l)
		part.add_child(grade_l)
		var stage := T.tag("", T.DIM, _font(0.12))
		stage.custom_minimum_size.x = _px(1.55)
		var bar_box := HBoxContainer.new()
		bar_box.custom_minimum_size.x = _px(1.75)
		bar_box.add_theme_constant_override("separation", _px(0.05))
		var bar := _bar(_px(0.8), _px(0.2))
		bar_box.add_child(bar[0])
		var pct := _cell("", _px(0.7), T.TEXT, "mono_bold", 0.15)
		bar_box.add_child(pct)
		var cond := _cell("", _px(0.8), T.TEXT, "mono_medium", 0.15)
		for c: Control in [bay, part, stage, bar_box, cond]:
			cells.add_child(c)
		var wrap := T.row([cells], i % 2 == 1)
		body.add_child(wrap)
		_rows.append({"name": name_l, "grade": grade_l, "stage": stage, "fill": bar[1], "bar": bar[0], "pct": pct, "cond": cond})
	body.add_child(_heading("COMING IN"))
	_coming = T.label("", "body", _font(0.13), T.TEXT)
	_coming.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_coming)


func _drones(body: VBoxContainer) -> void:
	body.add_child(_heading("BSX RF-2 REFURBISHERS"))
	for i in works.bots.size():
		var b: Dictionary = works.bots[i]
		var cells := HBoxContainer.new()
		cells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cells.add_theme_constant_override("separation", _px(0.05))
		var serial := _cell(String(b.serial), _px(1.3), T.ORANGE, "mono_bold", 0.12)
		var doing := _cell("", 0, T.TEXT, "body_medium", 0.12)
		doing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bar := _bar(_px(0.5), _px(0.18))
		var pct := _cell("", _px(0.65), T.TEXT, "mono_medium", 0.12)
		for c: Control in [serial, doing, bar[0], pct]:
			cells.add_child(c)
		body.add_child(T.row([cells], i % 2 == 1))
		_bots.append({"doing": doing, "fill": bar[1], "bar": bar[0], "pct": pct})


func _works(body: VBoxContainer) -> void:
	body.add_child(_heading("TODAY"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", _px(0.06))
	grid.add_theme_constant_override("v_separation", _px(0.06))
	for f: Array in [["goods", "Goods in"], ["rollers", "On rollers"], ["certified", "Certified"], ["scrapped", "Scrapped"],
			["crane", "Crane"], ["cart", "Cart"]]:
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_theme_stylebox_override("panel", T.plate(_px(0.06)))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -2)
		v.add_child(T.label(str(f[1]).to_upper(), "display_medium", _font(0.09), T.DIM))
		var val := T.label("", "mono_bold", _font(0.17), T.TEXT)
		v.add_child(val)
		p.add_child(v)
		grid.add_child(p)
		_figures[f[0]] = val
	body.add_child(grid)
	var spent := PanelContainer.new()
	spent.add_theme_stylebox_override("panel", T.plate(_px(0.06)))
	var sv := VBoxContainer.new()
	sv.add_child(T.label("SPENT ON REFURBISHING", "display_medium", _font(0.09), T.DIM))
	var sval := T.label("", "mono_bold", _font(0.17), T.AMBER)
	sv.add_child(sval)
	spent.add_child(sv)
	body.add_child(spent)
	_figures["spent"] = sval
	body.add_child(_heading("READY TO TAKE"))
	_ready = T.label("", "body", _font(0.12), T.TEXT)
	_ready.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_ready)


func refresh() -> void:
	for i in _rows.size():
		_fill_row(i)
	for i in _bots.size():
		_fill_bot(i)
	var waiting := works.backlog.size() + works.lots_at(RefurbWorks.AT_CART).size()
	(_figures.goods as Label).text = str(waiting)
	(_figures.rollers as Label).text = str(works.lots_at(RefurbWorks.AT_INTAKE).size())
	(_figures.certified as Label).text = str(works.certified)
	(_figures.certified as Label).modulate = T.GOOD
	(_figures.scrapped as Label).text = str(works.scrapped)
	(_figures.crane as Label).text = String(works.crane.phase).to_upper()
	(_figures.cart as Label).text = String(works.cart.phase).to_upper()
	(_figures.spent as Label).text = "CR " + T.money(roundi(works.spent))
	var coming: PackedStringArray = []
	for lot in works.lots_at(RefurbWorks.AT_CART) + works.lots_at(RefurbWorks.AT_INTAKE) + works.lots_at(RefurbWorks.AT_CRANE):
		coming.append("%s %d%%" % [String(lot.name), roundi(float(lot.condition) * 100.0)])
	for id in works.backlog.slice(0, 4):
		var lot: Dictionary = works.lots.get(id, {})
		if not lot.is_empty():
			coming.append("%s %d%%" % [String(lot.name), roundi(float(lot.condition) * 100.0)])
	_coming.text = "   ·   ".join(coming.slice(0, 6)) if not coming.is_empty() else "Nothing waiting"
	var ready: PackedStringArray = []
	var keys: Array = works.stock.keys()
	keys.sort()
	for t: String in keys:
		var p := works.catalog.part(t)
		ready.append("%s %s  x%d" % [p.display_name if p else t, DesignGrades.label(p) if p else "", int(works.stock[t])])
	for lot in works.lots_at(RefurbWorks.AT_OUT):
		var rp := works.catalog.part(String(lot.result))
		ready.append("%s %s" % [rp.display_name if rp else String(lot.name), DesignGrades.label(rp) if rp else ""])
	_ready.text = "\n".join(ready.slice(0, 6)) + ("\n+%d more" % (ready.size() - 6) if ready.size() > 6 else "") if not ready.is_empty() else "Nothing yet"


func _fill_row(i: int) -> void:
	var r := _rows[i]
	var lot := works.lot_on(i)
	var name_l: Label = r.name
	var grade_l: Label = r.grade
	var stage_l := (r.stage as Control).get_child(0).get_child(0) as Label
	var stage_box := (r.stage as Control).get_child(0) as PanelContainer
	var fill: ColorRect = r.fill
	var bar: ColorRect = r.bar
	if lot.is_empty():
		name_l.text = "Free"
		name_l.modulate = T.DIM
		grade_l.text = ""
		_stage(stage_l, stage_box, "WAITING", T.DIM)
		fill.size.x = 0.0
		(r.pct as Label).text = ""
		(r.cond as Label).text = ""
		return
	name_l.modulate = Color.WHITE
	name_l.text = String(lot.name)
	var p := works.catalog.part(String(lot.type))
	var to := works.catalog.part(works.certified_type(String(lot.type)))
	var grades := "%s  >  %s" % [DesignGrades.label(p) if p else "?", DesignGrades.label(to) if to else "?"]
	var stage := int(lot.stage)
	var progress := float(lot.progress)
	if String(lot.where) != RefurbWorks.AT_CRADLE:
		_stage(stage_l, stage_box, "ON ITS WAY", T.CYAN)
		progress = 0.0
	elif stage < 0:
		var scrap := String(lot.result) == "scrap"
		_stage(stage_l, stage_box, "TO THE SKIP" if scrap else "CERTIFIED", T.BAD if scrap else T.GOOD)
		progress = 1.0
	else:
		var label := RefurbWorks.STAGE_NAMES[stage] + (" (RETEST)" if bool(lot.retest) and stage == RefurbWorks.Stage.REBUILD else "")
		_stage(stage_l, stage_box, label, STAGE_COLOURS[stage])
	fill.size = Vector2(bar.custom_minimum_size.x * clampf(progress, 0.0, 1.0), bar.custom_minimum_size.y)
	fill.color = STAGE_COLOURS[stage] if stage >= 0 else T.GOOD
	(r.pct as Label).text = "%d%%" % roundi(progress * 100.0)
	var cond := float(lot.condition)
	(r.cond as Label).text = "%d%%" % roundi(cond * 100.0)
	(r.cond as Label).modulate = T.GOOD if cond > 0.7 else (T.AMBER if cond > 0.4 else T.BAD)
	var names: PackedStringArray = []
	var team: Array[Dictionary] = []
	if i == works.heavy_index():
		team = works.heavy_team(int(lot.id))
	if team.is_empty():
		for b: Dictionary in works.bots:
			if int(b.lot) == int(lot.id):
				team.append(b)
	for b: Dictionary in team:
		names.append(String(b.serial).get_slice("/", 1) + ("H" if String(b.role) == "heavy" else ""))
	grade_l.text = grades + ("   ·   " + " ".join(names) if not names.is_empty() else "")


func _stage(l: Label, box: PanelContainer, text: String, colour: Color) -> void:
	if l.text == text and l.get_meta("colour", Color()) == colour:
		return
	l.text = text
	l.set_meta("colour", colour)
	l.add_theme_color_override("font_color", colour)
	var st := T.box(Color(colour, 0.18), colour, 2, 0.0)
	st.content_margin_left = _px(0.05)
	st.content_margin_right = _px(0.05)
	box.add_theme_stylebox_override("panel", st)


func _fill_bot(i: int) -> void:
	var b: Dictionary = works.bots[i]
	var r := _bots[i]
	var lot: Dictionary = works.lots.get(int(b.lot), {})
	var state := String(b.state)
	var doing := ""
	var home := (b.pos as Vector3).distance_to(works.dock_point(i)) < 0.05
	match state:
		RefurbWorks.BOT_WORK:
			doing = "%s  %s" % [RefurbWorks.STAGE_NAMES[int(lot.stage)] if not lot.is_empty() and int(lot.stage) >= 0 else "Working", String(lot.get("name", ""))]
		RefurbWorks.BOT_FETCH:
			doing = "Fetching " + String(lot.get("name", "a part"))
		RefurbWorks.BOT_CARRY:
			doing = "Carrying " + String(lot.get("name", "a part"))
		RefurbWorks.BOT_STOW:
			doing = "Racking " + String(lot.get("name", "a part"))
		RefurbWorks.BOT_RETURN:
			doing = "Flying home"
		_:
			doing = ("Charging" if bool(b.charging) else "On its charger") if home else "Going to its charger"
	(r.doing as Label).text = doing
	var charge := float(b.charge)
	var fill: ColorRect = r.fill
	var bar: ColorRect = r.bar
	fill.size = Vector2(bar.custom_minimum_size.x * clampf(charge, 0.0, 1.0), bar.custom_minimum_size.y)
	fill.color = T.GOOD if charge > 0.6 else (T.AMBER if charge > 0.3 else T.BAD)
	(r.pct as Label).text = "%d%%" % roundi(charge * 100.0)
