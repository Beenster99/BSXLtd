extends ModuleTest
## Free beams and plates (beenster, 21 Nov: "there is no such thing as a wing or a fin or a
## nosecone - there is just beams and plates ... We should be able to rotate the beams, have
## grids to help snap and guidelines to help align"): beams anywhere in 3D, turned about their
## length; plates spanned on their ends; snapping to ends, along beams, to her frame's corners
## and to the grid, with guidelines; built as girders and plates welded, riveted and bolted to
## her rings; counted, priced, measured and warned about; placed from the table's plan and its
## side view, the console's 3D view and walk-inside.
##   tools/run_tests.sh design

const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")
const WalkInside := preload("res://modules/design/internal/walk/walk_inside.gd")
const FreeTool := preload("res://modules/design/internal/free/free_tool.gd")
const PlanView := preload("res://modules/design/internal/views/plan_view.gd")


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _built(plan: Dictionary) -> Dictionary:
	var body := RigidBody3D.new()
	var kit := ShipKit.new(body)
	kit.model = PartModel.new(body, true)
	DesignFrame.build(plan, kit)
	var names := {}
	var joints := {"weld": 0, "rivet": 0, "bolt_hull": 0}
	for p: PartData in kit.model.parts.values():
		if p.path.begins_with("free/"):
			names[p.part_name] = int(names.get(p.part_name, 0)) + 1
	for c: ConnectionData in kit.model.connections:
		var a := kit.model.parts.get(c.part_a) as PartData
		var b := kit.model.parts.get(c.part_b) as PartData
		if a == null or b == null:
			continue
		var fa := a.path.begins_with("free/")
		var fb := b.path.begins_with("free/")
		if fa and fb and c.kind == ConnectionData.Kind.WELD:
			joints.weld += 1
		elif fa and fb and c.kind == ConnectionData.Kind.RIVET:
			joints.rivet += 1
		elif fa != fb:
			joints.bolt_hull += 1
	body.free()
	return {"names": names, "joints": joints}


## Her side's upper corner at station i (ship space).
func _corner(plan: Dictionary, i: int) -> Vector3:
	var st: Dictionary = plan.stations[i]
	var best := Vector2(-INF, -INF)
	for c: Vector2 in (st.profile as PackedVector2Array):
		if c.x > best.x + 0.01 or (absf(c.x - best.x) <= 0.01 and c.y > best.y):
			best = c
	return Vector3(best.x, best.y, float(st.z))


func run_tests() -> void:
	Flags.set_flag("design.outside", true)
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	var rec := bus.open_sample()
	bus.mirror = DesignMirror.OFF
	var plan := bus.frame_plan()
	var body: Array = plan.body
	var i0 := int(body[0]) + 1
	var i1 := i0 + 1
	var n0 := _corner(plan, i0)
	var n1 := _corner(plan, i1)
	var out := Vector3(4.0, 0.0, 0.0)

	# The record: beams and plates as edits, checked.
	bus.editor.do({"op": "add_free_beam", "beam": {"a": DesignFree.arr(n0), "b": DesignFree.arr(n0 + out)}})
	bus.editor.do({"op": "add_free_beam", "beam": {"a": DesignFree.arr(n1), "b": DesignFree.arr(n1 + out)}})
	bus.editor.do({"op": "add_free_beam", "beam": {"a": DesignFree.arr(n0 + out), "b": DesignFree.arr(n1 + out), "size": "light"}})
	check(rec.free_beams.size() == 3, "three beams laid off her side: %d" % rec.free_beams.size())
	bus.editor.do({"op": "add_free_beam", "beam": {"a": [0, 0, 0], "b": [0.05, 0, 0]}})
	check(rec.free_beams.size() == 3, "a beam too short to cut is not laid")
	var pts := [DesignFree.arr(n0), DesignFree.arr(n1), DesignFree.arr(n1 + out), DesignFree.arr(n0 + out)]
	bus.editor.do({"op": "add_free_plate", "plate": {"pts": pts}})
	check(rec.free_plates.size() == 1, "a plate across them")
	var bent := pts.duplicate(true)
	bent[2] = DesignFree.arr(n1 + out + Vector3(0, 1.0, 0))
	bus.editor.do({"op": "add_free_plate", "plate": {"pts": bent}})
	check(rec.free_plates.size() == 1, "a plate that is not flat is not made")
	var g0: String = rec.free_beams.keys()[0]
	bus.editor.do({"op": "set_free_beam", "id": g0, "fields": {"roll": DesignFree.ROLL_STEP * 2.0}})
	var xf := DesignFree.beam_xf(rec.free_beams[g0])
	check(absf(xf.basis.y.angle_to(Vector3.UP) - DesignFree.ROLL_STEP * 2.0) < 0.05, "a beam turned 30 degrees about its length")
	var back := DesignRecord.from_dict(rec.to_dict())
	check(back.free_beams == rec.free_beams and back.free_plates == rec.free_plates, "they save with the design")
	bus.editor.undo()
	check(is_zero_approx(float(rec.free_beams[g0].get("roll", 0.0))), "undo turns it back")

	# Built: girders and a plate, welded, riveted and bolted to her rings.
	plan = bus.frame_plan()
	var b := _built(plan)
	check(int(b.names.get("FreeBeam", 0)) == 3 and int(b.names.get("HullPlate", 0)) == 1, "built as three girders and a plate: %s" % [b.names])
	check(int(b.joints.weld) >= 2, "the beams welded where they meet: %d" % int(b.joints.weld))
	check(int(b.joints.rivet) >= 4, "the plate riveted to the beams under its edges: %d" % int(b.joints.rivet))
	check(int(b.joints.bolt_hull) >= 2, "and bolted to her rings: %d" % int(b.joints.bolt_hull))
	var c := DesignFrame.counts(plan)
	check(int(c.free_beams) == 3 and float(c.free_m2) > 3.0, "counted: %d beams, %.1f m2" % [int(c.free_beams), float(c.free_m2)])
	check(DesignFrame.build_list(plan).any(func(r): return str(r.name) == "Free beams" and int(r.qty) == 3), "on the build list")
	check(float(DesignBerth.size_of(rec).beam) >= n0.x + 4.0 + 0.0, "her beam in the berth takes them: %.1f m" % float(DesignBerth.size_of(rec).beam))
	var codes := func() -> Array: return bus.problems().map(func(p): return str(p.code))
	check(not codes.call().has("free_adrift"), "joined to her hull: no warning")
	bus.editor.do({"op": "add_free_beam", "beam": {"a": [20, 20, 0], "b": [22, 20, 0]}})
	check(codes.call().has("free_adrift"), "a beam out in space on its own: WILL IT WORK says so")
	bus.editor.undo()

	# Snapping and guidelines.
	var hit := DesignFree.place(rec, plan, n0 + out + Vector3(0.1, 0.12, -0.05), 0.25)
	check(str(hit.kind) == "node" and (hit.point as Vector3).distance_to(n0 + out) < 0.01, "near a beam's end: on it")
	var along := DesignFree.place(rec, plan, n0 + Vector3(1.37, 0.15, 0.0), 0.25)
	check(str(along.kind) == "beam" and is_equal_approx(fmod((along.point as Vector3).x - n0.x, 0.25), 0.0), "near a beam: on it, a grid step along: %s" % along.point)
	var free_pt := DesignFree.place(rec, plan, Vector3(30.13, 7.38, 2.61), 0.5)
	check(str(free_pt.kind) == "grid" and (free_pt.point as Vector3).is_equal_approx(Vector3(30.0, 7.5, 2.5)), "out in the open: on the grid: %s" % free_pt.point)
	var lined := DesignFree.place(rec, plan, Vector3(n0.x + 6.03, n0.y + 0.05, n0.z + 0.04), 0.25)
	check((lined.point as Vector3).y == n0.y and (lined.point as Vector3).z == n0.z and not (lined.guides as Array).is_empty(),
			"in line with an end along x: pulled onto its line, a guideline shown: %d" % (lined.guides as Array).size())

	# The tool: a chain of beams, then a plate, by clicks (mirrored across her too).
	var tool := FreeTool.new(bus)
	tool.start("beam")
	var top := n0 + Vector3(0, 3.0, 0)
	tool.aim_point(n0)
	tool.click()
	tool.aim_point(top)
	var made := tool.click()
	check(made != "" and rec.free_beams.has(made) and tool.pts.size() == 1, "BEAM: click, click: a beam, and the next starts at its end")
	tool.aim_point(top + Vector3(0, 0, 2.0))
	tool.click()
	check(rec.free_beams.size() == 5, "it chains on: %d beams" % rec.free_beams.size())
	tool.cancel()
	tool.cancel()
	check(not tool.active(), "Esc twice puts it down")
	bus.mirror = DesignMirror.ACROSS
	tool.start("plate")
	for p: Vector3 in [n0, top, top + Vector3(0, 0, 2.0)]:
		tool.aim_point(p)
		tool.click()
	var before := rec.free_plates.size()
	check(tool.finish() != "" and rec.free_plates.size() == before + 2, "PLATE: three corners and Enter, mirrored to port too")
	bus.mirror = DesignMirror.OFF

	# The table: the plan places beams at the work height, the side view at the work x.
	var room := Node3D.new()
	add_child(room)
	var cam := Camera3D.new()
	room.add_child(cam)
	cam.current = true
	var f := Furnishing.new()
	room.add_child(f)
	f.setup(bus, Furnishing.stand_in_walls())
	f.open_console()
	await frames(4)
	var con = f.console
	var pv: PlanView = con.plan
	con.plan.select("", "")
	await frames(2)
	check(con.find_child("FreeRows", true, false) != null and con.find_child("AddShape_wing", true, false) == null,
			"nothing picked: BEAMS AND PLATES, and no prefab shapes to add")
	(con.find_child("FreeTool_beam", true, false) as Button).pressed.emit()
	check(pv.free.mode == "beam", "BEAM takes up the tool at the table")
	var count := rec.free_beams.size()
	pv.free_aim(pv.to_screen(Vector2(10.0, 0.0)))
	pv.free.click()
	pv.free_aim(pv.to_screen(Vector2(10.0, 3.0)))
	pv.free.click()
	var pg := ""
	for k: String in rec.free_beams:
		var ka := DesignFree.v3(rec.free_beams[k].a)
		if is_equal_approx(ka.x, 10.0) and is_zero_approx(ka.z):
			pg = k
	check(rec.free_beams.size() == count + 1 and pg != "", "a beam drawn on the plan")
	if pg != "":
		check(is_equal_approx(DesignFree.v3(rec.free_beams[pg].a).y, snappedf(pv.deck * rec.deck_height + bus.free_work.y, bus.free_grid)), "at the work height above the deck")
	pv.set_tool("select")
	if pg != "":
		var mid := (DesignFree.v3(rec.free_beams[pg].a) + DesignFree.v3(rec.free_beams[pg].b)) * 0.5
		var fh := pv.pick_free(pv.to_screen(pv.view_of(mid)))
		check(str(fh.get("id", "")) == pg, "a click on it on the plan picks it")
		pv.select("free_beam", pg)
		await frames(2)
		check(con.find_child("FreeBeamRows", true, false) != null, "its rows: section, roll, ends")
		var plus := con.find_child("FreeBeamRoll_plus", true, false) as Button
		if plus:
			plus.pressed.emit()
		check(is_equal_approx(float(rec.free_beams[pg].roll), DesignFree.ROLL_STEP), "ROLL + turns it 15 degrees")
		await frames(2)
		var up := con.find_child("FreeBeam_b_y_plus", true, false) as Button
		var by := DesignFree.v3(rec.free_beams[pg].b).y
		if up:
			up.pressed.emit()
		check(is_equal_approx(DesignFree.v3(rec.free_beams[pg].b).y, by + bus.free_grid), "END B Y + lifts its end a grid step")
	# The side view: z along, height up; x from the work point.
	var side := PlanView.new()
	side.size = Vector2(800, 600)
	room.add_child(side)
	side.setup(bus, PlanView.SIDE, true)
	side.set_tool("free_beam")
	bus.free_work = Vector3(7.0, 1.2, 0.0)
	count = rec.free_beams.size()
	side.free_aim(side.to_screen(Vector2(-3.0, -1.0)))
	side.free.click()
	side.free_aim(side.to_screen(Vector2(-3.0, -5.0)))
	side.free.click()
	var sb: Dictionary = rec.free_beams.values().filter(func(e): return is_equal_approx(DesignFree.v3(e.a).x, 7.0))[0] if rec.free_beams.size() > count else {}
	check(not sb.is_empty() and is_equal_approx(DesignFree.v3(sb.b).y, 5.0) and is_equal_approx(DesignFree.v3(sb.a).z, -3.0),
			"the side view lays one upright, at the work x: %s" % [sb])
	bus.free_work = Vector3(0.0, 1.5, 0.0)
	# The console's 3D view picks a beam under a ray.
	var mid0 := (n0 + n0 + out) * 0.5
	var pk := DesignFree.pick(rec, mid0 + Vector3(0, 5, 0), Vector3.DOWN)
	check(str(pk.get("kind", "")) == "beam", "a ray down onto a beam picks it")
	room.queue_free()
	await frames(2)

	# Walk-inside: B, aim, click, click; aim at it, R rolls, E edits, X removes.
	var room2 := Node3D.new()
	add_child(room2)
	var cam2 := Camera3D.new()
	room2.add_child(cam2)
	cam2.current = true
	var fw := Furnishing.new()
	room2.add_child(fw)
	fw.setup(bus, Furnishing.stand_in_walls())
	fw.open_walk()
	await frames(3)
	var walk: WalkInside = fw.walk
	walk.set("rebuild_delay", 0.0)
	walk.toggle_fly()
	await _physics(5)
	var spot := Vector3(-12.0, 4.0, 0.0)
	walk.body.position = spot + Vector3(0, 0, 6.0)
	walk.body.rotation.y = 0.0
	walk.camera.rotation.x = 0.0
	await _physics(3)
	check(walk.start_free("beam") and walk.free.mode == "beam", "B: the beam tool in walk-inside")
	count = rec.free_beams.size()
	walk.free_click()
	walk.camera.rotation.x = 0.35
	await _physics(2)
	var wid := walk.free_click()
	check(wid != "" and rec.free_beams.size() == count + 1, "click, look up, click: a beam where you aimed")
	walk.free.cancel()
	walk.free.cancel()
	await _physics(4)
	await frames(2)
	if wid != "":
		var wb: Dictionary = rec.free_beams[wid]
		var wm := (DesignFree.v3(wb.a) + DesignFree.v3(wb.b)) * 0.5
		walk.body.rotation = Vector3.ZERO
		walk.camera.rotation.x = 0.0
		walk.body.position = wm + Vector3(0, 0, 3.0) - walk.camera.position
		await _physics(3)
		var fa := walk.free_aimed()
		check(str(fa.get("id", "")) == wid, "aiming at it: %s" % [fa])
		walk.turn()
		check(is_equal_approx(float(rec.free_beams[wid].roll), DesignFree.ROLL_STEP), "R rolls it")
		check(walk.open_hull_menu() and walk.find_child("FreeBeamRows", true, false) != null, "E: its rows")
		walk.toggle_palette()
		check(walk.remove_aimed() and not rec.free_beams.has(wid), "X takes it off")
	room2.queue_free()
	await frames(2)
