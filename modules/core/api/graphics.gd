extends Node
## Graphics autoload: applies GraphicsOptions to the window, the 3D view, the world's
## environment and every light and camera, including ones made later (it watches nodes
## being added to the tree, so lamps, floodlights and tool flashes all follow the settings).
## Presentation only: nothing here touches game state, so players can pick different
## settings in the same game.
##
## Ported from Void Salvage (scripts/autoload/graphics.gd) so both games look and tune the
## same; keep the two in step. GraphicsOptions is its settings, GraphicsPanel its menu.

signal changed

## How far lamps and their shadows are drawn, per draw distance (m).
const LIGHT_FADE: Array[float] = [60.0, 120.0, 250.0, 500.0]
## How far the sun's shadows reach, per draw distance (m).
const SUN_SHADOW: Array[float] = [100.0, 200.0, 350.0, 600.0]
## How far volumetric lighting reaches, per volumetrics level (m).
const FOG_LENGTH: Array[float] = [0.0, 128.0, 220.0, 350.0, 500.0]
## Froxel grid per volumetrics level: [screen cells, depth slices].
const FOG_GRID: Array = [[64, 48], [64, 48], [128, 64], [160, 96], [256, 128]]
## Shadow map sizes per shadow level (px).
const SUN_ATLAS: Array[int] = [1024, 2048, 4096, 4096, 8192]
const LAMP_ATLAS: Array[int] = [0, 2048, 4096, 4096, 8192]

## Dust in empty space, per unit of the "Light beams" slider (1/m). Kept thin so sunlit
## space stays clear; lamps make up for it with a stronger fog energy below.
@export var dust_density: float = 0.0001
## How strongly the sun lights the dust and gas clouds.
@export var sun_fog_energy: float = 0.15
## How strongly spotlights (helmet lamp, floodlights) light the dust: their visible beams.
@export var spot_fog_energy: float = 10.0
## How strongly other lamps light the dust.
@export var lamp_fog_energy: float = 4.0

## The surface detail last set on the shader globals: (detail, normals). Headless runs keep
## no globals, so the tests read this.
var surface_levels: Vector2 = Vector2.ONE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GraphicsOptions.load_settings()
	get_tree().node_added.connect(_on_node_added)
	get_window().size_changed.connect(_apply_ui_scale)
	apply_display()
	apply_scene.call_deferred()


## Applies everything and tells listeners (gas clouds) to update.
func apply_all() -> void:
	apply_display()
	apply_scene()
	changed.emit()


# --- Window and view ------------------------------------------------------------------

func apply_display() -> void:
	var win := get_window()
	var mode := int(GraphicsOptions.get_value("window_mode"))
	var want: Window.Mode = [Window.MODE_WINDOWED, Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN][mode]
	if DisplayServer.get_name() != "headless":
		if win.mode != want:
			win.mode = want
		if want == Window.MODE_WINDOWED:
			var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
			var size := GraphicsOptions.resolution()
			size = Vector2i(mini(size.x, usable.size.x), mini(size.y, usable.size.y))
			if win.size != size:
				win.size = size
				win.position = usable.position + (usable.size - size) / 2
		DisplayServer.window_set_vsync_mode([DisplayServer.VSYNC_DISABLED, DisplayServer.VSYNC_ENABLED,
				DisplayServer.VSYNC_ADAPTIVE, DisplayServer.VSYNC_MAILBOX][int(GraphicsOptions.get_value("vsync"))])
		_apply_hdr(win)
	Engine.max_fps = GraphicsOptions.max_fps()
	_apply_ui_scale()
	apply_viewport()


func _apply_ui_scale() -> void:
	var win := get_window()
	win.content_scale_factor = GraphicsOptions.ui_scale_for(win.size.y)
	apply_viewport()


static func hdr_supported() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_HDR_OUTPUT) \
			and DisplayServer.window_is_hdr_output_supported()


func _apply_hdr(win: Window) -> void:
	if not hdr_supported():
		return
	var on: bool = GraphicsOptions.get_value("hdr")
	win.hdr_output_requested = on
	if on:
		DisplayServer.window_set_hdr_output_max_luminance(float(GraphicsOptions.get_value("hdr_peak")))
		DisplayServer.window_set_hdr_output_reference_luminance(float(GraphicsOptions.get_value("hdr_paper_white")))


## The 3D view: upscaling, render scale, anti-aliasing, texture filtering, detail, shadows,
## surface detail.
func apply_viewport() -> void:
	var vp := get_viewport()
	var upscaler := int(GraphicsOptions.get_value("upscaler"))
	var scale := float(GraphicsOptions.get_value("render_scale"))
	# In fullscreen, a resolution below the screen's renders the 3D view smaller.
	var win := get_window()
	if win.mode != Window.MODE_WINDOWED and win.size.y > 0:
		scale *= minf(1.0, float(GraphicsOptions.resolution().y) / float(win.size.y))
	if upscaler != 0:
		scale = minf(scale, 1.0)
	var mode: Viewport.Scaling3DMode = [Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_FSR,
			Viewport.SCALING_3D_MODE_FSR2][upscaler]
	# FSR can't scale down, so change mode and scale in an order that never pairs FSR with >1.
	if upscaler == 0:
		vp.scaling_3d_mode = mode
		vp.scaling_3d_scale = clampf(scale, 0.25, 2.0)
	else:
		vp.scaling_3d_scale = clampf(scale, 0.25, 1.0)
		vp.scaling_3d_mode = mode
	vp.fsr_sharpness = (1.0 - float(GraphicsOptions.get_value("sharpness"))) * 2.0
	var aa := int(GraphicsOptions.get_value("antialiasing"))
	var fsr2 := upscaler == 2
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else (Viewport.SCREEN_SPACE_AA_SMAA if aa == 2 else Viewport.SCREEN_SPACE_AA_DISABLED)
	vp.use_taa = (aa == 3 or aa == 7) and not fsr2
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED,
			Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X, Viewport.MSAA_4X][aa]
	if fsr2:
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.anisotropic_filtering_level = int(GraphicsOptions.get_value("anisotropic")) as Viewport.AnisotropicFiltering
	vp.mesh_lod_threshold = [8.0, 4.0, 1.0, 0.5][int(GraphicsOptions.get_value("detail"))]
	vp.use_debanding = true
	var sh := int(GraphicsOptions.get_value("shadows"))
	vp.positional_shadow_atlas_size = LAMP_ATLAS[sh]
	vp.positional_shadow_atlas_16_bits = sh < 4
	RenderingServer.directional_shadow_atlas_set_size(SUN_ATLAS[sh], sh < 4)
	var soft: Array = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
			RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
			RenderingServer.SHADOW_QUALITY_SOFT_ULTRA]
	RenderingServer.directional_soft_shadow_filter_set_quality(soft[sh])
	RenderingServer.positional_soft_shadow_filter_set_quality(soft[sh])
	apply_surfaces()


## The salvage and ship surfaces' detail layer and its bumps (shader globals).
func apply_surfaces() -> void:
	surface_levels = GraphicsOptions.surface_levels()
	RenderingServer.global_shader_parameter_set("surface_detail", surface_levels.x)
	RenderingServer.global_shader_parameter_set("surface_normal", surface_levels.y)


# --- The world --------------------------------------------------------------------------

## Everything already in the scene: environments, lights, cameras, gas clouds.
func apply_scene() -> void:
	_walk(get_tree().root)


func _walk(n: Node) -> void:
	_tune(n)
	for c in n.get_children():
		_walk(c)


func _on_node_added(n: Node) -> void:
	if n is Light3D or n is Camera3D or n is WorldEnvironment:
		_tune.call_deferred(n)


func _tune(n: Node) -> void:
	if not is_instance_valid(n):
		return
	if n is WorldEnvironment:
		apply_environment(n as WorldEnvironment)
	elif n is Light3D:
		tune_light(n as Light3D)
	elif n is Camera3D:
		tune_camera(n as Camera3D)


static func apply_environment(we: WorldEnvironment) -> void:
	var env := we.environment
	if env == null:
		return
	if not env.has_meta("gfx_base"):
		env.set_meta("gfx_base", {"exposure": env.tonemap_exposure, "glow": env.glow_intensity})
	var base: Dictionary = env.get_meta("gfx_base")
	var gs := GraphicsOptions
	env.tonemap_mode = [Environment.TONE_MAPPER_ACES, Environment.TONE_MAPPER_AGX,
			Environment.TONE_MAPPER_FILMIC][int(gs.get_value("tonemap"))]
	env.tonemap_exposure = float(base["exposure"]) * float(gs.get_value("brightness"))
	var bloom := float(gs.get_value("bloom"))
	env.glow_enabled = bloom > 0.0
	env.glow_intensity = float(base["glow"]) * bloom
	# Ambient occlusion.
	var ao := int(gs.get_value("ao"))
	env.ssao_enabled = ao > 0
	if ao > 0:
		RenderingServer.environment_set_ssao_quality([0, RenderingServer.ENV_SSAO_QUALITY_LOW,
				RenderingServer.ENV_SSAO_QUALITY_MEDIUM, RenderingServer.ENV_SSAO_QUALITY_HIGH,
				RenderingServer.ENV_SSAO_QUALITY_ULTRA][ao], ao <= 2, 0.5, 2, 50.0, 300.0)
	# Global illumination.
	var gi := int(gs.get_value("gi"))
	var gq := int(gs.get_value("gi_quality"))
	env.ssil_enabled = gi == 1 or gi == 3
	if env.ssil_enabled:
		RenderingServer.environment_set_ssil_quality([RenderingServer.ENV_SSIL_QUALITY_LOW,
				RenderingServer.ENV_SSIL_QUALITY_MEDIUM, RenderingServer.ENV_SSIL_QUALITY_HIGH,
				RenderingServer.ENV_SSIL_QUALITY_ULTRA][gq], gq <= 1, 0.5, 4, 50.0, 300.0)
	env.sdfgi_enabled = gi >= 2
	if env.sdfgi_enabled:
		env.sdfgi_cascades = [4, 5, 6, 8][gq]
		env.sdfgi_min_cell_size = [0.3, 0.2, 0.15, 0.1][gq]
		env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_100_PERCENT   # space has no "flat"
		env.sdfgi_use_occlusion = true
		env.sdfgi_read_sky_light = true
		env.sdfgi_bounce_feedback = 0.5
		RenderingServer.environment_set_sdfgi_ray_count([RenderingServer.ENV_SDFGI_RAY_COUNT_8,
				RenderingServer.ENV_SDFGI_RAY_COUNT_16, RenderingServer.ENV_SDFGI_RAY_COUNT_32,
				RenderingServer.ENV_SDFGI_RAY_COUNT_64][gq])
		RenderingServer.environment_set_sdfgi_frames_to_converge([RenderingServer.ENV_SDFGI_CONVERGE_IN_10_FRAMES,
				RenderingServer.ENV_SDFGI_CONVERGE_IN_15_FRAMES, RenderingServer.ENV_SDFGI_CONVERGE_IN_20_FRAMES,
				RenderingServer.ENV_SDFGI_CONVERGE_IN_30_FRAMES][gq])
		RenderingServer.gi_set_use_half_resolution(gq <= 1)
	# Reflections.
	var refl := int(gs.get_value("reflections"))
	env.ssr_enabled = refl > 0
	if refl > 0:
		env.ssr_max_steps = [0, 32, 64, 128][refl]
		RenderingServer.environment_set_ssr_half_size(refl < 2)
	# Volumetric lighting: thin dust everywhere (lamp beams, sun shafts), plus gas clouds.
	var vol := int(gs.get_value("volumetrics"))
	env.volumetric_fog_enabled = vol > 0
	if vol > 0:
		var dust: float = 0.0001
		var node := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Graphics")
		if node:
			dust = float(node.get("dust_density"))
		env.volumetric_fog_density = dust * float(gs.get_value("beams"))
		env.volumetric_fog_albedo = Color(0.9, 0.9, 0.92)
		env.volumetric_fog_emission = Color.BLACK
		env.volumetric_fog_anisotropy = 0.25          # a little forward scatter: beams glow toward you
		env.volumetric_fog_length = FOG_LENGTH[vol]
		env.volumetric_fog_detail_spread = 2.0
		env.volumetric_fog_ambient_inject = 0.0       # space's faint ambient shouldn't fill the dust
		env.volumetric_fog_sky_affect = 1.0           # the same over sky and objects (no grey planet disc)
		env.volumetric_fog_gi_inject = 0.5 if env.sdfgi_enabled else 0.0
		env.volumetric_fog_temporal_reprojection_enabled = true
		var grid: Array = FOG_GRID[vol]
		RenderingServer.environment_set_volumetric_fog_volume_size(int(grid[0]), int(grid[1]))
		RenderingServer.environment_set_volumetric_fog_filter_active(vol >= 2)
	# Eye adaptation (auto exposure), gently: a stop or so brighter in dark interiors.
	var eye: bool = gs.get_value("eye_adaptation")
	var cam := we.camera_attributes as CameraAttributesPractical
	if cam == null and eye:
		cam = CameraAttributesPractical.new()
		we.camera_attributes = cam
	if cam:
		cam.auto_exposure_enabled = eye
		cam.auto_exposure_scale = 0.4
		cam.auto_exposure_speed = 0.6
		cam.auto_exposure_min_sensitivity = 80.0     # space is mostly black, so keep it on a short leash
		cam.auto_exposure_max_sensitivity = 130.0


## Shadows, beams and draw distance for one light. Remembers what its maker set the first
## time, so lower settings can always go back to that.
static func tune_light(l: Light3D) -> void:
	if l.has_meta("gfx_fixed"):
		return   # its maker set it for a capture: shadows, range and all stay as they are
	if not l.has_meta("gfx_base"):
		l.set_meta("gfx_base", {"shadow": l.shadow_enabled, "fog": l.light_volumetric_fog_energy, "size": l.light_size})
	var base: Dictionary = l.get_meta("gfx_base")
	var gs := GraphicsOptions
	var sh := int(gs.get_value("shadows"))
	var dd := int(gs.get_value("draw_distance"))
	var node := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Graphics")
	var sun_fog: float = float(node.get("sun_fog_energy")) if node else 0.15
	var spot_fog: float = float(node.get("spot_fog_energy")) if node else 10.0
	var lamp_fog: float = float(node.get("lamp_fog_energy")) if node else 4.0
	if l is DirectionalLight3D:
		var sun := l as DirectionalLight3D
		sun.shadow_enabled = sh > 0
		sun.directional_shadow_max_distance = SUN_SHADOW[dd]
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if sh >= 3 \
				else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.light_angular_distance = 0.5 if sh >= 4 else 0.0     # the sun's real size: soft penumbras
		sun.light_volumetric_fog_energy = float(base["fog"]) * sun_fog
		return
	var spot := l is SpotLight3D
	var big := spot or (l is OmniLight3D and (l as OmniLight3D).omni_range >= 5.0)
	l.shadow_enabled = sh > 0 and (bool(base["shadow"]) or (sh >= 2 and spot) or (sh >= 3 and big) or sh >= 4)
	if l.has_meta("gfx_no_shadow"):
		l.shadow_enabled = false   # its maker says shadows aren't worth it (rows of corridor lamps)
	l.light_volumetric_fog_energy = float(base["fog"]) * (spot_fog if spot else lamp_fog)
	l.light_size = maxf(float(base["size"]), 0.05 if sh >= 4 else 0.0)
	if l is OmniLight3D:
		var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
		(l as OmniLight3D).omni_shadow_mode = OmniLight3D.SHADOW_CUBE if sh >= 4 or compat else OmniLight3D.SHADOW_DUAL_PARABOLOID
	l.distance_fade_enabled = true
	l.distance_fade_begin = LIGHT_FADE[dd]
	l.distance_fade_length = LIGHT_FADE[dd] * 0.25
	l.distance_fade_shadow = LIGHT_FADE[dd] * 0.5


static func tune_camera(c: Camera3D) -> void:
	if c.has_meta("gfx_keep_fov"):
		return
	c.fov = float(GraphicsOptions.get_value("fov"))
