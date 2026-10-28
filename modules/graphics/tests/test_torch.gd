extends ModuleTest
## G3, the helmet torch: L switches it, it rides with the view camera a little up and to the
## right, it comes on by itself as night falls and goes off at dawn, crewmates' torches
## show on their avatars' heads (and go when they leave), and its flag takes it away.
##   tools/run_tests.sh graphics


func run_tests() -> void:
	var bus := Modules.bus("graphics") as GfxBus
	Flags.set_flag(GfxBus.TORCH, true)
	await frames(2)
	var torch := bus.torch
	check(torch != null, "the torch is there with its flag on")
	check(Keys.has("graphics.torch") and Keys.key_of("graphics.torch") == KEY_L, "on L in Key binds")
	if torch == null:
		return
	torch.set_on(false)
	# Your rig: a body with a hidden mesh (it casts the sun's shadow only) and the camera on its head.
	var rig := CharacterBody3D.new()
	add_child(rig)
	var body_mesh := MeshInstance3D.new()
	body_mesh.mesh = CapsuleMesh.new()
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	rig.add_child(body_mesh)
	var rig_head := Node3D.new()
	rig.add_child(rig_head)
	var cam := Camera3D.new()
	cam.position = Vector3(3, 1.7, 5)
	cam.rotation_degrees = Vector3(0, 30, 0)
	rig_head.add_child(cam)
	var crate := MeshInstance3D.new()
	crate.mesh = BoxMesh.new()
	add_child(crate)
	cam.make_current()

	_press()
	await frames(3)
	var lamp: SpotLight3D = torch.lamp
	check(torch.on and lamp.visible, "L switches it on")
	var offset := cam.global_transform.affine_inverse() * lamp.global_position
	check(offset.is_equal_approx(torch.OFFSET), "it sits on the helmet, up and right of the eyes")
	check((-lamp.global_basis.z).dot(-cam.global_basis.z) > 0.999, "and shines where you look")
	check(lamp.has_meta("gfx_no_beam"), "no dust cone in your own face")
	check(body_mesh.get_layer_mask_value(torch.OWN_LAYER) and body_mesh.get_layer_mask_value(1),
			"your own body is marked, and keeps its layer")
	check(lamp.shadow_caster_mask & body_mesh.layers & ~1 == 0 and lamp.shadow_caster_mask & 1 != 0,
			"so your torch casts no shadow of you, but does of everything else")
	check(not crate.get_layer_mask_value(torch.OWN_LAYER), "the rest of the world is left alone")
	cam.position = Vector3(-4, 1.7, 0)
	await frames(2)
	check((cam.global_transform.affine_inverse() * lamp.global_position).is_equal_approx(torch.OFFSET), "it follows you")
	_press()
	await frames(2)
	check(not torch.on and not lamp.visible, "L again switches it off")

	torch.set_daylight(0.0)
	check(torch.on, "it comes on as night falls")
	torch.set_daylight(0.1)
	check(torch.on, "and stays on through twilight")
	torch.toggle()
	check(not torch.on, "L still works at night")
	torch.set_daylight(0.5)
	torch.set_daylight(0.02)
	check(torch.on, "the next nightfall puts it on again")
	torch.set_daylight(0.6)
	check(not torch.on, "and dawn takes it off")

	# A crewmate's torch on their avatar.
	var avatar := Node3D.new()
	var head := Node3D.new()
	head.add_to_group("crew_head")
	head.set_meta("peer_id", 7)
	avatar.add_child(head)
	add_child(avatar)
	var stamped: Variant = torch._validate(7, {"on": true, "peer": 3})
	check(stamped is Dictionary and int(stamped.peer) == 7, "the host stamps a switch with who sent it")
	torch._apply(stamped)
	await frames(2)
	var theirs := head.get_node_or_null("HelmetTorch_7") as SpotLight3D
	check(theirs != null, "a crewmate's torch shows on their head")
	var helmet := MeshInstance3D.new()
	head.add_child(helmet)
	torch._unshadow_wearers()
	check(helmet.get_layer_mask_value(torch.OWN_LAYER) and theirs.shadow_caster_mask & helmet.layers & ~1 == 0,
			"and doesn't shadow their own avatar")
	check(not crate.get_layer_mask_value(torch.OWN_LAYER), "nor marks anything past the avatar")
	check(torch.get_net_snapshot().torches.has("7"), "late joiners hear of it")
	torch._apply({"peer": 7, "on": false})
	await frames(2)
	check(not is_instance_valid(theirs) or theirs.is_queued_for_deletion(), "and it goes off when they switch it")
	torch.apply_net_snapshot({"torches": {"9": true}})
	var head9 := Node3D.new()
	head9.add_to_group("crew_head")
	head9.set_meta("peer_id", 9)
	add_child(head9)
	await frames(2)
	check(head9.get_node_or_null("HelmetTorch_9") != null, "a snapshot lights torches, even on avatars made later")
	torch._on_peer_left(9, "left")
	check(not torch.crew.has(9), "a player leaving takes their torch")

	Flags.set_flag(GfxBus.TORCH, false)
	await frames(2)
	check(bus.torch == null and not Keys.has("graphics.torch"), "flag off: gone, key too")
	Flags.set_flag(GfxBus.TORCH, true)
	await frames(2)
	if bus.torch:
		bus.torch.set_on(false)
	for n in [cam, avatar, head9]:
		n.queue_free()


func _press() -> void:
	var ev := InputEventAction.new()
	ev.action = "graphics.torch"
	ev.pressed = true
	Input.parse_input_event(ev)
