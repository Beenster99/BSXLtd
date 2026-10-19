class_name TradesLook
extends RefCounted
## Void Salvage's look for everything Trades draws, so the bench reads as the same universe:
## its company palette and lit edge strips (ShipParts), paint on the shared salvage surface
## shader with a finish from the finish library (ShipSurface.of), plain metals and a small
## lit screen for tools (SalvageTool.metal/readout), the suit and tool arm colours
## (PlayerModel, ToolController), and its HUD's cyan monospace text (Hud).
## BSX's own touch is the orange company trim where Void Salvage has teal.

const SHELL := Color(0.86, 0.85, 0.82)     # warm white panels
const DARK := Color(0.15, 0.16, 0.18)      # fittings, frames
const TOP := Color(0.7, 0.71, 0.7)         # counter tops
const TRIM := Color("e8792b")              # BSX orange (Void Salvage's teal is 0.12, 0.34, 0.44)
const EDGE := Color(0.4, 0.86, 1.0)        # the lit edge strip
const SCREEN := Color(0.45, 0.95, 1.0)     # screen text
const WARM := Color(1.0, 0.78, 0.5)        # warm lamp lens
## The salvager's suit and exoskeleton frame (PlayerModel), and the tool arm (ToolController).
const SUIT := Color(0.86, 0.86, 0.84)
const FRAME := Color(0.16, 0.17, 0.19)
const VISOR := Color(0.85, 0.62, 0.2)
const ARM := Color(0.25, 0.26, 0.28)
## The HUD's text: bright, dim (unselected), and the warning colour.
const HUD := Color(0.62, 0.9, 1.0, 0.9)
const HUD_DIM := Color(0.62, 0.9, 1.0, 0.35)
const HUD_WARN := Color(1.0, 0.62, 0.3, 0.95)

const SURFACE := preload("res://shared/void_salvage/shaders/salvage_surface.gdshader")

static var _paints: Dictionary = {}
static var _font: SystemFont


## Paint on the salvage surface shader: `color` with its own shine, or a finish from
## SurfaceFinish ("brushed_steel", "galvanised", "rubber_tread"...). One material per paint.
static func paint(color: Color, metallic: float, roughness: float, finish := "") -> ShaderMaterial:
	var key := "%s/%.2f/%.2f/%s" % [color.to_html(), metallic, roughness, finish]
	if _paints.has(key):
		return _paints[key]
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	# The albedo uniform is a source_color: Godot takes it as sRGB, like a StandardMaterial3D.
	m.set_shader_parameter("albedo", Vector3(color.r, color.g, color.b))
	m.set_shader_parameter("metallic", metallic)
	m.set_shader_parameter("roughness", roughness)
	m.set_shader_parameter("survey_skip", true)
	m.set_shader_parameter("material_finish", SurfaceFinish.code(finish) if finish != "" else 0)
	SurfaceFinish.apply(m)
	_paints[key] = m
	return m


## A lit strip or lamp lens (ShipKit.glow).
static func glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.03, 0.03)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## Plain metal for tools and the suit (SalvageTool.metal).
static func metal(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


## The one shared monospace font (Hud._mono_font): readout columns line up.
static func mono_font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Consolas", "Menlo", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	return _font


## HUD text in the Void Salvage style: monospace, cyan, a soft dark outline.
static func hud_label(font_size: int, color := HUD) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var settings := LabelSettings.new()
	settings.font = mono_font()
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = 4
	settings.outline_color = Color(0, 0, 0, 0.6)
	label.label_settings = settings
	return label


## A hotbar slot's box (Hud._build_hotbar): lit when selected.
static func slot_style(on: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(4)
	s.set_content_margin_all(10)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.set_border_width_all(2)
	s.bg_color = Color(0.62, 0.9, 1.0, 0.18) if on else Color(0.0, 0.0, 0.0, 0.35)
	s.border_color = HUD if on else Color(0.62, 0.9, 1.0, 0.18)
	return s


## A small lit screen (SalvageTool.readout): a dark panel `size` metres (width, height) at
## `at` under `parent`, with a monospace Label3D on its face (+Z). Returns the label.
static func readout(parent: Node3D, at: Vector3, size: Vector2, color := SCREEN) -> Label3D:
	var panel := MeshInstance3D.new()
	panel.name = "Readout"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, size.y, 0.008)
	panel.mesh = mesh
	panel.material_override = metal(Color(0.02, 0.03, 0.04), 0.2, 0.25)
	panel.position = at
	parent.add_child(panel)
	var label := Label3D.new()
	label.font = mono_font()
	label.font_size = 48
	label.pixel_size = size.y / 3.6 / 48.0
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector3(-size.x * 0.46, 0.0, 0.006)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.add_child(label)
	return label


## Void Salvage's environment (scenes/main.tscn): cool ambient, filmic tonemap, ambient
## occlusion and a little glow on the lit strips. Indoors there is no starfield to light
## and reflect, so a dim grey sky stands in for it (never seen: the background stays dark)
## and the metals keep their sheen.
static func environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.01, 0.012, 0.018)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.23, 0.28)
	sky_mat.sky_horizon_color = Color(0.32, 0.33, 0.36)
	sky_mat.ground_horizon_color = Color(0.2, 0.2, 0.21)
	sky_mat.ground_bottom_color = Color(0.08, 0.08, 0.09)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.3
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.ssao_enabled = true
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_bloom = 0.05
	return e
