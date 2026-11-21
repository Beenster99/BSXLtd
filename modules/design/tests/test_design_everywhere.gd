extends ModuleTest
## Every hull change from every view, live for the crew (beenster, 21 Nov: "I should be able to
## make a wing shape in plan view from the table and my friend see it appear in walkinside view.
## And vice versa. That goes for all hull modifications"). Ana at the console and Ben flying
## round her in walk-inside, on two machines through a stand-in network: a wing Ana adds at the
## table is built where Ben flies; Ben aims at it, sizes it, adds a fin, paints her and takes the
## wing off, and each lands on Ana's table; her nose's sizes show on its plates from either view.
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


func _shape_parts(walk: WalkInside, sid: String) -> int:
	var n := 0
	if walk.builder.frame_model == null:
		return 0
	for p: PartData in walk.builder.frame_model.parts.values():
		if HullRows.shape_of_path(p.path) == sid:
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
	var walk: WalkInside = fb.walk
	walk.set("rebuild_delay", 0.0)
	walk.toggle_fly()
	con.plan.select("", "")
	await frames(2)

	# Ana adds wings at the table: Ben sees them built where he flies.
	check(_press(con, "AddShape_wing"), "ADD WINGS at the table")
	hub.pump()
	var brec: DesignRecord = bbus.library.current
	var arec: DesignRecord = abus.library.current
	check(brec.shapes.size() == 1, "the wings reach Ben's machine")
	var sid: String = brec.shapes.keys()[0] if not brec.shapes.is_empty() else ""
	await _physics(4)
	await frames(2)
	check(_shape_parts(walk, sid) > 10, "and are built round him in walk-inside: %d parts" % _shape_parts(walk, sid))

	# Ben flies over a wing, aims at it and opens its menu with E.
	var limbs: Array = (bbus.frame_plan().limbs as Array).filter(func(l): return str(l.shape) == sid and float(l.side) > 0.0)
	var box := DesignShape.limb_box(limbs[0]) if not limbs.is_empty() else AABB()
	walk.body.position = Vector3(box.get_center().x, box.end.y + 3.0, box.get_center().z)
	walk.body.rotation.y = 0.0
	walk.camera.rotation.x = -PI * 0.5 + 0.01
	await _physics(3)
	check(walk.shape_aimed() == sid, "looking down on the wing: it is the shape aimed at: '%s'" % walk.shape_aimed())
	check(walk.open_hull_menu() and walk.hull_menu == "shape:" + sid and walk.find_child("ShapeEdit", true, false) != null,
			"E on the wing opens its sizes, as at the table")
	var span0 := DesignShape.field(arec.shapes[sid], "span")
	check(_press(walk, "Shape_span_plus"), "SPAN + from walk-inside")
	hub.pump()
	check(DesignShape.field(arec.shapes[sid], "span") > span0, "the wing grows on Ana's table: %.1f to %.1f m" % [span0, DesignShape.field(arec.shapes[sid], "span")])
	await frames(2)
	var shown := walk.find_child("Shape_span_value", true, false) as Label
	check(shown != null and absf(float(shown.text) - DesignShape.field(brec.shapes[sid], "span")) < 0.06, "Ben's menu shows the new span")

	# Ana changes it at the table while Ben has it open: his menu follows.
	con.plan.select("shape", sid)
	await frames(2)
	check(_press(con, "Shape_sweep_plus"), "SWEEP + at the table")
	hub.pump()
	await frames(2)
	var sweep_lbl := walk.find_child("Shape_sweep_value", true, false) as Label
	check(sweep_lbl != null and absf(float(sweep_lbl.text) - DesignShape.field(brec.shapes[sid], "sweep")) < 0.06,
			"Ana's sweep shows in Ben's menu straight away")

	# Ben adds a fin from out there and paints her.
	check(_press(walk, "AddShape_fin"), "ADD FIN from walk-inside")
	hub.pump()
	var fin := ""
	for k: String in arec.shapes:
		if str(arec.shapes[k].type) == "fin":
			fin = k
	check(fin != "" and Together._same(arec, brec), "the fin lands on Ana's table")
	await frames(2)
	check(walk.hull_menu == "shape:" + fin, "and Ben's menu turns to the fin")
	check(_press(walk, "Livery_base_d46a1e"), "a base colour from walk-inside")
	hub.pump()
	check(str(arec.livery.get("base", "")) == "#d46a1e", "Ana's design is painted: %s" % [arec.livery])
	await frames(2)
	check(_press(walk, "Outline_round_0"), "ROUND THE ROOMS for deck 0 from walk-inside")
	hub.pump()
	check(arec.hull_outline(0).size() >= 3 and Together._same(arec, brec), "her outline is drawn on Ana's plan: %d corners" % arec.hull_outline(0).size())
	await frames(2)
	check(_press(walk, "Outline_clear_0"), "and CLEAR")
	hub.pump()
	check(arec.hull_outline(0).is_empty(), "back to the proposed hull")
	await frames(2)

	# Her nose: its sizes on the nose's plates, from the table and from out there.
	con.plan.select("", "")
	await frames(2)
	check(_press(con, "AddShape_nose"), "ADD NOSE at the table")
	hub.pump()
	var fp := abus.frame_plan()
	var st: Array = fp.stations
	var nose_panel := "%.2f:%d" % [(float(st[0].z) + float(st[1].z)) * 0.5, DesignFrame.ROOF_EDGE]
	check(HullRows.end_shape_at(abus, nose_panel) != "", "a plate of her nose belongs to the nose")
	con.plan.select("panel", nose_panel)
	await frames(2)
	check(con.find_child("PanelRows", true, false) != null and con.find_child("ShapeEdit", true, false) != null,
			"picking a nose plate in the 3D view: the plate's rows and the nose's sizes")
	walk.hull_menu = nose_panel
	walk._fill_palette()
	check(walk.find_child("PanelRows", true, false) != null and walk.find_child("ShapeEdit", true, false) != null,
			"the same on that plate from walk-inside")

	# A ray down onto the wing picks it, as a click in the console's 3D view does.
	var hit := HullRows.pick_shape(abus, Vector3(box.get_center().x, box.end.y + 5.0, box.get_center().z), Vector3.DOWN)
	check(str(hit.get("id", "")) == sid, "the 3D view picks the wing under the pointer")

	# Ben takes the wings off from out there.
	walk.show_shape(sid)
	await frames(1)
	check(_press(walk, "ShapeRemove"), "REMOVE from walk-inside")
	hub.pump()
	check(not arec.shapes.has(sid) and Together._same(arec, brec), "the wings are gone from Ana's table too")
	await _physics(4)
	await frames(2)
	check(_shape_parts(walk, sid) == 0, "and from round Ben")
	check(walk.hull_menu == "hull" and walk.find_child("ShapeRows", true, false) != null, "his menu goes back to the whole hull")

	# Flying with nothing aimed at: E still opens the hull's rows.
	walk.toggle_palette()
	walk.body.position = Vector3(0, 60.0, 0)
	walk.camera.rotation.x = PI * 0.5 - 0.01
	await _physics(3)
	check(walk.open_hull_menu() and walk.hull_menu == "hull", "E out in space: her shapes and paint")

	room.queue_free()
	await frames(2)
	abus.free()
	bbus.free()
