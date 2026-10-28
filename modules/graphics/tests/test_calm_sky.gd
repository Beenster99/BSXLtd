extends ModuleTest
## A calm sky and the sea (beenster, 0.3.26: "planets are too bright and distracting"; "the BSX
## base should be placed near to a sea"): with "graphics.calm_sky" the planets are smaller and
## dimmer and the night's stars, galaxy and nebula fainter, the flag off puts Graphics's own sky
## back; sea() gives styled water with "graphics.sea" and plain water without.
##   tools/run_tests.sh graphics


func run_tests() -> void:
	Flags.set_flag(GfxBus.SKY, true)
	Flags.set_flag(GfxBus.CALM_SKY, false)
	var sky := AlienSky.new()
	sky.hour_override = 15.0
	add_child(sky)
	await frames(3)
	var m := sky.sky_material
	check(m.get_shader_parameter("giant_radius") == null, "flag off: the giant at the shader's own size")
	check(is_equal_approx(float(m.get_shader_parameter("halo")), float(GfxBus.SkyLook.PALETTE["halo"])),
			"flag off: Graphics's own halo")

	Flags.set_flag(GfxBus.CALM_SKY, true)
	await frames(2)
	check(m.shader == GfxBus.SkyLook.SkyShader, "still Graphics's sky")
	check(float(m.get_shader_parameter("giant_radius")) < 0.25, "the gas giant is smaller")
	check(float(m.get_shader_parameter("planet_dim")) < 0.6, "the planets sit back in the air")
	check(float(m.get_shader_parameter("star_brightness")) < float(GfxBus.SkyLook.PALETTE["star_brightness"]),
			"fewer bright stars")
	check(float(m.get_shader_parameter("nebula")) < 0.5 and float(m.get_shader_parameter("galaxy")) < 0.5,
			"a faint galaxy and nebula")
	check(m.get_shader_parameter("sun_dir") != null, "AlienSky still sets the sun")

	Flags.set_flag(GfxBus.CALM_SKY, false)
	await frames(2)
	check(m.get_shader_parameter("planet_dim") == null and m.get_shader_parameter("giant_radius") == null,
			"flag off again: the planets as drawn")
	check(is_equal_approx(float(m.get_shader_parameter("star_brightness")), float(GfxBus.SkyLook.PALETTE["star_brightness"])),
			"and Graphics's stars")
	sky.queue_free()

	var gfx := Modules.bus("graphics") as GfxBus
	Flags.set_flag(GfxBus.SEA, true)
	var sea := gfx.sea(Vector2(400, 300))
	check(sea.material_override is ShaderMaterial and (sea.material_override as ShaderMaterial).shader == GfxBus.SeaLook.SeaShader,
			"the sea wears the sea shader")
	var plane := sea.mesh as PlaneMesh
	check(plane.size == Vector2(400, 300) and plane.subdivide_width > 20, "a plane of the size asked, fine enough for swells")
	check(sea.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "water casts no shadow")
	add_child(sea)
	await frames(2)
	check(sea.find_children("*", "CollisionObject3D").is_empty(), "no collision")
	sea.queue_free()
	Flags.set_flag(GfxBus.SEA, false)
	var plain := gfx.sea(Vector2(100, 100))
	check(plain.material_override is StandardMaterial3D, "flag off: plain water")
	plain.free()
	Flags.set_flag(GfxBus.SEA, true)
