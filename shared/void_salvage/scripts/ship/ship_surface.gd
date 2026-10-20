class_name ShipSurface
extends RefCounted
## The player ships' and stations' paint on the salvage surface shader (docs/ECONOMY_PLAN.md
## section 7, A1), so the company's livery gets the same PBR detail as the wrecks: the
## paint's colour and shine, brushed steel where it is bare metal, upholstery where it
## is cloth (`finish_for`; a paint's meta "finish" names any SurfaceFinish).
## Never weathered, and never part of the survey glass's view (`survey_skip`): the pilot's
## own ship isn't the wreck being read. ShipKit.add and StationMesh.finish pass every
## material through `of`. Presentation only.

## Paint this metallic or more reads as bare metal: it shows the brushed steel finish.
const BARE_METAL: float = 0.7
## Paint this rough (and not metallic) reads as cloth: cushions, mattresses.
const CLOTH_ROUGH: float = 0.85

static var _surfaces: Dictionary = {}


## The finish a plain paint shows (SurfaceFinish id): the one its meta "finish" names
## (ShipKit.paint(..., finish)), else brushed steel when it is metallic enough, upholstery
## when it is rough and not metallic, else "" (paint as built: the material's own metallic
## and roughness, smooth, chipping to bare metal).
static func finish_for(std: StandardMaterial3D) -> String:
	if std.has_meta("finish"):
		return String(std.get_meta("finish"))
	if std.metallic >= BARE_METAL:
		return "brushed_steel"
	if std.metallic < 0.1 and std.roughness >= CLOTH_ROUGH:
		return "upholstery"
	return ""


## The ship surface for `material`: a shared shader copy of a plain paint (one per paint),
## or `material` itself when it glows, is see-through or textured (lamps, screens, glass,
## kit models).
static func of(material: Material) -> Material:
	var std := material as StandardMaterial3D
	if std == null or std.emission_enabled or std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
			or std.albedo_texture != null or std.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL:
		return material
	if not _surfaces.has(std):
		var m := ShaderMaterial.new()
		m.shader = SurfaceFinish.surface_shader(std.cull_mode == BaseMaterial3D.CULL_DISABLED)
		# StandardMaterial3D takes its colour as sRGB; this shader's albedo is linear.
		var c := std.albedo_color.srgb_to_linear()
		m.set_shader_parameter("albedo", Vector3(c.r, c.g, c.b))
		m.set_shader_parameter("use_vertex_color", std.vertex_color_use_as_albedo)
		m.set_shader_parameter("vertex_color_srgb", std.vertex_color_is_srgb)
		m.set_shader_parameter("metallic", std.metallic)
		m.set_shader_parameter("roughness", std.roughness)
		m.set_shader_parameter("survey_skip", true)
		m.set_shader_parameter("material_finish", SurfaceFinish.code(finish_for(std)))
		SurfaceDetail.apply(m)
		_surfaces[std] = m
	return _surfaces[std]
