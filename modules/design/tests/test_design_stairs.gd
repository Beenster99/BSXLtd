extends ModuleTest
## Stairwells you can use (beenster, 20 Nov: "the stairs are always the length of the room - so
## there is no space to get on the stairs or get off them"): a flight of a fixed run for the
## deck height with a landing at each end, which way it climbs and which wall it stands
## against set per stairwell, and WILL IT WORK says when a stairwell is too short.
##   tools/run_tests.sh design

const WalkBuild := preload("res://modules/design/internal/walk/walk_build.gd")
const WalkInside := preload("res://modules/design/internal/walk/walk_inside.gd")
const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")
const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")
const DesignConsole := preload("res://modules/design/internal/console/design_console.gd")


func run_tests() -> void:
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()

	# The flight: a fixed run, landings at both ends, never the whole room.
	var long := {"id": "s", "type": "stairs", "deck": 0, "x": 0.0, "z": 0.0, "w": 2.0, "d": 8.0}
	var f := DesignStairs.flight(long, 3.0)
	check(is_equal_approx(float(f.length), DesignStairs.run_for(3.0)) and bool(f.fits), "an 8 m stairwell: a %.1f m flight, not 8" % float(f.length))
	var fr: Rect2 = f.rect
	var foot: Rect2 = f.foot
	var head: Rect2 = f.head
	check(is_equal_approx(fr.position.y, DesignStairs.LANDING) and is_equal_approx(foot.position.y, 0.0)
			and is_equal_approx(head.position.y, fr.end.y), "landing at the foot, flight, landing at the head: %s %s %s" % [foot, fr, head])
	check(fr.size.x <= 1.0 + 0.001, "half the width at most, a way past it")
	long.stair_flip = true
	var back := DesignStairs.flight(long, 3.0)
	check(int(back.climbs) == -1 and (back.foot as Rect2).position.y > (back.rect as Rect2).position.y
			and (back.head as Rect2).end.y <= (back.rect as Rect2).position.y + 0.001, "flipped, it climbs the other way: foot at the far end")
	long.stair_side = true
	check(is_equal_approx((DesignStairs.flight(long, 3.0).rect as Rect2).end.x, 2.0), "and it can stand against the other wall")
	var short := {"id": "t", "type": "stairs", "deck": 0, "x": 0.0, "z": 0.0, "w": 2.0, "d": 4.0}
	check(not bool(DesignStairs.flight(short, 3.0).fits), "a 4 m stairwell is too short for 3 m decks (needs %.1f)" % DesignStairs.needs(3.0))

	# The rules: a short stairwell, a flight coming up outside the room above.
	var rec := bus.library.create("Stairs")
	bus.editor.do({"op": "add_room", "room": {"id": "a", "type": "stairs", "deck": 0, "x": 0, "z": 0, "w": 2, "d": 4}})
	bus.editor.do({"op": "add_room", "room": {"id": "b", "type": "stairs", "deck": 1, "x": 0, "z": 0, "w": 2, "d": 4}})
	var codes := bus.problems().map(func(p): return str(p.code))
	check("stairs_short" in codes, "WILL IT WORK: the stairwell is too short for its stairs")
	var p: Dictionary = bus.problems().filter(func(q): return str(q.code) == "stairs_short")[0] if "stairs_short" in codes else {}
	check(not p.is_empty() and (p.rooms as Array).has("a") and "4.8" in str(p.text), "it names the room and the length needed: %s" % p.get("text", ""))
	bus.editor.do({"op": "set_room", "id": "a", "fields": {"d": 5.0}})
	bus.editor.do({"op": "set_room", "id": "b", "fields": {"d": 3.5}})
	codes = bus.problems().map(func(q): return str(q.code))
	check(not "stairs_short" in codes and "stairs_no_head" in codes, "long enough, but the room above stops short of its head: %s" % [codes])
	bus.editor.do({"op": "set_room", "id": "b", "fields": {"d": 5.0}})
	codes = bus.problems().map(func(q): return str(q.code))
	check(not "stairs_short" in codes and not "stairs_no_head" in codes, "both 5 m: the stairs work")

	# A part in the wrong room is told where it goes (beenster, 20 Nov).
	bus.editor.do({"op": "add_component", "component": {"type": "life_support", "room": "a", "x": 1.5, "z": 4.0}})
	var wrong := bus.problems().filter(func(q): return str(q.code) == "wrong_room")
	check(not wrong.is_empty() and "it goes in Engineering" in str(wrong[0].text) and " or " in str(wrong[0].text),
			"wrong room says where it goes: %s" % (wrong[0].text if not wrong.is_empty() else ""))

	# The sample skiff's stairwell passes, and you can walk from its foot up onto deck 2.
	var sample := bus.open_sample()
	check(bus.problems().filter(func(q): return str(q.code).begins_with("stairs")).is_empty(), "the sample skiff's stairs pass")
	var room := Node3D.new()
	add_child(room)
	var cam := Camera3D.new()
	room.add_child(cam)
	cam.current = true
	var fu := Furnishing.new()
	room.add_child(fu)
	fu.setup(bus, Furnishing.stand_in_walls())
	fu.open_console()
	await frames(2)
	(fu.console.find_child("BtnWalkInside", true, false) as Button).pressed.emit()
	await frames(2)
	var walk: WalkInside = fu.walk
	walk.set("rebuild_delay", 0.0)
	var sf := WalkBuild.ramp_plan(sample.rooms["r7"], sample.deck_height)
	var sfoot: Rect2 = sf.foot
	var srect: Rect2 = sf.rect
	walk.body.position = Vector3(srect.get_center().x, 0.3, sfoot.get_center().y)
	walk.body.rotation.y = PI  # facing +Z: up the flight
	await _physics(20)
	check(walk.body.is_on_floor() and walk.body.position.y < 1.2, "standing on the landing at the foot: %.2f" % walk.body.position.y)
	Input.action_press(Keys.FORWARD)
	await _physics(150)
	Input.action_release(Keys.FORWARD)
	await _physics(10)
	check(walk.body.position.y > sample.deck_height - 0.3, "walked up the flight onto deck 2: y %.2f, z %.2f" % [walk.body.position.y, walk.body.position.z])
	check(int(walk.where().deck) == 1, "and you are on deck 2: %s" % [walk.where()])
	fu.close_walk()
	await frames(2)

	# The console: buttons to turn the flight and move it to the other wall.
	fu.console.plan.select("room", "r7")
	await frames(1)
	var flip := fu.console.find_child("StairFlip", true, false) as Button
	var side := fu.console.find_child("StairSide", true, false) as Button
	check(flip != null and side != null, "a selected stairwell has CLIMB OTHER WAY and OTHER WALL")
	if flip:
		flip.pressed.emit()
		check(bool(sample.rooms["r7"].get("stair_flip", false)), "CLIMB OTHER WAY flips it")
	if side:
		(fu.console.find_child("StairSide", true, false) as Button).pressed.emit()
		check(bool(sample.rooms["r7"].get("stair_side", false)), "OTHER WALL moves it")
	room.queue_free()
	await frames(2)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
