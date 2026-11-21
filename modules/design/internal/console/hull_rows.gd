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


## PAINT AND MARKINGS (the outside designer, stage 4), under the design's name when nothing is
## picked: base and trim colours, a pattern, a stripe down her sides and its height, her name and
## hull number painted on, the client's livery in one go, and back to bare alloy.
static func livery(bus: DesignBus) -> Control:
	var rec := bus.library.current
	var col := VBoxContainer.new()
	col.name = "LiveryRows"
	col.add_theme_constant_override("separation", 3)
	var l := rec.livery
	col.add_child(T.label("PAINT AND MARKINGS", "display_bold", 16, T.ORANGE))
	var set_l := func(fields: Dictionary) -> void:
		bus.editor.do({"op": "set_meta", "fields": {"livery": fields}})
	for which: Array in [["base", "BASE", DesignLivery.base(l)], ["trim", "TRIM", DesignLivery.trim(l)], ["stripe", "STRIPE", null]]:
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 3)
		col.add_child(row)
		var lbl := T.label(which[1], "display_medium", 13, T.DIM)
		lbl.custom_minimum_size.x = 58
		row.add_child(lbl)
		var now := str(l.get(which[0], ""))
		for sw: String in DesignLivery.SWATCHES:
			var key: String = which[0]
			row.add_child(chip("Livery_%s_%s" % [key, sw.substr(1)], sw, sw == now, func() -> void:
				set_l.call({key: sw})))
		if which[0] == "stripe" and now != "":
			var off := T.button("NONE", false, 13)
			off.name = "Livery_stripe_none"
			off.pressed.connect(func() -> void: set_l.call({"stripe": null}))
			row.add_child(off)
	var pats := HFlowContainer.new()
	pats.add_theme_constant_override("h_separation", 3)
	col.add_child(pats)
	for pat: String in DesignLivery.PATTERNS:
		var b := T.button(str(DesignLivery.PATTERN_NAMES[pat]).to_upper(), false, 13, str(l.get("pattern", "plain")) == pat)
		b.name = "Livery_pattern_" + pat
		b.pressed.connect(func() -> void: set_l.call({"pattern": pat}))
		pats.add_child(b)
	if str(l.get("stripe", "")) != "":
		for at: String in DesignLivery.STRIPES:
			var b := T.button("STRIPE " + at.to_upper(), false, 13, str(l.get("stripe_at", "mid")) == at)
			b.name = "Livery_stripe_at_" + at
			b.pressed.connect(func() -> void: set_l.call({"stripe_at": at}))
			pats.add_child(b)
	var marks := HFlowContainer.new()
	marks.add_theme_constant_override("h_separation", 3)
	col.add_child(marks)
	var show := T.button("NAME ON HULL", false, 13, bool(l.get("show_name", false)))
	show.name = "Livery_show_name"
	show.pressed.connect(func() -> void: set_l.call({"show_name": not bool(l.get("show_name", false))}))
	marks.add_child(show)
	var num := LineEdit.new()
	num.name = "Livery_number"
	num.placeholder_text = "Hull number"
	num.text = str(l.get("number", ""))
	num.custom_minimum_size.x = 120
	num.text_submitted.connect(func(t: String) -> void: set_l.call({"number": t.strip_edges() if t.strip_edges() != "" else null}))
	marks.add_child(num)
	var client := str(rec.order.get("client", ""))
	if client != "":
		var cb := T.button("CLIENT LIVERY", false, 13)
		cb.name = "Livery_client"
		cb.pressed.connect(func() -> void:
			var sector := str(rec.order.get("sector", (ShipClients.TABLE.get(client, {}) as Dictionary).get("sector", "trade")))
			set_l.call(DesignLivery.for_client(client, sector)))
		marks.add_child(cb)
	if not l.is_empty():
		var bare := T.button("BARE ALLOY", false, 13)
		bare.name = "Livery_bare"
		bare.pressed.connect(func() -> void: bus.editor.do({"op": "set_meta", "fields": {"livery_set": {}}}))
		marks.add_child(bare)
	return col

## HULL SHAPE (the outside designer, stage 2): her nose, stern, wings, fins, pods and fairings,
## each a button that picks it, and ADD for each kind.
static func shapes(bus: DesignBus, pick: Callable) -> Control:
	var rec := bus.library.current
	var col := VBoxContainer.new()
	col.name = "ShapeRows"
	col.add_theme_constant_override("separation", 3)
	col.add_child(T.label("HULL SHAPE", "display_bold", 16, T.ORANGE))
	if not rec.shapes.is_empty():
		var have := HFlowContainer.new()
		have.add_theme_constant_override("h_separation", 3)
		col.add_child(have)
		var ids := rec.shapes.keys()
		ids.sort()
		for sid: String in ids:
			var b := T.button(DesignShape.describe(rec.shapes[sid]).to_upper(), false, 13)
			b.name = "Shape_" + sid
			b.pressed.connect(func() -> void: pick.call(sid))
			have.add_child(b)
	var adds := HFlowContainer.new()
	adds.add_theme_constant_override("h_separation", 3)
	col.add_child(adds)
	for type: String in DesignShape.TYPES:
		if type in DesignShape.ENDS and not DesignShape.end_shape(rec, type).is_empty():
			continue
		var b := T.button("ADD " + str(DesignShape.NAMES[type]).to_upper(), false, 13)
		b.name = "AddShape_" + type
		b.pressed.connect(func() -> void:
			var sid := add_shape(bus, type)
			if sid != "":
				pick.call(sid))
		adds.add_child(b)
	return col

## Adds a shape of `type` where it sits best on her (a wing amidships, a fin and pods aft). Returns
## its id.
static func add_shape(bus: DesignBus, type: String) -> String:
	var rec := bus.library.current
	var fp := bus.frame_plan()
	var st: Array = fp.get("stations", [])
	if rec == null or st.is_empty():
		return ""
	var body: Array = fp.get("body", [0, st.size() - 1])
	var z0 := float(st[int(body[0])].z)
	var z1 := float(st[int(body[1])].z)
	var z := (z0 + z1) * 0.5
	match type:
		"fin":
			z = z1 - minf(2.0, (z1 - z0) * 0.25)
		"pod":
			z = lerpf(z0, z1, 0.7)
	var id := rec.peek_id("s")
	var before := rec.shapes.size()
	bus.editor.do({"op": "add_shape", "shape": DesignShape.make(type, snappedf(z, 0.25))})
	if rec.shapes.size() == before and not bus.is_shared():
		return ""
	# In a crew the host adds it a moment later, under the same id: pick it now and the
	# menus show it as it lands.
	return id

## A shape picked: each of its sizes with - and +, where it sits along her, MIRROR, the face it
## stands on, REMOVE.
static func shape_edit(bus: DesignBus, id: String, remove: Callable) -> Control:
	var rec := bus.library.current
	if rec == null or not rec.shapes.has(id):
		var gone := VBoxContainer.new()
		gone.name = "ShapeEdit"
		gone.add_child(T.label("That shape is not on her: taken off, or still on its way.", "body", 14, T.DIM))
		return gone
	var s: Dictionary = rec.shapes[id]
	var type := str(s.type)
	var col := VBoxContainer.new()
	col.name = "ShapeEdit"
	col.add_theme_constant_override("separation", 3)
	col.add_child(T.label("%s   %s" % [DesignShape.describe(s).to_upper(), DesignRecord.tag(id)], "display_bold", 18, T.ORANGE))
	col.add_child(T.label("Built as frames and plates, bolted to her rings.", "body", 13, T.DIM))
	var set_s := func(fields: Dictionary) -> void:
		bus.editor.do({"op": "set_shape", "id": id, "fields": fields})
	var rows: Array = []
	if not type in DesignShape.ENDS:
		rows.append(["z", "ALONG", -200.0, 200.0, 0.25])
	for f: Array in DesignShape.FIELDS.get(type, []):
		if f[0] == "at" and type == "fairing" and str(s.get("face", "roof")) != "side":
			continue
		if f[0] == "x" and type == "fairing" and str(s.get("face", "roof")) == "side":
			continue
		rows.append([f[0], f[1], f[3], f[4], f[5]])
	for r: Array in rows:
		var key: String = r[0]
		var now := DesignShape.field(s, key) if key != "z" else float(s.get("z", 0.0))
		var h := HBoxContainer.new()
		col.add_child(h)
		var l := T.label(str(r[1]), "display_medium", 13, T.DIM)
		l.custom_minimum_size.x = 120
		h.add_child(l)
		for dir: float in [-1.0, 1.0]:
			var b := T.button("-" if dir < 0.0 else "+", false, 13)
			b.name = "Shape_%s_%s" % [key, "minus" if dir < 0.0 else "plus"]
			var to := clampf(snappedf(now + dir * float(r[4]), float(r[4])), float(r[2]), float(r[3]))
			b.disabled = is_equal_approx(to, now)
			b.pressed.connect(func() -> void: set_s.call({key: to}))
			if dir < 0.0:
				h.add_child(b)
				var v := T.label("%.2f" % now if float(r[4]) < 0.1 else "%.1f" % now, "mono", 13, T.TEXT)
				v.name = "Shape_%s_value" % key
				v.custom_minimum_size.x = 48
				h.add_child(v)
			else:
				h.add_child(b)
	var opts := HFlowContainer.new()
	opts.add_theme_constant_override("h_separation", 3)
	col.add_child(opts)
	if type in ["wing", "pod"]:
		var m := T.button("BOTH SIDES", false, 13, DesignShape.mirrored(s))
		m.name = "ShapeMirror"
		m.pressed.connect(func() -> void: set_s.call({"mirror": not DesignShape.mirrored(s)}))
		opts.add_child(m)
	for face: String in DesignShape.FACES.get(type, []):
		var b := T.button("ON THE " + face.to_upper(), false, 13, str(s.get("face", "")) == face)
		b.name = "ShapeFace_" + face
		b.pressed.connect(func() -> void: set_s.call({"face": face}))
		opts.add_child(b)
	var rm := T.button("REMOVE (DEL)", false, 15)
	rm.name = "ShapeRemove"
	rm.pressed.connect(remove)
	col.add_child(rm)
	return col

## A part on the skin: where it is (roof, port side, nose...), TURN a quarter about the hull's
## normal, and nudges along the ship and across its face.
static func skin_row(bus: DesignBus, m: Dictionary) -> Control:
	var id := str(m.id)
	var col := VBoxContainer.new()
	col.name = "SkinRow"
	col.add_child(T.label("On the %s" % DesignOutside.face_name(m), "body", 14, T.DIM))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	col.add_child(row)
	var edge := int(m.get("edge", 0))
	var pt := bus.catalog.part(str(m.type))
	var stands := pt != null and DesignOutside.standing(m, pt, DesignOutside.surface(bus.frame_plan(), m).get("normal", Vector3.UP))
	var buttons := [["SkinTurn", "TURN", {"spin": wrapf(float(m.get("spin", 0.0)) + PI * 0.5, -PI, PI)}],
			["SkinStand", "LAY FLAT" if stands else "STAND UP", {"stand": not stands}]]
	if edge >= 0:
		buttons.append(["SkinFore", "FORE", {"z": float(m.z) - 0.25}])
		buttons.append(["SkinAft", "AFT", {"z": float(m.z) + 0.25}])
		buttons.append(["SkinLeft", "ACROSS -", {"t": clampf(float(m.get("t", 0.5)) - 0.1, 0.0, 1.0)}])
		buttons.append(["SkinRight", "ACROSS +", {"t": clampf(float(m.get("t", 0.5)) + 0.1, 0.0, 1.0)}])
	else:
		buttons.append(["SkinLeft", "PORT", {"x": float(m.get("x", 0.0)) - 0.25}])
		buttons.append(["SkinRight", "STARBOARD", {"x": float(m.get("x", 0.0)) + 0.25}])
		buttons.append(["SkinUp", "UP", {"y": float(m.get("y", 0.0)) + 0.25}])
		buttons.append(["SkinDown", "DOWN", {"y": float(m.get("y", 0.0)) - 0.25}])
	for spec: Array in buttons:
		var b := T.button(spec[1], false, 14)
		b.name = spec[0]
		var fields: Dictionary = spec[2]
		b.pressed.connect(func() -> void: bus.editor.do({"op": "set_mount", "id": id, "fields": fields}))
		row.add_child(b)
	return col


## The shape a built part belongs to, from its path ("shape_<id>_<s|p|c>/..."), "" for none.
static func shape_of_path(path: String) -> String:
	if not path.begins_with("shape_"):
		return ""
	return path.get_slice("/", 0).trim_prefix("shape_").get_slice("_", 0)


## The nose or stern a skin panel ("<z>:<edge>") is part of, "" when it is on her body.
static func end_shape_at(bus: DesignBus, panel_id: String) -> String:
	var rec := bus.library.current
	var fp := bus.frame_plan()
	var st: Array = fp.get("stations", [])
	if rec == null or st.is_empty() or panel_id == "":
		return ""
	var k := DesignFrame.bay_at(fp, float(panel_id.get_slice(":", 0)))
	var body: Array = fp.get("body", [0, st.size() - 1])
	var type := "nose" if k >= 0 and k < int(body[0]) else ("stern" if k >= int(body[1]) else "")
	if type == "":
		return ""
	for sid: String in rec.shapes:
		if str(rec.shapes[sid].type) == type:
			return sid
	return ""


## The wing, fin, pod or fairing a ray (ship space) meets first: {id, dist}, {} for none.
static func pick_shape(bus: DesignBus, from: Vector3, dir: Vector3) -> Dictionary:
	var best := {}
	for limb: Dictionary in bus.frame_plan().get("limbs", []):
		var hit: Variant = DesignShape.limb_box(limb).grow(0.05).intersects_ray(from, dir)
		if hit == null:
			continue
		var d := from.distance_to(hit as Vector3)
		if best.is_empty() or d < float(best.dist):
			best = {"id": str(limb.shape), "dist": d}
	return best


## Every hull row that is not about one panel: HULL SHAPE (pick or add a shape) and PAINT AND
## MARKINGS, as at the console with nothing picked.
static func whole_hull(bus: DesignBus, pick: Callable) -> Control:
	var col := VBoxContainer.new()
	col.name = "WholeHull"
	col.add_theme_constant_override("separation", 8)
	col.add_child(shapes(bus, pick))
	col.add_child(outline(bus))
	col.add_child(livery(bus))
	return col


## HULL OUTLINE, deck by deck, as at the console's hull tools: ROUND THE ROOMS draws it round
## that deck's rooms, CLEAR goes back to the proposed hull. Corners are dragged on the plan; out
## here the mouse wheel on her side pushes a section out or in.
static func outline(bus: DesignBus) -> Control:
	var col := VBoxContainer.new()
	col.name = "OutlineRows"
	col.add_theme_constant_override("separation", 3)
	var rec := bus.library.current
	if rec == null:
		return col
	col.add_child(T.label("HULL OUTLINE", "display_bold", 16, T.ORANGE))
	var decks := {}
	for r: Dictionary in rec.rooms.values():
		decks[int(r.deck)] = true
	var ds := decks.keys()
	ds.sort()
	for d: int in ds:
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 3)
		col.add_child(row)
		var drawn := not rec.hull_outline(d).is_empty()
		var lbl := T.label("DECK %d  %s" % [d, "DRAWN" if drawn else "PROPOSED"], "display_medium", 13, T.DIM)
		lbl.custom_minimum_size.x = 120
		row.add_child(lbl)
		var round_b := T.button("ROUND THE ROOMS", false, 13)
		round_b.name = "Outline_round_%d" % d
		round_b.pressed.connect(func() -> void:
			var pts := rec.hull_round_rooms(d, 0.5)
			if not pts.is_empty():
				bus.editor.do({"op": "set_hull", "deck": d, "points": pts}))
		row.add_child(round_b)
		if drawn:
			var clear_b := T.button("CLEAR", false, 13)
			clear_b.name = "Outline_clear_%d" % d
			clear_b.pressed.connect(func() -> void: bus.editor.do({"op": "set_hull", "deck": d, "points": []}))
			row.add_child(clear_b)
	return col
