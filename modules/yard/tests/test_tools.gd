extends ModuleTest
## The Void Salvage hand tools in the yard (Wave 1, stage 1.4): the hotbar picks and puts away
## tools, the tool sits in the suit's hand, the grinder takes the practice frame's rivets off,
## the socket turns a bolt out, the freed panel flies off as a piece of its own, the grabber
## holds it, the tractor holds the bracket from across the dock, the beam tablet reads the
## frame's joints and the terminal builds the frame again.
##   tools/run_tests.sh yard


func run_tests() -> void:
	for f: String in [YardBus.FLAG, YardBus.STATION, YardBus.DOCK, YardBus.RACKING]:
		Flags.set_flag(f, true)
	var bus := Modules.bus("yard") as YardBus
	if bus == null:
		bus = YardBus.new()
		bus.name = "yard"
		Modules.add_child(bus)
		bus.register_module()
	for i in 8:
		check(InputMap.has_action("yard.tool_%d" % (i + 1)), "key for tool %d" % (i + 1))
	var station := (load(YardBus.SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child(station)
	await frames(3)
	var rig := station.get("mover") as YardRig
	var tools := rig.tools
	check(tools != null and tools.tools.size() == 8, "eight tools on the hotbar")
	check(tools.holstered, "you come in with the tool put away")
	tools.select_tool(0)
	check(not tools.holstered and tools.active_tool() is YardGrinder and tools.active_tool().visible, "1 draws the grinder")
	await frames(3)
	check(tools.active_tool().art != null, "the grinder is the Void Salvage model")
	check(rig.avatar.tool_override == tools.active_tool(), "the right hand holds it")
	tools.wheel(-1)
	check(tools.active_tool() is YardCutter, "the wheel goes round the hotbar")
	tools.holster(true)
	check(tools.holstered and not tools.tools[1].visible, "H puts it away")
	# A screen holding the pointer (the design room's console) hides the hotbar and keeps the keys.
	HudSlots.claim_pointer("test_tools")
	await frames(2)
	var bar := tools.get_node("Hotbar") as CanvasLayer
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.physical_keycode = KEY_2
	key.pressed = true
	tools._unhandled_input(key)
	check(not bar.visible and tools.holstered, "a console holding the pointer hides the hotbar and keeps the keys")
	HudSlots.release_pointer("test_tools")
	await frames(2)
	check(bar.visible, "the hotbar comes back after")

	var practice := station.get("practice") as Node3D
	check(practice != null, "the practice frame floats outside the airlock")
	var frame := practice.get("frame") as YardWorkpiece
	var start: int = practice.call("joints_left")
	check(start == 10, "its panels hang by 4 bolts, 4 rivets and 2 welds (%d)" % start)

	# The grinder on the riveted panel's rivets.
	tools.select_tool(0)
	var freed: Array = []
	frame.piece_freed.connect(func(p: YardWorkpiece) -> void: freed.append(p))
	var rivets := _joints(frame, ConnectionData.Kind.RIVET)
	var seen := {"bar": false, "most": 0.0}   # (lambdas change a dictionary, not a local)
	for c: ConnectionData in rivets:
		await _work(rig, frame, c, 300, func() -> void:
			seen.bar = bool(seen.bar) or tools.progress_shown()
			seen.most = maxf(float(seen.most), tools.progress_value()))
	check(rivets.all(func(c: ConnectionData) -> bool: return c.is_broken()), "the grinder took every rivet off")
	check(freed.size() == 1 and (freed[0] as YardWorkpiece).model.parts.size() == 1, "the riveted panel came free")
	check(tools.broken >= 4, "the tool counts what it broke (%d)" % tools.broken)
	check(bool(seen.bar) and float(seen.most) > 0.5, "a progress bar by the crosshair shows the rivet going (%.2f)" % float(seen.most))
	var piece: YardWorkpiece = freed[0] if freed.size() > 0 else null

	# The socket on a bolt that turns.
	tools.select_tool(2)
	var socket := tools.active_tool() as YardSocket
	var bolt: ConnectionData = null
	for c: ConnectionData in _joints(frame, ConnectionData.Kind.BOLT):
		if not c.is_seized(socket.seized_chance):
			bolt = c
			break
	if bolt:
		await _work(rig, frame, bolt, 400)
		check(bolt.is_broken(), "the socket turned a bolt out")
	tools.trigger_override = -1

	# The grabber holds the freed panel and brings it in.
	if piece:
		tools.select_tool(3)
		var at := piece.global_transform * piece.center_of_mass
		var head := at + Vector3(2.5, 0.0, 0.0)
		rig.place(head - Vector3(0, YardRig.FEET + YardRig.EYE, 0), at)
		await physics_steps(3)
		tools.trigger_override = 1
		await physics_steps(5)
		check(tools.grab_body == piece, "the grabber takes hold of the panel")
		await frames(2)
		check(tools.grip_showing(), "the claw's grip field is drawn on it")
		tools.hold_distance = 1.5
		await physics_steps(120)
		var near := (piece.global_transform * piece.center_of_mass).distance_to(rig.head.global_position)
		check(near < 2.3, "and pulls it in (%.2f m)" % near)
		tools.trigger_override = 0
		await physics_steps(2)
		check(tools.grab_body == null, "letting go lets it go")
		tools.trigger_override = -1

	# The tractor takes the loose bracket from across the dock and holds it where you aim.
	var bracket := practice.get("bracket") as YardWorkpiece
	tools.select_tool(4)
	var tractor := tools.active_tool() as YardTractor
	check(tractor != null and tractor.visible, "5 draws the tractor")
	await frames(3)
	check(tractor.art != null and tractor.art.pieces.has("coil") and tractor.art.pieces.has("hand"), "the tractor is drawn in the suit's finish, in the fitted hand")
	var b_at := bracket.global_transform * bracket.center_of_mass
	rig.place(b_at + Vector3(0, 0, 9.0) - Vector3(0, YardRig.FEET + YardRig.EYE, 0), b_at)
	await physics_steps(3)
	tools.trigger_override = 1
	await physics_steps(5)
	check(tools.grab_body == bracket, "the tractor's beam takes the bracket 9 m off")
	await frames(2)
	check(tools.grip_showing(), "with Void Salvage's grip field on it")
	tools.wheel(-1)
	tools.wheel(-1)
	tools.wheel(-1)
	await physics_steps(240)
	var b_near := (bracket.global_transform * bracket.center_of_mass).distance_to(rig.head.global_position)
	check(absf(b_near - tools.hold_distance) < 1.5 and tools.hold_distance < 7.0, "the wheel brings it in (%.1f m, held at %.1f)" % [b_near, tools.hold_distance])
	tools.trigger_override = 0
	await physics_steps(2)
	check(tools.grab_body == null, "and lets go")
	tools.trigger_override = -1

	# The beam tablet reads the frame in front of it and comes up to the eye on a click.
	tools.select_tool(5)
	var tablet := tools.active_tool() as YardTablet
	var f_at := frame.global_transform * Vector3(0.84, 1.3, 0.08)   # the welded panel
	rig.place(f_at + frame.global_basis.z * 2.0 - Vector3(0, YardRig.FEET + YardRig.EYE, 0), f_at)
	await physics_steps(3)
	check(tablet.reading == frame, "the tablet reads the frame it is aimed at (%s)" % (tablet.reading.name if tablet.reading else "nothing"))
	check(not tablet.is_up(), "held at the waist")
	tools.trigger_override = 1
	await physics_steps(2)
	tools.trigger_override = 0
	await frames(30)
	check(tablet.is_up(), "a click brings it up")
	await frames(3)
	check(tablet.art != null and tablet.art.pieces.has("lens"), "the tablet is the scanner slate with BSX's lens")
	tools.trigger_override = -1
	tools.holster(true)

	# The riveter puts the fitting frame's rivets in, the welder runs its welds (0.4.0 playtest).
	var fit := practice.get("fit") as YardWorkpiece
	check(fit != null and fit.planned.size() == 8, "the fitting frame has 6 rivets and 2 welds chalked (%d)" % (fit.planned.size() if fit else 0))
	check(_joints(fit, ConnectionData.Kind.SPOT).size() == 2, "its panels hang by a tack each")
	tools.select_tool(6)
	var riveter := tools.active_tool() as YardRiveter
	check(riveter != null and riveter.visible, "7 draws the riveter")
	await frames(3)
	check(riveter.art != null and riveter.art.pieces.has("hand"), "the riveter is drawn in the suit's finish, in the fitted hand")
	var spray := (tools.get_node("ToolEffects") as YardToolEffects).spray
	var fx := {"sparks": 0, "globs": 0, "bar": false}
	for p: Dictionary in fit.planned.filter(func(q: Dictionary) -> bool: return int(q.kind) == ConnectionData.Kind.RIVET):
		await _fasten(rig, fit, p, 400, func() -> void:
			fx.sparks = maxi(int(fx.sparks), spray.shower_count()))
	check(_joints(fit, ConnectionData.Kind.RIVET).size() == 6, "the riveter set all six rivets (%d)" % _joints(fit, ConnectionData.Kind.RIVET).size())
	check(riveter.punches == 6, "one punch a rivet, once the pressure is up (%d)" % riveter.punches)
	check(int(fx.sparks) > 100, "its punch throws sparks (%d)" % int(fx.sparks))
	fx.sparks = 0
	tools.select_tool(7)
	var welder := tools.active_tool() as YardWelder
	check(welder != null and welder.visible, "8 draws the welder")
	# The bead follows your aim: run one weld steadily, the other far too fast.
	var welds := fit.planned.filter(func(q: Dictionary) -> bool: return int(q.kind) == ConnectionData.Kind.WELD)
	var each := func() -> void:
		fx.sparks = maxi(int(fx.sparks), spray.shower_count())
		fx.globs = maxi(int(fx.globs), spray.count(1))
		fx.bar = bool(fx.bar) or (tools.progress_shown() and tools.work_label.begins_with("WELD"))
	var steady := welds[0] as Dictionary
	await _weld(rig, fit, steady, welder.ideal_speed, each)
	var neat := fit.last_weld.duplicate()
	check(not fit.planned.has(steady) and String(neat.get("grade", "")) == "NEAT", "a steady hand lays a neat bead (%s, %.2f)" % [neat.get("grade", "?"), float(neat.get("quality", 0.0))])
	check(fit.find_child("WeldBead_*", true, false) != null, "and the bead stays on the seam, ripple by ripple")
	var fast := welds[1] as Dictionary
	await _weld(rig, fit, fast, welder.ideal_speed * 3.5, each)
	var poor := fit.last_weld.duplicate()
	check(not fit.planned.has(fast) and String(poor.get("grade", "")) == "POOR", "rushing it lays a poor one (%s, %.2f)" % [poor.get("grade", "?"), float(poor.get("quality", 0.0))])
	var weak := _joints(fit, ConnectionData.Kind.WELD).map(func(c: ConnectionData) -> float: return c.max_health)
	check(weak.size() == 2 and float(weak.min()) < float(weak.max()) * 0.8, "and the poor bead is the weaker joint (%s)" % str(weak))
	check(_joints(fit, ConnectionData.Kind.WELD).size() == 2 and fit.planned.is_empty(), "the welder ran both welds")
	check(int(fx.sparks) > 200 and int(fx.globs) > 5, "sparks and molten metal (%d sparks, %d globs)" % [int(fx.sparks), int(fx.globs)])
	check(bool(fx.bar), "the bar shows the weld going in")
	check(tools.fastened_count == 8, "the tools count what they put in (%d)" % tools.fastened_count)
	tools.trigger_override = -1
	tools.holster(true)

	practice.call("rebuild")
	await frames(2)
	check(int(practice.call("joints_left")) == start, "the terminal builds the frame again")
	check((practice.get("fit") as YardWorkpiece).planned.size() == 8, "and the fitting frame")
	station.queue_free()
	await frames(2)


func _joints(body: YardWorkpiece, kind: ConnectionData.Kind) -> Array:
	return body.model.connections.filter(func(c: ConnectionData) -> bool: return c.kind == kind)


## Floats a metre out in front of planned fastening `p`, aims along it and holds the trigger
## till it is in (`each` runs every step).
func _fasten(rig: YardRig, body: YardWorkpiece, p: Dictionary, most: int, each: Callable) -> void:
	var at := body.planned_position(p)
	rig.place(at + body.planned_normal(p) * 0.9 - Vector3(0, YardRig.FEET + YardRig.EYE, 0), at)
	await physics_steps(3)
	rig.tools.trigger_override = 1
	for i in most:
		await physics_steps(1)
		each.call()
		if not body.planned.has(p):
			break
		if i % 30 == 29:
			at = body.planned_position(p)
			rig.place(at + body.planned_normal(p) * 0.9 - Vector3(0, YardRig.FEET + YardRig.EYE, 0), at)
	rig.tools.trigger_override = 0
	await physics_steps(2)


## Runs weld `p` by hand: from its low end, the aim moving up the seam at `speed` m/s, the
## trigger held, till it is in (`each` runs every step).
func _weld(rig: YardRig, body: YardWorkpiece, p: Dictionary, speed: float, each: Callable) -> void:
	var length := (p.seam_size as Vector2).x
	var up: Vector3 = p.seam_up
	var t := 0.0
	var aim := func(along: float) -> Vector3:
		return body.global_transform * ((p.at as Vector3) + up * (along - length * 0.5))
	var at: Vector3 = aim.call(0.0)
	rig.place(at + body.planned_normal(p) * 0.9 - Vector3(0, YardRig.FEET + YardRig.EYE, 0), at)
	await physics_steps(3)
	rig.tools.trigger_override = 1
	for i in int(length / speed * 60.0) + 240:
		t = minf(t + speed / 60.0, length)
		at = aim.call(t)
		rig.place(at + body.planned_normal(p) * 0.9 - Vector3(0, YardRig.FEET + YardRig.EYE, 0), at)
		await physics_steps(1)
		each.call()
		if not body.planned.has(p):
			break
	rig.tools.trigger_override = 0
	await physics_steps(2)


## Floats a metre out in front of joint `c`, aims at it and holds the trigger till it breaks.
func _work(rig: YardRig, body: YardWorkpiece, c: ConnectionData, most: int, each := Callable()) -> void:
	var at := body.joint_position(c)
	var head := at + body.joint_normal(c) * 0.9
	rig.place(head - Vector3(0, YardRig.FEET + YardRig.EYE, 0), at)
	await physics_steps(3)
	rig.tools.trigger_override = 1
	for i in most:
		await physics_steps(1)
		if each.is_valid():
			each.call()
		if c.is_broken():
			break
		if i % 30 == 29:
			# The push-back drifts you off: come back in front of it.
			at = body.joint_position(c)
			rig.place(at + body.joint_normal(c) * 0.9 - Vector3(0, YardRig.FEET + YardRig.EYE, 0), at)
	rig.tools.trigger_override = 0
	await physics_steps(2)


func physics_steps(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
