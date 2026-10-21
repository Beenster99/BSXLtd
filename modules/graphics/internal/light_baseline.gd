extends RefCounted
## G1, the lighting baseline for the open yard (flag "graphics.light"). Tunes on top of what
## Core's Graphics set from the player's options, so it never turns a costly effect on that
## the player turned off; it only changes how the effects that are on look.

## How much of the fill light comes from the sky rather than AlienSky's flat ambient colour
## (0 all colour .. 1 all sky). The sky gives shadows a direction and a tint: blue from
## above, warm near the ground at dusk.
const SKY_FILL := 0.7
## Sky reflection map size per detail level (Low .. Ultra), px. 128 blurred shiny paint.
const RADIANCE: Array[int] = [128, 256, 512, 512]
## How much distant things take the sky's colour through the haze (0..1).
const AERIAL := 0.55
## Haze glowing toward the sun (0..1).
const SUN_SCATTER := 0.12
## Contact shadow under and between things (Core's SSAO, when on).
const AO_RADIUS := 1.4          # m
const AO_INTENSITY := 2.4
const AO_POWER := 1.6
const AO_DETAIL := 0.7
## Share of direct light the contact shadow darkens too (0 only fill light).
const AO_LIGHT_AFFECT := 0.12
## Screen-space bounce (Core's SSIL, when on).
const SSIL_RADIUS := 5.0        # m
const SSIL_INTENSITY := 1.3
## The sun's apparent size, degrees: soft shadow edges that widen with distance.
const SUN_SIZE := 0.5
## Shadow setting (Off, Low, Medium, High, Ultra) from which the sun's shadows go soft.
const SOFT_SUN_FROM := 3

## Marks an environment this baseline has tuned (meta; tests read it).
const META := "gfx_light"


static func apply_environment(we: WorldEnvironment) -> void:
	var env := we.environment
	if env == null:
		return
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = SKY_FILL
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	if env.sky:
		var detail := clampi(int(GraphicsOptions.get_value("detail")), 0, RADIANCE.size() - 1)
		env.sky.radiance_size = _radiance(RADIANCE[detail])
	if env.fog_enabled:
		env.fog_aerial_perspective = AERIAL
		env.fog_sun_scatter = SUN_SCATTER
	env.ssao_radius = AO_RADIUS
	env.ssao_intensity = AO_INTENSITY
	env.ssao_power = AO_POWER
	env.ssao_detail = AO_DETAIL
	env.ssao_light_affect = AO_LIGHT_AFFECT
	env.ssil_radius = SSIL_RADIUS
	env.ssil_intensity = SSIL_INTENSITY
	if env.sdfgi_enabled:
		# The yard is mostly flat ground: finer cells in height than across.
		env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	env.set_meta(META, true)


static func apply_sun(sun: DirectionalLight3D) -> void:
	if sun.has_meta("gfx_fixed") or not sun.shadow_enabled:
		return
	if int(GraphicsOptions.get_value("shadows")) >= SOFT_SUN_FROM:
		sun.light_angular_distance = SUN_SIZE
	sun.set_meta(META, true)


static func _radiance(px: int) -> Sky.RadianceSize:
	match px:
		256:
			return Sky.RADIANCE_SIZE_256
		512:
			return Sky.RADIANCE_SIZE_512
	return Sky.RADIANCE_SIZE_128
