extends ModuleTest
## Design Room: walk-inside mode. WALK INSIDE on the console builds the open design round you
## at full size (floors, walls with doorways, stairs as ramps, the parts), you walk it with the
## movement keys, it follows changes made at the table, and Esc takes you back to the console.
##   tools/run_tests.sh design

const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")
const WalkInside := preload("res://modules/design/internal/walk/walk_inside.gd")
const WalkBuild := preload("res://modules/design/internal/walk/walk_build.gd")


func run_tests() -> void:
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
	f.open_console()
	await frames(2)
	var btn := f.console.find_child("BtnWalkInside", true, false) as Button
	check(btn != null and btn.text == "WALK INSIDE", "the console has a WALK INSIDE button")
	btn.pressed.emit()
	await frames(2)
	var walk: WalkInside = f.walk
	walk.set("rebuild_delay", 0.0)
	check(f.is_walking() and walk != null and not f.is_console_open(), "it leaves the console for the walk")
	check(walk.camera.current and HudSlots.pointer_claimed(), "you see through the walker's eyes, the yard's walker held still")
	check(walk.viewport.own_world_3d and walk.world.get_world_3d() != f.get_world_3d(), "built in a world of its own")

	# You start in the airlock, on its floor.
	await _physics(30)
	var w := walk.where()
	check(str(w.room) == "r6" and int(w.deck) == 0, "you start in the airlock: %s" % [w])
	check(walk.body.is_on_floor(), "standing on the floor")
	check(str(walk._where.text).contains("AIRLOCK"), "the corner says where you are: %s" % walk._where.text)

	# Walls have doorways: a piece over each door, from the door's head up.
	var lintels := walk.wall_pieces.filter(func(p): return is_equal_approx(float(p.y0), int(p.deck) * rec.deck_height + WalkInside.DOOR_H))
	check(lintels.size() == rec.doors.size(), "a doorway at every door: %d of %d" % [lintels.size(), rec.doors.size()])
	check(walk.ramps == PackedStringArray(["r7"]), "the stairs are a ramp up to the deck above: %s" % [walk.ramps])
	check(walk.find_child("Part_c3", true, false) != null, "the parts stand in their rooms")
	var b: WalkBuild = walk.builder
	check(b.lamps == rec.rooms.size() and b.frame != null and b.frame.welds.size() > 10 and b.doors.size() == rec.doors.size(),
			"a lamp in every room, a welded frame round the rooms, a sliding door in every doorway: %d %d %d"
			% [b.lamps, b.frame.welds.size() if b.frame else 0, b.doors.size()])
	check(walk.find_child("CableTray*", true, false) != null and walk.find_child("Pipe*", true, false) != null
			and walk.find_child("Riser*", true, false) != null, "cable trays, fuel pipes and the riser up the stairwell")
	var plated := b.frame_model.parts.values().filter(func(pd): return pd.part_name == "DeckPlate").size()
	check(plated > 4 and walk.find_child("HoloOutline", true, false) != null,
			"deck plates underfoot on the deck frame (%d), and the faint hologram outline" % plated)

	# Walk forward (towards the middle of the ship): out of the airlock into the corridor.
	walk.body.position.x = 0.0  # in line with the door
	walk.body.rotation.y = 0.0  # facing -Z, to the bow
	var start := walk.body.position
	Input.action_press(Keys.FORWARD)
	await _physics(60)
	Input.action_release(Keys.FORWARD)
	check(walk.body.position.z < start.z - 1.5, "the forward key walks you: %.2f -> %.2f" % [start.z, walk.body.position.z])
	check(str(walk.where().room) == "r2", "through the airlock door into the corridor: %s" % [walk.where()])

	# The ramp is solid and climbs: a ray down over its top end lands near the deck above.
	var plan := WalkBuild.ramp_plan(rec.rooms["r7"])
	var top: Rect2 = plan.rect
	var p := walk.world.global_transform * Vector3(top.get_center().x, 10, top.end.y - 0.3)
	var q := PhysicsRayQueryParameters3D.create(p, p - Vector3(0, 20, 0), WalkInside.LAYER, [b.frame_body.get_rid()])
	var hit := walk.world.get_world_3d().direct_space_state.intersect_ray(q)
	var hy: float = (walk.world.global_transform.affine_inverse() * (hit.position as Vector3)).y if hit else -99.0
	check(hit and hy > rec.deck_height - 0.5 and hy < rec.deck_height, "the ramp's top end is just under deck 2: %.2f" % hy)

	# Someone at the table adds a room: it appears round you.
	bus.editor.do({"op": "add_room", "room": {"id": "rx", "type": "cargo", "x": 4, "z": 4, "w": 4, "d": 4}})
	await frames(2)
	check(walk.world.find_children("*", "StaticBody3D", true, false).any(
			func(n): return str((n.get_meta("walk", {}) as Dictionary).get("room", "")) == "rx"), "a room added at the table appears inside")

	await _designing(walk, rec, bus)

	# Esc goes back to the table.
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	f._input(esc)
	await frames(2)
	check(not f.is_walking() and f.is_console_open() and cam.current, "Esc goes back to the console and your own view")
	check(HudSlots.pointer_claimed(), "the console keeps the mouse")
	f.close_console()
	check(not HudSlots.pointer_claimed(), "leaving the console frees it")
	room.queue_free()
	await frames(2)


## Designing from inside: picking up, turning, placing, removing parts; doors; walls; the hull.
func _designing(walk: WalkInside, rec: DesignRecord, bus: DesignBus) -> void:
	# Stand in engineering, looking down at the floor by the reactor.
	walk.body.position = Vector3(2.0, 1.0, -1.0)
	walk.body.rotation.y = PI  # facing +Z
	walk.look(Vector2(0, 0))
	walk.camera.rotation.x = -1.1
	walk.set("_pitch", -1.1)
	await _physics(10)
	var a := walk.aim()
	check(not a.is_empty() and str(a.info.kind) == "floor" and str(a.info.room) == "r5", "aiming at engineering's deck: %s" % [a.get("info")])
	# A new fuel pump from the palette.
	walk.toggle_palette()
	var btn := walk.find_child("Part_fuel_pump", true, false) as Button
	check(walk.is_palette_open() and btn != null, "Tab opens the parts for this room")
	btn.pressed.emit()
	check(not walk.is_palette_open() and str(walk.holding.type) == "fuel_pump", "picking one puts it in your hands")
	walk._update_spot()
	check(str(walk.spot.room) == "r5", "it would go where you aim: %s" % [walk.spot])
	var before := rec.components.size()
	check(walk.put_down() and rec.components.size() == before + 1, "a click puts it down")
	var new_id := ""
	for id in rec.components:
		if str(rec.components[id].type) == "fuel_pump" and str(rec.components[id].room) == "r5":
			new_id = str(id)
	check(new_id != "", "it's in the design, in engineering")
	await frames(2)
	await _physics(2)
	# Pick it up again, turn it, put it back down: one move.
	a = walk.aim()
	check(not a.is_empty() and str(a.info.kind) == "component" and str(a.info.id) == new_id, "now you aim at it: %s" % [a.get("info")])
	walk.click()
	check(str(walk.holding.id) == new_id, "a click picks it up")
	walk.turn()
	walk.camera.rotation.x = -0.9
	await _physics(2)
	walk.click()
	check(walk.holding.is_empty() and int(rec.components[new_id].rot) == 1, "turned and put back down: %s" % [rec.components[new_id]])
	await frames(2)
	await _physics(2)
	walk.camera.rotation.x = -0.9
	await _physics(2)
	check(walk.remove_aimed() and not rec.components.has(new_id), "X takes it out")
	bus.editor.undo()
	check(rec.components.has(new_id), "and undo puts it back")
	# A good spot needs the part's services in reach: the engine away from the fuel line.
	walk.holding = {"type": "main_engine", "id": "", "rot": 0}
	walk.spot = {}
	await frames(1)
	walk._update_spot()
	check(str(walk.spot.why) != "", "the part in your hands says why a spot is good or not: %s" % walk.spot.why)
	walk.holding = {}
	# A wall: face the engineering's east (outer) wall, push it out a grid step.
	walk.body.position = Vector3(5.0, 1.0, 1.0)
	walk.body.rotation.y = -PI * 0.5  # facing +X
	walk.camera.rotation.x = 0.0
	await _physics(4)
	a = walk.aim()
	check(not a.is_empty() and str(a.info.kind) == "wall" and a.info.outer, "aiming at the outer wall: %s" % [a.get("info")])
	var w0 := float(rec.rooms["r5"].w)
	check(walk.push_wall(1) and is_equal_approx(float(rec.rooms["r5"].w), w0 + rec.grid), "the wheel pushes the wall out")
	await frames(2)
	await _physics(2)
	var doors0 := rec.doors.size()
	check(walk.door_here() != "" and rec.doors.size() == doors0 + 1, "F puts a door in it")
	bus.editor.undo()
	bus.editor.undo()
	check(is_equal_approx(float(rec.rooms["r5"].w), w0) and rec.doors.size() == doors0, "undo takes both back")
	# The hull from inside.
	walk.toggle_palette()
	var frame := walk.find_child("Structure_frame", true, false) as Button
	var was := str(rec.structure.frame)
	frame.pressed.emit()
	check(str(rec.structure.frame) != was, "the hull choices change from inside: %s" % rec.structure.frame)
	bus.editor.undo()
	walk.toggle_palette()
	await frames(2)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
