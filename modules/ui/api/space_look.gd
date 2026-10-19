class_name SpaceLook
extends RefCounted
## Void Salvage's world look for any BSX scene: its starfield sky, environment (ACES
## tonemap, glow, SSAO, dim blue ambient) and sun (scenes/main.tscn). A scene adds
##   add_child(SpaceLook.world_environment())
##   add_child(SpaceLook.sun())
## and the Graphics autoload then applies the player's quality settings to both, as in
## Void Salvage. Interiors keep the sky for what shows through windows and doors; their
## own lamps do the lighting.

const STARFIELD := preload("res://modules/ui/api/shaders/starfield.gdshader")
## Void Salvage's Sun node, exactly as main.tscn stores it.
static var sun_transform: Transform3D = str_to_var("Transform3D(-0.34202012, -0.2747395, 0.8986325, 0, 0.9563048, 0.2923717, -0.9396926, 0.099997, -0.32707548, 0, 0, 0)")


static func environment() -> Environment:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = STARFIELD
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.05, 0.06, 0.09)
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.ssao_enabled = true
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_bloom = 0.05
	return e


static func world_environment() -> WorldEnvironment:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = environment()
	return we


## The sun: warm white, low and to one side, with Void Salvage's shadow settings.
static func sun() -> DirectionalLight3D:
	var s := DirectionalLight3D.new()
	s.name = "Sun"
	s.transform = sun_transform
	s.light_color = Color(1, 0.95, 0.88)
	s.light_energy = 2.6
	s.shadow_enabled = true
	s.shadow_bias = 0.08
	s.shadow_normal_bias = 3.0
	s.directional_shadow_max_distance = 200.0
	return s
