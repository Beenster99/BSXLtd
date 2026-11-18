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
	for i in 6:
		check(InputMap.has_action("yard.tool_%d" % (i + 1)), "key for tool %d" % (i + 1))
	var station := (load(YardBus.SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child(station)
	await frames(3)
	var rig := station.get("mover") as YardRig
	var tools := rig.tools
	check(tools != null and tools.tools.size() == 6, "six tools on the hotbar")
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
	for c: ConnectionData in rivets:
		await _work(rig, frame, c, 300)
	check(rivets.all(func(c: ConnectionData) -> bool: return c.is_broken()), "the grinder took every rivet off")
	check(freed.size() == 1 and (freed[0] as YardWorkpiece).model.parts.size() == 1, "the riveted panel came free")
	check(tools.broken >= 4, "the tool counts what it broke (%d)" % tools.broken)
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

	practice.call("rebuild")
	await frames(2)
	check(int(practice.call("joints_left")) == start, "the terminal builds the frame again")
	station.queue_free()
	await frames(2)


func _joints(body: YardWorkpiece, kind: ConnectionData.Kind) -> Array:
	return body.model.connections.filter(func(c: ConnectionData) -> bool: return c.kind == kind)


## Floats a metre out in front of joint `c`, aims at it and holds the trigger till it breaks.
func _work(rig: YardRig, body: YardWorkpiece, c: ConnectionData, most: int) -> void:
	var at := body.joint_position(c)
	var head := at + body.joint_normal(c) * 0.9
	rig.place(head - Vector3(0, YardRig.FEET + YardRig.EYE, 0), at)
	await physics_steps(3)
	rig.tools.trigger_override = 1
	for i in most:
		await physics_steps(1)
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
