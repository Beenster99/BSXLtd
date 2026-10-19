extends PanelContainer
## HUD card that pops up when a joint is graded: score, grade, points per rule and faults.
## Hidden until the first grade, and again when the joint is taken apart.

const GRADE_COLORS := {
	JointRecord.PASS: Color("6cc070"),
	JointRecord.MARGINAL: Color("f2a33a"),
	JointRecord.FAIL: Color("e0584f"),
	JointRecord.UNGRADED: Color("93a1af"),
}
const RULE_NAMES := {
	"torque": "Torque", "sequence": "Sequence", "fastener": "Fasteners", "threads": "Threads",
	"head": "Head shape", "hole": "Hole fit", "deburr": "Deburring", "seated": "Drawn tight",
	"speed": "Travel speed", "angle": "Torch angle", "arc": "Arc length", "coverage": "Coverage",
	"penetration": "Penetration", "crimp": "Crimps", "strip": "Strip length",
	"continuity": "Continuity", "insulation": "Insulation", "polarity": "Polarity",
}

var shown_joint: StringName
var _box: VBoxContainer


func _ready() -> void:
	name = "QualityScoreCard"
	theme = BsxTheme.get_theme()
	custom_minimum_size = Vector2(420, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = VBoxContainer.new()
	add_child(_box)
	hide()
	var bus := Modules.bus("quality") as QualityBus
	if bus:
		bus.joint_graded.connect(show_record)
		bus.record_dropped.connect(_on_dropped)


func show_record(r: JointRecord) -> void:
	shown_joint = r.joint_id
	for c in _box.get_children():
		c.queue_free()
	var head := BsxTheme.title("%s  %s" % [_score_text(r), r.grade], 40)
	head.name = "Headline"
	head.add_theme_color_override("font_color", GRADE_COLORS.get(r.grade, BsxTheme.TEXT))
	_box.add_child(head)
	_box.add_child(BsxTheme.muted(String(r.joint_id).capitalize()))
	for key in r.breakdown:
		var l := Label.new()
		l.text = "%s  %d" % [RULE_NAMES.get(key, String(key).capitalize()), roundi(r.breakdown[key])]
		_box.add_child(l)
	for f in r.faults:
		var l := Label.new()
		l.text = "• " + str(f.text)
		l.add_theme_color_override("font_color", GRADE_COLORS[JointRecord.FAIL])
		_box.add_child(l)
	show()


func _on_dropped(joint_id: StringName) -> void:
	if joint_id == shown_joint:
		hide()


static func _score_text(r: JointRecord) -> String:
	return "--" if r.score < 0 else "%d/100" % r.score
