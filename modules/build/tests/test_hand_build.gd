extends ModuleTest
## Building by hand in the berth (master plan 5.2 to 5.5): the sample skiff comes to the build
## berth as a ghost; the first job glows and F floats it in; the welder makes its welds with
## your hands, each one marked in with its quality; the socket runs a fitting's bolts home; the
## stand-in keel stands down; the frame done pays the keel, the hull and fittings the fit-out;
## the trial gets a workmanship row; a saved build comes back as it was.
##   tools/run_tests.sh build


class FakeContracts:
	extends Node
	var paid: Array[String] = []
	var tracked: Array[String] = []

	func request_ship_stage(contract_id: String, stage_id: String) -> void:
		paid.append("%s/%s" % [contract_id, stage_id])

	func track_build(contract_id: String) -> void:
		tracked.append(contract_id)


func run_tests() -> void:
	for f: String in [YardBus.FLAG, YardBus.STATION, YardBus.DOCK, YardBus.RACKING, BuildBus.FLAG, BuildBus.HAND_FLAG, "build.weld_beacons"]:
		Flags.set_flag(f, true)
	var bus := Modules.bus("build") as BuildBus
	check(bus != null, "the module is loaded")
	if bus == null:
		return
	var yard := Modules.bus("yard") as YardBus
	var station := (load(YardBus.SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child(station)
	await frames(3)
	bus.start_sample()
	await frames(2)
	var berth := bus.berth
	check(berth != null and is_instance_valid(berth), "the build goes in the berth")
	var root := yard.build_berth_root()
	check(berth.get_parent() == root, "under the yard's build berth")
	var work := berth.get("work") as RigidBody3D
	var ghost := berth.get("ghost") as RigidBody3D
	check(work != null and ghost != null, "a ghost and a workpiece")
	var pl := bus.plan()
	var bp: Object = bus.blueprint()
	var bpm: PartModel = bp.get("model")
	check(bpm.part_visual(bpm.parts.keys()[0]).material_override is ShaderMaterial and
			(bpm.part_visual(bpm.parts.keys()[0]).material_override as ShaderMaterial).shader.resource_path.ends_with("ghost.gdshader"),
			"the whole ship shows as a holo")
	var area := berth.get("use_area") as Area3D
	check(area != null and area.has_meta("yard_use") and str(area.get_meta("yard_hint")).contains("Frame ring 0"),
			"the first job glows, and F floats it in (%s)" % (str(area.get_meta("yard_hint")) if area else "none"))
	# The stand-in keel stands down on the shared clock.
	for i in 30:
		await frames(1)
	var workers: Node = station.get("workers")
	check(workers == null or str(workers.get("claimed")) == BuildBus.CLAIM, "TartanCo's stand-in keel gives the berth up")

	# F at the glowing pieces: they float in, chalked for the welder.
	(area.get_meta("yard_use") as Callable).call()
	await physics_steps(4)
	var wm: PartModel = work.get("model")
	check(wm.parts.size() == (pl.jobs[0].parts as Array).size(), "the frame ring's pieces are on the ship (%d)" % wm.parts.size())
	check(bool(berth.call("floating")), "and float in")
	berth.call("settle")
	var planned: Array = work.get("planned")
	check(planned.size() == (pl.jobs[0].key as Array).size() and planned.all(func(p: Dictionary) -> bool: return int(p.kind) == ConnectionData.Kind.WELD),
			"its welds are chalked (%d)" % planned.size())
	check(bus.next_job() == -1 and bus.job_in_hand() == 0, "nothing else glows till it is fixed")
	# Placed, not welded: no beads on it yet (beenster, 20 Nov), and the card counts the welds.
	var drawn := wm.connections.filter(func(c: ConnectionData) -> bool: return wm.joint_view(c) != null)
	check(not wm.connections.is_empty() and drawn.is_empty(), "the ring sits in place unwelded, no beads (%d drawn of %d)" % [drawn.size(), wm.connections.size()])
	check(int(berth.call("marks_shown")) == planned.size(), "each weld to make is outlined bright over the holo (%d)" % int(berth.call("marks_shown")))
	# Easy to find (beenster, 0.5.3: "VERY hard to find"): a marker over the view for each one,
	# through beams, an arrow to the nearest, a light on each, an outline drawn through members.
	var beacons := berth.get("beacons") as CanvasLayer
	check(beacons != null and is_instance_valid(beacons), "the welds get markers over the view")
	if beacons:
		var targets: Array = beacons.call("targets")
		check(targets.size() == planned.size(), "one marker for each weld to make (%d)" % targets.size())
		var far := (work.global_position + Vector3(0, 0, 30))
		var near: Dictionary = beacons.call("nearest", targets, far)
		check(not near.is_empty() and targets.all(func(t: Dictionary) -> bool:
				return far.distance_to(t.at) >= far.distance_to(near.at) - 0.001), "the nearest is the one pointed to")
	var marks: Dictionary = berth.get("_marks")
	check(not marks.is_empty() and marks.values().all(func(m: Node) -> bool: return m.get_node_or_null("Glow") is OmniLight3D),
			"each weld's spot glows")
	var mmat := berth.get("_mark_mat") as ShaderMaterial
	check(mmat != null and mmat.next_pass is ShaderMaterial and
			(mmat.next_pass as ShaderMaterial).shader.resource_path.ends_with("seam_mark_through.gdshader"),
			"and its outline shows through the beams in front")
	check(planned.all(func(p: Dictionary) -> bool: return (p.seam_size as Vector2).x <= 0.13 + 0.001),
			"each weld is short enough that aiming anywhere on it starts the arc")
	var first_card := str(berth.call("card_text", bus.progress()))
	check(first_card.contains("%d welds remaining (welder, 8)" % planned.size()), "the card says how many welds remain (%s)" % first_card)

	# Weld them by hand.
	var rig := station.get("mover") as RigidBody3D
	var tools: Node = rig.get("tools")
	tools.call("select_tool", 7)
	var welder: Node = tools.call("active_tool")
	await frames(2)
	for p: Dictionary in planned.duplicate():
		await _weld(rig, work, p, float(welder.get("ideal_speed")))
	await frames(2)
	var done: Dictionary = bus.active().done
	check(done.size() == (pl.jobs[0].key as Array).size(), "every weld is marked in the build (%d)" % done.size())
	check(done.values().all(func(q: float) -> bool: return q >= 0.6), "steady welds are good work (%s)" % str(done.values()))
	check(bus.job_finished(0), "the ring is fixed")
	check(bus.next_job() == 1 and berth.get("use_area") != null, "and the next ring glows")
	check(wm.connections.size() >= (pl.jobs[0].inner as Array).size() + (pl.jobs[0].key as Array).size(), "its joints are made")
	check(wm.connections.all(func(c: ConnectionData) -> bool: return wm.joint_view(c) != null), "and every bead shows now it is welded")

	# Every chalked seam where you can get at it (beenster, 20 Nov: "a weld line is behind a
	# beam"): the next frame jobs landed one by one, each weld line seen square on all along with
	# nothing in front of it, and room to stand there.
	var hidden: Array[String] = []
	var chalked := 0
	for n in 6:
		var jn := bus.next_job()
		if jn < 0 or str(pl.jobs[jn].stage) != "frame":
			break
		bus.land_next()
		await physics_steps(4)
		berth.call("settle")
		for p: Dictionary in (work.get("planned") as Array):
			if int(p.kind) != ConnectionData.Kind.WELD:
				continue
			chalked += 1
			if not bool(berth.call("line_clear", p)):
				hidden.append("%s at %s" % [pl.jobs[jn].name, str(p.at)])
		bus.debug_next_job()
		await frames(1)
	check(chalked >= 6 and hidden.is_empty(), "every chalked weld line lies in the open (%d lines, hidden: %s)" % [chalked, str(hidden)])

	# Payments: the frame pays the keel, the hull and fittings the fit-out.
	var fake := FakeContracts.new()
	add_child(fake)
	bus.set("_contracts", fake)
	bus.builds["sc_test"] = bus.builds[BuildBus.SAMPLE].duplicate(true)
	bus.builds.erase(BuildBus.SAMPLE)
	bus.set("_plans", {"sc_test": (bus.get("_plans") as Dictionary)[BuildBus.SAMPLE]})
	bus.current = "sc_test"
	berth.set("contract", "sc_test")
	bus.debug_finish_stage()
	check(bus.stage_finished("frame"), "the debug fixes the rest of the frame")
	check(fake.paid == ["sc_test/keel"], "the frame done pays the keel (%s)" % str(fake.paid))
	bus.debug_finish_stage()
	check(bus.stage_finished("plates"), "then the plates")
	check(fake.paid.size() == 1, "no fit-out till the fittings are in")

	# A fitting's bolts by hand with the socket.
	var fit_job := bus.next_job()
	check(str(pl.jobs[fit_job].stage) == "fittings", "a fitting is next (%s)" % pl.jobs[fit_job].name)
	bus.land_next()
	await physics_steps(4)
	berth.call("settle")
	var bolts: Array = (work.get("planned") as Array).filter(func(p: Dictionary) -> bool: return int(p.kind) == ConnectionData.Kind.BOLT)
	check(bolts.size() >= 2, "its bolts are marked (%d)" % bolts.size())
	tools.call("select_tool", 2)
	await frames(2)
	for p: Dictionary in bolts.duplicate():
		await _fasten(rig, work, p, 400)
	check(bus.job_finished(fit_job), "the socket ran them home and it is bolted down")
	bus.debug_finish_stage()
	check(fake.paid == ["sc_test/keel", "sc_test/fit_out"], "hull closed, fittings in: the fit-out is paid (%s)" % str(fake.paid))
	var rows := bus.trial_rows("sc_test")
	check(rows.size() == 2 and str(rows[0].key) == "workmanship" and bool(rows[0].ok), "the trial gets the workmanship (%s)" % str(rows[0]))
	check(not bool(rows[1].ok), "and holds back while she is not built in full")
	bus.debug_finish_stage()
	bus.debug_finish_stage()
	check(bus.complete(), "every job done")
	check(bool(bus.trial_rows("sc_test")[1].ok), "built in full")
	var card := str(berth.call("card_text", bus.progress()))
	check(card.contains("ready for her trial"), "the card says she is ready (%s)" % card)

	# Saved and loaded: the berth builds her again as she was.
	var saved := bus.save_data()
	var parts := wm.parts.size()
	var joints := wm.connections.size()
	bus.load_data({}, BuildBus.SAVE_VERSION)
	await frames(2)
	check(bus.berth == null or not is_instance_valid(bus.berth), "an empty save empties the berth")
	bus.load_data(saved, BuildBus.SAVE_VERSION)
	await frames(2)
	var again: RigidBody3D = bus.berth.get("work")
	var am: PartModel = again.get("model")
	check(am.parts.size() == parts and am.connections.size() == joints, "the saved build comes back (%d/%d parts, %d/%d joints)" % [am.parts.size(), parts, am.connections.size(), joints])
	bus.stop()
	await frames(2)
	check(bus.current == "", "taken out of the berth")
	station.queue_free()
	await frames(2)


## Runs weld `p` by hand at `speed`, as the yard's tool test does.
func _weld(rig: RigidBody3D, body: RigidBody3D, p: Dictionary, speed: float) -> void:
	var length := (p.seam_size as Vector2).x
	var up: Vector3 = p.seam_up
	var t := 0.0
	var aim := func(along: float) -> Vector3:
		return body.global_transform * ((p.at as Vector3) + up * (along - length * 0.5))
	var n: Vector3 = body.call("planned_normal", p)
	var at: Vector3 = aim.call(0.0)
	var off := _stand_off(body, at, n)
	rig.call("place", at + off - _eye(rig), at)
	await physics_steps(3)
	# Where the eye really is against where it was put (a look steeply down or up swings it
	# about the neck): put it back over the spot.
	var fix: Vector3 = (at + off) - ((rig.get("tools") as Node).get("aim_origin") as Vector3)
	rig.call("place", at + off - _eye(rig) + fix, at)
	await physics_steps(2)
	(rig.get("tools") as Node).set("trigger_override", 1)
	for i in int(length / speed * 60.0) + 240:
		t = minf(t + speed / 60.0, length)
		at = aim.call(t)
		rig.call("place", at + off - _eye(rig) + fix, at)
		await physics_steps(1)
		if not (body.get("planned") as Array).has(p):
			break
	(rig.get("tools") as Node).set("trigger_override", 0)
	await physics_steps(2)
	if (body.get("planned") as Array).has(p) and absf(n.y) > 0.7:
		# Over a floor or under a ceiling the test rig's eye can't swing down its own line the way a
		# player tilts to: run the torch along it as the welder does (YardWorkpiece.weld_along at its
		# ideal pace), and the tool's word to the yard.
		var torch := 0.0
		for i in int(length / speed * 60.0) + 60:
			torch = minf(torch + speed / 60.0, length)
			var r: Dictionary = body.call("weld_along", p, aim.call(torch), 1.0 / 60.0, speed)
			if bool(r.done):
				var model: PartModel = body.get("model")
				var q := float((body.get("last_weld") as Dictionary).get("quality", 1.0))
				Modules.bus("yard").emit_signal("hand_fastened", body, model.connections.back(), q)
				break
			await physics_steps(1)
		await physics_steps(2)


## Where to stand off spot `at` (world) on a face facing `n`: 0.9 m out along it, or, over a
## floor or under a ceiling (the eye can't look straight down its own line), leaning off to a side
## the spot can be seen from.
func _stand_off(body: RigidBody3D, at: Vector3, n: Vector3) -> Vector3:
	if absf(n.y) < 0.7:
		return n * 0.9
	for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK,
			Vector3.RIGHT * 0.6, Vector3.LEFT * 0.6, Vector3.FORWARD * 0.6, Vector3.BACK * 0.6]:
		var off := (n * 0.5 + side * 0.75)
		var q := PhysicsRayQueryParameters3D.create(at + off, at - off.normalized() * 0.05)
		var hit := body.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.get("collider") == body and (hit.position as Vector3).distance_to(at) < 0.04:
			return off
	return n * 0.9


func _fasten(rig: RigidBody3D, body: RigidBody3D, p: Dictionary, most: int) -> void:
	var at: Vector3 = body.call("planned_position", p)
	var n: Vector3 = body.call("planned_normal", p)
	rig.call("place", at + n * 0.9 - _eye(rig), at)
	await physics_steps(3)
	(rig.get("tools") as Node).set("trigger_override", 1)
	for i in most:
		await physics_steps(1)
		if not (body.get("planned") as Array).has(p):
			break
		if i % 30 == 29:
			rig.call("place", at + n * 0.9 - _eye(rig), at)
	(rig.get("tools") as Node).set("trigger_override", 0)
	await physics_steps(2)
	if (body.get("planned") as Array).has(p) and absf(n.y) > 0.7:
		# Straight down on a deck the test rig's eye can't look down its own line: run the socket
		# on it as the tool does (YardWorkpiece.work_planned), and the tool's word to the yard.
		for i in 200:
			if bool(body.call("work_planned", p, 1.0 / 60.0 / 1.4)):
				var model: PartModel = body.get("model")
				Modules.bus("yard").emit_signal("hand_fastened", body, model.connections.back(), 1.0)
				break
			await physics_steps(1)
		await physics_steps(2)


func physics_steps(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## How far the rig's eye stands above where it is placed.
func _eye(rig: Node) -> Vector3:
	var k: Dictionary = (rig.get_script() as Script).get_script_constant_map()
	return Vector3(0, float(k.FEET) + float(k.EYE), 0)
