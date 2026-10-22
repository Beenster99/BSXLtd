class_name TradesSpecSheet
extends Control
## A spec sheet as a paper doc (beenster, 2026-10-22), on the right of the wrist's Specs
## channel: the part you're looking at (or the one the joint you're on holds) typed up on
## works paper: what it is, its slot, mass and size, every joint holding it with what its tool
## is set to, and the joint you're on marked. Looking at nothing, the sheet is the ship's
## fastener schedule. A slight tilt, a punched margin and a BSX stamp make it read as paper.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const PAPER := Color("efe9da")
const PAPER_EDGE := Color("d8cfb8")
const INK := Color("23272c")
const INK_DIM := Color("6b6a64")
const RED := Color("b8322a")
## The sheet's size (pixels) and tilt (degrees).
const SIZE := Vector2(420, 560)
const TILT_DEG := -1.2

var station: TradesShipJoints
var paper: PanelContainer
var _body: VBoxContainer


func _init(p_station: TradesShipJoints) -> void:
	station = p_station
	name = "SpecSheet"
	custom_minimum_size = SIZE + Vector2(20, 20)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper = PanelContainer.new()
	paper.name = "Paper"
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.border_color = PAPER_EDGE
	st.set_border_width_all(1)
	st.shadow_color = Color(0, 0, 0, 0.35)
	st.shadow_size = 6
	st.shadow_offset = Vector2(3, 4)
	st.content_margin_left = 34
	st.content_margin_right = 22
	st.content_margin_top = 20
	st.content_margin_bottom = 18
	paper.add_theme_stylebox_override("panel", st)
	paper.position = Vector2(10, 10)
	paper.size = SIZE
	paper.custom_minimum_size = SIZE
	paper.pivot_offset = SIZE * 0.5
	paper.rotation = deg_to_rad(TILT_DEG)
	add_child(paper)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 4)
	paper.add_child(_body)
	# Punched holes down the left margin.
	for y: float in [0.18, 0.5, 0.82]:
		var hole := Hole.new()
		hole.position = paper.position + Vector2(16, SIZE.y * y)
		add_child(hole)
	_fill()


## Text on the sheet (tests).
func text() -> String:
	var out := PackedStringArray()
	for l in find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return "\n".join(out)


func _fill() -> void:
	_line("BSX LTD  ·  SPECIFICATION SHEET", "display_bold", 18, INK)
	var lines := station.inspect_lines() if station else PackedStringArray()
	var joint: FastenerPoint = station.points[station.aimed] if station and station.aimed >= 0 else null
	if lines.is_empty():
		_schedule()
		return
	_line("DOC  SPEC-%s   REV A" % (FastenerPoint.slot_of(joint.joint_id) if joint else "PART").to_upper(), "mono_medium", 13, INK_DIM)
	_rule()
	_line(lines[0], "display_bold", 30, INK)
	for i in range(1, lines.size()):
		var l := lines[i]
		if l.strip_edges() == "":
			continue
		var heading := l == l.to_upper() and not l.contains("  ")
		_line(l, "display_bold" if heading else "mono_medium", 17 if heading else 13, INK)
	if joint:
		_rule()
		_line("YOU ARE ON", "display_bold", 15, RED)
		_line("%s  %s" % [joint.joint_id, TradesShipJoints.spec_line(joint)], "mono_medium", 15, RED)
	_stamp()


## Looking at nothing: the ship's fastener schedule.
func _schedule() -> void:
	_line("DOC  SPEC-SHIP   REV A", "mono_medium", 13, INK_DIM)
	_rule()
	_line("FASTENER SCHEDULE", "display_bold", 30, INK)
	var seen := {}
	if station:
		for f in station.points:
			if TradesShipJoints.is_practice(f):
				continue
			var key := "%s|%s" % [f.kind, f.spec]
			if seen.has(key):
				seen[key][0] += 1
				continue
			seen[key] = [1, f]
	if seen.is_empty():
		_line("No ship in the bay.", "mono_medium", 15, INK_DIM)
	for key: String in seen:
		var row: Array = seen[key]
		_line("%2d x %s" % [row[0], TradesShipJoints.spec_line(row[1])], "mono_medium", 15, INK)
	_line("Look at a part or a joint to see its sheet.", "body_medium", 15, INK_DIM)
	_stamp()


func _line(text: String, face: String, size: int, colour: Color) -> Label:
	var l := T.label(text, face, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = SIZE.x - 60
	_body.add_child(l)
	return l


func _rule() -> void:
	var r := ColorRect.new()
	r.color = Color(INK, 0.6)
	r.custom_minimum_size = Vector2(0, 2)
	_body.add_child(r)


## A rubber stamp, a little crooked, at the foot of the sheet.
func _stamp() -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 56)
	_body.add_child(holder)
	var stamp := Label.new()
	stamp.text = "BSX LTD  ISSUED"
	stamp.add_theme_font_override("font", T.font("display_bold"))
	stamp.add_theme_font_size_override("font_size", 22)
	stamp.add_theme_color_override("font_color", Color(RED, 0.75))
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = Color(RED, 0.75)
	box.set_border_width_all(3)
	box.set_content_margin_all(6)
	stamp.add_theme_stylebox_override("normal", box)
	stamp.position = Vector2(SIZE.x - 260, 8)
	stamp.rotation = deg_to_rad(-7.0)
	holder.add_child(stamp)


## A punched hole in the margin.
class Hole:
	extends Control

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 7.0, Color("3a3e44"))
		draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 20, Color(0, 0, 0, 0.4), 1.5)
