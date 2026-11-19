extends ModuleTest
## Design Room: the structure. The room proposes a ship's structure from its rooms and hull:
## frame rings at stations along her, stringers, node blocks and welds, the skin riveted on,
## glass over the bridge, the outer doors cut and framed. It is built with Void Salvage's frame
## kit as parts and joints, priced by its members, skin and joints, drawn on the holotable and
## walked in.
##   tools/run_tests.sh design

const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")
const WalkBuild := preload("res://modules/design/internal/walk/walk_build.gd")


func run_tests() -> void:
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	var rec := bus.library.create("Frame test")
	check(DesignFrame.propose(rec).is_empty(), "nothing to frame in an empty design")
	for op: Dictionary in [
		{"op": "add_room", "room": {"id": "r1", "type": "bridge", "deck": 0, "x": -2, "z": -8, "w": 4, "d": 3}},
		{"op": "add_room", "room": {"id": "r2", "type": "corridor", "deck": 0, "x": -1, "z": -5, "w": 2, "d": 8}},
		{"op": "add_room", "room": {"id": "r3", "type": "cargo", "deck": 0, "x": -3, "z": 3, "w": 6, "d": 6}},
		{"op": "add_room", "room": {"id": "r4", "type": "quarters", "deck": 1, "x": -2, "z": -2, "w": 4, "d": 4}},
		{"op": "add_room", "room": {"id": "r5", "type": "airlock", "deck": 0, "x": 1, "z": -3, "w": 2, "d": 2}},
		{"op": "add_door", "door": {"a": "r1", "b": "r2", "deck": 0, "x": 0, "z": -5}},
		{"op": "add_door", "door": {"a": "r2", "b": "r3", "deck": 0, "x": 0, "z": 3}},
		{"op": "add_door", "door": {"a": "r2", "b": "r5", "deck": 0, "x": 1, "z": -2}},
		{"op": "add_door", "door": {"a": "r5", "b": "", "deck": 0, "x": 3, "z": -2}},
		{"op": "add_door", "door": {"a": "r3", "b": "", "deck": 0, "x": 0, "z": 9}},
	]:
		bus.editor.do(op)
	var plan := DesignFrame.propose(rec)
	var st: Array = plan.stations
	var gaps_ok := true
	for i in range(1, st.size()):
		var gap := float(st[i].z) - float(st[i - 1].z)
		gaps_ok = gaps_ok and absf(gap - float(rec.structure.spacing)) < 0.5
	check(st.size() >= 8 and gaps_ok, "a frame station every %.0f m along her: %d" % [rec.structure.spacing, st.size()])
	check(st.all(func(s): return (s.profile as PackedVector2Array).size() == DesignFrame.SIDES and _convex(s.profile)),
			"every ring is an eight-sided convex section")
	var inside := true
	var why := ""
	for r: Dictionary in rec.rooms.values():
		for z in [float(r.z), float(r.z) + float(r.d)]:
			var hull := _rect_at(st, z)
			var y0 := int(r.deck) * rec.deck_height
			var room := Rect2(float(r.x), y0, float(r.w), rec.deck_height)
			if not hull.grow(-0.2).encloses(room):
				inside = false
				why = "%s at z %.1f: %s in %s" % [r.id, z, room, hull]
	check(inside, "every room stands inside the hull with room for the frame %s" % why)
	check(plan.style == "channel", "a standard frame is Void Salvage's channel style")
	check(not (plan.glass as Dictionary).is_empty() and (plan.glass as Dictionary).has("0:0"), "glass over the bridge")
	var side: Array = (plan.openings as Array).filter(func(o): return int(o.edge) == DesignFrame.STARBOARD)
	var stern: Array = (plan.openings as Array).filter(func(o): return int(o.get("cap", -1)) == 1)
	check(side.size() == 1 and stern.size() == 1, "the airlock's door cut in her side, the cargo door in her stern")

	# Built with the frame kit, as parts and joints.
	var body := RigidBody3D.new()
	var kit := ShipKit.new(body)
	kit.model = PartModel.new(body, true)
	var h := DesignFrame.build(plan, kit)
	var names := {}
	for p: PartData in kit.model.parts.values():
		names[p.part_name] = int(names.get(p.part_name, 0)) + 1
	check(int(names.get("FrameNode", 0)) > 0 and int(names.get("FrameRing", 0)) > 0 and int(names.get("Stringer", 0)) > 0,
			"node blocks, rings and stringers: %s" % [names])
	check(h.welds.size() > 50 and h.rivets.size() > 100, "welded frame, riveted skin: %d welds, %d rivets" % [h.welds.size(), h.rivets.size()])
	check(h.jambs.size() >= 2, "the side door framed with posts and rails: %d" % h.jambs.size())
	check(h.cap_plates.size() > 1, "the stern plate cut round its door: %d pieces" % h.cap_plates.size())
	var glass := kit.model.parts.values().filter(func(p): return p.kind == PartData.Kind.GLASS)
	check(glass.size() >= 3, "glass panels over the bridge: %d" % glass.size())
	var ring: PartData = h.rings[2][DesignFrame.STARBOARD]
	check(DesignFrame.describe(ring).begins_with("Frame ring, frame 2, starboard side"), DesignFrame.describe(ring))
	body.free()

	# The spec counts what it is made of.
	var fc := DesignFrame.counts(plan)
	var t := DesignTotals.compute(rec, bus.catalog)
	var welds: Array = t.lines.filter(func(l): return l.id == "welds")
	check(welds.size() == 1 and int(welds[0].qty) == int(fc.welds) and float(welds[0].cost) > 0.0,
			"the welds are on the parts list and priced: %s" % [welds])

	# Designers change it: closer frames, a heavier frame. Undo takes it back.
	bus.editor.do({"op": "set_meta", "fields": {"structure": {"spacing": 1.0, "frame": "heavy"}}})
	var closer := DesignFrame.propose(rec)
	check((closer.stations as Array).size() > st.size() and closer.style == "bowhead",
			"a metre apart in the heavy frame: %d stations, %s" % [(closer.stations as Array).size(), closer.style])
	bus.editor.undo()
	check((DesignFrame.propose(rec).stations as Array).size() == st.size(), "undo puts the frame back")

	# Designers shape it: a panel glazed or plated, a section pushed out. Undo takes it back.
	var mid := (float(st[4].z) + float(st[5].z)) * 0.5
	bus.editor.do({"op": "set_frame", "key": DesignFrame.panel_key(mid, DesignFrame.STARBOARD), "value": {"glass": true}})
	bus.editor.do({"op": "set_frame", "key": DesignFrame.panel_key((float(st[0].z) + float(st[1].z)) * 0.5, 0), "value": {"glass": false}})
	var shaped := DesignFrame.propose(rec)
	check((shaped.glass as Dictionary).has("4:%d" % DesignFrame.STARBOARD) and not (shaped.glass as Dictionary).has("0:0"),
			"a window in her side, the bridge roof plated over: %s" % [shaped.glass.keys()])
	var r0: Rect2 = st[3].rect
	bus.editor.do({"op": "set_frame", "key": DesignFrame.section_key(float(st[3].z)), "value": {"grow": [0.0, 1.0, 0.5, 0.0]}})
	var r1: Rect2 = DesignFrame.propose(rec).stations[3].rect
	check(is_equal_approx(r1.size.x, r0.size.x + 1.0) and is_equal_approx(r1.end.y, r0.end.y + 0.5) and is_equal_approx(r1.position.x, r0.position.x),
			"her section pushed out a metre to starboard and half up: %s -> %s" % [r0, r1])
	var copy := DesignRecord.from_dict(rec.to_dict())
	check(copy.frame_edits == rec.frame_edits and copy.frame_edits.size() == 3, "the changes are saved with the design")
	for i in 3:
		bus.editor.undo()
	check(rec.frame_edits.is_empty() and (DesignFrame.propose(rec).glass as Dictionary) == (plan.glass as Dictionary), "undo takes the changes back")

	# Walk inside it.
	var room := Node3D.new()
	add_child(room)
	var f := Furnishing.new()
	room.add_child(f)
	f.setup(bus, Furnishing.stand_in_walls())
	f.open_walk()
	await frames(2)
	var walk: Node3D = f.walk
	var b: WalkBuild = walk.builder
	check(b.frame_body != null and b.frame_model.parts.size() > 100, "walk-inside builds the real frame")
	check(walk.find_child("Sill_%s" % str(rec.doors.values().filter(func(d): return str(d.b) == "" and float(d.x) == 3.0)[0].id), true, false) != null,
			"a sill across to the skin at the airlock door")
	var w: Node3D = walk.world
	var from := w.global_transform * Vector3(20, 1.5, 6.0)
	var q := PhysicsRayQueryParameters3D.create(from, w.global_transform * Vector3(0, 1.5, 6.0), WalkBuild.LAYER)
	var hit := w.get_world_3d().direct_space_state.intersect_ray(q)
	var part := b.frame_part(hit.get("collider"), int(hit.get("shape", -1))) if hit else null
	check(part != null and part.part_name == "HullPlate", "from outside you see her hull plates: %s" % [part.part_name if part else hit])

	# Shape it from inside: G at the corridor's outer wall glazes the panel behind it.
	walk.body.position = Vector3(0.0, 1.0, 1.0)
	walk.body.rotation.y = -PI * 0.5  # facing +X
	walk.camera.rotation.x = 0.0
	walk.set("_pitch", 0.0)
	await _physics(4)
	var fa: Dictionary = walk.frame_aimed()
	check(not fa.is_empty() and int(fa.edge) == DesignFrame.STARBOARD and int(fa.bay) >= 0, "the hull side behind the wall: %s" % [fa])
	check(walk.glass_here() and rec.frame_edits.size() == 1 and (DesignFrame.propose(rec).glass as Dictionary).has("%d:%d" % [int(fa.bay), DesignFrame.STARBOARD]),
			"G puts a window there: %s" % [rec.frame_edits])
	await frames(2)
	walk.camera.rotation.x = 0.0
	await _physics(2)
	check(walk.glass_here() and rec.frame_edits.size() == 1 and not (DesignFrame.propose(rec).glass as Dictionary).has("%d:%d" % [int(fa.bay), DesignFrame.STARBOARD]),
			"G again plates it over")
	bus.editor.undo()
	bus.editor.undo()
	# The wheel at her hull plates, from outside: her section there pushed out to starboard.
	walk.body.position = Vector3(7.0, 1.0, 6.0)
	walk.body.rotation.y = PI * 0.5  # facing -X
	await _physics(4)
	var fo: Dictionary = walk.frame_aimed()
	var before: Rect2 = walk.builder.frame_plan.stations[int(fo.get("station", 0))].rect
	check(not fo.is_empty() and fo.part != null and walk.push_hull(1), "the wheel on her plating: %s" % [fo.get("part")])
	var after: Rect2 = DesignFrame.propose(rec).stations[int(fo.get("station", 0))].rect
	check(is_equal_approx(after.end.x, before.end.x + 0.25) and is_equal_approx(after.position.x, before.position.x),
			"pushed out a quarter metre to starboard: %s -> %s" % [before, after])
	bus.editor.undo()
	f.close_walk()
	await frames(2)

	# With every wall panel showing her, opening the sample (dozens of edits) and an edit stay
	# quick: the views read the rules once, when they next draw (it took 21 s and dropped the
	# crew in co-op).
	var t0 := Time.get_ticks_msec()
	bus.open_sample()
	var t_open := Time.get_ticks_msec() - t0
	t0 = Time.get_ticks_msec()
	bus.editor.do({"op": "add_room", "room": {"id": "zz", "type": "cargo", "deck": 0, "x": 30, "z": 30, "w": 4, "d": 4}})
	var t_do := Time.get_ticks_msec() - t0
	check(t_open < 3000 and t_do < 200, "the sample opens in %d ms, an edit takes %d ms" % [t_open, t_do])
	room.queue_free()
	await frames(2)


## The hull's section at z, between the stations either side (x across, y up).
func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


static func _rect_at(st: Array, z: float) -> Rect2:
	for i in range(1, st.size()):
		if z <= float(st[i].z) + 0.001:
			var a: Rect2 = st[i - 1].rect
			var b: Rect2 = st[i].rect
			var t := clampf((z - float(st[i - 1].z)) / maxf(float(st[i].z) - float(st[i - 1].z), 0.001), 0.0, 1.0)
			return Rect2(a.position.lerp(b.position, t), a.size.lerp(b.size, t))
	return st[st.size() - 1].rect


static func _convex(p: PackedVector2Array) -> bool:
	var sign := 0.0
	for i in p.size():
		var c := (p[(i + 1) % p.size()] - p[i]).cross(p[(i + 2) % p.size()] - p[(i + 1) % p.size()])
		if absf(c) < 1e-6:
			continue
		if sign == 0.0:
			sign = signf(c)
		elif signf(c) != sign:
			return false
	return true
