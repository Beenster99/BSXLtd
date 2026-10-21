extends ModuleTest
## G5, ground surfaces: a mesh whose material is marked "gfx_surface" is drawn with
## Graphics's ground shader in its owner's colour, shared paints share one copy, MultiMeshes
## and Void Salvage's ship surface work too, unmarked and unknown kinds are left alone, and
## the flag off puts the owner's materials back.
##   tools/run_tests.sh graphics


func run_tests() -> void:
	Flags.set_flag(GfxBus.SURFACES, true)
	var look := GfxBus.SurfaceLook
	check(not look.GroundShader.get_shader_uniform_list().is_empty(), "the ground shader compiles")

	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.5, 0.49, 0.47)
	concrete.roughness = 0.95
	concrete.set_meta(look.META, "concrete")
	var slab := _mesh(concrete)
	var base := _mesh(concrete)
	var plain := _mesh(StandardMaterial3D.new())
	var odd_mat := StandardMaterial3D.new()
	odd_mat.set_meta(look.META, "marble")
	var odd := _mesh(odd_mat)
	var painted := ShipSurface.of(ShipKit.paint(Color(0.55, 0.55, 0.53), 0.0, 0.55, "satin_paint"))
	painted.set_meta(look.META, "epoxy")
	var floor_mm := MultiMeshInstance3D.new()
	floor_mm.multimesh = MultiMesh.new()
	floor_mm.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	floor_mm.multimesh.mesh = BoxMesh.new()
	floor_mm.multimesh.instance_count = 2
	floor_mm.material_override = painted
	add_child(floor_mm)
	await frames(3)

	var m := slab.material_override as ShaderMaterial
	check(m != null and m.shader == look.GroundShader, "a marked concrete slab gets the ground shader")
	check(slab.get_meta(look.SAVED) == concrete, "the owner's material is kept to go back to")
	var want := concrete.albedo_color.srgb_to_linear()
	var got: Vector3 = m.get_shader_parameter("albedo")
	check(got.is_equal_approx(Vector3(want.r, want.g, want.b)), "in the owner's colour")
	check(float(m.get_shader_parameter("slab")) > 0.0 and float(m.get_shader_parameter("oil")) > 0.0,
			"concrete has slabs and oil stains")
	check(base.material_override == m, "nodes sharing a paint share one Graphics copy")
	check(plain.material_override is StandardMaterial3D, "unmarked materials are left alone")
	check(odd.material_override == odd_mat, "an unknown kind is left alone")
	var e := floor_mm.material_override as ShaderMaterial
	check(e != null and e.shader == look.GroundShader and float(e.get_shader_parameter("scuffs")) > 0.0,
			"a MultiMesh on Void Salvage's ship surface gets the epoxy look")
	var ec: Vector3 = e.get_shader_parameter("albedo")
	check(ec.is_equal_approx(painted.get_shader_parameter("albedo")), "in the ship surface's colour")
	check(float(e.get_shader_parameter("roughness")) < 0.55, "epoxy is a touch shinier than painted")

	# A mesh added later is restyled as it arrives.
	var late := _mesh(concrete)
	await frames(2)
	check(late.material_override == m, "a slab added later is restyled too")

	Flags.set_flag(GfxBus.SURFACES, false)
	await frames(2)
	check(slab.material_override == concrete and not slab.has_meta(look.SAVED), "flag off: the owner's material is back")
	check(floor_mm.material_override == painted, "and on the MultiMesh")
	Flags.set_flag(GfxBus.SURFACES, true)
	await frames(2)
	check(slab.material_override == m, "flag on again: restyled again")
	for n in [slab, base, plain, odd, floor_mm, late]:
		n.queue_free()


func _mesh(mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.material_override = mat
	add_child(mi)
	return mi
