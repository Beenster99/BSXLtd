extends Node3D
## The yard's surroundings in orbit (stage 1.5's sky): stars and the galaxy's band, the sun,
## the planet below with its clouds and thin air, and its moon far off. A low blue fill stands
## in for the planet's reflected light.

const SkyShader := preload("res://modules/yard/internal/shaders/space_sky.gdshader")
const PlanetShader := preload("res://modules/yard/internal/shaders/planet.gdshader")
const AtmosphereShader := preload("res://modules/yard/internal/shaders/atmosphere.gdshader")
const MoonShader := preload("res://modules/yard/internal/shaders/moon.gdshader")

## The planet's radius and the height of the yard above its surface (m).
@export var planet_radius := 20000.0
@export var altitude := 900.0
## Where the sun is (the way its light travels is the opposite).
@export var sun_direction := Vector3(0.55, 0.45, -0.35)
@export var sun_energy := 1.6
## The moon: which way it lies, how far (m) and how big (m); it shows about 2.5 degrees across.
@export var moon_direction := Vector3(-0.6, 0.25, -0.75)
@export var moon_distance := 40000.0
@export var moon_radius := 900.0

var environment: Environment
var sun: DirectionalLight3D
var planet: MeshInstance3D


func _ready() -> void:
	name = "SpaceSky"
	add_to_group("gfx_world")
	# The planet, its air and the moon are kilometres off and alone in their planes: nothing
	# can flicker against them, and the Graphics module's z-fight check would grid each of
	# their 600 m faces in 2 m cells (the scan of the station never finished).
	set_meta("gfx_coplanar_ok", true)
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SkyShader
	var sky := Sky.new()
	sky.sky_material = sky_mat
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.32, 0.38, 0.5)
	environment.ambient_light_energy = 0.35
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 6.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.03
	environment.glow_hdr_threshold = 1.2
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.08
	environment.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = sun_energy
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -sun_direction.normalized(), Vector3.UP)

	# The planet's light, bounced up from below.
	var fill := DirectionalLight3D.new()
	fill.name = "PlanetLight"
	fill.light_energy = 0.18
	fill.light_color = Color(0.45, 0.6, 0.9)
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, Vector3(0.1, 1.0, 0.2), Vector3.FORWARD)

	var centre := Vector3(0, -(planet_radius + altitude), -2500)
	planet = _sphere(planet_radius, PlanetShader, centre, 192, 96)
	planet.name = "Planet"
	(planet.material_override as ShaderMaterial).set_shader_parameter("sun_dir", sun_direction.normalized())
	var air := _sphere(planet_radius * 1.012, AtmosphereShader, centre, 128, 64)
	air.name = "Atmosphere"
	(air.material_override as ShaderMaterial).set_shader_parameter("sun_dir", sun_direction.normalized())
	# The moon, far off above the horizon on the sun's side.
	var moon := _sphere(moon_radius, MoonShader, moon_direction.normalized() * moon_distance, 64, 32)
	moon.name = "Moon"


func _sphere(radius: float, shader: Shader, at: Vector3, segments: int, rings: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	mi.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	mi.extra_cull_margin = radius
	add_child(mi)
	return mi
