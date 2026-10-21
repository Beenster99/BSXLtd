extends ModuleTest
## G3, lamps: a spot lamp gets a reflector's pool of light, a big one a beam of lit dust
## shining the lamp's way, which hides with the lamp and follows its energy; small lamps,
## "gfx_no_beam" lamps and lamps made with the flag off stay plain.
##   tools/run_tests.sh graphics


func run_tests() -> void:
	var bus := Modules.bus("graphics") as GfxBus
	Flags.set_flag(GfxBus.LAMPS, true)
	var vol_was: Variant = GraphicsOptions.get_value("volumetrics")
	GraphicsOptions.set_value("volumetrics", 0)

	var big := _spot(20.0, Vector3(0, 7, 0))
	var small := _spot(6.0, Vector3(4, 3, 0))
	var asked := _spot(6.0, Vector3(8, 3, 0), true)
	var plain := _spot(20.0, Vector3(12, 7, 0))
	plain.set_meta("gfx_no_beam", true)
	var own := _spot(20.0, Vector3(16, 7, 0))
	var mine := GradientTexture2D.new()
	own.light_projector = mine
	await frames(3)
	check(big.light_projector != null and small.light_projector != null, "spot lamps get a reflector's pool of light")
	check(own.light_projector == mine, "a lamp's own projector is kept")
	var beam := big.get_node_or_null("GfxBeam") as MeshInstance3D
	check(beam != null, "a big spot gets a beam")
	check(small.get_node_or_null("GfxBeam") == null, "a small one doesn't")
	check(asked.get_node_or_null("GfxBeam") != null, "unless it is in gfx_beam")
	check(plain.get_node_or_null("GfxBeam") == null, "gfx_no_beam keeps a big lamp plain")
	check(bus.beams.has(beam), "the bus keeps the beam up to date")
	if beam:
		var far := beam.global_transform * Vector3(0, -(beam.mesh as CylinderMesh).height / 2.0, 0)
		var near := beam.global_transform * Vector3(0, (beam.mesh as CylinderMesh).height / 2.0, 0)
		check(near.distance_to(big.global_position) < 0.01, "its narrow end is at the lamp")
		check(far.y < big.global_position.y - 5.0, "and it shines the lamp's way (down)")
		check(beam.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "it casts no shadow")
		var m := beam.material_override as ShaderMaterial
		var bright := float(m.get_shader_parameter("strength"))
		check(bright > 0.0, "it glows")
		big.light_energy *= 0.5
		await frames(2)
		check(is_equal_approx(float(m.get_shader_parameter("strength")), bright * 0.5), "it dims with its lamp")
		GraphicsOptions.set_value("volumetrics", 2)
		await frames(2)
		if GfxBus.LampLook.fog_beams():
			check(float(m.get_shader_parameter("strength")) < bright * 0.5, "fainter when the volumetric fog draws beams too")
		else:
			check(is_equal_approx(float(m.get_shader_parameter("strength")), bright * 0.5), "full strength where the renderer has no volumetric fog")
		big.visible = false
		check(not beam.is_visible_in_tree(), "it hides with its lamp")

	Flags.set_flag(GfxBus.LAMPS, false)
	var late := _spot(20.0, Vector3(20, 7, 0))
	await frames(3)
	check(late.light_projector == null and late.get_node_or_null("GfxBeam") == null, "flag off: new lamps stay plain")
	GraphicsOptions.set_value("volumetrics", vol_was)
	Flags.set_flag(GfxBus.LAMPS, true)
	for l in [big, small, asked, plain, own, late]:
		l.queue_free()


func _spot(reach: float, at: Vector3, beam_group := false) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.spot_range = reach
	l.spot_angle = 40.0
	l.light_energy = 10.0
	l.position = at
	l.rotation_degrees = Vector3(-90, 0, 0)
	if beam_group:
		l.add_to_group("gfx_beam")
	add_child(l)
	return l
