extends ModuleTest
## Design Room: walk-inside mode. WALK INSIDE on the console builds the open design round you
## at full size (floors, walls with doorways, stairs as ramps, the parts), you walk it with the
## movement keys, it follows changes made at the table, and Esc takes you back to the console.
##   tools/run_tests.sh design

const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")
const WalkInside := preload("res://modules/design/internal/walk/walk_inside.gd")


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
	check(f.is_walking() and walk != null and not f.is_console_open(), "it leaves the console for the walk")
	check(walk.camera.current and HudSlots.pointer_claimed(), "you see through the walker's eyes, the yard's walker held still")
	check(walk.global_position.distance_to(f.global_position + WalkInside.OFFSET) < 0.01, "built well away from the room")

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
	check(walk.find_child("Part_c3", true, false) != null and walk.find_child("RoomTag_r9", true, false) != null,
			"the parts stand in their rooms, the rooms carry their names")

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
	var plan := WalkInside.ramp_plan(rec.rooms["r7"])
	var top: Rect2 = plan.rect
	var p := walk.global_transform * Vector3(top.get_center().x, 10, top.end.y - 0.3)
	var q := PhysicsRayQueryParameters3D.create(p, p - Vector3(0, 20, 0), WalkInside.LAYER)
	var hit := walk.get_world_3d().direct_space_state.intersect_ray(q)
	var hy: float = (walk.global_transform.affine_inverse() * (hit.position as Vector3)).y if hit else -99.0
	check(hit and hy > rec.deck_height - 0.5 and hy < rec.deck_height, "the ramp's top end is just under deck 2: %.2f" % hy)

	# Someone at the table adds a room: it appears round you.
	bus.editor.do({"op": "add_room", "room": {"id": "rx", "type": "cargo", "x": 4, "z": 4, "w": 4, "d": 4}})
	await frames(2)
	check(walk.find_child("RoomTag_rx", true, false) != null, "a room added at the table appears inside")

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


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
