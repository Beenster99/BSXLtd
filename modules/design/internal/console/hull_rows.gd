extends RefCounted
## The hull's own controls, shared by the console's 3D view and walk-inside (the outside
## designer): a skin panel's rows (what it is made of, paint, the frames and members round it),
## the colour chips, the ring op, and whether a hull part fits where it is shown.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const PlanView := preload("res://modules/design/internal/views/plan_view.gd")


## A skin panel picked in the 3D view (the outside designer, stage 1): what it is made of, and
## the frame round it: split it with a new frame, move or take out the frames at its ends, take
## out (or put back) the ring girders at its ends and the stringers at its sides.
static func panel(bus: DesignBus, id: String) -> Control:
	var col := VBoxContainer.new()
	col.name = "PanelRows"
	var fp := bus.frame_plan()
	var st: Array = fp.get("stations", [])
	var z := float(id.get_slice(":", 0))
	var e := int(id.get_slice(":", 1))
	var k := DesignFrame.bay_at(fp, z)
	if k < 0 or st.is_empty():
		col.add_child(T.label("That panel is gone: the hull has changed.", "body", 14, T.DIM))
		return col
	var rec := bus.library.current
	var za := float(st[k].z)
	var zb := float(st[k + 1].z)
	var kind := DesignFrame.panel_at(fp, k, e)
	col.add_child(T.label("HULL PANEL   %s" % DesignFrame.EDGE_NAMES[e].to_upper(), "display_bold", 18, T.ORANGE))
	col.add_child(T.label("%s, frames %d to %d, %s m long" % [DesignFrame.PANEL_NAMES[kind], k, k + 1,
			PlanView._m(snappedf(zb - za, 0.1))], "body", 14, T.DIM))
	var mid := (za + zb) * 0.5
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	col.add_child(row)
	for pk: String in DesignFrame.PANEL_KINDS:
		var b := T.button(pk.to_upper(), false, 14, pk == kind)
		b.name = "Panel_" + pk
		b.pressed.connect(func() -> void:
			var was: Dictionary = (rec.frame_edits.get(DesignFrame.panel_key(mid, e), {}) as Dictionary).duplicate()
			was.erase("glass")
			was["kind"] = pk
			bus.editor.do({"op": "set_frame", "key": DesignFrame.panel_key(mid, e), "value": was}))
		row.add_child(b)
	# Paint this one panel by hand (DesignLivery), over the livery.
	var paint_row := HFlowContainer.new()
	paint_row.add_theme_constant_override("h_separation", 4)
	col.add_child(paint_row)
	paint_row.add_child(T.label("PAINT", "display_medium", 14, T.DIM))
	var pkey := DesignFrame.panel_key(mid, e)
	var painted := str((rec.frame_edits.get(pkey, {}) as Dictionary).get("paint", ""))
	for sw: String in DesignLivery.SWATCHES:
		paint_row.add_child(chip("PanelPaint_" + sw.substr(1), sw, sw == painted, func() -> void:
			var was: Dictionary = (rec.frame_edits.get(pkey, {}) as Dictionary).duplicate()
			was["paint"] = sw
			bus.editor.do({"op": "set_frame", "key": pkey, "value": was})))
	if painted != "":
		var clear := T.button("CLEAR", false, 14)
		clear.name = "PanelPaintClear"
		clear.pressed.connect(func() -> void:
			var was: Dictionary = (rec.frame_edits.get(pkey, {}) as Dictionary).duplicate()
			was.erase("paint")
			bus.editor.do({"op": "set_frame", "key": pkey, "value": was if not was.is_empty() else null}))
		paint_row.add_child(clear)
	var frames := HFlowContainer.new()
	frames.add_theme_constant_override("h_separation", 4)
	col.add_child(frames)
	var split := T.button("SPLIT (NEW FRAME)", false, 14)
	split.name = "PanelSplit"
	split.pressed.connect(func() -> void:
		bus.editor.do({"op": "set_frame", "key": DesignFrame.ring_key(mid), "value": {"add": true}}))
	frames.add_child(split)
	for end: Array in [[k, "FORE"], [k + 1, "AFT"]]:
		var i: int = end[0]
		if i <= 0 or i >= st.size() - 1:
			continue
		var at_z := float(st[i].z)
		var take := T.button("REMOVE FRAME " + str(end[1]), false, 14)
		take.name = "RemoveFrame" + str(end[1]).capitalize()
		take.pressed.connect(func() -> void: bus.editor.do(ring_op(rec, at_z, INF)))
		frames.add_child(take)
		for step: float in [-0.25, 0.25]:
			var mv := T.button("FRAME %s %s" % [str(end[1]), "FWD" if step < 0.0 else "BACK"], false, 14)
			mv.name = "MoveFrame%s%s" % [str(end[1]).capitalize(), "Fwd" if step < 0.0 else "Back"]
			mv.pressed.connect(func() -> void: bus.editor.do(ring_op(rec, at_z, at_z + step)))
			frames.add_child(mv)
	var members := HFlowContainer.new()
	members.add_theme_constant_override("h_separation", 4)
	col.add_child(members)
	var specs := [[DesignFrame.member_key(za, e), "RING FORE"], [DesignFrame.member_key(zb, e), "RING AFT"],
			[DesignFrame.stringer_key(mid, e), "STRINGER A"], [DesignFrame.stringer_key(mid, (e + 1) % DesignFrame.SIDES), "STRINGER B"]]
	for spec: Array in specs:
		var key: String = spec[0]
		var gone := rec.frame_edits.has(key)
		var b := T.button(("PUT BACK " if gone else "TAKE OUT ") + str(spec[1]), false, 14, gone)
		b.name = "Member_" + str(spec[1]).replace(" ", "")
		b.pressed.connect(func() -> void:
			bus.editor.do({"op": "set_frame", "key": key, "value": null if gone else {"remove": true}}))
		members.add_child(b)
	return col


## A colour swatch button: a small square of `html`, outlined when it is the one in use.
static func chip(node_name: String, html: String, on: bool, pressed: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(26, 26)
	b.tooltip_text = html
	var c := Color.from_string(html, Color.GRAY)
	for state: String in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, T.box(c if state != "hover" else c.lightened(0.15), T.ORANGE if on else T.EDGE, 3 if on else 1, 3.0))
	b.pressed.connect(pressed)
	return b


## The op that takes the ring at `z` out (to = INF) or moves it to `to`: a ring the designers
## added is moved or dropped by its own edit; a proposed one is taken out by a "remove" edit and
## a new one added where it goes.
static func ring_op(rec: DesignRecord, z: float, to: float) -> Dictionary:
	var ops: Array = []
	var own := ""
	for key: String in rec.frame_edits:
		if key.begins_with("ring:") and bool((rec.frame_edits[key] as Dictionary).get("add", false)) \
				and absf(float(key.get_slice(":", 1)) - z) < DesignFrame.RING_GAP:
			own = key
	if own != "":
		ops.append({"op": "set_frame", "key": own, "value": null})
	else:
		ops.append({"op": "set_frame", "key": DesignFrame.ring_key(z), "value": {"remove": true}})
	if to != INF:
		ops.append({"op": "set_frame", "key": DesignFrame.ring_key(to), "value": {"add": true}})
	return {"op": "batch", "ops": ops}


## Whether a part would fit where it is shown: on the hull, clear of the other parts outside.
static func fits(bus: DesignBus, m: Dictionary, pt: DesignPartType, xf: Transform3D) -> bool:
	var rec := bus.library.current
	var fp := bus.frame_plan()
	if not DesignOutside.on_hull(fp, m) or DesignOutside.overhang(fp, m, xf, pt) > 0:
		return false
	var bx := DesignOutside.box_of(xf, pt)
	for o: Dictionary in rec.mounts.values():
		var op := bus.catalog.part(str(o.type))
		if op == null:
			continue
		var ob := DesignOutside.box_of(DesignRules.mount_transform(rec, o, op, fp), op)
		if DesignOutside.boxes_overlap(bx[0], bx[1], ob[0], ob[1], 0.02):
			return false
	return true


## Where a hull part of `type` goes on the skin along a ray (ship space): the mount's fields,
## snapped along the ship to a quarter of the grid, or {} where the ray misses her.
static func mount_spot(bus: DesignBus, type: String, from: Vector3, dir: Vector3) -> Dictionary:
	var rec := bus.library.current
	if type == "" or rec == null:
		return {}
	var hit := DesignOutside.pick(bus.frame_plan(), from, dir)
	if hit.is_empty():
		return {}
	var m := DesignOutside.anchor(hit, rec)
	var step := maxf(rec.grid * 0.25, 0.05)
	if int(m.edge) >= 0:
		m.z = snappedf(float(m.z), step)
	else:
		m.x = snappedf(float(m.x), step)
		m.y = snappedf(float(m.y), step)
	m["type"] = type
	return m
