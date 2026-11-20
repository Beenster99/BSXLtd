extends VBoxContainer
## Help's size x class matrix: one group of components at a time, a row per component and a
## column per size (1 to 8), in the grade picked above. Each cell gives what that size does
## (kW, thrust, jump...) and the power it makes or uses. Click a power maker (a reactor,
## generator, battery...) to make it the supply: every cell it can run turns green, every one
## it can't turns red, and each group's button counts how many it runs.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const Data := preload("res://modules/help/internal/capability_data.gd")

const CELL_BG := Color(1, 1, 1, 0.04)
const RUN_BG := Color(0.12, 0.32, 0.14)
const NO_BG := Color(0.3, 0.08, 0.06)
const SHADE := Color(0.18, 0.42, 0.62)

var data: Data
var fs := 15
var grade := "S"
var category := "power"
## The supply's type id ("" for none) and the cell last clicked.
var supply_id := ""
var picked_id := ""

var _grades: HBoxContainer
var _cats: HFlowContainer
var _supply: Label
var _clear: Button
var _grid: GridContainer
var _detail: Label


func setup(catalog: DesignCatalog, px_per_m: float) -> void:
	data = Data.new(catalog)
	fs = maxi(12, int(px_per_m * 0.1))
	name = "Matrix"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", int(fs * 0.5))
	add_child(_label("Every component that comes in sizes, at every size from 1 (smallest) to 8 (largest), in the grade you pick. Bigger is not always better: compare a row against the others in its group. Click a reactor, generator or battery to make it the supply and see everything it can power.", "body", fs + 1, T.TEXT, true))
	_grades = HBoxContainer.new()
	_grades.name = "Grades"
	_grades.add_theme_constant_override("separation", int(fs * 0.3))
	add_child(_grades)
	_cats = HFlowContainer.new()
	_cats.name = "Groups"
	_cats.add_theme_constant_override("h_separation", int(fs * 0.3))
	_cats.add_theme_constant_override("v_separation", int(fs * 0.3))
	add_child(_cats)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", T.box(Color(0.12, 0.08, 0.03), T.ORANGE, 1, fs * 0.5))
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", int(fs * 0.8))
	bar.add_child(bar_row)
	_supply = _label("", "body_medium", fs + 1, Color(1.0, 0.85, 0.65), true)
	_supply.name = "Supply"
	bar_row.add_child(_supply)
	_clear = _chip("CLEAR SUPPLY", false)
	_clear.name = "ClearSupply"
	_clear.pressed.connect(set_supply.bind(""))
	bar_row.add_child(_clear)
	add_child(bar)
	_detail = _label("", "body", fs + 1, T.TEXT, true)
	_detail.name = "Detail"
	add_child(_detail)
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = 1 + DesignGrades.MAX_CLASS
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	add_child(_grid)
	var cats := data.categories()
	if not cats.any(func(c: Array) -> bool: return str(c[0]) == category) and not cats.is_empty():
		category = str(cats[0][0])
	refresh()


func set_grade(g: String) -> void:
	grade = g
	refresh()


func set_category(c: String) -> void:
	category = c
	refresh()


## Makes a power maker the supply ("" clears it).
func set_supply(type_id: String) -> void:
	supply_id = type_id
	refresh()


## What a cell click does: picks the part and, for a power maker, makes it the supply.
func pick(type_id: String) -> void:
	picked_id = type_id
	var p := data.catalog.part(type_id)
	if p and Data.is_supply(p):
		supply_id = "" if supply_id == type_id else type_id
	refresh()


func supply() -> DesignPartType:
	return data.catalog.part(supply_id) if supply_id != "" else null


## The cell button for a type id shown now, or null.
func cell(type_id: String) -> Button:
	return _grid.find_child("Cell_" + type_id.replace(":", "_"), false, false) as Button


## "run", "no", "supply" or "" for a cell, as it is coloured.
func cell_state(p: DesignPartType) -> String:
	var s := supply()
	if s == null:
		return ""
	if p.id == s.id:
		return "supply"
	if Data.draw(p) <= 0.0:
		return ""
	return "run" if Data.runs(s, p) else "no"


func refresh() -> void:
	_fill_grades()
	var s := supply()
	var cov := data.coverage(s) if s else {}
	_fill_cats(cov)
	if s:
		_supply.text = "SUPPLY  %s  ·  %s kW. It runs %d of the %d sizes and grades that use power." % [
				s.display_name, Data.short(Data.output(s)), int(cov.ok), int(cov.total)]
	else:
		_supply.text = "No supply picked. Click a power maker (the Power group) to see what it can run."
	_clear.visible = s != null
	_fill_grid()
	_fill_detail()


func _fill_grades() -> void:
	_clear_children(_grades)
	_grades.add_child(_label("GRADE", "display_bold", fs, T.DIM))
	for g in DesignGrades.GRADE_ORDER:
		var b := _chip("%s  %s" % [g, str(DesignGrades.GRADES[g].name)], g == grade)
		b.name = "Grade_" + g
		b.tooltip_text = str(DesignGrades.GRADES[g].blurb)
		b.pressed.connect(set_grade.bind(g))
		_grades.add_child(b)


func _fill_cats(cov: Dictionary) -> void:
	_clear_children(_cats)
	for c: Array in data.categories():
		var id := str(c[0])
		var text := str(c[1])
		if not cov.is_empty():
			var n: Array = cov.by_category.get(id, [0, 0])
			if int(n[1]) > 0:
				text += "  %d/%d" % [int(n[0]), int(n[1])]
		var b := _chip(text, id == category)
		b.name = "Group_" + id
		b.pressed.connect(set_category.bind(id))
		_cats.add_child(b)


func _fill_grid() -> void:
	_clear_children(_grid)
	var head := _label("COMPONENT", "display_bold", fs, T.DIM)
	head.custom_minimum_size.x = fs * 14
	_grid.add_child(head)
	for s in range(DesignGrades.MIN_CLASS, DesignGrades.MAX_CLASS + 1):
		var h := _label("SIZE %d" % s, "display_bold", fs - 1, T.DIM)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.custom_minimum_size.x = fs * 4.8
		_grid.add_child(h)
	var types := data.types_in(category)
	# Shade each rating against the best in the group, on a log scale.
	var best := {}
	for base in types:
		for s in range(DesignGrades.MIN_CLASS, DesignGrades.MAX_CLASS + 1):
			var v := data.variant(base, s, grade)
			if v:
				var m := Data.metric(v)
				best[m.field] = maxf(float(best.get(m.field, 0.0)), Data.value_of(v, str(m.field)))
	for base in types:
		var m := Data.metric(base)
		var name_box := VBoxContainer.new()
		name_box.add_theme_constant_override("separation", 0)
		name_box.add_child(_label(base.display_name, "body_medium", fs, T.TEXT))
		var sub := _label("%s, %s" % [m.label, m.unit], "body", fs - 3, T.DIM)
		name_box.add_child(sub)
		_grid.add_child(name_box)
		for s in range(DesignGrades.MIN_CLASS, DesignGrades.MAX_CLASS + 1):
			var v := data.variant(base, s, grade)
			if v == null:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(fs * 4.8, fs * 2.4)
				_grid.add_child(gap)
				continue
			_grid.add_child(_cell(v, float(best.get(Data.metric(v).field, 0.0))))


func _cell(v: DesignPartType, best: float) -> Button:
	var m := Data.metric(v)
	var value := Data.value_of(v, str(m.field))
	var power := ("+%s kW" % Data.short(Data.output(v))) if Data.is_supply(v) else \
			(("%s kW" % Data.short(-Data.draw(v))) if Data.draw(v) > 0.0 else "no power")
	var b := Button.new()
	b.name = "Cell_" + v.id.replace(":", "_")
	var plain := str(m.field) == "output" or str(m.field) == "draw"
	b.text = "%s\n%s" % [Data.short(value), ("kW made" if Data.is_supply(v) else "kW used") if plain else power]
	b.tooltip_text = "%s  ·  %s %s %s" % [v.display_name, m.label, Data.short(value), m.unit]
	b.custom_minimum_size = Vector2(fs * 4.8, fs * 2.4)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", T.font("mono_medium"))
	b.add_theme_font_size_override("font_size", fs - 2)
	var state := cell_state(v)
	var bg := CELL_BG
	match state:
		"run":
			bg = RUN_BG
		"no":
			bg = NO_BG
		_:
			if best > 0.0 and value > 0.0:
				bg = CELL_BG.lerp(SHADE, clampf(0.15 + 0.85 * log(1.0 + value) / log(1.0 + best), 0.0, 1.0) * 0.8)
	var edge := T.ORANGE if state == "supply" else (T.TEXT if v.id == picked_id else Color.TRANSPARENT)
	var box := T.box(bg, edge, 2 if edge != Color.TRANSPARENT else 0, fs * 0.2)
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("pressed", box)
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.15)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_color_override("font_color", T.TEXT if state != "no" else Color(1, 0.75, 0.7))
	b.add_theme_color_override("font_hover_color", T.TEXT)
	b.pressed.connect(pick.bind(v.id))
	return b


func _fill_detail() -> void:
	var p := data.catalog.part(picked_id) if picked_id != "" else null
	_detail.visible = p != null
	if p == null:
		_detail.text = ""
		return
	var m := Data.metric(p)
	var g: Dictionary = DesignGrades.GRADES.get(p.grade if p.grade != "" else "S", {})
	var facts: PackedStringArray = ["%s %s %s" % [m.label, Data.short(Data.value_of(p, str(m.field))), m.unit]]
	if str(m.field) != "output" and str(m.field) != "draw":
		facts.append(("makes %s kW" % Data.short(Data.output(p))) if Data.is_supply(p) else
				(("uses %s kW" % Data.short(Data.draw(p))) if Data.draw(p) > 0.0 else "no power"))
	facts.append("%s kg" % Data.short(p.mass))
	facts.append("%s cr" % Data.short(p.cost))
	facts.append("%.1f x %.1f x %.1f m" % [p.size.x, p.size.y, p.size.z])
	var lines: PackedStringArray = ["%s  (size %d, %s grade)" % [p.display_name, p.size_class, str(g.get("name", ""))],
			"  ·  ".join(facts)]
	var s := supply()
	if s and s.id != p.id and Data.draw(p) > 0.0:
		var form := "%s runs it: it uses %s of the %s kW made." if Data.runs(s, p) else "%s can't run it: it needs %s kW and the supply makes %s."
		lines.append(form % [s.display_name, Data.short(Data.draw(p)), Data.short(Data.output(s))])
	_detail.text = "\n".join(lines)


func _chip(text: String, on: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", T.font("body_medium"))
	b.add_theme_font_size_override("font_size", fs - 1)
	b.add_theme_color_override("font_color", T.TEXT if on else T.DIM)
	b.add_theme_color_override("font_hover_color", T.TEXT)
	var box := T.box(Color(0.1, 0.2, 0.3) if on else Color(1, 1, 1, 0.05), T.ORANGE if on else Color.TRANSPARENT, 1 if on else 0, fs * 0.35)
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("pressed", box)
	b.add_theme_stylebox_override("hover", T.box(Color(1, 1, 1, 0.1), Color.TRANSPARENT, 0, fs * 0.35))
	return b


func _label(text: String, face: String, size: int, colour: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", T.font(face))
	l.add_theme_font_size_override("font_size", maxi(8, size))
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _clear_children(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
