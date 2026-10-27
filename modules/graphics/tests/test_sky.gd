extends ModuleTest
## G4, sky and night: an AlienSky gets Graphics's sky shader and deep blue palette with the
## flag on, AlienSky still drives the sun on it, clouds move with the hour, the night is
## darker than AlienSky alone makes it, and the flag off puts AlienSky's own sky back.
##   tools/run_tests.sh graphics


func run_tests() -> void:
	Flags.set_flag(GfxBus.MOOD, false)   # test_mood darkens on top of this
	Flags.set_flag(GfxBus.SKY, true)
	var sky := AlienSky.new()
	sky.hour_override = 15.0
	add_child(sky)
	await frames(3)
	var m := sky.sky_material
	check(m.shader == GfxBus.SkyLook.SkyShader, "the yard's sky is Graphics's sky")
	check(m.has_meta(GfxBus.SkyLook.SAVED), "AlienSky's own shader is kept to go back to")
	check((m.get_shader_parameter("zenith_day") as Color).b > 0.4, "a deep blue day")
	check(m.get_shader_parameter("sun_dir") != null and float(m.get_shader_parameter("day")) > 0.5,
			"AlienSky still sets the sun on it")
	check(sky.environment.fog_height_density > 0.0, "haze lies low over the ground")
	var noon_clouds: Vector2 = m.get_shader_parameter("cloud_offset")

	# Night: AlienSky alone, then with Graphics's dark night on top.
	Flags.set_flag(GfxBus.SKY, false)
	await frames(2)
	check(m.shader == AlienSky.SHADER and not m.has_meta(GfxBus.SkyLook.SAVED), "flag off: AlienSky's own sky again")
	sky.set_hour(23.0)
	var plain_planet := sky.planet_light.light_energy
	var plain_fill := sky.environment.ambient_light_energy
	Flags.set_flag(GfxBus.SKY, true)
	await frames(2)
	sky.set_hour(23.0)
	check(m.shader == GfxBus.SkyLook.SkyShader, "flag on again: dressed again")
	check(sky.planet_light.light_energy < plain_planet * 0.8, "the night is darker: less planet-light")
	check(sky.environment.ambient_light_energy < plain_fill * 0.5, "and less fill")
	sky.set_hour(23.0)
	check(sky.planet_light.light_energy < plain_planet * 0.8 and sky.planet_light.light_energy > plain_planet * 0.5,
			"setting the same hour again doesn't darken it twice")
	var night_clouds: Vector2 = m.get_shader_parameter("cloud_offset")
	check(not night_clouds.is_equal_approx(noon_clouds), "the clouds have moved on with the hours")
	sky.set_hour(12.0)
	check(is_equal_approx(sky.planet_light.light_energy, 0.0) or sky.planet_light.light_energy < 0.05, "by day the planet-light is AlienSky's own")
	sky.queue_free()
