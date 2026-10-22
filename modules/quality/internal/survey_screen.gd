extends HBoxContainer
## The wrist screen's Surveys channel (and the TVs'): the independent surveyors' reports.
## The list is every report, newest first, with its overall grade; the docket on the right
## is the chosen report in full, joint by joint. REQUEST SURVEY calls the surveyors in;
## MARK JOB COMPLETE sends the job for its final survey. Built with TerminalKit to match
## the yard terminal.

const T := preload("res://modules/ui/api/terminal_kit.gd")

var bus: QualityBus
var glass := true
var selected := ""
var _contracts: Node


func _init(p_bus: QualityBus, p_glass := true) -> void:
	bus = p_bus
	glass = p_glass
	name = "Surveys"
	add_theme_constant_override("separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	bus.survey_started.connect(_on_started)
	bus.survey_finished.connect(_on_finished)
	_contracts = Modules.bus("contracts")
	if _contracts:
		_contracts.job_state_changed.connect(_on_job_state)
		_contracts.active_job_changed.connect(_on_active_job)
	refresh()


func pick(id: String) -> void:
	selected = id
	refresh()


func request() -> void:
	bus.request_survey(SurveyReport.CALLED)


func complete() -> void:
	bus.request_survey(SurveyReport.FINAL)


func refresh() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var reports := bus.reports()
	if bus.get_report(selected) == null:
		selected = reports[0].id if not reports.is_empty() else ""

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.2
	col.add_child(T.label(SurveyReport.FIRM.to_upper(), "display_bold", 22, T.TEXT))
	var status := T.label(status_text(), "body", 16, T.CYAN if bus.survey_running() else T.DIM)
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.add_child(_action("REQUEST SURVEY", "Request", SurveyReport.CALLED, false, request))
	buttons.add_child(_action("MARK JOB COMPLETE", "Complete", SurveyReport.FINAL, true, complete))
	col.add_child(buttons)
	col.add_child(T.columns([["REPORT", 0], ["JOINTS", 80], ["GRADE", 80]]))
	var list := T.list()
	col.add_child(list.get_parent())
	if reports.is_empty():
		var none := T.label("No surveys yet. The surveyors drop in unannounced while a job is on, or call them in.",
				"body", 16, T.DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(none)
	for i in reports.size():
		list.add_child(_row(reports[i], i % 2 == 1))
	add_child(col)
	add_child(_docket(bus.get_report(selected)))


## The line under the firm's name: who's on site, or what the buttons can do.
func status_text() -> String:
	if bus.survey_running():
		var s := bus.current_survey()
		var n: int = s.get("joints", []).size()
		return "Surveyors on site: %s of %d joint%s." % [_kind_words(StringName(s.get("kind", ""))),
				n, "" if n == 1 else "s"]
	var why := bus.why_not(SurveyReport.CALLED)
	return "Call the surveyors in for a look at the work so far." if why == "" else why + "."


static func _kind_words(kind: StringName) -> String:
	var r := SurveyReport.new()
	r.kind = kind
	return r.kind_name()


static func grade_colour(g: String) -> Color:
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


static func joint_colour(grade: String) -> Color:
	match grade:
		"PASS":
			return T.GOOD
		"MARGINAL":
			return T.AMBER
		"FAIL":
			return T.BAD
	return T.DIM


func _action(text: String, node_name: String, kind: StringName, filled: bool, on_press: Callable) -> Button:
	var b := T.button(text, filled, 18, false, glass)
	b.name = node_name
	var why := bus.why_not(kind)
	b.disabled = why != ""
	b.tooltip_text = why
	b.pressed.connect(on_press)
	return b


func _row(rep: SurveyReport, alt: bool) -> Control:
	var when := "%s  ·  %s" % [rep.id, rep.job_id] if rep.job_id != "" else rep.id
	var r := T.row([T.cell_text(rep.kind_name(), when), T.cell(str(rep.scanned()), 80, T.TEXT),
			T.cell(rep.grade, 80, grade_colour(rep.grade), "mono_bold")], alt, glass)
	r.name = "Row_" + rep.id.validate_node_name()
	if rep.id == selected:
		var st := (r.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		st.border_width_left = 4
		st.border_color = T.ORANGE
		r.add_theme_stylebox_override("panel", st)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	r.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pick(rep.id))
	return r


func _docket(rep: SurveyReport) -> Control:
	var d := T.docket("Survey report", rep.id if rep else "", glass)
	var body: VBoxContainer = d.body
	(d.panel as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	(d.panel as Control).size_flags_stretch_ratio = 1.3
	if rep == null:
		body.add_child(T.label("Pick a report to read it.", "body", 17, T.DIM))
		return d.panel
	var ink := T.TEXT if glass else T.INK
	var dim := T.DIM if glass else T.INK_DIM
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var big := T.figure("Grade", rep.grade, grade_colour(rep.grade), glass)
	big.name = "Grade"
	head.add_child(big)
	head.add_child(T.figure("Average", "%d" % roundi(rep.average), T.TEXT, glass))
	head.add_child(T.figure("Scanned", "%d / %d" % [rep.scanned(), rep.joints_on_job], T.TEXT, glass))
	body.add_child(head)
	var verdict := T.label(verdict_text(rep), "body_medium", 17, ink)
	verdict.name = "Verdict"
	verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(verdict)
	body.add_child(T.label("%d PASS  ·  %d MARGINAL  ·  %d FAIL" % [rep.passed, rep.marginal, rep.failed],
			"mono_medium", 15, dim))
	body.add_child(T.label("JOINTS SCANNED", "display_medium", 15, dim))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 4)
	scroll.add_child(lines)
	body.add_child(scroll)
	if rep.lines.is_empty():
		lines.add_child(T.label("No finished joints to scan.", "body", 15, dim))
	for line in rep.lines:
		lines.add_child(_line(line, ink, dim))
	return d.panel


## The docket's verdict sentence.
static func verdict_text(rep: SurveyReport) -> String:
	if rep.kind == SurveyReport.FINAL:
		if rep.accepted:
			return "Work accepted. The job is cleared for handover to the client."
		return "Work not accepted: %d joint%s failed. The job is back in progress for rework." % [
				rep.failed, "" if rep.failed == 1 else "s"]
	if rep.failed > 0:
		return "%d joint%s failed and must be put right before the final survey." % [rep.failed, "" if rep.failed == 1 else "s"]
	if rep.marginal > 0:
		return "No failures; %d marginal joint%s worth another look." % [rep.marginal, "" if rep.marginal == 1 else "s"]
	return "No issues found in the work scanned."


func _line(line: Dictionary, ink: Color, dim: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var top := HBoxContainer.new()
	var what := T.label(SurveyDesk.joint_words(line), "body", 15, ink)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	what.clip_text = true
	top.add_child(what)
	var score := int(line.get("score", -1))
	top.add_child(T.label("%d" % score if score >= 0 else "–", "mono_bold", 15, ink))
	var g := str(line.get("grade", ""))
	top.add_child(T.tag(g if g != "UNGRADED" else "NOT GRADED", joint_colour(g), 13))
	box.add_child(top)
	for f: Dictionary in line.get("faults", []):
		var l := T.label("  ·  " + str(f.get("text", f.get("code", ""))), "body", 14, dim)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	return box


func _on_started(_kind: StringName, _job_id: String, _joints: Array) -> void:
	refresh()


func _on_finished(rep: SurveyReport) -> void:
	selected = rep.id
	refresh()


func _on_job_state(_id: String, _a: String, _b: String) -> void:
	refresh()


func _on_active_job(_id: String) -> void:
	refresh()
