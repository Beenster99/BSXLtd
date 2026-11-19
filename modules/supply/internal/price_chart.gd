extends Control
## A price history chart: one line per series over the same days, a dashed line for the
## catalogue's list price, today's value at the right edge, the days a deal ran shaded.
## Series: [{name, colour, values: PackedFloat32Array, deals: PackedByteArray (1 on deal days),
## bold: bool}]. Drawn, not built from nodes, so it is cheap to redraw on every edit.

var series: Array[Dictionary] = []
## The catalogue price (0 = none drawn).
var reference := 0.0
## Days the values cover (the x axis), and the font size.
var days := 90
var font_size := 14
var title := ""
var unit_text := "CR each"

const GRID := Color(0.3, 0.45, 0.6, 0.25)
const AXIS := Color(0.55, 0.65, 0.75)
const DEAL := Color(0.5, 0.9, 0.5, 0.07)


func set_data(new_series: Array[Dictionary], ref: float, span_days: int, chart_title: String, units: String) -> void:
	series = new_series
	reference = ref
	days = span_days
	title = chart_title
	unit_text = units
	queue_redraw()


func _draw() -> void:
	var f := ThemeDB.fallback_font
	var fs := font_size
	var left := float(fs) * 5.2
	var right := float(fs) * 7.5
	var top := float(fs) * 2.2
	var bottom := float(fs) * 1.8
	var area := Rect2(left, top, maxf(size.x - left - right, 10.0), maxf(size.y - top - bottom, 10.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.07, 0.11))
	draw_string(f, Vector2(8, fs * 1.2), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, fs - 1, Color(0.9, 0.9, 0.86))
	draw_string(f, Vector2(8, fs * 1.2), unit_text, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 16, fs - 3, AXIS)
	if series.is_empty():
		draw_string(f, area.get_center() - Vector2(80, 0), "Pick a line to see its prices", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, AXIS)
		return
	var lo := INF
	var hi := -INF
	for s in series:
		for v in (s.values as PackedFloat32Array):
			lo = minf(lo, v)
			hi = maxf(hi, v)
	if reference > 0.0:
		lo = minf(lo, reference)
		hi = maxf(hi, reference)
	if not is_finite(lo) or hi <= lo:
		hi = lo + 1.0
	var pad := (hi - lo) * 0.08
	lo -= pad
	hi += pad
	var y_of := func(v: float) -> float: return area.end.y - (v - lo) / (hi - lo) * area.size.y
	# Grid: five price lines, a line a month (30 days) or a week on short spans.
	for i in 5:
		var v := lerpf(lo, hi, i / 4.0)
		var y: float = y_of.call(v)
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), GRID, 1.0)
		draw_string(f, Vector2(4, y + fs * 0.35), _short(v), HORIZONTAL_ALIGNMENT_RIGHT, left - 10, fs - 2, AXIS)
	var tick := 30 if days > 60 else 7
	var d := 0
	while d <= days:
		var x := area.end.x - float(d) / float(maxi(days - 1, 1)) * area.size.x
		if x >= area.position.x - 1:
			draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), GRID, 1.0)
			var lab := "today" if d == 0 else ("%d mo" % (d / 30) if tick == 30 else "%d d" % d)
			draw_string(f, Vector2(x - fs * 2.0, area.end.y + fs * 1.3), lab, HORIZONTAL_ALIGNMENT_CENTER, fs * 4.0, fs - 2, AXIS)
		d += tick
	# Deal days, shaded under the first (cheapest today) series that ran one.
	for s in series:
		var marks: PackedByteArray = s.get("deals", PackedByteArray())
		var n := marks.size()
		for i in n:
			if marks[i] == 1:
				var x0 := area.position.x + float(i) / float(maxi(n - 1, 1)) * area.size.x
				var w := area.size.x / float(maxi(n - 1, 1))
				draw_rect(Rect2(x0 - w * 0.5, area.position.y, w, area.size.y), Color(s.colour, 0.07))
	if reference > 0.0:
		var y: float = y_of.call(reference)
		var x := area.position.x
		while x < area.end.x:
			draw_line(Vector2(x, y), Vector2(minf(x + 8, area.end.x), y), Color(1, 1, 1, 0.35), 1.0)
			x += 14
		draw_string(f, Vector2(area.end.x + 6, y - 2), "list", HORIZONTAL_ALIGNMENT_LEFT, right, fs - 3, Color(1, 1, 1, 0.5))
	# The series, faint first, bold on top; today's value labelled at the right.
	var labels: Array = []
	for pass_bold in [false, true]:
		for s in series:
			if bool(s.get("bold", false)) != pass_bold:
				continue
			var vals: PackedFloat32Array = s.values
			var n := vals.size()
			if n < 2:
				continue
			var pts := PackedVector2Array()
			for i in n:
				pts.append(Vector2(area.position.x + float(i) / float(n - 1) * area.size.x, y_of.call(vals[i])))
			draw_polyline(pts, Color(s.colour, 1.0 if pass_bold else 0.75), 3.0 if pass_bold else 1.6, true)
			labels.append([pts[n - 1].y, s])
	labels.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var last_y := -INF
	for l: Array in labels:
		var y := maxf(float(l[0]), last_y + fs)
		last_y = y
		var s: Dictionary = l[1]
		var vals: PackedFloat32Array = s.values
		draw_string(f, Vector2(area.end.x + 6, y + fs * 0.35), "%s %s" % [_short(vals[vals.size() - 1]), str(s.name)],
				HORIZONTAL_ALIGNMENT_LEFT, right - 6, fs - 3, s.colour)


static func _short(v: float) -> String:
	if absf(v) >= 1000000.0:
		return "%.2fM" % (v / 1000000.0)
	if absf(v) >= 10000.0:
		return "%.1fk" % (v / 1000.0)
	if absf(v) >= 100.0:
		return "%d" % roundi(v)
	return "%.2f" % v
