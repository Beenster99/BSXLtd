extends PanelContainer
## TIME-LAPSE (master plan 6.6: "a time-lapse of the build"): the ship in the berth drawn side on
## and from above, every piece filling in at the moment its job was done, played through in
## twenty seconds and round again. The pieces still to come are a faint outline; each stage has
## its colour. Below, the clock of the build and how far the replay has got.

const T := preload("res://modules/ui/api/terminal_kit.gd")

## Seconds one play-through takes, and the pause at the end.
const PLAY_SECONDS := 20.0
const HOLD_SECONDS := 3.0
const STAGE_COLOURS := {"frame": Color("8fa3b3"), "plates": Color("6fc8e8"), "fittings": Color("e8c25a"),
		"wiring": Color("ff9a4d"), "pipes": Color("7fd47a")}

var bus: Object
var fs := 15
var _canvas: Control
var _caption: Label
var _t := 0.0
## [side rect, top rect, job, stage] per part, in ship space (m).
var _parts: Array = []
var _bounds := AABB()
var _for := ""
var _times: Dictionary = {}
var _end := 1.0


func setup(bots_bus: Object, density: float) -> void:
	bus = bots_bus
	fs = maxi(12, int(density * 0.1))
	name = "TimeLapse"
	add_theme_stylebox_override("panel", T.box(Color(0.02, 0.05, 0.09), Color.TRANSPARENT, 0, fs * 0.5))
	var col := VBoxContainer.new()
	add_child(col)
	_caption = T.label("", "mono_medium", fs - 1, T.TEXT)
	col.add_child(_caption)
	_canvas = Control.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.draw.connect(_draw_ship)
	col.add_child(_canvas)


func _process(delta: float) -> void:
	_t += delta
	if _t > PLAY_SECONDS + HOLD_SECONDS:
		_t = 0.0
	_load()
	_canvas.queue_redraw()


## Picks up the build in the berth: its parts' outlines and when each job was done.
func _load() -> void:
	var build := Modules.bus("build")
	var cid := str(build.get("current")) if build else ""
	if cid != _for:
		_for = cid
		_parts.clear()
		if cid == "":
			return
		var bp: Object = build.call("blueprint", cid)
		var pl: BuildPlan = build.call("plan", cid)
		if bp == null or pl == null:
			return
		_bounds = bp.get("bounds")
		var model: PartModel = bp.get("model")
		for id: int in model.parts:
			var b: AABB = bp.call("box_of", id)
			var j := int(pl.job_of.get(id, 0))
			_parts.append([Rect2(b.position.z, -b.end.y, b.size.z, b.size.y), Rect2(b.position.z, b.position.x, b.size.z, b.size.x),
					j, str(pl.jobs[j].stage)])
	# When each job was done: the bots' clock; a job done with no time (by hand, before the
	# bots came) goes in plan order at the start.
	_times.clear()
	var rec: Dictionary = (bus.get("lapse") as Dictionary).get(cid, {})
	_end = 1.0
	for k: String in rec:
		_times[int(k)] = float(rec[k])
		_end = maxf(_end, float(rec[k]))
	if build and cid != "":
		for j: int in (build.call("active") as Dictionary).get("landed", []):
			if bool(build.call("job_finished", j, cid)) and not _times.has(j):
				_times[j] = 0.0
	var now := float((bus.get("build_clock") as Dictionary).get(cid, _end))
	_end = maxf(_end, now)
	var shown := _end * clampf(_t / PLAY_SECONDS, 0.0, 1.0)
	var done := 0
	for j: int in _times:
		if float(_times[j]) <= shown:
			done += 1
	_caption.text = "TIME-LAPSE · %s · %s of %s worked · %d jobs done" % [
			str((build.call("progress", cid) as Dictionary).get("design_name", "")).to_upper() if cid != "" else "BERTH EMPTY",
			_span(shown), _span(_end), done]


func _draw_ship() -> void:
	var size := _canvas.size
	if _parts.is_empty() or size.x < 10.0:
		_canvas.draw_string(T.font("body_medium"), Vector2(fs, fs * 2), "Nothing in the build berth.", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, T.DIM)
		return
	var shown := _end * clampf(_t / PLAY_SECONDS, 0.0, 1.0)
	# Side view on top, plan below, each fitted to half the height.
	var pad := float(fs)
	var len := maxf(_bounds.size.z, 1.0)
	var half := (size.y - pad * 3.0) * 0.5
	var sx := minf((size.x - pad * 2.0) / len, half / maxf(_bounds.size.y, 1.0))
	var sp := minf((size.x - pad * 2.0) / len, half / maxf(_bounds.size.x, 1.0))
	var s := minf(sx, sp)
	var ox := (size.x - len * s) * 0.5 - _bounds.position.z * s
	var side_y := pad + half * 0.5 + (_bounds.end.y + _bounds.position.y) * 0.5 * s
	var top_y := pad * 2.0 + half * 1.5 - (_bounds.position.x + _bounds.end.x) * 0.5 * s
	for p: Array in _parts:
		var j := int(p[2])
		var in_at: float = _times.get(j, INF)
		var on := in_at <= shown
		var c: Color = STAGE_COLOURS.get(str(p[3]), T.TEXT)
		var r: Rect2 = p[0]
		var side := Rect2(ox + r.position.x * s, side_y + r.position.y * s, maxf(r.size.x * s, 1.0), maxf(r.size.y * s, 1.0))
		var rt: Rect2 = p[1]
		var top := Rect2(ox + rt.position.x * s, top_y + rt.position.y * s, maxf(rt.size.x * s, 1.0), maxf(rt.size.y * s, 1.0))
		if on:
			var fresh := clampf(1.0 - (shown - in_at) / maxf(_end * 0.04, 1.0), 0.0, 1.0)
			var col := c.lerp(Color.WHITE, fresh * 0.6)
			col.a = 0.55
			_canvas.draw_rect(side, col)
			_canvas.draw_rect(top, col)
		else:
			var faint := Color(c, 0.08)
			_canvas.draw_rect(side, faint, false, 1.0)
			_canvas.draw_rect(top, faint, false, 1.0)
	_canvas.draw_string(T.font("mono_medium"), Vector2(pad, pad), "SIDE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 3, T.DIM)
	_canvas.draw_string(T.font("mono_medium"), Vector2(pad, pad * 2.0 + half), "PLAN", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 3, T.DIM)
	# The replay's progress along the bottom.
	var bar := Rect2(pad, size.y - pad * 0.6, size.x - pad * 2.0, pad * 0.25)
	_canvas.draw_rect(bar, Color(0.15, 0.18, 0.22))
	_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_t / PLAY_SECONDS, 0.0, 1.0), bar.size.y)), T.ORANGE)


static func _span(s: float) -> String:
	if s < 60.0:
		return "%d s" % roundi(s)
	if s < 3600.0:
		return "%d min" % roundi(s / 60.0)
	return "%d h %02d min" % [int(s / 3600.0), int(fmod(s, 3600.0) / 60.0)]
