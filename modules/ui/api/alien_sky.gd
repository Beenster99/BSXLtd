class_name AlienSky
extends Node3D
## The sky over the BSX yard: an alien atmosphere with three planets in it, a sun that moves
## with the time of day (Settings "world"/"time_of_day", hours 0..24, the slider in
## Settings), stars at night and a faint planet-light so the yard is never pitch black. A
## scene adds one instead of its own WorldEnvironment and sun:
##   add_child(AlienSky.new())
## Night lights and the like read AlienSky.daylight() (0 night .. 1 full day) or listen to
## time_changed on the node (group "alien_sky"). The Graphics autoload applies the player's
## quality settings to its environment and lights as it does everywhere else.

signal time_changed(hour: float, daylight: float)

const SHADER := preload("res://modules/ui/api/shaders/alien_sky.gdshader")
const SECTION := "world"
const KEY := "time_of_day"
const DEFAULT_HOUR := 15.0
## How high the sun climbs at noon (sine of its elevation).
const NOON_HEIGHT := 0.82
## Toward the ringed gas giant (the shader draws it there; its light comes from there).
const GIANT_DIR := Vector3(-0.55, 0.42, -0.72)

var environment: Environment
var sky_material: ShaderMaterial
var sun: DirectionalLight3D
var planet_light: DirectionalLight3D
## Fixed hour for this sky; -1 follows the setting.
var hour_override := -1.0
var hour := DEFAULT_HOUR


func _init() -> void:
	name = "AlienSky"
	add_to_group("alien_sky")
	sky_material = ShaderMaterial.new()
	sky_material.shader = SHADER
	sky_material.set_shader_parameter("giant_dir", GIANT_DIR)
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.ssao_enabled = true
	environment.glow_enabled = true
	environment.glow_intensity = 0.7
	environment.glow_bloom = 0.04
	environment.fog_enabled = true
	environment.fog_density = 0.0011
	environment.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = environment
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 3.0
	sun.directional_shadow_max_distance = 180.0
	add_child(sun)
	# Light off the gas giant: dim, cool, no shadows; it carries the night.
	planet_light = DirectionalLight3D.new()
	planet_light.name = "PlanetLight"
	planet_light.light_color = Color(0.55, 0.62, 0.95)
	planet_light.shadow_enabled = false
	planet_light.set_meta("gfx_no_shadow", true)
	add_child(planet_light)


func _ready() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings and not settings.changed.is_connected(_on_setting):
		settings.changed.connect(_on_setting)
	apply()


func _exit_tree() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings and settings.changed.is_connected(_on_setting):
		settings.changed.disconnect(_on_setting)


## Sets this sky to an hour (screenshots, cut scenes); -1 goes back to the setting.
func set_hour(h: float) -> void:
	hour_override = h
	apply()


## Puts the sun, light, sky colours and fog where they belong for the hour.
func apply() -> void:
	hour = hour_override if hour_override >= 0.0 else setting_hour()
	var dir := sun_direction(hour)
	var d := daylight_at(hour)
	sky_material.set_shader_parameter("sun_dir", dir)
	sky_material.set_shader_parameter("day", d)
	if dir.y > -0.2:
		sun.look_at_from_position(Vector3.ZERO, -dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	sun.light_energy = 1.7 * smoothstep(-0.02, 0.2, dir.y)
	sun.light_color = Color(1.0, 0.52, 0.28).lerp(Color(1.0, 0.94, 0.84), smoothstep(0.05, 0.4, dir.y))
	sun.visible = sun.light_energy > 0.01
	var giant := GIANT_DIR.normalized()
	planet_light.look_at_from_position(Vector3.ZERO, -giant, Vector3.UP)
	planet_light.light_energy = lerpf(0.32, 0.0, d)
	environment.ambient_light_color = Color(0.16, 0.13, 0.30).lerp(Color(0.62, 0.66, 0.62), d)
	environment.ambient_light_energy = lerpf(0.35, 0.5, d)
	var dusk := clampf(1.0 - absf(d - 0.25) * 4.0, 0.0, 1.0)
	var fog := Color(0.07, 0.05, 0.12).lerp(Color(0.62, 0.74, 0.66), d).lerp(Color(0.9, 0.5, 0.3), dusk * 0.5)
	environment.fog_light_color = fog
	time_changed.emit(hour, d)


## The hour in Settings (0..24), or the default when Settings isn't there.
static func setting_hour() -> float:
	var loop := Engine.get_main_loop() as SceneTree
	var settings: Node = loop.root.get_node_or_null("Settings") if loop else null
	if settings == null:
		return DEFAULT_HOUR
	var v: Variant = settings.get_value(SECTION, KEY)
	return DEFAULT_HOUR if v == null else fposmod(float(v), 24.0)


## Toward the sun at an hour: it rises in the east (+X) at 6, is highest at 12 and sets in
## the west at 18.
static func sun_direction(h: float) -> Vector3:
	var a := (h - 6.0) / 12.0 * PI
	return Vector3(cos(a), sin(a) * NOON_HEIGHT, -0.42).normalized()


## 0 at night, about 0.25 at sunrise and sunset, 1 by mid morning.
static func daylight_at(h: float) -> float:
	return clampf((sun_direction(h).y + 0.06) / 0.42, 0.0, 1.0)


## Daylight now, by the setting.
static func daylight() -> float:
	return daylight_at(setting_hour())


## "15:30" for an hour.
static func clock(h: float) -> String:
	var minutes := int(roundf(fposmod(h, 24.0) * 60.0)) % (24 * 60)
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func _on_setting(section: String, key: String, _value: Variant) -> void:
	if section == SECTION and key == KEY and hour_override < 0.0:
		apply()
