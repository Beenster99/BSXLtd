extends VBoxContainer
## The emitter frame rig's screen after a field sweep: the unit's figures before, what its
## tier is rated for and what it tested at, the grade, and the snags if it failed. Built
## with TerminalKit to match the yard terminals; `glass` for the wrist and TVs.

const T := preload("res://modules/ui/api/terminal_kit.gd")

var plate: UpgradePlate
var glass := false


func _init(p_plate: UpgradePlate, p_glass := false) -> void:
	plate = p_plate
	glass = p_glass
	name = "FieldSweep"
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()


func _build() -> void:
	var d := T.docket("Field sweep", plate.serial if plate.passed else "NOT CERTIFIED", glass)
	var body: VBoxContainer = d.body
	add_child(d.panel)
	var ink := T.TEXT if glass else T.INK
	var dim := T.DIM if glass else T.INK_DIM
	body.add_child(T.label("%s  ·  tier %d" % [FieldSweep.part_words(plate.unit_id).capitalize(), plate.tier],
			"body_medium", 18, ink))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var g := T.figure("Grade", plate.grade, _grade_colour(plate.grade), glass)
	g.name = "Grade"
	head.add_child(g)
	head.add_child(T.figure("Of rated gain", "%d%%" % roundi(plate.efficiency * 100.0), T.TEXT, glass))
	var verdict := T.figure("Result", "PASS" if plate.passed else "FAIL", T.GOOD if plate.passed else T.BAD, glass)
	verdict.name = "Result"
	head.add_child(verdict)
	body.add_child(head)
	body.add_child(T.columns([["FIGURE", 0], ["BEFORE", 110], ["RATED", 110], ["TESTED", 110]]))
	var rows := VBoxContainer.new()
	rows.name = "Figures"
	rows.add_theme_constant_override("separation", 3)
	body.add_child(rows)
	var i := 0
	for stat in plate.base:
		var w: Array = FieldSweep.STATS.get(stat, [str(stat).capitalize(), "", 1.0])
		var before := float(plate.base[stat])
		var rated := float(plate.rated.get(stat, before))
		var tested := float(plate.tested.get(stat, before))
		var colour := T.TEXT
		if rated > before:
			colour = T.GOOD if tested >= rated else (T.AMBER if plate.passed else T.BAD)
		rows.add_child(T.row([T.cell_text(str(w[0]), str(w[1])), T.cell(_num(before * w[2]), 110),
				T.cell(_num(rated * w[2]), 110, T.TEXT), T.cell(_num(tested * w[2]), 110, colour, "mono_bold")],
				i % 2 == 1, glass))
		i += 1
	if not plate.snags.is_empty():
		body.add_child(T.label("SNAGS", "display_medium", 15, dim))
		for s in plate.snags:
			var l := T.label("·  " + str(s.get("text", "")), "body", 15, ink)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.add_child(l)
	body.add_child(T.label("%d JOINTS  ·  AVERAGE %d" % [plate.joints.size(), roundi(plate.average)],
			"mono_medium", 14, dim))


static func _num(v: float) -> String:
	return ("%.1f" % v) if absf(v) < 100.0 else str(roundi(v))


static func _grade_colour(g: String) -> Color:
	match g:
		"A", "B":
			return T.GOOD
		"C":
			return T.AMBER
		"D":
			return T.ORANGE
		"F":
			return T.BAD
	return T.DIM
