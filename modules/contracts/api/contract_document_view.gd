class_name ContractDocumentView
extends VBoxContainer
## Draws one job pack document (ContractJobPack) as a sheet in the terminal's look: a title,
## tags, then headed sections of lines. Any module may add one to its own screen:
##   ContractDocumentView.new(bus.document(job_id, "spec:c1"), glass)
## Small type on purpose (beenster, 0.3.14: "a smaller font and layout if it helps to put
## more information on the screen").

const T := preload("res://modules/ui/api/terminal_kit.gd")
const TONE_COLOURS: Dictionary = {"plain": T.STEEL, "good": T.GOOD, "bad": T.BAD, "warn": T.ORANGE, "info": T.CYAN}

var doc: Dictionary
var glass := true


func _init(p_doc: Dictionary, p_glass := true) -> void:
	doc = p_doc
	glass = p_glass
	name = "Document_" + String(doc.get("id", "")).validate_node_name()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	_fill()


func _fill() -> void:
	var ink := T.TEXT if glass else T.INK
	var dim := T.DIM if glass else T.INK_DIM
	if doc.is_empty():
		add_child(T.label("No document.", "body", 14, dim))
		return
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var title := T.label(String(doc.get("title", "")), "display_bold", 18, ink)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if String(doc.get("ref", "")) != "":
		head.add_child(T.label(String(doc.get("ref", "")), "mono_medium", 12, dim))
	add_child(head)
	var tags: Array = doc.get("tags", [])
	if not tags.is_empty():
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 6)
		for t: Dictionary in tags:
			row.add_child(T.tag(String(t.get("text", "")), tone_colour(String(t.get("tone", "plain"))), 12))
		add_child(row)
	for s: Dictionary in doc.get("sections", []):
		add_child(T.label(String(s.get("heading", "")).to_upper(), "display_medium", 12, dim))
		for line: String in s.get("lines", []):
			var l := T.label(line, "body", 14, ink)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			add_child(l)


static func tone_colour(tone: String) -> Color:
	return TONE_COLOURS.get(tone, T.STEEL)


## The document as plain text, for tests and logs.
static func text_of(d: Dictionary) -> String:
	var out := PackedStringArray([String(d.get("title", ""))])
	for s: Dictionary in d.get("sections", []):
		out.append(String(s.get("heading", "")).to_upper())
		for line: String in s.get("lines", []):
			out.append("  " + line)
	return "\n".join(out)
