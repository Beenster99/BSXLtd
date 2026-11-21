extends ModuleTest
## Every hull change from every view, live for the crew (beenster, 21 Nov: "I should be able to
## make a wing shape in plan view from the table and my friend see it appear in walkinside view.
## And vice versa. That goes for all hull modifications"; and the shapes are free beams and
## plates, not prefabs). Ana at the console and Ben flying round her in walk-inside, on two
## machines through a stand-in network: a beam Ana draws on the plan is built where Ben flies;
## Ben rolls it, changes its section, lays beams and a plate of his own, paints her, rounds her
## outline and takes Ana's beam off, and each lands on Ana's table; Ana's change shows in Ben's
## open menu.
##   tools/run_tests.sh design

const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")
const Together := preload("res://modules/design/tests/test_design_together.gd")
const HullRows := preload("res://modules/design/internal/console/hull_rows.gd")
const WalkInside := preload("res://modules/design/internal/walk/walk_inside.gd")


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _player(hub: Variant, id: int) -> Dictionary:
	var net = Together.Net.new()
	net.hub = hub
	net.id = id
	var bus := DesignBus.new()
	bus.hook_net(net)
	return {"bus": bus, "net": net}


func _press(root: Node, node_name: String) -> bool:
	var b := root.find_child(node_name, true, false) as Button
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true


func _free_parts(walk: WalkInside, id: String) -> int:
	var n := 0
	if walk.builder.frame_model == null:
		return 0
	for p: PartData in walk.builder.frame_model.parts.values():
		if p.path == "free/" + id:
			n += 1
	return n


func run_tests() -> void:
	Flags.set_flag("design.outside", true)
	var hub = Together.Hub.new()
	var ana := _player(hub, 1)
	var ben := _player(hub, 7)
	hub.join(ana.net)
	var abus: DesignBus = ana.bus
	var bbus: DesignBus = ben.bus
	abus.library.create("Everywhere")
	abus.editor.do({"op": "add_room", "room": {"type": "cargo", "deck": 0, "x": -3, "z": -4, "w": 6, "d": 8}})
	hub.pump()
	hub.join(ben.net)
	check(Together._same(abus.library.current, bbus.library.current), "Ben has Ana's design")

	# Ana at the table, Ben flying round her.
	var room := Node3D.new()
	add_child(room)
	var cam := Camera3D.new()
	room.add_child(cam)
	cam.current = true
	var fa := Furnishing.new()
	room.add_child(fa)
	fa.setup(abus, Furnishing.stand_in_walls())
	fa.open_console()
	var fb := Furnishing.new()
	room.add_child(fb)
	fb.setup(bbus, Furnishing.stand_in_walls())
	fb.open_walk()
	await frames(4)
	hub.pump()
	var con = fa.console
	var pv = con.plan
	var walk: WalkInside = fb.walk
	walk.set("rebuild_delay", 0.0)
	walk.toggle_fly()
	var arec: DesignRecord = abus.library.current
	var brec: DesignRecord = bbus.library.current

	# Ana draws a beam on the plan, out from her side: Ben sees it built where he flies.
	pv.set_tool("free_beam")
	pv.free_aim(pv.to_screen(Vector2(8.0, -1.0)))
	pv.free.click()
	pv.free_aim(pv.to_screen(Vector2(8.0, 2.0)))
	pv.free.click()
	pv.set_tool("select")
	hub.pump()
	check(brec.free_beams.size() == 1 and Together._same(arec, brec), "Ana's beam reaches Ben's machine")
	var gid: String = brec.free_beams.keys()[0] if not brec.free_beams.is_empty() else ""
	await _physics(4)
	await frames(2)
	check(_free_parts(walk, gid) == 1, "and is built round him in walk-inside")

	# Ben flies up to it and aims at it: R rolls it, E opens its rows, he makes it heavy.
	var gb: Dictionary = brec.free_beams.get(gid, {"a": [0, 0, 0], "b": [0, 0, 1]})
	var mid := (DesignFree.v3(gb.a) + DesignFree.v3(gb.b)) * 0.5
	walk.body.rotation = Vector3.ZERO
	walk.camera.rotation.x = -PI * 0.5 + 0.01
	walk.body.position = mid + Vector3(0, 3.0, 0) - walk.camera.position
	await _physics(3)
	check(str(walk.free_aimed().get("id", "")) == gid, "Ben aims at Ana's beam")
	walk.turn()
	hub.pump()
	check(is_equal_approx(float(arec.free_beams[gid].roll), DesignFree.ROLL_STEP), "R in walk-inside rolls it on Ana's table")
	check(walk.open_hull_menu() and walk.find_child("FreeBeamRows", true, false) != null, "E: the beam's rows")
	check(_press(walk, "FreeBeamSize_heavy"), "HEAVY from walk-inside")
	hub.pump()
	check(str(arec.free_beams[gid].size) == "heavy", "Ana's beam is heavy now")
	await frames(2)

	# Ana moves its end at the table while Ben has it open: his menu follows.
	pv.select("free_beam", gid)
	await frames(2)
	check(_press(con, "FreeBeam_b_y_plus"), "END B Y + at the table")
	hub.pump()
	await frames(2)
	var lbl := walk.find_child("FreeBeam_b_y_value", true, false) as Label
	check(lbl != null and absf(float(lbl.text) - DesignFree.v3(brec.free_beams[gid].b).y) < 0.01, "Ben's menu shows the new height straight away")
	walk.toggle_palette()

	# Ben lays two beams and a plate of his own: they land on Ana's table.
	check(walk.start_free("beam"), "B in walk-inside")
	var corner := DesignFree.v3(gb.a)
	var n := arec.free_beams.size()
	for p: Vector3 in [corner, corner + Vector3(0, 0, 3.0), corner + Vector3(0, 2.0, 3.0)]:
		walk.free.aim_point(p)
		walk.free.click()
	hub.pump()
	check(arec.free_beams.size() == n + 2 and Together._same(arec, brec), "his beams reach Ana: %d" % arec.free_beams.size())
	walk.start_free("plate")
	for p: Vector3 in [corner, corner + Vector3(0, 0, 3.0), corner + Vector3(0, 2.0, 3.0)]:
		walk.free.aim_point(p)
		walk.free.click()
	walk.free.finish()
	hub.pump()
	check(arec.free_plates.size() == 1 and Together._same(arec, brec), "and his plate")
	walk.free.cancel()
	walk.free.cancel()

	# Paint and the outline from out there.
	walk.toggle_palette()
	await frames(1)
	check(walk.find_child("FreeRows", true, false) != null and walk.find_child("AddShape_wing", true, false) == null,
			"Tab: beams and plates, no prefab shapes")
	check(_press(walk, "Livery_base_d46a1e"), "a base colour from walk-inside")
	hub.pump()
	check(str(arec.livery.get("base", "")) == "#d46a1e", "Ana's design is painted")
	await frames(2)
	check(_press(walk, "Outline_round_0"), "ROUND THE ROOMS for deck 0 from walk-inside")
	hub.pump()
	check(arec.hull_outline(0).size() >= 3 and Together._same(arec, brec), "her outline is drawn on Ana's plan: %d corners" % arec.hull_outline(0).size())
	await frames(2)
	check(_press(walk, "Outline_clear_0"), "and CLEAR")
	hub.pump()
	check(arec.hull_outline(0).is_empty(), "back to the proposed hull")
	walk.toggle_palette()

	# Ben takes Ana's beam off, from underneath (his plate stands over it).
	walk.body.rotation = Vector3.ZERO
	walk.camera.rotation.x = PI * 0.5 - 0.01
	var g2: Dictionary = brec.free_beams[gid]
	walk.body.position = (DesignFree.v3(g2.a) * 0.3 + DesignFree.v3(g2.b) * 0.7) - Vector3(0, 3.0, 0) - walk.camera.position
	await _physics(4)
	await frames(2)
	check(walk.remove_aimed(), "X in walk-inside on Ana's beam")
	hub.pump()
	check(not arec.free_beams.has(gid) and Together._same(arec, brec), "it is gone from her table")
	await _physics(4)
	await frames(2)
	check(_free_parts(walk, gid) == 0, "and from round Ben")

	# Flying with nothing aimed at: E still opens the hull's rows.
	walk.body.position = Vector3(0, 60.0, 0)
	walk.camera.rotation.x = PI * 0.5 - 0.01
	await _physics(3)
	check(walk.open_hull_menu() and walk.hull_menu == "hull" and walk.find_child("FreeRows", true, false) != null,
			"E out in space: beams and plates, her paint and outline")

	room.queue_free()
	await frames(2)
	abus.free()
	bbus.free()
