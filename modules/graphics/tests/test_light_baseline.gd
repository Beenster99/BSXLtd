extends ModuleTest
## G1, the lighting baseline: the yard's sky environment and sun get the outdoor look while
## "graphics.light" is on, other environments don't, and switching it off leaves new ones be.
##   tools/run_tests.sh graphics


func run_tests() -> void:
	var bus := Modules.bus("graphics") as GfxBus
	check(bus != null, "the graphics module loads")
	if bus == null:
		return
	Flags.set_flag("graphics.light", true)

	var sky := AlienSky.new()
	add_child(sky)
	await frames(3)
	var env := sky.environment
	check(env.has_meta("gfx_light"), "the yard's environment is tuned")
	check(env.ambient_light_source == Environment.AMBIENT_SOURCE_SKY, "fill light comes from the sky")
	check(env.ambient_light_sky_contribution > 0.5, "mostly sky, a little of AlienSky's colour")
	check(env.sky.radiance_size >= Sky.RADIANCE_SIZE_256 or int(GraphicsOptions.get_value("detail")) == 0,
			"sharper sky reflections above Low detail")
	check(env.fog_aerial_perspective > 0.0, "distant haze takes the sky's colour")

	# The time of day still drives the fill colour and strength.
	sky.set_hour(23.0)
	var night := env.ambient_light_energy
	sky.set_hour(12.0)
	check(env.ambient_light_energy > night, "the sky still sets day and night fill")
	check(env.ambient_light_source == Environment.AMBIENT_SOURCE_SKY, "the hour doesn't undo the sky fill")

	# A settings change re-applies Core's options, then this on top.
	var core_gfx := get_tree().root.get_node_or_null("Graphics")
	if core_gfx:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		core_gfx.apply_all()
		await frames(2)
		check(env.ambient_light_source == Environment.AMBIENT_SOURCE_SKY, "re-applied after a settings change")

	# The sun goes soft at High shadows and above.
	var shadows := int(GraphicsOptions.get_value("shadows"))
	if sky.sun.shadow_enabled and shadows >= 3:
		check(sky.sun.light_angular_distance > 0.0, "soft sun shadows")

	# An environment that isn't the yard's (menu, space backdrops) keeps its own look.
	var other := WorldEnvironment.new()
	other.environment = Environment.new()
	add_child(other)
	await frames(3)
	check(not other.environment.has_meta("gfx_light"), "other environments are left alone")
	other.queue_free()

	# Tagged "gfx_world", it gets the outdoor look too.
	var tagged := WorldEnvironment.new()
	tagged.environment = Environment.new()
	tagged.add_to_group(GfxBus.WORLD_GROUP)
	add_child(tagged)
	await frames(3)
	check(tagged.environment.has_meta("gfx_light"), "a tagged environment is tuned")
	tagged.queue_free()

	# Switched off, a new sky keeps AlienSky's own look.
	Flags.set_flag("graphics.light", false)
	var plain := AlienSky.new()
	add_child(plain)
	await frames(3)
	check(not plain.environment.has_meta("gfx_light"), "flag off: no restyle")
	check(plain.environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "flag off: flat fill as before")
	Flags.set_flag("graphics.light", true)
	plain.queue_free()
	sky.queue_free()
