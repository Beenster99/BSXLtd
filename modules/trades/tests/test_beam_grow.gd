extends ModuleTest
## trades.beam_grow (beenster, 29 Oct): with the design tablet a beam grows straight out of the
## ship face you click, its length on the wheel (Shift: its section), swung by Q/E and tilted
## by Shift+Q/E, and placed by a second click; a click on a beam's end grows the next one on
## from it. Only the ship and the design's beam ends can be clicked: not the ground. A placed
## beam takes the same keys about the end it grew from. The hologram is drawn as one, everyone
## sees each other's beams as they grow, and the design changes a beam at a time so two players'
## work at once is kept.

func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var saved := {}
	for flag: String in ["trades.beam_designer", "trades.beam_versions", "trades.beam_grow", "trades.beam_clear"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	bus.reset_data()
	var yard: Node3D = load(Router.scene_path(ShipBayBus.SHIPYARD_SCENE)).instantiate()
	add_child(yard)
	await frames(30)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	if rig.designer == null:
		rig.build_designer()
	var d := rig.designer
	rig.set_tool(&"tablet")
	await physics_frames(3)
	var xf := rig.ship_transform()

	# The hologram's look.
	check(d.get_node("Hologram/Ghost").material_override is ShaderMaterial, "beams are drawn as a hologram (its own shader)")

	# A frame node on her starboard side, high up.
	var nodes := d.frame_nodes()
	var bb := ship_bus.ship.bounds
	var top_x := -INF
	for n: Vector3 in nodes:
		top_x = maxf(top_x, n.x)
	var node := Vector3.INF
	for n: Vector3 in nodes:
		if n.x > top_x - 0.1 and absf(n.z - bb.get_center().z) < 3.0 and n.y > 0.5 \
				and (not node.is_finite() or absf(n.z - bb.get_center().z) < absf(node.z - bb.get_center().z)):
			node = n
	check(node.is_finite(), "a node on her starboard side: %s" % [node])

	# Only the ship can be clicked: the ground beside her can't.
	var ground := (xf.affine_inverse() * Vector3.ZERO).y
	_aim(d, xf, Vector3(bb.end.x + 3.0, ground + 1.5, bb.get_center().z), Vector3.DOWN)
	check(d.root_on == "", "pointing at the ground, nothing to grow from")
	d.click(true)
	check(d.draft.is_empty(), "and a click there starts nothing")
	# Her plating can be clicked, and says to strip it.
	_aim(d, xf, node + Vector3(2.0, 0, 0), Vector3.LEFT)
	check(d.root_on == "plate" and d.doing().contains("strip"), "on her plating: %s, %s" % [d.root_on, d.doing()])
	for s: MountSlot in ship_bus.get_slots():
		if s.slot_id.begins_with("plate_") and s.box.grow(0.3).has_point(node):
			for f in s.fasteners:
				ship_bus.note_joint_removed(f.joint_id)
	await physics_frames(2)
	# The plates taken off lie loose where they were: out of the way.
	for p: Node in yard.find_children("Loose_plate_*", "RigidBody3D", true, false):
		(p as RigidBody3D).freeze = true
		(p as RigidBody3D).global_position += Vector3.DOWN * 40.0
	await physics_frames(2)
	_aim(d, xf, node + Vector3(2.0, 0, 0), Vector3.LEFT)
	check(d.root_on == "frame", "with the plates off, on her frame: %s" % d.root_on)
	check(d.root_normal.dot(Vector3.RIGHT) > 0.9, "facing out of her side: %s" % [d.root_normal])

	# A click starts a beam growing straight out of the face.
	d.click(true)
	check(not d.draft.is_empty(), "a click starts a beam")
	_aim(d, xf, node + Vector3(2.0, 0, 0), Vector3.LEFT)
	var e: Vector3 = d.draft_end()[0]
	var root: Vector3 = d.draft.root
	check(absf(root.distance_to(e) - TradesBeamDesigner.GROW_M) < 0.01 and (e - root).normalized().dot(Vector3.RIGHT) > 0.9,
			"it grows a metre straight out of the face")
	d._draw()
	check(d.get_node("Hologram/Ghost").visible, "drawn as it grows")
	d.wheel(-1)
	d.wheel(-1)
	check(is_equal_approx(float(d.draft.length), TradesBeamDesigner.GROW_M + 0.2), "the wheel makes it longer: %.2f m" % float(d.draft.length))
	var sec := d.section
	d.fake_keys = [KEY_SHIFT]
	d.wheel(1)
	check(d.section != sec and is_equal_approx(float(d.draft.length), TradesBeamDesigner.GROW_M + 0.2), "Shift+wheel changes its section")
	d.key(TradesBus.KEY_TURN_RIGHT)
	d.key(TradesBus.KEY_TURN_RIGHT)
	d.fake_keys = []
	check(is_equal_approx(float(d.draft.pitch), 30.0), "Shift+E tilts it")
	d.key(TradesBus.KEY_TURN_LEFT)
	check(is_equal_approx(float(d.draft.yaw), -15.0), "Q swings it")
	e = d.draft_end()[0]
	var dir := (e - root).normalized()
	check(dir.y > 0.45 and dir.y < 0.55, "tilted 30 degrees up: %s" % [dir])
	check(d.doing().contains("Growing") and "\n".join(d.info_lines()).contains("tilted +30°"), "the panel says what it's doing: %s" % d.doing())
	# Right click lets it go; click again and place it.
	d.click(false)
	check(d.draft.is_empty() and d.beams().is_empty(), "right click lets it go")
	_aim(d, xf, node + Vector3(2.0, 0, 0), Vector3.LEFT)
	d.click(true)
	d.wheel(-1)
	_aim(d, xf, node + Vector3(2.0, 0, 0), Vector3.LEFT)
	d.click(true)
	var list := d.beams()
	check(list.size() == 1 and d.draft.is_empty(), "a second click places it")
	var first := int(list[0].id) if list.size() == 1 else -1
	var fb := d.beam(first)
	check(not fb.is_empty() and absf((fb.a as Vector3).distance_to(fb.b) - 1.1) < 0.01, "1.1 m long, from where it was clicked")
	d.run_checks()
	check(not d.loose_ends.any(func(x: Array) -> bool: return x[0] == first and x[1] == 0) and not d.unattached.has(first),
			"its root is held by her frame: %s" % [d.loose_ends])

	# Click its end: the next grows on from it.
	var tip: Vector3 = fb.b
	d.hovered = first
	_aim_at_beam(d, tip - Vector3(0, 0, 1.5), tip)
	check(d.root_on == "end" and d.root_point.is_equal_approx(tip) and d.doing().contains("this end"), "on its end: %s" % d.root_on)
	d.click(true)
	check(not d.draft.is_empty() and (d.draft.normal as Vector3).dot(Vector3.RIGHT) > 0.9, "a new beam grows on along it")
	d.key(TradesBus.KEY_TURN_RIGHT)
	d.key(TradesBus.KEY_TURN_RIGHT)
	d.key(TradesBus.KEY_TURN_RIGHT)
	d.click(true)
	list = d.beams()
	var second := -1
	for b: Dictionary in list:
		if int(b.id) != first:
			second = int(b.id)
	check(list.size() == 2 and (d.beam(second).a as Vector3).is_equal_approx(tip), "placed, joined at the first's end")
	d.run_checks()
	check(not d.unattached.has(second) and not d.loose_ends.any(func(x: Array) -> bool: return x[0] == second and x[1] == 0),
			"held by the first beam, so on the ship")

	# A placed beam: the wheel stretches it, Q/E swing it about its root, Ctrl+Q/E roll it.
	var sb := d.beam(second)
	var l0 := (sb.a as Vector3).distance_to(sb.b)
	d.hovered = second
	d.wheel(-1)
	sb = d.beam(second)
	check(absf((sb.a as Vector3).distance_to(sb.b) - (l0 + 0.1)) < 0.005 and (sb.a as Vector3).is_equal_approx(tip), "the wheel stretches it from its root")
	var before: Vector3 = sb.b
	d.key(TradesBus.KEY_TURN_LEFT)
	sb = d.beam(second)
	check((sb.a as Vector3).is_equal_approx(tip) and not (sb.b as Vector3).is_equal_approx(before), "Q swings it about its root")
	d.fake_keys = [KEY_CTRL]
	d.key(TradesBus.KEY_TURN_RIGHT)
	d.fake_keys = null
	check(is_equal_approx(float(d.beam(second).turn), 15.0), "Ctrl+E rolls it")
	check(d.undo() and is_equal_approx(float(d.beam(second).turn), 0.0), "undo takes the roll back")
	# Right click deletes it; undo brings it back.
	d.hovered = second
	d.click(false)
	check(d.beam(second).is_empty(), "right click deletes it")
	check(d.undo() and not d.beam(second).is_empty(), "undo brings it back")

	# Together: two players add a beam with the same id at once; the host keeps both.
	var ship := d.ship_id()
	var row := {"id": 99, "a": [0, 0, 0], "b": [0, 1, 0], "section": "box_100x100x5", "turn": 0.0}
	var one: Variant = d._validate(2, {"ship": ship, "version": "A", "put": row, "new": true})
	d._apply(one)
	var two: Variant = d._validate(3, {"ship": ship, "version": "A", "put": row.merged({"b": [0, 2, 0]}, true), "new": true})
	check(two is Dictionary and int(two.put.id) != 99 and int(two.asked) == 99, "the second gets a new id from the host: %s" % [two])
	d._apply(two)
	check(d.beams().size() == 4 and not d.beam(first).is_empty() and not d.beam(second).is_empty(), "both kept, and nobody's else lost")
	# One player's edit to one beam leaves the others alone.
	var mine := d.beam(first)
	bus.set_beam_design(ship, bus.beam_design(ship) + [{"id": 200, "a": [0, 0, 1], "b": [0, 1, 1], "section": "box_100x100x5", "turn": 0.0}])
	d.edit_beam(first, {"section": TradesBeamSections.step(str(mine.section), 1)})
	check(not d.beam(200).is_empty(), "an edit sends only that beam, so one another player added meanwhile stays")
	check(d._validate(2, {"ship": ship, "put": {"id": 5, "a": [0, 0, 0], "b": [0, 0, 0.01], "section": "box_100x100x5"}}) is String, "a bad beam is refused")
	# Everyone sees each other's beam as it grows.
	d._apply_draft({"peer": 7, "ship": ship, "a": [0, 3, 0], "b": [1, 3, 0], "section": "box_100x100x5"})
	d._physics_process(0.0)
	check(d.has_node("Hologram/Draft_7") and "\n".join(d.info_lines()).contains("Crew drawing  1 beam"), "another player's growing beam is drawn")
	d._apply_draft({"peer": 7})
	d._physics_process(0.0)
	await frames(1)
	check(not d.has_node("Hologram/Draft_7"), "and goes when they place it or let it go")
	check(d._validate_draft(7, {"a": [0, 0, 0], "b": [0, 0, 1], "section": "nope"}) is String, "a bad one isn't passed on")

	# Clearing the clutter (trades.beam_clear): Backspace takes them all; X brings them back.
	var all := d.beams().size()
	d.hovered = -1
	check(d.doing().contains("Backspace clear all"), "the panel says how to clear them: %s" % d.doing())
	check(d.key(TradesBus.KEY_RESET) and d.beams().is_empty() and bus.beam_design(ship).is_empty(), "Backspace clears every beam")
	check(d.key(TradesBus.KEY_MODE) and d.beams().size() == all, "one undo brings them all back: %d" % d.beams().size())
	Flags.set_flag("trades.beam_clear", false)
	check(not d.key(TradesBus.KEY_RESET) and d.beams().size() == all, "with the flag off Backspace leaves them")

	bus.reset_data()
	yard.queue_free()
	await frames(2)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


## The tablet's aim from `from` (ship space) along `dir`: the real ray into the yard.
func _aim(d: TradesBeamDesigner, xf: Transform3D, from: Vector3, dir: Vector3) -> void:
	var a := xf * from
	var hit := d.cast(a, xf.basis * dir)
	d.hovered = -1
	d._aim_grow(INF, hit, from, dir)


## Aims along a beam's end from `from` (ship space) with the beam under the aim.
func _aim_at_beam(d: TradesBeamDesigner, from: Vector3, at: Vector3) -> void:
	d._aim_grow(0.0, {}, from, (at - from).normalized())


func physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
