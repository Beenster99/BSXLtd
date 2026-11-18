class_name YardFx
extends RefCounted
## The bits of Void Salvage's Fx (scripts/world/fx.gd at 6523ae5) the tools' effects use:
## soft and spark sprites, the smoke and dust materials. Effects run at full scale.

static var _smoke_mat: StandardMaterial3D
static var _soft: GradientTexture2D
static var _dust_mat: ShaderMaterial
static var _spark: ImageTexture


## How many particles the effects throw (Void Salvage scales by its graphics preset).
static func effect_scale() -> float:
	return 1.0


static func soft_texture() -> GradientTexture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 64
		_soft.height = 64
	return _soft


## A spark's shape (VX18): a hot round core with a soft falloff and a faint four-point glint,
## white (tinted by its material), 32 px. For motes and embers that were square chips.
static func spark_texture() -> ImageTexture:
	if _spark == null:
		var size := 32
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var u := (float(x) + 0.5) / size * 2.0 - 1.0
				var v := (float(y) + 0.5) / size * 2.0 - 1.0
				var r := Vector2(u, v).length()
				var core := clampf(1.0 - r / 0.35, 0.0, 1.0)
				var halo := pow(clampf(1.0 - r, 0.0, 1.0), 3.0) * 0.55
				var glint := (pow(clampf(1.0 - absf(u) * 8.0, 0.0, 1.0), 2.0) * clampf(1.0 - absf(v), 0.0, 1.0)
						+ pow(clampf(1.0 - absf(v) * 8.0, 0.0, 1.0), 2.0) * clampf(1.0 - absf(u), 0.0, 1.0)) * 0.35
				img.set_pixel(x, y, Color(1, 1, 1, clampf(core * core + halo + glint, 0.0, 1.0)))
		img.generate_mipmaps()
		_spark = ImageTexture.create_from_image(img)
	return _spark


## Material for smoke puffs: soft texture, tinted and faded by vertex/instance colour, lit
## by the sun so trails have shape.
static func smoke_material() -> StandardMaterial3D:
	if _smoke_mat == null:
		_smoke_mat = StandardMaterial3D.new()
		_smoke_mat.albedo_texture = soft_texture()
		_smoke_mat.vertex_color_use_as_albedo = true
		_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_smoke_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_smoke_mat.roughness = 1.0
		# Lit by the sun (it faces the camera, so shading reads as density, not shape).
		_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_smoke_mat.disable_receive_shadows = true
	return _smoke_mat


## Material for dust and grit puffs (SmokeTrail): ragged little clouds torn by a tiling noise,
## each puff its own patch of it (shaders/dust_puff.gdshader), not the smoke's round blob.
static func dust_material() -> ShaderMaterial:
	if _dust_mat == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 4
		n.frequency = 0.02
		n.seed = 7
		var tex := NoiseTexture2D.new()
		tex.width = 128
		tex.height = 128
		tex.seamless = true
		tex.generate_mipmaps = true
		tex.noise = n
		_dust_mat = ShaderMaterial.new()
		_dust_mat.shader = load("res://modules/yard/assets/tools_fx/dust_puff.gdshader") as Shader
		_dust_mat.set_shader_parameter("noise_tex", tex)
	return _dust_mat


## A small orange-and-blue flame burst (a rocket lighting up).
