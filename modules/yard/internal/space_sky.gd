extends Node3D
## The yard's surroundings in deep space (0.4.1 playtest: "no planet nearby, it may be cooler
## to be in deep space with a stunning galaxy as a backdrop, maybe one or two distant
## planets"): stars, the home galaxy's band, a great spiral galaxy, nebulae, a ringed gas
## giant and a small blue world far off (all in the sky shader), and the sun. A faint cool
## fill from the spiral's side stands in for the galaxy's light.
##
## Drawn in high definition per pixel (see the shader). How fine its detail goes follows the
## player's Model detail setting: Low gives the standard sky, Medium high, High and Ultra the
## full one (SKY_DETAIL).

const SkyShader := preload("res://modules/yard/internal/shaders/space_sky.gdshader")

## Where the sun is (the way its light travels is the opposite).
@export var sun_direction := Vector3(0.55, 0.45, -0.35)
@export var sun_energy := 1.6

## The sky's detail (0 standard, 1 high, 2 ultra) for each Model detail choice (Low .. Ultra).
const SKY_DETAIL: Array[int] = [0, 1, 2, 2]

var environment: Environment
var sun: DirectionalLight3D
var sky_material: ShaderMaterial


func _ready() -> void:
	name = "SpaceSky"
	add_to_group("gfx_world")
	sky_material = ShaderMaterial.new()
	sky_material.shader = SkyShader
	sky_material.set_shader_parameter("sun_way", sun_direction.normalized())
	apply_detail()
	var graphics := get_node_or_null("/root/Graphics")
	if graphics != null and graphics.has_signal("changed"):
		graphics.connect("changed", apply_detail)
	var sky := Sky.new()
	sky.sky_material = sky_material
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

	# The spiral galaxy's light: faint and cool, from its side of the sky.
	var fill := DirectionalLight3D.new()
	fill.name = "GalaxyLight"
	fill.light_energy = 0.12
	fill.light_color = Color(0.6, 0.7, 1.0)
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, Vector3(0.35, -0.42, 0.84), Vector3.UP)   # travels away from it


## The sky's detail level for the player's Model detail setting (0..2).
static func detail_level() -> int:
	return SKY_DETAIL[clampi(int(GraphicsOptions.get_value("detail")), 0, SKY_DETAIL.size() - 1)]


func apply_detail() -> void:
	sky_material.set_shader_parameter("detail", detail_level())
