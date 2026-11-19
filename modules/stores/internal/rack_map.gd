extends Control
## The stores hall from above, for the warehouse stock screen: both storeys side by side
## (ground floor left, upper deck right), each rack a column of its bays from the yard side
## (bottom) to the back wall (top), every bay shaded by the share of its places in use in the
## rack kind's colour. The chosen part's bays are outlined in orange, the chosen bay in white.
## Goods in is marked on the east (right) of each storey. Click a bay: bay_clicked.

signal bay_clicked(rack: int, bay: int)

const PICK := Color(0.91, 0.47, 0.17)
const BAY_BG := Color(1, 1, 1, 0.05)

var font_size := 12
var kind_colours: Array[Color] = []
var _report: StoresReport
var _selected := ""
var _bay: Array = []
## rack index -> Rect2 per bay (local), for clicks.
var _cells: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func show_report(r: StoresReport, _store: YardRackStore, selected: String, bay: Array) -> void:
	_report = r
	_selected = selected
	_bay = bay
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var at: Vector2 = e.position
	for rack: int in _cells:
		var cells: Array = _cells[rack]
		for b in cells.size():
			if (cells[b] as Rect2).grow(1.0).has_point(at):
				bay_clicked.emit(rack, b)
				accept_event()
				return


## The rect of `bay` of rack `rack` (local), for tests.
func cell_rect(rack: int, bay: int) -> Rect2:
	return _cells[rack][bay] if _cells.has(rack) else Rect2()


func _draw() -> void:
	_cells.clear()
	if _report == null:
		return
	var font: Font = TerminalKit.font("mono_bold")
	var gap := 14.0
	var label_h := font_size * 1.6
	var foot_h := font_size * 1.4
	var storey_w := (size.x - gap) * 0.5
	for storey in 2:
		var x0 := storey * (storey_w + gap)
		var area := Rect2(x0, label_h, storey_w, size.y - label_h - foot_h)
		draw_rect(area, Color(1, 1, 1, 0.025))
		draw_rect(area, Color(0.2, 0.45, 0.65, 0.5), false, 1.0)
		var info: Dictionary = _report.storeys[storey]
		draw_string(font, Vector2(x0, font_size * 1.1), "%s  %d%%" % [StoresReport.STOREY_NAMES[storey].to_upper(),
				roundi(StoresReport.share(int(info.filled), int(info.places)) * 100.0)],
				HORIZONTAL_ALIGNMENT_LEFT, storey_w, font_size, TerminalKit.TEXT)
		draw_string(font, Vector2(x0, size.y - font_size * 0.3), "YARD SIDE ▼", HORIZONTAL_ALIGNMENT_LEFT, storey_w * 0.6,
				font_size - 1, TerminalKit.DIM)
		draw_string(font, Vector2(x0, size.y - font_size * 0.3), "GOODS IN ▶", HORIZONTAL_ALIGNMENT_RIGHT, storey_w,
				font_size - 1, TerminalKit.DIM)
		var racks: Array[int] = []
		for i in _report.racks.size():
			if int(_report.racks[i].storey) == storey:
				racks.append(i)
		if racks.is_empty():
			continue
		# Racks spread across the storey's width; goods in takes the last sixth.
		var lane := area.size.x * 0.84 / racks.size()
		var col_w := lane * 0.62
		for n in racks.size():
			var r := racks[n]
			var rack: Dictionary = _report.racks[r]
			var bays: Array = rack.bays
			var cx := area.position.x + lane * (n + 0.5)
			draw_string(font, Vector2(cx - col_w * 0.5, area.position.y + font_size * 1.05), str(rack.id),
					HORIZONTAL_ALIGNMENT_CENTER, col_w, font_size - 1, kind_colours[int(rack.kind)])
			var top := area.position.y + font_size * 1.4
			var h := (area.end.y - top - 4.0) / maxf(1.0, bays.size())
			var cells: Array[Rect2] = []
			for b in bays.size():
				# Bay 0 is at the yard side: the bottom.
				var cell := Rect2(cx - col_w * 0.5, area.end.y - 4.0 - (b + 1) * h + 1.0, col_w, h - 2.0)
				cells.append(cell)
				var bay: Dictionary = bays[b]
				var fill := StoresReport.share(int(bay.filled), int(bay.places))
				draw_rect(cell, BAY_BG)
				if fill > 0.0:
					draw_rect(cell, Color(kind_colours[int(rack.kind)], 0.15 + 0.75 * fill))
				if _selected != "" and (bay.parts as Dictionary).has(_selected):
					draw_rect(cell.grow(1.0), PICK, false, 2.0)
				if not _bay.is_empty() and int(_bay[0]) == r and int(_bay[1]) == b:
					draw_rect(cell.grow(2.5), Color.WHITE, false, 2.0)
			_cells[r] = cells
		# Goods in, along the east.
		var gi := Rect2(area.position.x + area.size.x * 0.87, area.position.y + font_size * 1.4, area.size.x * 0.1,
				area.size.y - font_size * 1.4 - 4.0)
		draw_rect(gi, Color(1, 1, 1, 0.04))
		draw_rect(gi, Color(1, 1, 1, 0.12), false, 1.0)
