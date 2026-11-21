extends Control
## Rings what a help picture points at: an orange box round each control whose text holds the
## words asked for, and its callout number in a badge at the box's corner (help_shots.gd).

const ORANGE := Color(1.0, 0.55, 0.1)
const BADGE_TEXT := Color(0.05, 0.03, 0.0)

## [number, rect] for each ring.
var _rings: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100


## `specs`: [[number, what], ...]. `what` is the words of one control on the screen, or a list
## of them: the ring goes round them all. Each can be "=WORDS" (the whole text, not part of it),
## end in "#2" (the third match) or "^1" (its parent, ^2 its parent's parent); "%Name" is the
## control of that node name. Returns those
## not found.
func mark(root: Control, specs: Array) -> Array:
	var missing: Array = []
	_rings.clear()
	for s: Array in specs:
		var whats: Array = s[1] if s[1] is Array else [s[1]]
		var r := Rect2()
		var any := false
		for w: String in whats:
			var c := pick(root, w)
			if c == null:
				missing.append(w)
				continue
			var cr := c.get_global_rect()
			r = cr if not any else r.merge(cr)
			any = true
		if any:
			_rings.append([int(s[0]), r.grow(5.0)])
	queue_redraw()
	return missing


## The control `what` names (see mark).
static func pick(root: Node, what: String) -> Control:
	var up := 0
	var nth := 0
	var w := what
	var hat := w.rfind("^")
	if hat > 0 and w.substr(hat + 1).is_valid_int():
		up = int(w.substr(hat + 1))
		w = w.left(hat)
	var hash := w.rfind("#")
	if hash > 0 and w.substr(hash + 1).is_valid_int():
		nth = int(w.substr(hash + 1))
		w = w.left(hash)
	var found: Array = []
	if w.begins_with("%"):
		var n := root.find_child(w.substr(1), true, false)
		if n is Control and (n as Control).is_visible_in_tree():
			found.append(n)
	else:
		var exact := w.begins_with("=")
		found = find_all(root, w.substr(1) if exact else w, exact)
	if found.size() <= nth:
		return null
	var c: Node = found[nth]
	for i in up:
		if c.get_parent() is Control:
			c = c.get_parent()
	return c as Control


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for ring: Array in _rings:
		var r: Rect2 = ring[1]
		draw_rect(r, Color(ORANGE, 0.12), true)
		draw_rect(r, ORANGE, false, 3.0)
		# On the ring's left edge, level with its first line (rings on rows next to each other
		# keep their badges apart).
		var c := Vector2(maxf(r.position.x - 10.0, 16.0), r.position.y + minf(r.size.y * 0.5, 16.0))
		draw_circle(c, 15.0, ORANGE)
		draw_arc(c, 15.0, 0, TAU, 32, Color(0, 0, 0, 0.6), 2.0)
		var t := str(ring[0])
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(font, c + Vector2(-w * 0.5, 7), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BADGE_TEXT)


## The first visible control whose text holds `words` (any case).
static func find_text(root: Node, words: String) -> Control:
	return pick(root, words)


static func find_all(root: Node, words: String, exact := false) -> Array:
	var out: Array = []
	var w := words.to_lower()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		if n is Control and not (n as Control).is_visible_in_tree():
			continue
		var t := ""
		if n is Button:
			t = (n as Button).text
		elif n is Label:
			t = (n as Label).text
		if t != "" and (t.strip_edges().to_lower() == w if exact else t.to_lower().contains(w)):
			out.append(n)
		stack.append_array(n.get_children())
	return out
