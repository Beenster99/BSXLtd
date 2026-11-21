extends ModuleTest
## The outside designer, stage 4 (plan 3.10): paint and markings. A base and trim colour in a
## pattern over the skin's panels, a stripe down both sides, her name and hull number painted
## on, a client's livery, single panels painted by hand; the skin built in those colours, the
## painters on the parts list, and all of it from the console.
##   tools/run_tests.sh design

const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")


func _hull_colours(plan: Dictionary) -> Dictionary:
	var body := RigidBody3D.new()
	var kit := ShipKit.new(body)
	kit.model = PartModel.new(body, true)
	DesignFrame.build(plan, kit)
	var out := {}
	for p: PartData in kit.model.parts.values():
		if p.part_name != "HullPlate":
			continue
		for v in kit.model.part_visual(p.id).find_children("*", "MeshInstance3D", true, false) + [kit.model.part_visual(p.id)]:
			var m: Material = (v as MeshInstance3D).get_active_material(0) if v is MeshInstance3D and (v as MeshInstance3D).mesh else null
			if m is StandardMaterial3D:
				out[(m as StandardMaterial3D).albedo_color.to_html(false)] = true
			elif m is ShaderMaterial and (m as ShaderMaterial).get_shader_parameter("albedo") is Vector3:
				# The surface shader takes its albedo in linear colour, as a vec3.
				var a: Vector3 = (m as ShaderMaterial).get_shader_parameter("albedo")
				out[Color(a.x, a.y, a.z).linear_to_srgb().to_html(false)] = true
	body.free()
	return out


func run_tests() -> void:
	Flags.set_flag("design.outside", true)
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	var rec: DesignRecord = bus.library.create("Kestrel Two")
	bus.editor.do({"op": "add_room", "room": {"type": "cargo", "deck": 0, "x": -3, "z": -4, "w": 6, "d": 8}})
	check(not DesignLivery.painted(rec) and DesignLivery.colour(bus.frame_plan(), 0, 0) == null, "a new design is bare alloy")
	var bare_lines := bus.totals().lines.filter(func(l): return str(l.id) == "paint")
	check(bare_lines.is_empty(), "and has no painters on its parts list")

	# The livery: set, merged, undone.
	bus.editor.do({"op": "set_meta", "fields": {"livery": {"base": "#1f4e79", "trim": "#d9dcd8", "pattern": "plain"}}})
	check(str(rec.livery.base) == "#1f4e79", "a base colour")
	var plan := bus.frame_plan()
	check((DesignLivery.colour(plan, 1, DesignFrame.ROOF_EDGE) as Color).is_equal_approx(Color("#1f4e79")), "plain: every panel in the base colour")
	bus.editor.do({"op": "set_meta", "fields": {"livery": {"pattern": "chamfers"}}})
	plan = bus.frame_plan()
	check((DesignLivery.colour(plan, 1, 1) as Color).is_equal_approx(Color("#d9dcd8")) and (DesignLivery.colour(plan, 1, 2) as Color).is_equal_approx(Color("#1f4e79")),
			"chamfers: the cut corners in the trim, the sides in the base")
	bus.editor.do({"op": "set_meta", "fields": {"livery": {"pattern": "bands"}}})
	plan = bus.frame_plan()
	check(DesignLivery.colour(plan, 0, 2) != DesignLivery.colour(plan, 1, 2), "bands: bay by bay")
	bus.editor.undo()
	check(str(rec.livery.pattern) == "chamfers", "undo puts the pattern back")
	var paint := bus.totals().lines.filter(func(l): return str(l.id) == "paint")
	check(not paint.is_empty() and float(paint[0].cost) > 0.0, "the painters on the parts list: %s" % [paint])

	# Built in those colours.
	var cols := _hull_colours(bus.frame_plan())
	var near := func(want: String) -> bool:
		return cols.keys().any(func(k): return (Color(k) - Color(want)).v < 0.02 and absf(Color(k).r - Color(want).r) < 0.02 and absf(Color(k).b - Color(want).b) < 0.02)
	check(near.call("#1f4e79") and near.call("#d9dcd8"), "the plates are built in the base and trim: %s" % [cols.keys()])

	# One panel painted by hand, over the livery, and it stays a metal plate.
	var st: Array = bus.frame_plan().stations
	var mid := (float(st[1].z) + float(st[2].z)) * 0.5
	bus.editor.do({"op": "set_frame", "key": DesignFrame.panel_key(mid, DesignFrame.STARBOARD), "value": {"paint": "#d46a1e"}})
	plan = bus.frame_plan()
	check((DesignLivery.colour(plan, 1, DesignFrame.STARBOARD) as Color).is_equal_approx(Color("#d46a1e")) and DesignFrame.panel_at(plan, 1, DesignFrame.STARBOARD) == "metal",
			"a panel painted orange by hand, still a hull plate")
	bus.editor.undo()

	# Stripe and lettering.
	bus.editor.do({"op": "set_meta", "fields": {"livery": {"stripe": "#c8a032", "stripe_at": "low", "show_name": true, "number": "bsx-07"}}})
	var holder := Node3D.new()
	add_child(holder)
	DesignLivery.decorate(bus.frame_plan(), rec, holder)
	check(holder.get_node_or_null("Stripe_%d" % DesignFrame.STARBOARD) != null and holder.get_node_or_null("Stripe_%d" % DesignFrame.PORT) != null,
			"a stripe down both sides")
	var mark := holder.get_node_or_null("Marking_%d" % DesignFrame.STARBOARD) as Label3D
	check(mark != null and "KESTREL TWO" in mark.text and "BSX-07" in mark.text, "her name and number painted on: %s" % (mark.text if mark else ""))
	var port := holder.get_node_or_null("Marking_%d" % DesignFrame.PORT) as Node3D
	check(mark != null and port != null and mark.position.x > 0.0 and port.position.x < 0.0, "on both sides")
	holder.queue_free()

	# A client's livery: the same every time for one client, different for another.
	var a := DesignLivery.for_client("kettle_rock", "mining")
	check(a == DesignLivery.for_client("kettle_rock", "mining") and a != DesignLivery.for_client("tallow_reserve", "military"),
			"a client's livery is its own: %s" % [a])

	# Saved and loaded; bare alloy again in one step.
	var back := DesignRecord.from_dict(rec.to_dict())
	check(back.livery == rec.livery, "the livery saves with the design")
	bus.editor.do({"op": "set_meta", "fields": {"livery_set": {}}})
	check(rec.livery.is_empty(), "BARE ALLOY takes it all off")
	bus.editor.undo()
	check(not rec.livery.is_empty(), "and undo puts it back")

	# The console: nothing picked shows PAINT AND MARKINGS.
	var room := Node3D.new()
	add_child(room)
	var cam := Camera3D.new()
	room.add_child(cam)
	cam.current = true
	var fu := Furnishing.new()
	room.add_child(fu)
	fu.setup(bus, Furnishing.stand_in_walls())
	fu.open_console()
	await frames(4)
	var con = fu.console
	con.plan.select("", "")
	await frames(2)
	check(con.find_child("LiveryRows", true, false) != null, "nothing picked: PAINT AND MARKINGS")
	var red := con.find_child("Livery_base_7a2a22", true, false) as Button
	if red:
		red.pressed.emit()
	check(str(rec.livery.get("base", "")) == "#7a2a22", "a swatch sets the base colour")
	await frames(2)
	var two := con.find_child("Livery_pattern_top", true, false) as Button
	if two:
		two.pressed.emit()
	check(str(rec.livery.get("pattern", "")) == "top", "TWO TONE sets the pattern")
	# A panel picked: paint it by hand.
	con.plan.select("panel", "%.2f:%d" % [mid, DesignFrame.ROOF_EDGE])
	await frames(2)
	var sw := con.find_child("PanelPaint_d46a1e", true, false) as Button
	if sw:
		sw.pressed.emit()
	check(str((rec.frame_edits.get(DesignFrame.panel_key(mid, DesignFrame.ROOF_EDGE), {}) as Dictionary).get("paint", "")) == "#d46a1e",
			"a picked panel painted from its swatches")
	await frames(2)
	var arm := con.find_child("Panel_armour", true, false) as Button
	if arm:
		arm.pressed.emit()
	var edit: Dictionary = rec.frame_edits.get(DesignFrame.panel_key(mid, DesignFrame.ROOF_EDGE), {})
	check(str(edit.get("kind", "")) == "armour" and str(edit.get("paint", "")) == "#d46a1e", "made armour, it keeps its paint: %s" % [edit])
	room.queue_free()
	await frames(2)
