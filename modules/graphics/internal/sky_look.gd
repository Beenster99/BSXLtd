extends RefCounted
## G4, sky and night (flag "graphics.sky"): how Graphics dresses Core and UI's AlienSky. Its
## sky material gets Graphics's sky shader (the same uniforms, so AlienSky still sets the sun
## and the hour), a deep blue day palette and clouds; the haze thickens low over the ground;
## after each hour AlienSky sets, the night is made properly dark (the planet-light dimmed,
## the ambient fill taken down) so the yard's lamps, floodlights and torches carry it.
## Flag off, the sky goes back to AlienSky's own shader and palette.

const SkyShader := preload("res://modules/graphics/internal/sky.gdshader")
## Meta on the sky material: the shader it had before (to put back).
const SAVED := "gfx_sky_saved"

## The deep blue day of beenster's shipyard picture, a cooler dusk zenith, a blue-black night.
const PALETTE := {
	"zenith_day": Color(0.035, 0.16, 0.46),
	"horizon_day": Color(0.50, 0.68, 0.80),
	"zenith_dusk": Color(0.10, 0.09, 0.30),
	"horizon_dusk": Color(1.0, 0.48, 0.24),
	"zenith_night": Color(0.004, 0.006, 0.02),
	"horizon_night": Color(0.025, 0.028, 0.06),
	"star_brightness": 4.0,
	"halo": 0.2,
	"horizon_glow": 0.08,
}
## A calm sky (flag "graphics.calm_sky", beenster's 0.3.26 playtest: "the planets are too
## bright and distracting, the player should be focused on the work in the yard"): smaller
## planets sat back in the air, fewer and dimmer stars, a faint galaxy and nebula, a softer
## halo round the sun.
const CALM := {
	"giant_radius": 0.17,
	"ice_radius": 0.05,
	"moon_radius": 0.028,
	"planet_dim": 0.4,
	"star_brightness": 2.2,
	"faint_stars": 0.5,
	"galaxy": 0.25,
	"nebula": 0.3,
	"halo": 0.12,
}
## Meta on the sky material: that the calm values are on it.
const CALMED := "gfx_sky_calm"

## Cloud cover (0 clear .. 1 overcast) and how far the wind moves them per hour.
const CLOUD_COVER := 0.5
const WIND_PER_HOUR := Vector2(0.21, 0.08)
## Ground haze: thicker below this height (m), by this much.
const HAZE_HEIGHT := 6.0
const HAZE_DENSITY := 0.012
## At full night: the planet-light's share and the ambient fill's share of what AlienSky set.
const NIGHT_PLANET := 0.7
const NIGHT_AMBIENT := 0.35


## Dresses an AlienSky (a node in group "alien_sky" with sky_material and environment).
static func apply(sky: Node, calm := false) -> void:
	var m := sky.get("sky_material") as ShaderMaterial
	if m == null:
		return
	if m.shader != SkyShader:
		m.set_meta(SAVED, m.shader)
		m.shader = SkyShader
	for key: String in PALETTE:
		m.set_shader_parameter(key, PALETTE[key])
	m.set_shader_parameter("cloud_cover", CLOUD_COVER)
	for key: String in CALM:
		m.set_shader_parameter(key, CALM[key] if calm else PALETTE.get(key))   # null: the shader's default
	if calm:
		m.set_meta(CALMED, true)
	elif m.has_meta(CALMED):
		m.remove_meta(CALMED)
	var env := sky.get("environment") as Environment
	if env:
		env.fog_height = HAZE_HEIGHT
		env.fog_height_density = HAZE_DENSITY
	sky.call("apply")   # AlienSky sets the hour on the new shader, then time_changed -> night()


## Takes the dressing off again.
static func remove(sky: Node) -> void:
	var m := sky.get("sky_material") as ShaderMaterial
	if m == null or not m.has_meta(SAVED):
		return
	m.shader = m.get_meta(SAVED)
	m.remove_meta(SAVED)
	for key: String in PALETTE:
		m.set_shader_parameter(key, null)   # back to the shader's own defaults
	for key: String in CALM:
		m.set_shader_parameter(key, null)
	if m.has_meta(CALMED):
		m.remove_meta(CALMED)
	var env := sky.get("environment") as Environment
	if env:
		env.fog_height_density = 0.0
	sky.call("apply")


## After AlienSky has set an hour: clouds where the wind has taken them, and the night dark.
static func night(sky: Node, hour: float, daylight: float) -> void:
	var m := sky.get("sky_material") as ShaderMaterial
	if m == null or m.shader != SkyShader:
		return
	m.set_shader_parameter("cloud_offset", WIND_PER_HOUR * hour)
	var dark := 1.0 - smoothstep(0.0, 0.3, daylight)
	var planet := sky.get("planet_light") as DirectionalLight3D
	if planet:
		planet.light_energy *= lerpf(1.0, NIGHT_PLANET, dark)
	var env := sky.get("environment") as Environment
	if env:
		env.ambient_light_energy *= lerpf(1.0, NIGHT_AMBIENT, dark)
