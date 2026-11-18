class_name YardTabletScreen
extends Control
## The beam tablet's screen (drawn into its SubViewport): the piece in front of it seen from
## its front (its own +Z), each part's outline and each joint still holding, by kind; a strip
## with its name, weight and joints left. With nothing in front: the BSX card.

const BG := Color(0.02, 0.05, 0.07)
const GRID := Color(0.2, 0.55, 0.7, 0.18)
const INK := Color(0.55, 0.95, 1.0)
const DIM := Color(0.4, 0.7, 0.8, 0.7)
const ORANGE := Color(1.0, 0.55, 0.15)
## Joint kinds' colours and names.
const KINDS := {
	ConnectionData.Kind.BOLT: [Color(1.0, 0.78, 0.25), "BOLTS"],
	ConnectionData.Kind.RIVET: [Color(0.82, 0.86, 0.9), "RIVETS"],
	ConnectionData.Kind.WELD: [Color(1.0, 0.45, 0.12), "WELDS"],
	ConnectionData.Kind.CONNECTOR: [Color(0.4, 1.0, 0.5), "PLUGS"],
	ConnectionData.Kind.SPOT: [Color(0.9, 0.5, 1.0), "SPOTS"],
}

var tablet: YardTablet


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), BG)
	var font := ShipKit.mono_font()
	var step := s.y / 10.0
	var x := 0.0
	while x < s.x:
		draw_line(Vector2(x, 0), Vector2(x, s.y), GRID, 1.0)
		x += step
	var y := 0.0
	while y < s.y:
		draw_line(Vector2(0, y), Vector2(s.x, y), GRID, 1.0)
		y += step
	var head := s.y * 0.075
	draw_string(font, Vector2(s.x * 0.03, head * 1.25), "BSX LTD  BEAM TABLET", HORIZONTAL_ALIGNMENT_LEFT, -1, int(head * 0.8), ORANGE)
	var body := tablet.reading if tablet and is_instance_valid(tablet.reading) else null
	if body == null:
		draw_string(font, Vector2(s.x * 0.03, s.y * 0.55), "AIM AT THE WORK", HORIZONTAL_ALIGNMENT_LEFT, -1, int(head), INK)
		draw_string(font, Vector2(s.x * 0.03, s.y * 0.55 + head * 1.4), "TO READ ITS PARTS AND JOINTS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(head * 0.6), DIM)
		return
	var model := body.model
	# The piece's front view: fit every part's box into the drawing area.
	var area := Rect2(s.x * 0.03, head * 2.0, s.x * 0.62, s.y - head * 2.6)
	var boxes: Array[Rect2] = []
	var bounds := Rect2()
	for id: int in model.parts:
		var collider := model.part_collider(id)
		if collider == null:
			continue
		var b := collider.transform * model.part_box(id)
		var r := Rect2(Vector2(b.position.x, -b.end.y), Vector2(b.size.x, b.size.y))
		boxes.append(r)
		bounds = r if bounds.size == Vector2.ZERO else bounds.merge(r)
	var scale := minf(area.size.x / maxf(bounds.size.x, 0.01), area.size.y / maxf(bounds.size.y, 0.01)) * 0.92
	var offset := area.get_center() - bounds.get_center() * scale
	for r in boxes:
		var drawn := Rect2(r.position * scale + offset, r.size * scale)
		draw_rect(drawn, Color(INK, 0.08))
		draw_rect(drawn, Color(INK, 0.75), false, 2.0)
	var counts: Dictionary = {}
	for c: ConnectionData in model.connections:
		counts[c.kind] = int(counts.get(c.kind, 0)) + 1
		var at := Vector2(c.local_position.x, -c.local_position.y) * scale + offset
		var colour: Color = (KINDS.get(c.kind, [INK, ""]) as Array)[0]
		if c.kind == ConnectionData.Kind.WELD:
			var seam := Vector2(c.seam_up.x, -c.seam_up.y) * c.seam_size.x * 0.5 * scale
			draw_line(at - seam, at + seam, colour, maxf(3.0, s.y * 0.012))
		else:
			draw_circle(at, maxf(3.0, s.y * 0.012), colour)
	# The strip: what it is, what it weighs, what still holds it.
	var tx := s.x * 0.68
	var name_text := String(body.name).to_upper().replace("_", " ")
	draw_string(font, Vector2(tx, head * 2.6), name_text.left(16), HORIZONTAL_ALIGNMENT_LEFT, -1, int(head * 0.75), INK)
	var kg := 0.0
	for id: int in model.parts:
		kg += (model.parts[id] as PartData).mass
	draw_string(font, Vector2(tx, head * 3.7), "%d PARTS  %.0f KG" % [model.parts.size(), kg], HORIZONTAL_ALIGNMENT_LEFT, -1, int(head * 0.6), DIM)
	var row := head * 5.2
	for kind: int in KINDS:
		if not counts.has(kind):
			continue
		var k: Array = KINDS[kind]
		draw_circle(Vector2(tx + head * 0.3, row - head * 0.25), head * 0.22, k[0])
		draw_string(font, Vector2(tx + head * 0.8, row), "%d %s" % [counts[kind], k[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, int(head * 0.65), INK)
		row += head * 1.15
	var left := model.connections.size()
	draw_string(font, Vector2(tx, s.y - head * 0.8), "FREE" if left == 0 else "%d TO UNDO" % left, HORIZONTAL_ALIGNMENT_LEFT, -1, int(head * 0.75), ORANGE)
