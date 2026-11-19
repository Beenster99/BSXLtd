extends PanelContainer
## The MOVING PARTS wall panel: every moving part of the open design with how it moves, its
## opening, time, power and load and whether it moves clear; what fits through the openings
## (MotionBus.BLOCKS); and SET HER DOWN's answer on a flat pad and rough ground, empty and with
## a full hold, with a plan of her feet, the line round them and her centre of mass.

const T := preload("res://modules/ui/api/terminal_kit.gd")

var bus: MotionBus
var px := 150.0
var _body: VBoxContainer
var _queued := false


func setup(motion_bus: MotionBus, px_per_m: float) -> void:
	bus = motion_bus
	px = px_per_m
	name = "MotionWall"
	add_theme_stylebox_override("panel", T.box(T.KIOSK, T.EDGE, 2, 14.0))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)
	bus.report_changed.connect(_queue)
	bus.operate_changed.connect(_queue)
	refresh()


func _exit_tree() -> void:
	if bus:
		if bus.report_changed.is_connected(_queue):
			bus.report_changed.disconnect(_queue)
		if bus.operate_changed.is_connected(_queue):
			bus.operate_changed.disconnect(_queue)


func _queue() -> void:
	if not _queued:
		_queued = true
		refresh.call_deferred()


func _size(base: int) -> int:
	return maxi(12, int(base * px / 150.0))


func refresh() -> void:
	_queued = false
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var r := bus.report()
	_body.add_child(T.label("MOVING PARTS", "display_bold", _size(24), T.TEXT))
	if r.is_empty():
		_body.add_child(T.label("No design open", "body", _size(17), T.DIM))
		return
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	var op := T.button("STOP" if bus.operating else "OPERATE", true, _size(16), bus.operating)
	op.name = "BtnOperate"
	op.pressed.connect(func() -> void: bus.set_operating(not bus.operating))
	bar.add_child(op)
	var down := T.button("LIFT OFF" if bus.grounded else "SET HER DOWN", false, _size(16), bus.grounded)
	down.name = "BtnGround"
	down.pressed.connect(func() -> void: bus.set_grounded(not bus.grounded))
	bar.add_child(down)
	for pad in MotionGround.PADS:
		var b := T.button(str(MotionGround.PAD_NAMES[pad]).to_upper(), false, _size(14), bus.pad == pad)
		b.name = "BtnPad_" + pad
		b.pressed.connect(func() -> void: bus.set_pad(pad, bus.full_hold))
		bar.add_child(b)
	var hold := T.button("HOLD FULL" if bus.full_hold else "HOLD EMPTY", false, _size(14), bus.full_hold)
	hold.name = "BtnHold"
	hold.pressed.connect(func() -> void: bus.set_pad(bus.pad, not bus.full_hold))
	bar.add_child(hold)
	_body.add_child(bar)
	var movers: Array = r.movers
	if movers.is_empty():
		_body.add_child(T.label("Nothing in this design moves yet: add doors, a ramp, landing gear, a crane...", "body", _size(17), T.DIM))
	else:
		_body.add_child(T.columns([["Part", 0], ["Moves", _w(170)], ["Opening", _w(140)], ["Time", _w(70)],
				["Power", _w(80)], ["Load", _w(90)], ["", _w(90)]]))
		var alt := false
		for mv: Dictionary in movers:
			var s: Dictionary = mv.spec
			var o: Vector2 = s.get("open", Vector2.ZERO)
			var clash: Array = r.clashes.get(mv.id, [])
			var kind := str(s.kind)
			var how := str(MotionTable.KIND_NAMES.get(kind, kind.trim_prefix("door_").capitalize()))
			var rng := float(s.get("range", 0.0))
			if kind in ["hinge_out", "hinge_up"]:
				how += " %d°" % int(rng)
			elif kind == "spin":
				how += " %d°" % int(MotionMovers.spin_half(mv) * 2.0)
			elif kind == "leg":
				how += " %s m" % _m(MotionMovers.leg_reach(mv))
			_body.add_child(T.row([T.cell_text(str(mv.name), str(s.get("note", ""))), T.cell(how, _w(170)),
					T.cell("%s x %s m" % [_m(o.x), _m(o.y)] if o.x > 0.0 else "-", _w(140)),
					T.cell("%s s" % _m(float(s.get("seconds", 0.0))), _w(70)),
					T.cell("%s kW" % _m(float(s.get("kw", 0.0))), _w(80)),
					T.cell("%s t" % _m(float(s.get("load_kg", 0.0)) / 1000.0) if float(s.get("load_kg", 0.0)) > 0.0 else "-", _w(90)),
					T.tag("CLASH" if not clash.is_empty() else "CLEAR", T.BAD if not clash.is_empty() else T.GOOD, _size(13))], alt))
			alt = not alt
			for c: Dictionary in clash:
				var l := T.label("   " + str(c.text), "body", _size(15), T.BAD)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_body.add_child(l)
	_openings(r.openings)
	_ground(r.ground)


func _w(v: float) -> float:
	return v * px / 150.0


static func _m(v: float) -> String:
	return str(snappedf(v, 0.01))


func _openings(list: Array) -> void:
	if list.is_empty():
		return
	_body.add_child(T.label("THROUGH THE OPENINGS", "display_bold", _size(20), T.TEXT))
	var cols: Array = [["Opening", 0]]
	for b: Dictionary in MotionBus.BLOCKS:
		cols.append([str(b.name), _w(110)])
	_body.add_child(T.columns(cols))
	var alt := false
	for o: Dictionary in list:
		var cells: Array = [T.cell_text(str(o.name), "%s x %s m" % [_m(o.open.x), _m(o.open.y)])]
		for b: Dictionary in MotionBus.BLOCKS:
			var ok := bool(o.fits.get(b.id, false))
			cells.append(T.cell("FITS" if ok else "NO", _w(110), T.GOOD if ok else T.DIM))
		_body.add_child(T.row(cells, alt))
		alt = not alt


func _ground(g: Dictionary) -> void:
	_body.add_child(T.label("SET HER DOWN", "display_bold", _size(20), T.TEXT))
	if g.get("cases", []).is_empty():
		var why := "No landing gear: add legs on the hull to stand her on a pad" if int(g.get("legs", 0)) == 0 \
				else "She can't stand on %d leg%s" % [int(g.legs), "" if int(g.legs) == 1 else "s"]
		_body.add_child(T.label(why, "body", _size(17), T.DIM))
		return
	_body.add_child(T.columns([["Pad", 0], ["Mass", _w(80)], ["Level", _w(90)], ["Clearance", _w(100)],
			["Tips at", _w(90)], ["Heaviest foot", _w(170)]]))
	var alt := false
	for c: Dictionary in g.cases:
		var heavy := 0.0
		var share := 0.0
		for i in g.feet.size():
			heavy = maxf(heavy, float(c.loads[i]))
			share = maxf(share, float(c.loads[i]) / maxf(float(g.feet[i].rated), 1.0))
		var tip := float(c.tip_deg)
		_body.add_child(T.row([T.cell_text(str(MotionGround.PAD_NAMES[c.pad]), "hold full" if c.load == "full" else "hold empty"),
				T.cell("%s t" % _m(float(c.mass) / 1000.0), _w(80)),
				T.cell("LEVEL" if bool(c.level) else "%s°" % _m(c.tilt_deg), _w(90), T.GOOD if bool(c.level) else T.AMBER),
				T.cell("%s m" % _m(c.clearance), _w(100), T.GOOD if float(c.clearance) >= MotionGround.MIN_CLEARANCE else T.BAD),
				T.cell("TIPS" if tip < 0.0 else "%d°" % int(tip), _w(90), T.BAD if tip < 0.0 else (T.GOOD if tip >= MotionGround.MIN_TIP else T.AMBER)),
				T.cell("%s t (%d%%)" % [_m(heavy / 1000.0), int(share * 100.0)], _w(170), T.BAD if share > 1.0 else T.TEXT)], alt))
		alt = not alt
	var plan := FeetPlan.new()
	plan.ground = g
	plan.bus = bus
	plan.custom_minimum_size = Vector2(0, _w(260))
	_body.add_child(plan)


## Her feet from above: the line round them, each foot's load, her centre of mass.
class FeetPlan extends Control:
	var ground: Dictionary
	var bus: MotionBus

	func _draw() -> void:
		var feet: Array = ground.feet
		var c: Dictionary = ground.cases[0]
		for k: Dictionary in ground.cases:
			if k.pad == bus.pad and k.load == ("full" if bus.full_hold else "empty"):
				c = k
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for f: Dictionary in feet:
			lo = lo.min(Vector2(f.at.x, f.at.z))
			hi = hi.max(Vector2(f.at.x, f.at.z))
		var cog := Vector2(c.cog.x, c.cog.z)
		lo = lo.min(cog) - Vector2(2, 2)
		hi = hi.max(cog) + Vector2(2, 2)
		var k2 := minf(size.x / (hi.x - lo.x), size.y / (hi.y - lo.y))
		var off := (size - (hi - lo) * k2) * 0.5
		var to := func(p: Vector2) -> Vector2: return off + (p - lo) * k2
		var pts := PackedVector2Array()
		for f: Dictionary in feet:
			pts.append(Vector2(f.at.x, f.at.z))
		var hull := Geometry2D.convex_hull(pts)
		var tip := float(c.tip_deg)
		var col := T.GOOD if tip >= MotionGround.MIN_TIP else (T.BAD if tip < 0.0 else T.AMBER)
		for i in hull.size() - 1:
			draw_line(to.call(hull[i]), to.call(hull[i + 1]), col, 3.0)
		var font := get_theme_default_font()
		for i in feet.size():
			var f: Dictionary = feet[i]
			var share := float(c.loads[i]) / maxf(float(f.rated), 1.0)
			var fc := T.BAD if share > 1.0 or float(c.loads[i]) < 0.0 else (T.AMBER if share > 0.85 else T.GOOD)
			var p: Vector2 = to.call(Vector2(f.at.x, f.at.z))
			draw_circle(p, 9.0, fc)
			draw_string(font, p + Vector2(12, 5), "%s t" % str(snappedf(float(c.loads[i]) / 1000.0, 0.1)),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 15, T.TEXT)
		var g2: Vector2 = to.call(cog)
		draw_circle(g2, 7.0, col)
		draw_string(font, g2 + Vector2(10, -8), "CENTRE OF MASS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, T.DIM)
