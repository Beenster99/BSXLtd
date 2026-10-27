extends ModuleTest
## The yard's mood (beenster, 0.3.23: "too bright in the yard, both in the day and at
## night"): with the flag on the sun and fill are lower by day, the night darker still, night
## lamps dimmed to pools that fall off sooner and still follow their owner's hour, and the
## flag off puts everything back as AlienSky and the lamp's owner set it.
##   tools/run_tests.sh graphics


func run_tests() -> void:
	Flags.set_flag(GfxBus.MOOD, false)
	var sky := AlienSky.new()
	sky.hour_override = 14.0
	add_child(sky)
	var lamp := SpotLight3D.new()
	lamp.light_energy = 0.0
	lamp.spot_attenuation = 0.8
	add_child(lamp)
	lamp.set_meta("night_energy", 10.0)   # its owner's full night energy, as the shipyard does
	await frames(3)
	var sun := sky.sun.light_energy
	var we := sky.get_node("WorldEnvironment") as WorldEnvironment
	var fill := sky.environment.ambient_light_energy
	sky.set_hour(23.0)
	var night_fill := sky.environment.ambient_light_energy
	var night_planet := sky.planet_light.light_energy

	Flags.set_flag(GfxBus.MOOD, true)
	await frames(3)
	sky.set_hour(14.0)
	check(sky.environment.ambient_light_energy < fill * 0.7, "by day the sky's fill is turned down")
	check(we.camera_attributes != null and we.camera_attributes.exposure_multiplier < 0.9, "and the exposure, so white walls stop glaring")
	check(is_equal_approx(sky.sun.light_energy, sun), "the sun is AlienSky's own")
	var dimmed := sky.environment.ambient_light_energy
	sky.set_hour(14.0)
	check(is_equal_approx(sky.environment.ambient_light_energy, dimmed), "the same hour again doesn't dim it twice")
	sky.set_hour(23.0)
	check(sky.environment.ambient_light_energy < night_fill * 0.9, "the night's fill is lower still")
	check(is_equal_approx(sky.planet_light.light_energy, night_planet), "and the planet-light is left as it was")
	check(is_equal_approx(we.camera_attributes.exposure_multiplier, 1.0), "but at night the exposure is the player's own")

	check(is_equal_approx(float(lamp.get_meta("night_energy")), 6.0), "a night lamp burns lower")
	GfxBus.MoodLook.lamp(lamp)
	check(is_equal_approx(float(lamp.get_meta("night_energy")), 6.0), "never dimmed twice")
	lamp.light_energy = float(lamp.get_meta("night_energy"))   # the owner's hour at full night
	var late := SpotLight3D.new()
	add_child(late)
	late.set_meta("night_energy", 8.0)
	late.light_energy = 8.0
	await frames(3)
	check(is_equal_approx(late.light_energy, 4.8) and is_equal_approx(float(late.get_meta("night_energy")), 4.8),
			"a lamp built later is dimmed as it arrives")
	var plain := SpotLight3D.new()
	plain.light_energy = 3.0
	add_child(plain)
	await frames(3)
	check(is_equal_approx(plain.light_energy, 3.0) and not plain.has_meta(GfxBus.MoodLook.META), "lamps that aren't night lamps are left alone")

	Flags.set_flag(GfxBus.MOOD, false)
	await frames(3)
	check(is_equal_approx(float(lamp.get_meta("night_energy")), 10.0) and is_equal_approx(lamp.light_energy, 10.0)
			and not lamp.has_meta(GfxBus.MoodLook.META),
			"flag off: the lamp is as its owner made it")
	sky.set_hour(14.0)
	check(is_equal_approx(sky.sun.light_energy, sun) and is_equal_approx(sky.environment.ambient_light_energy, fill)
			and is_equal_approx(we.camera_attributes.exposure_multiplier, 1.0),
			"and the day is AlienSky's own again")
	Flags.set_flag(GfxBus.MOOD, true)
	sky.queue_free()
