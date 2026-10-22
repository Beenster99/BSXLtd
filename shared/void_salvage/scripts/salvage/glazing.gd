class_name Glazing
extends RefCounted
## The kinds of glass a part's window or lens can be (docs/ECONOMY_PLAN.md section 7, A1
## revised). Glass is see-through, so it stays a StandardMaterial3D of its own rather than a
## finish on the salvage surface; a part names its kind in `PartShape.glass_kind` and
## WreckDesign.fit (or any builder) takes the material from `material(kind)`. One shared
## material per kind. Presentation only.
##   CLEAR     plain window glass, faint blue
##   TINTED    smoked canopy glass (cockpits, visors)
##   FROSTED   rough translucent panes (washrooms, light boxes)
##   ARMOURED  thick green-edged laminate (bridges, gun sights)
##   AMBER     a warm lamp lens
##   RED       a red lens (nav lights, warning lamps)
##   SOLAR     the glossy dark cover glass over solar cells

enum Kind { CLEAR, TINTED, FROSTED, ARMOURED, AMBER, RED, SOLAR }

## kind -> (colour with alpha, metallic, roughness).
const LOOKS: Dictionary = {
	Kind.CLEAR: [Color(0.5, 0.72, 0.9, 0.28), 0.3, 0.05],
	Kind.TINTED: [Color(0.12, 0.16, 0.2, 0.62), 0.4, 0.06],
	Kind.FROSTED: [Color(0.8, 0.85, 0.88, 0.7), 0.0, 0.6],
	Kind.ARMOURED: [Color(0.45, 0.7, 0.62, 0.45), 0.3, 0.08],
	Kind.AMBER: [Color(1.0, 0.7, 0.25, 0.6), 0.2, 0.1],
	Kind.RED: [Color(0.9, 0.12, 0.08, 0.65), 0.2, 0.1],
	Kind.SOLAR: [Color(0.1, 0.14, 0.24, 0.5), 0.5, 0.04],
}

static var _materials: Dictionary = {}


## The shared material for `kind`.
static func material(kind: int) -> StandardMaterial3D:
	if not _materials.has(kind):
		var look: Array = LOOKS.get(kind, LOOKS[Kind.CLEAR])
		var m := StandardMaterial3D.new()
		m.albedo_color = look[0]
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = float(look[1])
		m.roughness = float(look[2])
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[kind] = m
	return _materials[kind]


static func display_name(kind: int) -> String:
	return ["Clear glass", "Tinted glass", "Frosted glass", "Armoured glass", "Amber lens", "Red lens",
			"Solar cover glass"][clampi(kind, 0, Kind.size() - 1)]


## Most crack points a cracked pane draws (the shader's array).
const MAX_CRACKS: int = 8
static var _cracked_shader: Shader


## A crazed copy of the glass `base` (docs/DAMAGE_PLAN.md 9.3.3): radial lines and broken
## rings spreading from each of `cracks` ([[point in the mesh's space, radius m], ...]),
## milky near each point. One per pane (a wreck has tens, not thousands).
static func cracked(base: Material, cracks: Array) -> ShaderMaterial:
	if _cracked_shader == null:
		_cracked_shader = load("res://shared/void_salvage/shaders/glass_cracked.gdshader")
	var colour := Color(0.5, 0.72, 0.9, 0.28)
	var metallic := 0.3
	var roughness := 0.05
	var std := base as StandardMaterial3D
	if std:
		colour = std.albedo_color
		metallic = std.metallic
		roughness = std.roughness
	var m := ShaderMaterial.new()
	m.shader = _cracked_shader
	m.set_shader_parameter("albedo", colour)
	m.set_shader_parameter("metallic", metallic)
	m.set_shader_parameter("roughness", roughness)
	var points := PackedVector4Array()
	for c: Array in cracks.slice(0, MAX_CRACKS):
		var p: Vector3 = c[0]
		points.append(Vector4(p.x, p.y, p.z, float(c[1])))
	m.set_shader_parameter("crack_count", points.size())
	points.resize(MAX_CRACKS)
	m.set_shader_parameter("cracks", points)
	return m
