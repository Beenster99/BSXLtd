extends ModuleTest
## Walk-inside, flying (beenster, 21 Nov: "go to walkinside view, fly outside the model and
## design beams and plates for the hull"): Q flies (no gravity, through the walls), E on the
## hull opens its panel's rows (as at the console's 3D view: armour, paint, ring girders), and a
## hull part in hand fits where you aim on her skin, turns and comes off again.
##   tools/run_tests.sh design

const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")
const WalkInside := preload("res://modules/design/internal/walk/walk_inside.gd")


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func run_tests() -> void:
	Flags.set_flag("design.outside", true)
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	var room := Node3D.new()
	add_child(room)
	var cam := Camera3D.new()
	room.add_child(cam)
	cam.current = true
	var f := Furnishing.new()
	room.add_child(f)
	f.setup(bus, Furnishing.stand_in_walls())
	var rec := bus.open_sample()
	f.open_walk()
	await frames(3)
	var walk: WalkInside = f.walk
	walk.set("rebuild_delay", 0.0)
	await _physics(20)

	# Q: fly. Up with Space, through the roof, and no falling.
	check(walk.toggle_fly() and walk.flying and walk.body.collision_mask == 0, "Q flies, through the walls")
	var y0 := walk.body.position.y
	Input.action_press(Keys.JUMP)
	await _physics(40)
	Input.action_release(Keys.JUMP)
	var y1 := walk.body.position.y
	check(y1 > y0 + 2.0, "Space rises: %.1f to %.1f m" % [y0, y1])
	await _physics(30)
	check(absf(walk.body.position.y - y1) < 0.05, "and you hang there, no gravity")
	var z0 := walk.body.position.z
	walk.body.rotation.y = 0.0
	Input.action_press(Keys.FORWARD)
	await _physics(20)
	Input.action_release(Keys.FORWARD)
	check(walk.body.position.z < z0 - 1.0, "WASD flies where you look")

	# Over the roof, looking down at it: E opens the panel's rows.
	var plan := bus.frame_plan()
	var st: Array = plan.stations
	var mid := (float(st[1].z) + float(st[2].z)) * 0.5
	var roof := float(DesignShape.hull_at(plan, mid - 0.5, mid + 0.5).roof)
	walk.body.position = Vector3(0.3, roof + 5.0, mid)
	walk.camera.rotation.x = -PI * 0.5 + 0.01
	await _physics(3)
	var id := walk.panel_aimed()
	check(id != "" and int(id.get_slice(":", 1)) == DesignFrame.ROOF_EDGE, "looking down from above: the roof panel: %s" % id)
	check(walk.open_hull_menu() and walk.is_palette_open() and walk.find_child("HullMenu", true, false) != null,
			"E opens the hull menu")
	var arm := walk.find_child("Panel_armour", true, false) as Button
	if arm:
		arm.pressed.emit()
	var k := DesignFrame.bay_at(bus.frame_plan(), float(id.get_slice(":", 0)))
	check(DesignFrame.panel_at(bus.frame_plan(), k, DesignFrame.ROOF_EDGE) == "armour", "ARMOUR from the hull menu")
	await frames(2)
	var sw := walk.find_child("PanelPaint_d46a1e", true, false) as Button
	if sw:
		sw.pressed.emit()
	var edit: Dictionary = rec.frame_edits.get(DesignFrame.panel_key(float(id.get_slice(":", 0)), DesignFrame.ROOF_EDGE), {})
	check(str(edit.get("paint", "")) == "#d46a1e" and str(edit.get("kind", "")) == "armour", "painted, still armour: %s" % [edit])
	await frames(2)
	var ring := walk.find_child("Member_RINGFORE", true, false) as Button
	if ring:
		ring.pressed.emit()
	check(rec.frame_edits.keys().any(func(key): return str(key).begins_with("member:")), "a ring girder taken out from the hull menu")
	bus.editor.undo()
	var split := walk.find_child("PanelSplit", true, false) as Button
	var frames_before := (bus.frame_plan().stations as Array).size()
	if split:
		split.pressed.emit()
	check((bus.frame_plan().stations as Array).size() == frames_before + 1, "SPLIT adds a frame from out here")
	bus.editor.undo()

	# A hull part: in hand, aimed at the roof, clicked on.
	var mount_btn := walk.find_child("Mount_antenna", true, false) as Button
	if mount_btn == null:
		mount_btn = walk.find_child("Mount_*", true, false) as Button
	check(mount_btn != null, "the hull parts to fit are in the menu")
	if mount_btn:
		mount_btn.pressed.emit()
	check(bool(walk.holding.get("mount", false)) and not walk.is_palette_open(), "a hull part in hand")
	walk._update_spot()
	check(walk.spot.has("mount") and int(walk.spot.mount.edge) == DesignFrame.ROOF_EDGE, "it lands on the roof where you aim: %s" % [walk.spot.get("why", "")])
	walk.turn()
	var n := rec.mounts.size()
	check(walk.put_down() and rec.mounts.size() == n + 1, "click: fitted")
	var mid_id: String = rec.mounts.keys()[rec.mounts.size() - 1]
	check(DesignOutside.on_skin(rec.mounts[mid_id]) and is_equal_approx(float(rec.mounts[mid_id].spin), PI * 0.5),
			"on her skin, turned a quarter as you held it")
	await _physics(5)
	await frames(3)
	var a := walk.aim()
	check(not a.is_empty() and str(a.info.kind) == "mount", "aiming at it: %s" % [a.get("info", {})])
	check(walk.remove_aimed() and not rec.mounts.has(mid_id), "X takes it off again")

	# Q again: walking, the walls solid.
	check(not walk.toggle_fly() and walk.body.collision_mask == WalkInside.LAYER, "Q again walks")
	walk.spawn()
	room.queue_free()
	await frames(2)
