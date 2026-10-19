class_name GraphicsOptions
extends RefCounted
## Graphics options: what each one is, its choices, the quality presets, and saving them
## (user://graphics.cfg, section "graphics"). Static, so the menu, the Graphics autoload
## (which applies them) and the tests all share one copy. Ported from Void Salvage
## (GraphicsSettings) with the same options and presets.
##
## Every option is listed in OPTIONS: {key, tab, label, kind, choices or range, default,
## help}. Values are stored by key in `values`. Presets set the quality keys at once; any
## change by hand makes the preset "Custom".

const PATH := "user://graphics.cfg"
const SECTION := "graphics"

enum Kind { CHOICE, SLIDER, TOGGLE }

const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
		Vector2i(2560, 1440), Vector2i(3200, 1800), Vector2i(3840, 2160)]

const PRESETS: Array[String] = ["Low", "Medium", "High", "Ultra", "Max (screenshots)"]
const CUSTOM := "Custom"

## The options. "choices" for CHOICE, "min"/"max"/"step"/"unit" for SLIDER.
const OPTIONS: Array[Dictionary] = [
	# --- Display ------------------------------------------------------------------------
	{"key": "window_mode", "tab": "Display", "label": "Window", "kind": Kind.CHOICE, "default": 0,
		"choices": ["Windowed", "Borderless fullscreen", "Fullscreen (exclusive)"],
		"help": "Borderless switches to other windows instantly; exclusive can be a little faster."},
	{"key": "resolution", "tab": "Display", "label": "Resolution", "kind": Kind.CHOICE, "default": 1,
		"choices": ["1280 x 720", "1600 x 900", "1920 x 1080", "2560 x 1440", "3200 x 1800", "3840 x 2160 (4K)"],
		"help": "Windowed: the window's size. Fullscreen: the resolution the 3D view renders at (the screen stays at its own)."},
	{"key": "vsync", "tab": "Display", "label": "V-Sync", "kind": Kind.CHOICE, "default": 1,
		"choices": ["Off", "On", "Adaptive", "Mailbox (low latency)"],
		"help": "On stops tearing. Adaptive only syncs when you're above the refresh rate."},
	{"key": "max_fps", "tab": "Display", "label": "Frame rate limit", "kind": Kind.CHOICE, "default": 0,
		"choices": ["Unlimited", "30", "60", "90", "120", "144", "165", "240"], "help": ""},
	{"key": "fov", "tab": "Display", "label": "Field of view", "kind": Kind.SLIDER, "default": 80.0,
		"min": 60.0, "max": 110.0, "step": 1.0, "unit": "°", "help": "Vertical field of view."},
	{"key": "ui_scale", "tab": "Display", "label": "Interface size", "kind": Kind.CHOICE, "default": 0,
		"choices": ["Auto", "100%", "125%", "150%", "175%", "200%"],
		"help": "Auto grows the menus and HUD with the screen (so they're readable at 4K)."},
	{"key": "brightness", "tab": "Display", "label": "Brightness", "kind": Kind.SLIDER, "default": 1.0,
		"min": 0.5, "max": 2.0, "step": 0.05, "unit": "x", "help": "Overall exposure."},
	{"key": "hdr", "tab": "Display", "label": "HDR output", "kind": Kind.TOGGLE, "default": false,
		"help": "For HDR monitors (turn HDR on in Windows display settings too). Brighter highlights: engines, lamps, the sun."},
	{"key": "hdr_peak", "tab": "Display", "label": "HDR peak brightness", "kind": Kind.SLIDER, "default": 1000.0,
		"min": 400.0, "max": 4000.0, "step": 50.0, "unit": " nits", "help": "Set to your monitor's peak brightness."},
	{"key": "hdr_paper_white", "tab": "Display", "label": "HDR menu and scene brightness", "kind": Kind.SLIDER,
		"default": 200.0, "min": 80.0, "max": 400.0, "step": 10.0, "unit": " nits", "help": "How bright ordinary white looks in HDR."},
	{"key": "renderer", "tab": "Display", "label": "Graphics API", "kind": Kind.CHOICE, "default": 0,
		"choices": ["Vulkan", "DirectX 12"],
		"help": "Restart the game to switch. Try DirectX 12 if Vulkan stutters or crashes on your PC."},
	# --- Quality ------------------------------------------------------------------------
	{"key": "upscaler", "tab": "Quality", "label": "Upscaling", "kind": Kind.CHOICE, "default": 0,
		"choices": ["Off (native)", "AMD FSR 1 (spatial)", "AMD FSR 2.2 (temporal)"],
		"help": "Renders smaller and sharpens it up to full size: more frames per second. FSR 2.2 looks best and does its own anti-aliasing. (DLSS isn't available in this engine.)"},
	{"key": "render_scale", "tab": "Quality", "label": "Render scale", "kind": Kind.SLIDER, "default": 1.0,
		"min": 0.5, "max": 2.0, "step": 0.05, "unit": "x",
		"help": "Below 1 with upscaling: faster. Above 1 (upscaling off): supersampling, sharper but slow."},
	{"key": "sharpness", "tab": "Quality", "label": "Upscaling sharpness", "kind": Kind.SLIDER, "default": 0.6,
		"min": 0.0, "max": 1.0, "step": 0.05, "unit": "", "help": ""},
	{"key": "antialiasing", "tab": "Quality", "label": "Anti-aliasing", "kind": Kind.CHOICE, "default": 3,
		"choices": ["Off", "FXAA", "SMAA", "TAA", "MSAA 2x", "MSAA 4x", "MSAA 8x", "MSAA 4x + TAA"],
		"help": "Smooths jagged edges. TAA is smoothest; MSAA is crispest on thin frame members."},
	{"key": "anisotropic", "tab": "Quality", "label": "Texture filtering", "kind": Kind.CHOICE, "default": 3,
		"choices": ["Off", "2x", "4x", "8x", "16x"], "help": "Keeps surfaces sharp at shallow angles."},
	{"key": "detail", "tab": "Quality", "label": "Model detail", "kind": Kind.CHOICE, "default": 2,
		"choices": ["Low", "Medium", "High", "Ultra"], "help": "How soon distant models drop to simpler versions."},
	{"key": "surfaces", "tab": "Quality", "label": "Surface detail", "kind": Kind.CHOICE, "default": 2,
		"choices": ["Off", "Low (no bumps)", "High"],
		"help": "The fine look of every surface: brushed metal, paint grain, ceramic chalk, panel lines. High adds their bumps catching the light."},
	{"key": "shadows", "tab": "Quality", "label": "Shadows", "kind": Kind.CHOICE, "default": 3,
		"choices": ["Off", "Low", "Medium", "High", "Ultra"],
		"help": "Sharpness and softness of shadows, and which lights cast them: Medium adds the helmet lamp and floodlights, High adds the bigger lamps, Ultra every light."},
	{"key": "draw_distance", "tab": "Quality", "label": "Draw distance", "kind": Kind.CHOICE, "default": 2,
		"choices": ["Near", "Medium", "Far", "Max"],
		"help": "How far away shadows, lamps and volumetric effects are drawn."},
	# --- Lighting -----------------------------------------------------------------------
	{"key": "gi", "tab": "Lighting", "label": "Global illumination", "kind": Kind.CHOICE, "default": 1,
		"choices": ["Off", "Screen-space (SSIL)", "SDFGI", "SDFGI + SSIL"],
		"help": "Light bouncing off surfaces onto others. SDFGI traces light through the whole scene (the engine's ray-traced GI, done in software, so any GPU); SSIL adds fine bounce detail from what's on screen."},
	{"key": "gi_quality", "tab": "Lighting", "label": "GI quality", "kind": Kind.CHOICE, "default": 1,
		"choices": ["Low", "Medium", "High", "Ultra"], "help": ""},
	{"key": "ao", "tab": "Lighting", "label": "Ambient occlusion", "kind": Kind.CHOICE, "default": 3,
		"choices": ["Off", "Low", "Medium", "High", "Ultra"], "help": "Soft contact shadows in corners and seams."},
	{"key": "reflections", "tab": "Lighting", "label": "Reflections", "kind": Kind.CHOICE, "default": 2,
		"choices": ["Off", "Low", "High", "Ultra"], "help": "Screen-space reflections on metal and glass."},
	{"key": "volumetrics", "tab": "Lighting", "label": "Volumetric lighting", "kind": Kind.CHOICE, "default": 2,
		"choices": ["Off", "Low", "Medium", "High", "Ultra"],
		"help": "Light you can see in the air: lamp and headlight beams, sun shafts past the wreck, gas clouds."},
	{"key": "beams", "tab": "Lighting", "label": "Light beams (dust)", "kind": Kind.SLIDER, "default": 1.0,
		"min": 0.0, "max": 3.0, "step": 0.1, "unit": "x", "help": "How much dust hangs in the air to catch light."},
	{"key": "clouds", "tab": "Lighting", "label": "Gas clouds", "kind": Kind.TOGGLE, "default": true,
		"help": "Volumetric clouds of gas and dust drifting round the wreck field (needs volumetric lighting)."},
	{"key": "bloom", "tab": "Lighting", "label": "Bloom", "kind": Kind.SLIDER, "default": 1.0,
		"min": 0.0, "max": 2.0, "step": 0.1, "unit": "x", "help": "Glow round bright lights."},
	{"key": "tonemap", "tab": "Lighting", "label": "Tone mapping", "kind": Kind.CHOICE, "default": 0,
		"choices": ["ACES (punchy)", "AgX (natural, best for HDR)", "Filmic"], "help": ""},
	{"key": "eye_adaptation", "tab": "Lighting", "label": "Eye adaptation", "kind": Kind.TOGGLE, "default": false,
		"help": "Exposure adjusts slowly between bright sunlight and dark interiors."},
]

## Keys each preset sets, and their values per preset (Low, Medium, High, Ultra, Max).
const PRESET_VALUES: Dictionary = {
	"upscaler": [1, 0, 0, 0, 0],
	"render_scale": [0.67, 1.0, 1.0, 1.0, 1.5],
	"antialiasing": [1, 2, 3, 3, 7],
	"anisotropic": [1, 2, 3, 4, 4],
	"detail": [0, 1, 2, 3, 3],
	"surfaces": [1, 2, 2, 2, 2],
	"shadows": [1, 2, 3, 4, 4],
	"draw_distance": [0, 1, 2, 3, 3],
	"gi": [0, 1, 1, 3, 3],
	"gi_quality": [0, 0, 1, 2, 3],
	"ao": [0, 2, 3, 4, 4],
	"reflections": [0, 1, 2, 3, 3],
	"volumetrics": [0, 1, 2, 3, 4],
	"eye_adaptation": [false, false, false, false, false],
}

const DEFAULT_PRESET := "High"

## Where settings are saved (tests point this somewhere else).
static var path: String = PATH
static var values: Dictionary = {}
static var preset: String = DEFAULT_PRESET
static var _loaded := false


static func option(key: String) -> Dictionary:
	for o: Dictionary in OPTIONS:
		if o["key"] == key:
			return o
	return {}


static func get_value(key: String) -> Variant:
	if not _loaded:
		load_settings()
	if values.has(key):
		return values[key]
	return option(key).get("default")


## Sets one option by hand (the preset becomes Custom if it's a preset key).
static func set_value(key: String, v: Variant) -> void:
	if not _loaded:
		load_settings()
	values[key] = v
	if PRESET_VALUES.has(key):
		preset = _matching_preset()


static func apply_preset(name: String) -> void:
	if not _loaded:
		load_settings()
	var i := PRESETS.find(name)
	if i < 0:
		return
	for key: String in PRESET_VALUES:
		values[key] = PRESET_VALUES[key][i]
	preset = name


static func _matching_preset() -> String:
	for i in PRESETS.size():
		var all := true
		for key: String in PRESET_VALUES:
			if not is_equal_approx(float(get_value(key)), float(PRESET_VALUES[key][i])):
				all = false
				break
		if all:
			return PRESETS[i]
	return CUSTOM


static func reset_defaults() -> void:
	values.clear()
	for o: Dictionary in OPTIONS:
		values[o["key"]] = o["default"]
	_loaded = true
	apply_preset(DEFAULT_PRESET)


static func load_settings(from: String = "") -> void:
	if from == "":
		from = path
	_loaded = true
	values.clear()
	for o: Dictionary in OPTIONS:
		values[o["key"]] = o["default"]
	apply_preset(DEFAULT_PRESET)
	var cfg := ConfigFile.new()
	if cfg.load(from) != OK:
		return
	for o: Dictionary in OPTIONS:
		var key: String = o["key"]
		if not cfg.has_section_key(SECTION, key):
			continue
		var v: Variant = cfg.get_value(SECTION, key)
		match o["kind"]:
			Kind.CHOICE:
				values[key] = clampi(int(v), 0, (o["choices"] as Array).size() - 1)
			Kind.SLIDER:
				values[key] = clampf(float(v), float(o["min"]), float(o["max"]))
			Kind.TOGGLE:
				values[key] = bool(v)
	preset = _matching_preset()


static func save_settings(to: String = "") -> void:
	if to == "":
		to = path
	var cfg := ConfigFile.new()
	cfg.load(to)
	for key: String in values:
		cfg.set_value(SECTION, key, values[key])
	cfg.save(to)


# --- Derived values -------------------------------------------------------------------

## The surface detail's strength per "surfaces" choice: (detail, normals), 0..1 each. The
## salvage shader reads them as the globals surface_detail and surface_normal.
const SURFACE_LEVELS: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0)]


static func surface_levels() -> Vector2:
	return SURFACE_LEVELS[clampi(int(get_value("surfaces")), 0, SURFACE_LEVELS.size() - 1)]

static func resolution() -> Vector2i:
	return RESOLUTIONS[clampi(int(get_value("resolution")), 0, RESOLUTIONS.size() - 1)]


static func max_fps() -> int:
	var c: String = (option("max_fps")["choices"] as Array)[int(get_value("max_fps"))]
	return 0 if c == "Unlimited" else int(c)


## The interface scale for a window of this height (Auto grows from 1080p up).
static func ui_scale_for(window_height: int) -> float:
	var i := int(get_value("ui_scale"))
	if i == 0:
		return clampf(float(window_height) / 1080.0, 1.0, 2.0)
	return float([1.0, 1.0, 1.25, 1.5, 1.75, 2.0][i])


# --- Graphics API (needs a restart) ---------------------------------------------------

## Where the renderer choice is saved for the next start: override.cfg beside the game's
## exe (Godot reads it at launch, before the window opens).
static func override_path() -> String:
	return OS.get_executable_path().get_base_dir().path_join("override.cfg")


## Whether this build can switch graphics API (exported Windows builds).
static func can_switch_renderer() -> bool:
	return OS.has_feature("windows") and not OS.has_feature("editor")


static func renderer_driver_name(choice: int) -> String:
	return "d3d12" if choice == 1 else "vulkan"


## Writes the renderer choice to `path` (override.cfg) for the next start.
static func write_renderer(choice: int, to: String = "") -> Error:
	if to == "":
		to = override_path()
	var cfg := ConfigFile.new()
	cfg.load(to)
	cfg.set_value("rendering", "rendering_device/driver.windows", renderer_driver_name(choice))
	return cfg.save(to)


## The renderer running now (0 Vulkan, 1 DirectX 12).
static func current_renderer() -> int:
	return 1 if RenderingServer.get_current_rendering_driver_name() == "d3d12" else 0
